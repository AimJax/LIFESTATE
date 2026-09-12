extends RefCounted

## Clock / age / life-stage / needs regression coverage, ported from the C#
## simulation suite (clock, thirst, energy and need-persistence sections).


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func run(h: TestHarness) -> void:
	_clock_basics(h)
	_age_and_life_stage(h)
	_needs_decay(h)
	_energy_and_sleep(h)
	_food_and_drink(h)
	_partial_hour_continuity(h)


static func _clock_basics(h: TestHarness) -> void:
	h.section("Clock-C")

	var pair := fresh()
	var clock: GameClock = pair[0]

	h.eq_int("Clock-C1 starts at day 0", clock.day, 0)
	h.eq_int("Clock-C2 starts at 00:00", clock.hour * 60 + clock.minute, 0)

	clock.advance_seconds(1)
	h.eq_int("Clock-C3: 1 real second = 4 game minutes", clock.minute, 4)

	clock.advance_seconds(14)
	h.eq_int("Clock-C4: 15 real seconds = 1 game hour", clock.hour, 1)
	h.eq_int("Clock-C5 minute is reset", clock.minute, 0)

	clock.advance_seconds(15 * 24)
	h.eq_int("Clock-C6: 6 real minutes = 1 game day", clock.day, 1)
	# Hour 1 + 24 hours lands on hour 1 of the next day.
	h.eq_int("Clock-C7 hour follows the day rollover", clock.hour, 1)

	clock.advance_seconds(360 * 364)
	h.eq_int("Clock-C8 day 365 reached", clock.day, 365)
	h.eq_int("Clock-C9 year derived from day", clock.year, 1)
	h.eq_int("Clock-C10 day of year is 0", clock.day_of_year, 0)

	var before: int = clock.day
	clock.advance_game_minutes(-5)
	h.eq_int("Clock-C11 negative minutes is a no-op", clock.day, before)

	var overflow_clock := GameClock.new()
	overflow_clock.restore(GameClock.MAX_DAY, 0, 0)
	h.eq_bool("Clock-C12 overflow is rejected", overflow_clock.advance_game_minutes(1440), false)
	h.eq_int("Clock-C13 overflow leaves day untouched", overflow_clock.day, GameClock.MAX_DAY)


static func _age_and_life_stage(h: TestHarness) -> void:
	h.section("Age-LS")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	h.eq_int("Age-LS1 newborn age is 0", player.age, 0)
	h.eq_int("Age-LS2 newborn stage is Infant", player.life_stage, LifeStage.Stage.INFANT)

	var expectations: Array = [
		[1, LifeStage.Stage.INFANT],
		[2, LifeStage.Stage.EARLY_CHILDHOOD],
		[5, LifeStage.Stage.EARLY_CHILDHOOD],
		[6, LifeStage.Stage.CHILD],
		[12, LifeStage.Stage.CHILD],
		[13, LifeStage.Stage.TEEN],
		[17, LifeStage.Stage.TEEN],
		[18, LifeStage.Stage.ADULT],
		[64, LifeStage.Stage.ADULT],
		[65, LifeStage.Stage.ELDER],
	]
	for entry in expectations:
		var age: int = entry[0]
		var stage: int = entry[1]
		var probe := GameClock.new()
		probe.restore(age * 365, 0, 0)
		var probe_player := PlayerState.new(probe)
		h.eq_int("Age-LS3 age %d -> %s" % [age, LifeStage.display_name(stage)], probe_player.life_stage, stage)

	h.eq_string("Age-LS4 stage display name matches reference ToString",
		LifeStage.display_name(LifeStage.Stage.EARLY_CHILDHOOD), "EarlyChildhood")

	advance_days(clock, 6 * 365 + 10)
	h.eq_int("Age-LS5 age derives from clock day", player.age, 6)
	h.eq_int("Age-LS6 stage follows age", player.life_stage, LifeStage.Stage.CHILD)


static func _needs_decay(h: TestHarness) -> void:
	h.section("Needs")

	var pair := fresh()
	var player: PlayerState = pair[1]

	h.eq_int("Needs-1 energy starts at 100", player.energy, 100)
	h.eq_int("Needs-2 hunger starts at 100", player.hunger, 100)
	h.eq_int("Needs-3 thirst starts at 100", player.thirst, 100)
	h.eq_int("Needs-4 money starts at 1000", player.money, 1000)

	player.advance_simulation(60)
	h.eq_int("Needs-5 awake energy -1 per hour", player.energy, 99)
	h.eq_int("Needs-6 hunger -1 per hour", player.hunger, 99)
	h.eq_int("Needs-7 thirst -2 per hour", player.thirst, 98)

	player.advance_simulation(60 * 10)
	h.eq_int("Needs-8 awake energy -1 per hour over 11 hours", player.energy, 89)
	h.eq_int("Needs-9 hunger -1 per hour over 11 hours", player.hunger, 89)
	h.eq_int("Needs-10 thirst floors at 0", player.thirst, 78)

	# Drain completely and confirm the clamp at zero.
	player.advance_simulation(60 * 500)
	h.eq_int("Needs-11 energy never goes negative", player.energy, 0)
	h.eq_int("Needs-12 hunger never goes negative", player.hunger, 0)
	h.eq_int("Needs-13 thirst never goes negative", player.thirst, 0)


static func _energy_and_sleep(h: TestHarness) -> void:
	h.section("Sleep-E")

	var pair := fresh()
	var player: PlayerState = pair[1]

	player.advance_simulation(60 * 100)
	h.eq_int("Sleep-E1 energy drained to 0", player.energy, 0)

	player.start_sleeping()
	h.eq_bool("Sleep-E2 sleeping flag set", player.is_sleeping, true)

	player.advance_simulation(60)
	h.eq_int("Sleep-E3 sleeping energy +5 per hour", player.energy, 5)

	player.advance_simulation(60 * 19)
	h.eq_int("Sleep-E4 sleeping energy caps at 100", player.energy, 100)

	player.stop_sleeping()
	h.eq_bool("Sleep-E5 sleeping flag cleared", player.is_sleeping, false)

	player.advance_simulation(60)
	h.eq_int("Sleep-E6 awake decay resumes after waking", player.energy, 99)

	# Separate remainders: awake minutes must not leak into the sleeping accumulator.
	var pair2 := fresh()
	var player2: PlayerState = pair2[1]
	player2.advance_simulation(59)
	h.eq_int("Sleep-E7 59 awake minutes keep energy", player2.energy, 100)
	h.eq_int("Sleep-E8 awake remainder recorded", player2.get_awake_minutes_accumulator(), 59)
	player2.start_sleeping()
	player2.advance_simulation(1)
	h.eq_int("Sleep-E9 sleep remainder starts fresh", player2.get_sleeping_minutes_accumulator(), 1)
	h.eq_int("Sleep-E10 awake remainder preserved", player2.get_awake_minutes_accumulator(), 59)


static func _food_and_drink(h: TestHarness) -> void:
	h.section("Eat-Drink")

	var pair := fresh()
	var player: PlayerState = pair[1]

	player.eat(20)
	h.eq_int("Eat-Drink1 eating at full hunger stays at 100", player.hunger, 100)

	player.advance_simulation(60 * 100)
	player.eat(20)
	h.eq_int("Eat-Drink2 eat restores hunger", player.hunger, 20)

	player.eat(1000)
	h.eq_int("Eat-Drink3 hunger caps at 100", player.hunger, 100)

	player.eat(0)
	h.eq_int("Eat-Drink4 eating zero is a no-op", player.hunger, 100)

	player.eat(-25)
	h.eq_int("Eat-Drink5 negative restore is a no-op", player.hunger, 100)

	player.advance_simulation(60 * 100)
	player.drink(20)
	h.eq_int("Eat-Drink6 drink restores thirst", player.thirst, 20)

	player.drink(500)
	h.eq_int("Eat-Drink7 thirst caps at 100", player.thirst, 100)

	player.drink(-5)
	h.eq_int("Eat-Drink8 negative drink is a no-op", player.thirst, 100)


static func _partial_hour_continuity(h: TestHarness) -> void:
	h.section("Partial-N")

	var pair := fresh()
	var player: PlayerState = pair[1]

	player.advance_simulation(59)
	h.eq_int("Partial-N1 59 minutes keep energy", player.energy, 100)
	h.eq_int("Partial-N2 59 minutes keep hunger", player.hunger, 100)
	h.eq_int("Partial-N3 59 minutes keep thirst", player.thirst, 100)

	player.advance_simulation(1)
	h.eq_int("Partial-N4 completing the hour applies energy", player.energy, 99)
	h.eq_int("Partial-N5 completing the hour applies hunger", player.hunger, 99)
	h.eq_int("Partial-N6 completing the hour applies thirst", player.thirst, 98)

	# Ten one-minute steps must equal one ten-minute step.
	var stepwise := fresh()
	var stepwise_player: PlayerState = stepwise[1]
	for _i in range(10):
		stepwise_player.advance_simulation(6)
	var single := fresh()
	var single_player: PlayerState = single[1]
	single_player.advance_simulation(60)
	h.eq_int("Partial-N7 stepped energy matches single call", stepwise_player.energy, single_player.energy)
	h.eq_int("Partial-N8 stepped thirst matches single call", stepwise_player.thirst, single_player.thirst)

	# Remainders must survive a stop/start cycle (NeedPersist-N1..N3 in C#).
	var persist := fresh()
	var persist_player: PlayerState = persist[1]
	persist_player.advance_simulation(45)
	persist_player.advance_simulation(45)
	h.eq_int("Partial-N9 accumulation across calls applies one hour", persist_player.energy, 99)
	h.eq_int("Partial-N10 remainder is 30 minutes", persist_player.get_awake_minutes_accumulator(), 30)
