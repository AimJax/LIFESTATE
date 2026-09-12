class_name PendingLifeEvent
extends RefCounted

## Ported from PendingLifeEvent.cs.

var event_id: String = ""
var triggered_day: int = 0


func _init(p_event_id: String = "", p_triggered_day: int = 0) -> void:
	event_id = p_event_id
	triggered_day = p_triggered_day
