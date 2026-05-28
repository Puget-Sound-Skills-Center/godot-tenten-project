extends CanvasLayer

const UITheme = preload("res://script/ui_theme.gd")

var _load_btn: Button

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	if global.player_dead and not visible:
		_present()

func _present() -> void:
	var save_path := "user://save_slot_%d.cfg" % global.active_save_slot
	_load_btn.visible = FileAccess.file_exists(save_path)
	visible = true
	get_tree().paused = true

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 220)
	panel.offset_left = -200
	panel.offset_top = -110
	panel.offset_right = 200
	panel.offset_bottom = 110
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.20, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_load_btn = Button.new()
	_load_btn.text = "Load Last Save"
	_load_btn.pressed.connect(_on_load_last_save)
	vbox.add_child(_load_btn)

	var home_btn := Button.new()
	home_btn.text = "Home Screen"
	home_btn.pressed.connect(_on_home_screen)
	vbox.add_child(home_btn)

func _on_load_last_save() -> void:
	global.player_dead = false
	if not global.load_from_slot(global.active_save_slot):
		_on_home_screen()
		return
	get_tree().paused = false
	visible = false
	var scene_file := "res://scenes/world.tscn"
	match global.current_scene:
		"cliff_side": scene_file = "res://scenes/cliff_side.tscn"
		"dungeon":    scene_file = "res://scenes/dungeon.tscn"
	get_tree().change_scene_to_file(scene_file)

func _on_home_screen() -> void:
	global.player_dead = false
	global.reset_for_new_game()
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/home_screen.tscn")
