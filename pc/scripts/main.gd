extends Node2D

const Fighter := preload("res://scripts/fighter.gd")
const HUDScript := preload("res://scripts/hud.gd")

var red: DigitalFighter
var blue: DigitalFighter
var hud: FightHUD
var red_rounds := 0
var blue_rounds := 0
var round_number := 1
var round_over := false
var reset_timer := 0.0
var cpu_enabled := true
var _f2_down := false


func _ready() -> void:
	randomize()
	var floor_body := StaticBody2D.new()
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(1280, 40)
	floor_collision.shape = floor_shape
	floor_body.position = Vector2(640, 624)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 1
	floor_body.add_child(floor_collision)
	add_child(floor_body)
	red = Fighter.new()
	red.setup("Herói Vermelho", 1, load("res://assets/heroi_vermelho_battle.png"), false)
	red.position = Vector2(360, 604)
	add_child(red)
	blue = Fighter.new()
	blue.setup("Herói Azul", 2, load("res://assets/heroi_azul_battle.png"), true)
	blue.position = Vector2(920, 604)
	add_child(blue)
	red.opponent = blue
	blue.opponent = red
	red.health_changed.connect(_on_health_changed.bind(1))
	blue.health_changed.connect(_on_health_changed.bind(2))
	red.defeated.connect(_on_fighter_defeated)
	blue.defeated.connect(_on_fighter_defeated)
	hud = HUDScript.new()
	add_child(hud)
	hud.set_message("ROUND 1 — LUTEM!")
	queue_redraw()


func _process(delta: float) -> void:
	var f2_pressed := Input.is_key_pressed(KEY_F2)
	if f2_pressed and not _f2_down:
		cpu_enabled = not cpu_enabled
		blue.cpu_controlled = cpu_enabled
		hud.set_cpu_enabled(cpu_enabled)
	_f2_down = f2_pressed
	if round_over:
		reset_timer -= delta
		if reset_timer <= 0:
			_start_next_round()


func _draw() -> void:
	for band in range(12):
		var color := Color("11152e").lerp(Color("6b275c"), float(band) / 11.0)
		draw_rect(Rect2(0, band * 45, 1280, 48), color, true)
	draw_circle(Vector2(1040, 145), 82, Color("f6d48c"))
	draw_circle(Vector2(1012, 124), 15, Color("d8b87c"))
	draw_circle(Vector2(1070, 172), 22, Color("d8b87c"))
	for x in range(0, 1280, 85):
		var height := 80 + (x * 37) % 150
		draw_rect(Rect2(x, 530 - height, 70, height), Color("171428"), true)
		for light_y in range(int(500 - height), 500, 28):
			var light_color := Color("49d9ff") if (x + light_y) % 3 == 0 else Color("ff557f")
			draw_rect(Rect2(x + 12, light_y, 8, 12), light_color, true)
	draw_rect(Rect2(0, 530, 1280, 190), Color("1d1a28"), true)
	draw_rect(Rect2(0, 530, 1280, 8), Color("ffd06a"), true)
	for x in range(-200, 1400, 90):
		draw_line(Vector2(x, 720), Vector2(x + 220, 530), Color("343047"), 2)
	for y in range(560, 720, 38):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("343047"), 2)


func _on_health_changed(value: float, player: int) -> void:
	hud.set_health(player, value)


func _on_fighter_defeated(loser: DigitalFighter) -> void:
	if round_over:
		return
	round_over = true
	reset_timer = 2.4
	red.set_physics_process(false)
	blue.set_physics_process(false)
	if loser == blue:
		red_rounds += 1
		hud.set_message("HERÓI VERMELHO VENCEU!")
	else:
		blue_rounds += 1
		hud.set_message("HERÓI AZUL VENCEU!")
	hud.set_rounds(red_rounds, blue_rounds)


func _start_next_round() -> void:
	if red_rounds >= 2 or blue_rounds >= 2:
		var champion := "HERÓI VERMELHO" if red_rounds > blue_rounds else "HERÓI AZUL"
		red_rounds = 0
		blue_rounds = 0
		round_number = 1
		hud.set_message(champion + " É O CAMPEÃO! NOVA PARTIDA")
	else:
		round_number += 1
		hud.set_message("ROUND %d — LUTEM!" % round_number)
	hud.set_rounds(red_rounds, blue_rounds)
	red.reset_fighter(Vector2(360, 604))
	blue.reset_fighter(Vector2(920, 604))
	red.set_physics_process(true)
	blue.set_physics_process(true)
	round_over = false
