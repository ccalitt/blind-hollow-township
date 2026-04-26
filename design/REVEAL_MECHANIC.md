# Reveal Mechanic — Hollow Township

> Status: FROZEN (2026-04-26)
> Satisfies: Pillar 1 (Earned Dread), Pillar 4 (Day/Night as Structural Argument)

---

## 1. The Problem

Pillar 1 requires that horror be traceable to player choice. Without a legibility mechanism, the causal chain exists in the data but not in the player's experience — consequential horror collapses into random dread, which reads as unfairness, not earned weight. Research in LIGS and Story2Game causal recognition tests demonstrates that approximately 30% of players fail to make the day-choice-to-night-consequence connection without any surface signal, even in games where the causal structure is architecturally sound. For Hollow Township, a 30% legibility failure rate is a Pillar 1 kill condition: if the player cannot attribute the horror to themselves, the entire moral weight system fails.

---

## 2. The Chapter 1 Reveal Model — Dawn Consequence Thread

**What it is**: At dawn, for each NPC whose night consequence is traceable to a specific day choice, one to two declarative sentences appear in the narrative log. These sentences name the chain. They do not evaluate it.

**Format rules**:
- Two sentences maximum per consequenced NPC.
- Sentence 1: the day choice. Named NPC, named action, named zone or assignment.
- Sentence 2: the night consequence. Named NPC, named outcome. No elaboration.
- No "because." No "as a result." No causal connective tissue. The sentences sit next to each other. The player assembles the meaning.
- No moral framing. No resolution. No statement of what the choice meant.

**Where and when**:
- Delivery point: bottom-left narrative log. Same register, same format as night-phase event text. No visual distinction, no icon, no label marking it as a "consequence thread."
- Timing: first 60 seconds of dawn phase, before player input is accepted. The thread lands before the player can act on it.

**What it is not**: A recap. A summary screen. A score. A moral judgment. An explanation. The distinction from NOT-THIS.md's forbidden "day recap / summary screen": this does not tell the player what their choices meant — it names what happened. The player determines what it meant.

**How it is generated**: The Consequence Trace Agent queries GSI-2 (all day choices with populated choice_ids) and the night event log (all events with populated consequence_ids). It identifies matched pairs. It passes each matched pair to the Story Progression Agent with a strict output instruction: two sentences, declarative, named NPC, no evaluation. The Master Enforcer validates tone before delivery.

**Edge case — quiet night**: If no consequence fired on a given night (player made choices that did not feed the Debt), the dawn log is silent on this thread. No entry appears. The absence is information: the player reads it as the gap it is. Do not manufacture threads for quiet nights. Fabricated causal chains are worse than no causal chains — they teach the player a false grammar.

---

## 3. The Chapter 2+ Reveal Model — Environmental Only

By Chapter 2, the player knows the causal grammar. The dawn consequence thread is withdrawn entirely.

Reveals are environmental: building state changes visible from the Management View, NPC sprite emotional states readable from Zone 2 (the Settlement Common), zone-level visual decay via the corruption shader on hollow-adjacent structures, the absence of NPCs from their assigned posts at the expected hour. The player reads the world, not the log.

This is the correct escalation. The horror of Chapter 1 was learning you were complicit. The horror of Chapter 2 is knowing you are complicit and still having to look.

---

## 4. The Reveal Test

Every dawn consequence thread entry must pass all three before delivery:

1. **Does it name a specific NPC and a specific day choice?** No abstractions. "A worker" and "the post" fail. "Elias" and "the eastern ridge assignment" pass.

2. **Does it state the consequence without evaluating it?** No "because," no causal framing, no moral register. If the sentence contains an explanation, cut the explanation.

3. **Would it make sense to a player who made different choices?** If yes — it is atmosphere, not earned dread. Cut it. The thread must be legible only because of what *this* player did.

---

## 5. Examples

---

**Example 1**

Day choice: Player assigned Elias to the Mill Quarter (Zone 1) instead of his eastern ridge post (Zone 3) to accelerate resource processing.

Night consequence: The eastern ridge went unwatched. The treeline moved. Elias was not there to measure it.

Dawn thread:
> Elias was assigned to the Mill Quarter on Day 1.
> The eastern ridge post was empty at third watch. The treeline is thirty yards closer this morning than it was yesterday.

---

**Example 2**

Day choice: Player assigned Maren to the incomplete structure (Zone 4) — she wanted the visible work, the player accommodated her.

Night consequence: Maren's arc destabilized on Night 2. She did not return to the supply post at the expected shift rotation.

Dawn thread:
> Maren was assigned to the incomplete structure on Day 1.
> She did not log the morning count. The ledger for Night 2 has no entry in her hand.

---

**Example 3**

Day choice: Player accepted the resource surplus offered by the Harrow's Crossing Compact and applied it to Zone 1 (the Mill Quarter). The surplus came from the western hollow.

Night consequence: Zone 1 showed anomalies at Night 2. Ruth, assigned to the Mill Quarter, reported the event and then stopped speaking about it.

Dawn thread:
> The Compact's surplus was applied to the Mill Quarter on Day 1.
> Ruth has not spoken about what she heard at the second watch. She has not filed a report.

---
