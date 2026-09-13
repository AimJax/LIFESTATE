extends RefCounted

## Persistence coverage, ported from the C# Persistence / Offline Progression /
## NeedPersist sections, plus explicit C#-save interchange tests.

const TEST_PATH: String = "user://test_save.json"
const FIXED_NOW: float = 1789000000.0  # deterministic UTC seconds


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func run(h: TestHarness) -> void:
	_round_trip(h)
	_schema(h)
	_validation(h)
	_offline(h)
	_large_offline(h)
	_version_compatibility(h)
	_csharp_interchange(h)


static func _populate(clock: GameClock, player: PlayerState) -> void:
	advance_days(clock, 6 * 365 + 3)
	player.enroll_primary_school()
	player.resolve_event_choice(LifeEventCatalog.STAY_QUIET)
	player.start_studying()
	player.advance_simulation(60 * 7)
	player.stop_studying()
	player.start_playing()
	player.advance_simulation(60 * 3 + 25)
	player.stop_playing()
	player.start_family_time()
	player.advance_simulation(60 * 2 + 40)
	player.stop_family_time()
	player.eat(15)
	player.drink(9)


static func _round_trip(h: TestHarness) -> void:
	h.section("Persist-P")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_populate(clock, player)

	var save_result: Dictionary = SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	h.check("Persist-P1 save succeeds", save_result["ok"], save_result["error"])

	var loaded := fresh()
	var loaded_clock: GameClock = loaded[0]
	var loaded_player: PlayerState = loaded[1]
	var load_result: Dictionary = SaveManager.load_game(loaded_clock, loaded_player, TEST_PATH, FIXED_NOW)
	h.check("Persist-P2 load succeeds", load_result["ok"], load_result["error"])
	h.eq_int("Persist-P3 no offline time when clocks match", load_result["offline_seconds"], 0)

	h.eq_int("Persist-P4 clock day round trips", loaded_clock.day, clock.day)
	h.eq_int("Persist-P5 clock hour round trips", loaded_clock.hour, clock.hour)
	h.eq_int("Persist-P6 clock minute round trips", loaded_clock.minute, clock.minute)
	h.eq_int("Persist-P7 money round trips", loaded_player.money, player.money)
	h.eq_int("Persist-P8 energy round trips", loaded_player.energy, player.energy)
	h.eq_int("Persist-P9 hunger round trips", loaded_player.hunger, player.hunger)
	h.eq_int("Persist-P10 thirst round trips", loaded_player.thirst, player.thirst)
	h.eq_int("Persist-P11 StudyXP round trips", loaded_player.study_xp, player.study_xp)
	h.eq_int("Persist-P12 TotalPlayHours round trips", loaded_player.total_play_hours, player.total_play_hours)
	h.eq_int("Persist-P13 awake remainder round trips",
		loaded_player.get_awake_minutes_accumulator(), player.get_awake_minutes_accumulator())
	h.eq_int("Persist-P14 play remainder round trips",
		loaded_player.get_play_minutes_accumulator(), player.get_play_minutes_accumulator())
	h.eq_int("Persist-P15 family remainder round trips",
		loaded_player.get_family_time_minutes_accumulator(), player.get_family_time_minutes_accumulator())
	h.eq_int("Persist-P16 study remainder round trips",
		loaded_player.get_study_minutes_accumulator(), player.get_study_minutes_accumulator())
	h.near_float("Persist-P17 intelligence round trips",
		loaded_player.attributes.intelligence, player.attributes.intelligence)
	h.near_float("Persist-P18 curiosity round trips",
		loaded_player.traits.curiosity, player.traits.curiosity)
	h.eq_int("Persist-P19 Academics experience round trips",
		loaded_player.skills.academics.experience, player.skills.academics.experience)
	h.eq_int("Persist-P20 education status round trips",
		loaded_player.education.status, player.education.status)
	h.eq_int("Persist-P21 education progress round trips",
		loaded_player.education.education_progress, player.education.education_progress)
	h.near_float("Persist-P22 closeness round trips",
		loaded_player.relationships.mother_relationship.closeness,
		player.relationships.mother_relationship.closeness)
	h.eq_string("Persist-P23 mother identity round trips",
		loaded_player.family.mother.id, player.family.mother.id)
	h.eq_string("Persist-P24 father identity round trips",
		loaded_player.family.father.id, player.family.father.id)
	h.eq_int("Persist-P25 event history round trips",
		loaded_player.events.history_count(), player.events.history_count())
	h.eq_string("Persist-P26 history event id round trips",
		loaded_player.events.history[0].event_id, player.events.history[0].event_id)

	# Activities and remainders are preserved, so needs keep decaying identically.
	loaded_player.advance_simulation(30)
	player.advance_simulation(30)
	h.eq_int("Persist-P27 post-load simulation parity (energy)", loaded_player.energy, player.energy)
	h.eq_int("Persist-P28 post-load simulation parity (thirst)", loaded_player.thirst, player.thirst)


static func _schema(h: TestHarness) -> void:
	h.section("Schema-S")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_populate(clock, player)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	var raw: String = FileAccess.get_file_as_string(TEST_PATH)
	var data: Variant = JSON.parse_string(raw)
	h.check("Schema-S1 save file parses as JSON", typeof(data) == TYPE_DICTIONARY)
	var save: Dictionary = data

	h.eq_int("Schema-S2 version is 9", save["Version"], 9)
	var required: PackedStringArray = [
		"Day", "Hour", "Minute", "Money", "Energy", "Hunger", "Thirst", "StudyXP",
		"IsSleeping", "IsWorking", "IsStudying", "IsPlaying", "IsSpendingFamilyTime",
		"WorkMinutesAccumulator", "StudyMinutesAccumulator", "AwakeMinutesAccumulator",
		"SleepingMinutesAccumulator", "HungerMinutesAccumulator", "ThirstMinutesAccumulator",
		"PlayMinutesAccumulator", "FamilyTimeMinutesAccumulator", "AcademicsExperience",
		"EducationStatus", "PrimaryGrade", "EducationProgress", "SchoolYearStartDay",
		"TotalPlayHours", "CurrentEventId", "CurrentEventTriggeredDay", "EventHistory",
		"MotherId", "MotherName", "MotherBirthDay", "FatherId", "FatherName", "FatherBirthDay",
		"MotherRelationshipPersonId", "MotherCloseness", "FatherRelationshipPersonId",
		"FatherCloseness", "Confidence", "Curiosity", "Patience", "Ambition", "Empathy",
		"Intelligence", "Fitness", "Social", "Discipline", "Creativity", "SavedAtUtc",
	]
	var missing: PackedStringArray = []
	for key in required:
		if not save.has(key):
			missing.append(key)
	h.check("Schema-S3 every C# field name is present", missing.is_empty(), ", ".join(missing))

	h.check("Schema-S4 event history keeps C# entry keys",
		typeof(save["EventHistory"]) == TYPE_ARRAY
		and save["EventHistory"].size() == 1
		and save["EventHistory"][0].has("EventId")
		and save["EventHistory"][0].has("ChoiceId")
		and save["EventHistory"][0].has("TriggeredDay")
		and save["EventHistory"][0].has("ResolvedDay"))

	h.check("Schema-S5 SavedAtUtc is a .NET-compatible ISO stamp",
		typeof(save["SavedAtUtc"]) == TYPE_STRING
		and (save["SavedAtUtc"] as String).contains("T")
		and (save["SavedAtUtc"] as String).ends_with("+00:00"),
		str(save["SavedAtUtc"]))

	var parsed: float = SaveData.parse_utc(save["SavedAtUtc"])
	h.near_float("Schema-S6 timestamp parses back to the saved instant", parsed, FIXED_NOW, 1.0)

	h.check("Schema-S7 GUIDs are canonical strings",
		typeof(save["MotherId"]) == TYPE_STRING and (save["MotherId"] as String).length() == 36
		and (save["MotherId"] as String).count("-") == 4)
	h.check("Schema-S8 no pending event is null, not a blank string", save["CurrentEventId"] == null)


static func _validation(h: TestHarness) -> void:
	h.section("Validate-V")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_populate(clock, player)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_PATH)

	# Live state that must survive a rejected load untouched.
	var live := fresh()
	var live_clock: GameClock = live[0]
	var live_player: PlayerState = live[1]
	live_player.money = 12345
	live_player.energy = 77
	live_clock.restore(999, 5, 5)

	var cases: Array = [
		["Energy out of range", {"Energy": 500}],
		["negative money", {"Money": -1}],
		["hour out of range", {"Hour": 24}],
		["minute out of range", {"Minute": 60}],
		["accumulator out of range", {"AwakeMinutesAccumulator": 60}],
		["two activities active", {"IsSleeping": true, "IsWorking": true}],
		["unsupported version", {"Version": 99}],
		["unknown pending event", {"CurrentEventId": "childhood.unknown"}],
		["pending event in the future", {"CurrentEventId": LifeEventCatalog.FIRST_DAY_SCHOOL_ID, "CurrentEventTriggeredDay": 999999}],
		["academics experience over cap", {"AcademicsExperience": 10001}],
		["attribute out of range", {"Intelligence": 150.0}],
		["attribute is not a number", {"Intelligence": "ten"}],
		["trait out of range", {"Confidence": 150.0}],
		["missing parent identity", {"MotherId": ""}],
		["duplicate parent identity", {"FatherId": ""}],
		["blank parent name", {"MotherName": "   "}],
		["relationship cross-reference mismatch", {"FatherRelationshipPersonId": "99999999-9999-4999-8999-999999999999"}],
		["bad closeness", {"MotherCloseness": 500.0}],
		["invalid education state", {"EducationStatus": EducationState.Status.PRIMARY_SCHOOL, "PrimaryGrade": 9}],
		["bad event history choice", {"EventHistory": [{"EventId": LifeEventCatalog.BROKEN_TOY_ID, "ChoiceId": "keep_money", "TriggeredDay": 10, "ResolvedDay": 10}]}],
		["duplicate one-shot history", {"EventHistory": [
			{"EventId": LifeEventCatalog.FOUND_MONEY_ID, "ChoiceId": LifeEventCatalog.KEEP_MONEY, "TriggeredDay": 10, "ResolvedDay": 10},
			{"EventId": LifeEventCatalog.FOUND_MONEY_ID, "ChoiceId": LifeEventCatalog.GIVE_PARENT, "TriggeredDay": 20, "ResolvedDay": 20}]}],
		["missing timestamp", {"SavedAtUtc": null}],
		["malformed timestamp", {"SavedAtUtc": "not-a-date"}],
	]

	for entry in cases:
		var label: String = entry[0]
		var patch: Dictionary = entry[1]
		var data: Dictionary = JSON.parse_string(base_text)
		for key in patch:
			data[key] = patch[key]
		var write: Dictionary = _write(TEST_PATH, JSON.stringify(data))
		var result: Dictionary = SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)
		h.eq_bool("Validate-V rejects %s" % label, result["ok"], false)

	h.eq_int("Validate-V live money untouched by rejected loads", live_player.money, 12345)
	h.eq_int("Validate-V live energy untouched by rejected loads", live_player.energy, 77)
	h.eq_int("Validate-V live clock untouched by rejected loads", live_clock.day, 999)

	h.eq_bool("Validate-V missing file fails cleanly",
		SaveManager.load_game(live_clock, live_player, "user://definitely_missing.json", FIXED_NOW)["ok"], false)

	var garbage: Dictionary = _write(TEST_PATH, "{not json")
	h.check("Validate-V write garbage for next check", garbage["ok"])
	h.eq_bool("Validate-V malformed JSON fails cleanly",
		SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)["ok"], false)

	# Corrupting a JSON array top-level must also fail.
	_write(TEST_PATH, "[1,2,3]")
	h.eq_bool("Validate-V non-object JSON fails cleanly",
		SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)["ok"], false)


static func _offline(h: TestHarness) -> void:
	h.section("Offline-O")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 19 * 365)
	player.apply_for_job(JobCatalog.LABORER_ID)
	player.start_working()
	player.advance_simulation(60 * 3)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var money_at_save: int = player.money
	var day_at_save: int = clock.day

	var loaded := fresh()
	var loaded_clock: GameClock = loaded[0]
	var loaded_player: PlayerState = loaded[1]
	var later: float = FIXED_NOW + 3600.0
	var result: Dictionary = SaveManager.load_game(loaded_clock, loaded_player, TEST_PATH, later)

	h.check("Offline-O1 load succeeds", result["ok"], result["error"])
	h.eq_int("Offline-O2 elapsed seconds measured", result["offline_seconds"], 3600)
	h.eq_int("Offline-O3 elapsed minutes converted", result["offline_minutes"], 14400)
	h.eq_int("Offline-O4 clock advanced by one hour of real time",
		loaded_clock.day, day_at_save + 10)
	h.eq_int("Offline-O5 work earnings applied offline",
		loaded_player.money, money_at_save + 2400)
	h.eq_int("Offline-O6 offline energy drains to the floor", loaded_player.energy, 0)
	h.eq_int("Offline-O7 offline hunger drains to the floor", loaded_player.hunger, 0)
	h.eq_int("Offline-O8 offline thirst drains to the floor", loaded_player.thirst, 0)
	h.eq_int("Offline-O9 activity state persists through a load", loaded_player.is_working, true)

	# A future timestamp yields no offline progress.
	var future := fresh()
	var future_clock: GameClock = future[0]
	var future_player: PlayerState = future[1]
	var future_result: Dictionary = SaveManager.load_game(future_clock, future_player, TEST_PATH, FIXED_NOW - 5000.0)
	h.check("Offline-O10 future timestamp still loads", future_result["ok"], future_result["error"])
	h.eq_int("Offline-O11 future timestamp produces zero offline seconds", future_result["offline_seconds"], 0)
	h.eq_int("Offline-O12 future timestamp leaves money unchanged", future_player.money, money_at_save)

	# Fractional seconds are truncated, not rounded.
	var fractional := fresh()
	var fractional_clock: GameClock = fractional[0]
	var fractional_player: PlayerState = fractional[1]
	var fractional_result: Dictionary = SaveManager.load_game(
		fractional_clock, fractional_player, TEST_PATH, FIXED_NOW + 3599.75)
	h.eq_int("Offline-O13 sub-second remainder is truncated",
		fractional_result["offline_minutes"], 3599 * GameClock.MINUTES_PER_REAL_SECOND)

	# Offline study also advances education and skills.
	var studier := fresh()
	var studier_clock: GameClock = studier[0]
	var studier_player: PlayerState = studier[1]
	advance_days(studier_clock, 6 * 365)
	studier_player.enroll_primary_school()
	studier_player.start_studying()
	SaveManager.save_game(studier_clock, studier_player, TEST_PATH, FIXED_NOW)

	var study_loaded := fresh()
	var study_loaded_clock: GameClock = study_loaded[0]
	var study_loaded_player: PlayerState = study_loaded[1]
	SaveManager.load_game(study_loaded_clock, study_loaded_player, TEST_PATH, FIXED_NOW + 3600.0)
	h.eq_int("Offline-O14 offline study grants StudyXP", study_loaded_player.study_xp, 2400)
	h.eq_int("Offline-O15 offline study grants Academics XP",
		study_loaded_player.skills.academics.experience, 2400)
	h.eq_int("Offline-O16 offline study advances education progress",
		study_loaded_player.education.education_progress, 100)
	h.near_float("Offline-O17 offline study grants intelligence",
		study_loaded_player.attributes.intelligence, 10.0 + 240.0 * 0.05)

	# Overflow is rejected rather than wrapped.
	var overflowing := fresh()
	var overflowing_clock: GameClock = overflowing[0]
	var overflowing_player: PlayerState = overflowing[1]
	advance_days(overflowing_clock, 19 * 365)
	overflowing_player.money = PlayerState.INT32_MAX - 10
	overflowing_player.apply_for_job(JobCatalog.LABORER_ID)
	overflowing_player.start_working()
	SaveManager.save_game(overflowing_clock, overflowing_player, TEST_PATH, FIXED_NOW)
	var overflow_result: Dictionary = SaveManager.load_game(overflowing_clock, overflowing_player, TEST_PATH, FIXED_NOW + 86400.0)
	h.eq_bool("Offline-O18 overflow-prone save is rejected", overflow_result["ok"], false)


static func _large_offline(h: TestHarness) -> void:
	h.section("Offline-L")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	player.start_playing()
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	var loaded := fresh()
	var loaded_clock: GameClock = loaded[0]
	var loaded_player: PlayerState = loaded[1]

	# ~31.7 years of real time. A per-minute loop would need ~66 million
	# iterations; this must return almost immediately.
	var started: int = Time.get_ticks_msec()
	var result: Dictionary = SaveManager.load_game(loaded_clock, loaded_player, TEST_PATH, FIXED_NOW + 1000000000.0)
	var elapsed_ms: int = Time.get_ticks_msec() - started

	h.check("Offline-L1 huge offline load succeeds", result["ok"], result["error"])
	h.check("Offline-L2 huge offline load is O(1), not a loop", elapsed_ms < 2000, "%d ms" % elapsed_ms)
	h.eq_int("Offline-L3 elapsed seconds measured",
		result["offline_seconds"], 1000000000)
	h.eq_int("Offline-L4 clock advanced by the full duration",
		loaded_clock.day, clock.day + 1000000000 * GameClock.MINUTES_PER_REAL_SECOND / 1440)
	h.eq_int("Offline-L5 needs clamped, not corrupted", loaded_player.energy, 0)
	h.eq_int("Offline-L6 thirst clamped, not corrupted", loaded_player.thirst, 0)
	h.check("Offline-L7 play hours accumulated without overflow",
		loaded_player.total_play_hours > 0 and loaded_player.total_play_hours < PlayerState.INT64_MAX)
	h.check("Offline-L8 no grades fabricated without education progress",
		loaded_player.education.status == EducationState.Status.PRIMARY_SCHOOL
		and loaded_player.education.primary_grade == 1)
	h.check("Offline-L9 age advanced sensibly", loaded_player.age > 30, str(loaded_player.age))

	# Extreme duration: a real day of unplayed time is already covered above, but
	# verify the day/overflow guard rejects values past the 32-bit day counter.
	var extreme := fresh()
	var extreme_clock: GameClock = extreme[0]
	var extreme_player: PlayerState = extreme[1]
	var extreme_result: Dictionary = SaveManager.load_game(
		extreme_clock, extreme_player, TEST_PATH, FIXED_NOW + 1.0e15)
	h.eq_bool("Offline-L10 absurd duration rejected instead of overflowing", extreme_result["ok"], false)


static func _version_compatibility(h: TestHarness) -> void:
	h.section("Legacy-LV")

	for version in [2, 3, 4, 5, 6, 7]:
		var data: Dictionary = _legacy_fixture(version)
		_write(TEST_PATH, JSON.stringify(data))

		var pair := fresh()
		var clock: GameClock = pair[0]
		var player: PlayerState = pair[1]
		var result: Dictionary = SaveManager.load_game(clock, player, TEST_PATH, FIXED_NOW)

		h.eq_bool("Legacy-LV version %d loads" % version, result["ok"], true)
		h.eq_int("Legacy-LV version %d restores money" % version, player.money, 4242)
		h.eq_int("Legacy-LV version %d restores needs" % version, player.energy, 90)

		if version >= 4:
			h.near_float("Legacy-LV version %d restores traits" % version, player.traits.confidence, 61.5)
		else:
			h.near_float("Legacy-LV version %d defaults traits to 50" % version, player.traits.confidence, 50.0)

		if version >= 3:
			h.eq_int("Legacy-LV version %d restores education" % version,
				player.education.status, EducationState.Status.PRIMARY_SCHOOL)
		else:
			h.eq_int("Legacy-LV version %d defaults education" % version,
				player.education.status, EducationState.Status.NOT_ENROLLED)

		if version >= 6:
			h.eq_string("Legacy-LV version %d restores parent identity" % version,
				player.family.mother.id, "11111111-1111-4111-8111-111111111111")
			h.near_float("Legacy-LV version %d restores closeness" % version,
				player.relationships.mother_relationship.closeness, 66.0)
		else:
			h.check("Legacy-LV version %d keeps generated parents" % version,
				Uuid.is_valid(player.family.mother.id)
				and player.family.mother.id != "11111111-1111-4111-8111-111111111111")
			h.near_float("Legacy-LV version %d defaults closeness" % version,
				player.relationships.mother_relationship.closeness, 50.0)

		if version >= 7:
			h.eq_int("Legacy-LV version %d restores TotalPlayHours" % version, player.total_play_hours, 12)
			h.eq_int("Legacy-LV version %d restores history" % version, player.events.history_count(), 1)
		else:
			h.eq_int("Legacy-LV version %d defaults TotalPlayHours" % version, player.total_play_hours, 0)
			h.eq_int("Legacy-LV version %d defaults history" % version, player.events.history_count(), 0)


static func _legacy_fixture(version: int) -> Dictionary:
	var data: Dictionary = {
		"Version": version,
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
		"SavedAtUtc": SaveData.format_utc(FIXED_NOW),
	}

	if version >= 3:
		data["EducationStatus"] = EducationState.Status.PRIMARY_SCHOOL
		data["PrimaryGrade"] = 3
		data["EducationProgress"] = 45
		data["SchoolYearStartDay"] = 1460

	if version >= 4:
		data["Confidence"] = 61.5
		data["Curiosity"] = 52.0
		data["Patience"] = 53.0
		data["Ambition"] = 54.0
		data["Empathy"] = 55.0

	if version >= 6:
		data["MotherId"] = "11111111-1111-4111-8111-111111111111"
		data["MotherName"] = "Mother"
		data["MotherBirthDay"] = -10220
		data["FatherId"] = "22222222-2222-4222-8222-222222222222"
		data["FatherName"] = "Father"
		data["FatherBirthDay"] = -10950
		data["MotherRelationshipPersonId"] = "11111111-1111-4111-8111-111111111111"
		data["MotherCloseness"] = 66.0
		data["FatherRelationshipPersonId"] = "22222222-2222-4222-8222-222222222222"
		data["FatherCloseness"] = 44.0

	if version >= 7:
		data["TotalPlayHours"] = 12
		data["CurrentEventId"] = null
		data["CurrentEventTriggeredDay"] = 0
		data["EventHistory"] = [
			{"EventId": LifeEventCatalog.BROKEN_TOY_ID, "ChoiceId": LifeEventCatalog.TRY_FIX,
			 "TriggeredDay": 1500, "ResolvedDay": 1500},
		]

	if version >= 8:
		data["SecondaryGrade"] = 0

	return data


static func _csharp_interchange(h: TestHarness) -> void:
	h.section("Interop-X")

	# A save exactly as System.Text.Json writes it (PascalCase keys, GUID strings,
	# 7-digit fractional UTC stamp), including a pending event and history.
	var stamp: String = SaveData.format_utc(FIXED_NOW)
	var json: String = """{
"Version":7,"Day":2560,"Hour":8,"Minute":15,"Money":1500,"Energy":64,"Hunger":71,"Thirst":58,"StudyXP":90,
"IsSleeping":false,"IsWorking":false,"IsStudying":true,"IsPlaying":false,"IsSpendingFamilyTime":false,
"WorkMinutesAccumulator":0,"StudyMinutesAccumulator":42,"AwakeMinutesAccumulator":17,"SleepingMinutesAccumulator":0,
"HungerMinutesAccumulator":9,"ThirstMinutesAccumulator":3,"PlayMinutesAccumulator":50,"FamilyTimeMinutesAccumulator":0,
"AcademicsExperience":450,"EducationStatus":1,"PrimaryGrade":2,"EducationProgress":63,"SchoolYearStartDay":2190,
"TotalPlayHours":37,"CurrentEventId":"childhood.first_day_school","CurrentEventTriggeredDay":2190,
"EventHistory":[{"EventId":"childhood.broken_toy","ChoiceId":"try_fix","TriggeredDay":1500,"ResolvedDay":1500}],
"MotherId":"3f2504e0-4f89-41d3-9a0c-0305e82c3301","MotherName":"Mother","MotherBirthDay":-10220,
"FatherId":"9c1f2a44-6b5e-41f7-8d21-77aa0c4b9e10","FatherName":"Father","FatherBirthDay":-10950,
"MotherRelationshipPersonId":"3f2504e0-4f89-41d3-9a0c-0305e82c3301","MotherCloseness":58.5,
"FatherRelationshipPersonId":"9c1f2a44-6b5e-41f7-8d21-77aa0c4b9e10","FatherCloseness":47.25,
"Confidence":62.5,"Curiosity":55.25,"Patience":51.0,"Ambition":49.75,"Empathy":53.5,
"Intelligence":18.75,"Fitness":12.5,"Social":14.25,"Discipline":10.0,"Creativity":16.0,
"SavedAtUtc":"%s"}""" % stamp

	_write(TEST_PATH, json)

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	var result: Dictionary = SaveManager.load_game(clock, player, TEST_PATH, FIXED_NOW)

	h.check("Interop-X1 C#-formatted save loads", result["ok"], result["error"])
	h.eq_int("Interop-X2 clock restored", clock.day * 10000 + clock.hour * 100 + clock.minute, 2560 * 10000 + 815)
	h.eq_int("Interop-X3 money restored", player.money, 1500)
	h.eq_int("Interop-X4 study flag restored", 1 if player.is_studying else 0, 1)
	h.eq_int("Interop-X5 TotalPlayHours restored", player.total_play_hours, 37)
	h.eq_int("Interop-X6 education restored", player.education.primary_grade, 2)
	h.eq_int("Interop-X7 education progress restored", player.education.education_progress, 63)
	h.near_float("Interop-X8 attributes restored", player.attributes.intelligence, 18.75)
	h.near_float("Interop-X9 traits restored", player.traits.empathy, 53.5)
	h.eq_string("Interop-X10 parent identity restored", player.family.mother.id, "3f2504e0-4f89-41d3-9a0c-0305e82c3301")
	h.near_float("Interop-X11 closeness restored", player.relationships.father_relationship.closeness, 47.25)
	h.eq_int("Interop-X12 history restored", player.events.history_count(), 1)
	h.check("Interop-X13 pending event restored",
		player.events.current_event != null
		and player.events.current_event.event_id == LifeEventCatalog.FIRST_DAY_SCHOOL_ID)
	h.eq_int("Interop-X14 pending trigger day restored", player.events.current_event.triggered_day, 2190)
	h.eq_int("Interop-X15 study remainder restored", player.get_study_minutes_accumulator(), 42)
	h.eq_int("Interop-X16 play remainder restored", player.get_play_minutes_accumulator(), 50)

	# Round trip back out: our own output must be readable again.
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var second := fresh()
	var second_clock: GameClock = second[0]
	var second_player: PlayerState = second[1]
	var second_result: Dictionary = SaveManager.load_game(second_clock, second_player, TEST_PATH, FIXED_NOW)
	h.check("Interop-X17 our own output reloads", second_result["ok"], second_result["error"])
	h.eq_string("Interop-X18 identity preserved through a resave", second_player.family.father.id,
		player.family.father.id)
	h.eq_int("Interop-X19 values preserved through a resave", second_player.total_play_hours, 37)

	# A C# 2.0-style save with no newer fields must still load.
	var legacy: Dictionary = {
		"Version": 2, "Day": 100, "Hour": 1, "Minute": 2, "Money": 500,
		"Energy": 50, "Hunger": 50, "Thirst": 50, "StudyXP": 0,
		"IsSleeping": false, "IsWorking": false, "IsStudying": false,
		"IsPlaying": false, "IsSpendingFamilyTime": false,
		"SavedAtUtc": SaveData.format_utc(FIXED_NOW),
	}
	_write(TEST_PATH, JSON.stringify(legacy))
	var legacy_pair := fresh()
	var legacy_result: Dictionary = SaveManager.load_game(legacy_pair[0], legacy_pair[1], TEST_PATH, FIXED_NOW)
	h.check("Interop-X20 sparse legacy save loads", legacy_result["ok"], legacy_result["error"])
	h.eq_int("Interop-X21 sparse legacy money restored", legacy_pair[1].money, 500)

	# Timestamp parser coverage.
	h.near_float("Interop-X22 parses Z suffix", SaveData.parse_utc("2026-09-12T17:19:03Z"),
		SaveData.parse_utc("2026-09-12T17:19:03+00:00"), 0.001)
	h.near_float("Interop-X23 applies a positive offset",
		SaveData.parse_utc("2026-09-12T19:19:03+02:00"),
		SaveData.parse_utc("2026-09-12T17:19:03+00:00"), 0.001)
	h.near_float("Interop-X24 applies a negative offset",
		SaveData.parse_utc("2026-09-12T12:19:03-05:00"),
		SaveData.parse_utc("2026-09-12T17:19:03+00:00"), 0.001)
	h.check("Interop-X25 rejects DateTimeOffset.MinValue",
		is_nan(SaveData.parse_utc("0001-01-01T00:00:00+00:00")))
	h.check("Interop-X26 rejects garbage", is_nan(SaveData.parse_utc("banana")))
	h.check("Interop-X27 rejects null", is_nan(SaveData.parse_utc(null)))
	h.check("Interop-X28 fractional seconds parsed",
		not is_nan(SaveData.parse_utc("2026-09-12T17:19:03.4567890+00:00")))


static func _write(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(text)
	file.close()
	return {"ok": true}
