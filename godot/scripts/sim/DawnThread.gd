class_name DawnThread
extends RefCounted
## DawnThread — the dawn consequence thread (REVEAL_MECHANIC.md, Option B).
##
## Port of backend/consequence/thread_generator.py. For each person whose night is
## traceable to a specific day choice: two declarative sentences. Sentence 1 names
## the choice. Sentence 2 names the outcome. No "because". No evaluation. The
## player assembles the meaning. A quiet night produces nothing — no thread is ever
## manufactured, because a fabricated causal chain teaches a false grammar.
##
## On the final dawn the thread is the most complete it will ever be: everyone whose
## arc moved across the five days surfaces in it (CHAPTER_ONE Night 5 + Dawn).
##
## Pillar 1 (Earned Dread): this is the legibility surface. Without it roughly a
## third of players never connect the night to the day (Gap 2).

const TIER_WEIGHTS := {"macro": 3, "mid": 2, "micro": 1}
const FORBIDDEN := ["because", "as a result", "therefore", "which meant", "so that"]

const FINAL_LINES := {
	"ruth": {
		"better": "Ruth Callan was at the fourth wall before first light. She put her hand flat on it and went to the mill.",
		"worse": "Ruth Callan gave the morning orders from the saw floor. She did not come to the manager's post for them.",
		"broken": "Ruth Callan did not give the morning orders. The crew waited, then gave them to each other.",
		"gone": "Ruth Callan's bunk is made. The photograph is not on the shelf.",
	},
	"thomas": {
		"better": "Thomas Vael wrote the spring entry into the infirmary log in full. He used the word he meant.",
		"worse": "Thomas Vael has not put the instruments away. He explains this to anyone who passes the door.",
		"broken": "Thomas Vael is treating no one. The annotated book is open to a page he has not turned.",
		"gone": "The infirmary is unlocked. Thomas Vael's coat is on the hook. He is not in it.",
	},
	"maren": {
		"better": "Maren Voss logged the morning count in one book. She closed it without looking for the other.",
		"worse": "Maren Voss logged the morning count twice. The figures agree. She checked them a third time.",
		"broken": "Maren Voss did not log the morning count. The pencil is on the page where she put it down.",
		"gone": "The supply post is open. The graduation programme is gone from the shelf above the ledger.",
	},
	"elias": {
		"better": "Elias Grout gave his report in whole sentences. Someone wrote it down while he was speaking.",
		"worse": "Elias Grout came down from the ridge and reported nothing. He is filling in a delivery clipboard.",
		"broken": "Elias Grout did not come down for the morning count. He is on the ridge, facing the wrong way.",
		"gone": "The eastern ridge lamp was burning at first light. Elias Grout was not under it.",
	},
	"constance": {
		"better": "Constance Harrow walked to the Common unprompted. She sat where the table had been.",
		"worse": "Constance Harrow was at her window before first light. She refers to this year by its number now.",
		"broken": "Constance Harrow has not come out. The survey case is on her step.",
		"gone": "Constance Harrow's door is open. The survey case is on her step.",
	},
	"peder": {
		"better": "Peder Lund walked the footings at first light and wrote down a load figure. He showed it to someone.",
		"worse": "Peder Lund has covered the foundation trench with boards. He has not said what the boards are for.",
		"broken": "Peder Lund has put down his tools. The three photographs are out on the sawhorse, face up.",
		"gone": "Peder Lund's tools are on the sawhorse, cleaned. The crew is waiting on an order.",
	},
	"_arrival": {
		"better": "{npc} was at {his} place before the mill started. No one had to show {him} where it was.",
		"worse": "{npc} used to ask each morning whether the road had been looked at. {He} did not ask this morning.",
		"broken": "{npc} is standing where the road ends. {He} has been there since the light came.",
		"gone": "{npc}'s bunk is empty. What {he} was carrying on arrival is on it.",
	},
}


static func sentence_one(choice: Dictionary) -> String:
	var at := str(choice.get("action_type", ""))
	if not Content.SENTENCE_ONE.has(at):
		return ""
	var ids: Array = choice.get("npc_ids", [])
	var payload: Dictionary = choice.get("choice_payload", {})
	var out := str(Content.SENTENCE_ONE[at])
	out = out.replace("{day}", str(int(choice["day_cycle"])))
	out = out.replace("{npc2}", GameState.npc_name(str(ids[1])) if ids.size() > 1 else "")
	out = out.replace("{npc}", GameState.npc_name(str(ids[0])) if ids.size() > 0 else "")
	out = out.replace("{zone}", GameState.zone_name(str(payload.get("zone_id", ""))))
	out = out.replace("{building}", str(payload.get("building_type", "building")))
	out = out.replace("{post}", "the " + str(payload.get("post_name", "post")).split(",")[0].replace("Eastern Ridge", "Eastern Ridge watchtower"))
	return out


## Reveal Test (REVEAL_MECHANIC §4): names a specific person and a specific choice,
## states without evaluating. Gate 3 (legible only because of what THIS player did)
## holds by construction: every entry is built from a logged choice of this session.
static func passes_reveal_test(s1: String, s2: String, npc_id: String) -> bool:
	if s1 == "" or s2 == "" or npc_id == "":
		return false
	if not s2.contains(GameState.npc_name(npc_id)):
		return false
	var both := (s1 + " " + s2).to_lower()
	for f in FORBIDDEN:
		if both.contains(f):
			return false
	return true


static func _entry_for_event(e: Dictionary) -> Dictionary:
	var npcs: Array = e.get("threat_npc_ids", [])
	if npcs.is_empty() or str(e.get("thread", "")) == "":
		return {}
	var npc_id := str(npcs[0])
	for cid in e.get("cause_chain", []):
		var c: Dictionary = GameState.choice_by_id(str(cid))
		if c.is_empty():
			continue
		var s1 := sentence_one(c)
		var s2 := str(e["thread"])
		if passes_reveal_test(s1, s2, npc_id):
			return {"npc_id": npc_id, "sentence_1": s1, "sentence_2": s2,
				"event_id": str(e.get("event_id", "")), "choice_id": str(c["choice_id"]),
				"intensity": int(e.get("horror_intensity", 1)), "hour": float(e.get("hour", 0.0)),
				"day_unlock": str(e.get("day_unlock", ""))}
	return {}


static func generate(day: int) -> Array:
	# One entry per consequenced person: the heaviest thing that reached them.
	var by_npc := {}
	for e in GameState.last_night_events:
		var entry := _entry_for_event(e)
		if entry.is_empty():
			continue
		var id := str(entry["npc_id"])
		if not by_npc.has(id) or int(entry["intensity"]) > int(by_npc[id]["intensity"]):
			by_npc[id] = entry
	var entries: Array = by_npc.values()
	entries.sort_custom(func(a, b): return float(a["hour"]) < float(b["hour"]))
	# Night 1 surfaces one consequence. Only one.
	if day == 1 and entries.size() > 1:
		entries.sort_custom(func(a, b): return int(a["intensity"]) > int(b["intensity"]))
		entries = [entries[0]]
	if day >= Chapter.LAST_DAY:
		entries.append_array(_final_entries(by_npc))
	return entries


## Everyone whose arc moved across five days, named with the choice that moved them.
static func _final_entries(already: Dictionary) -> Array:
	var out: Array = []
	var ids: Array = GameState.ORIGINAL_SIX.duplicate()
	ids.append_array(GameState.arrival_order)
	for id in ids:
		if already.has(id):
			continue
		var n: Dictionary = GameState.npc(id)
		var last: Dictionary = {}
		for h in GameState.arc_history:
			if str(h["npc_id"]) == id and str(h["choice_id"]) != "":
				last = h
		if last.is_empty():
			continue
		var kind := ""
		if bool(n["gone"]):
			kind = "gone"
		elif str(n["arc_state"]) == "broken":
			kind = "broken"
		elif bool(n["is_arrival"]):
			kind = "better" if GameState.arc_rank(str(last["to"])) > GameState.arc_rank(str(last["from"])) else "worse"
		else:
			var start := GameState.arc_rank(str(n["opening_arc"]))
			var now := GameState.arc_rank(str(n["arc_state"]))
			if now > start:
				kind = "better"
			elif now < start:
				kind = "worse"
		if kind == "":
			continue
		var c: Dictionary = GameState.choice_by_id(str(last["choice_id"]))
		if c.is_empty():
			continue
		var table: Dictionary = FINAL_LINES[id] if FINAL_LINES.has(id) else FINAL_LINES["_arrival"]
		var s1 := sentence_one(c)
		var s2 := Content.fill(str(table[kind]), id)
		if passes_reveal_test(s1, s2, id):
			out.append({"npc_id": id, "sentence_1": s1, "sentence_2": s2, "event_id": "",
				"choice_id": str(c["choice_id"]), "intensity": 2, "hour": 99.0, "day_unlock": ""})
	return out


## The last lines of the chapter. They state what is there. They do not say what it means.
static func closing_lines() -> Array:
	var out: Array = []
	out.append("The mill has started. No one gave the order.")
	if GameState.zone5_marked:
		out.append("There is a way into the western hollow this morning that no one here cut.")
	else:
		out.append("The western hollow is where it was.")
	var standing := 0
	for w in GameState.walkers:
		if not bool(w["cleared"]) and str(w["zone_id"]) != "zone_5":
			standing += 1
	if standing == 1:
		out.append("One of the trees inside the settlement was not planted there.")
	elif standing > 1:
		out.append("%s of the trees inside the settlement were not planted there." % ["Two", "Three", "Four", "Five", "Six", "Seven", "Eight"][clampi(standing - 2, 0, 6)])
	if GameState.active_watchers() > 0:
		out.append("The morning count has not been taken. The ledger is open to a page no one turned to.")
	out.append("The road in ends where it ended.")
	return out


## NPC investment anchor (CHAPTER_ONE "Required Output"): tier-weighted count of
## choices that named each person. Arrivals are eligible. Never shown to the player.
static func compute_investment_anchor() -> String:
	var scores := {}
	for c in GameState.choice_log:
		var w: int = TIER_WEIGHTS.get(str(c["moral_tier"]), 1)
		for id in c["npc_ids"]:
			if GameState.npc_states.has(str(id)):
				scores[str(id)] = int(scores.get(str(id), 0)) + w
	var best := ""
	var best_score := 0
	var ids: Array = scores.keys()
	ids.sort()
	for id in ids:
		# Chapter 2's false dawn needs someone who is there to open on.
		if not GameState.npc_is_present(str(id)):
			continue
		if int(scores[id]) > best_score:
			best_score = int(scores[id])
			best = str(id)
	return best
