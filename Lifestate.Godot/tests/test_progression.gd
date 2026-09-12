extends RefCounted

## Attribute / trait / skill / education coverage, ported from the C#
## Attribute-A*, Skill-S*, Trait-T* and Education-E* sections.


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func run(h: TestHarness) -> void:
	_attributes(h)
	_traits(h)
	_skills(h)
	_education(h)


static func _attributes(h: TestHarness) -> void:
	h.section("Attribute-A")

	var attributes := PlayerAttributes.new()
	h.near_float("Attribute-A1 intelligence default", attributes.intelligence, 10.0)
	h.near_float("Attribute-A2 fitness default", attributes.fitness, 10.0)
	h.near_float("Attribute-A3 social default", attributes.social, 10.0)
	h.near_float("Attribute-A4 discipline default", attributes.discipline, 10.0)
	h.near_float("Attribute-A5 creativity default", attributes.creativity, 10.0)

	attributes.add_intelligence(5.0)
	h.near_float("Attribute-A6 controlled mutation applies", attributes.intelligence, 15.0)

	attributes.add_intelligence(1000.0)
	h.near_float("Attribute-A7 mutations clamp at 100", attributes.intelligence, 100.0)

	attributes.add_intelligence(-1000.0)
	h.near_float("Attribute-A8 mutations clamp at 0", attributes.intelligence, 0.0)

	attributes.add_intelligence(NAN)
	h.near_float("Attribute-A9 NaN mutation is a no-op", attributes.intelligence, 0.0)

	attributes.add_intelligence(INF)
	h.near_float("Attribute-A10 Inf mutation is a no-op", attributes.intelligence, 0.0)

	attributes.restore(20.0, 30.0, 40.0, 50.0, 60.0)
	h.near_float("Attribute-A11 restore applies valid values", attributes.intelligence, 20.0)
	h.near_float("Attribute-A12 restore applies all fields", attributes.creativity, 60.0)

	attributes.restore(500.0, -500.0, 40.0, 50.0, 60.0)
	h.near_float("Attribute-A13 restore clamps high", attributes.intelligence, 100.0)
	h.near_float("Attribute-A14 restore clamps low", attributes.fitness, 0.0)

	attributes.restore(NAN, 30.0, 40.0, 50.0, 60.0)
	h.near_float("Attribute-A15 restore rejects NaN", attributes.intelligence, 100.0)

	attributes.set_all_max()
	h.check("Attribute-A16 set_all_max",
		attributes.intelligence == 100.0 and attributes.discipline == 100.0 and attributes.creativity == 100.0)

	# Explicit zero must persist as zero rather than falling back to the default.
	attributes.restore(0.0, 0.0, 0.0, 0.0, 0.0)
	h.near_float("Attribute-A17 explicit zero is preserved", attributes.intelligence, 0.0)


static func _traits(h: TestHarness) -> void:
	h.section("Trait-T")

	var traits := PlayerTraits.new()
	h.near_float("Trait-T1 confidence default", traits.confidence, 50.0)
	h.near_float("Trait-T2 curiosity default", traits.curiosity, 50.0)
	h.near_float("Trait-T3 patience default", traits.patience, 50.0)
	h.near_float("Trait-T4 ambition default", traits.ambition, 50.0)
	h.near_float("Trait-T5 empathy default", traits.empathy, 50.0)

	traits.add_empathy(1.0)
	h.near_float("Trait-T6 controlled mutation applies", traits.empathy, 51.0)

	traits.add_empathy(-100.0)
	h.near_float("Trait-T7 mutation clamps at 0", traits.empathy, 0.0)

	traits.add_empathy(1000.0)
	h.near_float("Trait-T8 mutation clamps at 100", traits.empathy, 100.0)

	traits.add_confidence(NAN)
	h.near_float("Trait-T9 NaN mutation is a no-op", traits.confidence, 50.0)

	traits.set_all_max()
	h.check("Trait-T10 set_all_max",
		traits.confidence == 100.0 and traits.patience == 100.0 and traits.ambition == 100.0)

	traits.restore(10.0, 20.0, 30.0, 40.0, 50.0)
	h.near_float("Trait-T11 restore applies values", traits.confidence, 10.0)
	h.near_float("Trait-T12 restore applies all fields", traits.empathy, 50.0)


static func _skills(h: TestHarness) -> void:
	h.section("Skill-S")

	var skills := PlayerSkills.new()
	h.eq_int("Skill-S1 experience starts at 0", skills.academics.experience, 0)
	h.eq_int("Skill-S2 level starts at 0", skills.academics.level, 0)

	skills.academics.add_experience(50)
	h.eq_int("Skill-S3 experience accumulates", skills.academics.experience, 50)
	h.eq_int("Skill-S4 level derives from experience", skills.academics.level, 0)

	skills.academics.add_experience(50)
	h.eq_int("Skill-S5 first level at 100 experience", skills.academics.level, 1)

	skills.academics.add_experience(0)
	h.eq_int("Skill-S6 zero experience is a no-op", skills.academics.experience, 100)

	skills.academics.add_experience(-50)
	h.eq_int("Skill-S7 negative experience is a no-op", skills.academics.experience, 100)

	skills.academics.add_experience(9900)
	h.eq_int("Skill-S8 experience caps at max", skills.academics.experience, SkillProgress.MAX_EXPERIENCE)
	h.eq_int("Skill-S9 max level is 100", skills.academics.level, 100)

	skills.academics.add_experience(500)
	h.eq_int("Skill-S10 cap is sticky", skills.academics.experience, SkillProgress.MAX_EXPERIENCE)

	var restore_skill := SkillProgress.new()
	restore_skill.restore(250)
	h.eq_int("Skill-S11 restore applies valid value", restore_skill.experience, 250)
	restore_skill.restore(-1)
	h.eq_int("Skill-S12 invalid low restore is a no-op", restore_skill.experience, 250)
	restore_skill.restore(SkillProgress.MAX_EXPERIENCE + 1)
	h.eq_int("Skill-S13 invalid high restore is a no-op", restore_skill.experience, 250)
	restore_skill.set_max()
	h.eq_int("Skill-S14 set_max", restore_skill.experience, SkillProgress.MAX_EXPERIENCE)


static func _education(h: TestHarness) -> void:
	h.section("Education-E")

	var education := EducationState.new()
	h.eq_int("Education-E1 starts not enrolled", education.status, EducationState.Status.NOT_ENROLLED)
	h.eq_int("Education-E2 grade starts at 0", education.primary_grade, 0)

	h.eq_bool("Education-E3 first enrolment succeeds", education.try_enroll(2190), true)
	h.eq_int("Education-E4 status is enrolled", education.status, EducationState.Status.PRIMARY_SCHOOL)
	h.eq_int("Education-E5 grade starts at 1", education.primary_grade, 1)
	h.eq_int("Education-E6 school year start recorded", education.school_year_start_day, 2190)
	h.eq_bool("Education-E7 second enrolment fails", education.try_enroll(2190), false)

	education.add_progress(40)
	h.eq_int("Education-E8 progress accumulates", education.education_progress, 40)

	education.add_progress(500)
	h.eq_int("Education-E9 progress caps at 100", education.education_progress, 100)

	education.add_progress(0)
	h.eq_int("Education-E10 zero progress is a no-op", education.education_progress, 100)

	education.evaluate_progression(2190 + 364)
	h.eq_int("Education-E11 calendar alone does not advance", education.primary_grade, 1)

	education.evaluate_progression(2190 + 365)
	h.eq_int("Education-E12 grade advances with calendar + progress", education.primary_grade, 2)
	h.eq_int("Education-E13 progress resets on grade advance", education.education_progress, 0)
	h.eq_int("Education-E14 school year restarts", education.school_year_start_day, 2555)

	education.evaluate_progression(2555 + 800)
	h.eq_int("Education-E15 no advance without progress", education.primary_grade, 2)

	# Grade 6 completion.
	var completing := EducationState.new()
	completing.try_enroll(0)
	var day: int = 0
	for _grade in range(6):
		completing.add_progress(100)
		day += 365
		completing.evaluate_progression(day)
	h.eq_int("Education-E16 completes after grade 6", completing.status, EducationState.Status.COMPLETED_PRIMARY)
	h.eq_int("Education-E17 final grade is 6", completing.primary_grade, 6)
	h.eq_int("Education-E18 completion progress is 100", completing.education_progress, 100)

	completing.evaluate_progression(day + 4000)
	h.eq_int("Education-E19 completion is terminal", completing.status, EducationState.Status.COMPLETED_PRIMARY)

	# Restore invariants (mirrors the C# defense-in-depth checks).
	var invariant := EducationState.new()
	h.eq_bool("Education-E20 rejects inconsistent not-enrolled restore",
		invariant.restore(EducationState.Status.NOT_ENROLLED, 1, 0, 0), false)
	h.eq_bool("Education-E21 rejects grade 0 when enrolled",
		invariant.restore(EducationState.Status.PRIMARY_SCHOOL, 0, 0, 0), false)
	h.eq_bool("Education-E22 rejects grade 7", invariant.restore(EducationState.Status.PRIMARY_SCHOOL, 7, 0, 0), false)
	h.eq_bool("Education-E23 rejects progress 101", invariant.restore(EducationState.Status.PRIMARY_SCHOOL, 1, 101, 0), false)
	h.eq_bool("Education-E24 rejects incomplete completion",
		invariant.restore(EducationState.Status.COMPLETED_PRIMARY, 5, 100, 0), false)
	h.eq_bool("Education-E25 accepts valid enrolled restore",
		invariant.restore(EducationState.Status.PRIMARY_SCHOOL, 3, 50, 800), true)
	h.eq_int("Education-E26 restored grade", invariant.primary_grade, 3)
	h.eq_bool("Education-E27 rejects unknown status", invariant.restore(99, 1, 0, 0), false)
	h.eq_int("Education-E28 failed restore leaves state intact", invariant.primary_grade, 3)

	# Enrolment is age gated and immediately evaluates event eligibility.
	var clock := GameClock.new()
	var player := PlayerState.new(clock)
	h.eq_bool("Education-E29 underage enrolment rejected", player.enroll_primary_school(), false)
	advance_days(clock, 6 * 365)
	h.eq_bool("Education-E30 age 6 enrolment accepted", player.enroll_primary_school(), true)
	h.check("Education-E31 enrolment immediately triggers First Day of School",
		player.events.current_event != null and player.events.current_event.event_id == LifeEventCatalog.FIRST_DAY_SCHOOL_ID)
