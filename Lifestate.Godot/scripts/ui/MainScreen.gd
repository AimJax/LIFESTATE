extends Control

## Main screen controller. Owns navigation, the refresh cycle, feedback text and
## the F2 developer overlay. Presentation only: every gameplay mutation goes
## through PlayerState / SaveManager on the GameService session.

const ScreenLifeClass = preload("res://scripts/ui/screens/ScreenLife.gd")
const ScreenActivitiesClass = preload("res://scripts/ui/screens/ScreenActivities.gd")
const ScreenPeopleClass = preload("res://scripts/ui/screens/ScreenPeople.gd")
const ScreenMoreClass = preload("res://scripts/ui/screens/ScreenMore.gd")
const ScreenCharacterClass = preload("res://scripts/ui/screens/ScreenCharacter.gd")
const ScreenEducationClass = preload("res://scripts/ui/screens/ScreenEducation.gd")
const ScreenSaveLoadClass = preload("res://scripts/ui/screens/ScreenSaveLoad.gd")
const ScreenSettingsClass = preload("res://scripts/ui/screens/ScreenSettings.gd")

const NAV_ORDER := ["life", "activities", "people", "more"]

@onready var _title_label: Label = $Layout/TopBar/TopBarRow/TitleLabel
@onready var _clock_label: Label = $Layout/TopBar/TopBarRow/ClockLabel
@onready var _run_button: Button = $Layout/TopBar/TopBarRow/RunButton
@onready var _screen_host: MarginContainer = $Layout/ScreenHost
@onready var _feedback_label: Label = $Layout/FeedbackLabel
@onready var _nav_bar: HBoxContainer = $Layout/NavBar

var _screens: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _screen_roots: Dictionary = {}
var _current_screen: String = "life"
var _focused_screen: String = "life"
var _god_panel: PanelContainer
var _god_visible: bool = false


func _ready() -> void:
	UiTheme.theme()
	_build_shell()
	_build_screens()
	_show_screen("life")

	GameService.state_changed.connect(_on_state_changed)
	GameService.game_loaded.connect(_on_game_loaded)
	GameService.feedback_requested.connect(set_feedback)

	var window: Window = get_window()
	window.min_size = Vector2i(1100, 720)
	_refresh_all()


func _build_shell() -> void:
	_title_label.text = "LIFESTATE"
	_title_label.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY)

	_run_button.pressed.connect(_on_run_pressed)

	for index in NAV_ORDER.size():
		var key: String = NAV_ORDER[index]
		var button: Button = _nav_bar.get_child(index)
		button.pressed.connect(func() -> void: _show_screen(key))
		_nav_buttons[key] = button

	_build_god_overlay()


func _build_screens() -> void:
	_screens = {
		"life": ScreenLifeClass.new(GameService),
		"activities": ScreenActivitiesClass.new(GameService),
		"people": ScreenPeopleClass.new(GameService),
		"more": ScreenMoreClass.new(GameService, self),
		"character": ScreenCharacterClass.new(GameService),
		"education": ScreenEducationClass.new(GameService),
		"save_load": ScreenSaveLoadClass.new(GameService),
		"settings": ScreenSettingsClass.new(GameService),
	}

	for key in _screens:
		var host := Control.new()
		host.name = "Screen_" + key
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		host.visible = false
		_screen_host.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_screen_roots[key] = host
		_screens[key].build(host)


## Navigating must never touch simulation state: this only changes visibility.
func _show_screen(key: String) -> void:
	_current_screen = key
	for screen_key in _screen_roots:
		var host: Control = _screen_roots[screen_key]
		host.visible = screen_key == key

	var nav_key: String = key if NAV_ORDER.has(key) else "more"
	for nav in _nav_buttons:
		var button: Button = _nav_buttons[nav]
		var selected: bool = nav == nav_key
		button.add_theme_color_override("font_color", UiTheme.ACCENT if selected else UiTheme.TEXT_SECONDARY)
		button.add_theme_color_override("font_hover_color", UiTheme.ACCENT if selected else UiTheme.TEXT_PRIMARY)

	_refresh_all()


func _refresh_all() -> void:
	_clock_label.text = GameService.clock_text()
	var running: bool = GameService.is_running
	_run_button.text = "Running" if running else "Paused"
	_run_button.add_theme_color_override("font_color", UiTheme.POSITIVE if running else UiTheme.TEXT_SECONDARY)

	if _screens.has(_current_screen):
		_screens[_current_screen].refresh()
	# The More hub mirrors a few live values, so keep it current cheaply.
	if _current_screen != "more" and _screen_roots["more"].visible:
		_screens["more"].refresh()


func _on_state_changed() -> void:
	_refresh_all()


func _on_game_loaded(offline_seconds: int) -> void:
	if offline_seconds > 0:
		set_feedback("Game loaded. %d seconds of offline time were simulated." % offline_seconds, UiTheme.POSITIVE)
	else:
		set_feedback("Game loaded.", UiTheme.POSITIVE)


func _on_run_pressed() -> void:
	GameService.toggle_running()
	_refresh_all()


## Contextual feedback: errors negative, success positive, neutral secondary.
func set_feedback(text: String, color: Color = UiTheme.TEXT_SECONDARY) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)


func go_to(key: String) -> void:
	_show_screen(key)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		toggle_god_mode()
		get_viewport().set_input_as_handled()


# =====================================================================
# Developer overlay (F2) — hidden by default, never part of the game layout
# =====================================================================

func _build_god_overlay() -> void:
	_god_panel = PanelContainer.new()
	_god_panel.name = "GodModeOverlay"
	_god_panel.custom_minimum_size = Vector2(290, 0)
	_god_panel.visible = false
	_god_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE_RAISED, UiTheme.WARNING))
	add_child(_god_panel)

	var body := UiTheme.card_body(_god_panel, UiTheme.SPACE_XS)
	body.add_child(UiTheme.tag("DEVELOPER — GOD MODE", UiTheme.WARNING))
	body.add_child(UiTheme.label("F2 closes this panel", UiTheme.FONT_TAG, UiTheme.TEXT_MUTED))

	_add_god_button(body, "+1 Day", func() -> void: GameService.god_mode.advance_days(1))
	_add_god_button(body, "+1 Year", func() -> void: GameService.god_mode.advance_days(365))
	_add_god_button(body, "+10 Years", func() -> void: GameService.god_mode.advance_days(3650))
	_add_god_button(body, "+100 Money", func() -> void: GameService.god_mode.add_money(100))
	_add_god_button(body, "Restore Needs", func() -> void: GameService.god_mode.restore_needs())
	_add_god_button(body, "Max Attributes", func() -> void: GameService.god_mode.max_attributes())
	_add_god_button(body, "Max Skills", func() -> void: GameService.god_mode.max_skills())
	_add_god_button(body, "Max Traits", func() -> void: GameService.god_mode.max_traits())
	_add_god_button(body, "Complete Current School Grade", func() -> void: _on_complete_school_grade())

	var close_button := UiTheme.button("Close (F2)", UiTheme.NEGATIVE, UiTheme.BUTTON_HEIGHT_SMALL)
	close_button.pressed.connect(toggle_god_mode)
	body.add_child(close_button)

	resized.connect(_position_god_overlay)
	_position_god_overlay()


func _add_god_button(parent: Control, text: String, action: Callable) -> void:
	var button := UiTheme.button(text, UiTheme.TEXT_PRIMARY, UiTheme.BUTTON_HEIGHT_SMALL)
	button.pressed.connect(func() -> void:
		action.call()
		_refresh_all()
	)
	parent.add_child(button)


func _position_god_overlay() -> void:
	if _god_panel == null:
		return
	_god_panel.position = Vector2(
		size.x - _god_panel.size.x - UiTheme.SPACE_MD,
		UiTheme.TOP_BAR_HEIGHT + UiTheme.SPACE_MD
	)


func _on_complete_school_grade() -> void:
	var result := GameService.god_mode.complete_current_school_grade()
	if result["ok"]:
		set_feedback(result["message"], UiTheme.POSITIVE)
	else:
		set_feedback(result["message"], UiTheme.WARNING)
	_refresh_all()
	_show_screen("education")

## Enabled state and visibility move together, so a hidden overlay can never be
## left silently active.
func toggle_god_mode() -> void:
	_god_visible = not _god_visible
	GameService.god_mode.set_enabled(_god_visible)
	_god_panel.visible = _god_visible
	if _god_visible:
		_god_panel.reset_size()
		_position_god_overlay()
		_god_panel.move_to_front()
		set_feedback("God Mode enabled.", UiTheme.WARNING)
	else:
		set_feedback("God Mode disabled.", UiTheme.TEXT_SECONDARY)


func is_god_mode_visible() -> bool:
	return _god_visible
