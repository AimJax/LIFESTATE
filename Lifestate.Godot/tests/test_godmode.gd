extends RefCounted

## God Mode coverage, ported from the C# GodMode sections, including the
## invariant that time skips advance the clock but do not simulate rewards.


static func fresh() -> Array:
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	return [clock, player, GodMode.new(clock, player)]


static func run(h: TestHarness) -> void:
	_gating(h)
	_time_skip(h)
	_cheats(h)


static func _gating(h: TestHarness) -> void:
	h.section("GodMode-G")

	var trio := fresh()
	var clock: GameClock = trio[0]
	var player: PlayerState = trio[1]
	var god: GodMode = trio[2]

	h.eq_bool("GodMode-G1 starts disabled", god.is_enabled, false)

	god.advance_days(365)
	h.eq_int("GodMode-G2 disabled time skip does nothing", clock.day, 0)

	god.add_money(500)
	h.eq_int("GodMode-G3 disabled money cheat does nothing", player.money, 1000)

	var needs_pair := fresh()
	var needs_player: PlayerState = needs_pair[1]
	var needs_god: GodMode = needs_pair[2]
	needs_player.advance_simulation(60 * 30)
	var drained: int = needs_player.energy
	needs_god.restore_needs()
	h.eq_int("GodMode-G4 disabled restore needs does nothing", needs_player.energy, drained)

	needs_god.set_enabled(true)
	h.eq_bool("GodMode-G5 can be enabled", needs_god.is_enabled, true)
	needs_god.set_enabled(false)
	h.eq_bool("GodMode-G6 can be disabled again", needs_god.is_enabled, false)


static func _time_skip(h: TestHarness) -> void:
	h.section("GodMode-T")

	var trio := fresh()
	var clock: GameClock = trio[0]
	var player: PlayerState = trio[1]
	var god: GodMode = trio[2]
	god.set_enabled(true)

	god.advance_days(1)
	h.eq_int("GodMode-T1 +1 day advances the clock", clock.day, 1)
	h.eq_int("GodMode-T2 skipped time does not drain energy", player.energy, 100)
	h.eq_int("GodMode-T3 skipped time does not drain hunger", player.hunger, 100)
	h.eq_int("GodMode-T4 skipped time does not earn money", player.money, 1000)
	h.eq_int("GodMode-T5 skipped time grants no StudyXP", player.study_xp, 0)
	h.eq_int("GodMode-T6 skipped time grants no play hours", player.total_play_hours, 0)

	god.advance_days(365)
	h.eq_int("GodMode-T7 +1 year advances the clock", clock.day, 366)
	h.eq_int("GodMode-T8 age follows the skipped clock", player.age, 1)

	god.advance_days(3650)
	h.eq_int("GodMode-T9 +10 years advances the clock", clock.day, 4016)
	h.eq_int("GodMode-T10 age now 11", player.age, 11)

	# Age-based eligibility is reevaluated after a skip, without rewards:
	# Found Money became eligible at age 8, so this skip is when it triggers.
	var eligible_day: int = clock.day
	h.check("GodMode-T11 time skips reevaluate event eligibility",
		player.events.current_event != null
		and player.events.current_event.event_id == LifeEventCatalog.FOUND_MONEY_ID)
	h.eq_int("GodMode-T12 TriggeredDay is the skipped current day",
		player.events.current_event.triggered_day, eligible_day)
	god.advance_days(3650)
	h.eq_int("GodMode-T12b a pending event keeps its original trigger day",
		player.events.current_event.triggered_day, eligible_day)
	h.eq_int("GodMode-T13 no money fabricated by the skip", player.money, 1000)
	h.eq_int("GodMode-T14 no skills fabricated by the skip", player.skills.academics.experience, 0)

	# A skipped year must not silently advance school grades.
	var student_trio := fresh()
	var student_clock: GameClock = student_trio[0]
	var student_player: PlayerState = student_trio[1]
	var student_god: GodMode = student_trio[2]
	student_god.set_enabled(true)
	student_god.advance_days(6 * 365)
	student_player.enroll_primary_school()
	student_player.start_studying()
	student_player.advance_simulation(60 * 120)
	h.eq_int("GodMode-T15 studying earns education progress", student_player.education.education_progress, 100)
	var grade_before: int = student_player.education.primary_grade
	student_god.advance_days(400)
	h.eq_int("GodMode-T16 skip alone does not advance a grade",
		student_player.education.primary_grade, grade_before)


static func _cheats(h: TestHarness) -> void:
	h.section("GodMode-C")

	var trio := fresh()
	var player: PlayerState = trio[1]
	var god: GodMode = trio[2]
	god.set_enabled(true)

	player.advance_simulation(60 * 40)
	god.restore_needs()
	h.eq_int("GodMode-C1 restore needs refills energy", player.energy, 100)
	h.eq_int("GodMode-C2 restore needs refills hunger", player.hunger, 100)
	h.eq_int("GodMode-C3 restore needs refills thirst", player.thirst, 100)

	god.add_money(250)
	h.eq_int("GodMode-C4 add money applies", player.money, 1250)

	god.add_money(-100)
	h.eq_int("GodMode-C5 negative add money is ignored", player.money, 1250)

	god.max_attributes()
	h.check("GodMode-C6 max attributes",
		player.attributes.intelligence == 100.0
		and player.attributes.fitness == 100.0
		and player.attributes.social == 100.0
		and player.attributes.discipline == 100.0
		and player.attributes.creativity == 100.0)

	god.max_traits()
	h.check("GodMode-C7 max traits",
		player.traits.confidence == 100.0
		and player.traits.curiosity == 100.0
		and player.traits.patience == 100.0
		and player.traits.ambition == 100.0
		and player.traits.empathy == 100.0)

	god.max_skills()
	h.eq_int("GodMode-C8 max skills", player.skills.academics.experience, SkillProgress.MAX_EXPERIENCE)
	h.eq_int("GodMode-C9 max skills level", player.skills.academics.level, 100)

	player.skills.academics.add_experience(1000)
	h.eq_int("GodMode-C10 maxed skills stay capped", player.skills.academics.experience, SkillProgress.MAX_EXPERIENCE)
	god.max_attributes()
	player.attributes.add_intelligence(50.0)
	h.near_float("GodMode-C11 maxed attributes stay capped", player.attributes.intelligence, 100.0)
