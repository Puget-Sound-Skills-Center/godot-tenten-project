extends Node

func _ready() -> void:
	var vp := $SubViewportContainer/SubViewport as SubViewport
	global.game_viewport = vp
	$SubViewportContainer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global.scene_change_requested.connect(_on_scene_change)
	_load_scene("res://scenes/home_screen.tscn")

func _on_scene_change(path: String) -> void:
	_load_scene(path)

func _load_scene(path: String) -> void:
	var vp := $SubViewportContainer/SubViewport as SubViewport
	for child in vp.get_children():
		child.queue_free()
	var packed = load(path)
	if packed == null:
		push_error("main.gd: cannot load scene: " + path)
		return
	vp.add_child(packed.instantiate())
