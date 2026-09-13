extends SceneTree

## Headless regression runner for the GDScript port:
##
##   godot --headless --path Lifestate.Godot --script res://tests/run_tests.gd
##
## Exits 0 when every assertion passes, 1 otherwise.

const TestClockNeeds = preload("res://tests/test_clock_needs.gd")
const TestActivities = preload("res://tests/test_activities.gd")
const TestProgression = preload("res://tests/test_progression.gd")
const TestFamilyEvents = preload("res://tests/test_family_events.gd")
const TestPersistence = preload("res://tests/test_persistence.gd")
const TestGodMode = preload("res://tests/test_godmode.gd")
const TestEducation = preload("res://tests/test_education.gd")
const TestGodModeEducation = preload("res://tests/test_godmode_education.gd")
const TestCareer = preload("res://tests/test_career.gd")

func _initialize() -> void:
	var harness := TestHarness.new()

	print("LIFESTATE — GDScript simulation regression suite")
	print("Godot %s" % Engine.get_version_info()["string"])

	TestClockNeeds.run(harness)
	TestActivities.run(harness)
	TestProgression.run(harness)
	TestFamilyEvents.run(harness)
	TestPersistence.run(harness)
	TestGodMode.run(harness)
	TestEducation.run(harness)
	TestGodModeEducation.run(harness)
	TestCareer.run(harness)

	print("")
	print("==================================================")
	print("RESULT: %d passed, %d failed" % [harness.passed, harness.failed])
	if harness.failed > 0:
		print("FAILURES:")
		for failure in harness.failures:
			print("  - %s" % failure)
	print("==================================================")

	quit(1 if harness.failed > 0 else 0)
