extends Node
## Plays sound effects, music and ambience. Autoload "AudioManager".
##
## Sounds are found by NAME in audio/sfx, audio/music and audio/ambience. An .ogg wins over a .wav, so a real sound
## replaces a placeholder by simply dropping a file with the same name there. The placeholders are made by
## tools/audio/generate_audio.py.
## Music and sound effects each have a volume (0..1) on their own audio bus; SaveManager keeps them in the save file.

const SFX_DIR: String = "res://audio/sfx/"
const MUSIC_DIR: String = "res://audio/music/"
const AMBIENCE_DIR: String = "res://audio/ambience/"
const EXTENSIONS: Array[String] = ["ogg", "wav"]
const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"
const VOICES: int = 16 # sounds that can play at the same time
const MIN_INTERVAL_MSEC: int = 45 # the same sound is not started more often than this
const MUSIC_DB: float = -9.0
const AMBIENCE_DB: float = -15.0
const SILENT_DB: float = -60.0

# Loudness trim per sound, in dB (everything else plays at 0).
const TRIM_DB: Dictionary = {
	"slash": -5.0, "slash_enemy": -4.0, "hit": -4.0, "dash": -4.0, "ultimate_tick": -8.0, "ui_click": -4.0,
	"gold": -6.0, "arrow": -5.0, "shuriken": -5.0, "blink": -5.0, "kaeshi_stance": -4.0, "door": -4.0,
}

var music_volume: float = 0.8
var sfx_volume: float = 0.8

var _cache: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_name: String = ""
var _ambience_name: String = ""
var _tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # menus and the pause screen keep their sounds
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	_music = _make_loop_player()
	_ambience = _make_loop_player()
	_apply_volumes()
	# Every button in the game clicks, without wiring each one by hand.
	get_tree().node_added.connect(_on_node_added)


# ---------------------------------------------------------------- sound effects

## Plays a sound effect by name. Returns the player (or null when the sound does not exist or is throttled).
func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_variation: float = 0.06) -> AudioStreamPlayer:
	var stream: AudioStream = _get_stream(SFX_DIR, sound_name)
	if stream == null:
		return null
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sound_name, -10000)) < MIN_INTERVAL_MSEC:
		return null
	_last_played[sound_name] = now
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES # the oldest voice is reused when all are busy
	voice.stream = stream
	voice.volume_db = float(TRIM_DB.get(sound_name, 0.0)) + volume_db
	voice.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	voice.play()
	return voice


# ---------------------------------------------------------------- music and ambience

## Fades to the named music loop. Asking for the track that already plays does nothing; "" stops the music.
func play_music(track_name: String, fade: float = 1.0) -> void:
	if track_name == _music_name:
		return
	_music_name = track_name
	_switch(_music, MUSIC_DIR, track_name, MUSIC_DB, fade)


func stop_music(fade: float = 1.0) -> void:
	play_music("", fade)


func play_ambience(track_name: String, fade: float = 2.0) -> void:
	if track_name == _ambience_name:
		return
	_ambience_name = track_name
	_switch(_ambience, AMBIENCE_DIR, track_name, AMBIENCE_DB, fade)


func stop_ambience(fade: float = 1.0) -> void:
	play_ambience("", fade)


func _switch(player: AudioStreamPlayer, folder: String, track_name: String, target_db: float, fade: float) -> void:
	if _tweens.has(player) and _tweens[player].is_valid():
		_tweens[player].kill()
	var tween := create_tween()
	_tweens[player] = tween
	if player.playing:
		tween.tween_property(player, "volume_db", SILENT_DB, fade * 0.5)
	tween.tween_callback(func() -> void:
		var stream: AudioStream = _get_stream(folder, track_name) if track_name != "" else null
		if stream == null:
			player.stop()
			return
		_make_looping(stream)
		player.stream = stream
		player.volume_db = SILENT_DB
		player.play())
	if track_name != "":
		tween.tween_property(player, "volume_db", target_db, fade * 0.5)


# ---------------------------------------------------------------- volume (0..1)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func to_dict() -> Dictionary:
	return {"music_volume": music_volume, "sfx_volume": sfx_volume}


func from_dict(data: Dictionary) -> void:
	music_volume = clampf(float(data.get("music_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.8)), 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


# ---------------------------------------------------------------- helpers

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _make_loop_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = MUSIC_BUS
	player.volume_db = SILENT_DB
	add_child(player)
	return player


## Loads audio/<folder>/<name>.ogg or .wav (cached). A missing sound warns once and is then ignored.
func _get_stream(folder: String, sound_name: String) -> AudioStream:
	var key: String = folder + sound_name
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	for extension in EXTENSIONS:
		var path: String = "%s%s.%s" % [folder, sound_name, extension]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream == null:
		push_warning("AudioManager: no sound named '%s' in %s" % [sound_name, folder])
	_cache[key] = stream
	return stream


func _make_looping(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play_sfx("ui_click", 0.0, 0.03)
