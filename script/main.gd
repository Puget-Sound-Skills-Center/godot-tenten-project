extends Node

func _ready() -> void:
	var vp := $SubViewportContainer/SubViewport as SubViewport
	global.game_viewport = vp
	$SubViewportContainer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global.scene_change_requested.connect(_on_scene_change)
	_load_scene("res://scenes/home_screen.tscn")

func _on_scene_change(path: String) -> void:
	_load_scene.call_deferred(path)

func _load_scene(path: String) -> void:
	var vp := $SubViewportContainer/SubViewport as SubViewport
	for child in vp.get_children():
		child.free()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("main.gd: cannot load scene: " + path)
		return
	vp.add_child(packed.instantiate())
