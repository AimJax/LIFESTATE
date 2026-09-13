extends RefCounted

## Career foundation coverage: catalog, deterministic hiring, job wages for the
## Work activity, offline integration and Save Version 9 persistence including
## the legacy pre-v9 migration rule.

const TEST_PATH: String = "user://test_career_save.json"
const FIXED_NOW: float = 1790000000.0


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func run(h: TestHarness) -> void:
	_catalog(h)
	_default_state(h)
	_hiring(h)
	_one_job_and_quit(h)
	_work_wages(h)
	_work_partial_hours(h)
	_offline_wages(h)
	_save_v9_round_trip(h)
	_save_v9_invalid(h)
	_legacy_migration(h)


static func _catalog(h: TestHarness) -> void:
	h.section("Career-C")
	h.eq_int("Career-C1 exactly four jobs exist", JobCatalog.definitions().size(), 4)

	var ids: Array = []
	for definition in JobCatalog.definitions():
		ids.append(definition.id)
	var unique: Dictionary = {}
	for id in ids:
		unique[id] = true
	h.check("Career-C2 job ids are unique", ids.size() == 4 and unique.size() == 4, str(ids))
	h.check("Career-C3 ids are the required stable strings",
		JobCatalog.is_known_job("laborer") and JobCatalog.is_known_job("retail_worker")
		and JobCatalog.is_known_job("delivery_driver") and JobCatalog.is_known_job("office_clerk"))
	h.check("Career-C4 unknown id is rejected by catalog",
		not JobCatalog.is_known_job("astronaut") and not JobCatalog.is_known_job(""))

	var laborer: JobDefinition = JobCatalog.get_by_id(JobCatalog.LABORER_ID)
	h.eq_int("Career-C5 Laborer wage is exactly 10", laborer.hourly_wage, 10)
	h.eq_int("Career-C6 Laborer minimum age is 18", laborer.minimum_age, 18)
	h.eq_int("Career-C7 Laborer education requirement is NONE",
		laborer.education_requirement, JobDefinition.EducationRequirement.NONE)
	h.check("Career-C8 Laborer has no attribute requirement", laborer.required_attribute.is_empty())

	var retail: JobDefinition = JobCatalog.get_by_id(JobCatalog.RETAIL_WORKER_ID)
	h.eq_int("Career-C9 Retail wage is exactly 12", retail.hourly_wage, 12)
	h.eq_int("Career-C10 Retail education is PRIMARY_COMPLETED",
		retail.education_requirement, JobDefinition.EducationRequirement.PRIMARY_COMPLETED)
	h.check("Career-C11 Retail requires social >= 15",
		retail.required_attribute == "social" and retail.required_attribute_min == 15.0)

	var delivery: JobDefinition = JobCatalog.get_by_id(JobCatalog.DELIVERY_DRIVER_ID)
	h.eq_int("Career-C12 Delivery wage is exactly 15", delivery.hourly_wage, 15)
	h.eq_int("Career-C13 Delivery education is PRIMARY_COMPLETED",
		delivery.education_requirement, JobDefinition.EducationRequirement.PRIMARY_COMPLETED)
	h.check("Career-C14 Delivery requires discipline >= 20",
		delivery.required_attribute == "discipline" and delivery.required_attribute_min == 20.0)

	var clerk: JobDefinition = JobCatalog.get_by_id(JobCatalog.OFFICE_CLERK_ID)
	h.eq_int("Career-C15 Office Clerk wage is exactly 18", clerk.hourly_wage, 18)
	h.eq_int("Career-C16 Clerk education is SECONDARY_COMPLETED",
		clerk.education_requirement, JobDefinition.EducationRequirement.SECONDARY_COMPLETED)
	h.check("Career-C17 Clerk requires intelligence >= 20",
		clerk.required_attribute == "intelligence" and clerk.required_attribute_min == 20.0)

	h.check("Career-C18 every job hires at 18", _all_minimum_ages() == 4, str(_all_minimum_ages()))


static func _all_minimum_ages() -> int:
	var count: int = 0
	for definition in JobCatalog.definitions():
		if definition.minimum_age == 18:
			count += 1
	return count


static func _default_state(h: TestHarness) -> void:
	h.section("Career-D")
	var pair := fresh()
	var player: PlayerState = pair[1]
	h.eq_string("Career-D1 new player starts unemployed", player.career.current_job_id, "")
	h.eq_bool("Career-D2 is_employed false by default", player.career.is_employed(), false)
	h.eq_int("Career-D3 unemployed wage is zero", player.career.hourly_wage(), 0)
	h.check("Career-D4 current_job is null when unemployed", player.career.current_job() == null)


static func _hiring(h: TestHarness) -> void:
	h.section("Career-H")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	# Underage (age 0): every application fails on age.
	h.eq_bool("Career-H1 underage cannot get Laborer", player.can_apply(JobCatalog.LABORER_ID), false)
	h.eq_bool("Career-H2 underage cannot get Office Clerk", player.can_apply(JobCatalog.OFFICE_CLERK_ID), false)
	h.eq_bool("Career-H3 underage apply fails", player.apply_for_job(JobCatalog.LABORER_ID), false)
	h.eq_string("Career-H4 underage job id unchanged", player.career.current_job_id, "")
	h.check("Career-H5 underage reason mentions age",
		player.evaluate_application(JobCatalog.LABORER_ID)["reason"].contains("at least 18"))

	# Age 18 with no education: only Laborer.
	advance_days(clock, 18 * 365)
	h.eq_int("Career-H6 player is 18", player.age, 18)
	h.eq_bool("Career-H7 Laborer hires at 18", player.apply_for_job(JobCatalog.LABORER_ID), true)
	h.eq_string("Career-H8 held job is laborer", player.career.current_job_id, JobCatalog.LABORER_ID)
	player.quit_job()

	h.eq_bool("Career-H9 Retail fails without Primary completion",
		player.can_apply(JobCatalog.RETAIL_WORKER_ID), false)
	h.check("Career-H10 Retail reason names primary school",
		player.evaluate_application(JobCatalog.RETAIL_WORKER_ID)["reason"].contains("primary"))
	player.education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, 0)
	h.eq_bool("Career-H11 Retail passes education with default social 10",
		player.can_apply(JobCatalog.RETAIL_WORKER_ID), false)
	h.check("Career-H12 Retail reason names social",
		player.evaluate_application(JobCatalog.RETAIL_WORKER_ID)["reason"].contains("Social"))

	player.attributes.restore(10.0, 10.0, 14.9, 10.0, 10.0)
	h.eq_bool("Career-H13 Retail fails Social 14.9", player.can_apply(JobCatalog.RETAIL_WORKER_ID), false)
	player.attributes.restore(10.0, 10.0, 15.0, 10.0, 10.0)
	h.eq_bool("Career-H14 Retail succeeds with Primary + Social 15",
		player.apply_for_job(JobCatalog.RETAIL_WORKER_ID), true)
	h.eq_string("Career-H15 held job is retail_worker", player.career.current_job_id, JobCatalog.RETAIL_WORKER_ID)
	player.quit_job()

	player.attributes.restore(10.0, 10.0, 10.0, 19.9, 10.0)
	h.eq_bool("Career-H16 Delivery fails Discipline 19.9", player.can_apply(JobCatalog.DELIVERY_DRIVER_ID), false)
	player.attributes.restore(10.0, 10.0, 10.0, 20.0, 10.0)
	h.eq_bool("Career-H17 Delivery succeeds with Primary + Discipline 20",
		player.apply_for_job(JobCatalog.DELIVERY_DRIVER_ID), true)
	player.quit_job()

	h.eq_bool("Career-H18 Office fails without Secondary completion",
		player.can_apply(JobCatalog.OFFICE_CLERK_ID), false)
	player.education.restore(EducationState.Status.COMPLETED_SECONDARY, 6, 100, 0, 12)
	player.attributes.restore(10.0, 10.0, 10.0, 10.0, 10.0)
	h.eq_bool("Career-H19 Office fails Intelligence 10", player.can_apply(JobCatalog.OFFICE_CLERK_ID), false)
	player.attributes.restore(20.0, 10.0, 10.0, 10.0, 10.0)
	h.eq_bool("Career-H20 Office succeeds with Secondary + Intelligence 20",
		player.apply_for_job(JobCatalog.OFFICE_CLERK_ID), true)
	player.quit_job()

	# Enrollment floor still enforced (age gate is the job's minimum_age).
	var child := fresh()
	child[1].education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, 0)
	h.eq_bool("Career-H21 a 5-year-old completed-primary player still cannot apply",
		child[1].can_apply(JobCatalog.RETAIL_WORKER_ID), false)


static func _one_job_and_quit(h: TestHarness) -> void:
	h.section("Career-Q")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 18 * 365)

	h.eq_bool("Career-Q1 Laborer hires", player.apply_for_job(JobCatalog.LABORER_ID), true)
	h.eq_string("Career-Q2 held job is laborer", player.career.current_job_id, JobCatalog.LABORER_ID)
	h.check("Career-Q3 second-apply reason says quit first",
		player.evaluate_application(JobCatalog.OFFICE_CLERK_ID)["reason"].contains("Quit"))
	h.eq_bool("Career-Q4 applying to another job while employed fails",
		player.apply_for_job(JobCatalog.OFFICE_CLERK_ID), false)
	h.eq_string("Career-Q5 original job retained", player.career.current_job_id, JobCatalog.LABORER_ID)

	# Quit stops an active Work session.
	h.eq_bool("Career-Q6 start_working works while employed", _start(player), true)
	h.eq_bool("Career-Q7 quit succeeds while working", player.quit_job(), true)
	h.eq_bool("Career-Q8 quit stops Work", player.is_working, false)
	h.eq_bool("Career-Q9 cannot quit twice", player.quit_job(), false)
	h.eq_string("Career-Q10 unemployed after quit", player.career.current_job_id, "")

	# Rehire into the other job after quitting.
	h.eq_bool("Career-Q11 cannot rehire Office Clerk without meeting requirements",
		player.can_apply(JobCatalog.OFFICE_CLERK_ID), false)
	player.education.restore(EducationState.Status.COMPLETED_SECONDARY, 6, 100, 0, 12)
	player.attributes.restore(20.0, 10.0, 10.0, 10.0, 10.0)
	h.eq_bool("Career-Q12 rehire after quit succeeds", player.apply_for_job(JobCatalog.OFFICE_CLERK_ID), true)
	h.eq_string("Career-Q13 new job held", player.career.current_job_id, JobCatalog.OFFICE_CLERK_ID)
	player.quit_job()

	# Unknown job ids are rejected everywhere.
	h.eq_bool("Career-Q12 unknown id fails can_apply", player.can_apply("astronaut"), false)
	h.eq_bool("Career-Q13 unknown id fails apply_for_job", player.apply_for_job("astronaut"), false)
	h.eq_bool("Career-Q14 empty id fails apply_for_job", player.apply_for_job(""), false)
	h.eq_string("Career-Q15 job unchanged after unknown ids", player.career.current_job_id, "")


static func _work_wages(h: TestHarness) -> void:
	h.section("Career-W")
	_wage_case(h, JobCatalog.LABORER_ID, 10)
	_wage_case(h, JobCatalog.RETAIL_WORKER_ID, 12)
	_wage_case(h, JobCatalog.DELIVERY_DRIVER_ID, 15)
	_wage_case(h, JobCatalog.OFFICE_CLERK_ID, 18)


static func _wage_case(h: TestHarness, job_id: String, wage: int) -> void:
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 18 * 365)
	_meet_requirements(player, job_id)
	h.check("Career-W setup hires %s" % job_id, player.apply_for_job(job_id))

	var money_before: int = player.money
	h.eq_bool("Career-W %s starts working" % job_id, _start(player), true)
	player.advance_simulation(60)
	h.eq_int("Career-W %s one hour earns exactly +%d" % [job_id, wage], player.money, money_before + wage)
	player.stop_working()


static func _start(player: PlayerState) -> bool:
	player.start_working()
	return player.is_working


static func _meet_requirements(player: PlayerState, job_id: String) -> void:
	var job: JobDefinition = JobCatalog.get_by_id(job_id)
	if job.education_requirement == JobDefinition.EducationRequirement.PRIMARY_COMPLETED:
		player.education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, 0)
	elif job.education_requirement == JobDefinition.EducationRequirement.SECONDARY_COMPLETED:
		player.education.restore(EducationState.Status.COMPLETED_SECONDARY, 6, 100, 0, 12)
	if not job.required_attribute.is_empty():
		player.attributes.restore(10.0, 10.0, 10.0, 10.0, 10.0)
		match job.required_attribute:
			"social":
				player.attributes.restore(10.0, 10.0, 20.0, 10.0, 10.0)
			"discipline":
				player.attributes.restore(10.0, 10.0, 10.0, 20.0, 10.0)
			"intelligence":
				player.attributes.restore(20.0, 10.0, 10.0, 10.0, 10.0)


static func _work_partial_hours(h: TestHarness) -> void:
	h.section("Career-WP")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 18 * 365)
	player.apply_for_job(JobCatalog.LABORER_ID)
	player.start_working()

	var money_before: int = player.money
	player.advance_simulation(59)
	h.eq_int("Career-WP1 59 minutes earns nothing", player.money, money_before)
	player.advance_simulation(1)
	h.eq_int("Career-WP2 60 minutes earns one hour", player.money, money_before + 10)
	player.advance_simulation(59)
	h.eq_int("Career-WP3 119 minutes still one hour", player.money, money_before + 10)
	player.advance_simulation(1)
	h.eq_int("Career-WP4 120 minutes earns two hours", player.money, money_before + 20)

	# Partial accumulator survives stop/start of the activity.
	player.stop_working()
	player.start_working()
	player.advance_simulation(30)
	h.eq_int("Career-WP5 remainder carries across stop/start", player.money, money_before + 20)
	player.advance_simulation(30)
	h.eq_int("Career-WP6 completed hour pays after carry", player.money, money_before + 30)
	player.stop_working()


static func _offline_wages(h: TestHarness) -> void:
	h.section("Career-O")

	for case in [[JobCatalog.LABORER_ID, 10], [JobCatalog.OFFICE_CLERK_ID, 18]]:
		var job_id: String = case[0]
		var wage: int = case[1]

		var pair := fresh()
		var clock: GameClock = pair[0]
		var player: PlayerState = pair[1]
		advance_days(clock, 18 * 365)
		_meet_requirements(player, job_id)
		player.apply_for_job(job_id)
		player.start_working()
		player.advance_simulation(60 * 5)  # 5 completed hours active
		SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
		var money_at_save: int = player.money
		var acc_at_save: int = player.get_work_minutes_accumulator()

		var loaded := fresh()
		var loaded_clock: GameClock = loaded[0]
		var loaded_player: PlayerState = loaded[1]
		var result: Dictionary = SaveManager.load_game(loaded_clock, loaded_player, TEST_PATH, FIXED_NOW + 3600.0)

		h.check("Career-O %s offline load succeeds" % job_id, result["ok"], result["error"])
		# 1 real hour = 4 game minutes/second * 3600 seconds = 14400 game minutes
		# = 240 hours. With a clean accumulator that is exactly 240*h of pay.
		h.eq_string("Career-O %s job persists through save" % job_id,
			loaded_player.career.current_job_id, job_id)
		h.eq_int("Career-O %s offline wage multiplier correct" % job_id,
			loaded_player.money, money_at_save + 240 * wage)
		h.eq_int("Career-O %s accumulator preserved" % job_id,
			loaded_player.get_work_minutes_accumulator(), acc_at_save)
		h.eq_bool("Career-O %s still working after load" % job_id, loaded_player.is_working, true)

	# Unemployed offline progression earns nothing.
	var unemp := fresh()
	var unemp_clock: GameClock = unemp[0]
	var unemp_player: PlayerState = unemp[1]
	advance_days(unemp_clock, 18 * 365)
	SaveManager.save_game(unemp_clock, unemp_player, TEST_PATH, FIXED_NOW)
	var unemp_loaded := fresh()
	SaveManager.load_game(unemp_loaded[0], unemp_loaded[1], TEST_PATH, FIXED_NOW + 3600.0)
	h.eq_int("Career-O unemployed offline earns nothing", unemp_loaded[1].money, 1000)
	h.eq_string("Career-O unemployed stays unemployed offline", unemp_loaded[1].career.current_job_id, "")


static func _save_v9_round_trip(h: TestHarness) -> void:
	h.section("Career-S")

	# Employed round trip.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 18 * 365)
	_meet_requirements(player, JobCatalog.OFFICE_CLERK_ID)
	player.apply_for_job(JobCatalog.OFFICE_CLERK_ID)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var raw: String = FileAccess.get_file_as_string(TEST_PATH)
	var data: Dictionary = JSON.parse_string(raw)
	h.eq_int("Career-S1 save version is exactly 9", data["Version"], 9)
	h.eq_string("Career-S2 CurrentJobId serialized", data["CurrentJobId"], JobCatalog.OFFICE_CLERK_ID)

	var loaded := fresh()
	var load_result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW)
	h.check("Career-S3 employed save loads", load_result["ok"], load_result["error"])
	h.eq_string("Career-S4 employed round trips", loaded[1].career.current_job_id, JobCatalog.OFFICE_CLERK_ID)

	# Unemployed round trip.
	player.quit_job()
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var unemp_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.check("Career-S5 unemployed CurrentJobId serializes empty", unemp_data["CurrentJobId"] == "")
	var unemp_loaded := fresh()
	var unemp_result: Dictionary = SaveManager.load_game(unemp_loaded[0], unemp_loaded[1], TEST_PATH, FIXED_NOW)
	h.check("Career-S6 unemployed save loads", unemp_result["ok"], unemp_result["error"])
	h.eq_string("Career-S7 unemployed round trips", unemp_loaded[1].career.current_job_id, "")
	h.eq_bool("Career-S8 working flag not resurrected", unemp_loaded[1].is_working, false)


static func _save_v9_invalid(h: TestHarness) -> void:
	h.section("Career-V")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 18 * 365)
	_meet_requirements(player, JobCatalog.LABORER_ID)
	player.apply_for_job(JobCatalog.LABORER_ID)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_PATH)

	var live := fresh()
	var live_player: PlayerState = live[1]
	live_player.money = 777

	var cases: Array = [
		["unknown CurrentJobId", {"CurrentJobId": "astronaut"}],
		["numeric CurrentJobId", {"CurrentJobId": 42}],
		["IsWorking with no job", {"IsWorking": true, "CurrentJobId": ""}],
		["IsWorking with unknown job", {"IsWorking": true, "CurrentJobId": "astronaut"}],
	]
	for entry in cases:
		var data: Dictionary = JSON.parse_string(base_text)
		for key in entry[1]:
			data[key] = entry[1][key]
		_write(TEST_PATH, JSON.stringify(data))
		var result: Dictionary = SaveManager.load_game(live[0], live[1], TEST_PATH, FIXED_NOW)
		h.eq_bool("Career-V rejects %s" % entry[0], result["ok"], false)

	h.eq_int("Career-V live money untouched by rejected loads", live_player.money, 777)
	h.eq_string("Career-V live career untouched by rejected loads", live_player.career.current_job_id, "")


static func _legacy_migration(h: TestHarness) -> void:
	h.section("Career-L")

	# A pre-v9 save with IsWorking=true must migrate to Laborer (matching the
	# historical flat 10/hour wage); IsWorking=false stays unemployed.
	var fixture: Dictionary = _legacy_v8_fixture()
	fixture["IsWorking"] = true
	fixture["WorkMinutesAccumulator"] = 30
	_write(TEST_PATH, JSON.stringify(fixture))
	var working := fresh()
	var working_result: Dictionary = SaveManager.load_game(working[0], working[1], TEST_PATH, FIXED_NOW)
	h.check("Career-L1 legacy working save loads", working_result["ok"], working_result["error"])
	h.eq_string("Career-L2 legacy working migrates to Laborer",
		working[1].career.current_job_id, JobCatalog.LABORER_ID)
	h.eq_bool("Career-L3 legacy working keeps IsWorking", working[1].is_working, true)

	var fixture_off: Dictionary = _legacy_v8_fixture()
	fixture_off["IsWorking"] = false
	_write(TEST_PATH, JSON.stringify(fixture_off))
	var idle := fresh()
	var idle_result: Dictionary = SaveManager.load_game(idle[0], idle[1], TEST_PATH, FIXED_NOW)
	h.check("Career-L4 legacy idle save loads", idle_result["ok"], idle_result["error"])
	h.eq_string("Career-L5 legacy idle stays unemployed", idle[1].career.current_job_id, "")
	h.eq_bool("Career-L6 legacy idle not working", idle[1].is_working, false)

	# v9 must remain in SUPPORTED_VERSIONS and v2-v8 all still load.
	h.check("Career-L7 version 9 supported",
		SaveData.SUPPORTED_VERSIONS.has(9) and SaveData.VERSION == 9)


static func _legacy_v8_fixture() -> Dictionary:
	return {
		"Version": 8,
		"Day": 2190, "Hour": 12, "Minute": 30,
		"Money": 4242, "Energy": 90, "Hunger": 80, "Thirst": 70, "StudyXP": 120,
		"IsSleeping": false, "IsWorking": false, "IsStudying": false,
		"IsPlaying": false, "IsSpendingFamilyTime": false,
		"WorkMinutesAccumulator": 0, "StudyMinutesAccumulator": 30,
		"AwakeMinutesAccumulator": 15, "SleepingMinutesAccumulator": 0,
		"HungerMinutesAccumulator": 5, "ThirstMinutesAccumulator": 25,
		"PlayMinutesAccumulator": 0, "FamilyTimeMinutesAccumulator": 0,
		"AcademicsExperience": 340,
		"EducationStatus": 1, "PrimaryGrade": 3, "EducationProgress": 45, "SchoolYearStartDay": 1460,
		"SecondaryGrade": 0,
		"TotalPlayHours": 12,
		"CurrentEventId": null,
		"CurrentEventTriggeredDay": 0,
		"EventHistory": [],
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
		"Confidence": 61.5, "Curiosity": 52.0, "Patience": 53.0, "Ambition": 54.0, "Empathy": 55.0,
		"Intelligence": 15.0, "Fitness": 12.0, "Social": 11.0, "Discipline": 10.0, "Creativity": 9.0,
		"SavedAtUtc": SaveData.format_utc(FIXED_NOW),
	}


static func _write(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(text)
	file.close()
	return {"ok": true}
