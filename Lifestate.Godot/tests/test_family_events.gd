extends RefCounted

## Family / relationship / life-event coverage, ported from the C# family (F),
## relationship and event (EV) sections.


static func advance_days(clock: GameClock, days: int) -> void:
	clock.advance_seconds(days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND)


static func fresh() -> Array:
	var clock := GameClock.new()
	return [clock, PlayerState.new(clock)]


static func run(h: TestHarness) -> void:
	_family(h)
	_relationships(h)
	_event_triggers(h)
	_event_resolution(h)
	_event_history(h)


static func _family(h: TestHarness) -> void:
	h.section("Family-F")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	h.eq_string("Family-F1 mother name", player.family.mother.person_name, "Mother")
	h.eq_string("Family-F2 father name", player.family.father.person_name, "Father")
	h.eq_int("Family-F3 mother role", player.family.mother.role, Person.Role.MOTHER)
	h.eq_int("Family-F4 father role", player.family.father.role, Person.Role.FATHER)
	h.eq_int("Family-F5 mother birth day encodes age 28", player.family.mother.birth_day, -28 * 365)
	h.eq_int("Family-F6 father birth day encodes age 30", player.family.father.birth_day, -30 * 365)
	h.eq_int("Family-F7 mother age at day 0", player.family.mother.get_age_for_day(0), 28)
	h.eq_int("Family-F8 father age at day 0", player.family.father.get_age_for_day(0), 30)
	h.check("Family-F9 parent IDs are valid and distinct",
		Uuid.is_valid(player.family.mother.id) and Uuid.is_valid(player.family.father.id)
		and player.family.mother.id != player.family.father.id)

	advance_days(clock, 10 * 365)
	h.eq_int("Family-F10 mother age advances with the clock", player.family.mother.get_age(clock), 38)
	h.eq_int("Family-F11 father age advances with the clock", player.family.father.get_age(clock), 40)

	var restore_family := PlayerFamily.new()
	var mother := Person.new("11111111-1111-4111-8111-111111111111", "Mother", -9000, Person.Role.MOTHER)
	var father := Person.new("22222222-2222-4222-8222-222222222222", "Father", -9500, Person.Role.FATHER)
	h.eq_bool("Family-F12 valid restore succeeds", restore_family.restore(mother, father), true)
	h.eq_string("Family-F13 restore replaces identity", restore_family.mother.id, mother.id)
	h.eq_bool("Family-F14 duplicate parent identity rejected",
		restore_family.restore(mother, Person.new(mother.id, "Father", -9500, Person.Role.FATHER)), false)
	h.eq_bool("Family-F15 swapped roles rejected",
		restore_family.restore(father, mother), false)
	h.eq_string("Family-F16 failed restore leaves identity intact", restore_family.mother.id, mother.id)


static func _relationships(h: TestHarness) -> void:
	h.section("Relationship-R")

	var pair := fresh()
	var player: PlayerState = pair[1]

	h.near_float("Relationship-R1 mother closeness default",
		player.relationships.mother_relationship.closeness, 50.0)
	h.near_float("Relationship-R2 father closeness default",
		player.relationships.father_relationship.closeness, 50.0)
	h.eq_string("Relationship-R3 mother relationship references mother",
		player.relationships.mother_relationship.person_id, player.family.mother.id)
	h.eq_string("Relationship-R4 father relationship references father",
		player.relationships.father_relationship.person_id, player.family.father.id)

	var relationship := Relationship.new("33333333-3333-4333-8333-333333333333")
	relationship.add_closeness(10.0)
	h.near_float("Relationship-R5 closeness accumulates", relationship.closeness, 60.0)
	relationship.add_closeness(1000.0)
	h.near_float("Relationship-R6 closeness caps at 100", relationship.closeness, 100.0)
	relationship.add_closeness(-1000.0)
	h.near_float("Relationship-R7 closeness floors at 0", relationship.closeness, 0.0)
	relationship.add_closeness(NAN)
	h.near_float("Relationship-R8 NaN closeness is a no-op", relationship.closeness, 0.0)
	h.near_float("Relationship-R9 invalid initial closeness falls back to default",
		Relationship.new("33333333-3333-4333-8333-333333333333", NAN).closeness, 50.0)

	var restore_relationships := PlayerRelationships.new("a", "b")
	h.eq_bool("Relationship-R10 restore with empty identities rejected",
		restore_relationships.restore(
			Relationship.new("", 50.0), Relationship.new("b", 50.0)), false)


static func _event_triggers(h: TestHarness) -> void:
	h.section("Event-EV")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	h.check("Event-EV1 nothing pending for a newborn", player.events.current_event == null)

	advance_days(clock, 5 * 365)
	player.events.evaluate_triggers(clock.day)
	h.check("Event-EV2 no event while unenrolled at age 5", player.events.current_event == null)

	advance_days(clock, 365)
	h.check("Event-EV3 age 6 unenrolled still nothing", player.events.current_event == null)

	player.enroll_primary_school()
	h.check("Event-EV4 enrolment triggers First Day of School",
		player.events.current_event != null
		and player.events.current_event.event_id == LifeEventCatalog.FIRST_DAY_SCHOOL_ID)

	# One pending maximum.
	var pending_before: String = player.events.current_event.event_id
	player.events.evaluate_triggers(clock.day + 3650)
	h.eq_string("Event-EV5 only one pending event may exist", player.events.current_event.event_id, pending_before)

	# Broken Toy requires age 4 + 10 completed play hours.
	var toy := fresh()
	var toy_clock: GameClock = toy[0]
	var toy_player: PlayerState = toy[1]
	advance_days(toy_clock, 4 * 365)
	toy_player.start_playing()
	toy_player.advance_simulation(60 * 9)
	h.check("Event-EV6 nine play hours is not enough", toy_player.events.current_event == null)
	toy_player.advance_simulation(60)
	h.check("Event-EV7 tenth play hour triggers Broken Toy immediately",
		toy_player.events.current_event != null
		and toy_player.events.current_event.event_id == LifeEventCatalog.BROKEN_TOY_ID)

	# Found Money requires age 8.
	var money := fresh()
	var money_clock: GameClock = money[0]
	var money_player: PlayerState = money[1]
	advance_days(money_clock, 8 * 365)
	money_player.events.evaluate_triggers(money_clock.day)
	h.check("Event-EV8 age 8 triggers Found Money",
		money_player.events.current_event != null
		and money_player.events.current_event.event_id == LifeEventCatalog.FOUND_MONEY_ID)
	h.eq_int("Event-EV9 trigger day is the current day", money_player.events.current_event.triggered_day, money_clock.day)

	# Deterministic priority: when all three are eligible at once and nothing is
	# pending, First Day of School wins. (Play hours are granted up front because
	# accumulating them live would trigger Broken Toy at the tenth hour first.)
	var priority := fresh()
	var priority_clock: GameClock = priority[0]
	var priority_player: PlayerState = priority[1]
	advance_days(priority_clock, 8 * 365)
	priority_player.restore_total_play_hours(10)
	priority_player.enroll_primary_school()
	h.check("Event-EV10 all three events are eligible at once",
		priority_player.age >= 8
		and priority_player.education.status == EducationState.Status.PRIMARY_SCHOOL
		and priority_player.total_play_hours >= 10)
	h.eq_string("Event-EV11 First Day of School outranks Broken Toy and Found Money",
		priority_player.events.current_event.event_id, LifeEventCatalog.FIRST_DAY_SCHOOL_ID)

	# Time alone must not fabricate rewards, only eligibility.
	h.eq_int("Event-EV12 no rewards simulated for skipped time", priority_player.money, 1000)

	# Events do not pause time or block activities.
	var running := fresh()
	var running_clock: GameClock = running[0]
	var running_player: PlayerState = running[1]
	advance_days(running_clock, 8 * 365)
	running_player.events.evaluate_triggers(running_clock.day)
	var day_before: int = running_clock.day
	h.eq_bool("Event-EV13 activity may start while an event is pending",
		running_player.start_family_time(), true)
	running_player.advance_simulation(60)
	h.eq_bool("Event-EV14 simulation keeps running while pending", running_clock.day >= day_before, true)


static func _event_resolution(h: TestHarness) -> void:
	h.section("Event-R")

	# Invalid choice mutates nothing and keeps the event pending.
	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]
	advance_days(clock, 6 * 365)
	player.enroll_primary_school()
	var patience_before: float = player.traits.patience
	h.eq_bool("Event-R1 unknown choice is rejected", player.resolve_event_choice("not_a_choice"), false)
	h.near_float("Event-R2 rejected choice mutates no traits", player.traits.patience, patience_before)
	h.check("Event-R3 rejected choice keeps the event pending", player.events.current_event != null)
	h.eq_int("Event-R4 rejected choice adds no history", player.events.history_count(), 0)

	# First Day / stay_quiet
	h.eq_bool("Event-R5 valid choice resolves", player.resolve_event_choice(LifeEventCatalog.STAY_QUIET), true)
	h.near_float("Event-R6 stay_quiet raises patience by 1", player.traits.patience, patience_before + 1.0)
	h.near_float("Event-R7 stay_quiet lowers confidence by 0.5", player.traits.confidence, 49.5)
	h.check("Event-R8 pending cleared after resolution", player.events.current_event == null)
	h.eq_int("Event-R9 resolution recorded once", player.events.history_count(), 1)
	h.eq_bool("Event-R10 resolving again fails", player.resolve_event_choice(LifeEventCatalog.STAY_QUIET), false)
	h.eq_int("Event-R11 no duplicate history", player.events.history_count(), 1)

	# First Day / introduce_yourself
	var introduce := fresh()
	var introduce_clock: GameClock = introduce[0]
	var introduce_player: PlayerState = introduce[1]
	advance_days(introduce_clock, 6 * 365)
	introduce_player.enroll_primary_school()
	introduce_player.resolve_event_choice(LifeEventCatalog.INTRODUCE_YOURSELF)
	h.near_float("Event-R12 introduce_yourself raises confidence by 1", introduce_player.traits.confidence, 51.0)
	h.near_float("Event-R13 introduce_yourself raises social by 0.5", introduce_player.attributes.social, 10.5)

	# Broken Toy outcomes
	var fix := fresh()
	var fix_clock: GameClock = fix[0]
	var fix_player: PlayerState = fix[1]
	advance_days(fix_clock, 4 * 365)
	fix_player.start_playing()
	fix_player.advance_simulation(60 * 10)
	fix_player.resolve_event_choice(LifeEventCatalog.TRY_FIX)
	h.near_float("Event-R14 try_fix raises creativity by 1", fix_player.attributes.creativity, 11.3)
	h.near_float("Event-R15 try_fix raises patience by 0.5", fix_player.traits.patience, 50.5)

	var ask := fresh()
	var ask_clock: GameClock = ask[0]
	var ask_player: PlayerState = ask[1]
	advance_days(ask_clock, 4 * 365)
	ask_player.start_playing()
	ask_player.advance_simulation(60 * 10)
	ask_player.resolve_event_choice(LifeEventCatalog.ASK_PARENT)
	h.near_float("Event-R16 ask_parent raises mother closeness by 0.5",
		ask_player.relationships.mother_relationship.closeness, 50.5)
	h.near_float("Event-R17 ask_parent raises father closeness by 0.5",
		ask_player.relationships.father_relationship.closeness, 50.5)
	h.near_float("Event-R18 ask_parent raises empathy by 0.5", ask_player.traits.empathy, 50.5)

	# Found Money outcomes
	var keep := fresh()
	var keep_clock: GameClock = keep[0]
	var keep_player: PlayerState = keep[1]
	advance_days(keep_clock, 8 * 365)
	keep_player.events.evaluate_triggers(keep_clock.day)
	keep_player.resolve_event_choice(LifeEventCatalog.KEEP_MONEY)
	h.eq_int("Event-R19 keep_money adds 25 money", keep_player.money, 1025)
	h.near_float("Event-R20 keep_money lowers empathy by 0.5", keep_player.traits.empathy, 49.5)

	var give := fresh()
	var give_clock: GameClock = give[0]
	var give_player: PlayerState = give[1]
	advance_days(give_clock, 8 * 365)
	give_player.events.evaluate_triggers(give_clock.day)
	give_player.resolve_event_choice(LifeEventCatalog.GIVE_PARENT)
	h.eq_int("Event-R21 give_parent adds no money", give_player.money, 1000)
	h.near_float("Event-R22 give_parent raises empathy by 1", give_player.traits.empathy, 51.0)

	# Money saturation is preserved (found money on a saturated balance).
	var saturated := fresh()
	var saturated_clock: GameClock = saturated[0]
	var saturated_player: PlayerState = saturated[1]
	saturated_player.money = PlayerState.INT32_MAX
	saturated_player.add_money_safely(25)
	h.eq_int("Event-R23 safe money saturates instead of wrapping",
		saturated_player.money, PlayerState.INT32_MAX)
	saturated_player.add_money_safely(-PlayerState.INT32_MAX - 50)
	h.eq_int("Event-R24 safe money never goes negative", saturated_player.money, 0)

	# One-shot events never trigger again after resolution.
	var oneshot := fresh()
	var oneshot_clock: GameClock = oneshot[0]
	var oneshot_player: PlayerState = oneshot[1]
	advance_days(oneshot_clock, 6 * 365)
	oneshot_player.enroll_primary_school()
	oneshot_player.resolve_event_choice(LifeEventCatalog.STAY_QUIET)
	oneshot_player.events.evaluate_triggers(oneshot_clock.day + 3650)
	var retriggered: bool = oneshot_player.events.current_event != null \
		and oneshot_player.events.current_event.event_id == LifeEventCatalog.FIRST_DAY_SCHOOL_ID
	h.eq_bool("Event-R25 resolved one-shot events never retrigger", retriggered, false)

	# Catalog integrity.
	h.eq_int("Event-R26 catalog exposes exactly three events", LifeEventCatalog.definitions().size(), 3)
	h.eq_bool("Event-R27 catalog exposes the First Day of School first",
		LifeEventCatalog.definitions()[0].id == LifeEventCatalog.FIRST_DAY_SCHOOL_ID, true)
	h.eq_bool("Event-R28 priority order is deterministic",
		LifeEventCatalog.priority_order()[0] == LifeEventCatalog.FIRST_DAY_SCHOOL_ID, true)
	h.eq_bool("Event-R29 unknown event rejected by catalog", LifeEventCatalog.is_known_event("nope"), false)
	h.eq_bool("Event-R30 valid choice recognised by catalog",
		LifeEventCatalog.is_known_choice(LifeEventCatalog.FOUND_MONEY_ID, LifeEventCatalog.GIVE_PARENT), true)
	h.eq_bool("Event-R31 cross-event choice rejected",
		LifeEventCatalog.is_known_choice(LifeEventCatalog.FOUND_MONEY_ID, LifeEventCatalog.TRY_FIX), false)


static func _event_history(h: TestHarness) -> void:
	h.section("Event-H")

	var pair := fresh()
	var clock: GameClock = pair[0]
	var player: PlayerState = pair[1]

	# All-or-nothing restore.
	var entries: Array[EventHistoryEntry] = [
		EventHistoryEntry.new(LifeEventCatalog.BROKEN_TOY_ID, LifeEventCatalog.TRY_FIX, 1500, 1500),
	]
	h.eq_bool("Event-H1 valid history restore succeeds", player.events.restore_history(entries), true)
	h.eq_int("Event-H2 history restored", player.events.history_count(), 1)

	var invalid: Array[EventHistoryEntry] = [
		EventHistoryEntry.new(LifeEventCatalog.FOUND_MONEY_ID, LifeEventCatalog.KEEP_MONEY, 3000, 3000),
		EventHistoryEntry.new("childhood.unknown", "keep_money", 3000, 3000),
	]
	h.eq_bool("Event-H3 invalid batch rejected", player.events.restore_history(invalid), false)
	h.eq_int("Event-H4 rejected batch leaves history untouched", player.events.history_count(), 1)

	var bad_choice: Array[EventHistoryEntry] = [
		EventHistoryEntry.new(LifeEventCatalog.BROKEN_TOY_ID, "keep_money", 10, 10),
	]
	h.eq_bool("Event-H5 mismatched choice rejected", player.events.restore_history(bad_choice), false)

	var bad_days: Array[EventHistoryEntry] = [
		EventHistoryEntry.new(LifeEventCatalog.FOUND_MONEY_ID, LifeEventCatalog.KEEP_MONEY, 100, 50),
	]
	h.eq_bool("Event-H6 resolved-before-triggered rejected", player.events.restore_history(bad_days), false)

	var duplicates: Array[EventHistoryEntry] = [
		EventHistoryEntry.new(LifeEventCatalog.FOUND_MONEY_ID, LifeEventCatalog.KEEP_MONEY, 100, 100),
		EventHistoryEntry.new(LifeEventCatalog.FOUND_MONEY_ID, LifeEventCatalog.GIVE_PARENT, 200, 200),
	]
	h.eq_bool("Event-H7 duplicate one-shot entries rejected", player.events.restore_history(duplicates), false)

	# Pending restore guards.
	h.eq_bool("Event-H8 unknown pending event rejected",
		player.events.restore_pending("childhood.unknown", 100), false)
	h.eq_bool("Event-H9 already-resolved pending event rejected",
		player.events.restore_pending(LifeEventCatalog.BROKEN_TOY_ID, 100), false)
	h.eq_bool("Event-H10 valid pending restore accepted",
		player.events.restore_pending(LifeEventCatalog.FIRST_DAY_SCHOOL_ID, 100), true)
	h.eq_bool("Event-H11 second pending restore rejected",
		player.events.restore_pending(LifeEventCatalog.FOUND_MONEY_ID, 100), false)

	# Order is preserved exactly.
	var ordered := fresh()
	var ordered_player: PlayerState = ordered[1]
	var ordered_entries: Array[EventHistoryEntry] = [
		EventHistoryEntry.new(LifeEventCatalog.BROKEN_TOY_ID, LifeEventCatalog.TRY_FIX, 1500, 1500),
		EventHistoryEntry.new(LifeEventCatalog.FIRST_DAY_SCHOOL_ID, LifeEventCatalog.STAY_QUIET, 2200, 2200),
		EventHistoryEntry.new(LifeEventCatalog.FOUND_MONEY_ID, LifeEventCatalog.GIVE_PARENT, 3000, 3000),
	]
	ordered_player.events.restore_history(ordered_entries)
	h.eq_int("Event-H12 three entries restored", ordered_player.events.history_count(), 3)
	h.eq_string("Event-H13 order preserved (first)", ordered_player.events.history[0].event_id,
		LifeEventCatalog.BROKEN_TOY_ID)
	h.eq_string("Event-H14 order preserved (last)", ordered_player.events.history[2].event_id,
		LifeEventCatalog.FOUND_MONEY_ID)
	h.eq_int("Event-H15 triggered day preserved", ordered_player.events.history[1].triggered_day, 2200)
	h.eq_int("Event-H16 resolved day preserved", ordered_player.events.history[1].resolved_day, 2200)
