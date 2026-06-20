extends CanvasLayer

# Глубокий атмосферный фон с параллаксом — рисуется ПОД миром (negative layer).
# 3 слоя плавающих силуэтов на разной глубине, дальние двигаются медленнее.

var camera_node: Camera2D = null
var _draw_node: Node2D = null
var _t: float = 0.0
var biome_palette: int = 0   # 0=лавандовый, 1=aqua, 2=peach
# Volumetric fog бэнды
var _fog_bands: Array = []   # [{y, h, alpha, color, drift}]

# Каждый слой — массив "силуэтов": {x, y, w, h, color}
# Координаты в мировом пространстве слоя.
var _layers: Array = []

func _ready() -> void:
	layer = -50   # под всем
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Node2D.new()
	_draw_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)

	_rebuild_layers()
	# Fog bands — горизонтальные полосы тумана
	for i in 8:
		_fog_bands.append({
			"y_base": randf() * 800.0 - 100.0,
			"h": randf_range(40, 120),
			"alpha": randf_range(0.04, 0.10),
			"drift": randf_range(8, 18),
			"phase": randf() * TAU,
		})

func set_biome(palette: int) -> void:
	biome_palette = palette
	_rebuild_layers()

func _rebuild_layers() -> void:
	_layers.clear()
	# Палитра силуэтов по биому
	var l_far: Color
	var l_mid: Color
	var l_near: Color
	match biome_palette:
		0:  # Лавандовый
			l_far = Color(0.18, 0.15, 0.28, 0.42)
			l_mid = Color(0.25, 0.20, 0.38, 0.55)
			l_near = Color(0.30, 0.25, 0.45, 0.65)
		1:  # Aqua / underwater
			l_far = Color(0.10, 0.22, 0.30, 0.45)
			l_mid = Color(0.15, 0.32, 0.42, 0.55)
			l_near = Color(0.22, 0.42, 0.55, 0.65)
		2:  # Peach / cream
			l_far = Color(0.28, 0.18, 0.20, 0.42)
			l_mid = Color(0.40, 0.25, 0.30, 0.55)
			l_near = Color(0.55, 0.32, 0.38, 0.65)
		_:
			l_far = Color(0.18, 0.15, 0.28, 0.42)
			l_mid = Color(0.25, 0.20, 0.38, 0.55)
			l_near = Color(0.30, 0.25, 0.45, 0.65)
	_layers.append({
		"parallax": 0.08,
		"items": _gen_layer_items(12, 80.0, 180.0, l_far),
	})
	_layers.append({
		"parallax": 0.20,
		"items": _gen_layer_items(16, 40.0, 100.0, l_mid),
	})
	_layers.append({
		"parallax": 0.40,
		"items": _gen_layer_items(22, 20.0, 55.0, l_near),
	})

func _gen_layer_items(count: int, min_size: float, max_size: float, base_col: Color) -> Array:
	var arr = []
	for i in count:
		var w = randf_range(min_size, max_size)
		var h = randf_range(min_size, max_size)
		arr.append({
			"x": randf_range(-1500, 2700),
			"y": randf_range(-600, 1500),
			"w": w,
			"h": h,
			"col": base_col,
			# Лёгкое вертикальное колыхание
			"sway_phase": randf() * TAU,
			"sway_amp": randf_range(2.0, 8.0),
		})
	return arr

func set_camera(cam: Camera2D) -> void:
	camera_node = cam

func _process(delta: float) -> void:
	_t += delta
	# Throttle: ПК ~20 Гц, телефон ~10 Гц — параллакс медленный, разницы нет
	var _step := 6 if OS.has_feature("mobile") else 3
	if Engine.get_process_frames() % _step == 0:
		_draw_node.queue_redraw()

func _on_draw() -> void:
	var vs = get_viewport().get_visible_rect().size
	# Градиентное небо — снизу темнее, сверху чуть светлее лиловое
	for i in 12:
		var y_frac = float(i) / 12.0
		var y = y_frac * vs.y
		var h = vs.y / 12.0
		var col = Color(0.10, 0.08, 0.18).lerp(Color(0.18, 0.10, 0.22), y_frac)
		_draw_node.draw_rect(Rect2(0, y, vs.x, h + 1), col)

	# Камера-позиция (для параллакса)
	var cam_pos = Vector2.ZERO
	if camera_node and is_instance_valid(camera_node):
		cam_pos = camera_node.global_position

	# Рисуем слои силуэтов
	var fog_col = _fog_color_for_biome()
	for li in _layers.size():
		var layer_data = _layers[li]
		var p = layer_data.parallax
		var items = layer_data.items
		for item in items:
			var screen_x = (item.x - cam_pos.x * p)
			var screen_y = (item.y - cam_pos.y * p) + sin(_t * 0.3 + item.sway_phase) * item.sway_amp
			screen_x = fposmod(screen_x, vs.x + 800.0) - 400.0
			if screen_x < -item.w or screen_x > vs.x or screen_y < -item.h - 50 or screen_y > vs.y + 50:
				continue
			_draw_node.draw_rect(Rect2(screen_x, screen_y, item.w, item.h), item.col)
			_draw_node.draw_rect(Rect2(screen_x, screen_y, item.w, 3),
				Color(item.col.r * 1.3, item.col.g * 1.3, item.col.b * 1.3, item.col.a))
	# Туман — ОДИН полноэкранный проход вместо трёх (было по разу на слой =
	# тройной овердров каждый кадр). Суммарная плотность сохранена.
	_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y),
		Color(fog_col.r, fog_col.g, fog_col.b, 0.16))

	# Волнистые туманные полосы поверх всех фоновых слоёв
	for band in _fog_bands:
		var by = band.y_base + sin(_t * 0.15 + band.phase) * band.drift - cam_pos.y * 0.30
		by = fposmod(by, vs.y + 200.0) - 100.0
		if by < -band.h or by > vs.y:
			continue
		_draw_node.draw_rect(Rect2(0, by, vs.x, band.h),
			Color(fog_col.r, fog_col.g, fog_col.b, band.alpha))

func _fog_color_for_biome() -> Color:
	match biome_palette:
		0: return Color(0.65, 0.55, 0.85)   # лавандовый туман
		1: return Color(0.55, 0.75, 0.85)   # aqua mist
		2: return Color(0.95, 0.80, 0.75)   # peach haze
	return Color(0.65, 0.55, 0.85)
