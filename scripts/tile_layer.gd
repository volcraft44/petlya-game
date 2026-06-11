extends Node2D

# Статичный слой тайлов комнаты. Рисуется ОДИН РАЗ после генерации,
# Godot кэширует draw-команды. Никогда не перерисовывается во время игры —
# это убирает спайки кадра при queue_redraw комнаты.

var room = null   # ссылка на room.gd

func render(p_room) -> void:
	room = p_room
	z_index = -3   # под декалями и врагами, над фоном
	queue_redraw()

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
	draw_rect(Rect2(0, 0, rw, rh), Color(bg.r, bg.g, bg.b, 0.55))
	var wall_tex = room.wall_bg_texture
	if wall_tex == null:
		return
	var tw := 128.0
	var th := 128.0
	var cols: int = int(rw / tw) + 1
	var rows_t: int = int(rh / th) + 1
	var tint: Color
	match room.room_level % 4:
		0: tint = Color(1.0, 1.0, 1.0, 0.55)
		1: tint = Color(0.75, 1.0, 0.75, 0.55)
		2: tint = Color(1.0, 0.85, 0.7, 0.55)
		_: tint = Color(0.75, 0.85, 1.0, 0.55)
	for row in rows_t:
		for col in cols:
			var x: float = col * tw - tw
			var y: float = row * th - th
			draw_texture_rect(wall_tex, Rect2(x, y, tw, th), false, tint)
	draw_rect(Rect2(0, 0, rw, rh), Color(0, 0, 0, 0.38))

func _draw_solid_tiles() -> void:
	var grid = room.grid
	var grid_cols: int = room.grid_cols
	var grid_rows: int = room.grid_rows
	var tile_size: int = room.tile_size
	var rock_color: Color = room.rock_color
	var rock_light: Color = room.rock_light
	var rock_dark: Color = room.rock_dark
	var stone_tex = room.stone_texture

	if stone_tex:
		var tex_w = stone_tex.get_width()
		var tex_h = stone_tex.get_height()
		for r in grid_rows:
			for c in grid_cols:
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
	for r in grid_rows:
		for c in grid_cols:
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

	# Floor surfaces — merged runs
	for r in range(1, grid_rows):
		var run_start = -1
		for c in range(grid_cols + 1):
			var is_floor = c < grid_cols and grid[r][c] == 1 and grid[r - 1][c] == 0
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
	for r in range(grid_rows - 1):
		var run_start = -1
		for c in range(grid_cols + 1):
			var is_ceil = c < grid_cols and grid[r][c] == 1 and grid[r + 1][c] == 0
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
	for r in grid_rows:
		for c in range(1, grid_cols):
			if grid[r][c] == 1 and grid[r][c - 1] == 0:
				draw_rect(Rect2(c * tile_size, r * tile_size, 2, tile_size),
					Color(rock_dark.r, rock_dark.g, rock_dark.b, 0.6))
