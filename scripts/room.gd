extends Node2D

signal room_cleared
signal door_used(door)
signal challenge_complete

var room_width: float = 3200.0
var room_height: float = 1360.0
var enemies: Array = []
var doors: Array = []

# Level objectives (#42) — иногда нестандартная цель
var objective: String = "default"   # "default", "kill_all", "survive_60", "no_damage", "speedrun_30"
var objective_timer: float = 0.0
var objective_completed: bool = false
var objective_failed: bool = false
var is_cleared: bool = false
var room_level: int = 1
var is_boss_room: bool = false
var is_lava_boss: bool = false      # лавовый паркур-босс (level 10)
var lava_rise_y: float = 0.0        # текущая высота лавы (мировые Y), растёт вверх
var lava_rise_speed: float = 9.0    # px/сек — поднимается (медленно, можно карабкаться)
var golem_boss = null
var golem_script = preload("res://scripts/golem.gd")
var axe_killer_script = preload("res://scripts/axe_killer.gd")
var lava_boss_script = preload("res://scripts/lava_boss.gd")
var lava_y: float = 0.0  # Y position of lava surface in boss room

var tile_size: int = 16
var grid_cols: int = 0
var grid_rows: int = 0
var _last_cam_tile_x: int = -1
var _last_cam_tile_y: int = -1
var grid: Array = []  # 2D array: 1 = solid rock, 0 = open/air
# Туман войны для миникарты: explored[r][c] = true где побывал игрок
var explored: Array = []
const MINIMAP_EXPLORE_RADIUS: int = 8   # сколько тайлов открывается вокруг игрока
var _explore_cd: float = 0.0            # внутренний таймер обновления explored

# Слой декалей (кровь, следы, надписи)
var decals: Node2D = null
var tile_layer: Node2D = null
var _footprint_cd: float = 0.0

# Нацарапанные надписи на стенах — лор петли
const WALL_LORE: Array = [
	"МЫ ПОМНИМ БУДУЩЕЕ",
	"ПЕТЛЯ НЕ КОНЧАЕТСЯ",
	"ТЫ УЖЕ БЫЛ ЗДЕСЬ",
	"БЕГИ ПОКА МОЖЕШЬ",
	"ОНИ ВСЕ БЫЛИ ТОБОЙ",
	"НЕ ДОВЕРЯЙ СВЕТУ",
	"СМЕРТЬ — ЭТО НАЧАЛО",
	"СКОЛЬКО РАЗ?",
	"ВЫХОДА НЕТ",
	"ПРОСНИСЬ",
]

var floor_y: float
var ceiling_y: float

# Colors — grey stone theme
var rock_color: Color = Color(0.45, 0.45, 0.48)
var rock_dark: Color = Color(0.3, 0.3, 0.33)
var rock_light: Color = Color(0.55, 0.55, 0.58)
var surface_color: Color = Color(0.6, 0.6, 0.63)
var bg_color: Color = Color(0.04, 0.03, 0.05)

# === МЯСНАЯ КОМНАТА (раз за игру) ===
var is_meat_room: bool = false
var corpses: Array = []        # [{x, y, type, rot, flip}]
var meat_blood_pools: Array = []    # [{x, y, r}]
var meat_pulse: float = 0.0    # для пульсации стен

# === RUSH B (CS easter egg) ===
var is_rush_b: bool = false
var rush_b_graffiti: Array = []    # [{x, y, text}]

# Stone texture
var stone_texture: Texture2D = null
var wall_bg_texture: Texture2D = null

# Torch
var torch_positions: Array = []
var dark_zones: Array = []
var platforms: Array = []  # For spawn positions
var caves: Array = []      # For main.gd compatibility

var torch_script = preload("res://scripts/torch.gd")
var portal_script = preload("res://scripts/skeleton_portal.gd")
var crystal_script = preload("res://scripts/crystal.gd")

# Portal system
var portals: Array = []
var portal_spawn_timer: float = 0.0
var portal_spawn_interval: float = 8.0
var player_ref: CharacterBody2D = null

# Chests
var chests: Array = []
var chest_near_idx: int = -1   # index of chest player is standing near (-1 = none)

# Ore blocks (for lockpick crafting)
var ore_blocks: Array = []  # {x, y, mined, area}
var pickaxe_enemy: CharacterBody2D = null  # The mob that drops pickaxe

# Crafting stations in start cave
var craft_stations: Array = []  # {type, x, y, area}
var player_near_station: String = ""  # "", "furnace", "anvil", "grate"
var grate_used_this_level: bool = false

# Gold ore blocks (separate from iron ore)
var gold_ore_blocks: Array = []  # {x, y, mined, area}

# Pearl enemy (drops pearl on death)
var pearl_enemy: CharacterBody2D = null

# Trial room (every 2 levels)
var trial_heart_pos: Vector2 = Vector2.ZERO
var trial_heart_area: Area2D = null

# Traps
var spikes: Array = []         # {x, y, w} — spike strips on floor
var poison_pipes: Array = []   # {x, y, dir, pool_w} — pipes with poison pools
var pressure_plates: Array = [] # {x, y, triggered, cooldown} — arrow traps
var trial_active: bool = false
var trial_complete: bool = false
var trial_enemies: Array = []
var player_near_heart: bool = false
signal trial_completed

# Legendary trial room (every 3 levels)
var legend_trial_pos: Vector2 = Vector2.ZERO
var legend_trial_area: Area2D = null
var legend_trial_active: bool = false
var legend_trial_complete: bool = false
var legend_trial_enemies: Array = []
var legend_trial_weapon_id: int = -1
var player_near_legend: bool = false
var legend_weapon_chest_placed: bool = false

# Blood pools (permanent floor stains on enemy death)
var blood_pools: Array = []  # [{x, y, r, alpha}]

# ── Horror effects (world-space) ──
var _horror_drip_cd:   float = 12.0
var _blood_drips:      Array = []   # [{x,y,len,max_len,speed,alpha}]
var _face_cd:          float = 0.0  # randomized in _ready
var _face_t:           float = -1.0
var _face_dur:         float = 0.0
var _face_wx:          float = 0.0   # world x
var _face_wy:          float = 0.0   # world y
var _wtext_cd:         float = 0.0  # randomized in _ready
var _wtext_t:          float = -1.0
var _wtext_dur:        float = 0.0
var _wtext_msg:        String = ""
var _wtext_wx:         float = 0.0
var _wtext_wy:         float = 0.0
var horror_total_deaths: int = 0    # set by main.gd
var _death_label_pos:  Vector2 = Vector2.ZERO  # set once on room gen

# Arena room (closes gates when player enters, open after clearing)
var is_arena_level: bool = false
var arena_active: bool = false
var arena_cleared: bool = false
var arena_gate_left: StaticBody2D = null
var arena_gate_right: StaticBody2D = null

# Secret rooms
var secret_rooms: Array = []  # [{cx, cy, wall_c, wall_r, revealed, chest_spawned}]

# Random room events
var room_event: String = ""  # "merchant", "altar", "cursed"
var event_used: bool = false
var merchant_items: Array = []
var altar_used: bool = false
var merchant_pos: Vector2 = Vector2.ZERO  # actual world position of merchant
var merchant_room: Dictionary = {}       # shop room pixel bounds {x_left, x_right, y_top, y_bot}
var merchant_selected: int = 0           # currently highlighted shop item index
var _shop_open_flag: bool = false        # true пока меню магазина открыто

# Stored enemy scene reference (for arena spawning)
var _enemy_scene_ref: PackedScene = null

# Mini-map data
var minimap_rooms: Array = []
var minimap_current_idx: int = -1
var minimap_start_idx: int = -1
var minimap_door_idx: int = -1

# Barrels
var barrels: Array = []  # [{pos: Vector2, active: bool}]

# Weapon shop items (for merchant)
const SHOP_WEAPONS = [
	{"weapon_id": 1,  "name": "Меч",            "rarity": "common",    "price": 5},
	{"weapon_id": 13, "name": "Топор",           "rarity": "uncommon",  "price": 12},
	{"weapon_id": 3,  "name": "Клинки",          "rarity": "uncommon",  "price": 12},
	{"weapon_id": 16, "name": "Тройной Лук",     "rarity": "uncommon",  "price": 15},
	{"weapon_id": 2,  "name": "Длинный Меч",     "rarity": "uncommon",  "price": 12},
	{"weapon_id": 4,  "name": "Молот",           "rarity": "rare",      "price": 25},
	{"weapon_id": 7,  "name": "Нож",             "rarity": "rare",      "price": 25},
	{"weapon_id": 14, "name": "Цепь",            "rarity": "rare",      "price": 25},
	{"weapon_id": 17, "name": "Моргенштерн",     "rarity": "rare",      "price": 30},
	{"weapon_id": 5,  "name": "Клинки Вампира",  "rarity": "legendary", "price": 50},
	{"weapon_id": 6,  "name": "Золотой Молот",   "rarity": "legendary", "price": 50},
	{"weapon_id": 10, "name": "Рука Змея",       "rarity": "legendary", "price": 55},
	{"weapon_id": 12, "name": "Книга Некроманта","rarity": "legendary", "price": 60},
]

# Door challenge system
# "lockpick" = normal lockpick, "guardians" = kill spear shieldmen, "crystal" = defend crystal
var challenge_type: String = "lockpick"
var challenge_started: bool = false
var challenge_complete_flag: bool = false
var reachable_set: Dictionary = {}  # Tiles reachable from start (for spawn validation)
var ladders: Array = []  # [{x, y_top, y_bottom, col}] — climbable ladders
var oneway_platforms: Array = []  # [{x, y, w}] — thin platforms, jump through from below
var door_guardians: Array = []
var crystal_node: Node2D = null
var crystal_attackers: Array = []

func _ready():
	grid_cols = int(room_width / tile_size)
	grid_rows = int(room_height / tile_size)
	floor_y = room_height - tile_size * 2
	ceiling_y = tile_size * 2
	# Stone texture отключена: используем процедурный voxel-стиль (Lucid Blocks look)
	stone_texture = null
	# Load wall background texture
	var wall_img = Image.new()
	if wall_img.load(ProjectSettings.globalize_path("res://sprites/wall_bg.png")) == OK:
		wall_bg_texture = ImageTexture.create_from_image(wall_img)
	elif ResourceLoader.exists("res://sprites/wall_bg.png"):
		wall_bg_texture = load("res://sprites/wall_bg.png")
	# Randomize horror cooldowns
	_horror_drip_cd = randf_range(10.0, 22.0)
	_face_cd        = randf_range(90.0, 200.0)
	_wtext_cd       = randf_range(120.0, 280.0)

func setup(level: int, enemy_scene: PackedScene, p_player_ref: CharacterBody2D):
	room_level = level
	player_ref = p_player_ref

	# Tutorial level 0
	if level == 0:
		_setup_tutorial_room()
		return

	# Boss level 5 — плоская арена с Палачом
	if level == 5:
		is_boss_room = true
		room_width = 1200.0
		room_height = 700.0
		grid_cols = int(room_width / tile_size)
		grid_rows = int(room_height / tile_size)
		floor_y = room_height - tile_size * 2
		_setup_axe_boss_room()
		return
	# Boss level 10 — лавовый паркур с Лавовым Стражем
	if level == 10:
		is_boss_room = true
		is_lava_boss = true
		room_width = 800.0
		room_height = 1400.0   # высокая вертикальная комната
		grid_cols = int(room_width / tile_size)
		grid_rows = int(room_height / tile_size)
		floor_y = room_height - tile_size * 2
		_setup_lava_boss_room()
		return

	_enemy_scene_ref = enemy_scene
	_set_biome(level)
	_determine_challenge_type()
	_generate_cave()
	_build_collision()
	_place_torches()
	_calculate_dark_zones()
	_spawn_enemies(enemy_scene, p_player_ref)
	_spawn_ore_blocks()
	_spawn_gold_ore()
	if challenge_type == "lockpick":
		_spawn_pickaxe_mob(enemy_scene, p_player_ref)
	if room_level % 4 == 0:  # Pearl enemy every 4 levels
		_spawn_pearl_enemy(enemy_scene, p_player_ref)
	_spawn_craft_stations()
	if room_level % 2 == 0:  # Trial room every 2 levels
		_spawn_trial_heart()
	if room_level % 3 == 0 and room_level > 0:  # Legendary trial every 3 levels
		_spawn_legend_trial()
	_spawn_door()
	portal_spawn_timer = randf_range(4.0, 7.0)
	portal_spawn_interval = max(5.0, 10.0 - room_level * 0.5)
	# Arena room: 30% chance for levels > 2
	if room_level > 2 and randf() < 0.30:
		_setup_arena()
	# Random event: guaranteed merchant every 3 levels, otherwise 45% chance
	if room_event == "":
		if room_level % 3 == 0:
			room_event = "merchant"
		elif room_level > 1 and randf() < 0.45:
			var events = ["merchant", "altar", "cursed"]
			room_event = events[randi() % events.size()]
	if room_event != "":
		_setup_room_event()

	# Статичный слой тайлов — рисуется один раз, кэшируется (нет спайков)
	_create_tile_layer()

	# Слой декалей + надписи на стенах
	decals = Node2D.new()
	decals.set_script(load("res://scripts/decals.gd"))
	add_child(decals)
	_place_wall_messages()

	# Назначаем случайную цель уровня (15% шанс на нестандартную, с 3-го уровня)
	objective = "default"
	objective_timer = 0.0
	objective_completed = false
	objective_failed = false
	if level >= 3 and randf() < 0.15:
		var opts = ["kill_all", "survive_60", "no_damage", "speedrun_30"]
		objective = opts[randi() % opts.size()]
		match objective:
			"survive_60": objective_timer = 60.0
			"speedrun_30": objective_timer = 30.0

	# Заполняем мясную комнату трупами и лужами крови
	if is_meat_room:
		_populate_meat_room()

	# Rush B пасхалка: граффити на стенах + 2 бонус-сундука у двери
	if is_rush_b:
		_populate_rush_b()

func _rarity_glow_color(rarity: String) -> Color:
	# Цвета совпадают с CS-rarity для целостности
	match rarity:
		"common":     return Color(0.78, 0.78, 0.82)
		"uncommon":   return Color(0.32, 0.55, 0.95)
		"rare":       return Color(0.55, 0.30, 0.95)
		"epic":       return Color(0.92, 0.30, 0.85)
		"legendary":  return Color(1.00, 0.20, 0.15)
		"contraband": return Color(1.00, 0.85, 0.15)
		_: return Color(0.78, 0.78, 0.82)

func _populate_rush_b():
	rush_b_graffiti.clear()
	# Цель: точка двери
	if doors.size() == 0:
		return
	var door_pos: Vector2 = doors[0].global_position
	# Раскидываем 6-10 граффити на стенах, ведущих к двери (от старта).
	var start_cave_data = null
	for cd in caves:
		if cd.type == "start":
			start_cave_data = cd
			break
	if not start_cave_data:
		return
	var start_x = start_cave_data.x
	var path_dist = door_pos.x - start_x
	var count = 8
	for i in count:
		var t = float(i + 1) / float(count + 1)
		var gx = start_x + path_dist * t
		# Ищем подходящий y — стена слева/справа на этом x
		var gy_grid = randi_range(int(grid_rows * 0.35), int(grid_rows * 0.7))
		var texts = ["RUSH B", "→ B →", "GO B GO B", "RUSH", "B"]
		rush_b_graffiti.append({
			"x": gx + randf_range(-30, 30),
			"y": float(gy_grid) * tile_size + randf_range(-10, 10),
			"text": texts[i % texts.size()],
			"angle": randf_range(-0.15, 0.15),
		})
	# Бонус-сундуки прямо у двери (2 шт)
	_place_chest(door_pos.x - 28, door_pos.y, true)
	_place_chest(door_pos.x - 56, door_pos.y, true)

func _place_wall_messages():
	# 2-4 нацарапанных лор-надписи на стенах уровня
	if not decals:
		return
	var msg_count = randi_range(2, 4)
	var used_msgs = []
	var attempts = 0
	while used_msgs.size() < msg_count and attempts < 60:
		attempts += 1
		var gc = randi_range(5, grid_cols - 6)
		var gr = randi_range(5, grid_rows - 6)
		# Нужна открытая клетка рядом со стеной
		if grid[gr][gc] == 0 and (grid[gr + 1][gc] == 1 or grid[gr - 1][gc] == 1):
			var msg = WALL_LORE[randi() % WALL_LORE.size()]
			if msg in used_msgs:
				continue
			used_msgs.append(msg)
			decals.add_wall_message(
				Vector2(gc * tile_size + 8, gr * tile_size + 8), msg)

func _populate_meat_room():
	corpses.clear()
	meat_blood_pools.clear()
	# Раскидываем трупы на полу пещеры
	var attempts = 0
	while corpses.size() < 12 and attempts < 200:
		attempts += 1
		var gc = randi_range(3, grid_cols - 4)
		var gr = randi_range(3, grid_rows - 3)
		# Хотим место на твёрдом полу (тайл-пол под ногами)
		if gr + 1 < grid_rows and grid[gr][gc] == 0 and grid[gr + 1][gc] == 1:
			corpses.append({
				"x": gc * tile_size + 8 + randf_range(-4, 4),
				"y": gr * tile_size + tile_size - 4,
				"type": randi() % 3,         # 0=скелет, 1=торс, 2=куча костей
				"rot": randf_range(-0.6, 0.6),
				"flip": randf() < 0.5,
			})
	# Лужи крови — больше, шире, перекрывающиеся
	attempts = 0
	while meat_blood_pools.size() < 16 and attempts < 200:
		attempts += 1
		var gc2 = randi_range(2, grid_cols - 3)
		var gr2 = randi_range(2, grid_rows - 3)
		if gr2 + 1 < grid_rows and grid[gr2][gc2] == 0 and grid[gr2 + 1][gc2] == 1:
			meat_blood_pools.append({
				"x": gc2 * tile_size + 8 + randf_range(-4, 4),
				"y": gr2 * tile_size + tile_size - 2,
				"r": randf_range(8.0, 22.0),
			})

func _setup_tutorial_room():
	rock_color = Color(0.45, 0.42, 0.38)
	rock_dark = Color(0.3, 0.28, 0.25)
	rock_light = Color(0.55, 0.52, 0.48)
	room_width = 800.0
	room_height = 400.0
	grid_cols = int(room_width / tile_size)
	grid_rows = int(room_height / tile_size)
	floor_y = room_height - tile_size * 2

	# Initialize grid — all empty
	grid.clear()
	for r in grid_rows:
		var row = []
		for c in grid_cols:
			row.append(0)
		grid.append(row)

	# Borders: top, bottom, left, right walls
	for c in grid_cols:
		for t in 2:
			grid[t][c] = 1
			grid[grid_rows - 1 - t][c] = 1
	for r in grid_rows:
		for t in 2:
			grid[r][t] = 1
			grid[r][grid_cols - 1 - t] = 1

	# Floor
	for c in range(2, grid_cols - 2):
		grid[grid_rows - 3][c] = 1

	# Section 1: Roll gap (1-block high passage) — tiles at columns 12-14, row ~18 (halfway up)
	var gap_r = grid_rows - 6
	for c in range(10, 16):
		grid[gap_r][c] = 1
		grid[gap_r - 1][c] = 1
	# Leave 1-tile gap at bottom for rolling through
	grid[gap_r + 1][12] = 0
	grid[gap_r + 1][13] = 0
	# Wall above gap
	for r in range(gap_r - 3, gap_r - 1):
		for c in range(10, 16):
			grid[r][c] = 1

	# Section 2: Wall climb — tall wall at columns 22-24
	for r in range(grid_rows - 10, grid_rows - 3):
		grid[r][22] = 1
		grid[r][23] = 1

	# Section 3: One-way platform above wall — can jump up, S to drop
	oneway_platforms.append({"x": 26 * tile_size, "y": (grid_rows - 8) * tile_size, "w": 5 * tile_size})
	oneway_platforms.append({"x": 32 * tile_size, "y": (grid_rows - 6) * tile_size, "w": 4 * tile_size})

	# Tutorial labels in caves
	caves.append({"x": 5 * tile_size, "y": (grid_rows - 3) * tile_size, "floor_y": float((grid_rows - 3) * tile_size), "type": "start"})
	caves.append({"x": 40 * tile_size, "y": (grid_rows - 3) * tile_size, "floor_y": float((grid_rows - 3) * tile_size), "type": "door"})

	_build_collision()
	_build_oneway_platforms()

	# Add torches for light
	var torch_script = load("res://scripts/torch.gd")
	for tx in [8, 20, 30, 40]:
		var t = Node2D.new()
		t.set_script(torch_script)
		t.position = Vector2(tx * tile_size, (grid_rows - 4) * tile_size)
		torch_positions.append(t.position)
		add_child(t)

	# Tutorial door at end
	_spawn_door()

func _setup_axe_boss_room():
	# Чистая плоская арена: сплошной пол, стены, пара платформ для манёвра.
	rock_color = Color(0.32, 0.14, 0.16)
	rock_dark = Color(0.18, 0.07, 0.09)
	rock_light = Color(0.55, 0.25, 0.22)
	surface_color = Color(0.65, 0.30, 0.28)
	bg_color = Color(0.08, 0.02, 0.03)
	lava_y = 99999.0   # нет лавы

	grid.clear()
	for r in grid_rows:
		var row = []
		for c in grid_cols:
			# Боковые стены + потолок (2 тайла)
			if c < 2 or c >= grid_cols - 2 or r < 2:
				row.append(1)
			else:
				row.append(0)
		grid.append(row)

	# Сплошной пол по всей ширине
	var floor_r = grid_rows - 3
	for c in range(grid_cols):
		grid[floor_r][c] = 1
		grid[floor_r + 1][c] = 1
		if floor_r + 2 < grid_rows:
			grid[floor_r + 2][c] = 1

	# 2 боковые платформы для уклонения (левая повыше, правая пониже)
	var pf_r1 = floor_r - 6
	for dc in range(6):
		grid[pf_r1][4 + dc] = 1
	var pf_r2 = floor_r - 9
	for dc in range(6):
		grid[pf_r2][grid_cols - 10 + dc] = 1
	# Центральная небольшая платформа
	for dc in range(5):
		grid[floor_r - 4][grid_cols / 2 - 2 + dc] = 1

	_build_collision()

	# Старт игрока — левый край на полу
	caves.append({
		"x": 100.0,
		"y": float((floor_r - 2) * tile_size),
		"w": 140.0, "h": 32.0,
		"type": "start",
		"floor_y": float(floor_r * tile_size)
	})
	# Дверь (появится после победы) — правый край на полу
	caves.append({
		"x": float((grid_cols - 5) * tile_size),
		"y": float((floor_r - 2) * tile_size),
		"w": 100.0, "h": 32.0,
		"type": "door",
		"floor_y": float(floor_r * tile_size)
	})

	# Спавн Палача — на полу, в центре-справа (на твёрдом полу)
	golem_boss = CharacterBody2D.new()
	golem_boss.set_script(axe_killer_script)
	golem_boss.position = Vector2(room_width * 0.65, (floor_r - 1) * tile_size)
	golem_boss.setup(player_ref)
	golem_boss.boss_defeated.connect(_on_golem_defeated)
	add_child(golem_boss)

	# Факелы по углам
	var torch_spots = [
		Vector2(4 * tile_size, (floor_r - 2) * tile_size - 8),
		Vector2((grid_cols - 5) * tile_size, (floor_r - 2) * tile_size - 8),
		Vector2(grid_cols / 2 * tile_size, (floor_r - 6) * tile_size - 8),
	]
	for tpos in torch_spots:
		var torch = Node2D.new()
		torch.set_script(torch_script)
		torch.position = tpos
		torch_positions.append(tpos)
		add_child(torch)

	_create_tile_layer()
	is_cleared = false

func _create_tile_layer():
	# Создаёт кэш-слой статичных тайлов (вызывается и в обычных, и в boss-комнатах)
	tile_layer = Node2D.new()
	tile_layer.set_script(load("res://scripts/tile_layer.gd"))
	add_child(tile_layer)
	tile_layer.render(self)

func _setup_lava_boss_room():
	# Вертикальная башня: карабкаешься вверх к двери, снизу поднимается лава.
	rock_color = Color(0.40, 0.18, 0.12)
	rock_dark = Color(0.25, 0.10, 0.08)
	rock_light = Color(0.70, 0.35, 0.18)
	surface_color = Color(0.80, 0.42, 0.20)
	bg_color = Color(0.10, 0.02, 0.01)

	# Грид: только боковые стены, внутри — платформы
	grid.clear()
	for r in grid_rows:
		var row = []
		for c in grid_cols:
			# Боковые стены (2 тайла) + потолок
			if c < 2 or c >= grid_cols - 2 or r < 2:
				row.append(1)
			else:
				row.append(0)
		grid.append(row)

	# Стартовый пол внизу
	var bottom_r = grid_rows - 3
	for c in range(2, grid_cols - 2):
		grid[bottom_r][c] = 1
		grid[bottom_r + 1][c] = 1

	# Зигзаг платформ вверх (чередуем лево/право, разрыв 3 тайла = доступно прыжком)
	var plat_r = bottom_r - 3
	var go_left = true
	while plat_r > 5:
		var plat_w = 6
		var px_start
		if go_left:
			px_start = 3
		else:
			px_start = grid_cols - 3 - plat_w
		for dc in range(plat_w):
			var nc = px_start + dc
			if nc >= 2 and nc < grid_cols - 2:
				grid[plat_r][nc] = 1
		go_left = not go_left
		plat_r -= 3

	# Верхняя площадка у двери
	for c in range(2, grid_cols - 2):
		grid[4][c] = 1

	_build_collision()

	# Старт — внизу
	caves.append({
		"x": float((grid_cols / 2) * tile_size),
		"y": float((bottom_r - 2) * tile_size),
		"w": 120.0, "h": 32.0,
		"type": "start",
		"floor_y": float(bottom_r * tile_size)
	})
	# Дверь — наверху
	caves.append({
		"x": float((grid_cols / 2) * tile_size),
		"y": float(5 * tile_size),
		"w": 120.0, "h": 32.0,
		"type": "door",
		"floor_y": float(5 * tile_size)
	})

	# Лава стартует ниже пола, медленно поднимается
	lava_rise_y = room_height + 20.0
	lava_y = lava_rise_y

	# Спавн лавового стража
	golem_boss = CharacterBody2D.new()
	golem_boss.set_script(lava_boss_script)
	golem_boss.position = Vector2(room_width * 0.5, room_height - 250)
	golem_boss.setup(player_ref)
	golem_boss.boss_defeated.connect(_on_golem_defeated)
	add_child(golem_boss)

	_spawn_door()
	_create_tile_layer()
	# Дверь наверху доступна сразу — цель добраться, паркуря и уклоняясь от лавы.
	# Убийство Лавового Стража необязательно, но останавливает лаву.
	is_cleared = true

func _setup_boss_room():
	# Open arena with lava pit, multi-level platforms, and the golem in center
	rock_color = Color(0.38, 0.35, 0.35)
	rock_dark = Color(0.25, 0.22, 0.22)
	rock_light = Color(0.6, 0.35, 0.2)
	surface_color = Color(0.65, 0.4, 0.22)
	bg_color = Color(0.04, 0.01, 0.01)

	lava_y = room_height - 60

	# Initialize empty grid
	grid.clear()
	for r in grid_rows:
		var row = []
		for c in grid_cols:
			row.append(0)
		grid.append(row)

	# Walls only on sides and ceiling (2 tiles thick)
	for r in grid_rows:
		for c in grid_cols:
			if r < 2 or c < 2 or c >= grid_cols - 2:
				grid[r][c] = 1

	var center_c = grid_cols / 2  # ~37
	var center_r = grid_rows / 2  # ~21

	# === MAIN FLOOR — wide open arena floor with lava pit in center ===
	var floor_r = grid_rows - 5  # row 38
	# Left solid floor
	for c in range(2, center_c - 8):
		grid[floor_r][c] = 1
		grid[floor_r + 1][c] = 1
	# Right solid floor
	for c in range(center_c + 8, grid_cols - 2):
		grid[floor_r][c] = 1
		grid[floor_r + 1][c] = 1

	# Lava pit in center bottom (deadly gap)
	var lava_row = grid_rows - 3
	for c in range(2, grid_cols - 2):
		for r in range(lava_row, grid_rows):
			grid[r][c] = 1

	# === GOLEM PEDESTAL — raised center platform ===
	var ped_r = center_r + 3  # slightly below center
	for dc in range(-5, 6):
		var nc = center_c + dc
		if nc >= 0 and nc < grid_cols:
			grid[ped_r][nc] = 1
			grid[ped_r + 1][nc] = 1
	# Pedestal pillars (left and right support columns)
	for dr in range(ped_r + 2, floor_r):
		grid[dr][center_c - 5] = 1
		grid[dr][center_c - 4] = 1
		grid[dr][center_c + 5] = 1
		grid[dr][center_c + 4] = 1

	# === UPPER PLATFORMS — for dodging meteors ===
	# Upper left balcony
	for dc in range(0, 10):
		grid[center_r - 6][4 + dc] = 1
	# Upper right balcony
	for dc in range(0, 10):
		grid[center_r - 6][grid_cols - 14 + dc] = 1
	# Top center platform (above golem — risky but strategic)
	for dc in range(-4, 5):
		grid[center_r - 12][center_c + dc] = 1

	# === MID-LEVEL FLOATING PLATFORMS — around golem ===
	# Left mid
	for dc in range(0, 7):
		grid[center_r][8 + dc] = 1
	# Right mid
	for dc in range(0, 7):
		grid[center_r][grid_cols - 15 + dc] = 1

	# === SMALL STEPPING STONES over lava pit ===
	# Left bridge stones (3 small platforms over lava)
	for dc in range(0, 3):
		grid[floor_r][center_c - 6 + dc] = 1
	for dc in range(0, 3):
		grid[floor_r - 2][center_c - 3 + dc] = 1
	for dc in range(0, 3):
		grid[floor_r][center_c + 4 + dc] = 1

	# === CHAINS / WALL DETAILS ===
	# Hanging chains from ceiling (decorative columns)
	for dr in range(2, center_r - 8):
		grid[dr][10] = 1
		grid[dr][grid_cols - 11] = 1

	_build_collision()

	# Player start — left floor
	caves.append({
		"x": 80.0,
		"y": float((floor_r - 2) * tile_size),
		"w": 160.0, "h": 32.0,
		"type": "start",
		"floor_y": float(floor_r * tile_size)
	})

	# Spawn boss — уровень 5 = Палач с Топором, иначе голем
	golem_boss = CharacterBody2D.new()
	if room_level == 5:
		golem_boss.set_script(axe_killer_script)
		golem_boss.position = Vector2(center_c * tile_size, (floor_r - 2) * tile_size)
		golem_boss.setup(player_ref)
		golem_boss.boss_defeated.connect(_on_golem_defeated)
	else:
		golem_boss.set_script(golem_script)
		golem_boss.position = Vector2(center_c * tile_size, ped_r * tile_size - 1)
		golem_boss.setup(player_ref)
		golem_boss.golem_defeated.connect(_on_golem_defeated)
	add_child(golem_boss)

	is_cleared = false

	# Torches — spread across platforms for atmosphere
	var torch_spots = [
		Vector2(6 * tile_size, (center_r - 6) * tile_size - 8),     # upper left
		Vector2((grid_cols - 8) * tile_size, (center_r - 6) * tile_size - 8),  # upper right
		Vector2(10 * tile_size, center_r * tile_size - 8),           # mid left
		Vector2((grid_cols - 10) * tile_size, center_r * tile_size - 8),  # mid right
		Vector2(80, floor_r * tile_size - 8),                        # start area
		Vector2((grid_cols - 6) * tile_size, floor_r * tile_size - 8),  # right floor
		Vector2(center_c * tile_size, (center_r - 12) * tile_size - 8),  # top center
	]
	for tpos in torch_spots:
		var torch = Node2D.new()
		torch.set_script(torch_script)
		torch.position = tpos
		torch_positions.append(tpos)
		add_child(torch)

	# Без этого вызова пол и стены не отрисовываются
	_create_tile_layer()

func _on_golem_defeated():
	is_cleared = true
	room_cleared.emit()
	if is_lava_boss:
		# Лава перестаёт подниматься, дверь уже наверху — её не двигаем
		lava_rise_speed = 0.0
		return
	# Дверь появляется на месте door-cave (правый край арены Палача)
	_spawn_door()

func setup_future_arena(p_player_ref: CharacterBody2D):
	# Special arena for the final boss — "Future Self"
	# Mirror world aesthetic: dark purple, symmetrical, open
	room_level = 10
	player_ref = p_player_ref
	lava_y = 99999.0  # No lava in this arena
	is_boss_room = true
	room_width = 1200.0
	room_height = 700.0
	grid_cols = int(room_width / tile_size)
	grid_rows = int(room_height / tile_size)
	floor_y = room_height - tile_size * 5

	# Dark mirror colors
	rock_color = Color(0.3, 0.28, 0.38)
	rock_dark = Color(0.2, 0.18, 0.28)
	rock_light = Color(0.35, 0.2, 0.45)
	surface_color = Color(0.4, 0.25, 0.55)
	bg_color = Color(0.03, 0.01, 0.05)

	# Initialize empty grid
	grid.clear()
	for r in grid_rows:
		var row = []
		for c in grid_cols:
			row.append(0)
		grid.append(row)

	# Borders — thick walls
	for r in grid_rows:
		for c in grid_cols:
			if r < 3 or c < 2 or c >= grid_cols - 2:
				grid[r][c] = 1

	var center_c = grid_cols / 2

	# === MAIN FLOOR — wide open flat arena ===
	var floor_row = grid_rows - 5
	for c in range(2, grid_cols - 2):
		grid[floor_row][c] = 1
		grid[floor_row + 1][c] = 1

	# Bottom fill
	for c in range(2, grid_cols - 2):
		for r in range(floor_row + 2, grid_rows):
			grid[r][c] = 1

	# === OPEN PLATFORMS — no blocks, just thin platforms to jump on ===
	# Low side platforms (easy to reach from floor)
	var low_r = floor_row - 6
	for dc in range(0, 7):
		grid[low_r][5 + dc] = 1
		grid[low_r][grid_cols - 12 + dc] = 1

	# Mid floating platforms (center area)
	var mid_r = floor_row - 12
	for dc in range(-4, 5):
		grid[mid_r][center_c + dc] = 1

	# High side platforms
	var high_r = floor_row - 18
	for dc in range(0, 5):
		grid[high_r][10 + dc] = 1
		grid[high_r][grid_cols - 15 + dc] = 1

	# Small stepping stones between levels
	var step_r1 = floor_row - 9
	for dc in range(0, 3):
		grid[step_r1][20 + dc] = 1
		grid[step_r1][grid_cols - 23 + dc] = 1

	var step_r2 = floor_row - 15
	for dc in range(0, 3):
		grid[step_r2][18 + dc] = 1
		grid[step_r2][grid_cols - 21 + dc] = 1

	_build_collision()

	# Start cave for player positioning
	caves.append({
		"x": 100.0,
		"y": float((floor_row - 2) * tile_size),
		"w": 160.0, "h": 32.0,
		"type": "start",
		"floor_y": float(floor_row * tile_size)
	})

	is_cleared = false

	# Purple-tinted torches
	var torch_spots = [
		Vector2(8 * tile_size, low_r * tile_size - 8),
		Vector2((grid_cols - 10) * tile_size, low_r * tile_size - 8),
		Vector2(6 * tile_size, mid_r * tile_size - 8),
		Vector2((grid_cols - 8) * tile_size, mid_r * tile_size - 8),
		Vector2(center_c * tile_size, high_r * tile_size - 8),
		Vector2(100, floor_row * tile_size - 8),
		Vector2(room_width - 100, floor_row * tile_size - 8),
		Vector2(center_c * tile_size, floor_row * tile_size - 8),
	]
	for tpos in torch_spots:
		var torch = Node2D.new()
		torch.set_script(torch_script)
		torch.position = tpos
		# Purple tint for mirror world
		torch.color = Color(0.7, 0.4, 1.0)
		torch_positions.append(tpos)
		add_child(torch)

	# Без этого вызова пол и стены финальной арены не отрисовываются
	_create_tile_layer()

func _determine_challenge_type():
	# Level 1: hard lockpick (difficulty 4)
	# Level 2: spear shieldmen guardians
	# Level 3: crystal defense
	# Level 4+: lockpick (normal scaling)
	# Pattern repeats: 5=guardians, 6=crystal, 7+=lockpick, etc.
	var cycle = (room_level - 1) % 3
	match cycle:
		0:  # Levels 1, 4, 7...
			challenge_type = "lockpick"
		1:  # Levels 2, 5, 8...
			challenge_type = "guardians"
		2:  # Levels 3, 6, 9...
			challenge_type = "crystal"

func get_location_num() -> int:
	return clampi((room_level - 1) / 4, 0, 2)

func _set_biome(level: int):
	# Мясная комната — особая палитра кровавой плоти
	if is_meat_room:
		rock_color = Color(0.65, 0.20, 0.35)
		rock_dark  = Color(0.35, 0.05, 0.18)
		rock_light = Color(0.88, 0.35, 0.55)
		surface_color = Color(0.95, 0.55, 0.70)
		bg_color = Color(0.15, 0.03, 0.10)
		return
	var loc = get_location_num()
	# === LUCID BLOCKS-STYLE PALETTE: pastel teal/lavender/pink/cream ===
	match loc:
		0:  # Зона 1 — Лавандово-розовая (dreamy intro)
			match (level - 1) % 4:
				0:
					rock_color    = Color(0.62, 0.55, 0.78)  # лавандовый
					rock_dark     = Color(0.40, 0.32, 0.55)
					rock_light    = Color(0.85, 0.78, 0.95)
					surface_color = Color(0.92, 0.82, 0.95)
					bg_color      = Color(0.12, 0.10, 0.22)
				1:
					rock_color    = Color(0.70, 0.55, 0.78)  # розово-лиловый
					rock_dark     = Color(0.45, 0.30, 0.55)
					rock_light    = Color(0.95, 0.80, 0.95)
					surface_color = Color(1.00, 0.85, 0.95)
					bg_color      = Color(0.15, 0.08, 0.22)
				2:
					rock_color    = Color(0.55, 0.72, 0.85)  # небесно-aqua
					rock_dark     = Color(0.32, 0.50, 0.65)
					rock_light    = Color(0.80, 0.92, 1.00)
					surface_color = Color(0.85, 0.95, 1.00)
					bg_color      = Color(0.08, 0.15, 0.22)
				3:
					rock_color    = Color(0.78, 0.65, 0.85)  # вечерняя сирень
					rock_dark     = Color(0.50, 0.40, 0.62)
					rock_light    = Color(0.95, 0.85, 0.98)
					surface_color = Color(1.00, 0.90, 0.95)
					bg_color      = Color(0.20, 0.12, 0.25)
		1:  # Зона 2 — Aqua/teal liminal "underwater"
			match (level - 1) % 4:
				0:
					rock_color    = Color(0.40, 0.70, 0.78)
					rock_dark     = Color(0.20, 0.45, 0.55)
					rock_light    = Color(0.65, 0.88, 0.95)
					surface_color = Color(0.75, 0.92, 0.98)
					bg_color      = Color(0.05, 0.12, 0.18)
				1:
					rock_color    = Color(0.50, 0.75, 0.85)
					rock_dark     = Color(0.28, 0.50, 0.62)
					rock_light    = Color(0.78, 0.92, 1.00)
					surface_color = Color(0.85, 0.95, 1.00)
					bg_color      = Color(0.08, 0.15, 0.20)
				2:
					rock_color    = Color(0.45, 0.62, 0.85)  # морской ультрамарин
					rock_dark     = Color(0.22, 0.38, 0.58)
					rock_light    = Color(0.70, 0.85, 1.00)
					surface_color = Color(0.80, 0.88, 1.00)
					bg_color      = Color(0.05, 0.10, 0.22)
				3:
					rock_color    = Color(0.55, 0.80, 0.75)  # mint
					rock_dark     = Color(0.30, 0.55, 0.50)
					rock_light    = Color(0.78, 0.95, 0.90)
					surface_color = Color(0.85, 1.00, 0.95)
					bg_color      = Color(0.06, 0.15, 0.13)
		2:  # Зона 3 — пинк/peach/cream — final dream realm
			match (level - 1) % 4:
				0:
					rock_color    = Color(0.92, 0.62, 0.72)  # коралл
					rock_dark     = Color(0.65, 0.35, 0.50)
					rock_light    = Color(1.00, 0.85, 0.90)
					surface_color = Color(1.00, 0.92, 0.92)
					bg_color      = Color(0.25, 0.12, 0.18)
				1:
					rock_color    = Color(0.95, 0.78, 0.65)  # peach
					rock_dark     = Color(0.65, 0.48, 0.35)
					rock_light    = Color(1.00, 0.92, 0.82)
					surface_color = Color(1.00, 0.95, 0.88)
					bg_color      = Color(0.22, 0.15, 0.10)
				2:
					rock_color    = Color(0.85, 0.70, 0.95)  # лавандово-розовый
					rock_dark     = Color(0.55, 0.42, 0.70)
					rock_light    = Color(1.00, 0.88, 1.00)
					surface_color = Color(1.00, 0.95, 1.00)
					bg_color      = Color(0.20, 0.12, 0.30)
				3:
					rock_color    = Color(0.98, 0.85, 0.70)  # cream-pink
					rock_dark     = Color(0.70, 0.55, 0.42)
					rock_light    = Color(1.00, 0.95, 0.85)
					surface_color = Color(1.00, 0.98, 0.92)
					bg_color      = Color(0.20, 0.15, 0.10)

func _generate_cave():
	grid.clear()
	explored.clear()
	caves.clear()
	platforms.clear()
	chests.clear()
	ladders.clear()
	oneway_platforms.clear()
	spikes.clear()
	poison_pipes.clear()
	pressure_plates.clear()

	# Initialize grid — all solid; explored — все false
	for r in grid_rows:
		var row = []
		var erow = []
		for c in grid_cols:
			erow.append(false)
		explored.append(erow)
		for c in grid_cols:
			row.append(1)
		grid.append(row)

	# === ROOM-GRID like the reference image ===
	# Dense rooms with platforms, wall ledges, pillars
	var rooms_x = 6
	var rooms_y = 5
	var cell_w = (grid_cols - 6) / rooms_x   # ~32 tiles
	var cell_h = (grid_rows - 6) / rooms_y   # ~16 tiles
	var wall_t = 2
	var room_data: Array = []

	# Create rooms — NOT all rooms are carved (some stay solid = variety)
	var room_active: Array = []  # which rooms exist
	for ry in rooms_y:
		for rx in rooms_x:
			# 80% chance room exists, always for start corner + edges
			var active = randf() < 0.80
			if (ry == rooms_y - 1 and rx == 0):
				active = true  # start
			# Always active on edges for connectivity
			if ry == 0 or ry == rooms_y - 1 or rx == 0 or rx == rooms_x - 1:
				active = true
			room_active.append(active)

			var c_left = 3 + rx * cell_w + wall_t
			var c_right = 3 + (rx + 1) * cell_w - wall_t
			var r_top = 3 + ry * cell_h + wall_t
			var r_bot = 3 + (ry + 1) * cell_h - wall_t

			if active:
				for r in range(r_top, r_bot + 1):
					for c in range(c_left, c_right + 1):
						if r >= 0 and r < grid_rows and c >= 0 and c < grid_cols:
							grid[r][c] = 0

			room_data.append({
				"rx": rx, "ry": ry,
				"r_top": r_top, "r_bot": r_bot,
				"c_left": c_left, "c_right": c_right,
				"active": active,
			})

	# Add floor at bottom of each active room
	for rd in room_data:
		if not rd.active:
			continue
		for c in range(rd.c_left - 1, rd.c_right + 2):
			if c >= 0 and c < grid_cols and rd.r_bot + 1 < grid_rows:
				grid[rd.r_bot + 1][c] = 1

	# === BUILD FIXED START ROOM (bottom-left) ===
	var start_room_idx = (rooms_y - 1) * rooms_x + 0
	_build_start_room(room_data[start_room_idx])

	# === FILL ROOMS with content ===
	for i_rd in room_data.size():
		if i_rd == start_room_idx:
			continue  # start room has fixed layout
		var rd = room_data[i_rd]
		if not rd.active:
			continue
		var rw = rd.c_right - rd.c_left
		var rh = rd.r_bot - rd.r_top

		# Choose room type based on shape + randomness
		var rtype: String
		var roll = randf()
		if rw <= 14 and rh >= 10:
			rtype = "tower"
		elif rw >= 20 and rh >= 12:
			rtype = "shaft"
		elif roll < 0.08 and i_rd != start_room_idx:
			rtype = "treasury"
		elif roll < 0.15 and i_rd != start_room_idx:
			rtype = "training"
		elif roll < 0.40:
			rtype = "basement"
		elif roll < 0.65:
			rtype = "ruins"
		else:
			rtype = "normal"

		# --- Wavy floor (all types except tower/shaft for cleaner jumps) ---
		if rtype == "ruins" or rtype == "basement" or rtype == "normal":
			var wf_phase = randf() * TAU
			var wf_amp = 2 if rtype == "ruins" else 1
			for c in range(rd.c_left, rd.c_right + 1):
				var wave = int(round((sin((c - rd.c_left) * 0.45 + wf_phase) + 1.0) * float(wf_amp) * 0.5))
				for dr in range(wave):
					var fr = rd.r_bot - dr
					if fr >= rd.r_top + 5 and fr < grid_rows:
						grid[fr][c] = 1

		# --- Wavy ceiling / stalactites (all types) ---
		var wc_phase = randf() * TAU
		var wc_count = randi_range(3, 6)
		for _s in wc_count:
			var sc = randi_range(rd.c_left + 1, rd.c_right - 2)
			var sh = randi_range(1, 4)
			var sw = randi_range(1, 3)
			for dc in range(sw):
				for dr in range(sh):
					var sr = rd.r_top + dr
					var tc = sc + dc
					if sr <= rd.r_bot - 5 and sr >= 0 and tc <= rd.c_right:
						grid[sr][tc] = 1

		# --- Room-type specific content ---
		match rtype:
			"tower":
				# Staggered zigzag platforms — jump up left/right alternating
				var step = maxi(3, rh / 5)
				var from_left = true
				var pr = rd.r_bot - 2
				while pr > rd.r_top + 3:
					var pw = randi_range(rw / 3, rw * 2 / 3)
					pw = mini(pw, rw - 3)
					var pc = rd.c_left + 2 if from_left else rd.c_right - pw - 2
					pc = clampi(pc, rd.c_left + 1, rd.c_right - pw - 1)
					if pw > 2:
						oneway_platforms.append({
							"x": float(pc * tile_size), "y": float(pr * tile_size),
							"w": float(pw * tile_size), "r": pr, "c": pc, "tw": pw,
						})
					from_left = not from_left
					pr -= randi_range(step - 1, step + 1)
				# Side wall nubs (decorative ledges, not walkable)
				for _n in randi_range(2, 4):
					var nr = randi_range(rd.r_top + 2, rd.r_bot - 2)
					var nw = randi_range(2, 4)
					var from_l = randf() < 0.5
					for dc in range(nw):
						var nc = (rd.c_left + dc) if from_l else (rd.c_right - dc)
						if nc >= rd.c_left and nc <= rd.c_right and nr < grid_rows:
							grid[nr][nc] = 1

			"basement":
				# Heavy floor pillars with platforms on top, wide open ceiling
				var num_pillars = randi_range(2, 4)
				var spacing = rw / (num_pillars + 1)
				for p in num_pillars:
					var pc = rd.c_left + int(spacing * (p + 1))
					var ph = randi_range(rh / 3, rh * 2 / 3)
					var pw2 = randi_range(2, 3)
					for dc in range(pw2):
						for dr in range(ph):
							var pr2 = rd.r_bot - dr
							var tc = pc + dc
							if pr2 >= rd.r_top + 3 and tc <= rd.c_right:
								grid[pr2][tc] = 1
					# Platform on pillar top
					var plat_c = maxi(rd.c_left + 1, pc - 2)
					var plat_w = mini(7, rd.c_right - plat_c - 1)
					if plat_w > 2:
						oneway_platforms.append({
							"x": float(plat_c * tile_size),
							"y": float((rd.r_bot - ph) * tile_size),
							"w": float(plat_w * tile_size),
							"r": rd.r_bot - ph, "c": plat_c, "tw": plat_w,
						})
				# Extra floating platforms between pillars
				for _e in randi_range(2, 4):
					var epr = randi_range(rd.r_top + 3, rd.r_bot - 4)
					var epw = randi_range(4, mini(10, rw - 4))
					var epc = randi_range(rd.c_left + 1, maxi(rd.c_left + 2, rd.c_right - epw))
					oneway_platforms.append({
						"x": float(epc * tile_size), "y": float(epr * tile_size),
						"w": float(epw * tile_size), "r": epr, "c": epc, "tw": epw,
					})

			"ruins":
				# Rubble mounds on floor + broken archways + irregular platforms
				for _r2 in randi_range(3, 5):
					var rc = randi_range(rd.c_left + 2, rd.c_right - 5)
					var rlen = randi_range(3, 6)
					var rheight = randi_range(1, 4)
					for dc in range(rlen):
						for dr in range(rheight):
							# Slope shape: taller in middle
							var mid_dist = abs(dc - rlen / 2)
							var max_h = rheight - mid_dist / 2
							if dr < max_h:
								var tr = rd.r_bot - dr
								var tc = rc + dc
								if tr >= rd.r_top + 4 and tc <= rd.c_right:
									grid[tr][tc] = 1
				# Broken arch (two pillars with a gap between)
				if rw > 14:
					for _arch in randi_range(1, 2):
						var ac = randi_range(rd.c_left + 3, rd.c_right - 9)
						var ah = randi_range(3, mini(6, rh - 4))
						var gap = randi_range(3, 5)
						for dr in range(ah):
							var ar = rd.r_bot - dr
							if ar >= rd.r_top + 3:
								grid[ar][ac] = 1
								if ac + 1 <= rd.c_right: grid[ar][ac + 1] = 1
								var rc2 = ac + gap + 2
								if rc2 <= rd.c_right: grid[ar][rc2] = 1
								if rc2 + 1 <= rd.c_right: grid[ar][rc2 + 1] = 1
				# Platforms at irregular heights
				var used_rows2: Array = []
				for _p2 in randi_range(3, 6):
					var pr3 = randi_range(rd.r_top + 3, rd.r_bot - 3)
					var too_close2 = false
					for ur2 in used_rows2:
						if abs(pr3 - ur2) < 3: too_close2 = true
					if too_close2: continue
					used_rows2.append(pr3)
					var pw3 = randi_range(3, mini(10, rw - 4))
					var pc3 = randi_range(rd.c_left + 1, maxi(rd.c_left + 2, rd.c_right - pw3))
					oneway_platforms.append({
						"x": float(pc3 * tile_size), "y": float(pr3 * tile_size),
						"w": float(pw3 * tile_size), "r": pr3, "c": pc3, "tw": pw3,
					})

			"shaft":
				# Alternating ledges from walls — zigzag path upward
				var step2 = maxi(2, rh / 7)
				var from_left2 = true
				var pr4 = rd.r_bot - 2
				while pr4 > rd.r_top + 3:
					var lw = randi_range(rw / 3, rw * 2 / 3)
					lw = mini(lw, rw - 3)
					var lc = rd.c_left + 1 if from_left2 else rd.c_right - lw
					lc = clampi(lc, rd.c_left + 1, rd.c_right - lw)
					oneway_platforms.append({
						"x": float(lc * tile_size), "y": float(pr4 * tile_size),
						"w": float(lw * tile_size), "r": pr4, "c": lc, "tw": lw,
					})
					from_left2 = not from_left2
					pr4 -= randi_range(step2, step2 + 2)

			"treasury":
				# Many chests + heavy spike traps — rich but dangerous
				for _tc in randi_range(2, 4):
					var tx = float(randi_range(rd.c_left + 3, rd.c_right - 3) * tile_size)
					var ty = float(rd.r_bot * tile_size) - 10
					_place_chest(tx, ty)
				# Extra spike density
				for _ts in randi_range(6, 12):
					var sc2 = randi_range(rd.c_left + 1, rd.c_right - 2)
					var sw2 = randi_range(2, 4)
					var overlap2 = false
					for esp in spikes:
						if abs(sc2 - int(esp.x / tile_size)) < 3: overlap2 = true
					if not overlap2:
						spikes.append({"x": float(sc2 * tile_size), "y": float(rd.r_bot * tile_size), "w": float(sw2 * tile_size)})
				# A few platforms to make it navigable
				for _tp in randi_range(2, 4):
					var pr_t = randi_range(rd.r_top + 3, rd.r_bot - 3)
					var pw_t = randi_range(5, mini(12, rw - 4))
					var pc_t = randi_range(rd.c_left + 1, maxi(rd.c_left + 2, rd.c_right - pw_t))
					oneway_platforms.append({"x": float(pc_t * tile_size), "y": float(pr_t * tile_size),
						"w": float(pw_t * tile_size), "r": pr_t, "c": pc_t, "tw": pw_t})

			"training":
				# Wooden dummy pillars + practice platforms, no traps
				for _td in randi_range(2, 3):
					var dc = randi_range(rd.c_left + 4, rd.c_right - 6)
					# Thick post from floor
					for dr_t in range(5):
						var tr_t = rd.r_bot - dr_t
						if tr_t >= rd.r_top + 2:
							grid[tr_t][dc] = 1
							grid[tr_t][dc + 1] = 1
				# Multiple platforms at regular heights
				var tp_step = maxi(3, rh / 5)
				var tp_r = rd.r_bot - 3
				var tp_left = true
				while tp_r > rd.r_top + 3:
					var tpw = randi_range(rw / 3, rw * 2 / 3)
					tpw = mini(tpw, rw - 4)
					var tpc = rd.c_left + 2 if tp_left else rd.c_right - tpw - 2
					tpc = clampi(tpc, rd.c_left + 1, rd.c_right - tpw - 1)
					if tpw > 2:
						oneway_platforms.append({"x": float(tpc * tile_size), "y": float(tp_r * tile_size),
							"w": float(tpw * tile_size), "r": tp_r, "c": tpc, "tw": tpw})
					tp_left = not tp_left
					tp_r -= randi_range(tp_step - 1, tp_step + 1)

			_: # "normal" — wall ledges + pillars + scattered platforms
				for _l in randi_range(2, 4):
					var from_left3 = randf() < 0.5
					var ledge_r = randi_range(rd.r_top + 3, rd.r_bot - 2)
					var ledge_w = randi_range(3, mini(8, maxi(3, rw / 3)))
					var lc2 = rd.c_left if from_left3 else rd.c_right - ledge_w + 1
					for dc2 in range(ledge_w):
						var nc = lc2 + dc2
						if nc >= rd.c_left and nc <= rd.c_right:
							grid[ledge_r][nc] = 1
							if ledge_r + 1 <= rd.r_bot: grid[ledge_r + 1][nc] = 1
				if rw > 15:
					for _p3 in randi_range(1, 2):
						var pc4 = randi_range(rd.c_left + 4, rd.c_right - 4)
						var ph2 = randi_range(3, mini(6, rh - 3))
						for dr2 in range(ph2):
							var pr5 = rd.r_bot - dr2
							if pr5 >= rd.r_top + 2:
								grid[pr5][pc4] = 1
								if pc4 + 1 <= rd.c_right: grid[pr5][pc4 + 1] = 1
				var used_rows3: Array = []
				for _p4 in randi_range(4, 8):
					var pr6 = randi_range(rd.r_top + 2, rd.r_bot - 2)
					var too_close3 = false
					for ur3 in used_rows3:
						if abs(pr6 - ur3) < 2: too_close3 = true
					if too_close3: continue
					used_rows3.append(pr6)
					var pw4 = randi_range(5, mini(16, maxi(5, rw - 4)))
					var pc5 = randi_range(rd.c_left + 1, maxi(rd.c_left + 2, rd.c_right - pw4))
					var blocked2 = false
					for lad2 in ladders:
						if lad2.col >= pc5 and lad2.col <= pc5 + pw4: blocked2 = true
					if blocked2: continue
					oneway_platforms.append({
						"x": float(pc5 * tile_size), "y": float(pr6 * tile_size),
						"w": float(pw4 * tile_size), "r": pr6, "c": pc5, "tw": pw4,
					})

		# --- Traps (all room types) ---
		if rw > 6:
			for _si in randi_range(3, 7):
				var spike_c = randi_range(rd.c_left + 1, rd.c_right - 3)
				var spike_w = randi_range(2, 3)
				var overlap = false
				for existing_sp in spikes:
					var ex = existing_sp.x / tile_size
					var ew = existing_sp.w / tile_size
					if spike_c < ex + ew + 2 and spike_c + spike_w > ex - 2:
						overlap = true; break
				if not overlap:
					spikes.append({
						"x": float(spike_c * tile_size),
						"y": float(rd.r_bot * tile_size),
						"w": float(spike_w * tile_size),
					})
		if randf() < 0.3 and rw > 8:
			var pool_w = randi_range(5, 8)
			var pool_c = randi_range(rd.c_left + 2, maxi(rd.c_left + 3, rd.c_right - pool_w - 1))
			var pool_h = randi_range(8, 14)
			var has_pipe = randf() < 0.5
			var pipe_x = 0.0; var pipe_y = 0.0; var pipe_dir = 1.0
			if has_pipe:
				var from_left4 = pool_c - rd.c_left < rd.c_right - (pool_c + pool_w)
				pipe_x = float((rd.c_left if from_left4 else rd.c_right) * tile_size)
				pipe_y = float(randi_range(rd.r_bot - 4, rd.r_bot - 2) * tile_size)
				pipe_dir = 1.0 if from_left4 else -1.0
			poison_pipes.append({
				"x": pipe_x, "y": pipe_y, "dir": pipe_dir, "has_pipe": has_pipe,
				"pool_x": float(pool_c * tile_size), "pool_y": float(rd.r_bot * tile_size),
				"pool_w": float(pool_w * tile_size), "pool_h": float(pool_h),
			})
		if randf() < 0.2 and rh > 6:
			var plate_c = randi_range(rd.c_left + 2, rd.c_right - 2)
			pressure_plates.append({
				"x": float(plate_c * tile_size), "y": float(rd.r_bot * tile_size),
				"triggered": false, "cooldown": 0.0, "arrows_shot": false, "r_top": rd.r_top,
			})

	# === CONNECT ROOMS horizontally ===
	for idx in room_data.size():
		var rd = room_data[idx]
		if not rd.active:
			continue
		var rx = rd.rx
		var ry = rd.ry
		if rx < rooms_x - 1:
			var right_idx = ry * rooms_x + rx + 1
			if not room_data[right_idx].active:
				continue
			if randf() < 0.85 or ry == rooms_y - 1 or ry == 0:
				var right_rd = room_data[right_idx]
				var open_r = rd.r_bot - randi_range(0, 1)
				var open_h = randi_range(4, 5)
				var wall_c_start = rd.c_right + 1
				var wall_c_end = right_rd.c_left - 1
				for r in range(open_r - open_h, open_r + 1):
					for c in range(wall_c_start, wall_c_end + 1):
						if r >= 0 and r < grid_rows and c >= 0 and c < grid_cols:
							grid[r][c] = 0
				for c in range(wall_c_start, wall_c_end + 1):
					if open_r + 1 < grid_rows and c >= 0 and c < grid_cols:
						grid[open_r + 1][c] = 1

	# === CONNECT ROOMS vertically (with ladders) ===
	for idx in room_data.size():
		var rd = room_data[idx]
		if not rd.active:
			continue
		var rx = rd.rx
		var ry = rd.ry
		if ry < rooms_y - 1:
			var below_idx = (ry + 1) * rooms_x + rx
			if not room_data[below_idx].active:
				continue
			if randf() < 0.65 or rx == 0 or rx == rooms_x - 1:
				var below_rd = room_data[below_idx]
				var open_c = randi_range(rd.c_left + 2, maxi(rd.c_left + 3, rd.c_right - 5))
				var open_w = randi_range(3, 4)
				# Open floor/ceiling
				for c in range(open_c, open_c + open_w):
					for r in range(rd.r_bot, below_rd.r_top + 1):
						if r >= 0 and r < grid_rows and c >= 0 and c < grid_cols:
							grid[r][c] = 0
				# Ladder right at the opening
				var ladder_c = open_c + open_w / 2
				ladders.append({
					"x": float(ladder_c * tile_size + tile_size / 2),
					"y_top": float((rd.r_bot - 3) * tile_size),
					"y_bottom": float((below_rd.r_top + 3) * tile_size),
					"col": ladder_c,
				})

	# === KEY AREAS ===
	var start_rd = room_data[(rooms_y - 1) * rooms_x + 0]
	var start_r = start_rd.r_bot
	var start_c = start_rd.c_left + 2
	caves.append({
		"x": float((start_rd.c_left + start_rd.c_right) / 2 * tile_size),
		"y": float(start_rd.r_top * tile_size),
		"w": float((start_rd.c_right - start_rd.c_left) * tile_size),
		"h": float((start_rd.r_bot - start_rd.r_top) * tile_size),
		"type": "start",
		"floor_y": float(start_rd.r_bot * tile_size)
	})

	# Pick a random room for the door (not the start room, far enough away)
	var start_idx = (rooms_y - 1) * rooms_x + 0
	var door_candidates: Array = []
	for i in room_data.size():
		if i == start_idx or not room_data[i].active:
			continue
		# Must be at least 2 rooms away from start (manhattan distance)
		var dx = absi(room_data[i].rx - room_data[start_idx].rx)
		var dy = absi(room_data[i].ry - room_data[start_idx].ry)
		if dx + dy >= 3:
			door_candidates.append(i)
	var door_idx = start_idx  # fallback
	if door_candidates.size() > 0:
		door_idx = door_candidates[randi() % door_candidates.size()]
	else:
		# fallback: top-right
		door_idx = 0 * rooms_x + rooms_x - 1
	var door_rd = room_data[door_idx]
	caves.append({
		"x": float((door_rd.c_left + door_rd.c_right) / 2 * tile_size),
		"y": float(door_rd.r_top * tile_size),
		"w": float((door_rd.c_right - door_rd.c_left) * tile_size),
		"h": float((door_rd.r_bot - door_rd.r_top) * tile_size),
		"type": "door",
		"floor_y": float(door_rd.r_bot * tile_size)
	})

	# Other active rooms as caves
	for i in room_data.size():
		var rd = room_data[i]
		if not rd.active:
			continue
		if i == start_idx or i == door_idx:
			continue
		var cave_type = "normal"
		caves.append({
			"x": float((rd.c_left + rd.c_right) / 2 * tile_size),
			"y": float(rd.r_top * tile_size),
			"w": float((rd.c_right - rd.c_left) * tile_size),
			"h": float((rd.r_bot - rd.r_top) * tile_size),
			"type": cave_type,
			"floor_y": float(rd.r_bot * tile_size)
		})

	# === CHESTS (in some rooms) ===
	var chest_count = 0
	var max_chests = 3 + room_level / 2
	max_chests = mini(max_chests, 7)
	var weapon_chest_placed = false
	for rd in room_data:
		if not rd.active or chest_count >= max_chests:
			continue
		if randf() < 0.25:  # 25% chance per room (up from 15%)
			var cx = float((rd.c_left + rd.c_right) / 2 * tile_size)
			var cy = float(rd.r_bot * tile_size) - 10
			if not weapon_chest_placed:
				_place_chest(cx, cy, true)  # First chest = guaranteed weapon
				weapon_chest_placed = true
			else:
				_place_chest(cx, cy)
			chest_count += 1
	# Guarantee at least one weapon chest per level
	if not weapon_chest_placed and room_data.size() > 0:
		var rd = room_data[randi() % room_data.size()]
		if rd.active:
			var cx = float((rd.c_left + rd.c_right) / 2 * tile_size)
			var cy = float(rd.r_bot * tile_size) - 10
			_place_chest(cx, cy, true)
			chest_count += 1

	# Secret rooms: 40% chance, hidden behind fake walls
	if randf() < 0.40:
		_place_secret_room()

	# === MINIMAP DATA ===
	minimap_rooms.clear()
	var start_idx2 = (rooms_y - 1) * rooms_x + 0
	for i2 in room_data.size():
		var rd2 = room_data[i2]
		# Find grid neighbours (right, down) for corridor drawing
		var neighbors = []
		var rx2 = rd2.rx; var ry2 = rd2.ry
		# right neighbour
		if rx2 + 1 < rooms_x:
			var ni = ry2 * rooms_x + (rx2 + 1)
			if ni < room_data.size() and room_data[ni].active:
				neighbors.append(ni)
		# down neighbour
		if ry2 + 1 < rooms_y:
			var ni = (ry2 + 1) * rooms_x + rx2
			if ni < room_data.size() and room_data[ni].active:
				neighbors.append(ni)
		minimap_rooms.append({
			"rx": rd2.rx, "ry": rd2.ry, "active": rd2.active,
			"is_start": (i2 == start_idx2),
			"is_door": (i2 == door_idx),
			"is_merchant": false,
			"visited": (i2 == start_idx2),
			"neighbors": neighbors,
			# Pixel bounds for real-time detection
			"px_left":  float(rd2.c_left  * tile_size),
			"px_right": float(rd2.c_right * tile_size),
			"py_top":   float(rd2.r_top   * tile_size),
			"py_bot":   float(rd2.r_bot   * tile_size),
		})
	minimap_current_idx = start_idx2
	minimap_start_idx = start_idx2
	minimap_door_idx = door_idx

	# === BARRELS (15% chance per active room) ===
	barrels.clear()
	for rd3 in room_data:
		if not rd3.active: continue
		if randf() < 0.15:
			var bx = float(randi_range(rd3.c_left + 2, rd3.c_right - 2) * tile_size)
			var by = float(rd3.r_bot * tile_size) - 8.0
			barrels.append({"pos": Vector2(bx, by), "active": true, "fuse": 0.0})

	# Ensure borders
	for r in grid_rows:
		for c in grid_cols:
			if r < 3 or r >= grid_rows - 3 or c < 3 or c >= grid_cols - 3:
				grid[r][c] = 1

	# Connectivity
	_ensure_all_caves_reachable(start_r, start_c)

	# NO extra auto-ladders — only placed at vertical room connections
	# _add_ladders() removed — ladders only where designed above

	_extract_floor_positions()
	# Add extra scattered platforms in open cave areas
	_add_extra_platforms()
	_build_oneway_platforms()
	reachable_set = _get_reachable_tiles()

	# Remove unreachable caves
	var valid_caves: Array = []
	for cave in caves:
		var cr = clampi(int(cave.y / tile_size), 0, grid_rows - 1)
		var cc = clampi(int(cave.x / tile_size), 0, grid_cols - 1)
		var key = cr * grid_cols + cc
		if reachable_set.has(key) or cave.type == "start":
			valid_caves.append(cave)
	caves = valid_caves

	# Place death counter label on a solid wall tile in the start cave area
	if caves.size() > 0:
		var sc = caves[0]
		_death_label_pos = Vector2(
			sc.get("x", 100.0) + randf_range(20.0, 60.0),
			sc.get("y", 400.0) - randf_range(30.0, 60.0)
		)

func _add_extra_platforms():
	# Scatter extra one-way platforms in large open vertical spaces
	# Look for open column spans of 3+ tiles wide and 4+ tiles tall
	var added = 0
	var max_extra = 6 + room_level / 2
	for attempt in 40:
		if added >= max_extra:
			break
		var r = randi_range(4, grid_rows - 8)
		var c = randi_range(4, grid_cols - 8)
		# Only place in open air (not solid)
		if grid[r][c] != 0:
			continue
		# Needs floor below (solid tile within 6 rows)
		var has_floor = false
		for dr in range(1, 7):
			if r + dr < grid_rows and grid[r + dr][c] == 1:
				has_floor = true
				break
		if not has_floor:
			continue
		# Platform width 3-6 tiles
		var pw = randi_range(3, 6)
		if c + pw >= grid_cols - 3:
			pw = grid_cols - 4 - c
		if pw < 2:
			continue
		# Check all tiles are open
		var clear = true
		for dc in pw:
			if c + dc >= grid_cols or grid[r][c + dc] != 0:
				clear = false
				break
		if not clear:
			continue
		# Check not too close to existing platforms
		var too_close = false
		for plat in oneway_platforms:
			var pr2 = int(plat.y / tile_size)
			var pc2 = int(plat.x / tile_size)
			var pw2 = int(plat.w / tile_size)
			if abs(pr2 - r) < 3 and not (c + pw < pc2 or c > pc2 + pw2):
				too_close = true
				break
		if too_close:
			continue
		oneway_platforms.append({
			"x": float(c * tile_size),
			"y": float(r * tile_size),
			"w": float(pw * tile_size),
			"r": r, "c": c, "tw": pw,
		})
		added += 1

func _count_neighbors(r: int, c: int) -> int:
	var count = 0
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if dr == 0 and dc == 0:
				continue
			var nr = r + dr
			var nc = c + dc
			if nr < 0 or nr >= grid_rows or nc < 0 or nc >= grid_cols:
				count += 1
			elif grid[nr][nc] == 1:
				count += 1
	return count

func _carve_room(r: int, c: int, w: int, h: int):
	for dr in range(-h, h + 1):
		for dc in range(-1, w + 1):
			var nr = r + dr
			var nc = c + dc
			if nr > 2 and nr < grid_rows - 3 and nc > 2 and nc < grid_cols - 3:
				grid[nr][nc] = 0

func _make_floor(r: int, c: int, w: int):
	for dc in range(w):
		var nc = c + dc
		if nc > 2 and nc < grid_cols - 3 and r > 2 and r < grid_rows - 3:
			grid[r][nc] = 1

func _carve_path(sr: int, sc: int, er: int, ec: int):
	var r = sr
	var c = sc
	var max_steps = 1200  # Larger map needs more steps

	for step in max_steps:
		if abs(r - er) <= 2 and abs(c - ec) <= 2:
			break

		# Bias toward target with some randomness
		var choices = []
		if r > er:
			choices.append([-1, 0])
			choices.append([-1, 0])
		elif r < er:
			choices.append([1, 0])
			choices.append([1, 0])
		if c > ec:
			choices.append([0, -1])
			choices.append([0, -1])
		elif c < ec:
			choices.append([0, 1])
			choices.append([0, 1])
		# Random
		choices.append([randi_range(-1, 1), randi_range(-1, 1)])

		var choice = choices[randi() % choices.size()]
		r += choice[0]
		c += choice[1]
		r = clampi(r, 3, grid_rows - 4)
		c = clampi(c, 3, grid_cols - 4)

		# Carve 4-wide tunnel with extra headroom
		for dr in range(-2, 2):
			for dc in range(-1, 2):
				var nr = r + dr
				var nc = c + dc
				if nr > 2 and nr < grid_rows - 3 and nc > 2 and nc < grid_cols - 3:
					grid[nr][nc] = 0

func _ensure_headroom():
	# Scan all floor tiles — if ceiling is too close above, remove blocks
	# Player needs ~5 tiles (80px) of headroom to jump (jump_force=-300, gravity=650)
	var min_headroom = 5

	for r in range(5, grid_rows - 4):
		for c in range(5, grid_cols - 5):
			# Check if this is a floor surface (solid with open above)
			if grid[r][c] == 1 and grid[r - 1][c] == 0:
				# Count open tiles above this floor
				var headroom = 0
				for h in range(1, min_headroom + 2):
					if r - h < 3:
						break
					if grid[r - h][c] == 0:
						headroom += 1
					else:
						break

				# If headroom is too small, carve upward
				if headroom < min_headroom and headroom > 0:
					for h in range(1, min_headroom + 1):
						var tr = r - h
						if tr > 3 and tr < grid_rows - 3:
							grid[tr][c] = 0
							# Also widen 1 tile to each side for comfort
							if c - 1 > 3:
								grid[tr][c - 1] = 0
							if c + 1 < grid_cols - 3:
								grid[tr][c + 1] = 0

	# Also ensure all carved paths have minimum 3-wide vertical clearance
	# Scan for narrow horizontal pinch points (single-tile gaps)
	for r in range(4, grid_rows - 4):
		for c in range(4, grid_cols - 4):
			if grid[r][c] == 0:
				# Check vertical clearance
				var above_solid = r - 1 >= 0 and grid[r - 1][c] == 1
				var below_solid = r + 1 < grid_rows and grid[r + 1][c] == 1
				if above_solid and below_solid:
					# Single tile gap — too narrow, expand
					if r - 1 > 3:
						grid[r - 1][c] = 0
					if r + 1 < grid_rows - 3:
						grid[r + 1][c] = 0

func _add_ladders():
	# Place ladders in tall open shafts (where rooms connect vertically)
	var min_gap = 5

	for c in range(5, grid_cols - 5, 4):
		var open_run = 0
		var run_start_r = -1

		for r in range(3, grid_rows - 3):
			if grid[r][c] == 0:
				if open_run == 0:
					run_start_r = r
				open_run += 1
			else:
				if open_run > min_gap:
					# Check if there's already a ladder near this column
					var has_nearby = false
					for lad in ladders:
						if abs(lad.col - c) < 5 and abs(lad.y_top - run_start_r * tile_size) < 80:
							has_nearby = true
							break
					if not has_nearby:
						var lx = c * tile_size + tile_size / 2
						ladders.append({
							"x": lx,
							"y_top": float(run_start_r * tile_size),
							"y_bottom": float(r * tile_size),
							"col": c,
						})
				open_run = 0
				run_start_r = -1

var wall_sword_pos: Vector2 = Vector2.ZERO
var wall_sword_taken: bool = false
var player_near_sword: bool = false

func _build_start_room(rd: Dictionary):
	# Fixed starting room — clean, empty, safe space
	# No blocks, no enemies — just flat ground, torches, and a sword in the wall
	var cl = rd.c_left
	var cr = rd.c_right
	var rt = rd.r_top
	var rb = rd.r_bot

	# Clear the entire room interior — no random blocks
	for r in range(rt, rb + 1):
		for c in range(cl, cr + 1):
			grid[r][c] = 0

	# Solid floor
	for c in range(cl - 1, cr + 2):
		if c >= 0 and c < grid_cols and rb + 1 < grid_rows:
			grid[rb + 1][c] = 1

	# === SWORD IN WALL ===
	# Place sword stuck in right wall, at player height
	var sword_c = cr + 1  # right wall
	var sword_r = rb - 3  # roughly chest height
	wall_sword_pos = Vector2(float(sword_c * tile_size - 4), float(sword_r * tile_size + 8))
	wall_sword_taken = false

	# Interact area for sword
	var sword_area = Area2D.new()
	sword_area.position = wall_sword_pos
	sword_area.collision_layer = 0
	sword_area.collision_mask = 1
	var ss = CollisionShape2D.new()
	var sr = RectangleShape2D.new()
	sr.size = Vector2(24, 24)
	ss.shape = sr
	sword_area.add_child(ss)
	add_child(sword_area)
	sword_area.body_entered.connect(_on_sword_area_entered)
	sword_area.body_exited.connect(_on_sword_area_exited)

	# Two torches to light the room
	var torch_script = load("res://scripts/torch.gd")
	var torch = Node2D.new()
	torch.set_script(torch_script)
	var tx = float((cl + 3) * tile_size)
	var ty = float((rb - 1) * tile_size)
	torch.position = Vector2(tx, ty)
	torch_positions.append(Vector2(tx, ty))
	add_child(torch)

	var torch2 = Node2D.new()
	torch2.set_script(torch_script)
	var tx2 = float((cr - 3) * tile_size)
	var ty2 = float((rb - 1) * tile_size)
	torch2.position = Vector2(tx2, ty2)
	torch_positions.append(Vector2(tx2, ty2))
	add_child(torch2)

func _on_sword_area_entered(body):
	if body.is_in_group("player"):
		player_near_sword = true

func _on_sword_area_exited(body):
	if body.is_in_group("player"):
		player_near_sword = false

func _build_oneway_platforms():
	# One-way platforms on layer 6 (bit 32) — separate from solid walls (layer 3)
	for plat in oneway_platforms:
		var wall = StaticBody2D.new()
		wall.position = Vector2(plat.x + plat.w / 2.0, plat.y + 2.0)
		wall.collision_layer = 32  # layer 6
		wall.collision_mask = 0
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(plat.w, 4.0)
		shape.shape = rect
		shape.one_way_collision = true
		wall.add_child(shape)
		add_child(wall)

func _ensure_all_caves_reachable(start_r: int, start_c: int):
	# Flood fill from start position
	var visited = {}
	var queue = [[start_r, start_c]]
	visited[start_r * grid_cols + start_c] = true

	while queue.size() > 0:
		var cell = queue.pop_front()
		var cr = cell[0]
		var cc = cell[1]

		for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var nr = cr + d[0]
			var nc = cc + d[1]
			if nr < 0 or nr >= grid_rows or nc < 0 or nc >= grid_cols:
				continue
			var key = nr * grid_cols + nc
			if visited.has(key):
				continue
			if grid[nr][nc] == 0:
				visited[key] = true
				queue.append([nr, nc])

	# Check each cave room — if not reachable, carve a path to it
	for cave in caves:
		var cave_r = int(cave.y / tile_size)
		var cave_c = int(cave.x / tile_size)
		cave_r = clampi(cave_r, 3, grid_rows - 4)
		cave_c = clampi(cave_c, 3, grid_cols - 4)
		var key = cave_r * grid_cols + cave_c
		if not visited.has(key):
			# Carve a path from start to this cave
			_carve_path(start_r, start_c, cave_r, cave_c)
			# Re-flood from this cave to mark newly connected areas
			var q2 = [[cave_r, cave_c]]
			visited[key] = true
			while q2.size() > 0:
				var cell = q2.pop_front()
				for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
					var nr2 = cell[0] + d[0]
					var nc2 = cell[1] + d[1]
					if nr2 < 0 or nr2 >= grid_rows or nc2 < 0 or nc2 >= grid_cols:
						continue
					var k2 = nr2 * grid_cols + nc2
					if not visited.has(k2) and grid[nr2][nc2] == 0:
						visited[k2] = true
						q2.append([nr2, nc2])

func _extract_floor_positions():
	platforms.clear()
	for r in range(1, grid_rows):
		var run_start = -1
		for c in range(grid_cols):
			var is_floor = grid[r][c] == 1 and r > 0 and grid[r - 1][c] == 0
			if is_floor:
				if run_start == -1:
					run_start = c
			else:
				if run_start != -1:
					platforms.append({
						"x": float(run_start * tile_size),
						"y": float(r * tile_size),
						"w": float((c - run_start) * tile_size)
					})
					run_start = -1
		if run_start != -1:
			platforms.append({
				"x": float(run_start * tile_size),
				"y": float(r * tile_size),
				"w": float((grid_cols - run_start) * tile_size)
			})

func _build_collision():
	# Merge solid tiles into horizontal runs per row for efficient collision
	for r in grid_rows:
		var run_start = -1
		for c in range(grid_cols + 1):
			var is_solid = c < grid_cols and grid[r][c] == 1
			if is_solid:
				if run_start == -1:
					run_start = c
			else:
				if run_start != -1:
					var x = run_start * tile_size
					var y = r * tile_size
					var w = (c - run_start) * tile_size
					var h = tile_size
					_add_wall(Vector2(x + w / 2.0, y + h / 2.0), Vector2(w, h))
					run_start = -1

func _add_wall(pos: Vector2, size: Vector2):
	var wall = StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 4  # walls layer
	wall.collision_mask = 0
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)

	# Окклюдеры убраны: они затеняли сами стены и блоки становились невидимы.
	# Эффект "тумана войны" остаётся за счёт малого радиуса света + тёмного ambient.

	add_child(wall)

func _place_chest(cx: float, cy: float, force_weapon: bool = false):
	# Random weapon from loot table (weighted by CS-rarity)
	var roll = randf()
	var weapon_id: int
	var contraband = [23]                    # AWP Петли ★
	var legendary = [5, 6, 10, 11, 12]       # Vampire, Gold Hammer, Snake, Death Note, Necro
	var rare = [4, 7, 8, 9, 14, 15, 17]      # Hammer, Knife, Warp Bow, Claw, Chain, Anchor, Morningstar
	var uncommon = [2, 3, 13, 16, 18, 19]    # Long Sword, Blades, Axe, Triple Bow, Darts, Spear
	if force_weapon:
		roll = randf() * 0.50  # Force weapon (no heal)
	if roll < 0.005:  # 0.5% contraband
		weapon_id = contraband[randi() % contraband.size()]
	elif roll < 0.03:  # 2.5% legendary
		weapon_id = legendary[randi() % legendary.size()]
	elif roll < 0.18:  # 15% rare
		weapon_id = rare[randi() % rare.size()]
	elif roll < 0.50:  # 32% uncommon
		weapon_id = uncommon[randi() % uncommon.size()]
	else:  # 50% heal
		weapon_id = -1
	chests.append({"x": cx, "y": cy, "opened": false, "weapon_id": weapon_id})

	var chest_area = Area2D.new()
	chest_area.position = Vector2(cx, cy)
	chest_area.collision_layer = 0
	chest_area.collision_mask = 1
	var cs = CollisionShape2D.new()
	var cr = RectangleShape2D.new()
	cr.size = Vector2(20, 16)
	cs.shape = cr
	chest_area.add_child(cs)
	add_child(chest_area)

	var chest_idx = chests.size() - 1
	chests[chest_idx]["area"] = chest_area
	chest_area.body_entered.connect(_on_chest_body_entered.bind(chest_idx))
	chest_area.body_exited.connect(_on_chest_body_exited.bind(chest_idx))

func _on_chest_body_entered(body, idx: int):
	if body.is_in_group("player"):
		chest_near_idx = idx
		queue_redraw()

func _on_chest_body_exited(body, idx: int):
	if body.is_in_group("player"):
		if chest_near_idx == idx:
			chest_near_idx = -1
		queue_redraw()

func _open_chest(idx: int):
	if idx < 0 or idx >= chests.size():
		return
	if chests[idx].opened:
		return
	chests[idx].opened = true
	chest_near_idx = -1
	if player_ref and is_instance_valid(player_ref):
		var wid = chests[idx].get("weapon_id", -1)
		if wid >= 0 and player_ref.has_method("equip_weapon"):
			player_ref.equip_weapon(wid)
		else:
			player_ref.heal(40)
	queue_redraw()

func _trigger_arrow_trap(plate: Dictionary):
	# Shoot 3 arrows downward from ceiling
	if not player_ref or not is_instance_valid(player_ref):
		return
	var projectile_script = preload("res://scripts/projectile.gd")
	for i in 3:
		var proj = Area2D.new()
		proj.set_script(projectile_script)
		proj.projectile_type = 0  # ARROW
		proj.direction = Vector2(randf_range(-0.1, 0.1), 1.0).normalized()  # Downward
		proj.damage = 12
		proj.speed = 200
		proj.global_position = Vector2(plate.x + (i - 1) * 10, plate.r_top * tile_size)
		proj.rotation = PI / 2
		add_child(proj)

func get_nearest_torch_dist(pos: Vector2) -> float:
	var min_dist = INF
	for tp in torch_positions:
		var d = pos.distance_to(tp)
		if d < min_dist:
			min_dist = d
	return min_dist

func _place_torches():
	torch_positions.clear()

	# Place torches in cave rooms
	for cave in caves:
		if cave.type == "start" or randf() < 0.5:
			var torch = Node2D.new()
			torch.set_script(torch_script)
			var tx = cave.x + randf_range(-20, 20)
			var ty = cave.y - 10
			torch.position = Vector2(tx, ty)
			torch.on_wall_right = randf() > 0.5
			torch_positions.append(Vector2(tx, ty))
			add_child(torch)

	# Torches along some platforms (more for larger map)
	var placed = 0
	var max_torches = max(8, 14 - room_level / 2)
	for p in platforms:
		if p.w > 60 and randf() < 0.12 and placed < max_torches:
			var torch = Node2D.new()
			torch.set_script(torch_script)
			var tx = p.x + p.w / 2
			var ty = p.y - 5
			torch.position = Vector2(tx, ty)
			torch.on_wall_right = true
			torch_positions.append(Vector2(tx, ty))
			add_child(torch)
			placed += 1

func _calculate_dark_zones():
	dark_zones.clear()
	var light_radius = 80.0
	var scan_step = 20.0
	var x = 60.0

	while x < room_width - 60:
		var min_dist = INF
		for tp in torch_positions:
			var d = abs(tp.x - x)
			if d < min_dist:
				min_dist = d

		if min_dist > light_radius:
			var zone_start = x
			while x < room_width - 60:
				min_dist = INF
				for tp in torch_positions:
					var d = abs(tp.x - x)
					if d < min_dist:
						min_dist = d
				if min_dist <= light_radius:
					break
				x += scan_step
			dark_zones.append({"x": zone_start, "w": x - zone_start})
		x += scan_step

func _spawn_enemies(enemy_scene: PackedScene, p_player_ref: CharacterBody2D):
	# Scale carefully — each enemy runs physics + draw every frame
	# Old formula (18 + level*3, max 45) caused bad lag at level 6+
	var enemy_count = 10 + room_level * 2
	enemy_count = mini(enemy_count, 28)

	var loc = get_location_num()
	var weighted_classes: Array = []

	if loc == 0:
		# === LOCATION 1: Stone Dungeon — existing enemies, no Mage, no Spider ===
		weighted_classes.append([0, 4])  # ARCHER (common)
		if room_level >= 2:
			weighted_classes.append([2, 3])  # THROWER
		if room_level >= 3:
			weighted_classes.append([1, 3])  # CROSSBOW
		weighted_classes.append([3, 1])  # SHIELDMAN (rare)
		if room_level >= 2:
			weighted_classes.append([4, 2])  # FLY
		if room_level >= 4:
			weighted_classes.append([5, 1])  # STEALTH (rare)

	elif loc == 1:
		# === LOCATION 2: Dark Caves — spiders, summoner, mummy, mosquito, zombie ===
		weighted_classes.append([7,  3])  # SPIDER
		weighted_classes.append([8,  2])  # SUMMONER
		weighted_classes.append([10, 3])  # MUMMY
		weighted_classes.append([12, 3])  # MOSQUITO
		weighted_classes.append([13, 2])  # ZOMBIE_CORPSE

	else:
		# === LOCATION 3: Forsaken Halls — knights, herectics, dogs ===
		weighted_classes.append([14, 2])  # KNIGHT
		weighted_classes.append([15, 3])  # HERETIC (triggers group spawn of 5)
		weighted_classes.append([16, 4])  # DOG
		weighted_classes.append([7,  1])  # SPIDER (holdover)
		weighted_classes.append([13, 1])  # ZOMBIE_CORPSE (holdover)

	var shieldman_count = 0
	var max_shieldmen = 3 + (room_level / 3)
	max_shieldmen = mini(max_shieldmen, 6)
	var summoner_count = 0
	var max_summoners = 2  # never more than 2 summoners per room
	var knight_count = 0
	var max_knights = 3
	var heretic_groups_spawned = 0
	var max_heretic_groups = 3  # 3 packs × 5 = up to 15 herectics

	for i in enemy_count:
		var eclass = _pick_weighted(weighted_classes)

		if eclass == 3:  # SHIELDMAN cap
			if shieldman_count >= max_shieldmen:
				eclass = weighted_classes[0][0]
			else:
				shieldman_count += 1
		if eclass == 8:  # SUMMONER cap
			if summoner_count >= max_summoners:
				eclass = weighted_classes[0][0]
			else:
				summoner_count += 1
		if eclass == 14:  # KNIGHT cap
			if knight_count >= max_knights:
				eclass = weighted_classes[0][0]
			else:
				knight_count += 1
		if eclass == 15:  # HERETIC — spawn whole group, skip normal path
			if heretic_groups_spawned < max_heretic_groups:
				heretic_groups_spawned += 1
				_spawn_heretic_group(p_player_ref)
			continue

		var enemy = enemy_scene.instantiate()

		# Weaker per enemy: ~half HP, ~2/3 damage vs old formula
		var hp = (1 + room_level) * 10
		var spd = 30.0 + room_level * 3
		var dmg = 10 + room_level * 2
		dmg = mini(dmg, 30)  # Cap at 30 — never one-shot player
		if eclass == 3:   # SHIELDMAN
			hp += 20
		elif eclass == 7: # SPIDER — fast but moderate HP
			hp = int(hp * 0.9)
		elif eclass == 14:  # KNIGHT — setup_class handles its own HP/dmg, pass 0
			hp = 0; dmg = 0  # _setup_class() overrides these for KNIGHT
		elif eclass == 16:  # DOG — setup_class handles its own HP/dmg
			hp = 0; dmg = 0

		enemy.setup(eclass, hp, spd, dmg)
		enemy.player = p_player_ref

		# === ЗОНАЛЬНАЯ АГРЕССИЯ (ULTRAKILL-фил) ===
		# loc 0 — обычно; loc 1 (паркур) — быстрее; loc 2 (хардкор) — агрессивнее всех
		if loc == 1:
			# Зона 2: упор на движение — враги шустрые, чаще атакуют
			enemy.speed *= 1.25
			if "attack_cooldown" in enemy:
				enemy.attack_cooldown *= 0.8
		elif loc == 2:
			# Зона 3: хардкор — быстрые, агрессивные, больно бьют
			enemy.speed *= 1.35
			if "attack_cooldown" in enemy:
				enemy.attack_cooldown *= 0.65
			if "damage" in enemy:
				enemy.damage = int(enemy.damage * 1.25)

		# ELITE: шанс растёт с уровнем И с зоной (хардкор-зона = много элиты)
		var elite_base = 0.08 + room_level * 0.02
		if loc == 1: elite_base += 0.10
		elif loc == 2: elite_base += 0.22
		var elite_chance = clampf(elite_base, 0.08, 0.55)
		if randf() < elite_chance and enemy.has_method("make_elite"):
			var affixes = ["explosive", "fast", "armored", "ghostly", "healer"]
			enemy.make_elite(affixes[randi() % affixes.size()])

		var pos = _get_spawn_position()
		enemy.position = pos
		add_child(enemy)
		enemies.append(enemy)
		enemy.died.connect(_on_enemy_died)

	# Mini-boss: every 2 levels, one random enemy becomes a mini-boss
	if room_level >= 2 and enemies.size() > 0:
		var mb = enemies[randi() % enemies.size()]
		if mb.has_method("make_miniboss"):
			mb.make_miniboss()

func _spawn_heretic_group(p_player_ref: CharacterBody2D):
	var enemy_gd = load("res://scripts/enemy.gd")
	var hp  = (1 + room_level) * 10
	var spd = 30.0 + room_level * 3
	var dmg = mini(10 + room_level * 2, 30)
	var base_pos = _get_spawn_position()
	var group: Array = []
	for i in 5:
		var h = CharacterBody2D.new()
		h.set_script(enemy_gd)
		h.enemy_class = 15  # HERETIC — set BEFORE add_child so _ready() skips shieldman sprites
		add_child(h)
		h.setup(15, hp, spd, dmg)
		h.player = p_player_ref
		# Spread the group out a little
		h.global_position = base_pos + Vector2(randf_range(-40, 40), randf_range(-5, 5))
		group.append(h)
		enemies.append(h)
		h.died.connect(_on_enemy_died)
	# Cross-link group members so each knows its packmates
	for h in group:
		h.heretic_group = group.duplicate()
		h.heretic_group.erase(h)

func _pick_weighted(weighted: Array) -> int:
	var total_weight = 0
	for w in weighted:
		total_weight += w[1]
	var roll = randi() % total_weight
	var accumulated = 0
	for w in weighted:
		accumulated += w[1]
		if roll < accumulated:
			return w[0]
	return weighted[0][0]

# Находит Y верха твёрдого пола в колонке под точкой (px, py_hint).
# Гарантирует, что объект встанет НА блок, а не повиснет в воздухе и не
# окажется внутри стены. Используется для дверей и спавна врагов.
func _floor_y_in_column(px: float, py_hint: float) -> float:
	if grid.size() == 0 or grid_cols == 0:
		return py_hint
	var gc := clampi(int(px / tile_size), 0, grid_cols - 1)
	var gr := clampi(int(py_hint / tile_size), 0, grid_rows - 1)
	# Если точка-подсказка внутри блока — поднимаемся вверх до воздуха
	while gr > 0 and grid[gr][gc] == 1:
		gr -= 1
	# Спускаемся вниз до первого твёрдого тайла (это пол)
	var r := gr
	while r + 1 < grid_rows and grid[r + 1][gc] == 0:
		r += 1
	if r + 1 < grid_rows and grid[r + 1][gc] == 1:
		return float(r + 1) * tile_size  # верх пол-тайла = уровень пола
	# Пол не найден (сквозная шахта) — ставим на нижний ряд
	return float(grid_rows - 1) * tile_size

func _get_spawn_position() -> Vector2:
	# Pick a random non-start cave, verify position is reachable
	var spawn_caves = caves.filter(func(c): return c.type != "start" and c.type != "chest")
	if spawn_caves.size() == 0:
		spawn_caves = caves.filter(func(c): return c.type != "start")
	if spawn_caves.size() == 0:
		spawn_caves = caves

	for attempt in 30:
		var cave = spawn_caves[randi() % spawn_caves.size()]
		var px = cave.x + randf_range(-20, 20)
		# Привязываем к реальному полу в этой колонке (не висеть в воздухе)
		var py = _floor_y_in_column(px, cave.floor_y) - 1

		# Check that the grid cell is reachable from start
		if reachable_set.size() > 0:
			var gr = clampi(int(py / tile_size), 0, grid_rows - 1)
			var gc = clampi(int(px / tile_size), 0, grid_cols - 1)
			var key = gr * grid_cols + gc
			if reachable_set.has(key):
				return Vector2(px, py)
			# Try one tile above (enemy stands on floor, check above floor)
			var key_above = (gr - 1) * grid_cols + gc
			if gr > 0 and reachable_set.has(key_above):
				return Vector2(px, py)
		else:
			return Vector2(px, py)

	# Fallback: use start cave
	for cave in caves:
		if cave.type == "start":
			return Vector2(cave.x, _floor_y_in_column(cave.x, cave.floor_y) - 1)
	return Vector2(60, floor_y - 1)

func _spawn_door():
	var door_script_res = load("res://scripts/door.gd")
	var door = StaticBody2D.new()
	door.set_script(door_script_res)
	door.difficulty = mini(room_level, 5)

	# Set door label based on challenge type
	if is_boss_room:
		door.door_label = "[E] Continue"
	else:
		match challenge_type:
			"lockpick":
				door.door_label = "[E] Pick Lock (need lockpick)"
			"guardians":
				door.door_label = "[E] Summon Guardians"
			"crystal":
				door.door_label = "[E] Place Crystal (need ore)"

	var door_cave = null
	for cave in caves:
		if cave.type == "door":
			door_cave = cave
			break

	if door_cave:
		# Привязываем дверь к реальному полу — чтобы не висела в воздухе/в блоке
		var fy = _floor_y_in_column(door_cave.x, door_cave.floor_y)
		door.position = Vector2(door_cave.x, fy - 14)
	else:
		var best = caves[0]
		for cave in caves:
			if cave.x > best.x:
				best = cave
		var fy2 = _floor_y_in_column(best.x, best.floor_y)
		door.position = Vector2(best.x, fy2 - 14)

	add_child(door)
	doors.append(door)
	door.door_interact.connect(_on_door_interact)

func _process(delta):
	# Перерисовка комнаты только при смене видимой области (отсечение по камере).
	# Босс-комнаты перерисовываются каждый кадр ниже, им это не нужно.
	if not is_boss_room:
		_check_draw_cull()

	# Туман войны миникарты: обновляем 6 раз/сек (не каждый кадр)
	_explore_cd -= delta
	if _explore_cd <= 0.0 and player_ref and is_instance_valid(player_ref) and explored.size() > 0:
		_explore_cd = 0.16
		var ptx = int(player_ref.global_position.x / tile_size)
		var pty = int(player_ref.global_position.y / tile_size)
		var r2 = MINIMAP_EXPLORE_RADIUS * MINIMAP_EXPLORE_RADIUS
		for dr in range(-MINIMAP_EXPLORE_RADIUS, MINIMAP_EXPLORE_RADIUS + 1):
			for dc in range(-MINIMAP_EXPLORE_RADIUS, MINIMAP_EXPLORE_RADIUS + 1):
				if dr * dr + dc * dc > r2:
					continue
				var nr = pty + dr
				var nc = ptx + dc
				if nr >= 0 and nr < grid_rows and nc >= 0 and nc < grid_cols:
					explored[nr][nc] = true

	# === LEVEL OBJECTIVES ===
	if not objective_completed and not objective_failed and objective != "default":
		match objective:
			"kill_all":
				var alive = 0
				for e in enemies:
					if is_instance_valid(e): alive += 1
				if alive == 0 and enemies.size() > 0:
					objective_completed = true
			"survive_60", "speedrun_30":
				objective_timer -= delta
				if objective == "survive_60" and objective_timer <= 0:
					objective_completed = true
				if objective == "speedrun_30":
					# нужно зачистить за 30 сек
					var alive_s = 0
					for e in enemies:
						if is_instance_valid(e): alive_s += 1
					if alive_s == 0 and enemies.size() > 0 and objective_timer > 0:
						objective_completed = true
					elif objective_timer <= 0:
						objective_failed = true
			"no_damage":
				# Считаем выполненным когда все враги мертвы и урон=0
				if player_ref and "room_damage_taken" in player_ref and player_ref.room_damage_taken > 0:
					objective_failed = true
				else:
					var alive_n = 0
					for e in enemies:
						if is_instance_valid(e): alive_n += 1
					if alive_n == 0 and enemies.size() > 0:
						objective_completed = true

	# Декали: следы игрока + проявление надписей
	if decals and player_ref and is_instance_valid(player_ref):
		decals.update_message_visibility(player_ref.global_position)
		# Следы при ходьбе по полу
		if player_ref.is_on_floor() and abs(player_ref.velocity.x) > 50.0:
			_footprint_cd -= delta
			if _footprint_cd <= 0.0:
				_footprint_cd = 0.22
				decals.add_footprint(
					player_ref.global_position + Vector2(0, -1),
					player_ref.facing_right)

	# Minimap: detect which room player is in and mark as visited
	if player_ref and is_instance_valid(player_ref) and minimap_rooms.size() > 0:
		var px2 = player_ref.global_position.x
		var py2 = player_ref.global_position.y
		var changed = false
		for i3 in minimap_rooms.size():
			var rm = minimap_rooms[i3]
			if not rm.active: continue
			if px2 >= rm.px_left and px2 <= rm.px_right and py2 >= rm.py_top and py2 <= rm.py_bot:
				if not rm.visited:
					minimap_rooms[i3].visited = true
					changed = true
				if i3 != minimap_current_idx:
					minimap_current_idx = i3
					changed = true
				break
		if changed:
			# Push updated minimap to HUD via main
			var main_node = get_parent()
			if main_node and main_node.has_method("_sync_minimap"):
				main_node._sync_minimap()

	# Always check station/heart proximity (even after room cleared)
	var old_station = player_near_station
	var old_heart = player_near_heart
	if craft_stations.size() > 0:
		_check_station_proximity()
	if trial_heart_pos != Vector2.ZERO:
		_check_heart_proximity()
	if legend_trial_pos != Vector2.ZERO:
		_check_legend_proximity()
	# Redraw when proximity changes
	if player_near_station != old_station or player_near_heart != old_heart:
		queue_redraw()

	# Перерисовка при движении камеры УБРАНА — комната теперь рисуется целиком
	# один раз, Godot кэширует draw-команды. Это убирает спайки кадра.

	# Trap checks
	if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
		var px = player_ref.global_position.x
		var py = player_ref.global_position.y
		# Spikes — damage on contact with upward knockback
		for sp in spikes:
			if px > sp.x and px < sp.x + sp.w and py > sp.y - 8 and py < sp.y + 4:
				var spike_center_x = sp.x + sp.w * 0.5
				var kb_dir_x = 1.0 if px > spike_center_x else -1.0
				player_ref.take_damage(10, Vector2(kb_dir_x * 0.5, -1.0).normalized())
		# Poison pools — DOT or heal (acid_water card)
		for pp in poison_pipes:
			var ph = pp.get("pool_h", 8.0)
			if px > pp.pool_x and px < pp.pool_x + pp.pool_w and py > pp.pool_y - ph - 4 and py < pp.pool_y + 4:
				if player_ref.card_acid_water:
					player_ref.heal(1)  # Slow heal in poison
				elif player_ref.has_method("apply_poison"):
					player_ref.apply_poison(3.0, 5.0)
		# Pressure plates — trigger arrows from above
		for plate in pressure_plates:
			plate.cooldown = max(0, plate.cooldown - delta)
			if abs(px - plate.x) < 8 and abs(py - plate.y) < 6 and not plate.triggered and plate.cooldown <= 0:
				plate.triggered = true
				plate.cooldown = 5.0
				# Shoot arrows from ceiling
				_trigger_arrow_trap(plate)
				await get_tree().create_timer(0.5).timeout
				if is_instance_valid(self):
					plate.triggered = false

	# Лавовый паркур-босс: лава поднимается, мощный урон при касании
	if is_lava_boss and player_ref and is_instance_valid(player_ref):
		# Лава поднимается всё время (ускоряется когда босс жив дольше)
		lava_rise_y -= lava_rise_speed * delta
		# Не даём лаве уйти выше двери — стопаем у верха
		lava_rise_y = maxf(lava_rise_y, 6.0 * tile_size)
		lava_y = lava_rise_y
		# Урон если игрок в лаве — большой, "нельзя стоять"
		if player_ref.global_position.y > lava_y - 4:
			player_ref.take_damage(20, Vector2(0, -1.0))

	# Boss room lava damage (обычный boss room 5)
	if is_boss_room and not is_lava_boss and player_ref and is_instance_valid(player_ref):
		if player_ref.global_position.y > lava_y - 5:
			player_ref.take_damage(10, Vector2(0, -1))

	if is_boss_room:
		queue_redraw()  # Boss room is small, OK to redraw
		return

	# Arena checks
	if is_arena_level and not arena_active and not arena_cleared and player_ref and is_instance_valid(player_ref):
		var px2 = player_ref.global_position.x
		var py2 = player_ref.global_position.y
		if px2 > room_width * 0.3 and px2 < room_width * 0.7 and py2 < room_height * 0.85:
			_start_arena()
	if arena_active:
		var alive = 0
		for ae in enemies:
			if is_instance_valid(ae):
				alive += 1
		if alive == 0:
			_end_arena()

	# Secret room proximity
	for sr in secret_rooms:
		if not sr.revealed and player_ref and is_instance_valid(player_ref):
			var dist = player_ref.global_position.distance_to(Vector2(sr.wall_c * tile_size + tile_size, sr.wall_r * tile_size))
			if dist < 28 or ("is_rolling" in player_ref and player_ref.is_rolling):
				sr.revealed = true
				if not sr.chest_spawned:
					sr.chest_spawned = true
					_place_chest(sr.cx, sr.cy + tile_size * 2, true)
				queue_redraw()

	# Merchant interaction
	if room_event == "merchant" and not event_used and player_ref and is_instance_valid(player_ref):
		var near_merchant = player_ref.global_position.distance_to(merchant_pos) < 80
		if near_merchant:
			queue_redraw()
		# Открываем меню магазина при нажатии E рядом с торговцем
		if near_merchant and merchant_items.size() > 0:
			if Input.is_action_just_pressed("interact") and not _shop_open_flag:
				_shop_open_flag = true
				open_shop_menu_request.emit()

	# Altar interaction
	if room_event == "altar" and not altar_used and player_ref and is_instance_valid(player_ref):
		var altar_pos = Vector2(room_width * 0.5, room_height * 0.5)
		if player_ref.global_position.distance_to(altar_pos) < 30 and Input.is_action_just_pressed("interact"):
			if player_ref.health > 3:
				player_ref.health -= 3
				if player_ref.has_signal("health_changed"):
					player_ref.health_changed.emit(player_ref.health)
				altar_used = true
				player_ref.equip_weapon(randi_range(10, 22))
				queue_redraw()

	# Barrel explosion check
	if player_ref and is_instance_valid(player_ref) and player_ref.is_attacking:
		var wd_b = player_ref.weapon_data.get(player_ref.current_weapon, player_ref.weapon_data[1])
		var reach = wd_b.get("range", 22) + 14.0
		for barrel in barrels:
			if not barrel.active: continue
			if barrel.fuse > 0.0: continue  # уже горит фитиль
			if player_ref.global_position.distance_to(barrel.pos) < reach:
				barrel.fuse = 2.0  # 2-секундная задержка
				queue_redraw()

	# Тик фитилей у бочек
	var any_fuse = false
	for barrel in barrels:
		if not barrel.active: continue
		if barrel.fuse > 0.0:
			barrel.fuse -= delta
			any_fuse = true
			if barrel.fuse <= 0.0:
				barrel.active = false
				_explode_barrel(barrel.pos)
	if any_fuse:
		queue_redraw()

	if is_cleared:
		return

	portal_spawn_timer -= delta
	if portal_spawn_timer <= 0:
		_spawn_portal()
		portal_spawn_timer = portal_spawn_interval + randf_range(-1.5, 1.5)

	# ── Horror effects animation tick ──
	var horror_needs_redraw = false

	# Blood drips from ceiling tiles
	_horror_drip_cd -= delta
	if _horror_drip_cd <= 0.0:
		_spawn_ceiling_drip()
		_horror_drip_cd = randf_range(8.0, 22.0)
	for d in _blood_drips:
		if d.len < d.max_len:
			d.len += d.speed * delta
			horror_needs_redraw = true
	_blood_drips = _blood_drips.filter(func(d): return d.len < d.max_len)

	# Face in wall
	_face_cd -= delta
	if _face_cd <= 0.0 and _face_t < 0.0:
		_face_t   = randf_range(4.5, 7.0)
		_face_dur = _face_t
		_face_cd  = randf_range(90.0, 220.0)
		var vr    = _get_visible_tile_range()
		# Find a solid tile that is a wall face (has open space adjacent — visible to player)
		for _att in 40:
			var tc = randi_range(vr[0] + 2, maxi(vr[0] + 3, vr[1] - 2))
			var tr = randi_range(vr[2] + 2, maxi(vr[2] + 3, vr[3] - 3))
			if tc >= grid_cols or tr >= grid_rows or grid[tr][tc] != 1:
				continue
			var has_face = (tc + 1 < grid_cols and grid[tr][tc + 1] == 0) or \
			               (tc > 0 and grid[tr][tc - 1] == 0) or \
			               (tr > 0 and grid[tr - 1][tc] == 0)
			if has_face:
				_face_wx = tc * tile_size + tile_size * 0.5
				_face_wy = tr * tile_size + tile_size * 0.5
				break
	if _face_t >= 0.0:
		_face_t -= delta
		horror_needs_redraw = true

	# Wall text — must be on an actual wall face
	_wtext_cd -= delta
	if _wtext_cd <= 0.0 and _wtext_t < 0.0:
		var msgs = ["ты уже был здесь", "обернись", "я вижу тебя",
		            "выхода нет", "это не кончится", "беги", "мы помним"]
		_wtext_msg = msgs[randi() % msgs.size()]
		_wtext_cd  = randf_range(120.0, 280.0)
		var vr2    = _get_visible_tile_range()
		var placed = false
		for _att in 50:
			var tc = randi_range(vr2[0] + 1, maxi(vr2[0] + 2, vr2[1] - 2))
			var tr = randi_range(vr2[2] + 2, maxi(vr2[2] + 3, vr2[3] - 3))
			if tc >= grid_cols or tr >= grid_rows or grid[tr][tc] != 1:
				continue
			# Right wall face: solid tile with open space to the right, and open row below
			if tc + 1 < grid_cols and grid[tr][tc + 1] == 0:
				var open_below = tr + 1 < grid_rows and grid[tr + 1][tc + 1] == 0
				if open_below:
					_wtext_wx = (tc + 1) * tile_size + 2.0
					_wtext_wy = tr * tile_size + tile_size * 0.78
					_wtext_t   = randf_range(4.0, 6.5)
					_wtext_dur = _wtext_t
					placed = true
					break
			# Left wall face: solid tile with open space to the left
			elif tc > 0 and grid[tr][tc - 1] == 0:
				var open_below = tr + 1 < grid_rows and grid[tr + 1][tc - 1] == 0
				if open_below:
					_wtext_wx = (tc - 1) * tile_size + 2.0
					_wtext_wy = tr * tile_size + tile_size * 0.78
					_wtext_t   = randf_range(4.0, 6.5)
					_wtext_dur = _wtext_t
					placed = true
					break
		# If no wall face found, skip this trigger entirely
		if not placed:
			_wtext_cd = randf_range(20.0, 40.0)  # retry sooner
	if _wtext_t >= 0.0:
		_wtext_t -= delta
		horror_needs_redraw = true

	if horror_needs_redraw:
		queue_redraw()

func _spawn_portal():
	if not player_ref or not is_instance_valid(player_ref):
		return
	if portals.size() >= 3:
		return

	var portal = CharacterBody2D.new()
	portal.set_script(portal_script)

	var spawn_caves = caves.filter(func(c): return c.type != "chest")
	if spawn_caves.size() == 0:
		spawn_caves = caves

	var cave = spawn_caves[randi() % spawn_caves.size()]
	var px = cave.x + randf_range(-15, 15)
	var py = cave.floor_y - 1

	if Vector2(px, py).distance_to(player_ref.global_position) < 80:
		cave = spawn_caves[randi() % spawn_caves.size()]
		px = cave.x + randf_range(-15, 15)
		py = cave.floor_y - 1

	portal.position = Vector2(px, py)
	portal.setup(player_ref, mini(15 + room_level * 2, 30))
	portal.skeleton_health = (2 + room_level / 2) * 20
	portal.max_skeleton_health = portal.skeleton_health
	add_child(portal)
	portals.append(portal)
	portal.skeleton_died.connect(_on_portal_died)
	portal.open_portal()

func _on_portal_died(portal):
	portals.erase(portal)

func _on_enemy_died(enemy):
	# Blood pool at death position
	if is_instance_valid(enemy):
		blood_pools.append({
			"x": enemy.global_position.x,
			"y": enemy.global_position.y + 2,
			"r": randf_range(6.0, 14.0),
			"alpha": randf_range(0.35, 0.65)
		})
		queue_redraw()
	# Check for pickaxe drop
	if enemy.drops_pickaxe and player_ref and is_instance_valid(player_ref):
		player_ref.has_pickaxe = true
		player_ref.using_pickaxe = true  # Auto-equip
	# Check for pearl drop
	_check_pearl_drop(enemy)
	# Scroll drop: 1 scroll every 2 levels, chance per kill
	if player_ref and is_instance_valid(player_ref):
		var scroll_chance = 0.08  # 8% per kill
		if room_level % 2 == 0:
			scroll_chance = 0.12  # Higher chance on even levels
		if player_ref.scrolls.size() < player_ref.max_scrolls and randf() < scroll_chance:
			var scroll_types = ["dash", "kick", "speed_boost", "choke", "slide"]
			var scroll_id = scroll_types[randi() % scroll_types.size()]
			player_ref.pickup_scroll(scroll_id)
	enemies.erase(enemy)
	if enemies.size() == 0:
		is_cleared = true
		room_cleared.emit()

func _on_door_interact(door):
	door_used.emit(door)

# === ARENA ===

func _setup_arena():
	is_arena_level = true
	arena_active = false
	arena_cleared = false
	var cx = room_width / 2.0
	var cy = room_height / 2.0
	arena_gate_left = _create_gate(cx - room_width * 0.25, cy)
	arena_gate_right = _create_gate(cx + room_width * 0.25, cy)
	if arena_gate_left: arena_gate_left.visible = false
	if arena_gate_right: arena_gate_right.visible = false

func _create_gate(x: float, y: float) -> StaticBody2D:
	var gate = StaticBody2D.new()
	gate.collision_layer = 4
	gate.collision_mask = 1
	var shape_node = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(8, 80)
	shape_node.shape = shape
	gate.add_child(shape_node)
	gate.position = Vector2(x, y - 40)
	add_child(gate)
	return gate

func _start_arena():
	arena_active = true
	if arena_gate_left: arena_gate_left.visible = true
	if arena_gate_right: arena_gate_right.visible = true
	var count = randi_range(4, 6)
	for i in count:
		var ex = room_width * 0.35 + randf() * room_width * 0.3
		var ey = room_height * 0.55
		_spawn_single_enemy(ex, ey)
	queue_redraw()

func _end_arena():
	arena_active = false
	arena_cleared = true
	if arena_gate_left: arena_gate_left.queue_free(); arena_gate_left = null
	if arena_gate_right: arena_gate_right.queue_free(); arena_gate_right = null
	_place_chest(room_width * 0.5, room_height * 0.55, true)
	queue_redraw()

func _spawn_single_enemy(x: float, y: float):
	if not _enemy_scene_ref or not player_ref:
		return
	var enemy = _enemy_scene_ref.instantiate()
	var classes = [0, 1, 2, 3]
	var eclass = classes[randi() % classes.size()]
	var hp = (1 + room_level) * 12
	var spd = 30.0 + room_level * 3
	var dmg = 10 + room_level * 2
	enemy.setup(eclass, hp, spd, dmg)
	enemy.player = player_ref
	# Привязываем к реальному полу — арена-враг не должен висеть в воздухе
	enemy.position = Vector2(x, _floor_y_in_column(x, y) - 1)
	add_child(enemy)
	enemies.append(enemy)
	enemy.died.connect(_on_enemy_died)

func _explode_barrel(pos: Vector2):
	for enemy in enemies:
		if is_instance_valid(enemy) and pos.distance_to(enemy.global_position) < 90:
			var kb = (enemy.global_position - pos).normalized()
			enemy.take_damage(40, kb)
	# Damage player too if too close
	if player_ref and is_instance_valid(player_ref) and pos.distance_to(player_ref.global_position) < 60:
		player_ref.take_damage(15, (player_ref.global_position - pos).normalized())

func get_minimap_data() -> Array:
	return minimap_rooms

# Детальные данные для пиксельной миникарты
func get_minimap_detailed() -> Dictionary:
	# Возвращает компактные данные для отрисовки tile-grid миникарты + маркеры.
	var data = {
		"grid_cols": grid_cols,
		"grid_rows": grid_rows,
		"tile_size": tile_size,
		"grid": grid,                # 2D array
		"explored": explored,        # 2D array bool
		"iron_ore": [],              # [{x, y}]
		"gold_ore": [],
		"chests": [],                # [{x, y, opened}]
		"doors": [],                 # [{x, y}]
		"merchant": null,            # {x, y} или null
		"torches": [],               # [{x, y}]
		"barrels": [],
	}
	for ob in ore_blocks:
		if not ob.get("mined", false):
			data.iron_ore.append({"x": ob.x, "y": ob.y})
	for gb in gold_ore_blocks:
		if not gb.get("mined", false):
			data.gold_ore.append({"x": gb.x, "y": gb.y})
	for ch in chests:
		data.chests.append({"x": ch.x, "y": ch.y, "opened": ch.get("opened", false)})
	for d in doors:
		data.doors.append({"x": d.global_position.x, "y": d.global_position.y})
	if room_event == "merchant" and merchant_pos != Vector2.ZERO:
		data.merchant = {"x": merchant_pos.x, "y": merchant_pos.y}
	for t in torch_positions:
		data.torches.append({"x": t.x, "y": t.y})
	for b in barrels:
		if b.get("active", true):
			data.barrels.append({"x": b.pos.x, "y": b.pos.y})
	return data

func get_current_room_type() -> String:
	return ""

# === SECRET ROOMS ===

func _place_secret_room():
	for attempt in 40:
		var r = randi_range(5, grid_rows - 10)
		var c = randi_range(5, grid_cols - 12)
		if grid[r][c] == 1 and grid[r][c + 1] == 1 and grid[r][c + 2] == 0:
			for dr in range(-2, 4):
				for dc in range(2, 8):
					var nr = r + dr
					var nc = c + dc
					if nr >= 0 and nr < grid_rows and nc >= 0 and nc < grid_cols:
						grid[nr][nc] = 0
			var floor_r = r + 3
			for dc in range(2, 8):
				if c + dc < grid_cols:
					grid[floor_r][c + dc] = 1
			secret_rooms.append({
				"cx": float((c + 5) * tile_size),
				"cy": float((r + 1) * tile_size),
				"wall_c": c, "wall_r": r,
				"revealed": false, "chest_spawned": false
			})
			break

# === ROOM EVENTS ===

func _setup_room_event():
	match room_event:
		"merchant":
			# Pick 2 random weapons (different rarities) + heal + card
			var shuffled = SHOP_WEAPONS.duplicate()
			shuffled.shuffle()
			var picked: Array = []
			var rarities_used: Array = []
			for w in shuffled:
				if w.rarity not in rarities_used and picked.size() < 2:
					picked.append(w)
					rarities_used.append(w.rarity)
			merchant_items = [{"type": "heal", "cost": 8, "label": "Зелье HP", "bought": false, "coin": true}]
			for w in picked:
				var rarity_star = {"common": "○", "uncommon": "◈", "rare": "★", "legendary": "✦"}.get(w.rarity, "○")
				merchant_items.append({
					"type": "weapon", "weapon_id": w.weapon_id, "coin": true,
					"cost": w.price, "rarity": w.rarity,
					"label": rarity_star + " " + w.name + "  " + str(w.price) + "₡",
					"bought": false
				})
			merchant_items.append({"type": "card", "cost": 20, "label": "Случайная карта  20₡", "bought": false, "coin": true})
			# Find best cave for shop: not start/door, prefer mid-map, pick widest
			var best_cave = null
			var best_score: float = -1.0
			for cave in caves:
				if cave.type == "start" or cave.type == "door":
					continue
				# Score: prefer wide rooms near the horizontal middle
				var cx = cave.x
				var mid_x = room_width * 0.5
				var dist_penalty = abs(cx - mid_x) / room_width
				var score = cave.get("w", 0.0) * 0.01 - dist_penalty
				if score > best_score:
					best_score = score
					best_cave = cave
			if best_cave == null and caves.size() > 0:
				best_cave = caves[0]
			# Derive tile-grid bounds from cave pixel data
			var mr_x_left: float
			var mr_x_right: float
			var mr_y_top: float
			var mr_y_bot: float
			if best_cave != null:
				mr_x_left  = best_cave.x - best_cave.get("w", 192.0) * 0.5
				mr_x_right = best_cave.x + best_cave.get("w", 192.0) * 0.5
				mr_y_top   = best_cave.get("y", 0.0)
				mr_y_bot   = best_cave.floor_y
			else:
				mr_x_left  = room_width * 0.25
				mr_x_right = room_width * 0.55
				mr_y_top   = room_height * 0.35
				mr_y_bot   = room_height * 0.70
			# Carve a clear 12-tile-wide strip centered in the room at floor level
			# (grid changes only affect drawing; collision already built, so add counter wall separately)
			var mr_cx_tile: int = int((mr_x_left + mr_x_right) * 0.5 / tile_size)
			var strip_half: int = 6
			var c_strip_left:  int = max(int(mr_x_left / tile_size) + 1, mr_cx_tile - strip_half)
			var c_strip_right: int = min(int(mr_x_right / tile_size) - 1, mr_cx_tile + strip_half)
			var r_floor: int = int(mr_y_bot / tile_size)
			var r_clear_top: int = max(int(mr_y_top / tile_size) + 1, r_floor - 7)
			# Clear air above floor in the strip
			for rr in range(r_clear_top, r_floor):
				for cc in range(c_strip_left, c_strip_right + 1):
					if rr >= 0 and rr < grid_rows and cc >= 0 and cc < grid_cols:
						grid[rr][cc] = 0
			# Ensure floor row is solid
			for cc in range(c_strip_left, c_strip_right + 1):
				if r_floor >= 0 and r_floor < grid_rows and cc >= 0 and cc < grid_cols:
					grid[r_floor][cc] = 1
			# Remove any oneway platforms that overlap the strip to avoid spawning issues
			var to_remove: Array = []
			for plat in oneway_platforms:
				var pr: int = plat.get("r", -1)
				var pc: int = plat.get("c", -1)
				var ptw: int = plat.get("tw", 0)
				if pr >= r_clear_top and pr <= r_floor and pc <= c_strip_right and pc + ptw >= c_strip_left:
					to_remove.append(plat)
			for p in to_remove:
				oneway_platforms.erase(p)
			# Remove spikes in the strip
			var spikes_to_remove: Array = []
			for sp in spikes:
				var sc: int = int(sp.x / tile_size)
				var sw: int = int(sp.w / tile_size)
				if sc <= c_strip_right and sc + sw >= c_strip_left:
					spikes_to_remove.append(sp)
			for sp in spikes_to_remove:
				spikes.erase(sp)
			# Counter: solid block 3 tiles tall × 12 tiles wide, sitting 3 rows above floor
			var counter_w_tiles: int = 12
			var counter_c_left:  int = mr_cx_tile - counter_w_tiles / 2
			var counter_c_right: int = counter_c_left + counter_w_tiles
			var counter_r_bot:   int = r_floor - 3
			var counter_r_top:   int = counter_r_bot - 2   # 3 rows tall
			for rr in range(counter_r_top, counter_r_bot + 1):
				for cc in range(counter_c_left, counter_c_right + 1):
					if rr >= 0 and rr < grid_rows and cc >= 0 and cc < grid_cols:
						grid[rr][cc] = 0  # keep air (drawn visually, physical wall added below)
			# Add physical counter wall (separate static body so collision works without full rebuild)
			var ctr_x = float(counter_c_left * tile_size)
			var ctr_y = float(counter_r_top * tile_size)
			var ctr_w = float(counter_w_tiles * tile_size)
			var ctr_h = float(3 * tile_size)
			_add_wall(Vector2(ctr_x + ctr_w * 0.5, ctr_y + ctr_h * 0.5), Vector2(ctr_w, ctr_h))
			# Store shop room bounds for drawing
			merchant_room = {
				"x_left":  mr_x_left,
				"x_right": mr_x_right,
				"y_top":   mr_y_top,
				"y_bot":   mr_y_bot,
				"counter_x": ctr_x,
				"counter_y": ctr_y,
				"counter_w": ctr_w,
				"counter_h": ctr_h,
			}
			# Merchant stands behind the counter (upper side of counter, centered)
			var mp_cx: float = (mr_x_left + mr_x_right) * 0.5
			merchant_pos = Vector2(mp_cx, ctr_y - 10.0)
			merchant_selected = 0
			# Mark the minimap room containing merchant_pos
			for mm_i in minimap_rooms.size():
				var mm = minimap_rooms[mm_i]
				if mm.active and merchant_pos.x >= mm.px_left and merchant_pos.x <= mm.px_right \
						and merchant_pos.y >= mm.py_top and merchant_pos.y <= mm.py_bot:
					minimap_rooms[mm_i].is_merchant = true
					break
		"cursed":
			# Applied after enemies spawn — boost all enemies speed/damage
			for enemy in enemies:
				if is_instance_valid(enemy):
					enemy.speed *= 1.35
					enemy.damage = int(enemy.damage * 1.25)

# === DOOR CHALLENGES ===

func get_lockpick_difficulty() -> int:
	# Level 1: difficulty 4 (hard like level 4)
	if room_level == 1:
		return 4
	return mini(room_level, 5)

func start_guardian_challenge(enemy_scene: PackedScene):
	if challenge_started and not challenge_complete_flag:
		return
	challenge_started = true
	challenge_complete_flag = false

	# Clean up old guardians
	for g in door_guardians:
		if is_instance_valid(g):
			g.queue_free()
	door_guardians.clear()

	# Find door position
	var door_pos = Vector2(600, 350)
	if doors.size() > 0:
		door_pos = doors[0].global_position

	# Spawn 2 spear shieldmen on each side of door
	for i in 2:
		var guardian = enemy_scene.instantiate()
		var side = -1 if i == 0 else 1
		guardian.is_spear = true

		var hp = (3 + room_level / 2) * 15
		var spd = 30.0 + room_level * 2
		var dmg = 15 + room_level * 2
		dmg = mini(dmg, 35)  # Cap guardian damage

		guardian.setup(3, hp, spd, dmg)  # 3 = SHIELDMAN
		guardian.player = player_ref
		guardian.position = door_pos + Vector2(side * 40, 0)
		add_child(guardian)
		door_guardians.append(guardian)
		guardian.died.connect(_on_guardian_died)

func _on_guardian_died(enemy):
	door_guardians.erase(enemy)
	if door_guardians.size() == 0:
		challenge_complete_flag = true
		challenge_complete.emit()

func start_crystal_challenge(enemy_scene: PackedScene):
	# Clean up old challenge
	if crystal_node and is_instance_valid(crystal_node):
		crystal_node.queue_free()
	for a in crystal_attackers:
		if is_instance_valid(a):
			a.queue_free()
	crystal_attackers.clear()

	challenge_started = true
	challenge_complete_flag = false

	# Find door position
	var door_pos = Vector2(600, 350)
	if doors.size() > 0:
		door_pos = doors[0].global_position

	# Spawn crystal near door
	crystal_node = Node2D.new()
	crystal_node.set_script(crystal_script)
	crystal_node.position = door_pos + Vector2(-20, 0)
	# 240 HP = each of 4 enemies needs 3 hits to break it (4*3*20=240), scales with level
	crystal_node.health = 240 + room_level * 20
	crystal_node.max_health = crystal_node.health
	add_child(crystal_node)
	crystal_node.crystal_destroyed.connect(_on_crystal_destroyed)

	# Spawn 4 random enemies that attack ONLY the crystal
	var enemy_classes = [0, 2, 3]  # ARCHER, THROWER, SHIELDMAN
	if room_level >= 3:
		enemy_classes.append(1)  # CROSSBOW

	for i in 4:
		var attacker = enemy_scene.instantiate()
		var eclass = enemy_classes[randi() % enemy_classes.size()]

		var hp = (2 + room_level) * 15
		var spd = 30.0 + room_level * 3
		var dmg = 15  # Crystal attackers deal damage to crystal
		if eclass == 3:
			hp += 30

		attacker.setup(eclass, hp, spd, dmg)
		attacker.player = player_ref
		attacker.crystal_target = crystal_node  # They attack ONLY the crystal

		# Spawn from edges of the room
		var spawn_pos = _get_spawn_position()
		# Ensure they spawn away from crystal
		if spawn_pos.distance_to(crystal_node.position) < 100:
			spawn_pos = _get_spawn_position()
		attacker.position = spawn_pos
		add_child(attacker)
		crystal_attackers.append(attacker)
		attacker.died.connect(_on_crystal_attacker_died)

func _on_crystal_attacker_died(enemy):
	crystal_attackers.erase(enemy)
	if crystal_attackers.size() == 0:
		if crystal_node and is_instance_valid(crystal_node) and not crystal_node.is_destroyed:
			challenge_complete_flag = true
			challenge_complete.emit()

func _on_crystal_destroyed():
	# Crystal was destroyed — challenge failed
	# Attackers keep wandering, player can interact with door to retry
	pass

# === ORE & PICKAXE SYSTEM ===

func _spawn_ore_blocks():
	ore_blocks.clear()
	# Iron: 6 on lockpick/crystal levels, 1 on others
	var ore_count = 6 if (challenge_type == "lockpick" or challenge_type == "crystal") else 1
	var placed = 0
	var attempts = 0

	# First, flood fill from start to know which open tiles are reachable
	var reachable = {}
	var start_cave = null
	for cave in caves:
		if cave.type == "start":
			start_cave = cave
			break
	if start_cave:
		var sr = int(start_cave.y / tile_size)
		var sc = int(start_cave.x / tile_size)
		sr = clampi(sr, 0, grid_rows - 1)
		sc = clampi(sc, 0, grid_cols - 1)
		var queue = [[sr, sc]]
		reachable[sr * grid_cols + sc] = true
		while queue.size() > 0:
			var cell = queue.pop_front()
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var nr2 = cell[0] + d[0]
				var nc2 = cell[1] + d[1]
				if nr2 < 0 or nr2 >= grid_rows or nc2 < 0 or nc2 >= grid_cols:
					continue
				var k = nr2 * grid_cols + nc2
				if not reachable.has(k) and grid[nr2][nc2] == 0:
					reachable[k] = true
					queue.append([nr2, nc2])

	while placed < ore_count and attempts < 300:
		attempts += 1
		var r = randi_range(5, grid_rows - 5)
		var c = randi_range(5, grid_cols - 5)

		# Must be solid tile with open space ABOVE it (floor surface = visible block)
		if grid[r][c] != 1:
			continue
		if r <= 1 or grid[r - 1][c] != 0:
			continue  # Not a floor surface — skip buried blocks

		# The open space above must be REACHABLE (connected to main cave)
		var above_key = (r - 1) * grid_cols + c
		if not reachable.has(above_key):
			continue

		# Check not too close to other ore (spread them out)
		var too_close = false
		for ore in ore_blocks:
			if Vector2(ore.x, ore.y).distance_to(Vector2(c * tile_size + 8, r * tile_size + 8)) < 80:
				too_close = true
				break
		if too_close:
			continue

		var ox = float(c * tile_size + 8)
		var oy = float(r * tile_size + 8)

		# Create Area2D for ore detection (detects player attack layer 16)
		var ore_area = Area2D.new()
		ore_area.collision_layer = 0
		ore_area.collision_mask = 16  # player_attack
		var oshape = CollisionShape2D.new()
		var orect = RectangleShape2D.new()
		orect.size = Vector2(16, 16)
		oshape.shape = orect
		ore_area.add_child(oshape)
		ore_area.position = Vector2(ox, oy)
		add_child(ore_area)

		var ore_idx = placed
		ore_blocks.append({"x": ox, "y": oy, "mined": false, "area": ore_area, "r": r, "c": c})
		ore_area.area_entered.connect(_on_ore_hit.bind(ore_idx))
		placed += 1

func _on_ore_hit(attacker_area: Area2D, ore_idx: int):
	if ore_idx >= ore_blocks.size():
		return
	if ore_blocks[ore_idx].mined:
		return
	if not player_ref or not is_instance_valid(player_ref):
		return
	if not player_ref.using_pickaxe or not player_ref.is_attacking:
		return

	# Mine the ore!
	ore_blocks[ore_idx].mined = true
	if ore_blocks[ore_idx].area and is_instance_valid(ore_blocks[ore_idx].area):
		ore_blocks[ore_idx].area.queue_free()
	player_ref.ore_mined += 1
	player_ref.iron_ore += 1

	# Старое auto-craft убрано — отмычка крафтится теперь на наковальне явно

	queue_redraw()

func _spawn_pickaxe_mob(enemy_scene: PackedScene, p_player_ref: CharacterBody2D):
	var enemy = enemy_scene.instantiate()
	# Make it a thrower (visually distinct) with pickaxe drop
	var hp = (3 + room_level) * 20
	var spd = 25.0 + room_level * 3
	var dmg = 20
	enemy.setup(0, hp, spd, dmg)  # ARCHER class but with pickaxe flag
	enemy.player = p_player_ref
	enemy.drops_pickaxe = true

	# Spawn in a reachable spot, not too far from start
	var pos = _get_spawn_position()
	for attempt in 10:
		var candidate = _get_spawn_position()
		# Prefer positions closer to start area
		var start_cave = null
		for cave in caves:
			if cave.type == "start":
				start_cave = cave
				break
		if start_cave and candidate.distance_to(Vector2(start_cave.x, start_cave.floor_y)) < pos.distance_to(Vector2(start_cave.x, start_cave.floor_y)):
			pos = candidate

	enemy.position = pos
	add_child(enemy)
	enemies.append(enemy)
	enemy.died.connect(_on_enemy_died)
	pickaxe_enemy = enemy

func _on_pickaxe_enemy_died():
	if player_ref and is_instance_valid(player_ref):
		player_ref.has_pickaxe = true

# === GOLD ORE ===

func _spawn_gold_ore():
	gold_ore_blocks.clear()
	# Gold: 1 every 2 levels
	if room_level % 2 != 0:
		return

	# Reuse reachable set from ore spawning
	var reachable = _get_reachable_tiles()
	var attempts = 0

	while gold_ore_blocks.size() < 1 and attempts < 200:
		attempts += 1
		var r = randi_range(5, grid_rows - 5)
		var c = randi_range(5, grid_cols - 5)

		if grid[r][c] != 1:
			continue
		if r <= 1 or grid[r - 1][c] != 0:
			continue
		var above_key = (r - 1) * grid_cols + c
		if not reachable.has(above_key):
			continue

		# Not near iron ore
		var too_close = false
		for ore in ore_blocks:
			if Vector2(ore.x, ore.y).distance_to(Vector2(c * tile_size + 8, r * tile_size + 8)) < 60:
				too_close = true
				break
		if too_close:
			continue

		var ox = float(c * tile_size + 8)
		var oy = float(r * tile_size + 8)

		var ore_area = Area2D.new()
		ore_area.collision_layer = 0
		ore_area.collision_mask = 16
		var oshape = CollisionShape2D.new()
		var orect = RectangleShape2D.new()
		orect.size = Vector2(16, 16)
		oshape.shape = orect
		ore_area.add_child(oshape)
		ore_area.position = Vector2(ox, oy)
		add_child(ore_area)

		gold_ore_blocks.append({"x": ox, "y": oy, "mined": false, "area": ore_area, "r": r, "c": c})
		ore_area.area_entered.connect(_on_gold_ore_hit.bind(0))

func _on_gold_ore_hit(attacker_area: Area2D, ore_idx: int):
	if ore_idx >= gold_ore_blocks.size():
		return
	if gold_ore_blocks[ore_idx].mined:
		return
	if not player_ref or not is_instance_valid(player_ref):
		return
	if not player_ref.using_pickaxe or not player_ref.is_attacking:
		return

	gold_ore_blocks[ore_idx].mined = true
	if gold_ore_blocks[ore_idx].area and is_instance_valid(gold_ore_blocks[ore_idx].area):
		gold_ore_blocks[ore_idx].area.queue_free()
	player_ref.gold_ore += 1
	queue_redraw()

func _get_reachable_tiles() -> Dictionary:
	var reachable = {}
	var start_cave = null
	for cave in caves:
		if cave.type == "start":
			start_cave = cave
			break
	if not start_cave:
		return reachable
	var sr = clampi(int(start_cave.y / tile_size), 0, grid_rows - 1)
	var sc = clampi(int(start_cave.x / tile_size), 0, grid_cols - 1)
	var queue = [[sr, sc]]
	reachable[sr * grid_cols + sc] = true
	while queue.size() > 0:
		var cell = queue.pop_front()
		for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var nr2 = cell[0] + d[0]
			var nc2 = cell[1] + d[1]
			if nr2 < 0 or nr2 >= grid_rows or nc2 < 0 or nc2 >= grid_cols:
				continue
			var k = nr2 * grid_cols + nc2
			if not reachable.has(k) and grid[nr2][nc2] == 0:
				reachable[k] = true
				queue.append([nr2, nc2])
	return reachable

# === PEARL ENEMY ===

func _spawn_pearl_enemy(enemy_scene: PackedScene, p_player_ref: CharacterBody2D):
	var enemy = enemy_scene.instantiate()
	var hp = (3 + room_level) * 20
	var spd = 25.0 + room_level * 3
	var dmg = 20
	# Random class, but visually distinct
	enemy.setup(2, hp, spd, dmg)  # THROWER
	enemy.player = p_player_ref
	enemy.drops_pearl = true

	var pos = _get_spawn_position()
	enemy.position = pos
	add_child(enemy)
	enemies.append(enemy)
	enemy.died.connect(_on_enemy_died)
	pearl_enemy = enemy

func _check_pearl_drop(enemy):
	if enemy == pearl_enemy and player_ref and is_instance_valid(player_ref):
		player_ref.has_pearl = true

# === CRAFTING STATIONS ===

func _spawn_craft_stations():
	craft_stations.clear()
	player_near_station = ""
	grate_used_this_level = false

	# Find start cave
	var start_cave = null
	for cave in caves:
		if cave.type == "start":
			start_cave = cave
			break
	if not start_cave:
		return

	var base_x = start_cave.x
	var floor_y = start_cave.floor_y

	# Place 3 stations in start cave: furnace (left), anvil (center), grate (right)
	var stations_data = [
		{"type": "furnace", "x": base_x - 20, "y": floor_y - 10},
		{"type": "anvil", "x": base_x + 10, "y": floor_y - 10},
		{"type": "grate", "x": base_x + 40, "y": floor_y - 10},
	]

	for data in stations_data:
		var area = Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1  # Detect player
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(30, 30)
		shape.shape = rect
		area.add_child(shape)
		area.position = Vector2(data.x, data.y)
		add_child(area)

		var station = {"type": data.type, "x": data.x, "y": data.y, "area": area}
		craft_stations.append(station)

		var station_type = data.type
		area.body_entered.connect(_on_station_entered.bind(station_type))
		area.body_exited.connect(_on_station_exited.bind(station_type))

func _on_station_entered(body, station_type: String):
	if body.is_in_group("player"):
		player_near_station = station_type

func _on_station_exited(body, station_type: String):
	if body.is_in_group("player") and player_near_station == station_type:
		player_near_station = ""

func _check_station_proximity():
	# Direct proximity check — more reliable than Area2D signals
	if not player_ref or not is_instance_valid(player_ref):
		player_near_station = ""
		return
	var found = ""
	for station in craft_stations:
		var dist = player_ref.global_position.distance_to(Vector2(station.x, station.y))
		if dist < 30:
			found = station.type
			break
	player_near_station = found

func _check_heart_proximity():
	# Direct proximity check for trial heart
	if not player_ref or not is_instance_valid(player_ref):
		player_near_heart = false
		return
	if trial_heart_pos == Vector2.ZERO or trial_active or trial_complete:
		player_near_heart = false
		return
	var dist = player_ref.global_position.distance_to(trial_heart_pos)
	player_near_heart = dist < 30

signal craft_message(text: String)
signal open_craft_menu_request(station_type: String)
signal open_shop_menu_request

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		# Chest
		if chest_near_idx >= 0 and chest_near_idx < chests.size():
			if not chests[chest_near_idx].opened:
				_open_chest(chest_near_idx)
				get_viewport().set_input_as_handled()
				return
		# Crafting stations — open menu via signal to main.gd
		if player_near_station != "":
			open_craft_menu_request.emit(player_near_station)
			get_viewport().set_input_as_handled()
			return
		# Wall sword pickup
		if player_near_sword and not wall_sword_taken:
			wall_sword_taken = true
			if player_ref and is_instance_valid(player_ref) and player_ref.has_method("equip_weapon"):
				player_ref.equip_weapon(1)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		# Trial heart
		if player_near_heart and not trial_active and not trial_complete:
			start_trial()
			craft_message.emit("TRIAL STARTED! Survive!")
			get_viewport().set_input_as_handled()
			return

func buy_shop_item(idx: int) -> String:
	# Покупка предмета из магазина (вызывается из main.gd когда HUD эмитит сигнал)
	if not player_ref or not is_instance_valid(player_ref):
		return ""
	if idx < 0 or idx >= merchant_items.size():
		return ""
	var item = merchant_items[idx]
	if item.get("bought", false):
		return "Уже куплено"
	var cost = item.cost
	var use_coins = item.get("coin", false)
	var can_buy = false
	if use_coins:
		can_buy = "coins" in player_ref and player_ref.coins >= cost
	else:
		can_buy = player_ref.health > cost
	if not can_buy:
		return "Не хватает!"
	if use_coins:
		player_ref.coins -= cost
		if player_ref.has_signal("coins_changed"):
			player_ref.coins_changed.emit(player_ref.coins)
	else:
		player_ref.health -= cost
		if player_ref.has_signal("health_changed"):
			player_ref.health_changed.emit(player_ref.health)
	item["bought"] = true
	match item.type:
		"heal": player_ref.heal(30)
		"weapon":
			var wid = item.get("weapon_id", randi_range(1, 13))
			if player_ref.has_method("equip_weapon"):
				player_ref.equip_weapon(wid)
		"card":
			if player_ref.has_method("equip_weapon"):
				player_ref.equip_weapon(randi_range(1, 19))
	queue_redraw()
	return "Куплено"

func get_shop_items_for_menu() -> Array:
	# Маппинг merchant_items в формат HUD shop menu
	var arr = []
	for it in merchant_items:
		var entry = {
			"label": it.get("label", ""),
			"desc": it.get("desc", ""),
			"type": it.get("type", ""),
			"rarity": it.get("rarity", "common"),
			"price": it.get("cost", 0),
			"bought": it.get("bought", false),
		}
		arr.append(entry)
	return arr

func close_shop():
	_shop_open_flag = false

func try_craft() -> String:
	# Called from main.gd when player presses E near a station
	if not player_ref or not is_instance_valid(player_ref):
		return ""

	match player_near_station:
		"furnace":
			if player_ref.iron_ore > 0:
				player_ref.iron_ore -= 1
				player_ref.iron_ingot += 1
				return "Smelted iron ingot!"
			elif player_ref.gold_ore > 0:
				player_ref.gold_ore -= 1
				player_ref.gold_ingot += 1
				return "Smelted gold ingot!"
			else:
				return "Need ore to smelt!"
		"anvil":
			# Priority: lockpick > amulet > sword merge
			# Отмычка крафтится из 1 железного слитка + кирка
			if player_ref.iron_ingot > 0 and player_ref.has_pickaxe and not player_ref.has_lockpick:
				player_ref.iron_ingot -= 1
				player_ref.has_lockpick = true
				return "Crafted lockpick!"
			elif player_ref.gold_ingot > 0 and player_ref.has_pearl:
				player_ref.gold_ingot -= 1
				player_ref.has_pearl = false
				player_ref.has_amulet = true
				player_ref.amulet_timer = player_ref.amulet_heal_interval
				return "Crafted amulet! +1 HP/10s"
			elif player_ref.iron_ingot > 0 and player_ref.has_blade and player_ref.sword_tier < 2:
				player_ref.iron_ingot -= 1
				player_ref.sword_tier = 2
				player_ref.attack_damage += 20
				return "Merged sword! +20 DMG"
			else:
				return "Need materials! (ingot+pickaxe/pearl/blade)"
		"grate":
			if not grate_used_this_level:
				grate_used_this_level = true
				player_ref.has_flask = true
				player_ref.flask_charges += 3
				return "Filled flask! +3 charges [F]"
			else:
				return "Grate already used this level!"
	return ""

func try_craft_recipe(station_type: String, recipe_index: int) -> String:
	if not player_ref or not is_instance_valid(player_ref):
		return ""

	match station_type:
		"furnace":
			match recipe_index:
				0:  # Iron Ore → Iron Ingot
					if player_ref.iron_ore > 0:
						player_ref.iron_ore -= 1
						player_ref.iron_ingot += 1
						return "Smelted Iron Ingot!"
					return "Need Iron Ore!"
				1:  # Gold Ore → Gold Ingot
					if player_ref.gold_ore > 0:
						player_ref.gold_ore -= 1
						player_ref.gold_ingot += 1
						return "Smelted Gold Ingot!"
					return "Need Gold Ore!"
		"anvil":
			match recipe_index:
				0:  # Iron Ingot + Pickaxe → Lockpick (1 слиток железа)
					if player_ref.iron_ingot > 0 and player_ref.has_pickaxe and not player_ref.has_lockpick:
						player_ref.iron_ingot -= 1
						player_ref.has_lockpick = true
						return "Crafted Lockpick!"
					if player_ref.has_lockpick:
						return "Lockpick already crafted!"
					return "Need Iron Ingot + Pickaxe!"
				1:  # Iron Ingot + Blade → Merged Sword
					if player_ref.iron_ingot > 0 and player_ref.has_blade and player_ref.sword_tier < 2:
						player_ref.iron_ingot -= 1
						player_ref.sword_tier = 2
						player_ref.attack_damage += 20
						return "Merged Sword! +20 DMG!"
					return "Need Iron Ingot + Blade!"
				2:  # Gold Ingot + Pearl → Amulet
					if player_ref.gold_ingot > 0 and player_ref.has_pearl:
						player_ref.gold_ingot -= 1
						player_ref.has_pearl = false
						player_ref.has_amulet = true
						player_ref.amulet_timer = player_ref.amulet_heal_interval
						return "Crafted Amulet! +1 HP/10s"
					return "Need Gold Ingot + Pearl!"
		"grate":
			match recipe_index:
				0:  # Fill Flask
					if not grate_used_this_level:
						grate_used_this_level = true
						player_ref.has_flask = true
						player_ref.flask_charges += 3
						return "Filled Flask! +3 charges [F]"
					return "Already used this level!"
	return ""

# === TRIAL ROOM ===

func _spawn_trial_heart():
	# Find a dead_end cave to use as trial room
	var trial_cave = null
	for cave in caves:
		if cave.type == "dead_end":
			trial_cave = cave
			break
	if not trial_cave:
		# Use any non-start, non-door cave
		for cave in caves:
			if cave.type != "start" and cave.type != "door":
				trial_cave = cave
				break
	if not trial_cave:
		return

	trial_cave.type = "trial"
	trial_heart_pos = Vector2(trial_cave.x, trial_cave.floor_y - 12)

	# Create heart Area2D
	trial_heart_area = Area2D.new()
	trial_heart_area.collision_layer = 0
	trial_heart_area.collision_mask = 1
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	shape.shape = rect
	trial_heart_area.add_child(shape)
	trial_heart_area.position = trial_heart_pos
	add_child(trial_heart_area)
	trial_heart_area.body_entered.connect(_on_heart_entered)
	trial_heart_area.body_exited.connect(_on_heart_exited)

func _on_heart_entered(body):
	if body.is_in_group("player"):
		player_near_heart = true

func _on_heart_exited(body):
	if body.is_in_group("player"):
		player_near_heart = false

func start_trial():
	if trial_active or trial_complete:
		return
	trial_active = true
	trial_enemies.clear()

	var enemy_scene_ref = load("res://scenes/enemy.tscn")

	# Spawn crossbow enemies from left and right
	for side in [-1, 1]:
		var cb = enemy_scene_ref.instantiate()
		var hp = (3 + room_level) * 15
		var spd = 25.0 + room_level * 2
		var dmg = mini(15 + room_level * 2, 30)
		cb.setup(1, hp, spd, dmg)  # CROSSBOW
		cb.player = player_ref
		cb.position = trial_heart_pos + Vector2(side * 80, 0)
		add_child(cb)
		trial_enemies.append(cb)
		cb.died.connect(_on_trial_enemy_died)

	# Spawn 2-3 random enemies
	var extra = randi_range(2, 3)
	for i in extra:
		var e = enemy_scene_ref.instantiate()
		var eclass = [0, 2, 3][randi() % 3]
		var hp = (2 + room_level) * 20
		var spd = 30.0 + room_level * 4
		var dmg = 20 * (1 + room_level / 3)
		if room_level >= 5:
			dmg *= 2
		if eclass == 3:
			hp += 40
		e.setup(eclass, hp, spd, dmg)
		e.player = player_ref
		var angle = randf() * TAU
		e.position = trial_heart_pos + Vector2(cos(angle) * 60, sin(angle) * 30)
		add_child(e)
		trial_enemies.append(e)
		e.died.connect(_on_trial_enemy_died)

	# Remove heart visual
	if trial_heart_area and is_instance_valid(trial_heart_area):
		trial_heart_area.queue_free()
		trial_heart_area = null

func _on_trial_enemy_died(enemy):
	trial_enemies.erase(enemy)
	if trial_enemies.size() == 0 and trial_active:
		trial_active = false
		trial_complete = true
		trial_completed.emit()

# === LEGENDARY TRIAL ROOM (every 3 levels) ===

func _spawn_legend_trial():
	# Find a dead_end cave different from trial heart
	var trial_cave = null
	for cave in caves:
		if cave.type == "dead_end" and Vector2(cave.x, cave.floor_y) != trial_heart_pos:
			trial_cave = cave
			break
	if not trial_cave:
		for cave in caves:
			if cave.type != "start" and cave.type != "door" and cave.type != "trial":
				trial_cave = cave
				break
	if not trial_cave:
		return

	trial_cave.type = "legend_trial"
	legend_trial_pos = Vector2(trial_cave.x, trial_cave.floor_y - 12)

	# Pick a random legendary weapon for the reward
	var legend_weapons = [20, 21, 22]  # Sword&Shield, Golden Staff, Torch
	legend_trial_weapon_id = legend_weapons[randi() % legend_weapons.size()]

	# Create pickup area
	legend_trial_area = Area2D.new()
	legend_trial_area.collision_layer = 0
	legend_trial_area.collision_mask = 1
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	shape.shape = rect
	legend_trial_area.add_child(shape)
	legend_trial_area.position = legend_trial_pos
	add_child(legend_trial_area)
	legend_trial_area.body_entered.connect(_on_legend_entered)
	legend_trial_area.body_exited.connect(_on_legend_exited)

func _on_legend_entered(body):
	if body.is_in_group("player"):
		player_near_legend = true

func _on_legend_exited(body):
	if body.is_in_group("player"):
		player_near_legend = false

func _check_legend_proximity():
	if legend_trial_pos == Vector2.ZERO or legend_trial_active or legend_trial_complete:
		return
	if not player_ref or not is_instance_valid(player_ref):
		return
	var dist = player_ref.global_position.distance_to(legend_trial_pos)
	if dist < 20 and player_near_legend:
		# Auto-start when player touches the weapon pedestal
		start_legend_trial()

func start_legend_trial():
	if legend_trial_active or legend_trial_complete:
		return
	legend_trial_active = true
	legend_trial_enemies.clear()

	var enemy_scene_ref = load("res://scenes/enemy.tscn")

	# Spawn tough enemies — harder than normal trial
	var count = 4 + room_level / 2
	count = mini(count, 8)
	for i in count:
		var e = enemy_scene_ref.instantiate()
		var eclass = [0, 1, 2, 3][randi() % 4]
		var hp = (4 + room_level) * 20
		var spd = 35.0 + room_level * 4
		var dmg = 25 * (1 + room_level / 3)
		if room_level >= 5:
			dmg *= 2
		if eclass == 3:
			hp += 60
		e.setup(eclass, hp, spd, dmg)
		e.player = player_ref
		var angle = (float(i) / float(count)) * TAU
		e.position = legend_trial_pos + Vector2(cos(angle) * 70, sin(angle) * 30)
		add_child(e)
		legend_trial_enemies.append(e)
		enemies.append(e)
		e.died.connect(_on_legend_trial_enemy_died)

	# Show message
	if player_ref and player_ref.has_method("equip_weapon"):
		player_ref.weapon_pickup_msg = "УБЕЙ ВСЕХ ЧТОБЫ ЗАБРАТЬ ОРУЖИЕ!"
		player_ref.weapon_msg_timer = 3.0

	# Remove pickup area
	if legend_trial_area and is_instance_valid(legend_trial_area):
		legend_trial_area.queue_free()
		legend_trial_area = null

func _on_legend_trial_enemy_died(enemy):
	legend_trial_enemies.erase(enemy)
	if legend_trial_enemies.size() == 0 and legend_trial_active:
		legend_trial_active = false
		legend_trial_complete = true
		legend_weapon_chest_placed = true
		# Give the legendary weapon directly
		if player_ref and is_instance_valid(player_ref) and player_ref.has_method("equip_weapon"):
			player_ref.equip_weapon(legend_trial_weapon_id)
			player_ref.weapon_pickup_msg = "ЛЕГЕНДАРНОЕ ОРУЖИЕ!"
			player_ref.weapon_msg_timer = 3.0
		queue_redraw()

# === CRYSTAL PLACEMENT (Level 3 challenge) ===

func start_crystal_placement():
	# Player places crystal at their current position using mined ore
	if not player_ref or not is_instance_valid(player_ref):
		return
	if player_ref.ore_mined < player_ref.ore_needed:
		return

	challenge_started = true
	challenge_complete_flag = false

	# Spawn crystal at player position
	crystal_node = Node2D.new()
	crystal_node.set_script(crystal_script)
	crystal_node.position = player_ref.global_position + Vector2(0, -5)
	# 240 HP = each of 4 enemies needs 3 hits (4*3*20=240), scales with level
	crystal_node.health = 240 + room_level * 20
	crystal_node.max_health = crystal_node.health
	add_child(crystal_node)
	crystal_node.crystal_destroyed.connect(_on_crystal_destroyed)

	# Spawn 4 enemies that attack ONLY the crystal, near the crystal
	var enemy_scene_ref = load("res://scenes/enemy.tscn")
	var enemy_classes = [0, 2, 3]
	if room_level >= 3:
		enemy_classes.append(1)

	for i in 4:
		var attacker = enemy_scene_ref.instantiate()
		var eclass = enemy_classes[randi() % enemy_classes.size()]
		var hp = (2 + room_level) * 20
		var spd = 30.0 + room_level * 4
		var dmg = 20
		if eclass == 3:
			hp += 40
		attacker.setup(eclass, hp, spd, dmg)
		attacker.player = player_ref
		attacker.crystal_target = crystal_node

		# Spawn near crystal (within 60-120 px)
		var angle = randf() * TAU
		var dist = randf_range(60, 120)
		var spawn_pos = crystal_node.position + Vector2(cos(angle) * dist, sin(angle) * dist * 0.5)
		# Clamp to room bounds
		spawn_pos.x = clampf(spawn_pos.x, 50, room_width - 50)
		spawn_pos.y = clampf(spawn_pos.y, 50, room_height - 50)
		attacker.position = spawn_pos
		add_child(attacker)
		crystal_attackers.append(attacker)
		attacker.died.connect(_on_crystal_attacker_died)

	# Reset player ore (used up to make crystal)
	player_ref.ore_mined = 0

# === DRAWING ===

func _tile_shade(r: int, c: int) -> float:
	# Deterministic pseudo-random shade per tile
	var n = (r * 127 + c * 311 + room_level * 37)
	return fmod(abs(sin(float(n) * 0.7134)) * 43758.5453, 1.0) * 0.06 - 0.03

func _get_visible_tile_range() -> Array:
	# Отсечение по камере: декор/руда рисуются только в видимой области, а не
	# по всей комнате. Раньше возвращался весь грид — и room._draw отправлял
	# тысячи команд на GPU каждый кадр (постоянный лаг). Перерисовка при смене
	# видимой области делается в _process (_check_draw_cull).
	if tile_size <= 0:
		return [0, grid_cols, 0, grid_rows]
	# Центр — позиция игрока (надёжнее get_camera_2d, который мог быть null).
	var center: Vector2
	if player_ref and is_instance_valid(player_ref):
		center = player_ref.global_position
	else:
		return [0, grid_cols, 0, grid_rows]
	var halfx := 260.0
	var halfy := 170.0
	var c0 := clampi(int((center.x - halfx) / tile_size), 0, grid_cols)
	var c1 := clampi(int((center.x + halfx) / tile_size) + 1, 0, grid_cols)
	var r0 := clampi(int((center.y - halfy) / tile_size), 0, grid_rows)
	var r1 := clampi(int((center.y + halfy) / tile_size) + 1, 0, grid_rows)
	return [c0, c1, r0, r1]

var _last_draw_vr: Array = [-1, -1, -1, -1]

func _check_draw_cull() -> void:
	# Перерисовываем комнату только когда видимая область тайлов сменилась
	var vr = _get_visible_tile_range()
	if vr != _last_draw_vr:
		_last_draw_vr = vr
		queue_redraw()

func _draw_wall_background():
	# Полупрозрачная заливка — параллакс-фон должен просвечивать сквозь неё
	draw_rect(Rect2(0, 0, room_width, room_height),
		Color(bg_color.r, bg_color.g, bg_color.b, 0.55))

	if wall_bg_texture == null:
		return

	# Tile the texture across the whole room (no parallax)
	var tw: float = 128.0
	var th: float = 128.0
	var p_ox: float = 0.0
	var p_oy: float = 0.0
	var cols: int = int(room_width  / tw) + 1
	var rows_t: int = int(room_height / th) + 1

	# Biome tint colour
	var tint: Color
	match room_level % 4:
		0: tint = Color(1.0, 1.0, 1.0, 0.55)          # neutral grey
		1: tint = Color(0.75, 1.0, 0.75, 0.55)         # mossy green
		2: tint = Color(1.0, 0.88, 0.68, 0.55)         # warm sandstone
		_: tint = Color(0.75, 0.85, 1.0,  0.55)        # cold blue

	for row in rows_t:
		for col in cols:
			var x: float = col * tw - p_ox - tw
			var y: float = row * th - p_oy - th
			draw_texture_rect(wall_bg_texture, Rect2(x, y, tw, th), false, tint)

	# Dark vignette — makes the background feel deeper/darker than foreground
	draw_rect(Rect2(0, 0, room_width, room_height), Color(0, 0, 0, 0.38))

# ── Horror helpers ────────────────────────────────────────────────────────────
func _spawn_ceiling_drip() -> void:
	var vr = _get_visible_tile_range()
	for _att in 15:
		var c = randi_range(vr[0], maxi(vr[0], vr[1] - 1))
		var r = randi_range(vr[2], maxi(vr[2], vr[3] - 2))
		if c < grid_cols and r + 1 < grid_rows:
			if grid[r][c] == 1 and grid[r + 1][c] == 0:
				_blood_drips.append({
					"x":       c * tile_size + randf_range(2.0, tile_size - 2.0),
					"y":       (r + 1) * tile_size,
					"len":     0.0,
					"max_len": randf_range(14.0, 55.0),
					"speed":   randf_range(5.0, 16.0),
					"alpha":   randf_range(0.50, 0.78),
				})
				return

func _draw_horror_effects() -> void:
	# Blood drips
	for d in _blood_drips:
		if d.len > 0.0:
			draw_line(Vector2(d.x, d.y), Vector2(d.x, d.y + d.len),
				Color(0.50, 0.02, 0.02, d.alpha), 1.8)
			if d.len >= d.max_len * 0.75:
				draw_circle(Vector2(d.x, d.y + d.len), 2.8,
					Color(0.44, 0.01, 0.01, d.alpha * 0.85))

	# Face in wall
	if _face_t >= 0.0:
		var elapsed  = _face_dur - _face_t
		var fade_in  = clampf(elapsed / 1.5, 0.0, 1.0)
		var fade_out = clampf(_face_t / 1.5, 0.0, 1.0)
		_draw_horror_face(_face_wx, _face_wy, fade_in * fade_out * 0.52)

	# Wall text — carved into stone surface
	if _wtext_t >= 0.0:
		var elapsed  = _wtext_dur - _wtext_t
		var fade_in  = clampf(elapsed / 1.2, 0.0, 1.0)
		var fade_out = clampf(_wtext_t / 1.2, 0.0, 1.0)
		var ta       = fade_in * fade_out * 0.38
		# Shadow offset gives "engraved" look
		draw_string(ThemeDB.fallback_font,
			Vector2(_wtext_wx + 1.0, _wtext_wy + 1.0), _wtext_msg,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.08, 0.06, 0.06, ta * 0.9))
		draw_string(ThemeDB.fallback_font,
			Vector2(_wtext_wx, _wtext_wy), _wtext_msg,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.58, 0.54, 0.50, ta))

	# Death counter
	if horror_total_deaths > 5 and _death_label_pos != Vector2.ZERO:
		var msg = "ты умирал " + str(horror_total_deaths) + " раз"
		draw_string(ThemeDB.fallback_font,
			_death_label_pos, msg,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.55, 0.50, 0.45, 0.30))

func _draw_horror_face(fx: float, fy: float, alpha: float) -> void:
	if alpha < 0.01: return
	# All colors blend with stone — barely perceptible shadow impressions
	var shadow = Color(0.20, 0.18, 0.17, alpha)
	var dark   = Color(0.10, 0.08, 0.08, alpha)

	# Eye sockets — just two dark smudges, no outline
	for ex in [-7.0, 7.0]:
		draw_rect(Rect2(fx + ex - 4.0, fy - 11.0, 8.0, 6.0), shadow)
		draw_rect(Rect2(fx + ex - 3.0, fy - 10.0, 6.0, 4.0), dark)
		# Faint red glint inside each socket
		draw_circle(Vector2(fx + ex, fy - 8.5), 1.4, Color(0.45, 0.03, 0.03, alpha * 0.7))

	# Nose — a narrow vertical shadow
	draw_rect(Rect2(fx - 2.0, fy - 2.0, 4.0, 7.0), shadow)

	# Mouth — a dark horizontal crack, slightly open
	draw_rect(Rect2(fx - 9.0, fy + 7.0, 18.0, 2.5), shadow)
	draw_rect(Rect2(fx - 7.0, fy + 8.0, 14.0, 1.5), dark)

	# Subtle brow ridges — barely lighter than stone
	draw_line(Vector2(fx - 13.0, fy - 14.0), Vector2(fx - 3.0, fy - 12.0),
		Color(0.50, 0.46, 0.43, alpha * 0.4), 1.2)
	draw_line(Vector2(fx + 3.0,  fy - 12.0), Vector2(fx + 13.0, fy - 14.0),
		Color(0.50, 0.46, 0.43, alpha * 0.4), 1.2)

func _draw_corpse(cp: Dictionary):
	var px = cp.x
	var py = cp.y
	var bone = Color(0.78, 0.72, 0.60)
	var bone_dark = Color(0.45, 0.40, 0.32)
	var flesh = Color(0.55, 0.10, 0.10)
	var blood = Color(0.30, 0.02, 0.02, 0.9)
	# Тень-кровавый ореол под трупом
	draw_circle(Vector2(px, py + 1), 12.0, blood)
	match cp.type:
		0:
			# Скелет на спине: череп, рёбра, тазовые кости
			draw_circle(Vector2(px - 6, py - 2), 4.0, bone)            # череп
			draw_circle(Vector2(px - 7.5, py - 2.5), 0.8, bone_dark)    # глаз
			draw_circle(Vector2(px - 4.5, py - 2.5), 0.8, bone_dark)    # глаз
			# Рёбра
			for i in 4:
				var rx = px - 2 + i * 3
				draw_rect(Rect2(rx, py - 4, 1.2, 8), bone)
			draw_rect(Rect2(px - 2, py - 4, 14, 1.2), bone)             # позвоночник верх
			# Таз
			draw_rect(Rect2(px + 11, py - 3, 5, 6), bone)
			# Руки/ноги
			draw_line(Vector2(px - 2, py - 4), Vector2(px - 8, py + 4),
				bone, 1.3)
			draw_line(Vector2(px + 11, py + 3), Vector2(px + 16, py + 6),
				bone, 1.3)
		1:
			# Кровавый торс — без головы, с торчащими костями
			draw_rect(Rect2(px - 6, py - 8, 14, 9), flesh)
			# Рваные края
			for i in 5:
				var tx = px - 5 + i * 3
				draw_rect(Rect2(tx, py - 10, 2, 3), flesh)
			# Кости из мяса
			draw_rect(Rect2(px - 1, py - 13, 1.5, 6), bone)
			draw_rect(Rect2(px + 4, py - 12, 1.5, 5), bone)
			# Кровавая дорожка
			draw_rect(Rect2(px - 2, py - 2, 8, 4), blood)
		2:
			# Куча костей: несколько разбросанных
			draw_circle(Vector2(px, py - 1), 3.0, bone)               # маленький череп
			draw_rect(Rect2(px - 6, py + 1, 10, 1.5), bone)            # длинная кость
			draw_rect(Rect2(px - 4, py + 3, 8, 1.5), bone)
			draw_rect(Rect2(px - 1, py - 4, 1.5, 4), bone)
			draw_circle(Vector2(px + 5, py + 2), 1.0, bone_dark)

var dbg_draw_ms: float = 0.0

func _draw():
	var _ddt0 := Time.get_ticks_usec()
	_draw_body()
	dbg_draw_ms = (Time.get_ticks_usec() - _ddt0) / 1000.0

func _draw_body():
	# Статичные тайлы/фон/кромки рисует tile_layer (отдельный кэш-слой).
	# Здесь — только динамика (кровь, декор, сундуки, бочки и т.п.).

	# === BLOOD POOLS (после тайлов, с анимированными бликами) ===
	var blood_t = Time.get_ticks_msec() * 0.001
	for pool in blood_pools:
		draw_circle(Vector2(pool.x, pool.y), pool.r, Color(0.45, 0.02, 0.02, pool.alpha))
		draw_circle(Vector2(pool.x - pool.r * 0.3, pool.y - 1), pool.r * 0.5,
			Color(0.30, 0.01, 0.01, pool.alpha * 0.75))
		# Ripple — мерцающий блик на поверхности
		var ripple_t = sin(blood_t * 2.0 + pool.x * 0.05)
		var ripple_a = (0.5 + 0.5 * ripple_t) * pool.alpha * 0.6
		var rip_offset = Vector2(pool.r * 0.25 * sin(blood_t + pool.x * 0.03),
			pool.r * 0.1 * cos(blood_t * 0.7 + pool.y * 0.05))
		draw_circle(Vector2(pool.x, pool.y - pool.r * 0.4) + rip_offset,
			pool.r * 0.20, Color(0.85, 0.35, 0.30, ripple_a))

	# === RUSH B graffiti (CS пасхалка) ===
	if is_rush_b:
		var font := ThemeDB.fallback_font
		for g in rush_b_graffiti:
			var txt = g.text
			var fsize = 18
			var size = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
			# Тёмная "потёкшая" обводка
			draw_set_transform(Vector2(g.x, g.y), g.angle, Vector2.ONE)
			for ox in [-2, -1, 0, 1, 2]:
				for oy in [-2, -1, 0, 1, 2]:
					draw_string(font, Vector2(-size.x * 0.5 + ox, oy),
						txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
						Color(0.10, 0.00, 0.00, 0.6))
			# Сам красный текст
			draw_string(font, Vector2(-size.x * 0.5, 0),
				txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
				Color(0.85, 0.08, 0.08, 0.92))
			# Стекающая капля под буквой
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_rect(Rect2(g.x - 1, g.y + 2, 2, 6),
				Color(0.60, 0.05, 0.05, 0.75))

	# === MEAT ROOM DECOR — большие кровавые лужи + трупы ===
	if is_meat_room:
		var meat_t = Time.get_ticks_msec() * 0.001
		# Лужи (большие, перекрывающиеся, анимированные)
		for mp in meat_blood_pools:
			draw_circle(Vector2(mp.x, mp.y), mp.r,
				Color(0.30, 0.02, 0.02, 0.95))
			draw_circle(Vector2(mp.x - mp.r * 0.25, mp.y - 1), mp.r * 0.55,
				Color(0.50, 0.05, 0.05, 0.75))
			# Анимированный блик (движется по поверхности)
			var rip_phase = sin(meat_t * 1.5 + mp.x * 0.02)
			var rip_offset = Vector2(mp.r * 0.25 * rip_phase,
				mp.r * 0.1 * cos(meat_t + mp.y * 0.03))
			var rip_a = 0.45 * (0.6 + 0.4 * abs(rip_phase))
			draw_circle(Vector2(mp.x + mp.r * 0.2, mp.y - mp.r * 0.3) + rip_offset,
				mp.r * 0.15, Color(0.95, 0.30, 0.25, rip_a))
		# Трупы
		for cp in corpses:
			_draw_corpse(cp)

	# Draw barrels
	for barrel in barrels:
		if not barrel.active: continue
		var bx = barrel.pos.x
		var by = barrel.pos.y
		var lit = barrel.fuse > 0.0
		# Soft shadow под бочкой
		var b_sh = PackedVector2Array()
		for s in 12:
			var a = float(s) / 12.0 * TAU
			b_sh.append(Vector2(bx + cos(a) * 8, by + 7 + sin(a) * 2.2))
		draw_colored_polygon(b_sh, Color(0, 0, 0, 0.4))
		# Мигание красным когда фитиль горит (чем меньше остаётся, тем чаще)
		var body_col = Color(0.42, 0.28, 0.12)
		if lit:
			var blink_speed = 6.0 + (2.0 - barrel.fuse) * 8.0
			var blink = (sin(barrel.fuse * blink_speed) + 1.0) * 0.5
			body_col = Color(0.42, 0.28, 0.12).lerp(Color(1.0, 0.2, 0.1), blink * 0.7)
		draw_rect(Rect2(bx - 6, by - 14, 12, 18), body_col)  # body
		draw_rect(Rect2(bx - 7, by - 15, 14, 3), Color(0.28, 0.18, 0.08))   # top ring
		draw_rect(Rect2(bx - 7, by - 4, 14, 3),  Color(0.28, 0.18, 0.08))   # mid ring
		draw_rect(Rect2(bx - 7, by + 3, 14, 3),  Color(0.28, 0.18, 0.08))   # bot ring
		draw_rect(Rect2(bx - 1, by - 14, 2, 18), Color(0.55, 0.38, 0.18, 0.5))  # grain line
		if lit:
			# Фитиль сверху
			draw_line(Vector2(bx, by - 15), Vector2(bx, by - 22), Color(0.2, 0.15, 0.1), 1.5)
			# Искра на конце фитиля (мигает)
			var spark_r = 1.5 + randf() * 1.5
			draw_circle(Vector2(bx, by - 22), spark_r, Color(1.0, 0.85, 0.2))
			draw_circle(Vector2(bx, by - 22), spark_r * 0.5, Color(1.0, 1.0, 0.8))
			# Цифра таймера над бочкой
			var txt = str(ceil(barrel.fuse))
			var font := ThemeDB.fallback_font
			var fsize := 14
			var tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			# Тёмный фон-обводка
			for ox in [-1, 0, 1]:
				for oy in [-1, 0, 1]:
					draw_string(font, Vector2(bx - tw * 0.5 + ox, by - 28 + oy), txt,
						HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0))
			draw_string(font, Vector2(bx - tw * 0.5, by - 28), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1.0, 0.9, 0.3))

	# Кромки поверхностей теперь рисует tile_layer (кэш-слой)

	# Boss room lava
	if is_boss_room and not is_lava_boss:
		_draw_lava()
	# Лавовый паркур — поднимающаяся лава
	if is_lava_boss:
		_draw_rising_lava()

	# Decorations
	if not is_boss_room:
		_draw_decorations()

	# Ore blocks
	_draw_ore_blocks()

	# Gold ore blocks
	_draw_gold_ore_blocks()

	# Crafting stations
	_draw_craft_stations()

	# Trial heart
	_draw_trial_heart()

	# Legendary trial
	_draw_legend_trial()

	# Vines / lianas
	_draw_ladders()
	_draw_oneway_platforms()

	# Chests
	_draw_chests()

	# Sword in wall (start room)
	if wall_sword_pos != Vector2.ZERO and not wall_sword_taken:
		_draw_wall_sword()

	# Traps
	_draw_traps()

	# === ARENA GATES ===
	if is_arena_level and arena_active:
		for gate_x in [room_width * 0.25, room_width * 0.75]:
			for bar in 5:
				var by = room_height * 0.35 + bar * 18.0
				draw_rect(Rect2(gate_x - 4, by, 8, 14), Color(0.55, 0.32, 0.08, 0.95))
				draw_rect(Rect2(gate_x - 3, by + 1, 6, 12), Color(0.40, 0.22, 0.05))
		var blink = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.5
		draw_string(ThemeDB.fallback_font, Vector2(room_width * 0.5, room_height * 0.22),
			"АРЕНА!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1, 0.3, 0.1, blink))

	# === SECRET ROOM HINTS ===
	for sr in secret_rooms:
		if not sr.revealed:
			var t = Time.get_ticks_msec() * 0.002
			var shimmer = 0.04 + sin(t + sr.wall_c) * 0.035
			draw_rect(Rect2(sr.wall_c * tile_size, sr.wall_r * tile_size, tile_size * 2, tile_size * 4),
				Color(0.85, 0.75, 0.3, shimmer))

	# === ROOM EVENTS ===
	if room_event == "merchant" and not event_used and merchant_pos != Vector2.ZERO:
		var mp = merchant_pos
		# --- Shop room background & decorations ---
		if merchant_room.size() > 0:
			var rx_l: float = merchant_room.x_left
			var rx_r: float = merchant_room.x_right
			var ry_t: float = merchant_room.y_top
			var ry_b: float = merchant_room.y_bot
			var rw: float   = rx_r - rx_l
			var rh: float   = ry_b - ry_t
			# Warm background
			draw_rect(Rect2(rx_l, ry_t, rw, rh), Color(0.25, 0.20, 0.08, 0.92))
			# Back wall (top strip)
			draw_rect(Rect2(rx_l, ry_t, rw, tile_size * 2), Color(0.30, 0.22, 0.10))
			# Shelves on back wall — 2 rows of small boxes
			var shelf_y1: float = ry_t + tile_size * 0.5
			var shelf_y2: float = ry_t + tile_size * 1.5
			var shelf_cols: int = 6
			var shelf_gap: float = rw / float(shelf_cols + 1)
			for si in shelf_cols:
				var sx: float = rx_l + shelf_gap * float(si + 1)
				draw_rect(Rect2(sx - 5, shelf_y1 - 4, 10, 7), Color(0.55, 0.40, 0.18))
				draw_rect(Rect2(sx - 4, shelf_y2 - 3, 8, 5), Color(0.48, 0.35, 0.15))
				draw_rect(Rect2(sx - 3, shelf_y1 - 3, 6, 5), Color(0.70, 0.55, 0.28, 0.7))
			# Lanterns — two glowing orange circles on back wall corners
			var lantern_flicker: float = 0.65 + sin(Time.get_ticks_msec() * 0.0045) * 0.20
			var l1: Vector2 = Vector2(rx_l + 20, ry_t + tile_size)
			var l2: Vector2 = Vector2(rx_r - 20, ry_t + tile_size)
			draw_circle(l1, 9, Color(0.9, 0.55, 0.05, lantern_flicker * 0.55))
			draw_circle(l1, 5, Color(1.0, 0.80, 0.25, lantern_flicker))
			draw_circle(l2, 9, Color(0.9, 0.55, 0.05, lantern_flicker * 0.55))
			draw_circle(l2, 5, Color(1.0, 0.80, 0.25, lantern_flicker))
			# Counter
			var ct_x: float = merchant_room.counter_x
			var ct_y: float = merchant_room.counter_y
			var ct_w: float = merchant_room.counter_w
			var ct_h: float = merchant_room.counter_h
			draw_rect(Rect2(ct_x, ct_y, ct_w, ct_h), Color(0.42, 0.28, 0.10))
			draw_rect(Rect2(ct_x, ct_y, ct_w, 3), Color(0.58, 0.42, 0.18))  # top edge highlight
			draw_rect(Rect2(ct_x, ct_y, 3, ct_h), Color(0.55, 0.38, 0.14))  # left edge
			draw_rect(Rect2(ct_x + ct_w - 3, ct_y, 3, ct_h), Color(0.55, 0.38, 0.14))  # right edge
			# "ЛАВКА" sign above entrance — centered at bottom of room
			var sign_cx: float = (rx_l + rx_r) * 0.5
			draw_rect(Rect2(sign_cx - 30, ry_b - 14, 60, 12), Color(0.30, 0.18, 0.06))
			draw_rect(Rect2(sign_cx - 29, ry_b - 13, 58, 10), Color(0.20, 0.12, 0.04))
			draw_string(ThemeDB.fallback_font, Vector2(sign_cx, ry_b - 4),
				"ЛАВКА", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(1.0, 0.85, 0.25, 0.95))
		# --- Merchant figure ---
		draw_rect(Rect2(mp.x - 5, mp.y - 16, 10, 14), Color(0.40, 0.30, 0.14))   # body
		draw_rect(Rect2(mp.x - 4, mp.y - 22, 8, 7), Color(0.85, 0.70, 0.50))      # head
		draw_rect(Rect2(mp.x - 7, mp.y - 27, 14, 5), Color(0.30, 0.18, 0.06))     # hat brim
		draw_rect(Rect2(mp.x - 5, mp.y - 33, 10, 8), Color(0.22, 0.13, 0.04))     # hat top
		# --- Shop panel (shown when player is near) ---
		if player_ref and is_instance_valid(player_ref):
			var dist_to_m: float = player_ref.global_position.distance_to(merchant_pos)
			if dist_to_m < 80:
				var panel_w: float = 200.0
				var row_h: float   = 15.0
				var panel_h: float = 16.0 + merchant_items.size() * row_h + 36.0  # title + items + footer
				var px: float = mp.x - panel_w * 0.5
				var py: float = mp.y - 42.0 - panel_h
				# Panel background
				draw_rect(Rect2(px, py, panel_w, panel_h), Color(0.08, 0.06, 0.03, 0.92))
				# Gold border
				draw_rect(Rect2(px,                  py,                  panel_w, 2),   Color(0.85, 0.70, 0.20))
				draw_rect(Rect2(px,                  py + panel_h - 2,    panel_w, 2),   Color(0.85, 0.70, 0.20))
				draw_rect(Rect2(px,                  py,                  2, panel_h),   Color(0.85, 0.70, 0.20))
				draw_rect(Rect2(px + panel_w - 2,    py,                  2, panel_h),   Color(0.85, 0.70, 0.20))
				# Title row
				draw_string(ThemeDB.fallback_font, Vector2(mp.x, py + 13),
					"ЛАВКА", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1.0, 0.85, 0.25, 0.95))
				draw_rect(Rect2(px + 4, py + 16, panel_w - 8, 1), Color(0.85, 0.70, 0.20, 0.5))
				# Item rows
				var rarity_colors: Dictionary = {
					"common": Color(0.80, 0.80, 0.80),
					"uncommon": Color(0.30, 0.85, 0.30),
					"rare": Color(0.25, 0.50, 1.00),
					"legendary": Color(1.00, 0.70, 0.10),
				}
				for i in merchant_items.size():
					var item = merchant_items[i]
					var iy: float = py + 20.0 + i * row_h
					var is_bought: bool = item.get("bought", false)
					var is_sel: bool = (i == merchant_selected) and not is_bought
					# Highlight row
					if is_sel:
						draw_rect(Rect2(px + 3, iy - 1, panel_w - 6, row_h - 1), Color(0.35, 0.28, 0.08, 0.7))
					# Index number
					var num_col: Color = Color(0.6, 0.6, 0.6, 0.5) if is_bought else Color(0.9, 0.85, 0.5, 0.9)
					draw_string(ThemeDB.fallback_font, Vector2(px + 10, iy + row_h - 4),
						str(i + 1) + ".", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, num_col)
					# Rarity dot for weapons
					if item.type == "weapon":
						var rar: String = item.get("rarity", "common")
						var dot_col: Color = rarity_colors.get(rar, Color(0.8, 0.8, 0.8))
						if is_bought:
							dot_col.a = 0.3
						draw_circle(Vector2(px + 27, iy + row_h * 0.5 - 1), 3, dot_col)
					# Item name + price
					var name_text: String = item.label
					var text_col: Color = Color(0.5, 0.5, 0.5, 0.4) if is_bought else (
						Color(1.0, 0.95, 0.65) if is_sel else Color(0.85, 0.80, 0.55, 0.9)
					)
					draw_string(ThemeDB.fallback_font, Vector2(px + 34, iy + row_h - 4),
						name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, text_col)
					# Coin icon
					if not is_bought:
						draw_circle(Vector2(px + panel_w - 18, iy + row_h * 0.5 - 1), 4, Color(1.0, 0.85, 0.15))
					else:
						# Greyed strikethrough bar
						draw_rect(Rect2(px + 34, iy + row_h * 0.5 - 1, panel_w - 50, 1), Color(0.5, 0.5, 0.5, 0.4))
				# Footer divider
				var footer_y: float = py + 20.0 + merchant_items.size() * row_h + 2.0
				draw_rect(Rect2(px + 4, footer_y, panel_w - 8, 1), Color(0.85, 0.70, 0.20, 0.4))
				# Controls hint
				draw_string(ThemeDB.fallback_font, Vector2(mp.x, footer_y + 11),
					"[W/S] выбор   [E] купить", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(0.65, 0.65, 0.65, 0.85))
				# Coin count
				var coins_val: int = player_ref.get("coins") if "coins" in player_ref else 0
				draw_string(ThemeDB.fallback_font, Vector2(mp.x, footer_y + 24),
					"У вас: " + str(coins_val) + " C", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(1.0, 0.85, 0.25, 0.9))

	if room_event == "altar":
		var ap = Vector2(room_width * 0.5, room_height * 0.45)
		draw_rect(Rect2(ap.x - 9, ap.y, 18, 9), Color(0.35, 0.30, 0.45))
		draw_rect(Rect2(ap.x - 7, ap.y - 5, 14, 6), Color(0.40, 0.35, 0.50))
		if not altar_used:
			var t2 = Time.get_ticks_msec() * 0.003
			var g = 0.28 + sin(t2) * 0.12
			draw_circle(ap + Vector2(0, -5), 13, Color(0.6, 0.2, 1.0, g))
			draw_string(ThemeDB.fallback_font, Vector2(ap.x, ap.y - 24),
				"АЛТАРЬ [-3HP]", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.85, 0.55, 1.0, 0.95))
			if player_ref and is_instance_valid(player_ref):
				if player_ref.global_position.distance_to(Vector2(room_width * 0.5, room_height * 0.45)) < 30:
					draw_string(ThemeDB.fallback_font, Vector2(ap.x, ap.y + 18),
						"[E]", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 1, 0.4, 0.95))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(ap.x, ap.y - 16),
				"ИСПОЛЬЗОВАН", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(0.5, 0.5, 0.5, 0.6))

	if room_event == "cursed":
		var t3 = Time.get_ticks_msec() * 0.003
		var blink2 = 0.55 + sin(t3 * 2) * 0.4
		draw_string(ThemeDB.fallback_font, Vector2(room_width * 0.5, 35),
			"☠ ПРОКЛЯТАЯ КОМНАТА ☠", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.65, 0.1, 0.85, blink2))

	# World-space horror effects
	_draw_horror_effects()

func _draw_traps():
	# Spikes — sharp metal spikes on floor
	for sp in spikes:
		var x = sp.x
		var y = sp.y
		var w = sp.w
		# Base plate
		draw_rect(Rect2(x - 1, y - 2, w + 2, 3), Color(0.3, 0.3, 0.33))
		var num_sp = int(w / 5)
		for i in num_sp:
			var sx = x + i * 5 + 2.5
			# Main spike triangle
			draw_colored_polygon(
				PackedVector2Array([Vector2(sx - 2.5, y - 1), Vector2(sx, y - 9), Vector2(sx + 2.5, y - 1)]),
				Color(0.5, 0.5, 0.55, 0.9))
			# Highlight on spike tip
			draw_line(Vector2(sx, y - 9), Vector2(sx + 0.5, y - 5), Color(0.75, 0.75, 0.8, 0.5), 0.7)
			# Blood stain occasionally
			if fmod(float(i) * 3.7, 5.0) < 1.0:
				draw_circle(Vector2(sx, y - 4), 1.0, Color(0.6, 0.1, 0.1, 0.4))

	# Poison pools (with optional pipes)
	for pp in poison_pipes:
		# Draw pipe if present
		if pp.get("has_pipe", true):
			var px = pp.x
			var py = pp.y
			if px != 0.0:
				var pdir = pp.dir
				draw_rect(Rect2(px, py - 3, pdir * 12, 6), Color(0.3, 0.35, 0.3))
				draw_rect(Rect2(px + pdir * 10, py - 4, pdir * 4, 8), Color(0.25, 0.3, 0.25))
				var drip_x = px + pdir * 12
				var t = fmod(Time.get_ticks_msec() * 0.003, 1.0)
				draw_circle(Vector2(drip_x, py + 3 + t * 10), 1.5, Color(0.2, 0.85, 0.1, 1.0 - t))
		# Poison pool — big puddle
		var pool_x = pp.pool_x
		var pool_y = pp.pool_y
		var pool_w = pp.pool_w
		var pool_h = pp.get("pool_h", 8.0)
		# Dark base layer — full depth
		draw_rect(Rect2(pool_x, pool_y - pool_h, pool_w, pool_h + 2), Color(0.05, 0.3, 0.02, 0.55))
		# Main pool body — slightly inset
		draw_rect(Rect2(pool_x + 2, pool_y - pool_h + 1, pool_w - 4, pool_h - 1), Color(0.12, 0.55, 0.04, 0.7))
		# Bright green surface
		draw_rect(Rect2(pool_x + 3, pool_y - pool_h + 1, pool_w - 6, 3), Color(0.25, 0.8, 0.08, 0.5))
		# Surface ripple
		var ripple_t = fmod(Time.get_ticks_msec() * 0.001, 1.0)
		var ripple_x = pool_x + pool_w * ripple_t
		draw_line(Vector2(ripple_x - 3, pool_y - pool_h + 2), Vector2(ripple_x + 3, pool_y - pool_h + 2), Color(0.4, 0.95, 0.15, 0.4), 1.0)
		# Bubbles
		for bi in 5:
			var bx = pool_x + pool_w * (0.1 + 0.18 * bi)
			var by = pool_y - pool_h + 3
			var bubble_t = fmod(Time.get_ticks_msec() * 0.002 + bi * 0.7, 2.0)
			if bubble_t < 1.0:
				draw_circle(Vector2(bx, by - bubble_t * (pool_h - 4)), 1.5 - bubble_t * 0.5, Color(0.3, 0.9, 0.1, 0.5 - bubble_t * 0.3))

	# Pressure plates
	for plate in pressure_plates:
		var px = plate.x
		var py = plate.y
		var is_down = plate.triggered
		# Slightly visible plate on floor
		var plate_color = Color(0.4, 0.38, 0.35, 0.5) if not is_down else Color(0.5, 0.3, 0.2, 0.7)
		draw_rect(Rect2(px - 6, py - 1, 12, 2), plate_color)
		draw_line(Vector2(px - 5, py - 1), Vector2(px + 5, py - 1), Color(0.55, 0.5, 0.45, 0.3), 0.5)

func _draw_solid_tiles():
	# Only draw tiles visible on screen (viewport culling)
	var vr = _get_visible_tile_range()
	var c_min = vr[0]
	var c_max = vr[1]
	var r_min = vr[2]
	var r_max = vr[3]

	if stone_texture:
		# Draw stone texture on each tile
		var tex_w = stone_texture.get_width()
		var tex_h = stone_texture.get_height()
		for r in range(r_min, r_max):
			for c in range(c_min, c_max):
				if c < grid_cols and grid[r][c] == 1:
					var x = c * tile_size
					var y = r * tile_size
					# Tile the texture — use modulo for seamless tiling
					var src_x = (c * tile_size) % tex_w
					var src_y = (r * tile_size) % tex_h
					var src_w = mini(tile_size, tex_w - src_x)
					var src_h = mini(tile_size, tex_h - src_y)
					var src_rect = Rect2(src_x, src_y, src_w, src_h)
					var dst_rect = Rect2(x, y, tile_size, tile_size)
					draw_texture_rect_region(stone_texture, dst_rect, src_rect)
	else:
		# Lucid-Blocks стиль: каждый тайл рисуется как voxel-блок с фактурой
		# — основной цвет, верхний highlight, левый/нижний/правый shadow,
		#   шумовые "крапинки" для текстуры (детерминированно от позиции)
		var hl = rock_light
		var sh = Color(rock_dark.r * 0.65, rock_dark.g * 0.65, rock_dark.b * 0.65)
		var sh_inner = Color(rock_dark.r, rock_dark.g, rock_dark.b, 0.45)
		# "Крапинки" — чуть темнее/светлее основного, для детализации
		var speck_dark  = Color(rock_dark.r,  rock_dark.g,  rock_dark.b,  0.55)
		var speck_light = Color(rock_light.r, rock_light.g, rock_light.b, 0.45)
		for r in range(r_min, r_max):
			for c in range(c_min, c_max):
				if c >= grid_cols or grid[r][c] != 1:
					continue
				var x = c * tile_size
				var y = r * tile_size
				# 1) Базовая заливка
				draw_rect(Rect2(x, y, tile_size, tile_size), rock_color)
				# 2) Top highlight (свет сверху)
				draw_rect(Rect2(x, y, tile_size, 2), hl)
				# 3) Left edge — чуть светлее тоже (как ребро воксела)
				draw_rect(Rect2(x, y, 1, tile_size), Color(hl.r, hl.g, hl.b, 0.65))
				# 4) Bottom shadow
				draw_rect(Rect2(x, y + tile_size - 2, tile_size, 2), sh)
				# 5) Right edge shadow
				draw_rect(Rect2(x + tile_size - 1, y + 2, 1, tile_size - 4), sh_inner)
				# 6) Inner shadow gradient (3px над нижним краем)
				draw_rect(Rect2(x + 1, y + tile_size - 5, tile_size - 2, 3), sh_inner)
				# 7) Шумовые "крапинки" — 2 на тайл (детерм. от хеша r,c)
				var h = (r * 73 + c * 131) & 0xFF
				var sp1x = x + 3 + (h % 8)
				var sp1y = y + 4 + ((h >> 3) % 6)
				draw_rect(Rect2(sp1x, sp1y, 1, 1), speck_dark)
				var sp2x = x + 6 + ((h >> 2) % 7)
				var sp2y = y + 7 + ((h >> 4) % 5)
				draw_rect(Rect2(sp2x, sp2y, 1, 1), speck_light)
				# 8) Top-left corner highlight pixel (как угловой блик)
				draw_rect(Rect2(x + 1, y + 1, 1, 1), hl)
				draw_rect(Rect2(x + 2, y + 1, 1, 1),
					Color(hl.r, hl.g, hl.b, 0.7))

func _draw_surface_edges():
	var vr = _get_visible_tile_range()
	var c_min = vr[0]
	var c_max = vr[1]
	var r_min = vr[2]
	var r_max = vr[3]
	var ceil_col = Color(rock_dark.r - 0.05, rock_dark.g - 0.05, rock_dark.b - 0.03)
	var light_col = Color(rock_light.r, rock_light.g, rock_light.b, 0.5)

	# Floor surfaces — merged runs (only visible rows)
	for r in range(maxi(1, r_min), r_max):
		var run_start = -1
		for c in range(c_min, c_max + 1):
			var is_floor = c < c_max and c < grid_cols and grid[r][c] == 1 and grid[r - 1][c] == 0
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

	# Ceiling surfaces — merged runs (only visible rows)
	for r in range(r_min, mini(grid_rows - 1, r_max)):
		var run_start = -1
		for c in range(c_min, c_max + 1):
			var is_ceil = c < c_max and c < grid_cols and grid[r][c] == 1 and grid[r + 1][c] == 0
			if is_ceil:
				if run_start == -1:
					run_start = c
			else:
				if run_start != -1:
					var x = run_start * tile_size
					var w = (c - run_start) * tile_size
					draw_rect(Rect2(x, (r + 1) * tile_size - 2, w, 2), ceil_col)
					run_start = -1

	# Right wall surfaces (solid with open to left)
	for r in range(grid_rows):
		for c in range(1, grid_cols):
			if grid[r][c] == 1 and grid[r][c - 1] == 0:
				draw_rect(Rect2(c * tile_size, r * tile_size, 2, tile_size),
					Color(rock_dark.r, rock_dark.g, rock_dark.b, 0.6))

func _draw_rising_lava():
	var t = Time.get_ticks_msec() * 0.002
	var ly = lava_y
	# Свечение над поверхностью
	draw_rect(Rect2(0, ly - 12, room_width, 12), Color(1, 0.35, 0.05, 0.25))
	# Волнистая поверхность
	for c in range(0, int(room_width), 6):
		var wave = sin(t * 2.0 + c * 0.04) * 4
		var col = Color(1, 0.45, 0.08) if fmod(float(c) * 0.1 + t, 2.0) < 1.0 else Color(1, 0.65, 0.12)
		draw_rect(Rect2(c, ly + wave, 6, 4), col)
	# Тело лавы вниз
	draw_rect(Rect2(0, ly + 4, room_width, room_height - ly), Color(0.85, 0.25, 0.03))
	# Пузыри
	for i in 14:
		var bx = fmod(float(i) * 91.0 + t * 18, room_width)
		var by = ly + 14 + sin(t + i) * 6
		draw_circle(Vector2(bx, by), 4, Color(1, 0.6, 0.1, 0.4))
	# Предупреждающая полоса (мигает)
	var warn = 0.5 + 0.5 * sin(t * 8.0)
	draw_rect(Rect2(0, ly - 3, room_width, 2), Color(1, 0.9, 0.2, warn * 0.7))

func _draw_lava():
	if not is_boss_room:
		return
	# Не рисуем лаву если её нет (lava_y = 99999 = отключена)
	if lava_y >= room_height:
		return
	var lava_row = grid_rows - 4
	var ly = float(lava_row * tile_size)
	var t = Time.get_ticks_msec() * 0.002

	# Lava glow above surface
	draw_rect(Rect2(0, ly - 8, room_width, 8), Color(1, 0.3, 0.05, 0.15))

	# Lava surface (animated waves)
	for c in range(0, int(room_width), 4):
		var wave = sin(t + c * 0.05) * 3
		var col_a = Color(1, 0.4, 0.05, 0.9)
		var col_b = Color(1, 0.6, 0.1, 0.8)
		var col = col_a if fmod(float(c) * 0.1 + t, 2.0) < 1.0 else col_b
		draw_rect(Rect2(c, ly + wave, 4, 3), col)

	# Lava body
	draw_rect(Rect2(0, ly + 3, room_width, room_height - ly), Color(0.8, 0.25, 0.02))
	# Bright spots
	for i in 10:
		var bx = fmod(float(i) * 137.0 + t * 20, room_width)
		var by = ly + 8 + sin(t * 0.5 + i) * 5
		draw_circle(Vector2(bx, by), 6, Color(1, 0.6, 0.1, 0.3))

	# "GOLEM" boss name
	if golem_boss and is_instance_valid(golem_boss) and not golem_boss.is_dead:
		draw_string(ThemeDB.fallback_font, Vector2(room_width / 2 - 30, 30),
			"GOLEM", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.9, 0.4, 0.1, 0.8))

func _draw_decorations():
	var vr = _get_visible_tile_range()
	var c_min = vr[0]
	var c_max = vr[1]
	var r_min = vr[2]
	var r_max = vr[3]

	# Stalactites hanging from ceiling surfaces (only visible)
	var c_start_s = maxi(5, c_min - (c_min % 4))
	for c in range(c_start_s, mini(grid_cols - 5, c_max), 4):
		for r in range(maxi(3, r_min), mini(grid_rows - 3, r_max)):
			if grid[r][c] == 1 and r + 1 < grid_rows and grid[r + 1][c] == 0:
				var shade = _tile_shade(r, c)
				if shade > 0.01:
					var sx = c * tile_size + tile_size / 2
					var sy = (r + 1) * tile_size
					var sh = 4 + int(abs(shade) * 200) % 10
					var sw = 2 + int(abs(shade) * 100) % 3
					draw_rect(Rect2(sx - sw / 2, sy, sw, sh),
						Color(rock_dark.r + 0.05, rock_dark.g + 0.04, rock_dark.b + 0.02))
					draw_line(Vector2(sx, sy + sh), Vector2(sx, sy + sh + 2),
						Color(rock_dark.r, rock_dark.g, rock_dark.b), 1.0)

	# Moss on some floor tiles (only visible)
	var c_start_m = maxi(4, c_min - (c_min % 6))
	for c in range(c_start_m, mini(grid_cols - 4, c_max), 6):
		for r in range(maxi(3, r_min), mini(grid_rows - 3, r_max)):
			if grid[r][c] == 1 and r > 0 and grid[r - 1][c] == 0:
				var shade = _tile_shade(r, c + 1)
				if shade < -0.01:
					var mx = c * tile_size
					var mw = tile_size + int(abs(shade) * 200) % (tile_size * 2)
					draw_rect(Rect2(mx, r * tile_size - 1, mw, 2),
						Color(0.2, 0.35, 0.15, 0.3))

	# Skulls on floor in some caves
	if room_level >= 2:
		for cave in caves:
			if cave.type == "dead_end":
				var bx = cave.x
				var by = cave.floor_y
				draw_circle(Vector2(bx, by - 2), 3, Color(0.7, 0.65, 0.55, 0.3))
				draw_rect(Rect2(bx - 2, by - 4, 1, 1), Color(0.1, 0.1, 0.1, 0.3))
				draw_rect(Rect2(bx + 1, by - 4, 1, 1), Color(0.1, 0.1, 0.1, 0.3))

	# === VASES on floors (deterministic placement using tile_shade) ===
	for c in range(maxi(5, c_min), mini(grid_cols - 5, c_max), 7):
		for r in range(maxi(4, r_min), mini(grid_rows - 4, r_max)):
			if grid[r][c] == 1 and r > 0 and grid[r - 1][c] == 0:
				var shade = _tile_shade(r, c)
				if shade > 0.015:
					var vx = c * tile_size + tile_size / 2
					var vy = r * tile_size
					var vtype = int(abs(shade) * 1000) % 3  # 0=tall, 1=round, 2=small

					if vtype == 0:
						# Tall vase
						draw_rect(Rect2(vx - 3, vy - 10, 6, 10), Color(0.55, 0.35, 0.2, 0.8))
						draw_rect(Rect2(vx - 4, vy - 11, 8, 2), Color(0.6, 0.4, 0.25, 0.8))
						draw_rect(Rect2(vx - 2, vy - 12, 4, 2), Color(0.5, 0.3, 0.18, 0.8))
						# Pattern
						draw_line(Vector2(vx - 2, vy - 6), Vector2(vx + 2, vy - 6),
							Color(0.7, 0.5, 0.3, 0.5), 1.0)
					elif vtype == 1:
						# Round pot
						draw_circle(Vector2(vx, vy - 5), 4, Color(0.5, 0.32, 0.18, 0.8))
						draw_rect(Rect2(vx - 3, vy - 2, 6, 2), Color(0.45, 0.3, 0.15, 0.8))
						draw_rect(Rect2(vx - 2, vy - 9, 4, 2), Color(0.55, 0.35, 0.2, 0.7))
					else:
						# Small jar
						draw_rect(Rect2(vx - 2, vy - 6, 4, 6), Color(0.5, 0.38, 0.22, 0.8))
						draw_rect(Rect2(vx - 1, vy - 7, 2, 1), Color(0.55, 0.4, 0.25, 0.7))

	# === BUSHES / grass tufts on floors ===
	for c in range(maxi(4, c_min), mini(grid_cols - 4, c_max), 5):
		for r in range(maxi(4, r_min), mini(grid_rows - 4, r_max)):
			if grid[r][c] == 1 and r > 0 and grid[r - 1][c] == 0:
				var shade = _tile_shade(r, c + 2)
				if shade < -0.005:
					var bx = c * tile_size + tile_size / 2
					var by = r * tile_size
					var btype = int(abs(shade) * 2000) % 3

					if btype == 0:
						# Small bush (3 circles)
						draw_circle(Vector2(bx - 3, by - 4), 3, Color(0.2, 0.38, 0.15, 0.65))
						draw_circle(Vector2(bx + 2, by - 5), 4, Color(0.18, 0.42, 0.13, 0.6))
						draw_circle(Vector2(bx, by - 6), 3, Color(0.22, 0.45, 0.17, 0.55))
					elif btype == 1:
						# Grass tuft (lines sticking up)
						for gi in range(-3, 4):
							var gh = 3 + int(abs(sin(float(gi + c) * 2.3)) * 5)
							draw_line(Vector2(bx + gi * 2, by),
								Vector2(bx + gi * 2 + 1, by - gh),
								Color(0.2, 0.4, 0.15, 0.5), 1.0)
					else:
						# Weeds
						draw_line(Vector2(bx - 2, by), Vector2(bx - 4, by - 7),
							Color(0.25, 0.4, 0.18, 0.5), 1.0)
						draw_line(Vector2(bx, by), Vector2(bx + 1, by - 8),
							Color(0.22, 0.38, 0.15, 0.5), 1.0)
						draw_line(Vector2(bx + 3, by), Vector2(bx + 5, by - 6),
							Color(0.25, 0.42, 0.17, 0.45), 1.0)

	# === CHAINS hanging from ceilings ===
	for c in range(maxi(5, c_min), mini(grid_cols - 5, c_max), 11):
		for r in range(maxi(3, r_min), mini(grid_rows - 3, r_max)):
			if grid[r][c] == 1 and r + 1 < grid_rows and grid[r + 1][c] == 0:
				var shade = _tile_shade(r, c + 3)
				if shade > 0.02:
					var cx = c * tile_size + tile_size / 2
					var cy = (r + 1) * tile_size
					var chain_len = 3 + int(abs(shade) * 200) % 6
					for ci in range(chain_len):
						var link_y = cy + ci * 4
						var col_a = Color(0.4, 0.38, 0.35, 0.6) if ci % 2 == 0 else Color(0.35, 0.33, 0.3, 0.5)
						draw_rect(Rect2(cx - 1, link_y, 2, 3), col_a)

func _draw_ore_blocks():
	var t = Time.get_ticks_msec() * 0.002
	for ore in ore_blocks:
		if ore.mined:
			continue
		var ox = ore.x - 8
		var oy = ore.y - 8
		# Soft shadow под рудой
		var sh_pts = PackedVector2Array()
		for s in 14:
			var a = float(s) / 14.0 * TAU
			sh_pts.append(Vector2(ore.x + cos(a) * 10, ore.y + 8 + sin(a) * 2.5))
		draw_colored_polygon(sh_pts, Color(0, 0, 0, 0.35))
		# Большой пульсирующий glow вокруг руды (привлекает внимание)
		var pulse = 0.55 + 0.45 * sin(t + ore.x * 0.05)
		draw_circle(Vector2(ore.x, ore.y), 18, Color(0.95, 0.55, 0.20, 0.10 * pulse))
		draw_circle(Vector2(ore.x, ore.y), 12, Color(1.00, 0.70, 0.30, 0.18 * pulse))
		# Iron ore block - детализированный с voxel-edges
		draw_rect(Rect2(ox, oy, 16, 16), Color(0.35, 0.33, 0.30))
		draw_rect(Rect2(ox + 1, oy + 1, 14, 14), Color(0.42, 0.40, 0.36))
		# Iron specks (light metallic) с мерцанием
		var spk = 0.85 + sin(t * 3.0 + ore.x) * 0.15
		draw_rect(Rect2(ox + 3, oy + 3, 3, 2), Color(0.85 * spk, 0.65 * spk, 0.40 * spk))
		draw_rect(Rect2(ox + 9, oy + 5, 2, 3), Color(0.90 * spk, 0.70 * spk, 0.45 * spk))
		draw_rect(Rect2(ox + 5, oy + 10, 3, 2), Color(0.80 * spk, 0.60 * spk, 0.35 * spk))
		draw_rect(Rect2(ox + 11, oy + 11, 2, 2), Color(0.85 * spk, 0.62 * spk, 0.38 * spk))
		# Edge highlights (top + left)
		draw_rect(Rect2(ox, oy, 16, 1), Color(0.55, 0.52, 0.46))
		draw_rect(Rect2(ox, oy, 1, 16), Color(0.50, 0.48, 0.42))
		# Bottom shadow
		draw_rect(Rect2(ox, oy + 15, 16, 1), Color(0.20, 0.18, 0.15))
		# Sparkle — раз в ~2 сек на одной из жил блестит белый
		var sparkle_phase = fmod(t * 0.5 + ore.x * 0.01, 1.0)
		if sparkle_phase < 0.10:
			var sp_intensity = sin(sparkle_phase / 0.10 * PI)
			draw_circle(Vector2(ox + 5, oy + 4), 1.5, Color(1, 1, 1, sp_intensity * 0.9))
			draw_circle(Vector2(ox + 5, oy + 4), 3, Color(1, 0.9, 0.7, sp_intensity * 0.4))

func _draw_gold_ore_blocks():
	for ore in gold_ore_blocks:
		if ore.mined:
			continue
		var ox = ore.x - 8
		var oy = ore.y - 8
		var t_g = Time.get_ticks_msec() * 0.002
		# Soft shadow
		var sh_pts_g = PackedVector2Array()
		for s in 14:
			var a = float(s) / 14.0 * TAU
			sh_pts_g.append(Vector2(ore.x + cos(a) * 10, ore.y + 8 + sin(a) * 2.5))
		draw_colored_polygon(sh_pts_g, Color(0, 0, 0, 0.35))
		# Большой золотой glow (выраженный — это редкая руда)
		var pulse_g = 0.55 + 0.45 * sin(t_g * 1.5 + ore.x * 0.05)
		draw_circle(Vector2(ore.x, ore.y), 22, Color(1, 0.85, 0.20, 0.12 * pulse_g))
		draw_circle(Vector2(ore.x, ore.y), 14, Color(1, 0.92, 0.30, 0.25 * pulse_g))
		# Gold ore block
		draw_rect(Rect2(ox, oy, 16, 16), Color(0.40, 0.35, 0.20))
		draw_rect(Rect2(ox + 1, oy + 1, 14, 14), Color(0.48, 0.42, 0.26))
		# Gold specks (мерцают)
		var spk_g = 0.90 + sin(t_g * 4.0 + ore.x) * 0.10
		draw_rect(Rect2(ox + 3, oy + 3, 3, 2), Color(1 * spk_g, 0.85 * spk_g, 0.20))
		draw_rect(Rect2(ox + 9, oy + 5, 2, 3), Color(1 * spk_g, 0.90 * spk_g, 0.30))
		draw_rect(Rect2(ox + 5, oy + 10, 3, 2), Color(1 * spk_g, 0.85 * spk_g, 0.20))
		draw_rect(Rect2(ox + 11, oy + 11, 2, 2), Color(0.95 * spk_g, 0.80 * spk_g, 0.15))
		# Edge highlights
		draw_rect(Rect2(ox, oy, 16, 1), Color(1, 0.92, 0.35))
		draw_rect(Rect2(ox, oy, 1, 16), Color(0.85, 0.75, 0.25))
		draw_rect(Rect2(ox, oy + 15, 16, 1), Color(0.30, 0.22, 0.08))
		# Sparkle (золото мерцает чаще)
		var sp_phase = fmod(t_g * 0.8 + ore.x * 0.02, 1.0)
		if sp_phase < 0.12:
			var sp_i = sin(sp_phase / 0.12 * PI)
			draw_circle(Vector2(ox + 9, oy + 5), 2.0, Color(1, 1, 1, sp_i * 0.95))
			draw_circle(Vector2(ox + 9, oy + 5), 4, Color(1, 0.95, 0.7, sp_i * 0.5))

func _draw_craft_stations():
	for station in craft_stations:
		var sx = station.x
		var sy = station.y
		match station.type:
			"furnace":
				# Furnace - stone block with fire
				draw_rect(Rect2(sx - 8, sy - 8, 16, 16), Color(0.4, 0.35, 0.3))
				draw_rect(Rect2(sx - 7, sy - 7, 14, 14), Color(0.5, 0.45, 0.38))
				# Fire opening
				draw_rect(Rect2(sx - 4, sy - 2, 8, 8), Color(0.15, 0.08, 0.05))
				# Fire glow
				var t = Time.get_ticks_msec() * 0.005
				var flicker = 0.5 + sin(t) * 0.2
				draw_rect(Rect2(sx - 3, sy + 1, 6, 4), Color(1, 0.5, 0.1, flicker))
				draw_rect(Rect2(sx - 2, sy - 1, 4, 3), Color(1, 0.8, 0.2, flicker * 0.7))
				# Chimney
				draw_rect(Rect2(sx - 2, sy - 12, 4, 5), Color(0.45, 0.4, 0.35))
			"anvil":
				# Anvil - metal block
				draw_rect(Rect2(sx - 8, sy + 2, 16, 6), Color(0.35, 0.35, 0.38))
				draw_rect(Rect2(sx - 6, sy - 4, 12, 7), Color(0.42, 0.42, 0.46))
				draw_rect(Rect2(sx - 10, sy - 2, 20, 3), Color(0.48, 0.48, 0.52))
				# Horn
				draw_rect(Rect2(sx + 8, sy - 3, 4, 2), Color(0.45, 0.45, 0.5))
				# Highlight
				draw_rect(Rect2(sx - 9, sy - 2, 18, 1), Color(0.6, 0.6, 0.65, 0.5))
			"grate":
				# Grate - iron bars over stone
				draw_rect(Rect2(sx - 8, sy - 2, 16, 10), Color(0.3, 0.28, 0.25))
				# Bars
				for i in 5:
					draw_rect(Rect2(sx - 7 + i * 3, sy - 4, 2, 12), Color(0.5, 0.5, 0.55))
				# Water/liquid glow underneath
				draw_rect(Rect2(sx - 6, sy + 2, 12, 4), Color(0.2, 0.5, 0.7, 0.3))

		# Label when player is near
		if player_near_station == station.type:
			var label = ""
			match station.type:
				"furnace": label = "[E] Smelt"
				"anvil": label = "[E] Craft"
				"grate": label = "[E] Fill Flask"
			draw_string(ThemeDB.fallback_font, Vector2(sx - 20, sy - 18),
				label, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(1, 1, 0.5, 0.9))

func _draw_trial_heart():
	if trial_complete or trial_active or trial_heart_pos == Vector2.ZERO:
		return
	var hx = trial_heart_pos.x
	var hy = trial_heart_pos.y
	var t = Time.get_ticks_msec() * 0.003
	var pulse = 1.0 + sin(t * 2) * 0.1

	# Glowing heart
	draw_circle(Vector2(hx, hy), 14 * pulse, Color(1, 0.2, 0.3, 0.15))
	# Heart shape using rects
	draw_rect(Rect2(hx - 6, hy - 4, 5, 5), Color(0.9, 0.15, 0.2, 0.9))
	draw_rect(Rect2(hx + 1, hy - 4, 5, 5), Color(0.9, 0.15, 0.2, 0.9))
	draw_rect(Rect2(hx - 7, hy - 6, 6, 4), Color(0.9, 0.15, 0.2, 0.9))
	draw_rect(Rect2(hx + 1, hy - 6, 6, 4), Color(0.9, 0.15, 0.2, 0.9))
	draw_rect(Rect2(hx - 5, hy + 1, 10, 3), Color(0.9, 0.15, 0.2, 0.9))
	draw_rect(Rect2(hx - 3, hy + 4, 6, 2), Color(0.9, 0.15, 0.2, 0.9))
	draw_rect(Rect2(hx - 1, hy + 6, 2, 2), Color(0.9, 0.15, 0.2, 0.9))
	# Highlight
	draw_rect(Rect2(hx - 5, hy - 5, 3, 2), Color(1, 0.5, 0.5, 0.5))

	# Label
	if player_near_heart:
		draw_string(ThemeDB.fallback_font, Vector2(hx - 25, hy - 16),
			"[E] Trial (+50% HP)", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(1, 0.3, 0.3, 0.9))

func _draw_legend_trial():
	if legend_trial_pos == Vector2.ZERO:
		return
	var lx = legend_trial_pos.x
	var ly = legend_trial_pos.y
	var t = Time.get_ticks_msec() * 0.003

	if legend_trial_complete:
		# Show empty pedestal after weapon taken
		draw_rect(Rect2(lx - 10, ly + 2, 20, 6), Color(0.5, 0.45, 0.3))
		draw_rect(Rect2(lx - 8, ly + 3, 16, 4), Color(0.6, 0.55, 0.35))
		return

	if legend_trial_active:
		# Show enemies remaining counter
		var alive = 0
		for e in legend_trial_enemies:
			if is_instance_valid(e):
				alive += 1
		var msg = "ОСТАЛОСЬ: " + str(alive)
		draw_string(ThemeDB.fallback_font, Vector2(lx - 25, ly - 24),
			msg, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 0.3, 0.2, 0.9))
		# Pulsing danger indicator
		var pulse = 0.5 + sin(t * 4) * 0.3
		draw_circle(Vector2(lx, ly), 20, Color(1, 0.2, 0.1, pulse * 0.15))
		return

	# Draw weapon on pedestal (before trial starts)
	var pulse = 1.0 + sin(t * 2) * 0.15

	# Stone pedestal
	draw_rect(Rect2(lx - 10, ly + 2, 20, 6), Color(0.5, 0.45, 0.3))
	draw_rect(Rect2(lx - 12, ly + 6, 24, 4), Color(0.45, 0.4, 0.28))
	draw_rect(Rect2(lx - 8, ly + 3, 16, 4), Color(0.6, 0.55, 0.35))

	# Golden glow
	draw_circle(Vector2(lx, ly - 4), 16 * pulse, Color(1, 0.85, 0.2, 0.12))
	draw_circle(Vector2(lx, ly - 4), 10 * pulse, Color(1, 0.9, 0.3, 0.2))

	# Weapon silhouette based on type
	match legend_trial_weapon_id:
		20:  # Sword & Shield
			# Sword
			draw_line(Vector2(lx - 3, ly - 12), Vector2(lx - 3, ly), Color(0.9, 0.85, 0.5), 2)
			draw_line(Vector2(lx - 6, ly - 4), Vector2(lx, ly - 4), Color(0.9, 0.85, 0.5), 2)
			# Shield
			draw_rect(Rect2(lx + 2, ly - 10, 8, 10), Color(0.8, 0.75, 0.4, 0.8))
			draw_rect(Rect2(lx + 4, ly - 8, 4, 6), Color(0.9, 0.85, 0.5, 0.6))
		21:  # Golden Staff
			draw_line(Vector2(lx, ly - 14), Vector2(lx, ly + 2), Color(1, 0.9, 0.3), 2.5)
			draw_circle(Vector2(lx, ly - 14), 3, Color(1, 0.95, 0.5, 0.8))
		22:  # Torch
			draw_line(Vector2(lx, ly - 10), Vector2(lx, ly + 2), Color(0.6, 0.4, 0.2), 2.5)
			# Flame
			var flicker = sin(t * 6) * 2
			draw_circle(Vector2(lx + flicker * 0.3, ly - 12), 4, Color(1, 0.6, 0.1, 0.7))
			draw_circle(Vector2(lx, ly - 13), 3, Color(1, 0.9, 0.3, 0.5))

	# Label
	var weapon_name = ""
	match legend_trial_weapon_id:
		20: weapon_name = "Меч и Щит"
		21: weapon_name = "Золотая Палка"
		22: weapon_name = "Факел"
	draw_string(ThemeDB.fallback_font, Vector2(lx - 30, ly - 20),
		weapon_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(1, 0.9, 0.4, 0.9))
	if player_near_legend:
		draw_string(ThemeDB.fallback_font, Vector2(lx - 20, ly + 16),
			"[ПОДОЙДИ]", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(1, 0.8, 0.3, 0.8))

func get_ladder_at(px: float, py: float) -> Dictionary:
	# Check if position is near a ladder (for climbing)
	for lad in ladders:
		if abs(px - lad.x) < 24 and py >= lad.y_top - 24 and py <= lad.y_bottom + 8:
			return lad
	return {}

# Legacy compatibility
func get_vine_at(px: float, py: float) -> Dictionary:
	return get_ladder_at(px, py)

func _draw_ladders():
	var vr = _get_visible_tile_range()
	var c_min = vr[0]
	var c_max = vr[1]
	var r_min_px = vr[2] * tile_size - 32
	var r_max_px = vr[3] * tile_size + 32

	var rail_col = Color(0.45, 0.35, 0.2, 0.9)
	var rung_col = Color(0.5, 0.4, 0.25, 0.85)

	for lad in ladders:
		if lad.col < c_min - 1 or lad.col > c_max + 1:
			continue
		if lad.y_bottom < r_min_px or lad.y_top > r_max_px:
			continue

		var lx = lad.x
		var ly_top = lad.y_top
		var ly_bot = lad.y_bottom
		var lad_len = ly_bot - ly_top

		# Two vertical rails
		draw_line(Vector2(lx - 4, ly_top), Vector2(lx - 4, ly_bot), rail_col, 1.5)
		draw_line(Vector2(lx + 4, ly_top), Vector2(lx + 4, ly_bot), rail_col, 1.5)

		# Horizontal rungs every 10px
		var rung_step = 10
		for i in range(0, int(lad_len), rung_step):
			var ry = ly_top + i + 4
			if ry < ly_bot:
				draw_line(Vector2(lx - 4, ry), Vector2(lx + 4, ry), rung_col, 1.0)

		# Top bracket
		draw_rect(Rect2(lx - 5, ly_top - 2, 10, 3), rail_col)

func _draw_oneway_platforms():
	var vr = _get_visible_tile_range()
	var c_min_px = vr[0] * tile_size - 32
	var c_max_px = vr[1] * tile_size + 32

	for plat in oneway_platforms:
		if plat.x + plat.w < c_min_px or plat.x > c_max_px:
			continue
		# Thin platform line (can jump through from below)
		draw_rect(Rect2(plat.x, plat.y, plat.w, 3), surface_color)
		draw_rect(Rect2(plat.x, plat.y + 3, plat.w, 1), rock_dark)
		# Dotted underside (visual cue: one-way)
		for dx in range(0, int(plat.w), 8):
			draw_rect(Rect2(plat.x + dx + 1, plat.y + 4, 3, 1),
				Color(rock_dark.r, rock_dark.g, rock_dark.b, 0.3))

func _draw_chests():
	var t_chest = Time.get_ticks_msec() * 0.002
	for ci in chests.size():
		var chest = chests[ci]
		var cx = chest.x
		var cy = chest.y
		var wid = chest.get("weapon_id", -1)

		# Soft shadow под сундуком (любой)
		var ch_sh_pts = PackedVector2Array()
		for s in 14:
			var a = float(s) / 14.0 * TAU
			ch_sh_pts.append(Vector2(cx + cos(a) * 11, cy + 7 + sin(a) * 2.8))
		draw_colored_polygon(ch_sh_pts, Color(0, 0, 0, 0.42))

		if chest.opened:
			# Open chest body
			draw_rect(Rect2(cx - 8, cy - 4, 16, 10), Color(0.45, 0.3, 0.15))
			draw_rect(Rect2(cx - 7, cy - 3, 14, 8), Color(0.55, 0.38, 0.2))
			draw_rect(Rect2(cx - 8, cy - 10, 16, 6), Color(0.5, 0.33, 0.17))
			draw_rect(Rect2(cx - 8, cy - 1, 16, 1), Color(0.6, 0.55, 0.3))
			draw_rect(Rect2(cx - 6, cy - 3, 12, 5), Color(0.2, 0.15, 0.08))
		else:
			# Closed chest body
			draw_rect(Rect2(cx - 8, cy - 4, 16, 10), Color(0.45, 0.3, 0.15))
			draw_rect(Rect2(cx - 7, cy - 3, 14, 8), Color(0.55, 0.38, 0.2))
			draw_rect(Rect2(cx - 9, cy - 8, 18, 5), Color(0.5, 0.33, 0.17))
			draw_rect(Rect2(cx - 8, cy - 7, 16, 3), Color(0.55, 0.38, 0.2))
			draw_rect(Rect2(cx - 9, cy - 5, 18, 1), Color(0.6, 0.55, 0.3))
			draw_rect(Rect2(cx - 2, cy - 5, 4, 4), Color(0.65, 0.6, 0.3))
			draw_rect(Rect2(cx - 1, cy - 4, 2, 2), Color(0.3, 0.25, 0.1))
			# Glow color по CS-rarity оружия в сундуке
			if wid >= 0:
				var rarity = "common"
				if player_ref and "weapon_data" in player_ref:
					var wd = player_ref.weapon_data.get(wid, {})
					rarity = wd.get("rarity", "common")
				var rar_col = _rarity_glow_color(rarity)
				# Пульсирующее свечение
				var pulse_chest = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.003 + cx * 0.01)
				draw_circle(Vector2(cx, cy - 4), 18 + pulse_chest * 4.0,
					Color(rar_col.r, rar_col.g, rar_col.b, 0.12 * pulse_chest))
				draw_circle(Vector2(cx, cy - 4), 11, Color(rar_col.r, rar_col.g, rar_col.b, 0.22))
				# Лента-индикатор рарности на крышке
				draw_rect(Rect2(cx - 7, cy - 8, 14, 1), rar_col)
				# Звезда для contraband
				if rarity == "contraband":
					draw_string(ThemeDB.fallback_font, Vector2(cx - 3, cy - 12),
						"★", HORIZONTAL_ALIGNMENT_CENTER, -1, 10,
						Color(1.0, 0.9, 0.2, 0.5 + pulse_chest * 0.5))
				# Sparkle на углу замка (раз в 1.5 сек)
				var sparkle_phase_c = fmod(t_chest * 0.7 + cx * 0.01, 1.0)
				if sparkle_phase_c < 0.10:
					var sp_intensity = sin(sparkle_phase_c / 0.10 * PI)
					var spx = cx - 1
					var spy = cy - 5
					draw_circle(Vector2(spx, spy), 1.2, Color(1, 1, 1, sp_intensity * 0.95))
					draw_circle(Vector2(spx, spy), 2.5, Color(rar_col.r, rar_col.g, rar_col.b, sp_intensity * 0.6))
			else:
				# Heal chest — green cross
				draw_circle(Vector2(cx, cy - 4), 12, Color(0.3, 0.9, 0.3, 0.1))
				draw_rect(Rect2(cx - 1, cy - 7, 2, 4), Color(0.3, 0.9, 0.3, 0.5))
				draw_rect(Rect2(cx - 2, cy - 6, 4, 2), Color(0.3, 0.9, 0.3, 0.5))
			# [E] prompt when player is near this chest
			if ci == chest_near_idx:
				draw_string(ThemeDB.fallback_font, Vector2(cx - 6, cy - 22),
					"[E]", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(1, 1, 0.7, 0.7))

func _draw_wall_sword():
	var sx = wall_sword_pos.x
	var sy = wall_sword_pos.y
	# Sword stuck in stone wall — blade pointing down-left
	# Handle
	draw_line(Vector2(sx + 2, sy - 8), Vector2(sx + 2, sy - 2), Color(0.55, 0.42, 0.2), 2.5)
	# Guard
	draw_line(Vector2(sx - 4, sy - 2), Vector2(sx + 8, sy - 2), Color(0.6, 0.5, 0.2), 2.5)
	# Blade going into wall
	draw_line(Vector2(sx + 2, sy - 1), Vector2(sx + 2, sy + 14), Color(0.85, 0.85, 0.92), 2.5)
	draw_line(Vector2(sx + 3, sy), Vector2(sx + 3, sy + 12), Color(1, 1, 1, 0.3), 1.0)
	# Glow effect
	draw_circle(Vector2(sx + 2, sy), 10, Color(0.8, 0.8, 1.0, 0.08))
	# "E" prompt
	draw_string(ThemeDB.fallback_font, Vector2(sx - 6, sy - 14),
		"[E]", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(1, 1, 0.7, 0.7))
