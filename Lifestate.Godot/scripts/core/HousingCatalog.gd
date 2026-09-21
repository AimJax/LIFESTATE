class_name HousingCatalog
extends RefCounted

## Immutable known housing. IDs are persistence-sensitive and must never be
## renamed, translated or reordered. Metadata is reconstructed from the id on
## load; saves never contain housing definitions.

const PARENTS_ID: String = "parents"
const CHEAP_ROOM_ID: String = "cheap_room"
const APARTMENT_ID: String = "apartment"
const NICE_APARTMENT_ID: String = "nice_apartment"

static var _definitions: Array[HousingDefinition] = []


static func definitions() -> Array[HousingDefinition]:
	_ensure_definitions()
	return _definitions


static func get_by_id(housing_id: String) -> HousingDefinition:
	_ensure_definitions()
	for definition in _definitions:
		if definition.id == housing_id:
			return definition
	return null


static func is_known_housing(housing_id: String) -> bool:
	return get_by_id(housing_id) != null


static func _ensure_definitions() -> void:
	if not _definitions.is_empty():
		return

	_definitions = [
		HousingDefinition.new(
			PARENTS_ID, "Living with Parents", 0, 0,
			"Stay at the family home with no housing cost."
		),
		HousingDefinition.new(
			CHEAP_ROOM_ID, "Cheap Room", 8, 18,
			"A basic rented room with minimal expenses."
		),
		HousingDefinition.new(
			APARTMENT_ID, "Apartment", 20, 21,
			"A private apartment with more comfort and independence."
		),
		HousingDefinition.new(
			NICE_APARTMENT_ID, "Nice Apartment", 40, 25,
			"A comfortable apartment for an established lifestyle."
		),
	]
