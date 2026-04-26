# Places and Objects of Interest — Hollow Township

> Status: IN PROGRESS (2026-04-26). Procedural significance system. Pending review before freeze.
> Satisfies: Pillar 1 (Earned Dread — horror traced to player choice), Pillar 2 (Watched Feeling — world responds specifically), Pillar 3 (Moral Weight — logistics choices condition what becomes significant)

---

## Design Intent

Objects and places in Harrow's Crossing do not start significant. They become significant through events — through what the player built near them, assigned to them, or allowed to happen there. Significance is not labeled. It surfaces through NPC behavioral state lines, faction stance shifts, and environmental changes that accumulate without announcement.

The player who notices that Peder works differently at the Incomplete Structure on Day 4 than he did on Day 1 has discovered something about that place. The player who never looks has missed it. Both play the same game. One carries more weight.

Significance is **per-NPC and per-session**. The same zone means different things to Ruth than to Elias, and it means different things in a run where the player built near it on Day 1 versus a run where they avoided it. Places do not reset to neutral. Once something happens at a location, that location is changed — for the NPCs who were present, for the consequence chain, for the remainder of the chapter.

---

## The Significance Model

### How Significance Accumulates

Every location and named object has a significance state: a per-NPC map of event weight accumulated through the chapter.

```
significance_state: {
  zone_id or object_id: {
    npc_id: {
      event_weight: float,         # accumulated from witnessed events
      last_event_type: string,     # most recent event category
      behavioral_modifier: string, # current effect on NPC's behavioral state line
      permanent: bool,             # some significance cannot be lost
    }
  }
}
```

Significance accumulates through three mechanisms:

**1. Witnessed events.** An NPC assigned to a zone when a horror event fires has that event logged against that zone in their personal significance map. An NPC who was not present does not carry this weight. Two NPCs who both worked Zone 4 during a night event carry it differently — Elias who was actively watching carries it as confirmation; a new arrival who was there carries it as shock.

**2. Player assignment history.** A zone where the player repeatedly assigns their most capable NPC becomes significant to that NPC as a post. A zone where the player has never assigned anyone carries a different significance: the NPC who is first assigned there on Day 3 has no context. The zone is new to them. The player's assignment history conditions the NPC's readiness.

**3. Environmental shift.** The game can alter a zone's visual state based on DEBT accumulation. A zone near Zone 5 may have fog that persists past dawn, or torchlight that dims earlier than other zones. These environmental shifts are significance signals the player can observe without NPC intermediary. They are not labeled. The player notices the mill is darker today than yesterday, or they do not.

### Permanence vs. Decay

**Permanent significance**: Anything that results from a horror event. If a Walker reached Zone 3, that zone is permanently marked for Elias — his behavioral state line will reflect Zone 3 differently for the remainder of the chapter and into Chapter 2. This cannot be undone by reassigning him elsewhere.

**Decaying significance**: Faction tension, productivity drops, and minor observational shifts can be overwritten by subsequent events. A zone that was deprioritized on Day 1 loses that significance by Day 3 if it has been properly staffed since. The decay is not communicated; the NPC's behavioral state line simply returns toward baseline.

**Session-procedural**: Significance is computed from the specific run's choice log. The same player playing twice will generate different significance maps if they make different assignments. The western hollow is not always the first zone to accumulate horror — it is the first zone that the player's choices made a target.

---

## Named Places and Their Significance Potential

Each zone has a set of significance triggers — specific conditions that elevate the zone's weight. These are not labeled in-game. They are design constraints on event generation: the Horror Agent is only authorized to generate zone-specific significance events when these conditions are met.

### Zone 1 — The Mill Quarter

**Baseline state**: Active, productive. The sound of it reaches the Common before the building does.

**Significance triggers**:
- Compact surplus resources applied here → stockpile accumulates hollow-origin material. The mill output starts carrying the discrepancy forward. Watchers spawn here first.
- Three or more NPCs assigned here simultaneously → their behavioral state lines begin cross-referencing each other. The zone becomes a social node, not just a production one.
- Night 2 Watcher event fires here → the mill is now the place where the first quiet wrong thing happened. NPCs who work here on Day 3 have a behavioral modifier that reflects an absence they cannot name.

**Significance ceiling**: The Mill Quarter can become the most human-dense space in the chapter — every NPC passes through it. Its significance for multiple NPCs simultaneously makes it the highest-stakes assignment space. The player who treats it as a pure throughput node will have multiple NPCs accumulating significance there, compounding.

**Permanence**: First Watcher event in the Mill Quarter is permanent for all NPCs present. Ruth will not forget it. She will never say so directly.

---

### Zone 2 — The Settlement Common

**Baseline state**: Housing, faction meeting spaces, NPC daily routine. The social center.

**Significance triggers**:
- Faction interactions conducted here publicly → Ruth (if present) observes. Constance (if present) observes. The Gossip Engine picks up their observations as Stage 1 witnesses immediately.
- A new arrival housed near Constance → Constance's knowledge state updates. Her interaction options shift.
- Night event aftermath visible here at dawn → behavioral state changes from night events are visible here first. The Common is the early-warning surface for what happened overnight.

**Significance ceiling**: The Common is the gossip hub. Its significance is network significance: what the player does here is observed by the most people. High-visibility choices should be made here if the player wants information to spread; private choices should be made elsewhere.

**Permanence**: A faction interaction witnessed in the Common is permanent in every witness's memory. The Compact representative who was signed in public is a different political fact than one signed in private.

---

### Zone 3 — The Eastern Ridge

**Baseline state**: Elias's post. The only place that faces away from the hollow.

**Significance triggers**:
- Elias assigned here with watchtower → his observations are specific and reportable. Zone 3 becomes the informational anchor of the chapter.
- Elias removed from Zone 3 → the ridge goes dark. Zone 3 significance drops to near zero for everyone except Elias, who now carries the knowledge of what he would have seen.
- Walker reaches Zone 3 (Elias not present or blocked) → permanent significant damage event. Zone 3 is now the place where the settlement was breached. Every subsequent assignment here carries that context.
- Night 4 Surveyor pre-appearance witnessed from Zone 3 → Elias (or whoever is present) carries the most specific Surveyor observation available. This is the highest-value witness event in Chapter 1.

**Significance ceiling**: Zone 3 is the game's observation post for the player's own choices. It is the only zone that faces outward. What happens here is what the player chose to learn or not learn. Its significance is epistemic — it is the place where the player could have known.

**Permanence**: If a Walker breaches Zone 3, the breach is permanent. The zone's function as "safe perimeter" is gone for the chapter. NPCs assigned there afterward carry the knowledge of what got through.

---

### Zone 4 — The Incomplete Structure

**Baseline state**: Active construction. Three walls. Peder's crew.

**Significance triggers**:
- Fourth wall completed → spawns Walker condition. Zone 4 becomes the trigger site. This is the most consequential single construction choice in Chapter 1.
- Foundation excavated to six feet (Day 4/5) → Peder finds something. Zone 4 now carries an object-level significance event (see Objects section below). The zone is no longer just construction; it is archaeology.
- Maren assigned here (her visible want) → her fear-state suppresses. Zone 4 becomes her zone of relative safety; her behavioral state line reflects this for the chapter. If she is later reassigned away, the loss of that assignment is felt.
- Night 2 NPC arc destabilization fires here → the person who was assigned to Zone 4's incomplete structure has their arc shift here, in this specific place. The dawn consequence thread names Zone 4 explicitly. Every subsequent view of Zone 4 carries that NPC's destabilization.

**Significance ceiling**: Zone 4 is the chapter's primary moral site. It is where the player's most consequential building decision occurs (fourth wall), where Peder's foundation arc resolves, and where the deepest Chapter 2 horror will originate. It begins as a logistics decision and ends as the game's most weighted location.

**Permanence**: Foundation excavation result is permanently significant to Peder — and, through him, to anyone he transmits it to. What Peder found at six feet cannot be unfound.

---

### Zone 5 — The Western Hollow

**Baseline state**: Unused. No player action required. No player-facing UI.

**Significance triggers** (all indirect — the player cannot enter Zone 5 in Chapter 1):
- Walker origin: every Walker that spawns has its origin traced to Zone 5 in the dawn consequence thread. Zone 5 becomes legible as the source through repeated association.
- Surveyor patrol: the Surveyor walks the Zone 3/Zone 5 boundary. Its presence makes Zone 5 observable from Zone 3 without entering it.
- Dix's inspection (if approved): Dix enters Zone 5. Returns with a report. Zone 5 acquires official documentation — a different kind of significance. The County now has a record of what is there.
- Constance's knowledge: Constance knows the Zone 5 boundary is the falsified parcel. If the player creates conditions for her to speak, Zone 5 transitions from "place horror comes from" to "place where the fraud happened." This is the highest significance state Zone 5 can reach in Chapter 1.

**Significance ceiling**: Zone 5 is the chapter's central unanswered question. Its significance is entirely indirect — it accumulates meaning through what NPCs report, what creatures emerge from it, and what the survey implies. The player never sets foot in it. By chapter end, it is the most significant place in the game, having never been visited.

**Permanence**: All Zone 5 significance is permanent. The player cannot undo what the hollow is.

---

## Named Objects and Their Significance Potential

Objects become significant when events attach to them. They are not labeled. The player encounters them as part of the environment; significance surfaces through NPC behavioral state lines when the object becomes relevant to an NPC's arc.

### The Handover Ledger

**Starting state**: A record on the table in the manager's post. Fourteen names. Current resource counts. One line of handover note.

**Significance triggers**:
- Player reads it → it becomes the first moral surface of the chapter. Everything the player knows about the discrepancies comes from this object.
- Player provides it unedited to the Association → the ledger is now evidence. The Compact knows it is in the Association's hands. Maren's arc shifts (unburdening or compounding depending on what the ledger shows).
- Player provides edited version → the ledger contains a lie in the player's hand. The original remains. Maren knows both versions exist.
- Compact makes a new entry → by Day 2 (if player ignores the Compact), the ledger has an entry the player did not make. The object now contains action by someone else. The player's control of the record is broken.

**Permanence**: The ledger is permanent and cumulative. Every entry that has been made remains. By Day 5, the ledger is a document of the chapter. It is not a recap screen — it exists as an object in the world, accessible if the player clicks it. Its contents are a byproduct of choices, not a summary of them.

**Session-procedural generation**: The specific discrepancies in the ledger are computed from the opening state. They are the same within a session, but the significance of those discrepancies changes as the player interacts with them. A discrepancy that was covered and then re-covered is a different kind of entry than one that was disclosed immediately.

---

### Peder's Foundation Object (unnamed, Chapter 1)

**Starting state**: Does not exist as an object until Day 4/5 excavation.

**Significance triggers**:
- Foundation excavated to six feet → object appears. No name. No description in the UI. Peder's behavioral state line on Day 5 morning is the only signal: it describes him indirectly without naming what he found.
- Player asks Peder about the foundation before Day 5 → Peder describes it in one sentence (his voice register — practical, redirects abstract to logistics). The object gains a description without being named. It becomes significant to the player through Peder's reluctance.
- Player never asks → the excavation begins automatically Day 5. Peder's line changes. The object exists but is unnamed and unasked-about. This is a different significance state — the thing is there and the player does not know what it is. Chapter 2 opens with it.

**Permanence**: Permanent from Day 5. The object is the Chapter 2 horror seed. It cannot be un-excavated.

**Session-procedural**: The object's identity is a design decision for the horror layer (not specified in Chapter 1 documentation). Its significance in the current session is entirely through Peder's behavioral state — one person's reaction to one thing, unconfirmed and unnamed.

---

### Constance's Survey Document

**Starting state**: Exists in Constance's possession from Hour 0:00. Not visible to the player. Not an assignable object.

**Significance triggers**:
- Survey reference encountered at Compact meeting (Day 3) → the document's existence becomes inferable. The player knows there is a survey. They do not know Constance has the real one.
- Constance's window opens (Day 4) → she may reference it in conversation. Still not visible as an object. It exists as information: she has it, and what it shows is what she describes.
- Player creates maximum conditions (Day 4 + Dix approved + Compact survey reference) → Constance describes what the document shows. The object achieves its full significance without ever being a clickable item.

**Permanence**: The document's content is fixed from the world's founding. Its significance in any given session depends entirely on whether the player created conditions for Constance to speak. If she is silent at chapter end, the document exists and matters — and the player does not know what they missed.

---

### Personal Objects (Arrived-With)

Every NPC who has been in Harrow's Crossing carries something from their former life. These objects are not gameplay items. They appear in behavioral state lines under specific conditions — when an NPC's arc reaches a threshold that makes the object significant to their immediate state.

**Significance triggers** (per-NPC):
- Ruth: a photograph she looks at before the first shift every morning. Only visible in her behavioral state line if her arc has reached a specific grief-adjacent state (triggered by worker loss or her own near-arc-break).
- Elias: the delivery route clipboard from his last day. He still adds entries to it, dates and zones instead of addresses. Visible in behavioral state line when his Observation arc is at full output — "still logging."
- Thomas: a medical reference book he cannot stop annotating. Visible when his arc is contributing, not when it is functional. The annotation behavior is calm; the functional-Thomas does not annotate.
- Maren: a program from the degree ceremony she never attended. In her bag since she arrived. Appears in behavioral state line on the day her arc is most threatened — one mention, never repeated.
- Constance: no object. She describes once, if her arc reaches it, that she stopped carrying things a long time ago.
- Peder: three photographs. He does not say of whom. Visible only when he has spoken about the foundation.

These are "once" register items (per TONE.md's "once" rule). Each object appears at most once per chapter, in one behavioral state line, under specific arc conditions. They are not shrines. They are the residue of the rule that trapped people handle ordinary things with more care than those things warrant.

---

## Backend Integration

Significance state is computed by a **dedicated rule-based pass** (not the Story Progression Agent) and stored in `player_session_state`. This is a deterministic computation over the night event log — no LLM inference, no Enforcer gate. The Master Enforcer validates only LLM-generated text outputs (scene_text, event_text, behavioral_state_line). Rule-based computations like the significance pass and the gossip propagation pass are not Enforcer-gated; they write directly to session state after their own internal validation. This keeps the Enforcer's responsibility boundary clean: it validates generated text, not derived numeric state.

```
player_session_state additions:
  significance_map: {
    zone_id: {
      npc_id: {
        event_weight: float,
        events: [event_id, ...],
        permanent: bool,
        behavioral_modifier: string
      }
    }
  }
  object_significance: {
    object_id: {
      npc_id: {
        event_weight: float,
        events: [event_id, ...],
        accessible: bool
      }
    }
  }
```

**Significance computation pass** (runs at dawn, after night consequence thread generation):
1. Query all night events from `player_night_queue` with a `zone_id` field.
2. For each zone event, identify NPCs assigned to that zone during the event.
3. Increment `event_weight` for each present NPC × event's horror_intensity.
4. Set `behavioral_modifier` based on threshold bands (see table below).
5. Write updated significance_map to session state.
6. NPC Behavior Agent reads `behavioral_modifier` from significance_map in its USER block. This informs behavioral state line generation without the Agent needing to know the full event history.

**Behavioral modifier threshold bands**:

| event_weight | behavioral_modifier |
|---|---|
| 0.0 | `"baseline"` |
| 0.1–0.3 | `"alert"` — NPC is watchful but not changed |
| 0.3–0.6 | `"marked"` — NPC avoids discussing the zone; behavioral register shifts |
| 0.6–1.0 | `"weighted"` — NPC references the zone indirectly; performance affected |
| 1.0+ | `"carrying"` — NPC's arc has internalized the event; behavioral state lines now reference this place with the register of someone who experienced something they cannot explain |

**Object significance**: Tracked separately but feeds the same NPC Behavior Agent USER block. Object significance appears in behavioral state lines only when `accessible: true` — meaning the arc and trigger conditions have been met in the current session. The Agent sees `"maren_program: accessible"` and generates a behavioral state line that includes the program, once, in Maren's register.

---

## Procedural Differentiation Per Session

No two sessions generate the same significance map. The procedural inputs are:

1. **Day 1 assignment choices** — which zones received which NPCs on the first day conditions all subsequent observation and significance accumulation.
2. **Night event seeds** — the seeded random determines which NPCs are pressured on which nights, which zones are targeted, and how the Walker/Watcher/Surveyor events distribute.
3. **Gossip transfer outcomes** — which NPC-to-NPC transmissions fired (seeded per run) determines who carries significance for events they did not directly witness.
4. **Faction interaction timing** — public vs. private negotiations condition how many NPCs accumulated significance for the same event.

The result: the ledger is always significant, but to different NPCs in different ways. Zone 4 is always the construction site, but Maren's relationship to it is entirely different in a run where she was assigned there versus one where she was kept at the ledger. Peder's foundation object always appears, but what it means to the chapter depends on whether anyone asked him about it, and whether the gossip engine moved his silence to another NPC before the player got there.

The game is the same. What it means, to each NPC, in each session, is specific to what the player built.
