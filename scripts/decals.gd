extends Node2D

# Лёгкий слой декалей: кровь остаётся на полу, следы игрока, нацарапанные
# надписи на стенах. Отдельный Node2D — перерисовывается только при добавлении,
# не нагружает тяжёлый room._draw().

var blood_stains: Array = []   # [{pos, r, col}]
var footprints: Array = []     # [{pos, facing, alpha}]
var wall_messages: Array = []  # [{pos, text, angle, alpha}]

const MAX_BLOOD: int = 45
const MAX_FOOTPRINTS: int = 18

var _dirty: bool = false       # нужна ли перерисовка
var _redraw_cd: float = 0.0    # троттл перерисовки

func _ready() -> void:
	z_index = -2   # под врагами/игроком, над полом

func add_blood(world_pos: Vector2, amount: float = 1.0) -> void:
	var n = int(1 + amount * 2)   # меньше пятен за раз
	for i in n:
		blood_stains.append({
			"pos": world_pos + Vector2(randf_range(-10, 10), randf_range(-3, 6)),
			"r": randf_range(2.0, 6.0) * amount,
			"col": Color(randf_range(0.35, 0.50), 0.03, 0.03, randf_range(0.55, 0.85)),
		})
	while blood_stains.size() > MAX_BLOOD:
		blood_stains.pop_front()
	_dirty = true   # перерисуем не сразу, а в _process по троттлу

func add_footprint(world_pos: Vector2, facing_right: bool) -> void:
	footprints.append({
		"pos": world_pos,
		"facing": facing_right,
		"alpha": 0.5,
	})
	while footprints.size() > MAX_FOOTPRINTS:
		footprints.pop_front()
	_dirty = true

func add_wall_message(world_pos: Vector2, text: String) -> void:
	wall_messages.append({
		"pos": world_pos,
		"text": text,
		"angle": randf_range(-0.12, 0.12),
		"alpha": 0.0,   # проявляется при приближении игрока
	})

func _process(delta: float) -> void:
	# Следы медленно тают (фильтруем редко)
	_redraw_cd -= delta
	for fp in footprints:
		if fp.alpha > 0.0:
			fp.alpha -= delta * 0.04
			_dirty = true
	# Перерисовка максимум ~8 раз/сек, и только если есть изменения
	if _dirty and _redraw_cd <= 0.0:
		_redraw_cd = 0.12
		_dirty = false
		footprints = footprints.filter(func(f): return f.alpha > 0.0)
		queue_redraw()

func _draw() -> void:
	# Кровь
	for b in blood_stains:
		draw_circle(b.pos, b.r, b.col)
		# Тёмное ядро
		draw_circle(b.pos + Vector2(-b.r * 0.2, -b.r * 0.15), b.r * 0.5,
			Color(b.col.r * 0.6, 0.02, 0.02, b.col.a * 0.8))

	# Следы — маленькие тёмные отпечатки
	for fp in footprints:
		var a = clampf(fp.alpha, 0.0, 0.5)
		var fx = fp.pos.x
		var fy = fp.pos.y
		var dir = 1.0 if fp.facing else -1.0
		# Два овальных отпечатка
		draw_rect(Rect2(fx - 2, fy - 1, 4, 2), Color(0.05, 0.04, 0.06, a))
		draw_rect(Rect2(fx + dir * 4 - 2, fy - 1, 4, 2), Color(0.05, 0.04, 0.06, a * 0.7))

	# Надписи на стенах — кровавый нацарапанный текст
	var font := ThemeDB.fallback_font
	for wm in wall_messages:
		if wm.alpha <= 0.01:
			continue
		var fsize = 9
		var size = font.get_string_size(wm.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		draw_set_transform(wm.pos, wm.angle, Vector2.ONE)
		# Тёмная обводка
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				if ox == 0 and oy == 0: continue
				draw_string(font, Vector2(-size.x * 0.5 + ox, oy),
					wm.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
					Color(0.05, 0.0, 0.0, wm.alpha * 0.8))
		# Кровавый текст
		draw_string(font, Vector2(-size.x * 0.5, 0),
			wm.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
			Color(0.70, 0.10, 0.10, wm.alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Вызывается извне (room._process) — проявляет надписи рядом с игроком
func update_message_visibility(player_pos: Vector2) -> void:
	for wm in wall_messages:
		var dist = wm.pos.distance_to(player_pos)
		var target = 1.0 if dist < 120.0 else 0.0
		var new_a = lerpf(wm.alpha, target, 0.08)
		if abs(new_a - wm.alpha) > 0.005:
			wm.alpha = new_a
			_dirty = true
