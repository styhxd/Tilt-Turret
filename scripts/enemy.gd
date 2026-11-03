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
var _attack := 0.0
var _angle := 0.0
var _phase := 0.0
var _anim: AnimationPlayer
var _base_scale := Vector3.ONE
var _hit := 0.0
var _dying := false
var _visual: Node3D


func setup(def: Dictionary, wave: int, as_elite: bool) -> void:
	kind = str(def.id)
	elite = as_elite
	flying = bool(def.flying)
	speed = float(def.speed)
	impulse = float(def.impulse)
	height_ratio = float(def.height_ratio)
	attack_period = float(def.attack)
	hit_radius = float(def.radius)
	hp = float(def.hp) * (1.0 + float(wave - 1) * 0.12)
	if elite:
		hp *= 1.8
		impulse *= 1.4
		speed *= 1.08
	_angle = randf() * TAU
	_phase = randf() * TAU
	var visual := ModelUtil.instantiate("creatures", kind)
	add_child(visual)
	ModelUtil.fit(visual, float(def.visual_height))
	var tint := Color(1, 1, 1)
	if elite:
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
	_visual = visual
	_base_scale = scale
	_anim = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("fly" if flying else "move")


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	_hit = 0.16
	if hp <= 0.0 and not dead:
		dead = true
		_dying = true
		died.emit()


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
	scale = _base_scale * (1.0 + _hit * 1.8)
	_attack -= dt
	if flying:
		_tick_fly(dt, tower)
	else:
		_tick_ground(dt, tower)
	rotation.y = atan2(global_position.x, global_position.z)


func _tick_ground(dt: float, tower: Tower) -> void:
	var flat := Vector2(global_position.x, global_position.z)
	var dist := flat.length()
	if dist > hit_radius:
		var dir := -flat / maxf(dist, 0.001)
		global_position += Vector3(dir.x, 0, dir.y) * speed * dt
		global_position.y = 0.0
	elif _attack <= 0.0:
		_attack = attack_period
		_play("attack")
		tower.apply_hit(global_position, impulse, height_ratio)


func _tick_fly(dt: float, tower: Tower) -> void:
	_angle += speed * 0.22 * dt
	var dist := Vector2(global_position.x, global_position.z).length()
	var want := hit_radius if dist < 4.2 else 6.4
	var y := 0.7 + tower.total_height * height_ratio + sin(_phase + _angle) * 0.15
	var target := Vector3(cos(_angle) * want, y, sin(_angle) * want)
	var to := target - global_position
	var step := speed * dt
	if to.length() > step:
		global_position += to.normalized() * step
	else:
		global_position = target
	if dist <= hit_radius + 0.35 and _attack <= 0.0:
		_attack = attack_period
		_play("attack")
		tower.apply_hit(global_position, impulse, height_ratio)


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
		_play("fly" if flying else "move")
