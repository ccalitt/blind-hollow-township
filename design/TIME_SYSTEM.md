# Time System — Day, Night & Season Cycle

> Status: IN PROGRESS (2026-04-26). Timer logic, seasonal structure, Godot implementation spec.
> Serves PILLARS.md. Pending review before freeze.

---

## Design Mandate

Time is not a neutral clock. It is a moral instrument.

The Game of Thrones seasonal model is the direct inspiration: seasons in that world are not calendrical — they arrive when the world is ready, they last as long as the world demands, and their arrival is always a threat regardless of what the characters are doing. "Winter is coming" is not a forecast. It is a warning that the debt the living carry will eventually be collected.

In Hollow Township: seasons are not weather. They are THE DEBT's tempo. A long summer means more time to build, more choices to accumulate, more moral weight to carry before the reckoning. A short summer means the reckoning comes before the player is ready. The player cannot control which they get. They can only control what they build before it ends.

---

## The Three-Phase Day Cycle

Each in-game day has three phases with fixed real-time durations. The player cannot accelerate or pause the clock.

```
DAY PHASE     — 18 in-game hours — 25 real minutes
  Relief. Build. Manage. Negotiate. The world is visible.
  Creatures are not present. NPCs are accessible.
  Clock is visible to the player (sun position, ambient light).

DUSK WINDOW   — 2 in-game hours — 3 real minutes
  The transition. Night watch roster opens automatically.
  Player must confirm all NPC assignments before this window closes.
  If player does not confirm: assignments lock at whatever state they are in.
  The game does not warn twice. Dusk is not patient.

NIGHT PHASE   — 10 in-game hours — 15 real minutes
  Unease. THE DEBT arrives. Player observes only.
  Pre-computed event queue fires over WebSocket.
  Camera is player's only freedom.
  Creatures active per their behavioral rules.
  Dawn fires automatically when the 10 hours complete.

DAWN PHASE    — 2 in-game hours — 2 real minutes
  Compulsion. Survey what changed.
  Dawn consequence thread fires (REVEAL_MECHANIC.md model).
  NPC arc states updated and visible.
  Player input accepted after the first 60 seconds (consequence thread delivery).
  Then: Day Phase begins again.
```

**Total cycle**: 32 in-game hours → 45 real minutes per day/night cycle.
**Chapter 1**: 5 full cycles → ~3h 45min base clock time. With faction negotiation, mid-choice interaction pauses, and NPC context panel time, total playtime lands in the 4–5 hour target. The 5-day structure was established in the 2026-04-26 revision of CHAPTER_ONE.md. Do not use a 3-cycle figure here — it refers to the deprecated 3-day structure.

---

## The Clock — Godot Implementation

### Core Timer Node Structure

```
World (Node3D)
└── TimeManager (Node — Autoload singleton)
    ├── DayCycleTimer (Timer)
    ├── PhaseStateMachine (Node)
    └── SeasonManager (Node)
```

`TimeManager` is an Autoload singleton. All other systems (creature spawning, UI, lighting, NPC behavior triggers, backend calls) subscribe to its signals. Nothing else manages time.

### Time Constants

```gdscript
# TimeManager.gd

const REAL_SECONDS_PER_INGAME_HOUR := 83.33  # 1 in-game hour = ~83 real seconds
                                               # 24 in-game hours = 2000 real seconds = ~33 min
                                               # Adjusted per phase (see phase durations)

# Phase durations in real seconds
const PHASE_DURATIONS := {
    Phase.DAY:   1500.0,   # 25 min real
    Phase.DUSK:   180.0,   # 3 min real
    Phase.NIGHT:  900.0,   # 15 min real
    Phase.DAWN:   120.0,   # 2 min real
}

enum Phase { DAY, DUSK, NIGHT, DAWN }
enum Season { LATE_SUMMER, TURNING, DEEP_WINTER, THAW }
```

### Phase State Machine

```gdscript
# TimeManager.gd (continued)

signal phase_changed(new_phase: Phase)
signal hour_ticked(current_hour: int, current_phase: Phase)
signal night_roster_lock_warning()   # fires 60s before dusk closes
signal dawn_consequence_ready()      # fires after 60s of dawn (consequence thread complete)
signal season_changed(new_season: Season, severity: float)
signal debt_tempo_shifted(new_multiplier: float)

var current_phase: Phase = Phase.DAY
var current_day: int = 1
var current_season: Season = Season.LATE_SUMMER
var debt_tempo: float = 1.0          # season severity multiplier: 0.7 (mild) to 1.5 (brutal)
var elapsed_in_phase: float = 0.0

func _process(delta: float) -> void:
    elapsed_in_phase += delta * debt_tempo   # season severity accelerates or slows the clock
    _tick_hour()
    if elapsed_in_phase >= PHASE_DURATIONS[current_phase]:
        _advance_phase()

func _advance_phase() -> void:
    elapsed_in_phase = 0.0
    match current_phase:
        Phase.DAY:
            current_phase = Phase.DUSK
            _on_dusk_begin()
        Phase.DUSK:
            current_phase = Phase.NIGHT
            _on_night_begin()
        Phase.NIGHT:
            current_phase = Phase.DAWN
            _on_dawn_begin()
        Phase.DAWN:
            current_phase = Phase.DAY
            current_day += 1
            _on_day_begin()
    phase_changed.emit(current_phase)
```

### Phase Transition Handlers

```gdscript
func _on_dusk_begin() -> void:
    # Opens night watch roster UI
    # Signals GRAPHICS system to begin day→night visual transition
    # Calls POST /transition/night to backend (starts pre-computation)
    NightRosterUI.open()
    VisualTransitionSystem.begin_dusk()
    BackendBridge.post_transition_night(GameState.get_day_summary())

func _on_night_begin() -> void:
    # Locks all NPC assignments
    # Closes night watch roster (no further changes accepted)
    # Signals creature system to begin
    # Suspends player input except camera
    NightRosterUI.lock_and_close()
    CreatureSystem.begin_night(current_day, GameState.get_debt_level())
    InputManager.set_mode(InputManager.Mode.OBSERVE_ONLY)

func _on_dawn_begin() -> void:
    # Creatures stop (freeze in place)
    # Visual transition to dawn
    # Backend: POST /dawn { player_id, night_summary }
    # Dawn consequence thread fires after 60s
    CreatureSystem.end_night()
    VisualTransitionSystem.begin_dawn()
    BackendBridge.post_dawn(GameState.get_night_summary())
    await get_tree().create_timer(60.0).timeout
    dawn_consequence_ready.emit()
    InputManager.set_mode(InputManager.Mode.FULL)

func _on_day_begin() -> void:
    # Re-enables full player input
    # Checks for NPC inflow (WORLD_BACKSTORY.md arrival mechanic)
    # Signals SeasonManager to evaluate season state
    VisualTransitionSystem.begin_day()
    NPCInflowSystem.evaluate_arrival(current_day, GameState.get_debt_level())
    SeasonManager.evaluate_season(current_day, GameState.get_debt_level())
```

### Hour Ticking

```gdscript
var _last_emitted_hour: int = -1

func _tick_hour() -> void:
    # Convert elapsed real seconds within phase to in-game hours
    var phase_progress := elapsed_in_phase / PHASE_DURATIONS[current_phase]
    var phase_hours := _phase_ingame_hours(current_phase)
    var current_ingame_hour := int(phase_progress * phase_hours)
    if current_ingame_hour != _last_emitted_hour:
        _last_emitted_hour = current_ingame_hour
        hour_ticked.emit(current_ingame_hour, current_phase)

func _phase_ingame_hours(phase: Phase) -> int:
    match phase:
        Phase.DAY:   return 18
        Phase.DUSK:  return 2
        Phase.NIGHT: return 10
        Phase.DAWN:  return 2
    return 0
```

---

## The Seasonal System — Game of Thrones Model

### Design Principle

Seasons in Hollow Township do not follow a calendar. They follow THE DEBT.

In Game of Thrones, seasons are decoupled from astronomical time — summer and winter last as long as the world demands, arriving without fixed schedule, departing without warning. The horror of "winter is coming" is not that winter is approaching. It is that it has been summer for a long time, and the longer it lasts, the worse the winter will be. The debt of summer is paid in winter. The debt of good years is paid in bad ones.

In Hollow Township: a long summer means more time to build and more choices to accumulate. More moral debt. When the Turning begins, THE DEBT's tempo accelerates — night comes faster, creatures are more numerous, the consequences of choices compound faster. Deep Winter is the reckoning for everything the player built during summer.

The player cannot choose when seasons change. They can influence it: high DEBT levels accelerate the Turning. Transparency choices (reporting discrepancies, refusing the Compact's surplus) slow it. The trap has its own seasons and the player's choices feed them.

### The Four Seasons

These are not weather states. They are THE DEBT's operational modes.

```
LATE SUMMER        — The world before the reckoning
  Debt tempo:      0.8× (clock runs slower — more time to act)
  Night duration:  shortened by 15% (900s → 765s real)
  Creature count:  base (as derived from player choices)
  NPC inflow rate: low (one arrival per 6 in-game days)
  Visual:          warm desaturation, long shadows, amber fog at treeline
  Tone signal:     the last good days before something that has already started

TURNING            — The debt begins to move
  Debt tempo:      1.0× (baseline clock)
  Night duration:  standard (900s real)
  Creature count:  +1 additional Walker per active DEBT source
  NPC inflow rate: medium (one arrival per 4 in-game days)
  Visual:          color temperature drops, fog thickens, treeline advances 3 yards
  Tone signal:     the moment you realize you were not in late summer but in the last of it

DEEP WINTER        — The reckoning
  Debt tempo:      1.3× (clock accelerates — less time to act, faster consequences)
  Night duration:  extended by 25% (900s → 1125s real — 18.75 min)
  Creature count:  +2 per active DEBT source; Walkers move 2 zones per hour
  NPC inflow rate: high (one arrival per 2 in-game days — the trap is hungry)
  Visual:          near-monochrome, deep fog, point lights only from player torches
  Tone signal:     you are paying for everything now

THAW               — The accounting completes (Chapter 2 transition)
  Debt tempo:      0.9× (slightly slower — the world is exhausted)
  Night duration:  slightly shortened (900s → 810s real)
  Creature count:  reduced — but Surveyor's Shadow may linger from Chapter 1
  NPC inflow rate: lowest (one arrival per 8 in-game days)
  Visual:          dawn palette, flat light, damage visible in clear morning
  Tone signal:     the false dawn — the one thing that survived
```

### Season Transition Logic

Seasons do not transition on a fixed day counter. They transition when a threshold of DEBT + time is crossed.

```gdscript
# SeasonManager.gd

const SEASON_THRESHOLDS := {
    # [min_day, min_debt_level] to transition INTO this season
    # Thresholds shifted for 5-day Chapter 1 arc
    Season.TURNING:     { "day": 4,  "debt": 0.4 },   # reachable Day 4 at moderate DEBT
    Season.DEEP_WINTER: { "day": 5,  "debt": 0.70 },  # reachable Night 5 only at high DEBT
    Season.THAW:        { "day": 6,  "debt": -1.0 },  # Thaw triggers at Chapter end, not debt
}

func evaluate_season(current_day: int, debt_level: float) -> void:
    var target_season := _compute_target_season(current_day, debt_level)
    if target_season != TimeManager.current_season:
        _transition_to(target_season, debt_level)

func _compute_target_season(day: int, debt: float) -> Season:
    # Thaw is Chapter-end triggered, handled separately
    if day >= SEASON_THRESHOLDS[Season.DEEP_WINTER].day \
       and debt >= SEASON_THRESHOLDS[Season.DEEP_WINTER].debt:
        return Season.DEEP_WINTER
    if day >= SEASON_THRESHOLDS[Season.TURNING].day \
       and debt >= SEASON_THRESHOLDS[Season.TURNING].debt:
        return Season.TURNING
    return Season.LATE_SUMMER

func _transition_to(new_season: Season, debt_level: float) -> void:
    TimeManager.current_season = new_season
    var severity := _compute_severity(new_season, debt_level)
    TimeManager.debt_tempo = _season_tempo(new_season, severity)
    TimeManager.season_changed.emit(new_season, severity)
    VisualTransitionSystem.begin_season_shift(new_season, severity)

func _season_tempo(season: Season, severity: float) -> float:
    # severity is 0.0–1.0, scales the tempo within season's range
    match season:
        Season.LATE_SUMMER:   return lerp(0.75, 0.85, severity)
        Season.TURNING:       return lerp(0.95, 1.05, severity)
        Season.DEEP_WINTER:   return lerp(1.2,  1.4,  severity)
        Season.THAW:          return lerp(0.85, 0.95, severity)
    return 1.0

func _compute_severity(season: Season, debt_level: float) -> float:
    # Higher debt = higher severity within the season
    # Severity 0.0 = mild (player made good choices), 1.0 = brutal
    return clampf(debt_level / 1.0, 0.0, 1.0)
```

### DEBT Level — The Season Driver

THE DEBT level is a float 0.0–1.0 computed from the player's choice log at each day start.

```gdscript
# GameState.gd

func get_debt_level() -> float:
    # Queries DynamoDB choice log via backend at day transition
    # Returns normalized value:
    #   0.0 = full transparency (reported everything, refused Compact)
    #   1.0 = maximum compounding (covered everything, accepted all surplus)
    # Cached locally; refreshed at each day_begin
    return _cached_debt_level

# Backend computes debt from:
# +0.15 per covered ledger discrepancy (compounding)
# +0.20 per Compact surplus accepted
# +0.10 per building placed in Zone 5 adjacency
# -0.10 per disclosed discrepancy (reported to Association)
# -0.05 per Dix inspection approved
# Clamped 0.0–1.0
```

---

## Season Visual Integration — GRAPHICS.md Extension

The seasonal system drives all visual state changes via `VisualTransitionSystem`. These are additional parameters on top of the day/night cycle visual model already defined in GRAPHICS.md.

```gdscript
# VisualTransitionSystem.gd

func begin_season_shift(season: Season, severity: float) -> void:
    var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    var duration := 120.0  # season transitions over 2 real minutes (between days)

    match season:
        Season.TURNING:
            # Fog thickens at treeline; color temp drops 200K; desaturation increases
            tween.tween_property(env, "fog_density",
                lerp(0.02, 0.06, severity), duration)
            tween.tween_property(sky_light, "light_color",
                Color(lerp(0.91, 0.82, severity), lerp(0.78, 0.70, severity), lerp(0.60, 0.52, severity)),
                duration)

        Season.DEEP_WINTER:
            # Near-monochrome; fog dense; shadows sharp and cold
            tween.tween_property(env, "fog_density",
                lerp(0.08, 0.14, severity), duration)
            tween.tween_property(world_env, "adjustment_saturation",
                lerp(0.5, 0.25, severity), duration)
            tween.tween_property(sky_light, "light_color",
                Color(0.55, 0.60, 0.75), duration)  # cold blue

        Season.THAW:
            # Flat morning light; fog thin but gray; damage visible
            tween.tween_property(env, "fog_density", 0.03, duration)
            tween.tween_property(world_env, "adjustment_saturation", 0.45, duration)
```

**Season visual signatures**:

| Season | Fog density | Saturation | Light color | Treeline |
|--------|------------|-----------|------------|---------|
| Late Summer | 0.02–0.04 | 0.65–0.80 | Amber (#e8c89a) | Stable |
| Turning | 0.04–0.08 | 0.50–0.65 | Cooling (#d4c090→#c0b080) | Advances 3 yards |
| Deep Winter | 0.08–0.15 | 0.25–0.50 | Cold blue (#8090b0) | At settlement edge |
| Thaw | 0.02–0.04 | 0.40–0.50 | Flat gray (#c0c0c0) | Holds, visible damage |

---

## Chapter 1 Season Map

Chapter 1 spans 3 in-game days. Season transitions depend on player DEBT level. The range below shows fastest vs. slowest transition paths.

```
                    DAY 1        DAY 2        DAY 3        DAY 4        DAY 5
                    ──────────────────────────────────────────────────────────────
Low DEBT path:      LATE SUM     LATE SUM     LATE SUM     TURNING      TURNING
                    (player transparent, refused Compact, approved Dix)
                    Night 5 in Turning — Surveyor departs. Zone 5 stays closed.

Mid DEBT path:      LATE SUM     LATE SUM     LATE SUM     TURNING      TURNING
                    Night 4 Surveyor pre-appearance at standard duration.
                    Night 5 Surveyor marks — player compounded on 2–3 choices.

High DEBT path:     LATE SUM     LATE SUM     TURNING      TURNING      DEEP WINTER
                    (covered discrepancies, accepted surplus)
                    Night 5 in Deep Winter: 25% longer, +2 Walkers per source.
                    Surveyor marks decisively. Zone 5 fully open in Chapter 2.

Maximum DEBT path:  LATE SUM     TURNING      TURNING      DEEP WINTER  DEEP WINTER
                    (maximally complicit from Day 1)
                    Night 4 Surveyor pauses at Zone 5 boundary — visible signal.
                    Night 5: longest night, accelerated clock, Surveyor marks.
                    Chapter 1 end state: severe. Chapter 2 inherits DEBT 0.9+.
```

The player is not told which season they are in. They observe: the fog, the light, the treeline. The clock is not labeled "DEEP WINTER." The world just gets darker and the nights get longer and the time to act gets shorter. The player who pays attention will recognize the pattern. The player who doesn't will experience Night 3 as a consequence they did not see coming.

This is Earned Dread at the temporal scale.

---

## Extended Season Detail — The Full Year Across Chapters

Chapter 1 covers Late Summer through the beginning of Thaw — a single compressed season arc. Across the full game (Chapters 1–4+), the seasonal cycle completes once per chapter cluster and resets at a higher baseline. Each chapter inherits the severity of the previous chapter's end state.

### The GoT Parallel — Why Seasons Are Unpredictable in Length

In Game of Thrones, the maesters track season length but cannot predict it. Characters live with the anxiety of not knowing how long summer will last or how bad winter will be. The dread is structural: *you are always in debt to the next season.*

In Hollow Township, the same structure applies across chapters. Chapter 1 always begins in Late Summer. Whether it ends in Turning or Deep Winter depends entirely on the player. Chapter 2 begins in whatever state Chapter 1 ended — if Chapter 1 reached Deep Winter, Chapter 2 begins in Thaw. If Chapter 1 stayed in Turning, Chapter 2 begins in a mild Late Summer of its own, but the DEBT baseline carries forward — the minimum starting debt in Chapter 2 is 0.2 higher than where Chapter 1 ended.

**The debt of summer is paid in winter. The debt of winter is paid in the next summer, compounded.**

### Season Severity Inheritance

```
Chapter end DEBT level → Chapter 2 starting DEBT floor

Chapter 1 ends at DEBT 0.3 (transparent player):
    → Chapter 2 starts at DEBT 0.3 + 0.2 carry = 0.5 floor
    → Chapter 2 begins in mild Late Summer
    → Turning arrives faster than Chapter 1 because the floor is higher

Chapter 1 ends at DEBT 0.7 (complicit player):
    → Chapter 2 starts at DEBT 0.7 + 0.2 carry = 0.9 floor
    → Chapter 2 begins in Thaw (the false dawn)
    → Deep Winter arrives within first 2 in-game days of Chapter 2
    → The false dawn anchor (CONCEPT.md) survives into what is almost immediately winter
```

No player arrives at Chapter 2 in Late Summer with a clean slate. The carry mechanic ensures the accumulation is real across chapters, not reset at chapter boundaries.

### Season-Specific World Events (Beyond Creature Modifiers)

Each season carries world events that are not creature-based — environmental changes that manifest THE DEBT through the world's physical state rather than through nighttime threats.

**Late Summer world events** (one per 2 in-game days, background):
- The mill produces slightly more than the ledger shows. The surplus is real. Its origin is the hollow. Maren flags it or she doesn't.
- A section of the eastern ridge treeline is notably quieter than surrounding areas. Elias notices. He has been noticing it for weeks.
- The incomplete structure's wood has a faint smell that Peder identifies and does not name aloud.
- A new arrival's former-life objects interact unexpectedly with a Harrow's Crossing object — two things from different worlds that should not match, that match.

**Turning world events** (one per in-game day, visible):
- The fog at the western tree line persists two hours past dawn on one morning. It is not fog.
- A building placed adjacent to Zone 5 develops a hairline crack in its foundation overnight. Peder inspects it. His behavioral state line changes.
- Two NPCs independently report dreaming about roads they cannot identify. They do not know the other reported this. The player is told both, separately, on the same day.
- Constance Harrow is found at the Zone 3/5 boundary at dawn, facing the hollow. She says she was walking. Her voice register is different for the remainder of that day.

**Deep Winter world events** (concurrent with every night, visible at dawn):
- The treeline is measurably closer each morning. Not dramatically — 2–4 yards per day. The player can observe this through the camera. Nothing in the UI quantifies it.
- Tools left outside overnight are found in slightly different positions in the morning. Consistently. The positions are not random — they form a pattern over multiple days that Elias recognizes as a surveying grid.
- New arrivals in Deep Winter occasionally know the name "Harrow's Crossing" before they are told it. They are not sure why. The township does not advertise its name.
- The ledger develops new entries in handwriting that is not Maren's and not the player character's. The entries are accurate. They describe resource movements that have not yet happened.

**Thaw world events** (Chapter transition, one sequence):
- The morning after Night 3, one object belonging to a dead or broken NPC is found in a place that should be inaccessible — inside a locked building, on a post that was unoccupied during the night. It is placed deliberately. Not dropped.
- The treeline has not advanced further. For the first time in days, it has held. This is not relief. It is a held breath.
- The Surveyor's Shadow's footprints (if it marked Zone 5) are visible at dawn in the mud at the Zone 3/5 boundary. They lead into the hollow and do not come back out. They are fresh.

### Season Signal Hierarchy — What the Player Reads

The player learns the seasons through observation, not through a UI label. The signal hierarchy is:

```
Most subtle (Late Summer):
    Light quality — amber, slightly wrong for the time of year
    NPC behavioral state lines — "more careful than the day requires"
    Mill output — slightly over what the ledger shows

Becoming visible (Turning):
    Fog behavior — persists past dawn on specific mornings
    Treeline — measurably but not dramatically closer
    NPC behavioral convergence — two NPCs notice the same thing independently

Undeniable (Deep Winter):
    Treeline — visibly at settlement edge, camera can see it without zooming
    Ledger — entries the player did not make
    Night duration — player feels the extra real minutes of darkness
    New arrivals — know the name before being told

Aftermath (Thaw):
    The held treeline
    The footprints
    The one thing that survived
    The flat light that makes everything visible and nothing beautiful
```

### Season and Productivity Interaction

Season affects not just threat level but also what productivity gains are available. The silver lining scales with the threat (NPC_INFLOW_PRODUCTIVITY.md), and building output is also season-modulated:

| Season | Building output modifier | Reason |
|--------|------------------------|--------|
| Late Summer | 1.0× (baseline) | The world is not yet fighting back |
| Turning | 0.9× | Equipment behaves slightly wrong; workers distracted |
| Deep Winter | 0.75× | Cold (narratively), equipment failure from Watcher activity, shorter effective day |
| Thaw | 1.1× | Brief window — the world is exhausted, not hostile. Workers know it won't last. |

Thaw's 1.1× bonus is the game's most direct acknowledgment that the player gets a reward. It is brief. Chapter 2 inherits the DEBT floor that ends it. The player knows this, or they will.

### Real-Time Season Duration Reference (Chapter 1)

Based on the 45-minute day cycle and DEBT-driven tempo:

```
Scenario                   Day 1    Day 2    Day 3    Total real time
─────────────────────────────────────────────────────────────────────
Transparent (DEBT 0.2):    45 min   45 min   45 min   ~2h 15m
                           (0.8×)   (0.8×)   (1.0×)   (Late Summer → Turning)

Mid DEBT (0.5):            45 min   42 min   38 min   ~2h 05m
                           (0.8×)   (1.0×)   (1.3×)   (Summer → Turning → Winter)
                           Note: Deep Winter's accelerated clock shortens
                           the DAY phase but EXTENDS the NIGHT phase.
                           Night 3 = 18.75 real minutes of observation.

Max DEBT (0.9+):           45 min   38 min   35 min   ~1h 58m
                           (0.8×)   (1.3×)   (1.4×)   Day time collapses; night expands.
                           Night 2 = 18.75 min. Night 3 = 21 min (1.4× modifier).
                           Player has the least time to act and the most night to survive.
```

The maximum DEBT path produces the shortest day phases and the longest nights. This is the correct outcome: a player who compounded every choice has the least time to build anything and the most darkness to survive.

---

## Backend Integration

Season state and DEBT level are tracked backend-side and pushed to Godot on each day transition.

```
POST /transition/day  (fired at start of each Day phase)
  ← { debt_level: float, season: string, debt_tempo: float, 
      night_duration_seconds: float, creature_modifiers: {...} }

Godot: TimeManager and SeasonManager consume this response.
       All timer durations update for the incoming cycle.
       Visual transition begins immediately.
```

Night duration is computed server-side from season + debt, sent to Godot, and used as the `PHASE_DURATIONS[Phase.NIGHT]` for that cycle. The client does not compute this — the server controls how long the night lasts.

---

## NPC Inflow Timer Integration

Arrival rate is season-modulated and DEBT-influenced. Full mechanic specification in `NPC_INFLOW_PRODUCTIVITY.md`. This section owns the timer integration.

### Season-Modulated Arrival Quality Table

| Season | Arrival frequency | Skill depth distribution | Special condition |
|--------|-----------------|------------------------|-------------------|
| Late Summer | 1 per 6 days | 70% Surface, 28% Practiced, 2% Deep | Arrivals have full settling time available |
| Turning | 1 per 4 days | 60% Surface, 35% Practiced, 5% Deep | One Practiced arrival guaranteed before first winter night |
| Deep Winter | 1 per 2 days | 45% Surface, 40% Practiced, 15% Deep | Deep arrivals possible; arrive mid-urgency (Path C pressure) |
| Thaw | 1 per 8 days | 55% Surface, 40% Practiced, 5% Deep | Arrivals are calmer — settling curve shortened by 1 phase |

The silver lining scales with the threat: Deep Winter arrivals are more skilled but arrive when the player has the least time to integrate them. The Day 3 guaranteed arrival (see below) always arrives with 3 real minutes of dusk window remaining — the final integration vs. deployment choice of Chapter 1.

### Chapter 1 Guaranteed Arrival Sequence

Independent of season, Chapter 1 delivers four specific arrivals across Days 2–5 (Day 1 has no arrival — the player learns the original six NPCs first). This is the authoritative sequence. The NPC_INFLOW_PRODUCTIVITY.md specification matches this.

| Day | Arrival type | Design intent |
|-----|-------------|---------------|
| Day 2 | One Surface arrival, any domain | Establishes the mechanic at low stakes |
| Day 3 | One Practiced arrival in the domain the player has neglected most | The world fills the gap the player left |
| Day 4 | One Practiced arrival whose domain matches Night 4's most urgent defense gap | Computed from threat state, not domain absence — forces a triage choice |
| Day 5 | One arrival at highest available depth, domain matched to Night 5's most urgent need | Arrives at dusk minus 3 minutes. Path A is impossible. The game's last decision is also its most human. |

The Day 5 arrival is the clearest silver lining in Chapter 1: the worst night brings the most capable help. But integration is impossible in 3 minutes. Path C (immediate deployment, arc damage) is the only efficient option. The game does not label this.

```gdscript
# NPCInflowSystem.gd

const BASE_ARRIVAL_INTERVAL_DAYS := {
    Season.LATE_SUMMER:  6,
    Season.TURNING:      4,
    Season.DEEP_WINTER:  2,
    Season.THAW:         8,
}

# Skill depth weights per season [surface, practiced, deep]
const SKILL_DEPTH_WEIGHTS := {
    Season.LATE_SUMMER:  [0.70, 0.28, 0.02],
    Season.TURNING:      [0.60, 0.35, 0.05],
    Season.DEEP_WINTER:  [0.45, 0.40, 0.15],
    Season.THAW:         [0.55, 0.40, 0.05],
}

# Chapter 1 guaranteed sequence (overrides random arrival on days 2-5; Day 1 has no arrival)
const CHAPTER_1_GUARANTEED := {
    2: { "depth": "surface",   "domain": "any",       "special": false },
    3: { "depth": "practiced", "domain": "neglected",  "special": false },  # domain resolved at runtime
    4: { "depth": "practiced", "domain": "urgent",     "special": false },  # urgent = highest threat gap
    5: { "depth": "any",       "domain": "urgent",     "special": true },   # arrives at dusk -3min
}

func evaluate_arrival(current_day: int, debt_level: float) -> void:
    # Chapter 1 guaranteed sequence takes priority over interval logic
    if GameState.current_chapter == 1 and CHAPTER_1_GUARANTEED.has(current_day):
        _trigger_guaranteed_arrival(current_day)
        return

    var interval := BASE_ARRIVAL_INTERVAL_DAYS[TimeManager.current_season]
    # High debt shortens interval further (trap is hungry)
    interval = max(1, interval - int(debt_level * 2.0))
    if current_day % interval == 0:
        _trigger_arrival()

func _trigger_guaranteed_arrival(day: int) -> void:
    var spec := CHAPTER_1_GUARANTEED[day]
    var domain := _resolve_domain(spec.domain)   # "neglected" = domain player has least coverage
    var depth := _pick_depth(spec.depth, TimeManager.current_season)
    var archetype := _pick_archetype()
    var arrival := ArrivalEvent.new(archetype, domain, depth)
    if spec.special:
        # Day 3: schedule arrival at dusk -3min (TimeManager.get_dusk_time() - 180s)
        arrival.schedule_at(TimeManager.get_dusk_time() - 180.0)
    else:
        arrival.dispatch()

func _trigger_arrival() -> void:
    var season := TimeManager.current_season
    var weights := SKILL_DEPTH_WEIGHTS[season]
    var depth := _weighted_pick(["surface", "practiced", "deep"], weights)
    var domain := _pick_domain()
    var archetype := _pick_archetype()
    ArrivalEvent.new(archetype, domain, depth).dispatch()
```

---

## The Clock the Player Sees

The player never sees a real-time clock or a minute counter. They see:

- **Sun/moon position**: arc across the sky indicates phase and progress within it. Day phase sun moves from east toward west. Night phase moon rises and tracks. No numbers.
- **Light temperature**: shifts continuously through the day/night cycle (GRAPHICS.md lighting model, extended by season shifts above).
- **The treeline**: in Turning and Deep Winter, it is visibly closer. The player notices or they don't.
- **The night watch roster warning**: a single visual cue (fire light dims, ambient sound shifts) at 60 seconds before dusk locks. One signal. No countdown timer on screen.
- **NPC behavior**: NPCs in later seasons move differently — shorter routes, more time indoors, behavioral state lines reflect the season without naming it.

The player knows it is getting late because the world tells them, not because a UI element tells them.

---

## Pillar Compliance

| Pillar | Timer system contribution |
|--------|--------------------------|
| Pillar 1 — Earned Dread | Season severity is determined by player DEBT level. A player who compounds choices enters Deep Winter faster. The acceleration of time is a consequence of their choices. |
| Pillar 2 — The Watched Feeling | The treeline advancing. Nights growing longer. These are the world's visible response to what the player built. The season watches the player back. |
| Pillar 3 — Moral Weight | The clock accelerating in Deep Winter means fewer decisions before the next night. Every choice costs more when time is shorter. The timer makes moral weight physically scarce. |
| Pillar 4 — Day/Night Structure | The three-phase cycle (Day/Dusk/Night/Dawn) is the mechanical implementation of RELIEF→UNEASE→COMPULSION. The timer is the engine of the loop. |
| Pillar 5 — Genre Whitespace | No other game uses a morally-driven seasonal clock where the player's ethical choices determine how long they have before the worst night arrives. This is the genre whitespace, implemented as a timer. |
