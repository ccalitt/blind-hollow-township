#!/usr/bin/env python3
"""
Hollow Township — Playable Chapter 1 (terminal build)
=====================================================
A fully playable, offline terminal version of Chapter 1: "Harrow's Crossing".

This is NOT a separate game — it runs the *real* backend engine
(backend/engine.py and the gossip / significance / consequence passes). The only
thing it stands in for is the LLM Horror Agent: night events are selected by an
authored generator (generate_night_events) that enforces the WORLD_STATE.md
causal grammar — every night event traces to a specific day choice, exactly as
Pillar 1 (Earned Dread) and Pillar 4 (Day/Night) require. A day with no
Debt-feeding choices yields a quiet night and no manufactured consequence thread
(REVEAL_MECHANIC.md).

Play it:
    python tools/play.py

Auto-play a persona (no input needed; used for verification/demo):
    python tools/play.py --auto cover         # the compounding path
    python tools/play.py --auto transparent   # the transparency path
    python tools/play.py --auto random --seed 7

Design sources: PILLARS.md, WORLD_STATE.md, CHAPTER_ONE.md, REVEAL_MECHANIC.md,
TONE.md. Content is authored to those frozen docs; where a doc was silent a
simple pillar-consistent choice was made (noted in comments).
"""

from __future__ import annotations

import argparse
import os
import random
import sys
import textwrap
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.models import SessionState, NPCState, ChoiceEntry, NightEvent
from backend.engine import SessionEngine
from backend.consequence.thread_generator import compute_investment_anchor


# ── Static world reference (from WORLD_STATE.md) ────────────────────────────────

NPC_NAMES: dict[str, str] = {
    "ruth": "Ruth Callan",
    "thomas": "Thomas Vael",
    "maren": "Maren Voss",
    "elias": "Elias Grout",
    "constance": "Constance Harrow",
    "peder": "Peder Lund",
}

# Opening arc states — WORLD_STATE.md §3b (authored, not derived).
OPENING_ARCS: dict[str, str] = {
    "ruth": "present",
    "thomas": "functional",
    "maren": "present",
    "elias": "present",
    "constance": "contributing",
    "peder": "contributing",
}

ZONE_NAMES: dict[str, str] = {
    "zone_1": "the Mill Quarter",
    "zone_2": "the Settlement Common",
    "zone_3": "the Eastern Ridge",
    "zone_4": "the Incomplete Structure",
    "zone_5": "the Western Hollow",
}

# Default night posts (the township's standing roster before the player moves anyone).
DEFAULT_POSTS: dict[str, str] = {
    "ruth": "zone_1",
    "thomas": "zone_2",
    "maren": "zone_1",
    "elias": "zone_3",
    "constance": "zone_2",
    "peder": "zone_4",
}

HOLLOW_ADJACENT = {"zone_4", "zone_5"}


# ── Presentation helpers ────────────────────────────────────────────────────────

class Style:
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RESET = "\033[0m"
    RED = "\033[31m"
    AMBER = "\033[33m"
    PALE = "\033[37m"
    GREY = "\033[90m"


_USE_COLOR = sys.stdout.isatty()


def c(text: str, *codes: str) -> str:
    if not _USE_COLOR:
        return text
    return "".join(codes) + text + Style.RESET


def rule(char: str = "─", width: int = 70) -> None:
    print(c(char * width, Style.GREY))


def wrap(text: str, indent: str = "  ") -> str:
    return "\n".join(
        textwrap.fill(line, width=70, initial_indent=indent, subsequent_indent=indent)
        for line in text.split("\n")
    )


def name(npc_id: str) -> str:
    return NPC_NAMES.get(npc_id, npc_id.replace("_", " ").title())


def zone(zone_id: str) -> str:
    return ZONE_NAMES.get(zone_id, zone_id)


# ── Chapter content (authored to CHAPTER_ONE.md beats) ──────────────────────────
# Each option carries the consequence-engine fields. Moral framing is deliberately
# absent from option text (Pillar 3): tasks read as logistics, never as good/evil.

def chapter_decisions(day: int, state: SessionState, flags: dict) -> list[dict]:
    """Return the list of decisions presented on `day`, given current state/flags."""
    if day == 1:
        return [
            {
                "prompt": "The handover note reads: see to the structure first. "
                          "Where does Peder's crew work today?",
                "options": [
                    {"text": "Finish the incomplete structure's fourth wall",
                     "action_type": "peder_crew_zone4_fourth_wall", "npc_ids": ["peder"],
                     "tier": "micro", "zone": "zone_4", "debt": 0.15},
                    {"text": "Reinforce the Mill Quarter's processing building",
                     "action_type": "peder_crew_mill_reinforce", "npc_ids": ["peder"],
                     "tier": "micro", "zone": "zone_1", "debt": 0.0},
                    {"text": "Send them to survey the western hollow perimeter (Dix's request)",
                     "action_type": "peder_crew_zone5_survey", "npc_ids": ["peder"],
                     "tier": "micro", "zone": "zone_5", "debt": 0.10,
                     "note": "Peder refuses, quietly, with a logistics justification. "
                             "You note it. Dix is grateful."},
                ],
            },
            {
                "prompt": "Elias hands you his treeline report. He has been making it for a month.",
                "options": [
                    {"text": "Log it in the management record",
                     "action_type": "elias_report_logged", "npc_ids": ["elias"],
                     "tier": "micro", "zone": None, "debt": 0.0},
                    {"text": "Set it aside for now",
                     "action_type": "elias_report_ignored", "npc_ids": ["elias"],
                     "tier": "micro", "zone": None, "debt": 0.05},
                ],
            },
            {
                "prompt": "A second watch building can be raised today. Where do you site it?",
                "options": [
                    {"text": "On the Eastern Ridge, facing away from the hollow",
                     "action_type": "place_building", "npc_ids": ["elias"],
                     "tier": "micro", "zone": "zone_3", "debt": 0.0},
                    {"text": "At the hollow edge, beside the Incomplete Structure",
                     "action_type": "place_building", "npc_ids": ["peder"],
                     "tier": "micro", "zone": "zone_4", "debt": 0.15},
                ],
            },
            {
                "prompt": "Maren asks where she should be posted. It is the most visible work she could ask for.",
                "options": [
                    {"text": "Assign her to the Incomplete Structure (what she asked for)",
                     "action_type": "assign_npc", "npc_ids": ["maren"],
                     "tier": "micro", "zone": "zone_4", "debt": 0.0,
                     "note": "Assigning Maren to her visible want suppresses her fear-state."},
                    {"text": "Keep her at the Mill ledger desk",
                     "action_type": "assign_npc", "npc_ids": ["maren"],
                     "tier": "micro", "zone": "zone_1", "debt": 0.05},
                ],
            },
        ]

    if day == 2:
        return [
            {
                "prompt": "The Kettle River Labour Association's representative asks for the stockpile ledger.",
                "options": [
                    {"text": "Provide it unedited",
                     "action_type": "association_ledger_unedited", "npc_ids": ["maren"],
                     "tier": "mid", "zone": None, "debt": -0.10},
                    {"text": "Provide an edited version",
                     "action_type": "association_ledger_edited", "npc_ids": ["maren"],
                     "tier": "mid", "zone": None, "debt": 0.20,
                     "note": "The lie is in the record now. Maren knows it is there."},
                    {"text": "Acknowledge the discrepancy without handing over the document",
                     "action_type": "association_acknowledge", "npc_ids": ["maren"],
                     "tier": "mid", "zone": None, "debt": 0.05},
                ],
            },
            {
                "prompt": "Elias has held the Eastern Ridge alone for nine months. Do you move him?",
                "options": [
                    {"text": "Keep him on the Eastern Ridge",
                     "action_type": "assign_npc", "npc_ids": ["elias"],
                     "tier": "micro", "zone": "zone_3", "debt": 0.0},
                    {"text": "Bring him down to the Common with the others",
                     "action_type": "assign_npc", "npc_ids": ["elias"],
                     "tier": "micro", "zone": "zone_2", "debt": 0.10,
                     "note": "The ridge is the one post that faces away from the hollow."},
                ],
            },
            {
                "prompt": "Ruth and Elias have worked the ridge in tandem since yesterday. Keep them paired?",
                "options": [
                    {"text": "Keep Ruth and Elias working together",
                     "action_type": "bond_acknowledge", "npc_ids": ["elias", "ruth"],
                     "tier": "micro", "zone": "zone_3", "debt": 0.0, "bond": ("elias", "ruth")},
                    {"text": "Rotate them apart",
                     "action_type": "rotate_apart", "npc_ids": ["elias", "ruth"],
                     "tier": "micro", "zone": None, "debt": 0.0},
                ],
            },
        ]

    if day == 3:
        return [
            {
                "prompt": "Field Agent Dix requests a site inspection of the western hollow perimeter.",
                "options": [
                    {"text": "Approve the inspection",
                     "action_type": "dix_inspection_approved", "npc_ids": ["constance"],
                     "tier": "mid", "zone": None, "debt": 0.05, "set": ["dix_approved"]},
                    {"text": "Delay it on safety grounds",
                     "action_type": "dix_inspection_delayed", "npc_ids": ["constance"],
                     "tier": "mid", "zone": None, "debt": 0.05},
                    {"text": "Deny it",
                     "action_type": "dix_inspection_denied", "npc_ids": ["constance"],
                     "tier": "mid", "zone": None, "debt": 0.15,
                     "note": "The Compact is briefly, transparently grateful."},
                ],
            },
            {
                "prompt": "The Compact presents the survey ratification document. Constance is in the room.",
                "options": [
                    {"text": "Sign it",
                     "action_type": "compact_ratification_signed", "npc_ids": ["maren"],
                     "tier": "mid", "zone": None, "debt": 0.20, "set": ["compact_ratified"]},
                    {"text": "Delay it",
                     "action_type": "compact_ratification_delayed", "npc_ids": ["maren"],
                     "tier": "mid", "zone": None, "debt": 0.05},
                    {"text": "Ask about the survey's history",
                     "action_type": "compact_ask_survey_history", "npc_ids": ["constance"],
                     "tier": "mid", "zone": None, "debt": 0.0, "set_flag": ["survey_referenced"],
                     "note": "Constance does not answer. But the question is now in the room."},
                ],
            },
            {
                "prompt": "Thomas has been sideways for days. There is room in tonight's briefing.",
                "options": [
                    {"text": "Give Thomas the evening briefing slot",
                     "action_type": "thomas_briefing_slot", "npc_ids": ["thomas"],
                     "tier": "micro", "zone": "zone_2", "debt": -0.05, "set": ["thomas_spoke"]},
                    {"text": "Keep him on call at the infirmary",
                     "action_type": "assign_npc", "npc_ids": ["thomas"],
                     "tier": "micro", "zone": "zone_2", "debt": 0.05},
                ],
            },
        ]

    if day == 4:
        decisions = [
            {
                "prompt": "The Association has waited two days for your timeline commitment. They stop waiting today.",
                "options": [
                    {"text": "Commit to the structure timeline, publicly",
                     "action_type": "association_commit", "npc_ids": ["ruth"],
                     "tier": "mid", "zone": None, "debt": -0.05},
                    {"text": "Let the commitment slide",
                     "action_type": "association_ignored", "npc_ids": ["ruth"],
                     "tier": "mid", "zone": None, "debt": 0.15,
                     "note": "Three workers will stop attending the evening briefings."},
                ],
            },
            {
                "prompt": "Labor must be allocated. The Compact is owed an answer from yesterday.",
                "options": [
                    {"text": "Keep Peder's crew on the structure",
                     "action_type": "peder_crew_zone4_fourth_wall", "npc_ids": ["peder"],
                     "tier": "mid", "zone": "zone_4", "debt": 0.10},
                    {"text": "Release the crew to Compact-owned work",
                     "action_type": "compact_labor_release", "npc_ids": ["peder"],
                     "tier": "mid", "zone": "zone_4", "debt": 0.10,
                     "note": "The structure stops at three walls."},
                ],
            },
        ]
        # Constance's window opens only if the conditions are met (WORLD_STATE.md §3).
        conditions_met = flags.get("survey_referenced") and (
            state.dix_approved or flags.get("foundation_raised")
        )
        if conditions_met:
            decisions.append({
                "prompt": "Constance Harrow will answer one direct question today. Her window is open.",
                "options": [
                    {"text": "Ask her directly what she knows about the survey",
                     "action_type": "constance_speaks", "npc_ids": ["constance"],
                     "tier": "mid", "zone": None, "debt": -0.10, "set": ["constance_window_open"]},
                    {"text": "Leave it unasked",
                     "action_type": "constance_unasked", "npc_ids": ["constance"],
                     "tier": "micro", "zone": None, "debt": 0.0},
                ],
            })
        return decisions

    if day == 5:
        # The macro fork is shaped by what the player already did (CHAPTER_ONE.md).
        covered = (
            state.compact_ratified
            or any(ch.action_type == "association_ledger_edited" for ch in state_choice_log(state))
            or state.debt >= 0.5
        )
        if covered:
            macro = {
                "prompt": "The county audit can still be answered. The falsified survey is in your hands.",
                "options": [
                    {"text": "Disclose everything — the survey, the ledger, all of it",
                     "action_type": "macro_disclose_all", "npc_ids": ["constance"],
                     "tier": "macro", "zone": None, "debt": -0.20},
                    {"text": "Continue the cover one more season",
                     "action_type": "macro_continue_cover", "npc_ids": ["maren"],
                     "tier": "macro", "zone": None, "debt": 0.30},
                ],
            }
        else:
            macro = {
                "prompt": "You kept the record clean. Now you must decide what to do with what Constance told you.",
                "options": [
                    {"text": "Bring Constance's testimony to the county, on the record",
                     "action_type": "macro_disclose_all", "npc_ids": ["constance"],
                     "tier": "macro", "zone": None, "debt": -0.10},
                    {"text": "Hold the testimony back to protect the township's standing",
                     "action_type": "macro_continue_cover", "npc_ids": ["constance"],
                     "tier": "macro", "zone": None, "debt": 0.20},
                ],
            }
        return [
            {
                "prompt": "A fourth arrival reaches the township at dusk minus three minutes. There is no time to settle them.",
                "options": [
                    {"text": "Deploy them to tonight's most urgent post immediately",
                     "action_type": "arrival_role", "npc_ids": ["arrival_day5"],
                     "tier": "micro", "zone": "zone_3", "debt": 0.05,
                     "note": "No settling time. Their arc takes the damage. The game does not say so."},
                    {"text": "Hold them back, undermanning a post tonight",
                     "action_type": "arrival_held", "npc_ids": ["arrival_day5"],
                     "tier": "micro", "zone": None, "debt": 0.10},
                ],
            },
            macro,
        ]

    return []


# ── Night event generation (authored stand-in for the LLM Horror Agent) ─────────
# Enforces the WORLD_STATE.md causal grammar. Every event carries a cause_chain
# of real choice_ids so the dawn thread can name the chain. Never manufactures
# an event without a cause.

def generate_night_events(state: SessionState, day: int, today: list[ChoiceEntry]) -> list[NightEvent]:
    events: list[NightEvent] = []
    counter = {"n": 0}

    def mk(text: str, threat: list[str], zone_id, cause: list[str], intensity: int, creature: str):
        counter["n"] += 1
        return NightEvent(
            event_id=f"n{day}_e{counter['n']}",
            player_id=state.player_id,
            night=day,
            event_text=text,
            threat_npc_ids=threat,
            cause_chain=cause,
            zone_id=zone_id,
            horror_intensity=intensity,
            chapter=1,
        )

    base_intensity = {1: 1, 2: 1, 3: 2, 4: 2, 5: 3}.get(day, 1)
    if state.debt >= 0.6:
        base_intensity = min(3, base_intensity + 1)

    for ch in today:
        at = ch.action_type
        z = ch.choice_payload.get("zone_id")
        npc = ch.npc_ids[0] if ch.npc_ids else "peder"

        # Hollow Walkers — structure/crew/building reaching toward the hollow.
        if at in ("peder_crew_zone4_fourth_wall", "peder_crew_zone5_survey", "compact_labor_release") \
                or (at == "place_building" and z in HOLLOW_ADJACENT):
            wz = z if z in HOLLOW_ADJACENT else "zone_4"
            events.append(mk(
                f"Something stood at the edge of {zone(wz)} that was not standing there at dusk. "
                f"{name(npc)} logged it and did not go closer.",
                threat=[npc], zone_id=wz, cause=[ch.choice_id],
                intensity=base_intensity, creature="hollow_walker"))

        # Ledger Watchers — covered discrepancy or accepted Compact surplus.
        if at in ("association_ledger_edited", "association_acknowledge",
                  "compact_ratification_signed", "dix_inspection_denied"):
            events.append(mk(
                "A stockpile in the Mill Quarter is short again at dawn. "
                "The count matches no entry Maren wrote.",
                threat=["maren"], zone_id="zone_1", cause=[ch.choice_id],
                intensity=base_intensity, creature="ledger_watcher"))

        # Vacated post — the most capable watcher moved off the ridge.
        if at == "assign_npc" and "elias" in ch.npc_ids and z not in (None, "zone_3"):
            events.append(mk(
                "The Eastern Ridge post was unoccupied at the third watch. "
                "It is not empty. It is simply unwatched.",
                threat=["elias"], zone_id="zone_3", cause=[ch.choice_id],
                intensity=base_intensity, creature="hollow_walker"))

        # Association ignored — post coverage gaps.
        if at == "association_ignored":
            events.append(mk(
                "Two evening posts went uncovered. Ruth stood both of them herself, "
                "and said nothing about it in the morning.",
                threat=["ruth"], zone_id="zone_2", cause=[ch.choice_id],
                intensity=base_intensity, creature="none"))

        # Thomas's silence fractures if it was never given air by Day 3.
        if at == "assign_npc" and "thomas" in ch.npc_ids and day >= 3 and not state.thomas_spoke:
            events.append(mk(
                "Thomas was awake at the infirmary all night with no patient. "
                "He had set out instruments for one.",
                threat=["thomas"], zone_id="zone_2", cause=[ch.choice_id],
                intensity=base_intensity, creature="none"))

    # The Surveyor's Shadow — pre-appearance on Night 4 (witnesses, does not mark).
    if day == 4:
        anchor = _strongest_debt_choice(state)
        events.append(mk(
            "The Surveyor's Shadow walked the Zone 3/5 boundary once, at the third watch, "
            "and withdrew. It did not mark. Everyone on the ridge saw it.",
            threat=["elias"], zone_id="zone_3",
            cause=[anchor.choice_id] if anchor else [],
            intensity=min(3, base_intensity + 1), creature="surveyor"))

    # Night 5 — the Surveyor marks or departs by accumulated DEBT.
    if day == 5:
        anchor = _strongest_debt_choice(state)
        if state.debt >= 0.5:
            state.zone5_marked = True
            events.append(mk(
                "The Surveyor's Shadow stopped at the Zone 5 boundary and marked it. "
                "The hollow is open now. The accounting is complete.",
                threat=["constance"], zone_id="zone_5",
                cause=[anchor.choice_id] if anchor else [],
                intensity=3, creature="surveyor"))
        else:
            events.append(mk(
                "The Surveyor's Shadow completed its walk and departed before dawn. "
                "The Zone 5 boundary held. It is not relief. It is a held breath.",
                threat=["constance"], zone_id="zone_5",
                cause=[anchor.choice_id] if anchor else [],
                intensity=2, creature="surveyor"))

    # Night 1 surfaces only ONE consequence (CHAPTER_ONE.md).
    if day == 1 and len(events) > 1:
        events.sort(key=lambda e: e.horror_intensity, reverse=True)
        events = events[:1]

    return events


def _strongest_debt_choice(state: SessionState):
    log = state_choice_log(state)
    debt_choices = [ch for ch in log if ch.debt_delta > 0 and ch.npc_ids]
    if not debt_choices:
        debt_choices = [ch for ch in log if ch.npc_ids]
    if not debt_choices:
        return None
    return max(debt_choices, key=lambda ch: ch.debt_delta)


# Stash the full log on the state object so helpers can reach it.
def state_choice_log(state: SessionState) -> list[ChoiceEntry]:
    return getattr(state, "_full_log", [])


# ── Dawn rendering (Reveal Mechanic, Option B) ──────────────────────────────────

DAY_CHOICE_RENDER: dict[str, str] = {
    "peder_crew_zone4_fourth_wall": "Day {day}: Peder's crew was set to the structure's fourth wall.",
    "peder_crew_mill_reinforce":    "Day {day}: Peder's crew reinforced the Mill Quarter.",
    "peder_crew_zone5_survey":      "Day {day}: Peder's crew was sent to the hollow perimeter.",
    "compact_labor_release":        "Day {day}: Peder's crew was released to Compact work.",
    "place_building":               "Day {day}: a watch building was raised at {zone}.",
    "assign_npc":                   "Day {day}: {npc} was assigned to {zone}.",
    "elias_report_logged":          "Day {day}: Elias Grout's treeline report was logged.",
    "elias_report_ignored":         "Day {day}: Elias Grout's treeline report was set aside.",
    "association_ledger_edited":    "Day {day}: the ledger was provided in edited form.",
    "association_ledger_unedited":  "Day {day}: the ledger was provided unedited.",
    "association_acknowledge":      "Day {day}: the discrepancy was acknowledged, no document given.",
    "association_ignored":          "Day {day}: the timeline commitment was left to slide.",
    "association_commit":           "Day {day}: the structure timeline was committed to publicly.",
    "compact_ratification_signed":  "Day {day}: the survey ratification was signed.",
    "compact_ratification_delayed": "Day {day}: the survey ratification was delayed.",
    "compact_ask_survey_history":   "Day {day}: the survey's history was raised in front of Constance.",
    "dix_inspection_approved":      "Day {day}: the hollow inspection was approved.",
    "dix_inspection_delayed":       "Day {day}: the hollow inspection was delayed.",
    "dix_inspection_denied":        "Day {day}: the hollow inspection was denied.",
    "bond_acknowledge":             "Day {day}: {npc} was kept paired with their partner.",
    "rotate_apart":                 "Day {day}: {npc}'s pairing was rotated apart.",
    "constance_unasked":            "Day {day}: Constance Harrow was left unasked.",
    "arrival_held":                 "Day {day}: the dusk arrival was held back from the line.",
    "thomas_briefing_slot":         "Day {day}: Thomas Vael was given room to speak at the briefing.",
    "constance_speaks":             "Day {day}: Constance Harrow was asked directly, and answered.",
    "macro_disclose_all":           "Day {day}: the falsification was disclosed.",
    "macro_continue_cover":         "Day {day}: the cover was carried one more season.",
    "arrival_role":                 "Day {day}: the dusk arrival was deployed without settling.",
}


def render_sentence1(choice: ChoiceEntry) -> str:
    template = DAY_CHOICE_RENDER.get(choice.action_type, "Day {day}: {npc} — {action}.")
    npc = name(choice.npc_ids[0]) if choice.npc_ids else "someone"
    z = zone(choice.choice_payload.get("zone_id", "")) if choice.choice_payload.get("zone_id") else "their post"
    return template.format(day=choice.day_cycle, npc=npc, zone=z, action=choice.action_type)


# ── The game loop ───────────────────────────────────────────────────────────────

def make_initial_state(player_id: str) -> SessionState:
    state = SessionState(player_id=player_id)
    for npc_id, arc in OPENING_ARCS.items():
        n = NPCState(npc_id=npc_id, domain="")
        n.arc_state = arc
        state.npc_states[npc_id] = n
    state._full_log = []          # full chapter choice log (used by helpers + dawn)
    return state


def _slow(text: str, auto: bool) -> None:
    print(text)
    if not auto and _USE_COLOR:
        time.sleep(0.02)


def pick_option(decision: dict, auto_mode, rng, auto_index) -> int:
    options = decision["options"]
    if auto_mode is None:
        # Interactive
        while True:
            raw = input(c("  > ", Style.BOLD)).strip()
            if raw.lower() in ("q", "quit", "exit"):
                print("\n  You step back from the ledger. The township waits.\n")
                sys.exit(0)
            if raw.isdigit() and 1 <= int(raw) <= len(options):
                return int(raw) - 1
            print(c("    (enter a number, or 'q' to quit)", Style.DIM))
    # Auto personas
    if auto_mode == "random":
        return rng.randrange(len(options))
    # "cover" picks the highest-debt option; "transparent" the lowest.
    debts = [o.get("debt", 0.0) for o in options]
    if auto_mode == "cover":
        return debts.index(max(debts))
    if auto_mode == "transparent":
        return debts.index(min(debts))
    return 0


def apply_choice(state: SessionState, flags: dict, posts: dict, day: int,
                 decision: dict, opt: dict, idx: int) -> ChoiceEntry:
    cid = f"d{day}_{decision['prompt'][:8].strip().replace(' ', '_')}_{idx}"
    payload = {}
    if opt.get("zone"):
        payload["zone_id"] = opt["zone"]
    choice = ChoiceEntry(
        choice_id=cid,
        player_id=state.player_id,
        day_cycle=day,
        phase="day",
        moral_tier=opt["tier"],
        action_type=opt["action_type"],
        npc_ids=list(opt["npc_ids"]),
        choice_payload=payload,
        debt_delta=opt.get("debt", 0.0),
    )
    # Apply side effects.
    for attr in opt.get("set", []):
        setattr(state, attr, True)
    for f in opt.get("set_flag", []):
        flags[f] = True
    if opt.get("bond"):
        a, b = opt["bond"]
        if a in state.npc_states:
            state.npc_states[a].bond_partner = b
            state.npc_states[a].bond_depth += 1
    if opt.get("zone") and opt["action_type"] in ("assign_npc", "thomas_briefing_slot"):
        for nid in opt["npc_ids"]:
            if nid in posts:
                posts[nid] = opt["zone"]
    return choice


def play_day(state: SessionState, engine: SessionEngine, day: int, flags: dict,
             posts: dict, auto_mode, rng) -> None:
    auto = auto_mode is not None
    print()
    rule("━")
    titles = {
        1: "DAY 1 — False Control",
        2: "DAY 2 — Awareness Arrives",
        3: "DAY 3 — The Grammar Reveals Itself",
        4: "DAY 4 — The Trap Shows Its Grammar",
        5: "DAY 5 — The Reckoning Day",
    }
    print(c(f"  {titles.get(day, f'DAY {day}')}", Style.BOLD))
    print(c(f"  Harrow's Crossing · DEBT {state.debt:+.2f}", Style.DIM))
    rule("━")

    today: list[ChoiceEntry] = []
    decisions = chapter_decisions(day, state, flags)
    for decision in decisions:
        print()
        print(wrap(decision["prompt"]))
        for i, opt in enumerate(decision["options"], 1):
            print(c(f"    {i}. ", Style.BOLD) + opt["text"])
        idx = pick_option(decision, auto_mode, rng, None)
        opt = decision["options"][idx]
        if auto:
            print(c(f"  > {idx + 1}", Style.DIM) + c(f"  ({opt['text']})", Style.GREY))
        choice = apply_choice(state, flags, posts, day, decision, opt, idx)
        today.append(choice)
        state._full_log.append(choice)
        if opt.get("note"):
            print(c(wrap(opt["note"], indent="     "), Style.AMBER))

    # Day 4: foundation excavates automatically if never engaged.
    if day == 4 and not flags.get("foundation_raised"):
        state.peder_foundation_excavated = True

    # Apply the day's DEBT.
    state.debt = max(0.0, min(1.0, state.debt + sum(ch.debt_delta for ch in today)))

    # ── NIGHT ──────────────────────────────────────────────────────────────────
    day_result = engine.end_day(
        day=day,
        choice_log=today,
        night_precompute_fn=lambda s, log, know: generate_night_events(s, day, log),
        zone_assignments=dict(posts),
    )
    print()
    rule()
    print(c(f"  NIGHT {day}", Style.RED if state.debt >= 0.5 else Style.PALE))
    rule()
    if day_result.gossip_transfers_fired:
        print(c(wrap(f"({day_result.gossip_transfers_fired} thing(s) moved between people in the dark, "
                     f"before you could decide who should know.)", indent="  "), Style.DIM))
    if not day_result.night_events:
        print(wrap("The night was quiet. You do not know whether that is safety."))
    else:
        for ev in day_result.night_events:
            print(c(wrap(ev.event_text), Style.PALE))
            print()

    # ── DAWN ─────────────────────────────────────────────────────────────────-─
    dawn = engine.begin_dawn(
        day=day,
        choice_log=state._full_log,
        night_events=day_result.night_events,
        zone_assignments=dict(posts),
    )
    print()
    rule()
    print(c(f"  DAWN — after Night {day}", Style.AMBER))
    rule()
    if not dawn.thread_entries:
        print(wrap("Nothing in the morning names itself. The work resumes."))
    else:
        for entry in dawn.thread_entries:
            print(c("  " + render_sentence1(entry.day_choice), Style.DIM))
            print(c("  " + entry.night_event.event_text, Style.PALE))
            print()
    if dawn.errors:
        print(c(wrap("[engine] " + "; ".join(dawn.errors)), Style.RED))

    if not auto:
        input(c("\n  (press enter to continue)", Style.DIM))


def chapter_end(state: SessionState) -> None:
    print()
    rule("━")
    print(c("  CHAPTER 1 — END", Style.BOLD))
    rule("━")
    anchor = compute_investment_anchor(state._full_log)
    broken = [nid for nid, n in state.npc_states.items() if n.arc_state == "broken"]
    print()
    print(wrap(f"Final DEBT: {state.debt:.2f}"))
    print(wrap(f"The Western Hollow boundary was {'MARKED — open for Chapter 2.' if state.zone5_marked else 'held, for now.'}"))
    if anchor:
        print(wrap(f"The person your choices most often turned toward: {name(anchor)}."))
        print(c(wrap("(They become Chapter 2's false-dawn anchor. You are not told this in-game.)",
                     indent="  "), Style.DIM))
    print()
    if state.debt >= 0.5:
        print(wrap("You cannot immediately articulate all the choices that got you here. "
                   "That is the point. You will need Chapter 2 to find out if you can fix this."))
    else:
        print(wrap("You kept the worst of it at bay. It cost you something you have not "
                   "finished counting. The hollow is quiet. It is not done."))
    print()
    rule("━")


def main() -> None:
    parser = argparse.ArgumentParser(description="Hollow Township — Playable Chapter 1")
    parser.add_argument("--auto", choices=["cover", "transparent", "random"],
                        help="auto-play a persona instead of prompting for input")
    parser.add_argument("--seed", type=int, default=1, help="RNG seed for --auto random")
    parser.add_argument("--name", default=None, help="your anchor name (optional)")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    state = make_initial_state(player_id=f"play_{args.auto or 'human'}_{args.seed}")
    engine = SessionEngine(state)
    flags: dict = {}
    posts = dict(DEFAULT_POSTS)

    # Title / opening scene (WORLD_STATE.md §6).
    print()
    rule("━")
    print(c("  HOLLOW TOWNSHIP", Style.BOLD) + c("   ·   Chapter 1: Harrow's Crossing", Style.DIM))
    rule("━")
    print()
    print(wrap(
        "The mill is running; you hear it before you see it. The handover ledger is on "
        "the table in the manager's post — fourteen names, resource counts that do not "
        "match the stockpiles, and one line of note: see to the structure first. Across "
        "thirty yards of cleared ground, the incomplete building catches the morning light. "
        "Three of its walls are standing.\n\n"
        "No one who has arrived in Harrow's Crossing has left by the road they came in on. "
        "You do not know that yet."))
    print()
    print(c(wrap("Every choice below reads as logistics. Some of them are not. "
                 "You will find out which at night.", indent="  "), Style.DIM))
    if args.auto:
        print(c(wrap(f"[auto-play: '{args.auto}' persona, seed {args.seed}]", indent="  "), Style.GREY))
    else:
        print(c(wrap("Type the number of your choice. 'q' quits.", indent="  "), Style.GREY))

    for day in range(1, 6):
        play_day(state, engine, day, flags, posts, args.auto, rng)

    chapter_end(state)


if __name__ == "__main__":
    main()
