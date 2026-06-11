extends Node2D

# Облако дыма в стиле CS2 smoke.
# Враги внутри теряют видимость игрока (перестают атаковать/стрелять).

var lifetime: float = 8.0
var max_lifetime: float = 8.0
var radius: float = 70.0
var t: float = 0.0
# Пара puffs (клубков) для эстетики
var puffs: Array = []

func _ready() -> void:
	z_index = 5
	# Несколько случайных клубков
	for i in 7:
		var ang = randf() * TAU
		var r = randf_range(0.1, 0.85) * radius
		puffs.append({
			"offset": Vector2(cos(ang), sin(ang) * 0.7) * r,
			"size": randf_range(18.0, 32.0),
			"phase": randf() * TAU,
			"drift": randf_range(0.05, 0.20),
		})
	# Лёгкая просадка вниз (под гравитацией оседает)
	add_to_group("smoke_clouds")

func _process(delta: float) -> void:
	t += delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	# Применяем эффект "ослепления" к врагам внутри радиуса
	var room = get_parent()
	if room and "enemies" in room:
		for en in room.enemies:
			if is_instance_valid(en) and global_position.distance_to(en.global_position) < radius:
				if "smoke_blind_timer" in en:
					en.smoke_blind_timer = 0.5  # обновляем чтобы держался пока в дыму
	# Также игрок в дыму — невидим для невидевших врагов (бонус)
	queue_redraw()

func _draw() -> void:
	# Постепенно разрастается → стоит → рассеивается
	var grow = clampf(t / 0.6, 0.0, 1.0)
	var fade = clampf(lifetime / 1.2, 0.0, 1.0)
	var base_alpha = 0.85 * grow * fade
	# Тёмная внутренняя зона
	draw_circle(Vector2.ZERO, radius * grow * 0.9, Color(0.12, 0.12, 0.13, base_alpha))
	# Светлые клубы
	for p in puffs:
		var off = p.offset * grow
		var pulse = sin(t * p.drift * 8.0 + p.phase) * 2.0
		var size = (p.size + pulse) * grow
		draw_circle(off, size,
			Color(0.85, 0.85, 0.88, base_alpha * 0.55))
		draw_circle(off + Vector2(-size * 0.2, -size * 0.2), size * 0.5,
			Color(0.95, 0.95, 0.98, base_alpha * 0.35))
	# Тонкий ореол
	draw_arc(Vector2.ZERO, radius * grow, 0.0, TAU, 32,
		Color(0.6, 0.6, 0.65, base_alpha * 0.4), 2.0)
