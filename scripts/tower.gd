class_name Tower
extends Node3D

signal balance_hit
signal collapsed
signal landed
signal struck

const FALL_DEG := 28.0
const DANGER_DEG := 18.0
const SPRING := 11.0
const DAMP := 4.4
const GRAV_GAIN := 1.15
const INVERT := 0.12

var yaw := 0.0
var tilt_x := 0.0
var tilt_z := 0.0
var vel_x := 0.0
var vel_z := 0.0
var frozen_left := 0.0
var freeze_cd := 0.0
var fire_buff := 0.0
var total_height := 0.0
var falling := false
var alive := true
var tutorial := false
var collapsing := false
var collapse_left := 0.0
var stack: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var statue_mult := 1.0
var cannon_mult := 1.0
var gen_mult := 1.0
var ghost_good := false
var last_improved := false
var perfect_chain := 0
var culprit_id := ""
var splash_cannon := false
var twin_air := false
var crystal_bounce := false

var _yaw_pivot: Node3D
var _lean: Node3D
var _fall: Node3D
var _ghost: Node3D
var _ghost_id := ""
var _fall_id := ""
var _fall_epic := false
var _fall_y := 0.0
var _fall_vel := 0.0
var _danger_armed := true
var _sway := 0.0


func _ready() -> void:
	_yaw_pivot = Node3D.new()
	_yaw_pivot.name = "Yaw"
	add_child(_yaw_pivot)
	_lean = Node3D.new()
	_lean.name = "Lean"
	_yaw_pivot.add_child(_lean)


func begin(run_statue: float, run_cannon: float, run_gen: float, is_tutorial: bool) -> void:
	statue_mult = run_statue
	cannon_mult = run_cannon
	gen_mult = run_gen
	splash_cannon = GameState.plant_splash
	twin_air = GameState.plant_air
	crystal_bounce = GameState.plant_bounce
	tutorial = is_tutorial
	perfect_chain = 0
	last_improved = false
	ghost_good = false
	culprit_id = ""
	_clear()
	alive = true
	collapsing = false
	falling = false
	yaw = 0.0
	tilt_x = 0.0
	tilt_z = 0.0
	vel_x = 0.0
	vel_z = 0.0
	frozen_left = 0.0
	freeze_cd = 0.0
	fire_buff = 0.0
	total_height = 0.0
	_danger_armed = true
	_place_now("01_base_plate", false)


func add_yaw(delta: float) -> void:
	if not alive:
		return
	yaw += delta
	_apply_visual()


func tilt_deg() -> float:
	return rad_to_deg(Vector2(tilt_x, tilt_z).length())


func tilt_signed_deg() -> float:
	return rad_to_deg(tilt_x)


func height_blocks() -> int:
	return maxi(stack.size() - 1, 0)


func drop(id: String, epic: bool) -> bool:
	if falling or not alive or collapsing:
		return false
	falling = true
	_fall_id = id
	_fall_epic = epic
	_fall_vel = 0.0
	_fall_y = _top_world() + 2.6
	_fall = ModelUtil.instantiate("modules", id)
	_yaw_pivot.add_child(_fall)
	var def := Catalog.module(id)
	ModelUtil.fit(_fall, float(def.get("height", 0.9)))
	_fall.position = Vector3(0, _fall_y, 0)
	AudioDirector.play("drop")
	AudioDirector.buzz(18)
	return true


func show_ghost(id: String) -> void:
	if id == "":
		ghost_good = false
		if _ghost != null:
			_ghost.queue_free()
			_ghost = null
		_ghost_id = ""
		return
	var good := would_improve(id)
	if id == _ghost_id and _ghost != null:
		_ghost.position.y = total_height
		if good != ghost_good:
			ghost_good = good
			ModelUtil.ghost(_ghost, ghost_good)
		else:
			ghost_good = good
		return
	_ghost_id = id
	ghost_good = good
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost = ModelUtil.instantiate("modules", id)
	_lean.add_child(_ghost)
	var def := Catalog.module(id)
	ModelUtil.fit(_ghost, float(def.get("height", 0.9)))
	ModelUtil.ghost(_ghost, ghost_good)
	_ghost.position = Vector3(0, total_height, 0)


func freeze() -> void:
	frozen_left = 10.0
	freeze_cd = 45.0
	vel_x *= 0.2
	vel_z *= 0.2
	AudioDirector.play("freeze")


func freeze_ready() -> bool:
	return freeze_cd <= 0.0 and frozen_left <= 0.0


func revive() -> void:
	alive = true
	collapsing = false
	collapse_left = 0.0
	var mag := Vector2(tilt_x, tilt_z).length()
	if mag > 0.001:
		var target := deg_to_rad(8.0)
		tilt_x = tilt_x / mag * target
		tilt_z = tilt_z / mag * target
	vel_x = 0.0
	vel_z = 0.0
	var y := 0.0
	for item in stack:
		var node: Node3D = item.node
		node.position = Vector3(0, y, 0)
		node.rotation = Vector3.ZERO
		y += float(item.height)
	total_height = y
	_apply_visual()


func tick(dt: float, enemies: Array) -> void:
	shots.clear()
	if freeze_cd > 0.0:
		freeze_cd -= dt
	if fire_buff > 0.0:
		fire_buff -= dt
	if collapsing:
		_tick_collapse(dt)
		return
	if not alive:
		return
	_tick_fall(dt)
	_tick_pendulum(dt)
	if alive:
		_tick_weapons(dt, enemies)
		_tick_danger()
	if _ghost != null:
		_ghost.position.y = total_height
	_apply_visual()


func _tick_fall(dt: float) -> void:
	if not falling or _fall == null:
		return
	_fall_vel += 22.0 * dt
	_fall_y -= _fall_vel * dt
	var top := _top_world()
	if _fall_y <= top:
		_lock_fall()
	else:
		_fall.position.y = _fall_y


func _lock_fall() -> void:
	var before := _com_horizontal()
	var def := Catalog.module(_fall_id)
	var mass := float(def.get("mass", 1.0))
	if _fall_id == "05_kaiju_bust":
		mass *= statue_mult
	var dmg_mult := 1.0
	if _fall_epic:
		mass *= 1.4
		dmg_mult = 1.5
	var height := float(def.get("height", 0.9))
	_fall.reparent(_lean, false)
	_fall.position = Vector3(0, total_height, 0)
	_fall.rotation = Vector3.ZERO
	stack.append({
		"id": _fall_id,
		"mass": mass,
		"height": height,
		"com": Catalog.com_of(def),
		"weapon": str(def.get("weapon", "none")),
		"damage_mult": dmg_mult,
		"cd": 0.35,
		"node": _fall,
		"base_y": total_height,
	})
	_decorate(stack[stack.size() - 1])
	total_height += height
	falling = false
	_fall = null
	landed.emit()
	var after := _com_horizontal()
	last_improved = after + 0.025 < before or (after < 0.055 and before < 0.1)
	if last_improved:
		perfect_chain += 1
		fire_buff = 2.6 + minf(float(perfect_chain - 1) * 0.35, 1.2)
		AudioDirector.play("balance")
		AudioDirector.buzz(28)
		balance_hit.emit()
	else:
		perfect_chain = 0


func _tick_pendulum(dt: float) -> void:
	var com := _com()
	var mass := maxf(_mass(), 1.0)
	var length := maxf(com.y, 0.35)
	var inertia := mass * length * length
	var world_xz := _world_xz(Vector2(com.x, com.z))
	var g := 9.8
	var spring := SPRING
	var damp := DAMP
	if frozen_left > 0.0:
		frozen_left -= dt
		g *= 0.2
		spring *= 2.3
		damp *= 1.7
	var grav_x := mass * g * GRAV_GAIN * world_xz.x
	var grav_z := mass * g * GRAV_GAIN * world_xz.y
	grav_x += mass * g * length * INVERT * tilt_x
	grav_z += mass * g * length * INVERT * tilt_z
	var torque_x := grav_x - spring * mass * tilt_x - damp * mass * vel_x
	var torque_z := grav_z - spring * mass * tilt_z - damp * mass * vel_z
	vel_x += (torque_x / inertia) * dt
	vel_z += (torque_z / inertia) * dt
	vel_x = clampf(vel_x, -2.4, 2.4)
	vel_z = clampf(vel_z, -2.4, 2.4)
	tilt_x += vel_x * dt
	tilt_z += vel_z * dt
	if tutorial:
		var cap := deg_to_rad(16.0)
		var mag := Vector2(tilt_x, tilt_z).length()
		if mag > cap:
			tilt_x = tilt_x / mag * cap
			tilt_z = tilt_z / mag * cap
			vel_x *= 0.5
			vel_z *= 0.5
	var deg := tilt_deg()
	if not tutorial and deg >= FALL_DEG:
		_begin_collapse()


func apply_hit(from: Vector3, power: float, height_ratio: float) -> void:
	if not alive or collapsing:
		return
	var dir := Vector2(from.x, from.z)
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var shield := _shield_mul(dir)
	var kick := power * (0.42 + height_ratio) * shield * 0.2
	if frozen_left > 0.0:
		kick *= 0.25
	vel_x += dir.x * kick
	vel_z += dir.y * kick
	struck.emit()
	AudioDirector.play("hit")
	AudioDirector.buzz(12)


func apply_wind(dir: Vector2, power: float) -> void:
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	vel_x += dir.x * power
	vel_z += dir.y * power


func _tick_weapons(dt: float, enemies: Array) -> void:
	var balance := 1.0 - clampf(tilt_deg() / 24.0, 0.0, 1.0)
	var balance_mult := 0.55 + balance * 0.9
	if fire_buff > 0.0:
		balance_mult *= 1.35
	var generators := 0
	for item in stack:
		if str(item.weapon) == "generator":
			generators += 1
	var rate := balance_mult * (1.0 + float(generators) * 0.28 * gen_mult)
	for item in stack:
		var spec: Dictionary = Catalog.WEAPONS.get(str(item.weapon), {})
		if spec.is_empty():
			continue
		item.cd = float(item.cd) - dt * rate
		if float(item.cd) > 0.0:
			continue
		item.cd = float(spec.cd)
		var kind := str(spec.kind)
		if kind == "aura":
			_aura(item, enemies, float(spec.dmg) * cannon_mult * float(item.damage_mult) * balance_mult, float(spec.range))
		elif kind == "beam":
			_beam(item, enemies, float(spec.dmg) * cannon_mult * float(item.damage_mult) * balance_mult, float(spec.range))
		else:
			_bullet(item, enemies, spec, balance_mult)


func _bullet(item: Dictionary, enemies: Array, spec: Dictionary, balance_mult: float) -> void:
	var prefer := "flying" if str(item.weapon) == "crown" or (str(item.weapon) == "twin" and twin_air) else "any"
	var target := _pick(enemies, float(spec.range), prefer)
	if target == null:
		item.cd = 0.12
		return
	var style := str(item.weapon)
	var splash := float(spec.splash)
	if style == "cannon" and splash_cannon:
		splash = maxf(splash, 1.15)
	if style == "missile":
		prefer = "armor"
		var grouped := _pick(enemies, float(spec.range), "armor")
		if grouped != null:
			target = grouped
	var pellets := 2 if style == "twin" else 1
	for i in pellets:
		var spread := -0.12 if i == 0 else 0.12
		if pellets == 1:
			spread = 0.0
		shots.append({
			"from": _muzzle(item),
			"to": target.global_position + Vector3(spread, 0.35, spread),
			"speed": float(spec.speed),
			"damage": float(spec.dmg) * cannon_mult * float(item.damage_mult) * balance_mult,
			"splash": splash,
			"beam": false,
			"style": style,
		})
	AudioDirector.play(style)


func _beam(item: Dictionary, enemies: Array, damage: float, range: float) -> void:
	var target := _pick(enemies, range, "high")
	if target == null:
		item.cd = 0.05
		return
	target.take_damage(damage, 0.0)
	var end: Vector3 = target.global_position
	if crystal_bounce:
		var bounce := _pick(enemies, range, "any", target)
		if bounce != null:
			bounce.take_damage(damage * 0.65, 0.0)
			end = bounce.global_position
	shots.append({
		"from": _muzzle(item),
		"to": end,
		"speed": 0.0,
		"damage": 0.0,
		"splash": 0.0,
		"beam": true,
		"style": "crystal",
	})
	AudioDirector.play("crystal")


func _aura(item: Dictionary, enemies: Array, damage: float, range: float) -> void:
	var y0 := float(item.base_y)
	var y1 := y0 + float(item.height)
	for node in enemies:
		if not (node is Enemy) or node.dead:
			continue
		var p: Vector3 = node.global_position
		if p.y < y0 - 0.5 or p.y > y1 + 0.8:
			continue
		if Vector2(p.x, p.z).length() <= range:
			node.take_damage(damage, 0.0)
			shots.append({
				"from": _muzzle(item),
				"to": p,
				"speed": 0.0,
				"damage": 0.0,
				"splash": 0.0,
				"beam": false,
				"style": "spike",
			})


func _begin_collapse() -> void:
	if collapsing:
		return
	culprit_id = _worst_piece()
	alive = false
	collapsing = true
	collapse_left = 0.75
	if _fall != null:
		_fall.queue_free()
		_fall = null
	falling = false
	AudioDirector.play("fall")
	AudioDirector.buzz(50)
	for item in stack:
		item["vel"] = Vector3(randf_range(-2.2, 2.2), randf_range(1.5, 4.0), randf_range(-2.2, 2.2))
		item["spin"] = randf_range(-5.0, 5.0)


func _tick_collapse(dt: float) -> void:
	collapse_left -= dt
	for item in stack:
		var node: Node3D = item.node
		var vel: Vector3 = item.get("vel", Vector3.ZERO)
		vel.y -= 9.0 * dt
		item["vel"] = vel
		node.position += vel * dt
		node.rotate_z(float(item.get("spin", 0.0)) * dt)
	if collapse_left <= 0.0:
		collapsing = false
		collapsed.emit()


func _tick_danger() -> void:
	if tilt_deg() >= DANGER_DEG:
		if _danger_armed:
			_danger_armed = false
			AudioDirector.play("danger")
			AudioDirector.buzz(24)
	elif tilt_deg() < DANGER_DEG - 3.0:
		_danger_armed = true


func _place_now(id: String, epic: bool) -> void:
	var def := Catalog.module(id)
	var node := ModelUtil.instantiate("modules", id)
	_lean.add_child(node)
	var height := float(def.get("height", 0.9))
	ModelUtil.fit(node, height)
	node.position = Vector3(0, total_height, 0)
	var mass := float(def.get("mass", 1.0))
	stack.append({
		"id": id,
		"mass": mass,
		"height": height,
		"com": Catalog.com_of(def),
		"weapon": str(def.get("weapon", "none")),
		"damage_mult": 1.5 if epic else 1.0,
		"cd": 0.4,
		"node": node,
		"base_y": total_height,
	})
	_decorate(stack[stack.size() - 1])
	total_height += height


func _clear() -> void:
	for item in stack:
		var node: Node3D = item.node
		if is_instance_valid(node):
			node.queue_free()
	stack.clear()
	if _fall != null:
		_fall.queue_free()
		_fall = null
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_id = ""
	falling = false
	total_height = 0.0


func _decorate(item: Dictionary) -> void:
	if str(item.weapon) != "generator":
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.55
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("9cff6a")
	mat.emission_enabled = true
	mat.emission = Color("d6ff3f")
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position = Vector3(0, float(item.height) * 0.45, 0)
	(item.node as Node3D).add_child(ring)


func _mass() -> float:
	var total := 0.0
	for item in stack:
		total += float(item.mass)
	return total


func _com() -> Vector3:
	var acc := Vector3.ZERO
	var mass := 0.0
	for item in stack:
		var center := Vector3(float(item.com.x), float(item.base_y) + float(item.height) * 0.5, float(item.com.z))
		acc += center * float(item.mass)
		mass += float(item.mass)
	if mass <= 0.001:
		return Vector3.ZERO
	return acc / mass


func horizontal_com() -> float:
	return _com_horizontal()


func _com_horizontal() -> float:
	var com := _com()
	return _world_xz(Vector2(com.x, com.z)).length()


func _world_xz(local_xz: Vector2) -> Vector2:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector2(local_xz.x * c - local_xz.y * s, local_xz.x * s + local_xz.y * c)


func _shield_mul(hit_dir: Vector2) -> float:
	var factor := 1.0
	var face := Vector2(sin(yaw), cos(yaw))
	if face.dot(hit_dir) > 0.35:
		for item in stack:
			if str(item.weapon) == "shield":
				factor *= 0.55
	return factor


func _pick(enemies: Array, max_dist: float, prefer: String, skip: Node = null) -> Node3D:
	var best: Node3D = null
	var best_score := -999.0
	for node in enemies:
		if not (node is Enemy) or node.dead or node == skip:
			continue
		var d := global_position.distance_to(node.global_position)
		if d > max_dist:
			continue
		var score := max_dist - d
		if prefer == "flying" and node.def.get("flying", false):
			score += 8.0
		elif prefer == "high" and float(node.def.get("height_ratio", 0.0)) >= 0.4:
			score += 8.0
		elif prefer == "armor" and str(node.def.get("role", "")) == "armor":
			score += 6.0
		if score > best_score:
			best_score = score
			best = node
	return best


func would_improve(id: String) -> bool:
	var def := Catalog.module(id)
	if def.is_empty():
		return false
	var before := _com_horizontal()
	var mass := float(def.get("mass", 1.0))
	if id == "05_kaiju_bust":
		mass *= statue_mult
	var height := float(def.get("height", 0.9))
	var com := Catalog.com_of(def)
	var center := Vector3(float(com.x), total_height + height * 0.5, float(com.z))
	var acc := Vector3.ZERO
	var total := 0.0
	for item in stack:
		var c := Vector3(float(item.com.x), float(item.base_y) + float(item.height) * 0.5, float(item.com.z))
		acc += c * float(item.mass)
		total += float(item.mass)
	acc += center * mass
	total += mass
	if total <= 0.001:
		return true
	var next := acc / total
	var after := _world_xz(Vector2(next.x, next.z)).length()
	return after + 0.02 < before or (after < 0.06 and before < 0.12)


func _worst_piece() -> String:
	var worst := ""
	var worst_pull := -1.0
	for item in stack:
		var pull := _world_xz(Vector2(float(item.com.x), float(item.com.z))).length() * float(item.mass)
		if pull > worst_pull and str(item.id) != "01_base_plate":
			worst_pull = pull
			worst = str(item.id)
	return worst


func _muzzle(item: Dictionary) -> Vector3:
	var local := Vector3(float(item.com.x), float(item.base_y) + float(item.height) * 0.62, float(item.com.z))
	return _lean.global_transform * local


func _top_world() -> float:
	return total_height * cos(Vector2(tilt_x, tilt_z).length())


func _apply_visual() -> void:
	if _yaw_pivot:
		_yaw_pivot.rotation.y = yaw
	if _lean:
		var extra := 0.0
		if tilt_deg() >= DANGER_DEG:
			_sway += 0.35
			extra = sin(_sway) * deg_to_rad(1.6)
		_lean.rotation = Vector3(tilt_z + extra, 0.0, -tilt_x)
