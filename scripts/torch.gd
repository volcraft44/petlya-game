extends Node2D

var flicker_timer: float = 0.0
var flicker_offset: float = 0.0
var base_energy: float = 1.0
var light: PointLight2D
var on_wall_right: bool = false  # which side of wall
var color: Color = Color(0.95, 0.75, 0.85)  # пастельный pinker — dream-pop

var _low_end: bool = false

func _ready():
	_low_end = OS.has_feature("mobile")

	# На телефоне свет факела ВЫКЛЮЧЕН полностью — при 6–10 факелах это были
	# десятки перекрывающихся источников. Остаётся только рисованное пламя
	# (сцена и так светлая через ambient). На ПК — один свет на факел.
	if not _low_end:
		light = PointLight2D.new()
		light.color = color
		light.energy = base_energy
		light.texture = _create_light_texture()
		light.texture_scale = 2.8
		light.shadow_enabled = false
		add_child(light)

	flicker_offset = randf() * 100.0

func _create_light_texture() -> GradientTexture2D:
	var tex = GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)

	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	tex.gradient = grad

	return tex

var _fear: float = 0.0   # 0=спокоен, 1=рядом монстр — факел "боится"
var _fear_check_cd: float = 0.0

func _process(delta):
	flicker_timer += delta

	# Реактивный свет: проверяем врагов рядом (раз в 0.3 сек — дёшево)
	_fear_check_cd -= delta
	if _fear_check_cd <= 0.0:
		_fear_check_cd = 0.3
		var target_fear = 0.0
		var room = get_parent()
		if room and "enemies" in room:
			for en in room.enemies:
				if is_instance_valid(en):
					if global_position.distance_to(en.global_position) < 130.0:
						target_fear = 1.0
						break
		_fear = target_fear

	# Обновляем свет не каждый кадр — смена texture_scale заставляет свет
	# перерисовываться, а мерцание глазом не отличить на 20 Гц.
	# На телефоне света нет (light == null) — пропускаем.
	var base_scale := 2.8
	if light != null and Engine.get_process_frames() % 3 == 0:
		var flicker = sin(flicker_timer * 8 + flicker_offset) * 0.15 + sin(flicker_timer * 13 + flicker_offset * 2) * 0.1
		if _fear > 0.01:
			var panic = sin(flicker_timer * 30.0) * 0.25 * _fear
			light.energy = base_energy * (1.0 - _fear * 0.45) + flicker + panic
			light.texture_scale = (base_scale + flicker * 0.3) * (1.0 - _fear * 0.2)
		else:
			light.energy = base_energy + flicker
			light.texture_scale = base_scale + flicker * 0.3

	# Redraw — каждый 4-й кадр (god rays/марево медленные, разница не видна)
	if Engine.get_process_frames() % 4 == 0:
		queue_redraw()

func _draw():
	var s = 1 if on_wall_right else -1

	# === GOD RAYS — 3 диагональных луча света (облегчено для производительности) ===
	var flame_x = s * 3.0
	var flame_y = -10.0
	var ray_alpha = 0.04 + sin(flicker_timer * 3.0) * 0.015
	for i in 3:
		var ang = deg_to_rad(60 + i * 30)  # 60°..120° веер вниз
		var length = 65.0 + sin(flicker_timer * 1.5 + i) * 8.0
		var end_x = flame_x + cos(ang) * length
		var end_y = flame_y + sin(ang) * length
		var perp = Vector2(-sin(ang), cos(ang)) * 1.5
		var ray_far_w = perp * 2.5
		var beam_pts = PackedVector2Array([
			Vector2(flame_x, flame_y) + perp,
			Vector2(flame_x, flame_y) - perp,
			Vector2(end_x, end_y) - ray_far_w,
			Vector2(end_x, end_y) + ray_far_w,
		])
		draw_colored_polygon(beam_pts,
			Color(color.r, color.g, color.b, ray_alpha))

	# Wall mount bracket
	draw_rect(Rect2(-s * 2, -2, 4 * s, 3), Color(0.35, 0.25, 0.12))
	# Highlight on bracket
	draw_rect(Rect2(-s * 2, -2, 4 * s, 1), Color(0.55, 0.40, 0.20))

	# Stick (детализированный)
	draw_rect(Rect2(s * 2, -8, 2, 10), Color(0.40, 0.28, 0.12))
	draw_rect(Rect2(s * 2, -8, 1, 10), Color(0.55, 0.40, 0.18))  # left highlight

	# === HEAT DISTORTION — 2 кольца теплового марева (облегчено) ===
	for i in 2:
		var ring_y = -16.0 - i * 6.0
		var ring_offset_x = sin(flicker_timer * 6.0 + i * 1.7 + flicker_offset) * 2.0
		var ring_w = 6.0 + i * 2.0
		var ring_h = 2.0 + i * 0.7
		var ring_alpha = 0.12 - i * 0.04
		var ring_pts = PackedVector2Array()
		for sg in 10:
			var a = float(sg) / 10.0 * TAU
			ring_pts.append(Vector2(
				flame_x + ring_offset_x + cos(a) * ring_w,
				ring_y + sin(a) * ring_h))
		draw_colored_polygon(ring_pts,
			Color(1.0, 0.85, 0.55, ring_alpha))

	# === FLAME — многослойное пламя с мерцанием ===
	var flicker_x = sin(flicker_timer * 10 + flicker_offset) * 1.5
	var flicker_y = sin(flicker_timer * 7 + flicker_offset) * 1.0

	# Outer glow (большой)
	draw_circle(Vector2(flame_x + flicker_x, flame_y + flicker_y), 6,
		Color(color.r, color.g * 0.85, color.b * 0.95, 0.35))
	# Outer flame
	draw_circle(Vector2(flame_x + flicker_x, flame_y + flicker_y), 4,
		Color(1, 0.50, 0.55, 0.75))
	# Middle flame
	draw_circle(Vector2(flame_x + flicker_x * 0.5, flame_y - 1 + flicker_y * 0.5), 3,
		Color(1, 0.75, 0.70, 0.85))
	# Inner flame (яркое ядро)
	draw_circle(Vector2(flame_x, flame_y), 2,
		Color(1, 0.95, 0.85, 0.95))
	# Flame tip (искра)
	draw_circle(Vector2(flame_x + flicker_x * 0.3, flame_y - 4 + flicker_y * 0.3), 1.5,
		Color(1, 0.90, 0.55, 0.65))
	# Маленькая искорка ещё выше (отрывается от пламени)
	var spark_t = fmod(flicker_timer * 2.0 + flicker_offset, 1.5)
	if spark_t < 0.8:
		var sp_y = flame_y - 6.0 - spark_t * 14.0
		var sp_x = flame_x + sin(spark_t * 6.0) * 1.5
		var sp_a = (0.8 - spark_t) / 0.8
		draw_circle(Vector2(sp_x, sp_y), 1.0,
			Color(1, 0.85, 0.4, sp_a * 0.85))
