extends SceneTree

## Runtime smoke test: boots the real game shell and proves that the live
## Godot session drives the real simulation.
##
##   godot --headless --path Lifestate.Godot --script res://tests/run_smoke.gd
##
## Unlike run_tests.gd (which drives the core directly), this goes through the
## session autoload: the frame-rate-independent accumulator and the real
## Main.tscn scene tree. Exits 0 only when every check passes.
##
## The autoload is resolved by node path rather than by its global name, because
## a `--script` SceneTree entry point is compiled before autoload globals exist.

const SERVICE_NAME := "GameService"
const WAIT_MSEC := 3000

var _harness := TestHarness.new()
var _service: Node
var _main: Node
var _frames: int = 0
var _real_time_started: int = 0
var _real_time_baseline: int = 0
var _stage: int = 0
var _career_done: bool = false


func _initialize() -> void:
	print("LIFESTATE — Godot runtime smoke test")
	print("Godot %s" % Engine.get_version_info()["string"])
	print("")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	match _stage:
		0:
			_service = root.get_node_or_null(SERVICE_NAME)
			if not _boot_scene():
				return _finish()
			_stage = 1
			return false
		1:
			if not _check_session():
				return _finish()
			if not _check_initial_state():
				return _finish()
			_check_clickable_path()
			if not _check_deterministic_driver():
				return _finish()
			# Hand the tick back to the engine and let real time flow.
			_service.set_process(true)
			_real_time_baseline = _total_minutes(_service.clock)
			_real_time_started = Time.get_ticks_msec()
			_stage = 2
			return false
		2:
			if Time.get_ticks_msec() - _real_time_started < WAIT_MSEC:
				return false
			_check_live_loop()
			_check_scene_reads_live_state()
			_harness.check("shell survived live simulation", is_instance_valid(_main))
			_harness.check("session still owns the same PlayerState",
				_service.player != null and _service.player is PlayerState)
			if not _check_career_path():
				return _finish()
			return _finish()

	return _finish()


## Career smoke path through the REAL UI: reach 18, apply Laborer, work one
## game hour via the real Activities screen, verify +10, quit, verify idle.
func _check_career_path() -> bool:
	if _career_done:
		return true
	_career_done = true

	_harness.section("CareerPath")
	var player: PlayerState = _service.player
	var career_screen = _main._screens["career"]

	# Age to 18 through God Mode time control.
	_main.toggle_god_mode()
	_service.god_mode.advance_days(18 * 365)
	_main.toggle_god_mode()
	_harness.eq_int("career path reaches age 18", player.age, 18)

	# Open Career through MORE navigation and apply through the real button.
	_main._nav_buttons["more"].pressed.emit()
	_main.go_to("career")
	_harness.eq_string("career screen is reachable", _main._current_screen, "career")
	var laborer_entry: Dictionary = career_screen._job_cards[JobCatalog.LABORER_ID]
	laborer_entry["apply_button"].pressed.emit()
	_harness.eq_string("UI apply hires Laborer", player.career.current_job_id, JobCatalog.LABORER_ID)

	# Work one game hour through the real Activities screen.
	_main._nav_buttons["activities"].pressed.emit()
	var work_button: Button = _main._screens["activities"]._cards["work"]["action"]
	work_button.pressed.emit()
	_harness.eq_bool("Work starts while employed", player.is_working, true)
	var money_before: int = player.money
	player.advance_simulation(60)
	_harness.eq_int("one game hour of Laborer pays +10", player.money, money_before + 10)
	_harness.eq_int("one game hour grants +10 Career XP",
		player.career.get_experience(JobCatalog.LABORER_ID), 10)

	# Promote through the real UI: Max XP + Max Attributes in the God Mode
	# overlay, then ACCEPT PROMOTION on the Career screen.
	_main.toggle_god_mode()
	var max_xp_button := _find_button(_main, "Max Current Career XP")
	_harness.check("God Mode offers Max Current Career XP", max_xp_button != null)
	if max_xp_button != null:
		max_xp_button.pressed.emit()
	var max_attr_button := _find_button(_main, "Max Attributes")
	_harness.check("God Mode offers Max Attributes", max_attr_button != null)
	if max_attr_button != null:
		max_attr_button.pressed.emit()
	_main.toggle_god_mode()
	_main.go_to("career")
	_harness.eq_string("promotion is available", career_screen._promo_status.text, "PROMOTION AVAILABLE")
	career_screen._accept_button.pressed.emit()
	_harness.eq_string("UI promotion resolves Skilled Laborer", player.career.current_title(), "Skilled Laborer")
	_harness.eq_int("UI promotion resolves the rank wage", player.career.hourly_wage(), 15)

	# Another Work hour through the real Activities screen pays the new wage.
	# (The earlier shift may still be active, and the button toggles.)
	_main._nav_buttons["activities"].pressed.emit()
	var rank2_action: Button = _main._screens["activities"]._cards["work"]["action"]
	if not player.is_working:
		rank2_action.pressed.emit()
	_harness.eq_bool("Work runs at the new rank", player.is_working, true)
	money_before = player.money
	player.advance_simulation(60)
	_harness.eq_int("one game hour of Skilled Laborer pays +15", player.money, money_before + 15)
	_harness.eq_int("XP stays capped after promotion", player.career.get_experience(JobCatalog.LABORER_ID), 10000)

	# Quit through the real Career screen button and verify the state returns.
	_main.go_to("career")
	career_screen._quit_button.pressed.emit()
	_harness.eq_string("UI quit clears the job", player.career.current_job_id, "")
	_harness.eq_bool("UI quit stops Work", player.is_working, false)

	# Rehire through the real Apply button: history must be retained.
	laborer_entry["apply_button"].pressed.emit()
	_harness.eq_string("UI rehire restores Skilled Laborer", player.career.current_title(), "Skilled Laborer")
	_harness.eq_int("UI rehire restores rank", player.career.current_rank(), 2)
	_main.go_to("career")
	career_screen._quit_button.pressed.emit()

	# Navigating back re-renders Activities from live state, like a real user.
	_main._nav_buttons["activities"].pressed.emit()
	_harness.eq_string("Activities Work card returns to unemployed state",
		_main._screens["activities"]._cards["work"]["status"].text, "Get a job first.")

	# Economy through the real screen: run to the next midnight (age 18 pays
	# $5/day) and verify the charge plus the Economy screen readout.
	var to_midnight: int = 1440 - (_service.clock.hour * 60 + _service.clock.minute)
	var econ_before: int = player.money
	player.advance_simulation(to_midnight)
	_harness.eq_int("crossing midnight charges one $5 day", player.money, econ_before - 5)
	_harness.eq_int("charge recorded as paid", player.economy.total_paid, 5)
	_main.go_to("economy")
	_harness.eq_string("economy screen is reachable", _main._current_screen, "economy")
	var economy_screen = _main._screens["economy"]
	_harness.eq_string("Economy shows the daily cost",
		economy_screen._daily_label.text, "Current Daily Cost  $5 / day")
	_harness.eq_string("Economy shows the bracket",
		economy_screen._bracket_label.text, "Current Rate  Age 18–24 · $5/day")
	_harness.eq_string("Economy shows the clear state",
		economy_screen._clear_state_label.text, "No outstanding living expenses.")

	# Food & drink through the real Activities UI.
	player.debug_set_hunger(30)
	player.debug_set_thirst(25)
	_main._nav_buttons["activities"].pressed.emit()
	var activities_screen = _main._screens["activities"]
	(activities_screen._food_buttons["basic_meal"] as Button).pressed.emit()
	_harness.eq_int("UI meal charges $8", player.money, 1012)
	_harness.eq_int("UI meal restores hunger", player.hunger, 65)
	_harness.eq_int("UI meal counted", player.economy.meals_purchased, 1)
	(activities_screen._food_buttons["basic_drink"] as Button).pressed.emit()
	_harness.eq_int("UI drink charges $3", player.money, 1009)
	_harness.eq_int("UI drink restores thirst", player.thirst, 55)
	_harness.eq_int("UI drink counted", player.economy.drinks_purchased, 1)
	_harness.eq_int("UI spending totals", player.economy.food_drink_spent, 11)
	_main.go_to("economy")
	_harness.eq_string("Economy shows meal count",
		_main._screens["economy"]._meals_label.text, "Meals Purchased  1")

	# Counters survive save/load through the real session.
	_service.save_game("user://smoke_food.json")
	(activities_screen._food_buttons["basic_meal"] as Button).pressed.emit()
	_harness.eq_int("extra meal counted pre-load", player.economy.meals_purchased, 2)
	_service.load_game("user://smoke_food.json")
	_harness.eq_int("load restores money", player.money, 1009)
	_harness.eq_int("load restores meal count", player.economy.meals_purchased, 1)
	_harness.eq_int("load restores spending", player.economy.food_drink_spent, 11)

	# Housing through the real UI: move to Cheap Room, fail Apartment on age,
	# then cross a midnight and verify both daily charges.
	_main.go_to("housing")
	_harness.eq_string("housing screen is reachable", _main._current_screen, "housing")
	var housing_screen = _main._screens["housing"]
	(housing_screen._housing_cards["cheap_room"]["action"] as Button).pressed.emit()
	_harness.eq_string("UI move reaches cheap room",
		player.housing.current_housing_id, HousingCatalog.CHEAP_ROOM_ID)
	_harness.eq_int("UI move counted", player.housing.moves_completed, 1)
	(housing_screen._housing_cards["apartment"]["action"] as Button).pressed.emit()
	_harness.eq_string("apartment locked by age",
		player.housing.current_housing_id, HousingCatalog.CHEAP_ROOM_ID)
	var housing_money: int = player.money
	player.advance_simulation(1440)
	_harness.eq_int("midnight charges living plus housing",
		player.money, housing_money - 5 - 8)
	_harness.eq_int("housing paid recorded", player.housing.total_paid, 8)
	return true


func _boot_scene() -> bool:
	_harness.section("Boot")
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_harness.check("main scene resource loads", packed != null)
	if packed == null:
		return false
	_main = packed.instantiate()
	root.add_child(_main)
	_harness.check("main scene instantiates", _main != null)
	_harness.check("main scene script is attached", _main.get_script() != null)
	return true


func _check_session() -> bool:
	_harness.section("Session")
	_harness.check("session is available as an autoload", _service != null)
	if _service == null:
		return false
	_harness.check("session owns a real GameClock", _service.clock is GameClock)
	_harness.check("session owns a real PlayerState", _service.player is PlayerState)
	_harness.check("clock and player are wired together", _service.player._clock == _service.clock)
	_harness.check("session owns GodMode", _service.god_mode is GodMode)
	_harness.eq_bool("session starts paused like the C# reference", _service.is_running, false)
	return true


func _check_initial_state() -> bool:
	_harness.section("InitialState")
	_service.set_process(false)  # take manual control of the tick during checks
	_harness.eq_int("clock starts on day 0", _service.clock.day, 0)
	_harness.eq_int("clock starts at 00:00", _service.clock.hour * 60 + _service.clock.minute, 0)
	_harness.eq_int("player starts at age 0", _service.player.age, 0)
	_harness.eq_int("player starts as an Infant", _service.player.life_stage, LifeStage.Stage.INFANT)
	_harness.eq_int("player starts with 1000 money", _service.player.money, 1000)
	_harness.eq_int("energy starts full", _service.player.energy, 100)
	_harness.eq_int("hunger starts full", _service.player.hunger, 100)
	_harness.eq_int("thirst starts full", _service.player.thirst, 100)
	_harness.eq_string("player starts idle", _service.player.current_activity_name(), "Idle")
	return true


## The accumulator must be frame-rate independent: the same total delta applied in
## different slice sizes has to produce identical advancement.
func _check_deterministic_driver() -> bool:
	_harness.section("TickDriver")
	_service.set_running(true)
	var before: int = _total_minutes(_service.clock)

	# 2.5 accumulated real seconds => two whole-second steps => 8 game minutes.
	_service._process(0.5)
	_service._process(0.5)
	_service._process(1.0)
	_service._process(0.5)
	_harness.eq_int("2.5s in four slices advances 8 game minutes",
		_total_minutes(_service.clock) - before, 8)

	# The same 2.5s again, but as a single slice. The 0.5s left over from the
	# previous measurement is carried, not dropped, so 5.0 accumulated seconds
	# in total must yield exactly 5 whole-second steps = 20 game minutes.
	_service._process(2.5)
	_harness.eq_int("5s accumulated in uneven slices advances exactly 20 game minutes",
		_total_minutes(_service.clock) - before, 20)

	var baseline: int = _total_minutes(_service.clock)

	# Sub-second fragments alone must not advance time. The accumulator is back
	# to exactly zero here because the previous step consumed its remainder.
	baseline = _total_minutes(_service.clock)
	_service._process(0.2)
	_service._process(0.2)
	_harness.eq_int("0.4s of fragments does not advance the clock",
		_total_minutes(_service.clock) - baseline, 0)

	# A long stall beyond the per-frame cap must lose no time at all.
	baseline = _total_minutes(_service.clock)
	_service._process(500.0)
	_harness.eq_int("a 500s stall loses no time", _total_minutes(_service.clock) - baseline, 2000)

	# Needs must actually have been drained by that advancement.
	_harness.check("time advancement drained energy",
		_service.player.energy < 100, str(_service.player.energy))
	_harness.check("time advancement drained hunger",
		_service.player.hunger < 100, str(_service.player.hunger))
	return true


func _check_clickable_path() -> void:
	_harness.section("ClickablePath")
	var run_button: Button = _main.get_node("Layout/TopBar/TopBarRow/RunButton")
	run_button.pressed.emit()
	_harness.eq_bool("run button starts the simulation", _service.is_running, true)
	run_button.pressed.emit()
	_harness.eq_bool("run button stops the simulation", _service.is_running, false)

	for key in ["activities", "people", "more", "life"]:
		_main._nav_buttons[key].pressed.emit()
		_harness.eq_string("clicking %s navigates there" % key, _main._current_screen, key)

	_main._nav_buttons["activities"].pressed.emit()
	var wait_button := _find_button(_main._screen_roots["activities"], "Wait 1 Hour")
	_harness.check("Wait 1 Hour button is present", wait_button != null)
	if wait_button != null:
		var before: int = _total_minutes(_service.clock)
		wait_button.pressed.emit()
		_harness.eq_int("Wait 1 Hour advances exactly 60 game minutes",
			_total_minutes(_service.clock) - before, 60)
	_main._nav_buttons["life"].pressed.emit()


static func _find_button(node: Node, text: String) -> Button:
	var queue: Array[Node] = [node]
	while not queue.is_empty():
		var current: Node = queue.pop_front()
		if current is Button and (current as Button).text == text:
			return current as Button
		queue.append_array(current.get_children())
	return null


func _check_live_loop() -> void:
	_harness.section("LiveLoop")
	var advanced: int = _total_minutes(_service.clock) - _real_time_baseline
	_harness.check("the live loop advanced the simulation (%d min)" % advanced,
		advanced > 0, str(advanced))
	_harness.check("the live loop did not advance absurdly", advanced < 200, str(advanced))

	# Pausing must genuinely stop the clock.
	_service.set_running(false)
	var paused_baseline: int = _total_minutes(_service.clock)
	_service._process(5.0)
	_harness.eq_int("a paused session does not advance", _total_minutes(_service.clock), paused_baseline)
	_harness.eq_bool("session reports paused", _service.is_running, false)

	_service.set_running(true)
	_service._process(5.0)
	_harness.eq_int("resuming advances again", _total_minutes(_service.clock) - paused_baseline, 20)


## The scene must display the session's real numbers, not placeholders.
func _check_scene_reads_live_state() -> void:
	_harness.section("SceneBinding")
	_main._refresh_all()
	var life = _main._screens["life"]
	_harness.eq_string("Life age label matches the session",
		life._age_label.text, "Age %d" % _service.player.age)
	_harness.eq_string("Life money label matches the session",
		life._money_label.text, "$%s" % _thousands(_service.player.money))
	_harness.eq_string("Life activity label matches the session",
		life._activity_label.text, "Currently %s" % _service.player.current_activity_name())
	var clock_label: Label = _main.get_node("Layout/TopBar/TopBarRow/ClockLabel")
	_harness.eq_string("top bar clock matches the session",
		clock_label.text, _service.clock_text())
	_harness.check("top bar shows a real elapsed day",
		clock_label.text != "Day 0  00:00", clock_label.text)


static func _total_minutes(clock: GameClock) -> int:
	return clock.day * 1440 + clock.hour * 60 + clock.minute


static func _thousands(value: int) -> String:
	var text: String = str(value)
	var result: String = ""
	var count: int = 0
	for index in range(text.length() - 1, -1, -1):
		result = text[index] + result
		count += 1
		if count % 3 == 0 and index > 0:
			result = "," + result
	return result


func _finish() -> bool:
	print("")
	print("==================================================")
	print("SMOKE RESULT: %d passed, %d failed" % [_harness.passed, _harness.failed])
	for failure in _harness.failures:
		print("  - %s" % failure)
	print("==================================================")
	quit(1 if _harness.failed > 0 else 0)
	return true
