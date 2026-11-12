class_name NightSim
extends RefCounted
## NightSim — what the day summoned (NIGHT_SURVIVAL.md), computed at dusk.
##
## Offline stand-in for the Horror/Creature Agent and the pre-computed Night Event
## Queue. plan() reads the locked roster and the choice log and produces tonight's
## queue of events (each stamped with an in-game hour, a cause_chain of real
## choice_ids, and the flat second sentence the dawn thread will print) together
## with the full outcome. Nothing is random. commit() applies the outcome at dawn.
##
## CAUSALITY IS THE CONTRACT (Pillars 1 & 4):
##   * A Hollow Walker exists only because a building was placed against the hollow,
##     the crew worked the fourth wall, or the foundation was dug. One per act.
##   * A Ledger Watcher exists only because a discrepancy was covered or the
##     Compact's surplus was taken. It leaves only when the discrepancy is disclosed.
##   * The Surveyor's Shadow walks on Night 4 and Night 5 whatever the player did;
##     what it does at the hollow is the accumulated DEBT.
## A day with no Debt-feeding choices produces a quiet night. Nothing is manufactured.
##
## Night is allocation, not execution: the roster is locked, the player only watches.

const NIGHT_HOURS := 10
## Zone graph, hollow outward.
const ADJ := {
	"zone_5": ["zone_4"], "zone_4": ["zone_5", "zone_2"],
	"zone_2": ["zone_4", "zone_1", "zone_3"], "zone_1": ["zone_2"], "zone_3": ["zone_2"],
}
const WALKER_CAP := [1, 1, 2, 3, 99]
const MAX_WALKERS := 6
const GROUP_CAP := [1, 3, 5, 8, 99]


static func watch_name(hour: int) -> String:
	if hour <= 3:
		return "first watch"
	if hour <= 6:
		return "second watch"
	return "third watch"


static func route(from_zone: String, to_zone: String) -> Array:
	var prev := {from_zone: ""}
	var frontier: Array = [from_zone]
	while not frontier.is_empty():
		var cur: String = frontier.pop_front()
		if cur == to_zone:
			break
		for nxt in ADJ.get(cur, []):
			if not prev.has(nxt):
				prev[nxt] = cur
				frontier.append(nxt)
	if not prev.has(to_zone):
		return [from_zone]
	var path: Array = []
	var node := to_zone
	while node != "":
		path.push_front(node)
		node = str(prev[node])
	return path


# ═══════════════════════════════════════════════════════════════════════════
# Plan
# ═══════════════════════════════════════════════════════════════════════════

static func plan(day: int) -> void:
	var ctx := _context(day)
	var groups: Array = []
	_plan_surveyor(day, ctx, groups)
	_plan_macro(day, ctx, groups)
	_plan_walkers(day, ctx, groups)
	_plan_watchers(day, ctx, groups)
	_plan_ridge(day, ctx, groups)
	_plan_people(day, ctx, groups)

	groups.sort_custom(func(a, b): return int(a["priority"]) > int(b["priority"]))
	var cap: int = GROUP_CAP[clampi(day - 1, 0, 4)]
	var chosen: Array = []
	for g in groups:
		if chosen.size() < cap or bool(g.get("always", false)):
			chosen.append(g)

	var queue: Array = []
	var fx := _empty_fx()
	var n := 0
	for g in chosen:
		for e in g["events"]:
			n += 1
			e["event_id"] = "n%d_e%02d" % [day, n]
			e["night"] = day
			queue.append(e)
		_merge_fx(fx, g["fx"])
	_plan_bond_echo(day, ctx, fx, queue)
	queue.sort_custom(func(a, b): return float(a["hour"]) < float(b["hour"]) or (float(a["hour"]) == float(b["hour"]) and str(a["event_id"]) < str(b["event_id"])))

	# Post history: what the roster will say about last night.
	var history := {}
	for p in Chapter.posts():
		var pid := str(p["id"])
		if ctx["lit"].has(pid):
			history[pid] = "quiet"
		elif ctx["dark"].has(pid):
			history[pid] = "no lamp"
		elif Chapter.hands_cover(p):
			history[pid] = "quiet"
		else:
			history[pid] = "empty"
	for pid in fx["history"]:
		history[pid] = fx["history"][pid]
	fx["history"] = history
	fx["oil"] = ctx["lit"].size() * 2
	fx["lit"] = ctx["lit"].duplicate()
	fx["walker_target"] = _walker_target().get("post", "")
	fx["walkers"] = ctx["walkers_after"]
	fx["walker_queue"] = ctx["queue_after"]
	fx["walker_paths"] = ctx["walker_paths"]
	GameState.night_queue = queue
	GameState.night_result = fx


## Which staffed posts have a lamp tonight: [lit, dark], each post_id -> npc_id.
## There is oil for stock/2 lamps; posts are lit in roster order.
static func lit_posts() -> Array:
	var lamps := GameState.stock("oil") / 2
	var lit := {}
	var dark := {}
	for p in Chapter.posts():
		var pid := str(p["id"])
		var who := str(GameState.night_posts.get(pid, ""))
		if who == "" or not GameState.npc_is_capable(who):
			continue
		if lit.size() < lamps:
			lit[pid] = who
		else:
			dark[pid] = who
	return [lit, dark]


static func _context(day: int) -> Dictionary:
	var both := lit_posts()
	var lit: Dictionary = both[0]
	var dark: Dictionary = both[1]
	var arc := {}
	for id in GameState.npc_states:
		arc[id] = GameState.arc_rank(str(GameState.npc_states[id]["arc_state"]))
	var comforted := {}
	return {
		"day": day, "lit": lit, "dark": dark, "arc": arc, "capable": GameState.capable_count(),
		"comforted": comforted, "hit": {}, "walkers_after": [], "queue_after": [], "walker_paths": [],
		"direct": day >= 3,
		"med_floor": Chapter.arrival_bonus("medicine", true),
	}


static func _empty_fx() -> Dictionary:
	return {"arc": [], "emotion": {}, "injured": [], "gone": [], "flags": {}, "buildings": {},
		"stock": {}, "debt": 0.0, "treeline": 0, "history": {}, "saw": [], "faction": [],
		"double_sources": [], "surveyor": {}}


static func _merge_fx(into: Dictionary, fx: Dictionary) -> void:
	into["arc"].append_array(fx.get("arc", []))
	into["injured"].append_array(fx.get("injured", []))
	into["gone"].append_array(fx.get("gone", []))
	into["saw"].append_array(fx.get("saw", []))
	into["faction"].append_array(fx.get("faction", []))
	into["double_sources"].append_array(fx.get("double_sources", []))
	for k in ["emotion", "flags", "buildings", "history", "surveyor"]:
		for key in fx.get(k, {}):
			into[k][key] = fx[k][key]
	for kind in fx.get("stock", {}):
		into["stock"][kind] = int(into["stock"].get(kind, 0)) + int(fx["stock"][kind])
	into["debt"] = float(into["debt"]) + float(fx.get("debt", 0.0))
	into["treeline"] = int(into["treeline"]) + int(fx.get("treeline", 0))


static func _group(priority: int, always: bool = false) -> Dictionary:
	return {"priority": priority, "always": always, "events": [], "fx": _empty_fx()}


static func _ev(g: Dictionary, hour: float, text: String, thread: String, npcs: Array, cause: Array,
		zone_id: String, intensity: int, creature: String = "none", extra: Dictionary = {}) -> Dictionary:
	var who := str(npcs[0]) if not npcs.is_empty() else ""
	var e := {
		"hour": hour, "event_text": Content.fill(text, who), "thread": Content.fill(thread, who),
		"threat_npc_ids": npcs, "cause_chain": cause.filter(func(c): return str(c) != ""),
		"zone_id": zone_id, "horror_intensity": intensity, "creature": creature,
	}
	for k in extra:
		e[k] = extra[k]
	g["events"].append(e)
	return e


## Someone on a post was reached by what came. Mirrors GameState.shift_arc's floor
## so the text the player reads tonight is the outcome that is committed at dawn.
## Returns "steady" | "shaken" | "broken" | "gone".
static func _post_hit(ctx: Dictionary, g: Dictionary, npc_id: String, choice_id: String, hard: bool) -> String:
	var fx: Dictionary = g["fx"]
	fx["emotion"][npc_id] = GameState.EMOTION_AFRAID
	var n: Dictionary = GameState.npc_states[npc_id]
	# A bonded partner also on watch, or a full ration before the watch, absorbs the first blow.
	var partner := str(n["bond_partner"])
	var has_comfort: bool = (partner != "" and GameState.post_of(partner) != "") \
		or str(GameState.flags.get("rations_%d" % int(ctx["day"]), "")) == "rations_watch_first"
	if has_comfort and not ctx["comforted"].has(npc_id) and not hard:
		ctx["comforted"][npc_id] = true
		return "steady"
	var delta := -1
	if str(n["settling_path"]) == "rushed" or str(n["arc_state"]) == GameState.ARC_SETTLING:
		delta = -2
	var rank: int = int(ctx["arc"][npc_id])
	var target := maxi(0, rank + delta)
	if bool(ctx["med_floor"]):
		target = maxi(target, 1)
	var day: int = int(ctx["day"])
	if rank <= 1 and hard and day >= 4 and GameState.debt >= 0.6 and int(ctx["capable"]) > GameState.POPULATION_FLOOR:
		ctx["capable"] = int(ctx["capable"]) - 1
		ctx["arc"][npc_id] = -1
		fx["gone"].append([npc_id, choice_id])
		return "gone"
	if target == 0 and rank > 0:
		if int(ctx["capable"]) <= GameState.POPULATION_FLOOR:
			target = 1
		else:
			ctx["capable"] = int(ctx["capable"]) - 1
	if target == rank:
		return "steady"
	ctx["arc"][npc_id] = target
	ctx["hit"][npc_id] = choice_id
	fx["arc"].append([npc_id, target - rank, choice_id])
	return "broken" if target == 0 else "shaken"


static func _cause_npc(choice_id: String, fallback_zone: String) -> String:
	var c: Dictionary = GameState.choice_by_id(choice_id)
	for id in c.get("npc_ids", []):
		if GameState.npc_is_present(str(id)):
			return str(id)
	for id in GameState.npcs_in_zone(fallback_zone):
		if id != "constance":
			return id
	for id in ["peder", "ruth", "elias", "maren", "thomas"]:
		if GameState.npc_is_present(id):
			return id
	return ""


# ── Hollow Walkers ──────────────────────────────────────────────────────────

static func _walker_target() -> Dictionary:
	var newest: Dictionary = {}
	for b in GameState.standing_buildings():
		if newest.is_empty() or int(b["order"]) > int(newest["order"]):
			newest = b
	if not newest.is_empty():
		return {"kind": "building", "zone_id": str(newest["zone_id"]), "building": newest,
			"name": str(newest["building_type"]), "post": "post_%s" % str(newest["id"])}
	if GameState.has_flag("wall_work_day") or GameState.peder_foundation_excavated:
		return {"kind": "structure", "zone_id": "zone_4", "name": "incomplete structure", "post": "post_structure"}
	return {}


static func _tower_in(ctx: Dictionary, zone_id: String) -> String:
	for p in Chapter.posts():
		if str(p["kind"]) != "tower" or str(p["zone_id"]) != zone_id:
			continue
		var pid := str(p["id"])
		if not ctx["lit"].has(pid):
			continue
		if p.has("building_id") and str(GameState.building_by_id(str(p["building_id"])).get("state", "")) != "pristine":
			continue
		return pid
	return ""


static func _west_witness(ctx: Dictionary) -> Array:
	for pid in ["post_west", "post_structure"]:
		if ctx["lit"].has(pid):
			return [str(ctx["lit"][pid]), pid]
	for p in Chapter.posts():
		if str(p["zone_id"]) == "zone_4" and ctx["lit"].has(str(p["id"])):
			return [str(ctx["lit"][str(p["id"])]), str(p["id"])]
	return []


static func _plan_walkers(day: int, ctx: Dictionary, groups: Array) -> void:
	var movers: Array = []
	for w in GameState.walkers:
		if not bool(w["cleared"]):
			var m: Dictionary = w.duplicate(true)
			m["new"] = false
			movers.append(m)
	var cap: int = mini(WALKER_CAP[clampi(day - 1, 0, 4)], MAX_WALKERS)
	var queue_after: Array = []
	var fresh := 0
	var first_cause := ""
	for src in GameState.walker_queue:
		if int(src["from_night"]) <= day and movers.size() < cap:
			movers.append({"id": "w%d_%d" % [day, movers.size() + 1], "choice_id": str(src["choice_id"]),
				"zone_id": "zone_5", "day_spawned": day, "cleared": false, "new": true})
			fresh += 1
			if first_cause == "":
				first_cause = str(src["choice_id"])
		else:
			queue_after.append(src)
	# Season: more of them per active source (TIME_SYSTEM).
	var extra := 0
	if fresh > 0:
		extra = 1 if GameState.season == "turning" else (2 if GameState.season == "deep_winter" else 0)
	for i in extra:
		if movers.size() < cap:
			movers.append({"id": "w%d_%d" % [day, movers.size() + 1], "choice_id": first_cause,
				"zone_id": "zone_5", "day_spawned": day, "cleared": false, "new": true})
	ctx["queue_after"] = queue_after
	if movers.is_empty():
		return

	var g := _group(120, true)
	var target := _walker_target()
	var step := 2 if GameState.season == "deep_winter" else 3
	var held := {}            # tower post_id -> count
	var held_cause := {}
	var new_count := 0
	var new_cause := ""
	var left := {}            # zone -> [count, cause]
	var stopped := {}         # zone -> [count, cause]
	var passed := 0
	var passed_cause := ""
	var pass_hour := 99.0
	var reach_count := 0
	var reach_hour := 99.0
	var reach_cause := ""
	var idx := 0
	for m in movers:
		var cid := str(m["choice_id"])
		var start := str(m["zone_id"])
		var hour := minf(1.0 + float(idx) * 0.5, 4.0)
		var cur := start
		var path: Array = [[start, hour]]
		var outcome := ""
		if bool(m["new"]):
			new_count += 1
			if new_cause == "":
				new_cause = cid
		if not target.is_empty():
			if start == str(target["zone_id"]):
				# Already standing beside it. It leans at the third watch.
				outcome = "reached"
				hour = minf(7.0 + float(idx) * 0.25, 9.5)
			else:
				var zones := route(start, str(target["zone_id"]))
				var first := true
				for zi in range(1, zones.size()):
					var z: String = zones[zi]
					var t := hour + float(step)
					var slowed_by_person := false
					if first and start == "zone_5":
						# A clearing slows them. So does a person on the cut line, at a price.
						if GameState.clearings.has("west"):
							t += 3.0
						if ctx["lit"].has("post_west"):
							t += 3.0
							slowed_by_person = true
					first = false
					if t > float(NIGHT_HOURS):
						break
					var tower := _tower_in(ctx, z)
					if tower != "":
						var holder := str(ctx["lit"][tower])
						var limit := 1 if bool(GameState.npc_states[holder]["injured"]) else 99
						if int(held.get(tower, 0)) < limit:
							held[tower] = int(held.get(tower, 0)) + 1
							held_cause[tower] = cid
							outcome = "held"
							break
					if slowed_by_person:
						passed += 1
						pass_hour = minf(pass_hour, t - 1.0)
						if passed_cause == "":
							passed_cause = cid
					cur = z
					hour = t
					path.append([cur, hour])
				if outcome != "held" and cur == str(target["zone_id"]):
					outcome = "reached"
		if outcome == "reached":
			reach_count += 1
			reach_hour = minf(reach_hour, hour)
			if reach_cause == "":
				reach_cause = cid
		elif outcome == "" and cur != start and cur != "zone_5":
			var sc: Array = stopped.get(cur, [0, cid])
			stopped[cur] = [int(sc[0]) + 1, str(sc[1])]
		if cur != start and not bool(m["new"]):
			var lc: Array = left.get(start, [0, cid])
			left[start] = [int(lc[0]) + 1, str(lc[1])]
		ctx["walkers_after"].append({"id": str(m["id"]), "choice_id": cid, "zone_id": cur,
			"day_spawned": int(m["day_spawned"]), "cleared": false})
		ctx["walker_paths"].append({"id": str(m["id"]), "path": path, "end_hour": hour})
		idx += 1

	# ── What is said about it ──
	if new_count > 0:
		var witness := _west_witness(ctx)
		var wn := str(witness[0]) if not witness.is_empty() else _cause_npc(new_cause, "zone_4")
		var many := new_count > 1
		if not witness.is_empty():
			g["fx"]["emotion"][wn] = GameState.EMOTION_AFRAID
			if bool(ctx["direct"]):
				_ev(g, 1.0, ("{npc} counts the trees at the western edge. There are %s more than there were at dusk. They are walking." % _count_word(new_count)) if many
					else "{npc} counts the trees at the western edge. There is one more than there was at dusk. It is walking.",
					"{npc} counted %s more at the western edge than there %s at dusk. {He} watched %s walk." % [
						("%s trees" % _count_word(new_count)) if many else "one tree", "were" if many else "was", "them" if many else "it"],
					[wn], [new_cause], "zone_5", 2, "hollow_walker", {"focus": "zone_5"})
			else:
				_ev(g, 1.0, "{npc} reports a shape at the western treeline that was not there at dusk. It has not moved. It is closer than it should be for something that has not moved.",
					"{npc} reported a shape at the western treeline that was not there at dusk. {He} did not go closer.",
					[wn], [new_cause], "zone_5", 1, "hollow_walker", {"focus": "zone_5"})
		else:
			_ev(g, 1.0, "Something is standing at the edge of the western hollow that was not standing there at dusk. No one is posted where it could be seen.",
				"Something stood at the edge of the western hollow in the night. No one was posted to see it. {npc} found the ground pressed flat at first light.",
				[wn], [new_cause], "zone_5", 1, "hollow_walker", {"focus": "zone_5"})
	for zone_id in left:
		var n_left := int(left[zone_id][0])
		var where := GameState.zone_name(str(zone_id)) if str(zone_id) != "zone_5" else "the edge of the western hollow"
		_ev(g, 1.5, ("What stood at %s at dusk is not standing there now." % where) if n_left == 1
			else ("None of what stood at %s at dusk is standing there now." % where),
			"", [], [str(left[zone_id][1])], str(zone_id), 2, "hollow_walker", {"focus": str(zone_id)})
	if passed > 0:
		var pw := str(ctx["lit"]["post_west"])
		var res := _post_hit(ctx, g, pw, passed_cause, passed >= 2)
		g["fx"]["history"]["post_west"] = "Walker passed here"
		_ev(g, pass_hour, "It passed the cut line. {npc} stood to one side of it. It did not turn." if passed == 1
			else "%s of them passed the cut line. {npc} stood to one side. None of them turned." % _count_word(passed).capitalize(),
			"{npc} stood at the cut line while %s passed, near enough to touch." % ("it" if passed == 1 else "they")
				+ (" {He} has not gone back to the bunk." if res != "steady" else " {He} finished the watch."),
			[pw], [passed_cause, _post_choice(pw)], "zone_4", 2, "hollow_walker", {"focus": "post_west"})
	if reach_count > 0:
		_walker_reaches(day, ctx, g, reach_cause, target, reach_hour, reach_count)
	for zone_id in stopped:
		var sn := _cause_npc(str(stopped[zone_id][1]), str(zone_id))
		var n_st := int(stopped[zone_id][0])
		_ev(g, float(NIGHT_HOURS) - 0.5, ("It is standing in %s when the light comes. It does not move in the light." % GameState.zone_name(str(zone_id))) if n_st == 1
			else ("%s of them are standing in %s when the light comes. They do not move in the light." % [_count_word(n_st).capitalize(), GameState.zone_name(str(zone_id))]),
			"What walked in the night stopped in %s when the light came. {npc} walks the long way round." % GameState.zone_name(str(zone_id)),
			[sn], [str(stopped[zone_id][1])], str(zone_id), 2, "hollow_walker", {"focus": str(zone_id)})
	if not g["events"].is_empty():
		groups.append(g)

	# Towers that held. The structure is saved. The person is changed.
	for tower in held:
		var g2 := _group(118, true)
		var holder := str(ctx["lit"][tower])
		var count := int(held[tower])
		var cid2 := str(held_cause[tower])
		var n: Dictionary = GameState.npc_states[holder]
		var is_watchman: bool = str(n["domain"]) == "observation" and str(n["depth"]) != "surface"
		var believed: bool = holder != "elias" or GameState.has_choice("elias_report_logged") or GameState.has_flag("elias_heard")
		var pname := Chapter.post_name(tower).split(",")[0]
		if pname == "Eastern Ridge":
			pname = "old watchtower"
		var before := int(GameState.flags.get("held_nights_%s" % holder, 0))
		g2["fx"]["flags"]["held_nights_%s" % holder] = before + 1
		var unlock := "elias_tell" if holder == "elias" else ""
		if count == 1:
			var res2 := "steady"
			if not (is_watchman and believed):
				res2 = _post_hit(ctx, g2, holder, cid2, false)
			else:
				g2["fx"]["emotion"][holder] = GameState.EMOTION_AFRAID
			if before == 0:
				_ev(g2, 6.0, "It came to the edge of the lamplight below the %s and stopped. {npc} kept the lamp on it. {He} did not look away until the light came." % pname,
					"{npc} held the lamp on it from the %s until dawn. " % pname + ("{He} has not been relieved. {He} has not asked to be." if res2 == "steady" else "{He} came down and could not say how long it had been."),
					[holder], [cid2, _post_choice(holder)], Chapter.post_zone(tower), 2, "hollow_walker",
					{"focus": tower, "day_unlock": unlock})
			else:
				_ev(g2, 6.0, "It came to the edge of the lamplight below the %s again. {npc} had the lamp on it before it stopped." % pname,
					"{npc} held the lamp on it from the %s for another night. " % pname + ("{He} has started sleeping in the day." if res2 == "steady" else "{He} did not come down when the light came. {He} had to be fetched."),
					[holder], [cid2, _post_choice(holder)], Chapter.post_zone(tower), 2, "hollow_walker",
					{"focus": tower, "day_unlock": unlock})
		else:
			_post_hit(ctx, g2, holder, cid2, true)
			if not is_watchman:
				g2["fx"]["injured"].append(holder)
			_ev(g2, 6.0, "There were %s of them at the edge of the light below the %s. {npc} had one lamp." % [_count_word(count), pname],
				"{npc} came down from the %s at dawn with {his} hands wrapped. {He} does not say how." % pname,
				[holder], [cid2, _post_choice(holder)], Chapter.post_zone(tower), 3, "hollow_walker",
				{"focus": tower, "day_unlock": unlock})
		g2["fx"]["history"][tower] = "Walker held at the light"
		groups.append(g2)


static func _count_word(n: int) -> String:
	const WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return WORDS[clampi(n, 0, 10)]


static func _post_choice(npc_id: String) -> String:
	var c: Dictionary = GameState.last_choice_for_npc(npc_id, "post_npc")
	return str(c.get("choice_id", ""))


## One or more of them reached what they were walking toward. A building takes one
## step of damage a night, however many lean on it.
static func _walker_reaches(day: int, ctx: Dictionary, g: Dictionary, cid: String, target: Dictionary,
		hour: float, count: int) -> void:
	var zone_id := str(target["zone_id"])
	var zname := GameState.zone_name(zone_id)
	var bname := str(target["name"])
	var post_id := str(target["post"])
	var watch := watch_name(int(hour))
	var guard := str(ctx["lit"].get(post_id, ""))
	var it := "It" if count == 1 else "%s of them" % _count_word(count).capitalize()
	g["fx"]["history"][post_id] = "Walker reached here"
	if guard != "":
		var res := _post_hit(ctx, g, guard, cid, day >= 3 or count >= 2)
		if day >= 3 and GameState.debt >= 0.5 and res != "gone":
			g["fx"]["injured"].append(guard)
		var causes := [cid, _post_choice(guard)]
		match res:
			"gone":
				# Gap 8 authored fallback, verbatim.
				_ev(g, hour, "{npc} did not come in from %s at the third watch. The post is not empty. {npc} is simply not at it." % zname,
					"{npc} did not come in from the %s. The lamp was burning. The post is not empty." % bname,
					[guard], causes, zone_id, 3, "hollow_walker", {"focus": post_id})
			"broken":
				_ev(g, hour, "%s reached the %s at %s at the %s. {npc} was at the post. {He} was found there at first light with the lamp out." % [it, bname, zname, watch],
					"{npc} was found at the %s with the lamp out. {He} would not say when it went out." % bname,
					[guard], causes, zone_id, 3, "hollow_walker", {"focus": post_id})
			_:
				_ev(g, hour, "%s reached the %s at %s at the %s. {npc} was at the post. It leaned on the wall beside {him} the way a tree leans, and went no further." % [it, bname, zname, watch],
					"It stood beside {npc} at the %s until the light came. {npc} has not put down what {he} was holding." % bname,
					[guard], causes, zone_id, 2, "hollow_walker", {"focus": post_id})
		if count < 2:
			return
		hour = minf(hour + 0.5, 9.8)
	var finder := _cause_npc(cid, zone_id)
	if str(target["kind"]) == "structure":
		g["fx"]["flags"]["structure_damaged"] = day
		g["fx"]["flags"]["wall_setback"] = true
		var walled: bool = GameState.has_flag("wall_work_day")
		_ev(g, hour, ("No one was posted at the open frame of the incomplete structure. At the %s something leaned on the fourth wall. The new course is out of true." % watch) if walled
			else ("No one was posted at the open frame of the incomplete structure. At the %s something leaned on the corner post. It is out of true." % watch),
			"No one was posted at the open frame. " + ("The fourth wall's new course" if walled else "The corner post") + " is out of true. {npc} put a level on it and took the level away again.",
			[finder], [cid], zone_id, 2, "hollow_walker", {"focus": "post_structure"})
		return
	var b: Dictionary = target["building"]
	var bid := str(b["id"])
	if str(b["state"]) == "pristine":
		g["fx"]["buildings"][bid] = "damaged"
		_ev(g, hour, "No one was posted at the %s at %s. At the %s something leaned on it. The wall has bowed." % [bname, zname, watch] if guard == ""
			else "There were more than one. The wall of the %s has bowed behind {npc}." % bname,
			"No one was posted at the %s. One wall is staved in from the outside. {npc} found it at first light." % bname if guard == ""
			else "The %s has a wall staved in from the outside. {npc} found it at first light." % bname,
			[finder], [cid], zone_id, 2, "hollow_walker", {"focus": post_id})
	else:
		g["fx"]["buildings"][bid] = "destroyed"
		_ev(g, hour, "The %s at %s was leaned on again. The frame came down slowly and without much sound." % [bname, zname],
			"The %s at %s is down. {npc} found the boards stacked. No one stacked them." % [bname, zname],
			[finder], [cid], zone_id, 3, "hollow_walker", {"focus": post_id})


# ── Ledger Watchers ─────────────────────────────────────────────────────────

static func _plan_watchers(day: int, ctx: Dictionary, groups: Array) -> void:
	var sources: Array = []
	for d in GameState.discrepancies:
		if not bool(d["disclosed"]) and int(d["day"]) <= day:
			sources.append(d)
	if sources.is_empty():
		return
	# Early nights surface one creature type, not both (CHAPTER_ONE season table).
	var walkers_tonight: bool = not ctx["walkers_after"].is_empty()
	var g := _group(95, day >= 3)
	if day <= 2 and walkers_tonight:
		# They do not act where they cannot be told apart. They do multiply.
		var silent := _group(0, true)
		for d in sources:
			silent["fx"]["double_sources"].append(str(d["id"]))
		groups.append(silent)
		return
	var halved := Chapter.arrival_bonus("logistics")
	var stores_open: bool = not ctx["lit"].has("post_mill") and GameState.has_flag("association_walked")
	var floor_frac := 0.2
	for b in GameState.standing_buildings():
		if str(b["building_type"]) == "Storehouse" and str(b["state"]) == "pristine":
			floor_frac = 0.35
	var worst: Dictionary = sources[0]
	var total := 0
	var worst_kind := str(worst["stockpile"])
	var at_floor := false
	for d in sources:
		if int(d["watchers"]) > int(worst["watchers"]):
			worst = d
		var kind := str(d["stockpile"])
		var loss := 6 * int(d["watchers"])
		if halved:
			loss = loss / 2
		if stores_open:
			loss = loss * 3 / 2
		var floor_n := int(float(GameState.stockpiles[kind]["ledger"]) * floor_frac)
		var have := GameState.stock(kind) + int(g["fx"]["stock"].get(kind, 0))
		var take := clampi(have - floor_n, 0, loss)
		if take < loss:
			at_floor = true
		g["fx"]["stock"][kind] = int(g["fx"]["stock"].get(kind, 0)) - take
		total += take
		g["fx"]["double_sources"].append(str(d["id"]))
	worst_kind = str(worst["stockpile"])
	var cid := str(worst["choice_id"])
	var who := _cause_npc(cid, "zone_1")
	var stock_name := str(GameState.stockpiles[worst_kind]["name"]).to_lower()
	var lost := -int(g["fx"]["stock"].get(worst_kind, 0))
	if at_floor:
		g["fx"]["flags"]["watchers_at_mill"] = true
	g["fx"]["history"]["post_mill"] = "the lamp went out"
	var short_line := ("The %s count is short by %d." % [stock_name, lost]) if lost > 0 \
		else "Nothing more is missing from the stores. What was there to take has been taken."
	if not bool(ctx["direct"]):
		_ev(g, 4.5, "The lamp at the Mill Quarter stores went out twice at the second watch. There was no wind. No one was seen at the door.",
			short_line + " {npc} did not write a withdrawal. One line in the ledger is not where it was written.",
			[who], [cid], "zone_1", 1, "ledger_watcher", {"focus": "post_mill"})
	elif day == 3 or not GameState.has_flag("watcher_rows"):
		g["fx"]["flags"]["watcher_rows"] = day
		_ev(g, 4.5, "Every lamp in the Mill Quarter went out at once and came back one at a time, in the wrong order. The tools on the saw floor have been laid out in rows.",
			short_line + " The tools on the saw floor were found laid in a grid. {npc} put them back and did not log it.",
			[who], [cid], "zone_1", 2, "ledger_watcher", {"focus": "post_mill"})
	elif not GameState.has_flag("watcher_shelves"):
		g["fx"]["flags"]["watcher_shelves"] = day
		_ev(g, 4.5, "The stores door was found open at the second watch. Nothing was carried out. Every shelf label has been moved one shelf down.",
			short_line + " Every shelf label in the stores was one shelf down. {npc} moved them back by lamplight.",
			[who], [cid], "zone_1", 2, "ledger_watcher", {"focus": "post_mill"})
	else:
		_ev(g, 4.5, "The ledger was found open on the saw floor at the second watch. It was shut in the manager's post at dusk. The entries on the open page are dated next week.",
			short_line + " The ledger was found open on the saw floor. {npc} carried it back and did not read the open page aloud.",
			[who], [cid], "zone_1", 3, "ledger_watcher", {"focus": "post_mill"})
	if GameState.npc_is_present(who):
		g["fx"]["emotion"][who] = GameState.EMOTION_AFRAID
	if ctx["lit"].has("post_mill"):
		var guard := str(ctx["lit"]["post_mill"])
		if guard != who:
			g["fx"]["emotion"][guard] = GameState.EMOTION_AFRAID
	groups.append(g)


# ── The eastern ridge: witnessed change and unwitnessed change ──────────────

static func _plan_ridge(day: int, ctx: Dictionary, groups: Array) -> void:
	var on_ridge := str(ctx["lit"].get("post_ridge", ""))
	var moving: bool = GameState.debt >= 0.3 or GameState.season != "late_summer"
	if on_ridge == "elias" and not GameState.has_flag("elias_resolved"):
		var g := _group(90)
		g["fx"]["flags"]["elias_resolved"] = day
		if GameState.has_choice("elias_report_logged"):
			var c: Dictionary = GameState.find_choice("elias_report_logged")
			g["fx"]["flags"]["elias_confirmed"] = true
			g["fx"]["arc"].append(["elias", 1, str(c["choice_id"])])
			g["fx"]["treeline"] = 3
			_ev(g, 7.0, "Elias Grout was on the eastern ridge with the report logged. He has the measurement now. The treeline is three yards in from the stake he set last week.",
				"Elias Grout measured the treeline against his stake. Three yards. It is written down in his hand and in the manager's.",
				["elias"], [str(c["choice_id"])], "zone_3", 1, "none", {"focus": "post_ridge"})
		else:
			var c2: Dictionary = GameState.find_choice("elias_report_unlogged")
			g["fx"]["flags"]["elias_unbelieved"] = true
			g["fx"]["arc"].append(["elias", -1, str(c2.get("choice_id", ""))])
			g["fx"]["emotion"]["elias"] = GameState.EMOTION_AFRAID
			g["fx"]["treeline"] = 3
			_ev(g, 7.0, "Elias Grout stood the watch with nothing logged. He saw it again. There is no stake to measure against. There is no record that he ever asked.",
				"Elias Grout saw it again from the eastern ridge. There is nothing to measure it against. He has stopped describing it.",
				["elias"], [str(c2.get("choice_id", ""))], "zone_3", 1, "none", {"focus": "post_ridge"})
		groups.append(g)
		return
	if on_ridge == "" and not ctx["dark"].has("post_ridge"):
		# The one post that faces away from the hollow was not facing anything.
		var cause := ""
		for c3 in GameState.choice_log:
			var at := str(c3["action_type"])
			if (at == "post_cleared" and str(c3["choice_payload"].get("post_id", "")) == "post_ridge") \
					or (at == "assign_npc" and c3["npc_ids"].has("elias") and str(c3["choice_payload"].get("zone_id", "")) != "zone_3") \
					or (at == "post_npc" and str(c3["choice_payload"].get("post_id", "")) != "post_ridge" and _was_ridge_holder(c3)):
				cause = str(c3["choice_id"])
		if cause == "":
			return
		var who := _cause_npc(cause, "zone_3")
		var g2 := _group(88)
		var nights := int(GameState.flags.get("ridge_empty_nights", 0)) + 1
		g2["fx"]["flags"]["ridge_empty_nights"] = nights
		g2["fx"]["treeline"] = 5
		g2["fx"]["debt"] = 0.05
		g2["fx"]["history"]["post_ridge"] = "empty"
		if nights == 1:
			_ev(g2, 8.0, "The eastern ridge post stood empty at the third watch. The one post that faced away from the hollow was not facing anything.",
				"The eastern ridge post was empty at the third watch. {npc} was not there to measure. The treeline is nearer this morning than it was yesterday.",
				[who], [cause], "zone_3", 1 if day <= 2 else 2, "none", {"focus": "post_ridge"})
		else:
			_ev(g2, 8.0, "The eastern ridge post stood empty again. No one counted what moved.",
				"The eastern ridge post has been empty %s nights. {npc} was not there to measure. The last stake cannot be found." % _count_word(nights),
				[who], [cause], "zone_3", 2, "none", {"focus": "post_ridge"})
		groups.append(g2)
		return
	if on_ridge != "" and moving and day >= 2:
		var g3 := _group(10)
		g3["fx"]["treeline"] = 3
		var c4 := _post_choice(on_ridge)
		if c4 == "" and on_ridge == "elias":
			c4 = str(GameState.find_choice("elias_report_logged").get("choice_id", ""))
		if c4 != "":
			_ev(g3, 8.5, "{npc} measured the treeline from the old watchtower. Three yards in from the last stake.",
				"{npc} set a new stake at the eastern treeline. The old one is inside the trees.",
				[on_ridge], [c4], "zone_3", 1, "none", {"focus": "post_ridge"})
			groups.append(g3)


static func _was_ridge_holder(c: Dictionary) -> bool:
	return c["npc_ids"].has("elias")


# ── People: the consequences that are not creatures ─────────────────────────

static func _plan_people(day: int, ctx: Dictionary, groups: Array) -> void:
	# Assigned to the incomplete structure: the arc destabilises the NEXT night.
	for id in GameState.present_ids():
		var key := "structure_assigned_%s" % id
		if GameState.has_flag(key) and int(GameState.flags[key]) < day and not GameState.has_flag("structure_hit_%s" % id) \
				and GameState.npc_is_capable(id):
			var c: Dictionary = {}
			for ch in GameState.choice_log:
				if str(ch["action_type"]) in ["assign_npc", "arrival_role"] and ch["npc_ids"].has(id) \
						and str(ch["choice_payload"].get("zone_id", "")) == "zone_4":
					c = ch
					break
			if c.is_empty():
				continue
			var g := _group(70)
			g["fx"]["flags"]["structure_hit_%s" % id] = day
			var res := _post_hit(ctx, g, id, str(c["choice_id"]), false)
			_ev(g, 7.5, "{npc} took the visible work at the incomplete structure. At the third watch {he} was standing at the open frame, looking out, not in.",
				"{npc} did not report for the morning count. {He} was found at the open frame, facing west." if res != "steady" else "{npc} stood at the open frame through the third watch, facing west. {He} reported for the morning count.",
				[id], [str(c["choice_id"])], "zone_4", 2, "none", {"focus": "post_structure"})
			groups.append(g)

	# Thomas: Day 3 is the last day the silence holds.
	if day >= 3 and not GameState.thomas_spoke and not GameState.has_flag("thomas_fractured") and GameState.npc_is_capable("thomas"):
		var tc: Dictionary = GameState.find_choice("thomas_not_asked")
		if tc.is_empty():
			tc = GameState.last_choice_for_npc("thomas")
		if not tc.is_empty():
			var g2 := _group(80)
			g2["fx"]["flags"]["thomas_fractured"] = day
			g2["fx"]["arc"].append(["thomas", -1, str(tc["choice_id"])])
			g2["fx"]["emotion"]["thomas"] = GameState.EMOTION_AFRAID
			_ev(g2, 5.0, "Thomas Vael laid out instruments at the second watch for a patient. There was no patient. He stood by the table until the light came.",
				"Thomas Vael laid out instruments at the second watch for a patient who was not there. He has not put them away.",
				["thomas"], [str(tc["choice_id"])], "zone_2", 2, "none", {"focus": "zone_2", "day_unlock": "thomas_avoided"})
			groups.append(g2)

	# Day 1 mill reinforcement: the structure stayed at three walls; the labour dispute.
	if GameState.has_flag("timeline_slipped_d1") and not GameState.has_flag("dispute_fired") and GameState.npc_is_capable("ruth"):
		var mc: Dictionary = GameState.find_choice("crew_mill_reinforce", 1)
		var g3 := _group(60)
		g3["fx"]["flags"]["dispute_fired"] = day
		g3["fx"]["emotion"]["ruth"] = GameState.EMOTION_ANGRY
		_ev(g3, 4.0, "Three mill hands knocked at Ruth Callan's bunk at the second watch. They wanted a date for the fourth wall. She did not have one to give.",
			"Ruth Callan was asked for a date at the second watch. She did not have one. She has not asked the manager's post for one.",
			["ruth", "peder"], [str(mc.get("choice_id", ""))], "zone_2", 1, "none", {"focus": "zone_2"})
		groups.append(g3)

	# Day 1 fourth wall, no Walker yet: Night 1 is quiet. Almost.
	if int(GameState.flags.get("wall_work_day", 0)) == day and ctx["walkers_after"].is_empty() and GameState.npc_is_present("peder"):
		var wc: Dictionary = GameState.find_choice("crew_fourth_wall", day)
		var g4 := _group(20)
		_ev(g4, 3.0, "The fourth wall's first course went up today. Peder Lund says the new timber smells wrong. Not rot. Older than rot.",
			"Peder Lund says the new timber smells wrong. Not rot. Older than rot.",
			["peder"], [str(wc.get("choice_id", ""))], "zone_4", 1, "none", {"focus": "post_structure"})
		groups.append(g4)

	# Dix: denied / approved, the night of the answer.
	if GameState.has_choice("dix_inspection_denied", day):
		var dc: Dictionary = GameState.find_choice("dix_inspection_denied", day)
		var who := _cause_npc(str(dc["choice_id"]), "zone_3")
		var g5 := _group(50)
		g5["fx"]["treeline"] = 3
		_ev(g5, 6.5, "The audit flag stays open on the old survey. {npc} reports the western treeline did not hold its line tonight. It rested nearer.",
			"{npc} paced the western treeline at first light. It is three yards nearer than the cut line.",
			[who], [str(dc["choice_id"])], "zone_5", 2, "none", {"focus": "zone_5"})
		groups.append(g5)
	if GameState.has_choice("dix_inspection_approved", day) and GameState.npc_is_present("peder"):
		var ac: Dictionary = GameState.find_choice("dix_inspection_approved", day)
		var g6 := _group(45)
		_ev(g6, 2.5, "Dix's chain is on the county record now. Peder Lund walked the same line after dusk. He says the record is right in every figure and wrong about the ground.",
			"Peder Lund walked Dix's line after dusk. He will not say what gave under the chain at the fourth stake.",
			["peder"], [str(ac["choice_id"])], "zone_5", 1, "none", {"focus": "zone_5"})
		groups.append(g6)
	if GameState.has_choice("compact_ratification_signed", day):
		var rc: Dictionary = GameState.find_choice("compact_ratification_signed", day)
		var who2 := _cause_npc(str(rc["choice_id"]), "zone_1")
		var g7 := _group(55)
		_ev(g7, 5.5, "The existing survey is the township's record now. The Mill Quarter is the quietest it has been since the mill was built. {npc} noticed the quiet first.",
			"{npc} noticed that the Mill Quarter was quiet at the second watch. {He} has stopped mentioning it.",
			[who2], [str(rc["choice_id"])], "zone_1", 2, "none", {"focus": "zone_1"})
		groups.append(g7)

	# The Association stopped waiting: the posts the mill hands covered are not covered.
	if GameState.has_flag("association_walked") and GameState.npc_is_capable("ruth") and not GameState.has_flag("ruth_stood_both") \
			and not (ctx["lit"].has("post_mill") and ctx["lit"].has("post_common")):
		var wc2: Dictionary = GameState.find_choice("association_left_waiting")
		if wc2.is_empty():
			wc2 = GameState.find_choice("association_no_date")
		var g8 := _group(62)
		if not GameState.has_flag("ruth_stood_both"):
			g8["fx"]["flags"]["ruth_stood_both"] = day
			g8["fx"]["arc"].append(["ruth", -1, str(wc2.get("choice_id", ""))])
		g8["fx"]["emotion"]["ruth"] = GameState.EMOTION_ANGRY
		_ev(g8, 5.0, "The lamp round in the Common was not walked. The stores door was not checked. Ruth Callan did both herself after the second watch.",
			"Ruth Callan walked the lamp round and checked the stores herself. She was on the saw floor at first light. She did not mention it.",
			["ruth"], [str(wc2.get("choice_id", ""))], "zone_2", 2, "none", {"focus": "post_common"})
		groups.append(g8)

	# A date was said out loud. The wall is not there.
	if GameState.has_flag("promise_broken") and not GameState.has_flag("promise_fired") and GameState.npc_is_capable("ruth"):
		var pc: Dictionary = GameState.find_choice("association_date_given")
		var g9 := _group(85, true)
		g9["fx"]["flags"]["promise_fired"] = day
		g9["fx"]["arc"].append(["ruth", -1, str(pc.get("choice_id", ""))])
		_ev(g9, 2.0, "The date for the fourth wall passed at dusk. The Association's representative went to Ruth Callan's bunk, not to the manager's post.",
			"Ruth Callan was asked which side of the table she sits on. She has not answered. She has not been to the manager's post.",
			["ruth"], [str(pc.get("choice_id", ""))], "zone_2", 2, "none", {"focus": "zone_2"})
		groups.append(g9)

	# Night 5, three walls: the frost Ruth staked her word against. Traced to whatever
	# took the crew off the wall — which, on the honest path, is the honesty.
	if day == Chapter.LAST_DAY and GameState.structure_walls < 4 and GameState.npc_is_capable("ruth") \
			and not GameState.has_flag("promise_broken"):
		var fc := _wall_lost_cause()
		if not fc.is_empty():
			var g11 := _group(72)
			g11["fx"]["flags"]["ruth_frost"] = day
			g11["fx"]["arc"].append(["ruth", -1, str(fc["choice_id"])])
			_ev(g11, 9.0, "The first frost came at the third watch. The incomplete structure has three walls. Ruth Callan walked out to it and stood where the fourth would be.",
				"Ruth Callan stood where the fourth wall would be when the frost came. She had told the Association before first frost.",
				["ruth"], [str(fc["choice_id"])], "zone_4", 2, "none", {"focus": "post_structure"})
			groups.append(g11)

	# Maren under fear moves it outward to whoever she was last near (gossip pass).
	for tr in GameState.get_meta("gossip_transfers", []):
		if int(tr["day"]) == day and str(tr["from_npc"]) == "maren":
			var to := str(tr["to_npc"])
			if GameState.has_flag("leak_%s" % to) or not GameState.npc_is_capable(to) or int(GameState.flags.get("leak_count", 0)) >= 2:
				continue
			var lc: Dictionary = GameState.find_choice("association_ledger_edited")
			if lc.is_empty():
				lc = GameState.find_choice("ledger_carried_forward")
			if lc.is_empty():
				continue
			var g10 := _group(30)
			g10["fx"]["flags"]["leak_%s" % to] = day
			g10["fx"]["flags"]["leak_count"] = int(GameState.flags.get("leak_count", 0)) + 1
			g10["fx"]["emotion"][to] = GameState.EMOTION_AFRAID
			_ev(g10, 3.5, "{npc} did not sleep. Whatever Maren Voss said at the supply post in the afternoon, {npc} has carried it since.",
				"{npc} did not sleep. {He} has been to the supply post twice this morning and gone in neither time.",
				[to, "maren"], [str(lc["choice_id"])], "zone_2", 1, "none", {"focus": "zone_2"})
			groups.append(g10)
			break


## The choice that most plainly kept the fourth wall from going up.
static func _wall_lost_cause() -> Dictionary:
	var c: Dictionary = GameState.find_choice("peder_foundation_left")
	if not c.is_empty():
		return c
	# The Compact pulled the crew: the latest act that made it do so.
	var latest: Dictionary = {}
	for ch in GameState.choice_log:
		if str(ch["action_type"]) in ["association_ledger_unedited", "dix_inspection_approved",
				"compact_ask_survey_history", "discrepancy_logged", "macro_withdraw", "macro_true_count", "macro_carry_self"]:
			latest = ch
	if not latest.is_empty():
		return latest
	for ch in GameState.choice_log:
		if str(ch["action_type"]).begins_with("crew_") and str(ch["action_type"]) != "crew_fourth_wall":
			latest = ch
	return latest


# ── The Surveyor's Shadow ───────────────────────────────────────────────────

static func strongest_debt_choice() -> Dictionary:
	var best: Dictionary = {}
	for c in GameState.choice_log:
		if float(c["debt_delta"]) > 0.0 and (best.is_empty() or float(c["debt_delta"]) > float(best["debt_delta"])):
			best = c
	return best


static func _surveyor_seers(ctx: Dictionary) -> Array:
	var out: Array = []
	for p in Chapter.posts():
		var pid := str(p["id"])
		if ctx["lit"].has(pid) and str(p["zone_id"]) in ["zone_3", "zone_4"]:
			out.append([str(ctx["lit"][pid]), pid])
	return out


static func _plan_surveyor(day: int, ctx: Dictionary, groups: Array) -> void:
	if day < 4:
		return
	var g := _group(200, true)
	var seers := _surveyor_seers(ctx)
	var cause: Dictionary = strongest_debt_choice()
	var cause_ids: Array = [str(cause.get("choice_id", ""))]
	var high: bool = GameState.debt + float(0.0) >= Chapter.SURVEYOR_MARK_DEBT
	var names: Array = []
	for s in seers:
		names.append(GameState.npc_name(str(s[0])))
		g["fx"]["saw"].append(str(s[0]))
		g["fx"]["emotion"][str(s[0])] = GameState.EMOTION_AFRAID
		g["fx"]["history"][str(s[1])] = "the figure passed"
	var first := str(seers[0][0]) if not seers.is_empty() else ""
	var first_post := Chapter.post_name(str(seers[0][1])).split(",")[0] if not seers.is_empty() else ""
	var seen_line := ""
	if names.is_empty():
		seen_line = " No one is posted where it could be seen."
	elif names.size() == 1:
		seen_line = " %s saw it from the %s." % [names[0], first_post]
	else:
		seen_line = " %s saw it." % _join_names(names)
	if day == 4:
		var text := "A figure is walking the line between the eastern ridge and the western hollow. Every forty paces it stops. It is measuring." + seen_line
		_ev(g, 6.0, text,
			"{npc} watched it from the %s. {He} counted the paces between its stops. {He} has not said the number." % first_post if first != "" else "",
			[first] if first != "" else [], cause_ids, "zone_3", 3, "surveyor",
			{"focus": "surveyor", "surveyor": "walk", "day_unlock": "constance_boundary" if high else ""})
		if high:
			_ev(g, 8.0, "At the hollow boundary it stopped for the length of a watch and faced the settlement. Then it went on.",
				"", [], cause_ids, "zone_5", 3, "surveyor", {"focus": "surveyor", "surveyor": "pause"})
			g["fx"]["surveyor"]["paused"] = true
		g["fx"]["surveyor"]["walked4"] = true
	else:
		var macro: Dictionary = {}
		for c in GameState.choice_log:
			if str(c["moral_tier"]) == "macro":
				macro = c
		if not macro.is_empty():
			cause_ids.append(str(macro["choice_id"]))
		var witness := first if first != "" else ("constance" if GameState.npc_is_present("constance") else "")
		if high:
			_ev(g, 8.0, "The figure walked the boundary again. At the hollow it put out one arm, level, the way a surveyor sights a line. Then it stepped into the trees. The western hollow is open." + seen_line,
				"The figure sighted a line into the settlement and stepped into the hollow. {npc} saw where the arm pointed. {He} will not stand there.",
				[witness] if witness != "" else [], cause_ids, "zone_5", 3, "surveyor",
				{"focus": "surveyor", "surveyor": "mark"})
			g["fx"]["surveyor"]["marked"] = true
		else:
			_ev(g, 8.0, "The figure walked the boundary once more and did not stop at the hollow. At the treeline it was there, and then the treeline was only the treeline." + seen_line,
				"The figure completed its walk and did not mark. {npc} watched it go. {He} did not lower the lamp until the light came.",
				[witness] if witness != "" else [], cause_ids, "zone_5", 3, "surveyor",
				{"focus": "surveyor", "surveyor": "depart"})
		g["fx"]["surveyor"]["walked5"] = true
	groups.append(g)


static func _join_names(names: Array) -> String:
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var head: Array = names.slice(0, names.size() - 1)
	return "%s, and %s" % [", ".join(PackedStringArray(head)), names[names.size() - 1]]


# ── The macro's second-order effect (Night 5) ───────────────────────────────

static func _plan_macro(day: int, _ctx: Dictionary, groups: Array) -> void:
	if day != Chapter.LAST_DAY:
		return
	var macro: Dictionary = {}
	for c in GameState.choice_log:
		if str(c["moral_tier"]) == "macro":
			macro = c
	if macro.is_empty():
		return
	var cid := str(macro["choice_id"])
	var g := _group(190, true)
	var spoke: bool = GameState.has_flag("constance_asked")
	match str(macro["action_type"]):
		"macro_true_count":
			_ev(g, 3.0, "Two Compact men stood outside the supply post through the second watch. They did not come in. Maren Voss did not go out.",
				"Ruth Callan heard the count read out by someone else. She had meant to explain it on her own terms. No one has asked her to.",
				["ruth", "maren"], [cid], "zone_1", 2, "none", {"focus": "post_mill"})
			if GameState.npc_is_capable("ruth"):
				g["fx"]["arc"].append(["ruth", -1, cid])
		"macro_handover_book":
			_ev(g, 3.0, "Maren Voss read the handover figures to the Association in an even voice. At the third watch she was at the supply post with both books open, copying one into the other.",
				"Maren Voss read the handover figures aloud. She was found copying one book into the other. She did not stop when spoken to.",
				["maren"], [cid], "zone_1", 3, "none", {"focus": "post_mill"})
		"macro_carry_self":
			_ev(g, 3.0, "The Compact's reallocation order names the manager's post. Peder Lund's crew did not report to the structure at dusk.",
				"Ruth Callan signed the reallocation at dusk. She did not bring it to the manager's post. Maren Voss was not asked to carry anything. She has not decided what that means.",
				["ruth", "maren"], [cid], "zone_4", 2, "none", {"focus": "post_structure"})
			if GameState.npc_is_capable("ruth"):
				g["fx"]["arc"].append(["ruth", -1, cid])
		"macro_cosign":
			_ev(g, 3.0, "Field Agent Dix left at dusk with the filing signed. Constance Harrow sat on her step until the lamp round had passed twice.",
				"Constance Harrow sat on her step through the first watch. She has put the survey case back under the bed.",
				["constance"], [cid], "zone_2", 2, "none", {"focus": "zone_2"})
		"macro_constance_survey":
			_ev(g, 3.0, "The original survey is on the table in the Common under a lamp. Constance Harrow has not gone to bed. The Compact delegate has not gone home.",
				"Constance Harrow put the original survey on the table. She has not picked it up. She has not looked at it.",
				["constance"], [cid], "zone_2", 3, "none", {"focus": "zone_2"})
		"macro_withdraw":
			_ev(g, 3.0, "The Compact's hands left the structure at dusk and took their tools. Ruth Callan counted who was left.",
				"Ruth Callan counted the crew at dusk. She counted again at first light. The number is smaller.",
				["ruth"], [cid], "zone_4", 2, "none", {"focus": "post_structure"})
		"macro_testimony_named":
			_ev(g, 3.0, "Dix wrote Constance Harrow's name at the top of a page and left with it. Her lamp was lit all night.",
				"Constance Harrow's name is in the county's notebook. Her lamp was lit all night. She says she was reading.",
				["constance"], [cid], "zone_2", 2, "none", {"focus": "zone_2"})
		"macro_testimony_unnamed":
			_ev(g, 3.0, "Dix wrote 'source: township manager' and left. The Compact delegate knew before the first watch.",
				"Constance Harrow was not named. She asked who was. She did not ask a second time.",
				["constance"], [cid], "zone_2", 2, "none", {"focus": "zone_2"})
		"macro_silence":
			_ev(g, 3.0, "Field Agent Dix left at dusk with nothing signed and nothing said.",
				"Constance Harrow answered a direct question on Day 4. She has asked what was done with the answer. Nothing was." if spoke
				else "Constance Harrow watched Field Agent Dix go from her step. She was not asked. She did not offer.",
				["constance"], [cid], "zone_2", 2, "none", {"focus": "zone_2"})
		"macro_refuse_filing":
			_ev(g, 3.0, "Dix has taken a bunk in the Common and unpacked the notebook. Dix knocked at Constance Harrow's door at the first watch.",
				"Field Agent Dix knocked at Constance Harrow's door at the first watch. She let the knock finish.",
				["constance"], [cid], "zone_2", 2, "none", {"focus": "zone_2"})
		"macro_send_dix_to_constance":
			_ev(g, 3.0, "Dix sat with Constance Harrow for an hour by the clock. She answered every question that was asked directly.",
				"Constance Harrow answered every direct question. She offered nothing that was not asked. She is very tired.",
				["constance"], [cid], "zone_2", 2, "none", {"focus": "zone_2"})
	if not g["events"].is_empty():
		groups.append(g)


# ── Bond vulnerability: one of them saw it; now they both have ──────────────

static func _plan_bond_echo(day: int, ctx: Dictionary, fx: Dictionary, queue: Array) -> void:
	for npc_id in ctx["hit"]:
		var n: Dictionary = GameState.npc_states[npc_id]
		var partner := str(n["bond_partner"])
		if partner == "" or not bool(n["bond_acknowledged"]) or not GameState.npc_is_capable(partner):
			continue
		if GameState.has_flag("bond_echo_%s" % partner) or ctx["hit"].has(partner):
			continue
		var bc: Dictionary = GameState.last_choice_for_npc(npc_id, "bond_acknowledge")
		if bc.is_empty():
			continue
		fx["flags"]["bond_echo_%s" % partner] = day
		fx["emotion"][partner] = GameState.EMOTION_AFRAID
		var e := {
			"event_id": "n%d_bond_%s" % [day, partner], "night": day, "hour": 9.5,
			"event_text": "%s came off the post before the light and went to find %s before reporting to anyone." % [GameState.npc_name(npc_id), GameState.npc_name(partner)],
			"thread": "%s told %s before telling anyone. %s has not been back to the bunk." % [GameState.npc_name(npc_id), GameState.npc_name(partner), GameState.npc_name(partner)],
			"threat_npc_ids": [partner, npc_id], "cause_chain": [str(bc["choice_id"])],
			"zone_id": "zone_2", "horror_intensity": 2, "creature": "none", "focus": "zone_2",
		}
		queue.append(e)
		return


# ═══════════════════════════════════════════════════════════════════════════
# Commit (dawn)
# ═══════════════════════════════════════════════════════════════════════════

static func commit(day: int) -> void:
	var fx: Dictionary = GameState.night_result
	if fx.is_empty():
		GameState.last_night_events = []
		return
	for id in GameState.npc_states:
		# Fear from the night before fades unless tonight renews it.
		if str(GameState.npc_states[id]["emotion"]) == GameState.EMOTION_AFRAID and not fx["emotion"].has(id):
			if str(GameState.npc_states[id]["arc_state"]) not in ["fragile", "broken"]:
				GameState.npc_states[id]["emotion"] = GameState.EMOTION_NEUTRAL
	if GameState.post_of("thomas") != "":
		GameState.set_flag("thomas_posted_night_%d" % day)
	for a in fx["arc"]:
		if GameState.npc_is_present(str(a[0])):
			GameState.shift_arc(str(a[0]), int(a[1]), str(a[2]))
	for g in fx["gone"]:
		GameState.set_npc_gone(str(g[0]), str(g[1]))
	for id in fx["emotion"]:
		if GameState.npc_is_present(str(id)):
			GameState.set_npc_emotion(str(id), str(fx["emotion"][id]))
	for id in fx["injured"]:
		if GameState.npc_is_present(str(id)):
			GameState.npc_states[str(id)]["injured"] = true
	for id in fx["saw"]:
		if GameState.npc_states.has(str(id)):
			GameState.npc_states[str(id)]["saw_surveyor"] = true
			if not GameState.surveyor["seen_by"].has(str(id)):
				GameState.surveyor["seen_by"].append(str(id))
	for k in fx["flags"]:
		GameState.set_flag(str(k), fx["flags"][k])
	if bool(fx["flags"].get("wall_setback", false)):
		GameState.flags.erase("wall_setback")
		if GameState.structure_walls < 4:
			GameState.wall_progress = maxf(0.0, GameState.wall_progress - 1.0)
	for bid in fx["buildings"]:
		var b: Dictionary = GameState.building_by_id(str(bid))
		if not b.is_empty():
			b["state"] = str(fx["buildings"][bid])
			b["state_day"] = day
	for kind in fx["stock"]:
		GameState.add_stock(str(kind), int(fx["stock"][kind]))
	GameState.add_stock("oil", -int(fx.get("oil", 0)))
	GameState.stockpiles["oil"]["ledger"] = maxi(0, int(GameState.stockpiles["oil"]["ledger"]) - int(fx.get("oil", 0)))
	for d in GameState.discrepancies:
		if fx["double_sources"].has(str(d["id"])) and not bool(d["disclosed"]):
			d["watchers"] = mini(4, int(d["watchers"]) * 2)
	GameState.add_debt(float(fx["debt"]))
	GameState.treeline_advance += int(fx["treeline"])
	GameState.walkers = fx["walkers"].duplicate(true)
	GameState.walker_queue = fx["walker_queue"].duplicate(true)
	GameState.post_history = fx["history"].duplicate(true)
	var sv: Dictionary = fx["surveyor"]
	if bool(sv.get("paused", false)):
		GameState.surveyor["paused"] = true
	if bool(sv.get("walked4", false)):
		GameState.surveyor["walked"].append(4)
	if bool(sv.get("walked5", false)):
		GameState.surveyor["walked"].append(5)
	if bool(sv.get("marked", false)):
		GameState.surveyor["marked"] = true
		GameState.zone5_marked = true
	# A post held by someone who is no longer there is an empty post.
	for post_id in GameState.night_posts.keys():
		var who := str(GameState.night_posts[post_id])
		if who != "" and not GameState.npc_is_capable(who):
			GameState.night_posts[post_id] = ""
	GameState.last_night_events = GameState.night_queue.duplicate(true)
	GameState.all_night_events.append_array(GameState.night_queue.duplicate(true))
	for e in GameState.night_queue:
		for cid in e.get("cause_chain", []):
			var c: Dictionary = GameState.choice_by_id(str(cid))
			if not c.is_empty() and not c["consequence_ids"].has(str(e["event_id"])):
				c["consequence_ids"].append(str(e["event_id"]))
	GameState.night_queue = []
	GameState.night_result = {}
