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
			return _finish()

	return _finish()


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
