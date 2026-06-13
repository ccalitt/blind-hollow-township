# Graphics & Visual System — Hollow Township

> Status: FROZEN (reviewed 2026-06-13), with ONE exception: the sprite-readability claim
> (see "Character Rendering" and "State-Driven Visual System") is NOT frozen until the
> CRITICAL_GAPS_PLAN.md Gap 9 prototype test passes. Everything else in this document is frozen.
> All decisions serve PILLARS.md. Pillar alignment tagged on every decision.

---

## ⚠ Prototype Gate — Sprite Readability (CRITICAL_GAPS_PLAN.md Gap 9 — UNRESOLVED)

The claim that 2D billboard NPC sprites at 8–12% screen height (96×128px) carry sufficient
emotional information to support Pillar 2 (The Watched Feeling) is the technical foundation of
this document — and it is **not validated**. Per CRITICAL_GAPS_PLAN.md Gap 9, this is a
**prototyping gate, not a documentation gap**. The following sections remain NOT frozen until
the Gap 9 validation test passes (recognition rate ≥ 80% across 4 emotional states at the
proposed camera distance/elevation):
- Character Rendering — PROPOSED (sprite size, billboard approach, directional angles)
- State-Driven Visual System — NPC Appearance (emotion readability via shader/layers)
- Surveyor's Shadow sprite size (96×128px) — inherits the same readability dependency

If the prototype fails, the fallback design in Gap 9 applies (larger sprites — 128×192 for
primary NPCs — or world-space state indicators). All other visual systems (perspective, color,
lighting, fog, creature design for Walkers/Watchers, transitions, UI) are frozen independent
of this gate.

---

## Pillar Compliance

Every visual decision is downstream of the frozen pillars. Major mechanics and the pillar(s) they satisfy:

- **Earned Dread** (Pillar 1) → horror is visible consequence, not atmosphere. Buildings change (pristine/damaged/corrupted), NPCs change, the world shows what the player built. Walkers read as "timber in a different position than it was" — quiet wrongness, not spectacle. No jump-scare visual language.
- **The Watched Feeling** (Pillar 2) → named NPCs must be emotionally readable at a glance (sprites over abstract 3D); the night-phase camera snap looks at what matters, not what the player wants to see. *(Readability dependent on Gap 9 prototype — see gate above.)*
- **Moral Weight at Every Turn** (Pillar 3) → logistics UI feels mechanical. No color coding of moral weight, no confirmation dialogs on micro choices, no post-choice summary. Art does not editorialize.
- **Day/Night as Structural Argument** (Pillar 4) → day and night look and feel architecturally different (palette, fog, lighting all shift); the 2.5s transition is narrative punctuation, not a cut. The no-pause rule is reframed per CRITICAL_GAPS_PLAN.md Gap 5 — pause is permitted but freezes the player inside what they built (see Night phase UI).
- **Genre Whitespace** (Pillar 5) → visual language sits at the intersection of horror + simulation + drama. Not cartoon. Not photo-real. Not gothic horror. Between Frostpunk's gray industry and Darkest Dungeon's high-contrast silhouettes.

**NOT-THIS compliance**: no moral-weight color coding (not a binary moral system), horror is consequence-visible not jump-scare, pause does not create a safe retreat (it forces the player to keep looking).

---

## Perspective Decision — PROPOSED

**Recommendation: TPS at 35–45° elevation, Y-axis rotatable, with town-survey mode.**

### Why Not Pure Top-Down

Top-down orthographic (classic isometric) maximizes tactical clarity but minimizes emotional connection. At pure top-down, NPCs are icons. At 35–45° elevation, they are people. Pillar 2 ("The Watched Feeling") requires that named NPCs' emotional states are visible. A building at top-down is a rectangle. At 40° elevation, it looms.

### Why Not Full TPS (Shoulder Cam)

Shoulder cam (Resident Evil 4 style) creates maximum horror intimacy but is wrong for township management. The player cannot manage a township from 1m behind a character. The simulation layer requires a view that encompasses multiple buildings and NPCs simultaneously.

### The Chosen Model

**35–45° elevated follow-cam, Y-axis freely rotatable, with zoom range 8–30 units.**

- Default view: township visible at 60–70% screen width. NPCs ~8–12% of screen height — readable, not dominant.
- Zoom in: individual NPC interaction, horror close-ups. Camera snaps toward threat during night-phase push events.
- Zoom out: full township survey. Used during dawn phase when player assesses night's cost.
- Y-axis rotation: player can rotate to inspect building placement. Never forced; always optional.

**Night phase camera behavior**: During pre-computed horror events, camera snap is scripted (not player-controlled) for the duration of the event text display. Player regains camera control at event end. This creates the "watched" sensation — the camera looks at what matters, not what the player wants to see.

```
Godot Node Setup:

World (Node3D)
├── Terrain (MeshInstance3D)
├── Buildings (Node3D)
│   └── Building_Watchtower (Node3D — mesh + Area3D collider + state machine)
├── NPCs (Node3D)
│   └── NPC_Sarah (CharacterBody3D — CharacterBody + VisualState component)
├── CameraRig (Node3D — follows player township centroid, not a character)
│   ├── Pivot (Node3D — Y-axis rotation)
│   │   └── Arm (Node3D — camera distance: 8–30 units, adjustable)
│   │       └── Camera3D (fov=70°, pitch locked 35–45°)
└── UI (CanvasLayer)
```

**Camera transitions between day and night**: smooth lerp over 2.5s. Camera pulls slightly outward (8→12 units) at night, increases pitch slightly (40°→45°), fog density rises. Not an abrupt cut — a slow withdrawal.

---

## Character Rendering — PROPOSED

**Recommendation: 3D world environment + 2D billboard NPC sprites (Sprite3D / AnimatedSprite3D).**

### Why Billboards Over Full 3D

Full 3D characters require rigging, skinning, and motion capture quality to convey emotional nuance at the scale these NPCs appear on screen. Hand-drawn 2D sprites carry more emotional information per pixel. An artist-drawn fear expression on a 96×128 sprite reads faster and cleaner than a 3D facial rig at the same display size.

This is the approach used by Darkest Dungeon (pure 2D), Hades (2D characters in 3D space), and Stoneshard. It is the correct call for:
- Pillar 2 (named NPCs must feel individually human, not procedurally generated)
- Indie viability (6 named NPCs at ~240–360 hours artist time vs. 3D rigging at 600–900+ hours)

### Billboard Implementation (Godot 4)

```
NPC_Sarah (CharacterBody3D)
├── VisualRoot (Node3D — billboard pivot)
│   ├── BodySprite (AnimatedSprite3D — base body + expression)
│   ├── ClothingOverlay (Sprite3D — role assignment: cloak, armor, civilian)
│   ├── StatusOverlay (Sprite3D — injury, corruption state)
│   └── EquipmentSprite (Sprite3D — held item: torch, tool, weapon)
└── CollisionShape3D
```

Every `Sprite3D` uses `billboard = BILLBOARD_ENABLED` (built-in Godot). Sprites always face camera. Lighting is baked into sprite art — not computed per-pixel. Day/night is handled by material tint (see State-Driven Visuals section).

### Directional Angles

4-directional minimum (N/E/S/W). 8-directional preferred for the six named NPCs (Ruth, Thomas, Maren, Elias, Constance, Peder — see WORLD_STATE.md) and faction representatives. Arrivals and background figures: 4-directional sufficient.

---

## Sprite Production Pipeline

### Minimal Viable Pipeline (2-Person Team)

```
Step 1: Character Design (Aseprite or pencil-to-scan)
    → Establish: silhouette, color palette (4–5 colors per NPC), emotional state variants
    → Deliverable: concept sheet with 4 emotional states: neutral, afraid, angry, corrupted

Step 2: 3D Blocking (Blender, optional but recommended for consistency)
    → Build low-poly base mesh (~500 polys)
    → Set up orthographic camera at target view angle
    → Render 4–8 directional angles as reference sheets
    → Deliverable: angle reference PNGs (not shipped assets — reference only)

Step 3: Hand-Draw Animation Frames (Aseprite)
    → Per character, per animation set:
       idle:           6 frames
       walk (4-dir):   6 frames × 4 = 24 frames
       react (afraid): 4 frames
       react (corrupt):4 frames
       special event:  6 frames per triggered event (optional per NPC)
    → Total base: ~50–60 frames per NPC
    → Export: texture atlas PNG (2048×2048 max, multiple atlases if needed)

Step 4: Import to Godot (SpriteFrames)
    → Create SpriteFrames resource per NPC
    → Define animation names: "idle", "walk_n", "walk_e", "walk_s", "walk_w",
      "react_afraid", "react_corrupt", "react_event"
    → Frame rate: 100ms/frame (10 FPS) for movement, 150ms for reactions

Step 5: Material Setup
    → StandardMaterial3D per NPC: albedo = sprite texture, transparency = alpha pre-multiplied
    → Attach corruption/state shader (see below)
    → Assign VisualState dictionary reference (driven by backend NPC state)
```

**Time estimate per NPC**: 40–60 hours (design + blocking + animation + Godot import + shader tuning).
**Chapter 1 (6 NPCs minimum)**: 240–360 hours — 6–9 artist-weeks.

**Two-person split**:
- Person A: Blender blocking, angle references, Godot import, material/shader setup
- Person B: Aseprite hand-drawn frames, expression variants, animation polish

---

## Visual Language — Horror Without Jump Scares

The visual register is: **quiet institutional decay**. Not gothic horror. Not panic. The horror is what you notice after you've been looking for a while.

Reference anchors:
- Frostpunk: desaturation + silhouette-dominant architecture
- Darkest Dungeon: high-contrast, color is rare and alarming
- This War of Mine: brown-gray-white, emotion through composition
- Papers Please: bureaucratic layout as moral weight carrier

### Color Palette

```
Day Phase:
  Background: HSV sat ~0.35, val ~0.55 (muted industrial gray-brown)
  Structures: sat ~0.25–0.40, warm temp (~3500K ambient)
  NPCs: sat ~0.55 (higher than background — they stand out; they are the moral objects)
  Accent (fire, light sources): sat ~0.85, hue orange-yellow (the only warmth)

Night Phase:
  Background: HSV sat ~0.15, val ~0.25 (near-monochrome)
  Structures: sat ~0.10 — buildings become silhouettes
  NPCs: sat ~0.35 (still readable, but dimmed)
  Accent (horror events, corruption): sat ~0.70, hue desaturated teal/sickly green
  Fog: rgba(0.20, 0.22, 0.30, 0.60) — cold blue-gray

Corruption:
  Hue shift toward #2a5a5a (sickly teal)
  Normal map distortion (cracks, surface irregularity)
  Subtle pulsing emissive (not glowing — breathing)
```

**Rule**: Color saturation is moral information. Day is warmer, more saturated, falsely safe. Night strips that away. Corruption adds a sickly hue that reads as wrong, not scary.

### Lighting Model

3-point lighting. Day and night variants. No per-pixel dynamic lighting on billboard sprites — too expensive, kills 2D clarity. Lighting applied as material tint.

```
Day:
  Key:  directional, warm (#e8c89a), intensity 1.5, angle ~45° from NW
  Fill: ambient, cool (#a8b8c8), intensity 0.4
  Rim:  directional, neutral (#d0d0d8), intensity 0.6, from behind

Night:
  Key:  reduced directional, cold (#6a7a9a), intensity 0.6
  Fill: ambient, near-black (#202230), intensity 0.2
  Rim:  absent — darkness has no rim edge. Silhouettes flatten.
  Point lights: only from player-placed torches, campfires (orange, radius 4–6 units)
```

### Fog

Day: `fog_density = 0.02`, color `#c0c0b0` (haze, not threat).
Night: `fog_density = 0.15`, color `#1a1e2a` (enclosure, not mist).
Fog rises during night phase over a 3-second transition. Not instant. The darkness arrives.

### Camera Angle as Narrative

At 40° elevation, buildings loom. Taller structures cast long shadows toward the camera. The player sees the township from a position of marginal control — not commanding (top-down), not vulnerable (first-person). They are a middle manager watching something go wrong from a slight remove. This is the correct emotional distance for "Earned Dread."

---

## State-Driven Visual System — NPC Appearance

NPC visual state is driven by backend consequence data. The art system must translate backend state into visual deltas without requiring new hand-drawn assets per state combination.

### Backend Visual State Payload

```json
{
  "npc_id": "sarah",
  "visual_state": {
    "emotion":           "afraid",
    "assignment":        "north_post",
    "corruption_level":  0.3,
    "injury":            "leg",
    "equipment":         "torch"
  }
}
```

### Two-Tier Implementation

**Tier 1 — Parametric Shader (handles: emotion, corruption, day/night)**

```glsl
// NPC sprite shader — StandardMaterial3D extension
uniform float day_night_phase;     // 0.0 (day) → 1.0 (night)
uniform float corruption_strength; // 0.0 → 1.0
uniform vec3  emotion_tint;        // neutral=#fff, afraid=#aab, corrupt=#4a9a

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    if (base.a < 0.01) discard;

    // Day/night desaturation
    float sat = mix(0.8, 0.3, day_night_phase);
    vec3 gray = vec3(dot(base.rgb, vec3(0.299, 0.587, 0.114)));
    base.rgb = mix(gray, base.rgb, sat);

    // Corruption tint
    vec3 corruption_color = vec3(0.3, 0.55, 0.55); // sickly teal
    base.rgb = mix(base.rgb, corruption_color, corruption_strength * 0.65);

    // Emotion overlay (subtle)
    base.rgb = mix(base.rgb, emotion_tint, 0.12);

    ALBEDO = base.rgb;
    ALPHA  = base.a;
}
```

**Tier 2 — Modular Sprite Layers (handles: assignment clothing, injury, equipment)**

```gdscript
# NPC_Sarah.gd — called when backend pushes visual_state update
func apply_visual_state(state: Dictionary) -> void:
    # Tier 1: shader parameters
    var mat := $BodySprite.material_override as ShaderMaterial
    mat.set_shader_parameter("corruption_strength", state.get("corruption_level", 0.0))
    mat.set_shader_parameter("emotion_tint", EMOTION_COLORS[state.get("emotion", "neutral")])

    # Tier 2: clothing assignment
    var assignment := state.get("assignment", "civilian")
    $ClothingOverlay.sprite_frames = CLOTHING_FRAMES[assignment]
    $ClothingOverlay.visible = assignment != "civilian"

    # Tier 2: injury state
    var injury := state.get("injury", "none")
    $LegsSprite.sprite_frames = INJURY_FRAMES.get(injury, DEFAULT_LEGS)

    # Tier 2: equipment
    var equipment := state.get("equipment", "none")
    $EquipmentSprite.visible = equipment != "none"
    if equipment != "none":
        $EquipmentSprite.sprite_frames = EQUIPMENT_FRAMES[equipment]

const EMOTION_COLORS := {
    "neutral":   Vector3(1.0, 1.0, 1.0),
    "afraid":    Vector3(0.75, 0.78, 0.90),
    "angry":     Vector3(0.95, 0.80, 0.80),
    "corrupted": Vector3(0.60, 0.90, 0.90),
}
```

### Building State System

Buildings have 3 visual states: pristine, damaged, corrupted. State driven by player choice consequences. Not labeled for the player — the building just looks different.

```
Watchtower (pristine):   clean timber, warm torch light
Watchtower (damaged):    broken parapet visible, torch extinguished, dark
Watchtower (corrupted):  corruption shader active, sickly teal rim, slow pulsing emissive

Material swap trigger:   consequence_ids array in player_choices log →
                         Godot reads building_id → swaps StandardMaterial3D variant
```

Asset budget per building: 3 material variants (albedo swap + shader parameter). No new geometry per state. Geometry is authored once; state is shader and texture.

---

## Day/Night Transition — Technical Sequence

```
Player triggers night (or timer fires):
    t=0.0s   POST /transition/night → backend starts pre-computation
    t=0.0s   Godot begins transition:
               - Camera pull-back tween (Tween, 2.5s, ease-in-out)
               - WorldEnvironment: fog_density lerp (0.02 → 0.15, 3.0s)
               - DirectionalLight3D: intensity lerp (1.5 → 0.6, 2.5s), color lerp warm→cold
               - All NPC materials: day_night_phase lerp (0.0 → 1.0, 2.5s)
               - Ambient light: lerp (#a8b8c8 → #202230, 2.5s)
    t=2.5s   Transition animation complete. Night visuals locked.
    t=3–5s   Backend signals { event: "night_ready" } via WebSocket
    t=5.0s   Night phase begins. Pre-computed events served from queue.
```

The 2.5s transition is not a loading screen. It is narrative punctuation. The world does not cut to night. Night arrives.

---

## THE DEBT's Physical Forms — Visual Design

Three creature types require visual specification. None are NPCs. None use the billboard sprite system.

### The Hollow Walkers

**What they look like**: Low-poly silhouette mesh objects — not billboards. A Walker is a terrain object that moves. The geometry is a stylized dead tree form: root mass at the base, two to three asymmetric branches, no face, no eyes, no suggestion of intention. The silhouette reads as wrong-shaped timber, not as a creature. At night, with the near-monochrome palette, a Walker at distance looks like a large piece of debris that is in a different position than it was.

**Movement animation**: 3 keyframes. No walk cycle in the humanoid sense. The root mass shifts weight — a slow lateral lean followed by forward displacement, like something that has forgotten it is not supposed to move. Frame rate: 1 frame per 3 seconds at approach speed (one zone per night-hour). Movement is readable as deliberate only at close observation.

**Visual treatment**:
- No shader warmth — no emissive, no pulsing. Walkers are cold.
- Silhouette rendered at night contrast: near-black against the dark-gray fog.
- At dawn (when stopped): still Walkers use the `damaged` visual variant of terrain objects — they read as obstacles, not as threats. Their threat is over. Their presence remains.
- Corruption shader: NOT applied to Walkers. They are not corrupted. They are native.

**Godot implementation**:
```
Walker (Node3D — AnimationPlayer + StaticBody3D)
├── WalkerMesh (MeshInstance3D — low-poly tree silhouette, ~200 tris)
│   └── Material: StandardMaterial3D, albedo #1a1a1a, no emission
├── AnimationPlayer (zone-movement keyframe animation)
└── Area3D (detection radius — triggers NPC arc update on proximity)
```

**Asset estimate**: 1 Walker mesh, 3-keyframe animation. 20–30 hours.

---

### The Ledger Watchers

**What they look like**: Nothing. Watchers have no entity, no sprite, no mesh. They are environmental.

**Visual manifestations** (triggered by consequence events, not by creature position):
- `OmniLight3D` attached to affected stockpile buildings begins flickering. Flicker pattern: irregular, not rhythmic. Rhythm would suggest machinery. Irregularity suggests something deciding.
- Misplaced equipment props: small static mesh swaps (a tool rack in one position at dusk, a different position at dawn). The prop is the same object. The position is wrong. No animation — the player observes it as a state change between night phases.
- Ledger text (if the player opens the supply ledger during a Watcher-active night): one line in the ledger has been moved. Not added — moved. The accounting is being done by something else.

**Shader**: No creature shader. The flickering light uses `OmniLight3D.light_energy` tween with randomized intervals (0.3–1.8 seconds). Code only — no art asset required.

**Asset estimate**: 2–3 prop mesh variants for misplaced equipment. 8–12 hours.

---

### The Surveyor's Shadow

**What it looks like**: Human proportion. Monochrome billboard sprite (same AnimatedSprite3D system as NPCs, but desaturated beyond the night palette — HSV sat 0.0, val 0.15). The Surveyor reads as a human figure at the treeline seen from a distance of 40–60 world units. It does not approach. It does not look directly at the camera.

**Animation**: Walk cycle along the Zone 3/5 boundary path. 6 frames, slow cycle (150ms/frame). The walk is measured — not stalking, not fleeing. It is surveying. A figure doing a job.

**Visual treatment**:
- Surveyor sprite renders at the camera's maximum visible distance. It is always at the edge of legibility.
- No corruption shader. The Surveyor is not wrong — it is the original wrong made manifest.
- On Night 4 (pre-reckoning): Surveyor is visible for ~3 in-game hours, then withdraws. High-DEBT variant: pauses at the Zone 5 boundary for ~1 in-game hour before withdrawing. The pause is the only behavioral difference between DEBT states on Night 4.
- On Night 5 (marking): after completing its walk, the Surveyor stops at the Zone 5 boundary. If marking: it makes a single gesture (one additional animation frame — the surveyor's arm extended, measuring). Then it steps into the hollow. The zone boundary changes state. If departing: it completes the walk and the sprite fades at the treeline edge over 4 seconds.
- Camera behavior: on Night 4 and Night 5, camera auto-snaps to Surveyor position when it first appears. Player regains camera control after 8 seconds.

**Godot implementation**:
```
Surveyor (Node3D — positioned at Zone 3/5 boundary, path-following)
├── SurveyorSprite (AnimatedSprite3D — billboard, monochrome, 6-frame walk)
│   └── Material: StandardMaterial3D, albedo desaturated to #282828
├── PathFollow3D (follows predefined boundary path)
└── SurveyorController.gd (handles Night 4 vs Night 5 behavior, DEBT state)
```

**Asset estimate**: 1 Surveyor sprite sheet (6 walk frames + 1 marking frame), 7 frames at 96×128px. 15–20 hours.

---

## Asset Production Roadmap

| Asset | Priority | Volume | Est. Hours | Notes |
|-------|----------|--------|------------|-------|
| Named NPC base sprites + animation | 1 — Chapter 1 | 6 NPCs × ~55 frames | 240–360h | Critical path |
| NPC emotional state variants | 1 | 6 NPCs × 4 states | 60–80h | Shader handles most; 2–3 expression frames per state |
| Building meshes (day state) | 1 | 8–12 building types | 80–120h | Low-poly (500–2K tris). Blender → Godot .glb |
| Building material variants (damaged, corrupted) | 2 | 8–12 × 2 variants | 40–60h | Albedo swaps + shader param tuning |
| Walker mesh + movement animation | 1 — Chapter 1 | 1 mesh, 3 keyframes | 20–30h | Not a billboard — terrain object |
| Surveyor sprite + walk/marking animation | 1 — Chapter 1 | 7 frames at 96×128px | 15–20h | Billboard, monochrome |
| Ledger Watcher environmental props | 2 | 2–3 prop mesh variants | 8–12h | No creature mesh — environmental only |
| Corruption shader + VFX | 2 | 1 shader, 1 particle system | 20–30h | Shared across buildings and NPCs; NOT on Walkers |
| Day/night WorldEnvironment profiles | 1 | 2 profiles | 8–12h | Fog, ambient, directional light params |
| Terrain mesh + tiling textures | 2 | 1 tileset, 3–4 biome variants | 40–60h | Low-poly ground plane with modular tile assets |
| UI / HUD elements | 3 | ~20 UI elements | 40–60h | See: UI as Moral Interface below |

**Chapter 1 total art estimate**: 575–790 hours — 15–20 artist-weeks at 40h/week. Feasible for a 2-person team over 4 months alongside code work.

---

## UI as Moral Interface

Directly from Pillar 3: the logistics UI must feel mechanical until consequences reveal it wasn't.

**Visual rules for UI:**
- No color coding of moral weight. Assigning Sarah to the north post is a job-assignment UI interaction — it uses the same grey-and-white aesthetics as assigning a carpenter to a building.
- No confirmation dialogs for micro choices ("Are you sure you want to assign Sarah?"). Deliberateness should come from the player, not the UI.
- No post-choice summary ("You assigned Sarah. This may be dangerous."). The UI does not interpret.
- Building placement uses a grid overlay (clean, logistical) with no moral signaling on individual cells.
- Faction negotiation UI: text-list options, not dialogue wheel. Options are described by content, not by moral framing ("Offer them the north granary" — not "Be generous").

**Night phase UI:**
- Minimal. Event text delivered in a bottom-left narrative log (not a center-screen modal).
- No icons for horror events. Text only, in the NPC's register, not a system notification tone.
- Pause is permitted during night phase. When paused, the world freezes — visually intact,
  silent, and wrong. Not a menu overlay. Not a black screen. The player sees exactly what
  they were looking at, stopped. Pending events do not arrive while paused. Events already
  delivered cannot be undelivered.
  The design goal is not technical inability to pause. It is that pausing still requires
  the player to look at what is there. You can stop time. You cannot look away.

---

## TPS View in Context — Not a Walking Simulator

The TPS view is not for player avatar traversal. Hollow Township is a township management game. The "player character" is the township manager — an abstracted presence, not a controlled avatar.

**What TPS enables here:**
- Camera agency: player can look at what they want to see during the day
- Proximity reveals: zoom in on an NPC to see their emotional state (the UI does not label it)
- Horror push events: night-phase camera snaps toward threats, briefly removing player camera control — the world looks at what it wants you to see

**What TPS does not enable:**
- Character locomotion as primary input (this is not a third-person action game)
- Combat from a player avatar POV
- First-person sections

The camera is the player's relationship to the township, not a character controller.

---

## References

- Darkest Dungeon visual language analysis: redhook.studio
- Frostpunk environment art GDC 2019: gdcvault.com
- Godot 4 Sprite3D docs: docs.godotengine.org/en/stable/classes/class_sprite3d.html
- Godot 4 WorldEnvironment / Fog: docs.godotengine.org/en/stable/classes/class_environment.html
- Aseprite sprite animation: aseprite.org/docs/animation
- Blender orthographic rendering for game sprites: docs.blender.org/manual/en/latest/render/output/properties/format.html
- Hades visual design (2D characters in 3D space): supergiantgames.com/blog
- This War of Mine art direction: 11bitstudios.com
