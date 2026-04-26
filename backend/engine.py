"""
Hollow Township — Session Engine
=================================
Orchestrates all backend passes in correct order for one day→night→dawn cycle.
This is the Lambda entry point (or its local equivalent for testing).

Per-cycle sequence:
  DAY PHASE (player-driven, REST calls log choices in real time)
      ↓
  DAY END
    [1] Gossip Propagation Pass    — load observations, run transfers
    [2] Night Pre-Computation      — Horror/Creature Agent (LLM, async)
      ↓
  NIGHT PHASE (WebSocket, pre-computed events served from queue)
      ↓
  DAWN
    [3] Significance Pass          — zone/object significance from night events
    [4] Consequence Thread         — match choices to events, build thread payloads
    [5] Investment Anchor          — compute highest-weight NPC for False Dawn

All rule-based passes ([1], [3], [4], [5]) are synchronous and cheap.
Night Pre-Computation [2] is async and LLM-backed — this module only
invokes its interface (a callable) so tests can inject a mock.

Design specs:
  ARCHITECTURE.md — Agent line, pass ordering, latency budget
  WORLD_BACKSTORY.md Section 7 — Gossip model
  PLACES_AND_OBJECTS.md — Significance model
  REVEAL_MECHANIC.md — Consequence thread format
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Callable, Optional

from backend.models import SessionState, ChoiceEntry, NightEvent
from backend.gossip.propagation import run_pass as gossip_pass, knowledge_summary
from backend.significance.pass_ import run_dawn_pass as significance_pass, significance_summary
from backend.consequence.thread_generator import (
    generate_thread,
    compute_investment_anchor,
    ThreadEntry,
)


# ── Cycle result ──────────────────────────────────────────────────────────────

@dataclass
class CycleResult:
    day: int
    gossip_transfers_fired: int = 0
    night_events: list[NightEvent] = field(default_factory=list)
    thread_entries: list[ThreadEntry] = field(default_factory=list)
    knowledge_snapshot: dict = field(default_factory=dict)    # for NPC Behavior Agent USER block
    significance_snapshot: dict = field(default_factory=dict) # per-NPC, for NPC Behavior Agent
    investment_anchor: Optional[str] = None
    errors: list[str] = field(default_factory=list)


# ── Engine ────────────────────────────────────────────────────────────────────

class SessionEngine:
    """
    Stateful engine for one player session. Holds SessionState and applies
    each pass in order. In production this is reconstructed from DynamoDB
    at the start of each Lambda invocation.
    """

    def __init__(self, state: SessionState):
        self.state = state

    # ── Day end → night pre-computation ──────────────────────────────────────

    def end_day(
        self,
        day: int,
        choice_log: list[ChoiceEntry],
        night_precompute_fn: Callable[[SessionState, list[ChoiceEntry], dict], list[NightEvent]],
        zone_assignments: dict[str, str],
    ) -> CycleResult:
        """
        Call at day→night transition.

        Args:
            day: current day number
            choice_log: all choices logged today
            night_precompute_fn: async-ish callable that takes (state, choices, knowledge)
                                 and returns a list of NightEvent. In production this is
                                 the Horror/Creature Agent Lambda invocation.
                                 In tests inject a deterministic stub.
            zone_assignments: {npc_id: zone_id} for tonight's night roster

        Returns:
            CycleResult with gossip transfers fired and the night event queue.
        """
        result = CycleResult(day=day)

        # [1] Gossip Propagation Pass
        try:
            transfers = gossip_pass(
                state=self.state,
                day=day,
                choice_log=choice_log,
                night_events=[],  # no prior-night events for gossip on Day 1
            )
            result.gossip_transfers_fired = len(transfers)
        except Exception as e:
            result.errors.append(f"gossip_pass failed: {e}")

        # Build knowledge summary for Horror Agent (and NPC Behavior Agent)
        result.knowledge_snapshot = knowledge_summary(self.state)

        # [2] Night Pre-Computation (LLM, caller-supplied callable)
        try:
            result.night_events = night_precompute_fn(
                self.state,
                choice_log,
                result.knowledge_snapshot,
            )
        except Exception as e:
            result.errors.append(f"night_precompute_fn failed: {e}")
            result.night_events = []

        return result

    # ── Dawn ──────────────────────────────────────────────────────────────────

    def begin_dawn(
        self,
        day: int,
        choice_log: list[ChoiceEntry],
        night_events: list[NightEvent],
        zone_assignments: dict[str, str],
    ) -> CycleResult:
        """
        Call at night→dawn transition.

        Args:
            day: the day that just ended (night was night=day)
            choice_log: full chapter choice log (all days up to and including today)
            night_events: events that fired last night
            zone_assignments: {npc_id: zone_id} for the night that just ended

        Returns:
            CycleResult with significance updates, consequence thread entries,
            and the updated investment anchor.
        """
        result = CycleResult(day=day)
        result.night_events = night_events

        # [3] Significance Pass
        try:
            significance_pass(
                state=self.state,
                night_events=night_events,
                zone_assignments=zone_assignments,
                choice_log=choice_log,
                day=day,
            )
        except Exception as e:
            result.errors.append(f"significance_pass failed: {e}")

        # Build per-NPC significance snapshot for NPC Behavior Agent USER block
        result.significance_snapshot = {
            npc_id: significance_summary(self.state, npc_id)
            for npc_id in self.state.npc_states
        }

        # [4] Consequence Thread
        try:
            result.thread_entries = generate_thread(
                state=self.state,
                choice_log=choice_log,
                night_events=night_events,
                night=day,
            )
        except Exception as e:
            result.errors.append(f"thread_generator failed: {e}")

        # [5] Investment Anchor
        try:
            self.state.investment_anchor = compute_investment_anchor(choice_log)
            result.investment_anchor = self.state.investment_anchor
        except Exception as e:
            result.errors.append(f"investment_anchor failed: {e}")

        return result

    # ── NPC Behavior Agent USER block builder ─────────────────────────────────

    def build_npc_user_block(self, npc_id: str) -> dict:
        """
        Assembles the dynamic USER block fragment for one NPC Behavior Agent call.
        Includes: arc state, knowledge state (what they know), significance profile
        (how they relate to each zone and object), bond state.

        This is passed to the NPC Behavior Agent alongside the frozen SYSTEM prompt.
        The Agent generates behavioral state lines consistent with all three inputs.
        """
        npc = self.state.npc_states.get(npc_id)
        if not npc:
            return {}

        ks = self.state.knowledge_states.get(npc_id)
        knowledge = [o.observation_type for o in ks.held_observations] if ks else []

        sig = significance_summary(self.state, npc_id)

        return {
            "npc_id": npc_id,
            "arc_state": npc.arc_state,
            "domain": npc.domain,
            "bond_partner": npc.bond_partner,
            "bond_depth": npc.bond_depth,
            "knowledge_state": knowledge,
            "zone_significance": sig["zone_modifiers"],
            "accessible_objects": sig["accessible_objects"],
            "gossip_stage": ks.gossip_stage if ks else 1,
        }
