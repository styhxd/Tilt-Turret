class_name UiRoot
extends CanvasLayer

var world: World

var _screen := ""
var _splash: Control
var _menu: Control
var _hud: Control
var _shop: Control
var _settings: Control
var _pause: Control
var _over: Control
var _chest: Control
var _privacy: Control
var _drag: Control
var _meter: Control
var _score: Label
var _wave: Label
var _queue: HBoxContainer
var _tutorial: Label
var _wind: Label
var _balance: Label
var _freeze: Button
var _drop: Button
var _toast: Label
var _toast_life := 0.0
var _queue_sig := ""
var _balance_life := 0.0
var _wind_life := 0.0
var _title: Label
var _sub: Label
var _best: Label
var _coins: Label
var _daily: Label
var _play: Button
var _mod_btn: Button
var _set_btn: Button
var _over_title: Label
var _over_stats: Label
var _revive: Button
var _double: Button
var _retry: Button
var _over_menu: Button
var _doubled := false
var _shop_box: VBoxContainer
var _labels: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	if world != null:
		_connect_world()
	_show("splash")
	await get_tree().create_timer(0.35).timeout
	if _screen == "splash":
		_open_menu()


func _connect_world() -> void:
	world.fell.connect(_on_fell)
	world.chest_ready.connect(_on_chest)
	world.tutorial_step.connect(_on_tutorial)
	world.wind_warning.connect(_on_wind)
	world.tower.balance_hit.connect(_on_balance_popup)


func _process(delta: float) -> void:
	if _toast_life > 0.0:
		_toast_life -= delta
		if _toast_life <= 0.0:
			_toast.visible = false
	if _balance_life > 0.0:
		_balance_life -= delta
		_balance.modulate.a = clampf(_balance_life, 0.0, 1.0)
		if _balance_life <= 0.0:
			_balance.visible = false
	if _wind_life > 0.0:
		_wind_life -= delta
		if _wind_life <= 0.0:
			_wind.visible = false
	if world == null or not world.running or _screen != "hud":
		return
	_meter.queue_redraw()
	_score.text = str(world.score)
	_wave.text = Locale.t("wave") % world.wave
	_freeze.visible = world.tower.tilt_deg() >= 18.0 and world.tower.freeze_ready()
	_drop.disabled = world.tower.falling
	var sig := _queue_signature()
	if sig != _queue_sig:
		_queue_sig = sig
		_paint_queue()


func _unhandled_input(event: InputEvent) -> void:
	if _screen != "hud" or world == null or not world.running or get_tree().paused:
		return
	if event is InputEventScreenDrag:
		world.add_yaw(-event.relative.x * 0.0075)


func _build() -> void:
	var theme := _theme()
	_drag = Control.new()
	_drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag)

	_splash = _full(Color("07080b"))
	var splash_title := _label("Tilt Turret", 84)
	splash_title.set_anchors_preset(Control.PRESET_CENTER)
	splash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash.add_child(splash_title)
	add_child(_splash)

	_menu = _full(Color(0.04, 0.045, 0.06, 0.92))
	var menu_box := _column()
	menu_box.set_anchors_preset(Control.PRESET_CENTER)
	menu_box.offset_left = -420
	menu_box.offset_right = 420
	menu_box.offset_top = -520
	menu_box.offset_bottom = 520
	_title = _label("Tilt Turret", 78)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = _label("Stack & Defense", 32)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate = Color("d6ff3f")
	_best = _label("", 30)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins = _label("", 30)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_daily = _label("", 26)
	_daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_daily.modulate = Color("e7c56a")
	_play = _button("play", _on_play, true)
	_mod_btn = _button("modules", _open_shop, false)
	_set_btn = _button("settings", _open_settings, false)
	for node in [_title, _sub, _best, _coins, _daily, _play, _mod_btn, _set_btn]:
		menu_box.add_child(node)
	_menu.add_child(menu_box)
	add_child(_menu)

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = theme
	add_child(_hud)
	_build_hud()

	_shop = _card()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 28
	scroll.offset_top = 36
	scroll.offset_right = -28
	scroll.offset_bottom = -28
	_shop.add_child(scroll)
	_shop_box = _column()
	_shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_shop_box)
	add_child(_shop)

	_settings = _card()
	_build_settings()
	add_child(_settings)

	_pause = _card()
	_build_pause()
	add_child(_pause)

	_over = _card()
	_build_over()
	add_child(_over)

	_chest = _card()
	_build_chest()
	add_child(_chest)

	_privacy = _card()
	_build_privacy()
	add_child(_privacy)

	_toast = _label("", 32)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_bottom = -280
	_toast.offset_top = -360
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_toast.theme = theme
	add_child(_toast)
	_apply_theme(theme)


func _build_hud() -> void:
	var pause_b := _button("pause", _open_pause, false)
	pause_b.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause_b.offset_left = 28
	pause_b.offset_top = 28
	pause_b.offset_right = 250
	pause_b.offset_bottom = 120
	_hud.add_child(pause_b)

	_score = _label("0", 48)
	_score.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score.offset_top = 28
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_score)

	_wave = _label("", 32)
	_wave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave.offset_left = -280
	_wave.offset_top = 40
	_wave.offset_right = -28
	_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_wave)

	_meter = LeanBar.new()
	_meter.world = world
	_meter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_meter.offset_left = -360
	_meter.offset_right = 360
	_meter.offset_top = 130
	_meter.offset_bottom = 176
	_hud.add_child(_meter)

	_queue = HBoxContainer.new()
	_queue.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_queue.offset_left = -420
	_queue.offset_right = 420
	_queue.offset_top = 196
	_queue.offset_bottom = 300
	_queue.alignment = BoxContainer.ALIGNMENT_CENTER
	_queue.add_theme_constant_override("separation", 16)
	_queue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_queue)

	_tutorial = _label("", 36)
	_tutorial.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tutorial.offset_top = -430
	_tutorial.offset_bottom = -300
	_tutorial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_tutorial)

	_balance = _label(Locale.t("balance"), 64)
	_balance.set_anchors_preset(Control.PRESET_CENTER)
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance.modulate = Color("d6ff3f")
	_balance.visible = false
	_hud.add_child(_balance)

	_wind = _label("", 32)
	_wind.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wind.offset_top = 310
	_wind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wind.modulate = Color("9fd0ff")
	_wind.visible = false
	_hud.add_child(_wind)

	_freeze = _button("freeze", _on_freeze, false)
	_freeze.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_freeze.offset_left = -520
	_freeze.offset_top = -250
	_freeze.offset_right = -250
	_freeze.offset_bottom = -130
	_freeze.visible = false
	_hud.add_child(_freeze)

	_drop = _button("drop", _on_drop, true)
	_drop.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_drop.offset_left = -250
	_drop.offset_top = -250
	_drop.offset_right = -36
	_drop.offset_bottom = -36
	_hud.add_child(_drop)


func _build_settings() -> void:
	var box := _column()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_top = 80
	box.offset_right = -48
	box.offset_bottom = -48
	box.add_child(_label_key("settings", 56))
	box.add_child(_button("sound", _toggle_sfx, false))
	box.add_child(_button("music", _toggle_music, false))
	box.add_child(_button("language", _toggle_lang, false))
	box.add_child(_button("how_to", _replay_tutorial, false))
	box.add_child(_button("remove_ads", _buy_ads, false))
	box.add_child(_button("restore", _restore, false))
	box.add_child(_button("privacy", _open_privacy, false))
	box.add_child(_button("close", _open_menu, false))
	_settings.add_child(box)


func _build_pause() -> void:
	var box := _column()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -280
	box.offset_bottom = 280
	box.add_child(_label_key("pause", 64))
	box.add_child(_button("resume", _resume, true))
	box.add_child(_button("quit", _quit_run, false))
	_pause.add_child(box)


func _build_over() -> void:
	var box := _column()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -560
	box.offset_bottom = 560
	_over_title = _label("", 60)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_stats = _label("", 32)
	_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_revive = _button("revive", _on_revive, true)
	_double = _button("double", _on_double, false)
	_retry = _button("retry", _on_retry, false)
	_over_menu = _button("menu", _on_over_menu, false)
	for node in [_over_title, _over_stats, _revive, _double, _retry, _over_menu]:
		box.add_child(node)
	_over.add_child(box)


func _build_chest() -> void:
	var box := _column()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -360
	box.offset_bottom = 360
	box.add_child(_label_key("chest", 60))
	var body := _label("", 30)
	body.name = "ChestBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	box.add_child(_button("chest", _on_chest_ad, true))
	box.add_child(_button("skip", _on_chest_skip, false))
	_chest.add_child(box)


func _build_privacy() -> void:
	var box := _column()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_top = 60
	box.offset_right = -40
	box.offset_bottom = -40
	box.add_child(_label_key("privacy", 52))
	var body := _label("", 28)
	body.name = "PrivacyBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	box.add_child(_button("close", _open_settings, false))
	_privacy.add_child(box)


func _open_menu() -> void:
	get_tree().paused = false
	_refresh_copy()
	_show("menu")
	Ads.show_banner()


func _on_play() -> void:
	_start(false)


func _replay_tutorial() -> void:
	_start(true)


func _start(force_tutorial: bool) -> void:
	get_tree().paused = false
	Ads.hide_banner()
	var teach := force_tutorial or not GameState.tutorial_done
	world.start_run(teach)
	_doubled = false
	_queue_sig = ""
	_tutorial.visible = teach
	if teach:
		_tutorial.text = Locale.t("tutorial_0")
	_show("hud")
	AudioDirector.play("click")


func _on_drop() -> void:
	world.request_drop()


func _on_freeze() -> void:
	Ads.show_rewarded("freeze", func(ok: bool) -> void:
		if ok:
			world.apply_freeze()
			_freeze.visible = false
		else:
			_toast_msg(Locale.t("ad_unavailable"))
	)


func _on_fell() -> void:
	get_tree().paused = false
	_doubled = false
	_over_title.text = Locale.t("game_over")
	var height := world.tower.height_blocks()
	var best_mark := ""
	if height >= GameState.best_height and height > 0:
		best_mark = "\n" + Locale.t("new_best")
	_over_stats.text = "%s %d    %s %d    %s %d\n+%d %s%s" % [
		Locale.t("height"), height,
		Locale.t("kills"), world.kills,
		Locale.t("score"), world.score,
		world.last_earned, Locale.t("coins"), best_mark,
	]
	_revive.visible = not world.revives_used
	_double.visible = true
	_show("over")


func _on_revive() -> void:
	Ads.show_rewarded("revive", func(ok: bool) -> void:
		if ok:
			world.revive_run()
			_show("hud")
		else:
			_toast_msg(Locale.t("ad_unavailable"))
	)


func _on_double() -> void:
	if _doubled:
		return
	Ads.show_rewarded("double", func(ok: bool) -> void:
		if ok:
			GameState.coins += world.last_earned
			GameState.save_game()
			_doubled = true
			_double.visible = false
			_refresh_copy()
		else:
			_toast_msg(Locale.t("ad_unavailable"))
	)


func _on_retry() -> void:
	Ads.show_interstitial(func() -> void:
		_start(false)
	)


func _on_over_menu() -> void:
	Ads.show_interstitial(func() -> void:
		_open_menu()
	)


func _on_chest() -> void:
	_chest_body()
	_show("chest")


func _on_chest_ad() -> void:
	Ads.show_rewarded("chest", func(ok: bool) -> void:
		if ok:
			world.grant_epic()
		else:
			_toast_msg(Locale.t("ad_unavailable"))
		world.close_chest()
		_show("hud")
	)


func _on_chest_skip() -> void:
	world.close_chest()
	_show("hud")
	AudioDirector.play("click")


func _on_tutorial(step: int) -> void:
	if step >= 3:
		_tutorial.visible = false
		return
	_tutorial.visible = true
	_tutorial.text = Locale.t("tutorial_%d" % step)


func _on_wind(dir: Vector2) -> void:
	_wind.visible = true
	_wind.text = Locale.t("wind")
	_wind_life = 1.3
	_wind.rotation = dir.angle() * 0.15


func _on_balance_popup() -> void:
	_balance.visible = true
	_balance.text = Locale.t("balance")
	_balance_life = 0.9


func _open_shop() -> void:
	AudioDirector.play("click")
	_rebuild_shop()
	_show("shop")


func _open_settings() -> void:
	AudioDirector.play("click")
	_refresh_copy()
	_show("settings")


func _open_privacy() -> void:
	_refresh_copy()
	_show("privacy")


func _open_pause() -> void:
	if _screen != "hud":
		return
	_show("pause")
	get_tree().paused = true


func _resume() -> void:
	get_tree().paused = false
	_show("hud")


func _quit_run() -> void:
	get_tree().paused = false
	world.running = false
	_open_menu()


func _toggle_sfx() -> void:
	GameState.sfx_on = not GameState.sfx_on
	GameState.save_game()
	_refresh_copy()


func _toggle_music() -> void:
	AudioDirector.set_music(not GameState.music_on)


func _toggle_lang() -> void:
	GameState.locale = "en" if GameState.locale == "pt" else "pt"
	GameState.save_game()
	_refresh_copy()


func _buy_ads() -> void:
	var started := Billing.buy_remove_ads()
	if GameState.ads_removed:
		Ads.hide_banner()
		_toast_msg(Locale.t("ads_owned"))
	elif not started:
		_toast_msg(Locale.t("price_fallback"))
	_refresh_copy()


func _restore() -> void:
	Billing.restore()
	_toast_msg(Locale.t("restore"))


func _rebuild_shop() -> void:
	for child in _shop_box.get_children():
		child.queue_free()
	_shop_box.add_child(_label_key("collection", 52))
	var hint := _label(Locale.t("shop_hint"), 26)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_box.add_child(hint)
	_shop_box.add_child(_label("%s: %d" % [Locale.t("coins"), GameState.coins], 32))
	_add_upgrade("statue", "upgrade_statue")
	_add_upgrade("cannon", "upgrade_cannon")
	_add_upgrade("generator", "upgrade_generator")
	for id in Catalog.modules().keys():
		var line := _label("%s — %s" % [Locale.t("mod_" + id), Locale.t("desc_" + id)], 26)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_shop_box.add_child(line)
	_shop_box.add_child(_button("close", _open_menu, false))


func _add_upgrade(stat: String, key: String) -> void:
	var level := GameState.upgrade_level(stat)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_l := _label("%s  %d/10" % [Locale.t(key), level], 28)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var b := Button.new()
	if level >= GameState.MAX_UPGRADE:
		b.text = Locale.t("maxed")
		b.disabled = true
	else:
		b.text = "%s %d" % [Locale.t("buy"), GameState.upgrade_cost(level)]
		b.pressed.connect(func() -> void:
			if GameState.try_buy(stat):
				AudioDirector.play("click")
				_rebuild_shop()
			else:
				_toast_msg(Locale.t("coins"))
		)
	b.custom_minimum_size = Vector2(280, 84)
	row.add_child(b)
	_shop_box.add_child(row)


func _paint_queue() -> void:
	for child in _queue.get_children():
		child.queue_free()
	if world == null:
		return
	for piece in world.queue:
		var id := str(piece.id)
		var text := Locale.t("mod_" + id)
		if bool(piece.epic):
			text = Locale.t("epic") + "\n" + text
		var chip := _label(text, 26)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.custom_minimum_size = Vector2(240, 88)
		_queue.add_child(chip)


func _queue_signature() -> String:
	var sig := ""
	for piece in world.queue:
		sig += str(piece.id)
		if bool(piece.epic):
			sig += "*"
		sig += "|"
	return sig


func _refresh_copy() -> void:
	_title.text = Locale.t("title")
	_sub.text = Locale.t("subtitle")
	_best.text = "%s  %d" % [Locale.t("best"), GameState.best_height]
	_coins.text = "%s  %d" % [Locale.t("coins"), GameState.coins]
	var today := Time.get_date_string_from_system()
	_daily.visible = GameState.last_daily != today
	_daily.text = Locale.t("daily")
	_play.text = Locale.t("play")
	_mod_btn.text = Locale.t("modules")
	_set_btn.text = Locale.t("settings")
	_drop.text = Locale.t("drop")
	_freeze.text = Locale.t("freeze")
	_revive.text = Locale.t("revive")
	_double.text = Locale.t("double")
	_retry.text = Locale.t("retry")
	_over_menu.text = Locale.t("menu")
	_walk_buttons(_settings)
	_walk_buttons(_pause)
	_walk_buttons(_chest)
	_walk_buttons(_privacy)
	var chest_body := _chest.find_child("ChestBody", true, false)
	if chest_body is Label:
		chest_body.text = Locale.t("chest_body")
	var privacy_body := _privacy.find_child("PrivacyBody", true, false)
	if privacy_body is Label:
		privacy_body.text = Locale.t("privacy_body")
	_meter.queue_redraw()


func _walk_buttons(root: Node) -> void:
	for node in root.find_children("*", "Button", true, false):
		var key := str(node.get_meta("key", ""))
		if key == "sound":
			node.text = "%s: %s" % [Locale.t("sound"), Locale.t("on") if GameState.sfx_on else Locale.t("off")]
		elif key == "music":
			node.text = "%s: %s" % [Locale.t("music"), Locale.t("on") if GameState.music_on else Locale.t("off")]
		elif key == "language":
			node.text = "%s: %s" % [Locale.t("language"), "PT" if GameState.locale == "pt" else "EN"]
		elif key == "remove_ads" and GameState.ads_removed:
			node.text = Locale.t("ads_owned")
		elif key != "":
			node.text = Locale.t(key)


func _show(screen: String) -> void:
	_screen = screen
	_splash.visible = screen == "splash"
	_menu.visible = screen == "menu"
	_hud.visible = screen == "hud"
	_shop.visible = screen == "shop"
	_settings.visible = screen == "settings"
	_pause.visible = screen == "pause"
	_over.visible = screen == "over"
	_chest.visible = screen == "chest"
	_privacy.visible = screen == "privacy"
	if screen == "menu" or screen == "settings" or screen == "shop" or screen == "privacy":
		_refresh_copy()


func _toast_msg(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_life = 1.8


func _chest_body() -> void:
	pass


func _full(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect


func _card() -> Panel:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _label_key(key: String, size: int) -> Label:
	var label := _label(Locale.t(key), size)
	label.set_meta("key", key)
	return label


func _button(key: String, cb: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = Locale.t(key)
	button.set_meta("key", key)
	button.set_meta("primary", primary)
	button.custom_minimum_size = Vector2(0, 96)
	button.pressed.connect(func() -> void:
		AudioDirector.play("click")
		cb.call()
	)
	if primary:
		button.theme_type_variation = "PrimaryButton"
	return button


func _theme() -> Theme:
	var theme := Theme.new()
	var font := ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	theme.default_font = font
	theme.default_font_size = 36
	var normal := _box(Color("1c2430"), 22)
	var hover := _box(Color("2a3544"), 22)
	var pressed := _box(Color("d6ff3f"), 22)
	var primary := _box(Color("d6ff3f"), 28)
	var primary_hover := _box(Color("e7ff86"), 28)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", _box(Color("2a2f36"), 22))
	theme.set_color("font_color", "Button", Color("f4f1ea"))
	theme.set_color("font_hover_color", "Button", Color("f4f1ea"))
	theme.set_color("font_pressed_color", "Button", Color("14180f"))
	theme.set_color("font_disabled_color", "Button", Color("8b9188"))
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", primary)
	theme.set_stylebox("hover", "PrimaryButton", primary_hover)
	theme.set_stylebox("pressed", "PrimaryButton", _box(Color("b6e01a"), 28))
	theme.set_color("font_color", "PrimaryButton", Color("14180f"))
	theme.set_color("font_hover_color", "PrimaryButton", Color("14180f"))
	theme.set_color("font_pressed_color", "PrimaryButton", Color("14180f"))
	var panel := _box(Color(0.05, 0.06, 0.08, 0.94), 0)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_color("font_color", "Label", Color("f4f1ea"))
	return theme


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _apply_theme(theme: Theme) -> void:
	for node in [_menu, _hud, _shop, _settings, _pause, _over, _chest, _privacy, _toast]:
		node.theme = theme


class LeanBar extends Control:
	var world: World
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("14181f"))
		var mag := 0.0
		var signed := 0.0
		if world != null and world.tower != null:
			mag = world.tower.tilt_deg()
			signed = world.tower.tilt_signed_deg()
		var col := Color("8fe05a")
		if mag >= 8.0:
			col = Color("f0c14a")
		if mag >= 18.0:
			col = Color("ff5a3c")
		draw_rect(Rect2(w * 0.5 - 2, 0, 4, h), Color("3c4450"))
		var t := clampf(signed / 28.0, -1.0, 1.0)
		var x := w * 0.5 + t * w * 0.42
		draw_rect(Rect2(x - 10, 2, 20, h - 4), col)
