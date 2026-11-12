extends Node
## Headless playthrough tests. Plays all five days through Chapter.gd — the same
## code path the UI uses — as several personas, and checks the design contracts
## that the frozen docs make non-negotiable.
##
##   godot --headless --path godot res://tests/TestRunner.tscn
##   godot --headless --path godot res://tests/TestRunner.tscn -- --verbose

var failures: Array = []
var checks := 0
var verbose := false
var rng := RandomNumberGenerator.new()

const BANNED_NIGHT_WORDS := ["perhaps", "at least", "but", "still"]


func _ready() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	SaveSystem.enabled = false
	for persona in ["passive", "transparent", "compounder", "careful_builder", "neglectful"]:
		_play(persona, 0)
	for s in range(1, 41):
		_play("random", s)
	_test_save_roundtrip()
	_test_season_map()
	_test_static_text()
	print("")
	print("checks: %d   failures: %d" % [checks, failures.size()])
	for f in failures:
		print("  FAIL  " + str(f))
	get_tree().quit(1 if not failures.is_empty() else 0)


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


# ── Driving the game ────────────────────────────────────────────────────────

func option(target: String, id_or_text: String) -> Dictionary:
	var p: Dictionary = Chapter.panel(target)
	for o in p.get("options", []):
		if str(o.get("id", "")) == id_or_text or str(o.get("text", "")).contains(id_or_text):
			return o
	return {}


func pick(target: String, id_or_text: String) -> bool:
	var o := option(target, id_or_text)
	if o.is_empty():
		return false
	Chapter.choose(o)
	return true


func assign(npc: String, zone: String) -> bool:
	var p: Dictionary = Chapter.panel(npc)
	for o in p.get("options", []):
		if str(o.get("act", "")) == "assign" and str(o.get("zone", "")) == zone:
			Chapter.choose(o)
			return true
	return false


func settle_arrivals(near: String, matched: bool, talk: bool, promise: bool) -> void:
	for id in GameState.arrival_order:
		var n: Dictionary = GameState.npc_states[id]
		if int(n["arrival_day"]) != GameState.current_day:
			continue
		if str(n["stage"]) == "housing":
			var p: Dictionary = Chapter.panel(id)
			for o in p["options"]:
				if str(o["act"]) == "house" and str(o["near"]) == near:
					Chapter.choose(o)
					break
			if str(n["stage"]) == "housing":
				pick(id, "Any open bunk")
		if str(n["stage"]) == "role":
			var z: String = Content.DOMAIN_ZONE[str(n["domain"])] if matched else "zone_1"
			if matched and z == "zone_2":
				pass
			if not assign(id, z):
				# Already in that zone: any other zone still counts as a role.
				assign(id, "zone_1" if z != "zone_1" else "zone_2")
				if matched:
					assign(id, z)
		if talk and str(n["stage"]) == "talk":
			pick(id, "Ask how")
			if promise:
				pick(id, "road is being looked into")


func _play(persona: String, seed_value: int) -> void:
	GameState.reset()
	rng.seed = 9000 + seed_value
	var tag := "%s#%d" % [persona, seed_value]
	var total_events := 0
	for day in range(1, 6):
		Chapter.begin_day(day)
		for step in 21:
			var prog := float(step) / 20.0
			Chapter.tick_day(prog)
			_act(persona, day, prog)
			_check_day_invariants(tag, day)
		Chapter.begin_dusk()
		_roster(persona, day)
		ok(Chapter.posts().size() > Chapter.rosterable().size(), "%s d%d: roster must always have more posts than people (%d posts, %d people)" % [tag, day, Chapter.posts().size(), Chapter.rosterable().size()])
		Chapter.begin_night()
		var queue: Array = GameState.night_queue.duplicate(true)
		total_events += queue.size()
		_check_night(tag, persona, day, queue)
		var entries: Array = Chapter.begin_dawn()
		_check_dawn(tag, persona, day, entries, queue)
		if verbose and seed_value <= 1:
			_dump(tag, day, queue, entries)
	_check_chapter_end(tag, persona, total_events)


func _act(persona: String, day: int, prog: float) -> void:
	match persona:
		"passive":
			pass
		"transparent":
			_act_transparent(day, prog)
		"compounder":
			_act_compounder(day, prog)
		"careful_builder":
			_act_careful(day, prog)
		"neglectful":
			_act_neglectful(day, prog)
		"random":
			_act_random(day, prog)


func _act_transparent(day: int, prog: float) -> void:
	if prog == 0.0:
		if day == 1:
			pick("elias", "elias_report_logged")
			pick("obj_ledger", "ledger_counted_entered")
			pick("peder", "crew_mill_reinforce")
		else:
			pick("peder", "crew_clear_west") or pick("peder", "crew_mill_reinforce")
		if day == 2:
			pick("thomas", "thomas_briefing")
			pick("peder", "peder_foundation_asked")
			pick("peder", "peder_foundation_left")
	settle_arrivals("ruth", true, true, false)
	pick("rep_compact", "compact_surplus_declined")
	pick("rep_association", "association_ledger_unedited")
	pick("rep_dix", "dix_inspection_approved")
	pick("rep_compact", "compact_ask_survey_history")
	pick("rep_association", "association_no_date")
	pick("constance", "constance_asked")
	pick("ruth", "rations_watch_first")
	if day >= 3:
		for id in ["elias", "ruth", "maren", "thomas"]:
			pick(id, "Keep them working together")
	for t in ["maren", "rep_dix"]:
		pick(t, "macro_true_count") or pick(t, "macro_testimony_named") or pick(t, "macro_send_dix_to_constance") or pick(t, "macro_constance_survey")
	pick("obj_ledger", "Log the discrepancy formally")


func _act_compounder(day: int, prog: float) -> void:
	if prog == 0.0:
		pick("peder", "crew_fourth_wall")
		if day == 1:
			pick("obj_ledger", "ledger_carried_forward")
			pick("elias", "elias_report_unlogged")
			assign("maren", "zone_1") 
			Chapter.place_building("Watchtower", "zone_4", Vector2i(-4, 2))
		if day == 2:
			Chapter.place_building("Storehouse", "zone_4", Vector2i(-5, 2))
		if day == 3:
			Chapter.place_building("Bunkhouse", "zone_4", Vector2i(-4, 3))
			assign("elias", "zone_1")
	settle_arrivals("", false, false, false)
	pick("rep_compact", "compact_surplus_accepted")
	pick("rep_association", "association_ledger_edited")
	pick("rep_dix", "dix_inspection_denied")
	pick("rep_compact", "compact_ratification_signed")
	pick("rep_association", "association_date_given")
	pick("rep_dix", "macro_cosign")
	pick("maren", "macro_handover_book")


func _act_careful(day: int, prog: float) -> void:
	# Builds defences away from the hollow, logs things, but takes the surplus.
	if prog == 0.0:
		if day == 1:
			pick("elias", "elias_report_logged")
			pick("peder", "crew_fourth_wall")
			assign("maren", "zone_4")
			Chapter.place_building("Watchtower", "zone_2", Vector2i(0, 1))
		elif day == 2:
			pick("peder", "crew_fourth_wall")
			pick("thomas", "thomas_briefing")
		elif day == 3:
			pick("peder", "crew_clear_west")
			Chapter.place_building("Storehouse", "zone_1", Vector2i(1, -4))
		else:
			pick("peder", "crew_repair") or pick("peder", "crew_clear_walker") or pick("peder", "crew_mill_reinforce")
		pick("peder", "peder_foundation_asked")
	settle_arrivals("elias", true, true, true)
	pick("rep_compact", "compact_surplus_accepted")
	pick("rep_association", "association_ledger_acknowledge")
	pick("rep_dix", "dix_inspection_delayed")
	pick("rep_compact", "compact_ratification_delayed")
	pick("rep_association", "association_date_given")
	pick("ruth", "rations_arrivals_first")
	pick("constance", "constance_asked")
	for t in ["maren", "rep_dix"]:
		pick(t, "macro_carry_self") or pick(t, "macro_withdraw") or pick(t, "macro_testimony_unnamed") or pick(t, "macro_refuse_filing")
	if day >= 3:
		for id in ["elias", "ruth", "maren", "thomas", "peder"]:
			pick(id, "Keep them working together")


func _act_neglectful(day: int, prog: float) -> void:
	# Answers nothing, moves everyone off their posts, builds against the hollow.
	if prog == 0.0:
		if day == 1:
			assign("elias", "zone_1")
			assign("thomas", "zone_4")
			pick("peder", "crew_hollow_survey")
			Chapter.place_building("Bunkhouse", "zone_4", Vector2i(-4, 2))
		if day == 2:
			Chapter.place_building("Secondary Processing Shed", "zone_4", Vector2i(-5, 2))
		if day == 4:
			pick("peder", "peder_foundation_asked")
			pick("peder", "crew_excavate")
	settle_arrivals("constance", false, true, true)


func _act_random(day: int, prog: float) -> void:
	var targets: Array = ["obj_ledger", "obj_board", "rep_compact", "rep_association", "rep_dix"]
	targets.append_array(GameState.npc_states.keys())
	for i in 2:
		if rng.randf() < 0.45:
			var t: String = targets[rng.randi() % targets.size()]
			var p: Dictionary = Chapter.panel(t)
			var opts: Array = p.get("options", [])
			if not opts.is_empty():
				Chapter.choose(opts[rng.randi() % opts.size()])
	if rng.randf() < 0.07:
		var z: String = ["zone_1", "zone_2", "zone_3", "zone_4", "zone_5"][rng.randi() % 5]
		var bt: String = Content.BUILD_ORDER[rng.randi() % Content.BUILD_ORDER.size()]
		var before := GameState.buildings.size()
		Chapter.place_building(bt, z, Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6)))
		if z == "zone_5":
			ok(GameState.buildings.size() == before, "random: building placed inside the hollow")
	if rng.randf() < 0.15:
		_random_roster()
	var _unused := day + int(prog)


func _random_roster() -> void:
	var posts: Array = Chapter.posts()
	var people: Array = Chapter.rosterable()
	if people.is_empty():
		return
	var post: Dictionary = posts[rng.randi() % posts.size()]
	if rng.randf() < 0.2:
		Chapter.set_post(str(post["id"]), "")
	else:
		Chapter.set_post(str(post["id"]), str(people[rng.randi() % people.size()]))


func _roster(persona: String, day: int) -> void:
	match persona:
		"transparent":
			Chapter.set_post("post_ridge", "elias")
			if day >= 2:
				Chapter.set_post("post_west", "ruth")
			if day >= 4:
				Chapter.set_post("post_structure", "maren")
		"compounder":
			# Staffs the tower it built against the hollow and nothing else.
			for p in Chapter.posts():
				if str(p["kind"]) == "tower" and str(p["id"]) != "post_ridge":
					Chapter.set_post(str(p["id"]), "thomas")
			if day >= 3:
				Chapter.set_post("post_structure", "maren")
			if day == 5:
				for id in GameState.arrival_order:
					if int(GameState.npc_states[id]["arrival_day"]) == 5:
						Chapter.set_post("post_west", id)
		"careful_builder":
			Chapter.set_post("post_ridge", "elias")
			for p in Chapter.posts():
				if str(p["kind"]) == "tower" and str(p["id"]) != "post_ridge":
					Chapter.set_post(str(p["id"]), "ruth")
			if day >= 3:
				Chapter.set_post("post_structure", "peder")
		"neglectful":
			pass
		"random":
			for i in 3:
				_random_roster()


# ── Contracts ───────────────────────────────────────────────────────────────

func _check_day_invariants(tag: String, day: int) -> void:
	ok(GameState.debt >= 0.0 and GameState.debt <= 1.0, "%s d%d: debt out of range" % [tag, day])
	ok(GameState.capable_count() >= GameState.POPULATION_FLOOR, "%s d%d: population floor broken (%d)" % [tag, day, GameState.capable_count()])
	for kind in GameState.stockpiles:
		ok(int(GameState.stockpiles[kind]["count"]) >= 0, "%s d%d: negative stock %s" % [tag, day, kind])
	# Panels must always be well-formed and never label an option.
	for t in GameState.npc_states.keys() + ["obj_ledger", "obj_board", "rep_compact", "rep_association", "rep_dix"]:
		var p: Dictionary = Chapter.panel(str(t))
		for o in p.get("options", []):
			var text := str(o.get("text", ""))
			ok(text != "", "%s d%d: empty option text on %s" % [tag, day, t])
			for bad in ["(", "risk", "danger", "moral", "debt", "DEBT", "+", "%"]:
				ok(not text.contains(bad), "%s d%d: option carries a label '%s': %s" % [tag, day, bad, text])
		for l in p.get("lines", []):
			ok(not str(l["text"]).contains("{"), "%s d%d: unfilled template on %s: %s" % [tag, day, t, str(l["text"])])


func _check_night(tag: String, persona: String, day: int, queue: Array) -> void:
	for e in queue:
		var creature := str(e.get("creature", "none"))
		var text := str(e["event_text"])
		ok(text != "", "%s n%d: empty event text" % [tag, day])
		ok(not text.contains("{"), "%s n%d: unfilled template: %s" % [tag, day, text])
		ok(not str(e.get("thread", "")).contains("{"), "%s n%d: unfilled thread template: %s" % [tag, day, str(e.get("thread", ""))])
		ok(float(e["hour"]) >= 0.0 and float(e["hour"]) <= 10.0, "%s n%d: event hour out of range" % [tag, day])
		# Pillar 1 / 4: nothing happens at night that a day choice did not cause.
		if creature != "surveyor":
			ok(not e["cause_chain"].is_empty(), "%s n%d: event without a cause: %s" % [tag, day, text])
		for cid in e["cause_chain"]:
			var c: Dictionary = GameState.choice_by_id(str(cid))
			ok(not c.is_empty(), "%s n%d: cause %s is not in the choice log" % [tag, day, str(cid)])
			if not c.is_empty():
				ok(int(c["day_cycle"]) <= day, "%s n%d: cause from the future" % [tag, day])
		if creature == "surveyor":
			ok(day >= 4, "%s n%d: the Surveyor appeared before Night 4" % [tag, day])
		_check_banned(tag, day, text)
		_check_banned(tag, day, str(e.get("thread", "")))
	if day >= 4:
		var seen := false
		for e in queue:
			if str(e.get("creature", "")) == "surveyor":
				seen = true
		ok(seen, "%s n%d: the Surveyor did not walk" % [tag, day])
	if persona == "passive":
		# "A player who made no choices generates no creatures." What does surface
		# must trace to a specific thing that was left undone and logged as such.
		for e in queue:
			var cr := str(e.get("creature", "none"))
			ok(cr == "none" or cr == "surveyor", "passive n%d: a creature appeared with no choices made: %s" % [day, str(e["event_text"])])
			if cr == "none":
				for cid in e["cause_chain"]:
					ok(bool(GameState.choice_by_id(str(cid)).get("choice_payload", {}).get("by_default", false)) \
						or str(GameState.choice_by_id(str(cid))["action_type"]).ends_with("unanswered") \
						or str(GameState.choice_by_id(str(cid))["action_type"]) in ["association_left_waiting", "compact_ratification_delayed"],
						"passive n%d: event traced to a choice the passive player did not make: %s" % [day, str(e["event_text"])])
	if day == 1:
		var creatures := {}
		for e in queue:
			creatures[str(e.get("creature", "none"))] = true
		ok(not (creatures.has("hollow_walker") and creatures.has("ledger_watcher")), "%s n1: Walker and Watcher on the same first night" % tag)


func _check_banned(tag: String, day: int, text: String) -> void:
	var lower := " " + text.to_lower() + " "
	for w in BANNED_NIGHT_WORDS:
		var re := RegEx.new()
		re.compile("\\b" + w + "\\b")
		ok(re.search(lower) == null, "%s n%d: night register uses '%s': %s" % [tag, day, w, text])


func _check_dawn(tag: String, persona: String, day: int, entries: Array, queue: Array) -> void:
	if day == 1:
		ok(entries.size() <= 1, "%s dawn1: more than one consequence surfaced (%d)" % [tag, entries.size()])
	if queue.is_empty() and day < 5:
		ok(entries.is_empty(), "%s dawn%d: a thread was manufactured for a quiet night" % [tag, day])
	var seen := {}
	for en in entries:
		var s1 := str(en["sentence_1"])
		var s2 := str(en["sentence_2"])
		ok(DawnThread.passes_reveal_test(s1, s2, str(en["npc_id"])), "%s dawn%d: entry fails the Reveal Test: %s / %s" % [tag, day, s1, s2])
		ok(not seen.has(str(en["npc_id"])), "%s dawn%d: two entries for %s" % [tag, day, str(en["npc_id"])])
		seen[str(en["npc_id"])] = true
		ok(not s1.contains("{") and not s2.contains("{"), "%s dawn%d: unfilled template: %s / %s" % [tag, day, s1, s2])
		ok(s1.contains("Day "), "%s dawn%d: sentence 1 does not name the day: %s" % [tag, day, s1])
		ok(not GameState.choice_by_id(str(en["choice_id"])).is_empty(), "%s dawn%d: entry cites a missing choice" % [tag, day])
		_check_banned(tag, day, s1)
		_check_banned(tag, day, s2)
		# Two sentences maximum on the consequence side would be ideal; cap the length.
		ok(s2.length() < 260, "%s dawn%d: sentence 2 too long (%d)" % [tag, day, s2.length()])
	ok(GameState.capable_count() >= GameState.POPULATION_FLOOR, "%s dawn%d: population floor broken" % [tag, day])
	for kind in GameState.stockpiles:
		ok(int(GameState.stockpiles[kind]["count"]) >= 0, "%s dawn%d: negative stock" % [tag, day])


var stats := {}

func _check_chapter_end(tag: String, persona: String, total_events: int) -> void:
	ok(GameState.chapter_complete, "%s: chapter did not complete" % tag)
	var macros := 0
	for c in GameState.choice_log:
		if str(c["moral_tier"]) == "macro":
			macros += 1
			ok(int(c["day_cycle"]) == 5, "%s: macro choice before Day 5" % tag)
	ok(macros == 1, "%s: expected exactly one macro choice, got %d" % [tag, macros])
	var h: Dictionary = Chapter.handoff()
	ok(JSON.stringify(h) != "", "%s: handoff not serialisable" % tag)
	var worse := 0
	var better := 0
	for id in GameState.ORIGINAL_SIX:
		var n: Dictionary = GameState.npc_states[id]
		var a := GameState.arc_rank(str(n["arc_state"]))
		var b := GameState.arc_rank(str(n["opening_arc"]))
		if bool(n["gone"]) or a < b:
			worse += 1
		elif a > b:
			better += 1
	if persona == "compounder":
		ok(GameState.zone5_marked, "compounder: the Surveyor should mark Zone 5 (debt %.2f)" % GameState.debt)
		ok(worse >= 2, "compounder: at least two people should be worse off (%d)" % worse)
	if persona == "transparent":
		ok(not GameState.zone5_marked, "transparent: the Surveyor should depart (debt %.2f)" % GameState.debt)
		# No clean ending: transparency still costs someone.
		ok(worse >= 1, "transparent: every ending is compromised — someone must be worse off")
		ok(better >= 1, "transparent: at least one arc should have advanced")
	if persona == "passive":
		ok(h["chapter_1_investment_anchor"] != "" or GameState.choice_log.size() <= 1, "passive: anchor")
	if persona != "random":
		print("%-18s debt %.2f  season %-11s marked %-5s  events %2d  worse %d  better %d  anchor %-9s walls %d  fork %s" % [
			tag, GameState.debt, GameState.season, str(GameState.zone5_marked), total_events, worse, better,
			GameState.investment_anchor, GameState.structure_walls, str(GameState.flags.get("macro_fork", ""))])
	else:
		stats["runs"] = int(stats.get("runs", 0)) + 1
		stats["marked"] = int(stats.get("marked", 0)) + (1 if GameState.zone5_marked else 0)
		stats["events"] = int(stats.get("events", 0)) + total_events
		stats["worse"] = int(stats.get("worse", 0)) + worse
		stats["better"] = int(stats.get("better", 0)) + better
		stats["fork_" + str(GameState.flags.get("macro_fork", ""))] = int(stats.get("fork_" + str(GameState.flags.get("macro_fork", "")), 0)) + 1
		if int(stats["runs"]) == 40:
			print("random x40: %s" % str(stats))


func _dump(tag: String, day: int, queue: Array, entries: Array) -> void:
	print("── %s  night %d  (debt %.2f, %s) ──" % [tag, day, GameState.debt, GameState.season])
	for e in queue:
		print("   [%4.1f] %s" % [float(e["hour"]), str(e["event_text"])])
	for en in entries:
		print("   > %s" % str(en["sentence_1"]))
		print("   > %s" % str(en["sentence_2"]))
	if day == 5:
		for l in DawnThread.closing_lines():
			print("   . %s" % str(l))


# ── Unit-ish tests ──────────────────────────────────────────────────────────

func _test_save_roundtrip() -> void:
	GameState.reset()
	rng.seed = 4242
	for day in range(1, 4):
		Chapter.begin_day(day)
		for step in 11:
			Chapter.tick_day(float(step) / 10.0)
			_act_random(day, float(step) / 10.0)
		Chapter.begin_dusk()
		Chapter.begin_night()
		if day < 3:
			Chapter.begin_dawn()
	var a := var_to_str(GameState.to_dict())
	var snapshot: Dictionary = str_to_var(a)
	GameState.reset()
	GameState.from_dict(snapshot)
	var b := var_to_str(GameState.to_dict())
	ok(a == b, "save: state does not round-trip through to_dict/from_dict")
	# And the restored session can finish the night it was saved in.
	var entries: Array = Chapter.begin_dawn()
	ok(typeof(entries) == TYPE_ARRAY, "save: restored session could not reach dawn")


func _test_season_map() -> void:
	# TIME_SYSTEM.md Season Map rows.
	ok(Chapter.target_season(3, 0.10) == "late_summer", "season: low debt day 3")
	ok(Chapter.target_season(4, 0.45) == "turning", "season: mid debt day 4")
	ok(Chapter.target_season(3, 0.75) == "turning", "season: high debt day 3")
	ok(Chapter.target_season(5, 0.75) == "deep_winter", "season: high debt day 5")
	ok(Chapter.target_season(2, 0.90) == "turning", "season: max debt day 2")
	ok(Chapter.target_season(4, 0.90) == "deep_winter", "season: max debt day 4")
	ok(Chapter.target_season(1, 1.00) == "late_summer", "season: day 1 is always late summer")


func _test_static_text() -> void:
	for at in Content.SENTENCE_ONE:
		var s := str(Content.SENTENCE_ONE[at])
		ok(s.contains("{day}"), "sentence 1 for %s does not name the day" % at)
		_check_banned("static", 0, s)
	for id in DawnThread.FINAL_LINES:
		for k in DawnThread.FINAL_LINES[id]:
			_check_banned("final", 0, str(DawnThread.FINAL_LINES[id][k]))
