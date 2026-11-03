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
	world.start_run(true)
	world.add_yaw(0.9)
	await get_tree().create_timer(0.15).timeout
	world.request_drop()
	await get_tree().create_timer(1.1).timeout
	var stack_n := world.tower.stack.size()
	var tilt := world.tower.tilt_deg()
	print("SMOKE stack=", stack_n, " tilt=", snappedf(tilt, 0.01), " alive=", world.tower.alive, " tutorial=", world._tutorial)
	if stack_n < 2 or not world.tower.alive:
		get_tree().quit(1)
		return
	get_tree().quit(0)
