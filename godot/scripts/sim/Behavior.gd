class_name Behavior
extends RefCounted
## Behavior — the one line of behavioral state in each person's context panel.
##
## Offline stand-in for the NPC Behavior Agent (INTERACTION_MODEL §3): a sentence
## reflecting the person's actual state, in their register, read from arc + flags +
## what they witnessed. It is not a mood meter and never names a consequence.
## Pillar 2: memory shows through behaviour, never through accusation (TONE.md).

static func line(id: String) -> String:
	var n: Dictionary = GameState.npc(id)
	if n.is_empty():
		return ""
	if GameState.current_phase == "night":
		return _night_line(id, n)
	var out := ""
	if bool(n["is_arrival"]):
		out = _arrival(id, n)
	else:
		match id:
			"ruth": out = _ruth(n)
			"thomas": out = _thomas(n)
			"maren": out = _maren(n)
			"elias": out = _elias(n)
			"constance": out = _constance(n)
			"peder": out = _peder(n)
	# Two people report the same dream, independently (Turning). Told separately.
	if GameState.current_day >= 4 and str(n["arc_state"]) != "broken":
		if str(GameState.flags.get("dream_a", "")) == id:
			out = "Dreamed of a road with no township on it. Says it was a road %s knew." % Content.pron(id, 0)
		elif str(GameState.flags.get("dream_b", "")) == id:
			out = "Dreamed of a road. Cannot say which. Describes the bend in it exactly."
	if bool(n["injured"]) and str(n["arc_state"]) != "broken":
		out += " Favouring one hand."
	return Content.fill(out, id)


static func _night_line(id: String, _n: Dictionary) -> String:
	var post_id := GameState.post_of(id)
	if post_id == "":
		return "In the bunks."
	return "On the %s." % Chapter.post_name(post_id).split(",")[0].to_lower().replace("eastern ridge", "eastern ridge watchtower")


static func _f(flag: String) -> bool:
	return GameState.has_flag(flag)


static func _partner_first(n: Dictionary) -> String:
	return GameState.npc_first(str(n["bond_partner"]))


static func _ruth(n: Dictionary) -> String:
	var arc := str(n["arc_state"])
	if int(GameState.flags.get("rations_open", 0)) == GameState.current_day:
		return "Waiting to be told who draws first. Has the tally in her hand."
	if arc == "broken":
		return "Gave no orders this morning. Is looking at a photograph she has not shown anyone."
	if _f("promise_fired") or arc == "fragile":
		return "Stands at the saw floor door. Does not come further into the room."
	if _f("ruth_stood_both"):
		return "Walked two posts herself last night. Says the saws need her today."
	if GameState.dawn_unlocks.has("thomas_avoided"):
		return "Hasn't spoken to Thomas since the morning count."
	if _f("ledger_out"):
		return "Says the count was hers to explain. Says it once."
	if _f("wall_complete_day"):
		return "Put her hand flat on the fourth wall this morning. Working faster than she has in weeks."
	if GameState.anchor_state() != "intact":
		return "Moves a little carefully around the manager's post. Saw something written down and crossed out."
	if str(n["bond_partner"]) != "":
		return "Working faster than she has in weeks. Doesn't say why."
	if _f("dispute_fired") and GameState.structure_walls < 4:
		return "Was asked for a date last night. Wants one before the shift ends."
	if _f("ledger_true"):
		return "Read the new figures over Maren's shoulder. Said nothing. Went back to the mill."
	if GameState.has_choice("ledger_carried_forward"):
		return "Watches your hands when the stores come up. Has not brought up the ledger."
	return "Wants the fourth wall up before first frost. Has told the Association so."


static func _thomas(n: Dictionary) -> String:
	var arc := str(n["arc_state"])
	if arc == "broken":
		return "Has the annotated book open. Is not reading it."
	if _f("thomas_fractured"):
		return "Explains the instrument tray to anyone at the door. No one asked about the tray."
	if GameState.thomas_spoke:
		return "Wrote the spring case up in full. Sleeps now. Checks the forearms of new arrivals."
	for id in GameState.npc_states:
		if id != "thomas" and GameState.npc_is_present(id) and bool(GameState.npc_states[id]["injured"]):
			return "Counting bandage. Says the cause was mechanical. Says it again."
	if _f("thomas_posted_night_%d" % (GameState.current_day - 1)):
		return "Was awake on a post all night. Describes the cold in clinical terms."
	if str(n["emotion"]) == "afraid":
		return "Over-explains why the lamp went out. It is a long explanation for a lamp."
	if GameState.current_day >= 2:
		return "Brought up the weather, then the mill dust, then the previous manager's forearm. Stopped there."
	return "Precise about the infirmary stock. Says he gave you the ledger because you were standing next to it."


static func _maren(n: Dictionary) -> String:
	var arc := str(n["arc_state"])
	var macro := str(GameState.flags.get("macro_choice", ""))
	if arc == "broken":
		return "Has a graduation programme out on the supply desk. Six weeks, it says. She is reading the date."
	if macro == "macro_handover_book":
		return "Copying one book into the other. Does not look up."
	if macro == "macro_true_count":
		return "Logged the count once. Left the pencil on the desk and went to eat."
	if _f("maren_signed"):
		return "Does not come to the manager's post. Sends the count by someone else."
	if _f("maren_stalled"):
		return "Told the Compact she needed another day. Wants you to know she said that."
	if _f("ledger_lie"):
		return "Knows which figure was changed. Starts to say something about the timber and stops."
	if GameState.has_choice("ledger_carried_forward") and GameState.current_day >= 2:
		return "Left the ledger exactly where she found it. Both times."
	if _f("structure_hit_maren"):
		return "On the structure, where people can see her. Keeps her back to the open side of the frame."
	if str(n["zone"]) == "zone_4":
		return "On the structure, where people can see her. Works like someone being graded."
	if _f("ledger_true"):
		return "Read the counted figures back to herself. Then asked where she would be working."
	if str(n["bond_partner"]) != "":
		return "Works nearer to %s than the task needs. Does not finish sentences about the stockpiles." % _partner_first(n)
	return "Has been at the ledger since before the mill started. Asks where you want her. Does not finish the sentence about the stockpiles."


static func _elias(n: Dictionary) -> String:
	var arc := str(n["arc_state"])
	if arc == "broken":
		return "On the ridge. Facing the wrong way. Filling in a delivery clipboard."
	if _f("elias_heard"):
		return "Says it in whole sentences now. Wants it written the way he said it."
	if bool(n["saw_surveyor"]):
		return "Counted its paces. Has the number. Has not said the number."
	if GameState.dawn_unlocks.has("elias_tell"):
		return "Held a lamp on something all night. Is standing near the manager's post without a reason to."
	if _f("elias_confirmed"):
		return "Has a measurement. Three yards. Says the number like something he is allowed to keep."
	if _f("elias_unbelieved"):
		return "Saw it again. Started to describe it. Asked about the hours instead."
	if str(n["zone"]) != "zone_3" or (GameState.post_of("elias") != "post_ridge" and GameState.current_day >= 2):
		return "Asked about the eastern ridge assignment. Not about the hours. About the reason."
	if str(n["bond_partner"]) != "":
		return "Tells %s what he sees, in pieces. Tells no one else." % _partner_first(n)
	if GameState.current_day == 1:
		return "Hasn't slept. Asks about the treeline survey."
	if GameState.current_day >= 3:
		return "Answers when spoken to. The answers are getting shorter."
	return "Keeps looking at the eastern window."


static func _constance(n: Dictionary) -> String:
	var arc := str(n["arc_state"])
	if arc == "broken":
		return "Has not come out. The survey case is on her step."
	if _f("constance_asked"):
		return "Answered what was asked. Refers to this year by its number now. Does not look at the western window."
	if GameState.dawn_unlocks.has("constance_boundary"):
		return "Was found at the ridge boundary at dawn, facing the hollow. She says she was walking."
	if _f("constance_window"):
		return "Sits outside the manager's post. Has brought nothing with her. Is not waiting for anyone else."
	if _f("dix_interviewing") or _f("dix_stays"):
		return "Was visited by the county. Says the county asks its questions sideways."
	if _f("survey_history_asked"):
		return "Heard the question in the Common. Has been formal since. More formal."
	if GameState.compact_ratified:
		return "Watched the pen cross the page. Mentions the fourth year, apropos of nothing."
	if _f("constance_housed_arrival"):
		return "Listens to the new arrival ask about the road. Does not correct the question."
	if GameState.anchor_state() != "intact":
		return "Has seen six managers. Says the fourth also stopped saying a name."
	return "Formal. Has seen six managers. Is waiting to see what this one needs."


static func _peder(n: Dictionary) -> String:
	var arc := str(n["arc_state"])
	if arc == "broken":
		return "Tools down. Three photographs on the sawhorse, face up."
	if GameState.peder_foundation_excavated:
		return "Has boarded over the trench. Talks about the weight of the boards. Not what they cover."
	if _f("excavate_ordered"):
		return "Says eight feet is a load question. Says it twice. Has not picked up the shovel."
	if _f("foundation_left"):
		return "Easier in his shoulders. Building everything except the wall."
	if _f("foundation_raised"):
		return "Told you where he stopped. Is waiting to hear whether that was an answer or a start."
	if GameState.crew_unavailable_days.has(GameState.current_day):
		return "On Compact work today. Says wages are wages. Does not say whose."
	if _f("peder_refused_survey") and GameState.current_day == 1:
		return "Did not send the crew west. Says the ground is soft. Has not looked west since."
	if _f("structure_damaged"):
		return "Put a level on the new course. Took the level away. Talks about load."
	if _f("wall_work_day"):
		return "Smells the new timber before he sets it. Sets it anyway."
	if GameState.current_day >= 2:
		return "Wants to know if the foundation scope has changed."
	return "Wants an order for the crew. Any order that is not the foundation."


static func _arrival(id: String, n: Dictionary) -> String:
	var arc := str(n["arc_state"])
	var day := GameState.current_day
	if day == int(n["arrival_day"]) and str(n["settling_path"]) == "":
		return str(n["signal"])
	if arc == "broken":
		return "Standing where the road ends. Has been there since the light came."
	if bool(n.get("promise_failed", false)):
		return "Walked the road to where it stops. Does not ask about it now."
	if str(n.get("conversation", "")) == "promised":
		return "Lighter than yesterday. Has told two people the road is being looked into."
	if bool(n["saw_surveyor"]):
		return "Saw the figure on the boundary. Has started pacing distances without meaning to."
	if str(n["bond_partner"]) != "":
		return "Follows %s's lead without being asked to." % _partner_first(n)
	if arc == "fragile":
		return "Does the work. Looks up every time a door opens."
	match str(n["settling_path"]):
		"rushed":
			return "Working. Hasn't stopped since {he} arrived."
		"integration":
			if arc == "contributing":
				return "Has stopped counting days out loud. Knows where things are kept."
			return "Getting {his} bearings. Working carefully."
		"accelerated":
			return "Does what the role asks. Eats alone. Has not learned anyone's name twice."
	return str(n["signal"])


# ── Faction representatives: one in-world line; they respond in behaviour ───

static func rep_line(faction_id: String) -> String:
	var day := GameState.current_day
	match faction_id:
		"compact":
			if GameState.compact_ratified:
				return "The delegate is cordial and brief. The document is not on the table any more."
			if _f("survey_history_asked"):
				return "The delegate is counting the chairs in the Common. There are eleven."
			if day == 1:
				return "\"The Compact is glad of a steady hand. There will be a small document later in the week. Nothing that needs reading twice.\""
			return "The delegate asks after the stores, and waits through the answer."
		"association":
			if _f("association_walked"):
				return "The representative is not here. A mill hand is standing where the representative stood."
			if _f("ledger_out"):
				return "The representative nods from across the Common. It is the first nod."
			if day == 1:
				return "\"Five managers have made us promises. We will take one delivered thing over a speech.\""
			return "The representative has a list. The first line is the ledger. The second is the fourth wall."
		"dix":
			if GameState.dix_approved:
				return "Dix is drawing the western parcel from the chain notes and checking it against the county map. The two are on separate sheets."
			if _f("dix_interviewing"):
				return "Dix has a notebook open and three names in it. One is Harrow."
			if day == 1:
				return "\"Dix. County Surveyor's Office. I am here about a file, not about you.\""
			return "Dix is polite, and still here."
	return ""
