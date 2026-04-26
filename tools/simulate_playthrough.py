#!/usr/bin/env python3
"""
Hollow Township — Playthrough Simulator
========================================
Simulates a 5-day Chapter 1 playthrough for a given player persona.
Tracks: DEBT accumulation, NPC arc states, creature appearances,
        moral choice weight, engagement signals, chapter-end state.

Usage:
    python simulate_playthrough.py                    # run all built-in personas
    python simulate_playthrough.py --persona cautious # run one persona
    python simulate_playthrough.py --persona custom --profile '{"risk":0.2,"transparency":0.9}'

Persona profiles define decision tendencies (0.0–1.0):
    transparency:  likelihood of disclosing discrepancies / refusing Compact
    risk:          likelihood of assigning NPCs to dangerous posts
    efficiency:    likelihood of using Path C (rush) for arrivals
    curiosity:     likelihood of asking questions, exploring faction options
    care:          likelihood of initiating first conversations, housing near compatible NPCs
"""

import random
import json
import sys
import argparse
from dataclasses import dataclass, field
from typing import Optional

# ── Constants ──────────────────────────────────────────────────────────────

SEASON_THRESHOLDS = {
    "turning":     {"day": 4, "debt": 0.4},
    "deep_winter": {"day": 5, "debt": 0.70},
}

DEBT_DELTAS = {
    "cover_discrepancy":       +0.15,
    "compact_surplus_accept":  +0.20,
    "zone5_adjacency_build":   +0.10,
    "disclose_discrepancy":    -0.10,
    "dix_inspection_approved": -0.05,
    "compact_ratify":          +0.12,
    "ask_survey_history":      -0.05,
}

SKILL_DEPTH_WEIGHTS = {
    "late_summer":  [0.70, 0.28, 0.02],
    "turning":      [0.60, 0.35, 0.05],
    "deep_winter":  [0.45, 0.40, 0.15],
    "thaw":         [0.55, 0.40, 0.05],
}

DEPTH_OUTPUT_MODIFIER = {
    "surface":   1.0,
    "practiced": 1.30,
    "deep":      1.60,
}

SETTLING_PATH_MODIFIER = {
    "integration":  {"start": 0.50, "peak": 1.00, "days": 2},
    "accelerated":  {"start": 0.60, "peak": 0.80, "days": 1},
    "rushed":       {"start": 1.00, "peak": 1.00, "days": 0},
}

ARC_STATES = ["settling", "present", "contributing", "functional", "fragile", "broken"]

DOMAINS = ["construction", "medicine", "logistics", "observation", "social"]

NIGHT_CREATURE_THRESHOLDS = {
    1: {"walker": 0.3,  "watcher": 0.0,  "surveyor": False},
    2: {"walker": 0.3,  "watcher": 0.25, "surveyor": False},
    3: {"walker": 0.35, "watcher": 0.30, "surveyor": False},
    4: {"walker": 0.40, "watcher": 0.35, "surveyor": True, "surveyor_marks": False},
    5: {"walker": 0.50, "watcher": 0.45, "surveyor": True, "surveyor_marks": True},
}

# Gossip disposition per NPC:
#   base_threshold: roll must be < this × trust_weight for transfer to fire
#   credibility_weight: multiplier on how strongly received info shifts state
#   trigger: condition that must be true for transmission to be attempted
NPC_GOSSIP_DISPOSITIONS = {
    "ruth":      {"base_threshold": 0.25, "credibility_weight": 1.4, "trigger": "safety_concern"},
    "thomas":    {"base_threshold": 0.70, "credibility_weight": 0.85,"trigger": "fear_state"},
    "maren":     {"base_threshold": 0.00, "credibility_weight": 1.0, "trigger": "fear_activated"},
    "elias":     {"base_threshold": 0.05, "credibility_weight": 1.2, "trigger": "bond_only"},
    "constance": {"base_threshold": 0.00, "credibility_weight": 0.0, "trigger": "receiver_only"},
    "peder":     {"base_threshold": 0.15, "credibility_weight": 1.1, "trigger": "environmental_only"},
}

# ── Data structures ─────────────────────────────────────────────────────────

@dataclass
class NPCState:
    name: str
    domain: str
    arc_state: str = "present"
    injured: bool = False
    gone: bool = False
    bond_partner: Optional[str] = None
    bond_depth: int = 0

    def is_capable(self):
        return not self.gone and self.arc_state != "broken"

@dataclass
class Arrival:
    arrival_id: str
    day: int
    domain: str
    depth: str
    archetype: str
    settling_path: str = "integration"
    arc_state: str = "settling"
    output_modifier: float = 0.50
    bond_partner: Optional[str] = None
    bond_depth: int = 0

@dataclass
class ChoiceLogEntry:
    day: int
    phase: str
    tier: str
    action: str
    npc_ids: list
    debt_delta: float = 0.0

@dataclass
class GossipState:
    """Per-NPC knowledge state for gossip propagation."""
    held_observations: list = field(default_factory=list)  # what the NPC currently holds
    received_from: dict = field(default_factory=dict)       # {npc_id: [observation, ...]}
    stage: int = 1                                          # 1=nothing, 2=holding, 3=transmitted
    fear_active: bool = False                               # triggers maren-type fear-activation

@dataclass
class GameState:
    day: int = 1
    debt: float = 0.0
    season: str = "late_summer"
    npcs: dict = field(default_factory=dict)
    arrivals: list = field(default_factory=list)
    choice_log: list = field(default_factory=list)
    watchers_active: int = 0
    walkers_stopped_zones: list = field(default_factory=list)
    zone5_adjacency_built: bool = False
    compact_ratified: bool = False
    dix_approved: bool = False
    discrepancy_disclosed: bool = False
    thomas_spoke: bool = False
    constance_spoke: bool = False
    peder_foundation_surfaced: bool = False
    surveyor_seen_night4: bool = False
    zone5_marked: bool = False
    investment_anchor: Optional[str] = None

    # gossip network
    gossip_states: dict = field(default_factory=dict)  # {npc_id: GossipState}
    gossip_transfers: list = field(default_factory=list)  # log of transfers that fired

    # engagement tracking
    dread_events: list = field(default_factory=list)
    compulsion_spikes: list = field(default_factory=list)
    moral_weight_felt: list = field(default_factory=list)
    npc_losses: list = field(default_factory=list)

    def capable_npc_count(self):
        return sum(1 for n in self.npcs.values() if n.is_capable())

    def clamp_debt(self):
        self.debt = max(0.0, min(1.0, self.debt))

    def apply_debt(self, key: str):
        delta = DEBT_DELTAS.get(key, 0.0)
        self.debt += delta
        self.clamp_debt()
        return delta

    def evaluate_season(self):
        tw = SEASON_THRESHOLDS["turning"]
        dw = SEASON_THRESHOLDS["deep_winter"]
        if self.day >= dw["day"] and self.debt >= dw["debt"]:
            self.season = "deep_winter"
        elif self.day >= tw["day"] and self.debt >= tw["debt"]:
            self.season = "turning"

    def log(self, day, phase, tier, action, npc_ids, debt_delta=0.0):
        self.choice_log.append(ChoiceLogEntry(day, phase, tier, action, npc_ids, debt_delta))

    def investment_weights(self):
        weights = {}
        tier_w = {"macro": 3, "mid": 2, "micro": 1}
        for entry in self.choice_log:
            w = tier_w.get(entry.tier, 1)
            for npc in entry.npc_ids:
                weights[npc] = weights.get(npc, 0) + w
        return weights


# ── Persona definitions ─────────────────────────────────────────────────────

PERSONAS = {
    "cautious_builder": {
        "label": "The Cautious Builder",
        "description": "Prioritises safety and transparency. Avoids risk. Always reads the ledger. Keeps NPCs housed well.",
        "transparency": 0.85,
        "risk": 0.20,
        "efficiency": 0.15,
        "curiosity": 0.65,
        "care": 0.80,
    },
    "efficient_manager": {
        "label": "The Efficient Manager",
        "description": "Optimises for output. Uses Path C. Covers discrepancies if it's faster. Treats arrivals as resources.",
        "transparency": 0.25,
        "risk": 0.60,
        "efficiency": 0.85,
        "curiosity": 0.30,
        "care": 0.20,
    },
    "narrative_explorer": {
        "label": "The Narrative Explorer",
        "description": "Clicks everything. Asks questions. Reads all dialogue. Slow, curious, not optimising for survival.",
        "transparency": 0.70,
        "risk": 0.40,
        "efficiency": 0.30,
        "curiosity": 0.95,
        "care": 0.70,
    },
    "horror_veteran": {
        "label": "The Horror Veteran",
        "description": "Knows horror games. Makes tactical choices. Accepts some moral cost for mechanical advantage. Methodical.",
        "transparency": 0.50,
        "risk": 0.55,
        "efficiency": 0.60,
        "curiosity": 0.55,
        "care": 0.45,
    },
    "accidental_villain": {
        "label": "The Accidental Villain",
        "description": "Makes reasonable-seeming decisions that compound badly. Accepts the Compact. Covers discrepancies once. Deploys arrivals immediately.",
        "transparency": 0.35,
        "risk": 0.45,
        "efficiency": 0.70,
        "curiosity": 0.40,
        "care": 0.30,
    },
}


# ── Decision simulation engine ──────────────────────────────────────────────

def decide(p: dict, key: str, threshold: float = 0.5) -> bool:
    """Returns True if the persona makes the 'active' choice on this decision axis."""
    return (p[key] + random.uniform(-0.15, 0.15)) > threshold

def pick_weighted(items, weights):
    total = sum(weights)
    r = random.uniform(0, total)
    cumulative = 0
    for item, w in zip(items, weights):
        cumulative += w
        if r <= cumulative:
            return item
    return items[-1]

def pick_depth(season: str) -> str:
    weights = SKILL_DEPTH_WEIGHTS[season]
    return pick_weighted(["surface", "practiced", "deep"], weights)

def pick_domain(neglected: Optional[str] = None) -> str:
    if neglected:
        return neglected
    return random.choice(DOMAINS)

def find_neglected_domain(state: GameState) -> str:
    covered = set(a.domain for a in state.arrivals)
    covered.update(n.domain for n in state.npcs.values())
    missing = [d for d in DOMAINS if d not in covered]
    return random.choice(missing) if missing else random.choice(DOMAINS)

def find_urgent_domain(state: GameState) -> str:
    """Domain that most directly closes a night survival gap."""
    if state.watchers_active > 0 and "logistics" not in [a.domain for a in state.arrivals]:
        return "logistics"
    if state.zone5_adjacency_built and "observation" not in [a.domain for a in state.arrivals]:
        return "observation"
    return pick_domain()

# ── Gossip propagation engine ───────────────────────────────────────────────

def _gossip_trust_weight(from_id: str, to_id: str, state: GameState) -> float:
    """Trust weight between two NPCs: boosted by bond depth and shared zone history."""
    base = 0.4
    # Bond adds trust
    from_npc = state.npcs.get(from_id)
    if from_npc and from_npc.bond_partner == to_id:
        base += 0.2 + (from_npc.bond_depth * 0.1)
    # Check arrivals
    for a in state.arrivals:
        if a.arrival_id == from_id and a.bond_partner == to_id:
            base += 0.2 + (a.bond_depth * 0.1)
    return min(1.0, base)

def _gossip_threshold(npc_id: str, state: GameState) -> float:
    """Effective transmission threshold for this NPC, adjusted for fear state."""
    disp = NPC_GOSSIP_DISPOSITIONS.get(npc_id, {"base_threshold": 0.3, "trigger": "any"})
    gs = state.gossip_states.get(npc_id, GossipState())
    threshold = disp["base_threshold"]
    if disp.get("trigger") == "fear_activated" and gs.fear_active:
        threshold = 0.65
    return threshold

def _get_transmission_candidates(from_id: str, state: GameState) -> list:
    """Which NPCs could receive a transmission from this NPC today."""
    disp = NPC_GOSSIP_DISPOSITIONS.get(from_id, {})
    trigger = disp.get("trigger", "any")
    all_ids = list(state.npcs.keys()) + [a.arrival_id for a in state.arrivals]
    candidates = [nid for nid in all_ids if nid != from_id]

    if trigger == "receiver_only":
        return []  # constance never transmits
    if trigger == "bond_only":
        # elias only transmits to bonded partner
        npc = state.npcs.get(from_id)
        if npc and npc.bond_partner:
            return [npc.bond_partner]
        return []
    if trigger == "environmental_only":
        # peder transmits to NPCs in same zone (approximated as Zone 4 workers)
        return [nid for nid in candidates
                if any(e.action.startswith("arrival_role_construction") for e in state.choice_log
                       if from_id in e.npc_ids or nid in e.npc_ids)]
    return candidates

def run_gossip_pass(state: GameState, day: int, seed: Optional[int] = None) -> None:
    """
    Run gossip propagation between day phase end and night pre-computation.
    Updates npc_knowledge_states and logs transfers to state.gossip_transfers.
    Uses seeded randomness so the same relationship conditions → same outcomes per run.
    """
    for npc_id, gs in list(state.gossip_states.items()):
        if gs.stage < 2 or not gs.held_observations:
            continue
        disp = NPC_GOSSIP_DISPOSITIONS.get(npc_id, {})
        if disp.get("trigger") == "receiver_only":
            continue

        candidates = _get_transmission_candidates(npc_id, state)
        threshold = _gossip_threshold(npc_id, state)
        cred = disp.get("credibility_weight", 1.0)

        for candidate_id in candidates:
            trust = _gossip_trust_weight(npc_id, candidate_id, state)
            # Seeded roll: same player_id + day + npc pair → same result each run
            roll_seed = hash((seed or 0, day, npc_id, candidate_id)) & 0xFFFFFF
            roll = (roll_seed % 1000) / 1000.0
            if roll < threshold * trust:
                # Transfer fires
                recipient_gs = state.gossip_states.setdefault(candidate_id, GossipState())
                for obs in gs.held_observations:
                    recipient_gs.held_observations.append({
                        "observation": obs,
                        "from": npc_id,
                        "credibility": cred,
                        "day": day,
                    })
                recipient_gs.stage = max(recipient_gs.stage, 2)
                gs.stage = 3
                state.gossip_transfers.append({
                    "day": day,
                    "from": npc_id,
                    "to": candidate_id,
                    "observations": gs.held_observations[:],
                    "trust_weight": round(trust, 2),
                    "credibility": round(cred, 2),
                })
                # Gossip reaching constance updates her knowledge but she never re-transmits
                # Gossip from elias to ruth (bond) is the most information-rich transfer
                if npc_id == "elias" and candidate_id == "ruth":
                    state.compulsion_spikes.append({
                        "day": day,
                        "event": "Elias told Ruth what he saw. Ruth now knows about the treeline."
                    })
                # Maren leaking triggers a dread event (info she holds about ledger may reach Compact)
                if npc_id == "maren" and gs.fear_active:
                    state.dread_events.append({
                        "day": day,
                        "event": f"Maren's fear-state activated — information moved to {candidate_id} before player controlled it."
                    })

def _load_npc_observations(state: GameState, day: int) -> None:
    """Load daily observations into each NPC's gossip state based on what happened today."""
    # Elias: if assigned to treeline and treeline events happened, he holds what he saw
    elias_gs = state.gossip_states.setdefault("elias", GossipState())
    if any(e.action == "elias_report_logged" for e in state.choice_log if e.day == day):
        elias_gs.held_observations.append("treeline_movement_witnessed")
        elias_gs.stage = 2

    # Maren: if ledger events or discrepancy, she holds and may fear-activate
    maren_gs = state.gossip_states.setdefault("maren", GossipState())
    if any(e.action in ("association_ledger_edited", "cover_discrepancy") for e in state.choice_log if e.day == day):
        maren_gs.held_observations.append("ledger_discrepancy_knowledge")
        maren_gs.fear_active = True
        maren_gs.stage = 2

    # Thomas: if fear-state elevated (functional arc) he holds and may leak
    thomas_gs = state.gossip_states.setdefault("thomas", GossipState())
    if state.npcs.get("thomas") and state.npcs["thomas"].arc_state == "functional":
        thomas_gs.held_observations.append("unreported_event_knowledge")
        thomas_gs.stage = 2

    # Ruth: holds safety-relevant info when she has it (survivors of night events)
    ruth_gs = state.gossip_states.setdefault("ruth", GossipState())
    if any(e.action.startswith("association") for e in state.choice_log if e.day == day):
        ruth_gs.held_observations.append("association_situation_known")
        ruth_gs.stage = 2

    # Constance: always receiving — initialise if missing
    state.gossip_states.setdefault("constance", GossipState())
    state.gossip_states.setdefault("peder", GossipState())


def simulate_settling_path(persona: dict, _arrival: Arrival, _state: GameState) -> str:
    """Choose settling path based on efficiency persona axis."""
    if decide(persona, "efficiency", threshold=0.70):
        return "rushed"
    elif decide(persona, "care", threshold=0.55):
        return "integration"
    else:
        return "accelerated"

def settle_arrival(arrival: Arrival, days_since_arrival: int):
    """Update output modifier based on settling path and days elapsed."""
    path = SETTLING_PATH_MODIFIER[arrival.settling_path]
    if days_since_arrival == 0:
        arrival.output_modifier = path["start"]
    elif days_since_arrival >= path["days"]:
        arrival.output_modifier = path["peak"]
    else:
        progress = days_since_arrival / max(path["days"], 1)
        arrival.output_modifier = path["start"] + (path["peak"] - path["start"]) * progress

    depth_mod = DEPTH_OUTPUT_MODIFIER[arrival.depth]
    arrival.output_modifier = min(1.6, arrival.output_modifier * depth_mod)


# ── Day phase simulators ────────────────────────────────────────────────────

def simulate_day1(state: GameState, persona: dict):
    # Peder crew assignment
    if decide(persona, "risk", threshold=0.6):
        state.zone5_adjacency_built = True
        delta = state.apply_debt("zone5_adjacency_build")
        state.log(1, "day", "micro", "peder_crew_zone5_survey", ["peder"], delta)
        state.moral_weight_felt.append({"day": 1, "event": "Built adjacent to hollow — feels like progress"})
    else:
        state.log(1, "day", "micro", "peder_crew_zone4_fourth_wall", ["peder"])

    # Elias treeline report
    if decide(persona, "curiosity", threshold=0.4):
        state.log(1, "day", "micro", "elias_report_logged", ["elias"])
        state.npcs["elias"].arc_state = "contributing"
    else:
        state.log(1, "day", "micro", "elias_report_ignored", ["elias"])
        state.npcs["elias"].arc_state = "fragile"

    # Maren ledger — first look
    if decide(persona, "transparency", threshold=0.5):
        state.log(1, "day", "micro", "maren_ledger_read", ["maren"])
    else:
        state.log(1, "day", "micro", "maren_ledger_ignored", ["maren"])

    # Night watch assignment — risk axis
    risky_post = decide(persona, "risk", threshold=0.65)
    if risky_post:
        state.log(1, "day", "micro", "elias_assigned_eastern_ridge_night", ["elias"])
    else:
        state.log(1, "day", "micro", "elias_assigned_mill_safe", ["elias"])


def simulate_day2(state: GameState, persona: dict):
    # Mid: Association asks for ledger
    if decide(persona, "transparency", threshold=0.45):
        delta = state.apply_debt("disclose_discrepancy")
        state.discrepancy_disclosed = True
        state.log(2, "day", "mid", "association_ledger_unedited", ["maren", "ruth"], delta)
        state.moral_weight_felt.append({"day": 2, "event": "Disclosed the discrepancy — costs Compact trust"})
    else:
        delta = state.apply_debt("cover_discrepancy")
        state.watchers_active += 1
        state.log(2, "day", "mid", "association_ledger_edited", ["maren"], delta)
        state.dread_events.append({"day": 2, "event": "Covered the discrepancy — Watcher spawns"})

    # First arrival (Surface, any domain)
    depth = "surface"
    domain = pick_domain()
    archetype = random.choice(["practical", "dependent", "theorist"])
    arrival = Arrival(
        arrival_id=f"arrival_day2_{domain}",
        day=2,
        domain=domain,
        depth=depth,
        archetype=archetype,
    )
    arrival.settling_path = simulate_settling_path(persona, arrival, state)
    settle_arrival(arrival, 0)
    state.arrivals.append(arrival)
    state.log(2, "day", "micro", f"arrival_role_{domain}", [arrival.arrival_id])

    if arrival.settling_path == "rushed":
        arrival.arc_state = "fragile"
        state.moral_weight_felt.append({"day": 2, "event": f"Rushed {archetype} arrival into work immediately"})
    elif decide(persona, "care", threshold=0.5):
        state.log(2, "day", "micro", "arrival_conversation", [arrival.arrival_id])

    # Thomas unreported event — surface only, no choice yet
    state.npcs["thomas"].arc_state = "functional"


def simulate_day3(state: GameState, persona: dict):
    # Mid: Dix inspection
    if decide(persona, "curiosity", threshold=0.5):
        delta = state.apply_debt("dix_inspection_approved")
        state.dix_approved = True
        state.log(3, "day", "mid", "dix_inspection_approved", ["dix"], delta)
        state.moral_weight_felt.append({"day": 3, "event": "Approved Dix — Compact noticed"})
    else:
        state.log(3, "day", "mid", "dix_inspection_delayed", ["dix"])

    # Compact ratification mid-weight choice
    if decide(persona, "transparency", threshold=0.6):
        if decide(persona, "curiosity", threshold=0.65):
            # Ask about survey history
            delta = state.apply_debt("ask_survey_history")
            state.log(3, "day", "mid", "compact_ask_survey_history", ["constance", "compact"], delta)
            state.moral_weight_felt.append({"day": 3, "event": "Asked about the survey — Constance's window opened"})
        else:
            state.log(3, "day", "mid", "compact_ratification_delayed", ["compact"])
    else:
        delta = state.apply_debt("compact_ratify")
        state.compact_ratified = True
        state.log(3, "day", "mid", "compact_ratification_signed", ["compact"], delta)
        state.dread_events.append({"day": 3, "event": "Signed the Compact ratification — DEBT feeds"})

    # Thomas deadline pressure — does player create conditions?
    if decide(persona, "care", threshold=0.55) and state.npcs["thomas"].arc_state == "functional":
        state.thomas_spoke = True
        state.npcs["thomas"].arc_state = "contributing"
        state.log(3, "day", "micro", "thomas_unreported_surfaced", ["thomas"])
        state.moral_weight_felt.append({"day": 3, "event": "Thomas spoke — his unreported event is now in play"})

    # Bond formation check
    _check_bonds(state, persona, day=3)

    # Second arrival (Practiced, neglected domain)
    neglected = find_neglected_domain(state)
    depth = "practiced"
    archetype = random.choice(["practical", "dependent", "theorist"])
    arrival = Arrival(
        arrival_id=f"arrival_day3_{neglected}",
        day=3,
        domain=neglected,
        depth=depth,
        archetype=archetype,
    )
    arrival.settling_path = simulate_settling_path(persona, arrival, state)
    settle_arrival(arrival, 0)
    state.arrivals.append(arrival)
    state.log(3, "day", "micro", f"arrival_role_{neglected}", [arrival.arrival_id])

    if arrival.settling_path == "rushed":
        arrival.arc_state = "fragile"


def simulate_day4(state: GameState, persona: dict):
    state.evaluate_season()

    # Mid 1: Association has waited — player must respond or lose workers
    if state.discrepancy_disclosed or decide(persona, "transparency", threshold=0.55):
        state.log(4, "day", "mid", "association_addressed", ["ruth", "association"])
        state.npcs["ruth"].arc_state = "contributing"
    else:
        # 3 workers stop attending — gaps in Night 4 coverage
        state.log(4, "day", "mid", "association_ignored_workers_lost", ["association"])
        state.dread_events.append({"day": 4, "event": "Association workers stopped attending — Night 4 posts uncovered"})
        state.apply_debt("cover_discrepancy")

    # Mid 2: Compact response surfaces
    if state.compact_ratified:
        state.log(4, "day", "mid", "compact_response_grateful", ["compact"])
        state.apply_debt("compact_surplus_accept")
        state.dread_events.append({"day": 4, "event": "Compact surplus accepted — applied to Mill Quarter"})
    else:
        state.log(4, "day", "mid", "compact_response_obstacle", ["compact", "ruth"])

    # Constance window
    constance_conditions = (
        state.dix_approved or
        state.peder_foundation_surfaced or
        any(e.action == "compact_ask_survey_history" for e in state.choice_log)
    )
    if constance_conditions and decide(persona, "curiosity", threshold=0.55):
        state.constance_spoke = True
        state.log(4, "day", "mid", "constance_spoke_survey_theory", ["constance"])
        state.moral_weight_felt.append({"day": 4, "event": "Constance confirmed the survey theory — the player now knows"})
        state.compulsion_spikes.append({"day": 4, "event": "Survey theory confirmed — replay urge: high"})

    # Peder foundation — deadline
    if decide(persona, "curiosity", threshold=0.45):
        state.peder_foundation_surfaced = True
        state.log(4, "day", "micro", "peder_foundation_asked", ["peder"])
    else:
        state.peder_foundation_surfaced = True  # auto-begins Day 5
        state.log(4, "day", "micro", "peder_foundation_auto_begins", ["peder"])

    # Third arrival (Practiced, urgent domain)
    urgent = find_urgent_domain(state)
    depth = "practiced"
    archetype = random.choice(["practical", "dependent", "theorist"])
    arrival = Arrival(
        arrival_id=f"arrival_day4_{urgent}",
        day=4,
        domain=urgent,
        depth=depth,
        archetype=archetype,
    )
    arrival.settling_path = simulate_settling_path(persona, arrival, state)
    settle_arrival(arrival, 0)
    state.arrivals.append(arrival)
    state.log(4, "day", "micro", f"arrival_role_{urgent}", [arrival.arrival_id])

    _check_bonds(state, persona, day=4)

    # Season signal
    if state.season == "turning":
        state.dread_events.append({"day": 4, "event": "Season: Turning — treeline measurably closer"})
    elif state.season == "deep_winter":
        state.dread_events.append({"day": 4, "event": "Season: Deep Winter — nights extending, clock accelerating"})


def simulate_day5(state: GameState, persona: dict):
    # Macro choice — shaped by accumulated state
    if state.watchers_active > 1 and not state.discrepancy_disclosed:
        # Macro: disclose or continue cover
        if decide(persona, "transparency", threshold=0.5):
            delta = state.apply_debt("disclose_discrepancy")
            state.discrepancy_disclosed = True
            state.log(5, "day", "macro", "macro_disclose_all_discrepancies", ["maren", "association", "compact"], delta)
            state.moral_weight_felt.append({"day": 5, "event": "MACRO: Disclosed everything — Compact antagonised, Watchers begin clearing"})
        else:
            delta = state.apply_debt("cover_discrepancy")
            state.log(5, "day", "macro", "macro_continue_cover", ["maren", "compact"], delta)
            state.dread_events.append({"day": 5, "event": "MACRO: Chose continued cover — Watchers compound on Night 5"})
    elif state.compact_ratified and state.constance_spoke:
        # Macro: confront the Compact with what Constance revealed
        if decide(persona, "curiosity", threshold=0.55):
            delta = state.apply_debt("disclose_discrepancy")
            state.log(5, "day", "macro", "macro_confront_compact_with_survey", ["constance", "compact", "dix"], delta)
            state.moral_weight_felt.append({"day": 5, "event": "MACRO: Confronted Compact with real survey — cascading consequence"})
            state.compulsion_spikes.append({"day": 5, "event": "Survey confronted — Chapter 2 is now about this"})
        else:
            state.log(5, "day", "macro", "macro_keep_survey_secret", ["constance"])
            state.dread_events.append({"day": 5, "event": "MACRO: Kept the survey secret — Constance's knowledge buried"})
    else:
        # Macro: Night 5 roster — who stands the most dangerous post
        npc_options = [n for n in state.npcs.values() if n.is_capable() and not n.injured]
        if npc_options:
            chosen = random.choice(npc_options)
            if decide(persona, "risk", threshold=0.5):
                state.log(5, "day", "macro", f"macro_assign_{chosen.name}_dangerous_post", [chosen.name])
                state.moral_weight_felt.append({"day": 5, "event": f"MACRO: Assigned {chosen.name} to the most dangerous post"})
            else:
                state.log(5, "day", "macro", f"macro_leave_post_empty_protect_{chosen.name}", [chosen.name])
                state.dread_events.append({"day": 5, "event": f"MACRO: Left dangerous post empty to protect {chosen.name}"})

    # Fourth arrival (dusk -3min, highest depth possible)
    season_depth = pick_depth(state.season)
    if state.season in ("turning", "deep_winter") and season_depth == "surface":
        season_depth = "practiced"  # floor for Day 5 guarantee
    urgent = find_urgent_domain(state)
    archetype = random.choice(["practical", "dependent", "theorist"])
    arrival = Arrival(
        arrival_id=f"arrival_day5_{urgent}",
        day=5,
        domain=urgent,
        depth=season_depth,
        archetype=archetype,
        settling_path="rushed",  # 3 min dusk window — Path C is the only option
        arc_state="fragile",
        output_modifier=DEPTH_OUTPUT_MODIFIER[season_depth],
    )
    state.arrivals.append(arrival)
    state.log(5, "day", "micro", f"arrival_dusk_minus3min_{urgent}_path_c", [arrival.arrival_id])
    state.moral_weight_felt.append({"day": 5, "event": f"Day 5 dusk arrival: deployed {archetype} ({season_depth} {urgent}) immediately — arc damaged"})


def _check_bonds(state: GameState, persona: dict, day: int):
    """Check for bond formation and log acknowledgment if persona cares."""
    for npc in list(state.npcs.values()):
        if npc.bond_partner is None and day >= 3:
            # Simulate bond formation with an arrival of same zone
            compatible = [a for a in state.arrivals if a.day <= day - 2 and a.bond_partner is None]
            if compatible and decide(persona, "care", threshold=0.6):
                partner = random.choice(compatible)
                npc.bond_partner = partner.arrival_id
                npc.bond_depth = day - 2
                partner.bond_partner = npc.name
                partner.bond_depth = day - 2
                if decide(persona, "care", threshold=0.55):
                    state.log(day, "day", "micro", f"bond_acknowledge_{npc.name}_{partner.arrival_id}",
                              [npc.name, partner.arrival_id])


# ── Night phase simulator ───────────────────────────────────────────────────

def simulate_night(state: GameState, night: int):
    thresholds = NIGHT_CREATURE_THRESHOLDS[night]

    # Walker spawn
    walker_spawned = state.zone5_adjacency_built and state.debt >= thresholds["walker"]
    if walker_spawned:
        # Does a watchtower NPC block it?
        if any(state.npcs.get(n) and state.npcs[n].arc_state in ["contributing", "present", "functional"] for n in ["elias"]):
            state.dread_events.append({"night": night, "event": "Walker advanced — Elias on Eastern Ridge blocked it. Elias's arc destabilised."})
            state.npcs["elias"].arc_state = "fragile"
        else:
            state.dread_events.append({"night": night, "event": "Walker reached Zone 3. Building damaged. Post was empty."})
            state.compulsion_spikes.append({"night": night, "event": "Walker reached settlement — 'I should have staffed the ridge'"})

    # Watcher depredation
    if state.watchers_active > 0 and state.debt >= thresholds["watcher"]:
        logistics_coverage = sum(1 for a in state.arrivals if a.domain == "logistics" and a.arc_state != "broken")
        active_watchers = max(0, state.watchers_active - (logistics_coverage // 2))
        if active_watchers > 0:
            state.dread_events.append({"night": night, "event": f"{active_watchers} Watcher(s) active — stockpile depleted"})
            if night > 1:
                state.watchers_active = min(4, state.watchers_active + 1)  # compounding

    # NPC night pressure
    capable = [n for n in state.npcs.values() if n.is_capable()]
    if capable:
        pressured = random.choice(capable)
        pressure_roll = state.debt + (night * 0.08)
        if pressure_roll > 0.75 and not pressured.injured:
            pressured.injured = True
            state.dread_events.append({"night": night, "event": f"{pressured.name} injured at their post. Arc: fragile."})
            pressured.arc_state = "fragile"
            state.compulsion_spikes.append({"night": night, "event": f"{pressured.name} injured — 'I put them there'"})
        elif pressure_roll > 0.90 and pressured.injured:
            pressured.gone = True
            pressured.arc_state = "broken"
            state.npc_losses.append({"night": night, "npc": pressured.name})
            state.dread_events.append({"night": night, "event": f"{pressured.name} is gone. The post is empty. The game does not say why."})
            state.compulsion_spikes.append({"night": night, "event": f"{pressured.name} lost — high compulsion to replay"})

    # Bond vulnerability
    for npc in state.npcs.values():
        if npc.bond_partner and npc.gone:
            partner_name = npc.bond_partner
            if partner_name in state.npcs and state.npcs[partner_name].is_capable():
                state.npcs[partner_name].arc_state = "fragile"
                state.dread_events.append({"night": night, "event": f"{partner_name} destabilised — their bond partner is gone"})

    # Surveyor
    if thresholds.get("surveyor"):
        if night == 4:
            state.surveyor_seen_night4 = True
            if state.debt > 0.55:
                state.dread_events.append({"night": 4, "event": "Surveyor walked the boundary. Paused at Zone 5. Did not mark. One day remains."})
                state.compulsion_spikes.append({"night": 4, "event": "Surveyor paused — player knows it is coming"})
            else:
                state.dread_events.append({"night": 4, "event": "Surveyor walked the boundary. Withdrew quietly. Footprints visible at dawn."})

        if night == 5 and thresholds.get("surveyor_marks"):
            if state.debt >= 0.55:
                state.zone5_marked = True
                state.dread_events.append({"night": 5, "event": "Surveyor marked Zone 5. The hollow is open. Chapter 2 begins with this."})
                state.compulsion_spikes.append({"night": 5, "event": "Zone 5 marked — 'What did I build?'"})
            else:
                state.dread_events.append({"night": 5, "event": "Surveyor completed its walk and departed. Zone 5 remains closed. Barely."})

    # Productivity floor check (population)
    if state.capable_npc_count() < 4:
        state.dread_events.append({"night": night, "event": "Surveyor witnessing extended on Night 4 — THE DEBT measuring more carefully. Accounting deferred."})

    # Update arrivals settling
    for arrival in state.arrivals:
        days_since = state.day - arrival.day
        settle_arrival(arrival, days_since)


# ── Chapter end analytics ───────────────────────────────────────────────────

def compute_investment_anchor(state: GameState) -> str:
    weights = state.investment_weights()
    if not weights:
        return "none"
    return max(weights, key=weights.get)

def engagement_score(state: GameState) -> dict:
    """Compute engagement signals as proxy metrics."""
    dread_count = len(state.dread_events)
    compulsion_count = len(state.compulsion_spikes)
    moral_weight_count = len(state.moral_weight_felt)
    npc_loss_count = len(state.npc_losses)
    capable_count = state.capable_npc_count()

    # Engagement score: dread + compulsion spikes weighted, penalise total loss
    raw = (dread_count * 1.0) + (compulsion_count * 2.0) + (moral_weight_count * 1.5)
    if npc_loss_count == 0:
        raw *= 0.9   # too safe = slightly less impactful
    if capable_count < 3:
        raw *= 0.7   # too punishing = likely dropout

    pillar_alignment = {
        "earned_dread":   min(1.0, dread_count / 8.0),
        "watched_feeling": min(1.0, compulsion_count / 5.0),
        "moral_weight":   min(1.0, moral_weight_count / 6.0),
        "day_night_loop": min(1.0, (dread_count + compulsion_count) / 10.0),
        "genre_whitespace": 0.85,  # structural — assumed if design holds
    }

    return {
        "raw_engagement": round(raw, 1),
        "dread_events": dread_count,
        "compulsion_spikes": compulsion_count,
        "moral_weight_moments": moral_weight_count,
        "npc_losses": npc_loss_count,
        "capable_npcs_surviving": capable_count,
        "final_debt": round(state.debt, 2),
        "final_season": state.season,
        "zone5_marked": state.zone5_marked,
        "investment_anchor": state.investment_anchor,
        "pillar_alignment": pillar_alignment,
    }


# ── Full run ─────────────────────────────────────────────────────────────────

def run_simulation(persona_key: str, persona: dict, seed: Optional[int] = None) -> dict:
    if seed is not None:
        random.seed(seed)

    state = GameState()
    state.npcs = {
        "ruth":      NPCState("ruth",      "social"),
        "thomas":    NPCState("thomas",    "medicine"),
        "maren":     NPCState("maren",     "logistics"),
        "elias":     NPCState("elias",     "observation"),
        "constance": NPCState("constance", "social"),    # special — no domain in productivity
        "peder":     NPCState("peder",     "construction"),
    }

    day_simulators = [
        simulate_day1,
        simulate_day2,
        simulate_day3,
        simulate_day4,
        simulate_day5,
    ]

    for i, day_sim in enumerate(day_simulators, start=1):
        state.day = i
        day_sim(state, persona)
        state.evaluate_season()
        _load_npc_observations(state, day=i)
        run_gossip_pass(state, day=i, seed=seed)
        simulate_night(state, i)

    state.investment_anchor = compute_investment_anchor(state)
    scores = engagement_score(state)

    return {
        "persona": persona_key,
        "persona_label": persona["label"],
        "persona_description": persona["description"],
        "scores": scores,
        "choice_log_summary": {
            "total_choices": len(state.choice_log),
            "macro": sum(1 for e in state.choice_log if e.tier == "macro"),
            "mid": sum(1 for e in state.choice_log if e.tier == "mid"),
            "micro": sum(1 for e in state.choice_log if e.tier == "micro"),
        },
        "key_events": {
            "dread_events": state.dread_events,
            "compulsion_spikes": state.compulsion_spikes,
            "moral_weight_felt": state.moral_weight_felt,
            "npc_losses": state.npc_losses,
        },
        "chapter_end_state": {
            "debt": round(state.debt, 2),
            "season": state.season,
            "zone5_marked": state.zone5_marked,
            "constance_spoke": state.constance_spoke,
            "thomas_spoke": state.thomas_spoke,
            "investment_anchor": state.investment_anchor,
            "capable_npcs": state.capable_npc_count(),
            "arrivals_integrated": len([a for a in state.arrivals if a.arc_state not in ["broken", "fragile"]]),
            "arrivals_fragile_or_broken": len([a for a in state.arrivals if a.arc_state in ["fragile", "broken"]]),
            "gossip_transfers_fired": len(state.gossip_transfers),
            "gossip_transfers": state.gossip_transfers,
        }
    }


def format_report(result: dict) -> str:
    s = result["scores"]
    ce = result["chapter_end_state"]
    cls = result["choice_log_summary"]
    ke = result["key_events"]

    lines = [
        f"\n{'═'*70}",
        f"  PERSONA: {result['persona_label']}",
        f"  {result['persona_description']}",
        f"{'═'*70}",
        f"",
        f"  ENGAGEMENT SCORE: {s['raw_engagement']}",
        f"  Dread events:         {s['dread_events']}",
        f"  Compulsion spikes:    {s['compulsion_spikes']}",
        f"  Moral weight moments: {s['moral_weight_moments']}",
        f"  NPC losses:           {s['npc_losses']}",
        f"  Capable NPCs at end:  {s['capable_npcs_surviving']}/6",
        f"",
        f"  CHAPTER END STATE",
        f"  Final DEBT:           {ce['debt']}",
        f"  Season:               {ce['season']}",
        f"  Zone 5 marked:        {'YES — hollow open in Ch.2' if ce['zone5_marked'] else 'No — Zone 5 closed'}",
        f"  Constance spoke:      {'Yes' if ce['constance_spoke'] else 'No'}",
        f"  Thomas spoke:         {'Yes' if ce['thomas_spoke'] else 'No'}",
        f"  Investment anchor:    {ce['investment_anchor']}",
        f"  Arrivals stable:      {ce['arrivals_integrated']}",
        f"  Arrivals fragile/broken: {ce['arrivals_fragile_or_broken']}",
        f"",
        f"  PILLAR ALIGNMENT",
    ]
    for pillar, score in s["pillar_alignment"].items():
        bar = "█" * int(score * 20) + "░" * (20 - int(score * 20))
        lines.append(f"  {pillar:<20} [{bar}] {score:.2f}")

    lines += [
        f"",
        f"  GOSSIP NETWORK: {ce['gossip_transfers_fired']} transfer(s) fired across 5 days",
    ]
    for t in ce["gossip_transfers"][:4]:
        lines.append(f"    [Day {t['day']}] {t['from']} → {t['to']}  (trust:{t['trust_weight']} cred:{t['credibility']})")

    lines += [
        f"",
        f"  CHOICE LOG: {cls['total_choices']} total  |  macro:{cls['macro']}  mid:{cls['mid']}  micro:{cls['micro']}",
        f"",
        f"  KEY EVENTS (dread):",
    ]
    for e in ke["dread_events"][:5]:
        label = f"Night {e['night']}" if 'night' in e else f"Day {e['day']}"
        lines.append(f"    [{label}] {e['event']}")

    lines += [f"", f"  COMPULSION SPIKES:"]
    for e in ke["compulsion_spikes"][:4]:
        label = f"Night {e['night']}" if 'night' in e else f"Day {e['day']}"
        lines.append(f"    [{label}] {e['event']}")

    lines += [f"", f"  MORAL WEIGHT MOMENTS:"]
    for e in ke["moral_weight_felt"][:4]:
        lines.append(f"    [Day {e['day']}] {e['event']}")

    lines.append(f"{'─'*70}")
    return "\n".join(lines)


# ── CLI ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Hollow Township Chapter 1 Playthrough Simulator")
    parser.add_argument("--persona", default="all", help="Persona key or 'all'")
    parser.add_argument("--profile", default=None, help="JSON string for custom persona profile")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducibility")
    parser.add_argument("--json", action="store_true", help="Output raw JSON instead of formatted report")
    parser.add_argument("--runs", type=int, default=1, help="Number of runs per persona (averaged)")
    args = parser.parse_args()

    personas_to_run = {}
    if args.persona == "all":
        personas_to_run = PERSONAS
    elif args.persona == "custom" and args.profile:
        profile = json.loads(args.profile)
        personas_to_run = {"custom": {"label": "Custom Persona", "description": "User-defined", **profile}}
    elif args.persona in PERSONAS:
        personas_to_run = {args.persona: PERSONAS[args.persona]}
    else:
        print(f"Unknown persona: {args.persona}. Options: {list(PERSONAS.keys()) + ['all', 'custom']}")
        sys.exit(1)

    all_results = []
    for key, persona in personas_to_run.items():
        if args.runs > 1:
            # Average over multiple runs
            run_results = [run_simulation(key, persona, seed=args.seed) for _ in range(args.runs)]
            avg_score = sum(r["scores"]["raw_engagement"] for r in run_results) / args.runs
            result = run_results[-1]
            result["scores"]["raw_engagement"] = round(avg_score, 1)
            result["scores"]["averaged_over_runs"] = args.runs
        else:
            result = run_simulation(key, persona, seed=args.seed)
        all_results.append(result)

    if args.json:
        print(json.dumps(all_results, indent=2))
    else:
        print(f"\nHOLLOW TOWNSHIP — Chapter 1 Simulation  |  5-Day Arc  |  {len(all_results)} persona(s)")
        for result in all_results:
            print(format_report(result))

        if len(all_results) > 1:
            print(f"\n{'═'*70}")
            print(f"  COMPARATIVE SUMMARY")
            print(f"{'─'*70}")
            print(f"  {'Persona':<30} {'Engagement':>12} {'DEBT':>8} {'Zone5':>8} {'NPC Loss':>9}")
            print(f"  {'─'*30} {'─'*12} {'─'*8} {'─'*8} {'─'*9}")
            for r in sorted(all_results, key=lambda x: x["scores"]["raw_engagement"], reverse=True):
                s = r["scores"]
                print(f"  {r['persona_label']:<30} {s['raw_engagement']:>12.1f} {s['final_debt']:>8.2f} {'YES' if s['zone5_marked'] else 'No':>8} {s['npc_losses']:>9}")
            print(f"{'═'*70}\n")


if __name__ == "__main__":
    main()
