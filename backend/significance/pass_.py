"""
Hollow Township — Significance Computation Pass
================================================
Rule-based computation. No LLM inference. Runs at dawn, after the night
consequence thread has been generated.

Design spec: PLACES_AND_OBJECTS.md — Backend Integration section.

For each night event that fired:
  1. Identify which zone it occurred in.
  2. Identify which NPCs were present (in threat_npc_ids or assigned to that zone).
  3. Increment event_weight for each present NPC × horror_intensity.
  4. Update behavioral_modifier from threshold bands.
  5. Mark permanent significance for horror events (Walker breach, Surveyor mark).

Object significance is updated separately:
  - Ledger: updated when ledger-related choices are logged.
  - Foundation object: appears on Day 4/5 excavation.
  - Personal objects: accessibility flag set when NPC arc crosses threshold.

The NPC Behavior Agent reads behavioral_modifier from significance_map in its
USER block to generate state lines consistent with a person who has experienced
that level of accumulated event weight at a specific place.
"""

from __future__ import annotations
from typing import Optional

from backend.models import (
    SessionState,
    NightEvent,
    ChoiceEntry,
    ZoneNPCSignificance,
    ObjectNPCSignificance,
    weight_to_modifier,
)


# ── Zone significance update ──────────────────────────────────────────────────

# Horror events that create permanent significance for present NPCs
PERMANENT_EVENT_TYPES = {
    "walker_breach",
    "walker_reached_settlement",
    "surveyor_marked_zone5",
    "watcher_first_depredation",
}

# Zone assigned to each event type (events that have a clear home zone)
EVENT_ZONE_MAP: dict[str, str] = {
    "walker_breach":              "zone_3",
    "walker_reached_settlement":  "zone_3",
    "watcher_first_depredation":  "zone_1",
    "watcher_active":             "zone_1",
    "surveyor_walk_boundary":     "zone_3",
    "surveyor_marked_zone5":      "zone_5",
    "npc_injured_at_post":        None,   # zone determined by NPC assignment
    "arc_destabilized":           None,
}


def update_zone_significance(
    state: SessionState,
    event: NightEvent,
    zone_assignments: dict[str, str],  # {npc_id: zone_id} for tonight's roster
) -> None:
    """
    Apply one night event to the significance map.
    zone_assignments: which zone each NPC was assigned to this night.
    """
    # Determine zone from event or NPC assignment
    zone_id: Optional[str] = event.zone_id
    if not zone_id:
        # Infer from first threatened NPC's assignment
        for npc_id in event.threat_npc_ids:
            if npc_id in zone_assignments:
                zone_id = zone_assignments[npc_id]
                break

    if not zone_id:
        return  # cannot attribute significance without a zone

    permanent = any(t in event.event_text.lower() for t in
                    ["breach", "reached settlement", "marked zone 5", "marked zone5"])

    # All NPCs assigned to this zone tonight accumulate significance
    present_npcs = [
        npc_id for npc_id, z in zone_assignments.items() if z == zone_id
    ]
    # Also include directly threatened NPCs even if assignment was elsewhere
    for npc_id in event.threat_npc_ids:
        if npc_id not in present_npcs:
            present_npcs.append(npc_id)

    zone_map = state.significance_map.setdefault(zone_id, {})
    for npc_id in present_npcs:
        sig = zone_map.setdefault(npc_id, ZoneNPCSignificance())
        sig.apply_event(
            event_id=event.event_id,
            intensity=event.horror_intensity,
            permanent=permanent,
        )


def run_zone_significance_pass(
    state: SessionState,
    night_events: list[NightEvent],
    zone_assignments: dict[str, str],
) -> None:
    """
    Run significance update for all night events at once. Called at dawn.
    """
    for event in night_events:
        update_zone_significance(state, event, zone_assignments)


# ── Object significance update ────────────────────────────────────────────────

def update_ledger_significance(
    state: SessionState,
    choice_log: list[ChoiceEntry],
    day: int,
) -> None:
    """
    Ledger significance: updated by ledger-related choice actions.
    NPCs who were in npc_ids for ledger choices accumulate significance.
    """
    obj_id = "handover_ledger"
    ledger_actions = {
        "maren_ledger_read", "association_ledger_unedited",
        "association_ledger_edited", "compact_ledger_entry_added",
    }
    obj_map = state.object_significance.setdefault(obj_id, {})

    for entry in choice_log:
        if entry.action_type in ledger_actions and entry.day_cycle == day:
            for npc_id in entry.npc_ids:
                sig = obj_map.setdefault(npc_id, ObjectNPCSignificance())
                sig.event_weight += 0.3
                sig.events.append(entry.choice_id)
                # Ledger becomes accessible to all participants in ledger events
                sig.accessible = True


def update_foundation_object(
    state: SessionState,
    day: int,
) -> None:
    """
    Peder's foundation object appears on Day 4/5 excavation.
    Becomes accessible to Peder; transferred to others only through gossip.
    """
    if not state.peder_foundation_excavated:
        return

    obj_id = "peder_foundation_object"
    obj_map = state.object_significance.setdefault(obj_id, {})
    peder_sig = obj_map.setdefault("peder", ObjectNPCSignificance())
    if not peder_sig.accessible:
        peder_sig.accessible = True
        peder_sig.event_weight = 1.0
        peder_sig.events.append(f"excavation_day{day}")


def update_personal_objects(state: SessionState) -> None:
    """
    Personal objects become accessible when NPC arc crosses a specific threshold.
    These are "once" register items per TONE.md. Once accessible, they stay accessible
    but each NPC's object only ever surfaces once in generated content.
    """
    arc_object_conditions: dict[str, tuple[str, list[str]]] = {
        # npc_id: (object_id, [arc_states that trigger accessibility])
        "ruth":      ("ruth_photograph",        ["fragile", "broken"]),
        "elias":     ("elias_delivery_clipboard", ["contributing"]),
        "thomas":    ("thomas_reference_book",   ["contributing"]),
        "maren":     ("maren_degree_program",    ["fragile", "broken"]),
        "peder":     ("peder_three_photographs", ["contributing"]),
    }
    for npc_id, (obj_id, trigger_states) in arc_object_conditions.items():
        npc = state.npc_states.get(npc_id)
        if not npc:
            continue
        if npc.arc_state in trigger_states:
            obj_map = state.object_significance.setdefault(obj_id, {})
            sig = obj_map.setdefault(npc_id, ObjectNPCSignificance())
            sig.accessible = True
            if not sig.events:
                sig.event_weight = 0.5
                sig.events.append(f"arc_threshold_{npc.arc_state}")


def run_object_significance_pass(
    state: SessionState,
    choice_log: list[ChoiceEntry],
    day: int,
) -> None:
    """
    Run all object significance updates at dawn.
    """
    update_ledger_significance(state, choice_log, day)
    update_foundation_object(state, day)
    update_personal_objects(state)


# ── Zone 5 progressive significance ──────────────────────────────────────────

def update_zone5_significance(state: SessionState, day: int) -> None:
    """
    Zone 5 accumulates significance indirectly — through Walker origins,
    Surveyor patrol, Dix inspection, and Constance's speech.
    NPCs who received these observations (via gossip or direct witness)
    accumulate Zone 5 significance.
    """
    zone_id = "zone_5"
    zone_map = state.significance_map.setdefault(zone_id, {})

    # Every NPC who has a Walker-related observation knows Zone 5 is the source
    for npc_id, ks in state.knowledge_states.items():
        walker_obs = [
            o for o in ks.held_observations
            if "walker" in o.observation_type or "horror_witnessed" in o.observation_type
        ]
        if walker_obs:
            sig = zone_map.setdefault(npc_id, ZoneNPCSignificance())
            for obs in walker_obs:
                sig.apply_event(
                    event_id=obs.source_event_id or f"walker_obs_day{day}",
                    intensity=1,
                    permanent=False,
                )

    # Dix inspection approved: Zone 5 has official documentation
    if state.dix_approved:
        # All NPCs in Zone 2 (Common) at the time of approval accumulate significance
        for npc_id in state.npc_states:
            if state.npc_states[npc_id].is_capable():
                sig = zone_map.setdefault(npc_id, ZoneNPCSignificance())
                if not any(e.startswith("dix_inspection") for e in sig.events):
                    sig.apply_event("dix_inspection_approved", intensity=1, permanent=True)

    # Constance spoke: Zone 5 is now the fraud site
    if state.constance_window_open:
        constance_sig = zone_map.setdefault("constance", ZoneNPCSignificance())
        if not any(e.startswith("constance_survey") for e in constance_sig.events):
            constance_sig.apply_event("constance_survey_knowledge", intensity=2, permanent=True)


# ── Full dawn significance pass ───────────────────────────────────────────────

def run_dawn_pass(
    state: SessionState,
    night_events: list[NightEvent],
    zone_assignments: dict[str, str],
    choice_log: list[ChoiceEntry],
    day: int,
) -> None:
    """
    Full significance update pass. Called at dawn, after night event generation
    and before consequence thread delivery.
    Order matters: zone significance runs first (uses night events),
    then object significance (uses choice log and arc states),
    then Zone 5 (uses gossip knowledge states).
    """
    run_zone_significance_pass(state, night_events, zone_assignments)
    run_object_significance_pass(state, choice_log, day)
    update_zone5_significance(state, day)


# ── Significance summary (for NPC Behavior Agent USER block) ──────────────────

def significance_summary(state: SessionState, npc_id: str) -> dict:
    """
    Returns a compact significance profile for one NPC, for inclusion in the
    NPC Behavior Agent USER block alongside their knowledge state.

    Format:
      {
        "zone_modifiers": {"zone_1": "marked", "zone_3": "carrying", ...},
        "accessible_objects": ["elias_delivery_clipboard"],
      }
    """
    zone_modifiers: dict[str, str] = {}
    for zone_id, npc_map in state.significance_map.items():
        if npc_id in npc_map:
            zone_modifiers[zone_id] = npc_map[npc_id].behavioral_modifier

    accessible_objects: list[str] = []
    for obj_id, npc_map in state.object_significance.items():
        if npc_id in npc_map and npc_map[npc_id].accessible:
            accessible_objects.append(obj_id)

    return {
        "zone_modifiers": zone_modifiers,
        "accessible_objects": accessible_objects,
    }
