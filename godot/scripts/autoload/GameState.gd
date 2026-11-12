extends Node
## GameState — authoritative session state (Autoload singleton).
##
## The GDScript equivalent of backend/models.py SessionState, extended to carry the
## whole of Chapter 1: five days of choices, the six named NPCs and every arrival,
## the three factions, stockpiles, buildings, the creatures that are standing in the
## township, and the story flags the chapter beats read.
##
## Everything here is plain data (Dictionaries / Arrays of built-in types) so that
## to_dict()/from_dict() can round-trip the session through SaveSystem, and so the
## rule passes in scripts/sim/ can be driven headlessly by the test suite.
##
## Pillar 2 (The Watched Feeling): named NPCs with arcs + factions with memory live here.
## Pillar 3 (Moral Weight): every logistics action lands in choice_log with a moral_tier.

const ARC_SETTLING := "settling"
const ARC_PRESENT := "present"
const ARC_CONTRIBUTING := "contributing"
const ARC_FUNCTIONAL := "functional"
const ARC_FRAGILE := "fragile"
const ARC_BROKEN := "broken"

## Worst -> best. "settling" sits beside "functional" for comparison purposes.
const ARC_LADDER := ["broken", "fragile", "functional", "present", "contributing"]

const EMOTION_NEUTRAL := "neutral"
const EMOTION_AFRAID := "afraid"
const EMOTION_ANGRY := "angry"
const EMOTION_CORRUPTED := "corrupted"

const ZONE_IDS := ["zone_1", "zone_2", "zone_3", "zone_4", "zone_5"]
const ORIGINAL_SIX := ["ruth", "thomas", "maren", "elias", "constance", "peder"]

## Hidden floor (NPC_INFLOW_PRODUCTIVITY): at least this many named people stay capable.
const POPULATION_FLOOR := 4

# ── Session ─────────────────────────────────────────────────────────────────
var player_id: String = "local_player"
var current_chapter: int = 1
var current_day: int = 1
var current_phase: String = "day"          # day | dusk | night | dawn
var debt: float = 0.0                       # 0.0..1.0 — THE DEBT
var season: String = "late_summer"
var anchor_name: String = "someone"         # WORLD_STATE §7
var anchor_erosion: float = 0.0
var chapter_complete: bool = false

# ── People, factions, places ────────────────────────────────────────────────
var npc_states: Dictionary = {}
var factions: Dictionary = {}
var zones: Dictionary = {}

# ── The record ──────────────────────────────────────────────────────────────
var choice_log: Array = []
var _choice_counter: int = 0

# ── The township ────────────────────────────────────────────────────────────
## Each: { id, building_type, zone_id, cell:[x,y], day_placed, order, state }
## state: pristine | damaged | destroyed
var buildings: Array = []
## { timber|provisions|oil: { ledger:int, count:int } }
var stockpiles: Dictionary = {}
## Ledger Watcher sources. Each: { id, choice_id, stockpile, watchers, disclosed, day }
var discrepancies: Array = []
## Hollow Walkers that exist. Each: { id, choice_id, zone_id, day_spawned, active, cleared }
var walkers: Array = []
## Walker sources not yet walking (the delay is the horror). Each: { choice_id, from_night }
var walker_queue: Array = []
var structure_walls: int = 3
var wall_progress: float = 0.0
var clearings: Array = []                   # "west" | "east"
var treeline_advance: int = 0               # yards, cumulative

# ── Day-to-day ──────────────────────────────────────────────────────────────
var crew_order: Dictionary = {}             # today's order for Peder's crew
var crew_unavailable_days: Array = []       # days the Compact holds the crew
var built_today: int = 0
## Tonight's roster: post_id -> npc_id ("" when empty).
var night_posts: Dictionary = {}
## post_id -> one-descriptor outcome of the last night ("quiet", "Walker reached here").
var post_history: Dictionary = {}
## Consecutive days two people have shared a day zone: "a|b" -> int.
var cozone_days: Dictionary = {}
var flags: Dictionary = {}
var beats_done: Dictionary = {}
## Open one-round faction asks: faction_id -> ask_id.
var open_asks: Dictionary = {}
var faction_last_contact: Dictionary = {}
var arrival_order: Array = []               # npc ids of arrivals, in order
var dawn_unlocks: Array = []                # active day_unlock ids for today

# ── Night / dawn ────────────────────────────────────────────────────────────
var night_queue: Array = []                 # tonight's precomputed events
var night_result: Dictionary = {}           # tonight's precomputed outcome
var last_night_events: Array = []
var night_roster: Dictionary = {}           # npc_id -> zone_id (for the significance pass)
var all_night_events: Array = []
var dawn_threads: Dictionary = {}           # day -> Array of entries
var arc_history: Array = []                 # { day, phase, npc_id, from, to, choice_id }
var surveyor: Dictionary = {}               # { seen_by:[], paused:bool, marked:bool }
var log_lines: Array = []                   # narrative log, persisted

# ── Mirrors of backend SessionState booleans ───────────────────────────────
var compact_ratified: bool = false
var dix_approved: bool = false
var discrepancy_disclosed: bool = false
var thomas_spoke: bool = false
var constance_window_open: bool = false
var peder_foundation_excavated: bool = false
var zone5_marked: bool = false
var investment_anchor: String = ""


func _ready() -> void:
	reset()


## Fresh session. Called at boot and by "begin" on the title screen.
func reset() -> void:
	player_id = "local_player"
	current_chapter = 1
	current_day = 1
	current_phase = "day"
	debt = 0.0
	season = "late_summer"
	anchor_name = "someone"
	anchor_erosion = 0.0
	chapter_complete = false
	choice_log = []
	_choice_counter = 0
	buildings = []
	discrepancies = []
	walkers = []
	walker_queue = []
	structure_walls = 3
	wall_progress = 0.0
	clearings = []
	treeline_advance = 0
	crew_order = {}
	crew_unavailable_days = []
	built_today = 0
	night_posts = {}
	post_history = {}
	cozone_days = {}
	flags = {}
	beats_done = {}
	open_asks = {}
	faction_last_contact = {"compact": 1, "association": 1, "dix": 1}
	arrival_order = []
	dawn_unlocks = []
	night_queue = []
	night_result = {}
	last_night_events = []
	night_roster = {}
	all_night_events = []
	dawn_threads = {}
	arc_history = []
	surveyor = {"seen_by": [], "paused": false, "marked": false, "walked": []}
	log_lines = []
	compact_ratified = false
	dix_approved = false
	discrepancy_disclosed = false
	thomas_spoke = false
	constance_window_open = false
	peder_foundation_excavated = false
	zone5_marked = false
	investment_anchor = ""
	for m in ["knowledge_states", "gossip_transfers", "significance_map", "object_significance"]:
		if has_meta(m):
			remove_meta(m)
	_init_zones()
	_init_factions()
	_init_npcs()
	_init_stockpiles()


func _init_zones() -> void:
	zones = {
		"zone_1": {"zone_id": "zone_1", "name": "The Mill Quarter", "short": "Mill Quarter",
			"buildable": true, "hollow_adjacent": false},
		"zone_2": {"zone_id": "zone_2", "name": "The Settlement Common", "short": "Settlement Common",
			"buildable": true, "hollow_adjacent": false},
		"zone_3": {"zone_id": "zone_3", "name": "The Eastern Ridge", "short": "Eastern Ridge",
			"buildable": true, "hollow_adjacent": false},
		# The hollow-facing build site. Anything raised here is adjacent to Zone 5.
		"zone_4": {"zone_id": "zone_4", "name": "The Incomplete Structure", "short": "Incomplete Structure",
			"buildable": true, "hollow_adjacent": true},
		"zone_5": {"zone_id": "zone_5", "name": "The Western Hollow", "short": "Western Hollow",
			"buildable": false, "hollow_adjacent": true},
	}


func _init_factions() -> void:
	factions = {
		"compact": {"faction_id": "compact", "name": "The Harrow's Crossing Compact",
			"rep": "Compact Delegate", "standing": 0.2, "memory": []},
		"association": {"faction_id": "association", "name": "The Kettle River Labour Association",
			"rep": "Association Representative", "standing": 0.0, "memory": []},
		"dix": {"faction_id": "dix", "name": "The County Surveyor's Office",
			"rep": "Field Agent Dix", "standing": 0.0, "memory": []},
	}


func _init_npcs() -> void:
	# Opening arc states are authored and fixed (WORLD_STATE §3b).
	npc_states = {
		"ruth": make_npc("ruth", "Ruth Callan", "Mill foreman", "social", ARC_PRESENT,
			"selective_disclosure", "zone_1"),
		"thomas": make_npc("thomas", "Thomas Vael", "Physician", "medicine", ARC_FUNCTIONAL,
			"pressure_valve", "zone_2"),
		"maren": make_npc("maren", "Maren Voss", "Supply clerk", "logistics", ARC_PRESENT,
			"fear_activated", "zone_1"),
		"elias": make_npc("elias", "Elias Grout", "Watchman", "observation", ARC_PRESENT,
			"bond_only", "zone_3"),
		"constance": make_npc("constance", "Constance Harrow", "Eldest resident", "none", ARC_CONTRIBUTING,
			"receiver_only", "zone_2"),
		"peder": make_npc("peder", "Peder Lund", "Construction lead", "construction", ARC_CONTRIBUTING,
			"environmental_only", "zone_4"),
	}
	for id in ORIGINAL_SIX:
		npc_states[id]["opening_arc"] = npc_states[id]["arc_state"]
	# Elias holds the eastern ridge overnight rotation when the player arrives.
	night_posts = {"post_ridge": "elias"}


func make_npc(id: String, npc_name: String, role: String, domain: String, arc: String,
		gossip: String, zone: String) -> Dictionary:
	return {
		"npc_id": id,
		"name": npc_name,
		"first": npc_name.split(" ")[0],
		"role": role,
		"domain": domain,
		"depth": "practiced",
		"arc_state": arc,
		"opening_arc": arc,
		"emotion": EMOTION_NEUTRAL,
		"gossip_disposition": gossip,
		"zone": zone,
		"zone_days": 0,               # consecutive days in the current day zone
		"bond_partner": "",
		"bond_depth": 0,
		"bond_acknowledged": false,
		"injured": false,
		"gone": false,
		"saw_surveyor": false,
		"is_arrival": false,
		"arrival_day": 0,
		"settling_path": "",
		"housed_near": "",
		"role_assigned": false,
		"conversation": "",           # "" | "asked" | "promised"
		"output": 1.0,
		"object_shown": false,
	}


func _init_stockpiles() -> void:
	# "Three resource stockpiles are lower than the handover ledger shows."
	stockpiles = {
		"timber": {"ledger": 120, "count": 96, "name": "Cut timber"},
		"provisions": {"ledger": 84, "count": 63, "name": "Provisions"},
		"oil": {"ledger": 40, "count": 30, "name": "Lamp oil"},
	}


# ── Queries ─────────────────────────────────────────────────────────────────

func npc(npc_id: String) -> Dictionary:
	return npc_states.get(npc_id, {})


func npc_name(npc_id: String) -> String:
	return str(npc_states.get(npc_id, {}).get("name", npc_id.capitalize()))


func npc_first(npc_id: String) -> String:
	return str(npc_states.get(npc_id, {}).get("first", npc_id.capitalize()))


func zone_name(zone_id: String) -> String:
	return str(zones.get(zone_id, {}).get("name", zone_id))


func zone_short(zone_id: String) -> String:
	return str(zones.get(zone_id, {}).get("short", zone_id))


func npc_is_present(npc_id: String) -> bool:
	var n: Dictionary = npc_states.get(npc_id, {})
	return not n.is_empty() and not bool(n.get("gone", false))


func npc_is_capable(npc_id: String) -> bool:
	var n: Dictionary = npc_states.get(npc_id, {})
	if n.is_empty():
		return false
	return not bool(n.get("gone", false)) and str(n.get("arc_state", "")) != ARC_BROKEN


func capable_count() -> int:
	var c := 0
	for id in npc_states:
		if npc_is_capable(id):
			c += 1
	return c


func present_ids() -> Array:
	var out: Array = []
	for id in npc_states:
		if npc_is_present(id):
			out.append(id)
	return out


func arc_rank(arc: String) -> int:
	if arc == ARC_SETTLING:
		return 2
	return ARC_LADDER.find(arc)


func has_flag(f: String) -> bool:
	return bool(flags.get(f, false))


func set_flag(f: String, v: Variant = true) -> void:
	flags[f] = v


func choices_for_day(day: int) -> Array:
	var out: Array = []
	for c in choice_log:
		if int(c["day_cycle"]) == day:
			out.append(c)
	return out


func find_choice(action_type: String, day: int = -1) -> Dictionary:
	for i in range(choice_log.size() - 1, -1, -1):
		var c: Dictionary = choice_log[i]
		if str(c["action_type"]) == action_type and (day < 0 or int(c["day_cycle"]) == day):
			return c
	return {}


func has_choice(action_type: String, day: int = -1) -> bool:
	return not find_choice(action_type, day).is_empty()


func choice_by_id(choice_id: String) -> Dictionary:
	for c in choice_log:
		if str(c["choice_id"]) == choice_id:
			return c
	return {}


## Most recent choice naming this NPC (optionally of a given action type).
func last_choice_for_npc(npc_id: String, action_type: String = "") -> Dictionary:
	for i in range(choice_log.size() - 1, -1, -1):
		var c: Dictionary = choice_log[i]
		if c["npc_ids"].has(npc_id) and (action_type == "" or str(c["action_type"]) == action_type):
			return c
	return {}


func standing_buildings() -> Array:
	var out: Array = []
	for b in buildings:
		if str(b["state"]) != "destroyed":
			out.append(b)
	return out


func building_by_id(id: String) -> Dictionary:
	for b in buildings:
		if str(b["id"]) == id:
			return b
	return {}


func npcs_in_zone(zone_id: String) -> Array:
	var out: Array = []
	for id in npc_states:
		if npc_is_present(id) and str(npc_states[id]["zone"]) == zone_id:
			out.append(id)
	return out


func post_of(npc_id: String) -> String:
	for post_id in night_posts:
		if str(night_posts[post_id]) == npc_id:
			return str(post_id)
	return ""


func active_watchers() -> int:
	var n := 0
	for d in discrepancies:
		if not bool(d["disclosed"]):
			n += int(d["watchers"])
	return n


func undisclosed_sources() -> Array:
	var out: Array = []
	for d in discrepancies:
		if not bool(d["disclosed"]):
			out.append(d)
	return out


# ── Mutation ────────────────────────────────────────────────────────────────

## Append a choice to the log, apply its DEBT delta, emit EventBus.choice_made.
func log_choice(action_type: String, moral_tier: String, npc_ids: Array,
		payload: Dictionary = {}, debt_delta: float = 0.0) -> Dictionary:
	_choice_counter += 1
	var ids: Array = []
	for i in npc_ids:
		if str(i) != "":
			ids.append(str(i))
	var entry := {
		"choice_id": "c%03d" % _choice_counter,
		"player_id": player_id,
		"day_cycle": current_day,
		"phase": current_phase,
		"moral_tier": moral_tier,
		"action_type": action_type,
		"npc_ids": ids,
		"choice_payload": payload,
		"consequence_ids": [],
		"debt_delta": debt_delta,
		"chapter": current_chapter,
	}
	choice_log.append(entry)
	add_debt(debt_delta)
	if payload.has("anchor_erosion_delta"):
		anchor_erosion = clampf(anchor_erosion + float(payload["anchor_erosion_delta"]), 0.0, 1.0)
	EventBus.choice_made.emit(entry)
	return entry


func add_debt(delta: float) -> void:
	debt = clampf(debt + delta, 0.0, 1.0)


func anchor_state() -> String:
	if anchor_erosion >= 0.3:
		return "hollow"
	if anchor_erosion >= 0.1:
		return "degrading"
	return "intact"


func assign_npc(npc_id: String, zone_id: String) -> void:
	if npc_states.has(npc_id) and str(npc_states[npc_id]["zone"]) != zone_id:
		npc_states[npc_id]["zone"] = zone_id
		npc_states[npc_id]["zone_days"] = 0


func set_npc_emotion(npc_id: String, emotion: String) -> void:
	if npc_states.has(npc_id):
		npc_states[npc_id]["emotion"] = emotion


## Move an NPC's arc by `delta` rungs, honouring the hidden population floor.
## Returns the new arc state. Every change is recorded in arc_history with the
## choice that caused it, so the final dawn thread can name it.
func shift_arc(npc_id: String, delta: int, choice_id: String = "", floor_arc: String = "") -> String:
	if not npc_states.has(npc_id) or delta == 0:
		return str(npc_states.get(npc_id, {}).get("arc_state", ""))
	var n: Dictionary = npc_states[npc_id]
	var from := str(n["arc_state"])
	var rank := arc_rank(from)
	var target := clampi(rank + delta, 0, ARC_LADDER.size() - 1)
	if floor_arc != "":
		target = maxi(target, arc_rank(floor_arc))
	# Hidden floor: breaking this person must not drop the township below four capable.
	if target == 0 and from != ARC_BROKEN and capable_count() <= POPULATION_FLOOR:
		target = 1
	var to: String = ARC_LADDER[target]
	if to == from:
		return from
	n["arc_state"] = to
	arc_history.append({"day": current_day, "phase": current_phase, "npc_id": npc_id,
		"from": from, "to": to, "choice_id": choice_id})
	_propagate_bond_loss(npc_id, to, choice_id)
	return to


func set_npc_gone(npc_id: String, choice_id: String = "") -> bool:
	if not npc_states.has(npc_id):
		return false
	if capable_count() <= POPULATION_FLOOR:
		return false
	var n: Dictionary = npc_states[npc_id]
	arc_history.append({"day": current_day, "phase": current_phase, "npc_id": npc_id,
		"from": str(n["arc_state"]), "to": "gone", "choice_id": choice_id})
	n["gone"] = true
	for post_id in night_posts.keys():
		if str(night_posts[post_id]) == npc_id:
			night_posts[post_id] = ""
	_propagate_bond_loss(npc_id, "gone", choice_id)
	return true


## If one of a bonded pair breaks or is lost, the survivor takes a hit
## proportional to bond depth. No warning is given (NPC_INFLOW_PRODUCTIVITY).
func _propagate_bond_loss(npc_id: String, new_state: String, choice_id: String) -> void:
	if new_state != ARC_BROKEN and new_state != "gone":
		return
	var partner := str(npc_states[npc_id].get("bond_partner", ""))
	if partner == "" or not npc_is_capable(partner):
		return
	var depth := int(npc_states[partner].get("bond_depth", 0))
	npc_states[partner]["bond_partner"] = ""
	npc_states[npc_id]["bond_partner"] = ""
	var hit := 1 if depth <= 2 else 2
	set_flag("bond_loss_%s" % partner, npc_id)
	shift_arc(partner, -hit, choice_id)
	set_npc_emotion(partner, EMOTION_AFRAID)


func set_bond(a: String, b: String, depth: int = 1) -> void:
	if npc_states.has(a) and npc_states.has(b):
		npc_states[a]["bond_partner"] = b
		npc_states[a]["bond_depth"] = depth
		npc_states[b]["bond_partner"] = a
		npc_states[b]["bond_depth"] = depth


func adjust_faction(faction_id: String, delta: float, memory_note: String = "") -> void:
	if not factions.has(faction_id):
		return
	factions[faction_id]["standing"] = clampf(float(factions[faction_id]["standing"]) + delta, -1.0, 1.0)
	if memory_note != "":
		factions[faction_id]["memory"].append("Day %d: %s" % [current_day, memory_note])
	faction_last_contact[faction_id] = current_day


func add_stock(kind: String, delta: int) -> void:
	if stockpiles.has(kind):
		stockpiles[kind]["count"] = maxi(0, int(stockpiles[kind]["count"]) + delta)


func stock(kind: String) -> int:
	return int(stockpiles.get(kind, {}).get("count", 0))


func add_log(text: String, kind: String = "plain") -> void:
	log_lines.append({"text": text, "kind": kind, "day": current_day, "phase": current_phase})
	if log_lines.size() > 400:
		log_lines.pop_front()
	EventBus.log_line.emit(text, kind)


# ── Serialization ───────────────────────────────────────────────────────────

const _SAVE_FIELDS := [
	"player_id", "current_chapter", "current_day", "current_phase", "debt", "season",
	"anchor_name", "anchor_erosion", "chapter_complete", "npc_states", "factions",
	"choice_log", "_choice_counter", "buildings", "stockpiles", "discrepancies", "walkers",
	"walker_queue", "structure_walls", "wall_progress", "clearings", "treeline_advance",
	"crew_order", "crew_unavailable_days", "built_today", "night_posts", "post_history",
	"cozone_days", "flags", "beats_done", "open_asks", "faction_last_contact",
	"arrival_order", "dawn_unlocks", "night_queue", "night_result", "last_night_events",
	"night_roster", "all_night_events", "dawn_threads", "arc_history", "surveyor",
	"log_lines", "compact_ratified", "dix_approved", "discrepancy_disclosed", "thomas_spoke",
	"constance_window_open", "peder_foundation_excavated", "zone5_marked", "investment_anchor",
]
const _SAVE_META := ["knowledge_states", "gossip_transfers", "significance_map", "object_significance"]


func to_dict() -> Dictionary:
	var d := {}
	for f in _SAVE_FIELDS:
		var v: Variant = get(f)
		if v is Dictionary or v is Array:
			v = v.duplicate(true)
		d[f] = v
	var meta := {}
	for m in _SAVE_META:
		if has_meta(m):
			meta[m] = get_meta(m).duplicate(true)
	d["_meta"] = meta
	return d


func from_dict(d: Dictionary) -> void:
	reset()
	for f in _SAVE_FIELDS:
		if d.has(f):
			var v: Variant = d[f]
			if v is Dictionary or v is Array:
				v = v.duplicate(true)
			set(f, v)
	var meta: Dictionary = d.get("_meta", {})
	for m in meta:
		set_meta(m, meta[m].duplicate(true))
