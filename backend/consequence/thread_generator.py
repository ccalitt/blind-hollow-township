"""
Hollow Township — Dawn Consequence Thread Generator
====================================================
Generates the two-sentence dawn consequence thread for each NPC whose
night consequence is traceable to a specific day choice.

Design spec: REVEAL_MECHANIC.md — Chapter 1 Reveal Model.

This module is the pre-LLM pass that:
  1. Pairs day choices with night events via cause_chain matching.
  2. Validates each pair passes the Reveal Test (specific NPC, specific choice,
     consequence without evaluation).
  3. Prepares a structured payload for the Story Progression Agent to render
     into final 2-sentence text.

The Story Progression Agent then takes each payload and generates:
  Sentence 1: the day choice (named NPC, named action, named zone/assignment)
  Sentence 2: the night consequence (named NPC, named outcome, no elaboration)

No "because". No causal connective tissue. The sentences sit next to each other.

The generator also handles gossip-chain attribution: if a night event was
triggered by a gossip-mediated belief shift, the cause_chain traces back to
the original player choice that created the gossip condition — not the gossip
act itself. The gossip act is never named in the dawn thread.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional

from backend.models import ChoiceEntry, NightEvent, SessionState


# ── Thread entry ──────────────────────────────────────────────────────────────

@dataclass
class ThreadEntry:
    npc_id: str
    day_choice: ChoiceEntry
    night_event: NightEvent
    sentence1_prompt: str    # structured prompt fragment for Story Progression Agent
    sentence2_prompt: str    # structured prompt fragment for Story Progression Agent
    gossip_mediated: bool = False   # true if cause chain passed through gossip
    tone_validated: bool = False    # set to True by Master Enforcer after generation


# ── Cause chain matching ──────────────────────────────────────────────────────

def match_cause_chains(
    choice_log: list[ChoiceEntry],
    night_events: list[NightEvent],
) -> list[tuple[ChoiceEntry, NightEvent]]:
    """
    Match day choices to night events via cause_chain.
    A night event's cause_chain contains choice_ids; we find those choices.
    Returns list of (choice, event) pairs, deduplicated by event.
    """
    choice_by_id = {c.choice_id: c for c in choice_log}
    matched: list[tuple[ChoiceEntry, NightEvent]] = []
    seen_events: set[str] = set()

    for event in night_events:
        if event.event_id in seen_events:
            continue
        for choice_id in event.cause_chain:
            if choice_id in choice_by_id:
                matched.append((choice_by_id[choice_id], event))
                seen_events.add(event.event_id)
                break  # one cause per event is enough for the thread

    return matched


# ── Gossip chain attribution ──────────────────────────────────────────────────

def resolve_gossip_attribution(
    event: NightEvent,
    choice_log: list[ChoiceEntry],
    state: SessionState,
) -> Optional[ChoiceEntry]:
    """
    If a night event was triggered by gossip-mediated belief (no direct choice
    in cause_chain), trace back to the original player choice that created the
    gossip condition.

    For example: Maren leaked to the Compact because the player assigned her
    outside her visible want. The relevant choice is "maren_assigned_elsewhere"
    on Day 1, not the gossip transfer itself.

    Returns the originating choice, or None if no attribution can be made.
    """
    gossip_transfers = state.gossip_transfers
    for transfer in gossip_transfers:
        # Find a gossip transfer that involved an NPC in this event's cause chain
        if transfer.to_npc in event.threat_npc_ids or transfer.from_npc in event.threat_npc_ids:
            # Trace back: find the original choice that loaded the observation
            # for the transmitting NPC
            for choice in choice_log:
                if transfer.from_npc in choice.npc_ids and choice.day_cycle < event.night:
                    return choice
    return None


# ── Reveal test validation ────────────────────────────────────────────────────

def passes_reveal_test(choice: ChoiceEntry, event: NightEvent) -> bool:
    """
    Validates the choice/event pair passes all three Reveal Test gates
    from REVEAL_MECHANIC.md:
      1. Names a specific NPC and a specific day choice.
      2. States consequence without evaluating it.
      3. Would not make sense to a player who made different choices
         (i.e., the link is causal, not atmospheric).

    Gate 3 is approximated by requiring the choice's npc_ids to overlap
    with the event's threat_npc_ids or the event's cause_chain to reference
    the specific choice_id.
    """
    # Gate 1: must have a named NPC
    if not choice.npc_ids or not event.threat_npc_ids:
        return False
    # Gate 3: causal link must exist
    npc_overlap = set(choice.npc_ids) & set(event.threat_npc_ids)
    chain_match = choice.choice_id in event.cause_chain
    return bool(npc_overlap or chain_match)


# ── Sentence prompt construction ──────────────────────────────────────────────

# Maps action_type to a plain-language day-choice description fragment.
# The Story Progression Agent uses this as the grounding for Sentence 1.
ACTION_TYPE_DESCRIPTIONS: dict[str, str] = {
    "assign_npc":                   "{npc} was assigned to {zone} on Day {day}.",
    "elias_report_logged":          "Elias's report was logged on Day {day}.",
    "elias_report_ignored":         "Elias's report was not logged on Day {day}.",
    "association_ledger_edited":    "The ledger was provided in edited form on Day {day}.",
    "association_ledger_unedited":  "The ledger was provided unedited on Day {day}.",
    "compact_ratification_signed":  "The Compact ratification document was signed on Day {day}.",
    "compact_ratification_delayed": "The Compact ratification was delayed on Day {day}.",
    "dix_inspection_approved":      "The site inspection was approved on Day {day}.",
    "dix_inspection_delayed":       "The site inspection was delayed on Day {day}.",
    "peder_crew_zone5_survey":      "Peder's crew was sent to the hollow perimeter on Day {day}.",
    "peder_crew_zone4_fourth_wall": "Peder's crew was assigned to complete the fourth wall on Day {day}.",
    "arrival_role":                 "{npc} was assigned a role on Day {day}.",
    "bond_acknowledge":             "{npc} and their partner were kept working together through Day {day}.",
    "compact_ask_survey_history":   "The survey's history was raised at the Compact meeting on Day {day}.",
    "macro_disclose_all":           "The discrepancies were disclosed on Day {day}.",
    "macro_continue_cover":         "The discrepancies were not disclosed on Day {day}.",
}

def build_sentence1_prompt(choice: ChoiceEntry) -> str:
    template = ACTION_TYPE_DESCRIPTIONS.get(
        choice.action_type,
        "{npc} — {action} — Day {day}."
    )
    npc = choice.npc_ids[0] if choice.npc_ids else "unknown"
    zone = choice.choice_payload.get("zone_id", "their post")
    return template.format(
        npc=npc,
        zone=zone,
        day=choice.day_cycle,
        action=choice.action_type,
    )

def build_sentence2_prompt(event: NightEvent) -> str:
    # Sentence 2 is grounded in the event's own text plus the threat NPC.
    npc = event.threat_npc_ids[0] if event.threat_npc_ids else "unknown"
    return (
        f"Night {event.night}: {npc}. "
        f"Consequence: {event.event_text[:120]}. "
        f"No elaboration. No evaluation. Declarative only."
    )


# ── Main generator ────────────────────────────────────────────────────────────

def generate_thread(
    state: SessionState,
    choice_log: list[ChoiceEntry],
    night_events: list[NightEvent],
    night: int,
) -> list[ThreadEntry]:
    """
    Generate the dawn consequence thread for one night.

    Returns a list of ThreadEntry objects ready for Story Progression Agent
    rendering. Empty list = quiet night (no entries manufactured).

    The caller passes these to the Story Progression Agent which generates
    the final two sentences per entry within the frozen tone profile.
    """
    if not night_events:
        return []   # quiet night — no thread manufactured

    matched_pairs = match_cause_chains(choice_log, night_events)
    entries: list[ThreadEntry] = []

    for choice, event in matched_pairs:
        if not passes_reveal_test(choice, event):
            continue

        # Check if this is gossip-mediated
        gossip_mediated = False
        if not (set(choice.npc_ids) & set(event.threat_npc_ids)):
            attribution = resolve_gossip_attribution(event, choice_log, state)
            if attribution:
                choice = attribution
                gossip_mediated = True
            else:
                continue  # cannot build a valid thread entry

        entry = ThreadEntry(
            npc_id=event.threat_npc_ids[0] if event.threat_npc_ids else choice.npc_ids[0],
            day_choice=choice,
            night_event=event,
            sentence1_prompt=build_sentence1_prompt(choice),
            sentence2_prompt=build_sentence2_prompt(event),
            gossip_mediated=gossip_mediated,
        )
        entries.append(entry)

    return entries


# ── Investment anchor computation ─────────────────────────────────────────────

TIER_WEIGHTS = {"macro": 3, "mid": 2, "micro": 1}

def compute_investment_anchor(choice_log: list[ChoiceEntry]) -> Optional[str]:
    """
    Identifies the NPC with the highest total choice-weight across the full
    chapter log. This is the False Dawn anchor — the NPC the player implicitly
    protected most, computable from their decisions.

    Faction tokens ("compact", "association", "dix") are excluded — the anchor
    must resolve to a named person, not a faction.
    """
    FACTION_TOKENS = {"compact", "association", "dix", "association_rep"}
    weights: dict[str, float] = {}

    for entry in choice_log:
        w = TIER_WEIGHTS.get(entry.moral_tier, 1)
        for npc_id in entry.npc_ids:
            if npc_id not in FACTION_TOKENS:
                weights[npc_id] = weights.get(npc_id, 0.0) + w

    if not weights:
        return None
    return max(weights, key=weights.get)
