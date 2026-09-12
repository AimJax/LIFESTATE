extends SceneTree

## Headless UI checks for the Godot front-end:
##
##   godot --headless --path Lifestate.Godot --script res://tests/run_ui_checks.gd
##
## Verifies the real scene tree, navigation wiring, the developer overlay and
## that the UI reads genuine simulation state. Exits 0 when everything passes.

var _harness := TestHarness.new()
var _main: Node
var _frames: int = 0
var _stage: int = 0
var _settle_frames: int = 0
var _resolution_index: int = 0
var _screen_index: int = 0

const RESOLUTIONS := [Vector2i(1100, 720), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900)]
const SCREEN_KEYS := ["life", "activities", "people", "more", "character", "education", "save_load", "settings"]


func _initialize() -> void:
	print("LIFESTATE — Godot UI checks")
	print("Godot %s" % Engine.get_version_info()["string"])
	print("")
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Could not load res://scenes/Main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0:
		if _frames < 3:
			return false
		# Preflight: if the scene script failed to load, every later lookup would
		# silently error out and the run would falsely report success.
		if not _check_scene_loaded():
			return _finish("aborted — main scene script did not load")
		_check_autoload()
		_check_shell()
		_check_screens()
		_check_startup_state()
		_check_navigation()
		_check_live_data()
		_check_developer_overlay()
		_check_palette()
		_stage = 1
		_prepare_geometry_case()
		return false

	_settle_frames += 1
	if _settle_frames < 3:
		return false
	_check_geometry_case()
	_screen_index += 1
	if _screen_index == SCREEN_KEYS.size():
		_screen_index = 0
		_resolution_index += 1
	if _resolution_index == RESOLUTIONS.size():
		return _finish()
	_prepare_geometry_case()
	return false


func _check_scene_loaded() -> bool:
	_harness.section("SceneLoad")
	var loaded: bool = _main != null and _main.get_script() != null and _main.has_method("go_to")
	_harness.check("main scene script attached and loaded", loaded)
	if not loaded:
		return false
	var roots: Variant = _main.get("_screen_roots")
	var has_roots: bool = typeof(roots) == TYPE_DICTIONARY and (roots as Dictionary).size() == 8
	_harness.check("all eight screen roots exist", has_roots, str(roots))
	return has_roots


func _check_autoload() -> void:
	_harness.section("Session")
	var service: Node = root.get_node_or_null("GameService")
	_harness.check("GameService autoload exists", service != null)
	if service == null:
		return
	_harness.check("session owns a GameClock", service.clock is GameClock)
	_harness.check("session owns a PlayerState", service.player is PlayerState)
	_harness.check("session owns GodMode", service.god_mode is GodMode)
	_harness.eq_bool("session starts paused  C# parity", service.is_running, false)


func _check_shell() -> void:
	_harness.section("Shell")
	var top_bar := _main.get_node_or_null("Layout/TopBar")
	var nav_bar := _main.get_node_or_null("Layout/NavBar")
	_harness.check("top status bar exists", top_bar != null)
	_harness.check("bottom navigation exists", nav_bar != null)
	_harness.eq_int("bottom navigation has four tabs", nav_bar.get_child_count(), 4)

	var title: Label = _main.get_node("Layout/TopBar/TopBarRow/TitleLabel")
	_harness.eq_string("window title label", title.text, "LIFESTATE")
	var clock_label: Label = _main.get_node("Layout/TopBar/TopBarRow/ClockLabel")
	_harness.check("clock label shows a day and time", clock_label.text.begins_with("Day "), clock_label.text)
	var run_button: Button = _main.get_node("Layout/TopBar/TopBarRow/RunButton")
	_harness.eq_string("run button reflects paused state", run_button.text, "Paused")

	var labels: PackedStringArray = []
	for index in nav_bar.get_child_count():
		labels.append((nav_bar.get_child(index) as Button).text)
	_harness.check("nav labels are exactly LIFE/ACTIVITIES/PEOPLE/MORE",
		labels == PackedStringArray(["LIFE", "ACTIVITIES", "PEOPLE", "MORE"]), str(labels))

	_harness.check("theme resource is applied",
		_main.theme != null or ProjectSettings.get_setting("gui/theme/custom", "") != "")


func _check_screens() -> void:
	_harness.section("Screens")
	for key in SCREEN_KEYS:
		_harness.check("screen '%s' built" % key, _main._screen_roots.has(key))

	var host: MarginContainer = _main.get_node("Layout/ScreenHost")
	_harness.eq_int("all screens are hosted", host.get_child_count(), 8)
	_harness.eq_string("Life is the default screen", _main._current_screen, "life")
	_harness.check("screen roots are Controls",
		_main._screen_roots.size() == 8
		and _main._screen_roots.values().filter(func(n): return n is Control).size() == 8)


func _check_startup_state() -> void:
	_harness.section("Startup")
	var service: Node = root.get_node("GameService")
	_harness.eq_bool("session starts paused  C# parity", service.is_running, false)
	_harness.eq_string("top bar starts paused", _main._run_button.text, "Paused")
	_harness.eq_bool("God Mode backend starts disabled", service.god_mode.is_enabled, false)
	_harness.eq_bool("developer overlay starts hidden", _main.is_god_mode_visible(), false)


func _check_navigation() -> void:
	_harness.section("Navigation")
	var service: Node = root.get_node("GameService")
	var day_before: int = service.clock.day
	var money_before: int = service.player.money
	var activity_before: String = service.player.current_activity_name()

	for key in ["activities", "people", "more", "life"]:
		_main._nav_buttons[key].pressed.emit()

		var visible_count: int = 0
		var visible_key: String = ""
		for screen_key in _main._screen_roots:
			if _main._screen_roots[screen_key].visible:
				visible_count += 1
				visible_key = screen_key
		_harness.eq_int("exactly one screen visible after '%s'" % key, visible_count, 1)
		_harness.eq_string("'%s' is the visible screen" % key, visible_key, key)

	_harness.eq_int("navigation does not advance the clock", service.clock.day, day_before)
	_harness.eq_int("navigation does not change money", service.player.money, money_before)
	_harness.eq_string("navigation does not change the activity",
		service.player.current_activity_name(), activity_before)

	# Secondary screens stay reachable from the More hub.
	_main.go_to("character")
	_harness.eq_string("More can open Character", _main._current_screen, "character")
	_harness.check("Character screen is visible", _main._screen_roots["character"].visible)
	_main.go_to("education")
	_harness.check("Education screen is visible", _main._screen_roots["education"].visible)
	_main.go_to("save_load")
	_harness.check("Save/Load screen is visible", _main._screen_roots["save_load"].visible)
	_main.go_to("settings")
	_harness.check("Settings screen is visible", _main._screen_roots["settings"].visible)
	_main.go_to("life")


func _check_live_data() -> void:
	_harness.section("LiveData")
	var service: Node = root.get_node("GameService")
	var player = service.player

	# Start a genuine activity through the simulation API, then confirm the UI
	# displays that real state rather than a placeholder.
	player.start_family_time()
	_main._screens["life"].refresh()
	var activity_label: Label = _main._screens["life"]._activity_label
	_harness.eq_string("Life shows the real current activity", activity_label.text, "Currently Family Time")

	player.stop_family_time()
	player.advance_simulation(60 * 70)
	_main._screens["life"].refresh()
	var energy_value: Label = _main._screens["life"]._need_values["Energy"]
	_harness.eq_string("Life need value matches PlayerState", energy_value.text, str(player.energy))
	_harness.eq_int("need value is not the initial placeholder", 1 if energy_value.text != "100" else 0, 1)

	var age_label: Label = _main._screens["life"]._age_label
	_harness.eq_string("Life age matches PlayerState", age_label.text, "Age %d" % player.age)

	# A real pending event must surface on the Life screen.
	service.clock.advance_seconds(6 * 365 * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	player.enroll_primary_school()
	_main._screens["life"].refresh()
	_harness.check("pending event card becomes visible",
		_main._screens["life"]._pending_card.visible)
	_harness.eq_int("pending event renders one button per choice",
		_main._screens["life"]._pending_choices.get_child_count(), 2)

	# Resolving through the UI button must record real history.
	var first_choice: Button = _main._screens["life"]._pending_choices.get_child(0)
	first_choice.pressed.emit()
	_harness.eq_int("UI choice resolution records history", player.events.history_count(), 1)
	_harness.check("feed renders the resolved event",
		_main._screens["life"]._feed_container.get_child_count() == 1)
	_harness.check("empty-life message is hidden once history exists",
		not _main._screens["life"]._empty_label.visible)

	# Activities screen reflects the real activity and offers all five cards.
	_harness.eq_int("Activities grid holds five cards",
		_main._screens["activities"]._cards.size(), 5)
	player.start_studying()
	_main._screens["activities"].refresh()
	_harness.check("Activities hero shows the real activity",
		_main._screens["activities"]._hero_name.text == "STUDYING",
		_main._screens["activities"]._hero_name.text)
	_harness.check("Activities shows live progression when studying",
		_main._screens["activities"]._progress_card.visible)
	player.stop_studying()

	# People screen derives parent ages from the clock.
	_main._screens["people"].refresh()
	var mother_age: Label = _main._screens["people"]._mother_values["age"]
	_harness.check("People shows a derived parent age",
		mother_age.text.contains("Age "), mother_age.text)
	_harness.check("parent age is not the newborn default",
		mother_age.text != "Mother · Age 28", mother_age.text)


func _check_developer_overlay() -> void:
	_harness.section("GodMode")
	var service: Node = root.get_node("GameService")
	var overlay: PanelContainer = _main._god_panel

	_harness.check("developer overlay exists", overlay != null)
	_harness.check("developer overlay is hidden by default", not overlay.visible)
	_harness.eq_bool("God Mode backend starts disabled", service.god_mode.is_enabled, false)

	# F2 key event goes through the real input handler.
	var event := InputEventKey.new()
	event.keycode = KEY_F2
	event.pressed = true
	_main._unhandled_input(event)
	_harness.check("F2 shows the overlay", overlay.visible)
	_harness.eq_bool("F2 enables God Mode", service.god_mode.is_enabled, true)

	_main._unhandled_input(event)
	_harness.check("F2 hides the overlay again", not overlay.visible)
	_harness.eq_bool("hidden overlay cannot stay enabled", service.god_mode.is_enabled, false)

	# A cheat must not apply while the overlay is hidden.
	var day_before: int = service.clock.day
	service.god_mode.advance_days(1)
	_harness.eq_int("disabled God Mode does not skip time", service.clock.day, day_before)

	_main.toggle_god_mode()
	var day_before_enabled: int = service.clock.day
	service.god_mode.advance_days(1)
	_harness.eq_int("enabled God Mode skips time", service.clock.day, day_before_enabled + 1)
	_main.toggle_god_mode()


func _check_palette() -> void:
	_harness.section("Palette")
	_harness.check("background is the approved dark navy", UiTheme.BACKGROUND.to_html(false) == "0d1117")
	_harness.check("accent is the approved blue", UiTheme.ACCENT.to_html(false) == "5fa8ff")
	_harness.check("positive/warning/negative accents are restrained",
		UiTheme.POSITIVE.to_html(false) == "63d297"
		and UiTheme.WARNING.to_html(false) == "e5b567"
		and UiTheme.NEGATIVE.to_html(false) == "e06c75")
	_harness.check("theme supplies button and panel styles",
		UiTheme.theme().has_stylebox("normal", "Button")
		and UiTheme.theme().has_stylebox("panel", "PanelContainer"))
	_harness.check("progress bars use themed fill",
		UiTheme.theme().has_stylebox("fill", "ProgressBar"))


func _prepare_geometry_case() -> void:
	root.size = RESOLUTIONS[_resolution_index]
	_main.go_to(SCREEN_KEYS[_screen_index])
	_settle_frames = 0


func _check_geometry_case() -> void:
	var resolution: Vector2i = RESOLUTIONS[_resolution_index]
	var key: String = SCREEN_KEYS[_screen_index]
	var host: Control = _main.get_node("Layout/ScreenHost")
	var screen: Control = _main._screen_roots[key]
	var representatives: Array[Control] = _representatives(key)
	var prefix := "%dx%d %s" % [resolution.x, resolution.y, key.to_upper()]

	_harness.section("Geometry " + prefix)
	_harness.check(prefix + " ScreenHost has non-zero geometry", _nonzero(host), _size(host))
	_harness.check(prefix + " screen root has non-zero geometry", _nonzero(screen), _size(screen))
	_harness.check(prefix + " screen root fills ScreenHost",
		screen.get_global_rect().is_equal_approx(host.get_global_rect()),
		"host=%s root=%s" % [_rect(host), _rect(screen)])
	for control in representatives:
		_harness.check(prefix + " representative content has non-zero geometry",
			_nonzero(control), _size(control))
		_harness.check(prefix + " representative content intersects ScreenHost",
			_intersects(control, host), "host=%s content=%s" % [_rect(host), _rect(control)])
		_harness.check(prefix + " representative content stays inside ScreenHost horizontally",
			_within_host_horizontal(control, host), "host=%s content=%s" % [_rect(host), _rect(control)])

	print("GEOMETRY %s host=%s root=%s content=%s intersects=%s" % [
		prefix, _size(host), _size(screen), _size(representatives[0]), _intersects(representatives[0], host)])


func _representatives(key: String) -> Array[Control]:
	var screen = _main._screens[key]
	match key:
		"life":
			return [screen._column.get_child(0), screen._age_label, screen._column.get_child(1)]
		"activities":
			return [screen._column.get_child(0), screen._hero_card, screen._cards["sleep"]["card"]]
		"people":
			return [screen._mother_card, screen._father_card]
		"more":
			return [screen._grid.get_child(0)]
		"character":
			return [screen._age_label]
		"education":
			return [screen._enroll_button]
		"save_load":
			return [screen._status_label]
		"settings":
			return [_first_button(_main._screen_roots[key])]
	return []


func _first_button(node: Node) -> Button:
	var queue: Array[Node] = [node]
	while not queue.is_empty():
		var current: Node = queue.pop_front()
		if current is Button:
			return current as Button
		queue.append_array(current.get_children())
	return null


static func _nonzero(control: Control) -> bool:
	return control != null and control.size.x > 0.0 and control.size.y > 0.0


static func _intersects(control: Control, host: Control) -> bool:
	return _nonzero(control) and control.get_global_rect().intersects(host.get_global_rect())


static func _within_host_horizontal(control: Control, host: Control) -> bool:
	if not _nonzero(control):
		return false
	var inner := control.get_global_rect()
	var outer := host.get_global_rect()
	return inner.position.x >= outer.position.x - 1.0 and inner.end.x <= outer.end.x + 1.0


static func _size(control: Control) -> String:
	return "MISSING" if control == null else "%sx%s" % [control.size.x, control.size.y]


static func _rect(control: Control) -> String:
	return "MISSING" if control == null else str(control.get_global_rect())


func _finish(note: String = "") -> bool:
	print("")
	print("==================================================")
	if not note.is_empty():
		print("UI RESULT: " + note)
	print("UI RESULT: %d passed, %d failed" % [_harness.passed, _harness.failed])
	for failure in _harness.failures:
		print("  - %s" % failure)
	print("==================================================")
	quit(1 if _harness.failed > 0 else 0)
	return true
