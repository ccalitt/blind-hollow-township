class_name Content
extends RefCounted
## Content — the authored text of Chapter 1.
##
## In production the LLM agents (NPC Behavior, Horror, Story Progression) render
## this prose from structured state, and the Master Enforcer validates tone. Offline,
## this file IS those agents: every line the player can read is authored here against
## TONE.md (specific, earned, quiet) and REVEAL_MECHANIC.md (name it, never evaluate it).
##
## Night-register rule (TONE.md): no "perhaps", "at least", "but", "still" in any line
## that can print at night or dawn. tests/run_tests.gd scans for them.

# ── Pronouns for the original six ───────────────────────────────────────────
const PRONOUNS := {
	"ruth": ["she", "her", "her"], "thomas": ["he", "him", "his"],
	"maren": ["she", "her", "her"], "elias": ["he", "him", "his"],
	"constance": ["she", "her", "her"], "peder": ["he", "him", "his"],
}

# ── Day assignments (INTERACTION_MODEL §3: plain text list) ─────────────────
const DAY_ASSIGNMENTS := [
	{"zone": "zone_1", "text": "Mill Quarter, day shift"},
	{"zone": "zone_2", "text": "Settlement Common, stores and infirmary"},
	{"zone": "zone_3", "text": "Eastern Ridge, treeline watch"},
	{"zone": "zone_4", "text": "Incomplete Structure, day labor"},
]

## Which day zone is "matched" work for a skill domain (NPC_INFLOW_PRODUCTIVITY).
const DOMAIN_ZONE := {
	"construction": "zone_4", "medicine": "zone_2", "logistics": "zone_1",
	"observation": "zone_3", "social": "zone_2",
}

# ── Buildings (INTERACTION_MODEL §2: names only, no stats) ──────────────────
const BUILDINGS := {
	"Watchtower": {"timber": 20},
	"Secondary Processing Shed": {"timber": 30},
	"Storehouse": {"timber": 24},
	"Bunkhouse": {"timber": 28},
}
const BUILD_ORDER := ["Watchtower", "Secondary Processing Shed", "Storehouse", "Bunkhouse"]

# ── Opening (WORLD_STATE §6) ────────────────────────────────────────────────
const OPENING := [
	"Harrow's Crossing. Morning. The mill is running.",
	"The handover ledger is on the table in the manager's post. Fourteen names. Three columns of counts.",
	"One line of handover note: see to the structure first.",
	"Across thirty yards of cleared ground, the incomplete building's frame catches the light. Three of its walls are standing.",
	"Peder Lund's crew is at the frame, waiting on an order. Elias Grout is down from the ridge with a report in his hand.",
]

# ── Arrivals (NPC_INFLOW_PRODUCTIVITY / WORLD_BACKSTORY) ────────────────────
## One person per domain. `signal` is the player's only skill information.
const ARRIVALS := {
	"construction": {
		"id": "ines", "name": "Ines Achterberg", "pron": ["she", "her", "her"], "archetype": "practical",
		"scene": "A woman is standing where the road ends, holding a spirit level. She was carrying it across a driveway.",
		"signal": {
			"surface": "Worked construction most of her life.",
			"practiced": "Twelve years framing residential builds. Knows which joints hold in cold weather.",
			"deep": "Structural engineer. She can read a foundation the way Thomas reads a patient.",
		},
		"answer": "\"I had the level in my hand. I have it now. Is the road being looked at?\"",
	},
	"medicine": {
		"id": "dov", "name": "Dov Mirsky", "pron": ["he", "him", "his"], "archetype": "dependent",
		"scene": "A man is standing where the road ends with a bicycle lock in one hand. There is no bicycle.",
		"signal": {
			"surface": "Was a pharmacy technician. Counts everything twice.",
			"practiced": "Nine years on an ambulance. Looks at hands before he looks at faces.",
			"deep": "Trauma surgeon. He has already noticed who here favours a side.",
		},
		"answer": "\"Someone is expecting me at six. It was nearly six. Does anyone go back down the road?\"",
	},
	"logistics": {
		"id": "hana", "name": "Hana Okafor", "pron": ["she", "her", "her"], "archetype": "practical",
		"scene": "A woman is standing where the road ends, counting coins from one palm into the other. She was at a laundromat.",
		"signal": {
			"surface": "Stocked shelves through college. Says she is good with lists.",
			"practiced": "Ran a night dispatch desk. Knows what a count looks like when someone has rounded it.",
			"deep": "Forensic auditor. She read the supply post like a page with a line missing.",
		},
		"answer": "\"I counted the road in. Four hundred steps. I can't find the first one. Will someone walk it with me?\"",
	},
	"observation": {
		"id": "callum", "name": "Callum Reyes", "pron": ["he", "him", "his"], "archetype": "theorist",
		"scene": "A man is standing where the road ends, between a truck that is not there and a trailhead that is not there.",
		"signal": {
			"surface": "Drove nights. Says he notices when a road is different.",
			"practiced": "Wildlife field technician. Six seasons counting what moves at dusk.",
			"deep": "Fire lookout, eleven summers. He can tell you which tree is new.",
		},
		"answer": "\"The trees behind me are the wrong age. All the same wrong age. You've had someone check the road?\"",
	},
	"social": {
		"id": "bea", "name": "Bea Lindqvist", "pron": ["she", "her", "her"], "archetype": "theorist",
		"scene": "A woman is standing where the road ends, holding a leash. She was walking a dog. There is no dog.",
		"signal": {
			"surface": "Tended bar. Remembers names.",
			"practiced": "Union steward at a cannery. People tell her things before they mean to.",
			"deep": "Hospice chaplain. She has sat with people who were waiting before.",
		},
		"answer": "\"Everyone here asked my name and my work. No one asked where I was going. Is there a way back?\"",
	},
}
const ARRIVAL_DOMAIN_ORDER := ["observation", "logistics", "medicine", "construction", "social"]

# ── Sentence 1 of the dawn thread: the day choice, named (REVEAL_MECHANIC §2) ─
## {npc} full name of first NPC, {npc2} second, {zone}, {day}, {building}, {post}.
const SENTENCE_ONE := {
	"assign_npc": "{npc} was assigned to {zone} on Day {day}.",
	"post_npc": "{npc} was posted to {post} for the night of Day {day}.",
	"post_cleared": "{npc} was taken off {post} on Day {day}.",
	"place_building": "A {building} was placed at {zone} on Day {day}.",
	"ledger_carried_forward": "The handover figures were carried forward in the ledger on Day {day}.",
	"ledger_counted_entered": "The counted figures were entered in the ledger on Day {day}.",
	"discrepancy_logged": "The discrepancy was logged formally on Day {day}.",
	"elias_report_logged": "Elias Grout's treeline report was logged on Day {day}.",
	"elias_report_unlogged": "Elias Grout's treeline report was not logged on Day {day}.",
	"crew_fourth_wall": "Peder Lund's crew was set to the fourth wall on Day {day}.",
	"crew_mill_reinforce": "Peder Lund's crew was set to the Mill Quarter's processing building on Day {day}.",
	"crew_hollow_survey": "Peder Lund's crew was asked to survey the western hollow perimeter on Day {day}.",
	"crew_clear_west": "Peder Lund's crew cleared the western perimeter on Day {day}.",
	"crew_clear_east": "Peder Lund's crew cleared the eastern perimeter on Day {day}.",
	"crew_repair": "Peder Lund's crew was set to repair the {building} on Day {day}.",
	"crew_clear_walker": "Peder Lund's crew was set to clear what stood in {zone} on Day {day}.",
	"crew_excavate": "Peder Lund was ordered to dig the foundation to depth on Day {day}.",
	"peder_foundation_asked": "Peder Lund was asked about the foundation on Day {day}.",
	"peder_foundation_left": "Peder Lund was told the foundation stays as it is on Day {day}.",
	"peder_foundation_unasked": "Peder Lund was not asked about the foundation by Day {day}.",
	"compact_surplus_accepted": "The Compact's surplus was taken into the Mill Quarter on Day {day}.",
	"compact_surplus_declined": "The Compact's wagon was sent back on Day {day}.",
	"association_ledger_unedited": "The ledger was given to the Association unedited on Day {day}.",
	"association_ledger_edited": "The ledger was given to the Association in edited form on Day {day}.",
	"association_ledger_acknowledge": "The discrepancy was acknowledged to the Association without the ledger on Day {day}.",
	"association_unanswered": "The Association's request for the ledger was not answered on Day {day}.",
	"association_date_given": "The Association was given a date for the fourth wall on Day {day}.",
	"association_no_date": "The Association was told there is no date for the fourth wall on Day {day}.",
	"association_left_waiting": "The Association was left waiting on Day {day}.",
	"dix_inspection_approved": "The inspection of the western hollow was approved on Day {day}.",
	"dix_inspection_delayed": "The inspection of the western hollow was delayed on Day {day}.",
	"dix_inspection_denied": "The inspection of the western hollow was denied on Day {day}.",
	"dix_unanswered": "Field Agent Dix's request was not answered on Day {day}.",
	"compact_ratification_signed": "The ratification document was signed on Day {day}.",
	"compact_ratification_delayed": "The ratification document was not signed on Day {day}.",
	"compact_ask_survey_history": "The survey's history was asked about in front of Constance Harrow on Day {day}.",
	"thomas_briefing": "Thomas Vael was given the evening briefing on Day {day}.",
	"thomas_not_asked": "Thomas Vael was not given the evening briefing by Day {day}.",
	"constance_asked": "Constance Harrow was asked directly about the survey on Day {day}.",
	"bond_acknowledge": "{npc} and {npc2} were kept working together through Day {day}.",
	"arrival_housing": "{npc} was given a bunk near {npc2} on Day {day}.",
	"arrival_housing_open": "{npc} was given an open bunk on Day {day}.",
	"arrival_role": "{npc} was assigned to {zone} on Day {day}.",
	"arrival_conversation": "{npc} was spoken with on the day of arrival, Day {day}.",
	"arrival_false_hope": "{npc} was told the road is being looked into on Day {day}.",
	"arrival_deployed": "{npc} was put on the night watch on the day of arrival, Day {day}.",
	"rations_watch_first": "The night watch drew rations first on Day {day}.",
	"rations_mill_first": "The mill crew drew rations first on Day {day}.",
	"rations_arrivals_first": "The newest arrivals drew rations first on Day {day}.",
	"macro_true_count": "Maren Voss was sent to the Association with the true count on Day {day}.",
	"macro_handover_book": "Maren Voss was sent to the Association with the handover book on Day {day}.",
	"macro_carry_self": "The true count was carried to the Association by the manager on Day {day}.",
	"macro_cosign": "The compliance filing was co-signed on Day {day}.",
	"macro_constance_survey": "Constance Harrow was asked to put the original survey on the table on Day {day}.",
	"macro_withdraw": "The ratification was withdrawn on Day {day}.",
	"macro_testimony_named": "Constance Harrow's account was given to Field Agent Dix under her name on Day {day}.",
	"macro_testimony_unnamed": "Constance Harrow's account was given to Field Agent Dix without her name on Day {day}.",
	"macro_silence": "Field Agent Dix was told nothing on Day {day}.",
	"macro_refuse_filing": "The compliance filing was refused on Day {day}.",
	"macro_send_dix_to_constance": "Field Agent Dix was sent to Constance Harrow on Day {day}.",
}

# ── Faction asks (INTERACTION_MODEL §4: one round, plain text, no framing) ──
## Each: prompt (the in-world line shown in the panel), options [{id,text}], and
## the day/time it opens. Effects live in Chapter.gd keyed by option id.
const ASKS := {
	"compact_surplus": {
		"faction": "compact",
		"log": "A Compact wagon has stopped at the Common. Flour, salt pork, lamp oil, sawn boards. The delegate says it is the township's by custom.",
		"prompt": "\"A new manager should not start short. It is already loaded. Say where you want it.\"",
		"options": [
			{"id": "compact_surplus_accepted", "text": "Take delivery at the Mill Quarter."},
			{"id": "compact_surplus_declined", "text": "Send the wagon back."},
		],
	},
	"association_ledger": {
		"faction": "association",
		"log": "The Association's representative is at the Common. They are asking for the stockpile ledger.",
		"prompt": "\"Five managers have told us the stores are sound. We would like to read it ourselves.\"",
		"options": [
			{"id": "association_ledger_unedited", "text": "Provide the ledger unedited."},
			{"id": "association_ledger_edited", "text": "Provide an edited version."},
			{"id": "association_ledger_acknowledge", "text": "Acknowledge the discrepancy without the document."},
		],
	},
	"dix_inspection": {
		"faction": "dix",
		"log": "Field Agent Dix is at the Common with a county map. Dix is asking to walk the western hollow perimeter.",
		"prompt": "\"There is an audit flag on this township eleven years old. I would like to close it. I need to see the western parcel.\"",
		"options": [
			{"id": "dix_inspection_approved", "text": "Approve the site inspection."},
			{"id": "dix_inspection_delayed", "text": "Delay the inspection. Safety conditions."},
			{"id": "dix_inspection_denied", "text": "Deny the request."},
		],
	},
	"compact_ratification": {
		"faction": "compact",
		"log": "The Compact has laid a document on the table in the Common. Constance Harrow is in the room.",
		"prompt": "\"It ratifies the existing survey in the management log. One signature. Every manager has signed it.\"",
		"options": [
			{"id": "compact_ratification_signed", "text": "Sign the ratification document."},
			{"id": "compact_ratification_delayed", "text": "Request time to review."},
			{"id": "compact_ask_survey_history", "text": "Ask about the survey's history."},
		],
	},
	"association_date": {
		"faction": "association",
		"log": "The Association's representative is back at the Common. They have stopped asking about the ledger. They are asking about the fourth wall.",
		"prompt": "\"We were told before the frost. We would like a day we can say out loud.\"",
		"options": [
			{"id": "association_date_given", "text": "Give them a date: tomorrow, before dusk."},
			{"id": "association_no_date", "text": "Tell them there is no date."},
		],
	},
}

# ── Macro forks (CHAPTER_ONE Day 5) ─────────────────────────────────────────
const MACROS := {
	"ledger": {
		"target": "maren",
		"log": [
			"Maren Voss is at the manager's post with two books. The handover ledger, and the one she has kept since.",
			"The Association meets at dusk. She is asking which book she carries in.",
		],
		"options": [
			{"id": "macro_true_count", "text": "Send her in with the true count."},
			{"id": "macro_handover_book", "text": "Send her in with the handover book."},
			{"id": "macro_carry_self", "text": "Carry the true count in yourself."},
		],
	},
	"survey": {
		"target": "rep_dix",
		"log": [
			"Field Agent Dix leaves at dusk with the compliance filing. It cites the survey that was ratified.",
			"Constance Harrow is sitting where she can see the table.",
		],
		"options": [
			{"id": "macro_cosign", "text": "Co-sign the compliance filing."},
			{"id": "macro_constance_survey", "text": "Ask Constance Harrow to put the original survey on the table."},
			{"id": "macro_withdraw", "text": "Withdraw the ratification."},
		],
	},
	"testimony": {
		"target": "rep_dix",
		"log": [
			"Field Agent Dix leaves at dusk. What Constance Harrow said is not in any record.",
			"She has not asked what will be done with it.",
		],
		"options": [
			{"id": "macro_testimony_named", "text": "Give Dix her account, with her name on it."},
			{"id": "macro_testimony_unnamed", "text": "Give Dix the account. Leave her name off it."},
			{"id": "macro_silence", "text": "Tell Dix nothing."},
		],
	},
	"filing": {
		"target": "rep_dix",
		"log": [
			"Field Agent Dix leaves at dusk and wants a co-signature on the compliance filing.",
			"The filing rests on the survey in the county record. No one here has offered another.",
		],
		"options": [
			{"id": "macro_cosign", "text": "Co-sign the compliance filing."},
			{"id": "macro_refuse_filing", "text": "Refuse to sign what has not been read against the land."},
			{"id": "macro_send_dix_to_constance", "text": "Send Dix to Constance Harrow."},
		],
	},
}

const MACRO_WORN_WORKFORCE := "There are few people left to carry this out. They are the ones who are here."

# ── What Constance says, once (WORLD_BACKSTORY: the Survey Theory) ──────────
const CONSTANCE_SPEAKS := [
	"\"In the fourth year the quota could not be met from the eastern ridge. The western hollow was cleared. The eastern paperwork was filed.\"",
	"\"The parcel the county holds on record and the parcel that was cut are not the same parcel. I have the survey that says so. I have had it since the fourth year.\"",
	"\"You asked me directly. I do not lie to a direct question. I had hoped not to be asked.\"",
]
const CONSTANCE_ANCHOR_LINE := "\"You have stopped saying the name of whoever you were driving back to. I noticed in the second year that I had stopped, too.\""

# ── Thomas, at the briefing ─────────────────────────────────────────────────
const THOMAS_SPEAKS := [
	"Thomas Vael takes the evening briefing. It lasts four minutes.",
	"\"In the spring I dressed a wound on the previous manager's forearm. The tissue had a grain. I mean that the way a sawyer means it. I wrote 'laceration' because there was a box for laceration.\"",
]

# ── Peder ───────────────────────────────────────────────────────────────────
const PEDER_REFUSES_SURVEY := "Peder Lund does not send the crew. \"Ground's soft out there. Won't take a tripod.\" He does not look west when he says it."
const PEDER_FOUNDATION_ANSWER := "\"Footings are at six feet. I stopped at six feet. A wall that size wants eight. I would stop at six again.\""
const PEDER_EXCAVATION_AUTO := "Peder Lund's crew broke ground on the foundation at first light. No one gave the order. The schedule gave it."


static func pron(npc_id: String, idx: int) -> String:
	if PRONOUNS.has(npc_id):
		return PRONOUNS[npc_id][idx]
	var n: Dictionary = GameState.npc(npc_id)
	var p: Array = n.get("pron", ["they", "them", "their"])
	return str(p[idx])


## Fill {npc} {first} {he} {him} {his} {He} {zone} etc. for a primary NPC.
static func fill(text: String, npc_id: String = "", extra: Dictionary = {}) -> String:
	var out := text
	if npc_id != "":
		out = out.replace("{npc}", GameState.npc_name(npc_id))
		out = out.replace("{first}", GameState.npc_first(npc_id))
		out = out.replace("{He}", pron(npc_id, 0).capitalize())
		out = out.replace("{he}", pron(npc_id, 0))
		out = out.replace("{him}", pron(npc_id, 1))
		out = out.replace("{his}", pron(npc_id, 2))
		out = out.replace("{His}", pron(npc_id, 2).capitalize())
	for k in extra:
		out = out.replace("{%s}" % k, str(extra[k]))
	return out
