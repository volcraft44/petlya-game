extends Node2D

# Слой тайлов комнаты с ОТСЕЧЕНИЕМ ПО КАМЕРЕ.
# Раньше рисовалась вся комната целиком (тысячи тайлов) — и хотя draw-команды
# кэшировались, Godot отправлял их все на GPU КАЖДЫЙ кадр. Это была постоянная
# нагрузка ("лагает просто когда ходишь"). Теперь рисуем только видимые тайлы
# и перерисовываем лишь когда камера сдвинулась на новую область.

var room = null   # ссылка на room.gd

# Текущий видимый диапазон тайлов (в индексах сетки)
var _vr: Rect2i = Rect2i(0, 0, 0, 0)
var _last_vr: Rect2i = Rect2i(-99999, -99999, 0, 0)

func render(p_room) -> void:
	room = p_room
	z_index = -3   # под декалями и врагами, над фоном
	_vr = _compute_visible_range()
	_last_vr = _vr
	queue_redraw()

func _process(_delta: float) -> void:
	if room == null:
		return
	var nr := _compute_visible_range()
	# Перерисовываем только если видимая область тайлов изменилась
	if nr != _last_vr:
		_last_vr = nr
		_vr = nr
		queue_redraw()

func _compute_visible_range() -> Rect2i:
	if room == null:
		return Rect2i(0, 0, 0, 0)
	var ts: int = room.tile_size
	if ts <= 0:
		return Rect2i(0, 0, room.grid_cols, room.grid_rows)
	var cam := get_viewport().get_camera_2d()
	var center: Vector2
	var zoom := Vector2(2.9, 2.9)
	if cam:
		center = cam.get_screen_center_position()
		zoom = cam.zoom
	else:
		# Камеры пока нет — берём весь видимый размер от центра комнаты
		center = Vector2(room.room_width, room.room_height) * 0.5
	var vis := Vector2(get_viewport().get_visible_rect().size)
	var half := vis * 0.5 / zoom
	# +3 тайла запаса по краям, чтобы не было «выезжающих» границ
	var x0 := int((center.x - half.x) / ts) - 3
	var x1 := int((center.x + half.x) / ts) + 3
	var y0 := int((center.y - half.y) / ts) - 3
	var y1 := int((center.y + half.y) / ts) + 3
	x0 = clampi(x0, 0, room.grid_cols)
	x1 = clampi(x1, 0, room.grid_cols)
	y0 = clampi(y0, 0, room.grid_rows)
	y1 = clampi(y1, 0, room.grid_rows)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)

func _draw() -> void:
	if room == null:
		return
	_draw_wall_background()
	_draw_solid_tiles()
	_draw_surface_edges()

func _draw_wall_background() -> void:
	var rw = room.room_width
	var rh = room.room_height
	var bg = room.bg_color
	# Фоновая заливка — только видимая область (в мировых координатах)
	var ts: int = room.tile_size
	var vx := _vr.position.x * ts
	var vy := _vr.position.y * ts
	var vw := _vr.size.x * ts
	var vh := _vr.size.y * ts
	draw_rect(Rect2(vx, vy, vw, vh), Color(bg.r, bg.g, bg.b, 0.55))
	var wall_tex = room.wall_bg_texture
	if wall_tex == null:
		draw_rect(Rect2(vx, vy, vw, vh), Color(0, 0, 0, 0.38))
		return
	var tw := 128.0
	var th := 128.0
	var tint: Color
	match room.room_level % 4:
		0: tint = Color(1.0, 1.0, 1.0, 0.55)
		1: tint = Color(0.75, 1.0, 0.75, 0.55)
		2: tint = Color(1.0, 0.85, 0.7, 0.55)
		_: tint = Color(0.75, 0.85, 1.0, 0.55)
	# Только плитки фона, попадающие в видимую область
	var c0 := int(vx / tw) - 1
	var c1 := int((vx + vw) / tw) + 1
	var r0 := int(vy / th) - 1
	var r1 := int((vy + vh) / th) + 1
	for row in range(r0, r1 + 1):
		for col in range(c0, c1 + 1):
			var x: float = col * tw
			var y: float = row * th
			draw_texture_rect(wall_tex, Rect2(x, y, tw, th), false, tint)
	draw_rect(Rect2(vx, vy, vw, vh), Color(0, 0, 0, 0.38))

func _draw_solid_tiles() -> void:
	var grid = room.grid
	var tile_size: int = room.tile_size
	var rock_color: Color = room.rock_color
	var rock_light: Color = room.rock_light
	var rock_dark: Color = room.rock_dark
	var stone_tex = room.stone_texture

	var rx0 := _vr.position.x
	var rx1 := _vr.position.x + _vr.size.x
	var ry0 := _vr.position.y
	var ry1 := _vr.position.y + _vr.size.y

	if stone_tex:
		var tex_w = stone_tex.get_width()
		var tex_h = stone_tex.get_height()
		for r in range(ry0, ry1):
			for c in range(rx0, rx1):
				if grid[r][c] == 1:
					var x = c * tile_size
					var y = r * tile_size
					var src_x = (c * tile_size) % tex_w
					var src_y = (r * tile_size) % tex_h
					var src_w = mini(tile_size, tex_w - src_x)
					var src_h = mini(tile_size, tex_h - src_y)
					draw_texture_rect_region(stone_tex,
						Rect2(x, y, tile_size, tile_size),
						Rect2(src_x, src_y, src_w, src_h))
		return

	# Voxel-стиль
	var hl = rock_light
	var sh = Color(rock_dark.r * 0.65, rock_dark.g * 0.65, rock_dark.b * 0.65)
	var sh_inner = Color(rock_dark.r, rock_dark.g, rock_dark.b, 0.45)
	var speck_dark  = Color(rock_dark.r,  rock_dark.g,  rock_dark.b,  0.55)
	var speck_light = Color(rock_light.r, rock_light.g, rock_light.b, 0.45)
	for r in range(ry0, ry1):
		for c in range(rx0, rx1):
			if grid[r][c] != 1:
				continue
			var x = c * tile_size
			var y = r * tile_size
			draw_rect(Rect2(x, y, tile_size, tile_size), rock_color)
			draw_rect(Rect2(x, y, tile_size, 2), hl)
			draw_rect(Rect2(x, y, 1, tile_size), Color(hl.r, hl.g, hl.b, 0.65))
			draw_rect(Rect2(x, y + tile_size - 2, tile_size, 2), sh)
			draw_rect(Rect2(x + tile_size - 1, y + 2, 1, tile_size - 4), sh_inner)
			draw_rect(Rect2(x + 1, y + tile_size - 5, tile_size - 2, 3), sh_inner)
			var h = (r * 73 + c * 131) & 0xFF
			draw_rect(Rect2(x + 3 + (h % 8), y + 4 + ((h >> 3) % 6), 1, 1), speck_dark)
			draw_rect(Rect2(x + 6 + ((h >> 2) % 7), y + 7 + ((h >> 4) % 5), 1, 1), speck_light)
			draw_rect(Rect2(x + 1, y + 1, 1, 1), hl)
			draw_rect(Rect2(x + 2, y + 1, 1, 1), Color(hl.r, hl.g, hl.b, 0.7))

func _draw_surface_edges() -> void:
	var grid = room.grid
	var grid_cols: int = room.grid_cols
	var grid_rows: int = room.grid_rows
	var tile_size: int = room.tile_size
	var rock_dark: Color = room.rock_dark
	var rock_light: Color = room.rock_light
	var surface_color: Color = room.surface_color
	var ceil_col = Color(rock_dark.r - 0.05, rock_dark.g - 0.05, rock_dark.b - 0.03)
	var light_col = Color(rock_light.r, rock_light.g, rock_light.b, 0.5)

	var rx0 := maxi(_vr.position.x, 0)
	var rx1 := mini(_vr.position.x + _vr.size.x, grid_cols)
	var ry0 := maxi(_vr.position.y, 1)
	var ry1 := mini(_vr.position.y + _vr.size.y, grid_rows)

	# Floor surfaces — merged runs (в видимых строках/столбцах)
	for r in range(ry0, ry1):
		var run_start = -1
		for c in range(rx0, rx1 + 1):
			var is_floor = c < rx1 and c < grid_cols and grid[r][c] == 1 and grid[r - 1][c] == 0
			if is_floor:
				if run_start == -1:
					run_start = c
			else:
				if run_start != -1:
					var x = run_start * tile_size
					var w = (c - run_start) * tile_size
					draw_rect(Rect2(x, r * tile_size, w, 2), surface_color)
					draw_rect(Rect2(x + 1, r * tile_size + 2, w - 2, 3), light_col)
					run_start = -1

	# Ceiling surfaces
	var cy1 := mini(_vr.position.y + _vr.size.y, grid_rows - 1)
	for r in range(maxi(_vr.position.y, 0), cy1):
		var run_start = -1
		for c in range(rx0, rx1 + 1):
			var is_ceil = c < rx1 and c < grid_cols and grid[r][c] == 1 and grid[r + 1][c] == 0
			if is_ceil:
				if run_start == -1:
					run_start = c
			else:
				if run_start != -1:
					var x = run_start * tile_size
					var w = (c - run_start) * tile_size
					draw_rect(Rect2(x, (r + 1) * tile_size - 2, w, 2), ceil_col)
					run_start = -1

	# Left edges of solid tiles
	for r in range(maxi(_vr.position.y, 0), ry1):
		for c in range(maxi(rx0, 1), rx1):
			if grid[r][c] == 1 and grid[r][c - 1] == 0:
				draw_rect(Rect2(c * tile_size, r * tile_size, 2, tile_size),
					Color(rock_dark.r, rock_dark.g, rock_dark.b, 0.6))
