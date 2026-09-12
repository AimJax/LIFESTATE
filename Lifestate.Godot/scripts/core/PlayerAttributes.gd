class_name PlayerAttributes
extends RefCounted

## Ported from PlayerAttributes.cs. Defaults 10.0, clamped 0..100, and any
## NaN/Inf input is silently ignored (a no-op), exactly like the reference.

const DEFAULT_VALUE: float = 10.0
const MIN_VALUE: float = 0.0
const MAX_VALUE: float = 100.0

var intelligence: float = DEFAULT_VALUE
var fitness: float = DEFAULT_VALUE
var social: float = DEFAULT_VALUE
var discipline: float = DEFAULT_VALUE
var creativity: float = DEFAULT_VALUE


func add_intelligence(amount: float) -> void:
	if _is_valid_input(amount):
		intelligence = clampf(intelligence + amount, MIN_VALUE, MAX_VALUE)


func add_fitness(amount: float) -> void:
	if _is_valid_input(amount):
		fitness = clampf(fitness + amount, MIN_VALUE, MAX_VALUE)


func add_social(amount: float) -> void:
	if _is_valid_input(amount):
		social = clampf(social + amount, MIN_VALUE, MAX_VALUE)


func add_discipline(amount: float) -> void:
	if _is_valid_input(amount):
		discipline = clampf(discipline + amount, MIN_VALUE, MAX_VALUE)


func add_creativity(amount: float) -> void:
	if _is_valid_input(amount):
		creativity = clampf(creativity + amount, MIN_VALUE, MAX_VALUE)


func set_all_max() -> void:
	intelligence = MAX_VALUE
	fitness = MAX_VALUE
	social = MAX_VALUE
	discipline = MAX_VALUE
	creativity = MAX_VALUE


func restore(i: float, f: float, s: float, d: float, c: float) -> void:
	if _is_valid_input(i):
		intelligence = clampf(i, MIN_VALUE, MAX_VALUE)
	if _is_valid_input(f):
		fitness = clampf(f, MIN_VALUE, MAX_VALUE)
	if _is_valid_input(s):
		social = clampf(s, MIN_VALUE, MAX_VALUE)
	if _is_valid_input(d):
		discipline = clampf(d, MIN_VALUE, MAX_VALUE)
	if _is_valid_input(c):
		creativity = clampf(c, MIN_VALUE, MAX_VALUE)


static func _is_valid_input(value: float) -> bool:
	return not (is_nan(value) or is_inf(value))
