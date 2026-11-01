class_name DigitalFighter
extends CharacterBody2D

signal health_changed(value: float)
signal defeated(fighter: DigitalFighter)

const GRAVITY := 2200.0
const FLOOR_Y := 604.0
const FRAME_IDLE_A := 0
const FRAME_IDLE_B := 1
const FRAME_WALK_FIRST := 2
const FRAME_CROUCH := 6
const FRAME_BLOCK := 7
const FRAME_JUMP := 8
const FRAME_APEX := 9
const FRAME_FALL := 10
const FRAME_LAND := 11
const FRAME_LIGHT := 12
const FRAME_HEAVY := 13
const FRAME_SPECIAL := 14
const FRAME_HURT := 15

var fighter_name := "Fighter"
var player_number := 1
var cpu_controlled := false
var max_health := 100.0
var health := 100.0
var walk_speed := 310.0
var jump_speed := -820.0
var acceleration := 70.0
var knockback_received_multiplier := 1.0
var damage_multiplier := 1.0
var defense_multiplier := 1.0
var opponent: DigitalFighter
var facing := 1.0

var _sprite: Sprite2D
var _frames: Array[AtlasTexture] = []
var _base_faces_right := true
var _animation_time := 0.0
var _attack_timer := 0.0
var _attack_total_duration := 0.0
var _attack_kind := ""
var _hit_stun := 0.0
var _land_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _taunt_timer := 0.0
var _attack_damage := 0.0
var _attack_reach := 0.0
var _attack_knockback := 0.0
var _attack_connected := false
var _special_cooldown := 0.0
var _cpu_think_timer := 0.0
var _cpu_direction := 0.0
var _cpu_attack := ""
var _cpu_dash := false
var _flash_timer := 0.0
var _is_blocking := false
var _knocked_down := false
var _crouching := false


func setup(name_text: String, number: int, texture: Texture2D, controlled_by_cpu: bool) -> void:
	fighter_name = name_text
	player_number = number
	cpu_controlled = controlled_by_cpu
	_base_faces_right = player_number == 1
	if player_number == 1:
		max_health = 120.0
		health = max_health
		walk_speed = 265.0
		jump_speed = -720.0
		acceleration = 44.0
		knockback_received_multiplier = 0.72
		damage_multiplier = 1.18
		defense_multiplier = 0.82
	else:
		max_health = 90.0
		health = max_health
		walk_speed = 365.0
		jump_speed = -940.0
		acceleration = 96.0
		knockback_received_multiplier = 1.12
		damage_multiplier = 0.92
		defense_multiplier = 1.08

	var cell_size := Vector2(texture.get_width() / 4.0, texture.get_height() / 4.0)
	for frame_index in range(16):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(
			(frame_index % 4) * cell_size.x,
			(frame_index / 4) * cell_size.y,
			cell_size.x,
			cell_size.y
		)
		_frames.append(frame)

	_sprite = Sprite2D.new()
	_sprite.texture = _frames[FRAME_IDLE_A]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var visual_scale := 0.70 if player_number == 1 else 0.76
	_sprite.scale = Vector2(visual_scale, visual_scale)
	_sprite.position = Vector2(0, -cell_size.y * visual_scale * 0.5)
	add_child(_sprite)
	var body_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(76, 158)
	body_shape.shape = rectangle
	body_shape.position = Vector2(0, -79)
	add_child(body_shape)
	collision_layer = 1
	collision_mask = 1
	position.y = FLOOR_Y


func _physics_process(delta: float) -> void:
	if not opponent:
		return
	var was_on_floor := is_on_floor()
	facing = sign(opponent.position.x - position.x)
	if facing == 0:
		facing = 1.0
	var should_face_right := facing > 0
	_sprite.flip_h = should_face_right != _base_faces_right
	_animation_time += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_stun = maxf(0.0, _hit_stun - delta)
	_land_timer = maxf(0.0, _land_timer - delta)
	_dash_timer = maxf(0.0, _dash_timer - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_taunt_timer = maxf(0.0, _taunt_timer - delta)
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	_flash_timer = maxf(0.0, _flash_timer - delta)
	_sprite.modulate = Color(1.0, 0.55, 0.55) if _flash_timer > 0 else Color.WHITE
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0:
		velocity.y = 0

	var move_axis := 0.0
	var wants_jump := false
	var wants_dash := false
	var requested_attack := ""
	_is_blocking = false
	_crouching = false
	if _hit_stun <= 0 and health > 0 and not _knocked_down:
		if cpu_controlled:
			_update_cpu(delta)
			move_axis = _cpu_direction
			requested_attack = _cpu_attack
			wants_dash = _cpu_dash
			_cpu_attack = ""
			_cpu_dash = false
		else:
			var prefix := "p%d_" % player_number
			move_axis = Input.get_axis(prefix + "left", prefix + "right")
			wants_jump = Input.is_action_just_pressed(prefix + "jump")
			wants_dash = Input.is_action_just_pressed(prefix + "dash")
			_crouching = Input.is_action_pressed(prefix + "crouch") and is_on_floor()
			_is_blocking = Input.is_action_pressed(prefix + "block") and _attack_timer <= 0
			if Input.is_action_just_pressed(prefix + "taunt") and _attack_timer <= 0:
				_taunt_timer = 0.8
			if Input.is_action_just_pressed(prefix + "light"):
				requested_attack = "light"
			elif Input.is_action_just_pressed(prefix + "heavy"):
				requested_attack = "heavy"
			elif Input.is_action_just_pressed(prefix + "special"):
				requested_attack = "special"

	if wants_dash and _dash_cooldown <= 0 and is_on_floor():
		_dash_timer = 0.18
		_dash_cooldown = 0.72
	if _attack_timer > 0 or _is_blocking or _crouching or _taunt_timer > 0:
		move_axis *= 0.22
	if _dash_timer > 0:
		velocity.x = facing * walk_speed * (2.25 if player_number == 1 else 2.65)
	else:
		velocity.x = move_toward(velocity.x, move_axis * walk_speed, acceleration)
	if wants_jump and is_on_floor() and _attack_timer <= 0 and not _crouching:
		velocity.y = jump_speed
	if requested_attack != "" and _attack_timer <= 0 and _taunt_timer <= 0:
		_start_attack(requested_attack)
	_process_attack_hit()
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_land_timer = 0.16 if player_number == 2 else 0.24
	position.x = clampf(position.x, 70.0, 1210.0)
	_update_visual()


func _start_attack(kind: String) -> void:
	_attack_connected = false
	_attack_kind = kind
	match kind:
		"light":
			_attack_timer = 0.32 if player_number == 2 else 0.38
			_attack_damage = 7.0 * damage_multiplier
			_attack_reach = 112.0
			_attack_knockback = 260.0
		"heavy":
			_attack_timer = 0.45 if player_number == 2 else 0.56
			_attack_damage = 12.0 * damage_multiplier
			_attack_reach = 142.0
			_attack_knockback = 390.0
		"special":
			if _special_cooldown > 0:
				_attack_kind = ""
				return
			_attack_timer = 0.62 if player_number == 2 else 0.74
			_attack_damage = 18.0 * damage_multiplier
			_attack_reach = 245.0
			_attack_knockback = 540.0
			_special_cooldown = 1.8
	_attack_total_duration = _attack_timer


func _process_attack_hit() -> void:
	if _attack_timer <= 0 or _attack_connected or not opponent or opponent.health <= 0:
		return
	if absf(opponent.position.x - position.x) <= _attack_reach and absf(opponent.position.y - position.y) < 135:
		_attack_connected = true
		opponent.take_damage(_attack_damage, facing, _attack_knockback, _attack_kind)


func take_damage(amount: float, hit_direction: float, knockback: float, attack_kind := "light") -> void:
	if health <= 0:
		return
	var applied_damage := amount * defense_multiplier * (0.25 if _is_blocking else 1.0)
	health = maxf(0.0, health - applied_damage)
	velocity.x = hit_direction * knockback * knockback_received_multiplier * (0.35 if _is_blocking else 1.0)
	_hit_stun = 0.12 if _is_blocking else (0.38 if attack_kind == "special" else 0.28)
	_flash_timer = 0.13
	_set_frame(FRAME_HURT)
	health_changed.emit(health / max_health * 100.0)
	if health <= 0:
		_knocked_down = true
		rotation = hit_direction * 1.35
		defeated.emit(self)


func play_victory() -> void:
	_attack_timer = 0
	_taunt_timer = 10.0
	_set_frame(FRAME_IDLE_B)


func reset_fighter(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	rotation = 0
	health = max_health
	_attack_timer = 0
	_hit_stun = 0
	_dash_timer = 0
	_taunt_timer = 0
	_special_cooldown = 0
	_knocked_down = false
	_set_frame(FRAME_IDLE_A)
	health_changed.emit(100.0)


func _update_cpu(delta: float) -> void:
	_cpu_think_timer -= delta
	if _cpu_think_timer > 0:
		return
	_cpu_think_timer = randf_range(0.10, 0.22)
	var distance := absf(opponent.position.x - position.x)
	if distance > 210:
		_cpu_direction = sign(opponent.position.x - position.x)
		if distance > 420 and _dash_cooldown <= 0 and randf() < 0.18:
			_cpu_dash = true
	elif distance < 92:
		_cpu_direction = -sign(opponent.position.x - position.x) if randf() < 0.35 else 0.0
	else:
		_cpu_direction = 0.0
	if distance < 125 and randf() < 0.42:
		_cpu_attack = "light" if randf() < 0.65 else "heavy"
	elif distance < 245 and _special_cooldown <= 0 and randf() < 0.18:
		_cpu_attack = "special"


func _update_visual() -> void:
	_sprite.position.x = 0
	_sprite.rotation = 0
	if _knocked_down:
		_set_frame(FRAME_HURT)
		return
	if _hit_stun > 0:
		_set_frame(FRAME_HURT)
		return
	if _attack_timer > 0:
		var attack_progress := 1.0 - _attack_timer / maxf(_attack_total_duration, 0.001)
		match _attack_kind:
			"light":
				if attack_progress < 0.20:
					_set_frame(FRAME_IDLE_B)
				elif attack_progress < 0.70:
					_set_frame(FRAME_LIGHT)
					_sprite.position.x = facing * 8.0
				else:
					_set_frame(FRAME_IDLE_A)
			"heavy":
				if attack_progress < 0.26:
					_set_frame(FRAME_CROUCH)
				elif attack_progress < 0.72:
					_set_frame(FRAME_HEAVY)
					_sprite.position.x = facing * 12.0
				else:
					_set_frame(FRAME_LAND)
			"special":
				if attack_progress < 0.30:
					_set_frame(FRAME_BLOCK)
				elif attack_progress < 0.80:
					_set_frame(FRAME_SPECIAL if player_number == 1 else FRAME_LIGHT)
					_sprite.position.x = -facing * 4.0
				else:
					_set_frame(FRAME_IDLE_B)
		return
	if _is_blocking:
		_set_frame(FRAME_BLOCK)
		_sprite.modulate = Color(0.72, 0.86, 1.0)
		return
	if _crouching:
		_set_frame(FRAME_CROUCH)
		return
	if not is_on_floor():
		if velocity.y < -180:
			_set_frame(FRAME_JUMP)
		elif velocity.y < 180:
			_set_frame(FRAME_APEX)
		else:
			_set_frame(FRAME_FALL)
		return
	if _land_timer > 0:
		_set_frame(FRAME_LAND)
		return
	if _taunt_timer > 0:
		_set_frame(FRAME_IDLE_B if int(_animation_time * 7.0) % 2 == 0 else FRAME_BLOCK)
		return
	if _dash_timer > 0 or absf(velocity.x) > 35:
		var rate := 15.0 if _dash_timer > 0 else (10.0 if player_number == 2 else 7.0)
		_set_frame(FRAME_WALK_FIRST + int(_animation_time * rate) % 4)
		return
	_set_frame(FRAME_IDLE_A if int(_animation_time * 3.0) % 2 == 0 else FRAME_IDLE_B)


func _set_frame(frame_index: int) -> void:
	if _sprite and frame_index >= 0 and frame_index < _frames.size():
		_sprite.texture = _frames[frame_index]


func current_frame_index() -> int:
	if not _sprite:
		return -1
	return _frames.find(_sprite.texture)
