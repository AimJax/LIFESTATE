class_name LifeEventDefinition
extends RefCounted

## Ported from LifeEventDefinition.cs. Immutable catalog content.

var id: String = ""
var title: String = ""
var description: String = ""
var choices: Array[EventChoice] = []


func _init(p_id: String = "", p_title: String = "", p_description: String = "", p_choices: Array[EventChoice] = []) -> void:
	id = p_id
	title = p_title
	description = p_description
	choices = p_choices


func get_choice(choice_id: String) -> EventChoice:
	for choice in choices:
		if choice.id == choice_id:
			return choice
	return null
