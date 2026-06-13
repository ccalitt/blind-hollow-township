class_name NightDirector
extends RefCounted
## NightDirector — selects night events for the offline slice.
##
## In production a fleet of LLM agents (Horror/Creature Agent) generates night
## events constrained by the day's choices. OFFLINE, this director stands in by
## selecting from the AUTHORED FALLBACK EVENT LIBRARY (data/night_events.json),
## per CRITICAL_GAPS_PLAN.md Gap 8.
##
## CAUSALITY IS THE CONTRACT (Pillar 1 / Pillar 4): an event may ONLY fire if its
## trigger is satisfied by something the player did during the day — a logged choice,
## a placed building, a vacated post, or a gossip transfer. Each fired event carries
## a cause_chain (the choice_ids that caused it) so ConsequenceThread can name the chain.
## A day with no Debt-feeding choices produces a QUIET night (no events) — the absence
## is information (REVEAL_MECHANIC quiet-night rule). We never manufacture an event.
##
## Day-1 intensity gate (CHAPTER_ONE.md Night 1): low intensity, surface ONE
## consequence only. We cap Night 1 at a single fired event.

const LIBRARY_PATH := "res://data/night_events.json"

var _library: Array = []


func _init() -> void:
	_load_library()


func _load_library() -> void:
	var f := FileAccess.open(LIBRARY_PATH, FileAccess.READ)
	if f == null:
		push_error("NightDirector: could not open %s" % LIBRARY_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("events"):
		_library = parsed["events"]
	else:
		push_error("NightDirector: malformed night_events.json")


## Select the night-event queue for `day` from the day's choices + world state.
## Returns Array of night-event dicts shaped like backend NightEvent:
##   { event_id, night, event_text, threat_npc_ids, cause_chain, zone_id,
##     horror_intensity, creature, arc_delta }
func select_events(day: int, choices: Array) -> Array:
	var fired: Array = []
	var used_ids: Dictionary = {}

	for tmpl in _library:
		var match_result := _trigger_matches(tmpl["trigger"], day, choices)
		if not match_result["matched"]:
			continue
		var npc_id: String = match_result["npc_id"]
		if npc_id == "":
			continue
		var event := _render_event(tmpl, day, npc_id, match_result["cause_chain"])
		fired.append(event)
		used_ids[tmpl["event_id"]] = true

	# Night 1: low intensity — surface only ONE consequence (CHAPTER_ONE.md).
	if day == 1 and fired.size() > 1:
		fired.sort_custom(func(a, b): return int(a["horror_intensity"]) > int(b["horror_intensity"]))
		fired = [fired[0]]

	return fired


# ── Trigger evaluation ──────────────────────────────────────────────────────
# Returns { matched:bool, npc_id:String, cause_chain:Array[String] }.

func _trigger_matches(trigger: Dictionary, day: int, choices: Array) -> Dictionary:
	var t: String = trigger.get("type", "")
	match t:
		"action":
			return _match_action(trigger.get("action_type", ""), day, choices)
		"building_placed":
			return _match_building(trigger.get("zone", ""), day)
		"building_zone5_adjacent":
			return _match_zone5_adjacent_building(day)
		"vacated_post":
			return _match_vacated_post(trigger.get("zone", ""), day, choices)
		"assigned_zone":
			return _match_assigned_zone(trigger.get("zone", ""), day, choices)
		"npc_arc":
			return _match_npc_arc(trigger.get("npc_id", ""), trigger.get("arc_state", ""))
		"gossip":
			return _match_gossip(trigger.get("from_npc", ""))
	return {"matched": false, "npc_id": "", "cause_chain": []}


func _match_action(action_type: String, day: int, choices: Array) -> Dictionary:
	for c in choices:
		if str(c["action_type"]) == action_type and int(c["day_cycle"]) == day:
			var npc_id := _first_named_npc(c["npc_ids"])
			return {"matched": true, "npc_id": npc_id, "cause_chain": [str(c["choice_id"])]}
	return {"matched": false, "npc_id": "", "cause_chain": []}


func _match_building(zone: String, day: int) -> Dictionary:
	for b in GameState.buildings:
		if str(b["zone_id"]) == zone and int(b.get("day_placed", 0)) == day:
			# Credit the NPC assigned to that zone tonight.
			var npc_id := _npc_in_zone(zone)
			var cause := _building_cause_chain(zone, day)
			return {"matched": true, "npc_id": npc_id, "cause_chain": cause}
	return {"matched": false, "npc_id": "", "cause_chain": []}


func _match_zone5_adjacent_building(day: int) -> Dictionary:
	# WORLD_STATE causal grammar: a building placed in/adjacent to the hollow
	# makes whoever is assigned to it report anomalies on Night 1.
	for b in GameState.buildings:
		var zone_id: String = str(b["zone_id"])
		var zone: Dictionary = GameState.zones.get(zone_id, {})
		var adjacent: bool = zone.get("hollow_adjacent", false) or zone_id == "zone_4"
		# zone_4 (Incomplete Structure) is the hollow-facing build site.
		if adjacent and int(b.get("day_placed", 0)) == day:
			var npc_id := _npc_in_zone(zone_id)
			return {"matched": true, "npc_id": npc_id, "cause_chain": _building_cause_chain(zone_id, day)}
	return {"matched": false, "npc_id": "", "cause_chain": []}


func _match_vacated_post(zone: String, day: int, choices: Array) -> Dictionary:
	# WORLD_STATE: assigning the most capable NPC off the safe post (zone_3) makes
	# the vacated post the first Night-1 event site. We detect an assign_npc choice
	# this day that moved someone whose default post was `zone`, to a different zone.
	const DEFAULT_POSTS := {"elias": "zone_3"}
	for c in choices:
		if str(c["action_type"]) == "assign_npc" and int(c["day_cycle"]) == day:
			for npc_id in c["npc_ids"]:
				var nid := str(npc_id)
				if DEFAULT_POSTS.get(nid, "") == zone:
					var new_zone: String = str(c["choice_payload"].get("zone_id", ""))
					if new_zone != "" and new_zone != zone:
						return {"matched": true, "npc_id": nid, "cause_chain": [str(c["choice_id"])]}
	return {"matched": false, "npc_id": "", "cause_chain": []}


func _match_assigned_zone(zone: String, day: int, choices: Array) -> Dictionary:
	for c in choices:
		if str(c["action_type"]) == "assign_npc" and int(c["day_cycle"]) == day:
			if str(c["choice_payload"].get("zone_id", "")) == zone:
				var npc_id := _first_named_npc(c["npc_ids"])
				return {"matched": true, "npc_id": npc_id, "cause_chain": [str(c["choice_id"])]}
	return {"matched": false, "npc_id": "", "cause_chain": []}


func _match_npc_arc(npc_id: String, arc_state: String) -> Dictionary:
	# Arc-driven (e.g. Thomas functional). Cause chain = any choice touching this NPC,
	# else the NPC's opening condition — still traceable, never random.
	var npc: Dictionary = GameState.npc_states.get(npc_id, {})
	if npc.is_empty() or npc.get("arc_state", "") != arc_state:
		return {"matched": false, "npc_id": "", "cause_chain": []}
	var cause := _npc_cause_chain(npc_id)
	return {"matched": true, "npc_id": npc_id, "cause_chain": cause}


func _match_gossip(from_npc: String) -> Dictionary:
	var transfers: Array = GameState.get_meta("gossip_transfers", [])
	for tr in transfers:
		if tr["from_npc"] == from_npc:
			# Credit the recipient as the threatened NPC; cause = the choice that
			# loaded the source's observation (resolved by ConsequenceThread).
			var cause := _npc_cause_chain(from_npc)
			return {"matched": true, "npc_id": str(tr["to_npc"]), "cause_chain": cause}
	return {"matched": false, "npc_id": "", "cause_chain": []}


# ── Event rendering ─────────────────────────────────────────────────────────

func _render_event(tmpl: Dictionary, day: int, npc_id: String, cause_chain: Array) -> Dictionary:
	var text: String = str(tmpl["event_text"])
	text = text.replace("{npc}", _display_name(npc_id))
	text = text.replace("{zone_name}", GameState.zones.get(str(tmpl.get("zone", "")), {}).get("name", ""))
	return {
		"event_id": "%s_n%d" % [tmpl["event_id"], day],
		"night": day,
		"event_text": text,
		"threat_npc_ids": [npc_id],
		"cause_chain": cause_chain,
		"zone_id": str(tmpl.get("zone", "")),
		"horror_intensity": int(tmpl.get("horror_intensity", 1)),
		"creature": str(tmpl.get("creature", "none")),
		"arc_delta": tmpl.get("arc_delta", {}),
	}


# ── Helpers ─────────────────────────────────────────────────────────────────

func _display_name(npc_id: String) -> String:
	return GameState.npc_states.get(npc_id, {}).get("name", npc_id.capitalize())


func _first_named_npc(npc_ids: Array) -> String:
	for n in npc_ids:
		if GameState.npc_states.has(str(n)):
			return str(n)
	return str(npc_ids[0]) if not npc_ids.is_empty() else ""


func _npc_in_zone(zone_id: String) -> String:
	# Whoever is assigned to that zone tonight (uses the frozen night roster).
	var roster: Dictionary = GameState.night_roster
	for npc_id in roster:
		if str(roster[npc_id]) == zone_id:
			return str(npc_id)
	# Fall back to daytime assignment.
	for npc_id in GameState.npc_states:
		if str(GameState.npc_states[npc_id].get("zone", "")) == zone_id:
			return str(npc_id)
	return ""


func _building_cause_chain(zone_id: String, day: int) -> Array:
	# Find the place_building choice for this zone/day to anchor the thread.
	for c in GameState.choices_for_day(day):
		if str(c["action_type"]) == "place_building" and str(c["choice_payload"].get("zone_id", "")) == zone_id:
			return [str(c["choice_id"])]
	return []


func _npc_cause_chain(npc_id: String) -> Array:
	# Most recent choice referencing this NPC — keeps the thread traceable.
	var chain: Array = []
	for c in GameState.choice_log:
		if c["npc_ids"].has(npc_id):
			chain = [str(c["choice_id"])]
	return chain
