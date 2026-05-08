extends Node2D

const TILE := 16
const PLAYER_SCENE := "res://scenes/player.tscn"
const TEST_FLOOR := 30

const ROOM_W := 1280
const ROOM_H := 800

const FLOOR_COLOR := Color(0.07, 0.06, 0.09)
const WALL_COLOR := Color(0.18, 0.16, 0.22)
const ZONE_DIVIDER_COLOR := Color(0.13, 0.11, 0.17)
const PUZZLE_TILE_COLOR := Color(0.55, 0.25, 0.85)
const PUZZLE_TILE_DONE_COLOR := Color(0.20, 0.80, 0.30)
const TRAP_GREEN_COLOR := Color(0.20, 0.80, 0.30)
const TRAP_RED_COLOR := Color(0.85, 0.20, 0.25)
const MATH_TILE_COLOR := Color(0.30, 0.50, 0.85)
const MATH_WRONG_COLOR := Color(0.85, 0.20, 0.25)
const ECHO_TILE_COLOR := Color(0.35, 0.30, 0.55)
const ECHO_FLASH_COLOR := Color(1.0, 1.0, 1.0)
const RESET_COLOR := Color(0.95, 0.85, 0.20)
const SOLVED_LABEL_COLOR := Color(0.45, 0.95, 0.45)

const ZONE_W := ROOM_W / 3
const ZONE_H := ROOM_H / 2
const ZONE_MARGIN := 40

const ZONE_ORDER := Rect2(0, 0, ZONE_W, ZONE_H)
const ZONE_MATH := Rect2(ZONE_W, 0, ZONE_W, ZONE_H)
const ZONE_TRAP := Rect2(2 * ZONE_W, 0, ZONE_W, ZONE_H)
const ZONE_ECHO := Rect2(0, ZONE_H, ZONE_W, ZONE_H)
const ZONE_SWITCHES := Rect2(ZONE_W, ZONE_H, ZONE_W, ZONE_H)
const ZONE_RESET := Rect2(2 * ZONE_W, ZONE_H, ZONE_W, ZONE_H)

var rng := RandomNumberGenerator.new()
var player_node: Node2D
var on_reset_pad := false

# Order
var order_tiles: Array = []
var order_next_index := 0
var order_label: Label

# Math
var math_tiles: Array = []
var math_answer := 0
var math_solved := false
var math_label: Label

# Trap
var trap_tiles: Array = []
var trap_greens_total := 0
var trap_greens_done := 0
var trap_solved := false
var trap_label: Label

# Echo
var echo_tiles: Array = []
var echo_sequence: Array = []
var echo_input_index := 0
var echo_demo_active := false
var echo_solved := false
var echo_label: Label

# Switches
var switches_tiles: Array = []
var switches_total := 0
var switches_done := 0
var switches_solved := false
var switches_label: Label

func _ready() -> void:
	rng.randomize()
	_build_floor_background()
	_build_outer_walls()
	_build_zone_dividers()
	_build_zone_labels()
	_build_reset_pad()
	_spawn_player()
	_build_all_puzzles()

func _process(_delta: float) -> void:
	if on_reset_pad and Input.is_action_just_pressed("interact"):
		_reset_all_puzzles()

# --- Layout ---

func _build_floor_background() -> void:
	var bg := ColorRect.new()
	bg.color = FLOOR_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(ROOM_W, ROOM_H)
	bg.z_index = -10
	add_child(bg)

func _make_wall(rect: Rect2, color: Color = WALL_COLOR, with_collision: bool = true) -> void:
	if with_collision:
		var body := StaticBody2D.new()
		body.position = rect.position + rect.size / 2.0
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		shape_node.shape = shape
		body.add_child(shape_node)
		var visual := ColorRect.new()
		visual.color = color
		visual.position = -rect.size / 2.0
		visual.size = rect.size
		body.add_child(visual)
		add_child(body)
	else:
		var visual := ColorRect.new()
		visual.color = color
		visual.position = rect.position
		visual.size = rect.size
		visual.z_index = -5
		add_child(visual)

func _build_outer_walls() -> void:
	var t := TILE
	_make_wall(Rect2(0, 0, ROOM_W, t))
	_make_wall(Rect2(0, ROOM_H - t, ROOM_W, t))
	_make_wall(Rect2(0, 0, t, ROOM_H))
	_make_wall(Rect2(ROOM_W - t, 0, t, ROOM_H))

func _build_zone_dividers() -> void:
	var thin := 4
	# vertical dividers
	_make_wall(Rect2(ZONE_W - thin / 2.0, 0, thin, ROOM_H), ZONE_DIVIDER_COLOR, false)
	_make_wall(Rect2(2 * ZONE_W - thin / 2.0, 0, thin, ROOM_H), ZONE_DIVIDER_COLOR, false)
	# horizontal divider
	_make_wall(Rect2(0, ZONE_H - thin / 2.0, ROOM_W, thin), ZONE_DIVIDER_COLOR, false)

func _build_zone_labels() -> void:
	order_label = _build_zone_label(ZONE_ORDER, "ORDER")
	math_label = _build_zone_label(ZONE_MATH, "MATH")
	trap_label = _build_zone_label(ZONE_TRAP, "TRAP")
	echo_label = _build_zone_label(ZONE_ECHO, "ECHO")
	switches_label = _build_zone_label(ZONE_SWITCHES, "SWITCHES")

func _build_zone_label(zone: Rect2, title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.position = Vector2(zone.position.x + 12, zone.position.y + 8)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)
	return lbl

func _spawn_player() -> void:
	var packed: PackedScene = load(PLAYER_SCENE)
	player_node = packed.instantiate()
	player_node.position = ZONE_RESET.position + ZONE_RESET.size / 2.0 - Vector2(0, 60)
	add_child(player_node)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = ROOM_W
	cam.limit_bottom = ROOM_H
	cam.limit_smoothed = true
	cam.drag_horizontal_enabled = true
	cam.drag_vertical_enabled = true
	player_node.add_child(cam)

# --- Reset ---

func _build_reset_pad() -> void:
	var center := ZONE_RESET.position + ZONE_RESET.size / 2.0
	var area := Area2D.new()
	area.position = center
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	shape_node.shape = shape
	area.add_child(shape_node)
	var visual := ColorRect.new()
	visual.color = RESET_COLOR
	visual.position = Vector2(-16, -16)
	visual.size = Vector2(32, 32)
	area.add_child(visual)
	var lbl := Label.new()
	lbl.text = "[E] RESET ALL"
	lbl.position = Vector2(-40, -34)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	area.add_child(lbl)
	area.body_entered.connect(_on_reset_body_entered)
	area.body_exited.connect(_on_reset_body_exited)
	add_child(area)

	var hint := Label.new()
	hint.text = "PUZZLE TEST ZONE\nWalk to a quadrant to try a puzzle.\nReturn here and press E to reset all."
	hint.position = ZONE_RESET.position + Vector2(40, 40)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	add_child(hint)

func _on_reset_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		on_reset_pad = true

func _on_reset_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		on_reset_pad = false

func _reset_all_puzzles() -> void:
	for t in order_tiles: t.queue_free()
	for t in math_tiles: t.queue_free()
	for t in trap_tiles: t.queue_free()
	for t in echo_tiles: t.queue_free()
	for t in switches_tiles: t.queue_free()
	order_tiles.clear()
	math_tiles.clear()
	trap_tiles.clear()
	echo_tiles.clear()
	switches_tiles.clear()
	order_next_index = 0
	math_solved = false
	trap_greens_done = 0
	trap_solved = false
	echo_sequence.clear()
	echo_input_index = 0
	echo_demo_active = false
	echo_solved = false
	switches_done = 0
	switches_solved = false
	_build_all_puzzles()

func _build_all_puzzles() -> void:
	_build_order_zone()
	_build_math_zone()
	_build_trap_zone()
	_build_echo_zone()
	_build_switches_zone()

# --- Helpers ---

func _pick_tile_position(zone: Rect2, existing: Array) -> Vector2:
	var min_dist := 3 * TILE
	var inner := zone.grow(-ZONE_MARGIN)
	for i in 120:
		var x: int = rng.randi_range(int(inner.position.x), int(inner.end.x))
		var y: int = rng.randi_range(int(inner.position.y) + 24, int(inner.end.y))
		var p := Vector2(x, y)
		var clash := false
		for et in existing:
			if p.distance_to(et.position) < min_dist:
				clash = true
				break
		if clash:
			continue
		return p
	return zone.position + zone.size / 2.0

func _make_tile(pos: Vector2, color: Color, label_text: String, on_enter: Callable) -> Area2D:
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
		lbl.position = Vector2(-3, -8) if label_text.length() <= 1 else Vector2(-7, -8)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		area.add_child(lbl)
	area.body_entered.connect(on_enter.bind(area))
	return area

func _set_tile_color(tile: Node, color: Color) -> void:
	for child in tile.get_children():
		if child is ColorRect:
			(child as ColorRect).color = color
			return

func _set_solved_label(lbl: Label, title: String) -> void:
	lbl.text = "%s — SOLVED!" % title
	lbl.add_theme_color_override("font_color", SOLVED_LABEL_COLOR)

# --- Order ---

func _build_order_zone() -> void:
	var n := clampi(3 + (TEST_FLOOR - 1) / 13, 3, 8)
	for i in n:
		var pos := _pick_tile_position(ZONE_ORDER, order_tiles)
		var tile := _make_tile(pos, PUZZLE_TILE_COLOR, str(i + 1), _on_order_tile)
		tile.set_meta("number", i + 1)
		order_tiles.append(tile)
		add_child(tile)
	order_label.text = "ORDER — step 1..%d in order" % n
	order_label.add_theme_color_override("font_color", Color.WHITE)

func _on_order_tile(body: Node2D, tile: Area2D) -> void:
	if not body.has_method("player"):
		return
	var num: int = tile.get_meta("number")
	if num == order_next_index + 1:
		_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
		order_next_index = num
		if order_next_index >= order_tiles.size():
			_set_solved_label(order_label, "ORDER")
		else:
			order_label.text = "ORDER — next: %d / %d" % [order_next_index + 1, order_tiles.size()]
	else:
		order_next_index = 0
		for t in order_tiles:
			_set_tile_color(t, PUZZLE_TILE_COLOR)
		order_label.text = "ORDER — wrong! reset to 1"

# --- Math ---

func _build_math_zone() -> void:
	var a := rng.randi_range(1, 9)
	var b := rng.randi_range(1, 9)
	var op := "+"
	var op_kind := 0
	if TEST_FLOOR >= 30 and rng.randf() < 0.5:
		op_kind = 1
	if TEST_FLOOR >= 60 and rng.randf() < 0.4:
		op_kind = 2
	if TEST_FLOOR >= 50 and op_kind != 2:
		a = rng.randi_range(1, 20)
		b = rng.randi_range(1, 20)
	match op_kind:
		1:
			op = "-"
			if a < b:
				var t := a; a = b; b = t
			math_answer = a - b
		2:
			op = "x"
			a = rng.randi_range(2, 9)
			b = rng.randi_range(2, 9)
			math_answer = a * b
		_:
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
		var pos := _pick_tile_position(ZONE_MATH, math_tiles)
		var tile := _make_tile(pos, MATH_TILE_COLOR, str(n), _on_math_tile)
		tile.set_meta("value", n)
		math_tiles.append(tile)
		add_child(tile)
	math_label.text = "MATH — solve: %d %s %d = ?" % [a, op, b]
	math_label.add_theme_color_override("font_color", Color.WHITE)

func _on_math_tile(body: Node2D, tile: Area2D) -> void:
	if not body.has_method("player"):
		return
	if math_solved:
		return
	var v: int = tile.get_meta("value")
	if v == math_answer:
		_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
		math_solved = true
		_set_solved_label(math_label, "MATH")
	else:
		_set_tile_color(tile, MATH_WRONG_COLOR)
		math_label.text = "MATH — wrong! try another"

# --- Trap ---

func _build_trap_zone() -> void:
	var greens := clampi(3 + (TEST_FLOOR - 1) / 13, 3, 8)
	var reds := clampi(2 + (TEST_FLOOR - 1) / 25, 2, 6)
	trap_greens_total = greens
	trap_greens_done = 0
	for i in greens:
		var pos := _pick_tile_position(ZONE_TRAP, trap_tiles)
		var tile := _make_tile(pos, TRAP_GREEN_COLOR, "", _on_trap_tile)
		tile.set_meta("is_green", true)
		tile.set_meta("activated", false)
		trap_tiles.append(tile)
		add_child(tile)
	for i in reds:
		var pos := _pick_tile_position(ZONE_TRAP, trap_tiles)
		var tile := _make_tile(pos, TRAP_RED_COLOR, "", _on_trap_tile)
		tile.set_meta("is_green", false)
		trap_tiles.append(tile)
		add_child(tile)
	trap_label.text = "TRAP — step %d green, avoid %d red" % [greens, reds]
	trap_label.add_theme_color_override("font_color", Color.WHITE)

func _on_trap_tile(body: Node2D, tile: Area2D) -> void:
	if not body.has_method("player"):
		return
	if trap_solved:
		return
	var is_green: bool = tile.get_meta("is_green")
	if not is_green:
		trap_greens_done = 0
		for t in trap_tiles:
			if t.get_meta("is_green"):
				t.set_meta("activated", false)
				_set_tile_color(t, TRAP_GREEN_COLOR)
		trap_label.text = "TRAP — RED! reset (0/%d)" % trap_greens_total
		return
	var activated: bool = tile.get_meta("activated")
	if activated:
		return
	tile.set_meta("activated", true)
	_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
	trap_greens_done += 1
	if trap_greens_done >= trap_greens_total:
		trap_solved = true
		_set_solved_label(trap_label, "TRAP")
	else:
		trap_label.text = "TRAP — %d / %d greens" % [trap_greens_done, trap_greens_total]

# --- Echo ---

func _build_echo_zone() -> void:
	var seq_len := clampi(2 + (TEST_FLOOR - 1) / 20, 2, 6)
	var n := maxi(seq_len + 1, 4)
	for i in n:
		var pos := _pick_tile_position(ZONE_ECHO, echo_tiles)
		var tile := _make_tile(pos, ECHO_TILE_COLOR, "", _on_echo_tile)
		tile.set_meta("index", i)
		echo_tiles.append(tile)
		add_child(tile)
	echo_sequence.clear()
	for j in seq_len:
		echo_sequence.append(rng.randi_range(0, n - 1))
	echo_input_index = 0
	echo_label.text = "ECHO — watch the %d-step sequence..." % seq_len
	echo_label.add_theme_color_override("font_color", Color.WHITE)
	_play_echo_demo()

func _play_echo_demo() -> void:
	echo_demo_active = true
	echo_input_index = 0
	for t in echo_tiles:
		_set_tile_color(t, ECHO_TILE_COLOR)
	var tween := create_tween()
	tween.tween_interval(0.5)
	for seq_idx in echo_sequence:
		var tile: Area2D = echo_tiles[seq_idx]
		tween.tween_callback(_set_tile_color.bind(tile, ECHO_FLASH_COLOR))
		tween.tween_interval(0.4)
		tween.tween_callback(_set_tile_color.bind(tile, ECHO_TILE_COLOR))
		tween.tween_interval(0.2)
	tween.tween_callback(_finish_echo_demo)

func _finish_echo_demo() -> void:
	echo_demo_active = false
	if not echo_solved:
		echo_label.text = "ECHO — repeat: 1 / %d" % echo_sequence.size()

func _on_echo_tile(body: Node2D, tile: Area2D) -> void:
	if not body.has_method("player"):
		return
	if echo_solved:
		return
	if echo_demo_active:
		return
	var idx: int = tile.get_meta("index")
	if idx == echo_sequence[echo_input_index]:
		_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
		echo_input_index += 1
		if echo_input_index >= echo_sequence.size():
			echo_solved = true
			_set_solved_label(echo_label, "ECHO")
		else:
			echo_label.text = "ECHO — %d / %d" % [echo_input_index + 1, echo_sequence.size()]
	else:
		echo_label.text = "ECHO — wrong! replaying..."
		_play_echo_demo()

# --- Switches ---

func _build_switches_zone() -> void:
	var n := clampi(3 + (TEST_FLOOR - 1) / 13, 3, 8)
	switches_total = n
	switches_done = 0
	for i in n:
		var pos := _pick_tile_position(ZONE_SWITCHES, switches_tiles)
		var tile := _make_tile(pos, PUZZLE_TILE_COLOR, "", _on_switches_tile)
		tile.set_meta("activated", false)
		switches_tiles.append(tile)
		add_child(tile)
	switches_label.text = "SWITCHES — activate all %d (any order)" % n
	switches_label.add_theme_color_override("font_color", Color.WHITE)

func _on_switches_tile(body: Node2D, tile: Area2D) -> void:
	if not body.has_method("player"):
		return
	if switches_solved:
		return
	var activated: bool = tile.get_meta("activated")
	if activated:
		return
	tile.set_meta("activated", true)
	_set_tile_color(tile, PUZZLE_TILE_DONE_COLOR)
	switches_done += 1
	if switches_done >= switches_total:
		switches_solved = true
		_set_solved_label(switches_label, "SWITCHES")
	else:
		switches_label.text = "SWITCHES — %d / %d" % [switches_done, switches_total]
