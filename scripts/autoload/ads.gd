extends Node

## Google sample IDs. Replace these with the real AdMob units before the Play Store build.
const APP_ID := "ca-app-pub-3940256099942544~3347511713"
const BANNER_ID := "ca-app-pub-3940256099942544/9214589741"
const INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"

var initialized := false
var rewarded_loaded := false
var interstitial_loaded := false
var _using_plugin := false
var _rewarded: RewardedAd
var _interstitial: InterstitialAd
var _banner: AdView
var _rewarded_cb: Callable
var _interstitial_cb: Callable
var _reward_earned := false
var _reward_listener := OnUserEarnedRewardListener.new()
var _reward_load := RewardedAdLoadCallback.new()
var _reward_content := FullScreenContentCallback.new()
var _interstitial_load := InterstitialAdLoadCallback.new()
var _interstitial_content := FullScreenContentCallback.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_boot")


func _boot() -> void:
	_using_plugin = Engine.has_singleton("PoingGodotAdMob")
	_reward_listener.on_user_earned_reward = func(_item) -> void:
		_reward_earned = true
	_reward_load.on_ad_loaded = _on_rewarded_loaded
	_reward_load.on_ad_failed_to_load = func(_error) -> void:
		rewarded_loaded = false
	_reward_content.on_ad_dismissed_full_screen_content = func() -> void:
		var earned := _reward_earned
		_clear_rewarded()
		_finish_reward(earned)
	_reward_content.on_ad_failed_to_show_full_screen_content = func(_error) -> void:
		_clear_rewarded()
		_finish_reward(false)
	_interstitial_load.on_ad_loaded = _on_interstitial_loaded
	_interstitial_load.on_ad_failed_to_load = func(_error) -> void:
		interstitial_loaded = false
	_interstitial_content.on_ad_dismissed_full_screen_content = func() -> void:
		_clear_interstitial()
		_complete_interstitial(true)
	_interstitial_content.on_ad_failed_to_show_full_screen_content = func(_error) -> void:
		_clear_interstitial()
		_complete_interstitial(false)
	if _using_plugin:
		_ask_consent()
	else:
		initialized = true


func _ask_consent() -> void:
	if not Engine.has_singleton("PoingGodotAdMobConsentInformation"):
		_init_sdk()
		return
	var info := UserMessagingPlatform.consent_information
	var request := ConsentRequestParameters.new()
	info.update(request, _after_consent, func(_error) -> void:
		_init_sdk()
	)


func _after_consent() -> void:
	var info := UserMessagingPlatform.consent_information
	var required := info.get_is_consent_form_available() and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED
	if required:
		UserMessagingPlatform.load_consent_form(
			func(form) -> void:
				form.show(func(_error) -> void: _init_sdk()),
			func(_error) -> void: _init_sdk()
		)
	else:
		_init_sdk()


func _init_sdk() -> void:
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status) -> void:
		initialized = true
		_load_rewarded()
		_load_interstitial()
	MobileAds.initialize(listener)
	if not _using_plugin:
		initialized = true


func gather_consent(on_done: Callable = Callable()) -> void:
	if on_done.is_valid():
		on_done.call()


func show_banner() -> void:
	if GameState.ads_removed or not _using_plugin:
		return
	if _banner == null:
		_banner = AdView.new(BANNER_ID, AdSize.BANNER, AdPosition.BOTTOM)
		_banner.load_ad(AdRequest.new())
	else:
		_banner.show()


func hide_banner() -> void:
	if _banner != null:
		_banner.hide()


func show_rewarded(placement: String, cb: Callable) -> void:
	_rewarded_cb = cb
	if _using_plugin and rewarded_loaded and _rewarded != null:
		_reward_earned = false
		_rewarded.show(_reward_listener)
		return
	if OS.has_feature("editor"):
		_simulate_reward()
		return
	_finish_reward(false)


func show_interstitial(cb: Callable = Callable()) -> void:
	_interstitial_cb = cb
	if not GameState.interstitial_allowed():
		_complete_interstitial(false)
		return
	if _using_plugin and interstitial_loaded and _interstitial != null:
		_interstitial.show()
		return
	_complete_interstitial(false)


func _simulate_reward() -> void:
	await get_tree().create_timer(0.2, true).timeout
	_finish_reward(true)


func _finish_reward(success: bool) -> void:
	if success:
		GameState.mark_rewarded()
	var cb := _rewarded_cb
	_rewarded_cb = Callable()
	if cb.is_valid():
		cb.call(success)
	_load_rewarded()


func _complete_interstitial(shown: bool) -> void:
	if shown:
		GameState.mark_interstitial()
	var cb := _interstitial_cb
	_interstitial_cb = Callable()
	if cb.is_valid():
		cb.call()
	if shown:
		_load_interstitial()


func _load_rewarded() -> void:
	if not _using_plugin:
		return
	rewarded_loaded = false
	RewardedAdLoader.new().load(REWARDED_ID, AdRequest.new(), _reward_load)


func _load_interstitial() -> void:
	if not _using_plugin:
		return
	interstitial_loaded = false
	InterstitialAdLoader.new().load(INTERSTITIAL_ID, AdRequest.new(), _interstitial_load)


func _on_rewarded_loaded(ad: RewardedAd) -> void:
	ad.full_screen_content_callback = _reward_content
	_rewarded = ad
	rewarded_loaded = true


func _on_interstitial_loaded(ad: InterstitialAd) -> void:
	ad.full_screen_content_callback = _interstitial_content
	_interstitial = ad
	interstitial_loaded = true


func _clear_rewarded() -> void:
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null
	rewarded_loaded = false


func _clear_interstitial() -> void:
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	interstitial_loaded = false


func plugin_active() -> bool:
	return _using_plugin
