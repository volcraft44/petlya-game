extends CharacterBody2D
# Future Self boss — knows all your moves, multiple phases
# "Я знаю тебя лучше, чем ты сам."

signal defeated

var player: CharacterBody2D = null
var health: int = 850
var max_health: int = 850
var damage: int = 16
var speed: float = 190.0
var throw_dash_dir: Vector2 = Vector2.RIGHT
var gravity_val: float = 650.0
var facing_right: bool = false
var is_dead: bool = false
var death_timer: float = 0.0

# AI state
enum State { IDLE, CHASE, ATTACK, DODGE, JUMP_ATTACK, DASH_STRIKE, COUNTER, TAUNT, THROW_SWORD, MEGA_STRIKE, STUN_RECOVER, THROW_DASH, THROW_DASH_LUNGE }
var state: int = State.IDLE
var state_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var combo_count: int = 0
var dodge_cooldown: float = 0.0
var jump_attack_landed: bool = false

# Phase system
var phase: int = 1
var phase_scale: float = 1.0  # grows bigger in phase 2+
var target_phase_scale: float = 1.0

# Counter system
var counter_window: float = 0.0

# Dash strike
var dash_target: Vector2 = Vector2.ZERO

# Throw sword
var throw_cooldown: float = 0.0

# MEGA STRIKE — sword grows huge, stuns on hit
var mega_strike_cooldown: float = 0.0
var mega_strike_charge: float = 0.0  # 0-1 charge animation
var mega_sword_length: float = 0.0  # grows during charge
var mega_hit: bool = false

# Stun on player
var player_stun_timer: float = 0.0

# Visual
var hit_flash: float = 0.0
var body_anim: float = 0.0

# Sprite animation
var sprite: Sprite2D = null
var walk_textures: Array = []
var swing_textures: Array = []
var jump_textures: Array = []
var current_frame: int = 0
var frame_timer: float = 0.0
var frame_speed: float = 12.0
var sprite_scale_val: float = 0.22
var current_anim: String = "walk"

# Pending shot animation
var pending_shot: bool = false
var pending_shot_timer: float = 0.0
var shot_delay: float = 0.4

# Taunt
var taunts_phase1: Array = [
	"Я знаю каждый твой удар.",
	"Ты предсказуем.",
]
var taunts_phase2: Array = [
	"Ты думал это всё? Я только начинаю.",
]
var taunts_phase3: Array = [
	"Я — ЭТО ТЫ. Через тысячу петель. Я СОВЕРШЕНСТВО.",
]
var current_taunt: String = ""
var taunt_display_timer: float = 0.0
var taunted_phase2: bool = false
var taunted_phase3: bool = false

var projectile_script = preload("res://scripts/projectile.gd")
var attack_hit_this_swing: bool = false

# === ДВИЖЕНИЕ ОКНА ОС (финальный босс) ===
var _win_origin:     Vector2i = Vector2i.ZERO
var _win_offset:     Vector2  = Vector2.ZERO
var _win_target:     Vector2  = Vector2.ZERO
var _win_return_cd:  float    = 0.0
var _win_drift_cd:   float    = 2.5
var _win_ready:      bool     = false
var _win_death:      bool     = false
var _prev_state:     int      = -1
var _win_mega_done:  bool     = false   # чтобы не шейкать mega дважды

func _win_init() -> void:
	if not _win_ready:
		_win_origin = DisplayServer.window_get_position()
		_win_ready  = true

func _win_push(dir: Vector2, intensity: float, hold: float = 0.5) -> void:
	var new_t = dir.normalized() * intensity
	# Не перебиваем более сильный толчок
	if new_t.length() < _win_target.length() * 0.55:
		return
	_win_target    = new_t
	_win_return_cd = hold

func _win_clamp(pos: Vector2i) -> Vector2i:
	# Не даём окну уйти дальше MAX_OFFSET пикселей от стартовой позиции
	# Так окно никогда не улетит на другой монитор
	var MAX_OFFSET = 90
	pos.x = clampi(pos.x, _win_origin.x - MAX_OFFSET, _win_origin.x + MAX_OFFSET)
	pos.y = clampi(pos.y, _win_origin.y - MAX_OFFSET, _win_origin.y + MAX_OFFSET)
	return pos

func _win_update(delta: float) -> void:
	if not _win_ready:
		return
	# Death — случайная тряска
	if _win_death:
		DisplayServer.window_set_position(_win_clamp(
			_win_origin + Vector2i(randi_range(-55, 55), randi_range(-55, 55))
		))
		return
	if _win_return_cd > 0.0:
		_win_return_cd -= delta
		if _win_return_cd <= 0.0:
			_win_target = Vector2.ZERO
	_win_offset = _win_offset.lerp(_win_target, 1.0 - exp(-9.0 * delta))
	DisplayServer.window_set_position(_win_clamp(
		_win_origin + Vector2i(int(_win_offset.x), int(_win_offset.y))
	))

func _ready():
	collision_layer = 2
	collision_mask = 4 | 8

	var shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 6
	capsule.height = 24
	shape.shape = capsule
	shape.position = Vector2(0, -12)
	add_child(shape)

	_load_textures()

	sprite = Sprite2D.new()
	sprite.position = Vector2(0, -12)
	sprite.scale = Vector2(sprite_scale_val, sprite_scale_val)
	add_child(sprite)
	if walk_textures.size() > 0:
		sprite.texture = walk_textures[0]

func _load_textures():
	for i in 12:
		var tex = _try_load("res://sprites/future_walk_clean/frame_%02d.png" % i)
		if tex:
			walk_textures.append(tex)
	for i in 15:
		var tex = _try_load("res://sprites/future_swing_clean/frame_%02d.png" % i)
		if tex:
			swing_textures.append(tex)
	for i in 12:
		var tex = _try_load("res://sprites/future_jump_clean/frame_%02d.png" % i)
		if tex:
			jump_textures.append(tex)

func _try_load(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		return load(res_path)
	var img = Image.new()
	var abs_path = ProjectSettings.globalize_path(res_path)
	if img.load(abs_path) == OK:
		return ImageTexture.create_from_image(img)
	return null

func setup(p_player: CharacterBody2D):
	player = p_player
	_win_init()
	# Dramatic entrance — boss stands still and taunts
	state = State.TAUNT
	state_timer = 3.0
	current_taunt = "Привет... это снова я. Вернее — ты."
	taunt_display_timer = 4.0

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO):
	if is_dead:
		return

	# During mega strike charge, reduced damage
	if state == State.MEGA_STRIKE and mega_strike_charge < 0.8:
		amount = int(amount * 0.5)

	# Phase 2+: chance to counter
	if phase >= 2 and state != State.DODGE and state != State.MEGA_STRIKE and randf() < 0.12:
		state = State.COUNTER
		state_timer = 0.5
		velocity = knockback_dir * -180
		velocity.y = -120
		current_taunt = "Предсказуемо!"
		taunt_display_timer = 1.5
		return

	health -= amount
	hit_flash = 0.2
	velocity += knockback_dir * 50

	var old_phase = phase
	if health < max_health * 0.3:
		phase = 3
	elif health < max_health * 0.6:
		phase = 2

	# Phase transitions — dramatic pause + quote + power up
	if phase == 2 and not taunted_phase2:
		taunted_phase2 = true
		target_phase_scale = 1.2
		damage = 16
		speed = 165.0
		state = State.TAUNT
		state_timer = 2.5  # Long dramatic pause
		current_taunt = "Ты думал это всё? Я только начинаю."
		taunt_display_timer = 4.0
		velocity = Vector2.ZERO
		# Фаза 2 — окно резко толкает в случайную сторону
		_win_push(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized(), 60.0, 0.7)
	elif phase == 3 and not taunted_phase3:
		taunted_phase3 = true
		target_phase_scale = 1.35
		damage = 22
		speed = 185.0
		state = State.TAUNT
		state_timer = 3.0  # Even longer pause
		current_taunt = "Я — ЭТО ТЫ. Через тысячу петель. Я СОВЕРШЕНСТВО."
		taunt_display_timer = 5.0
		velocity = Vector2.ZERO
		# Фаза 3 — сильный удар окном вниз-вправо (угрожающий)
		_win_push(Vector2(0.5, 0.8).normalized(), 85.0, 0.9)

	# Dodge after hit
	var dodge_chance = 0.2 + phase * 0.08
	if randf() < dodge_chance and dodge_cooldown <= 0 and state != State.MEGA_STRIKE:
		state = State.DODGE
		state_timer = 0.3
		dodge_cooldown = 0.8 - phase * 0.15
		var dodge_dir = -1.0 if facing_right else 1.0
		velocity.x = dodge_dir * 320
		velocity.y = -160
		collision_layer = 0

	if health <= 0:
		health = 0
		is_dead = true
		death_timer = 0.0

func _do_taunt(p: int):
	state = State.TAUNT
	state_timer = 1.2
	var pool: Array
	match p:
		1: pool = taunts_phase1
		2: pool = taunts_phase2
		3: pool = taunts_phase3
		_: pool = taunts_phase1
	current_taunt = pool[randi() % pool.size()]
	taunt_display_timer = 3.0

func _process(delta):
	_win_update(delta)
	body_anim += delta * 4.0
	hit_flash = max(0, hit_flash - delta)
	taunt_display_timer = max(0, taunt_display_timer - delta)
	attack_cooldown_timer = max(0, attack_cooldown_timer - delta)
	dodge_cooldown = max(0, dodge_cooldown - delta)
	throw_cooldown = max(0, throw_cooldown - delta)
	mega_strike_cooldown = max(0, mega_strike_cooldown - delta)

	# Smooth phase scale transition
	phase_scale = lerp(phase_scale, target_phase_scale, delta * 3.0)

	if is_dead:
		_win_death = true
		death_timer += delta
		if death_timer >= 2.5:
			# Возвращаем окно на место перед удалением
			if _win_ready:
				DisplayServer.window_set_position(_win_origin)
			defeated.emit()
			queue_free()
		if sprite:
			sprite.modulate.a = max(0, 1.0 - death_timer * 0.8)
			sprite.scale = Vector2(sprite_scale_val, sprite_scale_val) * phase_scale * (1.0 + death_timer * 0.3)
		queue_redraw()
		return

	if not player or not is_instance_valid(player):
		queue_redraw()
		return

	var dist = global_position.distance_to(player.global_position)
	var dir_to_player = (player.global_position - global_position).normalized()
	facing_right = dir_to_player.x > 0

	if sprite:
		sprite.flip_h = !facing_right
		sprite.scale = Vector2(sprite_scale_val, sprite_scale_val) * phase_scale
		if hit_flash > 0:
			sprite.modulate = Color(2, 0.5, 0.5, 1)
		elif state == State.MEGA_STRIKE:
			# Glow purple during mega strike
			var glow = 1.0 + mega_strike_charge * 0.8
			sprite.modulate = Color(glow, 0.6, glow * 1.5, 1)
		else:
			sprite.modulate = Color(1, 1, 1, 1)

	state_timer -= delta
	var cur_speed = speed + (phase - 1) * 10

	match state:
		State.IDLE:
			_set_anim("walk")
			if state_timer <= 0:
				var action = _choose_action(dist)
				_start_action(action, dist, dir_to_player, cur_speed)

		State.CHASE:
			_set_anim("walk")
			velocity.x = dir_to_player.x * cur_speed
			# Jump over obstacles and to reach player
			if is_on_floor() and (is_on_wall() or (player.global_position.y < global_position.y - 40)):
				velocity.y = -400

			if dist < 38 and attack_cooldown_timer <= 0:
				state = State.ATTACK
				state_timer = 0.3
				attack_hit_this_swing = false
				combo_count = 0
				_set_anim("swing")
			elif state_timer <= 0:
				state = State.IDLE
				state_timer = 0.05

		State.ATTACK:
			_set_anim("swing")
			velocity.x = (1.0 if facing_right else -1.0) * 60
			if not attack_hit_this_swing and state_timer < 0.12:
				_try_hit_player(40, damage)
				attack_hit_this_swing = true

			if state_timer <= 0:
				combo_count += 1
				var max_combo = 2 + phase
				if combo_count < max_combo and dist < 55 and attack_cooldown_timer <= 0:
					state = State.ATTACK
					state_timer = 0.2 - phase * 0.02
					attack_hit_this_swing = false
					_set_anim("swing")
				else:
					state = State.IDLE
					state_timer = 0.4
					attack_cooldown_timer = 0.8 - phase * 0.1

		State.DODGE:
			_set_anim("jump")
			if state_timer <= 0:
				collision_layer = 2
				if dist < 80:
					state = State.ATTACK
					state_timer = 0.25
					attack_hit_this_swing = false
					combo_count = 0
				else:
					state = State.CHASE
					state_timer = 0.3

		State.JUMP_ATTACK:
			_set_anim("jump")
			# Track player while in air
			if not is_on_floor():
				velocity.x = lerp(velocity.x, dir_to_player.x * cur_speed * 1.5, delta * 3.0)
			if is_on_floor() and state_timer < 0.5:
				if not jump_attack_landed:
					jump_attack_landed = true
					_try_hit_player(80, damage + 10)  # Big shockwave
				state = State.IDLE
				state_timer = 0.2

		State.DASH_STRIKE:
			_set_anim("swing")
			var dash_dir = (dash_target - global_position).normalized()
			velocity.x = dash_dir.x * 450
			velocity.y = -60
			if state_timer < 0.12:
				_try_hit_player(45, damage)
			if state_timer <= 0:
				state = State.IDLE
				state_timer = 0.15

		State.COUNTER:
			_set_anim("swing")
			velocity.x = (1.0 if facing_right else -1.0) * 250
			if state_timer < 0.15:
				_try_hit_player(45, damage + 5)
			if state_timer <= 0:
				state = State.IDLE
				state_timer = 0.1

		State.TAUNT:
			_set_anim("walk")
			velocity.x *= 0.8
			if state_timer <= 0:
				state = State.CHASE
				state_timer = 0.4

		State.THROW_SWORD:
			_set_anim("swing")
			velocity.x *= 0.3
			if not pending_shot and state_timer > 0.1:
				pending_shot = true
				pending_shot_timer = shot_delay
			if pending_shot:
				pending_shot_timer -= delta
				if pending_shot_timer <= 0:
					pending_shot = false
					_throw_projectile(dir_to_player)
			if state_timer <= 0:
				pending_shot = false
				state = State.IDLE
				state_timer = 0.3
				throw_cooldown = 2.5 - phase * 0.4

		State.MEGA_STRIKE:
			_set_anim("swing")
			velocity.x *= 0.3  # Slow during charge
			mega_strike_charge = min(mega_strike_charge + delta * 1.2, 1.0)
			mega_sword_length = lerp(mega_sword_length, 120.0 + phase * 20.0, delta * 4.0)

			# Release when fully charged
			if mega_strike_charge >= 1.0 and not mega_hit:
				mega_hit = true
				# HUGE range hit that stuns
				_mega_hit_player()
				state_timer = 0.3

			if state_timer <= 0 and mega_hit:
				state = State.IDLE
				state_timer = 0.5
				mega_strike_cooldown = 6.0 - phase * 1.0
				mega_strike_charge = 0.0
				mega_sword_length = 0.0
				mega_hit = false

		State.STUN_RECOVER:
			_set_anim("walk")
			velocity.x *= 0.9
			if state_timer <= 0:
				state = State.CHASE
				state_timer = 0.3

		State.THROW_DASH:
			# Замах → бросок меча в сторону игрока
			_set_anim("swing")
			velocity.x *= 0.4
			if not pending_shot and state_timer < 0.3:
				pending_shot = true
				_throw_projectile(throw_dash_dir)
			if state_timer <= 0:
				# Рывок ВСЛЕД за брошенным мечом — резкий и быстрый
				state = State.THROW_DASH_LUNGE
				state_timer = 0.35
				velocity.x = throw_dash_dir.x * 620.0   # очень быстрый рывок
				velocity.y = -80
				pending_shot = false

		State.THROW_DASH_LUNGE:
			_set_anim("swing")
			# Сохраняем скорость рывка, бьём по пути
			if state_timer < 0.20:
				_try_hit_player(48, damage + 6)
			if state_timer <= 0:
				state = State.IDLE
				state_timer = 0.2
				throw_cooldown = 2.2 - phase * 0.4

	_animate_sprite(delta)
	queue_redraw()

	# === Триггеры движения окна по смене состояния ===
	if player and is_instance_valid(player):
		var dir_to_pl = (player.global_position - global_position).normalized()
		var p_mult = 1.0 + (phase - 1) * 0.35   # фаза 3 = x1.7

		# При смене состояния — разные толчки
		if state != _prev_state:
			match state:
				State.DASH_STRIKE:
					# Рывок — окно летит в сторону удара
					var dd = (dash_target - global_position).normalized()
					_win_push(dd, 70.0 * p_mult, 0.55)
				State.JUMP_ATTACK:
					# Прыжок — окно вверх
					_win_push(Vector2(dir_to_pl.x * 0.3, -1.0), 55.0 * p_mult, 0.5)
				State.THROW_DASH_LUNGE:
					# Рывок за мечом — резко в сторону броска
					_win_push(throw_dash_dir, 75.0 * p_mult, 0.55)
				State.COUNTER:
					# Контратака — окно к игроку
					_win_push(dir_to_pl, 50.0 * p_mult, 0.4)
				State.MEGA_STRIKE:
					_win_mega_done = false

		# JUMP_ATTACK приземление — удар вниз
		if state == State.JUMP_ATTACK and jump_attack_landed and not _win_mega_done:
			_win_mega_done = true
			_win_push(Vector2(randf_range(-0.3, 0.3), 1.0), 65.0 * p_mult, 0.5)

		# MEGA_STRIKE — окно "заряжается" и бьёт при выстреле
		if state == State.MEGA_STRIKE:
			if mega_hit and not _win_mega_done:
				_win_mega_done = true
				_win_push(dir_to_pl + Vector2(0, 0.5), 90.0 * p_mult, 0.8)
			elif not mega_hit:
				# Медленный дрейф к игроку во время зарядки
				_win_push(dir_to_pl * 0.5, 35.0 * p_mult * mega_strike_charge, 0.3)

		# Автодрейф в CHASE/IDLE — раз в 2-4 сек лёгкое покачивание
		if state in [State.CHASE, State.IDLE, State.ATTACK]:
			_win_drift_cd -= delta
			if _win_drift_cd <= 0.0:
				_win_drift_cd = randf_range(1.5, 3.5) / p_mult
				var drift = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()
				_win_push(drift, randf_range(25.0, 45.0) * p_mult, 1.0)

	_prev_state = state

func _choose_action(dist: float) -> String:
	var options: Array = []

	# Phase 1: basic — chase + attack + occasional jump
	if dist < 45 and attack_cooldown_timer <= 0:
		options.append("attack")
		options.append("attack")

	if dist > 100:
		options.append("jump_attack")
		if phase >= 2:
			options.append("jump_attack")

	# Phase 2: adds dash strikes + more throws
	if phase >= 2 and dist > 80:
		options.append("dash_strike")
	if phase >= 3 and dist > 60:
		options.append("dash_strike")
		options.append("dash_strike")

	if dist > 50 and dist < 200 and throw_cooldown <= 0:
		options.append("throw")
		if phase >= 2:
			options.append("throw")
		if phase >= 3:
			options.append("throw")

	# СИГНАТУРНАЯ АТАКА: бросок меча + рывок за ним (фаза 2+, на средней дистанции)
	if phase >= 2 and dist > 70 and dist < 280 and throw_cooldown <= 0:
		options.append("throw_dash")
		if phase >= 3:
			options.append("throw_dash")
			options.append("throw_dash")

	# MEGA STRIKE — only phase 2+ and more frequent in phase 3
	if mega_strike_cooldown <= 0 and dist < 150:
		if phase >= 2:
			options.append("mega")
		if phase >= 3:
			options.append("mega")
			options.append("mega")

	if dist > 40:
		options.append("chase")
		options.append("chase")

	# Phase 3: hyper aggressive
	if phase >= 3:
		if dist > 60:
			options.append("dash_strike")
			options.append("jump_attack")
		if dist < 60:
			options.append("attack")

	if options.size() == 0:
		return "chase"
	return options[randi() % options.size()]

func _start_action(action: String, dist: float, dir: Vector2, spd: float):
	match action:
		"attack":
			state = State.ATTACK
			state_timer = 0.3
			attack_hit_this_swing = false
			combo_count = 0
		"jump_attack":
			state = State.JUMP_ATTACK
			state_timer = 1.0
			velocity.y = -480 - phase * 40
			velocity.x = dir.x * (300 + phase * 40)
			jump_attack_landed = false
		"dash_strike":
			state = State.DASH_STRIKE
			state_timer = 0.35
			dash_target = player.global_position
			velocity.y = -100
		"throw":
			state = State.THROW_SWORD
			state_timer = 0.8
		"throw_dash":
			# Запоминаем направление броска и входим в фазу замаха
			throw_dash_dir = dir.normalized()
			state = State.THROW_DASH
			state_timer = 0.45
			pending_shot = false
		"mega":
			state = State.MEGA_STRIKE
			state_timer = 1.5  # Long charge time — player can dodge
			mega_strike_charge = 0.0
			mega_sword_length = 20.0
			mega_hit = false
			current_taunt = "ГОТОВЬСЯ!" if phase < 3 else "КОНЕЦ!"
			taunt_display_timer = 1.5
		"chase":
			state = State.CHASE
			state_timer = randf_range(0.4, 1.0)

func _try_hit_player(hit_range: float, hit_damage: int):
	if not player or not is_instance_valid(player) or player.is_dead:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist < hit_range:
		var kb = (player.global_position - global_position).normalized()
		if player.has_method("take_damage"):
			player.take_damage(hit_damage, kb)

func _mega_hit_player():
	if not player or not is_instance_valid(player) or player.is_dead:
		return
	var dist = global_position.distance_to(player.global_position)
	var mega_range = mega_sword_length + 20
	if dist < mega_range:
		var kb = (player.global_position - global_position).normalized()
		var mega_damage = damage + 8 + phase * 5
		if player.has_method("take_damage"):
			player.take_damage(mega_damage, kb * 2.5)
		# Stun player — set velocity to 0 and freeze briefly
		if player.has_method("stun"):
			player.stun(0.8 + phase * 0.2)
		else:
			# Fallback: big knockback
			player.velocity = kb * 350
			player.velocity.y = -200

func _throw_projectile(dir: Vector2):
	if not player or not is_instance_valid(player):
		return
	var proj = Area2D.new()
	proj.set_script(projectile_script)
	proj.projectile_type = 0
	proj.direction = dir
	proj.damage = damage
	proj.speed = 300
	proj.global_position = global_position + Vector2(0, -12) + dir * 16
	proj.rotation = dir.angle()
	get_parent().add_child(proj)

	# Phase 2+: spread
	if phase >= 2:
		for angle_off in [-0.25, 0.25]:
			var spread_dir = dir.rotated(angle_off)
			var proj2 = Area2D.new()
			proj2.set_script(projectile_script)
			proj2.projectile_type = 0
			proj2.direction = spread_dir
			proj2.damage = damage
			proj2.speed = 280
			proj2.global_position = global_position + Vector2(0, -12) + spread_dir * 16
			proj2.rotation = spread_dir.angle()
			get_parent().add_child(proj2)

	# Phase 3: even more
	if phase >= 3:
		for angle_off in [-0.5, 0.5]:
			var spread_dir = dir.rotated(angle_off)
			var proj3 = Area2D.new()
			proj3.set_script(projectile_script)
			proj3.projectile_type = 0
			proj3.direction = spread_dir
			proj3.damage = damage
			proj3.speed = 260
			proj3.global_position = global_position + Vector2(0, -12) + spread_dir * 16
			proj3.rotation = spread_dir.angle()
			get_parent().add_child(proj3)

func _set_anim(anim_name: String):
	if current_anim != anim_name:
		current_anim = anim_name
		current_frame = 0
		frame_timer = 0.0

func _animate_sprite(delta):
	var textures: Array = []
	match current_anim:
		"walk": textures = walk_textures
		"swing": textures = swing_textures
		"jump": textures = jump_textures

	if textures.size() == 0:
		return

	var spd = frame_speed
	if state == State.MEGA_STRIKE:
		spd = 6.0  # Slow animation during charge
	elif state == State.ATTACK:
		spd = 16.0  # Fast attack anim

	frame_timer += delta * spd
	if frame_timer >= 1.0:
		frame_timer -= 1.0
		current_frame = (current_frame + 1) % textures.size()

	if sprite and current_frame < textures.size():
		sprite.texture = textures[current_frame]

func _physics_process(delta):
	velocity.y += gravity_val * delta
	if state != State.DODGE and state != State.DASH_STRIKE:
		velocity.x *= 0.92
	move_and_slide()

func _draw():
	if is_dead:
		_draw_death()
		return

	var cx = 0.0
	var cy = -12.0 * phase_scale

	# Health bar with phase color
	var bar_w = 35.0 * phase_scale
	var hp_frac = float(health) / max_health
	draw_rect(Rect2(cx - bar_w/2, cy - 24, bar_w, 3), Color(0.2, 0, 0.1, 0.6))
	var bar_color: Color
	match phase:
		1: bar_color = Color(0.8, 0.1, 0.9, 0.8)
		2: bar_color = Color(1.0, 0.4, 0.1, 0.9)
		3: bar_color = Color(1.0, 0.1, 0.1, 1.0)
		_: bar_color = Color(0.8, 0.1, 0.9, 0.8)
	draw_rect(Rect2(cx - bar_w/2, cy - 24, bar_w * hp_frac, 3), bar_color)

	# Phase indicator
	var phase_text = "ФАЗА %d" % phase
	draw_string(ThemeDB.fallback_font, Vector2(cx - 12, cy - 28),
		phase_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 6, bar_color)

	# Name
	draw_string(ThemeDB.fallback_font, Vector2(cx - 25, cy - 34),
		"БУДУЩИЙ ТЫ", HORIZONTAL_ALIGNMENT_CENTER, -1, 7,
		Color(0.6, 0.3, 0.9, 0.7))

	# Taunt text
	if taunt_display_timer > 0 and current_taunt != "":
		var ta = min(taunt_display_timer, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(cx - current_taunt.length() * 3, cy - 42),
			current_taunt, HORIZONTAL_ALIGNMENT_CENTER, -1, 8,
			Color(0.8, 0.5, 1.0, ta))

	# === MEGA STRIKE VISUAL ===
	if state == State.MEGA_STRIKE:
		_draw_mega_strike(cx, cy)

	# Dash trail
	if state == State.DASH_STRIKE or state == State.COUNTER:
		for i in 5:
			var dir_x = -1.0 if facing_right else 1.0
			var trail_pos = Vector2(cx + dir_x * i * 10, cy)
			draw_circle(trail_pos, 5.0 - i * 0.9, Color(0.5, 0.1, 0.8, 0.35 - i * 0.06))

	# Shockwave on jump landing
	if state == State.JUMP_ATTACK and jump_attack_landed:
		var sw = (0.5 - state_timer) * 2
		if sw > 0 and sw < 1:
			draw_arc(Vector2(cx, 0), sw * 80, 0, PI, 20, Color(0.8, 0.3, 1.0, 1.0 - sw), 3.0)
			# Ground crack lines
			for i in 6:
				var angle = PI * float(i) / 5
				var len_val = sw * 50
				draw_line(Vector2.ZERO, Vector2(cos(angle) * len_val, sin(angle) * len_val * 0.3),
					Color(0.6, 0.2, 0.9, (1.0 - sw) * 0.6), 1.5)

	# Phase aura glow
	if phase >= 2:
		var aura_alpha = 0.1 + sin(body_anim) * 0.05
		var aura_r = 20.0 * phase_scale
		var aura_col = Color(0.5, 0.1, 0.8, aura_alpha) if phase == 2 else Color(0.9, 0.1, 0.2, aura_alpha)
		draw_circle(Vector2(cx, cy + 5), aura_r, aura_col)

func _draw_mega_strike(cx: float, cy: float):
	var dir_x = 1.0 if facing_right else -1.0
	var charge = mega_strike_charge
	var sword_len = mega_sword_length

	# Charging glow circle
	var glow_r = 10 + charge * 30
	var glow_alpha = charge * 0.4
	draw_circle(Vector2(cx + dir_x * 10, cy), glow_r, Color(0.8, 0.2, 1.0, glow_alpha))

	# Growing sword blade
	var blade_start = Vector2(cx + dir_x * 8, cy - 2)
	var blade_end = Vector2(cx + dir_x * (8 + sword_len), cy - 2 + sin(body_anim * 2) * 3)
	var blade_w = 3.0 + charge * 4.0

	# Sword glow trail
	draw_line(blade_start, blade_end, Color(0.9, 0.5, 1.0, charge * 0.3), blade_w + 4)
	# Main blade
	draw_line(blade_start, blade_end, Color(0.7, 0.7, 0.8, charge * 0.9), blade_w)
	# Edge highlight
	draw_line(blade_start + Vector2(0, -1), blade_end + Vector2(0, -1),
		Color(1, 1, 1, charge * 0.5), 1.0)

	# Sword tip spark
	if charge > 0.5:
		var spark_pos = blade_end
		for i in 4:
			var angle = body_anim * 5 + i * TAU / 4
			var spark_r = 5 + sin(body_anim * 8 + i) * 3
			var sp = spark_pos + Vector2(cos(angle) * spark_r, sin(angle) * spark_r)
			draw_circle(sp, 2.0, Color(1, 0.8, 1, charge * 0.6))

	# "ГОТОВЬСЯ!" warning flash
	if charge > 0.3 and charge < 0.8:
		var flash = sin(body_anim * 10) * 0.5 + 0.5
		draw_circle(Vector2(cx, cy), 5 + flash * 8, Color(1, 0.3, 0.3, flash * 0.2))

func _draw_death():
	var cx = 0.0
	var cy = -12.0
	var alpha = max(0, 1.0 - death_timer * 0.6)

	for i in 30:
		var angle = (float(i) / 30) * TAU + death_timer * 3
		var dist = death_timer * 60
		var pos = Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist)
		var c = Color(0.5, 0.1, 0.8, alpha * 0.8)
		draw_circle(pos, 3.5 * alpha, c)

	var flash_r = (1.0 - death_timer * 0.4) * 25
	if flash_r > 0:
		draw_circle(Vector2(cx, cy), flash_r, Color(0.8, 0.4, 1.0, alpha * 0.5))
		draw_arc(Vector2(cx, cy), flash_r, 0, TAU, 24, Color(1, 0.8, 1, alpha * 0.3), 2.0)
