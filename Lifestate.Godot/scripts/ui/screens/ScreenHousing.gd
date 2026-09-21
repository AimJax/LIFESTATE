extends RefCounted

## Housing screen — current home plus the four housing options with
## availability. All mutations go through PlayerState.move_to_housing; this
## screen never edits state directly. Locked options stay visible so future
## progression is always previewable.

var _service
var _column: VBoxContainer
var _status_card: PanelContainer
var _status_title: Label
var _status_detail: Label
var _housing_cards: Dictionary = {}


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	_column.add_child(UiTheme.label("HOUSING", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	_column.add_child(UiTheme.label("Choose where to live. Moving is instant and free.",
		UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	_build_status_card()

	for definition in HousingCatalog.definitions():
		_column.add_child(_build_housing_card(definition))

	var back_button := UiTheme.button("Back", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	back_button.pressed.connect(func() -> void: _service_go_back())
	_column.add_child(back_button)

	refresh()


func _service_go_back() -> void:
	var main: Node = _column.get_tree().current_scene
	if main != null and main.has_method("go_to"):
		main.go_to("more")


func _build_status_card() -> void:
	_status_card = UiTheme.card(UiTheme.SURFACE)
	_column.add_child(_status_card)
	var body := UiTheme.card_body(_status_card, UiTheme.SPACE_XS)
	body.add_child(UiTheme.tag("CURRENT HOME"))
	_status_title = UiTheme.label("Living with Parents", UiTheme.FONT_DISPLAY, UiTheme.TEXT_PRIMARY)
	_status_detail = UiTheme.label("$0 / day", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	body.add_child(_status_title)
	body.add_child(_status_detail)


func _build_housing_card(definition: HousingDefinition) -> Control:
	var card := UiTheme.card(UiTheme.SURFACE)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := UiTheme.card_body(card, UiTheme.SPACE_XS)

	var header := UiTheme.hbox(UiTheme.SPACE_SM)
	var title := UiTheme.label(definition.display_name.to_upper(), UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiTheme.label("$%d / day" % definition.daily_cost, UiTheme.FONT_VALUE, UiTheme.POSITIVE))
	body.add_child(header)

	body.add_child(UiTheme.label(definition.description, UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY))

	var requirement := UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED)
	if definition.minimum_age > 0:
		requirement.text = "Requires Age %d" % definition.minimum_age
	elif definition.id == HousingCatalog.PARENTS_ID:
		requirement.text = "Available while under 25"
	body.add_child(requirement)

	var action := UiTheme.button("MOVE IN", UiTheme.ACCENT, UiTheme.BUTTON_HEIGHT_SMALL)
	action.pressed.connect(func() -> void: _on_move_in(definition.id))
	body.add_child(action)

	_housing_cards[definition.id] = {
		"card": card,
		"title": title,
		"requirement": requirement,
		"action": action,
	}
	return card


func _on_move_in(housing_id: String) -> void:
	var player: PlayerState = _service.player
	var evaluation: Dictionary = player.evaluate_move_to(housing_id)
	if not evaluation["ok"]:
		_service.request_feedback(evaluation["reason"], UiTheme.WARNING)
		refresh()
		return
	if player.move_to_housing(housing_id):
		_service.request_feedback("Moved to %s." % HousingCatalog.get_by_id(housing_id).display_name,
			UiTheme.POSITIVE)
	else:
		_service.request_feedback("Move failed.", UiTheme.WARNING)
	refresh()


func refresh() -> void:
	var player: PlayerState = _service.player
	var housing: HousingState = player.housing
	var current: HousingDefinition = housing.current_definition()

	if player.is_dead:
		_status_title.text = "FINAL HOME"
		_status_detail.text = current.display_name if current != null else "Unknown"
	else:
		_status_title.text = "CURRENT HOME"
		var home_name: String = current.display_name if current != null else "Unknown"
		var home_cost: int = current.daily_cost if current != null else 0
		_status_detail.text = "%s · $%d / day" % [home_name, home_cost]

	for definition in HousingCatalog.definitions():
		_refresh_card(player, definition)


func _refresh_card(player: PlayerState, definition: HousingDefinition) -> void:
	var entry: Dictionary = _housing_cards[definition.id]
	var action: Button = entry["action"]
	var requirement: Label = entry["requirement"]
	var is_current: bool = definition.id == player.housing.current_housing_id
	var evaluation: Dictionary = player.evaluate_move_to(definition.id)

	if player.is_dead:
		action.text = "MOVE IN"
		action.disabled = true
		requirement.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
		return

	if is_current:
		action.text = "CURRENT"
		action.disabled = true
		requirement.text = "Your current home"
		requirement.add_theme_color_override("font_color", UiTheme.POSITIVE)
	elif not evaluation["ok"]:
		action.text = "LOCKED"
		action.disabled = true
		requirement.text = evaluation["reason"]
		requirement.add_theme_color_override("font_color", UiTheme.NEGATIVE)
	else:
		action.text = "MOVE IN"
		action.disabled = false
		if definition.minimum_age > 0:
			requirement.text = "Requires Age %d" % definition.minimum_age
			requirement.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
		else:
			requirement.text = "Available while under 25"
			requirement.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
