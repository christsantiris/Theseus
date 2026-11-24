extends Node

# Debug mobile builds use Google's demo units. Live serving stays off until
# privacy handling and native-device validation are complete.
const ANDROID_TEST_UNIT := "ca-app-pub-3940256099942544/1033173712"
const IOS_TEST_UNIT := "ca-app-pub-3940256099942544/4411468910"
const ANDROID_UNIT := "ca-app-pub-9323307074562151/3770627453"
const IOS_UNIT := "ca-app-pub-9323307074562151/2070019624"
const MAX_LOAD_ATTEMPTS := 3

var _ad: InterstitialAd
var _content_callback: FullScreenContentCallback
var _loading := false
var _showing := false
var _load_attempts := 0
var _pending := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if requests_ads():
		MobileAds.set_publisher_first_party_id_enabled(false)
		MobileAds.initialize()


func requests_ads() -> bool:
	return OS.has_feature("mobile") and not _unit_id().is_empty()


func prepare() -> void:
	if not requests_ads() or _loading or _ad != null or _showing:
		return
	if not Engine.has_singleton("PoingGodotAdMobInterstitialAd"):
		return
	_loading = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = _on_ad_loaded
	callback.on_ad_failed_to_load = _on_ad_failed
	InterstitialAdLoader.new().load(_unit_id(), _new_request(), callback)


func show_then(on_finished: Callable) -> void:
	if _showing:
		return
	if _ad == null:
		on_finished.call()
		return
	_showing = true
	_pending = on_finished
	_content_callback = FullScreenContentCallback.new()
	_content_callback.on_ad_dismissed_full_screen_content = _finish
	_content_callback.on_ad_failed_to_show_full_screen_content = _on_show_failed
	_ad.full_screen_content_callback = _content_callback
	_ad.show()


func _on_ad_loaded(ad: InterstitialAd) -> void:
	_loading = false
	_load_attempts = 0
	_ad = ad


func _on_ad_failed(_error: LoadAdError) -> void:
	_loading = false
	_load_attempts += 1
	if _load_attempts < MAX_LOAD_ATTEMPTS:
		get_tree().create_timer(2.0).timeout.connect(prepare)


func _on_show_failed(_error: AdError) -> void:
	_finish()


func _finish() -> void:
	if not _showing:
		return
	_showing = false
	var ad := _ad
	_ad = null
	_content_callback = null
	if ad != null:
		ad.destroy()
	var done := _pending
	_pending = Callable()
	_load_attempts = 0
	prepare()
	if done.is_valid():
		done.call()


func _unit_id() -> String:
	return unit_id_for(OS.get_name(), OS.is_debug_build(), bool(ProjectSettings.get_setting("advertising/production_enabled", false)))


static func unit_id_for(platform: String, debug_build: bool, production_enabled: bool) -> String:
	if platform not in ["iOS", "Android"]:
		return ""
	if debug_build:
		return IOS_TEST_UNIT if platform == "iOS" else ANDROID_TEST_UNIT
	if production_enabled:
		return IOS_UNIT if platform == "iOS" else ANDROID_UNIT
	return ""


static func _new_request() -> AdRequest:
	var request := AdRequest.new()
	request.extras = {"npa": "1"}
	return request
