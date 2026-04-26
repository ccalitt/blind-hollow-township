# Engagement Loops — Hollow Township

> Status: IN PROGRESS (2026-04-27). Draft solution — pending user review before freeze.
> Reference: Dave the Diver structural analysis. All proposals cross-checked against PILLARS.md, CONCEPT.md, CHAPTER_ONE.md, INTERACTION_MODEL.md, NOT-THIS.md.
> Purpose: Address four structural gaps that research identifies as the difference between "I finished it" and "I can't stop."

---

## The Problem This Solves

The three-beat loop (RELIEF → UNEASE → COMPULSION) is correctly designed within a single session.
The gap: nothing in the current design explains *why a player picks up session two*. The loop closes
at dawn. The player is implicated and dreading the next day. But there is no *pull* — no designed
reentry. Dave the Diver's core insight is that engagement is not produced by a single loop; it is
produced by **reciprocal feeding** between loops, so that ending one session creates visible,
unresolved business that makes the next session feel necessary.

The four additions below address this without adding mechanics. They are structural adjustments to
how existing systems surface their outputs.

---

## 1. Dawn Unlocks: Night Consequences Modify Day Options

**Problem**: Currently the dawn consequence thread is read-only. The player sees what their
Day choices caused, but that realization has no operational impact on Day N+1. The COMPULSION
beat fires emotionally but has no mechanical hook to pull the player into the next day.

**Solution**: Dawn consequence thread entries that cross a significance threshold unlock or
modify specific Day options that were not available before. These are not rewards — they are
complications. The night's revelation changes what is *possible* tomorrow.

### Rules

- Only triggered by events with `horror_intensity == 2` or `horror_intensity == 3`.
- One unlock or modification per dawn maximum. Not every dawn produces one.
- The modification is never labeled as such. It appears as a new context panel option or a
  previously greyed assignment becoming available — no "unlocked!" notification.
- All modifications are complications, not improvements. They expand what the player can do
  in order to create new moral choices, not to reward good play.

### Examples by Event Type

| Night Event | Dawn Modification |
|-------------|-------------------|
| Watcher observed Elias at the ledger | Elias's context panel gains: "He wants to tell you something." — one-time option, no label |
| Walker reached Zone 3, left footprints | Zone 3 night-watch assignment gains additional option: "Send two." — costs coverage elsewhere |
| Surveyor paused at boundary (Night 4) | A hint surfaces that Constance may know something — one new behavioral state line describing her at the Zone 3/5 boundary at dawn. This does NOT open Constance's window. Her window requires the conditions in CHAPTER_ONE.md §Day 4 (Compact survey reference encountered AND one of: Dix inspection approved OR Peder foundation question raised). The Dawn Unlock creates pressure toward those conditions — it does not bypass them. A player who sees the hint but has not met the conditions must still build the required context before Constance speaks. |
| Bonded pair had one member threatened | "Keep them working together" option costs one zone coverage slot next day |
| Thomas's silence has compounded | An NPC's behavioral state line becomes: "Hasn't spoken to Thomas since the morning count." — a new assignment becomes available that puts them together |

### Implementation Surface

This does not require a new backend system. Dawn modification entries are produced by
`generate_thread()` in `consequence/thread_generator.py` — the ThreadEntry already carries
`night_event` and `day_choice`. A new optional field `day_unlock: dict | None` is added to
`ThreadEntry`. The engine surfaces this field to the Godot client at dawn.

The Godot client reads `day_unlock` entries and enables the corresponding UI option on Day N+1.
The player sees the option. They do not see the connection to the night event that unlocked it.

**Pillar:** 1 — Earned Dread. 3 — Moral Weight at Every Turn. 4 — Day/Night as Structural Argument.

---

## 2. Township Objectives: Visible Goals That Are Secretly Moral

**Problem**: Dave's engagement is partly driven by 2–3 visible objectives per session that give
the player a self-generated sense of purpose. Hollow Township's day phase has faction demands and
NPC wants — but none of these are surfaced as a trackable objective list. Players new to the game
may feel directionless between decision points, which reduces the sense of time pressure that makes
the macro choice land heavy.

**Solution**: A persistent **Township Board** — a single in-world object the player can click at
any time during day phase — that shows 2–3 active items drawn from NPC wants, faction pressures,
and township conditions. The items are descriptive, not instructional. They do not tell the player
what to do. They reflect the state of the world.

### Rules

- **Not a quest log.** There are no objectives with completion states, markers, or rewards.
- **Not a moral label.** Items describe situations, not choices. "The Association has been
  waiting three days for the ledger." is an item. "Deliver the ledger to the Association." is not.
- Items are generated from `SessionState` at day start by a rule-based pass — no LLM.
- Maximum 3 items visible at any time. Oldest item rotates out when a newer pressure is generated.
- Items disappear when the relevant situation resolves — or when it is too late. No "failed" state.
  The item simply stops being there. The player may or may not notice when it leaves.
- The Township Board is a physical object in the Settlement Common (Zone 2). The player
  must walk the camera to it and click it. It is not a UI panel that is always visible.

### Item Templates (not exhaustive)

```
"[NPC_NAME] hasn't been assigned since [day]. Their post is empty."
"The [faction] representative was last seen on Day [N]. No message since."
"[NPC_NAME] and [NPC_NAME] have worked the same post for [N] days."
"The [zone_name] hasn't been covered since Night [N]."
"[NPC_NAME] hasn't spoken at morning briefing in two days."
"The ledger has not been returned. [Faction] last asked on Day [N]."
```

### SessionState Flag → Item Mapping (authoritative — builder uses this, not the templates alone)

Each item has exactly one trigger condition in `SessionState`. The rule-based pass checks these in order; first 3 that match are shown.

| SessionState condition | Item text produced |
|---|---|
| `npc_states.[id].arc_state` == `fragile` or `broken`, and NPC has no current zone assignment | "[NPC_NAME] hasn't been assigned since Day [last_assignment_day]. Their post is empty." |
| `faction_states.[faction].last_contact_day` < current_day - 2 | "The [Faction] representative was last seen on Day [N]. No message since." |
| Two NPCs share the same zone for ≥ 2 consecutive days (from `player_choices` GSI-1) | "[NPC_NAME] and [NPC_NAME] have worked the same post for [N] days." |
| A zone had no NPC assigned on the previous night (from night pre-computation payload) | "The [zone_name] hasn't been covered since Night [N]." |
| An NPC's `gossip_stage` == 3 and they have not yet had a direct player interaction that day | "[NPC_NAME] hasn't spoken at morning briefing in two days." — only fires if `knowledge_states.[id].gossip_stage` == 3 and no `player_choices` entry for that NPC on the current day |
| `knowledge_states.maren.held_observations` contains `ledger_discrepancy_knowledge` and no disclosure choice logged | "The ledger has not been returned. [Faction] last asked on Day [N]." |

Items expire when their trigger condition resolves (zone assigned, faction contacted, disclosure made). No "failed" label — the item disappears. If none of the above conditions are active, the Board shows nothing. An empty Board is information.

### Why This Doesn't Violate NOT-THIS.md (No Day Recap Screen)

The Township Board is not a recap. It does not tell the player what their choices *meant*.
It describes the current state of the world in the same register as NPC behavioral state lines —
observable, not evaluative. The player reads it as a manager checking on their settlement.
They may or may not act on what they see. The board does not know the difference.

**Pillar:** 2 — The Watched Feeling. 3 — Moral Weight at Every Turn. 5 — Genre Whitespace
(the Board is the simulation layer making the drama legible — all three genres simultaneously).

---

## 3. Character Mediated System Discovery: NPCs Surface System Existence

**Problem**: The gossip system, significance system, and dawn thread operate invisibly. Players
who don't read design documents may complete Chapter 1 without understanding that the systems
exist — reducing the sense that the world is watching and responding specifically to them.
Tutorial text would break Pillar 3 (moral silence) and Pillar 2 (the Watched Feeling requires
discovery, not instruction).

**Solution**: The NPC Behavior Agent occasionally generates a behavioral state line that hints
at system existence through specific NPC behavior — without naming the system. The player
discovers the system by recognizing a pattern in NPC behavior.

### Rules

- These are generated by the NPC Behavior Agent, not authored. They emerge from the
  `knowledge_state` and `zone_significance` inputs the agent already receives.
- They follow all existing behavioral state line constraints: ≤ 80 chars, voice-register
  correct, no moral evaluation, no zone_n literals.
- They are not more frequent than any other behavioral state line. They are the same lines —
  just grounded in inputs that happen to imply system activity.
- The player may not catch them. That is correct. The Watched Feeling is felt, not explained.

### Examples by System

**Gossip engine surfacing:**
- Ruth (after receiving treeline_movement from Elias via bond):
  "Keeps looking at the eastern window. Was talking to Elias before the morning count."
- Thomas (after gossip_stage reaches 3, has transmitted):
  "Chose his words carefully with the arrival. Then didn't choose any."

**Significance system surfacing:**
- Peder (zone_significance for Zone 5 = "marked"):
  "Stayed on the near side of the perimeter. Didn't explain why."
- Maren (object_significance for handover_ledger = accessible):
  "Left the ledger exactly where she found it. Both times."

**Dawn thread mechanism surfacing (before the thread fires):**
- Elias (night before thread will reference his assignment):
  "Asked about the eastern ridge assignment. Not about the hours. About the reason."

### Agent Instruction Addition

The NPC Behavior Agent prompt (`agents/npc_behavior.md`) adds one instruction:
> When `zone_significance` contains a modifier of "marked" or higher, OR when
> `knowledge_state` contains a multi-observation array, OR when `accessible_objects`
> is non-empty: the state line may reference the NPC's *behavioral response* to that
> input — not the input itself. The NPC notices their world through action, not description.

**Pillar:** 2 — The Watched Feeling. 5 — Genre Whitespace (simulation depth visible through
narrative drama — both genres simultaneously).

---

## 4. Arrival as World Expansion: Each New NPC Unlocks One Discovery

**Problem**: The four arrivals in Chapter 1 (Days 2–5) feed the productivity and arc systems
but do not expand what the player can *discover*. In Dave the Diver, new areas unlock new fish
which enable new recipes — each discovery cascades. In Hollow Township, arrivals arrive and
begin working. There is no new discovery attached to their presence.

**Solution**: Each arrival, when assigned a role, makes one previously inaccessible interaction
available for that day only. Not a reward. Not a bonus. A door that wasn't open before.

### Rules

- The interaction is tied to the arrival's skill domain — it is what they *know* that opens it.
- It is available for one day only, from the moment of role assignment.
- It is presented identically to all other interactions — a text option in a context panel,
  no label, no weight indicator.
- If the player doesn't take it that day, it is gone. The game does not note its absence.
- The interaction generates a logged micro-tier choice (`arrival_discovery_[domain]`).
  It feeds the consequence engine. It may surface in a dawn thread — or not.

### Interactions by Skill Domain

| Domain | What Opens |
|--------|------------|
| Construction | Peder's context panel gains: "Ask him to look at the Zone 4 foundation." — one day only |
| Medicine | Gains: "Ask [arrival] about the injuries Thomas mentioned." — opens a thread Thomas has been suppressing |
| Logistics | Township Board gains a 4th item visible only today: the supply route the Association has been using |
| Observation | Elias's context panel gains: "He wants to show you something at the eastern boundary." |
| Social | Constance's interaction options expand by one if she hasn't already spoken: "How does the Compact know about the old survey?" |

### Why Not Earlier

Days 1 and 2 arrivals cannot open Constance's window (timing gate in CHAPTER_ONE.md).
Days 3–4 arrivals can only open interactions the game state supports — if Thomas has already
spoken, his thread is closed; the Medicine domain interaction does not appear.
Domain-interaction pairing is checked against `SessionState` flags before presenting the option.

**Pillar:** 1 — Earned Dread (the discovery may surface something the player would prefer
not to know). 2 — Watched Feeling (the world fills in around the player's decisions).
5 — Genre Whitespace (simulation depth feeding narrative drama — the arrival's skill domain
is a simulation mechanic that drives story discovery).

---

## What Is Not Added

All four additions above are structural — they route existing system outputs to new surfaces.
None of them add new mechanics, new systems, or new content types.

Specifically excluded:
- **No reward system**: dawn unlocks are complications, not rewards. Township Board items
  are not completeable. Arrival interactions are doors, not prizes.
- **No progress indicators**: no counters, no completion percentage, no "X of Y" anywhere.
- **No tutorial integration**: none of these additions are explained. They are discovered.
- **No FOMO timer**: no time-limited DLC equivalent. All urgency is diegetic (within the world),
  not artificial (external deadline).
- **No day recap screen**: the Township Board describes current state, not past events.

---

## Integration with Existing Backend Systems

| Addition | Existing System It Uses | New Code Required |
|----------|------------------------|-------------------|
| Dawn Unlocks | `ThreadEntry` in thread_generator.py | Add `day_unlock: dict | None` field to ThreadEntry; engine surfaces it |
| Township Board | `SessionState` flags, NPC arc states | New rule-based pass: `generate_board_items(state, day)` — ≤ 20 lines |
| Character-Mediated Discovery | NPC Behavior Agent (knowledge_state, zone_significance) | Agent prompt update only; no backend change |
| Arrival Discovery | Arrival role assignment (`player_arrivals` table) | Add `discovery_action` field to arrival schema; one flag check in engine |

**Pillar Summary**:

| Pillar | Additions That Serve It |
|--------|------------------------|
| 1 — Earned Dread | Dawn Unlocks, Arrival Discovery |
| 2 — The Watched Feeling | Township Board, Character-Mediated Discovery, Arrival Discovery |
| 3 — Moral Weight at Every Turn | Dawn Unlocks, Township Board |
| 4 — Day/Night as Structural Argument | Dawn Unlocks (night consequences feed back into day options) |
| 5 — Genre Whitespace | Township Board (simulation + drama simultaneously), Character-Mediated Discovery |
