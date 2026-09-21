extends RefCounted

## Economy foundation coverage: age-dependent daily rates, payment and
## shortfall semantics, exactly-once day boundaries, bracket birthdays, Work
## chronology across midnight (stepped/bulk/offline equivalence), death
## cutoff, Save Version 12 persistence/migration/validation and God Mode.

const TEST_PATH: String = "user://test_economy.json"
const FIXED_NOW: float = 1793000000.0


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func run(h: TestHarness) -> void:
	_rates(h)
	_fresh_state(h)
	_payments(h)
	_boundaries(h)
	_age_transitions(h)
	_work_chronology(h)
	_death(h)
	_save_v12(h)
	_validation(h)
	_offline_restore(h)
	_godmode(h)


# =====================================================================
# Rate table: the single authoritative source
# =====================================================================

static func _rates(h: TestHarness) -> void:
	h.section("Econ-R")

	var cases: Array = [
		[0, 0], [17, 0], [18, 5], [24, 5], [25, 10],
		[39, 10], [40, 15], [59, 15], [60, 10], [100, 10],
	]
	for entry in cases:
		h.eq_int("Econ-R age %d pays %d/day" % [entry[0], entry[1]],
			EconomyState.daily_rate_for_age(entry[0]), entry[1])

	h.eq_string("Econ-R child bracket", EconomyState.bracket_label(7), "Age 0–17 · $0/day")
	h.eq_string("Econ-R young bracket", EconomyState.bracket_label(18), "Age 18–24 · $5/day")
	h.eq_string("Econ-R adult bracket", EconomyState.bracket_label(30), "Age 25–39 · $10/day")
	h.eq_string("Econ-R middle bracket", EconomyState.bracket_label(50), "Age 40–59 · $15/day")
	h.eq_string("Econ-R senior bracket", EconomyState.bracket_label(70), "Age 60+ · $10/day")


# =====================================================================
# Fresh economy: zeroed totals, no charge at creation
# =====================================================================

static func _fresh_state(h: TestHarness) -> void:
	h.section("Econ-F")

	var pair := fresh()
	var player: PlayerState = pair[1]
	h.eq_int("Econ-F1 fresh paid is 0", player.economy.total_paid, 0)
	h.eq_int("Econ-F2 fresh outstanding is 0", player.economy.outstanding, 0)
	h.eq_int("Econ-F3 fresh missed is 0", player.economy.missed_payments, 0)
	h.eq_int("Econ-F4 creation charges nothing", player.money, PlayerState.STARTING_MONEY)


# =====================================================================
# Payment and shortfall semantics
# =====================================================================

static func _payments(h: TestHarness) -> void:
	h.section("Econ-P")

	# Full payment from savings.
	var rich := fresh()[1] as PlayerState
	var rich_out: Dictionary = rich.economy.apply_daily_charge(10, 100)
	h.eq_int("Econ-P1 full payment leaves money 90", rich_out["new_money"], 90)
	h.eq_int("Econ-P2 full payment records paid", rich.economy.total_paid, 10)
	h.eq_int("Econ-P3 full payment accrues nothing", rich.economy.outstanding, 0)
	h.eq_int("Econ-P4 full payment misses nothing", rich.economy.missed_payments, 0)

	# Exact payment zeroes money without debt.
	var exact := fresh()[1] as PlayerState
	var exact_out: Dictionary = exact.economy.apply_daily_charge(10, 10)
	h.eq_int("Econ-P5 exact payment zeroes money", exact_out["new_money"], 0)
	h.eq_int("Econ-P6 exact payment records paid", exact.economy.total_paid, 10)

	# Shortfall: money untouched, full amount outstanding, one miss.
	var poor := fresh()[1] as PlayerState
	var poor_out: Dictionary = poor.economy.apply_daily_charge(10, 9)
	h.eq_int("Econ-P7 shortfall leaves money at 9", poor_out["new_money"], 9)
	h.eq_int("Econ-P8 shortfall pays nothing", poor.economy.total_paid, 0)
	h.eq_int("Econ-P9 shortfall accrues the full 10", poor.economy.outstanding, 10)
	h.eq_int("Econ-P10 shortfall records one miss", poor.economy.missed_payments, 1)

	# Repeated shortfalls accumulate; money never goes negative.
	poor.economy.apply_daily_charge(10, 9)
	h.eq_int("Econ-P11 outstanding accumulates", poor.economy.outstanding, 20)
	h.eq_int("Econ-P12 misses accumulate", poor.economy.missed_payments, 2)

	# Zero-cost days mutate nothing.
	var child := fresh()[1] as PlayerState
	var child_out: Dictionary = child.economy.apply_daily_charge(0, 100)
	h.eq_int("Econ-P13 zero cost leaves money", child_out["new_money"], 100)
	h.eq_int("Econ-P14 zero cost pays nothing", child.economy.total_paid, 0)
	h.eq_int("Econ-P15 zero cost misses nothing", child.economy.missed_payments, 0)


# =====================================================================
# Exactly-once day boundaries through the engine
# =====================================================================

static func _boundaries(h: TestHarness) -> void:
	h.section("Econ-B")

	# 23:59 + 1 minute: exactly one assessment.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 18 * 365)
	clock.restore(clock.day, 23, 59)
	var money: int = player.money
	player.advance_simulation(1)
	h.eq_int("Econ-B1 one midnight charges once", player.money, money - 5)
	h.eq_int("Econ-B2 one midnight records paid", player.economy.total_paid, 5)
	h.eq_int("Econ-B3 one midnight misses nothing", player.economy.missed_payments, 0)

	# Same-day simulation charges nothing further.
	player.advance_simulation(60 * 20)
	h.eq_int("Econ-B4 same-day hours charge nothing", player.economy.total_paid, 5)

	# A full additional day charges exactly once more.
	player.advance_simulation(60 * 4)
	h.eq_int("Econ-B5 second midnight charges once", player.economy.total_paid, 10)

	# Save/load at the same timestamp duplicates nothing, and the restored
	# pointer keeps future midnights exact.
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var loaded := fresh()
	h.check("Econ-B6 reload succeeds",
		SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_int("Econ-B7 reload duplicates no charge", loaded[1].economy.total_paid, 10)
	h.eq_int("Econ-B8 reload preserves money", loaded[1].money, player.money)
	loaded[1].advance_simulation(60 * 24)
	h.eq_int("Econ-B9 next midnight after reload charges once", loaded[1].economy.total_paid, 15)

	# Child days (rate 0) assess nothing across many midnights.
	var kid_pair := fresh()
	var kid_clock: GameClock = kid_pair[0]
	var kid: PlayerState = kid_pair[1]
	advance_days(kid_clock, 10 * 365)
	TestHarness.advance_kept_alive(kid, 60 * 24 * 5)
	h.eq_int("Econ-B10 child week pays nothing", kid.economy.total_paid, 0)
	h.eq_int("Econ-B11 child week misses nothing", kid.economy.missed_payments, 0)
	h.eq_int("Econ-B12 child money untouched", kid.money, PlayerState.STARTING_MONEY)


# =====================================================================
# Bracket birthdays use the newly entered day's age
# =====================================================================

static func _age_transitions(h: TestHarness) -> void:
	h.section("Econ-A")

	var cases: Array = [
		[17, 5], [24, 10], [39, 15], [59, 10],
	]
	for entry in cases:
		var old_age: int = entry[0]
		var expected: int = entry[1]
		var pair := fresh()
		var clock: GameClock = pair[0]
		var player: PlayerState = pair[1]
		# Last minute of the final day at old_age; entering the next day
		# turns the birthday age and its new bracket rate.
		clock.restore(old_age * 365 + 364, 23, 59)
		var money: int = player.money
		player.advance_simulation(1)
		h.eq_int("Econ-A age %d birthday charges %d" % [old_age, expected],
			money - player.money, expected)
		h.eq_int("Econ-A birthday records paid", player.economy.total_paid, expected)

	# The day before the 18th birthday is still free.
	var minor_pair := fresh()
	var minor_clock: GameClock = minor_pair[0]
	var minor: PlayerState = minor_pair[1]
	minor_clock.restore(17 * 365 + 363, 23, 59)
	minor.advance_simulation(1)
	h.eq_int("Econ-A pre-birthday day is free", minor.economy.total_paid, 0)
	h.eq_int("Econ-A pre-birthday money kept", minor.money, PlayerState.STARTING_MONEY)


# =====================================================================
# Work across midnight: stepped, bulk and offline agree
# =====================================================================

static func _work_chronology(h: TestHarness) -> void:
	h.section("Econ-W")

	# Minute-stepped baseline: 23:00 -> 01:00 working at age 18.
	var stepped_pair := fresh()
	var stepped_clock: GameClock = stepped_pair[0]
	var stepped: PlayerState = stepped_pair[1]
	advance_days(stepped_clock, 18 * 365)
	stepped.apply_for_job(JobCatalog.LABORER_ID)
	stepped.start_working()
	stepped_clock.restore(stepped_clock.day, 23, 0)
	for _i in range(120):
		stepped.advance_simulation(1)
	h.eq_int("Econ-W1 stepped wages across midnight", stepped.money, 1000 + 20 - 5)
	h.eq_int("Econ-W2 stepped XP across midnight", stepped.career.get_experience(JobCatalog.LABORER_ID), 20)
	h.eq_int("Econ-W3 stepped expense paid", stepped.economy.total_paid, 5)

	# One bulk call must match minute stepping exactly.
	var bulk_pair := fresh()
	var bulk_clock: GameClock = bulk_pair[0]
	var bulk: PlayerState = bulk_pair[1]
	advance_days(bulk_clock, 18 * 365)
	bulk.apply_for_job(JobCatalog.LABORER_ID)
	bulk.start_working()
	bulk_clock.restore(bulk_clock.day, 23, 0)
	bulk.bulk_advance_simulation(120)
	h.eq_int("Econ-W4 bulk money matches stepped", bulk.money, stepped.money)
	h.eq_int("Econ-W5 bulk XP matches stepped",
		bulk.career.get_experience(JobCatalog.LABORER_ID),
		stepped.career.get_experience(JobCatalog.LABORER_ID))
	h.eq_int("Econ-W6 bulk paid matches stepped", bulk.economy.total_paid, stepped.economy.total_paid)
	h.eq_int("Econ-W7 bulk clock matches stepped",
		bulk_clock.hour * 60 + bulk_clock.minute,
		stepped_clock.hour * 60 + stepped_clock.minute)
	h.eq_int("Econ-W8 bulk thirst matches stepped", bulk.thirst, stepped.thirst)

	# Equivalent offline progression must match as well (30 real seconds).
	var offline := fresh()
	var offline_clock: GameClock = offline[0]
	var offline_player: PlayerState = offline[1]
	var setup := fresh()
	var setup_clock: GameClock = setup[0]
	var setup_player: PlayerState = setup[1]
	advance_days(setup_clock, 18 * 365)
	setup_player.apply_for_job(JobCatalog.LABORER_ID)
	setup_player.start_working()
	setup_clock.restore(setup_clock.day, 23, 0)
	SaveManager.save_game(setup_clock, setup_player, TEST_PATH, FIXED_NOW)
	h.check("Econ-W9 offline load succeeds",
		SaveManager.load_game(offline_clock, offline_player, TEST_PATH, FIXED_NOW + 30.0)["ok"])
	h.eq_int("Econ-W10 offline money matches stepped", offline_player.money, stepped.money)
	h.eq_int("Econ-W11 offline paid matches stepped", offline_player.economy.total_paid, 5)
	h.eq_bool("Econ-W12 offline still working", offline_player.is_working, true)


# =====================================================================
# Death freezes the economy with history retained
# =====================================================================

static func _death(h: TestHarness) -> void:
	h.section("Econ-XD")

	# A dead player crossing hypothetical days incurs nothing.
	var pair := fresh()
	var player: PlayerState = pair[1]
	player.die(PlayerState.CAUSE_STARVATION)
	player.advance_simulation(60 * 24 * 100)
	h.eq_int("Econ-XD1 dead days charge nothing", player.economy.total_paid, 0)
	h.eq_int("Econ-XD2 dead days miss nothing", player.economy.missed_payments, 0)

	# Death before the next boundary: no next-day charge.
	var dying_pair := fresh()
	var dying_clock: GameClock = dying_pair[0]
	var dying: PlayerState = dying_pair[1]
	advance_days(dying_clock, 30 * 365)
	dying.debug_set_health(5.0)
	dying.debug_set_thirst(0)
	dying.debug_set_hunger(100)
	dying.advance_simulation(60)
	h.eq_bool("Econ-XD3 same-day death occurs", dying.is_dead, true)
	h.eq_int("Econ-XD4 no boundary charge on death", dying.economy.total_paid, 0)

	# A charge assessed on entry survives a later same-day death.
	var charged_pair := fresh()
	var charged_clock: GameClock = charged_pair[0]
	var charged: PlayerState = charged_pair[1]
	advance_days(charged_clock, 30 * 365)
	charged_clock.restore(charged_clock.day, 23, 0)
	charged.debug_set_health(9.0)
	charged.debug_set_thirst(0)
	charged.debug_set_hunger(100)
	charged.advance_simulation(60)
	h.eq_int("Econ-XD5 midnight charge applied", charged.economy.total_paid, 10)
	charged.advance_simulation(60)
	h.eq_bool("Econ-XD6 later death occurs", charged.is_dead, true)
	h.eq_int("Econ-XD7 valid charge retained", charged.economy.total_paid, 10)
	h.eq_string("Econ-XD8 outstanding recorded", str(charged.economy.outstanding), "0")

	# Offline death before the boundary: no charge for the unentered day.
	var off_pair := fresh()
	var off_clock: GameClock = off_pair[0]
	var off: PlayerState = off_pair[1]
	advance_days(off_clock, 18 * 365)
	off_clock.restore(off_clock.day, 23, 0)
	off.debug_set_health(5.0)
	off.debug_set_thirst(0)
	off.debug_set_hunger(100)
	SaveManager.save_game(off_clock, off, TEST_PATH, FIXED_NOW)
	var off_loaded := fresh()
	# 30 real seconds = 120 game minutes, but death lands 15 minutes in.
	SaveManager.load_game(off_loaded[0], off_loaded[1], TEST_PATH, FIXED_NOW + 30.0)
	h.eq_bool("Econ-XD9 offline death occurs", off_loaded[1].is_dead, true)
	h.eq_int("Econ-XD10 unentered day never charged", off_loaded[1].economy.total_paid, 0)


# =====================================================================
# Save Version 12 persistence and migration
# =====================================================================

static func _save_v12(h: TestHarness) -> void:
	h.section("Econ-S")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 30 * 365)
	TestHarness.advance_kept_alive(player, 60 * 24 * 5)
	player.money = 3
	TestHarness.advance_kept_alive(player, 60 * 24 * 2)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_int("Econ-S1 save version is exactly 13", raw["Version"], 13)
	var stored: Dictionary = raw["Economy"]
	h.eq_int("Econ-S2 paid persisted", stored["TotalLivingExpensesPaid"], 50)
	h.eq_int("Econ-S3 outstanding persisted", stored["OutstandingLivingExpenses"], 20)
	h.eq_int("Econ-S4 missed persisted", stored["MissedLivingExpensePayments"], 2)

	var loaded := fresh()
	var load_result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW)
	h.check("Econ-S5 load succeeds", load_result["ok"], load_result["error"])
	h.eq_int("Econ-S6 paid round trips", loaded[1].economy.total_paid, 50)
	h.eq_int("Econ-S7 outstanding round trips", loaded[1].economy.outstanding, 20)
	h.eq_int("Econ-S8 missed round trips", loaded[1].economy.missed_payments, 2)
	h.eq_int("Econ-S9 money round trips", loaded[1].money, 3)

	# v11 migration: no Economy key; totals default to zero, job kept.
	var v11_pair := fresh()
	var v11_clock: GameClock = v11_pair[0]
	var v11_player: PlayerState = v11_pair[1]
	advance_days(v11_clock, 18 * 365)
	v11_player.apply_for_job(JobCatalog.LABORER_ID)
	SaveManager.save_game(v11_clock, v11_player, TEST_PATH, FIXED_NOW)
	var v11_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	v11_data["Version"] = 11
	v11_data.erase("Economy")
	_write(TEST_PATH, JSON.stringify(v11_data))
	var migrated := fresh()
	var migrate_result: Dictionary = SaveManager.load_game(migrated[0], migrated[1], TEST_PATH, FIXED_NOW)
	h.check("Econ-S10 v11 save still loads", migrate_result["ok"], migrate_result["error"])
	h.eq_int("Econ-S11 v11 paid defaults to 0", migrated[1].economy.total_paid, 0)
	h.eq_int("Econ-S12 v11 outstanding defaults to 0", migrated[1].economy.outstanding, 0)
	h.eq_int("Econ-S13 v11 missed defaults to 0", migrated[1].economy.missed_payments, 0)
	h.eq_string("Econ-S14 v11 job preserved", migrated[1].career.current_job_id, JobCatalog.LABORER_ID)

	# v10 migration: older saves likewise default with no retroactive charges.
	var v10_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	v10_data["Version"] = 10
	v10_data.erase("CareerProgress")
	_write(TEST_PATH, JSON.stringify(v10_data))
	var legacy := fresh()
	h.check("Econ-S15 v10 save still loads",
		SaveManager.load_game(legacy[0], legacy[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_int("Econ-S16 v10 paid defaults to 0", legacy[1].economy.total_paid, 0)


# =====================================================================
# Version 12 validation and transactional rejection
# =====================================================================

static func _validation(h: TestHarness) -> void:
	h.section("Econ-V")

	var pair := fresh()
	SaveManager.save_game(pair[0], pair[1], TEST_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_PATH)

	# Live state that must survive every rejected load untouched.
	var live := fresh()
	var live_clock: GameClock = live[0]
	var live_player: PlayerState = live[1]
	advance_days(live_clock, 25 * 365)
	live_player.money = 4242
	live_player.energy = 61
	live_player.debug_set_hunger(62)
	live_player.debug_set_thirst(63)
	live_player.debug_set_health(42.0)
	live_player.economy.restore(50, 20, 2)
	live_player.apply_for_job(JobCatalog.LABORER_ID)
	live_player.career.award_experience(JobCatalog.LABORER_ID, 900)
	live_player.start_working()
	live_player.debug_set_thirst(0)
	live_player.advance_simulation(45)
	live_clock.restore(4321, 7, 8)

	var cases: Array = [
		["missing Economy", {"__erase__": "Economy"}],
		["Economy not a dict", {"Economy": []}],
		["missing paid field", {"__erase_econ__": "TotalLivingExpensesPaid"}],
		["missing outstanding field", {"__erase_econ__": "OutstandingLivingExpenses"}],
		["missing missed field", {"__erase_econ__": "MissedLivingExpensePayments"}],
		["negative paid", {"__econ__": ["TotalLivingExpensesPaid", -1]}],
		["negative outstanding", {"__econ__": ["OutstandingLivingExpenses", -5]}],
		["negative missed", {"__econ__": ["MissedLivingExpensePayments", -2]}],
		["string paid", {"__econ__": ["TotalLivingExpensesPaid", "50"]}],
		["null outstanding", {"__econ__": ["OutstandingLivingExpenses", null]}],
		["boolean missed", {"__econ__": ["MissedLivingExpensePayments", true]}],
		["fractional paid", {"__econ__": ["TotalLivingExpensesPaid", 50.5]}],
		["overflow paid", {"__econ__": ["TotalLivingExpensesPaid", 1.0e30]}],
		["unknown economy field", {"__add_econ__": "Rent"}],
	]
	for entry in cases:
		var data: Dictionary = JSON.parse_string(base_text)
		_apply_patch(data, entry[1])
		_write(TEST_PATH, JSON.stringify(data))
		var result: Dictionary = SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)
		h.eq_bool("Econ-V rejects %s" % entry[0], result["ok"], false)

	h.eq_int("Econ-V live clock day untouched", live_clock.day, 4321)
	h.eq_int("Econ-V live money untouched", live_player.money, 4242)
	h.eq_int("Econ-V live energy untouched", live_player.energy, 61)
	h.eq_int("Econ-V live hunger untouched", live_player.hunger, 62)
	h.eq_int("Econ-V live thirst untouched", live_player.thirst, 0)
	h.near_float("Econ-V live health untouched", live_player.health, 42.0)
	h.eq_bool("Econ-V live death state untouched", live_player.is_dead, false)
	h.eq_bool("Econ-V live activity untouched", live_player.is_working, true)
	h.eq_string("Econ-V live career untouched", live_player.career.current_job_id, JobCatalog.LABORER_ID)
	h.eq_int("Econ-V live labor XP untouched", live_player.career.get_experience(JobCatalog.LABORER_ID), 900)
	h.eq_int("Econ-V live paid untouched", live_player.economy.total_paid, 50)
	h.eq_int("Econ-V live outstanding untouched", live_player.economy.outstanding, 20)
	h.eq_int("Econ-V live missed untouched", live_player.economy.missed_payments, 2)
	h.eq_int("Econ-V live streak untouched", live_player.get_dehydrated_minutes_accumulator(), 45)
	h.eq_int("Econ-V live education untouched",
		live_player.education.status, EducationState.Status.NOT_ENROLLED)

	# Whole-float interop still loads (C# long-typed JSON binding parity).
	var whole: Dictionary = JSON.parse_string(base_text)
	(whole["Economy"] as Dictionary)["TotalLivingExpensesPaid"] = 50.0
	_write(TEST_PATH, JSON.stringify(whole))
	var whole_loaded := fresh()
	h.check("Econ-V whole-float totals load",
		SaveManager.load_game(whole_loaded[0], whole_loaded[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_int("Econ-V whole-float value restores", whole_loaded[1].economy.total_paid, 50)


static func _apply_patch(data: Dictionary, patch: Dictionary) -> void:
	for key in patch:
		if key == "__erase__":
			data.erase(patch[key])
		elif key == "__erase_econ__":
			(data["Economy"] as Dictionary).erase(patch[key])
		elif key == "__econ__":
			var econ_patch: Array = patch[key]
			(data["Economy"] as Dictionary)[econ_patch[0]] = econ_patch[1]
		elif key == "__add_econ__":
			(data["Economy"] as Dictionary)[patch[key]] = 0
		else:
			data[key] = patch[key]


# =====================================================================
# Totals restore before offline simulation
# =====================================================================

static func _offline_restore(h: TestHarness) -> void:
	h.section("Econ-OL")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 30 * 365)
	player.economy.restore(50, 20, 2)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	# Two offline game days (720 real seconds) with survivable needs: the two
	# $10 assessments must accumulate onto the restored 50, not replace it.
	var loaded := fresh()
	var result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW + 720.0)
	h.check("Econ-OL1 offline load succeeds", result["ok"], result["error"])
	h.eq_int("Econ-OL2 offline days accumulate onto restored totals",
		loaded[1].economy.total_paid, 70)
	h.eq_int("Econ-OL3 offline money pays both days", loaded[1].money, 1000 - 20)
	h.eq_int("Econ-OL4 outstanding untouched offline", loaded[1].economy.outstanding, 20)
	h.eq_int("Econ-OL5 missed untouched offline", loaded[1].economy.missed_payments, 2)
	h.eq_bool("Econ-OL6 offline survivor lives", loaded[1].is_dead, false)


# =====================================================================
# God Mode economy helper
# =====================================================================

static func _godmode(h: TestHarness) -> void:
	h.section("Econ-G")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 30 * 365)
	player.economy.restore(50, 20, 2)
	player.career.award_experience(JobCatalog.LABORER_ID, 900)
	var god := GodMode.new(clock, player)

	var idle_god := GodMode.new(clock, player)
	h.eq_bool("Econ-G1 disabled tool fails", idle_god.clear_economy_debt()["ok"], false)

	god.set_enabled(true)
	var result: Dictionary = god.clear_economy_debt()
	h.eq_bool("Econ-G2 clear succeeds", result["ok"], true)
	h.eq_int("Econ-G3 outstanding cleared", player.economy.outstanding, 0)
	h.eq_int("Econ-G4 paid untouched", player.economy.total_paid, 50)
	h.eq_int("Econ-G5 missed untouched", player.economy.missed_payments, 2)
	h.eq_int("Econ-G6 money untouched", player.money, 1000)
	h.eq_int("Econ-G7 career XP untouched", player.career.get_experience(JobCatalog.LABORER_ID), 900)

	player.die(PlayerState.CAUSE_STARVATION)
	var dead: Dictionary = god.clear_economy_debt()
	h.eq_bool("Econ-G8 dead fails cleanly", dead["ok"], false)
	h.eq_string("Econ-G9 dead message", dead["message"], "Life has ended.")


static func _write(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(text)
	file.close()
	return {"ok": true}
