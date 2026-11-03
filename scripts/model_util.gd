class_name ModelUtil

static var _cache: Dictionary = {}

const FALLBACK := {
	"01_base_plate": Color("8a6a45"),
	"02_side_cannon": Color("b85a32"),
	"03_twin_guns": Color("c46b3a"),
	"04_generator": Color("3f8f86"),
	"05_kaiju_bust": Color("6d645c"),
	"06_shield_slab": Color("8d939c"),
	"07_spike_drum": Color("a34b3c"),
	"08_missile_rack": Color("c9842f"),
	"09_crystal_spur": Color("e36b2c"),
	"10_crown_nest": Color("d7a441"),
	"01_ram_beetle": Color("7a5a32"),
	"02_smash_crab": Color("8d4b3a"),
	"03_iron_slug": Color("5c6a62"),
	"04_manta_bat": Color("6a5a78"),
	"05_sting_wasp": Color("c4a03a"),
	"06_bloated_tick": Color("6e4a52"),
}


static func instantiate(kind: String, id: String) -> Node3D:
	var path := "res://assets/models/%s/%s.glb" % [kind, id]
	if ResourceLoader.exists(path):
		if not _cache.has(path):
			_cache[path] = load(path)
		var packed = _cache[path]
		if packed is PackedScene:
			var node := (packed as PackedScene).instantiate()
			if node is Node3D:
				_silence(node)
				return node
	return _box(id)


static func _box(id: String) -> Node3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	if id.begins_with("01_base"):
		mesh.size = Vector3(1.8, 0.45, 1.8)
	elif id.begins_with("05_"):
		mesh.size = Vector3(0.7, 1.2, 0.7)
	else:
		mesh.size = Vector3(0.85, 0.85, 0.85)
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FALLBACK.get(id, Color("888888"))
	mat.roughness = 0.72
	mesh_node.material_override = mat
	mesh_node.position.y = mesh.size.y * 0.5
	var root := Node3D.new()
	root.add_child(mesh_node)
	return root


static func fit(node: Node3D, target_height: float) -> void:
	var ab := local_aabb(node)
	var h := maxf(ab.size.y, 0.001)
	var s := target_height / h
	node.scale = Vector3(s, s, s)
	var min_y := ab.position.y * s
	var center_x := (ab.position.x + ab.size.x * 0.5) * s
	var center_z := (ab.position.z + ab.size.z * 0.5) * s
	node.position += Vector3(-center_x, -min_y, -center_z)
	_no_shadow(node)


static func local_aabb(node: Node3D) -> AABB:
	var found := false
	var box := AABB()
	var inv: Transform3D = node.global_transform.affine_inverse()
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child)
	for mi in meshes:
		var xf: Transform3D = inv * mi.global_transform
		var ab: AABB = xf * mi.get_aabb()
		if not found:
			box = ab
			found = true
		else:
			box = box.merge(ab)
	if not found:
		return AABB(Vector3.ZERO, Vector3.ONE)
	return box


static func dim(node: Node3D, on: bool) -> void:
	for mi in _meshes(node):
		if mi.name == "PowerCore":
			continue
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var current = mi.get_surface_override_material(i)
			if current == null:
				current = mi.get_active_material(i)
			if current == null or not (current is StandardMaterial3D):
				continue
			var std := (current as StandardMaterial3D).duplicate() as StandardMaterial3D
			if not mi.has_meta("base_albedo_%d" % i):
				mi.set_meta("base_albedo_%d" % i, std.albedo_color)
				mi.set_meta("base_emission_tex_%d" % i, std.emission_texture)
				mi.set_meta("base_emission_%d" % i, std.emission)
				mi.set_meta("base_emission_energy_%d" % i, std.emission_energy_multiplier)
			var base: Color = mi.get_meta("base_albedo_%d" % i)
			if on:
				std.albedo_color = base.lerp(Color(0.16, 0.16, 0.18), 0.78)
				std.emission_enabled = true
				std.emission_texture = null
				std.emission = Color(0.02, 0.02, 0.025)
				std.emission_energy_multiplier = 0.0
			else:
				std.albedo_color = base
				std.emission_enabled = true
				std.emission_texture = mi.get_meta("base_emission_tex_%d" % i)
				std.emission = mi.get_meta("base_emission_%d" % i)
				std.emission_energy_multiplier = float(mi.get_meta("base_emission_energy_%d" % i))
			mi.set_surface_override_material(i, std)


static func outline(node: Node3D, color: Color) -> void:
	var shader := load("res://shaders/rim.gdshader") as Shader
	if shader == null:
		return
	for mi in _meshes(node):
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("rim_color", color)
		mat.set_shader_parameter("push", 0.055)
		mi.material_overlay = mat


static func tint(node: Node3D, color: Color) -> void:
	for mi in _meshes(node):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat = mi.get_active_material(i)
			if mat == null:
				continue
			var dup = mat.duplicate()
			if dup is StandardMaterial3D:
				var std := dup as StandardMaterial3D
				std.albedo_color = color
				std.roughness = 0.42
				std.metallic = 0.08
				std.emission_enabled = true
				std.emission = Color(color.r, color.g, color.b, 1.0)
				std.emission_energy_multiplier = 0.22
				mi.set_surface_override_material(i, std)
			elif dup is BaseMaterial3D:
				(dup as BaseMaterial3D).albedo_color = color
				mi.set_surface_override_material(i, dup)


static func ghost(node: Node3D, good: bool = true) -> void:
	var tint := Color(0.45, 0.95, 0.55, 0.42) if good else Color(0.95, 0.32, 0.28, 0.42)
	for mi in _meshes(node):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var std := StandardMaterial3D.new()
			std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			std.albedo_color = tint
			std.emission_enabled = true
			std.emission = Color(tint.r, tint.g, tint.b, 1.0)
			std.emission_energy_multiplier = 0.6
			std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			std.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.set_surface_override_material(i, std)


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child)
	return meshes


static func _no_shadow(node: Node) -> void:
	for mi in _meshes(node):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


static func _silence(node: Node) -> void:
	for found in node.find_children("*", "AnimationPlayer", true, false):
		var player := found as AnimationPlayer
		player.active = true
		for anim_name in player.get_animation_list():
			var anim: Animation = player.get_animation(anim_name)
			if anim_name == "attack":
				anim.loop_mode = Animation.LOOP_NONE
			else:
				anim.loop_mode = Animation.LOOP_LINEAR
		if player.has_animation("idle"):
			player.play("idle")
