class_name TestHarness
extends RefCounted

## Minimal custom test harness. No third-party framework: the suite runs
## headlessly via `--script res://tests/run_tests.gd`.

const FLOAT_EPSILON: float = 0.000001

var passed: int = 0
var failed: int = 0
var failures: PackedStringArray = []

var _section: String = ""


func section(name: String) -> void:
	_section = name
	print("")
	print("=== %s ===" % name)


func check(name: String, condition: bool, detail: String = "") -> bool:
	var label: String = "%s / %s" % [_section, name] if not _section.is_empty() else name
	if condition:
		passed += 1
		print("PASS  %s" % label)
	else:
		failed += 1
		var message: String = label + (" -> " + detail if not detail.is_empty() else "")
		failures.append(message)
		print("FAIL  %s" % message)
	return condition


func eq_int(name: String, actual: int, expected: int) -> bool:
	return check(name, actual == expected, "expected %d, got %d" % [expected, actual])


func eq_bool(name: String, actual: bool, expected: bool) -> bool:
	return check(name, actual == expected, "expected %s, got %s" % [expected, actual])


func eq_string(name: String, actual: String, expected: String) -> bool:
	return check(name, actual == expected, "expected %s, got %s" % [expected, actual])


func near_float(name: String, actual: float, expected: float, epsilon: float = FLOAT_EPSILON) -> bool:
	return check(name, absf(actual - expected) <= epsilon, "expected %f, got %f" % [expected, actual])


## Every check inside one section, reported as a single regression assertion so
## the harness output stays readable at scale.
func group(name: String, condition: bool, detail: String = "") -> bool:
	return check(name, condition, detail)


## Advances the simulation in hunger-safe chunks, topping needs up between
## chunks so long activity sessions survive the Health/Death mortality rules.
## Inside a 10-hour chunk the worst drain is 20 thirst, so a topped-up player
## can never cross zero and deprivation damage never starts. Tests whose actual
## subject IS deprivation or death must drive advance_simulation directly.
static func advance_kept_alive(player: PlayerState, total_minutes: int) -> void:
	var chunk: int = 60 * 10
	var remaining: int = total_minutes
	while remaining > 0 and not player.is_dead:
		player.eat(100)
		player.drink(100)
		var step: int = mini(chunk, remaining)
		player.advance_simulation(step)
		remaining -= step
