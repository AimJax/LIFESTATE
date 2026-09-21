extends RefCounted

## Housing foundation coverage: definitions, manual moving, the Parents age
## rule, payment and shortfall semantics, living-first ordering, midnight move
## semantics, Work chronology (stepped/bulk/offline), death cutoff, Save
## Version 14 persistence/migration/validation, transactional rejection,
## offline equivalence and God Mode.

const TEST_PATH: String = "user://test_housing.json"
const FIXED_NOW: float = 1795000000.0


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func _at_age(clock: GameClock, age_years: int) -> void:
	clock.restore(age_years * 365, 0, 0)


static func run(h: TestHarness) -> void:
	_definitions(h)
	_moving(h)
	_parents_rule(h)
	_payments(h)
	_ordering(h)
	_midnight_moves(h)
	_work_chronology(h)
	_death(h)
	_save_v14(h)
	_validation(h)
	_offline_example(h)
	_godmode(h)


# =====================================================================
# Immutable definitions: one authority
# =====================================================================

static func _definitions(h: TestHarness) -> void:
	h.section("House-D")

	h.check("House-D1 exactly four homes exist", HousingCatalog.definitions().size() == 4)
	var ids: Array = []
	for definition in HousingCatalog.definitions():
		ids.append(definition.id)
	h.check("House-D2 IDs unique and stable",
		ids == ["parents", "cheap_room", "apartment", "nice_apartment"])
	h.check("House-D3 unknown ID rejected",
		not HousingCatalog.is_known_housing("mansion") and not HousingCatalog.is_known_housing(""))

	var parents: HousingDefinition = HousingCatalog.get_by_id(HousingCatalog.PARENTS_ID)
	h.eq_string("House-D4 parents display", parents.display_name, "Living with Parents")
	h.eq_int("House-D5 parents cost", parents.daily_cost, 0)
	h.eq_int("House-D6 parents age", parents.minimum_age, 0)
	h.eq_string("House-D7 parents description",
		parents.description, "Stay at the family home with no housing cost.")

	var cheap: HousingDefinition = HousingCatalog.get_by_id(HousingCatalog.CHEAP_ROOM_ID)
	h.eq_string("House-D8 cheap display", cheap.display_name, "Cheap Room")
	h.eq_int("House-D9 cheap cost", cheap.daily_cost, 8)
	h.eq_int("House-D10 cheap age", cheap.minimum_age, 18)
	h.eq_string("House-D11 cheap description",
		cheap.description, "A basic rented room with minimal expenses.")

	var apartment: HousingDefinition = HousingCatalog.get_by_id(HousingCatalog.APARTMENT_ID)
	h.eq_string("House-D12 apartment display", apartment.display_name, "Apartment")
	h.eq_int("House-D13 apartment cost", apartment.daily_cost, 20)
	h.eq_int("House-D14 apartment age", apartment.minimum_age, 21)
	h.eq_string("House-D15 apartment description",
		apartment.description, "A private apartment with more comfort and independence.")

	var nice: HousingDefinition = HousingCatalog.get_by_id(HousingCatalog.NICE_APARTMENT_ID)
	h.eq_string("House-D16 nice display", nice.display_name, "Nice Apartment")
	h.eq_int("House-D17 nice cost", nice.daily_cost, 40)
	h.eq_int("House-D18 nice age", nice.minimum_age, 25)
	h.eq_string("House-D19 nice description",
		nice.description, "A comfortable apartment for an established lifestyle.")


# =====================================================================
# Manual moving across ages
# =====================================================================

static func _moving(h: TestHarness) -> void:
	h.section("House-M")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	h.eq_string("House-M1 fresh home is parents",
		player.housing.current_housing_id, HousingCatalog.PARENTS_ID)
	h.eq_int("House-M2 fresh moves are 0", player.housing.moves_completed, 0)

	_at_age(clock, 17)
	h.eq_bool("House-M3 cheap rejected at 17",
		player.move_to_housing(HousingCatalog.CHEAP_ROOM_ID), false)
	h.eq_string("House-M4 age reason",
		player.evaluate_move_to(HousingCatalog.CHEAP_ROOM_ID)["reason"], "Requires age 18.")
	h.eq_bool("House-M5 apartment rejected at 17",
		player.move_to_housing(HousingCatalog.APARTMENT_ID), false)
	h.eq_bool("House-M6 nice rejected at 17",
		player.move_to_housing(HousingCatalog.NICE_APARTMENT_ID), false)
	h.eq_bool("House-M7 same home rejected",
		player.move_to_housing(HousingCatalog.PARENTS_ID), false)
	h.eq_string("House-M8 same-home reason",
		player.evaluate_move_to(HousingCatalog.PARENTS_ID)["reason"], "You already live here.")

	_at_age(clock, 18)
	h.check("House-M9 cheap move succeeds at 18",
		player.move_to_housing(HousingCatalog.CHEAP_ROOM_ID))
	h.eq_string("House-M10 current is cheap room",
		player.housing.current_housing_id, HousingCatalog.CHEAP_ROOM_ID)
	h.eq_int("House-M11 moves counted", player.housing.moves_completed, 1)
	h.eq_bool("House-M12 repeat move fails",
		player.move_to_housing(HousingCatalog.CHEAP_ROOM_ID), false)
	h.eq_int("House-M13 repeat move uncounted", player.housing.moves_completed, 1)

	_at_age(clock, 21)
	h.check("House-M14 apartment move succeeds at 21",
		player.move_to_housing(HousingCatalog.APARTMENT_ID))
	h.eq_int("House-M15 moves counted", player.housing.moves_completed, 2)

	_at_age(clock, 25)
	h.check("House-M16 nice move succeeds at 25",
		player.move_to_housing(HousingCatalog.NICE_APARTMENT_ID))
	h.eq_int("House-M17 moves counted", player.housing.moves_completed, 3)

	h.eq_bool("House-M18 unknown ID rejected", player.move_to_housing("mansion"), false)
	h.eq_string("House-M19 unknown reason",
		player.evaluate_move_to("mansion")["reason"], "That housing does not exist.")

	# Moving advances zero minutes and disturbs no activity.
	clock.restore(25 * 365, 12, 30)
	var day: int = clock.day
	var time: int = clock.hour * 60 + clock.minute
	h.check("House-M20 move back to cheap succeeds",
		player.move_to_housing(HousingCatalog.CHEAP_ROOM_ID))
	h.eq_int("House-M21 clock day frozen", clock.day, day)
	h.eq_int("House-M22 clock time frozen", clock.hour * 60 + clock.minute, time)

	# Dead players cannot move.
	player.die(PlayerState.CAUSE_STARVATION)
	var dead_eval: Dictionary = player.evaluate_move_to(HousingCatalog.APARTMENT_ID)
	h.eq_bool("House-M23 dead move rejected",
		player.move_to_housing(HousingCatalog.APARTMENT_ID), false)
	h.eq_string("House-M24 dead reason", dead_eval["reason"], "Life has ended.")
	h.eq_string("House-M25 dead home frozen",
		player.housing.current_housing_id, HousingCatalog.CHEAP_ROOM_ID)


# =====================================================================
# Parents selection rule (no eviction, no return at 25+)
# =====================================================================

static func _parents_rule(h: TestHarness) -> void:
	h.section("House-P")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	# Age 24: free return to Parents.
	_at_age(clock, 24)
	h.check("House-P1 cheap at 24", player.move_to_housing(HousingCatalog.CHEAP_ROOM_ID))
	h.check("House-P2 back to parents at 24",
		player.move_to_housing(HousingCatalog.PARENTS_ID))
	h.eq_int("House-P3 return counted", player.housing.moves_completed, 2)

	# Age 25 resident: no eviction, stays valid.
	_at_age(clock, 25)
	h.eq_string("House-P4 resident remains home",
		player.housing.current_housing_id, HousingCatalog.PARENTS_ID)
	h.eq_bool("House-P5 reselecting home fails",
		player.move_to_housing(HousingCatalog.PARENTS_ID), false)

	# Age 25 elsewhere: Parents can never be newly selected.
	h.check("House-P6 apartment at 25", player.move_to_housing(HousingCatalog.APARTMENT_ID))
	var parents_eval: Dictionary = player.evaluate_move_to(HousingCatalog.PARENTS_ID)
	h.eq_bool("House-P7 parents rejected at 25",
		player.move_to_housing(HousingCatalog.PARENTS_ID), false)
	h.eq_string("House-P8 parents reason", parents_eval["reason"],
		"You can no longer move back in with your parents.")

	# Migrated-style senior resident: loads at Parents, may leave once, never
	# return.
	var senior_pair := fresh()
	var senior_clock: GameClock = senior_pair[0]
	var senior: PlayerState = senior_pair[1]
	_at_age(senior_clock, 40)
	SaveManager.save_game(senior_clock, senior, TEST_PATH, FIXED_NOW)
	var senior_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_string("House-P9 senior defaults to parents",
		(senior_data["Housing"] as Dictionary)["CurrentHousingId"], "parents")
	(senior_data["Housing"] as Dictionary)["CurrentHousingId"] = "parents"
	_write(TEST_PATH, JSON.stringify(senior_data))
	var senior_loaded := fresh()
	h.check("House-P10 senior parents save loads",
		SaveManager.load_game(senior_loaded[0], senior_loaded[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_string("House-P11 senior still home",
		senior_loaded[1].housing.current_housing_id, HousingCatalog.PARENTS_ID)
	senior_loaded[1].move_to_housing(HousingCatalog.CHEAP_ROOM_ID)
	h.eq_string("House-P12 senior leaves once",
		senior_loaded[1].housing.current_housing_id, HousingCatalog.CHEAP_ROOM_ID)
	h.eq_bool("House-P13 senior cannot return",
		senior_loaded[1].move_to_housing(HousingCatalog.PARENTS_ID), false)


# =====================================================================
# Payment and shortfall semantics through the engine
# =====================================================================

static func _payments(h: TestHarness) -> void:
	h.section("House-Y")

	# Unit semantics on the domain object.
	var unit := HousingState.new()
	var unit_paid: Dictionary = unit.apply_daily_charge(8, 20)
	h.eq_int("House-Y1 full payment leaves 12", unit_paid["new_money"], 12)
	h.eq_int("House-Y2 full payment recorded", unit.total_paid, 8)
	var unit_short: Dictionary = unit.apply_daily_charge(20, 12)
	h.eq_int("House-Y3 shortfall leaves money", unit_short["new_money"], 12)
	h.eq_int("House-Y4 shortfall accrues fully", unit.outstanding, 20)
	h.eq_int("House-Y5 shortfall misses once", unit.missed_payments, 1)
	unit.apply_daily_charge(20, 12)
	h.eq_int("House-Y6 misses accumulate", unit.missed_payments, 2)
	h.eq_int("House-Y7 outstanding accumulates", unit.outstanding, 40)
	var unit_free: Dictionary = unit.apply_daily_charge(0, 12)
	h.eq_int("House-Y8 zero cost no-op", unit_free["new_money"], 12)
	h.eq_int("House-Y9 zero cost pays nothing", unit.total_paid, 8)

	# Engine: parents ($0) charges nothing across a full day at age 30.
	var home_pair := fresh()
	var home_clock: GameClock = home_pair[0]
	var home: PlayerState = home_pair[1]
	_at_age(home_clock, 30)
	home.advance_simulation(1440)
	h.eq_int("House-Y10 parents pay nothing", home.housing.total_paid, 0)
	h.eq_int("House-Y11 parents miss nothing", home.housing.missed_payments, 0)
	h.eq_int("House-Y12 living still assessed", home.economy.total_paid, 10)

	# Engine: cheap room ($8) with money $20 at age 18.
	var cheap_pair := fresh()
	var cheap_clock: GameClock = cheap_pair[0]
	var cheap: PlayerState = cheap_pair[1]
	_at_age(cheap_clock, 18)
	cheap.move_to_housing(HousingCatalog.CHEAP_ROOM_ID)
	cheap.money = 20
	cheap.advance_simulation(1440)
	h.eq_int("House-Y13 cheap money after day", cheap.money, 20 - 5 - 8)
	h.eq_int("House-Y14 cheap housing paid", cheap.housing.total_paid, 8)
	h.eq_int("House-Y15 cheap living paid", cheap.economy.total_paid, 5)

	# Engine: apartment shortfall keeps money, accrues fully, never negative.
	var short_pair := fresh()
	var short_clock: GameClock = short_pair[0]
	var short: PlayerState = short_pair[1]
	_at_age(short_clock, 30)
	short.move_to_housing(HousingCatalog.APARTMENT_ID)
	short.money = 19
	short.advance_simulation(1440)
	h.eq_int("House-Y16 shortfall money kept", short.money, 9)
	h.eq_int("House-Y17 shortfall housing accrues", short.housing.outstanding, 20)
	h.eq_int("House-Y18 shortfall misses once", short.housing.missed_payments, 1)
	h.eq_int("House-Y19 living paid first", short.economy.total_paid, 10)


# =====================================================================
# Deterministic living-first ordering
# =====================================================================

static func _ordering(h: TestHarness) -> void:
	h.section("House-O")

	# Money $25, age 30, apartment: living $10 wins, housing $20 misses.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_at_age(clock, 30)
	player.move_to_housing(HousingCatalog.APARTMENT_ID)
	player.money = 25
	player.advance_simulation(1440)
	h.eq_int("House-O1 living succeeds first", player.money, 15)
	h.eq_int("House-O2 living paid", player.economy.total_paid, 10)
	h.eq_int("House-O3 living accrues nothing", player.economy.outstanding, 0)
	h.eq_int("House-O4 housing unpaid", player.housing.total_paid, 0)
	h.eq_int("House-O5 housing accrues", player.housing.outstanding, 20)
	h.eq_int("House-O6 housing misses", player.housing.missed_payments, 1)

	# Money $30: both succeed in order, money hits exactly zero.
	var rich_pair := fresh()
	var rich_clock: GameClock = rich_pair[0]
	var rich: PlayerState = rich_pair[1]
	_at_age(rich_clock, 30)
	rich.move_to_housing(HousingCatalog.APARTMENT_ID)
	rich.money = 30
	rich.advance_simulation(1440)
	h.eq_int("House-O7 both charges clear money", rich.money, 0)
	h.eq_int("House-O8 living paid", rich.economy.total_paid, 10)
	h.eq_int("House-O9 housing paid", rich.housing.total_paid, 20)
	h.eq_int("House-O10 nothing outstanding", rich.housing.outstanding + rich.economy.outstanding, 0)


# =====================================================================
# Move-at-midnight semantics: housing at due time rules
# =====================================================================

static func _midnight_moves(h: TestHarness) -> void:
	h.section("House-N")

	# Move at 23:59 charges nothing immediately; the entered day uses the home.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_at_age(clock, 30)
	clock.restore(clock.day, 23, 59)
	player.money = 100
	h.check("House-N1 move to apartment", player.move_to_housing(HousingCatalog.APARTMENT_ID))
	h.eq_int("House-N2 move charges nothing", player.money, 100)
	h.eq_int("House-N3 move pays nothing", player.housing.total_paid, 0)
	player.advance_simulation(1)
	h.eq_int("House-N4 entered day charges apartment", player.housing.total_paid, 20)
	h.eq_int("House-N5 entered day charges living", player.economy.total_paid, 10)
	h.eq_int("House-N6 money after both", player.money, 70)

	# A day assessed at Parents, then moving at 00:01, charges nothing new:
	# the apartment starts at the NEXT entered day.
	var late_pair := fresh()
	var late_clock: GameClock = late_pair[0]
	var late: PlayerState = late_pair[1]
	_at_age(late_clock, 30)
	late.money = 100
	late.advance_simulation(1440)
	h.eq_int("House-N7 parents day pays living only", late.economy.total_paid, 10)
	h.eq_int("House-N8 parents day pays no housing", late.housing.total_paid, 0)
	late_clock.restore(late_clock.day, 0, 1)
	h.check("House-N9 move after assessment", late.move_to_housing(HousingCatalog.APARTMENT_ID))
	h.eq_int("House-N10 no immediate charge", late.housing.total_paid, 0)
	late.advance_simulation(1439)
	h.eq_int("House-N11 next day charges apartment", late.housing.total_paid, 20)


# =====================================================================
# Work across midnight with housing: one path, three steppings
# =====================================================================

static func _work_chronology(h: TestHarness) -> void:
	h.section("House-W")

	# Minute-stepped baseline: 23:00 -> 01:00, laborer, cheap room, age 18.
	var stepped_pair := fresh()
	var stepped_clock: GameClock = stepped_pair[0]
	var stepped: PlayerState = stepped_pair[1]
	_at_age(stepped_clock, 18)
	stepped.apply_for_job(JobCatalog.LABORER_ID)
	stepped.move_to_housing(HousingCatalog.CHEAP_ROOM_ID)
	stepped.start_working()
	stepped_clock.restore(stepped_clock.day, 23, 0)
	for _i in range(120):
		stepped.advance_simulation(1)
	h.eq_int("House-W1 stepped wages across midnight", stepped.money, 1000 + 20 - 5 - 8)
	h.eq_int("House-W2 stepped XP across midnight",
		stepped.career.get_experience(JobCatalog.LABORER_ID), 20)
	h.eq_int("House-W3 stepped living paid", stepped.economy.total_paid, 5)
	h.eq_int("House-W4 stepped housing paid", stepped.housing.total_paid, 8)

	# One bulk call must match minute stepping exactly.
	var bulk_pair := fresh()
	var bulk_clock: GameClock = bulk_pair[0]
	var bulk: PlayerState = bulk_pair[1]
	_at_age(bulk_clock, 18)
	bulk.apply_for_job(JobCatalog.LABORER_ID)
	bulk.move_to_housing(HousingCatalog.CHEAP_ROOM_ID)
	bulk.start_working()
	bulk_clock.restore(bulk_clock.day, 23, 0)
	bulk.bulk_advance_simulation(120)
	h.eq_int("House-W5 bulk money matches", bulk.money, stepped.money)
	h.eq_int("House-W6 bulk XP matches",
		bulk.career.get_experience(JobCatalog.LABORER_ID),
		stepped.career.get_experience(JobCatalog.LABORER_ID))
	h.eq_int("House-W7 bulk living matches", bulk.economy.total_paid, stepped.economy.total_paid)
	h.eq_int("House-W8 bulk housing matches", bulk.housing.total_paid, stepped.housing.total_paid)
	h.eq_int("House-W9 bulk needs match", bulk.thirst, stepped.thirst)

	# Equivalent offline progression must match as well.
	var setup := fresh()
	var setup_clock: GameClock = setup[0]
	var setup_player: PlayerState = setup[1]
	_at_age(setup_clock, 18)
	setup_player.apply_for_job(JobCatalog.LABORER_ID)
	setup_player.move_to_housing(HousingCatalog.CHEAP_ROOM_ID)
	setup_player.start_working()
	setup_clock.restore(setup_clock.day, 23, 0)
	SaveManager.save_game(setup_clock, setup_player, TEST_PATH, FIXED_NOW)
	var offline := fresh()
	h.check("House-W10 offline load succeeds",
		SaveManager.load_game(offline[0], offline[1], TEST_PATH, FIXED_NOW + 30.0)["ok"])
	h.eq_int("House-W11 offline money matches", offline[1].money, stepped.money)
	h.eq_int("House-W12 offline housing matches", offline[1].housing.total_paid, 8)
	h.eq_bool("House-W13 offline still working", offline[1].is_working, true)


# =====================================================================
# Death freezes housing with history retained
# =====================================================================

static func _death(h: TestHarness) -> void:
	h.section("House-X")

	# A dead player crossing hypothetical days incurs nothing.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_at_age(clock, 30)
	player.move_to_housing(HousingCatalog.APARTMENT_ID)
	player.die(PlayerState.CAUSE_STARVATION)
	player.advance_simulation(60 * 24 * 100)
	h.eq_int("House-X1 dead days charge nothing", player.housing.total_paid, 0)
	h.eq_int("House-X2 dead days miss nothing", player.housing.missed_payments, 0)
	h.eq_string("House-X3 dead home recorded",
		player.housing.current_housing_id, HousingCatalog.APARTMENT_ID)

	# Death exactly at the boundary: the day is entered but the fatal segment
	# resolves first, so no housing (or living) charge applies.
	var dying_pair := fresh()
	var dying_clock: GameClock = dying_pair[0]
	var dying: PlayerState = dying_pair[1]
	_at_age(dying_clock, 30)
	dying_clock.restore(dying_clock.day, 23, 0)
	dying.move_to_housing(HousingCatalog.APARTMENT_ID)
	dying.debug_set_health(5.0)
	dying.debug_set_thirst(0)
	dying.debug_set_hunger(100)
	dying.advance_simulation(60)
	h.eq_bool("House-X4 boundary death occurs", dying.is_dead, true)
	h.eq_int("House-X5 boundary day never charged", dying.housing.total_paid, 0)
	h.eq_int("House-X6 boundary living never charged", dying.economy.total_paid, 0)

	# A housing charge assessed on entry survives a later same-day death.
	var charged_pair := fresh()
	var charged_clock: GameClock = charged_pair[0]
	var charged: PlayerState = charged_pair[1]
	_at_age(charged_clock, 30)
	charged_clock.restore(charged_clock.day, 23, 0)
	charged.move_to_housing(HousingCatalog.APARTMENT_ID)
	charged.advance_simulation(60)
	h.eq_int("House-X6 midnight housing applied", charged.housing.total_paid, 20)
	charged.debug_set_health(5.0)
	charged.debug_set_thirst(0)
	charged.advance_simulation(60)
	h.eq_bool("House-X7 later death occurs", charged.is_dead, true)
	h.eq_int("House-X8 valid charge retained", charged.housing.total_paid, 20)
	h.eq_string("House-X9 home survives death",
		charged.housing.current_housing_id, HousingCatalog.APARTMENT_ID)

	# Offline death: no post-death housing charges.
	var off_pair := fresh()
	var off_clock: GameClock = off_pair[0]
	var off: PlayerState = off_pair[1]
	_at_age(off_clock, 30)
	off_clock.restore(off_clock.day, 23, 0)
	off.move_to_housing(HousingCatalog.APARTMENT_ID)
	off.debug_set_health(5.0)
	off.debug_set_thirst(0)
	off.debug_set_hunger(100)
	SaveManager.save_game(off_clock, off, TEST_PATH, FIXED_NOW)
	var off_loaded := fresh()
	SaveManager.load_game(off_loaded[0], off_loaded[1], TEST_PATH, FIXED_NOW + 30.0)
	h.eq_bool("House-X10 offline death occurs", off_loaded[1].is_dead, true)
	h.eq_int("House-X11 unentered day never charged", off_loaded[1].housing.total_paid, 0)


# =====================================================================
# Save Version 14 persistence and migration
# =====================================================================

static func _save_v14(h: TestHarness) -> void:
	h.section("House-S")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_at_age(clock, 30)
	player.move_to_housing(HousingCatalog.APARTMENT_ID)
	player.housing.restore(HousingCatalog.APARTMENT_ID, 400, 60, 3, 2)
	player.economy.restore(500, 20, 2, 46, 5, 2)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_int("House-S1 save version is exactly 14", raw["Version"], 14)
	var stored: Dictionary = raw["Housing"]
	h.eq_string("House-S2 home persisted", stored["CurrentHousingId"], "apartment")
	h.eq_int("House-S3 paid persisted", stored["TotalHousingPaid"], 400)
	h.eq_int("House-S4 outstanding persisted", stored["OutstandingHousing"], 60)
	h.eq_int("House-S5 missed persisted", stored["MissedHousingPayments"], 3)
	h.eq_int("House-S6 moves persisted", stored["MovesCompleted"], 2)

	var loaded := fresh()
	var load_result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW)
	h.check("House-S7 load succeeds", load_result["ok"], load_result["error"])
	h.eq_string("House-S8 home round trips",
		loaded[1].housing.current_housing_id, HousingCatalog.APARTMENT_ID)
	h.eq_int("House-S9 paid round trips", loaded[1].housing.total_paid, 400)
	h.eq_int("House-S10 outstanding round trips", loaded[1].housing.outstanding, 60)
	h.eq_int("House-S11 missed round trips", loaded[1].housing.missed_payments, 3)
	h.eq_int("House-S12 moves round trip", loaded[1].housing.moves_completed, 2)
	h.eq_int("House-S13 living paid intact", loaded[1].economy.total_paid, 500)
	h.eq_int("House-S14 food spent intact", loaded[1].economy.food_drink_spent, 46)

	# v13 migration: housing defaults to parents/zeros, everything else intact.
	var v13_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	v13_data["Version"] = 13
	v13_data.erase("Housing")
	_write(TEST_PATH, JSON.stringify(v13_data))
	var migrated := fresh()
	var migrate_result: Dictionary = SaveManager.load_game(migrated[0], migrated[1], TEST_PATH, FIXED_NOW)
	h.check("House-S15 v13 save still loads", migrate_result["ok"], migrate_result["error"])
	h.eq_string("House-S16 v13 home defaults to parents",
		migrated[1].housing.current_housing_id, HousingCatalog.PARENTS_ID)
	h.eq_int("House-S17 v13 paid defaults to 0", migrated[1].housing.total_paid, 0)
	h.eq_int("House-S18 v13 outstanding defaults to 0", migrated[1].housing.outstanding, 0)
	h.eq_int("House-S19 v13 missed defaults to 0", migrated[1].housing.missed_payments, 0)
	h.eq_int("House-S20 v13 moves default to 0", migrated[1].housing.moves_completed, 0)
	h.eq_int("House-S21 v13 living paid intact", migrated[1].economy.total_paid, 500)

	# v12 migration: same housing defaults with older economy shape.
	# (CareerProgress exists since v11, so it stays; only the v13 food keys
	# and the v14 Housing block are absent.)
	var v12_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	v12_data["Version"] = 12
	v12_data.erase("Housing")
	(v12_data["Economy"] as Dictionary).erase("FoodDrinkSpent")
	(v12_data["Economy"] as Dictionary).erase("MealsPurchased")
	(v12_data["Economy"] as Dictionary).erase("DrinksPurchased")
	_write(TEST_PATH, JSON.stringify(v12_data))
	var legacy := fresh()
	h.check("House-S22 v12 save still loads",
		SaveManager.load_game(legacy[0], legacy[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_int("House-S23 v12 paid defaults to 0", legacy[1].housing.total_paid, 0)


# =====================================================================
# Version 14 validation and transactional rejection
# =====================================================================

static func _validation(h: TestHarness) -> void:
	h.section("House-V")

	var pair := fresh()
	SaveManager.save_game(pair[0], pair[1], TEST_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_PATH)

	# Live state that must survive every rejected load untouched.
	var live := fresh()
	var live_clock: GameClock = live[0]
	var live_player: PlayerState = live[1]
	_at_age(live_clock, 30)
	live_player.money = 4242
	live_player.energy = 61
	live_player.debug_set_hunger(62)
	live_player.debug_set_thirst(63)
	live_player.debug_set_health(42.0)
	live_player.economy.restore(50, 20, 2, 46, 5, 2)
	live_player.move_to_housing(HousingCatalog.APARTMENT_ID)
	live_player.housing.restore(HousingCatalog.APARTMENT_ID, 400, 60, 3, 2)
	live_player.apply_for_job(JobCatalog.LABORER_ID)
	live_player.career.award_experience(JobCatalog.LABORER_ID, 900)
	live_player.start_working()
	live_player.debug_set_thirst(0)
	live_player.advance_simulation(45)
	live_clock.restore(4321, 7, 8)

	var cases: Array = [
		["missing Housing", {"__erase__": "Housing"}],
		["Housing not a dict", {"Housing": []}],
		["missing home id", {"__erase_home__": "CurrentHousingId"}],
		["missing paid", {"__erase_home__": "TotalHousingPaid"}],
		["missing outstanding", {"__erase_home__": "OutstandingHousing"}],
		["missing missed", {"__erase_home__": "MissedHousingPayments"}],
		["missing moves", {"__erase_home__": "MovesCompleted"}],
		["unknown home id", {"__home__": ["CurrentHousingId", "mansion"]}],
		["negative paid", {"__home__": ["TotalHousingPaid", -1]}],
		["negative outstanding", {"__home__": ["OutstandingHousing", -1]}],
		["negative missed", {"__home__": ["MissedHousingPayments", -1]}],
		["negative moves", {"__home__": ["MovesCompleted", -1]}],
		["string paid", {"__home__": ["TotalHousingPaid", "400"]}],
		["boolean moves", {"__home__": ["MovesCompleted", true]}],
		["null outstanding", {"__home__": ["OutstandingHousing", null]}],
		["fractional paid", {"__home__": ["TotalHousingPaid", 400.5]}],
		["overflow moves", {"__home__": ["MovesCompleted", 1.0e30]}],
		["unknown housing field", {"__add_home__": "Rent"}],
	]
	for entry in cases:
		var data: Dictionary = JSON.parse_string(base_text)
		_apply_patch(data, entry[1])
		_write(TEST_PATH, JSON.stringify(data))
		var result: Dictionary = SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)
		h.eq_bool("House-V rejects %s" % entry[0], result["ok"], false)

	h.eq_int("House-V live clock untouched", live_clock.day, 4321)
	h.eq_int("House-V live money untouched", live_player.money, 4242)
	h.eq_int("House-V live energy untouched", live_player.energy, 61)
	h.eq_int("House-V live hunger untouched", live_player.hunger, 62)
	h.eq_int("House-V live thirst untouched", live_player.thirst, 0)
	h.near_float("House-V live health untouched", live_player.health, 42.0)
	h.eq_bool("House-V live death state untouched", live_player.is_dead, false)
	h.eq_bool("House-V live activity untouched", live_player.is_working, true)
	h.eq_string("House-V live career untouched", live_player.career.current_job_id, JobCatalog.LABORER_ID)
	h.eq_int("House-V live labor XP untouched", live_player.career.get_experience(JobCatalog.LABORER_ID), 900)
	h.eq_int("House-V live education untouched",
		live_player.education.status, EducationState.Status.NOT_ENROLLED)
	h.eq_int("House-V live streak untouched", live_player.get_dehydrated_minutes_accumulator(), 45)
	h.eq_int("House-V live paid untouched", live_player.economy.total_paid, 50)
	h.eq_int("House-V live outstanding untouched", live_player.economy.outstanding, 20)
	h.eq_int("House-V live missed untouched", live_player.economy.missed_payments, 2)
	h.eq_int("House-V live spent untouched", live_player.economy.food_drink_spent, 46)
	h.eq_int("House-V live meals untouched", live_player.economy.meals_purchased, 5)
	h.eq_int("House-V live drinks untouched", live_player.economy.drinks_purchased, 2)
	h.eq_string("House-V live home untouched",
		live_player.housing.current_housing_id, HousingCatalog.APARTMENT_ID)
	h.eq_int("House-V live housing paid untouched", live_player.housing.total_paid, 400)
	h.eq_int("House-V live housing outstanding untouched", live_player.housing.outstanding, 60)
	h.eq_int("House-V live housing missed untouched", live_player.housing.missed_payments, 3)
	h.eq_int("House-V live moves untouched", live_player.housing.moves_completed, 2)

	# Whole-float interop and the legal parents-at-40 state both load.
	var whole: Dictionary = JSON.parse_string(base_text)
	(whole["Housing"] as Dictionary)["MovesCompleted"] = 2.0
	_write(TEST_PATH, JSON.stringify(whole))
	var whole_loaded := fresh()
	h.check("House-V whole-float moves load",
		SaveManager.load_game(whole_loaded[0], whole_loaded[1], TEST_PATH, FIXED_NOW)["ok"])

	var senior: Dictionary = JSON.parse_string(base_text)
	senior["Day"] = 40 * 365
	(senior["Housing"] as Dictionary)["CurrentHousingId"] = "parents"
	_write(TEST_PATH, JSON.stringify(senior))
	var senior_loaded := fresh()
	h.check("House-V parents at 40 loads",
		SaveManager.load_game(senior_loaded[0], senior_loaded[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_string("House-V senior home intact",
		senior_loaded[1].housing.current_housing_id, HousingCatalog.PARENTS_ID)


static func _apply_patch(data: Dictionary, patch: Dictionary) -> void:
	for key in patch:
		if key == "__erase__":
			data.erase(patch[key])
		elif key == "__erase_home__":
			(data["Housing"] as Dictionary).erase(patch[key])
		elif key == "__home__":
			var home_patch: Array = patch[key]
			(data["Housing"] as Dictionary)[home_patch[0]] = home_patch[1]
		elif key == "__add_home__":
			(data["Housing"] as Dictionary)[patch[key]] = 0
		else:
			data[key] = patch[key]


# =====================================================================
# Offline example: saved state + two living days
# =====================================================================

static func _offline_example(h: TestHarness) -> void:
	h.section("House-OL")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_at_age(clock, 30)
	player.move_to_housing(HousingCatalog.APARTMENT_ID)
	player.money = 100
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	# Two offline game days (720 real seconds): living $10 then housing $20,
	# twice, with survivable needs.
	var loaded := fresh()
	var result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW + 720.0)
	h.check("House-OL1 offline load succeeds", result["ok"], result["error"])
	h.eq_int("House-OL2 money after two days", loaded[1].money, 40)
	h.eq_int("House-OL3 living paid twice", loaded[1].economy.total_paid, 20)
	h.eq_int("House-OL4 housing paid twice", loaded[1].housing.total_paid, 40)
	h.eq_int("House-OL5 nothing outstanding", loaded[1].housing.outstanding, 0)
	h.eq_int("House-OL6 nothing missed", loaded[1].housing.missed_payments, 0)
	h.eq_bool("House-OL7 offline survivor lives", loaded[1].is_dead, false)

	# The identical active simulation must produce the identical state.
	var active := fresh()
	var active_clock: GameClock = active[0]
	var active_player: PlayerState = active[1]
	_at_age(active_clock, 30)
	active_player.move_to_housing(HousingCatalog.APARTMENT_ID)
	active_player.money = 100
	TestHarness.advance_kept_alive(active_player, 60 * 24 * 2)
	h.eq_int("House-OL8 active money matches", active_player.money, loaded[1].money)
	h.eq_int("House-OL9 active living matches", active_player.economy.total_paid, 20)
	h.eq_int("House-OL10 active housing matches", active_player.housing.total_paid, 40)


# =====================================================================
# God Mode housing helper
# =====================================================================

static func _godmode(h: TestHarness) -> void:
	h.section("House-G")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_at_age(clock, 30)
	player.move_to_housing(HousingCatalog.APARTMENT_ID)
	player.housing.restore(HousingCatalog.APARTMENT_ID, 400, 60, 3, 2)
	player.economy.restore(50, 20, 2, 46, 5, 2)
	var god := GodMode.new(clock, player)

	var idle_god := GodMode.new(clock, player)
	h.eq_bool("House-G1 disabled tool fails", idle_god.clear_housing_debt()["ok"], false)

	god.set_enabled(true)
	var result: Dictionary = god.clear_housing_debt()
	h.eq_bool("House-G2 clear succeeds", result["ok"], true)
	h.eq_int("House-G3 outstanding cleared", player.housing.outstanding, 0)
	h.eq_int("House-G4 paid untouched", player.housing.total_paid, 400)
	h.eq_int("House-G5 missed untouched", player.housing.missed_payments, 3)
	h.eq_int("House-G6 moves untouched", player.housing.moves_completed, 2)
	h.eq_string("House-G7 home untouched",
		player.housing.current_housing_id, HousingCatalog.APARTMENT_ID)
	h.eq_int("House-G8 money untouched", player.money, 1000)
	h.eq_int("House-G9 living outstanding untouched", player.economy.outstanding, 20)
	h.eq_int("House-G10 food stats untouched", player.economy.food_drink_spent, 46)
	h.eq_int("House-G11 clock untouched", clock.day, 30 * 365)

	player.die(PlayerState.CAUSE_STARVATION)
	var dead: Dictionary = god.clear_housing_debt()
	h.eq_bool("House-G12 dead fails cleanly", dead["ok"], false)
	h.eq_string("House-G13 dead message", dead["message"], "Life has ended.")


static func _write(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(text)
	file.close()
	return {"ok": true}
