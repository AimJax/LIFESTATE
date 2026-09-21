class_name ConsumableCatalog
extends RefCounted

## Immutable known consumables. IDs are persistence-adjacent (EconomyState
## counts meals/drinks by kind) and must never be renamed or repurposed.
## New definitions can be appended here without touching PlayerState: the
## purchase path resolves price and restoration from the definition.

const BASIC_MEAL_ID: String = "basic_meal"
const BASIC_DRINK_ID: String = "basic_drink"

static var _definitions: Array[ConsumableDefinition] = []


static func definitions() -> Array[ConsumableDefinition]:
	_ensure_definitions()
	return _definitions


static func get_by_id(consumable_id: String) -> ConsumableDefinition:
	_ensure_definitions()
	for definition in _definitions:
		if definition.id == consumable_id:
			return definition
	return null


static func is_known_consumable(consumable_id: String) -> bool:
	return get_by_id(consumable_id) != null


static func _ensure_definitions() -> void:
	if not _definitions.is_empty():
		return

	_definitions = [
		ConsumableDefinition.new(
			BASIC_MEAL_ID, "Basic Meal", 8, 35, 0, "Eat", "Ate"
		),
		ConsumableDefinition.new(
			BASIC_DRINK_ID, "Basic Drink", 3, 0, 30, "Drink", "Drank"
		),
	]
