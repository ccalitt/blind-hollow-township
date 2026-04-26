"""
Hollow Township — Backend Data Models
======================================
Shared dataclasses for all backend passes (gossip, significance, consequence).
These mirror the DynamoDB schema defined in ARCHITECTURE.md.
No cloud dependencies — these run identically in Lambda and in local tests.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional


# ── Choice log ────────────────────────────────────────────────────────────────

@dataclass
class ChoiceEntry:
    choice_id: str
    player_id: str
    day_cycle: int
    phase: str                   # "day" | "night" | "dawn"
    moral_tier: str              # "micro" | "mid" | "macro"
    action_type: str
    npc_ids: list[str]
    choice_payload: dict = field(default_factory=dict)
    consequence_ids: list[str] = field(default_factory=list)
    debt_delta: float = 0.0
    chapter: int = 1


# ── Night events ──────────────────────────────────────────────────────────────

@dataclass
class NightEvent:
    event_id: str
    player_id: str
    night: int
    event_text: str
    threat_npc_ids: list[str]
    cause_chain: list[str]       # choice_ids that caused this event
    zone_id: Optional[str]       # which zone the event occurred in
    horror_intensity: int        # 1 | 2 | 3
    npc_arc_deltas: dict = field(default_factory=dict)  # {npc_id: new_arc_state}
    chapter: int = 1


# ── NPC state ─────────────────────────────────────────────────────────────────

@dataclass
class NPCState:
    npc_id: str
    domain: str
    arc_state: str = "present"   # settling|present|contributing|functional|fragile|broken
    injured: bool = False
    gone: bool = False
    bond_partner: Optional[str] = None
    bond_depth: int = 0
    gossip_disposition: str = "any"   # mirrors WORLD_STATE gossip_disposition trigger field

    def is_capable(self) -> bool:
        return not self.gone and self.arc_state != "broken"


# ── Gossip models ─────────────────────────────────────────────────────────────

@dataclass
class Observation:
    observation_type: str        # "treeline_movement" | "ledger_discrepancy" | etc.
    source_event_id: Optional[str] = None
    day_witnessed: int = 0
    zone_id: Optional[str] = None


@dataclass
class NPCKnowledgeState:
    npc_id: str
    held_observations: list[Observation] = field(default_factory=list)
    received_from: dict[str, list[Observation]] = field(default_factory=dict)
    gossip_stage: int = 1        # 1=nothing held, 2=holding, 3=transmitted
    fear_active: bool = False


@dataclass
class GossipTransfer:
    day: int
    from_npc: str
    to_npc: str
    observations: list[Observation]
    trust_weight: float
    credibility_weight: float


# ── Significance models ───────────────────────────────────────────────────────

BEHAVIORAL_MODIFIER_THRESHOLDS = [
    (0.0,  "baseline"),
    (0.1,  "alert"),
    (0.3,  "marked"),
    (0.6,  "weighted"),
    (1.0,  "carrying"),
]

def weight_to_modifier(weight: float) -> str:
    modifier = "baseline"
    for threshold, label in BEHAVIORAL_MODIFIER_THRESHOLDS:
        if weight >= threshold:
            modifier = label
    return modifier


@dataclass
class ZoneNPCSignificance:
    event_weight: float = 0.0
    events: list[str] = field(default_factory=list)   # event_ids
    permanent: bool = False
    behavioral_modifier: str = "baseline"

    def apply_event(self, event_id: str, intensity: int, permanent: bool = False) -> None:
        self.event_weight += intensity * 0.3
        self.events.append(event_id)
        if permanent:
            self.permanent = True
        self.behavioral_modifier = weight_to_modifier(self.event_weight)


@dataclass
class ObjectNPCSignificance:
    event_weight: float = 0.0
    events: list[str] = field(default_factory=list)
    accessible: bool = False     # True when arc threshold condition is met


# ── Session state ─────────────────────────────────────────────────────────────

@dataclass
class SessionState:
    player_id: str
    current_day: int = 1
    current_phase: str = "day"
    debt: float = 0.0
    season: str = "late_summer"
    chapter: int = 1

    # NPC states — original six + arrivals keyed by npc_id
    npc_states: dict[str, NPCState] = field(default_factory=dict)

    # Gossip engine
    knowledge_states: dict[str, NPCKnowledgeState] = field(default_factory=dict)
    gossip_transfers: list[GossipTransfer] = field(default_factory=list)

    # Significance maps
    # significance_map[zone_id][npc_id] = ZoneNPCSignificance
    significance_map: dict[str, dict[str, ZoneNPCSignificance]] = field(default_factory=dict)
    # object_significance[object_id][npc_id] = ObjectNPCSignificance
    object_significance: dict[str, dict[str, ObjectNPCSignificance]] = field(default_factory=dict)

    # Persistent flags
    compact_ratified: bool = False
    dix_approved: bool = False
    discrepancy_disclosed: bool = False
    thomas_spoke: bool = False
    constance_window_open: bool = False
    peder_foundation_excavated: bool = False
    zone5_marked: bool = False

    # Investment anchor (computed at chapter end)
    investment_anchor: Optional[str] = None
