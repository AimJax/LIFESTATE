class_name GodMode
extends RefCounted

## Ported from GodMode.cs. Developer-only helpers, gated behind is_enabled.
##
## Invariant preserved from the reference: time skips advance the clock and
## reevaluate event eligibility, but they do NOT simulate skipped needs or
## activity rewards.

var _clock: GameClock
var _player: PlayerState

var is_enabled: bool = false


func _init(clock: GameClock, player: PlayerState) -> void:
	_clock = clock
	_player = player


func set_enabled(enabled: bool) -> void:
	is_enabled = enabled


func advance_days(days: int) -> void:
	if not is_enabled:
		return
	var real_seconds: int = days * 24 * 60 / GameClock.MINUTES_PER_REAL_SECOND
	_clock.advance_seconds(real_seconds)
	# Time skips can make age-based events eligible (e.g. Found Money at age 8).
	_player.events.evaluate_triggers(_clock.day)


func add_money(amount: int) -> void:
	if not is_enabled:
		return
	_player.debug_add_money(amount)


func restore_needs() -> void:
	if not is_enabled:
		return
	_player.debug_restore_needs()


func max_attributes() -> void:
	if not is_enabled:
		return
	_player.attributes.set_all_max()


func max_skills() -> void:
	if not is_enabled:
		return
	_player.skills.academics.set_max()


func max_traits() -> void:
	if not is_enabled:
		return
	_player.traits.set_all_max()
