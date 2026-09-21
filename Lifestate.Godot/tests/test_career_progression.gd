extends RefCounted

## Career progression foundation coverage: 12 rank definitions, per-career
## Career XP, manual promotions, independent career histories, rank-aware
## wages across normal/bulk/offline simulation, death cutoff, Save Version 11
## persistence/migration/validation, God Mode tooling and deprivation
## regression protection.

const TEST_PATH: String = "user://test_career_progression.json"
const FIXED_NOW: float = 1792000000.0


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


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


static func _hire_adult(player: PlayerState, clock: GameClock, job_id: String) -> bool:
	advance_days(clock, 18 * 365)
	_meet_requirements(player, job_id)
	return player.apply_for_job(job_id)


## Works `hours` completed hours while keeping needs alive (topped up between
## 10-hour chunks, so deprivation never starts and only Work is measured).
static func _work(player: PlayerState, hours: int) -> void:
	player.start_working()
	TestHarness.advance_kept_alive(player, hours * 60)
	player.stop_working()


static func run(h: TestHarness) -> void:
	_definitions(h)
	_experience(h)
	_promotions(h)
	_history(h)
	_wages(h)
	_bulk_offline(h)
	_death_cutoff(h)
	_save_v11(h)
	_validation(h)
	_offline_restore(h)
	_godmode(h)


# =====================================================================
# Rank definitions: exact 12 positions and promotion requirements
# =====================================================================

static func _definitions(h: TestHarness) -> void:
	h.section("Prog-D")

	var laborer: JobDefinition = JobCatalog.get_by_id(JobCatalog.LABORER_ID)
	h.eq_int("Prog-D1 laborer has three ranks", laborer.max_rank(), 3)
	h.eq_string("Prog-D2 R1 title", laborer.title_at(1), "Laborer")
	h.eq_int("Prog-D3 R1 wage", laborer.wage_at(1), 10)
	h.eq_string("Prog-D4 R2 title", laborer.title_at(2), "Skilled Laborer")
	h.eq_int("Prog-D5 R2 wage", laborer.wage_at(2), 15)
	h.eq_string("Prog-D6 R3 title", laborer.title_at(3), "Crew Leader")
	h.eq_int("Prog-D7 R3 wage", laborer.wage_at(3), 22)
	var labor_r2: CareerRank = laborer.rank_definition(2)
	h.check("Prog-D8 R2 gates XP 500 + fitness 25",
		labor_r2.promotion_xp == 500 and labor_r2.promotion_attribute == "fitness"
		and labor_r2.promotion_attribute_min == 25.0)
	var labor_r3: CareerRank = laborer.rank_definition(3)
	h.check("Prog-D9 R3 gates XP 1500 + fitness 40",
		labor_r3.promotion_xp == 1500 and labor_r3.promotion_attribute == "fitness"
		and labor_r3.promotion_attribute_min == 40.0)

	var retail: JobDefinition = JobCatalog.get_by_id(JobCatalog.RETAIL_WORKER_ID)
	h.eq_string("Prog-D10 retail R1/R2/R3 titles",
		"%s/%s/%s" % [retail.title_at(1), retail.title_at(2), retail.title_at(3)],
		"Retail Worker/Senior Associate/Store Supervisor")
	h.check("Prog-D11 retail wages 12/17/25",
		retail.wage_at(1) == 12 and retail.wage_at(2) == 17 and retail.wage_at(3) == 25)
	var retail_r2: CareerRank = retail.rank_definition(2)
	h.check("Prog-D12 retail R2 gates XP 500 + social 25",
		retail_r2.promotion_xp == 500 and retail_r2.promotion_attribute == "social"
		and retail_r2.promotion_attribute_min == 25.0)
	var retail_r3: CareerRank = retail.rank_definition(3)
	h.check("Prog-D13 retail R3 gates XP 1500 + social 40",
		retail_r3.promotion_xp == 1500 and retail_r3.promotion_attribute == "social"
		and retail_r3.promotion_attribute_min == 40.0)

	var delivery: JobDefinition = JobCatalog.get_by_id(JobCatalog.DELIVERY_DRIVER_ID)
	h.eq_string("Prog-D14 delivery R1/R2/R3 titles",
		"%s/%s/%s" % [delivery.title_at(1), delivery.title_at(2), delivery.title_at(3)],
		"Delivery Driver/Senior Driver/Route Supervisor")
	h.check("Prog-D15 delivery wages 15/21/29",
		delivery.wage_at(1) == 15 and delivery.wage_at(2) == 21 and delivery.wage_at(3) == 29)
	var delivery_r2: CareerRank = delivery.rank_definition(2)
	h.check("Prog-D16 delivery R2 gates XP 500 + discipline 30",
		delivery_r2.promotion_xp == 500 and delivery_r2.promotion_attribute == "discipline"
		and delivery_r2.promotion_attribute_min == 30.0)
	var delivery_r3: CareerRank = delivery.rank_definition(3)
	h.check("Prog-D17 delivery R3 gates XP 1500 + discipline 45",
		delivery_r3.promotion_xp == 1500 and delivery_r3.promotion_attribute == "discipline"
		and delivery_r3.promotion_attribute_min == 45.0)

	var office: JobDefinition = JobCatalog.get_by_id(JobCatalog.OFFICE_CLERK_ID)
	h.eq_string("Prog-D18 office R1/R2/R3 titles",
		"%s/%s/%s" % [office.title_at(1), office.title_at(2), office.title_at(3)],
		"Office Clerk/Senior Clerk/Office Supervisor")
	h.check("Prog-D19 office wages 18/25/35",
		office.wage_at(1) == 18 and office.wage_at(2) == 25 and office.wage_at(3) == 35)
	var office_r2: CareerRank = office.rank_definition(2)
	h.check("Prog-D20 office R2 gates XP 500 + intelligence 30",
		office_r2.promotion_xp == 500 and office_r2.promotion_attribute == "intelligence"
		and office_r2.promotion_attribute_min == 30.0)
	var office_r3: CareerRank = office.rank_definition(3)
	h.check("Prog-D21 office R3 gates XP 1500 + intelligence 45",
		office_r3.promotion_xp == 1500 and office_r3.promotion_attribute == "intelligence"
		and office_r3.promotion_attribute_min == 45.0)

	h.check("Prog-D22 out-of-range ranks resolve null",
		laborer.rank_definition(0) == null and laborer.rank_definition(4) == null)
	h.eq_int("Prog-D23 hiring wage still equals R1 wage", laborer.hourly_wage, 10)


# =====================================================================
# Career XP semantics
# =====================================================================

static func _experience(h: TestHarness) -> void:
	h.section("Prog-X")

	var pair := fresh()
	var player: PlayerState = pair[1]
	for job_id in [JobCatalog.LABORER_ID, JobCatalog.RETAIL_WORKER_ID,
			JobCatalog.DELIVERY_DRIVER_ID, JobCatalog.OFFICE_CLERK_ID]:
		h.eq_int("Prog-X1 fresh rank is 1 for %s" % job_id, player.career.get_rank(job_id), 1)
		h.eq_int("Prog-X2 fresh XP is 0 for %s" % job_id, player.career.get_experience(job_id), 0)

	var work_pair := fresh()
	var work_clock: GameClock = work_pair[0]
	var worker: PlayerState = work_pair[1]
	_hire_adult(worker, work_clock, JobCatalog.LABORER_ID)
	worker.start_working()
	var money_before: int = worker.money
	worker.advance_simulation(59)
	h.eq_int("Prog-X3 59 minutes earns no money", worker.money, money_before)
	h.eq_int("Prog-X4 59 minutes earns no XP", worker.career.get_experience(JobCatalog.LABORER_ID), 0)
	worker.advance_simulation(1)
	h.eq_int("Prog-X5 one completed hour pays the rank wage", worker.money, money_before + 10)
	h.eq_int("Prog-X6 one completed hour grants +10 XP", worker.career.get_experience(JobCatalog.LABORER_ID), 10)
	worker.stop_working()

	# XP accrues only for the held track across multiple hours.
	_work(worker, 3)
	h.eq_int("Prog-X7 three more hours grant +30 XP", worker.career.get_experience(JobCatalog.LABORER_ID), 40)
	h.eq_int("Prog-X8 office track untouched", worker.career.get_experience(JobCatalog.OFFICE_CLERK_ID), 0)
	h.eq_int("Prog-X9 retail track untouched", worker.career.get_experience(JobCatalog.RETAIL_WORKER_ID), 0)
	h.eq_int("Prog-X10 delivery track untouched", worker.career.get_experience(JobCatalog.DELIVERY_DRIVER_ID), 0)

	# Idle time simulates no XP; unemployment cannot start Work.
	var idle_pair := fresh()
	var idle: PlayerState = idle_pair[1]
	advance_days(idle_pair[0], 18 * 365)
	idle.advance_simulation(120)
	h.eq_int("Prog-X11 idle time grants no XP", idle.career.get_experience(JobCatalog.LABORER_ID), 0)
	idle.start_working()
	h.eq_bool("Prog-X12 unemployed Work cannot start", idle.is_working, false)

	# Dead players earn nothing.
	worker.die(PlayerState.CAUSE_STARVATION)
	var xp_at_death: int = worker.career.get_experience(JobCatalog.LABORER_ID)
	worker.advance_simulation(600)
	h.eq_int("Prog-X13 no XP after death", worker.career.get_experience(JobCatalog.LABORER_ID), xp_at_death)

	# Cap: XP saturates at 10000 while wages continue.
	var cap_pair := fresh()
	var cap_clock: GameClock = cap_pair[0]
	var capped: PlayerState = cap_pair[1]
	_hire_adult(capped, cap_clock, JobCatalog.LABORER_ID)
	capped.career.award_experience(JobCatalog.LABORER_ID, 9990)
	capped.start_working()
	var cap_money: int = capped.money
	capped.advance_simulation(120)
	h.eq_int("Prog-X14 XP caps at 10000", capped.career.get_experience(JobCatalog.LABORER_ID), 10000)
	h.eq_int("Prog-X15 capped hours still pay wages", capped.money, cap_money + 20)
	capped.advance_simulation(60)
	h.eq_int("Prog-X16 XP stays capped", capped.career.get_experience(JobCatalog.LABORER_ID), 10000)
	h.eq_int("Prog-X17 wages continue at cap", capped.money, cap_money + 30)
	capped.stop_working()


# =====================================================================
# Manual promotions across all four tracks
# =====================================================================

static func _promotions(h: TestHarness) -> void:
	h.section("Prog-P")

	var tracks: Array = [
		[JobCatalog.LABORER_ID, "fitness", 25.0, 40.0, "Skilled Laborer", "Crew Leader", 15, 22],
		[JobCatalog.RETAIL_WORKER_ID, "social", 25.0, 40.0, "Senior Associate", "Store Supervisor", 17, 25],
		[JobCatalog.DELIVERY_DRIVER_ID, "discipline", 30.0, 45.0, "Senior Driver", "Route Supervisor", 21, 29],
		[JobCatalog.OFFICE_CLERK_ID, "intelligence", 30.0, 45.0, "Senior Clerk", "Office Supervisor", 25, 35],
	]
	for track in tracks:
		_promote_track(h, track)

	# Unemployed and dead promotion attempts fail cleanly.
	var idle_pair := fresh()
	var idle: PlayerState = idle_pair[1]
	advance_days(idle_pair[0], 18 * 365)
	var idle_eval: Dictionary = idle.evaluate_promotion()
	h.eq_bool("Prog-P40 unemployed cannot promote", idle.promote(), false)
	h.eq_string("Prog-P41 unemployed reason", idle_eval["reason"], "You are not employed.")

	var dead_pair := fresh()
	var dead_clock: GameClock = dead_pair[0]
	var dead: PlayerState = dead_pair[1]
	_hire_adult(dead, dead_clock, JobCatalog.LABORER_ID)
	dead.die(PlayerState.CAUSE_STARVATION)
	var dead_eval: Dictionary = dead.evaluate_promotion()
	h.eq_bool("Prog-P42 dead cannot promote", dead.promote(), false)
	h.eq_string("Prog-P43 dead reason", dead_eval["reason"], "Life has ended.")


static func _promote_track(h: TestHarness, track: Array) -> void:
	var job_id: String = track[0]
	var attr: String = track[1]
	var attr_first: float = track[2]
	var attr_second: float = track[3]
	var title_2: String = track[4]
	var title_3: String = track[5]
	var wage_2: int = track[6]
	var wage_3: int = track[7]

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	h.check("Prog-P %s hires" % job_id, _hire_adult(player, clock, job_id))

	var no_xp: Dictionary = player.evaluate_promotion()
	h.eq_bool("Prog-P %s blocked without XP" % job_id, player.promote(), false)
	h.eq_string("Prog-P %s XP reason" % job_id, no_xp["reason"], "Need 500 Career XP.")

	player.career.award_experience(job_id, 500)
	_set_attribute(player, attr, attr_first - 0.1)
	var no_attr: Dictionary = player.evaluate_promotion()
	h.eq_bool("Prog-P %s blocked without attribute" % job_id, player.promote(), false)
	h.eq_string("Prog-P %s attribute reason" % job_id, no_attr["reason"],
		"%s must be at least %d." % [attr.capitalize(), int(attr_first)])

	_set_attribute(player, attr, attr_first)
	h.check("Prog-P %s promotable at exact thresholds" % job_id, player.can_promote())
	h.check("Prog-P %s first promotion succeeds" % job_id, player.promote())
	h.eq_int("Prog-P %s exactly one rank" % job_id, player.career.current_rank(), 2)
	h.eq_int("Prog-P %s XP unchanged by promotion" % job_id, player.career.current_experience(), 500)
	h.eq_string("Prog-P %s job id unchanged" % job_id, player.career.current_job_id, job_id)
	h.eq_string("Prog-P %s title resolves" % job_id, player.career.current_title(), title_2)
	h.eq_int("Prog-P %s wage resolves" % job_id, player.career.hourly_wage(), wage_2)

	var second_xp: Dictionary = player.evaluate_promotion()
	h.eq_bool("Prog-P %s second promotion needs more XP" % job_id, player.promote(), false)
	h.eq_string("Prog-P %s second XP reason" % job_id, second_xp["reason"], "Need 1500 Career XP.")

	player.career.award_experience(job_id, 1000)
	_set_attribute(player, attr, attr_second - 0.1)
	h.eq_bool("Prog-P %s blocked below second attribute" % job_id, player.promote(), false)
	_set_attribute(player, attr, attr_second)
	h.check("Prog-P %s second promotion succeeds" % job_id, player.promote())
	h.eq_int("Prog-P %s reaches rank 3" % job_id, player.career.current_rank(), 3)
	h.eq_int("Prog-P %s cumulative XP kept" % job_id, player.career.current_experience(), 1500)
	h.eq_string("Prog-P %s rank 3 title" % job_id, player.career.current_title(), title_3)
	h.eq_int("Prog-P %s rank 3 wage" % job_id, player.career.hourly_wage(), wage_3)

	var maxed: Dictionary = player.evaluate_promotion()
	h.eq_bool("Prog-P %s rank 3 cannot promote" % job_id, player.promote(), false)
	h.eq_string("Prog-P %s max-rank reason" % job_id, maxed["reason"], "Maximum career rank reached.")


static func _set_attribute(player: PlayerState, attr: String, value: float) -> void:
	match attr:
		"fitness":
			player.attributes.restore(10.0, value, 10.0, 10.0, 10.0)
		"social":
			player.attributes.restore(10.0, 10.0, value, 10.0, 10.0)
		"discipline":
			player.attributes.restore(10.0, 10.0, 10.0, value, 10.0)
		"intelligence":
			player.attributes.restore(value, 10.0, 10.0, 10.0, 10.0)


# =====================================================================
# Independent career histories
# =====================================================================

static func _history(h: TestHarness) -> void:
	h.section("Prog-H")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 18 * 365)

	h.check("Prog-H1 labor hires", player.apply_for_job(JobCatalog.LABORER_ID))
	player.career.award_experience(JobCatalog.LABORER_ID, 900)
	player.attributes.restore(10.0, 30.0, 10.0, 10.0, 10.0)
	h.check("Prog-H2 labor promotes to rank 2", player.promote())
	h.eq_string("Prog-H3 labor title resolves", player.career.current_title(), "Skilled Laborer")
	h.check("Prog-H4 labor quits", player.quit_job())
	h.eq_int("Prog-H5 labor rank retained while unemployed", player.career.get_rank(JobCatalog.LABORER_ID), 2)
	h.eq_int("Prog-H6 labor XP retained while unemployed", player.career.get_experience(JobCatalog.LABORER_ID), 900)

	_meet_requirements(player, JobCatalog.OFFICE_CLERK_ID)
	h.check("Prog-H7 office hires", player.apply_for_job(JobCatalog.OFFICE_CLERK_ID))
	player.career.award_experience(JobCatalog.OFFICE_CLERK_ID, 300)
	h.eq_int("Prog-H8 office starts at rank 1", player.career.get_rank(JobCatalog.OFFICE_CLERK_ID), 1)
	h.check("Prog-H9 office quits", player.quit_job())

	# Rehire restores the earned position at once, with base entry rules only.
	h.check("Prog-H10 labor rehires with base requirements", player.apply_for_job(JobCatalog.LABORER_ID))
	h.eq_int("Prog-H11 labor rank restored", player.career.current_rank(), 2)
	h.eq_int("Prog-H12 labor XP restored", player.career.current_experience(), 900)
	h.eq_string("Prog-H13 labor title immediate", player.career.current_title(), "Skilled Laborer")
	h.check("Prog-H14 labor quits again", player.quit_job())

	_meet_requirements(player, JobCatalog.OFFICE_CLERK_ID)
	h.check("Prog-H15 office rehires", player.apply_for_job(JobCatalog.OFFICE_CLERK_ID))
	h.eq_int("Prog-H16 office XP retained", player.career.current_experience(), 300)
	h.eq_int("Prog-H17 office rank retained", player.career.current_rank(), 1)
	h.eq_int("Prog-H18 labor history untouched by office", player.career.get_experience(JobCatalog.LABORER_ID), 900)


# =====================================================================
# Rank-aware wages in real Work
# =====================================================================

static func _wages(h: TestHarness) -> void:
	h.section("Prog-W")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_hire_adult(player, clock, JobCatalog.LABORER_ID)

	player.start_working()
	var money: int = player.money
	player.advance_simulation(60)
	h.eq_int("Prog-W1 labor R1 hour pays 10", player.money, money + 10)
	player.stop_working()

	player.career.award_experience(JobCatalog.LABORER_ID, 500)
	player.attributes.restore(10.0, 25.0, 10.0, 10.0, 10.0)
	h.check("Prog-W2 promotes to rank 2", player.promote())
	player.start_working()
	money = player.money
	player.advance_simulation(60)
	h.eq_int("Prog-W3 labor R2 hour pays 15", player.money, money + 15)
	player.stop_working()

	# Promotion mid-shift: later completed hours use the new wage while the
	# shift itself continues uninterrupted.
	player.start_working()
	money = player.money
	player.advance_simulation(30)
	player.career.award_experience(JobCatalog.LABORER_ID, 1000)
	player.attributes.restore(10.0, 40.0, 10.0, 10.0, 10.0)
	h.check("Prog-W4 mid-shift promotion succeeds", player.promote())
	h.eq_bool("Prog-W5 Work continues through promotion", player.is_working, true)
	player.advance_simulation(30)
	h.eq_int("Prog-W6 split hour pays at the new wage", player.money, money + 22)
	player.stop_working()

	player.start_working()
	money = player.money
	player.advance_simulation(60)
	h.eq_int("Prog-W7 labor R3 hour pays 22", player.money, money + 22)
	player.stop_working()
	h.check("Prog-W8 labor quits", player.quit_job())

	_meet_requirements(player, JobCatalog.OFFICE_CLERK_ID)
	h.check("Prog-W9 office hires", player.apply_for_job(JobCatalog.OFFICE_CLERK_ID))
	player.career.award_experience(JobCatalog.OFFICE_CLERK_ID, 1500)
	player.attributes.restore(45.0, 10.0, 10.0, 10.0, 10.0)
	h.check("Prog-W10 office reaches rank 2", player.promote())
	h.check("Prog-W11 office reaches rank 3", player.promote())
	player.start_working()
	money = player.money
	player.advance_simulation(60)
	h.eq_int("Prog-W12 office R3 hour pays 35", player.money, money + 35)
	player.stop_working()


# =====================================================================
# Bulk and offline progression
# =====================================================================

static func _bulk_offline(h: TestHarness) -> void:
	h.section("Prog-O")

	# Rank 2 bulk: money, XP and partial-hour carry all resolve at rank wage.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_hire_adult(player, clock, JobCatalog.LABORER_ID)
	player.career.award_experience(JobCatalog.LABORER_ID, 500)
	player.attributes.restore(10.0, 25.0, 10.0, 10.0, 10.0)
	h.check("Prog-O1 promotes to rank 2", player.promote())
	player.start_working()
	var money: int = player.money
	player.bulk_advance_simulation(90)
	h.eq_int("Prog-O2 90 bulk minutes pay one rank-2 hour", player.money, money + 15)
	h.eq_int("Prog-O3 90 bulk minutes grant +10 XP", player.career.current_experience(), 510)
	h.eq_int("Prog-O4 30-minute remainder carries", player.get_work_minutes_accumulator(), 30)
	player.bulk_advance_simulation(30)
	h.eq_int("Prog-O5 carried remainder completes at rank wage", player.money, money + 30)
	player.stop_working()

	# Threshold crossing never auto-promotes.
	var cross_pair := fresh()
	var cross_clock: GameClock = cross_pair[0]
	var cross: PlayerState = cross_pair[1]
	_hire_adult(cross, cross_clock, JobCatalog.LABORER_ID)
	cross.career.award_experience(JobCatalog.LABORER_ID, 490)
	cross.attributes.restore(10.0, 25.0, 10.0, 10.0, 10.0)
	cross.start_working()
	cross.advance_simulation(120)
	h.eq_int("Prog-O6 two hours cross the XP threshold", cross.career.current_experience(), 510)
	h.eq_int("Prog-O7 rank stays 1 after crossing", cross.career.current_rank(), 1)
	h.check("Prog-O8 promotion available but not taken", cross.can_promote())
	cross.stop_working()


# =====================================================================
# Death cutoff with progression active
# =====================================================================

static func _death_cutoff(h: TestHarness) -> void:
	h.section("Prog-XD")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_hire_adult(player, clock, JobCatalog.LABORER_ID)
	player.debug_set_health(4.0)
	player.debug_set_thirst(0)
	player.debug_set_hunger(100)
	player.start_working()
	var money: int = player.money
	player.advance_simulation(60)
	h.eq_bool("Prog-XD1 fatal hour kills", player.is_dead, true)
	h.eq_string("Prog-XD2 cause is dehydration", player.cause_of_death, PlayerState.CAUSE_DEHYDRATION)
	h.eq_int("Prog-XD3 lived hour still pays", player.money, money + 10)
	h.eq_int("Prog-XD4 lived hour still grants XP", player.career.get_experience(JobCatalog.LABORER_ID), 10)
	h.eq_int("Prog-XD5 rank unchanged by death", player.career.current_rank(), 1)
	h.eq_string("Prog-XD6 career retained", player.career.current_job_id, JobCatalog.LABORER_ID)
	h.eq_bool("Prog-XD7 Work stopped by death", player.is_working, false)
	player.advance_simulation(600)
	h.eq_int("Prog-XD8 no XP after death", player.career.get_experience(JobCatalog.LABORER_ID), 10)
	h.eq_int("Prog-XD9 no wages after death", player.money, money + 10)
	h.eq_bool("Prog-XD10 no promotion after death", player.promote(), false)


# =====================================================================
# Save Version 11 persistence and migration
# =====================================================================

static func _save_v11(h: TestHarness) -> void:
	h.section("Prog-S")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 18 * 365)
	h.check("Prog-S1 labor hires", player.apply_for_job(JobCatalog.LABORER_ID))
	player.career.award_experience(JobCatalog.LABORER_ID, 900)
	player.attributes.restore(10.0, 30.0, 10.0, 10.0, 10.0)
	h.check("Prog-S2 labor promotes", player.promote())
	h.check("Prog-S3 labor quits", player.quit_job())
	_meet_requirements(player, JobCatalog.OFFICE_CLERK_ID)
	h.check("Prog-S4 office hires", player.apply_for_job(JobCatalog.OFFICE_CLERK_ID))
	player.career.award_experience(JobCatalog.OFFICE_CLERK_ID, 300)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	h.eq_int("Prog-S5 save version is exactly 13", raw["Version"], 13)
	var stored: Dictionary = raw["CareerProgress"]
	h.check("Prog-S6 all four tracks persisted",
		stored.has("laborer") and stored.has("retail_worker")
		and stored.has("delivery_driver") and stored.has("office_clerk"))
	h.eq_int("Prog-S7 labor rank persisted", stored["laborer"]["Rank"], 2)
	h.eq_int("Prog-S8 labor XP persisted", stored["laborer"]["Experience"], 900)
	h.eq_int("Prog-S9 office XP persisted", stored["office_clerk"]["Experience"], 300)

	var loaded := fresh()
	var load_result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW)
	h.check("Prog-S10 load succeeds", load_result["ok"], load_result["error"])
	h.eq_string("Prog-S11 current job round trips",
		loaded[1].career.current_job_id, JobCatalog.OFFICE_CLERK_ID)
	h.eq_int("Prog-S12 labor rank round trips", loaded[1].career.get_rank(JobCatalog.LABORER_ID), 2)
	h.eq_int("Prog-S13 labor XP round trips", loaded[1].career.get_experience(JobCatalog.LABORER_ID), 900)
	h.eq_int("Prog-S14 office rank round trips", loaded[1].career.get_rank(JobCatalog.OFFICE_CLERK_ID), 1)
	h.eq_int("Prog-S15 office XP round trips", loaded[1].career.get_experience(JobCatalog.OFFICE_CLERK_ID), 300)
	h.eq_string("Prog-S16 rehired title resolves from history", loaded[1].career.current_title(), "Office Clerk")

	# v10 migration: no CareerProgress key; every track defaults Rank 1 / XP 0.
	var v10_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	v10_data["Version"] = 10
	v10_data.erase("CareerProgress")
	_write(TEST_PATH, JSON.stringify(v10_data))
	var migrated := fresh()
	var migrate_result: Dictionary = SaveManager.load_game(migrated[0], migrated[1], TEST_PATH, FIXED_NOW)
	h.check("Prog-S17 v10 save still loads", migrate_result["ok"], migrate_result["error"])
	h.eq_string("Prog-S18 v10 current job preserved",
		migrated[1].career.current_job_id, JobCatalog.OFFICE_CLERK_ID)
	for job_id in [JobCatalog.LABORER_ID, JobCatalog.RETAIL_WORKER_ID,
			JobCatalog.DELIVERY_DRIVER_ID, JobCatalog.OFFICE_CLERK_ID]:
		h.eq_int("Prog-S19 v10 %s defaults rank 1" % job_id, migrated[1].career.get_rank(job_id), 1)
		h.eq_int("Prog-S20 v10 %s defaults XP 0" % job_id, migrated[1].career.get_experience(job_id), 0)

	# v8 migration: pre-career saves keep working without progression state.
	# (SecondaryGrade exists since v8, so it stays; v9+ job and v10+ life
	# keys are absent and migrate to defaults.)
	var v8_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	v8_data["Version"] = 8
	v8_data.erase("CareerProgress")
	v8_data.erase("CurrentJobId")
	v8_data.erase("Health")
	v8_data.erase("IsDead")
	v8_data.erase("DeathDay")
	v8_data.erase("DeathAge")
	v8_data.erase("CauseOfDeath")
	v8_data.erase("LifeSeed")
	v8_data.erase("StarvingMinutesAccumulator")
	v8_data.erase("DehydratedMinutesAccumulator")
	v8_data["IsWorking"] = false
	_write(TEST_PATH, JSON.stringify(v8_data))
	var legacy := fresh()
	h.check("Prog-S21 v8 save still loads",
		SaveManager.load_game(legacy[0], legacy[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_int("Prog-S22 v8 labor defaults rank 1",
		legacy[1].career.get_rank(JobCatalog.LABORER_ID), 1)
	h.eq_int("Prog-S23 v8 labor defaults XP 0",
		legacy[1].career.get_experience(JobCatalog.LABORER_ID), 0)

	# Deprivation regression: saved 45-minute streaks still restore exactly.
	var streak_pair := fresh()
	var streak_clock: GameClock = streak_pair[0]
	var streak: PlayerState = streak_pair[1]
	streak.debug_set_thirst(0)
	streak.debug_set_hunger(100)
	streak.advance_simulation(45)
	SaveManager.save_game(streak_clock, streak, TEST_PATH, FIXED_NOW)
	var streak_loaded := fresh()
	SaveManager.load_game(streak_loaded[0], streak_loaded[1], TEST_PATH, FIXED_NOW)
	h.eq_int("Prog-S24 dehydration streak survives v11", streak_loaded[1].get_dehydrated_minutes_accumulator(), 45)
	var bad_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	bad_data["DehydratedMinutesAccumulator"] = 60
	_write(TEST_PATH, JSON.stringify(bad_data))
	h.eq_bool("Prog-S25 malformed streak still rejected",
		SaveManager.load_game(streak_loaded[0], streak_loaded[1], TEST_PATH, FIXED_NOW)["ok"], false)


# =====================================================================
# Version 11 validation and transactional rejection
# =====================================================================

static func _validation(h: TestHarness) -> void:
	h.section("Prog-V")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_hire_adult(player, clock, JobCatalog.LABORER_ID)
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)
	var base_text: String = FileAccess.get_file_as_string(TEST_PATH)

	# Live state that must survive every rejected load untouched.
	var live := fresh()
	var live_clock: GameClock = live[0]
	var live_player: PlayerState = live[1]
	advance_days(live_clock, 20 * 365)
	live_player.money = 4242
	live_player.energy = 61
	live_player.debug_set_hunger(62)
	live_player.debug_set_thirst(63)
	live_player.debug_set_health(42.0)
	live_player.debug_set_thirst(0)
	live_player.advance_simulation(45)
	live_player.apply_for_job(JobCatalog.LABORER_ID)
	live_player.career.award_experience(JobCatalog.LABORER_ID, 900)
	live_clock.restore(4321, 7, 8)

	var cases: Array = [
		["missing CareerProgress", {"__erase__": "CareerProgress"}],
		["CareerProgress not a dict", {"CareerProgress": []}],
		["missing laborer track", {"__erase_track__": "laborer"}],
		["unknown career track", {"__add_track__": "astronaut"}],
		["track entry not a dict", {"__track__": ["laborer", 42]}],
		["missing Rank", {"__track__": ["laborer", {"Experience": 100}]}],
		["missing Experience", {"__track__": ["laborer", {"Rank": 1}]}],
		["rank zero", {"__track__": ["laborer", {"Rank": 0, "Experience": 0}]}],
		["rank four", {"__track__": ["laborer", {"Rank": 4, "Experience": 2000}]}],
		["rank as string", {"__track__": ["laborer", {"Rank": "2", "Experience": 900}]}],
		["negative XP", {"__track__": ["laborer", {"Rank": 1, "Experience": -1}]}],
		["XP over cap", {"__track__": ["laborer", {"Rank": 1, "Experience": 10001}]}],
		["XP null", {"__track__": ["laborer", {"Rank": 1, "Experience": null}]}],
		["rank 2 below 500 XP", {"__track__": ["laborer", {"Rank": 2, "Experience": 499}]}],
		["rank 3 below 1500 XP", {"__track__": ["office_clerk", {"Rank": 3, "Experience": 1499}]}],
	]
	for entry in cases:
		var data: Dictionary = JSON.parse_string(base_text)
		_apply_patch(data, entry[1])
		_write(TEST_PATH, JSON.stringify(data))
		var result: Dictionary = SaveManager.load_game(live_clock, live_player, TEST_PATH, FIXED_NOW)
		h.eq_bool("Prog-V rejects %s" % entry[0], result["ok"], false)

	h.eq_int("Prog-V live clock day untouched", live_clock.day, 4321)
	h.eq_int("Prog-V live clock time untouched", live_clock.hour * 60 + live_clock.minute, 7 * 60 + 8)
	h.eq_int("Prog-V live money untouched", live_player.money, 4242)
	h.eq_int("Prog-V live energy untouched", live_player.energy, 61)
	h.eq_int("Prog-V live hunger untouched", live_player.hunger, 62)
	h.eq_int("Prog-V live thirst untouched", live_player.thirst, 0)
	h.near_float("Prog-V live health untouched", live_player.health, 42.0)
	h.eq_bool("Prog-V live death state untouched", live_player.is_dead, false)
	h.eq_string("Prog-V live career untouched", live_player.career.current_job_id, JobCatalog.LABORER_ID)
	h.eq_int("Prog-V live labor rank untouched", live_player.career.get_rank(JobCatalog.LABORER_ID), 1)
	h.eq_int("Prog-V live labor XP untouched", live_player.career.get_experience(JobCatalog.LABORER_ID), 900)
	h.eq_int("Prog-V live streak untouched", live_player.get_dehydrated_minutes_accumulator(), 45)

	# Boundary-accepted states load cleanly.
	var good2: Dictionary = JSON.parse_string(base_text)
	(good2["CareerProgress"] as Dictionary)["laborer"] = {"Rank": 2, "Experience": 500}
	_write(TEST_PATH, JSON.stringify(good2))
	var good_loaded := fresh()
	h.check("Prog-V rank 2 at exactly 500 XP loads",
		SaveManager.load_game(good_loaded[0], good_loaded[1], TEST_PATH, FIXED_NOW)["ok"])
	h.eq_int("Prog-V boundary rank restores", good_loaded[1].career.get_rank(JobCatalog.LABORER_ID), 2)

	var good3: Dictionary = JSON.parse_string(base_text)
	(good3["CareerProgress"] as Dictionary)["office_clerk"] = {"Rank": 3, "Experience": 1500}
	_write(TEST_PATH, JSON.stringify(good3))
	var good3_loaded := fresh()
	h.check("Prog-V rank 3 at exactly 1500 XP loads",
		SaveManager.load_game(good3_loaded[0], good3_loaded[1], TEST_PATH, FIXED_NOW)["ok"])


static func _apply_patch(data: Dictionary, patch: Dictionary) -> void:
	for key in patch:
		if key == "__erase__":
			data.erase(patch[key])
		elif key == "__erase_track__":
			(data["CareerProgress"] as Dictionary).erase(patch[key])
		elif key == "__add_track__":
			(data["CareerProgress"] as Dictionary)[patch[key]] = {"Rank": 1, "Experience": 0}
		elif key == "__track__":
			var track_patch: Array = patch[key]
			(data["CareerProgress"] as Dictionary)[track_patch[0]] = track_patch[1]
		else:
			data[key] = patch[key]


# =====================================================================
# Offline progression restores rank before simulating
# =====================================================================

static func _offline_restore(h: TestHarness) -> void:
	h.section("Prog-OL")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_hire_adult(player, clock, JobCatalog.LABORER_ID)
	player.career.award_experience(JobCatalog.LABORER_ID, 900)
	player.attributes.restore(10.0, 30.0, 10.0, 10.0, 10.0)
	h.check("Prog-OL1 promotes to rank 2", player.promote())
	player.start_working()
	var money: int = player.money
	SaveManager.save_game(clock, player, TEST_PATH, FIXED_NOW)

	# One real minute offline = 240 game minutes = 4 completed Work hours.
	var loaded := fresh()
	var result: Dictionary = SaveManager.load_game(loaded[0], loaded[1], TEST_PATH, FIXED_NOW + 60.0)
	h.check("Prog-OL2 offline load succeeds", result["ok"], result["error"])
	h.eq_int("Prog-OL3 offline pays the rank-2 wage, not rank 1",
		loaded[1].money, money + 4 * 15)
	h.eq_int("Prog-OL4 offline XP continues from 900",
		loaded[1].career.get_experience(JobCatalog.LABORER_ID), 940)
	h.eq_int("Prog-OL5 offline never auto-promotes", loaded[1].career.current_rank(), 2)
	h.eq_string("Prog-OL6 offline title stays rank 2",
		loaded[1].career.current_title(), "Skilled Laborer")
	h.eq_bool("Prog-OL7 still working after offline", loaded[1].is_working, true)


# =====================================================================
# God Mode career tool
# =====================================================================

static func _godmode(h: TestHarness) -> void:
	h.section("Prog-G")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	_hire_adult(player, clock, JobCatalog.LABORER_ID)
	var god := GodMode.new(clock, player)

	var idle_god := GodMode.new(clock, player)
	h.eq_bool("Prog-G1 disabled tool fails", idle_god.max_career_xp()["ok"], false)

	god.set_enabled(true)
	var result: Dictionary = god.max_career_xp()
	h.eq_bool("Prog-G2 max XP succeeds", result["ok"], true)
	h.eq_int("Prog-G3 current XP pinned to cap", player.career.get_experience(JobCatalog.LABORER_ID), 10000)
	h.eq_int("Prog-G4 rank untouched", player.career.current_rank(), 1)
	h.eq_int("Prog-G5 other tracks untouched", player.career.get_experience(JobCatalog.OFFICE_CLERK_ID), 0)
	h.eq_int("Prog-G6 money untouched", player.money, 1000)

	h.check("Prog-G7 labor quits", player.quit_job())
	var unemployed: Dictionary = god.max_career_xp()
	h.eq_bool("Prog-G8 unemployed fails cleanly", unemployed["ok"], false)
	h.eq_string("Prog-G9 unemployed message", unemployed["message"], "You are not employed.")

	player.die(PlayerState.CAUSE_STARVATION)
	var dead: Dictionary = god.max_career_xp()
	h.eq_bool("Prog-G10 dead fails cleanly", dead["ok"], false)
	h.eq_string("Prog-G11 dead message", dead["message"], "Life has ended.")


static func _write(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false}
	file.store_string(text)
	file.close()
	return {"ok": true}
