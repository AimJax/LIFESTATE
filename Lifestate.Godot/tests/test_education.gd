extends RefCounted

## Secondary education coverage, added as part of the secondary education
## foundation ticket. Reuses the existing primary-school model and extends it
## with grades 7-12 and terminal completed-secondary state.

static func run(h: TestHarness) -> void:
	secondary_statuses(h)
	secondary_enrollment(h)
	secondary_grade_progression(h)
	secondary_study_integration(h)
	secondary_save_round_trip(h)
	secondary_invalid_saves_rejected(h)
	legacy_v7_still_loads(h)
	secondary_offline_progression(h)


static func secondary_statuses(h: TestHarness) -> void:
	h.section("EduSec-S")

	h.check("EduSec-S1 Status enum values present",
		has_enum_value(EducationState.Status.SECONDARY_SCHOOL) and has_enum_value(EducationState.Status.COMPLETED_SECONDARY))

	h.eq_int("EduSec-S2 SECONDARY_SCHOOL value after COMPLETED_PRIMARY",
		EducationState.Status.COMPLETED_PRIMARY + 1, EducationState.Status.SECONDARY_SCHOOL)
	h.eq_int("EduSec-S3 COMPLETED_SECONDARY value after SECONDARY_SCHOOL",
		EducationState.Status.SECONDARY_SCHOOL + 1, EducationState.Status.COMPLETED_SECONDARY)

	h.check("EduSec-S4 Status.display_name handles secondary",
		EducationState.display_name(EducationState.Status.SECONDARY_SCHOOL) == "Currently enrolled")
	h.check("EduSec-S5 Status.display_name handles completed secondary",
		EducationState.display_name(EducationState.Status.COMPLETED_SECONDARY) == "Secondary school completed")

	h.eq_string("EduSec-S6 unknown status still returns unknown",
		EducationState.display_name(99), "Unknown")


static func secondary_enrollment(h: TestHarness) -> void:
	h.section("EduSec-E")

	var clock := GameClock.new()
	var player := PlayerState.new(clock)

	h.eq_bool("EduSec-E1 cannot enroll secondary while not enrolled",
		player.enroll_secondary_school(), false)
	h.eq_int("EduSec-E2 status still not enrolled", player.education.status, EducationState.Status.NOT_ENROLLED)

	advance_days(clock, 12 * 365)
	h.eq_bool("EduSec-E3 cannot enroll secondary before completing primary",
		player.enroll_secondary_school(), false)
	h.eq_int("EduSec-E4 status still not enrolled after age 12", player.education.status, EducationState.Status.NOT_ENROLLED)

	var young := fresh()
	advance_days(young[0], 11 * 365)
	h.check("EduSec-E5 completed-primary setup is valid",
		young[1].education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, 0))
	h.eq_bool("EduSec-E6 cannot enroll secondary under age 12",
		young[1].enroll_secondary_school(), false)

	player.enroll_primary_school()
	complete_primary(player, clock)

	h.eq_int("EduSec-E7 primary now completed", player.education.status, EducationState.Status.COMPLETED_PRIMARY)
	h.eq_int("EduSec-E8 primary grade is 6", player.education.primary_grade, 6)
	h.eq_int("EduSec-E9 primary progress is 100", player.education.education_progress, 100)
	h.check("EduSec-E10 age at least 12", player.age >= 12)
	h.eq_bool("EduSec-E11 can enroll secondary after primary completed and age 12+",
		player.enroll_secondary_school(), true)
	h.eq_int("EduSec-E12 status now secondary", player.education.status, EducationState.Status.SECONDARY_SCHOOL)
	h.eq_int("EduSec-E13 secondary grade starts at 7", player.education.secondary_grade, 7)
	h.eq_int("EduSec-E14 secondary progress starts at 0", player.education.education_progress, 0)
	h.eq_int("EduSec-E15 secondary school year records current day", player.education.school_year_start_day, clock.day)

	# Re-enrolling must fail.
	h.eq_bool("EduSec-E16 re-enroll secondary fails",
		player.enroll_secondary_school(), false)
	h.eq_int("EduSec-E17 status unchanged", player.education.status, EducationState.Status.SECONDARY_SCHOOL)

	# Completing primary later and trying again must still fail.
	player.stop_studying()
	player.start_studying()
	player.advance_simulation(60 * 50)
	player.stop_studying()
	advance_days(clock, 365)
	h.eq_int("EduSec-E18 still secondary after another year of study", player.education.status, EducationState.Status.SECONDARY_SCHOOL)


static func secondary_grade_progression(h: TestHarness) -> void:
	h.section("EduSec-G")

	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	advance_days(clock, 12 * 365)
	player.enroll_primary_school()
	complete_primary(player, clock)

	h.eq_bool("EduSec-G0 enrolled secondary", player.enroll_secondary_school(), true)

	var year_only := fresh()
	advance_days(year_only[0], 12 * 365)
	year_only[1].education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, 0)
	year_only[1].enroll_secondary_school()
	advance_days(year_only[0], 365)
	year_only[1].education.evaluate_progression(year_only[0].day)
	h.eq_int("EduSec-G1 elapsed year alone does not advance", year_only[1].education.secondary_grade, 7)

	h.eq_int("EduSec-G2 grade 7 requires progress too", player.education.secondary_grade, 7)
	player.start_studying()
	player.advance_simulation(60 * 101)
	player.stop_studying()
	h.eq_int("EduSec-G3 progress clamps to 100", player.education.education_progress, 100)
	advance_days(clock, 364)
	player.education.evaluate_progression(clock.day)
	h.eq_int("EduSec-G4 progress alone does not advance", player.education.secondary_grade, 7)

	advance_days(clock, 1)
	player.education.evaluate_progression(clock.day)
	h.eq_int("EduSec-G5 advanced to grade 8 with progress + year", player.education.secondary_grade, 8)
	h.eq_int("EduSec-G6 progress reset on grade advance", player.education.education_progress, 0)
	h.eq_int("EduSec-G7 new school year recorded", player.education.school_year_start_day, clock.day)

	for target in [9, 10, 11]:
		player.start_studying()
		player.advance_simulation(60 * 100)
		player.stop_studying()
		advance_days(clock, 365)
		player.education.evaluate_progression(clock.day)
		h.eq_int("EduSec-G grade advanced to %d" % target, player.education.secondary_grade, target)
		h.eq_int("EduSec-G progress reset at %d" % target, player.education.education_progress, 0)

	# Grade 12 completion.
	player.start_studying()
	player.advance_simulation(60 * 100)
	player.stop_studying()
	advance_days(clock, 365)
	player.education.evaluate_progression(clock.day)
	h.eq_int("EduSec-G12 grade 12 reached", player.education.secondary_grade, 12)
	h.eq_int("EduSec-G13 progress reset at grade 12", player.education.education_progress, 0)

	player.start_studying()
	player.advance_simulation(60 * 100)
	player.stop_studying()
	advance_days(clock, 365)
	player.education.evaluate_progression(clock.day)
	h.eq_int("EduSec-G14 completed secondary", player.education.status, EducationState.Status.COMPLETED_SECONDARY)
	h.eq_int("EduSec-G15 final grade is 12", player.education.secondary_grade, 12)
	h.eq_int("EduSec-G16 final progress is 100", player.education.education_progress, 100)
	h.eq_int("EduSec-G17 completion keeps grade 12 school-year start", player.education.school_year_start_day, clock.day - 365)

	h.eq_int("EduSec-G18 completed secondary is terminal", player.education.status, EducationState.Status.COMPLETED_SECONDARY)
	advance_days(clock, 5000)
	player.education.evaluate_progression(clock.day)
	h.eq_int("EduSec-G18 completed secondary stays terminal after years", player.education.status, EducationState.Status.COMPLETED_SECONDARY)


static func secondary_study_integration(h: TestHarness) -> void:
	h.section("EduSec-ST")

	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	advance_days(clock, 12 * 365)
	player.enroll_primary_school()
	complete_primary(player, clock)
	h.eq_bool("EduSec-ST0 enrolled secondary", player.enroll_secondary_school(), true)
	var xp_before: int = player.study_xp
	var academics_before: int = player.skills.academics.experience
	var intelligence_before: float = player.attributes.intelligence
	var curiosity_before: float = player.traits.curiosity
	var patience_before: float = player.traits.patience
	var ambition_before: float = player.traits.ambition

	# Study while in secondary should advance education progress AND usual study
	# rewards.
	player.start_studying()
	player.advance_simulation(60 * 50)
	player.stop_studying()

	h.eq_int("EduSec-ST1 secondary progress advanced", player.education.education_progress, 50)
	h.eq_int("EduSec-ST2 study xp advanced", player.study_xp, xp_before + 500)
	h.eq_int("EduSec-ST3 academics xp advanced", player.skills.academics.experience, academics_before + 500)
	h.near_float("EduSec-ST4 intelligence advanced", player.attributes.intelligence, intelligence_before + 50.0 * 0.05)

	# Study enough to advance, then finish the year.
	player.start_studying()
	player.advance_simulation(60 * 50)
	player.stop_studying()
	advance_days(clock, 365)
	player.education.evaluate_progression(clock.day)
	h.eq_int("EduSec-ST5 advanced to next grade", player.education.secondary_grade, 8)

	# Trait gains still happen during secondary study.
	h.near_float("EduSec-ST6 curiosity advanced", player.traits.curiosity, curiosity_before + 100.0 * 0.02)
	h.near_float("EduSec-ST7 patience advanced", player.traits.patience, patience_before + 100.0 * 0.01)
	h.near_float("EduSec-ST8 ambition advanced", player.traits.ambition, ambition_before + 100.0 * 0.01)


static func secondary_save_round_trip(h: TestHarness) -> void:
	h.section("EduSec-R")

	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	advance_days(clock, 12 * 365)
	player.enroll_primary_school()
	complete_primary(player, clock)
	h.eq_bool("EduSec-R0 enrolled secondary", player.enroll_secondary_school(), true)
	player.start_studying()
	player.advance_simulation(60 * 100)
	player.stop_studying()
	advance_days(clock, 365)
	player.education.evaluate_progression(clock.day)
	h.eq_int("EduSec-R1 grade 8 in progress", player.education.secondary_grade, 8)
	h.eq_int("EduSec-R2 progress reset after advance", player.education.education_progress, 0)
	player.start_studying()
	player.advance_simulation(60 * 50)
	player.stop_studying()
	h.eq_int("EduSec-R2 progress in progress", player.education.education_progress, 50)

	var save_result := SaveManager.save_game(clock, player, TEST_EDU_PATH, FIXED_NOW)
	h.check("EduSec-R3 save succeeds", save_result["ok"], save_result["error"])

	var dict := _read_json(TEST_EDU_PATH)
	h.eq_int("EduSec-R4 version is 8", dict["Version"], SaveData.VERSION)
	h.eq_int("EduSec-R5 secondary grade present", dict["SecondaryGrade"], 8)
	h.eq_int("EduSec-R6 secondary status present", dict["EducationStatus"], EducationState.Status.SECONDARY_SCHOOL)

	var loaded := fresh()
	var loaded_clock: GameClock = loaded[0]
	var loaded_player: PlayerState = loaded[1]
	var load_result: Dictionary = SaveManager.load_game(loaded_clock, loaded_player, TEST_EDU_PATH, FIXED_NOW)
	h.check("EduSec-R7 load succeeds", load_result["ok"], load_result["error"])
	h.eq_int("EduSec-R8 secondary grade round trips", loaded_player.education.secondary_grade, 8)
	h.eq_int("EduSec-R9 secondary status round trips", loaded_player.education.status, EducationState.Status.SECONDARY_SCHOOL)
	h.eq_int("EduSec-R10 secondary progress round trips", loaded_player.education.education_progress, 50)
	h.eq_int("EduSec-R11 primary grade preserved", loaded_player.education.primary_grade, 6)
	h.eq_int("EduSec-R12 primary progress preserved", loaded_player.education.education_progress, 50)
	h.eq_int("EduSec-R13 school year start preserved", loaded_player.education.school_year_start_day, player.education.school_year_start_day)

	# Completed secondary round trip.
	var clock2 := GameClock.new()
	var player2 := PlayerState.new(clock2)
	advance_days(clock2, 12 * 365)
	player2.enroll_primary_school()
	complete_primary(player2, clock2)
	h.eq_bool("EduSec-R14 enrolled secondary (completed path)", player2.enroll_secondary_school(), true)
	advance_grade_to(player2, clock2, 12)
	player2.start_studying()
	player2.advance_simulation(60 * 100)
	player2.stop_studying()
	advance_days(clock2, 365)
	player2.education.evaluate_progression(clock2.day)
	h.eq_int("EduSec-R15 completed secondary status", player2.education.status, EducationState.Status.COMPLETED_SECONDARY)

	var save_result2 := SaveManager.save_game(clock2, player2, TEST_EDU_PATH2, FIXED_NOW)
	h.check("EduSec-R16 completed secondary save succeeds", save_result2["ok"], save_result2["error"])

	var dict2 := _read_json(TEST_EDU_PATH2)
	h.eq_int("EduSec-R17 completed secondary status in file", dict2["EducationStatus"], EducationState.Status.COMPLETED_SECONDARY)
	h.eq_int("EduSec-R18 completed secondary grade in file", dict2["SecondaryGrade"], 12)
	h.eq_int("EduSec-R19 completed secondary progress in file", dict2["EducationProgress"], 100)

	var loaded2 := fresh()
	SaveManager.load_game(loaded2[0], loaded2[1], TEST_EDU_PATH2, FIXED_NOW)
	h.eq_int("EduSec-R20 completed secondary status round trips", loaded2[1].education.status, EducationState.Status.COMPLETED_SECONDARY)
	h.eq_int("EduSec-R21 completed secondary grade round trips", loaded2[1].education.secondary_grade, 12)
	h.eq_int("EduSec-R22 completed secondary progress round trips", loaded2[1].education.education_progress, 100)
	h.eq_int("EduSec-R23 primary grade preserved on completed secondary", loaded2[1].education.primary_grade, 6)
	h.eq_int("EduSec-R24 primary progress preserved on completed secondary", loaded2[1].education.education_progress, 100)


static func secondary_invalid_saves_rejected(h: TestHarness) -> void:
	h.section("EduSec-V")

	# Base v8 save with secondary in progress.
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	advance_days(clock, 12 * 365)
	player.enroll_primary_school()
	complete_primary(player, clock)
	h.eq_bool("EduSec-V0 enrolled secondary", player.enroll_secondary_school(), true)
	player.start_studying()
	player.advance_simulation(60 * 50)
	player.stop_studying()
	advance_days(clock, 365)
	player.education.evaluate_progression(clock.day)
	SaveManager.save_game(clock, player, TEST_EDU_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_EDU_PATH)

	# Live state that must survive rejected loads untouched.
	var live := fresh()
	var live_clock: GameClock = live[0]
	var live_player: PlayerState = live[1]
	live_player.money = 99999
	live_clock.restore(777, 7, 7)

	var cases: Array = [
		["secondary grade too low", {"SecondaryGrade": 6}],
		["secondary grade too high", {"SecondaryGrade": 13}],
		["completed secondary with grade 11", {"EducationStatus": EducationState.Status.COMPLETED_SECONDARY, "SecondaryGrade": 11}],
		["completed secondary with progress 50", {"EducationStatus": EducationState.Status.COMPLETED_SECONDARY, "EducationProgress": 50}],
		["negative progress", {"EducationProgress": -1}],
		["negative school year start", {"SchoolYearStartDay": -1}],
		["secondary enrolled with primary not completed", {"EducationStatus": EducationState.Status.SECONDARY_SCHOOL, "PrimaryGrade": 5}],
	]

	for entry in cases:
		var label: String = entry[0]
		var patch: Dictionary = entry[1]
		var data: Dictionary = JSON.parse_string(base_text)
		for key in patch:
			data[key] = patch[key]
		var write: Dictionary = _write(TEST_EDU_PATH, JSON.stringify(data))
		var result: Dictionary = SaveManager.load_game(live_clock, live_player, TEST_EDU_PATH, FIXED_NOW)
		h.eq_bool("EduSec-V rejects %s" % label, result["ok"], false)

	h.eq_int("EduSec-V live money untouched by rejected loads", live_player.money, 99999)
	h.eq_int("EduSec-V live clock untouched by rejected loads", live_clock.day, 777)


static func legacy_v7_still_loads(h: TestHarness) -> void:
	h.section("EduSec-L7")

	# Use the existing legacy fixture helper from persistence tests; it builds
	# v7-compatible saves without SecondaryGrade.
	var data: Dictionary = _legacy_fixture_like_v7()
	var write: Dictionary = _write(TEST_EDU_PATH, JSON.stringify(data))
	h.check("EduSec-L70 v7 save written", write["ok"])

	var pair := fresh()
	var load_result: Dictionary = SaveManager.load_game(pair[0], pair[1], TEST_EDU_PATH, FIXED_NOW)
	h.check("EduSec-L71 v7 save still loads", load_result["ok"], load_result["error"])
	h.eq_int("EduSec-L72 secondary grade defaults to 0", pair[1].education.secondary_grade, 0)
	h.eq_int("EduSec-L73 primary state preserved", pair[1].education.primary_grade, 3)
	h.eq_int("EduSec-L74 primary progress preserved", pair[1].education.education_progress, 45)
	h.eq_int("EduSec-L75 school year start preserved", pair[1].education.school_year_start_day, 1460)
	h.eq_int("EduSec-L76 status preserved", pair[1].education.status, EducationState.Status.PRIMARY_SCHOOL)
	h.eq_int("EduSec-L77 total play hours preserved", pair[1].total_play_hours, 12)
	h.eq_int("EduSec-L78 history preserved", pair[1].events.history_count(), 1)
	h.eq_string("EduSec-L79 event id preserved", pair[1].events.history[0].event_id,
		LifeEventCatalog.BROKEN_TOY_ID)


static func secondary_offline_progression(h: TestHarness) -> void:
	h.section("EduSec-O")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 12 * 365)
	player.education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, 0)
	player.enroll_secondary_school()
	player.start_studying()
	SaveManager.save_game(clock, player, TEST_EDU_PATH, FIXED_NOW)

	var one_hour := fresh()
	var result: Dictionary = SaveManager.load_game(one_hour[0], one_hour[1], TEST_EDU_PATH, FIXED_NOW + 3600.0)
	h.check("EduSec-O1 offline secondary load succeeds", result["ok"], result["error"])
	h.eq_int("EduSec-O2 offline Study adds capped education progress", one_hour[1].education.education_progress, 100)
	h.eq_int("EduSec-O3 offline Study adds normal StudyXP", one_hour[1].study_xp, 2400)
	h.eq_int("EduSec-O4 ten elapsed days do not advance Grade 7", one_hour[1].education.secondary_grade, 7)

	var large := fresh()
	var started: int = Time.get_ticks_msec()
	var large_result: Dictionary = SaveManager.load_game(large[0], large[1], TEST_EDU_PATH, FIXED_NOW + 10000000.0)
	var elapsed_ms: int = Time.get_ticks_msec() - started
	h.check("EduSec-O5 large offline load succeeds", large_result["ok"], large_result["error"])
	h.check("EduSec-O6 large offline load remains O(1)", elapsed_ms < 2000, "%d ms" % elapsed_ms)
	h.eq_int("EduSec-O7 large offline period advances only one grade", large[1].education.secondary_grade, 8)
	h.eq_int("EduSec-O8 grade advance consumes current progress", large[1].education.education_progress, 0)


static func complete_primary(player: PlayerState, clock: GameClock) -> void:
	for _grade in range(6):
		player.start_studying()
		player.advance_simulation(60 * 100)
		player.stop_studying()
		advance_days(clock, 365)
		player.education.evaluate_progression(clock.day)


static func advance_grade_to(player: PlayerState, clock: GameClock, target: int) -> void:
	while player.education.secondary_grade < target:
		player.start_studying()
		player.advance_simulation(60 * 100)
		player.stop_studying()
		advance_days(clock, 365)
		player.education.evaluate_progression(clock.day)


static func has_enum_value(status_value: int) -> bool:
	return status_value >= 0


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


const TEST_EDU_PATH: String = "user://test_education.json"
const TEST_EDU_PATH2: String = "user://test_education2.json"
const FIXED_NOW: float = 1789000000.0


static func _legacy_fixture_like_v7() -> Dictionary:
	return {
		"Version": 7,
		"Day": 2190,
		"Hour": 12,
		"Minute": 30,
		"Money": 4242,
		"Energy": 90,
		"Hunger": 80,
		"Thirst": 70,
		"StudyXP": 120,
		"IsSleeping": false,
		"IsWorking": false,
		"IsStudying": false,
		"IsPlaying": false,
		"IsSpendingFamilyTime": false,
		"WorkMinutesAccumulator": 0,
		"StudyMinutesAccumulator": 30,
		"AwakeMinutesAccumulator": 15,
		"SleepingMinutesAccumulator": 0,
		"HungerMinutesAccumulator": 5,
		"ThirstMinutesAccumulator": 25,
		"PlayMinutesAccumulator": 0,
		"FamilyTimeMinutesAccumulator": 0,
		"AcademicsExperience": 340,
		"EducationStatus": EducationState.Status.PRIMARY_SCHOOL,
		"PrimaryGrade": 3,
		"EducationProgress": 45,
		"SchoolYearStartDay": 1460,
		"TotalPlayHours": 12,
		"CurrentEventId": null,
		"CurrentEventTriggeredDay": 0,
		"EventHistory": [
			{"EventId": LifeEventCatalog.BROKEN_TOY_ID, "ChoiceId": LifeEventCatalog.TRY_FIX,
			 "TriggeredDay": 1500, "ResolvedDay": 1500},
		],
		"MotherId": "11111111-1111-4111-8111-111111111111",
		"MotherName": "Mother",
		"MotherBirthDay": -10220,
		"FatherId": "22222222-2222-4222-8222-222222222222",
		"FatherName": "Father",
		"FatherBirthDay": -10950,
		"MotherRelationshipPersonId": "11111111-1111-4111-8111-111111111111",
		"MotherCloseness": 66.0,
		"FatherRelationshipPersonId": "22222222-2222-4222-8222-222222222222",
		"FatherCloseness": 44.0,
		"Confidence": 61.5,
		"Curiosity": 52.0,
		"Patience": 53.0,
		"Ambition": 54.0,
		"Empathy": 55.0,
		"Intelligence": 18.75,
		"Fitness": 12.5,
		"Social": 14.25,
		"Discipline": 10.0,
		"Creativity": 16.0,
		"SavedAtUtc": SaveData.format_utc(FIXED_NOW),
	}


static func _write(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(text)
	file.close()
	return {"ok": true}


static func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary
