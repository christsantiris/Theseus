extends Node

# Debug mobile builds use Google's demo units. Release builds use the
# registered units once advertising/production_enabled is on. Google's User
# Messaging Platform (UMP) decides whether consent is needed: no ad is requested
# until the player has answered a required consent message.
const ANDROID_TEST_UNIT := "ca-app-pub-3940256099942544/1033173712"
const IOS_TEST_UNIT := "ca-app-pub-3940256099942544/4411468910"
const ANDROID_UNIT := "ca-app-pub-9323307074562151/3770627453"
const IOS_UNIT := "ca-app-pub-9323307074562151/2070019624"
const MAX_LOAD_ATTEMPTS := 3
const TRANSITION_SECONDS := 0.35
# Debug builds only: a hashed device ID from the UMP log forces the European
# consent message on that test device.
const CONSENT_TEST_DEVICE_SETTING := "advertising/consent_test_device_id"

## Emitted after consent information or the player's privacy choices change.
signal consent_changed

var _ad: InterstitialAd
var _content_callback: FullScreenContentCallback
var _loading := false
var _showing := false
var _load_attempts := 0
var _pending := Callable()
var _sdk_started := false
var _consent_form_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if requests_ads():
		# A choice saved in an earlier session lets ads start before the refresh.
		_start_ads_if_allowed()
		_refresh_consent()


func requests_ads() -> bool:
	return OS.has_feature("mobile") and not _unit_id().is_empty()


## True when Google's consent status permits ad requests.
func can_request_ads() -> bool:
	return requests_ads() and ads_allowed_for(UserMessagingPlatform.consent_information.get_consent_status())


static func ads_allowed_for(status: int) -> bool:
	return status in [ConsentInformation.ConsentStatus.OBTAINED, ConsentInformation.ConsentStatus.NOT_REQUIRED]


## True when the player must be able to reopen the consent message, for
## example in the European Economic Area or the UK.
func privacy_options_required() -> bool:
	return requests_ads() and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	if not privacy_options_required() or _consent_form_open:
		return
	_consent_form_open = true
	UserMessagingPlatform.show_privacy_options_form(_on_consent_form_dismissed)


func _refresh_consent() -> void:
	var request := ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = false
	var test_device: String = str(ProjectSettings.get_setting(CONSENT_TEST_DEVICE_SETTING, ""))
	if OS.is_debug_build() and not test_device.is_empty():
		var debug_settings := ConsentDebugSettings.new()
		debug_settings.debug_geography = DebugGeography.Values.EEA
		debug_settings.test_device_hashed_ids.append(test_device)
		request.consent_debug_settings = debug_settings
	# On failure (offline or misconfigured), keep whatever choice was saved earlier.
	UserMessagingPlatform.consent_information.update(request, _on_consent_info_updated, _on_consent_form_failed)


func _on_consent_info_updated() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() != ConsentInformation.ConsentStatus.REQUIRED or not info.get_is_consent_form_available():
		_on_consent_resolved()
		return
	UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_form_failed)


func _on_consent_form_loaded(form: ConsentForm) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() != ConsentInformation.ConsentStatus.REQUIRED:
		_on_consent_resolved()
		return
	_consent_form_open = true
	form.show(_on_consent_form_dismissed)


func _on_consent_form_failed(_error: FormError) -> void:
	_on_consent_resolved()


func _on_consent_form_dismissed(_error: FormError) -> void:
	_consent_form_open = false
	_on_consent_resolved()


func _on_consent_resolved() -> void:
	_start_ads_if_allowed()
	if not can_request_ads():
		_discard_loaded_ad()
	consent_changed.emit()


func _start_ads_if_allowed() -> void:
	if _sdk_started or not can_request_ads():
		return
	_sdk_started = true
	MobileAds.set_publisher_first_party_id_enabled(false)
	MobileAds.initialize()
	prepare()


func _discard_loaded_ad() -> void:
	if _ad != null and not _showing:
		_ad.destroy()
		_ad = null


func prepare() -> void:
	if not _sdk_started or not can_request_ads() or _loading or _ad != null or _showing:
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
	if _ad == null or not can_request_ads():
		on_finished.call()
		return
	_showing = true
	_pending = on_finished
	# Let gameplay taps settle before a ready ad appears. Never wait for a load.
	await get_tree().create_timer(TRANSITION_SECONDS, true, false, true).timeout
	if not can_request_ads():
		_finish()
		return
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


# Every request is non-personalized (npa) and uses Google's restricted data
# processing (rdp), so no player's data is used for interest-based ads or sold
# or shared, whatever they answer in a consent message.
static func _new_request() -> AdRequest:
	var request := AdRequest.new()
	request.extras = {"npa": "1", "rdp": "1"}
	return request
