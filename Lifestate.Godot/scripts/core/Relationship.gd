class_name Relationship
extends RefCounted

## Ported from Relationship.cs. Closeness is 0..100 and NaN/Inf is rejected.

const DEFAULT_CLOSENESS: float = 50.0
const MIN_CLOSENESS: float = 0.0
const MAX_CLOSENESS: float = 100.0

var person_id: String = ""
var closeness: float = DEFAULT_CLOSENESS


func _init(p_person_id: String = "", p_closeness: float = DEFAULT_CLOSENESS) -> void:
	person_id = p_person_id
	closeness = clampf(p_closeness, MIN_CLOSENESS, MAX_CLOSENESS) if _is_valid_value(p_closeness) else DEFAULT_CLOSENESS


func add_closeness(amount: float) -> void:
	if _is_valid_value(amount):
		closeness = clampf(closeness + amount, MIN_CLOSENESS, MAX_CLOSENESS)


func restore_closeness(value: float) -> void:
	if _is_valid_value(value):
		closeness = clampf(value, MIN_CLOSENESS, MAX_CLOSENESS)


func duplicate_relationship() -> Relationship:
	return Relationship.new(person_id, closeness)


static func _is_valid_value(value: float) -> bool:
	return not (is_nan(value) or is_inf(value))
