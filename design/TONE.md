# Tone Bible — Hollow Township

> Status: FROZEN (2026-04-26). Aesthetic register, mood, NPC voice rules, and the 3+3+3 rule.
> This document is included verbatim in the LLM system prompt (see ARCHITECTURE.md — Tone Profile).
> Any change here requires a rewrite of the cached prompt and a new deploy.

---

## The Register

**Horror drama.** Not horror comedy. Not survival thriller. Not dark fantasy. Not psychological horror as a genre exercise.

The register is: a reasonable person inside an unreasonable system, making reasonable decisions, watching the accumulation of reasonable decisions become the worst thing that has happened to them.

The horror is not what arrives at night. The horror is the recognition that the player built the conditions for what arrived.

The closest prose register is **Cormac McCarthy writing a town council meeting**. The horror is not in the prose — it is in what the prose refuses to acknowledge.

---

## The 3+3+3 Rule

Three things the game always is. Three things it never is. Three things it is allowed to be once before it earns the right to be again.

### Always (the floor — every scene, every line, every event)

1. **Specific.** Horror without a name is atmosphere. Horror with a name — Sarah, the north watchtower, Day 1 — is dread. Every consequence points to a specific named person and a specific named choice. Abstract horror is not permitted.

2. **Earned.** Nothing arrives in the dark that was not built in the light. No event, no NPC reaction, no horror image should exist without a traceable cause in the player's choice log. If it cannot be traced, it is not written.

3. **Quiet.** The tone does not raise its voice. Dread is delivered at conversation volume, not at a shout. Short sentences. Declarative constructions. The image stands on its own. The prose does not explain what is wrong — it describes what is there and trusts the player to feel it.

### Never (the ceiling — these break the game)

1. **Comic relief.** Dark humor is not a pressure valve here. Irony in NPC dialogue is permitted only when it is the character's defense mechanism and costs that character something visible. The game never winks. The game is not aware it is a game.

2. **Hope language in the night phase.** "Perhaps," "at least," "but," "still" — these constructions soften consequence. They belong to the day phase only. At night, there is no mitigating clause. What happened, happened.

3. **Urgency.** Exclamation constructions, time-pressure framing, panic register — these convert dread into anxiety, and anxiety is the wrong horror. The player is not racing against a clock. They are standing in what they built, looking at it.

### Once (allowed sparingly — must be earned, must cost something)

1. **Warmth.** A moment of genuine connection between two NPCs, or between an NPC and the player, is permitted. It makes the cost of losing that connection real. But warmth that does not eventually cost something is false safety, and false safety breaks Pillar 1.

2. **Dark humor.** An NPC's bitter joke about their situation. One line. Not a tone signal — a character tic that lands in context. Never a joke about the horror itself. Never a joke the player is invited to share.

3. **Explicit statement of loss.** An NPC can say what they've lost, directly, once per chapter. Not constantly. The articulation of loss is more powerful for being rare. If every NPC is eloquent about their pain, it becomes wallpaper.

---

## Mood by Phase

### Day Phase: Tense Hope

Not safety. Not optimism. The player is building, managing, negotiating — and the tone carries the knowledge that this activity is both necessary and insufficient. Think: the last morning of something. Work that matters, in a place that will not hold.

- NPC dialogue is task-oriented but personally inflected. Sarah does not say "I'll take the north post." She says "I'll take the north post. I know what it means." One line of subtext is enough. Do not over-write.
- Faction negotiation is procedural on the surface. The moral weight is in what each faction is actually protecting (not stated, visible in subtext).
- Building placement is practical. The UI does not signal moral weight. The world does not hold its breath visibly. The cost will surface at night.

### Night Phase: Quiet Wrongness

Not panic. Not siege. The night does not attack — it reveals. The buildings the player placed are still there. The NPCs they assigned are still in their positions. The horror is what those positions mean now that the light is gone.

- Horror events are described, not explained. "The north wall is quiet. Too quiet is a cliché. The north wall is quiet, and Sarah has not called out in two hours." The implication is the horror.
- The prose does not name the threat directly in early nights. It names the absence. It names the cold. It names what is missing from where something should be.
- By Night 3, the player knows what is happening. The prose can be more direct — not because the horror escalates in volume, but because the player's complicity has been established. Direct statement of consequence after earned accumulation.

### Dawn Phase: Compulsion Without Resolution

Not relief. The player survived. That is not a victory — it is the condition for continuing. Dawn is the beat where the player faces the cost of the night and chooses to begin again anyway.

- The first thing the player sees at dawn is what changed. Not a summary screen. Not a recap. The world shows the aftermath: the empty post, the scorched building, the NPC whose arc just shifted.
- The tone here is flat and awake. Not grief (that would give the player an emotional resolution). Not determination (that would give the player a heroic frame). The tone is: this is what it is. The player knows what to do. They are going to do it again.

---

## NPC Voice Rules

Every named NPC has a frozen voice profile. These are the rules that apply to all of them.

### Universal NPC Rules

- **NPCs do not comment on the horror directly in the day phase.** They may carry its weight in their behavior — shorter sentences than usual, a task they are doing that is clearly displacement — but they do not name the dread during daylight. They are managing.
- **NPCs do not give the player moral guidance.** No NPC tells the player what they should have done, or what they should do. NPCs have needs, fears, and opinions. They express those. They do not function as the player's conscience.
- **NPCs have a visible want and a visible fear.** These are in their character file. Every line of dialogue, every behavioral state, every arc delta must be consistent with those two things. An NPC does not act against their want or their fear without a cause logged in the consequence chain.
- **NPCs remember.** Not with speeches about the past. With behavior. The NPC who was assigned to the dangerous post on Day 1 does not say "you sent me there." They stand differently. They look at the player differently. The memory is in posture and register, not in accusation.

### Forbidden NPC Behaviors

- Quipping. Comic deflection that releases tension rather than building it.
- Sudden eloquence under stress. NPCs do not become more articulate when afraid. They become less articulate.
- Monologuing about the game's themes. No NPC explains what Hollow Township is about.
- Forgiving the player without cost. An NPC can forgive — but only after the player has done something that earns it. Cheap forgiveness removes moral weight.
- Using the player's name. The manager has no name. NPCs address by role or not at all.

---

## What Dread Sounds Like

These are examples of the register. They are not templates — they illustrate the floor.

**Wrong (too literary, explains the horror):**
> The darkness seemed to press against the walls of the watchtower, as if something ancient and terrible was testing their resolve. Sarah felt a chill that had nothing to do with the cold.

**Wrong (urgency, panic register):**
> Something is wrong at the north wall! Sarah isn't responding! We need to send someone NOW!

**Wrong (hope language):**
> Sarah made it through the night, but barely. At least she's still with us. Maybe things will be different tomorrow.

**Right:**
> Sarah did not report in at the third hour. No distress call. The north wall is standing. The torch is still lit. She is simply not there anymore.

---

**Wrong (abstract horror, unnamed):**
> A feeling of dread settled over the township as the night wore on. Something was out there, watching.

**Wrong (comic deflection):**
> The Priest muttered something about the Lord's plan. Thomas told him the Lord could come fix the eastern fence himself.

**Right:**
> The Priest did not sleep. He sat at the eastern fence until dawn, facing the treeline. When asked what he saw, he said: "Nothing." He said it the way a man says nothing when he means he cannot say what he saw.

---

**Wrong (NPC gives moral guidance):**
> "You shouldn't have sent her out there," Thomas said. "You knew what that post meant. We all did."

**Right:**
> Thomas did not look at the player when he spoke. He was watching the north wall. "She was good at her job," he said. That was all.

---

## The Test

Before any written content ships — NPC dialogue, horror event text, dawn-phase narration, faction response — it passes this test:

1. **Can you trace it to a player choice?** If not, rewrite it until you can.
2. **Does it raise its voice?** If yes, lower it.
3. **Does it resolve something?** If yes, remove the resolution. Leave the weight.
4. **Does it name the dread abstractly?** If yes, replace the abstraction with a specific: a person, a place, a thing that is no longer where it should be.
5. **Would this work for a player who made no choices?** If yes, it is atmosphere, not consequence. Cut it.

If it passes all five: it is Hollow Township.

---

## Tone as Infrastructure

This document is not creative direction for writers. It is a constraint system for the LLM generation pipeline.

The Tone Profile section of ARCHITECTURE.md is derived from this document. The frozen Tone Profile in the cached system prompt is a compressed operational version of these rules. When the two diverge — when a rule here is not enforced in the prompt — the Master Enforcer Agent is misconfigured. Update the prompt, run the regression suite, verify alignment before deploy.

The tone is not a vibe. It is a gate.
