class_name HousingDefinition
extends RefCounted

## Immutable housing option: bought into by moving, never owned in this
## ticket. Definitions are never serialized; saves persist only the mutable
## HousingState (current id plus payment history).

var id: String
var display_name: String
var daily_cost: int
var minimum_age: int
var description: String


func _init(
	p_id: String, p_display_name: String, p_daily_cost: int,
	p_minimum_age: int, p_description: String
) -> void:
	id = p_id
	display_name = p_display_name
	daily_cost = p_daily_cost
	minimum_age = p_minimum_age
	description = p_description
