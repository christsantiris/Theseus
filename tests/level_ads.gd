extends SceneTree

# Run: godot --headless --path . --script res://tests/level_ads.gd --fixed-fps 60
var failures: Array[String] = []


class TestAds extends "res://scenes/ui/level_ads.gd":
	var allowed := true
	var presentations := 0

	func can_request_ads() -> bool:
		return allowed

	func show_then(on_finished: Callable) -> void:
		presentations += 1
		super(on_finished)


class TestAd extends InterstitialAd:
	var shows := 0
	var destroyed := false

	func _init() -> void:
		super(-1)

	func show() -> void:
		shows += 1

	func destroy() -> void:
		destroyed = true


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
	# SDK mocks created during script loading precede the SceneTree. Give their
	# nodes a tree owner so test shutdown frees them and their signal connections.
	for plugin in [MobileAds._plugin, InterstitialAd._plugin]:
		if plugin is Node and plugin.get_parent() == null:
			root.add_child(plugin)
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
	_expect(request.convert_to_dictionary().extras.get("rdp") == "1", "Ad requests pass restricted data processing, so data is never sold or shared")
	var continued := [false]
	ads.show_then(func() -> void:
		continued[0] = true
	)
	_expect(continued[0], "Results proceed immediately when no interstitial is ready")

	var state: Node = root.get_node("LevelRun")
	# Exercise the real presentation callbacks without a native SDK or live ads.
	ads.set_script(TestAds)
	state.begin_level(1)
	var packed: PackedScene = load("res://scenes/levels/level_1.tscn")
	var level: Node = packed.instantiate()
	root.add_child(level)
	current_scene = level
	state.elapsed_seconds = 12.5
	var ad := TestAd.new()
	ads._ad = ad
	level._on_gate_entered()
	level._on_gate_entered()
	_expect(paused and not level.pause_screen.visible and ad.shows == 0, "Completion pauses gameplay and hides results during the brief transition")
	_expect(ads.presentations == 1, "Repeated completion signals do not present another ad")
	level._on_next_pressed()
	_expect(current_scene == level, "Continue cannot skip the transition or ad")
	await create_timer(ads.TRANSITION_SECONDS + 0.05, true, false, true).timeout
	_expect(ad.shows == 1 and not level.pause_screen.visible, "A ready ad appears before results and Continue")
	level._process(60.0)
	_expect(paused and state.elapsed_seconds == 12.5, "Gameplay and countdown stay paused during the ad")
	if root.get_node("MobileControls").enabled:
		var controls: Node = root.get_node("MobileControls")
		_expect(not controls.buttons.attack.visible and not controls.buttons.pause.visible, "Touch gameplay controls stay hidden during the ad")
		controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		controls.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		_expect(paused and not level.pause_screen.visible, "Focus loss and Android Back cannot resume gameplay during the ad")
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	_expect(ad.destroyed and paused and level.pause_screen.visible and level.next_button.visible, "Closing the ad reveals results while gameplay stays paused")
	_expect("Time 0:12" in level.details.text, "Results preserve the completion time")
	var late_ad := TestAd.new()
	ads._on_ad_loaded(late_ad)
	level._on_next_pressed()
	var next := await _await_scene(level)
	_expect(is_instance_valid(next) and next.get("level_number") == 2 and not paused, "Continue opens the next level directly")
	_expect(late_ad.shows == 0 and ads.presentations == 1, "Continue never presents a second or late-loading ad")

	# A show failure reaches the same results screen as a successful dismissal.
	next._on_gate_entered()
	await create_timer(ads.TRANSITION_SECONDS + 0.05, true, false, true).timeout
	late_ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content.call(AdError.new(0, "test", "Failed to show", null))
	_expect(late_ad.destroyed and paused and next.pause_screen.visible, "An ad that fails to show still reveals results")

	# Eligibility may change during the transition; do not show an ineligible ad.
	next._on_replay_pressed()
	await scene_changed
	next = current_scene
	var blocked_ad := TestAd.new()
	ads._ad = blocked_ad
	next._on_gate_entered()
	ads.allowed = false
	await create_timer(ads.TRANSITION_SECONDS + 0.05, true, false, true).timeout
	_expect(blocked_ad.shows == 0 and paused and next.pause_screen.visible, "Consent changes during the transition skip the ad and reveal results")
	ads.allowed = true

	next._on_replay_pressed()
	await scene_changed
	next = current_scene
	next._on_gate_entered()
	_expect(paused and next.pause_screen.visible and not ads._showing, "No ready ad reveals results immediately without a loading wait")
	var unavailable_ad := TestAd.new()
	ads._on_ad_loaded(unavailable_ad)
	await create_timer(ads.TRANSITION_SECONDS + 0.05, true, false, true).timeout
	_expect(unavailable_ad.shows == 0, "An ad loaded after results appear cannot interrupt them")
	ads._discard_loaded_ad()

	var restore_scores := preload("res://tests/high_score_data.gd").isolate(root.get_node("HighScores"))
	state.begin_level(8)
	change_scene_to_file("res://scenes/levels/level_8.tscn")
	await scene_changed
	var final_level := current_scene
	var final_ad := TestAd.new()
	ads._ad = final_ad
	var presentations: int = ads.presentations
	final_level._on_gate_entered()
	_expect(final_ad.shows == 0 and ads.presentations == presentations and final_level.pause_screen.visible, "Final victory skips ad presentation entirely")
	_expect(final_level.pause_heading.text == "Theseus Victorious" and not final_level.next_button.visible, "Final victory keeps its results and high scores")
	ads._discard_loaded_ad()
	restore_scores.call()
	_stop_audio(root)
	OS.delay_msec(150)
	if failures.is_empty():
		print("PASS: Android/iOS registration, consent gating, ad-before-results flow, paused countdown, dismissal/failure recovery, no late ads and direct level continuation.")
	else:
		print("FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
