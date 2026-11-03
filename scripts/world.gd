class_name World
extends Node3D

signal fell
signal chest_ready
signal tutorial_step(step: int)
signal wind_warning(dir: Vector2)

var tower: Tower
var running := false
var wave := 1
var kills := 0
var balance_hits := 0
var score := 0
var revives_used := false
var last_earned := 0
var chest_open := false
var tutorial_mode := false
var queue: Array[Dictionary] = []

var _enemies: Node3D
var _cam: Camera3D
var _pool: Array[MeshInstance3D] = []
var _live: Array[Dictionary] = []
var _beam: MeshInstance3D
var _beam_life := 0.0
var _spawn_cd := 1.2
var _wave_time := 0.0
var _light_streak := 0
var _next_epic := false
var _pending_daily := false
var _tutorial := -1
var _yaw_mark := 0.0
var _wind_cd := 7.0
var _wind_left := 0.0
var _wind_dir := Vector2.RIGHT
var _best_ring: MeshInstance3D


func _ready() -> void:
	Catalog.ensure()
	_build_scene()
	tower = Tower.new()
	tower.name = "Tower"
	add_child(tower)
	tower.balance_hit.connect(_on_balance)
	tower.collapsed.connect(_on_collapsed)
	_enemies = Node3D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_build_pool()


func start_run(is_tutorial: bool) -> void:
	_clear_enemies()
	_clear_bullets()
	wave = 1
	kills = 0
	balance_hits = 0
	score = 0
	revives_used = false
	last_earned = 0
	chest_open = false
	tutorial_mode = is_tutorial
	_light_streak = 0
	_next_epic = false
	_pending_daily = false
	_spawn_cd = 2.0
	_wave_time = 0.0
	_wind_cd = 6.0
	_wind_left = 0.0
	queue.clear()
	running = true
	GameState.runs += 1
	GameState.save_game()
	tower.begin(
		GameState.multiplier("statue"),
		GameState.multiplier("cannon"),
		GameState.multiplier("generator"),
		is_tutorial
	)
	var daily := GameState.consume_daily()
	_fill_queue()
	if is_tutorial:
		_tutorial = 0
		_yaw_mark = tower.yaw
		queue[0] = {"id": "05_kaiju_bust", "epic": false}
		_pending_daily = daily
		tutorial_step.emit(0)
	else:
		_tutorial = -1
		if daily and queue.size() > 0:
			queue[0].epic = true
	_sync_ghost()
	_place_camera(true)


func request_drop() -> bool:
	if not running or chest_open or queue.is_empty():
		return false
	if _tutorial == 0:
		return false
	var piece: Dictionary = queue[0]
	if not tower.drop(str(piece.id), bool(piece.epic)):
		return false
	queue.pop_front()
	_fill_queue()
	_sync_ghost()
	if _tutorial == 1:
		_tutorial = 2
		_spawn("01_ram_beetle", false)
		tutorial_step.emit(2)
	return true


func add_yaw(delta: float) -> void:
	if not running:
		return
	tower.add_yaw(delta)
	if _tutorial == 0 and abs(tower.yaw - _yaw_mark) > 0.5:
		_tutorial = 1
		tutorial_step.emit(1)


func apply_freeze() -> void:
	tower.freeze()


func grant_epic() -> void:
	_next_epic = true
	if queue.size() > 0:
		queue[0].epic = true
		_next_epic = false
	_sync_ghost()


func close_chest() -> void:
	chest_open = false
	_advance_wave()


func revive_run() -> void:
	if revives_used:
		return
	revives_used = true
	running = true
	tower.revive()
	for node in _enemies.get_children():
		if node is Enemy and node.global_position.length() < 3.4:
			node.queue_free()


func _physics_process(delta: float) -> void:
	if not running or tower == null:
		return
	tower.tutorial = _tutorial >= 0
	tower.tick(delta, _enemies.get_children())
	_shoot(tower.shots)
	_bullets(delta)
	_enemies_tick(delta)
	if _tutorial < 0 and not chest_open:
		_waves(delta)
		_wind(delta)
	_camera(delta)
	_best_marker()
	score = tower.height_blocks() * 10 + kills * 5 + balance_hits * 10


func _waves(delta: float) -> void:
	var duration := 16.0 + float(wave) * 1.2
	_wave_time += delta
	_spawn_cd -= delta
	if _spawn_cd <= 0.0 and _enemies.get_child_count() < 10 and _wave_time < duration:
		_spawn_random()
		_spawn_cd = maxf(1.15, 3.55 - float(wave) * 0.18)
	if _wave_time >= duration and _enemies.get_child_count() == 0:
		if wave % 3 == 0:
			chest_open = true
			chest_ready.emit()
			_wave_time = 0.0
		else:
			_advance_wave()


func _advance_wave() -> void:
	wave += 1
	_wave_time = 0.0
	_spawn_cd = 1.4


func _wind(delta: float) -> void:
	if wave < 6:
		return
	if _wind_left > 0.0:
		_wind_left -= delta
		if _wind_left <= 0.0:
			tower.apply_wind(_wind_dir, 0.2 + float(wave) * 0.012)
		return
	_wind_cd -= delta
	if _wind_cd <= 0.0:
		_wind_dir = Vector2.from_angle(randf() * TAU)
		_wind_left = 1.0
		_wind_cd = 8.5
		wind_warning.emit(_wind_dir)


func _spawn_random() -> void:
	var pool: Array[String] = []
	for id in Catalog.creatures().keys():
		if int(Catalog.creature(id).unlock_wave) <= wave:
			pool.append(id)
	if pool.is_empty():
		pool.append("01_ram_beetle")
	var elite := wave >= 4 and randf() < 0.18
	_spawn(pool[randi() % pool.size()], elite)


func _spawn(id: String, elite: bool) -> void:
	var def := Catalog.creature(id)
	if def.is_empty():
		return
	var enemy := Enemy.new()
	_enemies.add_child(enemy)
	enemy.setup(def, wave, elite)
	var ang := randf() * TAU
	var radius := 8.6
	enemy.position = Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
	enemy.died.connect(_on_enemy_died.bind(enemy))


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.dead:
		kills += 1
		AudioDirector.play("kill")
		enemy.queue_free()
	if _tutorial == 2 and kills >= 1:
		_finish_tutorial()


func _finish_tutorial() -> void:
	_tutorial = -1
	tutorial_mode = false
	GameState.tutorial_done = true
	GameState.save_game()
	if _pending_daily and queue.size() > 0:
		queue[0].epic = true
		_pending_daily = false
		_sync_ghost()
	tutorial_step.emit(3)
	_spawn_cd = 1.6


func _enemies_tick(delta: float) -> void:
	var nodes := _enemies.get_children()
	for node in nodes:
		if node is Enemy and not node.dead:
			node.tick(delta, tower)
	for i in nodes.size():
		if not (nodes[i] is Enemy):
			continue
		for j in range(i + 1, nodes.size()):
			if not (nodes[j] is Enemy):
				continue
			var a: Node3D = nodes[i]
			var b: Node3D = nodes[j]
			var delta_xz := Vector2(a.position.x - b.position.x, a.position.z - b.position.z)
			var dist := delta_xz.length()
			if dist < 0.85 and dist > 0.001:
				var push := delta_xz / dist * (0.85 - dist) * 0.5
				a.position += Vector3(push.x, 0, push.y)
				b.position -= Vector3(push.x, 0, push.y)


func _fill_queue() -> void:
	while queue.size() < 3:
		queue.append(_roll())


func _roll() -> Dictionary:
	var id: String
	if _light_streak >= 2 and wave < 6:
		id = Catalog.HEAVY_IDS[randi() % Catalog.HEAVY_IDS.size()]
	else:
		id = Catalog.DROP_IDS[randi() % Catalog.DROP_IDS.size()]
	if id in Catalog.LIGHT_IDS:
		_light_streak += 1
	else:
		_light_streak = 0
	var epic := _next_epic
	_next_epic = false
	return {"id": id, "epic": epic}


func _sync_ghost() -> void:
	if queue.is_empty() or not running:
		tower.show_ghost("")
		return
	tower.show_ghost(str(queue[0].id))


func _on_balance() -> void:
	balance_hits += 1


func _on_collapsed() -> void:
	if not running and last_earned > 0 and not tower.alive:
		return
	running = false
	last_earned = tower.height_blocks() + kills * 2 + balance_hits
	GameState.coins += last_earned
	var height := tower.height_blocks()
	if height > GameState.best_height:
		GameState.best_height = height
	if kills > GameState.best_kills:
		GameState.best_kills = kills
	if score > GameState.best_score:
		GameState.best_score = score
	GameState.save_game()
	fell.emit()


func _shoot(list: Array[Dictionary]) -> void:
	for shot in list:
		if bool(shot.get("beam", false)):
			_show_beam(shot.from, shot.to)
			continue
		var node := _take_bullet()
		if node == null:
			continue
		var dest: Vector3 = shot.to
		var origin: Vector3 = shot.from
		var dir := dest - origin
		if dir.length() < 0.05:
			dir = Vector3(0, 0.2, -1)
		dir = dir.normalized()
		node.global_position = origin
		node.visible = true
		var splash := float(shot.splash)
		node.scale = Vector3.ONE * (1.7 if splash > 0.0 else 1.0)
		_live.append({
			"node": node,
			"vel": dir * float(shot.speed),
			"damage": float(shot.damage),
			"splash": splash,
			"life": 2.2,
		})


func _bullets(delta: float) -> void:
	var i := 0
	while i < _live.size():
		var bullet: Dictionary = _live[i]
		bullet.life = float(bullet.life) - delta
		var node: MeshInstance3D = bullet.node
		node.global_position += (bullet.vel as Vector3) * delta
		var exploded := _touch_bullet(bullet)
		if exploded or float(bullet.life) <= 0.0 or node.global_position.y < -0.5:
			node.visible = false
			_live.remove_at(i)
		else:
			i += 1
	if _beam_life > 0.0:
		_beam_life -= delta
		if _beam_life <= 0.0:
			_beam.visible = false


func _touch_bullet(bullet: Dictionary) -> bool:
	var node: MeshInstance3D = bullet.node
	var splash := float(bullet.splash)
	var reach := 0.72 + splash
	for child in _enemies.get_children():
		if not (child is Enemy) or child.dead:
			continue
		if node.global_position.distance_to(child.global_position) <= reach:
			if splash > 0.0:
				for other in _enemies.get_children():
					if other is Enemy and not other.dead and other.global_position.distance_to(node.global_position) <= splash + 0.4:
						other.take_damage(float(bullet.damage))
			else:
				child.take_damage(float(bullet.damage))
			return true
	return false


func _show_beam(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	_beam.global_position = mid
	_beam.look_at(b, Vector3.UP)
	_beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var length := maxf(a.distance_to(b), 0.2)
	_beam.scale = Vector3(1, length, 1)
	_beam.visible = true
	_beam_life = 0.07


func _camera(delta: float) -> void:
	_place_camera(false, delta)


func _place_camera(snap: bool, delta: float = 0.016) -> void:
	var look_y := clampf(1.45 + tower.total_height * 0.28, 1.45, 9.0)
	var dist := 10.0 + tower.total_height * 0.4
	var want := Vector3(0.15, look_y + 3.5, dist)
	if snap:
		_cam.position = want
	else:
		_cam.position = _cam.position.lerp(want, 1.0 - exp(-3.2 * delta))
	_cam.look_at(Vector3(0, look_y, 0))
	var dutch := clampf(-deg_to_rad(tower.tilt_signed_deg()) * 0.28, -0.14, 0.14)
	if snap:
		_cam.rotation.z = dutch
	else:
		_cam.rotation.z = lerp(_cam.rotation.z, dutch, 1.0 - exp(-6.0 * delta))


func _best_marker() -> void:
	var h := float(GameState.best_height)
	_best_ring.visible = h >= 2.0
	if _best_ring.visible:
		_best_ring.position.y = 0.15 + h * 0.9


func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var world_env := Environment.new()
	world_env.background_mode = Environment.BG_COLOR
	world_env.background_color = Color("07080b")
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color("8d93a0")
	world_env.ambient_light_energy = 0.85
	world_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.fog_enabled = true
	world_env.fog_light_color = Color("07080b")
	world_env.fog_density = 0.018
	env.environment = world_env
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 28, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = false
	add_child(sun)

	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(_cam)
	_cam.current = true

	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 13.5
	disc.bottom_radius = 13.5
	disc.height = 0.35
	ground.mesh = disc
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("14171c")
	dirt.roughness = 0.94
	ground.material_override = dirt
	ground.position.y = -0.2
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var blob := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.6, 3.6)
	blob.mesh = quad
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_color = Color(0, 0, 0, 0.42)
	blob.material_override = shade
	blob.rotation.x = -PI * 0.5
	blob.position.y = 0.015
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)

	_best_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.15
	ring.outer_radius = 1.28
	_best_ring.mesh = ring
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(0.85, 1.0, 0.35, 0.35)
	_best_ring.material_override = ring_mat
	_best_ring.visible = false
	_best_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_best_ring)


func _build_pool() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ff7a3c")
	for _i in 28:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_pool.append(mi)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 1.0
	_beam.mesh = cyl
	var beam_mat := mat.duplicate()
	beam_mat.albedo_color = Color("ffd27a")
	_beam.material_override = beam_mat
	_beam.visible = false
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)


func _take_bullet() -> MeshInstance3D:
	for mi in _pool:
		if not mi.visible:
			return mi
	return null


func _clear_bullets() -> void:
	for bullet in _live:
		(bullet.node as MeshInstance3D).visible = false
	_live.clear()
	if _beam:
		_beam.visible = false


func _clear_enemies() -> void:
	if _enemies == null:
		return
	for node in _enemies.get_children():
		node.queue_free()
