extends RefCounted

## Economy screen — read-only foundation ledger: current money, the daily
## living-expense rate for the player's age bracket, and persistent totals.
## No repayment controls yet. Never mutates state; all numbers come from the
## authoritative EconomyState through PlayerState.

var _service
var _column: VBoxContainer
var _money_label: Label
var _daily_label: Label
var _bracket_label: Label
var _paid_label: Label
var _outstanding_label: Label
var _missed_label: Label
var _clear_state_label: Label
var _food_spent_label: Label
var _meals_label: Label
var _drinks_label: Label
var _home_label: Label
var _housing_cost_label: Label
var _housing_paid_label: Label
var _housing_outstanding_label: Label
var _housing_missed_label: Label
var _moves_label: Label
var _total_living_label: Label
var _total_housing_label: Label
var _total_combined_label: Label
var _back_button: Button


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	_column.add_child(UiTheme.label("ECONOMY", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	_column.add_child(UiTheme.label("Money and recurring living expenses.",
		UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	var money_card := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(money_card)
	var money_body := UiTheme.card_body(money_card, UiTheme.SPACE_XS)
	money_body.add_child(UiTheme.tag("CURRENT MONEY"))
	_money_label = UiTheme.label("$1,000", UiTheme.FONT_DISPLAY, UiTheme.POSITIVE)
	money_body.add_child(_money_label)

	var rate_card := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(rate_card)
	var rate_body := UiTheme.card_body(rate_card, UiTheme.SPACE_XS)
	rate_body.add_child(UiTheme.tag("LIVING EXPENSES"))
	_daily_label = UiTheme.label("", UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	_bracket_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	rate_body.add_child(_daily_label)
	rate_body.add_child(_bracket_label)
	_paid_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_outstanding_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_missed_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	rate_body.add_child(_paid_label)
	rate_body.add_child(_outstanding_label)
	rate_body.add_child(_missed_label)
	_clear_state_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.POSITIVE)
	rate_body.add_child(_clear_state_label)

	var food_card := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(food_card)
	var food_body := UiTheme.card_body(food_card, UiTheme.SPACE_XS)
	food_body.add_child(UiTheme.tag("FOOD & DRINK"))
	_food_spent_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_meals_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_drinks_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	food_body.add_child(_food_spent_label)
	food_body.add_child(_meals_label)
	food_body.add_child(_drinks_label)

	var housing_card := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(housing_card)
	var housing_body := UiTheme.card_body(housing_card, UiTheme.SPACE_XS)
	housing_body.add_child(UiTheme.tag("HOUSING"))
	_home_label = UiTheme.label("", UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	_housing_cost_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_housing_paid_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_housing_outstanding_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_housing_missed_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_moves_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	housing_body.add_child(_home_label)
	housing_body.add_child(_housing_cost_label)
	housing_body.add_child(_housing_paid_label)
	housing_body.add_child(_housing_outstanding_label)
	housing_body.add_child(_housing_missed_label)
	housing_body.add_child(_moves_label)

	var total_card := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(total_card)
	var total_body := UiTheme.card_body(total_card, UiTheme.SPACE_XS)
	total_body.add_child(UiTheme.tag("TOTAL DAILY COST"))
	_total_living_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_total_housing_label = UiTheme.label("", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	_total_combined_label = UiTheme.label("", UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	total_body.add_child(_total_living_label)
	total_body.add_child(_total_housing_label)
	total_body.add_child(_total_combined_label)

	_back_button = UiTheme.button("Back", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	_back_button.pressed.connect(func() -> void: _service_go_back())
	_column.add_child(_back_button)

	refresh()


func _service_go_back() -> void:
	var main: Node = _column.get_tree().current_scene
	if main != null and main.has_method("go_to"):
		main.go_to("more")


func refresh() -> void:
	var player: PlayerState = _service.player
	var economy: EconomyState = player.economy
	var rate: int = EconomyState.daily_rate_for_age(player.age)

	_money_label.text = UiTheme.format_money(player.money)
	_daily_label.text = "Current Daily Cost  $%d / day" % rate
	_bracket_label.text = "Current Rate  " + EconomyState.bracket_label(player.age)
	_paid_label.text = "Total Paid  %s" % UiTheme.format_money(economy.total_paid)
	_outstanding_label.text = "Outstanding  %s" % UiTheme.format_money(economy.outstanding)
	_missed_label.text = "Missed Payments  %d" % economy.missed_payments

	if economy.outstanding == 0:
		_clear_state_label.text = "No outstanding living expenses."
		_clear_state_label.add_theme_color_override("font_color", UiTheme.POSITIVE)
		_outstanding_label.add_theme_color_override("font_color", UiTheme.TEXT_SECONDARY)
	else:
		_clear_state_label.text = "$%s outstanding" % UiTheme.format_money(economy.outstanding).trim_prefix("$")
		_clear_state_label.add_theme_color_override("font_color", UiTheme.WARNING)
		_outstanding_label.add_theme_color_override("font_color", UiTheme.WARNING)

	_food_spent_label.text = "Food & Drink Spent  %s" % UiTheme.format_money(economy.food_drink_spent)
	_meals_label.text = "Meals Purchased  %d" % economy.meals_purchased
	_drinks_label.text = "Drinks Purchased  %d" % economy.drinks_purchased

	var housing: HousingState = player.housing
	var home: HousingDefinition = housing.current_definition()
	var home_name: String = home.display_name if home != null else "Unknown"
	var home_cost: int = home.daily_cost if home != null else 0
	_home_label.text = "Current Home  %s" % home_name
	_housing_cost_label.text = "Housing Cost  $%d / day" % home_cost
	_housing_paid_label.text = "Total Housing Paid  %s" % UiTheme.format_money(housing.total_paid)
	_housing_outstanding_label.text = "Outstanding Housing  %s" % UiTheme.format_money(housing.outstanding)
	_housing_missed_label.text = "Missed Payments  %d" % housing.missed_payments
	_moves_label.text = "Moves Completed  %d" % housing.moves_completed

	_total_living_label.text = "Living Expenses  $%d" % rate
	_total_housing_label.text = "Housing  $%d" % home_cost
	_total_combined_label.text = "Total  $%d / day" % (rate + home_cost)
