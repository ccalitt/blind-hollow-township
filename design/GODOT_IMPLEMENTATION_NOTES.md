# Godot Implementation Notes — Hollow Township

> **Status: RESEARCH NOTES — not frozen design.**
> Engine target: Godot 4.x (GDScript), per CLAUDE.md. PC-first (Steam EA) → web → mobile.
> Purpose: translate the frozen design docs (GRAPHICS.md, INTERACTION_MODEL.md, ARCHITECTURE.md)
> and the open prototype gates (CRITICAL_GAPS_PLAN.md Gap 5, Gap 9) into concrete, cited Godot
> patterns. Nothing here overrides a frozen doc. Where a frozen doc and this note disagree, the
> frozen doc wins and the discrepancy is flagged inline.
>
> **Verification posture:** Patterns marked [VERIFIED] are confirmed against the cited source.
> Patterns marked [API-KNOWLEDGE] rely on standard Godot 4 API that the cited docs reference but
> that the live docs pages (docs.godotengine.org) returned HTTP 403 to automated fetch — verify
> the exact property names against the running 4.x editor before locking. Patterns marked
> [JUDGEMENT] are engineering recommendations, not facts.

---

## 0. Scope and the One Constraint That Shapes Everything

This is **not** a third-person action game. Per GRAPHICS.md ("TPS View in Context") and
INTERACTION_MODEL.md §1, there is **no player avatar**. The "player character" is the camera +
cursor. That single fact removes the hardest parts of a 3D Godot project (character controller,
locomotion, animation state machine for the player) and reframes the camera rig as following a
**township centroid**, not a `CharacterBody3D`. Most third-person-camera tutorials assume a
controlled body; adapt them by replacing the followed body with a static/animated pivot.

---

## 1. Elevated Top-Down / TPS Camera (35–45°, pan + zoom + Y-rotate)

GRAPHICS.md "Perspective Decision" freezes the model: 35–45° elevated follow-cam, Y-axis freely
rotatable, zoom range 8–30 units, pitch locked 35–45°, fov 70°, camera follows the township
centroid. The node tree below is the frozen one from GRAPHICS.md; this section fills in the *how*.

### 1.1 Node rig

```
World (Node3D)
└── CameraRig (Node3D)              # position = township centroid; pan target
    └── Yaw (Node3D)                # Y-axis rotation only (Q/E or middle-drag)
        └── SpringArm3D             # camera distance/zoom; collision pull-in
            └── Camera3D            # pitch locked 35–45°; fov 70°
```

Rationale for the extra `Yaw` node: keep **pan** (move `CameraRig`), **rotate** (rotate `Yaw`),
and **zoom** (`SpringArm3D.spring_length`) on three separate nodes so each input maps to exactly
one transform and none of them fight. This is the standard isometric/strategy decomposition the
Godot community recommends — separate the rotation node from the arm so rotating the rig does not
rotate the camera mount unexpectedly. [VERIFIED — forum.godotengine.org isometric camera thread;
dredyson.com spring-arm rotation fix]

### 1.2 SpringArm3D — use it, but know why

`SpringArm3D` casts along its length and pulls the camera in when geometry intrudes, preventing
the camera clipping through buildings as the player rotates around the township. [VERIFIED —
docs spring_arm tutorial; supermatrix.studio]. Set `spring_length` for the zoom distance (8–30
units) and tween it for smooth zoom. Put a `shape` (small sphere) on it so the pull-in is not a
zero-radius ray.

Caveat [JUDGEMENT]: in a township-survey game the camera rarely sits *behind* tall geometry the
way a follow-cam does behind a player. If clip-through proves rare in the prototype, a plain
`Node3D` "Arm" with manual length is simpler and avoids surprise pull-ins during the scripted
night camera snaps (§1.5). Decide at prototype time. The frozen GRAPHICS.md tree shows a plain
`Arm (Node3D)`, so **SpringArm3D is an upgrade option, not a frozen requirement** — flag if adopted.

### 1.3 Perspective vs orthographic (the true-3D vs 2D-in-3D tradeoff)

- **Orthographic** keeps objects the same screen size regardless of distance — classic isometric,
  maximum tactical clarity, but it *flattens* the "buildings loom" effect GRAPHICS.md wants at 40°.
  [VERIFIED — docs class_projection; forum camera-zoom thread]
- **Perspective** (fov 70°, as frozen) makes near buildings loom and far ones recede — this is the
  "marginal control / middle manager watching from a slight remove" emotional distance GRAPHICS.md
  explicitly calls for ("Camera Angle as Narrative").

**Recommendation [JUDGEMENT, aligns with frozen GRAPHICS.md]:** keep **perspective**, fov 70°.
The frozen doc already specifies fov=70°, which only exists for perspective cameras — orthographic
uses `size` instead. So this is effectively settled by GRAPHICS.md; orthographic is out.

The broader "true 3D vs 2D-in-3D" question is **already answered by GRAPHICS.md**: a real 3D world
(terrain, building meshes, Walker meshes) with **2D billboard sprites for NPCs** (§2). That is the
Hades / Stoneshard model. Do not relitigate it here.

### 1.4 Zoom, pan, rotate — input mapping (INTERACTION_MODEL.md §1)

```gdscript
# CameraRig.gd  [JUDGEMENT — illustrative, verify node names at build]
@export var pan_speed := 12.0
@export var zoom_min := 8.0
@export var zoom_max := 30.0
@export var zoom_step := 2.0
@export var rotate_speed := 1.5

@onready var yaw: Node3D = $Yaw
@onready var arm: SpringArm3D = $Yaw/SpringArm3D

func _process(delta: float) -> void:
    var dir := Input.get_vector("pan_left", "pan_right", "pan_fwd", "pan_back")
    # pan in the rig's local XZ, rotated by current yaw so WASD is screen-relative
    var basis := Basis(Vector3.UP, yaw.rotation.y)
    global_position += basis * Vector3(dir.x, 0, dir.y) * pan_speed * delta
    if Input.is_action_pressed("rotate_cw"):
        yaw.rotation.y -= rotate_speed * delta
    if Input.is_action_pressed("rotate_ccw"):
        yaw.rotation.y += rotate_speed * delta

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(-zoom_step)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(zoom_step)

func _zoom(amount: float) -> void:
    var target = clampf(arm.spring_length + amount, zoom_min, zoom_max)
    create_tween().tween_property(arm, "spring_length", target, 0.15)
```

Keyboard map per INTERACTION_MODEL.md §1: pan WASD/arrows, zoom scroll or +/-, rotate Q/E or
middle-drag. All *world-object* interaction is mouse-only (Observe/Place cursor modes).

### 1.5 Scripted night camera snap (GRAPHICS.md "Night phase camera behavior")

During pre-computed horror events the camera snap is **scripted, not player-controlled**, for the
duration of event text, then control returns. Implement as a camera-control state flag, not by
disabling input nodes (you still want pause to work, §3):

```gdscript
# CameraDirector.gd  [JUDGEMENT]
enum Mode { PLAYER, SCRIPTED }
var mode := Mode.PLAYER

func snap_to(target_pos: Vector3, hold_seconds: float) -> void:
    mode = Mode.SCRIPTED
    var t := create_tween()
    t.tween_property(camera_rig, "global_position", target_pos, 0.6)\
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    await get_tree().create_timer(0.6 + hold_seconds).timeout
    mode = Mode.PLAYER     # player regains camera control at event end
```

When `mode == SCRIPTED`, `CameraRig._process` ignores pan/rotate input. This serves **Pillar 2
(The Watched Feeling)** — "the camera looks at what matters, not what the player wants to see."

### 1.6 Day→night camera transition

GRAPHICS.md freezes a 2.5s lerp: pull-back 8→12 units, pitch 40°→45°, fog rise, light dim. Use
one `Tween` driving `spring_length`, `Camera3D.rotation.x`, and `WorldEnvironment` fog/light in
parallel (`Tween.parallel()`). This is narrative punctuation, not a loading screen — it overlaps
the backend pre-computation window (ARCHITECTURE.md day→night pipeline, 2–5s).

---

## 2. Billboard Sprites + Emotional Readability (Gap 9 — UNRESOLVED GATE)

> **This is the prototype gate.** GRAPHICS.md is explicit: the claim that 96×128 billboard sprites
> at 8–12% screen height carry enough emotional information for Pillar 2 is **NOT frozen** until the
> Gap 9 validation test passes (≥80% recognition across 4 states). Everything in §2.1–§2.2 is the
> *mechanism*; §2.4 is the *test that decides whether the mechanism is sufficient*.

### 2.1 Billboard implementation in Godot 4

Use `Sprite3D` / `AnimatedSprite3D` with billboard mode. The relevant properties [API-KNOWLEDGE —
GRAPHICS.md already specifies `billboard = BILLBOARD_ENABLED`; live class_sprite3d page 403'd to
fetch, confirm names in editor]:

- `billboard`: `StandardMaterial3D.BILLBOARD_ENABLED` (full billboard, always faces camera) or
  `BILLBOARD_FIXED_Y` (rotates only around Y — usually **better for ground characters** so they
  don't tilt back when the camera pitches at 40°). **Recommendation [JUDGEMENT]: test
  `BILLBOARD_FIXED_Y` first** — full billboard can make a standing figure lean toward an elevated
  camera, which reads wrong for a township figure. GRAPHICS.md says `BILLBOARD_ENABLED`; flag this
  as a prototype refinement to revisit.
- `pixel_size`: world units per texture pixel — this sets the on-screen size of the sprite and is
  the dial you tune so a 96×128 sprite lands at 8–12% screen height at default zoom.
- `texture_filter`: set **Nearest** for crisp pixel art (no blur on scale). Also set
  Project Settings → Rendering → Textures → **Default Texture Filter = Nearest** project-wide.
  [VERIFIED — gdquest pixel-art-setup; forum pixel-perfect-textures thread]
- `alpha_cut`: use `ALPHA_CUT_DISCARD` (or scissor) rather than alpha blending where possible —
  blended transparency on many sprites causes sort/order artifacts and depth issues. The shader in
  GRAPHICS.md already `discard`s on `base.a < 0.01`, consistent with this.
- `shaded = false` for sprites whose lighting is baked into the art (GRAPHICS.md: "Lighting is
  baked into sprite art — not computed per-pixel"; day/night handled by material tint). [API-KNOWLEDGE]

Per-NPC layered tree is frozen in GRAPHICS.md (VisualRoot → BodySprite / ClothingOverlay /
StatusOverlay / EquipmentSprite). The two-tier visual-state system (parametric shader + modular
layers) is already authored there — implement as written; don't redesign.

### 2.2 What actually reads at distance (sprite-readability research)

The design risk is that emotion does not survive at 8–12% screen height. Research consensus on
small-sprite legibility:

- **Silhouette first.** If you can't tell what a sprite is from its outline alone, simplify it.
  Emotional *state* should be partly carried by **pose/silhouette**, not only face. [VERIFIED —
  SLYNYRD pixelblog-22; anyflip Pixel Logic guide]
- **Exaggerate at small size.** The smaller the sprite, the more pose, contrast, and
  frame-to-frame silhouette difference must be exaggerated. Subtle realism disappears below ~32px
  of meaningful detail. [VERIFIED — sprixen sprite-sizes guide]
- **Color/contrast as a second channel.** When detail can't fit, use color contrast to separate
  features and signal state. This matches GRAPHICS.md's `emotion_tint` (afraid → pale blue,
  angry → warm, corrupted → teal) and the Gap 9 fallback ("afraid NPCs get a pale face tint
  readable at distance"). [VERIFIED — medium/AlainGalvan pixel-art-for-gamedev; Pixel Logic]
- **Outlines aid clarity** against busy 3D terrain — a 1px contrasting outline keeps the figure
  legible against Frostpunk-gray ground. [VERIFIED — sprixen; SLYNYRD]
- **Vertical head room buys expression.** Larger sprites with more vertical pixels in the face
  enabled visible expression that small battle sprites could not. This directly supports the Gap 9
  fallback of **128×192 for primary NPCs** (Sarah, Priest, faction leaders) while keeping 96×128
  for background figures. [VERIFIED — sprite-ai anime-pixel-art on JRPG battle vs field sprites]

**Synthesis [JUDGEMENT]:** emotion at this scale is a **three-channel signal**: (1) silhouette/pose,
(2) the `emotion_tint` color shift, (3) a small number of high-contrast face pixels. Design the four
states (neutral/afraid/angry/corrupted) so each is distinguishable on **pose + tint alone**, with
the face as confirmation, not the sole carrier. This is the most likely path to passing Gap 9. If
it still fails, fall to the GRAPHICS.md Gap 9 fallback: 128×192 primaries and/or a world-space
state cue that is *part of the NPC's presence* (e.g., torch color, posture-as-shape) — explicitly
**not** a floating UI element (which would violate INTERACTION_MODEL.md "the UI does not interpret"
and Pillar 3).

### 2.3 Directional angles

GRAPHICS.md: 4-dir minimum, 8-dir for story-critical NPCs. With `BILLBOARD_FIXED_Y` the sprite
faces the camera, so "direction" is the character's *facing relative to camera* — pick the frame
set by comparing NPC facing to camera yaw and swapping `AnimatedSprite3D` animation
("walk_n/e/s/w"). The frozen SpriteFrames animation names are in GRAPHICS.md Production Pipeline.

### 2.4 Gap 9 validation-test protocol (concrete, executable)

This is the gate. Run it before freezing the readability claim. CRITICAL_GAPS_PLAN.md Gap 9
defines the pass bar (≥80% recognition, 4 states, 3–5 naive viewers). Concrete protocol:

1. **Build the harness in Godot** (not Photoshop): one `Sprite3D` NPC, 4 state textures, on the
   real terrain material, under the real day **and** night `WorldEnvironment` profiles (state must
   read in *both*; night desaturates per the shader). Camera at the frozen rig: 40° pitch, fov 70°.
2. **Test at three zooms**: 8u (close), ~19u (default — NPC at 8–12% height), 30u (survey). The
   default zoom is the one that must pass; record all three.
3. **Render target**: ship-resolution. PC target 1080p minimum; also capture at 720p (Steam Deck /
   low-end) because readability is resolution-sensitive — a sprite that reads at 1080p may not at
   720p. (Mobile port is later but note it now: phone screens will be the hardest case.)
4. **Naive-viewer task** (3–5 people who have not read design docs), two questions per state,
   randomized order:
   - Forced-choice: "Which of these four is this?" (neutral / afraid / angry / corrupted)
   - Free-recall: "What is this person feeling?" (catches false positives from the 4-way prompt)
5. **Pass bar**: forced-choice recognition ≥80% **at default zoom**, across all 4 states. A state
   below 80% is redesigned (more pose, stronger tint, bigger face) or the NPC promoted to 128×192.
6. **Record the deciding artifact**: a screenshot grid (4 states × 3 zooms × day/night) attached to
   the Gap 9 resolution note. The gate is visual; the evidence must be visual.
7. **Decision output**: PASS → GRAPHICS.md readability sections freeze as written. FAIL → adopt the
   GRAPHICS.md Gap 9 fallback and re-run. Do not freeze on a single marginal pass; the whole of
   Pillar 2's surface depends on it.

---

## 3. Real-Time but PAUSABLE Night Phase (Gap 5)

CRITICAL_GAPS_PLAN.md Gap 5 reframes the old no-pause rule: **pause is permitted**; it freezes the
world *visually intact, silent, and present* — not a menu, not a black screen. GRAPHICS.md "Night
phase UI" and INTERACTION_MODEL.md §5 freeze this: pending events don't arrive while paused; events
already delivered cannot be undelivered; the player can stop time but cannot look away.

### 3.1 Godot pause primitives [VERIFIED — docs pausing_games tutorial]

`get_tree().paused = true` does two things: halts 2D/3D physics, and gates every node's processing
by its **`process_mode`**. The five constants:

| Constant | Behavior |
|---|---|
| `PROCESS_MODE_INHERIT` | Follows parent's mode (default). |
| `PROCESS_MODE_PAUSABLE` | Processes only when **not** paused. (game world) |
| `PROCESS_MODE_WHEN_PAUSED` | Processes **only** when paused. (pause-only logic) |
| `PROCESS_MODE_ALWAYS` | Processes **always**, paused or not. |
| `PROCESS_MODE_DISABLED` | Never processes. |

### 3.2 The Hollow Township pattern — "frozen diorama, not a menu"

The design intent is unusual: most games pause to *show a menu over a frozen world*. Here, pausing
**is** the frozen world — the player keeps looking at exactly what they were looking at. So:

- **The game world (NPCs, Walkers, Surveyor animation, fog motion, WebSocket polling)** →
  `PROCESS_MODE_PAUSABLE` (the default once the parent is pausable). On pause they freeze in place.
  This produces the "still, silent, and wrong" frozen township the design wants. [JUDGEMENT]
- **Camera control** → `PROCESS_MODE_ALWAYS` **only if** you want the player to still pan/zoom while
  paused. Design call: GRAPHICS.md says the player "sees exactly what they were looking at, stopped"
  — which argues the camera should **also freeze** (i.e., stay `PAUSABLE`). **Recommendation
  [JUDGEMENT]: freeze the camera too** (camera `PAUSABLE`); pausing is a held breath, not a free
  inspection mode. Flag for design sign-off — this is a feel decision, not a technical one.
- **No pause overlay UI.** Critically, there is **no menu CanvasLayer** to mark `WHEN_PAUSED`. The
  pause "UI" is the absence of UI. If a minimal "paused" affordance is ever added, it must obey
  GRAPHICS.md (no center-screen modal, bottom-left register only) — but the frozen design implies
  none. This is the opposite of the standard tutorial pattern (which marks a menu `WHEN_PAUSED`);
  call it out so an engineer following a tutorial doesn't add a menu that violates the design.

```gdscript
# NightPhaseController.gd  [JUDGEMENT]
# World root for night content is PROCESS_MODE_PAUSABLE (inherited default).
# Pause input handler must keep running while paused → PROCESS_MODE_ALWAYS on THIS node.

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS   # so we can detect the unpause keypress

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):       # Space/P per INTERACTION_MODEL §1
        get_tree().paused = not get_tree().paused
        # No menu shown. No sound. The world simply stops or resumes.
```

### 3.3 The pause-and-WebSocket interaction (ties §3 to §4)

"Pending events do not arrive while paused." Two correct implementations [JUDGEMENT]:

- **Client-gated (recommended):** keep polling the socket on a node marked `PROCESS_MODE_ALWAYS`
  (so the connection stays alive and doesn't time out), but **buffer** received events into a queue
  and only **render/deliver** them when `not get_tree().paused`. The socket stays healthy; delivery
  is what pauses. This avoids dropping the connection.
- **Stop-poll (simpler, riskier):** put the polling node in `PAUSABLE` so `poll()` stops on pause.
  Risk: long pauses can let the TCP/WS connection idle out or buffer server-side. Given night
  phases are short and the server pushes a small pre-computed queue (ARCHITECTURE.md), this is
  *probably* fine, but the client-gated approach is safer. **Recommend client-gated.**

> Watch-out [VERIFIED — github godot#81994]: a known Godot issue is that `Tween`s created on a node
> that is *not* `PROCESS_MODE_ALWAYS` stop during pause even if you intended them to run. For the
> night phase you *want* tweens (sprite anim, fog) to freeze on pause — so this default behavior is
> correct here. But the day→night transition tween (§1.6) and any always-running UI tween must live
> on an `ALWAYS` node or they'll stall if pause is hit mid-transition.

This pattern serves **Pillar 4** (night is Unease) without giving the player a safe-retreat menu —
exactly the Gap 5 goal.

---

## 4. Calling the LLM/HTTP Backend from Godot

ARCHITECTURE.md "Godot 4 Integration" freezes the transport split: **REST (HTTPRequest) for day
phase**, **WebSocket for the night-phase event stream**, deltas only, gzip, <4KB/payload, backend
authoritative. This section gives the async/error patterns.

### 4.1 Day phase — HTTPRequest, await, timeout, retry

`HTTPRequest` is signal-based; `await` on `request_completed` turns it into a coroutine. The signal
yields `(result, response_code, headers, body)` — `body` is a `PackedByteArray`. [VERIFIED — dev.to
await article; gdquest await glossary; godot-proposals#1782]

**Critical gotcha [VERIFIED — same sources]:** `await` has **no built-in timeout**. If the signal
never fires (network drop), the coroutine hangs forever. You **must** add your own timeout and
**must** re-check `is_instance_valid()` after the await.

```gdscript
# BackendClient.gd  [JUDGEMENT — pattern is sound; verify HTTPRequest API in editor]
signal choice_failed(reason: String)

const MAX_RETRIES := 3          # mirror of the Master Enforcer 3-attempt policy (see §4.3)
const TIMEOUT_S := 5.0          # day-phase budget is <300ms; 5s is the give-up wall

func post_choice(path: String, payload: Dictionary) -> Variant:
    for attempt in range(MAX_RETRIES):
        var http := HTTPRequest.new()
        add_child(http)
        var headers := PackedStringArray(["Content-Type: application/json"])
        var err := http.request(BASE_URL + path, headers,
            HTTPClient.METHOD_POST, JSON.stringify(payload))
        if err != OK:
            http.queue_free()
            continue

        # Race the response against a timeout timer.
        var timeout := get_tree().create_timer(TIMEOUT_S)
        var result = await _first_of(http.request_completed, timeout.timeout)
        http.queue_free()

        if result == null:                      # timed out
            await _backoff(attempt)
            continue
        var code: int = result[1]
        var body: PackedByteArray = result[3]
        if code == 200:
            return JSON.parse_string(body.get_string_from_utf8())
        if code >= 500:                          # server error → retry
            await _backoff(attempt)
            continue
        choice_failed.emit("HTTP %d" % code)     # 4xx → don't retry
        return null
    choice_failed.emit("exhausted retries")
    return null

func _backoff(attempt: int) -> void:
    await get_tree().create_timer(0.25 * pow(2, attempt)).timeout   # 0.25/0.5/1.0s

# Helper: resume on whichever signal fires first. (No stdlib any() in GDScript.)
func _first_of(sig_a: Signal, sig_b: Signal) -> Variant:
    var done := [false]
    var box := [null]
    sig_a.connect(func(a=null,b=null,c=null,d=null):
        if not done[0]: done[0]=true; box[0]=[a,b,c,d], CONNECT_ONE_SHOT)
    sig_b.connect(func():
        if not done[0]: done[0]=true; box[0]=null, CONNECT_ONE_SHOT)
    while not done[0]:
        await get_tree().process_frame
    return box[0]
```

Notes:
- The fire-and-forget micro choice (ARCHITECTURE.md latency budget: <50ms, SQS) does **not** await
  a body — send and move on; the UI gives no confirmation anyway (INTERACTION_MODEL.md: "the
  building is there, that is the feedback"). Only narrative-trigger calls (<300ms) await a payload.
- One `HTTPRequest` node **per in-flight request** (or a small pool). A single node can't run
  concurrent requests. Creating/freeing per call is fine at this volume. [JUDGEMENT]
- Client-side retry is a **separate layer** from the server's Master Enforcer retry (§4.3).

### 4.2 Night phase — WebSocketPeer, polled, buffered

[VERIFIED — docs websocket tutorial via godot-docs source; rokojori 4.4 mirror]. The frozen pattern:

```gdscript
# NightFeed.gd  [VERIFIED pattern, adapted]
var socket := WebSocketPeer.new()
var inbox: Array = []                 # buffer; delivery gated by pause (see §3.3)

func open() -> void:
    socket.connect_to_url("wss://api.hollowtownship.com/night-feed")

func _process(_delta: float) -> void:
    socket.poll()                     # must call every frame
    match socket.get_ready_state():
        WebSocketPeer.STATE_OPEN:
            while socket.get_available_packet_count() > 0:
                var pkt := socket.get_packet()
                if socket.was_string_packet():
                    inbox.append(JSON.parse_string(pkt.get_string_from_utf8()))
        WebSocketPeer.STATE_CLOSING:
            pass                      # keep polling to finish the close handshake
        WebSocketPeer.STATE_CLOSED:
            var code := socket.get_close_code()
            _on_closed(code)          # reconnect-with-backoff if unexpected

func send_reaction(d: Dictionary) -> void:
    if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        socket.send_text(JSON.stringify(d))

func close() -> void:
    socket.close()                    # at night→dawn transition
```

- Open at day→night transition; close at night→dawn (ARCHITECTURE.md transport table). The node
  doing the polling is `PROCESS_MODE_ALWAYS` per §3.3 (client-gated buffering) so the connection
  survives pause while *delivery* of `inbox` items is gated on `not get_tree().paused`.
- **Reconnect with backoff** on unexpected `STATE_CLOSED`: the night queue lives in DynamoDB
  (ARCHITECTURE.md `player_night_queue`, TTL 24h), so a dropped socket can re-open and resume —
  events are pre-computed and durable, not lost on disconnect. [JUDGEMENT, grounded in ARCH schema]
- **Known engine watch-out [VERIFIED — github godot#115384]:** packets buffered *before* a close
  frame can become inaccessible once state flips to `STATE_CLOSING`. Drain
  `get_available_packet_count()` fully on every `STATE_OPEN` frame (the `while` loop above) so you
  don't leave packets undrained right as the server closes.

### 4.3 Mapping to the Master Enforcer retry policy

ARCHITECTURE.md Master Enforcer retries **server-side** (3 attempts: full context → reduced context
→ authored fallback library). The **client must not duplicate that semantic retry** — by the time
the server responds, it has *already* fallen back if needed. The client's retry (§4.1) is purely
for **transport failure** (timeout, 5xx, dropped socket), not content quality. Concretely:

- A `200 OK` with a fallback event (ARCHITECTURE.md `tone_check: "authored"`) is a **success** to
  the client — render it normally. The player can't tell a fallback from a generated event; that's
  the point.
- Client retries only on no-response / 5xx / socket drop. Cap at 3 (mirrors the server cap for
  symmetry, not because they're the same retries).
- The `cause_chain` field is **always present** in every event (ARCHITECTURE.md generation rules);
  the client uses it to render the traceable line (e.g., "Sarah shivers at the northern wall she
  was assigned to watch") — this is the **Pillar 1 / Pillar 4** payoff and the REVEAL_MECHANIC.md
  Option B dawn-thread surface. The client should treat a *missing* `cause_chain` as a malformed
  event and skip it (the server already rejects these at the Enforcer, so it should never happen —
  defensive only).

---

## 5. Data-Driven Content — Custom Resource vs JSON

ARCHITECTURE.md is the authority on *runtime, server-authoritative* state. This section is about
**authored, client-side static content**: NPC definitions, zone/map layout, building types, the
build-menu, and — importantly — the **client mirror of the authored fallback night-event library**
(`/backend/enforcer/fallback_events.json`), if any is needed client-side for offline/degraded mode.

### 5.1 Recommendation: custom `Resource` classes (.tres) for authored content; JSON only at the wire

Use Godot **custom `Resource`** (`class_name`, `@export`, saved as `.tres`) for everything authored
in-project. Reasons [VERIFIED — gdquest save-game; shaggydev custom-resources; simondalvai;
godot-proposals#18]:

- **Static typing + inspector authoring.** `@export var voice_register: String`,
  `@export var skill_domain: SkillDomain` (enum), `@export var sprite_frames: SpriteFrames` — edited
  in the inspector, type-checked, no parse-and-validate boilerplate.
- **Native Godot types for free.** `Color` (the day/night palette HSVs), `Vector3`
  (`emotion_tint`), `Texture2D`, `SpriteFrames`, `PackedScene` references resolve directly — JSON
  would force manual reconstruction of every one of these.
- **Nested resources.** An `NPCDefinition.tres` can embed a `VoiceProfile` resource and reference
  `SpriteFrames` — matching the layered visual system in GRAPHICS.md.
- **Version-controllable.** `.tres` is text, diff-friendly. (Ship as `.res` binary later if load
  time matters; `.tres` for dev.) [VERIFIED — ezcha; medium/Mark]

```gdscript
# npc_definition.gd  [JUDGEMENT — illustrative]
class_name NPCDefinition
extends Resource

@export var npc_id: String                       # must match backend npc_id exactly (ARCH rule)
@export var display_name: String
@export var voice_register: String               # frozen in WORLD_STATE.md
@export var directional_angles: int = 4          # 4 or 8 (GRAPHICS.md)
@export var sprite_frames: SpriteFrames
@export var sprite_size_px: Vector2i = Vector2i(96, 128)   # 128x192 for primaries (Gap 9 fallback)
@export var emotion_tints: Dictionary            # state -> Color (mirrors GRAPHICS.md EMOTION_COLORS)
```

### 5.2 Where JSON still belongs

- **The wire format.** All backend traffic is JSON (ARCHITECTURE.md schemas: scene_text,
  event_text, cause_chain, etc.). Parse with `JSON.parse_string()` into Dictionaries at the
  boundary; do **not** try to deserialize directly into Resources from the network (validation +
  trust boundary). [JUDGEMENT]
- **Author-owned content shared with the backend.** The fallback event library is authored on the
  **backend** side as JSON (`/backend/enforcer/fallback_events.json`) and is the *server's* asset.
  The client never needs it unless an offline mode is designed — and ARCHITECTURE.md makes the
  backend authoritative, so the client should **not** keep its own copy. **Recommendation: do not
  mirror the fallback library client-side.** If a future degraded/offline mode requires it, import
  that same JSON at build time into `.tres` rather than maintaining two authored sources of truth.

### 5.3 The rule

> Authored, edited-in-Godot, references engine types → **custom Resource (.tres)**.
> Crosses the network or is owned by the backend → **JSON at the boundary, Dictionary at runtime**.

---

## 6. Client Persistence — Mirroring DynamoDB SessionState

ARCHITECTURE.md is unambiguous: **backend is authoritative; client is the rendering layer; on
divergence, backend wins; client re-syncs on next REST call; send deltas only.** The DynamoDB
tables (`player_session_state`, `player_choices`, `player_night_queue`, `player_arrivals`) are the
source of truth. So the client save model is deliberately **thin**.

### 6.1 What the client keeps locally

| Keep client-side (cache/convenience) | Why |
|---|---|
| Last-known `hot_state` snapshot (≤2KB, the ARCH `hot_state` blob) | Instant resume render before the authoritative re-sync lands. |
| Rendered world layout for the current session (building placements, NPC positions) | So the scene can redraw without a full server round-trip on resume. Re-validated against server on next REST. |
| `player_id` / Cognito session token (ARCH Phase 1 auth) | To re-auth and resume. Store in OS secure store, not plaintext save. [JUDGEMENT] |
| Local settings (audio, video, keybinds) | Pure client concern, never server. |

### 6.2 What stays authoritative server-side (do NOT trust the client copy)

- The **choice log** (`player_choices`) — the consequence/traceability backbone. Never
  reconstructed from a client save; the client can't be the source of truth for what caused a
  horror event (Pillar 1 integrity).
- **NPC relationship map, faction standings, knowledge_state, arc_state, output_modifier,
  gossip stages** — all consequence-engine state.
- The **night event queue** — pre-computed server-side, delivered over WS, durable in DynamoDB
  (24h TTL). Client buffers it for the session but does not persist it as truth.

### 6.3 Save/load mechanism

Use a Godot custom `Resource` (`SessionCache.tres` via `ResourceSaver`/`ResourceLoader`) **or** a
small JSON file under `user://` for the thin client cache. **Recommendation [JUDGEMENT]:** a single
`user://session_cache.tres` (custom Resource — consistent with §5, typed, includes a
`server_version`/`last_sync_ts` field). On launch: load cache → render immediately → fire a REST
re-sync → reconcile (**backend wins**, per ARCH) → patch the rendered world with any deltas. This
gives a fast warm resume without ever letting the client become authoritative.

```gdscript
# session_cache.gd  [JUDGEMENT]
class_name SessionCache
extends Resource
@export var player_id: String
@export var last_sync_ts: int               # epoch ms; compare to server, server wins
@export var day_cycle: int
@export var phase: String                    # "day" | "night" | "dawn"
@export var hot_state: Dictionary            # opaque ≤2KB mirror of ARCH hot_state
@export var rendered_buildings: Array        # [{building_id, type, coords}] for fast redraw
```

> **Anti-pattern to avoid:** building a full local save system that tries to replay the game
> offline. It would duplicate the consequence engine, drift from the server, and break Pillar 1/2
> (the whole point is that *the server* remembers and the world responds *specifically*). Keep the
> client a cache.

---

## Recommended Project Structure

[JUDGEMENT — a starting layout consistent with the frozen docs. The other worker is creating the
actual Godot project; this is a proposal, not a mandate.]

```
res://
├── project.godot                # Default Texture Filter = Nearest (§2.1)
├── autoload/                    # singletons (see autoload list below)
│   ├── BackendClient.gd
│   ├── NightFeed.gd
│   ├── SessionStore.gd
│   └── EventBus.gd
├── world/
│   ├── World.tscn               # Node3D root (GRAPHICS.md tree)
│   ├── CameraRig.tscn           # Rig→Yaw→SpringArm3D→Camera3D (§1)
│   ├── CameraDirector.gd        # scripted night snaps (§1.5)
│   └── environment/
│       ├── DayEnvironment.tres        # WorldEnvironment profile (GRAPHICS.md)
│       └── NightEnvironment.tres
├── npc/
│   ├── NPC.tscn                 # CharacterBody3D + VisualRoot layers (GRAPHICS.md)
│   ├── NPC.gd                   # apply_visual_state() (GRAPHICS.md two-tier)
│   └── npc_shader.gdshader      # parametric emotion/corruption/day-night shader
├── creatures/
│   ├── Walker.tscn  WalkerController.gd
│   └── Surveyor.tscn SurveyorController.gd
├── buildings/
│   ├── Building.tscn            # mesh + Area3D + 3-state material swap
│   └── states/                  # pristine/damaged/corrupted materials
├── ui/
│   ├── ObserveCursor.gd / PlaceCursor.gd   # two cursor modes (INTERACTION_MODEL §1)
│   ├── ContextPanel.tscn        # right-side NPC/faction panel (INTERACTION_MODEL §3–4)
│   └── NightLog.tscn            # bottom-left narrative log (GRAPHICS.md night UI)
├── data/                        # custom Resources (§5)
│   ├── npcs/        *.tres       (NPCDefinition)
│   ├── buildings/  *.tres        (BuildingDefinition)
│   ├── zones/      *.tres        (ZoneDefinition)
│   └── factions/   *.tres        (FactionDefinition)
├── phases/
│   ├── DayPhaseController.gd
│   ├── NightPhaseController.gd  # pause handling (§3)
│   └── TransitionController.gd  # 2.5s day→night tween (§1.6)
└── assets/                      # sprites, atlases, meshes, audio
```

### Autoload (singleton) list

| Autoload | Responsibility | Process mode |
|---|---|---|
| `EventBus` | Decoupled signals (choice made, night_ready, event delivered). | INHERIT |
| `BackendClient` | REST/HTTPRequest day calls, retry/timeout (§4.1). | ALWAYS (network survives pause) |
| `NightFeed` | WebSocket open/poll/buffer/close (§4.2). | ALWAYS (connection survives pause; delivery gated, §3.3) |
| `SessionStore` | Thin client cache + reconcile-on-resync (§6). | ALWAYS |
| `GameState` | Current phase/day, pause coordination, camera mode flag. | ALWAYS |

Rationale: networking and state singletons are `ALWAYS` so a pause never drops a connection or
stalls a re-sync; the **world** nodes (NPCs, creatures, camera) stay `PAUSABLE` so pausing freezes
the diorama (§3.2).

---

## Pillar Compliance

| Technical choice | Pillar served | How |
|---|---|---|
| Scripted night camera snap, player loses control (§1.5) | **2 — The Watched Feeling** | The camera looks at what matters, not what the player wants — the world directs the gaze. |
| Perspective (not ortho) at 40°, buildings loom (§1.3) | **1 — Earned Dread**, **4 — Day/Night** | "Marginal control / middle manager watching it go wrong" — the correct emotional distance for earned dread. |
| Billboard sprites + 3-channel emotion signal (§2) | **2 — The Watched Feeling**, **5 — Genre Whitespace** | Named NPCs must read as individually human at a glance; hand-drawn emotion is the Hades/DD intersection of horror+sim+drama. **Gated by Gap 9.** |
| Pause = frozen diorama, no menu (§3) | **4 — Day/Night (Unease)** | "You can stop time. You cannot look away." Pause is not a safe retreat. |
| `cause_chain` always rendered (§4.3) | **1 — Earned Dread**, **3 — Moral Weight** | Every horror event traces to a player choice; the client surfaces the chain (REVEAL_MECHANIC Option B). |
| Backend authoritative, client is a cache (§6) | **1**, **2** | The world's memory and specificity live server-side — the client cannot fake or replay consequence. |
| No moral color-coding / no confirmation in UI Resources (§5) | **3 — Moral Weight** | Authored content carries no good/evil labels; logistics feels mechanical until consequence surfaces (INTERACTION_MODEL §6). |

---

## Open Items / Could Not Fully Verify

- **Sprite3D exact property names** (`billboard`, `pixel_size`, `alpha_cut`, `texture_filter`,
  `shaded`): docs.godotengine.org returned HTTP 403 to automated fetch; these are standard Godot 4
  API and are already used in GRAPHICS.md, but confirm exact spelling/enum values in the running
  4.x editor before locking code. [API-KNOWLEDGE]
- **`BILLBOARD_FIXED_Y` vs `BILLBOARD_ENABLED`** for ground NPCs at 40° pitch (§2.1): a prototype
  feel decision; GRAPHICS.md currently specifies `BILLBOARD_ENABLED`. Flagged, not resolved.
- **SpringArm3D vs plain Arm node** (§1.2): GRAPHICS.md shows a plain Arm; SpringArm3D is an
  upgrade. Decide at prototype based on actual clip-through frequency.
- **Camera freeze-on-pause vs free-pan-on-pause** (§3.2): a design feel call, flagged for sign-off.
- **Godot version pin**: docs cited are "stable/latest" (4.x). Pin the exact minor version (e.g.
  4.3 / 4.4) at project creation; the WebSocket and pause APIs above are stable across recent 4.x,
  but `await`/HTTPRequest timeout behavior should be re-tested on the pinned version.

---

## Sources

- Isometric/strategy camera rig (separate rotation node): https://forum.godotengine.org/t/how-can-i-move-and-rotate-an-isometric-camera-in-3d/51832 ; https://dredyson.com/how-i-solved-the-player-root-node-rotation-without-rotating-the-springarm-camera-child-node-in-godot-3d-a-complete-step-by-step-fix-guide-for-third-person-character-control/
- SpringArm3D (collision pull-in): https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html ; https://supermatrix.studio/blog/camera-controller-and-spring-arm-3d-in-godot
- Camera3D / projection (perspective vs orthographic): https://docs.godotengine.org/en/stable/classes/class_camera3d.html ; https://docs.godotengine.org/en/stable/classes/class_projection.html ; https://forum.godotengine.org/t/camera-zoom-without-changing-perspective/76588
- Pixel-art texture filter / Sprite3D billboard: https://www.gdquest.com/library/pixel_art_setup_godot4/ ; https://forum.godotengine.org/t/pixel-perfect-textures-for-3d-objects/38858 ; https://godotshaders.com/shader/billboard-sprite3d-sway-godot-4-0/
- Godot Sprite3D class reference: https://docs.godotengine.org/en/stable/classes/class_sprite3d.html
- Sprite readability / emotion at small size: https://www.slynyrd.com/blog/2019/10/21/pixelblog-22-top-down-character-sprites ; https://anyflip.com/kdjou/llhc/basic/101-150 (Pixel Logic) ; https://medium.com/@AlainGalvan/pixel-art-design-for-game-dev-32d22c83a296 ; https://sprixen.com/blog/pixel-art-sizes-guide ; https://www.sprite-ai.art/blog/anime-pixel-art
- Pausing / process_mode: https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html ; https://github.com/godotengine/godot/issues/81994 (tween-during-pause)
- HTTPRequest await / timeout: https://dev.to/ziva/gdscripts-await-keyword-is-the-underused-way-to-kill-callback-hell-in-godot-1oei ; https://school.gdquest.com/glossary/keyword_await ; https://github.com/godotengine/godot-proposals/issues/1782
- WebSocketPeer: https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html ; https://github.com/godotengine/godot-docs/blob/master/tutorials/networking/websocket.rst ; https://github.com/godotengine/godot/issues/115384 (packets before close frame)
- Custom Resource vs JSON: https://www.gdquest.com/library/save_game_godot4/ ; https://shaggydev.com/2026/04/08/godot-custom-resources/ ; https://simondalvai.org/blog/godot-custom-resources/ ; https://github.com/godotengine/godot-proposals/issues/18 ; https://ezcha.net/news/3-1-23-custom-resources-are-op-in-godot-4
