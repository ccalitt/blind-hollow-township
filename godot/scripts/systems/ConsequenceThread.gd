class_name ConsequenceThread
extends RefCounted
## ConsequenceThread — GDScript port of backend/consequence/thread_generator.py.
##
## Generates the dawn consequence thread (REVEAL_MECHANIC.md Option B): for each
## night event traceable to a day choice, two declarative sentences. Sentence 1 =
## the day choice (named NPC/action/zone). Sentence 2 = the night consequence
## (named NPC/outcome). No "because", no causal connective, no evaluation. Quiet
## nights produce NO entries (the absence is information — never manufacture threads).
##
## Pillar 1 (Earned Dread): this is the legibility surface that lets the player
## trace tonight's horror to yesterday's logistics. Without it ~30% of players
## miss the causal chain (Gap 2 research) and earned dread collapses into random dread.
##
## OFFLINE-SLICE STUB: the backend pairs choices+events into a structured payload and
## hands it to the LLM Story Progression Agent for final rendering. Here we render the
## two sentences deterministically from authored templates + the event's own text.
## The pairing/validation logic (match_cause_chains, passes_reveal_test, gossip
## attribution) is a faithful port; only the final sentence prose is templated, not LLM.

const TIER_WEIGHTS := {"macro": 3, "mid": 2, "micro": 1}
const FACTION_TOKENS := ["compact", "association", "dix", "association_rep"]

# action_type -> Sentence-1 template. {npc}/{zone}/{day} filled at render time.
const ACTION_DESCRIPTIONS := {
	"assign_npc": "{npc} was assigned to {zone} on Day {day}.",
	"elias_report_logged": "Elias's report was logged on Day {day}.",
	"elias_report_ignored": "Elias's report was not logged on Day {day}.",
	"association_ledger_edited": "The ledger was provided in edited form on Day {day}.",
	"association_ledger_unedited": "The ledger was provided unedited on Day {day}.",
	"cover_discrepancy": "The ledger discrepancy was covered on Day {day}.",
	"compact_ratification_signed": "The Compact ratification document was signed on Day {day}.",
	"compact_ratification_delayed": "The Compact ratification was delayed on Day {day}.",
	"compact_surplus_accepted": "The Compact's surplus was applied to {zone} on Day {day}.",
	"dix_inspection_approved": "The site inspection was approved on Day {day}.",
	"dix_inspection_delayed": "The site inspection was delayed on Day {day}.",
	"dix_inspection_denied": "The site inspection was denied on Day {day}.",
	"peder_crew_zone5_survey": "Peder's crew was sent to the hollow perimeter on Day {day}.",
	"peder_crew_zone4_fourth_wall": "Peder's crew was assigned to complete the fourth wall on Day {day}.",
	"peder_crew_zone1_reinforce": "Peder's crew reinforced the Mill Quarter on Day {day}.",
	"place_building": "A structure was placed in {zone} on Day {day}.",
	"arrival_role": "{npc} was assigned a role on Day {day}.",
	"bond_acknowledge": "{npc} and their partner were kept working together through Day {day}.",
	"compact_ask_survey_history": "The survey's history was raised at the Compact meeting on Day {day}.",
	"macro_disclose_all": "The discrepancies were disclosed on Day {day}.",
	"macro_continue_cover": "The discrepancies were not disclosed on Day {day}.",
}


# ── Cause-chain matching (mirrors match_cause_chains) ───────────────────────

static func _match_cause_chains(choices: Array, night_events: Array) -> Array:
	var choice_by_id: Dictionary = {}
	for c in choices:
		choice_by_id[str(c["choice_id"])] = c
	var matched: Array = []
	var seen: Dictionary = {}
	for event in night_events:
		var eid := str(event.get("event_id", ""))
		if seen.has(eid):
			continue
		for choice_id in event.get("cause_chain", []):
			if choice_by_id.has(str(choice_id)):
				matched.append([choice_by_id[str(choice_id)], event])
				seen[eid] = true
				break
	return matched


# ── Gossip attribution (mirrors resolve_gossip_attribution) ─────────────────

static func _resolve_gossip_attribution(event: Dictionary, choices: Array) -> Variant:
	var transfers: Array = GameState.get_meta("gossip_transfers", [])
	var threat: Array = event.get("threat_npc_ids", [])
	for transfer in transfers:
		if threat.has(transfer["to_npc"]) or threat.has(transfer["from_npc"]):
			for choice in choices:
				if choice["npc_ids"].has(transfer["from_npc"]) and int(choice["day_cycle"]) < int(event.get("night", 0)):
					return choice
	return null


# ── Reveal test (mirrors passes_reveal_test) ────────────────────────────────

static func _passes_reveal_test(choice: Dictionary, event: Dictionary) -> bool:
	if choice["npc_ids"].is_empty() or event.get("threat_npc_ids", []).is_empty():
		return false
	var overlap := false
	for n in choice["npc_ids"]:
		if event["threat_npc_ids"].has(n):
			overlap = true
			break
	var chain_match: bool = event.get("cause_chain", []).has(str(choice["choice_id"]))
	return overlap or chain_match


# ── Sentence rendering (STUB for the LLM Story Progression Agent) ───────────

static func _display_name(npc_id: String) -> String:
	return GameState.npc_states.get(npc_id, {}).get("name", npc_id.capitalize())


static func _zone_name(zone_id: String) -> String:
	return GameState.zones.get(zone_id, {}).get("name", "their post")


static func _sentence1(choice: Dictionary) -> String:
	var template: String = ACTION_DESCRIPTIONS.get(str(choice["action_type"]),
		"{npc} — %s — Day {day}." % str(choice["action_type"]))
	var npc_id: String = str(choice["npc_ids"][0]) if not choice["npc_ids"].is_empty() else "someone"
	var zone_id: String = str(choice["choice_payload"].get("zone_id", ""))
	var out := template
	out = out.replace("{npc}", _display_name(npc_id))
	out = out.replace("{zone}", _zone_name(zone_id) if zone_id != "" else "their post")
	out = out.replace("{day}", str(int(choice["day_cycle"])))
	return out


static func _sentence2(event: Dictionary) -> String:
	# Render Sentence 2 from the authored event text (already in TONE register).
	# The event text is the night consequence in the NPC's voice — declarative,
	# no evaluation — which is exactly what Sentence 2 requires.
	return str(event.get("event_text", ""))


# ── Main generator (mirrors generate_thread) ───────────────────────────────

## Returns Array of thread entries: { npc_id, sentence1, sentence2, gossip_mediated }.
## Empty array == quiet night (no entries manufactured).
static func generate_thread(choices: Array, night_events: Array) -> Array:
	if night_events.is_empty():
		return []
	var entries: Array = []
	for pair in _match_cause_chains(choices, night_events):
		var choice: Dictionary = pair[0]
		var event: Dictionary = pair[1]
		if not _passes_reveal_test(choice, event):
			continue

		var gossip_mediated := false
		var overlap := false
		for n in choice["npc_ids"]:
			if event["threat_npc_ids"].has(n):
				overlap = true
				break
		if not overlap:
			var attribution = _resolve_gossip_attribution(event, choices)
			if attribution != null:
				choice = attribution
				gossip_mediated = true
			else:
				continue

		var npc_id: String = str(event["threat_npc_ids"][0]) if not event.get("threat_npc_ids", []).is_empty() else str(choice["npc_ids"][0])
		entries.append({
			"npc_id": npc_id,
			"sentence1": _sentence1(choice),
			"sentence2": _sentence2(event),
			"gossip_mediated": gossip_mediated,
		})
	return entries


# ── Investment anchor (mirrors compute_investment_anchor) ───────────────────

static func compute_investment_anchor(choices: Array) -> String:
	var weights: Dictionary = {}
	for entry in choices:
		var w: int = TIER_WEIGHTS.get(str(entry["moral_tier"]), 1)
		for npc_id in entry["npc_ids"]:
			var nid := str(npc_id)
			if FACTION_TOKENS.has(nid):
				continue
			weights[nid] = float(weights.get(nid, 0.0)) + w
	if weights.is_empty():
		return ""
	var best := ""
	var best_w := -1.0
	for nid in weights:
		if weights[nid] > best_w:
			best_w = weights[nid]
			best = nid
	return best
