extends SceneTree

## Generates res://themes/Lifestate.tres from UiTheme so the committed resource
## is guaranteed-valid Godot text rather than hand-authored.
##
##   godot --headless --path Lifestate.Godot --script res://tools/generate_theme.gd

func _initialize() -> void:
	var theme := UiTheme.build_theme()
	DirAccess.make_dir_recursive_absolute("res://themes")
	var error: int = ResourceSaver.save(theme, "res://themes/Lifestate.tres")
	if error != OK:
		push_error("Failed to save theme: %d" % error)
		quit(1)
		return
	print("Saved res://themes/Lifestate.tres")
	quit(0)
