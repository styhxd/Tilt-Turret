class_name Catalog

static var _modules: Dictionary = {}
static var _creatures: Dictionary = {}
static var _waves: Array = []
static var _dusk: Array = []
static var _ready := false

const DROP_IDS: Array[String] = [
	"02_side_cannon", "03_twin_guns", "04_generator", "05_kaiju_bust",
	"06_shield_slab", "07_spike_drum", "08_missile_rack", "09_crystal_spur", "10_crown_nest",
]
const LIGHT_IDS: Array[String] = ["04_generator", "08_missile_rack", "09_crystal_spur", "10_crown_nest"]
const HEAVY_IDS: Array[String] = ["05_kaiju_bust", "06_shield_slab", "07_spike_drum"]

const WEAPONS := {
	"cannon": {"cd": 0.68, "dmg": 12.0, "speed": 22.0, "range": 10.5, "splash": 0.0, "kind": "bullet"},
	"twin": {"cd": 0.30, "dmg": 7.0, "speed": 24.0, "range": 10.5, "splash": 0.0, "kind": "bullet"},
	"missile": {"cd": 1.25, "dmg": 16.0, "speed": 13.0, "range": 11.0, "splash": 1.55, "kind": "bullet"},
	"crown": {"cd": 0.42, "dmg": 9.0, "speed": 26.0, "range": 10.5, "splash": 0.0, "kind": "bullet"},
	"crystal": {"cd": 0.14, "dmg": 3.4, "speed": 0.0, "range": 8.6, "splash": 0.0, "kind": "beam"},
	"spike": {"cd": 0.28, "dmg": 5.0, "speed": 0.0, "range": 1.75, "splash": 0.0, "kind": "aura"},
}


static func ensure() -> void:
	if _ready:
		return
	_modules = _load_map("res://data/modules.json")
	_creatures = _load_map("res://data/creatures.json")
	_waves = _load_list("res://data/waves.json")
	_dusk = _load_list("res://data/waves_dusk.json")
	_ready = true


static func _load_list(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data %s" % path)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Bad data %s" % path)
		return []
	return parsed


static func _load_map(path: String) -> Dictionary:
	var out := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data %s" % path)
		return out
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Bad data %s" % path)
		return out
	for item in parsed:
		out[str(item["id"])] = item
	return out


static func modules() -> Dictionary:
	ensure()
	return _modules


static func creatures() -> Dictionary:
	ensure()
	return _creatures


static func module(id: String) -> Dictionary:
	ensure()
	return _modules.get(id, {})


static func creature(id: String) -> Dictionary:
	ensure()
	return _creatures.get(id, {})


static func wave_script(wave: int, chapter: String = "meadow") -> Dictionary:
	ensure()
	var list := _dusk if chapter == "dusk" else _waves
	for item in list:
		if int(item.get("wave", -1)) == wave:
			return item
	return {}


static func counter_key(id: String) -> String:
	return str(COUNTER.get(id, "vs_line"))


static func creature_counter(id: String) -> String:
	return str(CREATURE_COUNTER.get(id, "vs_swarm"))


static func com_of(item: Dictionary) -> Vector3:
	var raw = item.get("com", [0, 0, 0])
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func weapon_of(id: String) -> Dictionary:
	var mod := module(id)
	var key := str(mod.get("weapon", "none"))
	if not WEAPONS.has(key):
		return {}
	return WEAPONS[key]


static func seal_key(id: String) -> String:
	var key := str(module(id).get("weapon", "none"))
	match key:
		"generator", "crystal", "crown":
			return "seal_conduct"
		"cannon", "twin", "missile":
			return "seal_shoot"
		"spike":
			return "seal_bite"
		"shield":
			return "seal_shield"
		_:
			if id == "05_kaiju_bust":
				return "seal_weigh"
			return "seal_conduct"


const ENERGY_COST := {
	"cannon": 2.0,
	"twin": 1.0,
	"missile": 4.0,
	"crown": 1.0,
	"crystal": 1.0,
	"spike": 0.0,
}

const RELICS: Array[String] = [
	"long_line", "alchemist", "crown_mark", "magnet", "thirsty", "reflect",
]

const COUNTER := {
	"02_side_cannon": "vs_slug",
	"03_twin_guns": "vs_air",
	"04_generator": "vs_line",
	"05_kaiju_bust": "vs_shove",
	"06_shield_slab": "vs_shove",
	"07_spike_drum": "vs_swarm",
	"08_missile_rack": "vs_armor",
	"09_crystal_spur": "vs_high",
	"10_crown_nest": "vs_air",
}

const CREATURE_COUNTER := {
	"01_ram_beetle": "vs_swarm",
	"02_smash_crab": "vs_armor",
	"03_iron_slug": "vs_slug",
	"04_manta_bat": "vs_air",
	"05_sting_wasp": "vs_air",
	"06_bloated_tick": "vs_bomb",
}
