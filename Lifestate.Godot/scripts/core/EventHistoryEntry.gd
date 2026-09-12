class_name EventHistoryEntry
extends RefCounted

## Ported from EventHistoryEntry.cs. Append-only life history record.

var event_id: String = ""
var choice_id: String = ""
var triggered_day: int = 0
var resolved_day: int = 0


func _init(p_event_id: String = "", p_choice_id: String = "", p_triggered_day: int = 0, p_resolved_day: int = 0) -> void:
	event_id = p_event_id
	choice_id = p_choice_id
	triggered_day = p_triggered_day
	resolved_day = p_resolved_day
