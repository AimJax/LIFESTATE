class_name LifeEventCatalog
extends RefCounted

## Ported from LifeEventCatalog.cs. Definitions are immutable catalog content;
## only runtime state lives in LifeEventSystem. IDs are persistence-sensitive
## and must never be translated or reordered.

const FIRST_DAY_SCHOOL_ID: String = "childhood.first_day_school"
const BROKEN_TOY_ID: String = "childhood.broken_toy"
const FOUND_MONEY_ID: String = "childhood.found_money"

const STAY_QUIET: String = "stay_quiet"
const INTRODUCE_YOURSELF: String = "introduce_yourself"
const TRY_FIX: String = "try_fix"
const ASK_PARENT: String = "ask_parent"
const KEEP_MONEY: String = "keep_money"
const GIVE_PARENT: String = "give_parent"

static var _definitions: Array[LifeEventDefinition] = []

## Deterministic priority order: First Day of School, Broken Toy, Found Money.
static var _priority_order: PackedStringArray = PackedStringArray([
	FIRST_DAY_SCHOOL_ID,
	BROKEN_TOY_ID,
	FOUND_MONEY_ID,
])


static func definitions() -> Array[LifeEventDefinition]:
	_ensure_definitions()
	return _definitions


static func priority_order() -> PackedStringArray:
	return _priority_order


static func get_by_id(event_id: String) -> LifeEventDefinition:
	_ensure_definitions()
	for definition in _definitions:
		if definition.id == event_id:
			return definition
	return null


static func is_known_event(event_id: String) -> bool:
	return get_by_id(event_id) != null


static func is_known_choice(event_id: String, choice_id: String) -> bool:
	var definition := get_by_id(event_id)
	if definition == null:
		return false
	return definition.get_choice(choice_id) != null


static func _ensure_definitions() -> void:
	if not _definitions.is_empty():
		return

	_definitions = [
		LifeEventDefinition.new(
			FIRST_DAY_SCHOOL_ID,
			"First Day of School",
			"It's your first day of school. The classroom is full of unfamiliar faces.",
			[
				EventChoice.new(STAY_QUIET, "Stay quiet and observe."),
				EventChoice.new(INTRODUCE_YOURSELF, "Introduce yourself to the other children."),
			] as Array[EventChoice]
		),
		LifeEventDefinition.new(
			BROKEN_TOY_ID,
			"Broken Toy",
			"One of your favorite toys breaks while you're playing.",
			[
				EventChoice.new(TRY_FIX, "Try to fix it yourself."),
				EventChoice.new(ASK_PARENT, "Ask your parents for help."),
			] as Array[EventChoice]
		),
		LifeEventDefinition.new(
			FOUND_MONEY_ID,
			"Found Money",
			"You find some money on the ground with nobody around.",
			[
				EventChoice.new(KEEP_MONEY, "Keep the money."),
				EventChoice.new(GIVE_PARENT, "Give it to your parents."),
			] as Array[EventChoice]
		),
	]
