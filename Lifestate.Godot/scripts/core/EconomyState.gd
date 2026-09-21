class_name EconomyState
extends RefCounted

## Mutable economy foundation: recurring daily living expenses plus the
## persistent totals that later systems (repayment, housing, budgets) build on.
##
## Rate rules are intentionally simple placeholder brackets and are NEVER
## serialized — saves persist only the three totals below. There is exactly
## one combined "Living Expenses" assessment per entered game day, driven by
## the simulation engine (never UI, frames, or wall clock).

const MIN_VALUE: int = 0
const MAX_VALUE: int = 9223372036854775807

var total_paid: int = 0
var outstanding: int = 0
var missed_payments: int = 0
## Historical food/drink spending: lifetime money spent plus per-kind purchase
## counts. Recorded only by successful manual purchases; daily living-expense
## totals are never touched by purchases and vice versa.
var food_drink_spent: int = 0
var meals_purchased: int = 0
var drinks_purchased: int = 0


## Authoritative daily living expense for a whole-year age. Single source:
## no UI-side or test-side rate tables in production code.
static func daily_rate_for_age(age_years: int) -> int:
	if age_years < 18:
		return 0
	if age_years <= 24:
		return 5
	if age_years <= 39:
		return 10
	if age_years <= 59:
		return 15
	return 10


## Human-readable current bracket, e.g. "Age 25–39 · $10/day".
static func bracket_label(age_years: int) -> String:
	if age_years < 18:
		return "Age 0–17 · $0/day"
	if age_years <= 24:
		return "Age 18–24 · $5/day"
	if age_years <= 39:
		return "Age 25–39 · $10/day"
	if age_years <= 59:
		return "Age 40–59 · $15/day"
	return "Age 60+ · $10/day"


## Applies one daily charge against available money. Never mutates the passed
## money directly: returns {"new_money": int} and records totals internally.
## Zero charges are no-ops. Shortfalls never touch money and never partially
## pay: the full amount accrues to outstanding with one missed payment.
## New income never auto-repays outstanding (no repayment mechanic yet).
func apply_daily_charge(expense: int, available_money: int) -> Dictionary:
	if expense <= 0:
		return {"new_money": available_money}
	if available_money >= expense:
		total_paid = _saturating_add(total_paid, expense)
		return {"new_money": available_money - expense}
	outstanding = _saturating_add(outstanding, expense)
	missed_payments = _saturating_add(missed_payments, 1)
	return {"new_money": available_money}


## Records one successful purchase. Unknown consumable ids are rejected so
## statistics can never desynchronize from the catalog. Failed purchases must
## never call this (no statistics change on failure).
func record_purchase(price: int, consumable_id: String) -> bool:
	if price < MIN_VALUE:
		return false
	if consumable_id == ConsumableCatalog.BASIC_MEAL_ID:
		meals_purchased = _saturating_add(meals_purchased, 1)
	elif consumable_id == ConsumableCatalog.BASIC_DRINK_ID:
		drinks_purchased = _saturating_add(drinks_purchased, 1)
	else:
		return false
	food_drink_spent = _saturating_add(food_drink_spent, price)
	return true


## God Mode / future-systems helper: clears the informational balance only.
## Totals, money, career, attributes and clock are untouched.
func clear_outstanding() -> void:
	outstanding = 0


## Strict restore for the transactional save path. All totals must be
## non-negative integers; anything else rejects without mutating state.
## Food/drink statistics default to zero so pre-v13 callers keep working.
func restore(
	p_paid: int, p_outstanding: int, p_missed: int,
	p_spent: int = 0, p_meals: int = 0, p_drinks: int = 0
) -> bool:
	if p_paid < MIN_VALUE or p_outstanding < MIN_VALUE or p_missed < MIN_VALUE:
		return false
	if p_spent < MIN_VALUE or p_meals < MIN_VALUE or p_drinks < MIN_VALUE:
		return false
	total_paid = p_paid
	outstanding = p_outstanding
	missed_payments = p_missed
	food_drink_spent = p_spent
	meals_purchased = p_meals
	drinks_purchased = p_drinks
	return true


func to_dict() -> Dictionary:
	return {
		"paid": total_paid,
		"outstanding": outstanding,
		"missed": missed_payments,
		"spent": food_drink_spent,
		"meals": meals_purchased,
		"drinks": drinks_purchased,
	}


static func _saturating_add(current: int, amount: int) -> int:
	if amount <= 0:
		return current
	if current >= MAX_VALUE - amount:
		return MAX_VALUE
	return current + amount
