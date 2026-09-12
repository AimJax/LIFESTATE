extends RefCounted

## People screen — the player's social world. Mother and Father get large,
## individual cards with a placeholder portrait block; Friends is a static
## empty state only (the system does not exist yet).

var _service
var _column: VBoxContainer
var _mother_card: PanelContainer
var _father_card: PanelContainer
var _mother_values: Dictionary = {}
var _father_values: Dictionary = {}


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	_column.add_child(UiTheme.label("PEOPLE", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	_column.add_child(UiTheme.label("Your social world.", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	_column.add_child(UiTheme.tag("FAMILY"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_MD)
	_column.add_child(row)

	var pair := _build_person_card("M", "MOTHER")
	_mother_card = pair[0]
	_mother_values = pair[1]
	row.add_child(_mother_card)

	pair = _build_person_card("F", "FATHER")
	_father_card = pair[0]
	_father_values = pair[1]
	row.add_child(_father_card)

	_column.add_child(UiTheme.tag("FRIENDS"))
	var empty_card := UiTheme.card(UiTheme.SURFACE)
	_column.add_child(empty_card)
	var body := UiTheme.card_body(empty_card, UiTheme.SPACE_XS)
	body.add_child(UiTheme.label("You haven't made any friends yet.", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	refresh()


func _build_person_card(initial: String, role: String) -> Array:
	var card := UiTheme.card(UiTheme.SURFACE)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := UiTheme.hbox(UiTheme.SPACE_MD)
	card.add_child(row)

	# Placeholder portrait block: reserved space for art without needing any.
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(68, 68)
	portrait.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE_RAISED, UiTheme.BORDER, 1, 6))
	var letter := UiTheme.label(initial, UiTheme.FONT_DISPLAY, UiTheme.ACCENT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(letter)
	row.add_child(portrait)

	var content := UiTheme.vbox(0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(UiTheme.tag(role))

	var name_label := UiTheme.label("", UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	var age_label := UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY)
	content.add_child(name_label)
	content.add_child(age_label)
	content.add_child(UiTheme.spacer(UiTheme.SPACE_XS))

	var closeness_row := UiTheme.hbox(UiTheme.SPACE_SM)
	closeness_row.add_child(UiTheme.label("Closeness", UiTheme.FONT_TAG, UiTheme.TEXT_MUTED))
	var bar := UiTheme.progress_bar(50.0, UiTheme.ACCENT)
	closeness_row.add_child(bar)
	var value := UiTheme.label("50", UiTheme.FONT_SMALL, UiTheme.TEXT_PRIMARY)
	value.custom_minimum_size = Vector2(42, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	closeness_row.add_child(value)
	content.add_child(closeness_row)

	row.add_child(content)

	return [card, {"name": name_label, "age": age_label, "bar": bar, "value": value}]


func refresh() -> void:
	var player: PlayerState = _service.player
	var day: int = _service.clock.day

	_apply_person(_mother_values, player.family.mother.person_name,
		"Mother", player.family.mother.get_age_for_day(day),
		player.relationships.mother_relationship.closeness)
	_apply_person(_father_values, player.family.father.person_name,
		"Father", player.family.father.get_age_for_day(day),
		player.relationships.father_relationship.closeness)


func _apply_person(values: Dictionary, person_name: String, role: String, age: int, closeness: float) -> void:
	values["name"].text = person_name
	values["age"].text = "%s · Age %d" % [role, age]
	values["bar"].value = closeness
	values["value"].text = "%.0f" % closeness
