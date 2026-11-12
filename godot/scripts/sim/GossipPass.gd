class_name GossipPass
extends RefCounted
## GossipPass — GDScript port of backend/gossip/propagation.py.
##
## Rule-based, no LLM. Runs at the day->night transition, before night events are
## selected. Three-stage model (1 nothing held, 2 holding, 3 transmitted). Transfer
## is stochastic but SEEDED per (player_id, day, from_npc, to_npc) so identical
## relationship conditions produce identical outcomes — faithful to the Python pass.
##
## Pillar 2 (The Watched Feeling): NPCs remember and pass what they know; the world
## reacts to what the player did, through the people in it.
##
## State is kept on GameState as a `knowledge_states` meta dictionary keyed by npc_id:
##   { npc_id: { held: Array[Dictionary], received_from: Dictionary,
##               gossip_stage: int, fear_active: bool } }
## Each observation: { observation_type, source_event_id, day_witnessed, zone_id }

# Gossip dispositions (mirrors GOSSIP_DISPOSITIONS in propagation.py).
# base_threshold: roll must be < threshold * trust for transfer to fire.
# trigger: gate before a transfer is even attempted.
const DISPOSITIONS := {
	"selective_disclosure": {"base_threshold": 0.25, "credibility_weight": 1.4, "trigger": "safety_concern"},
	"pressure_valve": {"base_threshold": 0.70, "credibility_weight": 0.85, "trigger": "fear_state"},
	"fear_activated": {"base_threshold": 0.00, "credibility_weight": 1.0, "trigger": "fear_activated"},
	"bond_only": {"base_threshold": 0.05, "credibility_weight": 1.2, "trigger": "bond_only"},
	"receiver_only": {"base_threshold": 0.00, "credibility_weight": 0.0, "trigger": "receiver_only"},
	"environmental_only": {"base_threshold": 0.15, "credibility_weight": 1.1, "trigger": "environmental_only"},
}

const DEFAULT_ARRIVAL := {"base_threshold": 0.40, "credibility_weight": 1.0, "trigger": "any"}


static func _meta() -> Dictionary:
	if not GameState.has_meta("knowledge_states"):
		GameState.set_meta("knowledge_states", {})
	return GameState.get_meta("knowledge_states")


static func _ensure(npc_id: String) -> Dictionary:
	var ks: Dictionary = _meta()
	if not ks.has(npc_id):
		ks[npc_id] = {"held": [], "received_from": {}, "gossip_stage": 1, "fear_active": false}
	return ks[npc_id]


static func _obs(otype: String, day: int, zone_id: String = "", source: String = "") -> Dictionary:
	return {"observation_type": otype, "source_event_id": source, "day_witnessed": day, "zone_id": zone_id}


# ── Trust (mirrors compute_trust) ───────────────────────────────────────────

static func compute_trust(from_id: String, to_id: String) -> float:
	var base := 0.4
	var from_npc: Dictionary = GameState.npc_states.get(from_id, {})
	if not from_npc.is_empty() and from_npc.get("bond_partner", "") == to_id:
		base += 0.2 + (int(from_npc.get("bond_depth", 0)) * 0.1)
	var to_npc: Dictionary = GameState.npc_states.get(to_id, {})
	if not to_npc.is_empty() and to_npc.get("bond_partner", "") == from_id:
		base = maxf(base, 0.4 + (int(to_npc.get("bond_depth", 0)) * 0.1))
	return minf(1.0, base)


# ── Candidate resolution (mirrors get_transmission_candidates) ──────────────

static func _disposition(npc_id: String) -> Dictionary:
	var npc: Dictionary = GameState.npc_states.get(npc_id, {})
	var key: String = npc.get("gossip_disposition", "")
	return DISPOSITIONS.get(key, DEFAULT_ARRIVAL)


static func get_candidates(from_id: String) -> Array[String]:
	var disp := _disposition(from_id)
	var trigger: String = disp["trigger"]
	var all_ids: Array[String] = []
	for k in GameState.npc_states.keys():
		all_ids.append(str(k))

	if trigger == "receiver_only":
		return [] as Array[String]

	if trigger == "bond_only":
		var npc: Dictionary = GameState.npc_states.get(from_id, {})
		var partner: String = npc.get("bond_partner", "")
		var bonded: Array[String] = []
		if partner != "":
			bonded.append(partner)
		return bonded

	if trigger == "environmental_only":
		var out: Array[String] = []
		for nid in all_ids:
			if nid == from_id:
				continue
			if GameState.npc_states.get(nid, {}).get("domain", "") == "construction":
				out.append(nid)
		return out

	# safety_concern, fear_state, fear_activated, any
	var rest: Array[String] = []
	for nid in all_ids:
		if nid != from_id:
			rest.append(nid)
	return rest


static func effective_threshold(from_id: String) -> float:
	var disp := _disposition(from_id)
	var threshold: float = disp["base_threshold"]
	var ks := _ensure(from_id)
	if disp["trigger"] == "fear_activated" and ks.get("fear_active", false):
		threshold = 0.65
	return threshold


# ── Seeded roll (mirrors seeded_roll: sha256 of key, first 4 bytes / 0xFFFFFFFF) ─

static func seeded_roll(player_id: String, day: int, from_id: String, to_id: String) -> float:
	var key := "%s:%d:%s:%s" % [player_id, day, from_id, to_id]
	var digest := key.sha256_buffer()
	var n: int = (int(digest[0]) << 24) | (int(digest[1]) << 16) | (int(digest[2]) << 8) | int(digest[3])
	return float(n) / float(0xFFFFFFFF)


# ── Observation loading (mirrors load_day_observations) ─────────────────────

static func load_day_observations(day: int, choices: Array, night_events: Array) -> void:
	# Elias: treeline observation when his report was logged.
	if _has_action(choices, "elias_report_logged", day):
		var e := _ensure("elias")
		e["held"].append(_obs("treeline_movement_witnessed", day, "zone_3"))
		e["gossip_stage"] = maxi(e["gossip_stage"], 2)

	# Maren: ledger cover / edit activates fear state -> Stage 2 + fear_active.
	if _has_action(choices, "association_ledger_edited", day) or _has_action(choices, "cover_discrepancy", day):
		var m := _ensure("maren")
		m["held"].append(_obs("ledger_discrepancy_knowledge", day))
		m["fear_active"] = true
		m["gossip_stage"] = maxi(m["gossip_stage"], 2)

	# Thomas: if arc is functional (unreported event weight), holds and may leak.
	var thomas: Dictionary = GameState.npc_states.get("thomas", {})
	if not thomas.is_empty() and thomas.get("arc_state", "") == "functional":
		var t := _ensure("thomas")
		if not _holds(t, "unreported_event_knowledge"):
			t["held"].append(_obs("unreported_event_knowledge", day))
			t["gossip_stage"] = maxi(t["gossip_stage"], 2)

	# Ruth: holds safety-relevant info when an Association interaction occurred.
	for c in choices:
		if int(c["day_cycle"]) == day and str(c["action_type"]).begins_with("association"):
			var r := _ensure("ruth")
			r["held"].append(_obs("association_situation_known", day))
			r["gossip_stage"] = maxi(r["gossip_stage"], 2)
			break

	# Night-event witnesses: any NPC in threat_npc_ids gets the horror observation.
	for ev in night_events:
		for npc_id in ev.get("threat_npc_ids", []):
			var ks := _ensure(str(npc_id))
			ks["held"].append(_obs("horror_witnessed_night%d" % int(ev.get("night", day)),
				day, str(ev.get("zone_id", "")), str(ev.get("event_id", ""))))
			ks["gossip_stage"] = maxi(ks["gossip_stage"], 2)

	_ensure("constance")
	_ensure("peder")


static func _has_action(choices: Array, action_type: String, day: int) -> bool:
	for c in choices:
		if str(c["action_type"]) == action_type and int(c["day_cycle"]) == day:
			return true
	return false


static func _holds(ks: Dictionary, otype: String) -> bool:
	for o in ks["held"]:
		if o["observation_type"] == otype:
			return true
	return false


# ── Main pass (mirrors run_pass) ────────────────────────────────────────────

## Returns an Array of fired transfers; mutates GameState's knowledge_states meta
## and appends to a `gossip_transfers` meta list (used by ConsequenceThread).
static func run_pass(day: int, choices: Array, night_events: Array) -> Array:
	load_day_observations(day, choices, night_events)

	if not GameState.has_meta("gossip_transfers"):
		GameState.set_meta("gossip_transfers", [])
	var transfers_log: Array = GameState.get_meta("gossip_transfers")

	var fired: Array = []
	var ks_map: Dictionary = _meta()

	for from_id in ks_map.keys():
		var ks: Dictionary = ks_map[from_id]
		if ks["gossip_stage"] < 2 or ks["held"].is_empty():
			continue
		var disp := _disposition(from_id)
		if disp["trigger"] == "receiver_only":
			continue

		var threshold := effective_threshold(from_id)
		var credibility: float = disp["credibility_weight"]
		for to_id in get_candidates(from_id):
			var trust := compute_trust(from_id, to_id)
			var roll := seeded_roll(GameState.player_id, day, from_id, to_id)
			if roll < threshold * trust:
				var recipient := _ensure(to_id)
				var transferred: Array = ks["held"].duplicate(true)
				for o in transferred:
					recipient["held"].append(o)
				if not recipient["received_from"].has(from_id):
					recipient["received_from"][from_id] = []
				recipient["received_from"][from_id].append_array(transferred)
				recipient["gossip_stage"] = maxi(recipient["gossip_stage"], 2)
				ks["gossip_stage"] = 3

				var transfer := {
					"day": day, "from_npc": from_id, "to_npc": to_id,
					"observations": transferred,
					"trust_weight": snappedf(trust, 0.001),
					"credibility_weight": snappedf(credibility, 0.001),
				}
				fired.append(transfer)
				transfers_log.append(transfer)

	return fired


## Compact {npc_id: [observation_type,...]} summary (mirrors knowledge_summary).
static func knowledge_summary() -> Dictionary:
	var result: Dictionary = {}
	for npc_id in _meta().keys():
		var types: Array = []
		for o in _meta()[npc_id]["held"]:
			if not types.has(o["observation_type"]):
				types.append(o["observation_type"])
		if not types.is_empty():
			result[npc_id] = types
	return result
