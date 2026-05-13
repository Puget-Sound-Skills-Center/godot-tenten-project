extends Node2D

const TILE := 16
const ROOM_W_BASE := 480
const ROOM_H_BASE := 320
const PLAYER_SCENE := "res://scenes/player.tscn"
const ENEMY_SCENE := "res://scenes/enemy.tscn"
const ENEMY_SCRIPT_BASE   := "res://script/enemy_base.gd"
const ENEMY_SCRIPT_RANGED := "res://script/enemy_ranged.gd"
const ENEMY_SCRIPT_FAST   := "res://script/enemy_fast.gd"
const ENEMY_SCRIPT_TANK   := "res://script/enemy_tank.gd"

const FLOOR_COLOR := Color(0.07, 0.06, 0.09)
const WALL_COLOR := Color(0.18, 0.16, 0.22)
const EXIT_COLOR := Color(0.20, 0.85, 0.30)
const EXIT_UNLOCKED_COLOR := Color(0.95, 0.90, 0.20)
const SAVE_COLOR := Color(0.95, 0.85, 0.20)
const PUZZLE_TILE_COLOR := Color(0.55, 0.25, 0.85)
const PUZZLE_TILE_DONE_COLOR := Color(0.20, 0.80, 0.30)
const TRAP_GREEN_COLOR := Color(0.20, 0.80, 0.30)
const TRAP_RED_COLOR := Color(0.85, 0.20, 0.25)
const MATH_TILE_COLOR := Color(0.30, 0.50, 0.85)
const MATH_WRONG_COLOR := Color(0.85, 0.20, 0.25)
const ECHO_TILE_COLOR := Color(0.35, 0.30, 0.55)
const ECHO_FLASH_COLOR := Color(1.0, 1.0, 1.0)

const THEME_CAVE := {
	"floor": Color(0.07, 0.06, 0.09),
	"wall":  Color(0.18, 0.16, 0.22),
	"exit":  Color(0.20, 0.85, 0.30),
	"accent": Color(0.35, 0.30, 0.55),
}
const THEME_RUINS := {
	"floor": Color(0.10, 0.08, 0.05),
	"wall":  Color(0.30, 0.22, 0.14),
	"exit":  Color(0.85, 0.75, 0.20),
	"accent": Color(0.55, 0.40, 0.20),
}
const THEME_ABYSS := {
	"floor": Color(0.02, 0.02, 0.08),
	"wall":  Color(0.08, 0.06, 0.20),
	"exit":  Color(0.60, 0.20, 0.90),
	"accent": Color(0.30, 0.10, 0.60),
}

var _theme: Dictionary

const PUZZLE_PROBABILITY := 0.2
const PUZZLE_TYPES := ["order", "math", "trap", "echo", "switches"]

var room_w: int
var room_h: int
var rng := RandomNumberGenerator.new()

var player_node: Node2D
var floor_label: Label
var save_prompt_label: Label
var puzzle_label: Label
var save_point_active := false

var puzzle_active := false
var puzzle_type := ""
var puzzle_tiles: Array = []
var puzzle_next_index := 0
var math_answer := 0
var trap_greens_total := 0
var trap_greens_done := 0
var switches_total := 0
var switches_done := 0
var echo_sequence: Array = []
var echo_input_index := 0
var echo_demo_active := false
var floor_exit_visual: ColorRect = null
var floor_exit_label: Label = null

func _ready() -> void:
	rng.randomize()
	var floor_no := clampi(global.current_floor, 1, global.DUNGEON_MAX_FLOOR)
	global.current_floor = floor_no
	_theme = _get_dungeon_theme(floor_no)
	global.current_scene = "dungeon"

	room_w = ROOM_W_BASE + floor_no * 8
	room_h = ROOM_H_BASE + floor_no * 8

	_build_floor_background()
	_build_outer_walls()
	var obstacles := _build_random_obstacles(floor_no)
	_setup_navigation(obstacles)
	_spawn_player()
	_spawn_enemies(floor_no, obstacles)
	_spawn_dungeon_dialogue_npc(floor_no, obstacles)
	var exit_pos := _build_floor_exit(floor_no, obstacles)
	_add_exit_barrier(exit_pos, obstacles)
	if floor_no % 10 == 0:
		_build_save_point(obstacles)
	_build_hud(floor_no)
	if rng.randf() < PUZZLE_PROBABILITY:
		_setup_puzzle(floor_no, obstacles, exit_pos)

func _process(_delta: float) -> void:
	if save_point_active and Input.is_action_just_pressed("interact"):
		_save_and_exit()
	_check_next_floor()

func _check_next_floor() -> void:
	if not global.next_floor:
		return
	global.next_floor = false
	if global.current_floor >= global.DUNGEON_MAX_FLOOR:
		_exit_to_cliffside(1)
		return
	global.current_floor += 1
	dialogue_manager.force_close()
	get_tree().reload_current_scene()

func _save_and_exit() -> void:
	var resume := mini(global.current_floor + 1, global.DUNGEON_MAX_FLOOR)
	_exit_to_cliffside(resume)

func _exit_to_cliffside(resume_floor: int) -> void:
	# Defensive force_close so a paused tree never carries across scene change (IN-04)
	dialogue_manager.force_close()
	global.dungeon_resume_floor = clampi(resume_floor, 1, global.DUNGEON_MAX_FLOOR)
	global.came_from_dungeon = true
	global.current_floor = 0
	global.current_scene = "cliff_side"
	get_tree().change_scene_to_file("res://scenes/cliff_side.tscn")

# --- Build helpers ---

func _setup_navigation(obstacles: Array) -> void:
	var geo := NavigationMeshSourceGeometryData2D.new()

	# Walkable floor: room interior minus the wall border
	geo.add_traversable_outline(PackedVector2Array([
		Vector2(TILE, TILE),
		Vector2(TILE, room_h - TILE),
		Vector2(room_w - TILE, room_h - TILE),
		Vector2(room_w - TILE, TILE),
	]))

	# Each obstacle rect punched out as a hole
	for rect in obstacles:
		geo.add_obstruction_outline(PackedVector2Array([
			rect.position,
			Vector2(rect.position.x, rect.end.y),
			rect.end,
			Vector2(rect.end.x, rect.position.y),
		]))

	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 10.0
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, geo)

	var nav_region := NavigationRegion2D.new()
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)

func _build_floor_background() -> void:
	var bg := ColorRect.new()
	bg.color = _theme.floor
	bg.position = Vector2.ZERO
	bg.size = Vector2(room_w, room_h)
	bg.z_index = -10
	add_child(bg)

func _make_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	var visual := ColorRect.new()
	visual.color = _theme.wall
	visual.position = -rect.size / 2.0
	visual.size = rect.size
	body.add_child(visual)
	add_child(body)

func _build_outer_walls() -> void:
	var t := TILE
	_make_wall(Rect2(0, 0, room_w, t))
	_make_wall(Rect2(0, room_h - t, room_w, t))
	_make_wall(Rect2(0, 0, t, room_h))
	_make_wall(Rect2(room_w - t, 0, t, room_h))

func _spawn_zone() -> Rect2:
	return Rect2(TILE, TILE, 6 * TILE, 6 * TILE)

func _exit_zone() -> Rect2:
	return Rect2(room_w - 7 * TILE, room_h - 7 * TILE, 6 * TILE, 6 * TILE)

func _build_random_obstacles(floor_no: int) -> Array:
	var rects: Array = []
	var target := 6 + floor_no / 5
	target = mini(target, 25)
	var attempts := 0
	while rects.size() < target and attempts < target * 8:
		attempts += 1
		var w := rng.randi_range(2, 6) * TILE
		var h := rng.randi_range(1, 4) * TILE
		var max_tx := maxi(2, room_w / TILE - 2 - w / TILE)
		var max_ty := maxi(2, room_h / TILE - 2 - h / TILE)
		var x := rng.randi_range(2, max_tx) * TILE
		var y := rng.randi_range(2, max_ty) * TILE
		var r := Rect2(x, y, w, h)
		if r.intersects(_spawn_zone()) or r.intersects(_exit_zone()):
			continue
		var clash := false
		for existing in rects:
			if r.intersects(existing.grow(TILE)):
				clash = true
				break
		if clash:
			continue
		rects.append(r)
		_make_wall(r)
	return rects

func _is_position_clear(pos: Vector2, obstacles: Array, radius: int = 8) -> bool:
	var pad := Rect2(pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
	if pad.position.x < TILE or pad.position.y < TILE:
		return false
	if pad.end.x > room_w - TILE or pad.end.y > room_h - TILE:
		return false
	if pad.intersects(_spawn_zone()):
		return false
	for r in obstacles:
		if pad.intersects(r):
			return false
	return true

func _spawn_player() -> void:
	var packed: PackedScene = load(PLAYER_SCENE)
	player_node = packed.instantiate()
	player_node.position = Vector2(2 * TILE + 8, 2 * TILE + 8)
	add_child(player_node)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = room_w
	cam.limit_bottom = room_h
	cam.limit_smoothed = true
	cam.drag_horizontal_enabled = true
	cam.drag_vertical_enabled = true
	player_node.add_child(cam)

func _spawn_enemies(floor_no: int, obstacles: Array) -> void:
	var max_count := mini(5 + floor_no, 30)
	var count := rng.randi_range(1, max_count)
	var packed: PackedScene = load(ENEMY_SCENE)
	var spawned := 0
	var attempts := 0
	while spawned < count and attempts < count * 30:
		attempts += 1
		var x := rng.randi_range(3, room_w / TILE - 3) * TILE
		var y := rng.randi_range(3, room_h / TILE - 3) * TILE
		var pos := Vector2(x, y)
		if not _is_position_clear(pos, obstacles, 14):
			continue
		var enemy: Node2D = packed.instantiate()
		enemy.set_script(load(_pick_enemy_script(floor_no)))
		enemy.position = pos
		add_child(enemy)
		var mult := _get_floor_multiplier(floor_no)
		enemy.max_health = int(enemy.max_health * mult)
		enemy.speed = float(enemy.speed) * mult
		enemy.money_drop = int(enemy.money_drop * mult)
		enemy.health = enemy.max_health
		spawned += 1

func _spawn_dungeon_dialogue_npc(_floor_no: int, obstacles: Array) -> void:
	var pos := _pick_save_position(obstacles)
	var npc := load("res://script/dungeon_dialogue_npc.gd").new()
	npc.position = pos
	add_child(npc)

func _build_floor_exit(floor_no: int, obstacles: Array) -> Vector2:
	var pos := _pick_exit_position(obstacles)
	var area := Area2D.new()
	area.position = pos
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, TILE)
	shape_node.shape = shape
	area.add_child(shape_node)
	var visual := ColorRect.new()
	visual.color = _theme.exit
	visual.position = Vector2(-TILE / 2.0, -TILE / 2.0)
	visual.size = Vector2(TILE, TILE)
	area.add_child(visual)
	var lbl := Label.new()
	lbl.text = "FINAL" if floor_no >= global.DUNGEON_MAX_FLOOR else "NEXT"
	lbl.position = Vector2(-TILE, -TILE - 6)
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	area.add_child(lbl)
	area.body_entered.connect(_on_exit_body_entered)
	add_child(area)
	floor_exit_visual = visual
	floor_exit_label = lbl
	return pos

func _pick_exit_position(obstacles: Array) -> Vector2:
	var ez := _exit_zone()
	var min_tx := int(ez.position.x) / TILE
	var max_tx := int(ez.position.x + ez.size.x) / TILE
	var min_ty := int(ez.position.y) / TILE
	var max_ty := int(ez.position.y + ez.size.y) / TILE
	for i in 80:
		var x := rng.randi_range(min_tx, max_tx) * TILE + TILE / 2
		var y := rng.randi_range(min_ty, max_ty) * TILE + TILE / 2
		var p := Vector2(x, y)
		if _is_position_clear(p, obstacles, 8):
			return p
	return ez.position + ez.size / 2.0

func _add_exit_barrier(exit_pos: Vector2, obstacles: Array) -> void:
	var sides := [0, 1, 2, 3]
	sides.shuffle()
	var added := 0
	for side in sides:
		if added >= 2:
			break
		var rect: Rect2
		match side:
			0:
				rect = Rect2(exit_pos.x - 2 * TILE, exit_pos.y - 1.5 * TILE, TILE, 3 * TILE)
			1:
				rect = Rect2(exit_pos.x + TILE, exit_pos.y - 1.5 * TILE, TILE, 3 * TILE)
			2:
				rect = Rect2(exit_pos.x - 1.5 * TILE, exit_pos.y - 2 * TILE, 3 * TILE, TILE)
			_:
				rect = Rect2(exit_pos.x - 1.5 * TILE, exit_pos.y + TILE, 3 * TILE, TILE)
		if rect.position.x < TILE or rect.position.y < TILE:
			continue
		if rect.end.x > room_w - TILE or rect.end.y > room_h - TILE:
			continue
		_make_wall(rect)
		obstacles.append(rect)
		added += 1

func _get_dungeon_theme(floor_no: int) -> Dictionary:
	if floor_no >= 67:
		return THEME_ABYSS
	elif floor_no >= 34:
		return THEME_RUINS
	else:
		return THEME_CAVE

func _pick_enemy_script(floor_no: int) -> String:
	if floor_no < 10:
		return ENEMY_SCRIPT_BASE
	elif floor_no < 34:
		return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_FAST].pick_random()
	elif floor_no < 67:
		return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_RANGED, ENEMY_SCRIPT_FAST].pick_random()
	else:
		return [ENEMY_SCRIPT_BASE, ENEMY_SCRIPT_RANGED, ENEMY_SCRIPT_FAST, ENEMY_SCRIPT_TANK].pick_random()

func _get_floor_multiplier(floor_no: int) -> float:
	return 1.0 + (floor_no - 1) / 99.0 * 2.0

func _on_exit_body_entered(body: Node2D) -> void:
	if not body.has_method("player"):
		return
	if puzzle_active:
		return
	global.next_floor = true

func _build_save_point(obstacles: Array) -> void:
	var pos := _pick_save_position(obstacles)
	var area := Area2D.new()
	area.position = pos
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, TILE)
	shape_node.shape = shape
	area.add_child(shape_node)
	var visual := ColorRect.new()
	visual.color = SAVE_COLOR
	visual.position = Vector2(-TILE / 2.0, -TILE / 2.0)
	visual.size = Vector2(TILE, TILE)
	area.add_child(visual)
	var lbl := Label.new()
	lbl.text = "SAVE"
	lbl.position = Vector2(-TILE, -TILE - 6)
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	area.add_child(lbl)
	area.body_entered.connect(_on_save_body_entered)
	area.body_exited.connect(_on_save_body_exited)
	add_child(area)

func _pick_save_position(obstacles: Array) -> Vector2:
	for i in 80:
		var min_tx := 8
		var max_tx := maxi(min_tx + 1, room_w / TILE - 8)
		var min_ty := 4
		var max_ty := maxi(min_ty + 1, room_h / TILE - 12)
		var x := rng.randi_range(min_tx, max_tx) * TILE + TILE / 2
		var y := rng.randi_range(min_ty, max_ty) * TILE + TILE / 2
		var p := Vector2(x, y)
		if _is_position_clear(p, obstacles, 10):
			return p
	return Vector2(room_w / 2, room_h / 2)

func _on_save_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		save_point_active = true
		if save_prompt_label:
			save_prompt_label.visible = true

func _on_save_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		save_point_active = false
		if save_prompt_label:
			save_prompt_label.visible = false

func _build_hud(floor_no: int) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	floor_label = Label.new()
	floor_label.position = Vector2(8, 24)
	floor_label.text = "Dungeon Floor %d / %d" % [floor_no, global.DUNGEON_MAX_FLOOR]
	floor_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(floor_label)

	save_prompt_label = Label.new()
	save_prompt_label.text = "[E] Save & exit dungeon"
	save_prompt_label.position = Vector2(120, 240)
	save_prompt_label.add_theme_color_override("font_color", Color.YELLOW)
	save_prompt_label.visible = false
	canvas.add_child(save_prompt_label)

	puzzle_label = Label.new()
	puzzle_label.position = Vector2(8, 40)
	puzzle_label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	puzzle_label.visible = false
	canvas.add_child(puzzle_label)

# --- Puzzle ---

func _setup_puzzle(floor_no: int, obstacles: Array, exit_pos: Vector2) -> void:
	puzzle_active = true
	puzzle_type = PUZZLE_TYPES[rng.randi() % PUZZLE_TYPES.size()]
	if puzzle_label:
		puzzle_label.visible = true
	match puzzle_type:
		"order":
			_build_puzzle_order(floor_no, obstacles, exit_pos)
		"math":
			_build_puzzle_math(floor_no, obstacles, exit_pos)
		"trap":
			_build_puzzle_trap(floor_no, obstacles, exit_pos)
		"echo":
			_build_puzzle_echo(floor_no, obstacles, exit_pos)
		"switches":
			_build_puzzle_switches(floor_no, obstacles, exit_pos)

func _pick_puzzle_tile_position(obstacles: Array, exit_pos: Vector2) -> Vector2:
	var min_tile_dist := 3 * TILE
	for i in 120:
		var x := rng.randi_range(4, maxi(4, room_w / TILE - 4)) * TILE + TILE / 2
		var y := rng.randi_range(4, maxi(4, room_h / TILE - 4)) * TILE + TILE / 2
		var p := Vector2(x, y)
		if not _is_position_clear(p, obstacles, 10):
			continue
		if p.distance_to(exit_pos) < min_tile_dist:
			continue
		var clash := false
		for existing in puzzle_tiles:
			if p.distance_to(existing.position) < min_tile_dist:
				clash = true
				break
		if clash:
			continue
		return p
	return Vector2(room_w / 2, room_h / 2)

func _make_tile_base(pos: Vector2, color: Color, label_text: String) -> Area2D:
	var area := Area2D.new()
	area.position = pos
	area.z_index = -1
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, TILE)
	shape_node.shape = shape
	area.add_child(shape_node)
	var visual := ColorRect.new()
	visual.color = color
	visual.position = Vector2(-TILE / 2.0, -TILE / 2.0)
	visual.size = Vector2(TILE, TILE)
	area.add_child(visual)
	if label_text != "":
		var lbl := Label.new()
		lbl.text = label_text
		lbl.position = Vector2(-3, -8) if label_text.length() <= 1 else Vector2(-6, -8)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		area.add_child(lbl)
	area.body_entered.connect(_on_puzzle_tile_entered.bind(area))
	return area

func _set_tile_color(tile: Node, color: Color) -> void:
	for child in tile.get_children():
		if child is ColorRect:
			(child as ColorRect).color = color
			return

func _on_puzzle_tile_entered(body: Node2D, tile: Area2D) -> void:
	if not body.has_method("player"):
		return
	if not puzzle_active:
		return
	match puzzle_type:
		"order":
			_handle_order_tile(tile)
		"math":
			_handle_math_tile(tile)
		"trap":
			_handle_trap_tile(tile)
		"echo":
			_handle_echo_tile(tile)
		"switches":
			_handle_switches_tile(tile)

func _unlock_exit() -> void:
	puzzle_active = false
	if floor_exit_visual:
		floor_exit_visual.color = EXIT_UNLOCKED_COLOR
	if floor_exit_label:
		floor_exit_label.text = "OPEN"

# --- Type: Order ---

func _build_puzzle_order(floor_no: int, obstacles: Array, exit_pos: Vector2) -> void:
	var tile_count := clampi(3 + (floor_no - 1) / 13, 3, 8)
	for i in tile_count:
		var pos := _pick_puzzle_tile_position(obstacles, exit_pos)
		var tile := _make_tile_base(pos, PUZZLE_TILE_COLOR, str(i + 1))
		tile.set_meta("number", i + 1)
		tile.set_meta("activated", false)
		puzzle_tiles.append(tile)
		add_child(tile)
	if puzzle_label:
		puzzle_label.text = "Order: step tiles 1-%d in order (next: 1)" % tile_count

func _handle_order_tile(tile: Area2D) -> void:
	var num: int = tile.get_meta("number")
	if num == puzzle_next_index + 1:
		tile.set_meta("activated", true)
		_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
		puzzle_next_index = num
		if puzzle_next_index >= puzzle_tiles.size():
			if puzzle_label:
				puzzle_label.text = "Order solved! Exit unlocked."
			_unlock_exit()
		elif puzzle_label:
			puzzle_label.text = "Order: next tile %d / %d" % [puzzle_next_index + 1, puzzle_tiles.size()]
	else:
		_reset_order()

func _reset_order() -> void:
	puzzle_next_index = 0
	for t in puzzle_tiles:
		t.set_meta("activated", false)
		_set_tile_color(t, PUZZLE_TILE_COLOR)
	if puzzle_label:
		puzzle_label.text = "Wrong! Reset. Step 1-%d in order" % puzzle_tiles.size()

# --- Type: Math ---

func _build_puzzle_math(floor_no: int, obstacles: Array, exit_pos: Vector2) -> void:
	var a := rng.randi_range(1, 9)
	var b := rng.randi_range(1, 9)
	var op := "+"
	var op_kind := 0
	if floor_no >= 30 and rng.randf() < 0.5:
		op_kind = 1
	if floor_no >= 60 and rng.randf() < 0.4:
		op_kind = 2
	if floor_no >= 50 and op_kind != 2:
		a = rng.randi_range(1, 20)
		b = rng.randi_range(1, 20)
	match op_kind:
		1:
			op = "-"
			if a < b:
				var t := a
				a = b
				b = t
			math_answer = a - b
		2:
			op = "x"
			a = rng.randi_range(2, 9)
			b = rng.randi_range(2, 9)
			math_answer = a * b
		_:
			op = "+"
			math_answer = a + b
	var tile_count := 5
	var numbers: Array = [math_answer]
	var range_max: int = maxi(math_answer * 2, 30)
	while numbers.size() < tile_count:
		var d := rng.randi_range(0, range_max)
		if d != math_answer and not (d in numbers):
			numbers.append(d)
	numbers.shuffle()
	for n in numbers:
		var pos := _pick_puzzle_tile_position(obstacles, exit_pos)
		var tile := _make_tile_base(pos, MATH_TILE_COLOR, str(n))
		tile.set_meta("value", n)
		puzzle_tiles.append(tile)
		add_child(tile)
	if puzzle_label:
		puzzle_label.text = "Solve: %d %s %d = ?  (step the answer)" % [a, op, b]

func _handle_math_tile(tile: Area2D) -> void:
	var v: int = tile.get_meta("value")
	if v == math_answer:
		_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
		if puzzle_label:
			puzzle_label.text = "Correct! Exit unlocked."
		_unlock_exit()
	else:
		_set_tile_color(tile, MATH_WRONG_COLOR)
		if puzzle_label:
			puzzle_label.text = "Wrong! Try another tile."

# --- Type: Trap ---

func _build_puzzle_trap(floor_no: int, obstacles: Array, exit_pos: Vector2) -> void:
	var greens := clampi(3 + (floor_no - 1) / 13, 3, 8)
	var reds := clampi(2 + (floor_no - 1) / 25, 2, 6)
	trap_greens_total = greens
	trap_greens_done = 0
	for i in greens:
		var pos := _pick_puzzle_tile_position(obstacles, exit_pos)
		var tile := _make_tile_base(pos, TRAP_GREEN_COLOR, "")
		tile.set_meta("is_green", true)
		tile.set_meta("activated", false)
		puzzle_tiles.append(tile)
		add_child(tile)
	for i in reds:
		var pos := _pick_puzzle_tile_position(obstacles, exit_pos)
		var tile := _make_tile_base(pos, TRAP_RED_COLOR, "")
		tile.set_meta("is_green", false)
		puzzle_tiles.append(tile)
		add_child(tile)
	if puzzle_label:
		puzzle_label.text = "Trap: step %d GREEN, avoid %d RED" % [greens, reds]

func _handle_trap_tile(tile: Area2D) -> void:
	var is_green: bool = tile.get_meta("is_green")
	if not is_green:
		_reset_trap()
		return
	var activated: bool = tile.get_meta("activated")
	if activated:
		return
	tile.set_meta("activated", true)
	_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
	trap_greens_done += 1
	if trap_greens_done >= trap_greens_total:
		if puzzle_label:
			puzzle_label.text = "Trap cleared! Exit unlocked."
		_unlock_exit()
	elif puzzle_label:
		puzzle_label.text = "Trap: %d/%d greens (avoid red!)" % [trap_greens_done, trap_greens_total]

func _reset_trap() -> void:
	trap_greens_done = 0
	for t in puzzle_tiles:
		if t.get_meta("is_green"):
			t.set_meta("activated", false)
			_set_tile_color(t, TRAP_GREEN_COLOR)
	if puzzle_label:
		puzzle_label.text = "Stepped on RED! Reset. (0/%d greens)" % trap_greens_total

# --- Type: Echo (Simon Says) ---

func _build_puzzle_echo(floor_no: int, obstacles: Array, exit_pos: Vector2) -> void:
	var seq_len := clampi(2 + (floor_no - 1) / 20, 2, 6)
	var tile_count := maxi(seq_len + 1, 4)
	for i in tile_count:
		var pos := _pick_puzzle_tile_position(obstacles, exit_pos)
		var tile := _make_tile_base(pos, _theme.accent, "")
		tile.set_meta("index", i)
		puzzle_tiles.append(tile)
		add_child(tile)
	echo_sequence.clear()
	for j in seq_len:
		echo_sequence.append(rng.randi_range(0, tile_count - 1))
	echo_input_index = 0
	if puzzle_label:
		puzzle_label.text = "Echo: watch the %d-step sequence..." % seq_len
	_play_echo_demo()

func _play_echo_demo() -> void:
	echo_demo_active = true
	echo_input_index = 0
	for t in puzzle_tiles:
		_set_tile_color(t, _theme.accent)
	var tween := create_tween()
	tween.tween_interval(0.5)
	for seq_idx in echo_sequence:
		var tile: Area2D = puzzle_tiles[seq_idx]
		tween.tween_callback(_set_tile_color.bind(tile, ECHO_FLASH_COLOR))
		tween.tween_interval(0.4)
		tween.tween_callback(_set_tile_color.bind(tile, _theme.accent))
		tween.tween_interval(0.2)
	tween.tween_callback(_finish_echo_demo)

func _finish_echo_demo() -> void:
	echo_demo_active = false
	if puzzle_label:
		puzzle_label.text = "Echo: repeat the sequence! (1 / %d)" % echo_sequence.size()

func _handle_echo_tile(tile: Area2D) -> void:
	if echo_demo_active:
		return
	var idx: int = tile.get_meta("index")
	if idx == echo_sequence[echo_input_index]:
		_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
		echo_input_index += 1
		if echo_input_index >= echo_sequence.size():
			if puzzle_label:
				puzzle_label.text = "Echo solved! Exit unlocked."
			_unlock_exit()
		elif puzzle_label:
			puzzle_label.text = "Echo: %d / %d" % [echo_input_index + 1, echo_sequence.size()]
	else:
		if puzzle_label:
			puzzle_label.text = "Wrong! Replaying sequence..."
		_play_echo_demo()

# --- Type: Switches ---

func _build_puzzle_switches(floor_no: int, obstacles: Array, exit_pos: Vector2) -> void:
	var n := clampi(3 + (floor_no - 1) / 13, 3, 8)
	switches_total = n
	switches_done = 0
	for i in n:
		var pos := _pick_puzzle_tile_position(obstacles, exit_pos)
		var tile := _make_tile_base(pos, PUZZLE_TILE_COLOR, "")
		tile.set_meta("activated", false)
		puzzle_tiles.append(tile)
		add_child(tile)
	if puzzle_label:
		puzzle_label.text = "Switches: activate all %d tiles (any order)" % n

func _handle_switches_tile(tile: Area2D) -> void:
	var activated: bool = tile.get_meta("activated")
	if activated:
		return
	tile.set_meta("activated", true)
	_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
	switches_done += 1
	if switches_done >= switches_total:
		if puzzle_label:
			puzzle_label.text = "All switches active! Exit unlocked."
		_unlock_exit()
	elif puzzle_label:
		puzzle_label.text = "Switches: %d / %d" % [switches_done, switches_total]
