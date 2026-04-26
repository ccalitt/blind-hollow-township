"""
Hollow Township — Gossip Propagation Pass
==========================================
Rule-based computation. No LLM inference. Runs at day→night transition,
before the Horror/Creature Agent pre-computes the night event queue.

Design spec: WORLD_BACKSTORY.md Section 7, ARCHITECTURE.md Gossip Engine.

Three-stage model:
  Stage 1 — NPC has nothing held
  Stage 2 — NPC holds an observation (from witnessed event or prior receipt)
  Stage 3 — NPC has transmitted at least once this day

Transmission is stochastic but seeded per (player_id, day, from_npc, to_npc)
so the same relationship conditions produce the same outcome in a given run.
Different bond depths or assignment histories produce different outcomes.
"""

from __future__ import annotations
import hashlib
from typing import Optional

from backend.models import (
    SessionState,
    NPCKnowledgeState,
    Observation,
    GossipTransfer,
)


# ── Gossip disposition table ──────────────────────────────────────────────────
# Mirrors NPC_GOSSIP_DISPOSITIONS in the simulator and ARCHITECTURE.md spec.
# base_threshold: roll must be < (threshold × trust_weight) for transfer to fire
# credibility_weight: multiplier on received info's influence on behavioural state
# trigger: condition gate before transmission is even attempted

GOSSIP_DISPOSITIONS: dict[str, dict] = {
    "ruth":      {"base_threshold": 0.25, "credibility_weight": 1.4, "trigger": "safety_concern"},
    "thomas":    {"base_threshold": 0.70, "credibility_weight": 0.85,"trigger": "fear_state"},
    "maren":     {"base_threshold": 0.00, "credibility_weight": 1.0, "trigger": "fear_activated"},
    "elias":     {"base_threshold": 0.05, "credibility_weight": 1.2, "trigger": "bond_only"},
    "constance": {"base_threshold": 0.00, "credibility_weight": 0.0, "trigger": "receiver_only"},
    "peder":     {"base_threshold": 0.15, "credibility_weight": 1.1, "trigger": "environmental_only"},
}

# Arrivals use a default disposition — moderate threshold, neutral credibility
DEFAULT_ARRIVAL_DISPOSITION: dict = {
    "base_threshold": 0.40,
    "credibility_weight": 1.0,
    "trigger": "any",
}


# ── Trust weight computation ──────────────────────────────────────────────────

def compute_trust(from_id: str, to_id: str, state: SessionState) -> float:
    """
    Base trust (0.4) boosted by bond depth between the two NPCs.
    Bond depth 1 = +0.2; each additional depth level = +0.1, capped at 1.0.
    """
    base = 0.4
    from_npc = state.npc_states.get(from_id)
    if from_npc and from_npc.bond_partner == to_id:
        base += 0.2 + (from_npc.bond_depth * 0.1)
    # Check reverse bond (arrival bonded to named NPC)
    to_npc = state.npc_states.get(to_id)
    if to_npc and to_npc.bond_partner == from_id:
        base = max(base, 0.2 + 0.2 + (to_npc.bond_depth * 0.1))
    return min(1.0, base)


# ── Candidate resolution ──────────────────────────────────────────────────────

def get_transmission_candidates(from_id: str, state: SessionState) -> list[str]:
    """
    Returns NPC IDs that `from_id` could transmit to today, filtered by
    their gossip disposition trigger.
    """
    disp = GOSSIP_DISPOSITIONS.get(from_id, DEFAULT_ARRIVAL_DISPOSITION)
    trigger = disp["trigger"]
    all_ids = list(state.npc_states.keys())

    if trigger == "receiver_only":
        return []

    if trigger == "bond_only":
        npc = state.npc_states.get(from_id)
        if npc and npc.bond_partner:
            return [npc.bond_partner]
        return []

    if trigger == "environmental_only":
        # Peder transmits only to NPCs currently sharing Zone 4 (construction domain proxy)
        return [
            nid for nid in all_ids
            if nid != from_id
            and state.npc_states.get(nid)
            and state.npc_states[nid].domain == "construction"
        ]

    # safety_concern, fear_state, fear_activated, any
    return [nid for nid in all_ids if nid != from_id]


# ── Effective threshold ───────────────────────────────────────────────────────

def effective_threshold(from_id: str, state: SessionState) -> float:
    disp = GOSSIP_DISPOSITIONS.get(from_id, DEFAULT_ARRIVAL_DISPOSITION)
    threshold = disp["base_threshold"]
    ks = state.knowledge_states.get(from_id)
    # Maren-type: fear_activated spikes transmission probability
    if disp["trigger"] == "fear_activated" and ks and ks.fear_active:
        threshold = 0.65
    return threshold


# ── Seeded roll ───────────────────────────────────────────────────────────────

def seeded_roll(player_id: str, day: int, from_id: str, to_id: str) -> float:
    """
    Deterministic roll in [0, 1) based on session + day + NPC pair.
    Same inputs → same outcome every time. Different bond conditions → different
    trust weight → different effective threshold → different outcome.
    """
    key = f"{player_id}:{day}:{from_id}:{to_id}"
    digest = hashlib.sha256(key.encode()).digest()
    return int.from_bytes(digest[:4], "big") / 0xFFFFFFFF


# ── Observation loading ───────────────────────────────────────────────────────

def load_day_observations(
    state: SessionState,
    day: int,
    choice_log: list,
    night_events: list,
) -> None:
    """
    Populate Stage 2 (held observations) from today's choice log and any
    night events that fired on the previous night. Called before run_pass().

    choice_log: list of ChoiceEntry from today's day phase
    night_events: list of NightEvent from last night (empty on Day 1)
    """

    def _ensure(npc_id: str) -> NPCKnowledgeState:
        if npc_id not in state.knowledge_states:
            state.knowledge_states[npc_id] = NPCKnowledgeState(npc_id=npc_id)
        return state.knowledge_states[npc_id]

    # Elias: logs a treeline observation when his report was acknowledged
    elias_ks = _ensure("elias")
    if any(e.action_type == "elias_report_logged" and e.day_cycle == day for e in choice_log):
        elias_ks.held_observations.append(
            Observation("treeline_movement_witnessed", day_witnessed=day, zone_id="zone_3")
        )
        elias_ks.gossip_stage = max(elias_ks.gossip_stage, 2)

    # Maren: ledger cover activates fear state → Stage 2 + fear_active
    maren_ks = _ensure("maren")
    if any(e.action_type in ("association_ledger_edited", "cover_discrepancy")
           and e.day_cycle == day for e in choice_log):
        maren_ks.held_observations.append(
            Observation("ledger_discrepancy_knowledge", day_witnessed=day)
        )
        maren_ks.fear_active = True
        maren_ks.gossip_stage = max(maren_ks.gossip_stage, 2)

    # Thomas: if arc is functional (unreported event weight), he holds and may leak
    thomas_npc = state.npc_states.get("thomas")
    if thomas_npc and thomas_npc.arc_state == "functional":
        thomas_ks = _ensure("thomas")
        if not any(o.observation_type == "unreported_event_knowledge"
                   for o in thomas_ks.held_observations):
            thomas_ks.held_observations.append(
                Observation("unreported_event_knowledge", day_witnessed=day)
            )
            thomas_ks.gossip_stage = max(thomas_ks.gossip_stage, 2)

    # Ruth: holds safety-relevant info when Association interaction occurred
    ruth_ks = _ensure("ruth")
    if any(e.action_type.startswith("association") and e.day_cycle == day for e in choice_log):
        ruth_ks.held_observations.append(
            Observation("association_situation_known", day_witnessed=day)
        )
        ruth_ks.gossip_stage = max(ruth_ks.gossip_stage, 2)

    # Night event witnesses: any NPC in threat_npc_ids for last night's events
    # gets the horror observation loaded into their knowledge state
    for event in night_events:
        for npc_id in event.threat_npc_ids:
            ks = _ensure(npc_id)
            ks.held_observations.append(
                Observation(
                    observation_type=f"horror_witnessed_night{event.night}",
                    source_event_id=event.event_id,
                    day_witnessed=day,
                    zone_id=event.zone_id,
                )
            )
            ks.gossip_stage = max(ks.gossip_stage, 2)

    # Ensure Constance and Peder have entries (receivers / env-only)
    _ensure("constance")
    _ensure("peder")


# ── Main propagation pass ─────────────────────────────────────────────────────

def run_pass(
    state: SessionState,
    day: int,
    choice_log: list,
    night_events: list,
) -> list[GossipTransfer]:
    """
    Full gossip propagation pass for one day→night transition.

    1. Load today's observations into knowledge states.
    2. For each NPC with held observations (Stage 2), attempt transmission
       to each eligible candidate.
    3. Successful transfers update the recipient's knowledge state and
       append a GossipTransfer record.
    4. Special consequence hooks fire on significant transfers (Elias→Ruth bond,
       Maren fear-activation cascade).

    Returns: list of GossipTransfer records that fired this pass.
    Also mutates state.knowledge_states and appends to state.gossip_transfers.
    """
    load_day_observations(state, day, choice_log, night_events)

    fired: list[GossipTransfer] = []

    for from_id, ks in list(state.knowledge_states.items()):
        if ks.gossip_stage < 2 or not ks.held_observations:
            continue

        disp = GOSSIP_DISPOSITIONS.get(from_id, DEFAULT_ARRIVAL_DISPOSITION)
        if disp["trigger"] == "receiver_only":
            continue

        threshold = effective_threshold(from_id, state)
        credibility = disp["credibility_weight"]
        candidates = get_transmission_candidates(from_id, state)

        for to_id in candidates:
            trust = compute_trust(from_id, to_id, state)
            roll = seeded_roll(state.player_id, day, from_id, to_id)

            if roll < threshold * trust:
                recipient_ks = state.knowledge_states.setdefault(
                    to_id, NPCKnowledgeState(npc_id=to_id)
                )
                transferred = list(ks.held_observations)
                for obs in transferred:
                    recipient_ks.held_observations.append(obs)
                recipient_ks.received_from.setdefault(from_id, []).extend(transferred)
                recipient_ks.gossip_stage = max(recipient_ks.gossip_stage, 2)
                ks.gossip_stage = 3

                transfer = GossipTransfer(
                    day=day,
                    from_npc=from_id,
                    to_npc=to_id,
                    observations=transferred,
                    trust_weight=round(trust, 3),
                    credibility_weight=round(credibility, 3),
                )
                fired.append(transfer)
                state.gossip_transfers.append(transfer)

    return fired


# ── Knowledge state summary (for NPC Behavior Agent USER block) ───────────────

def knowledge_summary(state: SessionState) -> dict[str, list[str]]:
    """
    Returns a compact {npc_id: [observation_type, ...]} dict for inclusion
    in the NPC Behavior Agent USER block. The Agent sees what each NPC knows
    without seeing how they got it — provenance is intentionally stripped.
    """
    result: dict[str, list[str]] = {}
    for npc_id, ks in state.knowledge_states.items():
        obs_types = list({o.observation_type for o in ks.held_observations})
        if obs_types:
            result[npc_id] = obs_types
    return result
