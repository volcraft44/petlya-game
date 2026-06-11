extends CharacterBody2D

# === БОСС 2: ЛАВОВЫЙ СТРАЖ ===
# Летающий босс. Бой идёт пока ты карабкаешься вверх по платформам к двери.
# Снизу поднимается лава — стоять нельзя. Босс стреляет огнём и пикирует.
signal boss_defeated

enum State { IDLE, FIREBALL, FIRE_RAIN, DIVE, RISE, RECOVER, DEATH }

var state: int = State.IDLE
var state_t: float = 0.0
var health: int = 300
var max_health: int = 300
var is_dead: bool = false
var is_boss: bool = true
var player: CharacterBody2D = null

var anim_t: float = 0.0
var hit_flash: float = 0.0
var attack_cd: float = 0.0
var hover_target: Vector2 = Vector2.ZERO
var dive_target: Vector2 = Vector2.ZERO
var eye_pulse: float = 0.0

# Снаряды-фаерболы: [{pos, vel, life}]
var fireballs: Array = []

# === ДВИЖЕНИЕ ОКНА ОС во время боя ===
var _win_origin:    Vector2i = Vector2i.ZERO
var _win_offset:    Vector2  = Vector2.ZERO   # текущее смещение (плавное)
var _win_target:    Vector2  = Vector2.ZERO   # целевое смещение
var _win_return_cd: float    = 0.0            # кулдаун перед возвратом в центр
var _win_drift_cd:  float    = 0.0            # автодрейф IDLE
var _win_rain_cd:   float    = 0.0            # кулдаун толчков во время дождя
var _win_ready:     bool     = false          # сохранили origin?
var _win_death:     bool     = false          # режим death-тряски

func _win_init() -> void:
	if not _win_ready:
		_win_origin = DisplayServer.window_get_position()
		_win_ready  = true

func _win_push(dir: Vector2, intensity: float, hold: float = 0.4) -> void:
	# Не перебиваем более сильный толчок
	var new_t = dir.normalized() * intensity
	if new_t.length() < _win_target.length() * 0.6:
		return
	_win_target    = new_t
	_win_return_cd = hold

func _win_update(delta: float) -> void:
	if not _win_ready:
		return
	# Death-тряска — случайные прыжки
	if _win_death:
		var s = Vector2i(randi_range(-28, 28), randi_range(-28, 28))
		DisplayServer.window_set_position(_win_origin + s)
		return
	# Кулдаун возврата
	if _win_return_cd > 0.0:
		_win_return_cd -= delta
		if _win_return_cd <= 0.0:
			_win_target = Vector2.ZERO
	# Плавное движение
	_win_offset = _win_offset.lerp(_win_target, 1.0 - exp(-9.0 * delta))
	DisplayServer.window_set_position(
		_win_origin + Vector2i(int(_win_offset.x), int(_win_offset.y))
	)

func setup(p_player: CharacterBody2D):
	player = p_player
	state = State.IDLE
	state_t = 1.5
	_win_init()
	var shape = CollisionShape2D.new()
	var circ = CircleShape2D.new()
	circ.radius = 18
	shape.shape = circ
	add_child(shape)
	collision_layer = 2
	collision_mask = 0   # летает сквозь всё (не падает)

func _physics_process(delta):
	if is_dead:
		_process_death(delta)
		return
	if not player or not is_instance_valid(player):
		return
	anim_t += delta
	eye_pulse += delta
	state_t -= delta
	attack_cd = maxf(0.0, attack_cd - delta)
	if hit_flash > 0.0:
		hit_flash -= delta

	_update_fireballs(delta)

	var is_enraged = health <= max_health * 0.4

	match state:
		State.IDLE:
			# Парим над игроком, слегка покачиваясь
			hover_target = player.global_position + Vector2(0, -120) + Vector2(sin(anim_t) * 60, 0)
			_hover_to(hover_target, delta, 90.0)
			if attack_cd <= 0:
				_choose_attack(is_enraged)
		State.FIREBALL:
			_hover_to(player.global_position + Vector2(0, -110), delta, 60.0)
			if state_t <= 0:
				_shoot_fireballs(3 if not is_enraged else 5)
				state = State.RECOVER
				state_t = 0.5
		State.FIRE_RAIN:
			# Парит сверху и сыплет огонь вниз веером
			_hover_to(Vector2(player.global_position.x, player.global_position.y - 160), delta, 100.0)
			state_t -= delta
			if fmod(state_t, 0.25) < 0.02:
				_rain_fire()
			if state_t <= 0:
				state = State.RECOVER
				state_t = 0.5
		State.DIVE:
			# Пикирует на игрока
			var to_t = (dive_target - global_position)
			velocity = to_t.normalized() * 380.0
			if global_position.distance_to(dive_target) < 24 or state_t <= 0:
				_dive_impact()
				state = State.RISE
				state_t = 0.8
			global_position += velocity * delta
		State.RISE:
			# Возврат вверх после пикирования
			_hover_to(player.global_position + Vector2(0, -130), delta, 200.0)
			if state_t <= 0:
				state = State.RECOVER
				state_t = 0.4
		State.RECOVER:
			_hover_to(player.global_position + Vector2(sin(anim_t) * 50, -120), delta, 70.0)
			if state_t <= 0:
				state = State.IDLE
		_:
			pass

	# Урон при контакте телом
	if state != State.DEATH and global_position.distance_to(player.global_position) < 24:
		_deal_damage(8)

	queue_redraw()

func _hover_to(target: Vector2, delta: float, spd: float):
	var to_t = target - global_position
	velocity = to_t.limit_length(spd)
	global_position += velocity * delta

func _choose_attack(is_enraged):
	var roll = randf()
	if roll < 0.4:
		state = State.FIREBALL
		state_t = 0.5
	elif roll < 0.7:
		state = State.FIRE_RAIN
		state_t = 1.6 if not is_enraged else 2.4
	else:
		dive_target = player.global_position
		state = State.DIVE
		state_t = 1.0
	attack_cd = (1.4 if not is_enraged else 0.8)

func _shoot_fireballs(count):
	var base = (player.global_position + Vector2(0, -16) - global_position).normalized()
	for i in count:
		var spread = (float(i) - count * 0.5) * 0.18
		var dir = base.rotated(spread)
		fireballs.append({"pos": global_position, "vel": dir * 220.0, "life": 4.0})

func _rain_fire():
	# Капля огня летит вниз с разбросом по x
	var px = global_position.x + randf_range(-40, 40)
	fireballs.append({"pos": Vector2(px, global_position.y + 10),
		"vel": Vector2(randf_range(-20, 20), 200.0), "life": 4.0})

func _dive_impact():
	if global_position.distance_to(player.global_position) < 50:
		_deal_damage(16)

func _update_fireballs(delta):
	for fb in fireballs:
		fb.pos += fb.vel * delta
		fb.vel.y += 60 * delta   # лёгкая гравитация
		fb.life -= delta
		if player and is_instance_valid(player):
			if fb.pos.distance_to(player.global_position + Vector2(0, -16)) < 14:
				_deal_damage(10)
				fb.life = 0
	fireballs = fireballs.filter(func(f): return f.life > 0.0)

func _deal_damage(dmg: int):
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var kb = sign(player.global_position.x - global_position.x)
		if kb == 0: kb = 1
		player.take_damage(dmg, Vector2(kb, -0.3).normalized())

func take_damage(amount: int, _knockback_dir: Vector2 = Vector2.ZERO):
	if is_dead:
		return
	if state == State.IDLE and state_t > 1.0:   # intro неуязвимость
		return
	# ULTRAKILL: уязвим только в RECOVER/RISE (окна после атак), иначе броня 25%
	var is_vuln = state in [State.RECOVER, State.RISE]
	if not is_vuln:
		amount = maxi(1, int(amount * 0.25))
	else:
		amount = int(amount * 1.5)
	health -= amount
	hit_flash = 0.12
	if health <= 0:
		health = 0
		is_dead = true
		state = State.DEATH
		state_t = 1.8

func _process_death(delta):
	state_t -= delta
	global_position.y += 30 * delta   # медленно падает
	queue_redraw()
	if state_t <= 0:
		boss_defeated.emit()
		queue_free()

func _draw():
	var flash = hit_flash > 0.0
	var is_enraged = health <= max_health * 0.4
	# Фаерболы
	for fb in fireballs:
		var lp = to_local(fb.pos)
		draw_circle(lp, 6, Color(1, 0.5, 0.1, 0.4))
		draw_circle(lp, 3.5, Color(1, 0.8, 0.2))
		draw_circle(lp, 1.5, Color(1, 1, 0.8))

	if is_dead:
		# Распад
		var frac = state_t / 1.8
		draw_circle(Vector2.ZERO, 18 * frac, Color(1, 0.4, 0.1, frac * 0.6))
		return

	# Окно уязвимости — золотое кольцо (бей сейчас!)
	if state in [State.RECOVER, State.RISE]:
		var vp = 0.5 + 0.5 * sin(eye_pulse * 10.0)
		draw_circle(Vector2.ZERO, 28, Color(1.0, 0.9, 0.3, 0.18 * vp))
		draw_arc(Vector2.ZERO, 26, 0, TAU, 24, Color(1.0, 0.9, 0.3, 0.6 * vp), 2.0)

	# Тело — парящий огненный череп/страж
	var glow = 0.6 + 0.4 * sin(eye_pulse * 4.0)
	var core_col = Color(0.95, 0.35, 0.10) if not is_enraged else Color(1.0, 0.15, 0.05)
	if flash: core_col = Color(1, 1, 1)
	# Внешнее свечение
	draw_circle(Vector2.ZERO, 24, Color(1, 0.4, 0.1, 0.20 * glow))
	draw_circle(Vector2.ZERO, 18, Color(1, 0.5, 0.1, 0.35 * glow))
	# Каменное "лицо"-череп
	draw_circle(Vector2.ZERO, 14, Color(0.20, 0.10, 0.08) if not flash else Color(1,1,1))
	# Глаза — горящие
	var eye_col = Color(1.0, 0.85, 0.2) if not is_enraged else Color(1.0, 0.95, 0.5)
	draw_circle(Vector2(-5, -2), 2.5, eye_col)
	draw_circle(Vector2(5, -2), 2.5, eye_col)
	# Огненная "корона"
	for i in 6:
		var a = float(i) / 6.0 * TAU + anim_t
		var fx = cos(a) * 16
		var fy = sin(a) * 16
		var flame_h = 4 + sin(anim_t * 8 + i) * 2
		draw_circle(Vector2(fx, fy), flame_h, Color(1, 0.5, 0.1, 0.55 * glow))
	# Рот-трещина
	draw_rect(Rect2(-6, 5, 12, 2), Color(1, 0.6, 0.1, glow))

	# HP-бар
	var bw = 40.0
	draw_rect(Rect2(-bw * 0.5, -34, bw, 4), Color(0.1, 0.0, 0.0, 0.8))
	var hpf = float(health) / float(max_health)
	draw_rect(Rect2(-bw * 0.5, -34, bw * hpf, 4),
		Color(1.0, 0.5, 0.1) if not is_enraged else Color(1.0, 0.2, 0.05))
