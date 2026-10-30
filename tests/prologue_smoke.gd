extends SceneTree

var failures: Array[String]=[]
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: ",description)
	else:
		failures.append(description)
		push_error(description)

func screenshot(file: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+file)

func finish_dialogue() -> void:
	var guard := 0
	while game.dialogue_open and guard<20:
		game._advance_dialogue()
		guard+=1
	check(guard<20,"Dialogue terminates")

func key_event(key: int, pressed: bool=true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode=key
	e.keycode=key
	e.pressed=pressed
	return e

func run() -> void:
	var scene := load("res://Prologue.tscn") as PackedScene
	game=scene.instantiate()
	game.save_path="res://tests/test_progress_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await process_frame
	await screenshot("prologue-menu.png")
	check(game.mode=="menu" and game.step==0,"New prologue starts at menu")
	check(game.sprite.sprite_frames.get_animation_names().size()==8,"Four walk and four idle animations exist")
	for direction in ["down","left","right","up"]:
		check(game.sprite.sprite_frames.get_frame_count("walk_"+direction)==4,"Four frames for "+direction)
	game.resume_game()
	check(game.dialogue_open,"Introduction opens")
	await screenshot("prologue-intro.png")
	finish_dialogue()
	await screenshot("prologue-room.png")
	game.player.position=Vector2(370,320)
	Input.parse_input_event(key_event(KEY_D))
	for i in range(15):
		await physics_frame
	Input.parse_input_event(key_event(KEY_D,false))
	check(game.player.position.x>375,"Animated character moves")
	game.nearby_object="phone"
	game._unhandled_input(key_event(KEY_E))
	check(game.flow=="voice" and game.dialogue_index==0,"One E opens one interaction without skipping a line")
	finish_dialogue()
	check(game.step==1,"Voice message unlocks project")
	check(game.mode=="friends_chat" and game.phone_panel.visible,"Voice message opens the preserved friends phone chat")
	game._unhandled_input(key_event(KEY_ESCAPE))
	check(game.mode=="room" and not game.phone_panel.visible,"Esc closes phone chat before using the computer")
	game.nearby_object="computer"
	game._unhandled_input(key_event(KEY_E))
	check(game.mode=="desktop","Computer opens")
	game._open_app("grok")
	check(game.step==1,"Grok cannot skip prologue")
	game.show_desktop()
	game._open_app("project")
	finish_dialogue()
	check(game.step==2,"Missing key unlocks Blender")
	game._open_app("blender")
	await screenshot("prologue-blender.png")
	game.begin_flow("blender")
	finish_dialogue()
	game._open_app("jbt")
	await screenshot("prologue-jbt.png")
	finish_dialogue()
	check(game.step==4 and game.consultations==1,"Script obtained from JBT")
	game._open_app("search")
	game.submit_search()
	check(game.step==4 and not game.dialogue_open,"Empty search does not advance")
	game.search_input.text="import bpy; bpy.ops.mesh.primitive_cylinder_add(vertices=16)"
	await screenshot("prologue-search.png")
	game.submit_search()
	finish_dialogue()
	check(game.step==5,"Pasted Blender code fails in search")
	game._open_app("jbt")
	finish_dialogue()
	game._open_app("jbt")
	finish_dialogue()
	check(game.step==7 and game.consultations==3,"Prompt for Grok obtained after three consultations")
	game._open_app("grok")
	finish_dialogue()
	check(game.step==8 and game.mode=="ending","Prologue ends before chapter one")
	await screenshot("prologue-ending.png")
	var restored=scene.instantiate()
	restored.save_path=game.save_path
	root.add_child(restored)
	check(restored.step==8 and restored.consultations==3,"Prologue save restores")
	restored.queue_free()
	await process_frame
	game._close_computer()
	game.show_notebook()
	game.go_back()
	check(game.mode=="room","Portable notebook returns to room")
	game.player.position=Vector2(568,300)
	Input.parse_input_event(key_event(KEY_W))
	for i in range(70):
		await physics_frame
	Input.parse_input_event(key_event(KEY_W,false))
	check(game.player.position.y>250,"Computer collision blocks movement")
	check(game._get_nearby_object()=="computer","Computer interaction is reachable from front")
	check(not game.get_node("Bed/CollisionShape2D").disabled,"Bed collision is enabled")
	var desk=game.get_node("Computer/DeskSprite")
	check(desk is AnimatedSprite2D and desk.sprite_frames.get_frame_count("screen")==2,"Computer uses two animation frames")
	game.update_computer_screen()
	check(desk.frame==1 and not desk.is_playing(),"Screen lights when player approaches")
	for i in range(40):
		await physics_frame
	check(desk.frame==1,"Screen stays lit without blinking")
	game.player.position=Vector2(450,340)
	game.update_computer_screen()
	check(desk.frame==0,"Screen turns off when player leaves")
	game.player.position=Vector2(662,280)
	game.update_computer_screen()
	var wardrobe=game.get_node("Wardrobe/WardrobeSprite")
	check(wardrobe.frame==1 and not wardrobe.is_playing(),"Wardrobe opens on approach without looping")
	await screenshot("wardrobe-open.png")
	game.player.position=Vector2(450,340)
	game.update_computer_screen()
	check(wardrobe.frame==0,"Wardrobe closes on departure")
	game.player.position=Vector2(619,362)
	check(game._get_nearby_object()=="phone","Phone on cabinet is reachable")
	game.player.position=Vector2(618,330)
	check(game._get_nearby_object()=="pizza","Pizza has separate reachable interaction")
	game.player.position=Vector2(526,330)
	Input.parse_input_event(key_event(KEY_W))
	for i in range(35):
		await physics_frame
	Input.parse_input_event(key_event(KEY_W,false))
	var chair_collider: CollisionShape2D = game.get_node("Chair/CollisionShape2D")
	var feet_collider: CollisionShape2D = game.player.get_node("CollisionShape2D")
	var chair_bottom: float = chair_collider.global_position.y + chair_collider.shape.size.y * 0.5
	var chair_stop: float = chair_bottom + feet_collider.shape.radius - feet_collider.position.y
	check(absf(game.player.position.y-chair_stop)<0.5,"Office chair blocks walking at its current base")
	game.player.position=Vector2(646,403)
	Input.parse_input_event(key_event(KEY_W))
	for i in range(25):
		await physics_frame
	Input.parse_input_event(key_event(KEY_W,false))
	check(game.player.position.y>=393.8,"Side cabinet has working collision")
	game.player.position=Vector2(356,235)
	Input.parse_input_event(key_event(KEY_W))
	for i in range(35):
		await physics_frame
	Input.parse_input_event(key_event(KEY_W,false))
	check(game._get_nearby_object()=="poster","Poster stays reachable beside furniture")
	for furniture in ["Bed","Computer","Wardrobe"]:
		var object=game.get_node(furniture)
		var shape=object.get_node("CollisionShape2D")
		var back: float=shape.global_position.y-shape.shape.size.y/2
		check(absf(back-184)<0.1,"No gap behind "+furniture)
	# Reach all four walls and corners from unobstructed lanes. Assert the
	# entire 8px feet collider stays inside the visible 448x224 floor.
	var routes := [
		[Vector2(390,260),[KEY_W]], [Vector2(390,350),[KEY_S]],
		[Vector2(390,370),[KEY_A]], [Vector2(600,320),[KEY_D]],
		[Vector2(350,350),[KEY_A,KEY_S]], [Vector2(600,320),[KEY_D,KEY_S]],
		[Vector2(270,215),[KEY_A,KEY_W]], [Vector2(695,300),[KEY_D,KEY_W]]
	]
	for route in routes:
		game.player.position=route[0]
		for key in route[1]:
			Input.parse_input_event(key_event(key))
		for i in range(90):
			await physics_frame
		for key in route[1]:
			Input.parse_input_event(key_event(key,false))
		var centre: Vector2=game.player.position+Vector2(0,-6)
		check(centre.x>=263.8 and centre.x<=696.2 and centre.y>=191.8 and centre.y<=400.2,"Feet stay inside visible floor on route "+str(route[1]))
	game.player.position=Vector2(300,366)
	Input.parse_input_event(key_event(KEY_W))
	for i in range(50):
		await physics_frame
	Input.parse_input_event(key_event(KEY_W,false))
	# The author's new bed ends at world y=309, rather than the old y=312.
	# Verify that walking actually reaches and stops at the current footprint.
	var bed_collision: CollisionShape2D = game.get_node("Bed/CollisionShape2D")
	var player_collision: CollisionShape2D = game.player.get_node("CollisionShape2D")
	var bed_rectangle := bed_collision.shape as RectangleShape2D
	var player_circle := player_collision.shape as CircleShape2D
	var bed_bottom := (bed_collision.global_transform * Vector2(0, bed_rectangle.size.y * 0.5)).y
	var expected_stop := bed_bottom + player_circle.radius - player_collision.position.y
	check(absf(game.player.position.y - expected_stop) < 0.5,"Current bed footprint blocks movement at its lower edge")
	game.player.position=Vector2(450,340)
	await screenshot("prologue-room-compact.png")
	DirAccess.remove_absolute(game.save_path)
	game.queue_free()
	await process_frame
	print("PROLOGUE RESULT: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
