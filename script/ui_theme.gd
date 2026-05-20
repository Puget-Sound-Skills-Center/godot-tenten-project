class_name UITheme
extends RefCounted
# Static design-token library for the MMORPG pixel-art UI.
# class_name makes every constant and static func available to any GDScript
# in the project without needing an autoload registration.

const FONT_PATH := "res://art/fonts/Daydream.ttf"

# ── Palette ────────────────────────────────────────────────────────────────
const C_OVERLAY     := Color(0.00, 0.00, 0.00, 0.74)
const C_PANEL_BG    := Color(0.07, 0.05, 0.02, 0.97)
const C_HEADER_BG   := Color(0.13, 0.09, 0.03, 1.00)
const C_BORDER      := Color(0.76, 0.62, 0.28, 1.00)
const C_BORDER_DIM  := Color(0.38, 0.28, 0.09, 1.00)
const C_DIVIDER     := Color(0.55, 0.44, 0.16, 0.65)
const C_TITLE       := Color(1.00, 0.86, 0.36, 1.00)
const C_TEXT        := Color(0.91, 0.86, 0.75, 1.00)
const C_HINT        := Color(0.54, 0.49, 0.39, 1.00)
const C_SUCCESS     := Color(0.36, 0.90, 0.46, 1.00)
const C_ERROR       := Color(0.92, 0.28, 0.22, 1.00)
const C_HP_BAR      := Color(0.80, 0.12, 0.10, 1.00)
const C_HP_BG       := Color(0.22, 0.06, 0.06, 1.00)
const C_GOLD        := Color(1.00, 0.82, 0.20, 1.00)
const C_BTN_NORMAL  := Color(0.11, 0.07, 0.02, 1.00)
const C_BTN_HOVER   := Color(0.23, 0.16, 0.05, 1.00)
const C_BTN_PRESS   := Color(0.33, 0.23, 0.08, 1.00)
const C_PORTRAIT_BG := Color(0.10, 0.10, 0.18, 1.00)

# ── Font (lazy-loaded static) ───────────────────────────────────────────────
static var _font: Font = null
static var _font_init: bool = false

static func _ensure_font() -> void:
	if _font_init:
		return
	_font_init = true
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

static func apply_font(node: Control, size: int = 10) -> void:
	_ensure_font()
	if _font != null:
		node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)

# ── StyleBoxes ─────────────────────────────────────────────────────────────

static func panel_style(bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = C_PANEL_BG
	s.border_width_left   = bw
	s.border_width_right  = bw
	s.border_width_top    = bw
	s.border_width_bottom = bw
	s.border_color = C_BORDER
	s.corner_radius_top_left     = 0
	s.corner_radius_top_right    = 0
	s.corner_radius_bottom_left  = 0
	s.corner_radius_bottom_right = 0
	s.shadow_color  = Color(0.0, 0.0, 0.0, 0.55)
	s.shadow_size   = 3
	s.shadow_offset = Vector2(2, 2)
	return s

static func _btn_base(bg: Color, border: Color, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = bg
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color = border
	s.corner_radius_top_left     = 0
	s.corner_radius_top_right    = 0
	s.corner_radius_bottom_left  = 0
	s.corner_radius_bottom_right = 0
	s.content_margin_left   = pad
	s.content_margin_right  = pad
	s.content_margin_top    = pad - 1
	s.content_margin_bottom = pad - 1
	return s

static func style_button(btn: Button, font_size: int = 10) -> void:
	btn.add_theme_stylebox_override("normal",   _btn_base(C_BTN_NORMAL, C_BORDER_DIM, 5))
	btn.add_theme_stylebox_override("hover",    _btn_base(C_BTN_HOVER,  C_BORDER,     5))
	btn.add_theme_stylebox_override("pressed",  _btn_base(C_BTN_PRESS,  C_TITLE,      5))
	btn.add_theme_stylebox_override("focus",    _btn_base(C_BTN_NORMAL, C_TITLE,      5))
	btn.add_theme_stylebox_override("disabled", _btn_base(Color(0.08, 0.06, 0.02, 0.6), C_BORDER_DIM, 5))
	btn.add_theme_color_override("font_color",          C_TEXT)
	btn.add_theme_color_override("font_hover_color",    C_TITLE)
	btn.add_theme_color_override("font_pressed_color",  C_TITLE)
	btn.add_theme_color_override("font_disabled_color", C_HINT)
	_ensure_font()
	if _font != null:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", font_size)

static func divider(w: float = 0.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = C_DIVIDER
	r.custom_minimum_size = Vector2(w, 1)
	return r
