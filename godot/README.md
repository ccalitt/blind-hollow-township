# Hollow Township — Godot Vertical Slice (Chapter 1: Day 1 → Night 1 → Dawn)

A playable, offline vertical slice of the core **Day → Night → Dawn** loop for *Hollow
Township*, built strictly from the frozen design docs in `../design/`. The simulation
layer (logistics) is the gameplay surface; the horror is the consequence layer that
surfaces at night, traceable to what the player did during the day.

> Working title, frozen concept: **Earned Dread** — *every right choice arrives already compromised.*

---

## How to open / run

1. Install **Godot 4.3 or newer** (standard build; no C#/.NET needed).
2. Open the Godot project manager → **Import** → select `godot/project.godot`.
3. Let the editor finish its first import (it will generate `.godot/` and `*.import`).
4. Press **Play** (F5). The main scene is `scenes/Main.tscn`.

### Controls (input map in `project.godot`)

| Action | Key / Mouse |
|--------|-------------|
| Pan camera | WASD / Arrow keys |
| Rotate camera (Y) | Q / E |
| Zoom | Mouse wheel, or `=` / `-` |
| Select / place | Left mouse |
| Cancel placement / close panel | Right mouse / Esc |
| Build menu | B (or the on-screen **Build** button) |
| Pause | P or Space |
| **Debug: skip current phase** | **F1** |

The real per-phase durations (TIME_SYSTEM.md: 25/3/15/2 real minutes) are far too long
to inspect, so the slice runs a **~20× compressed clock** (`TimeManager.SLICE_DURATIONS`).
The full-spec values are kept in `TimeManager.SPEC_DURATIONS`. Use **F1** to jump to the
next phase instantly while testing the loop.

### A typical Day 1 playthrough

1. **Day** (the world is warm, falsely safe): click NPCs to open their context panel
   (right side) and assign them to a zone via the plain text list. Click **Peder** to give
   his crew the first order (fourth wall / mill reinforcement / hollow survey). Click the
   faction representatives standing in the Settlement Common (Compact / Association / Dix)
   for their text-list choices. Press **B** to place a building (try one near the Incomplete
   Structure — it faces the hollow). Every action logs silently into the choice log.
2. **Dusk**: a single cue ("the fire dims") — assignments freeze into the night roster.
3. **Night** (saturation drops, fog rises): you can only pan/zoom. Authored night events
   fire in the bottom-left log — each one traceable to a Day choice. Pausing (P) freezes
   the world but does **not** make it safe and does **not** undo what you've seen (Gap 5).
4. **Dawn**: the **consequence thread** prints — one to two declarative sentences per
   consequenced NPC, naming the Day choice and the Night outcome, no evaluation. A quiet
   night prints nothing but the silence (the absence is information).

---

## Architecture

```
godot/
├── project.godot               # 4.3 config, main scene, input map
├── icon.svg                    # placeholder icon
├── data/
│   └── night_events.json       # AUTHORED FALLBACK NIGHT-EVENT LIBRARY (Gap 8) — the offline
│                               #   stand-in for the LLM Horror Agent
├── scenes/
│   ├── Main.tscn               # root: Township + GameDirector + GameUI
│   ├── Township.tscn           # map: zones, ground, CameraRig, WorldLighting
│   └── NPC.tscn                # one billboard NPC (script-built visuals)
├── scripts/
│   ├── Main.gd                 # bootstraps the world, prints opening scene, starts the clock
│   ├── autoload/
│   │   ├── EventBus.gd         # global signals (npc_selected, choice_made, phase_changed,
│   │   │                       #   night_event_fired, dawn_thread_ready, pause_toggled, …)
│   │   ├── GameState.gd        # SessionState equivalent: day/phase, DEBT, 6 NPCs + arcs,
│   │   │                       #   3 factions + memory, 5 zones, choice log
│   │   └── TimeManager.gd      # Day→Dusk→Night→Dawn clock; pausable night (Gap 5); seasons
│   ├── systems/                # GDScript ports of the rule-based backend passes (NOT the LLM)
│   │   ├── GossipPass.gd       # port of backend/gossip/propagation.py
│   │   ├── SignificancePass.gd # port of backend/significance/pass_.py
│   │   ├── ConsequenceThread.gd# port of backend/consequence/thread_generator.py
│   │   ├── NightDirector.gd    # selects authored events traceable to Day choices (Gap 8 stub)
│   │   └── GameDirector.gd     # port of backend/engine.py SessionEngine (pass ordering)
│   ├── world/
│   │   ├── Township.gd         # zone layout, NPC spawning, grid-snap building placement
│   │   ├── NPC.gd              # billboard Sprite3D, 4 emotional states, click→panel
│   │   ├── CameraRig.gd        # elevated 35–45° rig, pan/zoom/rotate (GRAPHICS.md)
│   │   ├── WorldLighting.gd    # day/night WorldEnvironment + sun transition
│   │   └── Placeholder.gd      # generates colored placeholder textures in code (no art)
│   └── ui/
│       └── GameUI.gd           # build menu, NPC panel (task list), faction panel
│                               #   (text list), narrative log, dawn thread, pause marker
```

### The loop, wired end to end

`GameDirector` is the GDScript mirror of `backend/engine.py`'s `SessionEngine`. It drives
the same pass order off `TimeManager` phase signals:

```
DAY    player clicks → GameState.log_choice(...) appends a ChoiceEntry-shaped dict
                        (action_type, moral_tier, npc_ids, zone, debt_delta)
        ↓
NIGHT  GameDirector._run_night():
         [1] GossipPass.run_pass         — loads observations from the day's choices,
                                            propagates between NPCs (seeded, deterministic)
         [2] NightDirector.select_events — picks authored events whose trigger is satisfied
                                            by a Day choice / placed building / vacated post /
                                            gossip; each event carries a cause_chain
         → EventBus.night_event_fired per event → bottom-left log + NPC emotion/arc delta
        ↓
DAWN   GameDirector._run_dawn():
         [3] SignificancePass.run_dawn_pass     — per-NPC, per-zone event weight + modifiers
         [4] ConsequenceThread.generate_thread  — matches choices↔events, builds the 1–2
                                                   sentence threads (Reveal Test gates ported)
         [5] ConsequenceThread.compute_investment_anchor — False Dawn anchor for Chapter 2
         → TimeManager delivers EventBus.dawn_thread_ready after the consequence delay
```

**Causality is the contract.** A night event can *only* fire if its trigger is satisfied by
something the player did (Pillar 1 / Pillar 4: no horror disconnected from choice). A day with
no Debt-feeding choices produces a **quiet night** — no thread is manufactured (REVEAL_MECHANIC).

---

## What is real vs. what is an offline stub

| Piece | Status in this slice | Replaced by (ARCHITECTURE.md) |
|-------|----------------------|-------------------------------|
| Day→Night→Dawn clock, phases, pause | **Real** | — |
| Choice logging, DEBT accumulation, season eval | **Real** | (backend persists to DynamoDB) |
| Gossip / Significance / Consequence-thread logic | **Real** (faithful GDScript port of the Python passes) | These passes stay rule-based; they run server-side in prod |
| Night event *content* | **Authored stub** — `data/night_events.json` (Gap 8 fallback library) | The **LLM Horror / Creature Agent** generates events constrained by the day's choices |
| Dawn thread *prose* | **Authored templates** rendered from the structured payload | The **LLM Story Progression Agent** renders the two sentences; the **Master Enforcer** validates tone |
| Behavioral state lines | **Authored register** per NPC | The **LLM NPC Behavior Agent** reads arc + knowledge + significance |
| NPC sprites | **Code-generated colored placeholders** with 4 readable states | Hand-drawn billboard sprites (blocked on the Gap 9 readability prototype) |
| Backend transport | **None** (everything in-memory) | REST `/transition/*` + WebSocket night queue |

The rule passes are ported faithfully so that when the LLM agents are wired in, they slot into
the exact same pass boundaries (`GameDirector` ↔ `SessionEngine`).

---

## Pillar Compliance

| Pillar | Where it lives in this slice |
|--------|------------------------------|
| **1 — Earned Dread** | `NightDirector.gd` (events fire only when traceable to a choice; cause_chain on every event) + `ConsequenceThread.gd` (names the chain at dawn, the legibility surface from Gap 2) |
| **2 — The Watched Feeling** | `GossipPass.gd` (NPCs remember and pass what they know) + `SignificancePass.gd` (per-person, per-place accumulated memory) + `GameState` factions carry a memory list |
| **3 — Moral Weight at Every Turn** | `GameUI.gd` + `Township.gd`: logistics UI with no labels, no confirmation, no weight color-coding; assignment/placement quietly write the choice log. `INTERACTION_MODEL.md` followed literally |
| **4 — Day/Night as Structural Argument** | `TimeManager.gd` is the RELIEF→UNEASE→COMPULSION engine; `GameDirector.gd` makes Night a function of Day and Dawn a function of Night |
| **5 — Genre Whitespace** | The whole slice runs simulation (build/assign/factions) + horror (night events) + drama (named NPC arcs/registers) through one shared choice log — none subordinated to the others |

**NOT-THIS compliance:** no good/evil sliders, no karma meter, no day recap/summary screen
(the dawn thread *names* — it does not *evaluate*), no random night events, no survival meters,
no safe zones, no confirmation dialogs.

---

## Places the frozen docs were silent (and what I chose)

- **Slice clock speed.** TIME_SYSTEM.md fixes 45-real-minute cycles. Unplayable to inspect, so
  the slice compresses ~20× (`SLICE_DURATIONS`) while preserving the phase ratio; spec values
  kept in `SPEC_DURATIONS`. Documented above.
- **Building types / menu contents.** The docs specify the *interaction* (icon-and-name list,
  no stats) but never enumerate Day-1 buildings. I authored four neutral names
  (Watchtower, Secondary Processing Shed, Storehouse, Bunkhouse) — names only, per §2.
- **Spatial zone layout.** WORLD_STATE.md gives zone identities and a *moral* adjacency grammar
  but no coordinates. I placed Zone 4 (Incomplete Structure) and Zone 5 (Hollow) on the western
  side so that building toward the structure reads as building toward the hollow.
- **DEBT deltas in the offline slice.** The numeric model lives in TIME_SYSTEM.md (server-side in
  prod). I applied those same magnitudes locally (+0.10 hollow-adjacent build, +0.20 Compact
  surplus, −0.10 disclosure, −0.05 Dix approval) so seasons can actually shift.
- **Sprite art / Gap 9.** GRAPHICS.md sprite readability is an unresolved prototype gate. I used
  code-generated colored swatches with distinct per-state face marks as the placeholder; the
  four emotional states are the readability target, not finished art.
- **Faction representatives as world objects.** §4 says reps "appear as named NPCs in the Common."
  I spawn three dedicated `is_faction_rep` NPC click-targets (Compact Delegate, Association
  Representative, Field Agent Dix) rather than overloading the six named NPCs.
- **Event delivery pacing at night.** The slice emits the night queue near-immediately into the
  log; a fuller build would gate each event on an in-game hour tick. The causal content is real;
  only the *spacing* is simplified.
