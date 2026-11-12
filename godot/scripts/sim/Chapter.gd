class_name Chapter
extends RefCounted
## Chapter — the rules of Chapter 1 (CHAPTER_ONE.md), as pure functions over GameState.
##
## This is the offline equivalent of backend/engine.py SessionEngine plus the
## authored beat structure: which faction asks open on which day, when arrivals
## reach the road's end, what each plain-text option does to the world, and what
## is resolved at dusk. Nothing in here touches a Node, so the test suite can play
## the whole five days headlessly through exactly the code path the UI uses:
##
##   begin_day -> tick_day(progress) -> [panel()/choose(), place_building(), set_post()]
##   -> begin_dusk -> begin_night -> begin_dawn        (x5)
##
## Pillar 3 (Moral Weight at Every Turn): every option here is described by what it
## is. No option carries a label for weight, risk, or moral category, and nothing
## is confirmed. The consequence is scheduled silently.

const LAST_DAY := 5
const SURVEYOR_MARK_DEBT := 0.5

## Scheduled beats: day -> [[progress 0..1, beat_id], ...]
const BEATS := {
	1: [[0.0, "d1_open"], [0.60, "d1_reception"]],
	2: [[0.0, "morning"], [0.14, "arrival_1"], [0.32, "ask_compact_surplus"], [0.52, "ask_association_ledger"]],
	3: [[0.0, "morning"], [0.12, "arrival_2"], [0.28, "ask_dix_inspection"], [0.55, "ask_compact_ratification"]],
	4: [[0.0, "morning"], [0.14, "ask_association_date"], [0.34, "compact_response"], [0.50, "arrival_3"]],
	5: [[0.0, "morning"], [0.50, "macro"], [0.88, "arrival_4"]],
}


# ═══════════════════════════════════════════════════════════════════════════
# Phase entry points
# ═══════════════════════════════════════════════════════════════════════════

static func begin_day(day: int) -> void:
	GameState.current_day = day
	GameState.current_phase = "day"
	GameState.crew_order = {}
	GameState.built_today = 0
	_evaluate_season(day)
	if day > 1:
		_heal_injured()
		_advance_settling()
	tick_day(0.0)


## Fire every scheduled beat whose time has come. Idempotent.
static func tick_day(progress: float) -> void:
	var day := GameState.current_day
	for beat in BEATS.get(day, []):
		var key := "%d_%s" % [day, beat[1]]
		if progress >= float(beat[0]) and not GameState.beats_done.has(key):
			GameState.beats_done[key] = true
			_fire_beat(str(beat[1]), day)


static func begin_dusk() -> void:
	var day := GameState.current_day
	tick_day(1.0)
	GameState.current_phase = "dusk"
	_close_open_asks(day)
	_log_omissions(day)
	_evening_briefing(day)
	GameState.add_log("The mill has stopped. The light is going.", "dusk")
	var lamps := GameState.stock("oil") / 2
	var staffed := 0
	for post_id in GameState.night_posts:
		if str(GameState.night_posts[post_id]) != "":
			staffed += 1
	if lamps < 6:
		GameState.add_log("There is oil for %s tonight." % _lamp_words(lamps), "dim")


static func begin_night() -> void:
	var day := GameState.current_day
	GameState.current_phase = "night"
	_resolve_crew(day)
	_production(day)
	_update_bonds(day)
	_settle_arrivals_at_dusk(day)
	_day5_promises(day)
	# Frozen roster for the significance pass: npc -> zone they stand in tonight.
	GameState.night_roster = {}
	for id in GameState.present_ids():
		var post_id := GameState.post_of(id)
		GameState.night_roster[id] = post_zone(post_id) if post_id != "" else "zone_2"
	GossipPass.run_pass(day, GameState.choices_for_day(day), [])
	NightSim.plan(day)


## Commits the night, runs the dawn passes, returns the consequence thread entries.
static func begin_dawn() -> Array:
	var day := GameState.current_day
	GameState.current_phase = "dawn"
	NightSim.commit(day)
	SignificancePass.run_dawn_pass(GameState.last_night_events, GameState.night_roster,
		GameState.choice_log, day)
	var entries: Array = DawnThread.generate(day)
	GameState.dawn_threads[day] = entries
	GameState.investment_anchor = DawnThread.compute_investment_anchor()
	_compute_dawn_unlocks(day)
	if day >= LAST_DAY:
		GameState.chapter_complete = true
	return entries


# ═══════════════════════════════════════════════════════════════════════════
# Beats
# ═══════════════════════════════════════════════════════════════════════════

static func _fire_beat(beat: String, day: int) -> void:
	match beat:
		"d1_open":
			GameState.add_log("Day 1.", "day")
			for l in Content.OPENING:
				GameState.add_log(l, "plain")
			GameState.add_log("Thomas Vael handed the ledger over at the door. He says it was because no one else was standing next to it.", "dim")
		"d1_reception":
			GameState.add_log("The Compact has set a table in the Common. Bread, preserves, eleven chairs. The delegate says the township is glad of a steady hand.", "plain")
			GameState.set_flag("reception_held")
			GameState.faction_last_contact["compact"] = 1
		"morning":
			_morning(day)
		"arrival_1":
			_spawn_arrival(1)
		"arrival_2":
			_spawn_arrival(2)
		"arrival_3":
			_spawn_arrival(3)
		"arrival_4":
			_spawn_arrival(4)
		"ask_compact_surplus":
			_open_ask("compact_surplus")
		"ask_association_ledger":
			_open_ask("association_ledger")
		"ask_dix_inspection":
			_open_ask("dix_inspection")
		"ask_compact_ratification":
			GameState.set_flag("survey_referenced")
			_open_ask("compact_ratification")
		"ask_association_date":
			_open_ask("association_date")
		"compact_response":
			_compact_response()
		"macro":
			_open_macro()


static func _open_ask(ask_id: String) -> void:
	var ask: Dictionary = Content.ASKS[ask_id]
	GameState.open_asks[str(ask["faction"])] = ask_id
	GameState.faction_last_contact[str(ask["faction"])] = GameState.current_day
	GameState.add_log(str(ask["log"]), "plain")
	EventBus.world_changed.emit()


static func _morning(day: int) -> void:
	GameState.add_log("Day %d." % day, "day")
	# What the night left standing, stated once, flat.
	for w in GameState.walkers:
		if not bool(w["cleared"]) and str(w["zone_id"]) != "zone_5":
			GameState.add_log("Something is standing in %s that the crew did not put there. It does not move in the light." % GameState.zone_name(str(w["zone_id"])), "plain")
			break
	for b in GameState.buildings:
		if int(b.get("state_day", 0)) == day - 1 and str(b["state"]) == "damaged":
			GameState.add_log("The %s at %s has a wall staved in. The timbers are bowed outward, not inward." % [str(b["building_type"]), GameState.zone_name(str(b["zone_id"]))], "plain")
		elif int(b.get("state_day", 0)) == day - 1 and str(b["state"]) == "destroyed":
			GameState.add_log("The %s at %s is down. The boards are stacked. No one stacked them." % [str(b["building_type"]), GameState.zone_name(str(b["zone_id"]))], "plain")
	# Covered discrepancy compounds by the next morning (WORLD_STATE causal grammar).
	if day == 2 and GameState.has_choice("ledger_carried_forward", 1) and not GameState.has_flag("second_discrepancy"):
		GameState.set_flag("second_discrepancy")
		var src: Dictionary = GameState.find_choice("ledger_carried_forward", 1)
		GameState.discrepancies.append({"id": "d_oil", "choice_id": str(src["choice_id"]),
			"stockpile": "oil", "watchers": 1, "disclosed": false, "day": 2, "label": "the lamp oil count"})
		GameState.add_log("The morning count of lamp oil does not match yesterday's entry. Maren Voss has written both figures down and drawn no line under either.", "plain")
	if GameState.has_flag("watchers_at_mill"):
		GameState.add_log("The saws were found set to a width no order calls for.", "dim")
	# Compact withdraws labour the day after a formal disclosure / inspection.
	if GameState.crew_unavailable_days.has(day):
		GameState.add_log("Peder Lund's crew is on Compact work today. Ruth Callan signed the reallocation. She did not bring it to the manager's post.", "plain")
	match day:
		3:
			if GameState.has_flag("dix_interviewing"):
				pass
		4:
			if GameState.season != "late_summer":
				_turning_events(day)
			_constance_window_check()
			if not GameState.has_flag("foundation_raised"):
				GameState.add_log("Peder Lund has the foundation drawings out on the sawhorse. The schedule says the footings are due.", "dim")
		5:
			if GameState.surveyor.get("walked", []).has(4):
				GameState.add_log("There are footprints at the boundary between the eastern ridge and the hollow. They lead in. They come back out.", "plain")
			if GameState.season != "late_summer" and not GameState.has_flag("turning_events_done"):
				_turning_events(day)
			_constance_window_check()
			_auto_excavation()
	_rations_check(day)


static func _turning_events(_day: int) -> void:
	GameState.set_flag("turning_events_done")
	GameState.add_log("The fog at the western treeline did not lift with the sun. It is not behaving like fog.", "plain")
	# Two NPCs report the same dream, independently. The player is told both, separately.
	var dreamers: Array = []
	for id in ["maren", "thomas", "ruth", "elias", "peder"]:
		if GameState.npc_is_capable(id):
			dreamers.append(id)
	for id in GameState.arrival_order:
		if GameState.npc_is_capable(id):
			dreamers.append(id)
	if dreamers.size() >= 2:
		GameState.set_flag("dream_a", dreamers[0])
		GameState.set_flag("dream_b", dreamers[dreamers.size() - 1])


static func _constance_window_check() -> void:
	if GameState.has_flag("constance_window") or GameState.has_flag("constance_asked"):
		return
	if not GameState.npc_is_capable("constance"):
		return
	# CHAPTER_ONE: survey reference encountered AND (Dix approved OR foundation raised).
	if GameState.has_flag("survey_met") and (GameState.dix_approved or GameState.has_flag("foundation_raised")):
		GameState.set_flag("constance_window")
		GameState.add_log("Constance Harrow is sitting outside the manager's post. She has not sat there before.", "plain")


static func _auto_excavation() -> void:
	if GameState.has_flag("foundation_raised") or GameState.peder_foundation_excavated:
		return
	if not GameState.npc_is_present("peder"):
		return
	GameState.peder_foundation_excavated = true
	GameState.set_flag("excavation_day", GameState.current_day)
	var c: Dictionary = GameState.find_choice("peder_foundation_unasked")
	var cid := str(c.get("choice_id", ""))
	GameState.add_debt(0.05)
	GameState.shift_arc("peder", -1, cid)
	GameState.set_npc_emotion("peder", GameState.EMOTION_AFRAID)
	GameState.add_log(Content.PEDER_EXCAVATION_AUTO, "plain")


static func _rations_check(day: int) -> void:
	if day < 3 or GameState.stock("provisions") >= 14 or GameState.has_flag("rations_%d" % day):
		return
	GameState.set_flag("rations_open", day)
	GameState.add_log("The stores will not cover a full issue today. Ruth Callan is waiting to be told who draws first.", "plain")


# ═══════════════════════════════════════════════════════════════════════════
# Season (TIME_SYSTEM.md). The doc's formula and its Season Map disagree and the
# author has not yet picked a fix; this follows the Season Map (the stated intent).
# ═══════════════════════════════════════════════════════════════════════════

static func target_season(day: int, debt: float) -> String:
	if debt >= 0.85:
		if day >= 4: return "deep_winter"
		if day >= 2: return "turning"
	elif debt >= 0.70:
		if day >= 5: return "deep_winter"
		if day >= 3: return "turning"
	elif debt >= 0.40:
		if day >= 4: return "turning"
	elif debt >= 0.20:
		if day >= 5: return "turning"
	return "late_summer"


static func _evaluate_season(day: int) -> void:
	const ORDER := ["late_summer", "turning", "deep_winter"]
	var target := target_season(day, GameState.debt)
	# Seasons do not turn back inside the chapter.
	if ORDER.find(target) > ORDER.find(GameState.season):
		GameState.season = target
		EventBus.season_changed.emit(target, clampf(GameState.debt, 0.0, 1.0))


static func night_length_multiplier() -> float:
	match GameState.season:
		"late_summer": return 0.85
		"deep_winter": return 1.25
	return 1.0


# ═══════════════════════════════════════════════════════════════════════════
# Posts (NIGHT_SURVIVAL — Night Watch Roster)
# ═══════════════════════════════════════════════════════════════════════════

## Every post that exists tonight. kind: tower | guard | perimeter.
## `hands` posts are covered by unnamed mill hands until the Association walks.
static func posts() -> Array:
	var out: Array = [
		{"id": "post_ridge", "name": "Eastern Ridge, the old watchtower", "zone_id": "zone_3", "kind": "tower", "hands": false},
		{"id": "post_west", "name": "Western perimeter, the cut line", "zone_id": "zone_4", "kind": "perimeter", "hands": false},
		{"id": "post_structure", "name": "Incomplete Structure, the open frame", "zone_id": "zone_4", "kind": "guard", "hands": false},
		{"id": "post_mill", "name": "Mill Quarter, the stores", "zone_id": "zone_1", "kind": "guard", "hands": true},
		{"id": "post_common", "name": "Settlement Common, the lamp round", "zone_id": "zone_2", "kind": "guard", "hands": true},
		{"id": "post_ledger", "name": "Manager's post, the ledger table", "zone_id": "zone_2", "kind": "guard", "hands": false},
		{"id": "post_road", "name": "The road, where it ends", "zone_id": "zone_2", "kind": "perimeter", "hands": false},
		{"id": "post_race", "name": "Mill race, the footbridge", "zone_id": "zone_1", "kind": "perimeter", "hands": false},
		{"id": "post_eastcut", "name": "Eastern cut line, below the ridge", "zone_id": "zone_3", "kind": "perimeter", "hands": false},
		{"id": "post_stumps", "name": "Southern stump field", "zone_id": "zone_4", "kind": "perimeter", "hands": false},
	]
	for b in GameState.standing_buildings():
		var kind := "tower" if str(b["building_type"]) == "Watchtower" else "guard"
		out.append({"id": "post_%s" % str(b["id"]),
			"name": "%s, %s" % [str(b["building_type"]), GameState.zone_short(str(b["zone_id"]))],
			"zone_id": str(b["zone_id"]), "kind": kind, "hands": false, "building_id": str(b["id"])})
	return out


static func post_by_id(post_id: String) -> Dictionary:
	for p in posts():
		if str(p["id"]) == post_id:
			return p
	return {}


static func post_zone(post_id: String) -> String:
	return str(post_by_id(post_id).get("zone_id", "zone_2"))


static func post_name(post_id: String) -> String:
	return str(post_by_id(post_id).get("name", post_id))


static func hands_cover(post: Dictionary) -> bool:
	return bool(post.get("hands", false)) and not GameState.has_flag("association_walked")


## People who can be put on the roster tonight.
static func rosterable() -> Array:
	var out: Array = []
	for id in GameState.npc_states:
		if id == "constance":
			continue
		if not GameState.npc_is_capable(id):
			continue
		var n: Dictionary = GameState.npc_states[id]
		if bool(n["is_arrival"]) and str(n.get("stage", "done")) == "housing":
			continue
		out.append(id)
	return out


static func roster_open() -> bool:
	return GameState.current_phase == "day" or GameState.current_phase == "dusk"


## Put `npc_id` on `post_id` ("" clears the post). One person per post, one post per person.
static func set_post(post_id: String, npc_id: String) -> void:
	if not roster_open() or post_by_id(post_id).is_empty():
		return
	var prev := str(GameState.night_posts.get(post_id, ""))
	if prev == npc_id:
		return
	if npc_id == "":
		GameState.night_posts[post_id] = ""
		_log_roster_choice("post_cleared", prev, post_id)
		EventBus.world_changed.emit()
		return
	if not rosterable().has(npc_id):
		return
	for other in GameState.night_posts.keys():
		if str(GameState.night_posts[other]) == npc_id:
			GameState.night_posts[other] = ""
	GameState.night_posts[post_id] = npc_id
	_log_roster_choice("post_npc", npc_id, post_id)
	var n: Dictionary = GameState.npc_states[npc_id]
	if bool(n["is_arrival"]) and int(n["arrival_day"]) == GameState.current_day:
		GameState.log_choice("arrival_deployed", "micro", [npc_id],
			{"post_id": post_id, "zone_id": post_zone(post_id)}, 0.05)
	EventBus.world_changed.emit()


## Roster fiddling should not inflate the choice log: a second roster decision
## about the same person on the same day rewrites the first.
static func _log_roster_choice(action: String, npc_id: String, post_id: String) -> void:
	if npc_id == "":
		return
	var payload := {"post_id": post_id, "zone_id": post_zone(post_id), "post_name": post_name(post_id)}
	for i in range(GameState.choice_log.size() - 1, -1, -1):
		var c: Dictionary = GameState.choice_log[i]
		if int(c["day_cycle"]) != GameState.current_day:
			break
		if (str(c["action_type"]) == "post_npc" or str(c["action_type"]) == "post_cleared") and c["npc_ids"].has(npc_id):
			c["action_type"] = action
			c["choice_payload"] = payload
			return
	GameState.log_choice(action, "micro", [npc_id], payload)


## Data for the roster surface. No effectiveness, no risk, no advice.
static func roster_panel() -> Dictionary:
	var rows: Array = []
	for p in posts():
		var who := str(GameState.night_posts.get(str(p["id"]), ""))
		if who != "" and not rosterable().has(who):
			GameState.night_posts[str(p["id"])] = ""
			who = ""
		var status := "EMPTY"
		var holder := ""
		if who != "":
			status = "STAFFED"
			holder = GameState.npc_name(who)
		elif hands_cover(p):
			status = "STAFFED"
			holder = "mill hands"
		rows.append({"post_id": str(p["id"]), "name": str(p["name"]), "status": status,
			"holder": holder, "npc_id": who,
			"last": str(GameState.post_history.get(str(p["id"]), ""))})
	var people: Array = []
	for id in rosterable():
		people.append({"npc_id": id, "name": GameState.npc_name(id),
			"line": Behavior.line(id), "post_id": GameState.post_of(id)})
	return {"posts": rows, "people": people}


# ═══════════════════════════════════════════════════════════════════════════
# Building placement (INTERACTION_MODEL §2)
# ═══════════════════════════════════════════════════════════════════════════

static func zone_blocked(zone_id: String) -> bool:
	for w in GameState.walkers:
		if not bool(w["cleared"]) and str(w["zone_id"]) == zone_id:
			return true
	return false


## Red means no. No reason is ever given.
static func can_place(building_type: String, zone_id: String) -> bool:
	if GameState.current_phase != "day":
		return false
	if not Content.BUILDINGS.has(building_type):
		return false
	var z: Dictionary = GameState.zones.get(zone_id, {})
	if z.is_empty() or not bool(z["buildable"]):
		return false
	if zone_blocked(zone_id):
		return false
	if GameState.stock("timber") < int(Content.BUILDINGS[building_type]["timber"]):
		return false
	return true


static func place_building(building_type: String, zone_id: String, cell: Vector2i) -> Dictionary:
	if not can_place(building_type, zone_id):
		return {}
	GameState.add_stock("timber", -int(Content.BUILDINGS[building_type]["timber"]))
	GameState.built_today += 1
	var b := {
		"id": "b%d" % (GameState.buildings.size() + 1),
		"building_type": building_type, "zone_id": zone_id,
		"cell": [cell.x, cell.y], "day_placed": GameState.current_day,
		"order": GameState.buildings.size() + 1, "state": "pristine", "state_day": 0,
	}
	GameState.buildings.append(b)
	var adjacent: bool = bool(GameState.zones[zone_id]["hollow_adjacent"])
	var who := _named_worker_in(zone_id)
	var c := GameState.log_choice("place_building", "micro", [who],
		{"zone_id": zone_id, "building_type": building_type, "building_id": str(b["id"])},
		0.10 if adjacent else 0.0)
	b["choice_id"] = str(c["choice_id"])
	if adjacent:
		# One Walker per building placed in violation. Day-1 placement walks on Night 1.
		GameState.walker_queue.append({"choice_id": str(c["choice_id"]), "from_night": GameState.current_day})
	EventBus.building_placed.emit(building_type, zone_id, cell)
	return b


static func _named_worker_in(zone_id: String) -> String:
	var best := ""
	for id in GameState.npcs_in_zone(zone_id):
		if id == "constance":
			continue
		if not bool(GameState.npc_states[id]["is_arrival"]):
			return id
		if best == "":
			best = id
	if best == "" and GameState.npc_is_present("peder"):
		best = "peder"
	return best


# ═══════════════════════════════════════════════════════════════════════════
# Panels (INTERACTION_MODEL §3, §4) — what clicking a thing shows
# ═══════════════════════════════════════════════════════════════════════════

static func rep_present(faction_id: String) -> bool:
	if GameState.current_phase != "day":
		return false
	if GameState.open_asks.has(faction_id):
		return true
	if GameState.current_day == 1:
		return true
	if faction_id == "dix" and GameState.current_day >= 3 and not GameState.has_flag("dix_departed"):
		return true
	return false


static func panel(target: String) -> Dictionary:
	if target == "obj_ledger":
		return _ledger_panel()
	if target == "obj_board":
		return _board_panel()
	if target.begins_with("rep_"):
		return _rep_panel(target.substr(4))
	if GameState.npc_states.has(target):
		return _npc_panel(target)
	return {}


static func _npc_panel(id: String) -> Dictionary:
	var n: Dictionary = GameState.npc_states[id]
	var p := {"target": id, "title": str(n["name"]), "subtitle": str(n["role"]), "lines": [], "options": []}
	if bool(n["gone"]):
		return {}
	var post_id := GameState.post_of(id)
	var current := _assignment_text(id)
	p["lines"].append({"text": current, "dim": true})
	if post_id != "":
		p["lines"].append({"text": "Tonight: %s" % post_name(post_id), "dim": true})
	var line := Behavior.line(id)
	if bool(n["is_arrival"]) and int(n["arrival_day"]) == GameState.current_day and str(n.get("conversation", "")) == "":
		line = str(n["signal"])
	p["lines"].append({"text": line, "dim": false})
	if bool(n["is_arrival"]) and int(n["arrival_day"]) == GameState.current_day and str(n.get("conversation", "")) != "":
		p["lines"].append({"text": str(n["answer"]), "dim": false})

	# Night and dusk: name and state only. The absence of options is the information.
	if GameState.current_phase != "day":
		return p
	if str(n["arc_state"]) == GameState.ARC_BROKEN:
		return p
	var opts: Array = p["options"]

	if bool(n["is_arrival"]) and str(n.get("stage", "done")) != "done":
		_arrival_options(id, opts)
		if str(n["stage"]) == "housing":
			return p

	if id == "peder":
		_peder_options(opts)
	elif id != "constance":
		for a in Content.DAY_ASSIGNMENTS:
			if str(a["zone"]) != str(n["zone"]):
				opts.append({"act": "assign", "npc": id, "zone": str(a["zone"]), "text": str(a["text"])})

	if id == "elias" and GameState.current_day == 1 and not GameState.has_choice("elias_report_logged") \
			and not GameState.has_choice("elias_report_unlogged"):
		opts.append({"act": "simple", "id": "elias_report_logged", "text": "Log the treeline report."})
		opts.append({"act": "simple", "id": "elias_report_unlogged", "text": "Set the report aside."})
	if id == "elias" and GameState.dawn_unlocks.has("elias_tell") and not GameState.has_flag("elias_heard"):
		opts.append({"act": "simple", "id": "elias_heard", "text": "He wants to tell you something."})
	if id == "thomas" and GameState.current_day in [2, 3] and not GameState.thomas_spoke \
			and not GameState.has_choice("thomas_briefing", GameState.current_day):
		opts.append({"act": "simple", "id": "thomas_briefing", "text": "Give him the evening briefing."})
	if id == "thomas" and GameState.dawn_unlocks.has("thomas_avoided") and not GameState.has_flag("thomas_paired") \
			and GameState.npc_is_capable("ruth"):
		opts.append({"act": "simple", "id": "thomas_pair_ruth", "text": "Pair him with Ruth Callan on the infirmary round."})
	if id == "ruth" and int(GameState.flags.get("rations_open", 0)) == GameState.current_day:
		opts.append({"act": "simple", "id": "rations_watch_first", "text": "The night watch draws first."})
		opts.append({"act": "simple", "id": "rations_mill_first", "text": "The mill crew draws first."})
		if not GameState.arrival_order.is_empty():
			opts.append({"act": "simple", "id": "rations_arrivals_first", "text": "The newest arrivals draw first."})
	if id == "constance" and GameState.has_flag("constance_window") and not GameState.has_flag("constance_asked"):
		opts.append({"act": "simple", "id": "constance_asked", "text": "Ask her what she knows about the survey."})

	# Bond acknowledgment — Day 3+, two consecutive days co-assigned. Never explained.
	var partner := str(n.get("bond_partner", ""))
	if GameState.current_day >= 3 and partner != "" and not bool(n["bond_acknowledged"]) \
			and GameState.npc_is_capable(partner):
		opts.append({"act": "bond", "npc": id, "partner": partner, "text": "Keep them working together."})

	# Arrival discovery — only on the day the role is assigned (ENGAGEMENT_LOOPS).
	var disc := str(GameState.flags.get("discovery_%d" % GameState.current_day, ""))
	if disc == "construction" and id == "peder" and not GameState.has_flag("foundation_raised"):
		opts.append({"act": "simple", "id": "peder_foundation_asked", "text": "Ask him to look at the foundation with the new arrival."})
	if disc == "observation" and id == "elias" and not GameState.has_flag("elias_boundary"):
		opts.append({"act": "simple", "id": "elias_boundary", "text": "He wants to show you something at the eastern boundary."})

	# Macro (Day 5) on its target.
	if GameState.has_flag("macro_open") and str(GameState.flags.get("macro_target", "")) == id:
		for o in Content.MACROS[str(GameState.flags["macro_fork"])]["options"]:
			opts.append({"act": "macro", "id": str(o["id"]), "text": str(o["text"])})
	return p


static func _assignment_text(id: String) -> String:
	var n: Dictionary = GameState.npc_states[id]
	if id == "constance":
		return "Settlement Common"
	if bool(n["is_arrival"]) and not bool(n["role_assigned"]):
		return "Where the road ends"
	if id == "peder" and not GameState.crew_order.is_empty():
		return str(GameState.crew_order.get("label", "With the crew"))
	for a in Content.DAY_ASSIGNMENTS:
		if str(a["zone"]) == str(n["zone"]):
			return str(a["text"])
	return GameState.zone_short(str(n["zone"]))


static func _peder_options(opts: Array) -> void:
	var day := GameState.current_day
	var crew_free: bool = GameState.crew_order.is_empty() and not GameState.crew_unavailable_days.has(day)
	if crew_free:
		if GameState.structure_walls < 4 and not GameState.has_flag("foundation_left"):
			opts.append({"act": "crew", "id": "crew_fourth_wall", "zone": "zone_4",
				"text": "Finish the incomplete structure's fourth wall."})
		opts.append({"act": "crew", "id": "crew_mill_reinforce", "zone": "zone_1",
			"text": "Reinforce the Mill Quarter's secondary processing building."})
		if day == 1 and not GameState.has_choice("crew_hollow_survey"):
			opts.append({"act": "crew", "id": "crew_hollow_survey", "zone": "zone_5",
				"text": "Survey the western hollow perimeter."})
		if day >= 2:
			if not GameState.clearings.has("west"):
				opts.append({"act": "crew", "id": "crew_clear_west", "zone": "zone_4",
					"text": "Clear the perimeter brush toward the western hollow."})
			if not GameState.clearings.has("east"):
				opts.append({"act": "crew", "id": "crew_clear_east", "zone": "zone_3",
					"text": "Clear the perimeter brush toward the eastern ridge."})
		for b in GameState.buildings:
			if str(b["state"]) == "damaged":
				opts.append({"act": "crew", "id": "crew_repair", "zone": str(b["zone_id"]), "building_id": str(b["id"]),
					"text": "Repair the %s at %s." % [str(b["building_type"]), GameState.zone_short(str(b["zone_id"]))]})
		var seen: Dictionary = {}
		for w in GameState.walkers:
			var z := str(w["zone_id"])
			if not bool(w["cleared"]) and z != "zone_5" and not seen.has(z):
				seen[z] = true
				opts.append({"act": "crew", "id": "crew_clear_walker", "zone": z,
					"text": "Clear what is standing in %s." % GameState.zone_short(z)})
	if day >= 2 and day <= 4 and not GameState.has_flag("foundation_raised"):
		opts.append({"act": "simple", "id": "peder_foundation_asked", "text": "Ask about the foundation."})
	if GameState.has_flag("foundation_raised") and not GameState.has_flag("foundation_left") \
			and not GameState.peder_foundation_excavated and not GameState.has_flag("excavate_ordered"):
		opts.append({"act": "simple", "id": "peder_foundation_left", "text": "Tell him the foundation stays as it is."})
		if crew_free:
			opts.append({"act": "crew", "id": "crew_excavate", "zone": "zone_4",
				"text": "Order the foundation dug to depth."})


static func _arrival_options(id: String, opts: Array) -> void:
	var n: Dictionary = GameState.npc_states[id]
	match str(n["stage"]):
		"housing":
			for other in GameState.ORIGINAL_SIX:
				if GameState.npc_is_capable(other):
					opts.append({"act": "house", "npc": id, "near": other,
						"text": "A bunk near %s." % GameState.npc_name(other)})
			opts.append({"act": "house", "npc": id, "near": "", "text": "Any open bunk."})
		"talk":
			if int(n["arrival_day"]) == GameState.current_day:
				if str(n["conversation"]) == "":
					opts.append({"act": "talk", "npc": id, "text": "Ask how they're doing."})
				elif str(n["conversation"]) == "asked":
					opts.append({"act": "promise", "npc": id,
						"text": "Tell %s the road is being looked into." % Content.pron(id, 1)})


static func _rep_panel(faction_id: String) -> Dictionary:
	var f: Dictionary = GameState.factions.get(faction_id, {})
	if f.is_empty() or not rep_present(faction_id):
		return {}
	var p := {"target": "rep_" + faction_id, "title": str(f["rep"]), "subtitle": str(f["name"]),
		"lines": [], "options": []}
	if GameState.open_asks.has(faction_id):
		var ask: Dictionary = Content.ASKS[str(GameState.open_asks[faction_id])]
		p["lines"].append({"text": str(ask["prompt"]), "dim": false})
		for o in ask["options"]:
			p["options"].append({"act": "ask", "faction": faction_id, "id": str(o["id"]), "text": str(o["text"])})
		return p
	if GameState.has_flag("macro_open") and str(GameState.flags.get("macro_target", "")) == "rep_" + faction_id:
		p["lines"].append({"text": "\"I leave at dusk. I would rather leave with something signed.\"", "dim": false})
		for o in Content.MACROS[str(GameState.flags["macro_fork"])]["options"]:
			p["options"].append({"act": "macro", "id": str(o["id"]), "text": str(o["text"])})
		return p
	p["lines"].append({"text": Behavior.rep_line(faction_id), "dim": false})
	return p


static func _ledger_panel() -> Dictionary:
	var p := {"target": "obj_ledger", "title": "The handover ledger", "subtitle": "Manager's post",
		"lines": [], "options": []}
	p["lines"].append({"text": "The cover carries the previous manager's name: Sorell. Fourteen names inside. Day %d." % GameState.current_day, "dim": true})
	for kind in ["timber", "provisions", "oil"]:
		var s: Dictionary = GameState.stockpiles[kind]
		var text := "%s — entered %d — counted %d" % [str(s["name"]), int(s["ledger"]), int(s["count"])]
		p["lines"].append({"text": text, "dim": false})
	if GameState.has_flag("compact_entry"):
		p["lines"].append({"text": "There is an entry near the bottom that is not in the manager's hand.", "dim": true})
	if GameState.active_watchers() > 0 and GameState.current_day >= 2:
		p["lines"].append({"text": "One line is not where it was written.", "dim": true})
	if GameState.current_phase != "day":
		return p
	if GameState.current_day == 1 and not GameState.has_choice("ledger_counted_entered") \
			and not GameState.has_choice("ledger_carried_forward"):
		p["options"].append({"act": "simple", "id": "ledger_counted_entered", "text": "Enter the counted figures."})
		p["options"].append({"act": "simple", "id": "ledger_carried_forward", "text": "Carry the handover figures forward."})
	if GameState.current_day >= 2 and not GameState.undisclosed_sources().is_empty():
		if _logistics_names_sources():
			for d in GameState.undisclosed_sources():
				p["options"].append({"act": "disclose", "source": str(d["id"]),
					"text": "Log the discrepancy formally: %s." % str(d["label"])})
		else:
			p["options"].append({"act": "disclose", "source": "", "text": "Log the discrepancy formally."})
	return p


static func _logistics_names_sources() -> bool:
	for id in GameState.arrival_order:
		var n: Dictionary = GameState.npc_states[id]
		if str(n["domain"]) == "logistics" and str(n["depth"]) != "surface" and GameState.npc_is_capable(id) \
				and str(n["zone"]) == "zone_1":
			return true
	return false


## The Township Board (ENGAGEMENT_LOOPS): at most three items, no completion state.
static func _board_panel() -> Dictionary:
	var p := {"target": "obj_board", "title": "The township board", "subtitle": "Settlement Common",
		"lines": [], "options": []}
	var items: Array = []
	var day := GameState.current_day
	for id in GameState.npc_states:
		var n: Dictionary = GameState.npc_states[id]
		if GameState.npc_is_present(id) and str(n["arc_state"]) in ["fragile", "broken"] and GameState.post_of(id) == "" \
				and int(n["zone_days"]) >= 1 and id != "constance":
			items.append("%s hasn't been assigned since Day %d. Their post is empty." % [str(n["name"]), maxi(1, day - int(n["zone_days"]))])
			break
	for fid in ["compact", "association", "dix"]:
		var last := int(GameState.faction_last_contact.get(fid, 1))
		if last < day - 2:
			items.append("The %s was last seen on Day %d. No message since." % [str(GameState.factions[fid]["rep"]), last])
			break
	for key in GameState.cozone_days:
		if int(GameState.cozone_days[key]) >= 2:
			var pair: PackedStringArray = str(key).split("|")
			if GameState.npc_is_present(pair[0]) and GameState.npc_is_present(pair[1]):
				items.append("%s and %s have worked the same post for %d days." % [
					GameState.npc_name(pair[0]), GameState.npc_name(pair[1]), int(GameState.cozone_days[key])])
				break
	for post_id in GameState.post_history:
		if str(GameState.post_history[post_id]) == "empty" and day >= 2:
			items.append("The %s hasn't been covered since Night %d." % [post_name(str(post_id)).split(",")[0], day - 1])
			break
	if not GameState.undisclosed_sources().is_empty() and GameState.has_flag("assoc_asked_day"):
		items.append("The ledger has not been returned. The Association last asked on Day %d." % int(GameState.flags["assoc_asked_day"]))
	if GameState.has_flag("supply_route_item"):
		items.append("The Association's supply route crosses the Compact's wood lot. The crossing is not on the ledger map.")
	for i in mini(3, items.size()):
		p["lines"].append({"text": str(items[i]), "dim": false})
	if items.is_empty():
		p["lines"].append({"text": "Nothing is pinned to it.", "dim": true})
	return p


# ═══════════════════════════════════════════════════════════════════════════
# Choosing (no confirmation; the choice is made when it is clicked)
# ═══════════════════════════════════════════════════════════════════════════

static func choose(opt: Dictionary) -> void:
	if GameState.current_phase != "day":
		return
	match str(opt.get("act", "")):
		"assign":
			_do_assign(str(opt["npc"]), str(opt["zone"]))
		"crew":
			_do_crew(opt)
		"simple":
			_do_simple(str(opt["id"]))
		"ask":
			_do_ask(str(opt["faction"]), str(opt["id"]))
		"macro":
			_do_macro(str(opt["id"]), false)
		"bond":
			_do_bond(str(opt["npc"]), str(opt["partner"]))
		"house":
			_do_house(str(opt["npc"]), str(opt["near"]))
		"talk":
			_do_talk(str(opt["npc"]))
		"promise":
			_do_promise(str(opt["npc"]))
		"disclose":
			_do_disclose(str(opt.get("source", "")))
	EventBus.world_changed.emit()


static func _do_assign(id: String, zone_id: String) -> void:
	var n: Dictionary = GameState.npc_states[id]
	if bool(n["is_arrival"]) and not bool(n["role_assigned"]):
		n["role_assigned"] = true
		n["stage"] = "talk"
		GameState.assign_npc(id, zone_id)
		GameState.log_choice("arrival_role", "micro", [id], {"zone_id": zone_id})
		if int(n["arrival_day"]) == GameState.current_day:
			GameState.set_flag("discovery_%d" % GameState.current_day, str(n["domain"]))
			if str(n["domain"]) == "logistics":
				GameState.set_flag("supply_route_item")
		return
	GameState.assign_npc(id, zone_id)
	GameState.log_choice("assign_npc", "micro", [id], {"zone_id": zone_id})
	# The ridge is a post by day and by night: leaving it by day leaves it by night.
	if zone_id != "zone_3" and str(GameState.night_posts.get("post_ridge", "")) == id:
		GameState.night_posts["post_ridge"] = ""
	# Gap 10: Maren's Day 1 assignment decides what she owes.
	if id == "maren" and zone_id == "zone_4" and GameState.current_day == 1:
		GameState.set_flag("maren_owes")
	if zone_id == "zone_4" and id != "peder" and str(n["domain"]) != "construction":
		if not GameState.has_flag("structure_assigned_%s" % id):
			GameState.set_flag("structure_assigned_%s" % id, GameState.current_day)


static func _do_crew(opt: Dictionary) -> void:
	var id := str(opt["id"])
	var zone_id := str(opt["zone"])
	if not GameState.crew_order.is_empty() or GameState.crew_unavailable_days.has(GameState.current_day):
		return
	if id == "crew_hollow_survey":
		# Peder refuses, quietly, with a logistics justification (WORLD_STATE §6).
		GameState.log_choice(id, "micro", ["peder"], {"zone_id": zone_id})
		GameState.adjust_faction("dix", 0.15, "The manager tried to send a crew to the western parcel.")
		GameState.adjust_faction("compact", -0.15, "The manager pointed a crew at the hollow.")
		GameState.set_flag("peder_refused_survey")
		GameState.set_npc_emotion("peder", GameState.EMOTION_AFRAID)
		GameState.add_log(Content.PEDER_REFUSES_SURVEY, "plain")
		return
	var payload := {"zone_id": zone_id}
	var debt := 0.0
	var label := "With the crew"
	match id:
		"crew_fourth_wall":
			debt = 0.10
			label = "Incomplete Structure, the fourth wall"
		"crew_mill_reinforce":
			label = "Mill Quarter, the processing building"
		"crew_clear_west":
			label = "Western perimeter, clearing"
		"crew_clear_east":
			label = "Eastern perimeter, clearing"
		"crew_repair":
			payload["building_id"] = str(opt["building_id"])
			payload["building_type"] = str(GameState.building_by_id(str(opt["building_id"])).get("building_type", "building"))
			label = "Repair work"
		"crew_clear_walker":
			label = "%s, clearing" % GameState.zone_short(zone_id)
		"crew_excavate":
			debt = 0.10
			label = "Incomplete Structure, the foundation"
			GameState.set_flag("excavate_ordered")
	var c := GameState.log_choice(id, "micro", ["peder"], payload, debt)
	GameState.crew_order = {"action": id, "zone": zone_id, "choice_id": str(c["choice_id"]),
		"label": label, "building_id": str(opt.get("building_id", ""))}
	if GameState.zones.has(zone_id) and zone_id != "zone_5":
		GameState.assign_npc("peder", zone_id)
	if id == "crew_excavate":
		GameState.set_npc_emotion("peder", GameState.EMOTION_AFRAID)


static func _do_simple(id: String) -> void:
	match id:
		"elias_report_logged":
			GameState.log_choice(id, "micro", ["elias"], {"zone_id": "zone_3"})
		"elias_report_unlogged":
			GameState.log_choice(id, "micro", ["elias"], {"zone_id": "zone_3"}, 0.05)
		"elias_heard":
			var c := GameState.log_choice("elias_heard", "micro", ["elias"], {"zone_id": "zone_3"})
			GameState.set_flag("elias_heard")
			GameState.shift_arc("elias", 1, str(c["choice_id"]))
			GameState.add_log("Elias Grout: \"The stake I set is inside the trees now. I didn't move it. I want that written the way I said it.\"", "voice")
		"elias_boundary":
			GameState.log_choice("elias_boundary", "micro", ["elias"], {"zone_id": "zone_3"})
			GameState.set_flag("elias_boundary")
			GameState.add_log("At the eastern boundary Elias Grout points at a row of saplings. They are in a line. Forty paces apart. He does not say what it looks like.", "plain")
		"thomas_briefing":
			GameState.log_choice(id, "micro", ["thomas"], {"zone_id": "zone_2"}, -0.05)
		"thomas_pair_ruth":
			GameState.log_choice("thomas_pair_ruth", "micro", ["thomas", "ruth"], {"zone_id": "zone_2"})
			GameState.set_flag("thomas_paired")
			GameState.assign_npc("ruth", "zone_2")
			GameState.assign_npc("thomas", "zone_2")
		"ledger_counted_entered":
			GameState.log_choice(id, "micro", ["maren"], {})
			for kind in GameState.stockpiles:
				GameState.stockpiles[kind]["ledger"] = int(GameState.stockpiles[kind]["count"])
			GameState.set_flag("ledger_true")
			GameState.set_npc_emotion("maren", GameState.EMOTION_AFRAID)
		"ledger_carried_forward":
			var c2 := GameState.log_choice(id, "micro", ["maren"], {}, 0.15)
			GameState.discrepancies.append({"id": "d_handover", "choice_id": str(c2["choice_id"]),
				"stockpile": "provisions", "watchers": 1, "disclosed": false, "day": 1,
				"label": "the handover shortfall"})
		"peder_foundation_asked":
			GameState.log_choice(id, "micro", ["peder"], {"zone_id": "zone_4"})
			GameState.set_flag("foundation_raised")
			GameState.set_npc_emotion("peder", GameState.EMOTION_AFRAID)
			GameState.add_log("Peder Lund: " + Content.PEDER_FOUNDATION_ANSWER, "voice")
		"peder_foundation_left":
			GameState.log_choice(id, "micro", ["peder"], {"zone_id": "zone_4"})
			GameState.set_flag("foundation_left")
			GameState.set_npc_emotion("peder", GameState.EMOTION_NEUTRAL)
			if not GameState.crew_order.is_empty() and str(GameState.crew_order["action"]) == "crew_fourth_wall":
				GameState.crew_order = {}
		"constance_asked":
			var c3 := GameState.log_choice(id, "mid", ["constance"], {"zone_id": "zone_2"}, -0.10)
			GameState.set_flag("constance_asked")
			GameState.constance_window_open = true
			GameState.set_npc_emotion("constance", GameState.EMOTION_AFRAID)
			GameState.shift_arc("constance", -1, str(c3["choice_id"]))
			if GameState.anchor_state() != "intact":
				GameState.add_log("Constance Harrow: " + Content.CONSTANCE_ANCHOR_LINE, "voice")
			for l in Content.CONSTANCE_SPEAKS:
				GameState.add_log("Constance Harrow: " + l, "voice")
		"rations_watch_first", "rations_mill_first", "rations_arrivals_first":
			var who: Array = ["ruth"]
			for post_id in GameState.night_posts:
				if id == "rations_watch_first" and str(GameState.night_posts[post_id]) != "":
					who.append(str(GameState.night_posts[post_id]))
			if id == "rations_arrivals_first":
				who.append_array(GameState.arrival_order)
			GameState.log_choice(id, "micro", who, {})
			GameState.set_flag("rations_%d" % GameState.current_day, id)
			GameState.flags.erase("rations_open")
			if id == "rations_arrivals_first":
				GameState.set_npc_emotion("ruth", GameState.EMOTION_ANGRY)
				GameState.adjust_faction("association", -0.1, "The newest hands ate before the mill crew.")
			elif id == "rations_watch_first":
				GameState.adjust_faction("association", -0.05, "The mill crew drew short.")


static func _do_ask(faction_id: String, option_id: String) -> void:
	if not GameState.open_asks.has(faction_id):
		return
	var ask_id := str(GameState.open_asks[faction_id])
	GameState.open_asks.erase(faction_id)
	GameState.faction_last_contact[faction_id] = GameState.current_day
	match option_id:
		"compact_surplus_accepted":
			var who := _named_worker_in("zone_1")
			var c := GameState.log_choice(option_id, "mid", [who], {"zone_id": "zone_1"}, 0.20)
			GameState.adjust_faction("compact", 0.15, "The surplus was taken.")
			for pair in [["provisions", 30], ["timber", 20], ["oil", 12]]:
				GameState.add_stock(str(pair[0]), int(pair[1]))
				GameState.stockpiles[str(pair[0])]["ledger"] = int(GameState.stockpiles[str(pair[0])]["ledger"]) + int(pair[1])
			GameState.discrepancies.append({"id": "d_surplus", "choice_id": str(c["choice_id"]),
				"stockpile": "provisions", "watchers": 1, "disclosed": false, "day": GameState.current_day,
				"label": "the Compact's surplus"})
			GameState.add_log("The delegate has the wagon unloaded at the Mill Quarter before the answer is finished.", "dim")
		"compact_surplus_declined":
			GameState.log_choice(option_id, "mid", [_named_worker_in("zone_1")], {"zone_id": "zone_1"})
			GameState.adjust_faction("compact", -0.10, "The wagon was sent back.")
			GameState.add_log("The delegate nods, and looks at the stores, and nods again. The wagon turns.", "dim")
		"association_ledger_unedited":
			GameState.log_choice(option_id, "mid", ["maren"], {}, -0.10)
			GameState.adjust_faction("association", 0.30, "The ledger was handed over unedited.")
			GameState.adjust_faction("compact", -0.20, "The stores were shown to the Association.")
			GameState.discrepancy_disclosed = true
			GameState.set_flag("ledger_out")
			for d in GameState.discrepancies:
				if str(d["id"]) in ["d_handover", "d_oil"]:
					d["disclosed"] = true
			_compact_pulls_crew(GameState.current_day + 1)
			GameState.set_npc_emotion("maren", GameState.EMOTION_NEUTRAL)
			GameState.set_npc_emotion("ruth", GameState.EMOTION_ANGRY)
			GameState.add_log("The representative reads standing up. Reads it twice. Thanks no one, and takes it to the mill.", "dim")
		"association_ledger_edited":
			var c2 := GameState.log_choice(option_id, "mid", ["maren"], {}, 0.15)
			GameState.adjust_faction("association", 0.10, "A ledger was handed over.")
			GameState.set_flag("ledger_lie")
			GameState.discrepancies.append({"id": "d_edited", "choice_id": str(c2["choice_id"]),
				"stockpile": "timber", "watchers": 1, "disclosed": false, "day": GameState.current_day,
				"label": "the edited timber figure"})
			GameState.set_npc_emotion("maren", GameState.EMOTION_AFRAID)
			GameState.add_log("The representative reads it standing up and says it is better than they were told. Maren Voss is looking at the floor.", "dim")
		"association_ledger_acknowledge":
			GameState.log_choice(option_id, "mid", ["maren"], {})
			GameState.adjust_faction("association", -0.05, "The shortfall was admitted. The book was not shown.")
			GameState.adjust_faction("compact", -0.05, "The manager said the word 'shortfall' in the Common.")
			GameState.set_flag("on_record_knowing")
			GameState.set_flag("assoc_waiting")
			GameState.add_log("\"Then you know,\" the representative says. \"That is something. It is not the book.\"", "dim")
		"dix_inspection_approved":
			GameState.log_choice(option_id, "mid", ["peder"], {"zone_id": "zone_5"}, -0.05)
			GameState.dix_approved = true
			GameState.adjust_faction("dix", 0.30, "The inspection was approved.")
			GameState.adjust_faction("compact", -0.30, "The county was let onto the western parcel.")
			_compact_pulls_crew(GameState.current_day + 1)
			GameState.add_log("Dix thanks the manager's post, not the manager, and walks west with a chain and a notebook.", "dim")
		"dix_inspection_delayed":
			GameState.log_choice(option_id, "mid", ["peder"], {"zone_id": "zone_5"})
			GameState.adjust_faction("dix", -0.10, "The inspection was put off.")
			GameState.set_flag("dix_delayed")
			GameState.add_log("Dix writes the reason down exactly as given, and underlines it.", "dim")
		"dix_inspection_denied":
			GameState.log_choice(option_id, "mid", [_ridge_or("elias")], {"zone_id": "zone_5"}, 0.10)
			GameState.adjust_faction("dix", -0.30, "The inspection was refused.")
			GameState.adjust_faction("compact", 0.20, "The county was kept off the western parcel.")
			GameState.add_log("Dix closes the map. Across the Common the Compact delegate takes off a hat that did not need taking off.", "dim")
		"compact_ratification_signed":
			GameState.log_choice(option_id, "mid", [_named_worker_in("zone_1")], {"zone_id": "zone_1"}, 0.20)
			GameState.compact_ratified = true
			GameState.set_flag("survey_met")
			GameState.set_flag("compact_labor")
			GameState.adjust_faction("compact", 0.40, "The survey was ratified.")
			GameState.adjust_faction("association", -0.10, "The manager signed the Compact's paper.")
			GameState.add_stock("timber", 20)
			GameState.stockpiles["timber"]["ledger"] = int(GameState.stockpiles["timber"]["ledger"]) + 20
			GameState.add_log("The delegate blots the signature. Constance Harrow watched the pen the whole way across.", "dim")
		"compact_ratification_delayed":
			GameState.log_choice(option_id, "mid", ["maren"], {})
			GameState.set_flag("survey_met")
			GameState.set_flag("ratification_pending")
			GameState.adjust_faction("compact", -0.10, "The manager asked for time.")
			GameState.add_log("\"Of course,\" the delegate says, and does not pick the document up.", "dim")
		"compact_ask_survey_history":
			GameState.log_choice(option_id, "mid", ["constance"], {"zone_id": "zone_2"})
			GameState.set_flag("survey_met")
			GameState.set_flag("survey_history_asked")
			GameState.adjust_faction("compact", -0.30, "The manager asked where the survey came from.")
			_compact_pulls_crew(GameState.current_day + 1)
			GameState.add_log("The delegate folds the document. Constance Harrow looks at the table, then at the window. No one answers.", "dim")
		"association_date_given":
			GameState.log_choice(option_id, "mid", ["ruth"], {"zone_id": "zone_4"})
			GameState.set_flag("timeline_promised")
			GameState.adjust_faction("association", 0.20, "A date was given for the fourth wall.")
			GameState.add_log("The representative repeats the date once, out loud, so that it has been said.", "dim")
		"association_no_date":
			GameState.log_choice(option_id, "mid", ["ruth"], {"zone_id": "zone_4"})
			GameState.adjust_faction("association", -0.20, "There is no date for the fourth wall.")
			if GameState.has_flag("assoc_waiting") or GameState.has_flag("ledger_lie"):
				_association_walks()
			GameState.add_log("\"Then we will stop asking,\" the representative says.", "dim")
	if ask_id == "association_ledger":
		GameState.set_flag("assoc_asked_day", GameState.current_day)


static func _ridge_or(fallback: String) -> String:
	var who := str(GameState.night_posts.get("post_ridge", ""))
	if who != "":
		return who
	return fallback if GameState.npc_is_present(fallback) else _named_worker_in("zone_3")


static func _compact_pulls_crew(day: int) -> void:
	if day <= LAST_DAY and not GameState.crew_unavailable_days.has(day):
		GameState.crew_unavailable_days.append(day)


static func _association_walks() -> void:
	if GameState.has_flag("association_walked"):
		return
	GameState.set_flag("association_walked", GameState.current_day)
	GameState.add_log("Three of the mill hands were not at the evening briefing.", "dim")


static func _close_open_asks(day: int) -> void:
	for faction_id in GameState.open_asks.keys():
		var ask_id := str(GameState.open_asks[faction_id])
		match ask_id:
			"compact_surplus":
				GameState.add_log("The Compact's wagon waited until the light went, then turned.", "dim")
			"association_ledger":
				GameState.log_choice("association_unanswered", "mid", ["maren"], {})
				GameState.set_flag("assoc_waiting")
				GameState.set_flag("assoc_asked_day", day)
				GameState.adjust_faction("association", -0.15, "The request for the ledger was not answered.")
			"dix_inspection":
				GameState.log_choice("dix_unanswered", "mid", ["constance"], {})
				GameState.set_flag("dix_interviewing")
				GameState.set_npc_emotion("constance", GameState.EMOTION_AFRAID)
				GameState.add_log("Field Agent Dix was seen at Constance Harrow's door before the light went.", "dim")
			"compact_ratification":
				GameState.log_choice("compact_ratification_delayed", "mid", ["maren"], {"unanswered": true})
				GameState.set_flag("ratification_pending")
			"association_date":
				GameState.log_choice("association_left_waiting", "mid", ["ruth"], {})
				GameState.adjust_faction("association", -0.25, "No one came to answer.")
				_association_walks()
	GameState.open_asks = {}
	if GameState.has_flag("macro_open"):
		_do_macro(_macro_default(), true)


static func _log_omissions(day: int) -> void:
	if day == 1 and not GameState.has_choice("elias_report_logged") and not GameState.has_choice("elias_report_unlogged") \
			and GameState.npc_is_present("elias"):
		GameState.log_choice("elias_report_unlogged", "micro", ["elias"], {"zone_id": "zone_3", "by_default": true}, 0.05)
	if day == 3 and not GameState.thomas_spoke and not GameState.has_choice("thomas_briefing") \
			and GameState.npc_is_present("thomas"):
		GameState.log_choice("thomas_not_asked", "micro", ["thomas"], {"by_default": true})
	if day == 4 and not GameState.has_flag("foundation_raised") and not GameState.peder_foundation_excavated \
			and GameState.npc_is_present("peder"):
		GameState.log_choice("peder_foundation_unasked", "micro", ["peder"], {"zone_id": "zone_4", "by_default": true})
	if int(GameState.flags.get("rations_open", 0)) == day:
		# No one said. Ruth feeds the mill first.
		GameState.set_flag("rations_%d" % day, "rations_mill_first")
		GameState.flags.erase("rations_open")


static func _evening_briefing(day: int) -> void:
	if not GameState.has_choice("thomas_briefing", day) or GameState.thomas_spoke:
		return
	if not GameState.npc_is_capable("thomas"):
		return
	var c: Dictionary = GameState.find_choice("thomas_briefing", day)
	# He was on a night post last night: he reads the injury list and sits down.
	if GameState.has_flag("thomas_posted_night_%d" % (day - 1)):
		GameState.add_log("Thomas Vael takes the evening briefing. He reads the injury list. He sits down. He was awake on a post all of last night.", "plain")
		return
	GameState.thomas_spoke = true
	for l in Content.THOMAS_SPEAKS:
		GameState.add_log(l, "voice" if str(l).begins_with("\"") else "plain")
	GameState.shift_arc("thomas", 1, str(c["choice_id"]))
	GameState.set_npc_emotion("thomas", GameState.EMOTION_NEUTRAL)


# ═══════════════════════════════════════════════════════════════════════════
# Day-4 Compact response (WORLD_STATE §4, Gap 10)
# ═══════════════════════════════════════════════════════════════════════════

static func _compact_response() -> void:
	if GameState.has_flag("compact_labor"):
		GameState.add_log("Six Compact hands are at the structure this morning with their own tools. No one sent for them.", "plain")
		return
	if not GameState.has_flag("ratification_pending") or GameState.compact_ratified:
		return
	if not GameState.npc_is_capable("maren"):
		return
	var delay: Dictionary = GameState.find_choice("compact_ratification_delayed")
	var cid := str(delay.get("choice_id", ""))
	if GameState.has_flag("maren_owes"):
		GameState.set_flag("maren_stalled")
		GameState.add_log("Maren Voss was seen with the Compact delegate at the supply post. She came away with nothing in her hands.", "plain")
	else:
		GameState.compact_ratified = true
		GameState.set_flag("compact_entry")
		GameState.set_flag("maren_signed")
		GameState.add_debt(0.20)
		GameState.shift_arc("maren", -1, cid)
		GameState.set_npc_emotion("maren", GameState.EMOTION_AFRAID)
		GameState.adjust_faction("compact", 0.2, "The supply clerk signed.")
		GameState.add_log("There is a new entry in the management log. It ratifies the existing survey. It is in Maren Voss's hand.", "plain")


# ═══════════════════════════════════════════════════════════════════════════
# Macro (Day 5) — a fork shaped by what the player already did
# ═══════════════════════════════════════════════════════════════════════════

static func macro_fork() -> String:
	if GameState.compact_ratified:
		return "survey"
	var covered: bool = GameState.has_choice("ledger_carried_forward") or GameState.has_choice("association_ledger_edited") \
		or not GameState.undisclosed_sources().is_empty()
	if covered and GameState.npc_is_capable("maren"):
		return "ledger"
	if GameState.has_flag("constance_asked"):
		return "testimony"
	return "filing"


static func _open_macro() -> void:
	var fork := macro_fork()
	var m: Dictionary = Content.MACROS[fork]
	GameState.set_flag("macro_fork", fork)
	GameState.set_flag("macro_target", str(m["target"]))
	GameState.set_flag("macro_open")
	for l in m["log"]:
		GameState.add_log(str(l), "plain")
	# Arc-workforce sensitivity: the same fork lands on a different floor.
	var worn := 0
	for id in GameState.npc_states:
		if GameState.npc_is_present(id) and str(GameState.npc_states[id]["arc_state"]) in ["broken", "fragile"]:
			worn += 1
	if worn >= 3:
		GameState.add_log(Content.MACRO_WORN_WORKFORCE, "dim")
	EventBus.world_changed.emit()


static func _macro_default() -> String:
	match str(GameState.flags.get("macro_fork", "")):
		"ledger": return "macro_handover_book"
	return "macro_silence"


static func _do_macro(id: String, by_default: bool) -> void:
	if not GameState.has_flag("macro_open"):
		return
	GameState.flags.erase("macro_open")
	var payload := {"fork": str(GameState.flags.get("macro_fork", ""))}
	if by_default:
		payload["by_default"] = true
	var spoke: bool = GameState.has_flag("constance_asked")
	match id:
		"macro_true_count":
			var c := GameState.log_choice(id, "macro", ["maren", "ruth"], payload, -0.20)
			_disclose_all()
			GameState.adjust_faction("association", 0.40, "The true count was read out.")
			GameState.adjust_faction("compact", -0.50, "The stores were opened to the Association.")
			GameState.shift_arc("maren", 1, str(c["choice_id"]))
			GameState.set_npc_emotion("maren", GameState.EMOTION_NEUTRAL)
		"macro_handover_book":
			var c2 := GameState.log_choice(id, "macro", ["maren"], payload, 0.30)
			GameState.adjust_faction("association", 0.10, "The handover book was read out.")
			GameState.shift_arc("maren", -2, str(c2["choice_id"]))
			GameState.set_npc_emotion("maren", GameState.EMOTION_CORRUPTED)
			for d in GameState.discrepancies:
				if not bool(d["disclosed"]):
					d["watchers"] = mini(4, int(d["watchers"]) * 2)
		"macro_carry_self":
			payload["anchor_erosion_delta"] = 0.1
			GameState.log_choice(id, "macro", ["maren", "ruth"], payload, -0.15)
			_disclose_all()
			GameState.adjust_faction("association", 0.30, "The manager read the true count.")
			GameState.adjust_faction("compact", -0.50, "The manager opened the stores.")
		"macro_cosign":
			var c3 := GameState.log_choice(id, "macro", ["constance"], payload, 0.30)
			GameState.adjust_faction("dix", 0.30, "The filing was co-signed.")
			GameState.adjust_faction("compact", 0.30, "The audit was closed on the old survey.")
			GameState.shift_arc("constance", -1, str(c3["choice_id"]))
		"macro_constance_survey":
			var c4 := GameState.log_choice(id, "macro", ["constance"], payload, -0.20)
			GameState.adjust_faction("dix", 0.40, "The original survey was produced.")
			GameState.adjust_faction("compact", -0.60, "The original survey was produced.")
			GameState.constance_window_open = true
			GameState.set_flag("ratification_contested")
			GameState.shift_arc("constance", -2, str(c4["choice_id"]))
			GameState.set_npc_emotion("constance", GameState.EMOTION_AFRAID)
		"macro_withdraw":
			var c5 := GameState.log_choice(id, "macro", ["ruth"], payload, -0.10)
			GameState.compact_ratified = false
			GameState.adjust_faction("compact", -0.60, "The ratification was withdrawn.")
			GameState.flags.erase("compact_labor")
			GameState.shift_arc("ruth", -1, str(c5["choice_id"]))
			GameState.set_npc_emotion("ruth", GameState.EMOTION_ANGRY)
		"macro_testimony_named":
			var c6 := GameState.log_choice(id, "macro", ["constance"], payload, -0.15)
			GameState.adjust_faction("dix", 0.40, "A named account was given.")
			GameState.adjust_faction("compact", -0.50, "Constance Harrow was named to the county.")
			GameState.shift_arc("constance", -2, str(c6["choice_id"]))
			GameState.set_npc_emotion("constance", GameState.EMOTION_AFRAID)
		"macro_testimony_unnamed":
			payload["anchor_erosion_delta"] = 0.1
			GameState.log_choice(id, "macro", ["constance"], payload, -0.05)
			GameState.adjust_faction("dix", 0.10, "An unsourced account was given.")
			GameState.adjust_faction("compact", -0.30, "The manager is the county's source.")
			GameState.set_flag("dix_returns")
		"macro_silence":
			var c7 := GameState.log_choice(id, "macro", ["constance"], payload, 0.15)
			if spoke:
				GameState.shift_arc("constance", -1, str(c7["choice_id"]))
		"macro_refuse_filing":
			GameState.log_choice(id, "macro", ["constance"], payload, -0.05)
			GameState.adjust_faction("dix", -0.20, "The filing was refused.")
			GameState.adjust_faction("compact", -0.20, "The filing was refused.")
			GameState.set_flag("dix_stays")
			GameState.set_npc_emotion("constance", GameState.EMOTION_AFRAID)
		"macro_send_dix_to_constance":
			var c8 := GameState.log_choice(id, "macro", ["constance"], payload, -0.15)
			GameState.constance_window_open = true
			GameState.adjust_faction("compact", -0.40, "The county was sent to Constance Harrow.")
			GameState.shift_arc("constance", -1, str(c8["choice_id"]))
			GameState.set_npc_emotion("constance", GameState.EMOTION_AFRAID)
	GameState.set_flag("macro_choice", id)
	if not GameState.has_flag("dix_stays"):
		GameState.set_flag("dix_departed")


static func _disclose_all() -> void:
	GameState.discrepancy_disclosed = true
	for d in GameState.discrepancies:
		d["disclosed"] = true


static func _do_disclose(source_id: String) -> void:
	var target: Dictionary = {}
	for d in GameState.undisclosed_sources():
		if source_id == "" or str(d["id"]) == source_id:
			target = d
			break
	if target.is_empty():
		return
	target["disclosed"] = true
	GameState.discrepancy_disclosed = true
	GameState.log_choice("discrepancy_logged", "mid", ["maren"], {"source": str(target["id"])}, -0.10)
	GameState.adjust_faction("compact", -0.25, "A discrepancy was written into the record.")
	GameState.adjust_faction("association", 0.10, "A discrepancy was written into the record.")
	_compact_pulls_crew(GameState.current_day + 1)
	if GameState.undisclosed_sources().is_empty():
		GameState.set_npc_emotion("maren", GameState.EMOTION_NEUTRAL)


static func _do_bond(a: String, b: String) -> void:
	GameState.log_choice("bond_acknowledge", "micro", [a, b], {"zone_id": str(GameState.npc_states[a]["zone"])})
	GameState.npc_states[a]["bond_acknowledged"] = true
	GameState.npc_states[b]["bond_acknowledged"] = true


# ═══════════════════════════════════════════════════════════════════════════
# Arrivals (NPC_INFLOW_PRODUCTIVITY)
# ═══════════════════════════════════════════════════════════════════════════

static func _used_domains() -> Array:
	var out: Array = []
	for id in GameState.arrival_order:
		out.append(str(GameState.npc_states[id]["domain"]))
	return out


## Domain coverage = capable people of that domain working its matched zone.
static func _neglected_domain() -> String:
	var used := _used_domains()
	var best := ""
	var best_cov := 99
	for domain in Content.ARRIVAL_DOMAIN_ORDER:
		if used.has(domain):
			continue
		var cov := 0
		for id in GameState.npc_states:
			var n: Dictionary = GameState.npc_states[id]
			if GameState.npc_is_capable(id) and str(n["domain"]) == domain \
					and str(n["zone"]) == str(Content.DOMAIN_ZONE[domain]):
				cov += 1
		if cov < best_cov:
			best_cov = cov
			best = domain
	return best


## The night's most urgent defence gap, read from threat state.
static func _urgent_domain() -> String:
	var used := _used_domains()
	var wanted: Array = []
	var walkers_out := GameState.walker_queue.size()
	for w in GameState.walkers:
		if not bool(w["cleared"]):
			walkers_out += 1
	if walkers_out > 0:
		wanted.append("observation")
		wanted.append("construction")
	if GameState.active_watchers() > 0:
		wanted.append("logistics")
	for id in GameState.npc_states:
		if GameState.npc_is_present(id) and (bool(GameState.npc_states[id]["injured"]) \
				or str(GameState.npc_states[id]["arc_state"]) == "fragile"):
			wanted.append("medicine")
			break
	wanted.append_array(["social", "observation", "logistics", "medicine", "construction"])
	for d in wanted:
		if not used.has(d):
			return str(d)
	return "social"


static func _spawn_arrival(slot: int) -> void:
	var domain := ""
	var depth := "surface"
	match slot:
		1:
			# "Any domain": varies with how the player spent Day 1, never random.
			var idx := (GameState.choices_for_day(1).size() + GameState.buildings.size()) % Content.ARRIVAL_DOMAIN_ORDER.size()
			domain = str(Content.ARRIVAL_DOMAIN_ORDER[idx])
		2:
			domain = _neglected_domain()
			depth = "practiced"
		3:
			domain = _urgent_domain()
			depth = "practiced"
		4:
			domain = _urgent_domain()
			depth = "deep" if GameState.season != "late_summer" else "practiced"
	if domain == "" or _used_domains().has(domain):
		for d in Content.ARRIVAL_DOMAIN_ORDER:
			if not _used_domains().has(d):
				domain = str(d)
				break
	var a: Dictionary = Content.ARRIVALS[domain]
	var id := str(a["id"])
	var n := GameState.make_npc(id, str(a["name"]), "Arrived Day %d" % GameState.current_day, domain,
		GameState.ARC_SETTLING, "arrival", "zone_2")
	n["is_arrival"] = true
	n["arrival_day"] = GameState.current_day
	n["depth"] = depth
	n["pron"] = a["pron"]
	n["archetype"] = str(a["archetype"])
	n["signal"] = str(a["signal"][depth])
	n["answer"] = str(a["answer"])
	n["stage"] = "housing"
	n["output"] = 0.5
	n["slot"] = slot
	GameState.npc_states[id] = n
	GameState.arrival_order.append(id)
	GameState.add_log(str(a["scene"]), "plain")
	if GameState.season == "deep_winter":
		GameState.add_log("%s says the name of the township before anyone tells %s." % [str(a["name"]), Content.pron(id, 1)], "dim")
	else:
		GameState.add_log("Ruth Callan asks a name, an injury, a trade. The name is %s." % str(a["name"]), "dim")
	EventBus.arrival_spawned.emit(id)
	EventBus.world_changed.emit()


static func _do_house(id: String, near: String) -> void:
	var n: Dictionary = GameState.npc_states[id]
	n["housed_near"] = near
	n["stage"] = "role"
	if near == "":
		GameState.log_choice("arrival_housing_open", "micro", [id], {})
	else:
		GameState.log_choice("arrival_housing", "micro", [id, near], {})
		if near == "constance":
			# She must face their raw hope; it accelerates what she holds.
			GameState.set_flag("constance_housed_arrival")
			GameState.set_npc_emotion("constance", GameState.EMOTION_AFRAID)
		# Housing starts a relationship with the neighbour.
		var key := _pair_key(id, near)
		GameState.cozone_days[key] = maxi(int(GameState.cozone_days.get(key, 0)), 1) if near != "constance" else 0


static func _do_talk(id: String) -> void:
	var n: Dictionary = GameState.npc_states[id]
	n["conversation"] = "asked"
	GameState.log_choice("arrival_conversation", "micro", [id], {})


static func _do_promise(id: String) -> void:
	var n: Dictionary = GameState.npc_states[id]
	n["conversation"] = "promised"
	n["promise_day"] = GameState.current_day
	GameState.log_choice("arrival_false_hope", "micro", [id], {"anchor_erosion_delta": 0.1})
	GameState.add_log("%s breathes out. It is the first time since the road." % str(n["name"]), "dim")


static func is_matched(id: String) -> bool:
	var n: Dictionary = GameState.npc_states.get(id, {})
	if n.is_empty() or not Content.DOMAIN_ZONE.has(str(n["domain"])):
		return false
	return str(n["zone"]) == str(Content.DOMAIN_ZONE[str(n["domain"])])


## Arrival-day dusk: the settling path is whatever the player's three decisions made it.
static func _settle_arrivals_at_dusk(day: int) -> void:
	for id in GameState.arrival_order:
		var n: Dictionary = GameState.npc_states[id]
		if int(n["arrival_day"]) != day or str(n["settling_path"]) != "":
			continue
		n["stage"] = "done"
		if not bool(n["role_assigned"]):
			n["role_assigned"] = true
		var posted := GameState.post_of(id) != ""
		var dependent := str(n["archetype"]) == "dependent"
		if posted:
			n["settling_path"] = "rushed"
			n["output"] = 1.0
			n["arc_state"] = GameState.ARC_FRAGILE if (dependent or day >= 4) else GameState.ARC_FUNCTIONAL
		elif str(n["housed_near"]) != "" and is_matched(id) and str(n["conversation"]) != "" \
				and GameState.stock("provisions") > 0:
			n["settling_path"] = "integration"
			n["output"] = 0.5
		else:
			n["settling_path"] = "accelerated"
			n["output"] = 0.6
			n["arc_state"] = GameState.ARC_FRAGILE if dependent else GameState.ARC_FUNCTIONAL


static func _advance_settling() -> void:
	var day := GameState.current_day
	for id in GameState.arrival_order:
		var n: Dictionary = GameState.npc_states[id]
		if not GameState.npc_is_capable(id):
			continue
		var days_in := day - int(n["arrival_day"])
		match str(n["settling_path"]):
			"integration":
				var fast := _social_guide_present(id)
				if days_in == 1:
					n["arc_state"] = GameState.ARC_CONTRIBUTING if fast else GameState.ARC_PRESENT
					n["output"] = 1.0 if fast else 0.75
				elif days_in == 2 and str(n["arc_state"]) == GameState.ARC_PRESENT:
					n["arc_state"] = GameState.ARC_CONTRIBUTING
					n["output"] = 1.0
			"accelerated":
				if days_in >= 1:
					n["output"] = 0.8
		# The promise fails two mornings later. Quiet and total.
		if str(n.get("conversation", "")) == "promised" and day - int(n.get("promise_day", day)) == 2 \
				and not bool(n.get("promise_failed", false)):
			n["promise_failed"] = true
			var c: Dictionary = GameState.last_choice_for_npc(id, "arrival_false_hope")
			GameState.shift_arc(id, -1, str(c.get("choice_id", "")))
			GameState.add_log("%s walked the road at first light as far as it goes. %s came back before the mill started." % [
				str(n["name"]), Content.pron(id, 0).capitalize()], "plain")


static func _social_guide_present(arrival_id: String) -> bool:
	var zone := str(GameState.npc_states[arrival_id]["zone"])
	for id in GameState.npcs_in_zone(zone):
		if id == arrival_id:
			continue
		var n: Dictionary = GameState.npc_states[id]
		if str(n["domain"]) == "social" and str(n["depth"]) != "surface" and GameState.npc_is_capable(id):
			return true
	return false


static func arrival_bonus(domain: String, need_practiced: bool = false) -> bool:
	for id in GameState.arrival_order:
		var n: Dictionary = GameState.npc_states[id]
		if str(n["domain"]) == domain and GameState.npc_is_capable(id) and is_matched(id) \
				and str(n["settling_path"]) != "" \
				and (not need_practiced or str(n["depth"]) != "surface"):
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════
# End-of-day resolution
# ═══════════════════════════════════════════════════════════════════════════

static func _resolve_crew(day: int) -> void:
	var order: Dictionary = GameState.crew_order
	if order.is_empty():
		if day == 1 and not GameState.crew_unavailable_days.has(day):
			GameState.adjust_faction("association", -0.10, "The crew stood down all of the first day.")
		return
	var cid := str(order["choice_id"])
	match str(order["action"]):
		"crew_fourth_wall":
			var gain := 1.0
			if GameState.built_today > 0:
				gain = 0.5
			if GameState.stock("timber") < 15:
				gain *= 0.5
			else:
				GameState.add_stock("timber", -15)
			if arrival_bonus("construction", true):
				gain += 0.5
			if GameState.has_flag("compact_labor"):
				gain += 1.0
			GameState.wall_progress += gain
			# The crew worked toward the hollow all day. Night 1 is quiet. Night 2 is not.
			GameState.walker_queue.append({"choice_id": cid, "from_night": day + 1})
			if not GameState.has_flag("wall_work_day"):
				GameState.set_flag("wall_work_day", day)
			if GameState.wall_progress >= 2.0 and GameState.structure_walls < 4:
				GameState.structure_walls = 4
				GameState.set_flag("wall_complete_day", day)
				GameState.adjust_faction("association", 0.20, "The fourth wall is up.")
				GameState.shift_arc("ruth", 1, cid)
		"crew_mill_reinforce":
			GameState.set_flag("mill_reinforced")
			if day == 1:
				GameState.set_flag("timeline_slipped_d1")
				GameState.adjust_faction("association", -0.15, "The structure was left at three walls on the first day.")
		"crew_clear_west":
			GameState.clearings.append("west")
			GameState.add_stock("timber", 6)
		"crew_clear_east":
			GameState.clearings.append("east")
			GameState.add_stock("timber", 6)
		"crew_repair":
			var b: Dictionary = GameState.building_by_id(str(order["building_id"]))
			if not b.is_empty() and str(b["state"]) == "damaged":
				b["state"] = "pristine"
				GameState.add_stock("timber", -mini(10, GameState.stock("timber")))
		"crew_clear_walker":
			for w in GameState.walkers:
				if str(w["zone_id"]) == str(order["zone"]) and not bool(w["cleared"]):
					w["cleared"] = true
			GameState.add_stock("timber", 8)
			GameState.set_flag("burned_walker_wood")
		"crew_excavate":
			GameState.peder_foundation_excavated = true
			GameState.set_flag("excavation_day", day)
			GameState.shift_arc("peder", -1, cid)
			GameState.walker_queue.append({"choice_id": cid, "from_night": day})


static func _production(day: int) -> void:
	var season_mult := 1.0
	match GameState.season:
		"turning": season_mult = 0.9
		"deep_winter": season_mult = 0.75
	var out := 0.0
	for id in GameState.npcs_in_zone("zone_1"):
		if GameState.npc_is_capable(id) and id != "constance":
			var o := float(GameState.npc_states[id]["output"])
			if str(GameState.npc_states[id]["arc_state"]) == "fragile":
				o *= 0.7
			out += o
	var timber := out * 8.0
	if GameState.has_flag("mill_reinforced"):
		timber += 8.0
	for b in GameState.standing_buildings():
		if str(b["building_type"]) == "Secondary Processing Shed" and str(b["state"]) == "pristine":
			timber += 8.0
	if GameState.has_flag("watchers_at_mill"):
		timber *= 0.5
	GameState.add_stock("timber", int(round(timber * season_mult)))
	GameState.stockpiles["timber"]["ledger"] = int(GameState.stockpiles["timber"]["ledger"]) + int(round(timber * season_mult))
	var eaten := 12 + GameState.arrival_order.size()
	GameState.add_stock("provisions", -eaten)
	GameState.stockpiles["provisions"]["ledger"] = maxi(0, int(GameState.stockpiles["provisions"]["ledger"]) - eaten)


static func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## Two people in the same day zone for two consecutive days form a bond.
## Neither state line ever says so.
static func _update_bonds(_day: int) -> void:
	var ids: Array = []
	for id in GameState.present_ids():
		if id != "constance" and GameState.npc_is_capable(id):
			ids.append(id)
			GameState.npc_states[id]["zone_days"] = int(GameState.npc_states[id]["zone_days"]) + 1
	var live: Dictionary = {}
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			if str(GameState.npc_states[a]["zone"]) == str(GameState.npc_states[b]["zone"]):
				var key := _pair_key(a, b)
				live[key] = int(GameState.cozone_days.get(key, 0)) + 1
	GameState.cozone_days = live
	# Strongest pairs first; one partner each; "accelerated" arrivals never bond.
	var keys: Array = live.keys()
	keys.sort_custom(func(x, y): return int(live[x]) > int(live[y]) or (int(live[x]) == int(live[y]) and str(x) < str(y)))
	for key in keys:
		if int(live[key]) < 2:
			continue
		var pair: PackedStringArray = str(key).split("|")
		var na: Dictionary = GameState.npc_states[pair[0]]
		var nb: Dictionary = GameState.npc_states[pair[1]]
		if str(na["settling_path"]) == "accelerated" or str(nb["settling_path"]) == "accelerated":
			continue
		var depth := mini(4, int(live[key]) - 1)
		if str(na["bond_partner"]) == pair[1]:
			GameState.set_bond(pair[0], pair[1], depth)
		elif str(na["bond_partner"]) == "" and str(nb["bond_partner"]) == "":
			GameState.set_bond(pair[0], pair[1], depth)
	# A bond does not survive separation unless it was kept.
	for id in ids:
		var n: Dictionary = GameState.npc_states[id]
		var partner := str(n["bond_partner"])
		if partner != "" and not live.has(_pair_key(id, partner)) and not bool(n["bond_acknowledged"]):
			GameState.npc_states[partner]["bond_partner"] = ""
			GameState.npc_states[partner]["bond_depth"] = 0
			n["bond_partner"] = ""
			n["bond_depth"] = 0


static func _heal_injured() -> void:
	if not GameState.npc_is_capable("thomas") or str(GameState.npc_states["thomas"]["zone"]) != "zone_2":
		return
	var capacity := 2 if arrival_bonus("medicine") else 1
	for id in GameState.npc_states:
		if capacity <= 0:
			break
		if id != "thomas" and GameState.npc_is_present(id) and bool(GameState.npc_states[id]["injured"]):
			GameState.npc_states[id]["injured"] = false
			capacity -= 1


## Day 5 dusk: a date that was said out loud, and a wall that is or is not there.
static func _day5_promises(day: int) -> void:
	if day != LAST_DAY:
		return
	if GameState.has_flag("timeline_promised") and GameState.structure_walls < 4:
		GameState.set_flag("promise_broken")
		GameState.adjust_faction("association", -0.40, "The date for the fourth wall passed.")
	if GameState.structure_walls < 4 and GameState.npc_is_capable("ruth") and not GameState.has_flag("ruth_wall_lost"):
		GameState.set_flag("ruth_wall_lost")


# ═══════════════════════════════════════════════════════════════════════════
# Dawn unlocks (ENGAGEMENT_LOOPS): at most one, never labelled, always a complication
# ═══════════════════════════════════════════════════════════════════════════

static func _compute_dawn_unlocks(_day: int) -> void:
	GameState.dawn_unlocks = []
	var best := ""
	var best_i := 1
	for e in GameState.last_night_events:
		var u := str(e.get("day_unlock", ""))
		if u != "" and int(e.get("horror_intensity", 1)) > best_i - 1 and int(e.get("horror_intensity", 1)) >= 2:
			best = u
			best_i = int(e["horror_intensity"]) + 1
	if best != "":
		GameState.dawn_unlocks.append(best)


static func _lamp_words(n: int) -> String:
	const WORDS := ["no lamps", "one lamp", "two lamps", "three lamps", "four lamps", "five lamps"]
	return WORDS[clampi(n, 0, 5)]


# ═══════════════════════════════════════════════════════════════════════════
# Chapter 2 handoff (CHAPTER_ONE "Required Output") — silent, never shown
# ═══════════════════════════════════════════════════════════════════════════

static func handoff() -> Dictionary:
	var npcs := {}
	for id in GameState.npc_states:
		var n: Dictionary = GameState.npc_states[id]
		npcs[id] = {"name": str(n["name"]), "arc_state": str(n["arc_state"]), "gone": bool(n["gone"]),
			"injured": bool(n["injured"]), "saw_surveyor": bool(n["saw_surveyor"]),
			"bond_partner": str(n["bond_partner"]), "is_arrival": bool(n["is_arrival"])}
	var standing := {}
	for f in GameState.factions:
		standing[f] = float(GameState.factions[f]["standing"])
	return {
		"chapter": 1,
		"chapter_1_investment_anchor": GameState.investment_anchor,
		"debt": GameState.debt,
		"chapter_2_debt_floor": clampf(GameState.debt + 0.2, 0.0, 1.0),
		"season": GameState.season,
		"zone5_marked": GameState.zone5_marked,
		"compact_ratified": GameState.compact_ratified,
		"constance_spoke": GameState.constance_window_open,
		"thomas_spoke": GameState.thomas_spoke,
		"peder_foundation_excavated": GameState.peder_foundation_excavated,
		"structure_walls": GameState.structure_walls,
		"active_watchers": GameState.active_watchers(),
		"walkers_standing": GameState.walkers.filter(func(w): return not bool(w["cleared"])).size(),
		"buildings": GameState.buildings.duplicate(true),
		"stockpiles": GameState.stockpiles.duplicate(true),
		"factions": standing,
		"npcs": npcs,
		"macro_choice": str(GameState.flags.get("macro_choice", "")),
		"anchor_state": GameState.anchor_state(),
		"choice_count": GameState.choice_log.size(),
	}
