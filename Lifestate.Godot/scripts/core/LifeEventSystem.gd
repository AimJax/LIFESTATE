class_name LifeEventSystem
extends RefCounted

## Ported from LifeEventSystem.cs. Owns runtime event state (one pending event +
## append-only history) for one player. No randomness anywhere.
##
## The player reference is intentionally untyped to avoid a cyclic class
## reference with PlayerState.

var _player
var _history: Array[EventHistoryEntry] = []

var current_event: PendingLifeEvent = null

var history: Array[EventHistoryEntry]:
	get:
		return _history


func _init(player) -> void:
	_player = player


## Deterministic trigger evaluation. At most one pending event may exist; if
## several are eligible, the highest priority wins. TriggeredDay is the CURRENT
## day even if eligibility began earlier.
func evaluate_triggers(current_day: int) -> void:
	if current_event != null:
		return

	if is_eligible_first_day() and not is_blocked(LifeEventCatalog.FIRST_DAY_SCHOOL_ID):
		current_event = PendingLifeEvent.new(LifeEventCatalog.FIRST_DAY_SCHOOL_ID, current_day)
		return

	if is_eligible_broken_toy() and not is_blocked(LifeEventCatalog.BROKEN_TOY_ID):
		current_event = PendingLifeEvent.new(LifeEventCatalog.BROKEN_TOY_ID, current_day)
		return

	if is_eligible_found_money() and not is_blocked(LifeEventCatalog.FOUND_MONEY_ID):
		current_event = PendingLifeEvent.new(LifeEventCatalog.FOUND_MONEY_ID, current_day)


func is_eligible_first_day() -> bool:
	return _player.age >= 6 and _player.education.status == EducationState.Status.PRIMARY_SCHOOL


func is_eligible_broken_toy() -> bool:
	return _player.age >= 4 and _player.total_play_hours >= 10


func is_eligible_found_money() -> bool:
	return _player.age >= 8


## One-shot events never trigger again once pending or resolved.
func is_blocked(event_id: String) -> bool:
	if current_event != null and current_event.event_id == event_id:
		return true
	return has_resolved(event_id)


func has_resolved(event_id: String) -> bool:
	for entry in _history:
		if entry.event_id == event_id:
			return true
	return false


## Controlled resolution: validate event + choice FIRST, then apply the exact
## deterministic outcome, append one history entry, clear pending. Invalid input
## mutates nothing and returns false.
func resolve_choice(choice_id: String, current_day: int) -> bool:
	if current_event == null:
		return false

	var event_id: String = current_event.event_id
	var triggered_day: int = current_event.triggered_day

	var definition := LifeEventCatalog.get_by_id(event_id)
	if definition == null:
		return false
	if not LifeEventCatalog.is_known_choice(event_id, choice_id):
		return false

	# Validation complete — apply explicit deterministic outcome. Exhaustive over
	# the catalog, so the final branch is unreachable by validation.
	if event_id == LifeEventCatalog.FIRST_DAY_SCHOOL_ID and choice_id == LifeEventCatalog.STAY_QUIET:
		_player.traits.add_patience(1.0)
		_player.traits.add_confidence(-0.5)
	elif event_id == LifeEventCatalog.FIRST_DAY_SCHOOL_ID and choice_id == LifeEventCatalog.INTRODUCE_YOURSELF:
		_player.traits.add_confidence(1.0)
		_player.attributes.add_social(0.5)
	elif event_id == LifeEventCatalog.BROKEN_TOY_ID and choice_id == LifeEventCatalog.TRY_FIX:
		_player.attributes.add_creativity(1.0)
		_player.traits.add_patience(0.5)
	elif event_id == LifeEventCatalog.BROKEN_TOY_ID and choice_id == LifeEventCatalog.ASK_PARENT:
		_player.relationships.mother_relationship.add_closeness(0.5)
		_player.relationships.father_relationship.add_closeness(0.5)
		_player.traits.add_empathy(0.5)
	elif event_id == LifeEventCatalog.FOUND_MONEY_ID and choice_id == LifeEventCatalog.KEEP_MONEY:
		_player.add_money_safely(25)
		_player.traits.add_empathy(-0.5)
	elif event_id == LifeEventCatalog.FOUND_MONEY_ID and choice_id == LifeEventCatalog.GIVE_PARENT:
		_player.traits.add_empathy(1.0)
		_player.relationships.mother_relationship.add_closeness(0.5)
		_player.relationships.father_relationship.add_closeness(0.5)
	else:
		return false

	_history.append(EventHistoryEntry.new(event_id, choice_id, triggered_day, current_day))
	current_event = null
	return true


## Controlled internal clear of pending state (transactional commit path).
func clear_pending() -> void:
	current_event = null


## Controlled internal restore of pending state. Unknown event IDs no-op.
func restore_pending(event_id: String, triggered_day: int) -> bool:
	if current_event != null:
		return false
	if not LifeEventCatalog.is_known_event(event_id):
		return false
	if triggered_day < 0:
		return false
	# Defense in depth: never restore a pending event that is already resolved.
	if has_resolved(event_id):
		return false

	current_event = PendingLifeEvent.new(event_id, triggered_day)
	return true


## Controlled internal restore of history. All-or-nothing: if any entry is
## invalid the whole restore no-ops and state is unchanged. Order is preserved.
func restore_history(entries: Array[EventHistoryEntry]) -> bool:
	var seen: Dictionary = {}
	for entry in entries:
		if entry == null:
			return false
		if not LifeEventCatalog.is_known_event(entry.event_id):
			return false
		if not LifeEventCatalog.is_known_choice(entry.event_id, entry.choice_id):
			return false
		if entry.triggered_day < 0:
			return false
		if entry.resolved_day < entry.triggered_day:
			return false
		if seen.has(entry.event_id):
			return false
		seen[entry.event_id] = true

	_history = entries.duplicate()
	return true


func history_count() -> int:
	return _history.size()


func duplicate_history() -> Array[EventHistoryEntry]:
	return _history.duplicate()
