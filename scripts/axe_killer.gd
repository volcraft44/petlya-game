extends CharacterBody2D

# === БОСС 1: ПАЛАЧ С ТОПОРОМ ===
# Богатый набор атак, телеграфы, фаза ярости. Сложный — требует движения и дэшей.
signal boss_defeated

enum State { INTRO, CHASE, CHAIN_WINDUP, CHAIN_THROW, CHAIN_PULL, COMBO,
	SPIN_WINDUP, SPIN, LEAP_WINDUP, LEAP, LEAP_LAND, AXE_THROW, RECOVER, DEATH }

var state: int = State.INTRO
var state_t: float = 0.0
var health: int = 380
var max_health: int = 380
var is_dead: bool = false
var is_boss: bool = true
var player: CharacterBody2D = null
var facing_right: bool = false
var gravity: float = 980.0

var is_enraged: bool = false       # < 40% HP
var attack_cd: float = 0.0          # пауза между атаками
var is_hit: bool = false
var hit_flash: float = 0.0
var anim_t: float = 0.0             # общий аниматор для покачивания
var vulnerable: bool = false        # уязвим только в окнах после атак (ULTRAKILL)
var block_flash: float = 0.0        # вспышка "БРОНЯ" при ударе по защите
var contact_tick: float = 0.0       # таймер урона от касания тела

# Цепь
var chain_target: Vector2 = Vector2.ZERO
var chain_progress: float = 0.0     # 0..1 выдвижение цепи
var chain_hit: bool = false
var combo_hits: int = 0

# Прыжок
var leap_target: Vector2 = Vector2.ZERO

# Брошенный топор (бумеранг)
var thrown_axe_active: bool = false
var thrown_axe_pos: Vector2 = Vector2.ZERO
var thrown_axe_vel: Vector2 = Vector2.ZERO
var thrown_axe_returning: bool = false
var thrown_axe_spin: float = 0.0

# Спин-атака
var spin_angle: float = 0.0

func setup(p_player: CharacterBody2D):
	player = p_player
	state = State.INTRO
	state_t = 1.5
	# Коллизия босса
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(28, 44)
	shape.shape = rect
	shape.position = Vector2(0, -22)
	add_child(shape)
	collision_layer = 2
	collision_mask = 4   # стены/пол

func _physics_process(delta):
	if is_dead:
		_process_death(delta)
		return
	if not player or not is_instance_valid(player):
		return

	anim_t += delta
	state_t -= delta
	attack_cd = maxf(0.0, attack_cd - delta)
	if hit_flash > 0.0:
		hit_flash -= delta

	# Гравитация
	if not is_on_floor():
		velocity.y += gravity * delta

	# Энрейдж
	if not is_enraged and health <= max_health * 0.40:
		is_enraged = true
		state = State.RECOVER
		state_t = 0.6

	if block_flash > 0.0:
		block_flash -= delta

	# === ОКНО УЯЗВИМОСТИ (ULTRAKILL) ===
	# Босс уязвим только в восстановлении после атак и при приземлении прыжка.
	# Всё остальное время — бронирован (наказывает спам-клик).
	vulnerable = state in [State.RECOVER, State.LEAP_LAND]

	# === УРОН ОТ КАСАНИЯ ТЕЛА ===
	# Стоять вплотную нельзя — тело наносит урон. Заставляет держать дистанцию/дэшить.
	contact_tick = maxf(0.0, contact_tick - delta)
	if state not in [State.INTRO, State.DEATH]:
		if global_position.distance_to(player.global_position) < 26 and contact_tick <= 0:
			contact_tick = 0.5
			_deal_contact_damage(8)

	var dist = global_position.distance_to(player.global_position)
	var dir_to_player = sign(player.global_position.x - global_position.x)
	if dir_to_player != 0 and state in [State.CHASE, State.CHAIN_WINDUP, State.SPIN_WINDUP, State.LEAP_WINDUP]:
		facing_right = dir_to_player > 0

	# Брошенный топор-бумеранг (живёт независимо)
	_update_thrown_axe(delta)

	match state:
		State.INTRO:
			velocity.x = 0
			if state_t <= 0:
				state = State.CHASE
		State.CHASE:
			_do_chase(delta, dist, dir_to_player)
		State.CHAIN_WINDUP:
			velocity.x = 0
			if state_t <= 0:
				_fire_chain()
		State.CHAIN_THROW:
			velocity.x = 0
			chain_progress = min(1.0, chain_progress + delta * 4.0)
			# Проверка попадания цепи
			if not chain_hit:
				var chain_tip = global_position + (chain_target - global_position) * chain_progress
				if chain_tip.distance_to(player.global_position + Vector2(0, -16)) < 24:
					chain_hit = true
					state = State.CHAIN_PULL
					state_t = 0.5
			if chain_progress >= 1.0 and not chain_hit:
				state = State.RECOVER
				state_t = 0.5
		State.CHAIN_PULL:
			velocity.x = 0
			# Притягиваем игрока к боссу
			if player.has_method("apply_external_pull"):
				player.apply_external_pull(global_position + Vector2(facing_right and -20 or 20, -16))
			else:
				var pull_dir = (global_position - player.global_position).normalized()
				player.velocity = pull_dir * 400
			chain_progress = max(0.0, chain_progress - delta * 3.0)
			if state_t <= 0:
				state = State.COMBO
				state_t = 0.0
				combo_hits = 0
		State.COMBO:
			velocity.x = 0
			# Серия из 3 быстрых ударов
			state_t -= delta
			if state_t <= 0 and combo_hits < 3:
				combo_hits += 1
				state_t = 0.28
				_combo_hit()
			elif combo_hits >= 3:
				state = State.RECOVER
				state_t = 0.7
				chain_hit = false
		State.SPIN_WINDUP:
			velocity.x = 0
			if state_t <= 0:
				state = State.SPIN
				state_t = 1.2 if not is_enraged else 1.6
				spin_angle = 0.0
		State.SPIN:
			# Крутится и движется к игроку, наносит урон в радиусе
			spin_angle += delta * (12.0 if not is_enraged else 16.0)
			velocity.x = dir_to_player * (70.0 if not is_enraged else 110.0)
			if dist < 42:
				_deal_contact_damage(14)
			if state_t <= 0:
				state = State.RECOVER
				state_t = 0.5
		State.LEAP_WINDUP:
			velocity.x = 0
			if state_t <= 0:
				# Прыжок к позиции игрока
				leap_target = player.global_position
				var dx = leap_target.x - global_position.x
				velocity.x = clampf(dx * 1.8, -260, 260)
				velocity.y = -460
				state = State.LEAP
				state_t = 2.0
		State.LEAP:
			# В воздухе — летим к цели
			if is_on_floor() and velocity.y >= 0 and state_t < 1.7:
				state = State.LEAP_LAND
				state_t = 0.35
				_leap_shockwave()
			if state_t <= 0:
				state = State.RECOVER
				state_t = 0.5
		State.LEAP_LAND:
			velocity.x = 0
			if state_t <= 0:
				state = State.RECOVER
				state_t = 0.4
		State.AXE_THROW:
			velocity.x = 0
			if state_t <= 0:
				_throw_axe()
				state = State.RECOVER
				state_t = 0.6
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0, delta * 400)
			if state_t <= 0:
				state = State.CHASE

	move_and_slide()
	queue_redraw()

func _do_chase(delta, dist, dir_to_player):
	# Двигаемся к игроку
	var spd = 105.0 if not is_enraged else 165.0
	velocity.x = dir_to_player * spd
	# Выбор атаки когда кулдаун прошёл
	if attack_cd <= 0:
		_choose_attack(dist)

func _choose_attack(dist):
	var roll = randf()
	if dist > 200:
		# Далеко — цепь или бросок топора
		if roll < 0.5:
			_begin_chain()
		else:
			_begin_axe_throw()
	elif dist > 90:
		# Средне — прыжок или цепь или топор
		if roll < 0.4:
			_begin_leap()
		elif roll < 0.7:
			_begin_chain()
		else:
			_begin_axe_throw()
	else:
		# Близко — спин или прыжок
		if roll < 0.6:
			_begin_spin()
		else:
			_begin_leap()
	attack_cd = (1.2 if not is_enraged else 0.6) + randf_range(-0.2, 0.4)

func _begin_chain():
	state = State.CHAIN_WINDUP
	state_t = 0.6
	chain_progress = 0.0
	chain_hit = false

func _fire_chain():
	# Запоминаем направление к игроку
	chain_target = player.global_position + Vector2(0, -16)
	state = State.CHAIN_THROW
	chain_progress = 0.0

func _combo_hit():
	# Удар в упор во время комбо — больно (цепь притянула = наказание)
	if global_position.distance_to(player.global_position) < 60:
		_deal_contact_damage(14)

func _begin_spin():
	state = State.SPIN_WINDUP
	state_t = 0.45

func _begin_leap():
	state = State.LEAP_WINDUP
	state_t = 0.5

func _leap_shockwave():
	# Ударная волна при приземлении
	if global_position.distance_to(player.global_position) < 80:
		_deal_contact_damage(18)
		if player.has_method("screen_shake"):
			player.screen_shake.emit(6.0, 0.3)

func _begin_axe_throw():
	state = State.AXE_THROW
	state_t = 0.4

func _throw_axe():
	thrown_axe_active = true
	thrown_axe_returning = false
	thrown_axe_pos = global_position + Vector2(0, -20)
	var aim = (player.global_position + Vector2(0, -16) - thrown_axe_pos).normalized()
	thrown_axe_vel = aim * 320.0
	thrown_axe_spin = 0.0

func _update_thrown_axe(delta):
	if not thrown_axe_active:
		return
	thrown_axe_spin += delta * 20.0
	if not thrown_axe_returning:
		thrown_axe_pos += thrown_axe_vel * delta
		thrown_axe_vel.y += 120 * delta   # лёгкая дуга
		# Через расстояние — возврат
		if thrown_axe_pos.distance_to(global_position) > 280:
			thrown_axe_returning = true
	else:
		var ret_dir = (global_position + Vector2(0, -20) - thrown_axe_pos).normalized()
		thrown_axe_pos += ret_dir * 360 * delta
		if thrown_axe_pos.distance_to(global_position + Vector2(0, -20)) < 20:
			thrown_axe_active = false
	# Урон игроку
	if player and is_instance_valid(player):
		if thrown_axe_pos.distance_to(player.global_position + Vector2(0, -16)) < 18:
			_deal_contact_damage(12)

func _deal_contact_damage(dmg: int):
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var kb = sign(player.global_position.x - global_position.x)
		if kb == 0: kb = 1
		player.take_damage(dmg, Vector2(kb, -0.4).normalized())

func take_damage(amount: int, _knockback_dir: Vector2 = Vector2.ZERO):
	if is_dead:
		return
	# В intro неуязвим
	if state == State.INTRO:
		return
	# ULTRAKILL: вне окна уязвимости — броня (урон 20%), нужно ловить открытия
	if not vulnerable:
		amount = maxi(1, int(amount * 0.20))
		block_flash = 0.15
	else:
		# В окне уязвимости — бонусный урон (+50%), награда за тайминг
		amount = int(amount * 1.5)
	health -= amount
	is_hit = true
	hit_flash = 0.12
	if health <= 0:
		health = 0
		is_dead = true
		state = State.DEATH
		state_t = 2.0

func _process_death(delta):
	state_t -= delta
	velocity.x = move_toward(velocity.x, 0, delta * 300)
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	queue_redraw()
	if state_t <= 0:
		boss_defeated.emit()
		queue_free()

# ─────────────────────────────────────────────────────────────
# DRAW
# ─────────────────────────────────────────────────────────────
func _draw():
	var s = 1.0 if facing_right else -1.0
	var flash = hit_flash > 0.0
	var body_col = Color(0.30, 0.10, 0.12) if not is_enraged else Color(0.55, 0.08, 0.10)
	if flash:
		body_col = Color(1, 1, 1)
	var dark = Color(0.15, 0.05, 0.06)

	# Тень под боссом
	if is_on_floor():
		draw_circle(Vector2(0, 2), 18, Color(0, 0, 0, 0.4))

	# === Индикатор состояния ===
	# Уязвим → золотое свечение (БЕЙ!). Броня при ударе → синяя вспышка (BLOCKED).
	if vulnerable and not is_dead:
		var vp = 0.5 + 0.5 * sin(anim_t * 10.0)
		draw_circle(Vector2(0, -22), 30, Color(1.0, 0.85, 0.2, 0.18 * vp))
		draw_arc(Vector2(0, -22), 28, 0, TAU, 24, Color(1.0, 0.9, 0.3, 0.6 * vp), 2.0)
	if block_flash > 0.0:
		var ba = block_flash / 0.15
		draw_arc(Vector2(0, -22), 26, 0, TAU, 24, Color(0.4, 0.7, 1.0, 0.7 * ba), 3.0)

	# Покачивание тела
	var sway = sin(anim_t * 4.0) * 1.5

	# === Телеграфы атак (красные индикаторы) ===
	_draw_telegraphs(s)

	# Ноги
	draw_rect(Rect2(-9, -16, 7, 16), dark)
	draw_rect(Rect2(2, -16, 7, 16), dark)
	# Тело (массивное)
	draw_rect(Rect2(-13, -42 + sway, 26, 28), body_col)
	# Броня-полосы
	draw_rect(Rect2(-13, -34 + sway, 26, 3), dark)
	draw_rect(Rect2(-13, -26 + sway, 26, 3), dark)
	# Капюшон палача
	draw_rect(Rect2(-10, -56 + sway, 20, 16), dark)
	# Прорезь для глаз — светятся
	var eye_col = Color(1.0, 0.2, 0.1) if not is_enraged else Color(1.0, 0.6, 0.1)
	draw_rect(Rect2(-7, -50 + sway, 5, 2), eye_col)
	draw_rect(Rect2(2, -50 + sway, 5, 2), eye_col)
	# Плечи-шипы
	draw_rect(Rect2(-16, -40 + sway, 4, 6), dark)
	draw_rect(Rect2(12, -40 + sway, 4, 6), dark)

	# === Топор (если не брошен) ===
	if not thrown_axe_active and state != State.SPIN:
		_draw_axe(Vector2(s * 16, -34 + sway), s, 0.0)

	# === Спин-атака — топор вращается вокруг ===
	if state == State.SPIN:
		var ax = cos(spin_angle) * 26
		var ay = sin(spin_angle) * 18 - 28
		_draw_axe(Vector2(ax, ay), 1.0, spin_angle)
		# След вращения
		draw_arc(Vector2(0, -28), 26, 0, TAU, 20, Color(1, 0.3, 0.1, 0.25), 3.0)

	# === Цепь ===
	if state in [State.CHAIN_THROW, State.CHAIN_PULL]:
		var origin = Vector2(s * 10, -30)
		var tip = to_local(chain_target) if state == State.CHAIN_THROW else (to_local(player.global_position) + Vector2(0, -16))
		var cur_tip = origin + (tip - origin) * chain_progress
		# Звенья цепи
		var seg = 8
		for i in seg:
			var p = origin.lerp(cur_tip, float(i) / seg)
			draw_circle(p, 2.5, Color(0.5, 0.5, 0.55))
		# Крюк на конце
		draw_circle(cur_tip, 4, Color(0.6, 0.6, 0.65))
		draw_rect(Rect2(cur_tip.x - 1, cur_tip.y - 4, 2, 4), Color(0.7, 0.7, 0.75))

	# === Брошенный топор ===
	if thrown_axe_active:
		var local_axe = to_local(thrown_axe_pos)
		_draw_axe(local_axe, 1.0, thrown_axe_spin)

	# HP-бар над боссом
	_draw_hp_bar(sway)

func _draw_axe(pos: Vector2, dir: float, rot: float):
	draw_set_transform(pos, rot, Vector2.ONE)
	# Рукоять
	draw_rect(Rect2(-1.5, -2, 3, 22), Color(0.35, 0.22, 0.10))
	# Лезвие
	var blade = Color(0.7, 0.72, 0.78) if not is_enraged else Color(0.9, 0.4, 0.3)
	var blade_pts = PackedVector2Array([
		Vector2(dir * 2, -4), Vector2(dir * 14, -10),
		Vector2(dir * 16, 2), Vector2(dir * 4, 4),
	])
	draw_colored_polygon(blade_pts, blade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_telegraphs(s: float):
	# Красные предупреждения перед атаками
	match state:
		State.CHAIN_WINDUP:
			# Линия в направлении игрока
			var prog = 1.0 - state_t / 0.6
			var tgt = to_local(player.global_position + Vector2(0, -16))
			draw_line(Vector2(s * 10, -30), Vector2(s * 10, -30) + (tgt - Vector2(s * 10, -30)) * prog,
				Color(1, 0.2, 0.1, 0.5), 2.0)
		State.SPIN_WINDUP:
			var pulse = 0.5 + 0.5 * sin(anim_t * 30.0)
			draw_arc(Vector2(0, -28), 30, 0, TAU, 24, Color(1, 0.3, 0.1, 0.4 * pulse), 2.5)
		State.LEAP_WINDUP:
			# Маркер где приземлится
			var tgt2 = to_local(player.global_position)
			draw_circle(Vector2(tgt2.x, 2), 24, Color(1, 0.2, 0.1, 0.25))
			draw_arc(Vector2(tgt2.x, 2), 24, 0, TAU, 20, Color(1, 0.3, 0.1, 0.6), 2.0)

func _draw_hp_bar(sway: float):
	var bw = 40.0
	var by = -68 + sway
	draw_rect(Rect2(-bw * 0.5, by, bw, 4), Color(0.1, 0.0, 0.0, 0.8))
	var frac = float(health) / float(max_health)
	var col = Color(0.9, 0.15, 0.1) if not is_enraged else Color(1.0, 0.5, 0.1)
	draw_rect(Rect2(-bw * 0.5, by, bw * frac, 4), col)
	draw_rect(Rect2(-bw * 0.5, by, bw, 4), Color(0.6, 0.6, 0.6, 0.4), false, 1.0)
