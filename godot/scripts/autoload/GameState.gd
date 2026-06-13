extends Node
## GameState — the GDScript equivalent of backend/models.py SessionState.
##
## Holds the authoritative session state for the offline slice: current day/phase,
## DEBT level, the six named NPCs (with arc_state + gossip disposition), the three
## factions (with standing + memory), the five zones, and the player choice log.
##
## This mirrors the backend dataclasses (SessionState, NPCState, ChoiceEntry,
## NightEvent) as Dictionaries so the rule passes in scripts/systems/ can read the
## same field names the Python passes do. Where the backend talks to DynamoDB, this
## slice keeps everything in memory — there is no cloud and no LLM (see README).
##
## Pillar 2 (The Watched Feeling): named NPCs with arcs + factions with memory live here.
## Pillar 3 (Moral Weight): every logistics choice is appended to choice_log with a moral_tier.

# ── Phase / arc enums kept as String constants so they round-trip to the backend names ──
const ARC_SETTLING := "settling"
const ARC_PRESENT := "present"
const ARC_CONTRIBUTING := "contributing"
const ARC_FUNCTIONAL := "functional"
const ARC_FRAGILE := "fragile"
const ARC_BROKEN := "broken"

# Emotional states the NPC sprite can swap between (GRAPHICS.md State-Driven Visuals).
const EMOTION_NEUTRAL := "neutral"
const EMOTION_AFRAID := "afraid"
const EMOTION_ANGRY := "angry"
const EMOTION_CORRUPTED := "corrupted"

# ── Session-level state (mirrors SessionState) ──────────────────────────────
var player_id: String = "local_player"
var current_chapter: int = 1
var current_day: int = 1
var current_phase: String = "day"          # day | dusk | night | dawn
var debt: float = 0.0                       # 0.0..1.0 — the DEBT level (TIME_SYSTEM.md)
var season: String = "late_summer"
## anchor_name — the person the player character was going home to (WORLD_STATE §7).
## Optional; "someone" if skipped. Drives Ruth/Constance behavioral register only.
var anchor_name: String = "someone"
var anchor_erosion: float = 0.0

# ── NPC states keyed by npc_id (mirrors NPCState) ───────────────────────────
## Each value: {
##   npc_id, name, role, domain, arc_state, emotion, zone (current assignment),
##   gossip_disposition, bond_partner, bond_depth, injured, gone,
##   want, fear, is_faction_rep, faction_id
## }
var npc_states: Dictionary = {}

# ── Factions keyed by faction_id (mirrors RimWorld-style standing, Gap 3) ───
## Each value: { faction_id, name, standing (-1.0..1.0), memory:Array[String] }
var factions: Dictionary = {}

# ── Zones keyed by zone_id (WORLD_STATE §5) ─────────────────────────────────
## Each value: { zone_id, name, function, buildable, hollow_adjacent }
var zones: Dictionary = {}

# ── Choice log (mirrors list[ChoiceEntry]) ──────────────────────────────────
## Each entry: {
##   choice_id, player_id, day_cycle, phase, moral_tier, action_type,
##   npc_ids:Array[String], choice_payload:Dictionary,
##   consequence_ids:Array[String], debt_delta:float, chapter
## }
var choice_log: Array[Dictionary] = []

# ── Buildings placed this session ───────────────────────────────────────────
## Each: { building_type, zone_id, cell:Vector2i, day_placed }
var buildings: Array[Dictionary] = []

# ── Night event log for the current night (mirrors list[NightEvent]) ────────
var last_night_events: Array[Dictionary] = []

# ── Tonight's roster: { npc_id: zone_id } — used by the significance pass ────
var night_roster: Dictionary = {}

# ── Persistent flags (mirrors SessionState booleans) ────────────────────────
var compact_ratified: bool = false
var dix_approved: bool = false
var discrepancy_disclosed: bool = false
var thomas_spoke: bool = false
var constance_window_open: bool = false
var peder_foundation_excavated: bool = false
var zone5_marked: bool = false

# ── Investment anchor (computed at chapter end) ─────────────────────────────
var investment_anchor: String = ""

var _choice_counter: int = 0


func _ready() -> void:
	_init_zones()
	_init_factions()
	_init_npcs()


# ── World initialization (authored, frozen-doc faithful) ────────────────────

func _init_zones() -> void:
	# WORLD_STATE.md §5. Zone 5 has no player-facing build UI; buildable=false.
	zones = {
		"zone_1": {"zone_id": "zone_1", "name": "The Mill Quarter", "function": "Core production",
			"buildable": true, "hollow_adjacent": false},
		"zone_2": {"zone_id": "zone_2", "name": "The Settlement Common", "function": "Housing / faction meeting",
			"buildable": true, "hollow_adjacent": false},
		"zone_3": {"zone_id": "zone_3", "name": "The Eastern Ridge", "function": "Watchtower / perimeter",
			"buildable": true, "hollow_adjacent": false},
		"zone_4": {"zone_id": "zone_4", "name": "The Incomplete Structure", "function": "Active construction",
			"buildable": true, "hollow_adjacent": false},
		# Zone 5 is the falsely surveyed land. Building adjacent to it feeds the DEBT.
		# It is the only zone whose cells are hollow_adjacent for the Walker spawn rule.
		"zone_5": {"zone_id": "zone_5", "name": "The Western Hollow", "function": "Falsely surveyed land",
			"buildable": false, "hollow_adjacent": true},
	}


func _init_npcs() -> void:
	# Original six. Opening arc_state values are authored & fixed (WORLD_STATE §3b).
	npc_states = {
		"ruth": _make_npc("ruth", "Ruth Callan", "Mill foreman", "social", ARC_PRESENT,
			"selective_disclosure", "zone_1",
			"To finish the incomplete structure before first frost.",
			"That the new manager finds the ledger discrepancies first."),
		"thomas": _make_npc("thomas", "Thomas Vael", "Physician", "medicine", ARC_FUNCTIONAL,
			"pressure_valve", "zone_2",
			"To be considered competent.",
			"Something that exceeds his ability to explain medically."),
		"maren": _make_npc("maren", "Maren Voss", "Supply clerk", "logistics", ARC_PRESENT,
			"fear_activated", "zone_1",
			"To be assigned to the incomplete structure's completion.",
			"The ledger. She does not know if the previous manager knew."),
		"elias": _make_npc("elias", "Elias Grout", "Watchman", "observation", ARC_PRESENT,
			"bond_only", "zone_3",
			"To be believed about the treeline.",
			"That what he saw comes back and the player ignored his warning."),
		"constance": _make_npc("constance", "Constance Harrow", "Eldest resident", "none", ARC_CONTRIBUTING,
			"receiver_only", "zone_2",
			"To live out her years without the accounting she knows is coming.",
			"That someone asks her directly what she knows."),
		"peder": _make_npc("peder", "Peder Lund", "Construction lead", "construction", ARC_CONTRIBUTING,
			"environmental_only", "zone_4",
			"Steady work — three people depend on his wages.",
			"Being ordered to dig the foundation deeper."),
	}
	# Faction representatives appear as named NPCs in the Settlement Common
	# (WORLD_STATE §4 / INTERACTION_MODEL §4). They are click-targets that open the
	# faction text-list, not NPCs you can assign — flagged with is_faction_rep.
	_add_faction_rep("rep_compact", "Compact Delegate", "compact")
	_add_faction_rep("rep_association", "Association Representative", "association")
	_add_faction_rep("rep_dix", "Field Agent Dix", "dix")


func _add_faction_rep(id: String, rep_name: String, faction_id: String) -> void:
	var rep := _make_npc(id, rep_name, factions_role(faction_id), "none", ARC_CONTRIBUTING,
		"receiver_only", "zone_2", "", "")
	rep["is_faction_rep"] = true
	rep["faction_id"] = faction_id
	npc_states[id] = rep


func factions_role(faction_id: String) -> String:
	match faction_id:
		"compact": return "The Harrow's Crossing Compact"
		"association": return "Kettle River Labour Association"
		"dix": return "County Surveyor's Office"
	return "Faction"


func _make_npc(id: String, npc_name: String, role: String, domain: String, arc: String,
		gossip: String, zone: String, want: String, fear: String) -> Dictionary:
	return {
		"npc_id": id,
		"name": npc_name,
		"role": role,
		"domain": domain,
		"arc_state": arc,
		"emotion": EMOTION_NEUTRAL,
		"gossip_disposition": gossip,
		"zone": zone,                 # current daytime assignment
		"bond_partner": "",
		"bond_depth": 0,
		"injured": false,
		"gone": false,
		"want": want,
		"fear": fear,
		"is_faction_rep": false,
		"faction_id": "",
		"is_arrival": false,
	}


func _init_factions() -> void:
	# Three factions (WORLD_STATE §4). RimWorld-style single standing value + memory list.
	factions = {
		"compact": {"faction_id": "compact", "name": "The Harrow's Crossing Compact",
			"standing": 0.2, "memory": []},        # opening: welcoming
		"association": {"faction_id": "association", "name": "The Kettle River Labour Association",
			"standing": 0.0, "memory": []},        # opening: reserved
		"dix": {"faction_id": "dix", "name": "County Surveyor's Office (Field Agent Dix)",
			"standing": 0.0, "memory": []},        # opening: professional
	}


# ── Capability check (mirrors NPCState.is_capable) ──────────────────────────

func npc_is_capable(npc_id: String) -> bool:
	var n: Dictionary = npc_states.get(npc_id, {})
	if n.is_empty():
		return false
	return not n.get("gone", false) and n.get("arc_state", "") != ARC_BROKEN


# ── Choice logging (mirrors ChoiceEntry construction) ───────────────────────

## Append a choice to the log and apply its debt delta. Emits EventBus.choice_made.
## moral_tier: "micro" | "mid" | "macro". action_type matches the backend
## ACTION_TYPE_DESCRIPTIONS / load_day_observations keys where a thread is wanted.
func log_choice(action_type: String, moral_tier: String, npc_ids: Array,
		payload: Dictionary = {}, debt_delta: float = 0.0) -> Dictionary:
	_choice_counter += 1
	var typed_ids: Array[String] = []
	for i in npc_ids:
		typed_ids.append(str(i))
	var entry := {
		"choice_id": "c%03d" % _choice_counter,
		"player_id": player_id,
		"day_cycle": current_day,
		"phase": current_phase,
		"moral_tier": moral_tier,
		"action_type": action_type,
		"npc_ids": typed_ids,
		"choice_payload": payload,
		"consequence_ids": [] as Array[String],
		"debt_delta": debt_delta,
		"chapter": current_chapter,
	}
	choice_log.append(entry)
	debt = clampf(debt + debt_delta, 0.0, 1.0)
	if payload.has("anchor_erosion_delta"):
		anchor_erosion = clampf(anchor_erosion + float(payload["anchor_erosion_delta"]), 0.0, 1.0)
	EventBus.choice_made.emit(entry)
	return entry


## Returns choices made on a given day (helper for the gossip pass).
func choices_for_day(day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in choice_log:
		if int(c["day_cycle"]) == day:
			out.append(c)
	return out


# ── DEBT (TIME_SYSTEM.md DEBT Level — driven locally instead of from backend) ─

func get_debt_level() -> float:
	return debt


# ── NPC mutation helpers used by the rule passes & UI ───────────────────────

func set_npc_arc(npc_id: String, arc: String) -> void:
	if npc_states.has(npc_id):
		npc_states[npc_id]["arc_state"] = arc


func set_npc_emotion(npc_id: String, emotion: String) -> void:
	if npc_states.has(npc_id):
		npc_states[npc_id]["emotion"] = emotion


func assign_npc(npc_id: String, zone_id: String) -> void:
	if npc_states.has(npc_id):
		npc_states[npc_id]["zone"] = zone_id


func set_bond(a: String, b: String, depth: int = 1) -> void:
	if npc_states.has(a):
		npc_states[a]["bond_partner"] = b
		npc_states[a]["bond_depth"] = depth
	if npc_states.has(b):
		npc_states[b]["bond_partner"] = a
		npc_states[b]["bond_depth"] = depth


func adjust_faction(faction_id: String, delta: float, memory_note: String = "") -> void:
	if not factions.has(faction_id):
		return
	factions[faction_id]["standing"] = clampf(factions[faction_id]["standing"] + delta, -1.0, 1.0)
	if memory_note != "":
		factions[faction_id]["memory"].append("Day %d: %s" % [current_day, memory_note])
