extends RefCounted

## More screen — secondary navigation as a 2x2 card grid instead of thin bars.

const ENTRIES: Array = [
	["CHARACTER", "Attributes, traits, and skills", "character"],
	["EDUCATION", "School and academic progress", "education"],
	["CAREER", "Jobs, wages and applications", "career"],
	["SAVE / LOAD", "Manage game data", "save_load"],
	["SETTINGS", "Interface and game preferences", "settings"],
]

var _service
var _main_screen
var _column: VBoxContainer
var _grid: GridContainer


func _init(service, main_screen) -> void:
	_service = service
	_main_screen = main_screen


func build(parent: Control) -> void:
	_column = UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	_column.add_child(UiTheme.label("MORE", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	_column.add_child(UiTheme.label("Character, education and game data.",
		UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", UiTheme.SPACE_MD)
	_grid.add_theme_constant_override("v_separation", UiTheme.SPACE_MD)
	_column.add_child(_grid)
	_column.resized.connect(func() -> void:
		_grid.columns = 2 if _column.size.x >= 760.0 else 1
	)

	for entry in ENTRIES:
		_grid.add_child(_build_menu_card(entry[0], entry[1], entry[2]))


func _build_menu_card(title: String, description: String, target: String) -> Control:
	var card := UiTheme.card(UiTheme.SURFACE)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = description
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_main_screen.go_to(target)
	)

	var body := UiTheme.card_body(card, UiTheme.SPACE_XS)
	var header := UiTheme.hbox(UiTheme.SPACE_SM)
	var title_label := UiTheme.label(title, UiTheme.FONT_HEADING, UiTheme.TEXT_PRIMARY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(UiTheme.label("›", UiTheme.FONT_HEADING, UiTheme.ACCENT))
	body.add_child(header)
	body.add_child(UiTheme.label(description, UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY))

	return card


func refresh() -> void:
	pass
