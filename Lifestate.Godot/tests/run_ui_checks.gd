extends SceneTree

## Real-scene UI checks, including ancestor-aware visible geometry.

var _harness := TestHarness.new()
var _main: Node
var _frames := 0
var _stage := 0
var _settle_frames := 0
var _resolution_index := 0
var _screen_index := 0
var _education_case_index := 0
var _career_case_index := 0

const RESOLUTIONS := [Vector2i(1100, 720), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900)]
const SCREEN_KEYS := ["life", "activities", "people", "more", "character", "education", "career", "save_load", "settings"]
const EDUCATION_CASES := ["primary_enroll", "primary_active", "primary_completed_wait", "secondary_enroll", "secondary_active", "secondary_completed"]
const CAREER_CASES := ["unemployed", "employed"]


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
		if not _check_scene_loaded():
			return _finish("aborted — main scene script did not load")
		_check_autoload()
		_check_shell()
		_check_screens()
		_check_startup_state()
		_check_navigation()
		_check_developer_overlay()
		_check_palette()
		_stage = 1
		_prepare_geometry_case()
		return false

	_settle_frames += 1
	if _settle_frames < 3:
		return false
	if _stage == 1:
		_check_geometry_case()
		_screen_index += 1
		if _screen_index == SCREEN_KEYS.size():
			_screen_index = 0
			_resolution_index += 1
		if _resolution_index == RESOLUTIONS.size():
			_stage = 2
			_prepare_education_case()
			return false
		_prepare_geometry_case()
		return false

	if _stage == 3:
		_check_career_case()
		_career_case_index += 1
		if _career_case_index == CAREER_CASES.size():
			_check_live_data()
			return _finish()
		_prepare_career_case()
		return false

	_check_education_case()
	_education_case_index += 1
	if _education_case_index == EDUCATION_CASES.size():
		_stage = 3
		_prepare_career_case()
		return false
	_prepare_education_case()
	return false


func _prepare_career_case() -> void:
	var service: Node = root.get_node("GameService")
	var player: PlayerState = service.player
	var case_name: String = CAREER_CASES[_career_case_index]
	match case_name:
		"unemployed":
			service.clock.restore(20 * 365, 0, 0)
			player.career.restore("")
			if player.is_working:
				player.stop_working()
		"employed":
			service.clock.restore(20 * 365, 0, 0)
			player.career.restore("")
			player.apply_for_job(JobCatalog.OFFICE_CLERK_ID)
			player.education.restore(EducationState.Status.COMPLETED_SECONDARY, 6, 100, service.clock.day - 365, 12)
			player.attributes.restore(20.0, 10.0, 10.0, 10.0, 10.0)
			player.apply_for_job(JobCatalog.OFFICE_CLERK_ID)
	_main.go_to("career")
	_main._screens["career"].refresh()
	_settle_frames = 0


func _check_career_case() -> void:
	var screen = _main._screens["career"]
	var host: Control = _main.get_node("Layout/ScreenHost")
	var service: Node = root.get_node("GameService")
	var player: PlayerState = service.player
	var case_name: String = CAREER_CASES[_career_case_index]
	var control: Control
	var expected_text: String
	match case_name:
		"unemployed":
			control = screen._status_title
			expected_text = "UNEMPLOYED"
		"employed":
			control = screen._status_detail
			expected_text = "Office Clerk · $18/hour"
	var visible_rect := _visible_rect(control, host)
	_harness.section("Career " + case_name)
	_harness.check(case_name + " representative has non-zero visible geometry",
		visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0,
		"control=%s visible=%s" % [_rect(control), visible_rect])
	_harness.eq_string(case_name + " visible text", control.text, expected_text)
	# A job card and its Apply button must be genuinely visible.
	var laborer_entry: Dictionary = screen._job_cards[JobCatalog.LABORER_ID]
	var card_rect := _visible_rect(laborer_entry["card"], host)
	_harness.check(case_name + " Laborer card has non-zero visible geometry",
		card_rect.size.x > 0.0 and card_rect.size.y > 0.0, "%s" % card_rect)
	var apply_rect := _visible_rect(laborer_entry["apply_button"], host)
	_harness.check(case_name + " Laborer Apply button has non-zero visible geometry",
		apply_rect.size.x > 0.0 and apply_rect.size.y > 0.0, "%s" % apply_rect)
	_harness.eq_bool(case_name + " employed flag matches player",
		screen._service.player.career.is_employed(), case_name == "employed")
	if case_name == "employed":
		_harness.eq_bool("employed career disables Apply buttons", laborer_entry["apply_button"].disabled, true)
		_harness.eq_bool("employed career shows Quit button", screen._quit_button.visible, true)


func _check_scene_loaded() -> bool:
	_harness.section("SceneLoad")
	var loaded: bool = _main != null and _main.get_script() != null and _main.has_method("go_to")
	_harness.check("main scene script attached and loaded", loaded)
	if not loaded:
		return false
	var roots: Variant = _main.get("_screen_roots")
	var has_roots: bool = typeof(roots) == TYPE_DICTIONARY and (roots as Dictionary).size() == 9
	_harness.check("all nine screen roots exist", has_roots, str(roots))
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
	_harness.eq_bool("session starts paused (C# parity)", service.is_running, false)


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
	_harness.eq_int("all screens are hosted", host.get_child_count(), 9)
	_harness.eq_string("Life is the default screen", _main._current_screen, "life")
	_harness.check("screen roots are Controls",
		_main._screen_roots.size() == 9
		and _main._screen_roots.values().filter(func(node): return node is Control).size() == 9)


func _check_startup_state() -> void:
	_harness.section("Startup")
	var service: Node = root.get_node("GameService")
	_harness.eq_bool("session starts paused (C# parity)", service.is_running, false)
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
		var visible_count := 0
		var visible_key := ""
		for screen_key in _main._screen_roots:
			if _main._screen_roots[screen_key].visible:
				visible_count += 1
				visible_key = screen_key
		_harness.eq_int("exactly one screen visible after '%s'" % key, visible_count, 1)
		_harness.eq_string("'%s' is the visible screen" % key, visible_key, key)
	_harness.eq_int("navigation does not advance the clock", service.clock.day, day_before)
	_harness.eq_int("navigation does not change money", service.player.money, money_before)
	_harness.eq_string("navigation does not change the activity", service.player.current_activity_name(), activity_before)
	_main.go_to("character")
	_harness.eq_string("More can open Character", _main._current_screen, "character")
	_harness.check("Character screen is visible", _main._screen_roots["character"].visible)
	_main.go_to("education")
	_harness.check("Education screen is visible", _main._screen_roots["education"].visible)
	_main.go_to("career")
	_harness.eq_string("More can open Career", _main._current_screen, "career")
	_harness.check("Career screen is visible", _main._screen_roots["career"].visible)
	_main.go_to("save_load")
	_harness.check("Save/Load screen is visible", _main._screen_roots["save_load"].visible)
	_main.go_to("settings")
	_harness.check("Settings screen is visible", _main._screen_roots["settings"].visible)
	_main.go_to("life")


func _check_live_data() -> void:
	_harness.section("LiveData")
	var service: Node = root.get_node("GameService")
	var player = service.player
	player.start_family_time()
	_main._screens["life"].refresh()
	var activity_label: Label = _main._screens["life"]._activity_label
	_harness.eq_string("Life shows the real current activity", activity_label.text, "Currently Family Time")
	player.stop_family_time()
	player.advance_simulation(60 * 70)
	_main._screens["life"].refresh()
	var energy_value: Label = _main._screens["life"]._need_values["Energy"]
	_harness.eq_string("Life need value matches PlayerState", energy_value.text, str(player.energy))
	_harness.check("need value is not the initial placeholder", energy_value.text != "100")
	var age_label: Label = _main._screens["life"]._age_label
	_harness.eq_string("Life age matches PlayerState", age_label.text, "Age %d" % player.age)
	service.clock.advance_seconds(6 * 365 * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	player.enroll_primary_school()
	_main._screens["life"].refresh()
	_harness.check("pending event card becomes visible", _main._screens["life"]._pending_card.visible)
	_harness.eq_int("pending event renders one button per choice", _main._screens["life"]._pending_choices.get_child_count(), 2)
	var first_choice: Button = _main._screens["life"]._pending_choices.get_child(0)
	first_choice.pressed.emit()
	_harness.eq_int("UI choice resolution records history", player.events.history_count(), 1)
	_harness.check("feed renders the resolved event", _main._screens["life"]._feed_container.get_child_count() == 1)
	_harness.check("empty-life message is hidden once history exists", not _main._screens["life"]._empty_label.visible)
	_harness.eq_int("Activities grid holds five cards", _main._screens["activities"]._cards.size(), 5)
	player.start_studying()
	_main._screens["activities"].refresh()
	_harness.check("Activities hero shows the real activity",
		_main._screens["activities"]._hero_name.text == "STUDYING", _main._screens["activities"]._hero_name.text)
	_harness.check("Activities shows live progression when studying", _main._screens["activities"]._progress_card.visible)
	player.stop_studying()
	_main._screens["people"].refresh()
	var mother_age: Label = _main._screens["people"]._mother_values["age"]
	_harness.check("People shows a derived parent age", mother_age.text.contains("Age "), mother_age.text)
	_harness.check("parent age is not the newborn default", mother_age.text != "Mother · Age 28", mother_age.text)


func _check_developer_overlay() -> void:
	_harness.section("GodMode")
	var service: Node = root.get_node("GameService")
	var overlay: PanelContainer = _main._god_panel
	_harness.check("developer overlay exists", overlay != null)
	_harness.check("developer overlay is hidden by default", not overlay.visible)
	_harness.eq_bool("God Mode backend starts disabled", service.god_mode.is_enabled, false)
	var event := InputEventKey.new()
	event.keycode = KEY_F2
	event.pressed = true
	_main._unhandled_input(event)
	_harness.check("F2 shows the overlay", overlay.visible)
	_harness.eq_bool("F2 enables God Mode", service.god_mode.is_enabled, true)
	_main._unhandled_input(event)
	_harness.check("F2 hides the overlay again", not overlay.visible)
	_harness.eq_bool("hidden overlay cannot stay enabled", service.god_mode.is_enabled, false)
	var day_before: int = service.clock.day
	service.god_mode.advance_days(1)
	_harness.eq_int("disabled God Mode does not skip time", service.clock.day, day_before)
	_main.toggle_god_mode()
	var enabled_day: int = service.clock.day
	service.god_mode.advance_days(1)
	_harness.eq_int("enabled God Mode skips time", service.clock.day, enabled_day + 1)
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
	_harness.check("progress bars use themed fill", UiTheme.theme().has_stylebox("fill", "ProgressBar"))


func _prepare_geometry_case() -> void:
	root.size = RESOLUTIONS[_resolution_index]
	_main.go_to(SCREEN_KEYS[_screen_index])
	_settle_frames = 0


func _check_geometry_case() -> void:
	var resolution: Vector2i = RESOLUTIONS[_resolution_index]
	var key: String = SCREEN_KEYS[_screen_index]
	var host: Control = _main.get_node("Layout/ScreenHost")
	var screen: Control = _main._screen_roots[key]
	var chain := _layout_chain(screen)
	var representatives := _representatives(key)
	var prefix := "%dx%d %s" % [resolution.x, resolution.y, key.to_upper()]
	_harness.section("Geometry " + prefix)
	_harness.check(prefix + " screen root fills ScreenHost",
		screen.get_global_rect().is_equal_approx(host.get_global_rect()),
		"host=%s root=%s" % [_rect(host), _rect(screen)])
	for control in chain:
		_harness.check(prefix + " layout ancestor %s has non-zero geometry" % control.name,
			_nonzero(control), _size(control))
	for control in representatives:
		_harness.check(prefix + " representative %s has non-zero geometry" % control.name,
			_nonzero(control), _size(control))
		var visible_rect := _visible_rect(control, host)
		_harness.check(prefix + " representative %s has a positive visible rect" % control.name,
			visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0,
			"control=%s visible=%s" % [_rect(control), visible_rect])
		_harness.check(prefix + " representative %s stays inside ScreenHost horizontally" % control.name,
			_within_host_horizontal(control, host), "host=%s content=%s" % [_rect(host), _rect(control)])
	if resolution == Vector2i(1280, 720) and ["life", "activities", "people", "more"].has(key):
		for required_text in _required_texts(key):
			var text_control := _find_text_control(screen, required_text)
			var text_visible := _visible_rect(text_control, host)
			_harness.check("%s '%s' is actually visible" % [prefix, required_text],
				text_visible.size.x > 0.0 and text_visible.size.y > 0.0,
				"node=%s visible=%s" % [_rect(text_control), text_visible])
	var scroll: Control = chain[3]
	print("GEOMETRY %s host=%s root=%s centered_host=%s center=%s scroll=%s vbox=%s visible=%s" % [
		prefix, _size(host), _size(screen), _size(chain[1]), _size(chain[2]), _size(scroll),
		_size(chain[4]), _visible_rect(representatives[0], host)])


func _prepare_education_case() -> void:
	var service: Node = root.get_node("GameService")
	var player: PlayerState = service.player
	var education: EducationState = player.education
	var case_name: String = EDUCATION_CASES[_education_case_index]
	match case_name:
		"primary_enroll":
			service.clock.restore(6 * 365, 0, 0)
			education.restore(EducationState.Status.NOT_ENROLLED, 0, 0, 0)
		"primary_active":
			service.clock.restore(8 * 365, 0, 0)
			education.restore(EducationState.Status.PRIMARY_SCHOOL, 3, 50, service.clock.day - 100)
		"primary_completed_wait":
			service.clock.restore(11 * 365, 0, 0)
			education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, service.clock.day - 365)
		"secondary_enroll":
			service.clock.restore(12 * 365, 0, 0)
			education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, service.clock.day - 365)
		"secondary_active":
			service.clock.restore(14 * 365, 0, 0)
			education.restore(EducationState.Status.SECONDARY_SCHOOL, 6, 50, service.clock.day - 100, 9)
		"secondary_completed":
			service.clock.restore(18 * 365, 0, 0)
			education.restore(EducationState.Status.COMPLETED_SECONDARY, 6, 100, service.clock.day - 365, 12)
	_main.go_to("education")
	_main._screens["education"].refresh()
	_settle_frames = 0


func _check_education_case() -> void:
	var screen = _main._screens["education"]
	var host: Control = _main.get_node("Layout/ScreenHost")
	var case_name: String = EDUCATION_CASES[_education_case_index]
	var control: Control
	var expected_text: String
	match case_name:
		"primary_enroll":
			control = screen._enroll_button
			expected_text = "ENROLL IN PRIMARY SCHOOL"
		"primary_active":
			control = screen._grade_label
			expected_text = "PRIMARY SCHOOL · GRADE 3"
		"primary_completed_wait":
			control = screen._secondary_hint_label
			expected_text = "Secondary school becomes available at age 12."
		"secondary_enroll":
			control = screen._secondary_enroll_button
			expected_text = "ENROLL IN SECONDARY SCHOOL"
		"secondary_active":
			control = screen._grade_label
			expected_text = "SECONDARY SCHOOL · GRADE 9"
		"secondary_completed":
			control = screen._grade_label
			expected_text = "SECONDARY SCHOOL COMPLETED"
	var visible_rect := _visible_rect(control, host)
	_harness.section("Education " + case_name)
	_harness.check(case_name + " representative has non-zero visible geometry",
		visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0,
		"control=%s visible=%s" % [_rect(control), visible_rect])
	_harness.eq_string(case_name + " visible text", control.text, expected_text)

static func _layout_chain(screen: Control) -> Array[Control]:
	var centered_host: Control = screen.get_child(0)
	var center: Control = centered_host.get_child(0)
	var scroll: Control = center.get_child(0)
	var column: Control = scroll.get_child(0)
	return [screen, centered_host, center, scroll, column]


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
			return [screen._grade_label]
		"save_load":
			return [screen._status_label]
		"settings":
			return [_first_button(_main._screen_roots[key])]
	return []


static func _required_texts(key: String) -> PackedStringArray:
	match key:
		"life":
			return PackedStringArray(["Age 0", "Infant", "$1,000", "Currently Idle", "Energy", "Hunger", "Thirst", "Your life story is just beginning."])
		"activities":
			return PackedStringArray(["ACTIVITIES", "IDLE", "SUPPORT", "SLEEP", "STUDY"])
		"people":
			return PackedStringArray(["MOTHER", "FATHER"])
		"more":
			return PackedStringArray(["CHARACTER", "EDUCATION", "CAREER", "SAVE / LOAD", "SETTINGS"])
	return PackedStringArray()


static func _find_text_control(node: Node, text: String) -> Control:
	var queue: Array[Node] = [node]
	while not queue.is_empty():
		var current: Node = queue.pop_front()
		if current is Label and (current as Label).text == text:
			return current as Label
		if current is Button and (current as Button).text == text:
			return current as Button
		queue.append_array(current.get_children())
	return null


static func _first_button(node: Node) -> Button:
	var queue: Array[Node] = [node]
	while not queue.is_empty():
		var current: Node = queue.pop_front()
		if current is Button:
			return current as Button
		queue.append_array(current.get_children())
	return null


static func _visible_rect(control: Control, stop_at: Control) -> Rect2:
	if not _nonzero(control) or not control.is_visible_in_tree():
		return Rect2()
	var visible_rect := control.get_global_rect()
	var current: Node = control
	while current != null:
		if current is Control:
			var ancestor := current as Control
			if not _nonzero(ancestor):
				return Rect2()
			if ancestor.clip_contents:
				visible_rect = visible_rect.intersection(ancestor.get_global_rect())
			if ancestor == stop_at:
				break
		current = current.get_parent()
	return visible_rect


static func _nonzero(control: Control) -> bool:
	return control != null and control.size.x > 0.0 and control.size.y > 0.0


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
