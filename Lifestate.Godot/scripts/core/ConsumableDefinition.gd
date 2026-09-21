class_name ConsumableDefinition
extends RefCounted

## Immutable purchasable consumable: bought and immediately consumed, never
## inventoried. Definitions are never serialized; saves persist only the
## historical spending statistics in EconomyState.

var id: String
var display_name: String
var price: int
var hunger_restored: int
var thirst_restored: int
## Button verb ("Eat"/"Drink") and feedback verb ("Ate"/"Drank").
var action_verb: String
var consumed_verb: String


func _init(
	p_id: String, p_display_name: String, p_price: int,
	p_hunger_restored: int, p_thirst_restored: int,
	p_action_verb: String, p_consumed_verb: String
) -> void:
	id = p_id
	display_name = p_display_name
	price = p_price
	hunger_restored = p_hunger_restored
	thirst_restored = p_thirst_restored
	action_verb = p_action_verb
	consumed_verb = p_consumed_verb
