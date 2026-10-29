extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func inspect_stream(path: String) -> void:
	var stream := load(path) as AudioStream
	print(path, " length=", stream.get_length())
	var playback := stream.instantiate_playback()
	playback.start()
	var peak := 0.0
	var energy := 0.0
	var sample_count := 0
	var first_audible_frame := -1
	var frame_cursor := 0
	for block in range(2000):
		var frames: PackedVector2Array = playback.mix_audio(1.0, 1024)
		if frames.is_empty():
			break
		for frame in frames:
			var level: float = maxf(absf(frame.x), absf(frame.y))
			peak = maxf(peak, level)
			energy += frame.x * frame.x + frame.y * frame.y
			if first_audible_frame < 0 and level > 0.001:
				first_audible_frame = frame_cursor
			frame_cursor += 1
			sample_count += 2
		if not playback.is_playing():
			break
	var rms := sqrt(energy / maxf(float(sample_count), 1.0))
	print(path, " peak=", peak, " rms=", rms, " first_audible_frame=", first_audible_frame, " mixed_frames=", frame_cursor)

func run() -> void:
	inspect_stream("res://assets/audio/walk.ogg")
	inspect_stream("res://assets/audio/pc.ogg")
	inspect_stream("res://assets/audio/main_menu.ogg")
	inspect_stream("res://assets/audio/room.ogg")
	inspect_stream("res://assets/audio/dialogues.ogg")
	quit()
