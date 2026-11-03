extends Node


func _ready() -> void:
	var world := World.new()
	world.name = "World"
	add_child(world)
	var ui := UiRoot.new()
	ui.name = "UI"
	ui.world = world
	add_child(ui)
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke(world)
	elif "--shots" in OS.get_cmdline_user_args():
		_shots(world, ui)


func _smoke(world: World) -> void:
	await get_tree().create_timer(0.2).timeout
	if Catalog.modules().size() != 10 or Catalog.creatures().size() != 6:
		push_error("catalog size")
		get_tree().quit(2)
		return
	var beetle := ModelUtil.instantiate("creatures", "01_ram_beetle")
	var player := beetle.find_child("AnimationPlayer", true, false)
	var skeleton := beetle.find_child("Skeleton3D", true, false)
	var bones := 0
	if skeleton is Skeleton3D:
		bones = (skeleton as Skeleton3D).get_bone_count()
	print("RIG bones=", bones, " clips=", (player as AnimationPlayer).get_animation_list() if player else [])
	if bones < 6:
		push_error("creature rig missing")
		get_tree().quit(3)
		return
	if Catalog.creature("06_bloated_tick").get("role", "") != "bomb":
		push_error("roles missing")
		get_tree().quit(4)
		return
	if Catalog.wave_script(1).is_empty():
		push_error("wave script missing")
		get_tree().quit(4)
		return
	world.start_run(true)
	world.tower.set_stud(-2)
	world._sync_ghost()
	if world.tower.would_improve("05_kaiju_bust"):
		push_error("bad stud still balances")
		get_tree().quit(1)
		return
	world.tower.set_stud(1)
	world._sync_ghost()
	var before := world.tower.horizontal_com()
	var ghost := world.tower.ghost_good
	if not ghost or world.tower.preview_offset().length() < 0.2:
		push_error("counter stud")
		get_tree().quit(1)
		return
	world.slide(0.0)
	await get_tree().create_timer(0.15).timeout
	if not world.request_drop():
		world.add_yaw(0.9)
		world.request_drop()
	await get_tree().create_timer(1.1).timeout
	var stack_n := world.tower.stack.size()
	var tilt := world.tower.tilt_deg()
	print("SMOKE stack=", stack_n, " tilt=", snappedf(tilt, 0.01), " alive=", world.tower.alive, " tutorial=", world._tutorial, " ghost=", ghost, " improved=", world.tower.last_improved, " com=", snappedf(before, 0.001), "->", snappedf(world.tower.horizontal_com(), 0.001))
	if stack_n < 2 or not world.tower.alive or not ghost or not world.tower.last_improved or world.tower.last_offset.length() < 0.2:
		get_tree().quit(1)
		return
	if world.bosses_spawned != 0:
		push_error("boss during tutorial")
		get_tree().quit(5)
		return
	var saved_splash := GameState.plant_splash
	GameState.plant_splash = false
	world.tower.begin(1.0, 1.0, 1.0, false)
	if world.tower.splash_cannon:
		get_tree().quit(6)
		return
	GameState.plant_splash = true
	world.tower.begin(1.0, 1.0, 1.0, false)
	if not world.tower.splash_cannon:
		get_tree().quit(6)
		return
	GameState.plant_splash = saved_splash
	world.tower._place_now("02_side_cannon", false)
	var cannon: Dictionary = world.tower.stack.back()
	var muzzle: Vector3 = world.tower._muzzle(cannon, 0)
	var mid := Vector3(0, float(cannon.base_y) + float(cannon.height) * 0.5, 0)
	if muzzle.distance_to(world.tower._lean.global_transform * mid) < 0.2:
		push_error("muzzle")
		get_tree().quit(6)
		return
	world._clear_enemies()
	world._spawn("01_ram_beetle", false)
	var spawned := world._enemies.get_child(world._enemies.get_child_count() - 1) as Enemy
	if spawned.position.z > -4.0:
		push_error("spawn facing")
		get_tree().quit(7)
		return
	spawned.position = Vector3(0, 0, -1.0)
	spawned.tick(0.05, world.tower)
	if spawned.clip_name() == "move":
		push_error("idle clip")
		get_tree().quit(7)
		return
	var bug := spawned
	bug.position = Vector3(0, 1.0, 1.2)
	world.missile_bursts = 0
	world.cannon_shots = 0
	world._shoot([{
		"from": Vector3(0, 1.0, 0),
		"to": Vector3(0, 1.0, 1.2),
		"speed": 40.0,
		"damage": 4.0,
		"splash": 1.2,
		"beam": false,
		"style": "missile",
	}])
	for _step in 8:
		world._bullets(0.02)
	var missile_fx := world.missile_bursts
	world._shoot([{
		"from": Vector3(0, 1.0, 0),
		"to": Vector3(0, 1.0, 1.2),
		"speed": 40.0,
		"damage": 4.0,
		"splash": 0.0,
		"beam": false,
		"style": "cannon",
	}])
	for _step in 8:
		world._bullets(0.02)
	if missile_fx < 1 or world.missile_bursts != missile_fx:
		push_error("missile fx")
		get_tree().quit(7)
		return
	var vel_before := world.tower.vel_x
	world._spawn("06_bloated_tick", false)
	var tick := world._enemies.get_child(world._enemies.get_child_count() - 1) as Enemy
	tick.position = Vector3(1.2, 0.4, 0.2)
	tick.take_damage(9999.0, 0.0)
	for _step in 12:
		tick.tick(0.05, world.tower)
	if world.tick_pushes < 1:
		push_error("tick push")
		get_tree().quit(8)
		return
	world._tutorial = -1
	world.tutorial_mode = false
	world.wave = 1
	while world._enemies.get_child_count() > 0:
		var leftover := world._enemies.get_child(0)
		world._enemies.remove_child(leftover)
		leftover.free()
	world._card_left = 0.0
	world._clear_left = 0.0
	world._awaiting_choice = false
	world.card_count = 0
	world._arm_wave()
	world._waves(0.01)
	if world.card_count < 1 or world._enemies.get_child_count() != 0:
		push_error("wave card")
		get_tree().quit(9)
		return
	GameState.music_on = true
	AudioDirector.start()
	AudioDirector.set_mood(true, false)
	AudioDirector._apply_layers()
	var drive_on := AudioDirector._drive.volume_db > -40.0
	var bass_on := AudioDirector._music.playing
	get_tree().paused = true
	AudioDirector._apply_layers()
	var drive_paused := AudioDirector._drive.volume_db < -40.0
	var bass_held := AudioDirector._music.playing
	get_tree().paused = false
	AudioDirector._apply_layers()
	var drive_back := AudioDirector._drive.playing and AudioDirector._drive.volume_db > -40.0
	print("AUDIO drive=", drive_on, " bass=", bass_on, " paused=", drive_paused, " held=", bass_held, " back=", drive_back, " tick=", world.tick_pushes, " vel=", vel_before)
	if not drive_on or not bass_on or not drive_paused or not bass_held or not drive_back:
		get_tree().quit(10)
		return
	world.wave = 2
	world._light_streak = 2
	var forced: Dictionary = world._roll()
	if not (str(forced.id) in Catalog.HEAVY_IDS):
		push_error("light streak")
		get_tree().quit(11)
		return
	if str(Catalog.wave_script(2).get("card", "")) != "wave_beetles_4":
		push_error("wave 2 card")
		get_tree().quit(12)
		return
	world.held = {}
	world.queue.clear()
	world._tutorial = -1
	world.wave = 1
	world.running = true
	world._gen_offered = false
	world._fill_queue()
	if world.queue.size() != 3:
		push_error("offer size")
		get_tree().quit(13)
		return
	var saw_gun := false
	var saw_heavy := false
	for piece in world.queue:
		var oid := str(piece.id)
		if oid in ["02_side_cannon", "03_twin_guns"]:
			saw_gun = true
		if oid in Catalog.HEAVY_IDS:
			saw_heavy = true
	if not saw_gun or not saw_heavy:
		push_error("offer bias")
		get_tree().quit(13)
		return
	world.choose_offer(0)
	if not world.queue.is_empty() or world.held.is_empty():
		push_error("offer pick")
		get_tree().quit(13)
		return
	world.tower.begin(1.0, 1.0, 1.0, false)
	world.tower._place_now("05_kaiju_bust", false)
	world.tower._place_now("02_side_cannon", false)
	world.tower._tick_energy(0.6)
	if bool(world.tower.stack[2].get("lit", false)):
		push_error("cannon lit through statue")
		get_tree().quit(14)
		return
	world.tower._place_now("04_generator", false)
	world.tower._tick_energy(0.5)
	if not bool(world.tower.stack[2].get("lit", false)):
		push_error("cannon dark beside generator")
		get_tree().quit(14)
		return
	world.tower._place_now("09_crystal_spur", false)
	world.tower._tick_energy(0.2)
	if world.tower.wire_count() < 1:
		push_error("wire")
		get_tree().quit(14)
		return
	var z_before := world.tower.vel_z
	world.tower.apply_hit(Vector3(0, 0, -3), 3.0, 0.2)
	if absf(world.tower.vel_z - z_before) < 0.01:
		push_error("z shove")
		get_tree().quit(15)
		return
	var dusk_was := GameState.dusk_open
	var coins_was := GameState.coins
	world.running = true
	world.won = false
	world._banked = false
	world.endless = false
	world.chapter = "meadow"
	world.wave = 10
	world._tutorial = -1
	world._relic_pending = false
	world._awaiting_relic = false
	world.chest_open = false
	world._breath = 0.0
	world._clear_sent = true
	world._clear_left = 0.05
	world._card_left = 0.0
	world._card_pending = false
	world._waves(0.1)
	if not world.won:
		push_error("victory")
		get_tree().quit(16)
		return
	GameState.dusk_open = dusk_was
	GameState.coins = coins_was
	GameState.save_game()
	print("SMOKE_OK")
	get_tree().quit(0)


func _shots(world: World, ui: UiRoot) -> void:
	await get_tree().create_timer(0.6).timeout
	GameState.dusk_open = false
	ui._refresh_copy()
	_grab("menu")
	ui._start(true)
	world.tower.set_stud(1)
	world._sync_ghost()
	world.slide(0.0)
	await get_tree().create_timer(0.45).timeout
	_grab("stud")
	world._tutorial = -1
	ui._tutorial.visible = false
	world._spawn("01_ram_beetle", false)
	var early := world._enemies.get_child(world._enemies.get_child_count() - 1)
	if early is Node3D:
		early.position = Vector3(0.0, 0.15, -2.6)
		early.rotation.y = PI
	if world.tower._ghost:
		world.tower._ghost.visible = false
	await get_tree().create_timer(0.35).timeout
	_grab("path")
	if early is Node3D:
		early.visible = false
	world.held = {}
	world.queue.clear()
	world.wave = 2
	world._gen_offered = false
	world._fill_queue()
	await get_tree().create_timer(0.25).timeout
	_grab("offer")
	world.choose_offer(0)
	await get_tree().create_timer(0.25).timeout
	_grab("held")
	world.held = {}
	ui._queue_sig = ""
	ui._paint_queue()
	if world.tower._ghost:
		world.tower._ghost.visible = false
	world.tower._place_now("05_kaiju_bust", false)
	world.tower._place_now("02_side_cannon", false)
	world.tower._tick_energy(0.05)
	await get_tree().create_timer(0.15).timeout
	_grab("dark")
	world.tower._place_now("04_generator", false)
	world.tower._place_now("09_crystal_spur", false)
	world.tower._tick_energy(0.45)
	await get_tree().create_timer(0.2).timeout
	_grab("lit")
	world.wave = 1
	world._start_breath()
	await get_tree().create_timer(0.2).timeout
	_grab("wave")
	get_tree().paused = true
	world.tower.tilt_z = 0.34
	world.tower.tilt_x = 0.05
	ui._meter.queue_redraw()
	await get_tree().create_timer(0.05, true).timeout
	_grab("bubble")
	get_tree().paused = false
	ui._on_victory()
	await get_tree().create_timer(0.2).timeout
	_grab("victory")
	get_tree().quit(0)


func _grab(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "res://build/shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	img.save_png(ProjectSettings.globalize_path(path + "/" + name + ".png"))
