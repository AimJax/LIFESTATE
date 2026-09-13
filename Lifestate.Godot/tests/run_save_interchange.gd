extends SceneTree

## Cross-implementation save interchange test.
##
##   godot --headless --path Lifestate.Godot --script res://tests/run_save_interchange.gd
##
## Proves the Godot build remains compatible with Version 7 C# saves:
##
##   1. load a save file WRITTEN BY THE C# BUILD (tests/fixtures/csharp_save_v7.json)
##   2. re-serialize it and compare every persisted key against the C# original
##   3. compare a canonical integer summary against the C# save-time summary
## Godot Version 8 -> C# Version 7 loading is intentionally unsupported.
##
## Exits 0 only when every check passes.

const CSHARP_SAVE := "res://tests/fixtures/csharp_save_v7.json"
const CSHARP_SUMMARY := "res://tests/fixtures/csharp_summary.json"
const GODOT_OFFLINE_SUMMARY := "res://tests/fixtures/godot_offline_summary.json"
const LEGACY_V1_SAVE := "res://tests/fixtures/legacy_v1_save.json"

## The C# harness wrote its fixture with this exact SavedAtUtc, and reloads with
## now == SavedAtUtc so offline progression is exactly zero on both sides.
const FIXED_STAMP: float = 1800000000.0

## SavedAtUtc is compared semantically rather than literally: .NET emits
## "2027-01-15T08:00:00+00:00" while the port emits the same instant with a
## 7-digit fractional part, which is the documented .NET round-trip form.
const STAMP_KEYS := ["SavedAtUtc"]

var _harness := TestHarness.new()


func _initialize() -> void:
	print("LIFESTATE — C# / GDScript save interchange")
	print("")

	var csharp_text: String = FileAccess.get_file_as_string(CSHARP_SAVE)
	_harness.check("C# fixture is readable", not csharp_text.is_empty(), CSHARP_SAVE)
	if csharp_text.is_empty():
		_finish()
		return

	var original: Variant = JSON.parse_string(csharp_text)
	_harness.check("C# fixture is valid JSON", typeof(original) == TYPE_DICTIONARY)
	if typeof(original) != TYPE_DICTIONARY:
		_finish()
		return

	# --- Direction A: the port loads a C#-written save ---------------------
	_harness.section("CSharpToGodot")
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	var result: Dictionary = SaveManager.load_game(clock, player, CSHARP_SAVE, FIXED_STAMP)
	_harness.check("port loads the C# save", result["ok"], str(result.get("error", "")))
	if not result["ok"]:
		_finish()
		return
	_harness.eq_int("no offline time when now == SavedAtUtc", result["offline_seconds"], 0)

	# Every persisted key must survive a round trip, in both directions.
	var reserialized: Dictionary = SaveData.to_dict(clock, player, FIXED_STAMP)
	var missing: PackedStringArray = []
	var changed: PackedStringArray = []
	for key in original:
		if not reserialized.has(key):
			missing.append(str(key))
			continue
		if str(key) in STAMP_KEYS or key == "Version":
			continue
		if _canonical(reserialized[key]) != _canonical(original[key]):
			changed.append("%s (%s != %s)" % [key, reserialized[key], original[key]])
	var extra: PackedStringArray = []
	for key in reserialized:
		if not original.has(key) and key != "SecondaryGrade":
			extra.append(str(key))

	_harness.eq_int("every C# key is re-serialized", missing.size(), 0)
	_harness.eq_int("no key changes value on round trip", changed.size(), 0)
	_harness.eq_int("port adds no unexpected keys", extra.size(), 0)
	_harness.eq_int("re-serialized C# save upgrades to Version 8", reserialized["Version"], 8)
	_harness.eq_int("legacy C# save defaults SecondaryGrade to zero", reserialized["SecondaryGrade"], 0)
	for key in missing:
		_harness.check("  missing key %s" % key, false)
	for entry in changed:
		_harness.check("  changed key %s" % entry, false)
	for key in extra:
		_harness.check("  extra key %s" % key, false)

	# JSON has no integer type, so the loader must coerce whole-number fields
	# back to int. If it did not, the port would re-write "1460.0" and the C#
	# build's long-typed JSON binding would reject the file.
	var entry_types: PackedStringArray = []
	for entry in player.events.history:
		if typeof(entry.triggered_day) != TYPE_INT:
			entry_types.append("TriggeredDay is %s" % type_string(typeof(entry.triggered_day)))
		if typeof(entry.resolved_day) != TYPE_INT:
			entry_types.append("ResolvedDay is %s" % type_string(typeof(entry.resolved_day)))
	_harness.eq_int("history days are loaded as real ints, not floats", entry_types.size(), 0)
	for message in entry_types:
		_harness.check("  %s" % message, false)
	_harness.check("timestamp is the same instant as the C# stamp",
		abs(SaveData.parse_utc(reserialized["SavedAtUtc"]) - SaveData.parse_utc(original["SavedAtUtc"])) < 0.001,
		"%s vs %s" % [reserialized["SavedAtUtc"], original["SavedAtUtc"]])

	# Semantic parity, field by field, via an integer-only summary.
	var csharp_summary: Variant = JSON.parse_string(FileAccess.get_file_as_string(CSHARP_SUMMARY))
	_harness.check("C# summary fixture is valid JSON", typeof(csharp_summary) == TYPE_DICTIONARY)
	if typeof(csharp_summary) == TYPE_DICTIONARY:
		var load_errors: PackedStringArray = _compare(clock, player, csharp_summary)
		_harness.eq_int("loaded state matches every C# value", load_errors.size(), 0)
		for entry in load_errors:
			_harness.check("  %s" % entry, false)

	# --- Offline parity: the same C# save, loaded one hour later -------------
	_harness.section("Offline")
	var offline_clock := GameClock.new()
	var offline_player := PlayerState.new(offline_clock)
	var offline: Dictionary = SaveManager.load_game(
		offline_clock, offline_player, CSHARP_SAVE, FIXED_STAMP + 3600.0)
	_harness.check("port loads the C# save with 1 hour of offline time",
		offline["ok"], str(offline.get("error", "")))
	_harness.eq_int("offline seconds are exactly 3600", offline["offline_seconds"], 3600)
	_harness.check("offline time advances the clock",
		offline_clock.day > clock.day, "%d vs %d" % [offline_clock.day, clock.day])
	var offline_summary: Variant = JSON.parse_string(FileAccess.get_file_as_string(GODOT_OFFLINE_SUMMARY))
	_harness.check("offline summary fixture is valid JSON", typeof(offline_summary) == TYPE_DICTIONARY)
	if typeof(offline_summary) == TYPE_DICTIONARY:
		var offline_errors: PackedStringArray = _compare(offline_clock, offline_player, offline_summary)
		_harness.eq_int("offline state still matches the Version 7 reference", offline_errors.size(), 0)
		for entry in offline_errors:
			_harness.check("  %s" % entry, false)

	# --- Version gating and transactional rejection --------------------------
	_harness.section("LegacySave")
	var live_clock := GameClock.new()
	var live_player := PlayerState.new(live_clock)
	live_clock.advance_seconds(600)
	live_player.advance_simulation(2400)
	var day_before: int = live_clock.day
	var money_before: int = live_player.money
	var energy_before: int = live_player.energy
	var rejected: Dictionary = SaveManager.load_game(live_clock, live_player, LEGACY_V1_SAVE, FIXED_STAMP)
	_harness.check("a Version 1 save is rejected", not rejected["ok"], str(rejected.get("error", "")))
	_harness.check("rejection names the unsupported version",
		str(rejected.get("error", "")).to_lower().contains("version"),
		str(rejected.get("error", "")))
	_harness.eq_int("rejected load leaves the clock untouched", live_clock.day, day_before)
	_harness.eq_int("rejected load leaves money untouched", live_player.money, money_before)
	_harness.eq_int("rejected load leaves needs untouched", live_player.energy, energy_before)

	_finish()


## Compares a live state against a reference summary dictionary.
func _compare(clock: GameClock, player: PlayerState, reference: Dictionary) -> PackedStringArray:
	var actual: Dictionary = _summary(clock, player)
	var errors: PackedStringArray = []
	for key in reference:
		if not actual.has(key):
			errors.append("%s is missing (expected %s)" % [key, reference[key]])
		elif _canonical(actual[key]) != _canonical(reference[key]):
			errors.append("%s = %s, expected %s" % [key, actual[key], reference[key]])
	for key in actual:
		if not reference.has(key):
			errors.append("%s was produced but is not in the reference" % key)
	return errors


## Integer-only state summary. Doubles are scaled by 100 so C# and GDScript
## emit byte-identical JSON.
func _summary(clock: GameClock, player: PlayerState) -> Dictionary:
	return {
		"Day": clock.day,
		"Hour": clock.hour,
		"Minute": clock.minute,
		"Age": player.age,
		"Money": player.money,
		"Energy": player.energy,
		"Hunger": player.hunger,
		"Thirst": player.thirst,
		"StudyXP": player.study_xp,
		"IsSleeping": 1 if player.is_sleeping else 0,
		"IsWorking": 1 if player.is_working else 0,
		"IsStudying": 1 if player.is_studying else 0,
		"IsPlaying": 1 if player.is_playing else 0,
		"IsFamilyTime": 1 if player.is_spending_family_time else 0,
		"AwakeAcc": player.get_awake_minutes_accumulator(),
		"SleepingAcc": player.get_sleeping_minutes_accumulator(),
		"HungerAcc": player.get_hunger_minutes_accumulator(),
		"ThirstAcc": player.get_thirst_minutes_accumulator(),
		"WorkAcc": player.get_work_minutes_accumulator(),
		"StudyAcc": player.get_study_minutes_accumulator(),
		"PlayAcc": player.get_play_minutes_accumulator(),
		"FamilyAcc": player.get_family_time_minutes_accumulator(),
		"AcademicsXP": _scaled(player.skills.academics.experience),
		"AcademicsLevel": player.skills.academics.level,
		"EducationStatus": player.education.status,
		"PrimaryGrade": player.education.primary_grade,
		"EducationProgress": player.education.education_progress,
		"SchoolYearStartDay": player.education.school_year_start_day,
		"TotalPlayHours": player.total_play_hours,
		"HistoryCount": player.events.history_count(),
		"PendingEvent": "" if player.events.current_event == null else player.events.current_event.event_id,
		"MotherName": player.family.mother.person_name,
		"MotherAge": player.family.mother.get_age(clock),
		"MotherCloseness": _scaled(player.relationships.mother_relationship.closeness),
		"FatherName": player.family.father.person_name,
		"FatherAge": player.family.father.get_age(clock),
		"FatherCloseness": _scaled(player.relationships.father_relationship.closeness),
		"Intelligence": _scaled(player.attributes.intelligence),
		"Fitness": _scaled(player.attributes.fitness),
		"Social": _scaled(player.attributes.social),
		"Discipline": _scaled(player.attributes.discipline),
		"Creativity": _scaled(player.attributes.creativity),
		"Confidence": _scaled(player.traits.confidence),
		"Curiosity": _scaled(player.traits.curiosity),
		"Patience": _scaled(player.traits.patience),
		"Ambition": _scaled(player.traits.ambition),
		"Empathy": _scaled(player.traits.empathy),
	}


static func _scaled(value: float) -> int:
	return int(round(value * 100.0))


## JSON-tolerant comparison: numbers are compared numerically so 5100.0 == 5100,
## recursively through arrays and dictionaries so nested day fields inside
## EventHistory are compared by value rather than by text.
static func _canonical(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return str(snappedf(float(value), 0.0001))
		TYPE_BOOL:
			return "1" if value else "0"
		TYPE_ARRAY:
			var items: PackedStringArray = []
			for item in value:
				items.append(_canonical(item))
			return "[" + ",".join(items) + "]"
		TYPE_DICTIONARY:
			var keys: Array = (value as Dictionary).keys()
			keys.sort()
			var fields: PackedStringArray = []
			for key in keys:
				fields.append(str(key) + ":" + _canonical(value[key]))
			return "{" + ",".join(fields) + "}"
		_:
			return str(value)


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s" % path)
		return
	file.store_string(text)
	file.close()


func _finish() -> void:
	print("")
	print("==================================================")
	print("INTERCHANGE RESULT: %d passed, %d failed" % [_harness.passed, _harness.failed])
	for failure in _harness.failures:
		print("  - %s" % failure)
	print("==================================================")
	quit(1 if _harness.failed > 0 else 0)
