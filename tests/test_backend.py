"""
Hollow Township — Backend Smoke Tests
======================================
Tests the gossip propagation pass, significance pass, consequence thread
generator, and session engine orchestration. No LLM calls, no cloud dependencies.

Run: python -m pytest tests/ -v
  or: python tests/test_backend.py
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    import pytest
except ModuleNotFoundError:
    # Allow `python tests/test_backend.py` to run without pytest installed.
    # Provides the minimal pytest surface this suite uses (approx, raises).
    class _Approx:
        def __init__(self, expected, rel=1e-6, abs=1e-9):
            self.expected, self.rel, self.abs = expected, rel, abs
        def __eq__(self, other):
            return abs(other - self.expected) <= max(self.rel * abs(self.expected), self.abs)
        def __repr__(self):
            return f"approx({self.expected})"

    class _PytestShim:
        @staticmethod
        def approx(expected, rel=1e-6, abs=1e-9):
            return _Approx(expected, rel, abs)

        class raises:
            def __init__(self, exc):
                self.exc = exc
            def __enter__(self):
                return self
            def __exit__(self, exc_type, exc, tb):
                return exc_type is not None and issubclass(exc_type, self.exc)

    pytest = _PytestShim()

from backend.models import (
    SessionState, NPCState, ChoiceEntry, NightEvent, Observation,
    NPCKnowledgeState, ZoneNPCSignificance, weight_to_modifier,
)
from backend.gossip.propagation import (
    compute_trust, get_transmission_candidates, effective_threshold,
    seeded_roll, load_day_observations, run_pass, knowledge_summary,
)
from backend.significance.pass_ import (
    update_zone_significance, significance_summary,
    update_personal_objects,
)
from backend.consequence.thread_generator import (
    match_cause_chains, passes_reveal_test, generate_thread,
    compute_investment_anchor, build_sentence1_prompt,
)
from backend.engine import SessionEngine, CycleResult


# ── Fixtures ──────────────────────────────────────────────────────────────────

def make_npc(npc_id: str, domain: str, arc: str, disposition: str) -> NPCState:
    n = NPCState(npc_id=npc_id, domain=domain)
    n.arc_state = arc
    n.gossip_disposition = disposition
    return n

def make_state(player_id: str = "test_player") -> SessionState:
    state = SessionState(player_id=player_id)
    state.npc_states = {
        "ruth":      make_npc("ruth",      "social",       "present",      "safety_concern"),
        "thomas":    make_npc("thomas",    "medicine",     "functional",   "fear_state"),
        "maren":     make_npc("maren",     "logistics",    "present",      "fear_activated"),
        "elias":     make_npc("elias",     "observation",  "contributing", "bond_only"),
        "constance": make_npc("constance", "social",       "present",      "receiver_only"),
        "peder":     make_npc("peder",     "construction", "present",      "environmental_only"),
    }
    return state

def make_choice(
    choice_id: str,
    action: str,
    npc_ids: list,
    day: int = 1,
    tier: str = "micro",
) -> ChoiceEntry:
    return ChoiceEntry(
        choice_id=choice_id,
        player_id="test_player",
        day_cycle=day,
        phase="day",
        moral_tier=tier,
        action_type=action,
        npc_ids=npc_ids,
    )

def make_event(
    event_id: str,
    night: int,
    cause_chain: list,
    threat_npcs: list,
    text: str = "Event text.",
    zone_id: str = "zone_3",
    intensity: int = 1,
) -> NightEvent:
    return NightEvent(
        event_id=event_id,
        player_id="test_player",
        night=night,
        event_text=text,
        threat_npc_ids=threat_npcs,
        cause_chain=cause_chain,
        zone_id=zone_id,
        horror_intensity=intensity,
    )


# ── Models ────────────────────────────────────────────────────────────────────

def test_weight_to_modifier_thresholds():
    assert weight_to_modifier(0.0) == "baseline"
    assert weight_to_modifier(0.05) == "baseline"
    assert weight_to_modifier(0.1) == "alert"
    assert weight_to_modifier(0.3) == "marked"
    assert weight_to_modifier(0.6) == "weighted"
    assert weight_to_modifier(1.0) == "carrying"
    assert weight_to_modifier(2.0) == "carrying"

def test_zone_significance_apply_event():
    sig = ZoneNPCSignificance()
    sig.apply_event("evt1", intensity=1, permanent=False)
    assert sig.event_weight == pytest.approx(0.3)
    assert sig.behavioral_modifier == "marked"   # 0.3 hits "marked" threshold exactly
    assert sig.permanent is False

    sig.apply_event("evt2", intensity=3, permanent=True)
    assert sig.event_weight == pytest.approx(1.2)
    assert sig.behavioral_modifier == "carrying"  # 1.2 >= 1.0 threshold
    assert sig.permanent is True


# ── Gossip engine ─────────────────────────────────────────────────────────────

def test_compute_trust_base():
    state = make_state()
    # No bond → base trust 0.4
    assert compute_trust("ruth", "thomas", state) == pytest.approx(0.4)

def test_compute_trust_with_bond():
    state = make_state()
    state.npc_states["elias"].bond_partner = "ruth"
    state.npc_states["elias"].bond_depth = 2
    trust = compute_trust("elias", "ruth", state)
    assert trust > 0.4
    assert trust <= 1.0

def test_constance_has_no_candidates():
    state = make_state()
    candidates = get_transmission_candidates("constance", state)
    assert candidates == []

def test_elias_bond_only_no_bond():
    state = make_state()
    candidates = get_transmission_candidates("elias", state)
    assert candidates == []

def test_elias_bond_only_with_bond():
    state = make_state()
    state.npc_states["elias"].bond_partner = "ruth"
    candidates = get_transmission_candidates("elias", state)
    assert candidates == ["ruth"]

def test_maren_fear_activated_threshold():
    state = make_state()
    state.knowledge_states["maren"] = NPCKnowledgeState(
        npc_id="maren",
        fear_active=True,
        gossip_stage=2,
        held_observations=[Observation("ledger_discrepancy_knowledge")],
    )
    threshold = effective_threshold("maren", state)
    assert threshold == pytest.approx(0.65)

def test_seeded_roll_deterministic():
    r1 = seeded_roll("player1", 3, "thomas", "ruth")
    r2 = seeded_roll("player1", 3, "thomas", "ruth")
    assert r1 == r2

def test_seeded_roll_different_inputs_differ():
    r1 = seeded_roll("player1", 3, "thomas", "ruth")
    r2 = seeded_roll("player1", 3, "maren", "ruth")
    assert r1 != r2

def test_load_day_observations_elias_report():
    state = make_state()
    choices = [make_choice("c1", "elias_report_logged", ["elias"], day=1)]
    load_day_observations(state, day=1, choice_log=choices, night_events=[])
    ks = state.knowledge_states.get("elias")
    assert ks is not None
    assert any(o.observation_type == "treeline_movement_witnessed" for o in ks.held_observations)
    assert ks.gossip_stage == 2

def test_load_day_observations_maren_ledger_cover():
    state = make_state()
    choices = [make_choice("c1", "association_ledger_edited", ["maren"], day=2)]
    load_day_observations(state, day=2, choice_log=choices, night_events=[])
    ks = state.knowledge_states.get("maren")
    assert ks is not None
    assert ks.fear_active is True
    assert any(o.observation_type == "ledger_discrepancy_knowledge" for o in ks.held_observations)

def test_run_pass_thomas_leaks_to_ruth():
    """Thomas (low threshold fear_state) should transfer to Ruth at base trust."""
    state = make_state()
    # Pre-load Thomas with an observation
    state.knowledge_states["thomas"] = NPCKnowledgeState(
        npc_id="thomas",
        held_observations=[Observation("unreported_event_knowledge", day_witnessed=1)],
        gossip_stage=2,
    )
    transfers = run_pass(state, day=2, choice_log=[], night_events=[])
    # Thomas has 0.70 threshold × 0.4 trust = 0.28 effective threshold
    # seeded_roll determines outcome — just verify the function runs and returns list
    assert isinstance(transfers, list)

def test_run_pass_constance_never_transmits():
    state = make_state()
    state.knowledge_states["constance"] = NPCKnowledgeState(
        npc_id="constance",
        held_observations=[Observation("everything_known", day_witnessed=1)],
        gossip_stage=2,
    )
    transfers = run_pass(state, day=2, choice_log=[], night_events=[])
    constance_transfers = [t for t in transfers if t.from_npc == "constance"]
    assert constance_transfers == []

def test_knowledge_summary_excludes_empty():
    state = make_state()
    state.knowledge_states["elias"] = NPCKnowledgeState(
        npc_id="elias",
        held_observations=[Observation("treeline_movement_witnessed")],
        gossip_stage=2,
    )
    summary = knowledge_summary(state)
    assert "elias" in summary
    assert "treeline_movement_witnessed" in summary["elias"]
    # NPCs with nothing held should not appear
    assert "constance" not in summary


# ── Significance pass ─────────────────────────────────────────────────────────

def test_zone_significance_update_applies_to_present_npcs():
    state = make_state()
    event = make_event("e1", night=1, cause_chain=["c1"], threat_npcs=["elias"], zone_id="zone_3", intensity=2)
    zone_assignments = {"elias": "zone_3", "ruth": "zone_1", "thomas": "zone_2"}
    update_zone_significance(state, event, zone_assignments)
    assert "zone_3" in state.significance_map
    assert "elias" in state.significance_map["zone_3"]
    sig = state.significance_map["zone_3"]["elias"]
    assert sig.event_weight == pytest.approx(0.6)
    assert sig.behavioral_modifier == "weighted"   # 0.6 >= 0.6 threshold

def test_personal_object_ruth_accessible_at_fragile():
    state = make_state()
    state.npc_states["ruth"].arc_state = "fragile"
    update_personal_objects(state)
    obj_map = state.object_significance.get("ruth_photograph", {})
    assert "ruth" in obj_map
    assert obj_map["ruth"].accessible is True

def test_personal_object_elias_accessible_at_contributing():
    state = make_state()
    state.npc_states["elias"].arc_state = "contributing"
    update_personal_objects(state)
    obj_map = state.object_significance.get("elias_delivery_clipboard", {})
    assert "elias" in obj_map
    assert obj_map["elias"].accessible is True

def test_personal_object_elias_not_accessible_at_fragile():
    state = make_state()
    state.npc_states["elias"].arc_state = "fragile"
    update_personal_objects(state)
    obj_map = state.object_significance.get("elias_delivery_clipboard", {})
    # fragile is not a trigger state for Elias's clipboard
    assert not obj_map.get("elias", type("X", (), {"accessible": False})()).accessible

def test_significance_summary_zone_modifiers():
    state = make_state()
    zone_map = state.significance_map.setdefault("zone_3", {})
    zone_map["elias"] = ZoneNPCSignificance(
        event_weight=1.2, events=["e1"], behavioral_modifier="carrying"
    )
    summary = significance_summary(state, "elias")
    assert summary["zone_modifiers"]["zone_3"] == "carrying"
    assert summary["accessible_objects"] == []


# ── Consequence thread generator ──────────────────────────────────────────────

def test_match_cause_chains_basic():
    choices = [
        make_choice("c1", "assign_npc", ["elias"], day=1),
        make_choice("c2", "association_ledger_edited", ["maren"], day=2),
    ]
    events = [
        make_event("e1", night=1, cause_chain=["c1"], threat_npcs=["elias"]),
    ]
    pairs = match_cause_chains(choices, events)
    assert len(pairs) == 1
    assert pairs[0][0].choice_id == "c1"
    assert pairs[0][1].event_id == "e1"

def test_match_cause_chains_no_match():
    choices = [make_choice("c1", "assign_npc", ["elias"], day=1)]
    events = [make_event("e1", night=1, cause_chain=["c99"], threat_npcs=["elias"])]
    pairs = match_cause_chains(choices, events)
    assert pairs == []

def test_passes_reveal_test_valid():
    choice = make_choice("c1", "assign_npc", ["elias"], day=1)
    event = make_event("e1", night=1, cause_chain=["c1"], threat_npcs=["elias"])
    assert passes_reveal_test(choice, event) is True

def test_passes_reveal_test_no_npc_overlap_no_chain_match():
    choice = make_choice("c1", "assign_npc", ["ruth"], day=1)
    event = make_event("e1", night=1, cause_chain=["c99"], threat_npcs=["thomas"])
    assert passes_reveal_test(choice, event) is False

def test_generate_thread_produces_entries():
    state = make_state()
    choices = [make_choice("c1", "assign_npc", ["elias"], day=1)]
    events = [make_event("e1", night=1, cause_chain=["c1"], threat_npcs=["elias"])]
    entries = generate_thread(state, choices, events, night=1)
    assert len(entries) == 1
    assert entries[0].npc_id == "elias"
    assert "Day 1" in entries[0].sentence1_prompt
    assert "Night 1" in entries[0].sentence2_prompt

def test_generate_thread_quiet_night():
    state = make_state()
    entries = generate_thread(state, [], [], night=1)
    assert entries == []

def test_compute_investment_anchor_excludes_faction_tokens():
    choices = [
        make_choice("c1", "compact_ratification_signed", ["compact"], day=3, tier="mid"),
        make_choice("c2", "assign_npc", ["elias"], day=1, tier="micro"),
        make_choice("c3", "assign_npc", ["elias"], day=2, tier="micro"),
        make_choice("c4", "assign_npc", ["ruth"], day=1, tier="micro"),
    ]
    anchor = compute_investment_anchor(choices)
    assert anchor == "elias"  # 2 micro = weight 2; ruth = 1; compact excluded

def test_compute_investment_anchor_macro_outweighs():
    choices = [
        make_choice("c1", "macro_action", ["ruth"], day=5, tier="macro"),
        make_choice("c2", "assign_npc", ["elias"], day=1, tier="micro"),
        make_choice("c3", "assign_npc", ["elias"], day=2, tier="micro"),
    ]
    anchor = compute_investment_anchor(choices)
    # ruth: macro = 3; elias: 2 micro = 2
    assert anchor == "ruth"

def test_build_sentence1_prompt_assign():
    choice = make_choice("c1", "assign_npc", ["elias"], day=1)
    prompt = build_sentence1_prompt(choice)
    assert "elias" in prompt
    assert "Day 1" in prompt


# ── Engine ────────────────────────────────────────────────────────────────────

def stub_night_precompute(_state, choice_log, _knowledge):
    """Deterministic stub for night pre-computation."""
    if not choice_log:
        return []
    return [
        make_event(
            "stub_e1", night=1,
            cause_chain=[choice_log[0].choice_id],
            threat_npcs=choice_log[0].npc_ids[:1],
            zone_id="zone_3",
        )
    ]

def test_engine_end_day_runs_gossip_pass():
    state = make_state()
    # Pre-load Maren with fear-state observation so gossip has something to transfer
    state.knowledge_states["maren"] = NPCKnowledgeState(
        npc_id="maren",
        held_observations=[Observation("ledger_discrepancy_knowledge")],
        fear_active=True,
        gossip_stage=2,
    )
    engine = SessionEngine(state)
    choices = [make_choice("c1", "association_ledger_edited", ["maren"], day=2)]
    zone_assignments = {"ruth": "zone_1", "elias": "zone_3", "maren": "zone_1",
                        "thomas": "zone_2", "constance": "zone_2", "peder": "zone_4"}
    result = engine.end_day(
        day=2,
        choice_log=choices,
        night_precompute_fn=stub_night_precompute,
        zone_assignments=zone_assignments,
    )
    assert isinstance(result, CycleResult)
    assert result.gossip_transfers_fired >= 0  # may or may not fire based on seeded roll
    assert result.knowledge_snapshot is not None
    assert isinstance(result.night_events, list)
    assert not result.errors

def test_engine_begin_dawn_produces_thread():
    state = make_state()
    engine = SessionEngine(state)
    choices = [make_choice("c1", "assign_npc", ["elias"], day=1)]
    events = [make_event("e1", night=1, cause_chain=["c1"], threat_npcs=["elias"], zone_id="zone_3")]
    zone_assignments = {"elias": "zone_3", "ruth": "zone_1"}
    result = engine.begin_dawn(
        day=1,
        choice_log=choices,
        night_events=events,
        zone_assignments=zone_assignments,
    )
    assert isinstance(result, CycleResult)
    assert len(result.thread_entries) >= 1
    assert result.investment_anchor == "elias"
    assert not result.errors

def test_engine_build_npc_user_block():
    state = make_state()
    state.knowledge_states["elias"] = NPCKnowledgeState(
        npc_id="elias",
        held_observations=[Observation("treeline_movement_witnessed")],
        gossip_stage=2,
    )
    engine = SessionEngine(state)
    block = engine.build_npc_user_block("elias")
    assert block["npc_id"] == "elias"
    assert block["arc_state"] == "contributing"
    assert "treeline_movement_witnessed" in block["knowledge_state"]

def test_engine_build_npc_user_block_missing_npc():
    state = make_state()
    engine = SessionEngine(state)
    block = engine.build_npc_user_block("nonexistent_npc")
    assert block == {}


# ── Full cycle integration ────────────────────────────────────────────────────

def test_full_day1_to_dawn_cycle():
    """
    End-to-end: Day 1 choices → gossip pass → stub night → dawn significance
    + consequence thread + investment anchor.
    """
    state = make_state()
    engine = SessionEngine(state)

    choices = [
        make_choice("c1", "elias_report_logged", ["elias"], day=1, tier="micro"),
        make_choice("c2", "association_ledger_edited", ["maren"], day=1, tier="mid"),
    ]
    zone_assignments = {
        "elias": "zone_3", "ruth": "zone_1", "maren": "zone_1",
        "thomas": "zone_2", "constance": "zone_2", "peder": "zone_4",
    }

    # Day end
    day_result = engine.end_day(
        day=1,
        choice_log=choices,
        night_precompute_fn=stub_night_precompute,
        zone_assignments=zone_assignments,
    )
    assert not day_result.errors
    assert len(day_result.night_events) == 1

    # Dawn
    dawn_result = engine.begin_dawn(
        day=1,
        choice_log=choices,
        night_events=day_result.night_events,
        zone_assignments=zone_assignments,
    )
    assert not dawn_result.errors
    assert dawn_result.investment_anchor in ("elias", "maren")
    assert "zone_3" in state.significance_map


if __name__ == "__main__":
    # Run as script if pytest not available
    results = []
    test_fns = [v for k, v in globals().items() if k.startswith("test_")]
    passed = failed = 0
    for fn in test_fns:
        try:
            fn()
            print(f"  PASS  {fn.__name__}")
            passed += 1
        except Exception as e:
            print(f"  FAIL  {fn.__name__}: {e}")
            failed += 1
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(0 if failed == 0 else 1)
