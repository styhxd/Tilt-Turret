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
var _freeze_arc: CooldownArc
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
var _banner: Label
var _banner_life := 0.0
var _choice: Control
var _heat_btn: Button
var _pact_shell: Button
var _pact_gust: Button
var _pact_glue: Button
var _codex_btn: Button
var _codex: Control
var _codex_box: VBoxContainer
var _sfx_slider: HSlider
var _music_slider: HSlider
var _chest_boost := false
var _codex_from_run := false
var _flag: Button
var _purse: Label
var _boss_label: Label
var _lineup: VBoxContainer
var _endless_btn: Button
var _dusk_btn: Button
var _dusk_menu: Button


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
	world.wave_card.connect(_on_banner)
	world.wave_clear.connect(_on_banner)
	world.relic_ready.connect(_on_relic)
	world.victory.connect(_on_victory)
	world.lineup.connect(_on_lineup)
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
	if _banner_life > 0.0:
		_banner_life -= delta
		_banner.modulate.a = clampf(_banner_life, 0.0, 1.0)
		if _banner_life <= 0.0:
			_banner.visible = false
	if world == null or not world.running or _screen != "hud":
		return
	if world.tower.ghost_good and not world.tower.falling:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.045
		_drop.pivot_offset = _drop.size * 0.5
		_drop.scale = Vector2(pulse, pulse)
	else:
		_drop.scale = Vector2.ONE
	_meter.queue_redraw()
	_score.text = str(world.score)
	_wave.text = Locale.t("wave_of") % [world.wave, 10] if world.wave <= 10 else Locale.t("wave") % world.wave
	if _purse:
		_purse.text = "+%d" % world.run_coins
	if _boss_label:
		var boss_alive := world._boss != null and is_instance_valid(world._boss) and not world._boss.dead
		_boss_label.visible = boss_alive
		if boss_alive:
			var ratio := world._boss.hp / maxf(world._boss.max_hp, 0.01)
			_boss_label.text = "%s  %d%%" % [Locale.t("cre_" + world._boss.kind), int(ratio * 100.0)]
	_freeze.visible = not GameState.pact_noglue and world.tower.tilt_deg() >= 18.0
	_freeze.disabled = not world.tower.freeze_ready()
	if _freeze_arc:
		_freeze_arc.queue_redraw()
	_drop.disabled = world.tower.falling or world.held.is_empty()
	if _flag:
		_flag.visible = world._breath > 0.0
	var sig := _queue_signature()
	if sig != _queue_sig:
		_queue_sig = sig
		_paint_queue()


func _unhandled_input(event: InputEvent) -> void:
	if _screen != "hud" or world == null or not world.running or get_tree().paused:
		return
	if event is InputEventScreenDrag:
		world.slide(-event.relative.x)


func _build() -> void:
	var theme := _theme()
	_drag = Control.new()
	_drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag)

	_splash = _full(Color("102033"))
	var splash_title := _label("Tilt Turret", 84)
	splash_title.set_anchors_preset(Control.PRESET_CENTER)
	splash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash.add_child(splash_title)
	add_child(_splash)

	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _column()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -420
	top.offset_right = 420
	top.offset_top = 72
	top.offset_bottom = 420
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
	for node in [_title, _sub, _best, _coins, _daily]:
		top.add_child(node)
	_menu.add_child(top)
	var menu_box := _column()
	menu_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	menu_box.offset_left = -420
	menu_box.offset_right = 420
	menu_box.offset_top = -700
	menu_box.offset_bottom = -36
	_play = _button("play", _on_play, true)
	_pact_shell = _button("pact_shell", func() -> void: _toggle_pact("shell"), false)
	_pact_gust = _button("pact_gust", func() -> void: _toggle_pact("gust"), false)
	_pact_glue = _button("pact_glue", func() -> void: _toggle_pact("glue"), false)
	var pact_row := HBoxContainer.new()
	pact_row.add_theme_constant_override("separation", 12)
	pact_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for pact in [_pact_shell, _pact_gust, _pact_glue]:
		pact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pact_row.add_child(pact)
	_dusk_menu = _button("dusk", _on_dusk, false)
	_dusk_menu.visible = false
	_mod_btn = _button("modules", _open_shop, false)
	_codex_btn = _button("codex", _open_codex, false)
	_set_btn = _button("settings", _open_settings, false)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	for nav_btn in [_mod_btn, _codex_btn, _set_btn]:
		nav_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(nav_btn)
	for node in [_play, pact_row, _dusk_menu, nav]:
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
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop.add_child(scroll)
	_shop_box = _column()
	_shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_shop_box)
	add_child(_shop)

	_codex = _card()
	var codex_scroll := ScrollContainer.new()
	codex_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	codex_scroll.offset_left = 28
	codex_scroll.offset_top = 36
	codex_scroll.offset_right = -28
	codex_scroll.offset_bottom = -28
	codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex.add_child(codex_scroll)
	_codex_box = _column()
	_codex_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_scroll.add_child(_codex_box)
	add_child(_codex)

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

	var score_plate := Panel.new()
	score_plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_plate.offset_left = -180
	score_plate.offset_right = 180
	score_plate.offset_top = 18
	score_plate.offset_bottom = 108
	score_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(score_plate)
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
	_banner = _label("", 30)
	_banner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_banner.offset_left = -540
	_banner.offset_right = -24
	_banner.offset_top = 96
	_banner.offset_bottom = 156
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_banner.clip_text = true
	_banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_banner)
	_lineup = VBoxContainer.new()
	_lineup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_lineup.offset_left = 20
	_lineup.offset_right = 300
	_lineup.offset_top = 660
	_lineup.offset_bottom = 1280
	_lineup.alignment = BoxContainer.ALIGNMENT_BEGIN
	_lineup.add_theme_constant_override("separation", 10)
	_lineup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lineup.visible = false
	_hud.add_child(_lineup)
	_choice = _full(Color(0.05, 0.08, 0.12, 0.72))
	_choice.visible = false
	var choice_box := _column()
	choice_box.set_anchors_preset(Control.PRESET_CENTER)
	choice_box.offset_left = -420
	choice_box.offset_right = 420
	choice_box.offset_top = -360
	choice_box.offset_bottom = 360
	choice_box.add_child(_label_key("choose", 42))
	choice_box.add_child(_button("mut_0", func() -> void: _pick_mut(0), true))
	choice_box.add_child(_button("mut_1", func() -> void: _pick_mut(1), false))
	choice_box.add_child(_button("mut_2", func() -> void: _pick_mut(2), false))
	_choice.add_child(choice_box)
	_hud.add_child(_choice)

	_meter = LeanBar.new()
	_meter.world = world
	_meter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_meter.offset_left = 16
	_meter.offset_right = 132
	_meter.offset_top = 150
	_meter.offset_bottom = 640
	_hud.add_child(_meter)

	_purse = _label("+0", 28)
	_purse.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_purse.offset_top = 108
	_purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_purse.modulate = Color("d6ff3f")
	_hud.add_child(_purse)

	_boss_label = _label("", 32)
	_boss_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_boss_label.offset_left = -420
	_boss_label.offset_top = 150
	_boss_label.offset_right = -150
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_label.modulate = Color("ff5a32")
	_boss_label.visible = false
	_hud.add_child(_boss_label)

	_queue = HBoxContainer.new()
	_queue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_queue.offset_left = -500
	_queue.offset_right = 500
	_queue.offset_top = -620
	_queue.offset_bottom = -290
	_queue.alignment = BoxContainer.ALIGNMENT_CENTER
	_queue.add_theme_constant_override("separation", 12)
	_queue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_queue)

	_tutorial = _label("", 34)
	_tutorial.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tutorial.offset_left = -480
	_tutorial.offset_right = 480
	_tutorial.offset_top = 150
	_tutorial.offset_bottom = 240
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
	_freeze.offset_left = -250
	_freeze.offset_top = -270
	_freeze.offset_right = -24
	_freeze.offset_bottom = -160
	_freeze.visible = false
	_hud.add_child(_freeze)
	_freeze_arc = CooldownArc.new()
	_freeze_arc.world = world
	_freeze_arc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_freeze_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_freeze.add_child(_freeze_arc)

	_drop = _button("drop", _on_drop, true)
	_drop.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_drop.offset_left = -500
	_drop.offset_top = -150
	_drop.offset_right = 500
	_drop.offset_bottom = -24
	_hud.add_child(_drop)
	var turn := _button("turn", world.rotate_piece, false)
	turn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	turn.offset_left = 24
	turn.offset_top = -270
	turn.offset_right = 210
	turn.offset_bottom = -160
	_hud.add_child(turn)
	_flag = _button("call_wave", func() -> void: world.call_wave(), true)
	_flag.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_flag.offset_left = -280
	_flag.offset_right = -16
	_flag.offset_top = -48
	_flag.offset_bottom = 64
	_flag.visible = false
	_hud.add_child(_flag)


func _build_settings() -> void:
	var box := _column()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_top = 80
	box.offset_right = -48
	box.offset_bottom = -48
	box.add_child(_label_key("settings", 56))
	box.add_child(_button("sound", _toggle_sfx, false))
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.05
	_sfx_slider.value = GameState.sfx_volume
	_sfx_slider.custom_minimum_size = Vector2(0, 48)
	_sfx_slider.value_changed.connect(func(v: float) -> void: GameState.set_sfx_volume(v))
	box.add_child(_sfx_slider)
	box.add_child(_button("music", _toggle_music, false))
	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.05
	_music_slider.value = GameState.music_volume
	_music_slider.custom_minimum_size = Vector2(0, 48)
	_music_slider.value_changed.connect(func(v: float) -> void: GameState.set_music_volume(v))
	box.add_child(_music_slider)
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
	_endless_btn = _button("endless", _on_endless, true)
	_dusk_btn = _button("dusk", _on_dusk_from_win, false)
	_endless_btn.visible = false
	_dusk_btn.visible = false
	for node in [_over_title, _over_stats, _revive, _double, _retry, _endless_btn, _dusk_btn, _over_menu]:
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
	box.add_child(_button("mut_0", func() -> void: _chest_pick(0), true))
	box.add_child(_button("mut_1", func() -> void: _chest_pick(1), false))
	box.add_child(_button("mut_2", func() -> void: _chest_pick(2), false))
	box.add_child(_button("chest", _on_chest_ad, false))
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
	if world:
		world.show_showcase(true)
	AudioDirector.start()
	Ads.boot()
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
	var culprit := ""
	if world.tower.culprit_id != "":
		culprit = "\n" + Locale.t("culprit") % Locale.t("mod_" + world.tower.culprit_id)
		culprit += "\n" + Locale.t("culprit_why")
	var net := ""
	if world.net_kills > 0:
		net = "\n%s %d" % [Locale.t("network"), world.net_kills]
	_over_stats.text = "%s %d    %s %d    %s %d\n+%d %s%s%s%s" % [
		Locale.t("height"), height,
		Locale.t("kills"), world.kills,
		Locale.t("score"), world.score,
		world.last_earned, Locale.t("coins"), best_mark, culprit, net,
	]
	_revive.visible = not world.revives_used
	_double.visible = true
	if _endless_btn:
		_endless_btn.visible = false
	if _dusk_btn:
		_dusk_btn.visible = false
	_show("over")


func _on_victory() -> void:
	get_tree().paused = false
	_over_title.text = Locale.t("victory")
	_over_stats.text = "%s %d    %s %d\n+%d %s\n%s %d" % [
		Locale.t("height"), world.tower.height_blocks(),
		Locale.t("kills"), world.kills,
		world.last_earned, Locale.t("coins"),
		Locale.t("network"), world.net_kills,
	]
	_revive.visible = false
	_double.visible = false
	_endless_btn.visible = true
	_dusk_btn.visible = world.chapter == "meadow"
	_show("over")


func _on_endless() -> void:
	world.continue_endless()
	_queue_sig = ""
	_show("hud")
	AudioDirector.play("click")


func _on_dusk() -> void:
	_start_chapter("dusk")


func _on_dusk_from_win() -> void:
	_start_chapter("dusk")


func _start_chapter(chapter_name: String) -> void:
	get_tree().paused = false
	Ads.hide_banner()
	world.start_run(false, chapter_name)
	_doubled = false
	_queue_sig = ""
	_tutorial.visible = false
	_show("hud")
	AudioDirector.play("click")


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
	_chest_boost = false
	var body := _chest.find_child("ChestBody", true, false) as Label
	if body:
		body.text = Locale.t("chest_body")
	_show("chest")
	AudioDirector.play("chest")


func _chest_pick(which: int) -> void:
	if world:
		world.apply_chest(which, _chest_boost)
	_chest_boost = false
	_show("hud")


func _on_chest_ad() -> void:
	Ads.show_rewarded("chest", func(ok: bool) -> void:
		if ok:
			_chest_boost = true
			if world:
				world.grant_epic()
			_toast_msg(Locale.t("epic"))
		else:
			_toast_msg(Locale.t("ad_unavailable"))
	)


func _on_chest_skip() -> void:
	if world:
		world.close_chest()
	_show("hud")
	AudioDirector.play("click")


func _on_tutorial(step: int) -> void:
	if step >= 3:
		_tutorial.visible = false
		return
	_tutorial.visible = true
	_tutorial.text = Locale.t("tutorial_%d" % step)


func _on_wind(_dir: Vector2) -> void:
	if _wind:
		_wind.visible = false


func _on_balance_popup() -> void:
	if _balance == null or world == null:
		return
	var chain := world.tower.perfect_chain
	_balance.text = Locale.t("balance") if chain <= 1 else "%s  x%d" % [Locale.t("balance"), chain]
	_balance.visible = true
	_balance_life = 0.7


func _open_shop() -> void:
	AudioDirector.play("click")
	_rebuild_shop()
	_show("shop")


func _open_codex(focus: String = "") -> void:
	_codex_from_run = _screen == "hud"
	AudioDirector.play("click")
	_rebuild_codex(focus)
	_show("codex")


func _close_codex() -> void:
	if _codex_from_run:
		_show("hud")
		return
	_open_menu()


func _rebuild_codex(focus: String) -> void:
	if _codex_box == null:
		return
	for child in _codex_box.get_children():
		child.queue_free()
	_codex_box.add_child(_label_key("codex", 52))
	for id in Catalog.creatures().keys():
		var line := _label("%s\n%s" % [Locale.t("cre_" + id), Locale.t("hint_" + id)], 26)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(960, 0)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == focus:
			line.modulate = Color("d6ff3f")
		_codex_box.add_child(line)
	for id in Catalog.modules().keys():
		var line := _label("%s\n%s" % [Locale.t("mod_" + id), Locale.t("desc_" + id)], 26)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(960, 0)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_codex_box.add_child(line)
	_codex_box.add_child(_button("close", _close_codex, false))


func _paint_pact(button: Button, on: bool) -> void:
	if button == null:
		return
	var key := str(button.name)
	button.text = "%s\n%s" % [Locale.t(key), Locale.t("on") if on else Locale.t("off")]
	button.modulate = Color("d6ff3f") if on else Color("f4f1ea")


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
	_add_toy("ghost")
	_add_toy("base_gen")
	_add_toy("relic")
	_add_toy("stud")
	_add_plant("splash", "02_side_cannon")
	_add_plant("air", "03_twin_guns")
	_add_plant("bounce", "09_crystal_spur")
	for id in Catalog.modules().keys():
		var card := PanelContainer.new()
		var inner := _label("%s\n%s" % [Locale.t("mod_" + id), Locale.t("desc_" + id)], 26)
		inner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.custom_minimum_size = Vector2(960, 0)
		card.add_child(inner)
		var stripe := StyleBoxFlat.new()
		stripe.bg_color = Color(ModelUtil.FALLBACK.get(id, Color.WHITE), 0.28)
		stripe.set_corner_radius_all(18)
		stripe.content_margin_left = 18
		stripe.content_margin_right = 18
		stripe.content_margin_top = 12
		stripe.content_margin_bottom = 12
		stripe.border_color = ModelUtil.FALLBACK.get(id, Color("d6ff3f"))
		stripe.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", stripe)
		_shop_box.add_child(card)
	_shop_box.add_child(_button("close", _open_menu, false))


func _add_toy(id: String) -> void:
	var card := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var text := _label("%s\n%s" % [Locale.t("toy_" + id), Locale.t("toy_" + id + "_fx")], 26)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var b := Button.new()
	if GameState.toy_owned(id):
		b.text = Locale.t("owned")
		b.disabled = true
	else:
		b.text = "%s %d" % [Locale.t("buy"), GameState.toy_cost(id)]
		b.pressed.connect(func() -> void:
			if GameState.try_buy_toy(id):
				AudioDirector.play("click")
				_rebuild_shop()
			else:
				_toast_msg(Locale.t("coins"))
		)
	b.custom_minimum_size = Vector2(240, 84)
	row.add_child(b)
	card.add_child(row)
	var stripe := StyleBoxFlat.new()
	stripe.bg_color = Color("1c2430")
	stripe.set_corner_radius_all(18)
	stripe.content_margin_left = 16
	stripe.content_margin_right = 16
	stripe.content_margin_top = 12
	stripe.content_margin_bottom = 12
	stripe.border_color = Color("d6ff3f")
	stripe.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", stripe)
	_shop_box.add_child(card)


func _add_upgrade(stat: String, key: String) -> void:
	var level := GameState.upgrade_level(stat)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_l := _label("%s  %d/10\n%s" % [Locale.t(key), level, GameState.upgrade_blurb(stat)], 26)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(520, 0)
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
	b.custom_minimum_size = Vector2(210, 84)
	row.add_child(b)
	_shop_box.add_child(row)


func _add_plant(id: String, module_id: String) -> void:
	var card := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var text := _label("%s\n%s" % [Locale.t("plant_" + id), Locale.t("plant_" + id + "_fx")], 26)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var b := Button.new()
	if GameState.plant_owned(id):
		b.text = Locale.t("owned")
		b.disabled = true
	else:
		b.text = "%s %d" % [Locale.t("buy"), GameState.plant_cost(id)]
		b.pressed.connect(func() -> void:
			if GameState.try_buy_plant(id):
				AudioDirector.play("click")
				_rebuild_shop()
			else:
				_toast_msg(Locale.t("coins"))
		)
	b.custom_minimum_size = Vector2(240, 84)
	row.add_child(b)
	card.add_child(row)
	var stripe := StyleBoxFlat.new()
	stripe.bg_color = Color(ModelUtil.FALLBACK.get(module_id, Color.WHITE), 0.22)
	stripe.set_corner_radius_all(18)
	stripe.content_margin_left = 16
	stripe.content_margin_right = 16
	stripe.content_margin_top = 12
	stripe.content_margin_bottom = 12
	stripe.border_color = Color("d6ff3f")
	stripe.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", stripe)
	_shop_box.add_child(card)


func _paint_queue() -> void:
	for child in _queue.get_children():
		child.queue_free()
	if world == null:
		return
	if not world.held.is_empty():
		_queue.add_child(_piece_card(world.held, -1))
		return
	var index := 0
	for piece in world.queue:
		_queue.add_child(_piece_card(piece, index))
		index += 1


func _piece_card(piece: Dictionary, index: int) -> Control:
	var id := str(piece.id)
	var raw: Variant = Catalog.module(id).get("com", [0, 0, 0])
	var pull := float(raw[0]) if raw is Array and raw.size() > 0 else 0.0
	var arrow := "→" if pull > 0.05 else ("←" if pull < -0.05 else "·")
	var light := ""
	if index < 0:
		light = ""
	elif world.tower != null and world.tower.would_light(id):
		light = "\n" + Locale.t("seal_lights")
	var counter := Locale.t(Catalog.counter_key(id))
	var cost := int(Catalog.ENERGY_COST.get(str(Catalog.module(id).get("weapon", "")), 0))
	var pips := ""
	if cost > 0:
		pips = "  " + "●".repeat(cost)
	var dry := ""
	if index < 0 and world.tower != null and not world.tower.would_light(id) and cost > 0:
		dry = "\n" + Locale.t("dry_cough")
	var text := "%s\n%s  %s\n%s%s%s%s" % [Locale.t("mod_" + id), Locale.t(Catalog.seal_key(id)), arrow, counter, pips, light, dry]
	if bool(piece.get("epic", false)):
		text = Locale.t("epic") + "\n" + text
	var chip := Button.new()
	chip.text = text
	chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chip.custom_minimum_size = Vector2(280, 250) if index < 0 else Vector2(280, 260)
	chip.add_theme_font_size_override("font_size", 26)
	chip.add_theme_color_override("font_color", Color("14180f"))
	if index >= 0:
		var pick := index
		chip.pressed.connect(func() -> void:
			world.choose_offer(pick)
			_queue_sig = ""
			_paint_queue()
		)
	else:
		chip.disabled = true
	var chip_box := StyleBoxFlat.new()
	var tint: Color = ModelUtil.FALLBACK.get(id, Color("d6ff3f"))
	chip_box.bg_color = Color(tint.r, tint.g, tint.b, 0.95)
	chip_box.set_corner_radius_all(22)
	chip_box.content_margin_left = 14
	chip_box.content_margin_right = 14
	chip_box.content_margin_top = 62
	chip_box.content_margin_bottom = 10
	chip_box.border_color = Color("d6ff3f") if bool(piece.get("epic", false)) or index < 0 else Color("1c2430")
	chip_box.set_border_width_all(4)
	chip.add_theme_stylebox_override("normal", chip_box)
	chip.add_theme_stylebox_override("hover", chip_box)
	chip.add_theme_stylebox_override("pressed", chip_box)
	chip.add_theme_stylebox_override("disabled", chip_box)
	var seal := SealMark.new()
	seal.kind = "statue" if id == "05_kaiju_bust" else str(Catalog.module(id).get("weapon", "none"))
	seal.set_anchors_preset(Control.PRESET_CENTER_TOP)
	seal.offset_left = -26
	seal.offset_right = 26
	seal.offset_top = 8
	seal.offset_bottom = 58
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(seal)
	return chip


func _toggle_pact(which: String) -> void:
	GameState.toggle_pact(which)
	AudioDirector.play("click")
	_refresh_copy()


func _toggle_heat() -> void:
	GameState.set_heat(not GameState.coin_heat())
	AudioDirector.play("click")
	_refresh_copy()


func _on_banner(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_life = 3.2


func _on_lineup(ids: Array) -> void:
	if _lineup == null:
		return
	for child in _lineup.get_children():
		child.queue_free()
	_lineup.visible = not ids.is_empty()
	var buckets: Dictionary = {}
	var order: Array[String] = []
	for entry in ids:
		var id := str(entry.get("id", "")) if entry is Dictionary else str(entry)
		var boss := entry is Dictionary and bool(entry.get("boss", false))
		var elite := entry is Dictionary and bool(entry.get("elite", false))
		var key := id + ("*" if boss else "")
		if not buckets.has(key):
			order.append(key)
			buckets[key] = {"id": id, "count": 0, "boss": boss, "elite": elite}
		buckets[key].count = int(buckets[key].count) + 1
	for key in order:
		var info: Dictionary = buckets[key]
		var id := str(info.id)
		var chip := Button.new()
		chip.text = "%s  %d" % [Locale.t("cre_" + id), int(info.count)]
		chip.custom_minimum_size = Vector2(180, 72)
		chip.add_theme_font_size_override("font_size", 24)
		var box := StyleBoxFlat.new()
		box.bg_color = Enemy.role_color(id)
		box.set_corner_radius_all(16)
		box.set_border_width_all(5 if bool(info.boss) or bool(info.elite) else 0)
		box.border_color = Color("ff5a32") if bool(info.boss) else Color("ffd15a")
		box.content_margin_left = 10
		box.content_margin_right = 10
		chip.add_theme_stylebox_override("normal", box)
		chip.add_theme_stylebox_override("hover", box)
		chip.add_theme_stylebox_override("pressed", box)
		chip.add_theme_color_override("font_color", Color("14180f"))
		var focus := id
		chip.pressed.connect(func() -> void: _open_codex(focus))
		_lineup.add_child(chip)


func _on_relic() -> void:
	if _choice == null or world == null:
		return
	_choice.visible = true
	var labels := _choice.find_children("*", "Label", true, false)
	if not labels.is_empty() and labels[0] is Label:
		(labels[0] as Label).text = Locale.t("choose")
	var buttons := _choice.find_children("*", "Button", true, false)
	for i in buttons.size():
		var button := buttons[i] as Button
		if i < world.relic_offer.size():
			button.text = Locale.t("relic_" + world.relic_offer[i])
			button.visible = true
		else:
			button.visible = false


func _pick_mut(which: int) -> void:
	if _choice:
		_choice.visible = false
	if world and not world.relic_offer.is_empty():
		world.pick_relic(which)
	elif world:
		world.apply_mutation(which)
	AudioDirector.play("click")


func _queue_signature() -> String:
	var sig := ""
	if world != null and not world.held.is_empty():
		sig = "H%s|" % str(world.held.id)
	if world == null:
		return sig
	for piece in world.queue:
		sig += str(piece.id)
		if bool(piece.epic):
			sig += "*"
		sig += "|"
	return sig


func _refresh_copy() -> void:
	_title.text = Locale.t("title")
	_sub.text = Locale.t("subtitle")
	_best.text = Locale.t("your_height") % GameState.best_height
	_coins.text = "%s  %d" % [Locale.t("coins"), GameState.coins]
	GameState.ensure_daily_pact()
	_daily.visible = true
	_daily.text = Locale.t("daily_pact") % Locale.t("pact_" + GameState.daily_pact)
	_play.text = Locale.t("play")
	_paint_pact(_pact_shell, GameState.pact_shell)
	_paint_pact(_pact_gust, GameState.pact_gust)
	_paint_pact(_pact_glue, GameState.pact_noglue)
	if _dusk_menu:
		_dusk_menu.visible = GameState.dusk_open
		_dusk_menu.text = Locale.t("dusk")
	if _flag:
		_flag.text = Locale.t("call_wave")
	_mod_btn.text = Locale.t("modules")
	if _codex_btn:
		_codex_btn.text = Locale.t("codex")
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
	_codex.visible = screen == "codex"
	_settings.visible = screen == "settings"
	_pause.visible = screen == "pause"
	_over.visible = screen == "over"
	_chest.visible = screen == "chest"
	_privacy.visible = screen == "privacy"
	if screen == "menu" or screen == "settings" or screen == "shop" or screen == "privacy" or screen == "codex":
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
	button.name = key
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
	var panel := _box(Color(0.07, 0.14, 0.22, 0.94), 28)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_color("font_color", "Label", Color("f4f1ea"))
	theme.set_constant("outline_size", "Label", 4)
	theme.set_color("font_outline_color", "Label", Color("102033"))
	return theme


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = Color("d6ff3f") if radius >= 28 else Color("3d5166")
	style.set_border_width_all(4 if radius >= 28 else 2)
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 10
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _apply_theme(theme: Theme) -> void:
	for node in [_menu, _hud, _shop, _codex, _settings, _pause, _over, _chest, _privacy, _toast]:
		node.theme = theme


class LeanBar extends Control:
	var world: World
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.14, 0.2, 0.82))
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color("2a3c30"), 3.0)
		draw_line(center - Vector2(radius * 0.7, 0), center + Vector2(radius * 0.7, 0), Color("2a3c30"), 2.0)
		var lean := Vector2.ZERO
		var preview := Vector2.ZERO
		var mag := 0.0
		var threat := 0.0
		var buff := 0.0
		if world != null and world.tower != null:
			mag = world.tower.tilt_deg()
			threat = world.threat_deg
			buff = world.tower.fire_buff
			lean = Vector2(rad_to_deg(world.tower.tilt_x), rad_to_deg(world.tower.tilt_z))
			preview = world.tower.preview_equilibrium_deg()
		var col := Color("8fe05a")
		if mag >= 8.0:
			col = Color("f0c14a")
		if mag >= 18.0 or threat >= 28.0:
			col = Color("ff5a3c")
		var bubble := center + Vector2(lean.x, -lean.y) / 28.0 * radius
		bubble.x = clampf(bubble.x, 10, size.x - 10)
		bubble.y = clampf(bubble.y, 10, size.y - 28)
		draw_circle(bubble, 14.0, col)
		draw_circle(bubble, 6.0, Color("fff6c8"))
		if world != null and world.tower != null and world.tower._ghost_id != "":
			var ghost := center + Vector2(preview.x, -preview.y) / 28.0 * radius
			draw_arc(ghost, 12.0, 0, TAU, 24, Color("d6ff3f"), 3.0, true)
		if threat > mag + 0.6:
			var mark := center + Vector2(0, -clampf(threat, 0, 28) / 28.0 * radius)
			draw_arc(mark, 16.0, 0, TAU, 24, Color("ff5a3c"), 4.0, true)
		if world != null and world.wind_preview.length() > 0.2:
			var tip := center + world.wind_preview.normalized() * radius * 0.75
			draw_line(center, tip, Color("9fd0ff"), 5.0)
		if buff > 0.05:
			var h := clampf(buff / 3.8, 0.05, 1.0) * (size.y - 16.0)
			draw_rect(Rect2(size.x - 14, size.y - 8 - h, 8, h), Color("d6ff3f"))
		if ThemeDB.fallback_font != null:
			draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 8), "%d°" % int(round(mag)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)
			if GameState.toy_ghost and threat > mag + 0.6:
				draw_string(ThemeDB.fallback_font, Vector2(8, 28), "%d°" % int(round(threat)), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ff5a3c"))


class CooldownArc extends Control:
	var world: World
	func _draw() -> void:
		if world == null or world.tower == null:
			return
		var left := world.tower.freeze_cd
		if left <= 0.0:
			return
		var frac := clampf(left / 45.0, 0.0, 1.0)
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, Color("9fd0ff"), 6.0, true)


class SealMark extends Control:
	var kind := "none"
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		draw_circle(center, radius, Color("1c2430"))
		draw_arc(center, radius - 1.5, 0, TAU, 28, Color("d6ff3f"), 3.0, true)
		var ink := Color("f4f1ea")
		match kind:
			"cannon":
				draw_rect(Rect2(center - Vector2(radius * 0.62, radius * 0.16), Vector2(radius * 1.24, radius * 0.32)), Color("ff7a32"))
			"twin":
				draw_rect(Rect2(center + Vector2(-radius * 0.55, -radius * 0.28), Vector2(radius * 1.1, radius * 0.18)), Color("ffb15a"))
				draw_rect(Rect2(center + Vector2(-radius * 0.55, radius * 0.1), Vector2(radius * 1.1, radius * 0.18)), Color("ffb15a"))
			"generator":
				draw_polyline(PackedVector2Array([
					center + Vector2(-radius * 0.12, -radius * 0.5),
					center + Vector2(radius * 0.22, -radius * 0.02),
					center + Vector2(-radius * 0.08, -radius * 0.02),
					center + Vector2(radius * 0.16, radius * 0.5),
				]), Color("d6ff3f"), 4.0)
			"statue":
				draw_circle(center + Vector2(0, -radius * 0.08), radius * 0.38, Color("c9b89a"))
			"shield":
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(0, -radius * 0.55),
					center + Vector2(radius * 0.48, -radius * 0.2),
					center + Vector2(radius * 0.32, radius * 0.5),
					center + Vector2(0, radius * 0.28),
					center + Vector2(-radius * 0.32, radius * 0.5),
					center + Vector2(-radius * 0.48, -radius * 0.2),
				]), Color("9fd0ff"))
			"spike":
				draw_arc(center, radius * 0.45, 0, TAU, 20, Color("ff5a3c"), 4.0, true)
				draw_circle(center, radius * 0.16, Color("ff5a3c"))
			"missile":
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(radius * 0.55, 0),
					center + Vector2(-radius * 0.15, -radius * 0.28),
					center + Vector2(-radius * 0.4, 0),
					center + Vector2(-radius * 0.15, radius * 0.28),
				]), Color("ffd15a"))
			"crystal":
				draw_line(center + Vector2(-radius * 0.1, radius * 0.45), center + Vector2(radius * 0.15, -radius * 0.5), Color("7af0ff"), 5.0)
			"crown":
				draw_polyline(PackedVector2Array([
					center + Vector2(-radius * 0.5, radius * 0.2),
					center + Vector2(-radius * 0.28, -radius * 0.45),
					center + Vector2(0, radius * 0.05),
					center + Vector2(radius * 0.28, -radius * 0.45),
					center + Vector2(radius * 0.5, radius * 0.2),
				]), Color("e7c56a"), 4.0)
			_:
				draw_rect(Rect2(center - Vector2(radius * 0.5, radius * 0.18), Vector2(radius, radius * 0.36)), ink)
