extends Node

signal achievement_sound_started(achievement_id: String, is_secret: bool, stream_path: String)

const MUSIC_PATHS := {
	"menu": "res://assets/audio/main_menu.ogg",
	"room": "res://assets/audio/room.ogg",
	"dialogue": "res://assets/audio/dialogues.ogg",
	"credits": "res://assets/audio/titri.ogg",
	"tab_war": "res://assets/audio/tab_war_ost.ogg",
	"wire_puzzle": "res://assets/audio/wire_puzzle_ost.ogg",
	"file_investigation": "res://assets/audio/file_investigation_ost.ogg",
	"queue_and_trial": "res://assets/audio/queue_and_trial_ost.ogg"
}
const WALK_PATH := "res://assets/audio/walk.ogg"
const PC_PATH := "res://assets/audio/pc.ogg"
const CALL_SFX_PATHS := {
	"call_drx": "res://assets/audio/call_worker_drx.ogg",
	"call_tables": "res://assets/audio/call_mllf_table.ogg",
	"call_palych": "res://assets/audio/call_palich_wb.ogg"
}
const ACHIEVEMENT_SFX_PATHS := {
	"normal": "res://assets/audio/achievement.ogg",
	"secret": "res://assets/audio/achievement_rare.ogg"
}
const SILENCE_DB := -80.0

@export_range(0.0, 5.0, 0.05) var default_fade_duration := 1.0
@export_range(-24.0, 24.0, 0.5) var music_player_volume_db := -3.0
# The supplied effect recordings are 20-35 dB quieter than the music files.
# These are source-level corrections; the user's SFX slider still applies once
# on the SFX bus after this compensation.
@export_range(-24.0, 24.0, 0.5) var walk_volume_db := 16.0
@export_range(-24.0, 24.0, 0.5) var pc_volume_db := 12.0

var _music_players: Array[AudioStreamPlayer] = []
var _active_music: AudioStreamPlayer
var _music_state := ""
var _fade_tween: Tween
var _walk_player: AudioStreamPlayer
var _pc_player: AudioStreamPlayer
var _call_sfx_player: AudioStreamPlayer
var _achievement_sfx_player: AudioStreamPlayer
var _music_ducked_for_call := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % (index + 1)
		player.bus = &"Music"
		player.volume_db = SILENCE_DB
		add_child(player)
		_music_players.append(player)
	_walk_player = AudioStreamPlayer.new()
	_walk_player.name = "WalkSFX"
	_walk_player.bus = &"SFX"
	_walk_player.volume_db = walk_volume_db
	_walk_player.stream = _load_loop(WALK_PATH)
	add_child(_walk_player)
	_pc_player = AudioStreamPlayer.new()
	_pc_player.name = "ComputerSFX"
	_pc_player.bus = &"SFX"
	_pc_player.volume_db = pc_volume_db
	_pc_player.stream = load(PC_PATH)
	add_child(_pc_player)
	_call_sfx_player = AudioStreamPlayer.new()
	_call_sfx_player.name = "CallEventSFX"
	_call_sfx_player.bus = &"SFX"
	_call_sfx_player.volume_db = 0.0
	_call_sfx_player.finished.connect(_restore_music_after_call)
	add_child(_call_sfx_player)
	_achievement_sfx_player = AudioStreamPlayer.new()
	_achievement_sfx_player.name = "AchievementSFX"
	_achievement_sfx_player.bus = &"SFX"
	_achievement_sfx_player.volume_db = 0.0
	add_child(_achievement_sfx_player)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")

func _load_loop(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream

func play_music(state: String, fade_duration: float = -1.0) -> void:
	if not MUSIC_PATHS.has(state):
		push_warning("Unknown music state: " + state)
		return
	if _active_music != null and _music_state == state and _active_music.playing:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var target: AudioStreamPlayer
	for player in _music_players:
		if player.playing and str(player.get_meta("music_state", "")) == state:
			target = player
			break
	if target == null:
		if _active_music == null:
			target = _music_players[0]
		else:
			target = _music_players[1] if _active_music == _music_players[0] else _music_players[0]
		target.stop()
		target.stream = _load_loop(str(MUSIC_PATHS[state]))
		target.set_meta("music_state", state)
		target.volume_db = SILENCE_DB
		target.play()
	_active_music = target
	_music_state = state
	var duration := default_fade_duration if fade_duration < 0.0 else fade_duration
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_parallel(true)
	for player in _music_players:
		if player == target:
			var target_volume := SILENCE_DB if _music_ducked_for_call else music_player_volume_db
			_fade_tween.tween_property(player, "volume_db", target_volume, duration)
		elif player.playing:
			_fade_tween.tween_property(player, "volume_db", SILENCE_DB, duration)
	var expected_target := target
	_fade_tween.chain().tween_callback(func():
		if _active_music != expected_target:
			return
		for player in _music_players:
			if player != expected_target:
				player.stop()
	)

func stop_music(fade_duration: float = -1.0) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var duration := default_fade_duration if fade_duration < 0.0 else fade_duration
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	for player in _music_players:
		if player.playing:
			_fade_tween.tween_property(player, "volume_db", SILENCE_DB, duration)
	_fade_tween.chain().tween_callback(func():
		for player in _music_players:
			player.stop()
		_active_music = null
		_music_state = ""
	)

func set_walking(walking: bool) -> void:
	if _walk_player == null:
		return
	if walking:
		if not _walk_player.playing:
			_walk_player.play()
	elif _walk_player.playing:
		_walk_player.stop()

func play_pc_sfx() -> void:
	if _pc_player == null:
		return
	if _pc_player.playing:
		return
	_pc_player.play()

func stop_pc_sfx() -> void:
	if _pc_player != null and _pc_player.playing:
		_pc_player.stop()

func play_call_sfx(event_id: String) -> void:
	if _call_sfx_player == null or not CALL_SFX_PATHS.has(event_id):
		return
	var stream := load(str(CALL_SFX_PATHS[event_id])) as AudioStream
	if stream == null:
		push_warning("Call event sound not found: " + event_id)
		return
	_call_sfx_player.stop()
	_call_sfx_player.stream = stream
	_music_ducked_for_call = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	for player in _music_players:
		if player.playing:
			_fade_tween.tween_property(player, "volume_db", SILENCE_DB, 0.18)
	_call_sfx_player.play()

func play_achievement_sfx(is_secret: bool, achievement_id: String = "") -> void:
	if _achievement_sfx_player == null:
		return
	var key := "secret" if is_secret else "normal"
	var path := str(ACHIEVEMENT_SFX_PATHS[key])
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Achievement sound is missing: " + path)
		return
	_achievement_sfx_player.stop()
	_achievement_sfx_player.stream = stream
	_achievement_sfx_player.play()
	achievement_sound_started.emit(achievement_id, is_secret, path)

func _restore_music_after_call() -> void:
	if not _music_ducked_for_call:
		return
	_music_ducked_for_call = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	for player in _music_players:
		if not player.playing:
			continue
		var target_volume := music_player_volume_db if player == _active_music else SILENCE_DB
		_fade_tween.tween_property(player, "volume_db", target_volume, 0.45)
	_fade_tween.chain().tween_callback(func():
		for player in _music_players:
			if player != _active_music:
				player.stop()
	)

func set_music_volume(linear_value: float) -> void:
	_set_bus_volume("Music", linear_value)

func set_sfx_volume(linear_value: float) -> void:
	_set_bus_volume("SFX", linear_value)

func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var value := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, value <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))

func current_music_state() -> String:
	return _music_state

func is_walking_sfx_playing() -> bool:
	return _walk_player != null and _walk_player.playing

func is_pc_sfx_playing() -> bool:
	return _pc_player != null and _pc_player.playing
