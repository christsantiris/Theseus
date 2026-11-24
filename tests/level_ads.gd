extends SceneTree

# Run: godot --headless --path . --script res://tests/level_ads.gd --fixed-fps 60
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _await_scene(previous: Node) -> Node:
	for _frame in 90:
		await physics_frame
		if is_instance_valid(current_scene) and current_scene != previous:
			return current_scene
	return current_scene


func _stop_audio(node: Node) -> void:
	for child in node.get_children():
		_stop_audio(child)
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null


func _run() -> void:
	var ads: Node = root.get_node("LevelAds")
	_expect(ads.has_method("prepare") and ads.has_method("show_then"), "Level ads autoload is present")
	_expect(not ads.requests_ads(), "Desktop and web do not request an interstitial")
	_expect(ProjectSettings.get_setting("admob/general/android/app_id") == "ca-app-pub-9323307074562151~4923413670", "Android export uses Theseus's registered AdMob app ID")
	_expect(ProjectSettings.get_setting("admob/general/ios/app_id") == "ca-app-pub-9323307074562151~5989083331", "iOS export uses Theseus's registered AdMob app ID")
	_expect(ProjectSettings.get_setting("advertising/production_enabled", false), "Release builds serve the registered ad units")
	_expect(str(ProjectSettings.get_setting(ads.CONSENT_TEST_DEVICE_SETTING, "")).is_empty(), "No consent test device is committed")
	_expect(not ads.can_request_ads() and not ads.privacy_options_required(), "Desktop and web skip consent and privacy options")
	_expect(not ads.ads_allowed_for(ConsentInformation.ConsentStatus.UNKNOWN), "Ads wait for Google's consent status")
	_expect(not ads.ads_allowed_for(ConsentInformation.ConsentStatus.REQUIRED), "Ads wait while a required consent message is unanswered")
	_expect(ads.ads_allowed_for(ConsentInformation.ConsentStatus.OBTAINED), "Ads load after the player answers the consent message")
	_expect(ads.ads_allowed_for(ConsentInformation.ConsentStatus.NOT_REQUIRED), "Ads load where no consent message applies")
	for platform in ["iOS", "Android"]:
		var expected_test: String = ads.IOS_TEST_UNIT if platform == "iOS" else ads.ANDROID_TEST_UNIT
		_expect(ads.unit_id_for(platform, true, true) == expected_test, "Debug builds always use test ads on " + platform)
		_expect(ads.unit_id_for(platform, true, false) == expected_test, "Debug ads work before live serving is enabled on " + platform)
		_expect(ads.unit_id_for(platform, false, false).is_empty(), "Release builds skip ads until production is enabled on " + platform)
	_expect(ads.unit_id_for("iOS", false, true) == "ca-app-pub-9323307074562151/2070019624", "Configured iOS production unit is separate from the test unit")
	_expect(ads.unit_id_for("Android", false, true) == "ca-app-pub-9323307074562151/3770627453", "Android production requests select their own registered unit")
	for platform in ["macOS", "Windows", "Linux", "Web"]:
		_expect(ads.unit_id_for(platform, true, true).is_empty(), "Mobile ads are unavailable on " + platform)
	var request: AdRequest = ads._new_request()
	_expect(request.convert_to_dictionary().extras.get("npa") == "1", "Ad requests pass non-personalized treatment to the native plugin")
	var continued := [false]
	ads.show_then(func() -> void:
		continued[0] = true
	)
	_expect(continued[0], "Continue proceeds immediately when no interstitial is ready")

	var state: Node = root.get_node("LevelRun")
	state.begin_level(1)
	var packed: PackedScene = load("res://scenes/levels/level_1.tscn")
	var level: Node = packed.instantiate()
	root.add_child(level)
	current_scene = level
	level._complete = true
	level._on_next_pressed()
	var next := await _await_scene(level)
	_expect(is_instance_valid(next) and next.get("level_number") == 2, "Continue still opens the next level")
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Android/iOS registration, debug test ads, production units, consent gating, non-personalized request parameters, desktop bypass and level continuation.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
