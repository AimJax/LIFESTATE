extends RefCounted

## Health + Death foundation coverage (Godot-only, Save Version 10+).## Sections: health defaults/clamps, deprivation damage with exact hourly
## semantics, cause precedence, the centralized death transition, dead action
## and reward locks, deterministic old-age mortality, offline death correctness,
## God Mode health tools, and v10 save validation.

const TEST_PATH: String = "user://test_health_death.json"
const FIXED_NOW: float = 1791000000.0


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func run(h: TestHarness) -> void:
	_health_basics(h)
	_deprivation_damage(h)
	_cause_precedence(h)
	_death_transition(h)
	_action_locks(h)
	_reward_locks(h)
	_mortality_table(h)
	_mortality_determinism(h)
	_mortality_death_path(h)
	_god_mode_tools(h)
	_god_mode_mortality_semantics(h)
	_offline_death(h)
	_offline_work_study_cutoff(h)
	_offline_event_cutoff(h)
	_save_v10_round_trip(h)
	_save_v10_invalid(h)
	_legacy_life_seed_migration(h)
	_normal_bulk_equivalence(h)
	_deprivation_persistence(h)


# =====================================================================
# Health basics
# =====================================================================

static func _health_basics(h: TestHarness) -> void:
	h.section("Life-H")

	var pair := fresh()
	var player: PlayerState = pair[1]

	h.near_float("Life-H1 default health is 100", player.health, 100.0)
	h.eq_bool("Life-H2 newborn is alive", player.is_dead, false)
	h.eq_int("Life-H3 living death day default", player.death_day, -1)
	h.eq_int("Life-H4 living death age default", player.death_age, -1)
	h.eq_string("Life-H5 living cause default", player.cause_of_death, "")

	player.debug_set_health(150.0)
	h.near_float("Life-H6 health clamps to 100", player.health, 100.0)
	player.debug_set_health(40.0)
	h.near_float("Life-H7 health can be lowered", player.health, 40.0)
	player.debug_set_health(-5.0)
	h.near_float("Life-H8 health clamps to 0", player.health, 0.0)

	h.eq_string("Life-H9 dehydration displays", PlayerState.display_cause(PlayerState.CAUSE_DEHYDRATION), "Dehydration")
	h.eq_string("Life-H10 starvation displays", PlayerState.display_cause(PlayerState.CAUSE_STARVATION), "Starvation")
	h.eq_string("Life-H11 old age displays", PlayerState.display_cause(PlayerState.CAUSE_OLD_AGE), "Old Age")


# =====================================================================
# Deprivation damage (deterministic hourly semantics)
# =====================================================================

static func _deprivation_damage(h: TestHarness) -> void:
	h.section("Life-D")

	# The ticket's exact partial-hour example: hunger 0, 59 minutes = no damage.
	var pair := fresh()
	var player: PlayerState = pair[1]
	player.debug_set_hunger(0)
	player.debug_set_thirst(100)
	player.advance_simulation(59)
	h.near_float("Life-D1 59 starving minutes deal no damage", player.health, 100.0)
	player.advance_simulation(1)
	h.near_float("Life-D2 completing the hour deals -2", player.health, 98.0)

	# Thirst-only: -5 per completed hour.
	var thirst_pair := fresh()
	var thirsty: PlayerState = thirst_pair[1]
	thirsty.debug_set_thirst(0)
	thirsty.debug_set_hunger(100)
	thirsty.advance_simulation(60)
	h.near_float("Life-D3 one dehydrated hour deals -5", thirsty.health, 95.0)

	# Both zero: streams add independently to -7 per hour.
	var both_pair := fresh()
	var both: PlayerState = both_pair[1]
	both.debug_set_hunger(0)
	both.debug_set_thirst(0)
	both.advance_simulation(60)
	h.near_float("Life-D4 both-zero hour deals -7", both.health, 93.0)

	# Low-but-positive needs never damage.
	var safe_pair := fresh()
	var safe: PlayerState = safe_pair[1]
	safe.debug_set_hunger(50)
	safe.debug_set_thirst(50)
	safe.debug_set_health(50.0)
	safe.advance_simulation(60 * 10)
	h.near_float("Life-D5 positive needs deal no damage", safe.health, 50.0)

	# Multiple hours accumulate deterministically.
	var multi_pair := fresh()
	var multi: PlayerState = multi_pair[1]
	multi.debug_set_thirst(0)
	multi.debug_set_hunger(100)
	multi.debug_set_health(50.0)
	multi.advance_simulation(60 * 3 + 59)
	h.near_float("Life-D6 three completed hours -15, partial hour nothing", multi.health, 35.0)
	multi.advance_simulation(1)
	h.near_float("Life-D7 fourth hour completes to -20", multi.health, 30.0)

	# Eating/drinking resets the deprivation streak: the reaching-hour rule
	# applies again after restoration.
	var restore_pair := fresh()
	var restored: PlayerState = restore_pair[1]
	restored.debug_set_thirst(0)
	restored.debug_set_hunger(100)
	restored.debug_set_health(50.0)
	restored.advance_simulation(60)
	restored.drink(20)
	restored.debug_set_thirst(0)
	restored.advance_simulation(59)
	h.near_float("Life-D8 restored streak restarts cleanly", restored.health, 45.0)


# =====================================================================
# Cause precedence
# =====================================================================

static func _cause_precedence(h: TestHarness) -> void:
	h.section("Life-P")

	# Fatal hour with thirst deprivation active: dehydration wins even when
	# hunger is also zero.
	var both_pair := fresh()
	var both: PlayerState = both_pair[1]
	both.debug_set_hunger(0)
	both.debug_set_thirst(0)
	both.debug_set_health(10.0)
	both.advance_simulation(60 * 2)
	h.eq_bool("Life-P1 both-zero death occurs", both.is_dead, true)
	h.eq_string("Life-P2 both-zero cause is dehydration", both.cause_of_death, PlayerState.CAUSE_DEHYDRATION)

	# Fatal hour with only hunger deprivation active: starvation.
	var starve_pair := fresh()
	var starve: PlayerState = starve_pair[1]
	starve.debug_set_hunger(0)
	starve.debug_set_thirst(50)
	starve.debug_set_health(4.0)
	starve.advance_simulation(60 * 2)
	h.eq_bool("Life-P3 thirst-safe death occurs", starve.is_dead, true)
	h.eq_string("Life-P4 thirst-safe cause is starvation", starve.cause_of_death, PlayerState.CAUSE_STARVATION)

	# Thirst merely REACHING zero at the fatal hour's end does not steal cause
	# from an active starvation hour: hunger 0, thirst 2, health 10.
	# Hour 1: thirst 2->0 (reaching hour), starvation -2 -> 8.
	# Hour 2: both zero -7 -> 1. Hour 3: both zero -7 -> 0 fatal => dehydration.
	var cross_pair := fresh()
	var cross: PlayerState = cross_pair[1]
	cross.debug_set_hunger(0)
	cross.debug_set_thirst(2)
	cross.debug_set_health(10.0)
	cross.advance_simulation(60 * 3)
	h.eq_string("Life-P5 both-zero fatal hour is dehydration", cross.cause_of_death, PlayerState.CAUSE_DEHYDRATION)


# =====================================================================
# Centralized death transition
# =====================================================================

static func _death_transition(h: TestHarness) -> void:
	h.section("Life-X")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 20 * 365)
	player.apply_for_job(JobCatalog.LABORER_ID)
	player.start_working()
	player.stop_working()
	player.start_studying()
	# Deprivation setup BEFORE the fatal hour, while still alive.
	player.debug_set_health(4.0)
	player.debug_set_thirst(0)

	player.advance_simulation(60)

	# Die through the real transition (deprivation path, not direct flags).
	player.debug_set_thirst(0)
	player.debug_set_health(4.0)
	player.advance_simulation(60)

	h.eq_bool("Life-X2 is_dead set", player.is_dead, true)
	h.near_float("Life-X3 health floored at 0", player.health, 0.0)
	h.eq_int("Life-X4 death day recorded", player.death_day, clock.day)
	h.eq_int("Life-X5 death age recorded", player.death_age, player.age)
	h.eq_string("Life-X6 cause recorded", player.cause_of_death, PlayerState.CAUSE_DEHYDRATION)
	h.eq_bool("Life-X7 all activities stopped", player.is_active(), false)

	# Duplicate death is rejected and never overwrites the original record.
	var death_day: int = player.death_day
	var death_age: int = player.death_age
	var cause: String = player.cause_of_death
	advance_days(clock, 100)
	h.eq_bool("Life-X8 duplicate die rejected", player.die(PlayerState.CAUSE_OLD_AGE), false)
	h.eq_bool("Life-X9 unknown cause rejected", player.die("fall"), false)
	h.eq_int("Life-X10 original death day preserved", player.death_day, death_day)
	h.eq_int("Life-X11 original death age preserved", player.death_age, death_age)
	h.eq_string("Life-X12 original cause preserved", player.cause_of_death, cause)

	# Health can never be restored after death (no resurrection).
	player.debug_set_health(100.0)
	player.debug_restore_needs()
	h.near_float("Life-X13 dead health stays 0", player.health, 0.0)


# =====================================================================
# Dead action locks (domain guards, not UI-only)
# =====================================================================

static func _action_locks(h: TestHarness) -> void:
	h.section("Life-L")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 20 * 365)
	player.apply_for_job(JobCatalog.LABORER_ID)
	player.education.restore(EducationState.Status.COMPLETED_PRIMARY, 6, 100, 0)
	player.die(PlayerState.CAUSE_OLD_AGE)

	var money_before: int = player.money
	var job_before: String = player.career.current_job_id
	var status_before: int = player.education.status

	player.eat(50)
	player.drink(50)
	h.eq_int("Life-L1 eat rejected", player.hunger, 100)
	h.eq_int("Life-L2 drink rejected", player.thirst, 100)

	player.start_sleeping()
	h.eq_bool("Life-L3 sleep rejected", player.is_sleeping, false)
	player.start_working()
	h.eq_bool("Life-L4 work rejected", player.is_working, false)
	player.start_studying()
	h.eq_bool("Life-L5 study rejected", player.is_studying, false)
	h.eq_bool("Life-L6 play rejected", player.start_playing(), false)
	h.eq_bool("Life-L7 family time rejected", player.start_family_time(), false)

	h.eq_bool("Life-L8 primary enrollment rejected", player.enroll_primary_school(), false)
	h.eq_bool("Life-L9 secondary enrollment rejected", player.enroll_secondary_school(), false)
	h.eq_bool("Life-L10 job application rejected", player.apply_for_job(JobCatalog.LABORER_ID), false)
	h.eq_bool("Life-L11 quit rejected", player.quit_job(), false)
	h.eq_bool("Life-L12 event choice rejected", player.resolve_event_choice(LifeEventCatalog.KEEP_MONEY), false)

	player.debug_add_money(1000)
	h.eq_int("Life-L13 god money rejected", player.money, money_before)

	h.eq_string("Life-L14 career retained at death", player.career.current_job_id, job_before)
	h.eq_int("Life-L15 education retained at death", player.education.status, status_before)
	h.check("Life-L16 relationships retained at death",
		player.relationships.mother_relationship.closeness > 0.0)


# =====================================================================
# Dead reward locks (no money/XP/progress from elapsed time)
# =====================================================================

static func _reward_locks(h: TestHarness) -> void:
	h.section("Life-R")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 20 * 365)
	player.apply_for_job(JobCatalog.LABORER_ID)
	player.start_working()
	player.die(PlayerState.CAUSE_OLD_AGE)

	var money: int = player.money
	var xp: int = player.study_xp
	var academics: int = player.skills.academics.experience
	var day: int = clock.day
	var play_hours: int = player.total_play_hours
	var closeness: float = player.relationships.mother_relationship.closeness

	var rewards: Dictionary = player.advance_simulation(60 * 24 * 30)
	h.eq_int("Life-R1 dead advance earns no money", player.money, money)
	h.eq_int("Life-R2 dead advance earns no StudyXP", player.study_xp, xp)
	h.eq_int("Life-R3 dead advance earns no Academics XP", player.skills.academics.experience, academics)
	h.eq_int("Life-R4 dead advance earns no play hours", player.total_play_hours, play_hours)
	h.near_float("Life-R5 dead advance earns no closeness", player.relationships.mother_relationship.closeness, closeness)
	h.eq_int("Life-R6 dead clock frozen", clock.day, day)
	h.eq_int("Life-R7 dead advance reports zero rewards", rewards["money_earned"], 0)

	var bulk: Dictionary = player.bulk_advance_simulation(60 * 24 * 365)
	h.eq_int("Life-R8 dead bulk earns nothing", bulk["money_earned"], 0)
	h.eq_int("Life-R9 dead bulk clock still frozen", clock.day, day)


# =====================================================================
# Mortality probability table (exact)
# =====================================================================

static func _mortality_table(h: TestHarness) -> void:
	h.section("Life-M")

	var expectations: Array = [
		[59, 0.0], [60, 0.00002], [69, 0.00002], [70, 0.0001], [79, 0.0001],
		[80, 0.0005], [89, 0.0005], [90, 0.002], [99, 0.002], [100, 0.0075],
		[109, 0.0075], [110, 0.02], [130, 0.02],
	]
	for entry in expectations:
		h.near_float("Life-M age %d probability" % entry[0],
			PlayerState.daily_mortality_probability(entry[0]), entry[1], 0.0000001)


# =====================================================================
# Mortality determinism (same seed + day = same roll)
# =====================================================================

static func _mortality_determinism(h: TestHarness) -> void:
	h.section("Life-MD")

	var roll_a: float = PlayerState.mortality_roll(12345, 40000)
	var roll_b: float = PlayerState.mortality_roll(12345, 40000)
	var roll_c: float = PlayerState.mortality_roll(12345, 40000)
	h.near_float("Life-MD1 same seed and day is stable", roll_a, roll_b, 0.0)
	h.near_float("Life-MD2 repeated calls are stable", roll_a, roll_c, 0.0)
	h.check("Life-MD3 roll is in [0, 1)", roll_a >= 0.0 and roll_a < 1.0, str(roll_a))

	# Changing the day changes the roll (chosen fixtures, not a universal claim).
	var changed_day: float = PlayerState.mortality_roll(12345, 40001)
	h.check("Life-MD4 changing day changes the roll", changed_day != roll_a,
		"%f vs %f" % [roll_a, changed_day])

	# Changing the seed changes the roll (chosen fixtures).
	var changed_seed: float = PlayerState.mortality_roll(54321, 40000)
	h.check("Life-MD5 changing seed changes the roll", changed_seed != roll_a,
		"%f vs %f" % [roll_a, changed_seed])


# =====================================================================
# Mortality death path (deterministic fixtures per age band)
# =====================================================================

## Finds a day inside the age-110+ band whose mortality roll fires for the seed.
static func _find_deadly_day(seed_value: int) -> int:
	for day in range(110 * 365, 111 * 365):
		if PlayerState.mortality_roll(seed_value, day) < PlayerState.daily_mortality_probability(110):
			return day
	return -1


## Finds a day inside the age-110+ band whose mortality roll survives.
static func _find_safe_day(seed_value: int) -> int:
	for day in range(110 * 365, 111 * 365):
		if PlayerState.mortality_roll(seed_value, day) >= PlayerState.daily_mortality_probability(110):
			return day
	return -1


static func _mortality_death_path(h: TestHarness) -> void:
	h.section("Life-MA")

	var seed_value: int = 424242
	var deadly_day: int = _find_deadly_day(seed_value)
	var safe_day: int = _find_safe_day(seed_value)
	h.check("Life-MA0 deadly fixture exists in the 110+ band", deadly_day > 0, str(deadly_day))
	h.check("Life-MA0a safe fixture exists in the 110+ band", safe_day > 0, str(safe_day))
	if deadly_day <= 0 or safe_day <= 0:
		return

	# Survival: crossing a safe midnight at 110+ does not kill.
	var safe_pair := fresh()
	var safe_clock: GameClock = safe_pair[0]
	var safe_player: PlayerState = safe_pair[1]
	safe_player.debug_set_life_seed(seed_value)
	safe_clock.restore(safe_day - 1, 23, 0)
	safe_player.advance_simulation(120)
	h.check("Life-MA1 safe midnight does not kill", not safe_player.is_dead)
	h.eq_int("Life-MA1a clock crossed the midnight", safe_clock.day, safe_day)

	# Death: crossing the deadly midnight at 110+ kills via the real transition.
	var deadly_pair := fresh()
	var deadly_clock: GameClock = deadly_pair[0]
	var deadly_player: PlayerState = deadly_pair[1]
	deadly_player.debug_set_life_seed(seed_value)
	deadly_clock.restore(deadly_day - 1, 23, 0)
	deadly_player.advance_simulation(120)
	h.eq_bool("Life-MA2 deadly midnight kills", deadly_player.is_dead, true)
	h.eq_string("Life-MA3 cause is old age", deadly_player.cause_of_death, PlayerState.CAUSE_OLD_AGE)
	h.eq_int("Life-MA4 death day is the deadly day", deadly_player.death_day, deadly_day)
	h.eq_int("Life-MA5 death age is 110", deadly_player.death_age, 110)
	h.near_float("Life-MA6 old-age death keeps health", deadly_player.health, 0.0)

	# Mortality is evaluated exactly once per day: living through the same day
	# again cannot re-roll (the pointer already passed it).
	h.eq_bool("Life-MA7 death is final after the roll", deadly_player.die(PlayerState.CAUSE_OLD_AGE), false)

	# Below-60 players never roll mortality.
	var young_pair := fresh()
	var young_clock: GameClock = young_pair[0]
	var young_player: PlayerState = young_pair[1]
	young_player.debug_set_life_seed(seed_value)
	advance_days(young_clock, 50 * 365)
	h.check("Life-MA8 age 50 with needs kept alive never dies of old age", not young_player.is_dead)


# =====================================================================
# God Mode health tools
# =====================================================================

static func _god_mode_tools(h: TestHarness) -> void:
	h.section("God-Life")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	var god := GodMode.new(clock, player)

	h.eq_string("God-Life1 disabled set_health rejected", god.set_health(10.0)["message"], "God Mode is disabled.")
	h.eq_string("God-Life2 disabled set_hunger rejected", god.set_hunger(0)["message"], "God Mode is disabled.")
	h.eq_string("God-Life3 disabled set_thirst rejected", god.set_thirst(0)["message"], "God Mode is disabled.")
	h.eq_string("God-Life4 disabled force death rejected", god.force_old_age_death()["message"], "God Mode is disabled.")
	h.near_float("God-Life5 no health change while disabled", player.health, 100.0)

	god.set_enabled(true)
	h.eq_bool("God-Life6 set_health applies", god.set_health(10.0)["ok"], true)
	h.near_float("God-Life7 health is 10", player.health, 10.0)
	h.eq_bool("God-Life8 set_hunger applies", god.set_hunger(0)["ok"], true)
	h.eq_int("God-Life9 hunger is 0", player.hunger, 0)
	h.eq_bool("God-Life10 set_thirst applies", god.set_thirst(0)["ok"], true)
	h.eq_int("God-Life11 thirst is 0", player.thirst, 0)

	h.eq_bool("God-Life12 force old age death applies", god.force_old_age_death()["ok"], true)
	h.eq_bool("God-Life13 player is dead", player.is_dead, true)
	h.eq_string("God-Life14 cause is old age", player.cause_of_death, PlayerState.CAUSE_OLD_AGE)

	# God Mode can never resurrect: every tool rejects with the terminal message.
	h.eq_string("God-Life15 set_health rejected while dead", god.set_health(100.0)["message"], "Life has ended.")
	h.eq_string("God-Life16 set_hunger rejected while dead", god.set_hunger(100)["message"], "Life has ended.")
	h.eq_string("God-Life17 set_thirst rejected while dead", god.set_thirst(100)["message"], "Life has ended.")
	h.eq_string("God-Life18 force death rejected while dead", god.force_old_age_death()["message"], "Life has ended.")
	h.near_float("God-Life19 health stays 0", player.health, 0.0)
	player.debug_restore_needs()
	h.near_float("God-Life21 needs unchanged while dead", player.thirst, 0.0)


static func _god_mode_mortality_semantics(h: TestHarness) -> void:
	h.section("God-Mort")

	# God Mode time skips must NEVER kill, even deep in the mortality band.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	var god := GodMode.new(clock, player)
	god.set_enabled(true)
	player.debug_set_life_seed(424242)

	god.advance_days(115 * 365)
	h.check("God-Mort1 skip to 115 never kills", not player.is_dead)
	h.eq_int("God-Mort2 age follows the skip", player.age, 115)

	# The skipped days are marked resolved: a subsequent engine step at the same
	# age does not retroactively evaluate them either.
	player.debug_set_thirst(100)
	player.debug_set_hunger(100)
	player.advance_simulation(60 * 24)
	h.check("God-Mort3 engine step after skip does not retro-kill", not player.is_dead)

	# But a genuinely lived midnight at a deadly day still kills.
	var deadly_day: int = _find_deadly_day(424242)
	clock.restore(deadly_day - 1, 23, 0)
	player.sync_mortality_to_clock()
	player.advance_simulation(120)
	h.eq_bool("God-Mort4 real midnight still evaluates mortality", player.is_dead, true)


# =====================================================================
# Offline death (exact fatal timing, not interval end)
# =====================================================================

static func _offline_death(h: TestHarness) -> void:
	h.section("Off-D")

	# Starvation: Health 10, hunger 0, thirst safe. 20 game hours offline must
	# die after 5 fatal damage hours (10 / 2), not at hour 20.
	var starve_pair := fresh()
	var starve_clock: GameClock = starve_pair[0]
	var starve: PlayerState = starve_pair[1]
	starve.debug_set_health(10.0)
	starve.debug_set_hunger(0)
	starve.debug_set_thirst(100)
	starve_clock.restore(500, 6, 0)
	SaveManager.save_game(starve_clock, starve, TEST_PATH, FIXED_NOW)

	var starve_loaded := fresh()
	var starve_result: Dictionary = SaveManager.load_game(
		starve_loaded[0], starve_loaded[1], TEST_PATH, FIXED_NOW + 20 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	h.check("Off-D1 starvation offline load succeeds", starve_result["ok"], starve_result["error"])
	h.eq_bool("Off-D2 starvation offline death occurs", starve_loaded[1].is_dead, true)
	h.eq_string("Off-D3 cause is starvation", starve_loaded[1].cause_of_death, PlayerState.CAUSE_STARVATION)
	# Death after 5 damage hours: day 500 11:00, not day 501 02:00.
	h.eq_int("Off-D4 death lands at the fatal hour", starve_loaded[0].day, 500)
	h.eq_int("Off-D5 death clock minute exact", starve_loaded[0].hour, 11)
	h.near_float("Off-D6 health floored", starve_loaded[1].health, 0.0)

	# Dehydration: Health 20, thirst 0, hunger safe. Dies after 4 fatal hours.
	var dehyd_pair := fresh()
	var dehyd_clock: GameClock = dehyd_pair[0]
	var dehyd: PlayerState = dehyd_pair[1]
	dehyd.debug_set_health(20.0)
	dehyd.debug_set_thirst(0)
	dehyd.debug_set_hunger(100)
	dehyd_clock.restore(500, 6, 0)
	SaveManager.save_game(dehyd_clock, dehyd, TEST_PATH, FIXED_NOW)

	var dehyd_loaded := fresh()
	SaveManager.load_game(dehyd_loaded[0], dehyd_loaded[1], TEST_PATH,
		FIXED_NOW + 48 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	h.eq_bool("Off-D7 dehydration offline death occurs", dehyd_loaded[1].is_dead, true)
	h.eq_string("Off-D8 cause is dehydration", dehyd_loaded[1].cause_of_death, PlayerState.CAUSE_DEHYDRATION)
	h.eq_int("Off-D9 death after 4 fatal hours, not 48", dehyd_loaded[0].hour, 10)

	# Both-zero: dehydration precedence offline too.
	var both_pair := fresh()
	var both_clock: GameClock = both_pair[0]
	var both: PlayerState = both_pair[1]
	both.debug_set_health(10.0)
	both.debug_set_hunger(0)
	both.debug_set_thirst(0)
	both_clock.restore(500, 6, 0)
	SaveManager.save_game(both_clock, both, TEST_PATH, FIXED_NOW)
	var both_loaded := fresh()
	SaveManager.load_game(both_loaded[0], both_loaded[1], TEST_PATH,
		FIXED_NOW + 20 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	h.eq_string("Off-D10 both-zero offline cause is dehydration", both_loaded[1].cause_of_death, PlayerState.CAUSE_DEHYDRATION)

	# Need CROSSES zero during the interval: damage starts the hour after the
	# reaching hour. Thirst 10 -> 0 at hour 5; 19 damage hours at -5 leaves 5.
	var cross_pair := fresh()
	var cross_clock: GameClock = cross_pair[0]
	var cross: PlayerState = cross_pair[1]
	cross.debug_set_health(100.0)
	cross.debug_set_thirst(10)
	cross.debug_set_hunger(100)
	cross_clock.restore(500, 6, 0)
	SaveManager.save_game(cross_clock, cross, TEST_PATH, FIXED_NOW)
	var cross_loaded := fresh()
	SaveManager.load_game(cross_loaded[0], cross_loaded[1], TEST_PATH,
		FIXED_NOW + 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	h.eq_bool("Off-D11 crossing death does not occur within 24h", cross_loaded[1].is_dead, false)
	h.near_float("Off-D12 damage began at the correct hour", cross_loaded[1].health, 5.0)

	# An already-dead save ignores offline elapsed time entirely. The dead state
	# is installed BEFORE the clock restore: restore_life_state syncs the death
	# record to the clock (DeathDay == Day), and the dead engine step is a no-op.
	var dead_pair := fresh()
	var dead_clock: GameClock = dead_pair[0]
	var dead: PlayerState = dead_pair[1]
	dead_clock.restore(700, 9, 30)
	dead.die(PlayerState.CAUSE_OLD_AGE)
	SaveManager.save_game(dead_clock, dead, TEST_PATH, FIXED_NOW)
	var dead_loaded := fresh()
	SaveManager.load_game(dead_loaded[0], dead_loaded[1], TEST_PATH, FIXED_NOW + 1.0e12)
	h.eq_int("Off-D13 dead clock unchanged by huge offline", dead_loaded[0].day, 700)
	h.eq_int("Off-D14 dead clock time unchanged", dead_loaded[0].hour * 60 + dead_loaded[0].minute, 9 * 60 + 30)
	h.eq_bool("Off-D15 dead state persists", dead_loaded[1].is_dead, true)
	h.eq_string("Off-D16 dead cause persists", dead_loaded[1].cause_of_death, PlayerState.CAUSE_OLD_AGE)


static func _offline_work_study_cutoff(h: TestHarness) -> void:
	h.section("Off-C")

	# Employed Laborer, working, thirst 0, health 20: death after 4 game hours.
	# Wages are earned only for the 4 completed work hours BEFORE death. The
	# clock is restored BEFORE hiring/working so the save day is fixed (no
	# pending event can be born after a later rewind).
	var work_pair := fresh()
	var work_clock: GameClock = work_pair[0]
	var work: PlayerState = work_pair[1]
	work_clock.restore(500, 6, 0)
	advance_days(work_clock, 19 * 365)
	work.apply_for_job(JobCatalog.LABORER_ID)
	work.start_working()
	work.debug_set_health(20.0)
	work.debug_set_thirst(0)
	work.debug_set_hunger(100)
	SaveManager.save_game(work_clock, work, TEST_PATH, FIXED_NOW)
	var money_at_save: int = work.money
	var day_at_save: int = work_clock.day

	var work_loaded := fresh()
	SaveManager.load_game(work_loaded[0], work_loaded[1], TEST_PATH,
		FIXED_NOW + 20 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	h.eq_bool("Off-C1 offline work death occurs", work_loaded[1].is_dead, true)
	h.eq_int("Off-C2 wages stop exactly at death", work_loaded[1].money, money_at_save + 40)
	h.eq_bool("Off-C2a death lands 4 game hours after the save", work_loaded[0].day, day_at_save)
	h.eq_int("Off-C2b death hour exact", work_loaded[0].hour, 10)
	h.eq_bool("Off-C3 work activity stopped by death", work_loaded[1].is_working, false)
	h.eq_string("Off-C4 career employment retained", work_loaded[1].career.current_job_id, JobCatalog.LABORER_ID)
	h.eq_string("Off-C5 cause is dehydration", work_loaded[1].cause_of_death, PlayerState.CAUSE_DEHYDRATION)

	# Studying player dies halfway: only pre-death StudyXP/progress. The clock
	# is advanced BEFORE enrollment so school_year_start_day <= save day (no
	# rewind: an earlier clock than the enrollment day would fail validation).
	var study_pair := fresh()
	var study_clock: GameClock = study_pair[0]
	var study: PlayerState = study_pair[1]
	study_clock.restore(500, 6, 0)
	advance_days(study_clock, 6 * 365)
	study.enroll_primary_school()
	study.start_studying()
	study.debug_set_health(20.0)
	study.debug_set_thirst(0)
	study.debug_set_hunger(100)
	SaveManager.save_game(study_clock, study, TEST_PATH, FIXED_NOW)

	var study_loaded := fresh()
	SaveManager.load_game(study_loaded[0], study_loaded[1], TEST_PATH,
		FIXED_NOW + 20 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	h.eq_bool("Off-C6 offline study death occurs", study_loaded[1].is_dead, true)
	h.eq_int("Off-C7 StudyXP stops exactly at death", study_loaded[1].study_xp, 40)
	h.eq_int("Off-C8 education progress stops exactly at death", study_loaded[1].education.education_progress, 4)
	h.eq_bool("Off-C9 study activity stopped by death", study_loaded[1].is_studying, false)


static func _offline_event_cutoff(h: TestHarness) -> void:
	h.section("Off-E")

	# A player saved just before their 8th birthday dies of dehydration during
	# the offline interval that crosses the Found Money trigger; the event must
	# never fire for the dead, while earlier history stays intact.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	var prior_history: Array[EventHistoryEntry] = [
		EventHistoryEntry.new(LifeEventCatalog.BROKEN_TOY_ID, LifeEventCatalog.TRY_FIX, 100, 100),
	]
	player.events.restore_history(prior_history)
	clock.restore(8 * 365 - 1, 12, 0)
	player.debug_set_health(20.0)
	player.debug_set_thirst(0)
	player.debug_set_hunger(100)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	var loaded := fresh()
	var result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH,
		FIXED_NOW + 20 * 60 / GameClock.MINUTES_PER_REAL_SECOND)
	h.check("Off-E1 offline death load succeeds", result["ok"], result["error"])
	h.eq_bool("Off-E2 player died crossing the trigger day", loaded[1].is_dead, true)
	h.check("Off-E3 later event did not trigger", loaded[1].events.current_event == null)
	h.eq_int("Off-E4 earlier history intact", loaded[1].events.history_count(), 1)


# =====================================================================
# Save Version 10
# =====================================================================

static func _save_v10_round_trip(h: TestHarness) -> void:
	h.section("Save-V10")

	# Living round trip.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	player.debug_set_health(73.5)
	player.debug_set_life_seed(987654)
	advance_days(clock, 30 * 365)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_int("Save-V10 version is exactly 11", raw["Version"], 11)
	h.near_float("Save-V10 health serialized", raw["Health"], 73.5)
	h.eq_bool("Save-V10 IsDead serialized", raw["IsDead"], false)
	h.eq_int("Save-V10 DeathDay default serialized", raw["DeathDay"], -1)
	h.eq_int("Save-V10 DeathAge default serialized", raw["DeathAge"], -1)
	h.eq_string("Save-V10 CauseOfDeath default serialized", raw["CauseOfDeath"], "")
	h.eq_int("Save-V10 LifeSeed serialized", raw["LifeSeed"], 987654)
	h.check("Save-V10 deprivation streaks serialized",
		raw.has("StarvingMinutesAccumulator") and raw.has("DehydratedMinutesAccumulator"))

	var loaded := fresh()
	var load_result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW)
	h.check("Save-V10 living load succeeds", load_result["ok"], load_result["error"])
	h.near_float("Save-V10 health round trips", loaded[1].health, 73.5)
	h.eq_int("Save-V10 life seed round trips", loaded[1].life_seed, 987654)
	h.eq_bool("Save-V10 living state round trips", loaded[1].is_dead, false)

	# Dead round trip: career retained, no activity, death fields exact.
	var dead_pair := fresh()
	var dead_clock: GameClock = dead_pair[0]
	var dead: PlayerState = dead_pair[1]
	advance_days(dead_clock, 25 * 365)
	dead.apply_for_job(JobCatalog.LABORER_ID)
	dead.start_working()
	dead.die(PlayerState.CAUSE_DEHYDRATION)
	SaveManager.save_game(dead_clock, dead, TEST_PATH, FIXED_NOW)

	var dead_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_bool("Save-V10 dead IsDead serialized", dead_raw["IsDead"], true)
	h.eq_string("Save-V10 dead cause serialized", dead_raw["CauseOfDeath"], "dehydration")
	h.eq_int("Save-V10 dead day serialized", dead_raw["DeathDay"], dead_clock.day)
	h.eq_int("Save-V10 dead age serialized", dead_raw["DeathAge"], 25)
	h.near_float("Save-V10 dead health serialized", dead_raw["Health"], 0.0)

	var dead_loaded := fresh()
	var dead_result: Dictionary = SaveManager.load_game(dead_loaded[0], dead_loaded[1], TEST_PATH, FIXED_NOW)
	h.check("Save-V10 dead load succeeds", dead_result["ok"], dead_result["error"])
	h.eq_bool("Save-V10 dead state round trips", dead_loaded[1].is_dead, true)
	h.eq_string("Save-V10 dead cause round trips", dead_loaded[1].cause_of_death, PlayerState.CAUSE_DEHYDRATION)
	h.eq_int("Save-V10 dead day round trips", dead_loaded[1].death_day, dead_clock.day)
	h.eq_int("Save-V10 dead age round trips", dead_loaded[1].death_age, 25)
	h.eq_string("Save-V10 career retained through death round trip",
		dead_loaded[1].career.current_job_id, JobCatalog.LABORER_ID)
	h.eq_bool("Save-V10 no active activity round trips", dead_loaded[1].is_active(), false)

	# Save/load must not change mortality outcomes: same seed + day = same roll.
	var mortal_pair := fresh()
	var mortal_clock: GameClock = mortal_pair[0]
	var mortal: PlayerState = mortal_pair[1]
	mortal.debug_set_life_seed(424242)
	var deadly_day: int = _find_deadly_day(424242)
	mortal_clock.restore(deadly_day - 1, 12, 0)
	SaveManager.save_game(mortal_clock, mortal, TEST_PATH, FIXED_NOW)
	var mortal_loaded := fresh()
	SaveManager.load_game(mortal_loaded[0], mortal_loaded[1], TEST_PATH, FIXED_NOW)
	mortal_loaded[1].advance_simulation(60 * 12)
	h.eq_bool("Save-V10 mortality outcome survives save/load", mortal_loaded[1].is_dead, true)
	h.eq_int("Save-V10 mortality day survives save/load", mortal_loaded[1].death_day, deadly_day)


static func _save_v10_invalid(h: TestHarness) -> void:
	h.section("Save-V10X")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 20 * 365)
	player.apply_for_job(JobCatalog.LABORER_ID)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_PATH)

	# Live state that must survive every rejected load untouched.
	var live := fresh()
	var live_clock: GameClock = live[0]
	var live_player: PlayerState = live[1]
	live_player.money = 555
	live_clock.restore(321, 4, 4)

	var dead_base: Dictionary = JSON.parse_string(base_text)
	dead_base["IsDead"] = true
	dead_base["Health"] = 0.0
	dead_base["CauseOfDeath"] = "old_age"
	dead_base["DeathDay"] = clock.day
	dead_base["DeathAge"] = 20
	var dead_text: String = JSON.stringify(dead_base)

	var cases: Array = [
		["living Health below 0", base_text.replace("\"Health\":100.0", "\"Health\":-1.0")],
		["living Health above 100", base_text.replace("\"Health\":100.0", "\"Health\":100.5")],
		["living Health exactly 0", base_text.replace("\"Health\":100.0", "\"Health\":0.0")],
		["living with cause set", base_text.replace("\"CauseOfDeath\":\"\"", "\"CauseOfDeath\":\"old_age\"")],
		["living with DeathDay set", base_text.replace("\"DeathDay\":-1", "\"DeathDay\":5")],
		["living with DeathAge set", base_text.replace("\"DeathAge\":-1", "\"DeathAge\":5")],
		["dead with Health above 0", dead_text.replace("\"Health\":0.0", "\"Health\":10.0")],
		["dead with missing cause", dead_text.replace("\"CauseOfDeath\":\"old_age\"", "\"CauseOfDeath\":\"\"")],
		["dead with unknown cause", dead_text.replace("\"CauseOfDeath\":\"old_age\"", "\"CauseOfDeath\":\"fall\"")],
		["dead with negative DeathDay", dead_text.replace("\"DeathDay\":%d" % clock.day, "\"DeathDay\":-1")],
		["dead with negative DeathAge", dead_text.replace("\"DeathAge\":20", "\"DeathAge\":-1")],
		["dead with DeathDay mismatching clock", dead_text.replace("\"DeathDay\":%d" % clock.day, "\"DeathDay\":%d" % (clock.day - 1))],
		["dead while working", dead_text.replace("\"IsWorking\":false", "\"IsWorking\":true")],
		["dead while sleeping", dead_text.replace("\"IsSleeping\":false", "\"IsSleeping\":true")],
		["dead while studying", dead_text.replace("\"IsStudying\":false", "\"IsStudying\":true")],
		["dead while playing", dead_text.replace("\"IsPlaying\":false", "\"IsPlaying\":true")],
		["dead while with family", dead_text.replace("\"IsSpendingFamilyTime\":false", "\"IsSpendingFamilyTime\":true")],
		["negative LifeSeed", base_text.replace("\"LifeSeed\":", "\"LifeSeedX\":")],
	]

	for entry in cases:
		var label: String = entry[0]
		_write(TEST_PATH, entry[1])
		var result: Dictionary = SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)
		h.eq_bool("Save-V10X rejects %s" % label, result["ok"], false)

	# LifeSeed below zero must also be rejected (explicit patch).
	var seed_data: Dictionary = JSON.parse_string(base_text)
	seed_data["LifeSeed"] = -5
	_write(TEST_PATH, JSON.stringify(seed_data))
	h.eq_bool("Save-V10X rejects negative LifeSeed",
		SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)["ok"], false)

	h.eq_int("Save-V10X live money untouched", live_player.money, 555)
	h.eq_int("Save-V10X live clock untouched", live_clock.day, 321)


static func _legacy_life_seed_migration(h: TestHarness) -> void:
	h.section("Legacy-Seed")

	# v9 loads derive a LifeSeed deterministically: same save -> same seed,
	# across separate loads (no per-load reroll).
	var fixture: Dictionary = _legacy_v9_fixture()
	_write(TEST_PATH, JSON.stringify(fixture))
	var first := fresh()
	h.check("Legacy-Seed1 v9 save loads", SaveManager.load_game(first[0], first[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_bool("Legacy-Seed2 v9 loads living", first[1].is_dead, false)
	h.near_float("Legacy-Seed3 v9 health defaults to 100", first[1].health, 100.0)
	h.eq_int("Legacy-Seed4 v9 death defaults", first[1].death_day, -1)

	_write(TEST_PATH, JSON.stringify(fixture))
	var second := fresh()
	SaveManager.load_game(second[0], second[1], TEST_PATH, FIXED_NOW)
	h.eq_int("Legacy-Seed5 migration seed is deterministic",
		second[1].life_seed, first[1].life_seed)
	h.check("Legacy-Seed6 seed is in the 31-bit domain",
		first[1].life_seed >= 0 and first[1].life_seed <= PlayerState.LIFE_SEED_MAX)


static func _legacy_v9_fixture() -> Dictionary:
	return {
		"Version": 9,
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
		"CurrentJobId": "",
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


# =====================================================================
# Normal vs bulk equivalence (shared engine, matching outcomes)
# =====================================================================

static func _normal_bulk_equivalence(h: TestHarness) -> void:
	h.section("Equiv")

	var scenarios: Array = [
		["hunger already 0", {"health": 40.0, "hunger": 0, "thirst": 100}],
		["thirst already 0", {"health": 40.0, "hunger": 100, "thirst": 0}],
		["both already 0", {"health": 40.0, "hunger": 0, "thirst": 0}],
		["thirst reaches 0 mid-interval", {"health": 100.0, "hunger": 100, "thirst": 20}],
		["hunger reaches 0 mid-interval", {"health": 100.0, "hunger": 20, "thirst": 100}],
		["death occurs mid-interval", {"health": 11.0, "hunger": 100, "thirst": 0}],
	]

	for scenario in scenarios:
		var label: String = scenario[0]
		var setup: Dictionary = scenario[1]

		var stepped := fresh()
		var stepped_clock: GameClock = stepped[0]
		var stepped_player: PlayerState = stepped[1]
		stepped_player.debug_set_health(setup["health"])
		stepped_player.debug_set_hunger(setup["hunger"])
		stepped_player.debug_set_thirst(setup["thirst"])
		var total_minutes: int = 60 * 80
		var remaining: int = total_minutes
		while remaining > 0 and not stepped_player.is_dead:
			var step: int = mini(60, remaining)
			stepped_player.advance_simulation(step)
			remaining -= step

		var bulk := fresh()
		var bulk_clock: GameClock = bulk[0]
		var bulk_player: PlayerState = bulk[1]
		bulk_player.debug_set_health(setup["health"])
		bulk_player.debug_set_hunger(setup["hunger"])
		bulk_player.debug_set_thirst(setup["thirst"])
		bulk_player.bulk_advance_simulation(total_minutes)

		var context: String = "Equiv %s" % label
		h.eq_bool("%s is_dead parity" % context, bulk_player.is_dead, stepped_player.is_dead)
		h.eq_int("%s clock day parity" % context, bulk_clock.day, stepped_clock.day)
		h.eq_int("%s clock time parity" % context,
			bulk_clock.hour * 60 + bulk_clock.minute,
			stepped_clock.hour * 60 + stepped_clock.minute)
		h.near_float("%s health parity" % context, bulk_player.health, stepped_player.health)
		h.eq_int("%s hunger parity" % context, bulk_player.hunger, stepped_player.hunger)
		h.eq_int("%s thirst parity" % context, bulk_player.thirst, stepped_player.thirst)
		if stepped_player.is_dead:
			h.eq_int("%s death day parity" % context, bulk_player.death_day, stepped_player.death_day)
			h.eq_int("%s death age parity" % context, bulk_player.death_age, stepped_player.death_age)
			h.eq_string("%s cause parity" % context, bulk_player.cause_of_death, stepped_player.cause_of_death)


# =====================================================================
# Deprivation accumulator persistence (Save Version 10)
# =====================================================================

static func _deprivation_persistence(h: TestHarness) -> void:
	h.section("Life-DP")

	# Dehydration partial hour survives save/load: thirst 0 with 45 streak
	# minutes saved, then +14 = no damage and +1 completes the hour for -5.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	player.debug_set_thirst(0)
	player.debug_set_hunger(100)
	player.advance_simulation(45)
	h.eq_int("Life-DP1 dehydrated streak builds pre-save", player.get_dehydrated_minutes_accumulator(), 45)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_int("Life-DP2 dehydrated streak serialized", raw["DehydratedMinutesAccumulator"], 45)

	var loaded := fresh()
	var load_result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW)
	h.check("Life-DP3 load succeeds", load_result["ok"], load_result["error"])
	h.eq_int("Life-DP4 dehydrated streak restored", loaded[1].get_dehydrated_minutes_accumulator(), 45)
	loaded[1].advance_simulation(14)
	h.near_float("Life-DP5 +14 minutes deals no damage", loaded[1].health, 100.0)
	loaded[1].advance_simulation(1)
	h.near_float("Life-DP6 +1 minute completes the hour for -5", loaded[1].health, 95.0)

	# Starvation equivalent: hunger 0 with 45 streak minutes, +14 = nothing,
	# +1 completes the hour for -2.
	var spair := fresh()
	var sclock: GameClock = spair[0]
	var starve: PlayerState = spair[1]
	starve.debug_set_hunger(0)
	starve.debug_set_thirst(100)
	starve.advance_simulation(45)
	h.eq_int("Life-DP7 starving streak builds pre-save", starve.get_starving_minutes_accumulator(), 45)
	SaveManager.save_game(sclock, starve, TEST_PATH, FIXED_NOW)
	var sraw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_int("Life-DP8 starving streak serialized", sraw["StarvingMinutesAccumulator"], 45)

	var sloaded := fresh()
	h.check("Life-DP9 starvation load succeeds",
		SaveManager.load_game(sloaded[0], sloaded[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_int("Life-DP10 starving streak restored", sloaded[1].get_starving_minutes_accumulator(), 45)
	sloaded[1].advance_simulation(14)
	h.near_float("Life-DP11 +14 minutes deals no damage", sloaded[1].health, 100.0)
	sloaded[1].advance_simulation(1)
	h.near_float("Life-DP12 +1 minute completes the hour for -2", sloaded[1].health, 98.0)

	# Exact death timing: Health 5 with a 45-minute streak dies on the 15th
	# post-load minute, not a fresh 60 minutes later.
	var dpair := fresh()
	var dclock: GameClock = dpair[0]
	var dying: PlayerState = dpair[1]
	dying.debug_set_health(5.0)
	dying.debug_set_thirst(0)
	dying.debug_set_hunger(100)
	dying.advance_simulation(45)
	SaveManager.save_game(dclock, dying, TEST_PATH, FIXED_NOW)

	var dloaded := fresh()
	SaveManager.load_game(dloaded[0], dloaded[1], TEST_PATH, FIXED_NOW)
	dloaded[1].advance_simulation(14)
	h.eq_bool("Life-DP13 still alive 1 minute before the fatal hour", dloaded[1].is_dead, false)
	h.near_float("Life-DP14 health untouched before the fatal hour", dloaded[1].health, 5.0)
	dloaded[1].advance_simulation(1)
	h.eq_bool("Life-DP15 dead once the streak hour completes", dloaded[1].is_dead, true)
	h.eq_string("Life-DP16 fatal cause is dehydration", dloaded[1].cause_of_death, PlayerState.CAUSE_DEHYDRATION)
	h.eq_int("Life-DP17 death clock hour is exact", dloaded[0].hour, 1)
	h.eq_int("Life-DP18 death clock minute is exact", dloaded[0].minute, 0)
	h.eq_int("Life-DP19 death day matches the frozen clock", dloaded[1].death_day, dloaded[0].day)

	# Offline progression respects the restored streak: 16 offline game
	# minutes (45 + 16 > 60) kill, and the clock freezes at the fatal minute.
	var opair := fresh()
	var oclock: GameClock = opair[0]
	var offline: PlayerState = opair[1]
	offline.debug_set_health(5.0)
	offline.debug_set_thirst(0)
	offline.debug_set_hunger(100)
	offline.advance_simulation(45)
	SaveManager.save_game(oclock, offline, TEST_PATH, FIXED_NOW)

	var oloaded := fresh()
	var oresult: Dictionary = SaveManager.load_game(oloaded[0], oloaded[1], TEST_PATH, FIXED_NOW + 4)
	h.check("Life-DP20 offline load succeeds", oresult["ok"], oresult["error"])
	h.eq_int("Life-DP21 offline minutes reported", oresult["offline_minutes"], 16)
	h.eq_bool("Life-DP22 partial streak dies offline", oloaded[1].is_dead, true)
	h.eq_string("Life-DP23 offline fatal cause is dehydration",
		oloaded[1].cause_of_death, PlayerState.CAUSE_DEHYDRATION)
	h.eq_int("Life-DP24 offline death freezes the clock hour", oloaded[0].hour, 1)
	h.eq_int("Life-DP25 offline death freezes the clock minute", oloaded[0].minute, 0)

	# Version 10 validation: accumulators are 0..59 integers, never clamped.
	var vpair := fresh()
	SaveManager.save_game(vpair[0], vpair[1], TEST_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_PATH)

	var live := fresh()
	var live_clock: GameClock = live[0]
	var live_player: PlayerState = live[1]
	live_player.money = 7777
	live_player.energy = 61
	live_player.debug_set_hunger(62)
	live_player.debug_set_thirst(63)
	live_player.debug_set_health(42.0)
	live_player.start_sleeping()
	live_clock.restore(4321, 7, 8)

	var bad_cases: Array = [
		["negative Starving", {"StarvingMinutesAccumulator": -1}],
		["Starving at 60", {"StarvingMinutesAccumulator": 60}],
		["negative Dehydrated", {"DehydratedMinutesAccumulator": -1}],
		["Dehydrated at 60", {"DehydratedMinutesAccumulator": 60}],
		["non-integer Starving", {"StarvingMinutesAccumulator": 1.5}],
		["string Dehydrated", {"DehydratedMinutesAccumulator": "45"}],
		["null Starving", {"StarvingMinutesAccumulator": null}],
		["null Dehydrated", {"DehydratedMinutesAccumulator": null}],
	]
	for entry in bad_cases:
		var label: String = entry[0]
		var patch: Dictionary = entry[1]
		var data: Dictionary = JSON.parse_string(base_text)
		for key in patch:
			data[key] = patch[key]
		_write(TEST_PATH, JSON.stringify(data))
		var bad_result: Dictionary = SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)
		h.eq_bool("Life-DP26 rejects %s" % label, bad_result["ok"], false)

	h.eq_int("Life-DP27 live clock day untouched", live_clock.day, 4321)
	h.eq_int("Life-DP28 live clock time untouched",
		live_clock.hour * 60 + live_clock.minute, 7 * 60 + 8)
	h.eq_int("Life-DP29 live money untouched", live_player.money, 7777)
	h.eq_int("Life-DP30 live energy untouched", live_player.energy, 61)
	h.eq_int("Life-DP31 live hunger untouched", live_player.hunger, 62)
	h.eq_int("Life-DP32 live thirst untouched", live_player.thirst, 63)
	h.near_float("Life-DP33 live health untouched", live_player.health, 42.0)
	h.eq_bool("Life-DP34 live death state untouched", live_player.is_dead, false)
	h.eq_bool("Life-DP35 live activity untouched", live_player.is_sleeping, true)
	h.eq_int("Life-DP36 live education untouched",
		live_player.education.status, EducationState.Status.NOT_ENROLLED)
	h.eq_string("Life-DP37 live career untouched", live_player.career.current_job_id, "")

	# Legacy saves predate the fields and must default both streaks to 0.
	var legacy: Dictionary = _legacy_v9_fixture()
	_write(TEST_PATH, JSON.stringify(legacy))
	var lloaded := fresh()
	h.check("Life-DP38 v9 save still loads",
		SaveManager.load_game(lloaded[0], lloaded[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_int("Life-DP39 v9 starving streak defaults to 0",
		lloaded[1].get_starving_minutes_accumulator(), 0)
	h.eq_int("Life-DP40 v9 dehydrated streak defaults to 0",
		lloaded[1].get_dehydrated_minutes_accumulator(), 0)


static func _write(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(text)
	file.close()
	return {"ok": true}
