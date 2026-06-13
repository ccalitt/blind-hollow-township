class_name SignificancePass
extends RefCounted
## SignificancePass — GDScript port of backend/significance/pass_.py.
##
## Rule-based, no LLM. Runs at dawn, after night events are known. For each night
## event it credits event_weight to NPCs present in the event's zone (this night's
## roster) plus directly threatened NPCs, then converts accumulated weight into a
## behavioral_modifier band. Also tracks object significance (the ledger, Peder's
## foundation, personal objects) and Zone 5 progressive significance.
##
## Pillar 2 (The Watched Feeling): the world accumulates a memory of where the
## player let things happen, per person, per place.
##
## Significance maps live on GameState meta:
##   significance_map: { zone_id: { npc_id: {event_weight, events:Array, permanent, behavioral_modifier} } }
##   object_significance: { object_id: { npc_id: {event_weight, events:Array, accessible} } }

const MODIFIER_THRESHOLDS := [
	[0.0, "baseline"], [0.1, "alert"], [0.3, "marked"], [0.6, "weighted"], [1.0, "carrying"],
]

const PERMANENT_TEXT_MARKERS := ["breach", "reached settlement", "marked zone 5", "marked zone5"]


static func _sig_map() -> Dictionary:
	if not GameState.has_meta("significance_map"):
		GameState.set_meta("significance_map", {})
	return GameState.get_meta("significance_map")


static func _obj_map() -> Dictionary:
	if not GameState.has_meta("object_significance"):
		GameState.set_meta("object_significance", {})
	return GameState.get_meta("object_significance")


static func weight_to_modifier(weight: float) -> String:
	var modifier := "baseline"
	for pair in MODIFIER_THRESHOLDS:
		if weight >= float(pair[0]):
			modifier = String(pair[1])
	return modifier


static func _zone_sig(zone_id: String, npc_id: String) -> Dictionary:
	var sm := _sig_map()
	if not sm.has(zone_id):
		sm[zone_id] = {}
	if not sm[zone_id].has(npc_id):
		sm[zone_id][npc_id] = {"event_weight": 0.0, "events": [], "permanent": false, "behavioral_modifier": "baseline"}
	return sm[zone_id][npc_id]


static func _apply_event(sig: Dictionary, event_id: String, intensity: int, permanent: bool) -> void:
	sig["event_weight"] += intensity * 0.3
	sig["events"].append(event_id)
	if permanent:
		sig["permanent"] = true
	sig["behavioral_modifier"] = weight_to_modifier(sig["event_weight"])


# ── Zone significance (mirrors update_zone_significance) ────────────────────

static func _update_zone_significance(event: Dictionary, roster: Dictionary) -> void:
	var zone_id: String = str(event.get("zone_id", ""))
	if zone_id == "":
		# Infer from first threatened NPC's assignment.
		for npc_id in event.get("threat_npc_ids", []):
			if roster.has(str(npc_id)):
				zone_id = str(roster[str(npc_id)])
				break
	if zone_id == "":
		return

	var text: String = str(event.get("event_text", "")).to_lower()
	var permanent := false
	for marker in PERMANENT_TEXT_MARKERS:
		if text.contains(marker):
			permanent = true
			break

	var present: Array[String] = []
	for npc_id in roster.keys():
		if str(roster[npc_id]) == zone_id:
			present.append(str(npc_id))
	for npc_id in event.get("threat_npc_ids", []):
		if not present.has(str(npc_id)):
			present.append(str(npc_id))

	for npc_id in present:
		var sig := _zone_sig(zone_id, npc_id)
		_apply_event(sig, str(event.get("event_id", "")), int(event.get("horror_intensity", 1)), permanent)


# ── Object significance (mirrors update_ledger_significance) ────────────────

static func _update_ledger_significance(choices: Array, day: int) -> void:
	const LEDGER_ACTIONS := ["maren_ledger_read", "association_ledger_unedited",
		"association_ledger_edited", "compact_ledger_entry_added", "cover_discrepancy"]
	var om := _obj_map()
	if not om.has("handover_ledger"):
		om["handover_ledger"] = {}
	for c in choices:
		if int(c["day_cycle"]) == day and LEDGER_ACTIONS.has(str(c["action_type"])):
			for npc_id in c["npc_ids"]:
				var nid := str(npc_id)
				if not om["handover_ledger"].has(nid):
					om["handover_ledger"][nid] = {"event_weight": 0.0, "events": [], "accessible": false}
				om["handover_ledger"][nid]["event_weight"] += 0.3
				om["handover_ledger"][nid]["events"].append(str(c["choice_id"]))
				om["handover_ledger"][nid]["accessible"] = true


static func _update_foundation_object(day: int) -> void:
	if not GameState.peder_foundation_excavated:
		return
	var om := _obj_map()
	if not om.has("peder_foundation_object"):
		om["peder_foundation_object"] = {}
	if not om["peder_foundation_object"].has("peder"):
		om["peder_foundation_object"]["peder"] = {"event_weight": 1.0, "events": ["excavation_day%d" % day], "accessible": true}


static func _update_personal_objects() -> void:
	var conditions := {
		"ruth": ["ruth_photograph", ["fragile", "broken"]],
		"elias": ["elias_delivery_clipboard", ["contributing"]],
		"thomas": ["thomas_reference_book", ["contributing"]],
		"maren": ["maren_degree_program", ["fragile", "broken"]],
		"peder": ["peder_three_photographs", ["contributing"]],
	}
	var om := _obj_map()
	for npc_id in conditions:
		var obj_id: String = conditions[npc_id][0]
		var trigger_states: Array = conditions[npc_id][1]
		var npc: Dictionary = GameState.npc_states.get(npc_id, {})
		if npc.is_empty():
			continue
		if trigger_states.has(npc.get("arc_state", "")):
			if not om.has(obj_id):
				om[obj_id] = {}
			if not om[obj_id].has(npc_id):
				om[obj_id][npc_id] = {"event_weight": 0.5, "events": ["arc_threshold_%s" % npc["arc_state"]], "accessible": true}


# ── Zone 5 progressive significance (mirrors update_zone5_significance) ──────

static func _update_zone5_significance(day: int) -> void:
	var ks_map: Dictionary = GameState.get_meta("knowledge_states", {})
	for npc_id in ks_map:
		for o in ks_map[npc_id]["held"]:
			var ot: String = o["observation_type"]
			if ot.contains("walker") or ot.contains("horror_witnessed"):
				var sig := _zone_sig("zone_5", str(npc_id))
				var src: String = o.get("source_event_id", "")
				_apply_event(sig, src if src != "" else "walker_obs_day%d" % day, 1, false)

	if GameState.dix_approved:
		for npc_id in GameState.npc_states:
			if GameState.npc_is_capable(npc_id):
				var sig := _zone_sig("zone_5", npc_id)
				if not _has_event_prefix(sig, "dix_inspection"):
					_apply_event(sig, "dix_inspection_approved", 1, true)

	if GameState.constance_window_open:
		var csig := _zone_sig("zone_5", "constance")
		if not _has_event_prefix(csig, "constance_survey"):
			_apply_event(csig, "constance_survey_knowledge", 2, true)


static func _has_event_prefix(sig: Dictionary, prefix: String) -> bool:
	for e in sig["events"]:
		if str(e).begins_with(prefix):
			return true
	return false


# ── Full dawn pass (mirrors run_dawn_pass) ──────────────────────────────────

static func run_dawn_pass(night_events: Array, roster: Dictionary, choices: Array, day: int) -> void:
	for event in night_events:
		_update_zone_significance(event, roster)
	_update_ledger_significance(choices, day)
	_update_foundation_object(day)
	_update_personal_objects()
	_update_zone5_significance(day)


# ── Per-NPC summary (mirrors significance_summary) — for behavioral state lines ─

static func significance_summary(npc_id: String) -> Dictionary:
	var zone_modifiers: Dictionary = {}
	for zone_id in _sig_map():
		if _sig_map()[zone_id].has(npc_id):
			zone_modifiers[zone_id] = _sig_map()[zone_id][npc_id]["behavioral_modifier"]
	var accessible: Array = []
	for obj_id in _obj_map():
		if _obj_map()[obj_id].has(npc_id) and _obj_map()[obj_id][npc_id]["accessible"]:
			accessible.append(obj_id)
	return {"zone_modifiers": zone_modifiers, "accessible_objects": accessible}
