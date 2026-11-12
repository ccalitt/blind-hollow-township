extends Node
## Audio — procedural sound bed (Autoload singleton).
##
## The project ships no audio assets, so every sound is synthesised into an
## AudioStreamWAV at startup. Three looping beds cross-fade with the phase clock
## (wind always; the mill by day; a low drone by night) and a handful of one-shot
## cues mark the structural beats (dusk, dawn, a night-log entry, a UI tick).
##
## NOT-THIS: no jump-scare stings. The night cue is quiet and identical every time;
## it marks that something was logged, it does not try to startle. The dread is in
## what the log says, not in the sound that accompanies it.
##
## Pillar 4: the player hears the clock (the mill stops at dusk) before any UI says so.

const RATE := 22050

var _wind: AudioStreamPlayer
var _mill: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _cues: Dictionary = {}          # name -> AudioStreamWAV
var _cue_players: Array[AudioStreamPlayer] = []
var _next_cue := 0
var _master_volume := 0.8
var _enabled := true
var _targets: Dictionary = {}       # player -> target linear volume


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless (tests / CI) has no audio device worth feeding; skip synthesis entirely.
	if DisplayServer.get_name() == "headless":
		_enabled = false
		return
	_wind = _make_loop(_synth_wind(6.0), -80.0)
	_mill = _make_loop(_synth_mill(4.0), -80.0)
	_drone = _make_loop(_synth_drone(8.0), -80.0)
	_cues = {
		"tick": _synth_tick(),
		"dusk": _synth_bell(146.8, 3.5),
		"dawn": _synth_bell(220.0, 2.5),
		"night": _synth_knock(),
		"page": _synth_page(),
	}
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_cue_players.append(p)
	_targets[_wind] = 0.35
	_targets[_mill] = 0.0
	_targets[_drone] = 0.0
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.night_event_fired.connect(func(_e): play_cue("night", 0.5))
	EventBus.dawn_thread_ready.connect(func(_e): play_cue("page", 0.4))


func set_master_volume(v: float) -> void:
	_master_volume = clampf(v, 0.0, 1.0)


func play_cue(cue_name: String, volume: float = 0.6) -> void:
	if not _enabled or not _cues.has(cue_name):
		return
	var p := _cue_players[_next_cue]
	_next_cue = (_next_cue + 1) % _cue_players.size()
	p.stream = _cues[cue_name]
	p.volume_db = linear_to_db(maxf(0.0001, volume * _master_volume))
	p.play()


## Called by the title screen / game to set the bed for a phase without a phase signal.
func set_bed(phase_name: String) -> void:
	if not _enabled:
		return
	match phase_name:
		"title":
			_targets[_wind] = 0.30; _targets[_mill] = 0.0; _targets[_drone] = 0.10
		"day":
			_targets[_wind] = 0.22; _targets[_mill] = 0.30; _targets[_drone] = 0.0
		"dusk":
			_targets[_wind] = 0.34; _targets[_mill] = 0.0; _targets[_drone] = 0.08
		"night":
			_targets[_wind] = 0.30; _targets[_mill] = 0.0; _targets[_drone] = 0.32
		"dawn":
			_targets[_wind] = 0.26; _targets[_mill] = 0.0; _targets[_drone] = 0.05


func _on_phase_changed(new_phase: int, _day: int) -> void:
	match new_phase:
		TimeManager.Phase.DAY:
			set_bed("day")
		TimeManager.Phase.DUSK:
			set_bed("dusk")
			play_cue("dusk", 0.5)
		TimeManager.Phase.NIGHT:
			set_bed("night")
		TimeManager.Phase.DAWN:
			set_bed("dawn")
			play_cue("dawn", 0.4)


func _process(delta: float) -> void:
	if not _enabled:
		return
	for p in _targets:
		var player: AudioStreamPlayer = p
		var cur := db_to_linear(player.volume_db)
		var target: float = float(_targets[p]) * _master_volume
		# Pause mutes the mill and the wind with the world, but the drone stays: the
		# frozen township is silent, not safe (Gap 5).
		if get_tree().paused and player != _drone:
			target = 0.0
		var next := move_toward(cur, target, delta * 0.25)
		player.volume_db = linear_to_db(maxf(0.0001, next))


# ── Synthesis ───────────────────────────────────────────────────────────────

func _make_loop(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	return p


func _to_wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Cross-fades the tail into the head so a noise loop has no audible seam.
func _seamless(samples: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := samples.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = samples[i]
	for i in fade:
		var t := float(i) / float(fade)
		out[i] = samples[i] * t + samples[n + i] * (1.0 - t)
	return out


func _synth_wind(seconds: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1101
	var fade := RATE / 2
	var n := int(seconds * RATE) + fade
	var s := PackedFloat32Array()
	s.resize(n)
	var low := 0.0
	var lower := 0.0
	for i in n:
		var white := rng.randf_range(-1.0, 1.0)
		low += (white - low) * 0.035
		lower += (low - lower) * 0.02
		var t := float(i) / RATE
		var gust := 0.55 + 0.45 * sin(t * TAU / seconds) * sin(t * TAU * 2.0 / seconds + 1.3)
		s[i] = (low * 0.6 + lower * 2.2) * gust * 1.6
	return _to_wav(_seamless(s, fade), true)


func _synth_mill(seconds: float) -> AudioStreamWAV:
	# A slow wheel thump and a thin saw whine. Period divides the loop exactly.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2203
	var n := int(seconds * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var beat := 1.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var bt := fmod(t, beat)
		var thump := sin(TAU * 58.0 * bt) * exp(-bt * 9.0) * 0.8
		var saw_phase := fmod(t * 310.0, 1.0)
		var whine := (saw_phase * 2.0 - 1.0) * 0.05 * (0.5 + 0.5 * sin(TAU * t / (seconds / 2.0)))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.2
		s[i] = thump + whine + lp * 0.05
	return _to_wav(s, true)


func _synth_drone(seconds: float) -> AudioStreamWAV:
	# Two low partials whose beat period divides the loop, plus a breath of noise.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3307
	var n := int(seconds * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var a := sin(TAU * 55.0 * t)
		var b := sin(TAU * 55.25 * t)
		var c := sin(TAU * 82.5 * t) * 0.35
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.01
		s[i] = (a + b) * 0.22 + c * 0.2 + lp * 0.6
	return _to_wav(s, true)


func _synth_tick() -> AudioStreamWAV:
	var n := int(0.05 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 900.0 * t) * exp(-t * 90.0) * 0.5
	return _to_wav(s, false)


func _synth_bell(freq: float, seconds: float) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 1.6)
		s[i] = (sin(TAU * freq * t) + 0.5 * sin(TAU * freq * 2.76 * t) * exp(-t * 3.0)
			+ 0.25 * sin(TAU * freq * 5.4 * t) * exp(-t * 6.0)) * env * 0.4
	return _to_wav(s, false)


func _synth_knock() -> AudioStreamWAV:
	# One dull knock on wood. The same every time.
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * (96.0 - t * 40.0) * t) * exp(-t * 14.0) * 0.9
	return _to_wav(s, false)


func _synth_page() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4409
	var n := int(0.35 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var hp_prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		var hp := white - hp_prev
		hp_prev = white
		s[i] = hp * sin(PI * t / 0.35) * 0.18
	return _to_wav(s, false)
