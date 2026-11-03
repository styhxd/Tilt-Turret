class_name Tower
extends Node3D

signal balance_hit
signal collapsed
signal landed
signal struck
signal slipped
signal deflected(dir: Vector3)

const FALL_DEG := 28.0
const DANGER_DEG := 18.0
const SPRING := 11.0
const DAMP := 4.4
const GRAV_GAIN := 1.15
const INVERT := 0.12
const STUD := 0.42

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
var stud := 0
var face := 0
var last_offset := Vector2.ZERO

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
var _stud_marks: Array[MeshInstance3D] = []
var _junk: Array[Dictionary] = []
var relics: Array[String] = []
var peak_power := 0.0
var _seg_of: Array = []
var _seg_pool: Array = []
var _seg_holder: Array = []
var _wires: Array[MeshInstance3D] = []


func _ready() -> void:
	_yaw_pivot = Node3D.new()
	_yaw_pivot.name = "Yaw"
	add_child(_yaw_pivot)
	_lean = Node3D.new()
	_lean.name = "Lean"
	_yaw_pivot.add_child(_lean)
	_build_studs()


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
	stud = 0
	face = 0
	last_offset = Vector2.ZERO
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
	relics.clear()
	peak_power = 0.0
	_place_now("01_base_plate", false)
	if GameState.toy_base_gen and not is_tutorial:
		_place_now("04_generator", false)


func add_yaw(delta: float) -> void:
	if not alive:
		return
	nudge_stud(1 if delta > 0.0 else -1)


func stud_span() -> int:
	return 3 if GameState.toy_stud else 2


func set_stud(index: int) -> void:
	stud = clampi(index, -stud_span(), stud_span())
	_refresh_ghost_pose()


func nudge_stud(step: int) -> void:
	if not alive or falling:
		return
	set_stud(stud + step)


func rotate_piece() -> void:
	if not alive or falling:
		return
	face = (face + 1) % 4
	_refresh_ghost_pose()


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
	var spot := preview_offset()
	_fall.position = Vector3(spot.x, _fall_y, spot.y)
	_fall.rotation.y = face * PI * 0.5
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
		ghost_good = good and supported_here()
		_refresh_ghost_pose()
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
	ghost_good = good and supported_here()
	ModelUtil.ghost(_ghost, ghost_good)
	_refresh_ghost_pose()


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
		var spot: Vector2 = item.get("offset", Vector2.ZERO)
		node.position = Vector3(spot.x, y, spot.y)
		node.rotation = Vector3(0, int(item.get("face", 0)) * PI * 0.5, 0)
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
	_tick_junk(dt)
	_refresh_ghost_pose()
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
		var spot := preview_offset()
		_fall.position = Vector3(spot.x, _fall_y, spot.y)


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
	var spot := preview_offset()
	last_offset = spot
	_fall.reparent(_lean, false)
	_fall.position = Vector3(spot.x, total_height, spot.y)
	_fall.rotation = Vector3(0, face * PI * 0.5, 0)
	if not supported_here():
		_junk.append({"node": _fall, "vel": Vector3(signf(spot.x) * 2.4, 2.2, 1.1)})
		falling = false
		_fall = null
		slipped.emit()
		return
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
		"offset": spot,
		"face": face,
		"span": float(def.get("span", 0.5)),
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
	var statues := 0
	for item in stack:
		if str(item.id) == "05_kaiju_bust":
			statues += 1
	kick *= 1.0 - minf(0.24, float(statues) * 0.08)
	if frozen_left > 0.0:
		kick *= 0.25
	vel_x += dir.x * kick
	vel_z += dir.y * kick
	struck.emit()
	AudioDirector.play("hit")
	AudioDirector.buzz(12)
	if shield < 0.98 and has_relic("reflect"):
		deflected.emit(Vector3(dir.x, 0.0, dir.y))


func apply_wind(dir: Vector2, power: float) -> void:
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	vel_x += dir.x * power
	vel_z += dir.y * power


func has_relic(id: String) -> bool:
	return id in relics


func any_powered() -> bool:
	for item in stack:
		if bool(item.get("lit", false)) and str(item.weapon) not in ["none", "shield", "generator"]:
			return true
	return false


func wire_count() -> int:
	var count := 0
	for wire in _wires:
		if wire.visible:
			count += 1
	return count


func equilibrium_deg() -> Vector2:
	return _equilibrium_of(_com())


func preview_equilibrium_deg() -> Vector2:
	if _ghost_id == "" or stack.is_empty() or not supported_here():
		return equilibrium_deg()
	var next := _hypothetical_com(_ghost_id, face, preview_offset())
	return _equilibrium_of(next)


func would_light(id: String) -> bool:
	if id in ["05_kaiju_bust", "07_spike_drum", "06_shield_slab", "01_base_plate"]:
		return false
	if id == "04_generator":
		return true
	if stack.is_empty():
		return false
	var top: Dictionary = stack.back()
	return _conducts(top) and bool(top.get("lit", false))


func _hypothetical_com(id: String, quarter: int, spot: Vector2) -> Vector3:
	var def := Catalog.module(id)
	var mass := float(def.get("mass", 1.0))
	if id == "05_kaiju_bust":
		mass *= statue_mult
		if has_relic("magnet"):
			mass *= 1.35
	var height := float(def.get("height", 0.9))
	var local := Catalog.com_of(def)
	var placed := _rotate_flat(Vector2(local.x, local.z), quarter) + spot
	var center := Vector3(placed.x, total_height + height * 0.5, placed.y)
	var acc := Vector3.ZERO
	var sum := 0.0
	for item in stack:
		var m := _com_mass(item)
		acc += _item_center(item) * m
		sum += m
	acc += center * mass
	sum += mass
	if sum <= 0.001:
		return Vector3.ZERO
	return acc / sum


func _equilibrium_of(com: Vector3) -> Vector2:
	var xz := _world_xz(Vector2(com.x, com.z))
	var k := rad_to_deg(9.8 * GRAV_GAIN / SPRING)
	return Vector2(xz.x, xz.y) * k


func _com_mass(item: Dictionary) -> float:
	var mass := float(item.mass)
	if str(item.id) == "05_kaiju_bust" and has_relic("magnet"):
		mass *= 1.35
	return mass


func _conducts(item: Dictionary) -> bool:
	var id := str(item.get("id", ""))
	if id == "05_kaiju_bust":
		return false
	if id == "06_shield_slab":
		return int(item.get("face", 0)) % 2 == 1
	return id in ["01_base_plate", "04_generator", "09_crystal_spur", "10_crown_nest"]


func _tick_energy(dt: float) -> void:
	var conduit: Array[bool] = []
	for item in stack:
		conduit.append(_conducts(item))
	var groups: Array = []
	var index := 0
	while index < stack.size():
		if not conduit[index]:
			index += 1
			continue
		var group: Array[int] = []
		while index < stack.size() and conduit[index]:
			group.append(index)
			index += 1
		groups.append(group)
	if has_relic("long_line") and groups.size() > 1:
		var merged: Array = []
		var g := 0
		while g < groups.size():
			var cur: Array = (groups[g] as Array).duplicate()
			if g + 1 < groups.size():
				var gap := int(groups[g + 1][0]) - int(cur.back())
				if gap == 2:
					cur.append_array(groups[g + 1])
					merged.append(cur)
					g += 2
					continue
			merged.append(cur)
			g += 1
		groups = merged
	_seg_of.clear()
	_seg_pool.clear()
	_seg_holder.clear()
	for _i in stack.size():
		_seg_of.append(-1)
	for group in groups:
		var pool := 0.0
		var cap := 0.0
		var regen := 0.0
		var holder := -1
		for idx in group:
			_seg_of[int(idx)] = _seg_pool.size()
			var item: Dictionary = stack[int(idx)]
			var id := str(item.id)
			if id == "01_base_plate":
				regen += 1.0
				cap += 4.0
				pool += float(item.get("pool", 0.0))
				if holder < 0:
					holder = int(idx)
			elif str(item.weapon) == "generator":
				regen += 4.0 * gen_mult
				cap += 12.0
				pool += float(item.get("pool", 0.0))
				if holder < 0:
					holder = int(idx)
		if holder < 0 and not (group as Array).is_empty():
			holder = int(group[0])
		pool = minf(cap, pool + regen * dt) if cap > 0.0 else 0.0
		for idx in group:
			stack[int(idx)]["pool"] = 0.0
		if holder >= 0:
			stack[holder]["pool"] = pool
		_seg_holder.append(holder)
		_seg_pool.append(pool)
	for i in stack.size():
		if int(_seg_of[i]) >= 0:
			continue
		var best := -1
		var best_pool := -1.0
		for neighbor in [i - 1, i + 1]:
			if neighbor < 0 or neighbor >= stack.size():
				continue
			var seg := int(_seg_of[neighbor])
			if seg < 0 or not _conducts(stack[neighbor]):
				continue
			if float(_seg_pool[seg]) > best_pool:
				best_pool = float(_seg_pool[seg])
				best = seg
		_seg_of[i] = best
	for i in stack.size():
		var seg := int(_seg_of[i])
		var lit := seg >= 0 and seg < _seg_pool.size() and float(_seg_pool[seg]) > 0.2
		stack[i]["lit"] = lit
		if lit and str(stack[i].weapon) not in ["none", "shield"]:
			peak_power = maxf(peak_power, float(_seg_pool[seg]))
		_paint_module(stack[i], lit)
	_update_wires()


func _can_spend(index: int, cost: float) -> bool:
	if cost <= 0.0:
		return true
	if index < 0 or index >= _seg_of.size():
		return false
	var seg := int(_seg_of[index])
	if seg < 0 or seg >= _seg_holder.size():
		return false
	var holder := int(_seg_holder[seg])
	if holder < 0:
		return false
	return float(stack[holder].get("pool", 0.0)) + 0.001 >= cost


func _spend(index: int, cost: float) -> bool:
	if cost <= 0.0:
		return true
	if not _can_spend(index, cost):
		return false
	var seg := int(_seg_of[index])
	var holder := int(_seg_holder[seg])
	var pool := float(stack[holder].get("pool", 0.0)) - cost
	stack[holder]["pool"] = pool
	_seg_pool[seg] = pool
	return true


func _tick_weapons(dt: float, enemies: Array) -> void:
	_tick_energy(dt)
	var balance := 1.0 - clampf(tilt_deg() / 24.0, 0.0, 1.0)
	var balance_mult := 0.55 + balance * 0.9
	if fire_buff > 0.0:
		balance_mult *= 1.35
	for index in stack.size():
		var item: Dictionary = stack[index]
		var spec: Dictionary = Catalog.WEAPONS.get(str(item.weapon), {})
		if spec.is_empty():
			continue
		var style := str(item.weapon)
		var cost := float(Catalog.ENERGY_COST.get(style, 0.0))
		if style == "spike" and has_relic("thirsty"):
			cost = 1.0
		var affordable := _can_spend(index, cost)
		var rate := balance_mult if affordable else 0.4
		item.cd = float(item.cd) - dt * rate
		if float(item.cd) > 0.0:
			continue
		if not affordable:
			if style in ["crystal", "crown"] or (style == "spike" and cost > 0.0):
				item.cd = 0.55
				_cough(item)
				continue
			item.cd = 1.6
			_fire_weapon(item, enemies, spec, balance_mult * 0.4, true)
			continue
		if not _spend(index, cost):
			item.cd = 0.3
			continue
		item.cd = float(spec.cd)
		var mult := balance_mult
		if has_relic("alchemist") and _touching_generators(item) > 0:
			mult *= 1.5
		if style == "spike" and has_relic("thirsty"):
			mult *= 2.0
		_fire_weapon(item, enemies, spec, mult, false)


func _fire_weapon(item: Dictionary, enemies: Array, spec: Dictionary, mult: float, dry: bool) -> void:
	var kind := str(spec.kind)
	var damage := float(spec.dmg) * cannon_mult * float(item.damage_mult) * mult
	var reach := float(spec.range)
	if str(item.weapon) == "spike" and has_relic("thirsty") and not dry:
		reach *= 1.65
	if kind == "aura":
		_aura(item, enemies, damage, reach)
		AudioDirector.play("dry" if dry else "spike")
	elif kind == "beam":
		_beam(item, enemies, damage, reach, dry)
	else:
		_bullet(item, enemies, spec, mult, dry)


func _cough(item: Dictionary) -> void:
	AudioDirector.play("dry")
	shots.append({
		"from": _muzzle(item, 0),
		"to": _muzzle(item, 0) + Vector3(0, 0.2, -0.4),
		"speed": 0.0,
		"damage": 0.0,
		"splash": 0.0,
		"beam": false,
		"style": "dry",
		"dry": true,
	})


func _bullet(item: Dictionary, enemies: Array, spec: Dictionary, balance_mult: float, dry: bool = false) -> void:
	var prefer := "flying" if str(item.weapon) == "crown" or (str(item.weapon) == "twin" and twin_air) else "any"
	if str(item.weapon) == "crown" and has_relic("crown_mark"):
		prefer = "flying"
	var target := _pick(enemies, float(spec.range), prefer)
	if target == null:
		item.cd = 0.12
		if dry:
			AudioDirector.play("dry")
		return
	var style := str(item.weapon)
	var splash := float(spec.splash)
	if style == "cannon" and splash_cannon:
		splash = maxf(splash, 1.15)
	if style == "missile":
		var grouped := _pick(enemies, float(spec.range), "armor")
		if grouped != null:
			target = grouped
	var pellets := 2 if style == "twin" else 1
	for i in pellets:
		var spread := -0.12 if i == 0 else 0.12
		if pellets == 1:
			spread = 0.0
		shots.append({
			"from": _muzzle(item, i),
			"to": target.global_position + Vector3(spread, 0.35, spread),
			"speed": float(spec.speed) * (0.72 if dry else 1.0),
			"damage": float(spec.dmg) * cannon_mult * float(item.damage_mult) * balance_mult,
			"splash": splash,
			"beam": false,
			"style": style,
			"dry": dry,
		})
	AudioDirector.play("dry" if dry else style)


func _beam(item: Dictionary, enemies: Array, damage: float, range: float, dry: bool = false) -> void:
	var prefer := "marked" if has_relic("crown_mark") else "high"
	var target := _pick(enemies, range, prefer)
	if target == null:
		item.cd = 0.05
		if dry:
			AudioDirector.play("dry")
		return
	if dry:
		AudioDirector.play("dry")
		return
	target.take_damage(damage, 0.0)
	var end: Vector3 = target.global_position
	if crystal_bounce:
		var bounce := _pick(enemies, range, "any", target)
		if bounce != null:
			bounce.take_damage(damage * 0.65, 0.0)
			end = bounce.global_position
	shots.append({
		"from": _muzzle(item, 0),
		"to": end,
		"speed": 0.0,
		"damage": 0.0,
		"splash": 0.0,
		"beam": true,
		"style": "crystal",
		"dry": false,
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
		var origin: Vector2 = item.get("offset", Vector2.ZERO)
		if Vector2(p.x, p.z).distance_to(origin) <= range:
			node.take_damage(damage, 0.0)
			shots.append({
				"from": _muzzle(item, 0),
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
		"offset": Vector2.ZERO,
		"face": 0,
		"span": float(def.get("span", 1.15)),
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
	var core := MeshInstance3D.new()
	core.name = "PowerCore"
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.2
	core.mesh = ball
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color("ff6a22")
	core_mat.emission_enabled = true
	core_mat.emission = Color("ff7a28")
	core_mat.emission_energy_multiplier = 2.4
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = core_mat
	core.position = Vector3(0, float(item.height) * 0.55, 0.48)
	core.visible = false
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(item.node as Node3D).add_child(core)
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
		var center := _item_center(item)
		var piece := _com_mass(item)
		acc += center * piece
		mass += piece
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
	for item in stack:
		if str(item.weapon) != "shield":
			continue
		var aim := _item_xz(item)
		if aim.length() < 0.08:
			aim = _rotate_flat(Vector2(0, 1), int(item.get("face", 0)))
		if aim.normalized().dot(hit_dir) > 0.15:
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
		if prefer == "marked" and float(node.marked) > 0.0:
			score += 14.0
		elif prefer == "flying" and node.def.get("flying", false):
			score += 8.0
		elif prefer == "high" and float(node.def.get("height_ratio", 0.0)) >= 0.4:
			score += 8.0
		elif prefer == "armor" and str(node.def.get("role", "")) == "armor":
			score += 6.0
		if has_relic("crown_mark") and float(node.marked) > 0.0:
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
		if has_relic("magnet"):
			mass *= 1.35
	var height := float(def.get("height", 0.9))
	var com := Catalog.com_of(def)
	var placed := _rotate_flat(Vector2(com.x, com.z), face) + preview_offset()
	var center := Vector3(placed.x, total_height + height * 0.5, placed.y)
	if not supported_here():
		return false
	var acc := Vector3.ZERO
	var total := 0.0
	for item in stack:
		var c := _item_center(item)
		var piece := _com_mass(item)
		acc += c * piece
		total += piece
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
		var pull := _item_xz(item).length() * float(item.mass)
		if pull > worst_pull and str(item.id) != "01_base_plate":
			worst_pull = pull
			worst = str(item.id)
	return worst


func _muzzle(item: Dictionary, which: int = 0) -> Vector3:
	var def := Catalog.module(str(item.id))
	var key := "muzzle2" if which == 1 and def.has("muzzle2") else "muzzle"
	var raw = def.get(key, null)
	var local := Vector3(float(item.com.x), float(item.height) * 0.62, float(item.com.z))
	if raw is Array and raw.size() >= 3:
		local = Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	var flat := _rotate_flat(Vector2(local.x, local.z), int(item.get("face", 0)))
	var spot: Vector2 = item.get("offset", Vector2.ZERO)
	var point := Vector3(flat.x + spot.x, float(item.base_y) + local.y, flat.y + spot.y)
	return _lean.global_transform * point


func _top_world() -> float:
	return total_height * cos(Vector2(tilt_x, tilt_z).length())


func preview_offset() -> Vector2:
	var base := Vector2.ZERO
	if not stack.is_empty():
		base = stack.back().get("offset", Vector2.ZERO)
	return base + Vector2(float(stud) * STUD, 0.0)


func supported_here() -> bool:
	if stack.is_empty():
		return true
	var top: Dictionary = stack.back()
	var delta: Vector2 = preview_offset() - Vector2(top.get("offset", Vector2.ZERO))
	return delta.length() <= float(top.get("span", 0.5)) + 0.02


func _rotate_flat(v: Vector2, quarter: int) -> Vector2:
	var ang := float(quarter) * PI * 0.5
	var c := cos(ang)
	var s := sin(ang)
	return Vector2(v.x * c - v.y * s, v.x * s + v.y * c)


func _item_xz(item: Dictionary) -> Vector2:
	var com: Vector3 = item.com
	return _rotate_flat(Vector2(com.x, com.z), int(item.get("face", 0))) + Vector2(item.get("offset", Vector2.ZERO))


func _item_center(item: Dictionary) -> Vector3:
	var flat := _item_xz(item)
	return Vector3(flat.x, float(item.base_y) + float(item.height) * 0.5, flat.y)


func _touching_generators(item: Dictionary) -> int:
	var count := 0
	var here := Vector2(item.get("offset", Vector2.ZERO))
	for other in stack:
		if other == item or str(other.weapon) != "generator":
			continue
		var there := Vector2(other.get("offset", Vector2.ZERO))
		if here.distance_to(there) <= STUD * 1.45:
			count += 1
	return count


func _refresh_ghost_pose() -> void:
	_place_studs()
	if _ghost == null:
		return
	var spot := preview_offset()
	_ghost.position = Vector3(spot.x, total_height, spot.y)
	_ghost.rotation.y = float(face) * PI * 0.5
	if _ghost_id == "":
		return
	var good := would_improve(_ghost_id)
	if good != ghost_good:
		ghost_good = good
		ModelUtil.ghost(_ghost, ghost_good)


func _build_studs() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.07
	mesh.bottom_radius = 0.09
	mesh.height = 0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f2e2a0")
	mat.emission_enabled = true
	mat.emission = Color("ffe08a")
	mat.emission_energy_multiplier = 0.4
	for _i in 7:
		var mark := MeshInstance3D.new()
		mark.mesh = mesh
		mark.material_override = mat
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lean.add_child(mark)
		_stud_marks.append(mark)


func _place_studs() -> void:
	if _stud_marks.is_empty() or stack.is_empty():
		return
	var top: Dictionary = stack.back()
	var origin: Vector2 = top.get("offset", Vector2.ZERO)
	var y := total_height + 0.04
	var span := stud_span()
	for i in _stud_marks.size():
		var stud_i := i - 3
		var x := origin.x + float(stud_i) * STUD
		_stud_marks[i].position = Vector3(x, y, origin.y)
		_stud_marks[i].visible = alive and not falling and absi(stud_i) <= span


func _tick_junk(dt: float) -> void:
	var i := 0
	while i < _junk.size():
		var bit: Dictionary = _junk[i]
		var node: Node3D = bit.node
		if not is_instance_valid(node):
			_junk.remove_at(i)
			continue
		var vel: Vector3 = bit.vel
		vel.y -= 12.0 * dt
		bit.vel = vel
		node.position += vel * dt
		node.rotate_z(4.0 * dt)
		if node.position.y < -1.2:
			node.queue_free()
			_junk.remove_at(i)
		else:
			i += 1


func _apply_visual() -> void:
	if _yaw_pivot:
		_yaw_pivot.rotation.y = yaw
	if _lean:
		var extra := 0.0
		if tilt_deg() >= DANGER_DEG:
			_sway += 0.35
			extra = sin(_sway) * deg_to_rad(1.6)
		_lean.rotation = Vector3(tilt_z + extra, 0.0, -tilt_x)


func _paint_module(item: Dictionary, lit: bool) -> void:
	var node := item.get("node") as Node3D
	if node == null:
		return
	var core := node.get_node_or_null("PowerCore")
	if core is MeshInstance3D:
		core.visible = lit
	var weapon := str(item.get("weapon", "none"))
	var dim := not lit and weapon in ["cannon", "twin", "missile", "crown", "crystal"]
	if bool(item.get("dimmed", false)) == dim:
		return
	item["dimmed"] = dim
	ModelUtil.dim(node, dim)


func _update_wires() -> void:
	if _wires.is_empty():
		for _i in 12:
			var mesh_node := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.12
			mesh.bottom_radius = 0.12
			mesh.height = 1.0
			mesh_node.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("ff6a2a")
			mat.emission_enabled = true
			mat.emission = Color("ff7a32")
			mat.emission_energy_multiplier = 2.6
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh_node.material_override = mat
			mesh_node.visible = false
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_lean.add_child(mesh_node)
			_wires.append(mesh_node)
	var pairs: Array[Vector3] = []
	for i in range(maxi(stack.size() - 1, 0)):
		if i >= _seg_of.size() or i + 1 >= _seg_of.size():
			break
		var seg := int(_seg_of[i])
		if seg < 0 or seg != int(_seg_of[i + 1]):
			continue
		if not _conducts(stack[i]) or not _conducts(stack[i + 1]):
			continue
		if seg >= _seg_pool.size() or float(_seg_pool[seg]) <= 0.2:
			continue
		pairs.append(_item_center(stack[i]))
		pairs.append(_item_center(stack[i + 1]))
	var shown := mini(pairs.size() / 2, _wires.size())
	for w in _wires.size():
		var wire := _wires[w]
		if w >= shown:
			wire.visible = false
			continue
		var az: Vector3 = pairs[w * 2]
		var bz: Vector3 = pairs[w * 2 + 1]
		var front := maxf(az.z, bz.z) + 0.92
		var a := Vector3(az.x, az.y, front)
		var b := Vector3(bz.x, bz.y, front)
		var diff := b - a
		var up := diff.normalized() if diff.length() > 0.001 else Vector3.UP
		var side := up.cross(Vector3.RIGHT)
		if side.length() < 0.001:
			side = up.cross(Vector3.FORWARD)
		side = side.normalized()
		var fwd := side.cross(up).normalized()
		var basis := Basis(side, up * diff.length(), fwd)
		wire.transform = Transform3D(basis, (a + b) * 0.5)
		wire.visible = true
