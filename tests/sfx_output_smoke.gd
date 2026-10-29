extends SceneTree

var failures: Array[String] = []
var audio_manager: Node
var capture: AudioEffectCapture
var sfx_bus := -1

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error(description)

func captured_peak() -> float:
	var peak := 0.0
	var frames := capture.get_buffer(capture.get_frames_available())
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak

func run() -> void:
	audio_manager = root.get_node("AudioManager")
	sfx_bus = AudioServer.get_bus_index("SFX")
	var previous_db := AudioServer.get_bus_volume_db(sfx_bus)
	var previous_mute := AudioServer.is_bus_mute(sfx_bus)
	AudioServer.set_bus_mute(sfx_bus, false)
	AudioServer.set_bus_volume_db(sfx_bus, 0.0)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(sfx_bus, capture)
	await create_timer(0.1).timeout
	var pc_player := audio_manager.get_node("ComputerSFX") as AudioStreamPlayer
	audio_manager.play_pc_sfx()
	await create_timer(0.2).timeout
	var first_position := pc_player.get_playback_position()
	audio_manager.play_pc_sfx()
	await create_timer(0.1).timeout
	check(pc_player.get_playback_position() > first_position, "Repeated computer updates do not restart its sound")
	check(captured_peak() > 0.03, "Computer SFX reaches the audible output bus")
	audio_manager.stop_pc_sfx()
	capture.clear_buffer()
	audio_manager.set_walking(true)
	await create_timer(0.25).timeout
	check(captured_peak() > 0.03, "Walking SFX reaches the audible output bus")
	audio_manager.set_walking(false)
	check(not audio_manager.is_walking_sfx_playing(), "Walking SFX stops with movement")
	AudioServer.remove_bus_effect(sfx_bus, AudioServer.get_bus_effect_count(sfx_bus) - 1)
	AudioServer.set_bus_volume_db(sfx_bus, previous_db)
	AudioServer.set_bus_mute(sfx_bus, previous_mute)
	print("SFX OUTPUT RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
