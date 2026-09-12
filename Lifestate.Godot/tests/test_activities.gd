extends RefCounted

## Activity regression coverage, ported from the C# work/study/play/family
## sections including mutual exclusion, partial-hour carry and bulk parity.


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func run(h: TestHarness) -> void:
	_mutual_exclusion(h)
	_work(h)
	_study(h)
	_play(h)
	_family_time(h)
	_bulk_parity(h)


static func _mutual_exclusion(h: TestHarness) -> void:
	h.section("Activity-EX")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 20)

	h.eq_bool("Activity-EX1 family time can start", player.start_family_time(), true)
	player.start_sleeping()
	h.eq_bool("Activity-EX2 sleeping cannot start while busy", player.is_sleeping, false)
	player.start_working()
	h.eq_bool("Activity-EX3 working cannot start while busy", player.is_working, false)
	h.eq_bool("Activity-EX4 playing cannot start while busy", player.start_playing(), false)
	h.eq_bool("Activity-EX5 family time cannot restart", player.start_family_time(), false)
	player.start_studying()
	h.eq_bool("Activity-EX6 studying cannot start while busy", player.is_studying, false)
	h.eq_int("Activity-EX7 exactly one activity is active", _active_count(player), 1)
	h.eq_string("Activity-EX8 activity name reflects state", player.current_activity_name(), "Family Time")

	player.stop_family_time()
	h.eq_string("Activity-EX9 idle after stopping", player.current_activity_name(), "Idle")
	h.eq_bool("Activity-EX10 sleeping can start once idle", _start_sleeping(player), true)
	h.eq_int("Activity-EX11 still exactly one activity", _active_count(player), 1)


static func _start_sleeping(player: PlayerState) -> bool:
	player.start_sleeping()
	return player.is_sleeping


static func _active_count(player: PlayerState) -> int:
	var count: int = 0
	if player.is_sleeping:
		count += 1
	if player.is_working:
		count += 1
	if player.is_studying:
		count += 1
	if player.is_playing:
		count += 1
	if player.is_spending_family_time:
		count += 1
	return count


static func _work(h: TestHarness) -> void:
	h.section("Work-W")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	player.start_working()
	h.eq_bool("Work-W1 underage work is rejected", player.is_working, false)

	advance_days(clock, 17 * 365)
	h.eq_int("Work-W2 still 17", player.age, 17)
	player.start_working()
	h.eq_bool("Work-W3 age 17 still rejected", player.is_working, false)

	advance_days(clock, 365)
	h.eq_int("Work-W4 now 18", player.age, 18)
	player.start_working()
	h.eq_bool("Work-W5 work allowed at 18", player.is_working, true)

	var money_before: int = player.money
	player.advance_simulation(60)
	h.eq_int("Work-W6 earns 10 per hour", player.money, money_before + 10)

	player.advance_simulation(60 * 8)
	h.eq_int("Work-W7 earns 10 per hour over 9 hours", player.money, money_before + 90)

	player.advance_simulation(59)
	h.eq_int("Work-W8 partial hour earns nothing", player.money, money_before + 90)
	player.advance_simulation(1)
	h.eq_int("Work-W9 completing the hour pays", player.money, money_before + 100)

	player.stop_working()
	var money_after: int = player.money
	player.advance_simulation(60 * 5)
	h.eq_int("Work-W10 stopped work earns nothing", player.money, money_after)


static func _study(h: TestHarness) -> void:
	h.section("Study-S")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	player.start_studying()
	h.eq_bool("Study-S1 underage study is rejected", player.is_studying, false)

	advance_days(clock, 6 * 365)
	player.start_studying()
	h.eq_bool("Study-S2 study allowed at age 6", player.is_studying, true)

	player.advance_simulation(59)
	h.eq_int("Study-S3 partial hour earns no StudyXP", player.study_xp, 0)
	h.near_float("Study-S4 partial hour earns no intelligence", player.attributes.intelligence, 10.0)
	h.eq_int("Study-S5 partial hour earns no Academics XP", player.skills.academics.experience, 0)

	player.advance_simulation(1)
	h.eq_int("Study-S6 first completed hour earns 10 StudyXP", player.study_xp, 10)
	h.near_float("Study-S7 intelligence +0.05 per hour", player.attributes.intelligence, 10.05)
	h.eq_int("Study-S8 Academics +10 XP per hour", player.skills.academics.experience, 10)
	h.near_float("Study-S9 curiosity +0.02 per hour", player.traits.curiosity, 50.02)
	h.near_float("Study-S10 patience +0.01 per hour", player.traits.patience, 50.01)
	h.near_float("Study-S11 ambition +0.01 per hour", player.traits.ambition, 50.01)

	player.advance_simulation(60 * 4)
	h.eq_int("Study-S12 five hours total StudyXP", player.study_xp, 50)
	h.near_float("Study-S13 five hours of intelligence", player.attributes.intelligence, 10.25)

	# Partial hour survives a stop/start cycle.
	var split := fresh()
	var split_clock: GameClock = split[0]
	var split_player: PlayerState = split[1]
	advance_days(split_clock, 6 * 365 + 1)
	split_player.start_studying()
	split_player.advance_simulation(30)
	split_player.stop_studying()
	split_player.advance_simulation(60 * 3)
	split_player.start_studying()
	split_player.advance_simulation(30)
	h.eq_int("Study-S14 partial hour carries across stop/start", split_player.study_xp, 10)

	# Studying while enrolled also advances education.
	var enrolled := fresh()
	var enrolled_clock: GameClock = enrolled[0]
	var enrolled_player: PlayerState = enrolled[1]
	advance_days(enrolled_clock, 6 * 365)
	h.eq_bool("Study-S15 enrolment succeeds at age 6", enrolled_player.enroll_primary_school(), true)
	enrolled_player.start_studying()
	enrolled_player.advance_simulation(60 * 10)
	h.eq_int("Study-S16 ten study hours add ten education progress", enrolled_player.education.education_progress, 10)


static func _play(h: TestHarness) -> void:
	h.section("Play-P")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	h.eq_bool("Play-P1 newborn cannot play", player.start_playing(), false)

	advance_days(clock, 2 * 365)
	h.eq_bool("Play-P2 age 2 can play", player.start_playing(), true)

	player.advance_simulation(60)
	h.near_float("Play-P3 fitness +0.03 per hour", player.attributes.fitness, 10.03)
	h.near_float("Play-P4 creativity +0.03 per hour", player.attributes.creativity, 10.03)
	h.near_float("Play-P5 confidence +0.02 per hour", player.traits.confidence, 50.02)
	h.near_float("Play-P6 curiosity +0.01 per hour", player.traits.curiosity, 50.01)
	h.eq_int("Play-P7 one completed play hour counted", player.total_play_hours, 1)

	player.advance_simulation(59)
	h.eq_int("Play-P8 partial play hour not counted", player.total_play_hours, 1)
	player.advance_simulation(1)
	h.eq_int("Play-P9 completing the hour counts it", player.total_play_hours, 2)

	player.stop_playing()
	var hours_after: int = player.total_play_hours
	player.advance_simulation(60 * 4)
	h.eq_int("Play-P10 stopped play adds no hours", player.total_play_hours, hours_after)

	player.start_playing()
	player.advance_simulation(60 * 3000)
	h.near_float("Play-P11 fitness caps at 100", player.attributes.fitness, 100.0)


static func _family_time(h: TestHarness) -> void:
	h.section("FamilyTime-F")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 5 * 365)

	h.eq_bool("FamilyTime-F1 family time always available", player.start_family_time(), true)
	player.advance_simulation(60)

	h.near_float("FamilyTime-F2 mother closeness +0.25 per hour",
		player.relationships.mother_relationship.closeness, 50.25)
	h.near_float("FamilyTime-F3 father closeness +0.25 per hour",
		player.relationships.father_relationship.closeness, 50.25)
	h.near_float("FamilyTime-F4 social +0.02 per hour", player.attributes.social, 10.02)
	h.near_float("FamilyTime-F5 empathy +0.02 per hour", player.traits.empathy, 50.02)
	h.near_float("FamilyTime-F6 confidence +0.01 per hour", player.traits.confidence, 50.01)

	player.advance_simulation(60 * 199)
	h.near_float("FamilyTime-F7 closeness caps at 100",
		player.relationships.mother_relationship.closeness, 100.0)

	player.stop_family_time()
	var closeness_after: float = player.relationships.father_relationship.closeness
	player.advance_simulation(60 * 3)
	h.near_float("FamilyTime-F8 stopped family time adds nothing",
		player.relationships.father_relationship.closeness, closeness_after)


static func _bulk_parity(h: TestHarness) -> void:
	h.section("Bulk-B")

	# Study: bulk applied in one arithmetic step must equal stepped simulation.
	var stepped := fresh()
	var stepped_clock: GameClock = stepped[0]
	var stepped_player: PlayerState = stepped[1]
	advance_days(stepped_clock, 6 * 365)
	stepped_player.enroll_primary_school()
	stepped_player.start_studying()
	for _i in range(10):
		stepped_player.advance_simulation(60)

	var bulk := fresh()
	var bulk_clock: GameClock = bulk[0]
	var bulk_player: PlayerState = bulk[1]
	advance_days(bulk_clock, 6 * 365)
	bulk_player.enroll_primary_school()
	bulk_player.start_studying()
	var rewards: Dictionary = bulk_player.bulk_advance_simulation(600)
	bulk_player.apply_rewards(rewards["money_earned"], rewards["xp_earned"])

	h.eq_int("Bulk-B1 StudyXP parity", bulk_player.study_xp, stepped_player.study_xp)
	h.near_float("Bulk-B2 intelligence parity",
		bulk_player.attributes.intelligence, stepped_player.attributes.intelligence)
	h.eq_int("Bulk-B3 Academics parity",
		bulk_player.skills.academics.experience, stepped_player.skills.academics.experience)
	h.eq_int("Bulk-B4 education progress parity",
		bulk_player.education.education_progress, stepped_player.education.education_progress)
	h.eq_int("Bulk-B5 energy parity", bulk_player.energy, stepped_player.energy)
	h.eq_int("Bulk-B6 hunger parity", bulk_player.hunger, stepped_player.hunger)
	h.eq_int("Bulk-B7 thirst parity", bulk_player.thirst, stepped_player.thirst)

	# Work: bulk money equals stepped money.
	var work_stepped := fresh()
	var work_stepped_clock: GameClock = work_stepped[0]
	var work_stepped_player: PlayerState = work_stepped[1]
	advance_days(work_stepped_clock, 19 * 365)
	work_stepped_player.start_working()
	for _i in range(12):
		work_stepped_player.advance_simulation(60)

	var work_bulk := fresh()
	var work_bulk_clock: GameClock = work_bulk[0]
	var work_bulk_player: PlayerState = work_bulk[1]
	advance_days(work_bulk_clock, 19 * 365)
	work_bulk_player.start_working()
	var work_rewards: Dictionary = work_bulk_player.bulk_advance_simulation(720)
	work_bulk_player.apply_rewards(work_rewards["money_earned"], work_rewards["xp_earned"])
	h.eq_int("Bulk-B8 work money parity", work_bulk_player.money, work_stepped_player.money)
	h.eq_int("Bulk-B9 work day earnings", work_bulk_player.money, 1000 + 120)

	# Play: bulk counts play hours identically.
	var play_bulk := fresh()
	var play_bulk_clock: GameClock = play_bulk[0]
	var play_bulk_player: PlayerState = play_bulk[1]
	advance_days(play_bulk_clock, 3 * 365)
	play_bulk_player.start_playing()
	play_bulk_player.bulk_advance_simulation(60 * 7 + 30)
	h.eq_int("Bulk-B10 bulk play hours counted", play_bulk_player.total_play_hours, 7)
	h.eq_int("Bulk-B11 bulk play remainder kept", play_bulk_player.get_play_minutes_accumulator(), 30)

	# Bulk must use the saved remainder (offline continuity).
	var remainder_player: PlayerState = fresh()[1]
	remainder_player.restore_values(1000, 100, 100, 100, 0, false, false, false, true, false,
		0, 0, 0, 0, 0, 0, 55, 0)
	remainder_player.bulk_advance_simulation(5)
	h.eq_int("Bulk-B12 saved play remainder completes an hour", remainder_player.total_play_hours, 1)
	h.eq_int("Bulk-B13 remainder resets after the hour", remainder_player.get_play_minutes_accumulator(), 0)
