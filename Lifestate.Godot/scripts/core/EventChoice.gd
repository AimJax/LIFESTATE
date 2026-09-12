class_name EventChoice
extends RefCounted

## Ported from EventChoice.cs.

var id: String = ""
var text: String = ""


func _init(p_id: String = "", p_text: String = "") -> void:
	id = p_id
	text = p_text
