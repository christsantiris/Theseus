extends Node

# Full-screen ads play between levels on Android and iOS. Desktop and web
# continue immediately. These are Google's sample interstitial units.
const ANDROID_UNIT := "ca-app-pub-3940256099942544/1033173712"
const IOS_UNIT := "ca-app-pub-3940256099942544/4411468910"
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
		MobileAds.initialize()


func requests_ads() -> bool:
	return OS.has_feature("mobile")


func prepare() -> void:
	if not requests_ads() or _loading or _ad != null or _showing:
		return
	if not Engine.has_singleton("PoingGodotAdMobInterstitialAd"):
		return
	_loading = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = _on_ad_loaded
	callback.on_ad_failed_to_load = _on_ad_failed
	InterstitialAdLoader.new().load(_unit_id(), AdRequest.new(), callback)


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
	if OS.get_name() == "iOS":
		return IOS_UNIT
	return ANDROID_UNIT
