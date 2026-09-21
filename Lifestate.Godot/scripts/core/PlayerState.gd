class_name PlayerState
extends RefCounted

## Ported 1:1 from the C# reference implementation (PlayerState.cs), then
## extended post-migration with the Godot-only Health + Death foundation.
##
## Sub-hour accumulators are load-bearing for simulation correctness: rewards
## only apply on completed hours while remainders carry across calls, so partial
## hours must never be dropped or simplified away.
##
## Death semantics (Godot-only, Save Version 10+):
##   - Health 0..100, damaged 2/hour while starving and 5/hour while dehydrated
##     (7/hour when both), per completed hour of deprivation time.
##   - The hour in which a need REACHES zero is never a damage hour; damage
##     starts with the first completed hour after the need is already zero.
##   - Death is one authoritative transition (die): deprivation damage and
##     deterministic old-age mortality both go through it.
##   - The simulation engine advances time in segments bounded by midnights,
##     need-zero crossings and deprivation-hour boundaries, so death lands on
##     the exact minute and the clock stops there. Normal play, Wait 1 Hour and
##     offline bulk progression all run the SAME engine, so results are
##     equivalent by construction and offline progression stays bounded (~70
##     game hours to the worst-case death, never a per-minute replay).
##   - Old-age mortality is evaluated once per newly entered day from a
##     deterministic roll over (LifeSeed, day); God Mode time skips sync the
##     mortality pointer WITHOUT evaluating, so skips never kill.

const INT32_MAX: int = 2147483647
const INT64_MAX: int = 9223372036854775807

const NEEDS_MAX: int = 100
const MINUTES_PER_HOUR: int = 60

const STARTING_MONEY: int = 1000

# --- Rates (identical to the reference) ---
const ENERGY_PER_SLEEP_HOUR: int = 5
const ENERGY_PER_AWAKE_HOUR: int = 1
const HUNGER_PER_HOUR: int = 1
const THIRST_PER_HOUR: int = 2
## Historical flat work wage, kept for reference/legacy-tooling parity only.
## It no longer drives gameplay: work pay comes from the held JobDefinition
## (CareerState.hourly_wage). Laborer matches this value exactly.
const MONEY_PER_WORK_HOUR: int = 10
const STUDY_XP_PER_HOUR: int = 10
const CAREER_XP_PER_WORK_HOUR: int = 10
const INTELLIGENCE_PER_STUDY_HOUR: float = 0.05
const ACADEMICS_XP_PER_STUDY_HOUR: int = 10
const CURIOSITY_PER_STUDY_HOUR: float = 0.02
const PATIENCE_PER_STUDY_HOUR: float = 0.01
const AMBITION_PER_STUDY_HOUR: float = 0.01
const FITNESS_PER_PLAY_HOUR: float = 0.03
const CREATIVITY_PER_PLAY_HOUR: float = 0.03
const CONFIDENCE_PER_PLAY_HOUR: float = 0.02
const CURIOSITY_PER_PLAY_HOUR: float = 0.01
const CLOSENESS_PER_FAMILY_HOUR: float = 0.25
const SOCIAL_PER_FAMILY_HOUR: float = 0.02
const EMPATHY_PER_FAMILY_HOUR: float = 0.02
const CONFIDENCE_PER_FAMILY_HOUR: float = 0.01

const WORK_MIN_AGE: int = 18
const STUDY_MIN_AGE: int = 6
const PLAY_MIN_AGE: int = 2
const ENROLL_MIN_AGE: int = 6
const SECONDARY_ENROLL_MIN_AGE: int = 12

const MAX_EDUCATION_PROGRESS_PER_BULK: int = 100

## Hunger drains exactly 1 per completed hour, so minutes-to-zero is linear.
const HUNGER_PER_HOUR_MINUTES_SCALE: int = 60

# --- Health / Death foundation (Godot-only post-migration) ---
## Stable death-cause identifiers persisted in saves.
const CAUSE_DEHYDRATION: String = "dehydration"
const CAUSE_STARVATION: String = "starvation"
const CAUSE_OLD_AGE: String = "old_age"
const DEATH_CAUSES: Array = [CAUSE_DEHYDRATION, CAUSE_STARVATION, CAUSE_OLD_AGE]

const HEALTH_MAX: float = 100.0
const STARVATION_DAMAGE_PER_HOUR: float = 2.0
const DEHYDRATION_DAMAGE_PER_HOUR: float = 5.0

## LifeSeed domain: persisted 31-bit non-negative integer.
const LIFE_SEED_MAX: int = 2147483647

var _clock: GameClock

var attributes: PlayerAttributes = PlayerAttributes.new()
var skills: PlayerSkills = PlayerSkills.new()
var education: EducationState = EducationState.new()
var traits: PlayerTraits = PlayerTraits.new()
var family: PlayerFamily = PlayerFamily.new()
var relationships: PlayerRelationships
var events: LifeEventSystem
var career: CareerState = CareerState.new()
var economy: EconomyState = EconomyState.new()
var housing: HousingState = HousingState.new()

var total_play_hours: int = 0
var money: int = STARTING_MONEY
var energy: int = NEEDS_MAX
var hunger: int = NEEDS_MAX
var thirst: int = NEEDS_MAX
var study_xp: int = 0

var is_sleeping: bool = false
var is_working: bool = false
var is_studying: bool = false
var is_playing: bool = false
var is_spending_family_time: bool = false

# --- Life / death state ---
var health: float = HEALTH_MAX
var is_dead: bool = false
var death_day: int = -1
var death_age: int = -1
var cause_of_death: String = ""
## Generated once per life, persisted forever, and used for deterministic
## old-age mortality rolls. Legacy saves derive it deterministically.
var life_seed: int = 0

var _awake_minutes_accumulator: int = 0
var _sleeping_minutes_accumulator: int = 0
var _hunger_minutes_accumulator: int = 0
var _thirst_minutes_accumulator: int = 0
var _work_minutes_accumulator: int = 0
var _study_minutes_accumulator: int = 0
var _play_minutes_accumulator: int = 0
var _family_time_minutes_accumulator: int = 0

## Deprivation time accumulators (completed 60-minute deprivation hours).
var _starving_minutes_accumulator: int = 0
var _dehydrated_minutes_accumulator: int = 0

## Last day whose old-age mortality has been resolved. Days are evaluated
## exactly once, at the moment they are entered.
var _mortality_evaluated_day: int = 0

## Last day whose living-expense assessment has been resolved. Like mortality,
## each entered day is assessed exactly once, at the moment it is entered.
var _economy_assessed_day: int = 0


func _init(clock: GameClock) -> void:
	_clock = clock
	relationships = PlayerRelationships.new(family.mother.id, family.father.id)
	events = LifeEventSystem.new(self)
	life_seed = randi() % (LIFE_SEED_MAX + 1)


# =====================================================================
# Derived state
# =====================================================================

var age: int:
	get:
		return _clock.day / GameClock.DAYS_PER_YEAR

var life_stage: int:
	get:
		return LifeStage.for_age(age)

var life_stage_name: String:
	get:
		return LifeStage.display_name(life_stage)


## True when any exclusive activity is running.
func is_active() -> bool:
	return is_sleeping or is_working or is_studying or is_playing or is_spending_family_time


func current_activity_name() -> String:
	if is_sleeping:
		return "Sleeping"
	if is_working:
		return "Working"
	if is_studying:
		return "Studying"
	if is_playing:
		return "Playing"
	if is_spending_family_time:
		return "Family Time"
	return "Idle"


# =====================================================================
# Death (one authoritative transition; everything else defers to it)
# =====================================================================

## The single death transition. Rejects duplicate death and unknown causes.
## Sets the terminal state, stops every activity and freezes the simulation:
## every mutating gameplay method checks is_dead, and the simulation engine
## no-ops entirely once dead, so the clock can never advance past death.
func die(cause_id: String) -> bool:
	if is_dead:
		return false
	if not DEATH_CAUSES.has(cause_id):
		return false

	is_dead = true
	health = 0.0
	death_day = _clock.day
	death_age = age
	cause_of_death = cause_id

	# Clear activity flags directly: the guarded stop_* methods early-return
	# once is_dead is set, and death must leave NO active activity.
	is_sleeping = false
	is_working = false
	is_studying = false
	is_playing = false
	is_spending_family_time = false
	return true


static func display_cause(cause_id: String) -> String:
	match cause_id:
		CAUSE_DEHYDRATION:
			return "Dehydration"
		CAUSE_STARVATION:
			return "Starvation"
		CAUSE_OLD_AGE:
			return "Old Age"
	return "Unknown"


# =====================================================================
# Deterministic old-age mortality
# =====================================================================

## Foundation mortality curve, interpreted literally (percent / 100).
## Evaluated once per newly entered day; never per frame.
static func daily_mortality_probability(age_value: int) -> float:
	if age_value < 60:
		return 0.0
	if age_value < 70:
		return 0.00002   # 0.002%
	if age_value < 80:
		return 0.0001    # 0.01%
	if age_value < 90:
		return 0.0005    # 0.05%
	if age_value < 100:
		return 0.002     # 0.20%
	if age_value < 110:
		return 0.0075    # 0.75%
	return 0.02           # 2.00%


## Deterministic uniform roll in [0, 1) derived from stable state.
## Same LifeSeed + same day always produce the same roll; no wall clock, no
## unseeded RNG — save/load and offline progression cannot reroll death.
static func mortality_roll(seed_value: int, day: int) -> float:
	var mixed: int = _stable_hash(seed_value * 1000003 + day)
	return float(mixed & 0x1FFFFFFFFFFFFF) / 9007199254740992.0


## Stable 63-bit integer mix (splitmix-style). Uses only 64-bit wrapping
## integer arithmetic, so the result is identical on every platform and run.
## Stable integer mix. Deliberately uses only 31-bit operands with multiply
## and add inside 62-bit results, so it never relies on 64-bit wraparound
## semantics and produces identical values on every platform and run.
static func _stable_hash(value: int) -> int:
	var z: int = value & 0x7FFFFFFFFFFFFFFF
	z = (z ^ (z >> 30)) & 0x7FFFFFFF
	z = z * 1103515245 + 12345
	z = (z ^ (z >> 27)) & 0x7FFFFFFF
	z = z * 1103515245 + 12345
	z = z ^ (z >> 31)
	return z & 0x7FFFFFFFFFFFFFFF


## Deterministic migration seed for legacy saves (v2–v9), derived from stable
## saved state so the same legacy save always yields the same LifeSeed.
static func migration_seed(day: int, hour: int, minute: int, money_value: int) -> int:
	return _stable_hash(day * 1000003 + hour * 1009 + minute * 13 + money_value) & 0x7FFFFFFF


## Resolves old-age mortality for every newly entered day. Deprivation death
## is resolved first by the engine within the same segment, so a deprivation
## death at a day boundary always outranks old age (ticket precedence).
func _evaluate_daily_mortality() -> void:
	var day: int = _mortality_evaluated_day + 1
	while day <= _clock.day and not is_dead:
		var probability: float = daily_mortality_probability(day / GameClock.DAYS_PER_YEAR)
		if probability > 0.0 and mortality_roll(life_seed, day) < probability:
			die(CAUSE_OLD_AGE)
			return
		day += 1
	_mortality_evaluated_day = _clock.day


## Assesses the combined living expense for every newly entered day, exactly
## once per day. The rate uses the age on the entered day itself, so bracket
## birthdays take effect immediately with no cached rate. Zero-cost days are
## no-ops; shortfalls accrue to outstanding without touching money (see
## EconomyState). Never runs for the dead, and never for days entered by
## non-simulating clock jumps (those sync the pointer without assessing).
##
## Housing resolves immediately after living expenses for the same entered
## day (living first, housing second), using the home occupied when the day
## becomes due. The two systems stay distinct: separate charges, separate
## totals, separate outstanding balances.
func _assess_entered_days() -> void:
	while _economy_assessed_day < _clock.day and not is_dead:
		_economy_assessed_day += 1
		var expense: int = EconomyState.daily_rate_for_age(
			_economy_assessed_day / GameClock.DAYS_PER_YEAR)
		if expense > 0:
			var living_outcome: Dictionary = economy.apply_daily_charge(expense, money)
			money = living_outcome["new_money"]
		var home: HousingDefinition = housing.current_definition()
		if home != null and home.daily_cost > 0:
			var housing_outcome: Dictionary = housing.apply_daily_charge(home.daily_cost, money)
			money = housing_outcome["new_money"]


## Marks all days up to the current clock day as mortality-resolved WITHOUT
## evaluating them. God Mode time skips call this so skips are predictable and
## never kill the character; the engine calls it at the end of every interval.
## Economy assessments are marked resolved alongside mortality: skips are
## navigation/testing cheats and must never simulate needs, rewards, deaths or
## living expenses for the skipped days.
func sync_mortality_to_clock() -> void:
	_mortality_evaluated_day = _clock.day
	_economy_assessed_day = _clock.day


# =====================================================================
# Activity control (mutual exclusion preserved exactly; dead is locked)
# =====================================================================

func start_sleeping() -> void:
	if is_dead:
		return
	if is_working or is_studying or is_playing or is_spending_family_time:
		return
	is_sleeping = true


func stop_sleeping() -> void:
	if is_dead:
		return
	is_sleeping = false


func start_working() -> void:
	if is_dead:
		return
	# Invariant: only an employed adult may Work. Hiring already enforced the
	# job's minimum age, but the check is preserved here defensively.
	if not career.is_employed() or age < WORK_MIN_AGE or is_sleeping or is_studying or is_playing or is_spending_family_time:
		return
	is_working = true


func stop_working() -> void:
	if is_dead:
		return
	is_working = false


func start_studying() -> void:
	if is_dead:
		return
	if age < STUDY_MIN_AGE or is_sleeping or is_working or is_playing or is_spending_family_time:
		return
	is_studying = true


func stop_studying() -> void:
	if is_dead:
		return
	is_studying = false


func start_playing() -> bool:
	if is_dead:
		return false
	if age < PLAY_MIN_AGE or is_sleeping or is_working or is_studying or is_playing or is_spending_family_time:
		return false
	is_playing = true
	return true


func stop_playing() -> void:
	if is_dead:
		return
	is_playing = false


func start_family_time() -> bool:
	if is_dead:
		return false
	if is_sleeping or is_working or is_studying or is_playing or is_spending_family_time:
		return false
	is_spending_family_time = true
	return true


func stop_family_time() -> void:
	if is_dead:
		return
	is_spending_family_time = false


func enroll_primary_school() -> bool:
	if is_dead:
		return false
	if age < ENROLL_MIN_AGE:
		return false
	var enrolled: bool = education.try_enroll(_clock.day)
	if enrolled:
		# Enrolment can immediately make events eligible (First Day of School).
		events.evaluate_triggers(_clock.day)
	return enrolled

# =====================================================================
# Career (Godot-only post-migration system)
# =====================================================================

## Centralized deterministic job-requirement evaluation. UI reads the reason;
## apply_for_job enforces it. Never duplicate this logic in screens.
func evaluate_application(job_id: String) -> Dictionary:
	if not JobCatalog.is_known_job(job_id):
		return {"ok": false, "reason": "That job does not exist."}
	if is_dead:
		return {"ok": false, "reason": "Life has ended."}
	if career.is_employed():
		return {"ok": false, "reason": "Quit your current job first."}

	var job: JobDefinition = JobCatalog.get_by_id(job_id)
	if age < job.minimum_age:
		return {"ok": false, "reason": "You must be at least %d years old." % job.minimum_age}

	match job.education_requirement:
		JobDefinition.EducationRequirement.PRIMARY_COMPLETED:
			if education.status != EducationState.Status.COMPLETED_PRIMARY and education.status != EducationState.Status.COMPLETED_SECONDARY:
				return {"ok": false, "reason": "Complete primary school first."}
		JobDefinition.EducationRequirement.SECONDARY_COMPLETED:
			if education.status != EducationState.Status.COMPLETED_SECONDARY:
				return {"ok": false, "reason": "Complete secondary school first."}

	if not job.required_attribute.is_empty():
		var value: float = _attribute_value(job.required_attribute)
		if value < job.required_attribute_min:
			return {"ok": false, "reason": "%s must be at least %d." % [job.required_attribute.capitalize(), int(job.required_attribute_min)]}

	return {"ok": true, "reason": ""}


func can_apply(job_id: String) -> bool:
	return evaluate_application(job_id)["ok"]


## Deterministic hire: requirements met means hired immediately.
func apply_for_job(job_id: String) -> bool:
	if not evaluate_application(job_id)["ok"]:
		return false
	if not career.hire(job_id):
		return false
	events.evaluate_triggers(_clock.day)
	return true


## Quitting clears the job and stops an active Work session so the
## is_working == true while unemployed invariant can never hold.
func quit_job() -> bool:
	if is_dead:
		return false
	if not career.quit():
		return false
	if is_working:
		stop_working()
	return true


func _attribute_value(name: String) -> float:
	match name:
		"intelligence":
			return attributes.intelligence
		"fitness":
			return attributes.fitness
		"social":
			return attributes.social
		"discipline":
			return attributes.discipline
	return 0.0


## Centralized promotion evaluation. UI reads the reason; promote() enforces
## it. Never duplicate this logic in screens.
func evaluate_promotion() -> Dictionary:
	if is_dead:
		return {"ok": false, "reason": "Life has ended."}
	if not career.is_employed():
		return {"ok": false, "reason": "You are not employed."}
	var job: JobDefinition = career.current_job()
	if job == null:
		return {"ok": false, "reason": "That job does not exist."}
	var next_definition: CareerRank = career.next_rank_definition()
	if next_definition == null:
		return {"ok": false, "reason": "Maximum career rank reached."}
	if career.current_experience() < next_definition.promotion_xp:
		return {"ok": false, "reason": "Need %d Career XP." % next_definition.promotion_xp}
	if _attribute_value(next_definition.promotion_attribute) < next_definition.promotion_attribute_min:
		return {"ok": false, "reason": "%s must be at least %d." % [
			next_definition.promotion_attribute.capitalize(), int(next_definition.promotion_attribute_min)]}
	return {"ok": true, "reason": ""}


func can_promote() -> bool:
	return evaluate_promotion()["ok"]


## Manual promotion: exactly one rank, XP untouched, job id unchanged, Work
## uninterrupted (later completed hours simply pay the new wage).
func promote() -> bool:
	if not evaluate_promotion()["ok"]:
		return false
	return career.promote_current()


## Lowest age at which Living with Parents can no longer be newly selected.
## Residents who are already home are never evicted by birthdays or loads.
const PARENTS_MOVE_OUT_AGE: int = 25


## Centralized move evaluation. UI reads the reason; move_to_housing enforces
## it. Never duplicate this logic in screens.
func evaluate_move_to(housing_id: String) -> Dictionary:
	if not HousingCatalog.is_known_housing(housing_id):
		return {"ok": false, "reason": "That housing does not exist."}
	if is_dead:
		return {"ok": false, "reason": "Life has ended."}
	if housing_id == housing.current_housing_id:
		return {"ok": false, "reason": "You already live here."}
	var definition: HousingDefinition = HousingCatalog.get_by_id(housing_id)
	if age < definition.minimum_age:
		return {"ok": false, "reason": "Requires age %d." % definition.minimum_age}
	if housing_id == HousingCatalog.PARENTS_ID and age >= PARENTS_MOVE_OUT_AGE:
		return {"ok": false, "reason": "You can no longer move back in with your parents."}
	return {"ok": true, "reason": ""}


func can_move_to(housing_id: String) -> bool:
	return evaluate_move_to(housing_id)["ok"]


## Manual instant move: zero game minutes, no activity interruption, no fee.
## History (including unpaid balances) is retained; only the current home and
## the move counter change.
func move_to_housing(housing_id: String) -> bool:
	if not evaluate_move_to(housing_id)["ok"]:
		return false
	housing.current_housing_id = housing_id
	housing.moves_completed = mini(HousingState.MAX_VALUE, housing.moves_completed + 1)
	return true


func enroll_secondary_school() -> bool:
	if is_dead:
		return false
	if age < SECONDARY_ENROLL_MIN_AGE:
		return false
	if education.status != EducationState.Status.COMPLETED_PRIMARY:
		return false
	var enrolled: bool = education.try_enroll_secondary(_clock.day)
	if enrolled:
		events.evaluate_triggers(_clock.day)
	return enrolled


func resolve_event_choice(choice_id: String) -> bool:
	if is_dead:
		return false
	return events.resolve_choice(choice_id, _clock.day)


# =====================================================================
# Needs
# =====================================================================

func update_energy(elapsed_minutes: int) -> void:
	if is_sleeping:
		_sleeping_minutes_accumulator += elapsed_minutes
		var hours_slept: int = _sleeping_minutes_accumulator / MINUTES_PER_HOUR
		if hours_slept > 0:
			energy = mini(NEEDS_MAX, energy + hours_slept * ENERGY_PER_SLEEP_HOUR)
			_sleeping_minutes_accumulator %= MINUTES_PER_HOUR
	else:
		_awake_minutes_accumulator += elapsed_minutes
		var hours_awake: int = _awake_minutes_accumulator / MINUTES_PER_HOUR
		if hours_awake > 0:
			energy = maxi(0, energy - hours_awake * ENERGY_PER_AWAKE_HOUR)
			_awake_minutes_accumulator %= MINUTES_PER_HOUR


func update_hunger(elapsed_minutes: int) -> void:
	_hunger_minutes_accumulator += elapsed_minutes
	var hours_passed: int = _hunger_minutes_accumulator / MINUTES_PER_HOUR
	if hours_passed > 0:
		hunger = maxi(0, hunger - hours_passed * HUNGER_PER_HOUR)
		_hunger_minutes_accumulator %= MINUTES_PER_HOUR


func update_thirst(elapsed_minutes: int) -> void:
	_thirst_minutes_accumulator += elapsed_minutes
	var hours_passed: int = _thirst_minutes_accumulator / MINUTES_PER_HOUR
	if hours_passed > 0:
		thirst = maxi(0, thirst - hours_passed * THIRST_PER_HOUR)
		_thirst_minutes_accumulator %= MINUTES_PER_HOUR


func eat(hunger_restored: int) -> void:
	if is_dead:
		return
	if hunger_restored <= 0:
		return
	hunger = mini(NEEDS_MAX, hunger + hunger_restored)
	# Eating ends the starvation streak: the next deprivation episode starts a
	# fresh completed-hour accumulator instead of inheriting stale minutes.
	_starving_minutes_accumulator = 0


func drink(thirst_restored: int) -> void:
	if is_dead:
		return
	if thirst_restored <= 0:
		return
	thirst = mini(NEEDS_MAX, thirst + thirst_restored)
	_dehydrated_minutes_accumulator = 0


## Authoritative food/drink purchase path: the ONLY way bought consumables
## enter the simulation. UI calls this and reports the returned message; it
## never mutates money or needs directly.
##
## Instant action: advances zero game minutes, changes no activity, and pays
## the full price even when restoration clamps at 100. All-or-nothing:
## shortfalls fail with money, needs and statistics untouched, and no living-
## expense debt is created. Outstanding living expenses never block a
## purchase the player can afford in cash.
## Returns {"ok": bool, "message": String}.
func purchase_consumable(consumable_id: String) -> Dictionary:
	if not ConsumableCatalog.is_known_consumable(consumable_id):
		return {"ok": false, "message": "That item does not exist."}
	if is_dead:
		return {"ok": false, "message": "Life has ended."}
	var definition: ConsumableDefinition = ConsumableCatalog.get_by_id(consumable_id)
	if money < definition.price:
		return {"ok": false, "message": "Not enough money."}
	money -= definition.price
	# Controlled restoration: eat()/drink() clamp to 100 and reset the
	# matching deprivation streak, so revived needs accrue no stale damage.
	if definition.hunger_restored > 0:
		eat(definition.hunger_restored)
	if definition.thirst_restored > 0:
		drink(definition.thirst_restored)
	economy.record_purchase(definition.price, definition.id)
	return {"ok": true, "message": "%s %s for $%d." % [
		definition.consumed_verb, definition.display_name, definition.price]}


# =====================================================================
# Activity rewards
# =====================================================================

func update_work(elapsed_minutes: int) -> void:
	if not is_working:
		return

	_work_minutes_accumulator += elapsed_minutes
	var hours_worked: int = _work_minutes_accumulator / MINUTES_PER_HOUR
	if hours_worked > 0:
		# One authoritative completed-hour count drives both wages (at the
		# CURRENT rank wage) and Career XP for the held track, so pay and
		# progression can never disagree. Partial hours carry, exactly as
		# before; XP stops at death with wages by construction.
		money += hours_worked * career.hourly_wage()
		career.award_experience(career.current_job_id, hours_worked * CAREER_XP_PER_WORK_HOUR)
		_work_minutes_accumulator %= MINUTES_PER_HOUR


func update_study(elapsed_minutes: int) -> void:
	if not is_studying:
		return

	_study_minutes_accumulator += elapsed_minutes
	var hours_studied: int = _study_minutes_accumulator / MINUTES_PER_HOUR
	if hours_studied > 0:
		study_xp += hours_studied * STUDY_XP_PER_HOUR
		attributes.add_intelligence(hours_studied * INTELLIGENCE_PER_STUDY_HOUR)
		skills.academics.add_experience(hours_studied * ACADEMICS_XP_PER_STUDY_HOUR)
		if education.status == EducationState.Status.PRIMARY_SCHOOL or education.status == EducationState.Status.SECONDARY_SCHOOL:
			education.add_progress(hours_studied)
		traits.add_curiosity(hours_studied * CURIOSITY_PER_STUDY_HOUR)
		traits.add_patience(hours_studied * PATIENCE_PER_STUDY_HOUR)
		traits.add_ambition(hours_studied * AMBITION_PER_STUDY_HOUR)
		_study_minutes_accumulator %= MINUTES_PER_HOUR


func update_play(elapsed_minutes: int) -> void:
	if not is_playing:
		return

	_play_minutes_accumulator += elapsed_minutes
	var hours_played: int = _play_minutes_accumulator / MINUTES_PER_HOUR
	if hours_played > 0:
		attributes.add_fitness(hours_played * FITNESS_PER_PLAY_HOUR)
		attributes.add_creativity(hours_played * CREATIVITY_PER_PLAY_HOUR)
		traits.add_confidence(hours_played * CONFIDENCE_PER_PLAY_HOUR)
		traits.add_curiosity(hours_played * CURIOSITY_PER_PLAY_HOUR)
		_play_minutes_accumulator %= MINUTES_PER_HOUR
		_add_total_play_hours_safely(hours_played)


func update_family_time(elapsed_minutes: int) -> void:
	if not is_spending_family_time:
		return

	_family_time_minutes_accumulator += elapsed_minutes
	var hours_spent: int = _family_time_minutes_accumulator / MINUTES_PER_HOUR
	if hours_spent > 0:
		relationships.mother_relationship.add_closeness(hours_spent * CLOSENESS_PER_FAMILY_HOUR)
		relationships.father_relationship.add_closeness(hours_spent * CLOSENESS_PER_FAMILY_HOUR)
		attributes.add_social(hours_spent * SOCIAL_PER_FAMILY_HOUR)
		traits.add_empathy(hours_spent * EMPATHY_PER_FAMILY_HOUR)
		traits.add_confidence(hours_spent * CONFIDENCE_PER_FAMILY_HOUR)
		_family_time_minutes_accumulator %= MINUTES_PER_HOUR


# =====================================================================
# Simulation engine
# =====================================================================

## Advances the simulation by `minutes` of game time, INCLUDING the clock.
## Time is processed in segments bounded by midnights, need-zero crossings and
## deprivation-hour boundaries, so:
##   - needs/rewards keep their exact accumulator semantics (splitting minutes
##     across segments is mathematically identical to one batch call),
##   - deprivation damage lands on exact deprivation-hour boundaries,
##   - old-age mortality is evaluated exactly when a new day is entered,
##   - death stops the clock at the exact death minute (later time discarded).
## Normal play, Wait 1 Hour, stall catch-up and offline bulk progression all
## run this one engine, so their results are equivalent by construction.
## Returns {"money_earned": int, "xp_earned": int} for the whole interval.
func advance_simulation(minutes: int) -> Dictionary:
	var result := {"money_earned": 0, "xp_earned": 0}
	if is_dead or minutes <= 0:
		return result

	var money_before: int = money
	var xp_before: int = study_xp
	var remaining: int = minutes

	# Days entered by non-simulating clock jumps (God Mode skips, test aging
	# helpers) are resolved without mortality evaluation: the pointer catches up
	# here, so only midnights crossed DURING engine time can roll mortality.
	if _clock.day > _mortality_evaluated_day:
		_mortality_evaluated_day = _clock.day
	# Same-day economy rule: jumps enter days without simulation, so no living
	# expense may be assessed for them either. The in-loop pointer below only
	# ever advances over midnights crossed DURING engine time.
	if _clock.day > _economy_assessed_day:
		_economy_assessed_day = _clock.day

	while remaining > 0 and not is_dead:
		var seg: int = _next_segment_minutes(remaining)
		if seg <= 0:
			break
		if not _clock.advance_game_minutes(seg):
			# Clock overflow guard. Unreachable in practice: alive players die
			# within ~70 offline hours, far below the day counter's range.
			break
		# Deprivation is decided by the need values at SEGMENT START: the segment
		# in which a need reaches zero is never a damage segment (damage begins
		# with the first completed hour after the need is already zero), and the
		# cause precedence reflects the deprivation that was actually active.
		var hunger_at_start: int = hunger
		var thirst_at_start: int = thirst
		_apply_needs_and_rewards(seg)
		_apply_deprivation(seg, hunger_at_start, thirst_at_start)
		if not is_dead and _clock.day > _mortality_evaluated_day:
			_evaluate_daily_mortality()
		# Living expenses resolve after mortality for each entered day, so a
		# death at (or before) the boundary incurs no further charges while a
		# charge assessed on entry survives a later same-day death.
		if not is_dead:
			_assess_entered_days()
		remaining -= seg

	sync_mortality_to_clock()
	# Education resolves pre-death study against the final (possibly death-day)
	# calendar; events must never trigger for a dead player.
	education.evaluate_progression(_clock.day)
	if not is_dead:
		events.evaluate_triggers(_clock.day)

	result["money_earned"] = money - money_before
	result["xp_earned"] = study_xp - xp_before
	return result


## O(1)-per-segment bulk/offline progression. Same engine, same semantics.
## Offline intervals always end in death within ~70 game hours (needs drain
## with no eat/drink), so the segment loop is bounded regardless of how much
## real time passed — never a per-minute or per-day replay.
func bulk_advance_simulation(elapsed_minutes: int) -> Dictionary:
	return advance_simulation(elapsed_minutes)


## Bounded segment size: never crosses midnight, a need's zero-crossing, or a
## deprivation-hour boundary, and never exceeds the remaining minutes.
func _next_segment_minutes(remaining: int) -> int:
	var seg: int = remaining

	var total_minutes: int = _clock.day * 1440 + _clock.hour * 60 + _clock.minute
	var to_midnight: int = 1440 - (total_minutes % 1440)
	seg = mini(seg, to_midnight)

	# A need that is still positive must not pass zero inside a segment: the
	# reaching segment is never a deprivation segment (damage starts with the
	# first completed hour AFTER the need is already zero).
	if hunger > 0:
		seg = mini(seg, hunger * HUNGER_PER_HOUR_MINUTES_SCALE - _hunger_minutes_accumulator)
	if thirst > 0:
		var thirst_hours_to_zero: int = int(ceil(float(thirst) / float(THIRST_PER_HOUR)))
		seg = mini(seg, thirst_hours_to_zero * MINUTES_PER_HOUR - _thirst_minutes_accumulator)

	# Active deprivation resolves damage on exact hour boundaries.
	if hunger <= 0:
		seg = mini(seg, MINUTES_PER_HOUR - _starving_minutes_accumulator)
	if thirst <= 0:
		seg = mini(seg, MINUTES_PER_HOUR - _dehydrated_minutes_accumulator)

	return seg


func _apply_needs_and_rewards(seg: int) -> void:
	update_energy(seg)
	update_hunger(seg)
	update_thirst(seg)
	update_work(seg)
	update_study(seg)
	update_play(seg)
	update_family_time(seg)


## Applies deprivation damage for one segment. Damage is -2 per completed
## deprivation hour while starving and -5 while dehydrated (both stream
## independently, so both-zero yields -7/hour). The AT-START need values
## decide: the reaching segment accrues nothing, and a fatal hour caused by
## starvation damage while thirst merely reached zero at its end is
## Starvation, not Dehydration. Dehydration keeps precedence whenever thirst
## deprivation was active during the segment.
func _apply_deprivation(seg: int, hunger_at_start: int, thirst_at_start: int) -> void:
	if hunger_at_start <= 0:
		_starving_minutes_accumulator += seg
		var starving_hours: int = _starving_minutes_accumulator / MINUTES_PER_HOUR
		if starving_hours > 0:
			_starving_minutes_accumulator %= MINUTES_PER_HOUR
			health = maxf(0.0, health - starving_hours * STARVATION_DAMAGE_PER_HOUR)
	if thirst_at_start <= 0:
		_dehydrated_minutes_accumulator += seg
		var dehydrated_hours: int = _dehydrated_minutes_accumulator / MINUTES_PER_HOUR
		if dehydrated_hours > 0:
			_dehydrated_minutes_accumulator %= MINUTES_PER_HOUR
			health = maxf(0.0, health - dehydrated_hours * DEHYDRATION_DAMAGE_PER_HOUR)
	if health <= 0.0 and not is_dead:
		if thirst_at_start <= 0:
			die(CAUSE_DEHYDRATION)
		else:
			# Unreachable without thirst deprivation: health only falls through
			# deprivation damage, so hunger_at_start must have been <= 0.
			die(CAUSE_STARVATION)


## Overflow gate for offline progression: a conservative upper bound that
## assumes the WHOLE interval is worked/studied. Rewards are applied inline by
## the simulation engine; this only decides whether the interval is safe.
func preflight_work_and_study(elapsed_minutes: int) -> Dictionary:
	var total_money: int = money
	var total_xp: int = study_xp

	if is_working:
		var total_work_minutes: int = _work_minutes_accumulator + elapsed_minutes
		total_money += (total_work_minutes / MINUTES_PER_HOUR) * career.hourly_wage()

	if is_studying:
		var total_study_minutes: int = _study_minutes_accumulator + elapsed_minutes
		total_xp += (total_study_minutes / MINUTES_PER_HOUR) * STUDY_XP_PER_HOUR

	return {
		"ok": total_money <= INT32_MAX and total_xp <= INT32_MAX,
		"total_money": total_money,
		"total_xp": total_xp,
	}


func apply_rewards(money_earned: int, xp_earned: int) -> void:
	money += money_earned
	study_xp += xp_earned


# =====================================================================
# Controlled mutations
# =====================================================================

## Saturates at int.MaxValue (never wraps) and never goes below zero.
func add_money_safely(amount: int) -> void:
	money = clampi(money + amount, 0, INT32_MAX)


## Lifetime completed Play hours with safe saturation at long.MaxValue.
func _add_total_play_hours_safely(hours: int) -> void:
	if hours <= 0:
		return
	if hours >= INT64_MAX - total_play_hours:
		total_play_hours = INT64_MAX
	else:
		total_play_hours += hours


func restore_total_play_hours(hours: int) -> void:
	if hours < 0:
		return
	total_play_hours = hours


func debug_add_money(amount: int) -> void:
	if is_dead:
		return
	if amount > 0:
		money += amount


func debug_restore_needs() -> void:
	if is_dead:
		return
	energy = NEEDS_MAX
	hunger = NEEDS_MAX
	thirst = NEEDS_MAX


## Developer-tool mutation helpers (God Mode only). Rejected while dead —
## God Mode can test deprivation but can never resurrect.
func debug_set_health(value: float) -> void:
	if is_dead:
		return
	health = clampf(value, 0.0, HEALTH_MAX)


func debug_set_hunger(value: int) -> void:
	if is_dead:
		return
	hunger = clampi(value, 0, NEEDS_MAX)
	if hunger > 0:
		_starving_minutes_accumulator = 0


func debug_set_thirst(value: int) -> void:
	if is_dead:
		return
	thirst = clampi(value, 0, NEEDS_MAX)
	if thirst > 0:
		_dehydrated_minutes_accumulator = 0


## Test-support setter so regression suites can pin Energy without long
## unattended drains (which are now lethal). Not exposed in the God Mode panel.
func debug_set_energy(value: int) -> void:
	if is_dead:
		return
	energy = clampi(value, 0, NEEDS_MAX)


## Deterministic LifeSeed injection for tests (production seeds are generated
## once in _init or derived on legacy migration).
func debug_set_life_seed(seed_value: int) -> void:
	life_seed = clampi(seed_value, 0, LIFE_SEED_MAX)


# =====================================================================
# Save/load support
# =====================================================================

## Complete mutable-state snapshot used by the transactional commit path.
func snapshot() -> Dictionary:
	return {
		"money": money,
		"energy": energy,
		"hunger": hunger,
		"thirst": thirst,
		"study_xp": study_xp,
		"is_sleeping": is_sleeping,
		"is_working": is_working,
		"is_studying": is_studying,
		"is_playing": is_playing,
		"is_spending_family_time": is_spending_family_time,
		"awake_minutes_accumulator": _awake_minutes_accumulator,
		"sleeping_minutes_accumulator": _sleeping_minutes_accumulator,
		"hunger_minutes_accumulator": _hunger_minutes_accumulator,
		"thirst_minutes_accumulator": _thirst_minutes_accumulator,
		"work_minutes_accumulator": _work_minutes_accumulator,
		"study_minutes_accumulator": _study_minutes_accumulator,
		"play_minutes_accumulator": _play_minutes_accumulator,
		"family_time_minutes_accumulator": _family_time_minutes_accumulator,
		"total_play_hours": total_play_hours,
		"health": health,
		"is_dead": is_dead,
		"death_day": death_day,
		"death_age": death_age,
		"cause_of_death": cause_of_death,
		"life_seed": life_seed,
		"starving_minutes_accumulator": _starving_minutes_accumulator,
		"dehydrated_minutes_accumulator": _dehydrated_minutes_accumulator,
		"mortality_evaluated_day": _mortality_evaluated_day,
		"economy_assessed_day": _economy_assessed_day,
		"economy": economy.to_dict(),
		"housing": housing.to_dict(),
		"career_progress": career.snapshot_progress(),
	}


func restore_snapshot(state: Dictionary) -> void:
	restore_values(
		state["money"], state["energy"], state["hunger"], state["thirst"], state["study_xp"],
		state["is_sleeping"], state["is_working"], state["is_studying"], state["is_playing"],
		state["is_spending_family_time"],
		state["awake_minutes_accumulator"], state["sleeping_minutes_accumulator"],
		state["hunger_minutes_accumulator"], state["thirst_minutes_accumulator"],
		state["work_minutes_accumulator"], state["study_minutes_accumulator"],
		state["play_minutes_accumulator"], state["family_time_minutes_accumulator"]
	)
	restore_total_play_hours(state["total_play_hours"])
	restore_life_state(
		state["health"], state["is_dead"], state["death_day"], state["death_age"],
		state["cause_of_death"], state["life_seed"],
		state["starving_minutes_accumulator"], state["dehydrated_minutes_accumulator"]
	)
	career.restore_progress(state["career_progress"])
	var economy_state: Dictionary = state["economy"]
	economy.restore(economy_state["paid"], economy_state["outstanding"], economy_state["missed"],
		economy_state["spent"], economy_state["meals"], economy_state["drinks"])
	var housing_state: Dictionary = state["housing"]
	housing.restore(housing_state["housing_id"], housing_state["paid"], housing_state["outstanding"],
		housing_state["missed"], housing_state["moves"])
	_mortality_evaluated_day = state["mortality_evaluated_day"]
	_economy_assessed_day = state["economy_assessed_day"]


## Controlled restore. Parameter order matches the C# reference exactly.
func restore_values(
	p_money: int, p_energy: int, p_hunger: int, p_thirst: int, p_study_xp: int,
	p_is_sleeping: bool, p_is_working: bool, p_is_studying: bool, p_is_playing: bool,
	p_is_spending_family_time: bool,
	p_awake_minutes_accumulator: int, p_sleeping_minutes_accumulator: int,
	p_hunger_minutes_accumulator: int, p_thirst_minutes_accumulator: int,
	p_work_minutes_accumulator: int, p_study_minutes_accumulator: int,
	p_play_minutes_accumulator: int, p_family_time_minutes_accumulator: int
) -> void:
	money = p_money
	energy = p_energy
	hunger = p_hunger
	thirst = p_thirst
	study_xp = p_study_xp
	is_sleeping = p_is_sleeping
	is_working = p_is_working
	is_studying = p_is_studying
	is_playing = p_is_playing
	is_spending_family_time = p_is_spending_family_time
	_awake_minutes_accumulator = p_awake_minutes_accumulator
	_sleeping_minutes_accumulator = p_sleeping_minutes_accumulator
	_hunger_minutes_accumulator = p_hunger_minutes_accumulator
	_thirst_minutes_accumulator = p_thirst_minutes_accumulator
	_work_minutes_accumulator = p_work_minutes_accumulator
	_study_minutes_accumulator = p_study_minutes_accumulator
	_play_minutes_accumulator = p_play_minutes_accumulator
	_family_time_minutes_accumulator = p_family_time_minutes_accumulator


## Controlled restore of the life/death block. Defense in depth: dead state
## always carries Health 0 and no active activity, and the mortality pointer
## is synced to the restored clock so already-lived days are never re-rolled.
func restore_life_state(
	p_health: float, p_is_dead: bool, p_death_day: int, p_death_age: int,
	p_cause_of_death: String, p_life_seed: int,
	p_starving_acc: int = 0, p_dehydrated_acc: int = 0
) -> void:
	health = clampf(p_health, 0.0, HEALTH_MAX)
	is_dead = p_is_dead
	death_day = p_death_day
	death_age = p_death_age
	cause_of_death = p_cause_of_death
	life_seed = clampi(p_life_seed, 0, LIFE_SEED_MAX)
	_starving_minutes_accumulator = clampi(p_starving_acc, 0, MINUTES_PER_HOUR - 1)
	_dehydrated_minutes_accumulator = clampi(p_dehydrated_acc, 0, MINUTES_PER_HOUR - 1)
	if is_dead:
		health = 0.0
		is_sleeping = false
		is_working = false
		is_studying = false
		is_playing = false
		is_spending_family_time = false
	sync_mortality_to_clock()


func get_awake_minutes_accumulator() -> int:
	return _awake_minutes_accumulator


func get_sleeping_minutes_accumulator() -> int:
	return _sleeping_minutes_accumulator


func get_hunger_minutes_accumulator() -> int:
	return _hunger_minutes_accumulator


func get_thirst_minutes_accumulator() -> int:
	return _thirst_minutes_accumulator


func get_work_minutes_accumulator() -> int:
	return _work_minutes_accumulator


func get_study_minutes_accumulator() -> int:
	return _study_minutes_accumulator


func get_play_minutes_accumulator() -> int:
	return _play_minutes_accumulator


func get_family_time_minutes_accumulator() -> int:
	return _family_time_minutes_accumulator


func get_starving_minutes_accumulator() -> int:
	return _starving_minutes_accumulator


func get_dehydrated_minutes_accumulator() -> int:
	return _dehydrated_minutes_accumulator
