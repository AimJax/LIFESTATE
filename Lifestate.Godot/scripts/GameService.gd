extends Node

## Authoritative LIFESTATE game session. Registered as the `GameService`
## autoload so the UI reads one simulation state instead of creating its own.
##
## The clock driver lives here; all simulation semantics stay in the core
## (GameClock / PlayerState / LifeEventSystem), which has no Godot dependency.

signal state_changed
signal event_changed
signal activity_changed
signal game_loaded(offline_seconds: int)

## Screens report contextual feedback through the session so they stay
## decoupled from the shell that renders it.
signal feedback_requested(text: String, color: Color)

## One real second = 4 game minutes, matching the C# WinForms timer exactly.
const TICK_SECONDS: float = 1.0

## Cap on whole-second steps simulated in a single frame; any remaining time is
## folded into one bulk step so nothing is dropped and no time is lost.
const MAX_STEPS_PER_FRAME: int = 60

var clock: GameClock
var player: PlayerState
var god_mode: GodMode

var is_running: bool = false

var _accumulator: float = 0.0
var _last_activity_name: String = "Idle"
var _last_event_id: String = ""


func _ready() -> void:
	reset_game()


func _process(delta: float) -> void:
	if not is_running:
		return

	_accumulator += delta
	var steps: int = 0
	while _accumulator >= TICK_SECONDS and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= TICK_SECONDS
		_step_seconds(1)
		steps += 1

	# Long frame stalls (window minimised, breakpoint, slow disk) are applied in
	# one arithmetic step rather than thousands of iterations.
	if _accumulator >= TICK_SECONDS:
		var remaining_seconds: int = int(_accumulator / TICK_SECONDS)
		_accumulator -= float(remaining_seconds) * TICK_SECONDS
		_step_seconds(remaining_seconds)

	if steps > 0:
		state_changed.emit()


func reset_game() -> void:
	clock = GameClock.new()
	player = PlayerState.new(clock)
	god_mode = GodMode.new(clock, player)
	_accumulator = 0.0
	_last_activity_name = player.current_activity_name()
	_last_event_id = ""
	state_changed.emit()


func request_feedback(text: String, color: Color = Color.WHITE) -> void:
	feedback_requested.emit(text, color)


func set_running(running: bool) -> void:
	is_running = running
	state_changed.emit()


func toggle_running() -> void:
	set_running(not is_running)


## Advances the simulation by real seconds (1 second = 4 game minutes).
func _step_seconds(seconds: int) -> void:
	if seconds <= 0:
		return
	clock.advance_seconds(seconds)
	player.advance_simulation(seconds * GameClock.MINUTES_PER_REAL_SECOND)
	_emit_transitions()


## "Wait 1 Hour" support action: identical to the reference implementation.
func wait_one_hour() -> void:
	clock.advance_seconds(15)
	player.advance_simulation(60)
	_emit_transitions()
	state_changed.emit()


func _emit_transitions() -> void:
	var activity_name: String = player.current_activity_name()
	if activity_name != _last_activity_name:
		_last_activity_name = activity_name
		activity_changed.emit()

	var event_id: String = ""
	if player.events.current_event != null:
		event_id = player.events.current_event.event_id
	if event_id != _last_event_id:
		_last_event_id = event_id
		event_changed.emit()


func save_game(path: String = "") -> Dictionary:
	return SaveManager.save_game(clock, player, path)


func load_game(path: String = "") -> Dictionary:
	var result: Dictionary = SaveManager.load_game(clock, player, path)
	if result["ok"]:
		_last_activity_name = player.current_activity_name()
		_last_event_id = ""
		state_changed.emit()
		game_loaded.emit(result["offline_seconds"])
	return result


func clock_text() -> String:
	return "Day %s  %02d:%02d" % [_thousands(clock.day), clock.hour, clock.minute]


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
