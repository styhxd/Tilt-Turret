extends Node

const SAVE_PATH := "user://save.cfg"
const MAX_UPGRADE := 10

var coins: int = 0
var best_height: int = 0
var best_kills: int = 0
var best_score: int = 0
var runs: int = 0
var tutorial_done: bool = false
var locale: String = "pt"
var sfx_on: bool = true
var music_on: bool = true
var ads_removed: bool = false
var last_daily: String = ""
var upgrade_statue: int = 0
var upgrade_cannon: int = 0
var upgrade_generator: int = 0
var plant_splash: bool = false
var plant_air: bool = false
var plant_bounce: bool = false
var heat: bool = false
var pact_shell: bool = false
var pact_gust: bool = false
var pact_noglue: bool = false
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var seen_ids: String = ""
var daily_pact: String = ""
var daily_pact_day: String = ""
var toy_ghost: bool = false
var toy_base_gen: bool = false
var toy_relic: bool = false
var toy_stud: bool = false
var legacy_refunded: bool = false
var dusk_open: bool = false
var last_interstitial_msec: int = -100000
var last_rewarded_msec: int = -100000


func _ready() -> void:
	load_game()
	process_mode = Node.PROCESS_MODE_ALWAYS


func text(key: String) -> String:
	return Locale.t(key)


func upgrade_level(stat: String) -> int:
	match stat:
		"statue":
			return upgrade_statue
		"cannon":
			return upgrade_cannon
		"generator":
			return upgrade_generator
	return 0


func multiplier(_stat: String) -> float:
	return 1.0


func upgrade_blurb(stat: String) -> String:
	var level := upgrade_level(stat)
	var mark := 3
	if level >= 3:
		mark = 6
	if level >= 6:
		mark = 10
	return text("%s_%d" % [stat, mark])


func coin_heat() -> bool:
	return pact_shell and pact_gust and pact_noglue


func toggle_pact(which: String) -> void:
	match which:
		"shell":
			pact_shell = not pact_shell
		"gust":
			pact_gust = not pact_gust
		"glue":
			pact_noglue = not pact_noglue
	heat = coin_heat()
	save_game()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_game()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	save_game()


func has_seen(id: String) -> bool:
	return id in seen_ids.split(",", false)


func mark_seen(id: String) -> void:
	if id == "" or has_seen(id):
		return
	seen_ids = id if seen_ids == "" else seen_ids + "," + id
	save_game()


func ensure_daily_pact() -> void:
	var today := Time.get_date_string_from_system()
	if daily_pact_day == today and daily_pact != "":
		return
	var opts := ["shell", "gust", "glue"]
	daily_pact = opts[absi(today.hash()) % opts.size()]
	daily_pact_day = today
	save_game()


func daily_matches() -> bool:
	match daily_pact:
		"shell":
			return pact_shell
		"gust":
			return pact_gust
		"glue":
			return pact_noglue
	return false


func upgrade_cost(level: int) -> int:
	return 40 + level * 35


func plant_cost(id: String) -> int:
	match id:
		"splash":
			return 80
		"air":
			return 110
		"bounce":
			return 140
	return 9999


func plant_owned(id: String) -> bool:
	match id:
		"splash":
			return plant_splash
		"air":
			return plant_air
		"bounce":
			return plant_bounce
	return false


func try_buy_plant(id: String) -> bool:
	if plant_owned(id):
		return false
	var cost := plant_cost(id)
	if coins < cost:
		return false
	coins -= cost
	match id:
		"splash":
			plant_splash = true
		"air":
			plant_air = true
		"bounce":
			plant_bounce = true
		_:
			return false
	save_game()
	return true


func try_buy_toy(id: String) -> bool:
	if toy_owned(id):
		return false
	var cost := toy_cost(id)
	if coins < cost:
		return false
	coins -= cost
	match id:
		"ghost":
			toy_ghost = true
		"base_gen":
			toy_base_gen = true
		"relic":
			toy_relic = true
		"stud":
			toy_stud = true
		_:
			return false
	save_game()
	return true


func toy_owned(id: String) -> bool:
	match id:
		"ghost":
			return toy_ghost
		"base_gen":
			return toy_base_gen
		"relic":
			return toy_relic
		"stud":
			return toy_stud
	return false


func toy_cost(id: String) -> int:
	match id:
		"ghost":
			return 90
		"base_gen":
			return 120
		"relic":
			return 150
		"stud":
			return 160
	return 9999


func _refund_legacy() -> void:
	if legacy_refunded:
		return
	var grant := _spent(upgrade_statue) + _spent(upgrade_cannon) + _spent(upgrade_generator)
	coins += grant
	upgrade_statue = 0
	upgrade_cannon = 0
	upgrade_generator = 0
	legacy_refunded = true
	save_game()


func _spent(level: int) -> int:
	var total := 0
	for i in level:
		total += 40 + i * 35
	return total


func set_heat(on: bool) -> void:
	heat = on
	pact_shell = on
	pact_gust = on
	pact_noglue = on
	save_game()


func try_buy(stat: String) -> bool:
	var level := upgrade_level(stat)
	if level >= MAX_UPGRADE:
		return false
	var cost := upgrade_cost(level)
	if coins < cost:
		return false
	coins -= cost
	_set_upgrade(stat, level + 1)
	save_game()
	return true


func _set_upgrade(stat: String, level: int) -> void:
	match stat:
		"statue":
			upgrade_statue = level
		"cannon":
			upgrade_cannon = level
		"generator":
			upgrade_generator = level


func mark_rewarded() -> void:
	last_rewarded_msec = Time.get_ticks_msec()


func mark_interstitial() -> void:
	last_interstitial_msec = Time.get_ticks_msec()


func interstitial_allowed() -> bool:
	if ads_removed:
		return false
	if runs < 3:
		return false
	var now := Time.get_ticks_msec()
	if now - last_interstitial_msec < 90000:
		return false
	if now - last_rewarded_msec < 5000:
		return false
	return true


func consume_daily() -> bool:
	var today := Time.get_date_string_from_system()
	if last_daily == today:
		return false
	last_daily = today
	save_game()
	return true


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		if OS.get_locale().begins_with("en"):
			locale = "en"
		else:
			locale = "pt"
		return
	coins = int(cf.get_value("p", "coins", 0))
	best_height = int(cf.get_value("p", "best_height", 0))
	best_kills = int(cf.get_value("p", "best_kills", 0))
	best_score = int(cf.get_value("p", "best_score", 0))
	runs = int(cf.get_value("p", "runs", 0))
	tutorial_done = bool(cf.get_value("p", "tutorial_done", false))
	locale = str(cf.get_value("p", "locale", "pt"))
	sfx_on = bool(cf.get_value("p", "sfx_on", true))
	music_on = bool(cf.get_value("p", "music_on", true))
	ads_removed = bool(cf.get_value("p", "ads_removed", false))
	last_daily = str(cf.get_value("p", "last_daily", ""))
	upgrade_statue = int(cf.get_value("p", "upgrade_statue", 0))
	upgrade_cannon = int(cf.get_value("p", "upgrade_cannon", 0))
	upgrade_generator = int(cf.get_value("p", "upgrade_generator", 0))
	plant_splash = bool(cf.get_value("p", "plant_splash", false))
	plant_air = bool(cf.get_value("p", "plant_air", false))
	plant_bounce = bool(cf.get_value("p", "plant_bounce", false))
	heat = bool(cf.get_value("p", "heat", false))
	var legacy_heat := heat
	pact_shell = bool(cf.get_value("p", "pact_shell", legacy_heat))
	pact_gust = bool(cf.get_value("p", "pact_gust", legacy_heat))
	pact_noglue = bool(cf.get_value("p", "pact_noglue", legacy_heat))
	heat = pact_shell and pact_gust and pact_noglue
	sfx_volume = float(cf.get_value("p", "sfx_volume", 1.0))
	music_volume = float(cf.get_value("p", "music_volume", 1.0))
	seen_ids = str(cf.get_value("p", "seen_ids", ""))
	daily_pact = str(cf.get_value("p", "daily_pact", ""))
	daily_pact_day = str(cf.get_value("p", "daily_pact_day", ""))
	toy_ghost = bool(cf.get_value("p", "toy_ghost", false))
	toy_base_gen = bool(cf.get_value("p", "toy_base_gen", false))
	toy_relic = bool(cf.get_value("p", "toy_relic", false))
	toy_stud = bool(cf.get_value("p", "toy_stud", false))
	legacy_refunded = bool(cf.get_value("p", "legacy_refunded", false))
	dusk_open = bool(cf.get_value("p", "dusk_open", false))
	_refund_legacy()


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "coins", coins)
	cf.set_value("p", "best_height", best_height)
	cf.set_value("p", "best_kills", best_kills)
	cf.set_value("p", "best_score", best_score)
	cf.set_value("p", "runs", runs)
	cf.set_value("p", "tutorial_done", tutorial_done)
	cf.set_value("p", "locale", locale)
	cf.set_value("p", "sfx_on", sfx_on)
	cf.set_value("p", "music_on", music_on)
	cf.set_value("p", "ads_removed", ads_removed)
	cf.set_value("p", "last_daily", last_daily)
	cf.set_value("p", "upgrade_statue", upgrade_statue)
	cf.set_value("p", "upgrade_cannon", upgrade_cannon)
	cf.set_value("p", "upgrade_generator", upgrade_generator)
	cf.set_value("p", "plant_splash", plant_splash)
	cf.set_value("p", "plant_air", plant_air)
	cf.set_value("p", "plant_bounce", plant_bounce)
	cf.set_value("p", "heat", heat)
	cf.set_value("p", "pact_shell", pact_shell)
	cf.set_value("p", "pact_gust", pact_gust)
	cf.set_value("p", "pact_noglue", pact_noglue)
	cf.set_value("p", "sfx_volume", sfx_volume)
	cf.set_value("p", "music_volume", music_volume)
	cf.set_value("p", "seen_ids", seen_ids)
	cf.set_value("p", "daily_pact", daily_pact)
	cf.set_value("p", "daily_pact_day", daily_pact_day)
	cf.set_value("p", "toy_ghost", toy_ghost)
	cf.set_value("p", "toy_base_gen", toy_base_gen)
	cf.set_value("p", "toy_relic", toy_relic)
	cf.set_value("p", "toy_stud", toy_stud)
	cf.set_value("p", "legacy_refunded", legacy_refunded)
	cf.set_value("p", "dusk_open", dusk_open)
	cf.save(SAVE_PATH)
