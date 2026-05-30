extends Node

func _ready() -> void:
	var vp := $SubViewportContainer/SubViewport as SubViewport
	global.game_viewport = vp
	$SubViewportContainer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# SubViewports do NOT inherit the project's default_texture_filter (they
	# default to linear), which blurs the magnified pixel art. Force nearest on
	# the SubViewport's canvas so all inheriting sprites/tilemaps stay crisp.
	RenderingServer.viewport_set_default_canvas_item_texture_filter(
		vp.get_viewport_rid(),
		RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)
	global.scene_change_requested.connect(_on_scene_change)
	_load_scene("res://scenes/home_screen.tscn")

func _on_scene_change(path: String) -> void:
	_load_scene.call_deferred(path)

# Pure-UI scenes render in the root canvas (full physical resolution, so TTF
# text stays crisp). Pixel-art game scenes render inside the 960x540 SubViewport
# for the chunky upscaled look.
const UI_SCENES := ["res://scenes/home_screen.tscn"]

var _current: Node = null

func _load_scene(path: String) -> void:
	if is_instance_valid(_current):
		_current.free()
		_current = null
	# Defensive: clear anything still parented under the SubViewport.
	var vp := $SubViewportContainer/SubViewport as SubViewport
	for child in vp.get_children():
		child.free()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("main.gd: cannot load scene: " + path)
		return
	var inst := packed.instantiate()
	_current = inst
	if path in UI_SCENES:
		add_child(inst)
	else:
		vp.add_child(inst)
