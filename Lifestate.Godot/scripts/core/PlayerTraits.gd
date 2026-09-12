class_name PlayerTraits
extends RefCounted

## Ported from PlayerTraits.cs. Defaults 50.0, clamped 0..100, NaN/Inf no-ops.

const DEFAULT_VALUE: float = 50.0
const MIN_VALUE: float = 0.0
const MAX_VALUE: float = 100.0

var confidence: float = DEFAULT_VALUE
var curiosity: float = DEFAULT_VALUE
var patience: float = DEFAULT_VALUE
var ambition: float = DEFAULT_VALUE
var empathy: float = DEFAULT_VALUE


func add_confidence(amount: float) -> void:
	if _is_valid_input(amount):
		confidence = clampf(confidence + amount, MIN_VALUE, MAX_VALUE)


func add_curiosity(amount: float) -> void:
	if _is_valid_input(amount):
		curiosity = clampf(curiosity + amount, MIN_VALUE, MAX_VALUE)


func add_patience(amount: float) -> void:
	if _is_valid_input(amount):
		patience = clampf(patience + amount, MIN_VALUE, MAX_VALUE)


func add_ambition(amount: float) -> void:
	if _is_valid_input(amount):
		ambition = clampf(ambition + amount, MIN_VALUE, MAX_VALUE)


func add_empathy(amount: float) -> void:
	if _is_valid_input(amount):
		empathy = clampf(empathy + amount, MIN_VALUE, MAX_VALUE)


func set_all_max() -> void:
	confidence = MAX_VALUE
	curiosity = MAX_VALUE
	patience = MAX_VALUE
	ambition = MAX_VALUE
	empathy = MAX_VALUE


func restore(c: float, cu: float, p: float, a: float, e: float) -> void:
	if _is_valid_input(c):
		confidence = clampf(c, MIN_VALUE, MAX_VALUE)
	if _is_valid_input(cu):
		curiosity = clampf(cu, MIN_VALUE, MAX_VALUE)
	if _is_valid_input(p):
		patience = clampf(p, MIN_VALUE, MAX_VALUE)
	if _is_valid_input(a):
		ambition = clampf(a, MIN_VALUE, MAX_VALUE)
	if _is_valid_input(e):
		empathy = clampf(e, MIN_VALUE, MAX_VALUE)


static func _is_valid_input(value: float) -> bool:
	return not (is_nan(value) or is_inf(value))
