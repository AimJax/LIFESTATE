extends RefCounted

## Save / Load screen. Uses the same save schema as the C# build, written to
## user:// so the location resolves correctly on Windows, Linux and Android.

var _service
var _status_label: Label
var _path_label: Label


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	var column := UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	column.add_child(UiTheme.label("SAVE / LOAD", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	column.add_child(UiTheme.label("Manage game data.", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	var card := UiTheme.card(UiTheme.SURFACE)
	column.add_child(card)
	var body := UiTheme.card_body(card, UiTheme.SPACE_SM)

	var title := UiTheme.label("Your progress is stored locally on this computer.",
		UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)

	var buttons := UiTheme.hbox(UiTheme.SPACE_SM)
	var save_button := UiTheme.button("SAVE GAME", UiTheme.ACCENT)
	save_button.pressed.connect(_save)
	buttons.add_child(save_button)

	var load_button := UiTheme.button("LOAD GAME", UiTheme.TEXT_PRIMARY)
	load_button.pressed.connect(_load)
	buttons.add_child(load_button)

	var import_button := UiTheme.button("IMPORT WINFORMS SAVE", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	import_button.pressed.connect(_import_windows_save)
	buttons.add_child(import_button)

	body.add_child(buttons)

	_status_label = UiTheme.label(" ", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY)
	body.add_child(_status_label)
	_path_label = UiTheme.label("Save location: %s" % SaveManager.default_save_path(),
		UiTheme.FONT_TAG, UiTheme.TEXT_MUTED)
	body.add_child(_path_label)

	var back_button := UiTheme.button("Back", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	back_button.pressed.connect(func() -> void:
		var main: Node = column.get_tree().current_scene
		if main != null and main.has_method("go_to"):
			main.go_to("more")
	)
	column.add_child(back_button)

	refresh()


func _save() -> void:
	var result: Dictionary = _service.save_game()
	if result["ok"]:
		_set_status("Game saved.", UiTheme.POSITIVE)
	else:
		_set_status("Save failed: %s" % result["error"], UiTheme.NEGATIVE)


func _load() -> void:
	if not SaveManager.save_exists():
		_set_status("No saved game was found.", UiTheme.WARNING)
		return

	var result: Dictionary = _service.load_game()
	if result["ok"]:
		if result["offline_seconds"] > 0:
			_set_status("Game loaded. %d seconds of offline time simulated." % result["offline_seconds"],
				UiTheme.POSITIVE)
		else:
			_set_status("Game loaded.", UiTheme.POSITIVE)
	else:
		_set_status("Save could not be loaded: %s" % result["error"], UiTheme.NEGATIVE)


func _import_windows_save() -> void:
	var result: Dictionary = SaveManager.import_windows_save()
	if result["ok"]:
		_set_status("Imported save from %s" % result["source"], UiTheme.POSITIVE)
	else:
		_set_status(result["error"], UiTheme.WARNING)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	_service.request_feedback(text, color)


func refresh() -> void:
	pass
