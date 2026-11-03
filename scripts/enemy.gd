class_name Enemy
extends Node3D

signal died

var kind := ""
var hp := 10.0
var speed := 1.0
var impulse := 1.0
var flying := false
var height_ratio := 0.0
var attack_period := 1.0
var hit_radius := 1.3
var dead := false
var elite := false
var boss := false
var def: Dictionary = {}
var role := ""
var armor := 1.0
var splash_taken := 1.0
var death_push := 0.0
var max_hp := 1.0
var slow := 1.0
var _attack := 0.0
var _angle := 0.0
var _phase := 0.0
var _anim: AnimationPlayer
var _base_scale := Vector3.ONE
var _hit := 0.0
var _dying := false
var _doomed := false
var _die_in := 0.0
var _windup := 0.0
var _mark: MeshInstance3D
var _visual: Node3D
var _tint := Color.WHITE
var _flashed := false
var _warn: MeshInstance3D
var _bar: MeshInstance3D


func setup(def: Dictionary, wave: int, as_elite: bool, as_boss: bool = false) -> void:
	self.def = def
	kind = str(def.id)
	elite = as_elite or as_boss
	boss = as_boss
	role = str(def.get("role", ""))
	armor = float(def.get("armor", 1.0))
	splash_taken = float(def.get("splash_taken", 1.0))
	death_push = float(def.get("death_push", 0.0))
	flying = bool(def.flying)
	speed = float(def.speed)
	impulse = float(def.impulse)
	height_ratio = float(def.height_ratio)
	attack_period = float(def.attack)
	hit_radius = float(def.radius)
	hp = float(def.hp) * (1.0 + float(wave - 1) * 0.12)
	if GameState.heat:
		hp *= 1.45
		impulse *= 1.35
	if boss:
		hp *= 4.2
		impulse *= 1.6
		speed *= 0.86
	elif elite:
		hp *= 1.8
		impulse *= 1.4
		speed *= 1.08
	max_hp = hp
	_angle = randf() * TAU
	_phase = randf() * TAU
	var visual := ModelUtil.instantiate("creatures", kind)
	add_child(visual)
	ModelUtil.fit(visual, float(def.visual_height))
	var tint := Color(1, 1, 1)
	if boss:
		tint = Color(0.95, 0.42, 0.28)
		scale = Vector3.ONE * 1.85
	elif elite:
		tint = Color(0.62, 0.48, 0.46)
		scale = Vector3.ONE * 1.32
	else:
		var palette := [
			Color(1.0, 1.0, 1.0),
			Color(0.72, 0.95, 0.78),
			Color(1.0, 0.8, 0.68),
			Color(0.72, 0.8, 1.0),
			Color(0.92, 0.74, 1.0),
		]
		tint = palette[randi() % palette.size()]
		scale = Vector3.ONE * randf_range(0.78, 1.14)
	ModelUtil.tint(visual, tint)
	_tint = tint
	_visual = visual
	_base_scale = scale
	_anim = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("fly" if flying else "move")
	if death_push > 0.0:
		_warn = MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.16
		ball.height = 0.32
		_warn.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("ff4d3a")
		mat.emission_enabled = true
		mat.emission = Color("ff4d3a")
		mat.emission_energy_multiplier = 2.4
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_warn.material_override = mat
		_warn.position = Vector3(0, float(def.visual_height) + 0.25, 0)
		add_child(_warn)
	if boss:
		_bar = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 0.08, 0.08)
		_bar.mesh = box
		var bar_mat := StandardMaterial3D.new()
		bar_mat.albedo_color = Color("ffd15a")
		bar_mat.emission_enabled = true
		bar_mat.emission = Color("ffd15a")
		bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bar.material_override = bar_mat
		_bar.position = Vector3(0, float(def.visual_height) + 0.55, 0)
		add_child(_bar)


func take_damage(amount: float, splash: float = 0.0) -> void:
	if dead:
		return
	var mul := splash_taken if splash > 0.0 else armor
	hp -= amount * mul
	_hit = 0.16
	_flashed = false
	if hp <= 0.0 and not dead and not _doomed:
		_doomed = true
		_die_in = 0.34
		_play("attack")
		_ground_mark()


func tick(dt: float, tower) -> void:
	_hit = maxf(_hit - dt, 0.0)
	if _dying:
		scale = scale.lerp(Vector3.ONE * 0.02, 1.0 - exp(-10.0 * dt))
		position.y += dt * 0.8
		if scale.x < 0.08:
			queue_free()
		return
	if dead or not tower.alive:
		return
	if _doomed and not dead:
		_die_in -= dt
		scale = _base_scale * (1.2 + sin(Time.get_ticks_msec() * 0.02) * 0.08)
		if _die_in <= 0.0:
			dead = true
			_dying = true
			died.emit()
		return
	scale = _base_scale * (1.0 + _hit * 1.8)
	if _visual != null and _hit > 0.08 and not _flashed:
		_flashed = true
		ModelUtil.tint(_visual, Color(1.0, 0.96, 0.82))
	elif _visual != null and _hit <= 0.0 and _flashed:
		_flashed = false
		ModelUtil.tint(_visual, _tint)
	if _warn != null:
		_warn.scale = Vector3.ONE * (1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.012))
	if _bar != null:
		_bar.scale.x = clampf(hp / maxf(max_hp, 0.01), 0.05, 1.0)
	var flat := Vector2(global_position.x, global_position.z)
	var dist := flat.length()
	var moving := dist > hit_radius
	if moving:
		_step_toward(dt, tower)
		_play("fly" if flying else "move")
	else:
		_hold_attack(dt, tower)
	var face := Vector2(-global_position.x, -global_position.z)
	if face.length() > 0.05:
		rotation.y = atan2(face.x, face.y)
	if role == "bomb" and hp < max_hp * 0.45:
		_ground_mark()


func clip_name() -> String:
	if _anim == null:
		return ""
	return String(_anim.current_animation)


func _step_toward(dt: float, tower: Tower) -> void:
	var flat := Vector2(global_position.x, global_position.z)
	var dist := maxf(flat.length(), 0.001)
	var dir := -flat / dist
	var pace := speed * slow
	if role == "armor":
		dir = Vector2(dir.x + cos(_phase + Time.get_ticks_msec() * 0.002) * 0.65, dir.y).normalized()
		pace *= 0.85
	elif role == "tank":
		pace *= 0.72
	elif role == "skirmish":
		pace *= 1.25
	global_position += Vector3(dir.x, 0, dir.y) * pace * dt
	if flying:
		var y := 0.85 + tower.total_height * height_ratio
		if role == "skirmish":
			y += sin(_phase + Time.get_ticks_msec() * 0.01) * 0.12
		elif role == "high":
			y += sin(_phase) * 0.2 + 0.35
		global_position.y = lerpf(global_position.y, y, 1.0 - exp(-6.0 * dt))
	else:
		global_position.y = 0.0


func _hold_attack(dt: float, tower: Tower) -> void:
	if flying:
		global_position.y = 0.85 + tower.total_height * height_ratio + sin(Time.get_ticks_msec() * 0.006) * 0.08
	if _windup > 0.0:
		_windup -= dt
		if _windup <= 0.0:
			tower.apply_hit(global_position, impulse, height_ratio)
			_play("idle")
		return
	_attack -= dt
	if _attack <= 0.0:
		_attack = attack_period
		_windup = 0.42 if role == "tank" else 0.2
		_play("attack")
		return
	if clip_name() != "attack":
		_play("idle")


func _ground_mark() -> void:
	if _mark != null:
		return
	_mark = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.28
	ring.outer_radius = 0.42
	_mark.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff4d3a")
	mat.emission_enabled = true
	mat.emission = Color("ff4d3a")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark.material_override = mat
	_mark.position = Vector3(0, 0.05, 0)
	add_child(_mark)


func _play(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation == clip and _anim.is_playing():
		return
	_anim.play(clip)
	_anim.speed_scale = 1.35 if clip == "attack" else clampf(speed * 0.55, 0.8, 1.8)
	if not _anim.animation_finished.is_connected(_on_anim_finished):
		_anim.animation_finished.connect(_on_anim_finished)


func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == "attack" and not dead:
		_play("idle")
