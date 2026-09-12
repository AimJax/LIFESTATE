extends RefCounted

## Settings screen — intentionally minimal. No audio, resolution or language
## systems exist, so nothing here pretends to configure them.

var _service


func _init(service) -> void:
	_service = service


func build(parent: Control) -> void:
	var column := UiTheme.centered_column(parent, UiTheme.CONTENT_MAX_WIDTH, UiTheme.SPACE_LG)
	column.add_child(UiTheme.label("SETTINGS", UiTheme.FONT_SCREEN_TITLE, UiTheme.TEXT_PRIMARY))
	column.add_child(UiTheme.label("Interface and game preferences.", UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))

	var card := UiTheme.card(UiTheme.SURFACE)
	column.add_child(card)
	var body := UiTheme.card_body(card, UiTheme.SPACE_XS)
	body.add_child(UiTheme.tag("INTERFACE"))
	body.add_child(UiTheme.label("More settings will be available later.",
		UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY))
	body.add_child(UiTheme.spacer(UiTheme.SPACE_XS))
	body.add_child(UiTheme.label("F2 opens the developer God Mode overlay.",
		UiTheme.FONT_TAG, UiTheme.TEXT_MUTED))

	var back_button := UiTheme.button("Back", UiTheme.TEXT_SECONDARY, UiTheme.BUTTON_HEIGHT_SMALL)
	back_button.pressed.connect(func() -> void:
		var main: Node = column.get_tree().current_scene
		if main != null and main.has_method("go_to"):
			main.go_to("more")
	)
	column.add_child(back_button)


func refresh() -> void:
	pass
