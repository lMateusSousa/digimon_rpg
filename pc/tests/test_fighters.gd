extends SceneTree

var failures: Array[String] = []
var passed := 0


func _init() -> void:
	print("Iniciando testes dos dois lutadores...")
	call_deferred("_run_tests")


func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _wait_physics(frames: int) -> void:
	for frame in range(frames):
		await physics_frame


func _tap_action(action: String, frames := 1) -> void:
	Input.action_press(action)
	await _wait_physics(frames)
	Input.action_release(action)
	await _wait_physics(1)


func _run_tests() -> void:
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await _wait_physics(5)
	var red: DigitalFighter = arena.red
	var blue: DigitalFighter = arena.blue
	blue.cpu_controlled = false
	_expect(red._frames.size() == 16 and blue._frames.size() == 16, "Os dois usam 16 quadros extraídos dos guias originais")
	_expect(red.walk_speed < blue.walk_speed, "Vermelho é mais lento que o Azul")
	_expect(absf(red.jump_speed) < absf(blue.jump_speed), "Vermelho pula menos que o Azul")
	_expect(red.knockback_received_multiplier < blue.knockback_received_multiplier, "Vermelho aguenta mais recuo")

	_expect(red.current_frame_index() in [0, 1, 11], "Vermelho entra em idle/aterrissagem")
	_expect(blue.current_frame_index() in [0, 1, 11], "Azul entra em idle/aterrissagem")

	var red_start_x := red.position.x
	Input.action_press("p1_right")
	await _wait_physics(18)
	_expect(red.position.x > red_start_x, "Vermelho caminha para a direita")
	_expect(red.current_frame_index() in [2, 3, 4, 5], "Vermelho usa quadros de caminhada")
	Input.action_release("p1_right")

	var blue_start_x := blue.position.x
	Input.action_press("p2_left")
	await _wait_physics(18)
	_expect(blue.position.x < blue_start_x, "Azul caminha para a esquerda")
	_expect(blue.current_frame_index() in [2, 3, 4, 5], "Azul usa quadros de caminhada")
	Input.action_release("p2_left")

	red.reset_fighter(Vector2(360, 604))
	blue.reset_fighter(Vector2(920, 604))
	await _wait_physics(3)
	await _tap_action("p1_jump")
	_expect(red.position.y < 604 and red.current_frame_index() in [8, 9, 10], "Vermelho pula com animação aérea")
	red.reset_fighter(Vector2(360, 604))
	blue.reset_fighter(Vector2(920, 604))
	await _wait_physics(3)
	await _tap_action("p2_jump")
	_expect(blue.position.y < 604 and blue.current_frame_index() in [8, 9, 10], "Azul pula com animação aérea")

	red.reset_fighter(Vector2(360, 604))
	blue.reset_fighter(Vector2(920, 604))
	await _wait_physics(3)
	Input.action_press("p1_crouch")
	await _wait_physics(2)
	_expect(red.current_frame_index() == 6, "Vermelho agacha")
	Input.action_release("p1_crouch")
	Input.action_press("p2_block")
	await _wait_physics(2)
	_expect(blue.current_frame_index() == 7, "Azul bloqueia")
	Input.action_release("p2_block")

	var dash_start := red.position.x
	await _tap_action("p1_dash", 3)
	_expect(red.position.x - dash_start > 15, "Vermelho executa corrida curta/dash")
	dash_start = blue.position.x
	await _tap_action("p2_dash", 3)
	_expect(dash_start - blue.position.x > 15, "Azul executa dash rápido")

	red.reset_fighter(Vector2(500, 604))
	blue.reset_fighter(Vector2(590, 604))
	await _wait_physics(3)
	var blue_health_before := blue.health
	red._start_attack("light")
	red._attack_timer = red._attack_total_duration * 0.55
	red._process_attack_hit()
	red._update_visual()
	_expect(red.current_frame_index() == 12, "Vermelho mostra ataque leve")
	_expect(blue.health < blue_health_before, "Ataque leve vermelho causa dano")

	red.reset_fighter(Vector2(500, 604))
	blue.reset_fighter(Vector2(590, 604))
	var red_health_before := red.health
	blue._start_attack("heavy")
	blue._attack_timer = blue._attack_total_duration * 0.55
	blue._process_attack_hit()
	blue._update_visual()
	_expect(blue.current_frame_index() == 13, "Azul mostra combo pesado")
	_expect(red.health < red_health_before, "Combo azul causa dano")

	red.reset_fighter(Vector2(450, 604))
	blue.reset_fighter(Vector2(650, 604))
	blue_health_before = blue.health
	red._start_attack("special")
	red._attack_timer = red._attack_total_duration * 0.55
	red._process_attack_hit()
	red._update_visual()
	_expect(red.current_frame_index() == 14, "Vermelho usa especial de fogo")
	_expect(blue.health < blue_health_before, "Especial de fogo alcança o adversário")

	red.reset_fighter(Vector2(450, 604))
	blue.reset_fighter(Vector2(650, 604))
	red_health_before = red.health
	blue._start_attack("special")
	blue._attack_timer = blue._attack_total_duration * 0.55
	blue._process_attack_hit()
	blue._update_visual()
	_expect(blue.current_frame_index() == 12, "Azul usa especial de gelo pelas mãos")
	_expect(red.health < red_health_before, "Especial de gelo alcança o adversário")

	blue.reset_fighter(Vector2(590, 604))
	blue._is_blocking = true
	blue_health_before = blue.health
	red._attack_connected = false
	red._start_attack("heavy")
	red._process_attack_hit()
	var blocked_damage := blue_health_before - blue.health
	_expect(blocked_damage > 0 and blocked_damage < 5, "Bloqueio reduz o dano")

	red.reset_fighter(Vector2(500, 604))
	blue.reset_fighter(Vector2(700, 604))
	await _wait_physics(3)
	await _tap_action("p1_taunt")
	_expect(red._taunt_timer > 0, "Vermelho executa provocação")
	await _tap_action("p2_taunt")
	_expect(blue._taunt_timer > 0, "Azul executa provocação")

	print("TESTES: %d aprovados, %d falhas" % [passed, failures.size()])
	quit(0 if failures.is_empty() else 1)
