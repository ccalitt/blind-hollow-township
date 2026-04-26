# Critical Gaps — Resolution Plan

> Status: IN PROGRESS (2026-04-26).
> Source: Critical review of all frozen design docs.
> Purpose: Convert identified gaps into scoped design work with clear owners and sequencing.
> Each gap gets: the problem restated in one line, the resolution approach, the output doc required, and dependencies.

---

## Sequencing Logic

Gaps are grouped into three tiers by dependency order. You cannot address Tier 2 until Tier 1 is done. Tier 3 is the long-game risk, not blocked, but needs to be seen clearly before Chapter 2 design begins.

```
TIER 1 — FOUNDATIONAL (blocks everything downstream)
  Gap 10: No authored world exists
  Gap 1:  Horror threat is undefined
  Gap 3:  Faction system is undesigned

TIER 2 — MECHANICAL (requires Tier 1 to be grounded)
  Gap 2:  Causal reveal mechanism unspecified
  Gap 4:  Player interaction model undefined
  Gap 7:  Cost model calibration error

TIER 3 — SYSTEMIC / OPERATIONAL (can be worked in parallel but must land before build)
  Gap 5:  No-pause rule needs reexamination
  Gap 6:  Tone Profile divergence between TONE.md and ARCHITECTURE.md
  Gap 8:  Master Enforcer has no retry cap or fallback
  Gap 9:  NPC readability at township scale unvalidated
  Gap 11: Retention architecture across chapters
```

---

## TIER 1 — FOUNDATIONAL

---

### Gap 10 — No Authored World Exists

**Problem**: WORLD_STATE is referenced as the source of NPC voice profiles and lore across ARCHITECTURE.md, TONE.md, and GRAPHICS.md. It does not exist. Every agent that references character voice, lore consistency, or spatial context is operating on a foundation that hasn't been written.

**Resolution Approach**: Write `WORLD_STATE.md` as the first new document. This is not a creative document — it is an operational reference that the LLM system prompt can include verbatim. It contains only the facts the system needs, in the format the system can use.

**Contents required in WORLD_STATE.md**:
- Township name, location, historical context (2–3 sentences maximum — no novels)
- The nature of the horror (see Gap 1 — these are written together)
- 6 named NPCs: name, role, visible want, visible fear, voice register (3–5 words), relationship to player at game start
- 3 faction names, what each wants, what each fears, opening stance toward player
- Map structure: how many zones, what each zone is called, what the player can build in each
- The opening scene: what the player sees at Hour 0:00, what their first decision is

**Output doc**: `design/WORLD_STATE.md`

**Dependency**: None. This unblocks everything else.

**Proposed approach**: Write in a single session. No procedural generation. 100% authored. This is the creative heart of the game — the one document where the answer is not a system, it is a choice.

---

### Gap 1 — The Horror Threat Is Undefined

**Problem**: The Creature/Horror Agent generates night events shaped by player choices, but has no behavioral ruleset to operate within. "Corruption" is referenced throughout the docs but its nature, rules, and limits are not defined. An undefined threat cannot be constraint-generated.

**Resolution Approach**: Define the horror as part of WORLD_STATE.md (they are inseparable — the world and its horror are the same document). The horror definition requires three things:

1. **Nature**: What is it? Not a genre label — a specific entity or force with defined properties. The best horror in this genre space is ecological rather than supernatural-arbitrary. Darkest Dungeon's horrors are old gods with defined appetites. Frostpunk's horror is winter with rules. This War of Mine's horror is human behavior under deprivation with documented mechanics. Hollow Township's horror should have an equivalent specificity.

   **Research basis**: The LIGS and Story2Game systems both work on bounded-rule horror generation. PANGeA's character constraint model implies the horror must have behavioral parameters equivalent to an NPC's want/fear profile — or the Horror Agent has nothing to constrain its output against.

2. **Rules of propagation**: How does it spread? What makes it stronger? What, if anything, slows it? These rules must be finite and authored — not because the game explains them to the player, but because the consequence engine needs them. The player discovers the rules through consequence; the system knows them from the start.

3. **Relationship to player choices**: Specifically — which types of Day choices feed the horror? Building placement feeds it how? NPC assignment feeds it how? Faction negotiation feeds it how? This is the causal grammar of the game. Without it, the Horror Agent generates events that feel random even when they're technically traced to a choice_id.

**Output doc**: Section in `WORLD_STATE.md` — "The Horror: Nature, Rules, Propagation"

**Dependency**: None. Must be written before any Horror Agent prompt or night-event generation is designed.

---

### Gap 3 — The Faction System Is Load-Bearing and Undesigned

**Problem**: CHAPTER_ONE.md has a mid-weight faction choice at Hour 1:45 responding to Day 1 decisions. The faction system it references has never been designed. Three documents mention factions; none define them.

**Resolution Approach**: Design the minimum viable faction system in WORLD_STATE.md. "Minimum viable" means: enough to make the mid-weight choice at Hour 1:45 work, and enough to feed the NPC Behavior Agent's faction-logic trigger.

**What must be defined**:
- Number of factions in Chapter 1: recommend exactly 3 (sufficient for triangular tension, not complex enough to overwhelm a 3–4 hour chapter)
- Each faction's: name, what they represent (not allegory — practical interest), what they want from the player, what they will do if ignored, what they will do if betrayed
- The player's opening relationship to each faction (neutral, cautious, indebted, etc.)
- The negotiation mechanic surface: what does the player actually *do* when interacting with a faction? (Text-list choice, resource offer, NPC assignment — must be specified to design the UI)
- The mid-weight choice at Hour 1:45: what is it, what are the two or three options, what is the second-order consequence of each

**Research basis**: RimWorld's faction system (3 standing values: goodwill, hostility, ally) is the right complexity level for Chapter 1. The key insight from the competitive research is that players want factions to *remember* — DD2 failed partly because nothing persisted. Faction memory in Hollow Township is already solved architecturally (NPC Behavior Agent with DynamoDB-backed standing). The design gap is purely what the factions *are* and *want*.

**Output doc**: Section in `WORLD_STATE.md` — "Factions: Names, Wants, Mechanics"

**Dependency**: Must exist before Hour 1:45 beat can be fully designed. Unblocks Gap 2 (reveal mechanic can be partially faction-driven).

---

## TIER 2 — MECHANICAL

---

### Gap 2 — Causal Reveal Mechanism Is Unspecified

**Problem**: The entire moral weight system depends on the player *recognizing* the connection between Day choices and Night consequences. The design assumes they will. It does not say how.

**Resolution Approach**: Design the reveal as a first-class mechanic. Three viable models exist; choose one and freeze it.

**Option A — Environmental show, no tell** (purist approach)
The connection is visual only. The building Sarah was assigned to shows visible change. Her sprite reflects her state. No text links Day 1 choice to Night 1 consequence. The player infers it. 
- Aligns perfectly with Pillar 3 (logistics feels mechanical until consequence surfaces) and TONE.md (the game does not explain)
- **Risk**: Research (LIGS, Story2Game) shows causal recognition fails for ~30% of players without any surface signal. If the player doesn't make the connection, earned dread collapses into random dread. This is the This War of Mine abandonment problem: consequence without legible cause reads as unfairness, not horror.

**Option B — Dawn-phase consequence journal** (structured reveal)
At each dawn, a sparse log entry surfaces 1–2 explicit links: not a summary, but a specific statement. "The north post was quiet after midnight. Sarah had been assigned there on Day 1." This is one sentence. It connects the chain without editorializing.
- Compatible with TONE.md (declarative, non-interpretive)
- Aligns with NOT-THIS.md caveat: NOT a "day recap / summary screen" — this is a consequence thread, not a score. The distinction: it names the chain, it does not evaluate it.
- **Research basis**: GENEVA's DAG model shows consequence chains are only felt as earned when the player can trace the node path — even implicitly. One sentence of causal anchoring is the minimum viable signal.

**Option C — Consequence inscription** (environmental + text hybrid)
Causal text appears *on the world*. A mark on the building wall. A name carved somewhere. A logbook that the player can inspect but is never forced to read. The connection is available but not pushed.
- Most authorial control, highest production cost (requires physical world integration)

**Recommendation**: Option B for Chapter 1 (legibility is more important than purity at launch; the player needs to understand the system before they can fear it), with Option A as the target register from Chapter 2 onward once the player knows the grammar.

**Output doc**: `design/REVEAL_MECHANIC.md` (short — 1–2 pages, frozen before Chapter 1 build)

**Dependency**: Requires WORLD_STATE.md (Gap 10) to be written first — the reveal references specific NPCs and choices by name.

---

### Gap 4 — Player Interaction Model Is Undefined

**Problem**: The player has no avatar, the day phase requires "onboarding through action," the camera is elevated 3D — but nowhere is it specified what the player *does* with their mouse and keyboard. Click to select? Drag to place? Direct order to NPC? This is the entire UX surface of the game.

**Resolution Approach**: Define the interaction model as a single-page spec before any Godot work begins. The interaction model must answer:

1. **Primary cursor mode**: Point-and-click on world objects (buildings, NPCs, ground tiles) — Frostpunk model. The player has no avatar; the cursor is their presence. This is the correct model for a township management game.

2. **Building placement**: Grid-snap drag-and-drop from a build menu, or click-to-select tile then click-to-place. Either works; one must be chosen. The moral implication: placement should feel like a logistics decision, not a puzzle — so snap-to-grid with no alignment challenge is correct (the difficulty is the consequence, not the placement act).

3. **NPC interaction**: Click on named NPC → context panel appears with available assignments/tasks. Not a dialogue tree — a task list. The NPC has their visible want and fear in the panel (not labeled "want" and "fear" — just their current state in behavioral language). Player selects a task. Done. The moral weight is invisible at assignment time.

4. **Faction negotiation**: Click on faction representative NPC → text-list of negotiation options. No dialogue wheel. Text options are task-framed, not morally framed. Selection is immediate — no undo.

5. **Night phase input**: Minimal. Player can pan camera, zoom. Cannot issue orders (NPCs are in their assigned positions). Cannot pause. This is the correct model.

**Research basis**: Frostpunk's interaction model is the closest reference — the player is a disembodied decision-maker operating on a visible city. The key lesson from FP2's mixed reception: when the interaction model becomes abstract (political votes replacing direct construction), players feel distance instead of consequence. The click-on-the-person model is essential.

**Output doc**: Section in `WORLD_STATE.md` or standalone `design/INTERACTION_MODEL.md` (the latter if it grows beyond 1 page)

**Dependency**: Required before GRAPHICS.md can be frozen (the UI section in GRAPHICS.md cannot be completed without knowing the interaction model). Required before any Godot UI work begins.

---

### Gap 7 — Cost Model Calibration Error

**Problem**: ARCHITECTURE.md models 24 decision points per 4-hour session. CHAPTER_ONE.md specifies approximately 3–4 micro choices per 30-minute day phase + 1 mid per 30–45 minutes + 1 macro per chapter. Actual decision density is ~40–60 decisions per session — approximately 2× the modeled figure. All scaling projections compound this error.

**Resolution Approach**: Recalibrate the cost model with correct decision density. This is arithmetic, not design.

**Revised estimate**:
```
Chapter 1 session: ~3.5 hours average

Day phase decisions (micro):
  Day 1 (30 min): 3–4 micro = 4 avg
  Day 2 (45 min): 3–4 micro = 4 avg
  Day 3 (60 min): 3–4 micro = 4 avg
  Subtotal micro: ~12 per session

Day phase decisions (mid):
  ~1 per 30–45 min × 3 day phases = ~3 mid choices

Macro choices: 1 per chapter = 1

Night phase consequence events (LLM calls):
  Night 1: 2–3 events (micro consequences surface)
  Night 2: 3–4 events (micro + mid consequences)
  Night 3: 4–5 events (chapter climax — all threads converge)
  Subtotal: ~10 night events

NPC arc updates: ~6 NPCs × 2 updates/session = 12 arc calls
Master Enforcer validation: 1 call per LLM output = mirrors above

Total inference calls per session: ~38 day decisions + 20 night events = ~58 calls
(vs. 48 modeled — difference is night event density, not day)

Revised cost with prompt caching (95% hit rate):
  58 calls × $0.00012/call = ~$0.007/session (vs. $0.006 modeled — immaterial)
  
Monthly scaling (revised):
  Indie (100 DAU): ~$21 LLM (vs. $18) — negligible
  Early Access (1K DAU): ~$210 LLM (vs. $180) — negligible
  Growth (10K DAU): ~$840 LLM (vs. $720) — ~17% higher
```

**Finding**: The error exists and should be corrected, but it does not threaten the cost model materially at any scale. The ~17% variance at growth tier is within the model's existing uncertainty bands. Update ARCHITECTURE.md cost section with corrected figures; note the calibration basis.

**Output**: Edit to `design/ARCHITECTURE.md` cost model section — recalibrated numbers, corrected decision density basis.

**Dependency**: None. Can be done immediately.

---

## TIER 3 — SYSTEMIC / OPERATIONAL

---

### Gap 5 — No-Pause Rule Needs Reexamination

**Problem**: GRAPHICS.md bans player pause during night phase as a horror design decision. The actual consequence is: simultaneous real-time text reading + visual monitoring + no ability to process — which is a UX failure that can break immersion faster than pause would.

**Resolution Approach**: Reframe the constraint. The design goal is *felt inability to look away* — not *technical inability to pause*. These are different.

**Proposed model**: Pause is permitted but costs something. Specifically:
- Player can pause at any time during night phase.
- Pausing does not stop the narrative log's text from having been delivered — it has already landed.
- Pausing does stop any *pending* events from arriving for the duration.
- What the pause UI shows: the current state of the township — still, silent, and wrong. Not a menu. Not black screen. The frozen world at that moment.
- The act of pausing does not undo what the player has seen. It gives them a moment to sit with it.

This converts pause from "comfort escape" into "you can stop time but you still have to look at it." That is more frightening than forced real-time, not less.

**Research basis**: Darkest Dungeon allows pause during combat — and the horror is not diminished by it, because the horror is in the *state*, not the *pace*. This War of Mine allows pause — the dread of the scavenging screen is not reduced by the ability to stop and look at it. The "watching feeling" in both games survives pause because the horror is visual and spatial, not just temporal.

**Output**: Update to `design/GRAPHICS.md` night phase UI section. One paragraph replacing the no-pause rule.

**Dependency**: None.

---

### Gap 6 — Tone Profile Divergence Between TONE.md and ARCHITECTURE.md

**Problem**: TONE.md is the full tone bible. ARCHITECTURE.md contains a compressed Tone Profile for the LLM system prompt. They already diverge at freeze: the "Once" category (warmth permitted once per chapter, dark humor permitted once per chapter) is absent from the system prompt. The LLM is constrained more tightly than the design intends.

**Resolution Approach**: Add a reconciliation step to the deploy process and fix the divergence now.

**Immediate fix**: Update the Tone Profile in ARCHITECTURE.md to include the "Once" category as a conditional rule:

```
CONDITIONAL PERMISSIONS (once per chapter, must be earned):
  Warmth: Permitted when two named NPCs have shared prior consequence. 
    Format: behavior-level only (they work alongside each other without speaking about it).
    Not: dialogue about how much they care about each other.
  Dark humor: One line, NPC-specific to character's established register.
    Not permitted: from NPCs with "stoic" or "formal" voice registers.
    Not permitted: about the horror itself.
  Explicit loss statement: One direct articulation of what an NPC has lost.
    Trigger: only after that NPC has experienced a consequence traceable to player choice.
    Not: preemptive grief. Only retrospective statement.
```

**Process fix**: Add a rule to CLAUDE.md — any change to TONE.md requires a corresponding update to the Tone Profile in ARCHITECTURE.md and a re-run of the 50-prompt regression suite.

**Output**: Edit to `design/ARCHITECTURE.md` Tone Profile section. Edit to `CLAUDE.md` session rules.

**Dependency**: None.

---

### Gap 8 — Master Enforcer Has No Retry Cap or Fallback

**Problem**: The Enforcer retries any pillar-violating output indefinitely. Edge cases (player with no meaningful day choices, contradictory state) could produce unresolvable generation requests. No fallback exists for what happens when a night event cannot be generated.

**Resolution Approach**: Add retry cap and fallback chain to the Enforcer specification in ARCHITECTURE.md.

**Retry policy**:
```
Retry cap: 3 attempts per generation request.

Attempt 1: Normal generation with full dynamic context.
Attempt 2: Reduce dynamic context to only cause_chain items (strip NPC memories,
           strip scene history — isolate the causal input, remove noise).
Attempt 3: Fall back to authored fallback event library (see below).

If all 3 fail: log to error_queue, serve fallback event, page on-call
              (Phase 2+) or write to error log (Phase 1).
```

**Fallback event library**: A set of 20–30 authored minimum-viable horror events, each requiring only a `npc_id` and a `day` to render. These are not generated — they are written by the human author, pass the tone test, and cover the essential case: "something is wrong with [NPC] tonight, traceable to Day [X], but the specifics cannot be generated." They are the floor, not the content.

Example fallback event:
```json
{
  "event_text": "[NPC_NAME] did not come in from the [ZONE] at the third watch. The post is not empty. [NPC_NAME] is simply not at it.",
  "cause_chain": ["[CHOICE_ID]"],
  "horror_intensity": 1,
  "tone_check": "authored"
}
```

This is consistent with TONE.md's register: specific, quiet, traceable, no resolution.

**Output**: New section in `design/ARCHITECTURE.md` — "Master Enforcer: Retry Policy and Fallback Library"

**Dependency**: Requires WORLD_STATE.md (Gap 10) to write the fallback library — the events reference named zones and NPCs.

---

### Gap 9 — NPC Readability at Township Scale Unvalidated

**Problem**: GRAPHICS.md claims 2D billboard sprites at 8–12% screen height carry sufficient emotional information. This claim is the technical foundation of Pillar 2 (The Watched Feeling). It has not been tested at the proposed display size.

**Resolution Approach**: This is a prototyping gate, not a documentation gap. The answer cannot be determined in a design doc — it must be validated with a screen.

**Validation test** (before GRAPHICS.md is frozen):
1. Create a single test sprite: one NPC at the proposed 96×128px size, with 4 emotional states (neutral, afraid, angry, corrupted).
2. Render it in Godot at the proposed camera distance (8–30 units) and elevation (35–45°).
3. Show the result to 3–5 people who have not read the design docs. Ask: can you tell the difference between the 4 states? Can you name what each state is?
4. If recognition rate is below 80%: redesign the sprite resolution (recommend 128×192 for primary NPCs) or redesign the emotional signal (higher-contrast expression, larger head-to-body ratio, color-coded state accent — e.g., afraid NPCs get a pale face tint that is readable at distance).

**Fallback design if small-sprite readability fails**: Consider a subtle world-space indicator above NPC head — not a floating UI element, but a visual state that is *part of the NPC's world presence*. A torch they're holding that changes color. A posture that is readable as shape, not expression. This keeps Pillar 2 without requiring pixel-level expression work at small display sizes.

**Output**: Prototyping task — not a doc. Note in `design/GRAPHICS.md` that this section cannot be frozen until the validation test passes.

**Dependency**: Godot environment setup. Can be done with a placeholder sprite.

---

### Gap 11 — Retention Architecture Across Chapters Is Absent

**Problem**: The design is optimized for the end-of-Chapter-1 emotion: unresolved compulsion. This is the correct instinct for Chapter 1. It is potentially fatal for a multi-chapter game. This War of Mine has a documented 40%+ abandonment rate attributed to unresolved emotional cost without sufficient relief beats. The design currently has no model for how sustained dread is architecturally possible across multiple chapters without either: (a) releasing the tension in a way that compromises Pillar 1, or (b) accumulating weight until the player stops.

**Resolution Approach**: Address this at the design level before Chapter 2 work begins. Do not retrofit it — plan the architecture now so Chapter 1 is built with it in mind.

**The core finding from research**: The engagement loop is RELIEF → UNEASE → COMPULSION. The design correctly identifies this. The gap is that every chapter is designed to end at COMPULSION — which means every chapter begins at UNEASE. There is no designed reentry point of RELIEF at chapter start. If Chapter 2 begins in the same register that Chapter 1 ends, the player has no earned breath. The accumulation becomes weight, not dread.

**Proposed retention architecture** — the "false dawn" model:
- Chapter 2 opens with a genuine relief beat. Something was saved. Something that the player could not be sure would survive, survived. This is not a clean ending — it is a specific, named, traceable positive outcome from their Chapter 1 choices.
- The relief is real but brief. Within 15–20 minutes of Chapter 2, it is complicated — not reversed, but complicated. The thing that survived has a cost that was deferred, not avoided.
- This gives the player a reason to return (something they care about made it) without breaking Pillar 1 (every right choice arrives already compromised — the survival carries its own cost).

**Research basis**: This is structurally identical to how The Road maintains reader engagement: the boy. Something the protagonist is protecting that is worth protecting. Hollow Township needs one such anchor per player — and because choices diverge, the anchor must be *the NPC the player most tried to protect in Chapter 1*, which is knowable from the choice log.

**What this requires from Chapter 1 design**: The NPC arc system must track which NPC has the highest player-investment signal (most choices made in their direction, most micro choices affecting them) — so Chapter 2 can open with that NPC's state as the relief anchor. This is an architectural decision that must be built into Chapter 1, not bolted onto Chapter 2.

**Output**: New section in `design/CONCEPT.md` — "Cross-Chapter Retention Architecture: The False Dawn Model" — and a note in `CHAPTER_ONE.md` that NPC investment tracking is a required output of the Chapter 1 arc system.

**Dependency**: Requires WORLD_STATE.md (NPCs must be named and characterized before investment tracking can be designed). Should be addressed before Chapter 1 Godot build begins.

---

## Summary — Work Order

| Priority | Gap | Output Required | Blocks |
|----------|-----|----------------|--------|
| 1 | Gap 10 — No authored world | `WORLD_STATE.md` | Everything |
| 1 | Gap 1 — Horror undefined | Section in WORLD_STATE.md | Horror Agent, night events |
| 1 | Gap 3 — Factions undesigned | Section in WORLD_STATE.md | Hour 1:45 beat, NPC Behavior Agent |
| 2 | Gap 4 — Interaction model undefined | `INTERACTION_MODEL.md` or WORLD_STATE section | GRAPHICS.md freeze, Godot UI |
| 2 | Gap 2 — Reveal mechanic unspecified | `REVEAL_MECHANIC.md` | Chapter 1 playtesting |
| 2 | Gap 7 — Cost model recalibration | Edit ARCHITECTURE.md | Investor/planning conversations |
| 3 | Gap 6 — Tone Profile divergence | Edit ARCHITECTURE.md + CLAUDE.md | Every LLM deploy |
| 3 | Gap 8 — Enforcer retry cap | Edit ARCHITECTURE.md | Production stability |
| 3 | Gap 5 — No-pause reexamination | Edit GRAPHICS.md | Night phase UX |
| 3 | Gap 11 — Cross-chapter retention | Edit CONCEPT.md + CHAPTER_ONE.md | Chapter 2 design |
| Proto | Gap 9 — Sprite readability | Prototype test | GRAPHICS.md freeze |

---

## What Gets Written Next (Proposed)

The single highest-leverage action is writing `WORLD_STATE.md`. It unblocks Gaps 1, 3, 4, 8, and 11 simultaneously. It is also the only document that is purely a creative act — the rest are systems built on top of it. Every other gap is a design or engineering problem. This one is a choice about what the game actually is.

Until the world has a name, the horror has a nature, and the NPCs have voices — the consequence engine has nothing to be consequential *about*.
