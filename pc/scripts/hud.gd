class_name FightHUD
extends Control

var red_health := 100.0
var blue_health := 100.0
var red_rounds := 0
var blue_rounds := 0
var message := "ROUND 1"
var cpu_enabled := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	draw_rect(Rect2(54, 42, 500, 36), Color("201b2c"), true)
	draw_rect(Rect2(726, 42, 500, 36), Color("201b2c"), true)
	draw_rect(Rect2(60, 48, 488 * red_health / 100.0, 24), Color("ff4b3e"), true)
	var blue_width := 488 * blue_health / 100.0
	draw_rect(Rect2(1220 - blue_width, 48, blue_width, 24), Color("32b7ff"), true)
	draw_rect(Rect2(54, 42, 500, 36), Color("fff4d2"), false, 3)
	draw_rect(Rect2(726, 42, 500, 36), Color("fff4d2"), false, 3)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(58, 34), "HERÓI VERMELHO", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(1222, 34), "HERÓI AZUL", HORIZONTAL_ALIGNMENT_RIGHT, 500, 22, Color.WHITE)
	draw_string(font, Vector2(560, 70), "%d - %d" % [red_rounds, blue_rounds], HORIZONTAL_ALIGNMENT_CENTER, 160, 28, Color("fff4d2"))
	draw_string(font, Vector2(390, 118), message, HORIZONTAL_ALIGNMENT_CENTER, 500, 30, Color.WHITE)
	draw_string(font, Vector2(22, 694), "P1: A/D mover  W pular  F soco  G golpe  H especial  R defender", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e9e2ff"))
	var mode_text := "F2: CPU ligada" if cpu_enabled else "F2: 2 jogadores | P2: setas + J/K/L/I"
	draw_string(font, Vector2(638, 694), mode_text, HORIZONTAL_ALIGNMENT_RIGHT, 620, 18, Color("e9e2ff"))


func set_health(player: int, value: float) -> void:
	if player == 1:
		red_health = value
	else:
		blue_health = value
	queue_redraw()


func set_rounds(red: int, blue: int) -> void:
	red_rounds = red
	blue_rounds = blue
	queue_redraw()


func set_message(value: String) -> void:
	message = value
	queue_redraw()


func set_cpu_enabled(value: bool) -> void:
	cpu_enabled = value
	queue_redraw()
