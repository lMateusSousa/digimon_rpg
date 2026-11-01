class_name DigitalFighter
extends CharacterBody2D

signal health_changed(value: float)
signal defeated(fighter: DigitalFighter)

const GRAVITY := 2200.0
const FLOOR_Y := 604.0

var fighter_name := "Fighter"
var player_number := 1
var cpu_controlled := false
var max_health := 100.0
var health := 100.0
var walk_speed := 310.0
var jump_speed := -820.0
var damage_multiplier := 1.0
var defense_multiplier := 1.0
var opponent: DigitalFighter
var facing := 1.0

var _sprite: Sprite2D
var _idle_texture: AtlasTexture
var _attack_texture: AtlasTexture
var _attack_timer := 0.0
var _hit_stun := 0.0
var _attack_damage := 0.0
var _attack_reach := 0.0
var _attack_knockback := 0.0
var _attack_connected := false
var _special_cooldown := 0.0
var _cpu_think_timer := 0.0
var _cpu_direction := 0.0
var _cpu_attack := ""
var _flash_timer := 0.0
var _is_blocking := false


func setup(name_text: String, number: int, texture: Texture2D, controlled_by_cpu: bool) -> void:
	fighter_name = name_text
	player_number = number
	cpu_controlled = controlled_by_cpu
	if player_number == 1:
		max_health = 120.0
		health = max_health
		walk_speed = 265.0
		jump_speed = -720.0
		damage_multiplier = 1.18
		defense_multiplier = 0.82
	else:
		max_health = 90.0
		health = max_health
		walk_speed = 365.0
		jump_speed = -940.0
		damage_multiplier = 0.92
		defense_multiplier = 1.08
	_idle_texture = AtlasTexture.new()
	_idle_texture.atlas = texture
	_idle_texture.region = Rect2(0, 0, 64, 64)
	_attack_texture = AtlasTexture.new()
	_attack_texture.atlas = texture
	_attack_texture.region = Rect2(64, 0, 64, 64)
	_sprite = Sprite2D.new()
	_sprite.texture = _idle_texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(3.0, 3.0)
	_sprite.position = Vector2(0, -91)
	add_child(_sprite)
	var body_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(72, 154)
	body_shape.shape = rectangle
	body_shape.position = Vector2(0, -77)
	add_child(body_shape)
	collision_layer = 1
	collision_mask = 1
	position.y = FLOOR_Y


func _physics_process(delta: float) -> void:
	if not opponent:
		return
	facing = sign(opponent.position.x - position.x)
	if facing == 0:
		facing = 1.0
	_sprite.flip_h = facing < 0
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_stun = maxf(0.0, _hit_stun - delta)
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	_flash_timer = maxf(0.0, _flash_timer - delta)
	_sprite.modulate = Color(1.0, 0.55, 0.55) if _flash_timer > 0 else Color.WHITE
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0:
		velocity.y = 0
	var move_axis := 0.0
	var wants_jump := false
	var requested_attack := ""
	_is_blocking = false
	if _hit_stun <= 0 and health > 0:
		if cpu_controlled:
			_update_cpu(delta)
			move_axis = _cpu_direction
			requested_attack = _cpu_attack
			_cpu_attack = ""
		else:
			var prefix := "p%d_" % player_number
			move_axis = Input.get_axis(prefix + "left", prefix + "right")
			wants_jump = Input.is_action_just_pressed(prefix + "jump")
			_is_blocking = Input.is_action_pressed(prefix + "block") and _attack_timer <= 0
			if Input.is_action_just_pressed(prefix + "light"):
				requested_attack = "light"
			elif Input.is_action_just_pressed(prefix + "heavy"):
				requested_attack = "heavy"
			elif Input.is_action_just_pressed(prefix + "special"):
				requested_attack = "special"
	if _attack_timer > 0 or _is_blocking:
		move_axis *= 0.25
	velocity.x = move_toward(velocity.x, move_axis * walk_speed, 70.0)
	if wants_jump and is_on_floor() and _attack_timer <= 0:
		velocity.y = jump_speed
	if requested_attack != "" and _attack_timer <= 0:
		_start_attack(requested_attack)
	_process_attack_hit()
	_update_visual()
	move_and_slide()
	position.x = clampf(position.x, 70.0, 1210.0)


func _start_attack(kind: String) -> void:
	_attack_connected = false
	match kind:
		"light":
			_attack_timer = 0.32
			_attack_damage = 7.0 * damage_multiplier
			_attack_reach = 112.0
			_attack_knockback = 260.0
		"heavy":
			_attack_timer = 0.48
			_attack_damage = 12.0 * damage_multiplier
			_attack_reach = 142.0
			_attack_knockback = 390.0
		"special":
			if _special_cooldown > 0:
				return
			_attack_timer = 0.68
			_attack_damage = 18.0 * damage_multiplier
			_attack_reach = 230.0
			_attack_knockback = 520.0
			_special_cooldown = 1.8


func _process_attack_hit() -> void:
	if _attack_timer <= 0 or _attack_connected or not opponent or opponent.health <= 0:
		return
	if absf(opponent.position.x - position.x) <= _attack_reach and absf(opponent.position.y - position.y) < 125:
		_attack_connected = true
		opponent.take_damage(_attack_damage, facing, _attack_knockback)


func take_damage(amount: float, hit_direction: float, knockback: float) -> void:
	if health <= 0:
		return
	var applied_damage := amount * defense_multiplier * (0.25 if _is_blocking else 1.0)
	health = maxf(0.0, health - applied_damage)
	velocity.x = hit_direction * knockback * (0.35 if _is_blocking else 1.0)
	_hit_stun = 0.12 if _is_blocking else 0.28
	_flash_timer = 0.13
	health_changed.emit(health / max_health * 100.0)
	if health <= 0:
		defeated.emit(self)


func reset_fighter(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	health = max_health
	_attack_timer = 0
	_hit_stun = 0
	_special_cooldown = 0
	health_changed.emit(100.0)


func _update_cpu(delta: float) -> void:
	_cpu_think_timer -= delta
	if _cpu_think_timer > 0:
		return
	_cpu_think_timer = randf_range(0.10, 0.22)
	var distance := absf(opponent.position.x - position.x)
	if distance > 190:
		_cpu_direction = sign(opponent.position.x - position.x)
	elif distance < 92:
		_cpu_direction = -sign(opponent.position.x - position.x) if randf() < 0.35 else 0.0
	else:
		_cpu_direction = 0.0
	if distance < 125 and randf() < 0.42:
		_cpu_attack = "light" if randf() < 0.65 else "heavy"
	elif distance < 230 and _special_cooldown <= 0 and randf() < 0.18:
		_cpu_attack = "special"


func _update_visual() -> void:
	_sprite.texture = _attack_texture if _attack_timer > 0 else _idle_texture
	if _is_blocking:
		_sprite.modulate = Color(0.65, 0.82, 1.0)
	var crouching := not cpu_controlled and Input.is_action_pressed("p%d_crouch" % player_number)
	_sprite.position.y = -76 if crouching else -91
