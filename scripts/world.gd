class_name World
extends Node3D

signal fell
signal chest_ready
signal tutorial_step(step: int)
signal wind_warning(dir: Vector2)
signal wave_card(text: String)
signal wave_clear(text: String)
signal mutation_ready
signal boss_changed(ratio: float)

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
var _slide_px := 0.0
var _fires: Array[Dictionary] = []
var _biome := -1
var _grass: MultiMeshInstance3D
var _ground: MeshInstance3D
var _path_mesh: MeshInstance3D
var _env: Environment
var _wind_cd := 7.0
var _wind_left := 0.0
var _wind_dir := Vector2.RIGHT
var _best_ring: MeshInstance3D
var _shake := 0.0
var _sparks: Array[Dictionary] = []
var _spark_pool: Array[MeshInstance3D] = []
var _card_left := 0.0
var _card_pending := false
var _clear_left := 0.0
var _clear_sent := false
var _script: Array[Dictionary] = []
var _hitstop := 0.0
var _boss: Enemy
var _awaiting_choice := false
var _choice_wave := 0
var card_count := 0
var missile_bursts := 0
var cannon_shots := 0
var bosses_spawned := 0
var tick_pushes := 0
var _fx: Node3D
var _meshes: Dictionary = {}
var _rings: Array[Dictionary] = []


func _ready() -> void:
	Catalog.ensure()
	_build_scene()
	tower = Tower.new()
	tower.name = "Tower"
	add_child(tower)
	tower.balance_hit.connect(_on_balance)
	tower.collapsed.connect(_on_collapsed)
	tower.landed.connect(_on_landed)
	tower.struck.connect(_on_struck)
	_enemies = Node3D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_fx = Node3D.new()
	_fx.name = "Fx"
	add_child(_fx)
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
	_card_left = 0.0
	_card_pending = not is_tutorial
	_clear_left = 0.0
	_clear_sent = false
	_hitstop = 0.0
	_awaiting_choice = false
	_boss = null
	_script.clear()
	queue.clear()
	running = true
	if _showcase:
		_showcase.visible = false
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
	if not is_tutorial:
		_arm_wave()


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
	slide(80.0 if delta > 0.0 else -80.0)


func slide(pixels: float) -> void:
	if not running:
		return
	_slide_px += pixels
	while absf(_slide_px) >= 46.0:
		var step := 1 if _slide_px > 0.0 else -1
		_slide_px -= float(step) * 46.0
		tower.nudge_stud(step)
	if _tutorial == 0 and tower.ghost_good:
		_tutorial = 1
		tutorial_step.emit(1)


func rotate_piece() -> void:
	if not running:
		return
	tower.rotate_piece()
	if _tutorial == 0 and tower.ghost_good:
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
	if _hitstop > 0.0:
		_hitstop -= delta
		_sparks_tick(delta)
		_camera(delta)
		return
	tower.tick(delta, _enemies.get_children())
	_shoot(tower.shots)
	_bullets(delta)
	_sparks_tick(delta)
	_fx_tick(delta)
	_enemies_tick(delta)
	_shake = move_toward(_shake, 0.0, delta * 2.8)
	if _tutorial < 0 and not chest_open and not _awaiting_choice:
		_waves(delta)
		_wind(delta)
	_sync_ghost()
	_fires_tick(delta)
	_push_grass()
	if running:
		_apply_biome(wave)
	var danger := tower.tilt_deg() >= 18.0
	var combat := _enemies.get_child_count() > 0 and _tutorial < 0
	AudioDirector.set_mood(combat, danger)
	_camera(delta)
	_best_marker()
	score = tower.height_blocks() * 10 + kills * 5 + balance_hits * 10


func _waves(delta: float) -> void:
	var duration := 16.0 + float(wave) * 1.2
	if _clear_left > 0.0:
		_clear_left -= delta
		if _clear_left <= 0.0:
			if wave % 3 == 0:
				chest_open = true
				chest_ready.emit()
			else:
				_advance_wave()
		return
	if _card_left > 0.0:
		_card_left -= delta
		return
	if _card_pending:
		_announce()
		return
	_wave_time += delta
	_spawn_cd -= delta
	if _spawn_cd <= 0.0 and _enemies.get_child_count() < 10 and _wave_time < duration and not _script.is_empty():
		var job: Dictionary = _script.pop_front()
		_spawn(str(job.id), bool(job.elite), bool(job.get("boss", false)))
		_spawn_cd = maxf(0.85, 2.4 - float(wave) * 0.08)
	if _wave_time >= duration and _enemies.get_child_count() == 0 and _script.is_empty() and not _clear_sent:
		_clear_sent = true
		_clear_left = 1.2
		var next_name := _next_threat()
		wave_clear.emit("%s %d   %s %d\n%s" % [Locale.t("height"), tower.height_blocks(), Locale.t("kills"), kills, next_name])


func _advance_wave() -> void:
	wave += 1
	_wave_time = 0.0
	_spawn_cd = 1.4
	_clear_sent = false
	_arm_wave()


func _arm_wave() -> void:
	_script.clear()
	_card_pending = true
	_boss = null
	if wave % 3 == 0 and wave != _choice_wave:
		_awaiting_choice = true
		mutation_ready.emit()
		return
	var script := Catalog.wave_script(wave)
	if script.is_empty() and wave % 5 == 0:
		script = {"card": "wave_boss", "boss": "02_smash_crab", "groups": [{"id": "01_ram_beetle", "count": 3, "elite": false}]}
	if script.is_empty():
		var id := _random_id()
		_script.append({"id": id, "elite": wave >= 4 and randf() < 0.18, "boss": false})
		_script.append({"id": id, "elite": false, "boss": false})
		return
	if script.has("boss") and _tutorial < 0:
		_script.append({"id": str(script.boss), "elite": true, "boss": true})
	for group in script.get("groups", []):
		var count := int(group.get("count", 1))
		for _i in count:
			_script.append({
				"id": str(group.get("id", "01_ram_beetle")),
				"elite": bool(group.get("elite", false)),
				"boss": false,
			})


func apply_mutation(which: int) -> void:
	_awaiting_choice = false
	_choice_wave = wave
	if queue.is_empty():
		_arm_wave()
		return
	if which == 0:
		queue[0].epic = true
	elif which == 1 and not queue.is_empty():
		queue[0].id = "06_shield_slab"
		queue[0].epic = false
	else:
		tower.fire_buff = maxf(tower.fire_buff, 4.0)
	_sync_ghost()
	_arm_wave()


func _announce() -> void:
	_card_pending = false
	_card_left = 1.0
	card_count += 1
	var script := Catalog.wave_script(wave)
	var key := str(script.get("card", "wave_mixed"))
	if script.is_empty() and wave % 5 == 0:
		key = "wave_boss"
	wave_card.emit(Locale.t(key))


func _next_threat() -> String:
	var upcoming := Catalog.wave_script(wave + 1)
	if upcoming.is_empty():
		return Locale.t("wave") % (wave + 1)
	return Locale.t(str(upcoming.get("card", "wave_mixed")))


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


func _random_id() -> String:
	var pool: Array[String] = []
	for id in Catalog.creatures().keys():
		if int(Catalog.creature(id).unlock_wave) <= wave:
			pool.append(id)
	if pool.is_empty():
		return "01_ram_beetle"
	return pool[randi() % pool.size()]


func _spawn(id: String, elite: bool, as_boss: bool = false) -> void:
	if as_boss and (_tutorial >= 0 or tutorial_mode):
		return
	var def := Catalog.creature(id)
	if def.is_empty():
		return
	var enemy := Enemy.new()
	_enemies.add_child(enemy)
	enemy.setup(def, wave, elite, as_boss)
	if as_boss:
		_boss = enemy
		bosses_spawned += 1
		boss_changed.emit(1.0)
	var lane := randf_range(-1.35, 1.35)
	enemy.position = Vector3(lane, 1.15 if enemy.flying else 0.0, -8.6)
	enemy.died.connect(_on_enemy_died.bind(enemy))


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.dead:
		kills += 1
		AudioDirector.play("kill")
		_burst(enemy.global_position + Vector3(0, 0.45, 0), Color("ffb15a"), 14)
		_shake = maxf(_shake, 0.34 if enemy.boss or enemy.elite else 0.18)
		if enemy.boss or enemy.elite:
			_hitstop = 0.03
		if enemy.death_push > 0.0:
			tower.apply_hit(enemy.global_position, enemy.death_push, enemy.height_ratio)
			tick_pushes += 1
		if enemy.boss:
			_boss = null
			boss_changed.emit(0.0)
			if not chest_open:
				chest_open = true
				chest_ready.emit()
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
	_arm_wave()


func _enemies_tick(delta: float) -> void:
	var nodes := _enemies.get_children()
	for node in nodes:
		if node is Enemy and not node.dead:
			node.slow = 0.55 if node.role == "swarm" and _in_fire(node.global_position) else 1.0
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
	var color := Color("d8ff6a") if tower.perfect_chain > 1 else Color("9cff6a")
	_burst(Vector3(0, tower.total_height, 0), color, 10 + tower.perfect_chain * 4)
	_shake = maxf(_shake, 0.16 + float(tower.perfect_chain) * 0.04)


func _on_collapsed() -> void:
	if not running and last_earned > 0 and not tower.alive:
		return
	running = false
	last_earned = tower.height_blocks() + kills * 2 + balance_hits
	if GameState.heat:
		last_earned *= 2
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
		var style := str(shot.get("style", "cannon"))
		if style == "spike":
			_pulse(shot.to, Color("e7ff9a"))
			continue
		if bool(shot.get("beam", false)) or style == "crystal":
			_show_beam(shot.from, shot.to, style)
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
		node.mesh = _meshes.get(style, _meshes["cannon"])
		node.material_override = _style_mat(style)
		node.global_position = origin
		node.visible = true
		if style == "cannon":
			cannon_shots += 1
			node.scale = Vector3(0.22, 0.22, 0.55)
			_burst(origin, Color("ffb15a"), 5)
		elif style == "twin":
			node.scale = Vector3(0.08, 0.08, 0.35)
			_burst(origin, Color("fff1c2"), 2)
		elif style == "missile":
			node.scale = Vector3(0.16, 0.16, 0.42)
			dir = (dir + Vector3.UP * 0.55).normalized()
		elif style == "crown":
			node.scale = Vector3(0.06, 0.06, 0.7)
		else:
			node.scale = Vector3.ONE * 0.2
		_live.append({
			"node": node,
			"vel": dir * float(shot.speed),
			"damage": float(shot.damage),
			"splash": float(shot.splash),
			"life": 2.4,
			"style": style,
			"target": dest,
		})


func _bullets(delta: float) -> void:
	var i := 0
	while i < _live.size():
		var bullet: Dictionary = _live[i]
		bullet.life = float(bullet.life) - delta
		var node: MeshInstance3D = bullet.node
		var style := str(bullet.style)
		var vel: Vector3 = bullet.vel
		if style == "missile":
			vel.y -= 7.5 * delta
		elif style == "crown":
			var aim: Vector3 = bullet.target - node.global_position
			if aim.length() > 0.05:
				vel = vel.lerp(aim.normalized() * vel.length(), 0.18)
		bullet.vel = vel
		node.global_position += vel * delta
		if vel.length() > 0.05:
			node.look_at(node.global_position + vel, Vector3.UP)
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
	var style := str(bullet.style)
	var reach := 0.45 if style == "twin" else 0.62
	for child in _enemies.get_children():
		if not (child is Enemy) or child.dead:
			continue
		if node.global_position.distance_to(child.global_position) <= reach + (0.2 if splash > 0.0 else 0.0):
			if splash > 0.0:
				for other in _enemies.get_children():
					if other is Enemy and not other.dead and other.global_position.distance_to(node.global_position) <= splash + 0.45:
						other.take_damage(float(bullet.damage), splash)
				_explode(node.global_position, style)
			else:
				child.take_damage(float(bullet.damage), 0.0)
				_burst(node.global_position, _style_color(style), 6)
			_shake = maxf(_shake, 0.12 if style == "cannon" else 0.06)
			return true
	return false


func _explode(at: Vector3, style: String) -> void:
	if style == "missile":
		missile_bursts += 1
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.42
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _style_color(style)
	mat.emission_enabled = true
	mat.emission = _style_color(style)
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	_fx.add_child(ring)
	ring.global_position = at
	_rings.append({"node": ring, "life": 0.28})
	if style == "missile":
		_fires.append({"at": Vector2(at.x, at.z), "life": 2.0})
	_burst(at, _style_color(style), 12)


func _pulse(at: Vector3, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.7
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position = Vector3(at.x, 0.08, at.z)
	_fx.add_child(ring)
	_rings.append({"node": ring, "life": 0.22})


func _fx_tick(delta: float) -> void:
	var i := 0
	while i < _rings.size():
		var ring: Dictionary = _rings[i]
		ring.life = float(ring.life) - delta
		var node: Node3D = ring.node
		if is_instance_valid(node):
			node.scale += Vector3.ONE * delta * 8.0
		if float(ring.life) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			_rings.remove_at(i)
		else:
			i += 1


func _style_color(style: String) -> Color:
	match style:
		"twin":
			return Color("fff4c8")
		"missile":
			return Color("ff7a32")
		"crown":
			return Color("d9b4ff")
		"crystal":
			return Color("9af6ff")
		"spike":
			return Color("d6ff78")
		_:
			return Color("ffb15a")


func _style_mat(style: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var color := _style_color(style)
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _show_beam(a: Vector3, b: Vector3, style: String = "crystal") -> void:
	var mid := (a + b) * 0.5
	_beam.global_position = mid
	if _beam.material_override is StandardMaterial3D:
		(_beam.material_override as StandardMaterial3D).albedo_color = _style_color(style)
		(_beam.material_override as StandardMaterial3D).emission = _style_color(style)
	_beam.look_at(b, Vector3.UP)
	_beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var length := maxf(a.distance_to(b), 0.2)
	_beam.scale = Vector3(1.4 if style == "crystal" else 0.4, length, 1.4 if style == "crystal" else 0.4)
	_beam.visible = true
	_beam_life = 0.22 if style == "crystal" else 0.12
	_burst(b, _style_color(style), 6)


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
	if _shake > 0.0:
		_cam.position += Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * _shake


func _in_fire(at: Vector3) -> bool:
	var flat := Vector2(at.x, at.z)
	for bit in _fires:
		if float(bit.life) > 0.0 and flat.distance_to(bit.at) < 1.35:
			return true
	return false


func _fires_tick(delta: float) -> void:
	var i := 0
	while i < _fires.size():
		_fires[i].life = float(_fires[i].life) - delta
		if float(_fires[i].life) <= 0.0:
			_fires.remove_at(i)
		else:
			i += 1


func _push_grass() -> void:
	if _grass == null or not (_grass.material_override is ShaderMaterial):
		return
	var mat := _grass.material_override as ShaderMaterial
	var slots: Array[Vector3] = [Vector3(0, -20, 0), Vector3(0, -20, 0), Vector3(0, -20, 0)]
	var n := 0
	if _enemies != null:
		for node in _enemies.get_children():
			if n >= 3 or not (node is Enemy) or node.dead:
				continue
			slots[n] = node.global_position
			n += 1
	mat.set_shader_parameter("enemy_a", slots[0])
	mat.set_shader_parameter("enemy_b", slots[1])
	mat.set_shader_parameter("enemy_c", slots[2])
	if _fires.is_empty():
		mat.set_shader_parameter("fire_amt", 0.0)
	else:
		var bit: Dictionary = _fires[0]
		mat.set_shader_parameter("fire_at", Vector3(bit.at.x, 0.0, bit.at.y))
		mat.set_shader_parameter("fire_amt", clampf(float(bit.life) / 2.0, 0.0, 1.0))


func _apply_biome(wave_n: int) -> void:
	var index := 0
	if wave_n >= 10:
		index = 2
	elif wave_n >= 5:
		index = 1
	if index == _biome or _env == null or _ground == null:
		return
	_biome = index
	var names := ["meadow", "dusk", "ember"]
	var skies := [Color("8ec6ea"), Color("d27a62"), Color("2a140f")]
	var fogs := [Color("c5e4f6"), Color("e7b090"), Color("4a2418")]
	var suns := [Color("fff2d8"), Color("ffb07a"), Color("ff7a3c")]
	var tints := [Color("6ea84a"), Color("8a6a3a"), Color("6a4030")]
	var tex := load("res://assets/textures/%s.jpg" % names[index])
	var sky := load("res://assets/textures/sky_%s.jpg" % names[index])
	var mat := _ground.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		_ground.material_override = mat
	mat.albedo_color = tints[index]
	mat.emission_enabled = index == 2
	mat.emission = Color("ff5a20")
	mat.emission_energy_multiplier = 0.25 if index == 2 else 0.0
	if tex is Texture2D:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(6, 6, 6)
	_env.background_color = skies[index]
	_env.ambient_light_color = skies[index].lightened(0.2)
	_env.fog_light_color = fogs[index]
	if sky is Texture2D:
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = sky
		panorama.energy_multiplier = 1.35 if index == 0 else 1.05
		var sky_res := Sky.new()
		sky_res.sky_material = panorama
		_env.background_mode = Environment.BG_SKY
		_env.sky = sky_res
	else:
		_env.background_mode = Environment.BG_COLOR
	if _grass != null and _grass.material_override is ShaderMaterial:
		(_grass.material_override as ShaderMaterial).set_shader_parameter("albedo_tint", Vector3(tints[index].r, tints[index].g, tints[index].b))
	for child in get_children():
		if child is DirectionalLight3D and child.light_energy > 1.0:
			child.light_color = suns[index]


func _build_path() -> void:
	_path_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.8, 0.04, 10.5)
	_path_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8a6840")
	mat.roughness = 1.0
	var dirt := load("res://assets/textures/dusk.jpg")
	if dirt is Texture2D:
		mat.albedo_texture = dirt
		mat.uv1_scale = Vector3(1.5, 4.0, 1.0)
	_path_mesh.material_override = mat
	_path_mesh.position = Vector3(0, 0.02, -4.6)
	add_child(_path_mesh)


func _build_grass() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.38)
	quad.orientation = PlaneMesh.FACE_Z
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = false
	multi.mesh = quad
	multi.instance_count = 220
	var i := 0
	while i < 220:
		var x := randf_range(-7.5, 7.5)
		var z := randf_range(-8.5, 6.5)
		if absf(x) < 1.5 and z < -0.4 and z > -8.2:
			x = 1.7 if x >= 0.0 else -1.7
		var xf := Transform3D(Basis(Vector3.UP, randf() * TAU), Vector3(x, 0.19, z))
		multi.set_instance_transform(i, xf)
		i += 1
	_grass = MultiMeshInstance3D.new()
	_grass.multimesh = multi
	_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode cull_disabled;\nvarying vec3 tint;\nuniform vec3 enemy_a = vec3(0.0, -20.0, 0.0);\nuniform vec3 enemy_b = vec3(0.0, -20.0, 0.0);\nuniform vec3 enemy_c = vec3(0.0, -20.0, 0.0);\nuniform vec3 fire_at = vec3(0.0, -20.0, 0.0);\nuniform float fire_amt = 0.0;\nuniform vec3 albedo_tint = vec3(0.22, 0.42, 0.16);\nvoid vertex(){\n\tvec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\tvec3 push = vec3(0.0);\n\tfloat d0 = distance(w, enemy_a);\n\tif (d0 < 1.35) push += normalize(w - enemy_a) * (1.35 - d0);\n\tfloat d1 = distance(w, enemy_b);\n\tif (d1 < 1.35) push += normalize(w - enemy_b) * (1.35 - d1);\n\tfloat d2 = distance(w, enemy_c);\n\tif (d2 < 1.35) push += normalize(w - enemy_c) * (1.35 - d2);\n\tfloat burn = fire_amt * (1.0 - clamp(distance(w, fire_at) / 1.7, 0.0, 1.0));\n\tVERTEX.x += push.x * UV.y * 0.55;\n\tVERTEX.z += push.z * UV.y * 0.55;\n\ttint = mix(albedo_tint, vec3(0.85, 0.28, 0.05), burn);\n}\nvoid fragment(){\n\tALBEDO = tint;\n\tALPHA = mix(0.15, 0.95, UV.y);\n\tEMISSION = vec3(1.0, 0.28, 0.02) * clamp(tint.r - tint.g, 0.0, 1.0);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_grass.material_override = mat
	add_child(_grass)


var _showcase: Node3D


func show_showcase(on: bool) -> void:
	if _showcase:
		_showcase.visible = on and not running
	if on and _cam:
		_apply_biome(1)
		_cam.position = Vector3(0.2, 2.6, 7.4)
		_cam.look_at(Vector3(0, 1.35, 0.2))


func _build_showcase() -> void:
	_showcase = Node3D.new()
	add_child(_showcase)
	var y := 0.0
	for id in ["01_base_plate", "05_kaiju_bust", "02_side_cannon"]:
		var def := Catalog.module(id)
		var node := ModelUtil.instantiate("modules", id)
		_showcase.add_child(node)
		var h := float(def.get("height", 0.9))
		ModelUtil.fit(node, h)
		node.position = Vector3(0.15 if id != "01_base_plate" else 0.0, y, 0)
		y += h


func _best_marker() -> void:
	var h := float(GameState.best_height)
	_best_ring.visible = h >= 2.0
	if _best_ring.visible:
		_best_ring.position.y = 0.15 + h * 0.9


func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var world_env := Environment.new()
	_env = world_env
	world_env.background_mode = Environment.BG_COLOR
	world_env.background_color = Color("8ec6ea")
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color("c5d4ea")
	world_env.ambient_light_energy = 1.15
	world_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.glow_enabled = true
	world_env.glow_intensity = 0.55
	world_env.glow_strength = 0.85
	world_env.glow_bloom = 0.12
	world_env.fog_enabled = true
	world_env.fog_light_color = Color("c5e4f6")
	world_env.fog_density = 0.003
	env.environment = world_env
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 32, 0)
	sun.light_energy = 1.7
	sun.light_color = Color("fff2d8")
	sun.shadow_enabled = false
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 200, 0)
	rim.light_energy = 0.55
	rim.light_color = Color("7ec8ff")
	rim.shadow_enabled = false
	add_child(rim)
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
	dirt.albedo_color = Color("243044")
	dirt.roughness = 0.72
	dirt.emission_enabled = true
	dirt.emission = Color("1a3a48")
	dirt.emission_energy_multiplier = 0.35
	ground.material_override = dirt
	ground.position.y = -0.2
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_ground = ground
	_build_path()
	_build_grass()
	_apply_biome(1)
	_build_showcase()

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
	mat.emission_enabled = true
	mat.emission = Color("ffb15a")
	mat.emission_energy_multiplier = 2.4
	var cannon := CapsuleMesh.new()
	cannon.radius = 0.12
	cannon.height = 0.46
	var twin := CapsuleMesh.new()
	twin.radius = 0.04
	twin.height = 0.28
	var missile := CapsuleMesh.new()
	missile.radius = 0.1
	missile.height = 0.38
	var crown := BoxMesh.new()
	crown.size = Vector3(0.08, 0.08, 0.7)
	_meshes = {"cannon": cannon, "twin": twin, "missile": missile, "crown": crown}
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
	beam_mat.emission_enabled = true
	beam_mat.emission = Color("fff1c2")
	beam_mat.emission_energy_multiplier = 3.0
	_beam.material_override = beam_mat
	_beam.visible = false
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.08
	spark_mesh.height = 0.16
	for _i in 48:
		var spark := MeshInstance3D.new()
		spark.mesh = spark_mesh
		var spark_mat := StandardMaterial3D.new()
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_mat.emission_enabled = true
		spark_mat.emission = Color("ffd27a")
		spark_mat.emission_energy_multiplier = 2.0
		spark_mat.albedo_color = Color("ffd27a")
		spark.material_override = spark_mat
		spark.visible = false
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		_spark_pool.append(spark)


func _on_landed() -> void:
	_shake = maxf(_shake, 0.22)
	_burst(Vector3(0, tower.total_height, 0), Color("d6ff3f"), 12)


func _on_struck() -> void:
	_shake = maxf(_shake, 0.28)


func _burst(at: Vector3, color: Color, count: int) -> void:
	for _i in count:
		var node := _take_spark()
		if node == null:
			return
		node.global_position = at
		node.visible = true
		node.scale = Vector3.ONE * randf_range(0.6, 1.4)
		var mat := node.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = color
			mat.emission = color
		_sparks.append({
			"node": node,
			"vel": Vector3(randf_range(-2.2, 2.2), randf_range(1.2, 3.4), randf_range(-2.2, 2.2)),
			"life": randf_range(0.28, 0.5),
			"max": 0.5,
		})


func _sparks_tick(delta: float) -> void:
	var i := 0
	while i < _sparks.size():
		var spark: Dictionary = _sparks[i]
		spark.life = float(spark.life) - delta
		var node: MeshInstance3D = spark.node
		var vel: Vector3 = spark.vel
		vel.y -= 6.0 * delta
		spark.vel = vel
		node.global_position += vel * delta
		node.scale = Vector3.ONE * clampf(float(spark.life) / float(spark.max), 0.0, 1.0)
		if float(spark.life) <= 0.0:
			node.visible = false
			_sparks.remove_at(i)
		else:
			i += 1


func _take_spark() -> MeshInstance3D:
	for mi in _spark_pool:
		if not mi.visible:
			return mi
	return null


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
