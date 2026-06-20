extends Node2D

var player_scene = preload("res://scenes/player.tscn")
var enemy_scene = preload("res://scenes/enemy.tscn")
var lockpick_scene = preload("res://scenes/lockpick_minigame.tscn")

var player: CharacterBody2D
var current_room: Node2D
var lockpick_ui: Control
var hud: CanvasLayer
var game_over_screen: CanvasLayer
var current_level: int = 1
var pending_door = null
var camera: Camera2D
var loop_count: int = 0  # How many times player has looped

# ── Mimic event ──
var mimic_node    = null
var mimic_script  = preload("res://scripts/mimic.gd")
var mimic_level: int = -1    # level where mimic appears (set randomly each run)
var mimic_done: bool = false  # already fired this run

# ── Horror overlay (vignette, eyes, echo, silhouette, glitch, no-exit) ──
var horror_effects: CanvasLayer = null
var no_exit_level: int = -1

# ── Giant spider event ──
var spider_script  = preload("res://scripts/giant_spider_event.gd")
var spider_level:  int  = -1

# ── Meat room (раз за игру) ──
var meat_room_level: int = -1
var meat_room_done: bool = false

# ── CS-overlay + Rush B + boss case opening ──
var cs_overlay: CanvasLayer = null
var background_layers: CanvasLayer = null   # параллакс-фон
var mobile_controls: CanvasLayer = null     # виртуальные кнопки (Android/iOS)
var rush_b_level: int = -1
var rush_b_done: bool = false
# Защищаем от повторного триггера ACE в одной и той же комнате
var ace_armed: bool = true
var spider_done:   bool = false
var spider_node          = null
var spider_canvas: CanvasLayer = null   # CanvasLayer wrapping the spider so vignette is in screen-space
var spider_hidden_enemies: Array = []   # enemies hidden during event

# ── Psycho-eyes cutscene ──
var psycho_active: bool = false
var psycho_textures: Array = []
var psycho_frame: int = 0
var psycho_timer: float = 0.0
var psycho_canvas: CanvasLayer = null
var psycho_draw_node: Node2D = null
const PSYCHO_FPS: float  = 24.0
const PSYCHO_TOTAL: int  = 120

# ── Death cutscene (watching_eyes2.mp4) ──
var death_cutscene_active: bool  = false
var death_textures: Array        = []
var death_frame: int             = 0
var death_timer: float           = 0.0
var death_canvas: CanvasLayer    = null
var death_draw_node: Node2D      = null
const DEATH_FPS:   float = 24.0
const DEATH_TOTAL: int   = 168

# ── Insanity sequence (triggered every 10 device-deaths) ──
var total_deaths:       int   = 0
var insanity_level:     int   = 0   # how many 10-death thresholds we've shown
var insanity_active:    bool  = false
var insanity_t:         float = 0.0
var insanity_canvas:    CanvasLayer = null
var insanity_draw_node: Node2D      = null
const INSANITY_DEATHS: int = 10
# Rep durations in seconds: first rep has quote, subsequent are faster
const INSANITY_DURS: Array = [5.5, 4.0, 3.5]   # total = 13.0s

# Story / time loop system
var story_shown: bool = false
var final_choice_active: bool = false
var future_self_fight: bool = false

# Pause menu
var is_paused: bool = false
var pause_menu_selection: int = 0  # 0=resume, 1=settings, 2=tutorial, 3=quit
var settings_open: bool = false
var settings_selection: int = 0
var settings_master_vol: float = 80.0
var settings_sfx_vol: float = 60.0
var settings_shake: bool = true
var tutorial_requested: bool = false

# Post-boss bonus
var boss_bonus_active: bool = false
var boss_bonus_options: Array = []
var boss_bonus_selected: int = 0

# Character level-up
var level_up_active: bool = false
var level_up_choices: Array = []
var level_up_selected: int = 0

# Background music
var music_ap: AudioStreamPlayer = null
var music_pb: AudioStreamGeneratorPlayback = null
var music_time: float = 0.0

# Story messages per level (time loop lore)
var story_messages: Dictionary = {
	1: ["Ты просыпаешься... снова.", "Что-то не так. Ты уже был здесь раньше."],
	2: ["Эти существа... они выглядят почти человечными.", "Почему они так отчаянно пытаются тебя убить?"],
	3: ["На стене нацарапано: 'МЫ ПОМНИМ БУДУЩЕЕ'", "Они знают что-то, чего не знаешь ты."],
	4: ["Странный голос: 'Ты не понимаешь. Мы пытаемся всё исправить.'", "'Ты — причина всего.'"],
	5: ["БОСС ЖДЁТ.", "Голем — страж времени. Он охраняет разлом."],
	6: ["За разломом... другой мир. Или тот же?", "Время здесь течёт иначе."],
	7: ["'Каждый раз, когда ты умираешь, петля начинается заново.'", "'Мы все были тобой. Когда-то.'"],
	8: ["Монстры стали сильнее. Они учатся.", "'Мы помним каждую твою попытку.'"],
	9: ["'Осталось недолго. Разлом нестабилен.'", "'Скоро тебе придётся выбрать.'"],
	10: ["ФИНАЛЬНЫЙ УРОВЕНЬ.", "'Время петли подходит к концу...'", "'Что ты выберешь?'"],
}

var loop_messages: Array = [
	"Петля замкнулась. Ты снова здесь.",
	"Сколько раз ты уже проходил этот путь?",
	"Мир помнит тебя, даже если ты не помнишь его.",
]

# Global darkness overlay
var darkness: CanvasModulate


# Низкое железо (телефон): на нём выключаем весь динамический свет —
# главный пожиратель FPS в 2D — и держим сцену яркой через ambient.
var _low_end: bool = OS.has_feature("mobile")

# Ставит цвет CanvasModulate. На телефоне свет выключен, поэтому держим
# сцену достаточно светлой (иначе без источников света было бы черно).
func _ambient(col: Color) -> Color:
	if _low_end:
		return Color(0.62, 0.56, 0.66)
	return col

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Process even when paused (for ESC menu)
	# FPS-лимит по платформе: телефон — 60 (экономия батареи/GPU), ПК — 120
	Engine.max_fps = 60 if OS.has_feature("mobile") else 120
	# На телефоне рендерим в БАЗОВОМ разрешении 1280x768 и растягиваем на экран.
	# С режимом canvas_items игра рисовалась в родном разрешении телефона
	# (1080p–1440p) — в 2–6 раз больше пикселей и нагрузки на заполнение.
	# Режим viewport убирает это — главный выигрыш FPS на телефоне.
	if OS.has_feature("mobile"):
		var win := get_window()
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		win.content_scale_size = Vector2i(1280, 768)
	# Camera
	camera = Camera2D.new()
	camera.zoom = Vector2(2.9, 2.9)  # HD: больше zoom т.к. viewport 1280x768
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()  # гарантируем, что это активная камера (для куллинга тайлов)

	# Тёмный лиловый сумрак — атмосферно но не светло.
	darkness = CanvasModulate.new()
	darkness.color = _ambient(Color(0.07, 0.06, 0.10))
	add_child(darkness)

	# HUD
	var hud_script = load("res://scripts/hud.gd")
	hud = CanvasLayer.new()
	hud.set_script(hud_script)
	add_child(hud)
	hud.craft_recipe_selected.connect(_on_craft_recipe_selected)
	hud.final_choice_made.connect(_on_final_choice)
	hud.weapon_selected.connect(_on_weapon_selected)
	if hud.has_signal("relic_chosen"):
		hud.relic_chosen.connect(_on_relic_chosen)
	if hud.has_signal("modifier_chosen"):
		hud.modifier_chosen.connect(_on_modifier_chosen)

	# Game Over
	var go_script = load("res://scripts/game_over.gd")
	game_over_screen = CanvasLayer.new()
	game_over_screen.set_script(go_script)
	add_child(game_over_screen)
	game_over_screen.restart_game.connect(_restart_game)

	# Глубокий параллакс-фон (рисуется под миром)
	var bg_script = load("res://scripts/background_layers.gd")
	background_layers = CanvasLayer.new()
	background_layers.set_script(bg_script)
	add_child(background_layers)
	background_layers.set_camera(camera)

	# CS-overlay (killstreaks, ACE, headshots, scope, inspect, case opening, crosshair)
	var cs_script = load("res://scripts/cs_overlay.gd")
	cs_overlay = CanvasLayer.new()
	cs_overlay.set_script(cs_script)
	add_child(cs_overlay)

	# Horror effects overlay
	var he_script = load("res://scripts/horror_effects.gd")
	horror_effects = CanvasLayer.new()
	horror_effects.set_script(he_script)
	add_child(horror_effects)

	# Мобильные кнопки управления (только на Android/iOS)
	var mc_script = load("res://scripts/mobile_controls.gd")
	mobile_controls = CanvasLayer.new()
	mobile_controls.set_script(mc_script)
	mobile_controls.layer = 50
	add_child(mobile_controls)

	# Lockpick UI
	lockpick_ui = lockpick_scene.instantiate()
	var lockpick_canvas = CanvasLayer.new()
	lockpick_canvas.layer = 10
	lockpick_canvas.add_child(lockpick_ui)
	add_child(lockpick_canvas)
	lockpick_ui.lockpick_success.connect(_on_lockpick_success)
	lockpick_ui.lockpick_failed.connect(_on_lockpick_failed)

	_show_start_menu()

func _show_start_menu():
	var menu_script = load("res://scripts/start_menu.gd")
	var menu = CanvasLayer.new()
	menu.set_script(menu_script)
	add_child(menu)
	# Получаем weapon_data из скрипта player.gd (через временный инстанс)
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	if player_scene:
		var tmp = player_scene.instantiate()
		menu.set_weapon_list(tmp.weapon_data)
		tmp.queue_free()
	menu.quick_start.connect(_start_game)
	menu.custom_start.connect(_start_custom_game)
	# В меню игровые кнопки скрыты, чтобы не перехватывать тач у Button-ов меню
	if mobile_controls and mobile_controls.has_method("set_active"):
		mobile_controls.set_active(false)

var _custom_config: Dictionary = {}   # сохранённая кастомка для применения после создания игрока

func _start_custom_game(cfg: Dictionary):
	_custom_config = cfg
	_start_game()

func _start_game():
	# Игра началась — показываем виртуальные кнопки на телефоне
	if mobile_controls and mobile_controls.has_method("set_active"):
		mobile_controls.set_active(true)
	# Daily seed (если включён в кастомной игре)
	if _custom_config.get("daily_seed", false):
		var d = Time.get_date_dict_from_system()
		var seed_val = d.year * 10000 + d.month * 100 + d.day
		seed(seed_val)
		if hud:
			hud.show_message("DAILY SEED %04d-%02d-%02d" % [d.year, d.month, d.day], 3.0)
	current_level = 1
	mimic_level  = randi_range(2, 6)
	mimic_done   = false
	spider_level = randi_range(3, 9)
	while spider_level == mimic_level:
		spider_level = randi_range(3, 9)
	spider_done  = false
	no_exit_level = randi_range(3, 8)
	meat_room_level = randi_range(3, 9)
	meat_room_done = false
	# Rush B — рандомный уровень между 2 и 9, отличный от других ивентов
	rush_b_level = randi_range(2, 9)
	rush_b_done = false

	# Применяем кастомные настройки: выключаем события которые игрок отрубил
	if _custom_config.has("events_enabled"):
		var ev = _custom_config.events_enabled
		if not ev.get("mimic", true):       mimic_level = -1
		if not ev.get("spider", true):      spider_level = -1
		if not ev.get("no_exit", true):     no_exit_level = -1
		if not ev.get("meat_room", true):   meat_room_level = -1
		if not ev.get("rush_b", true):      rush_b_level = -1

	_load_deaths()
	if total_deaths >= (insanity_level + 1) * INSANITY_DEATHS:
		insanity_level += 1
		_save_deaths()
		_start_insanity_sequence()
		return   # _finish_game_setup() is called at end of the sequence
	_finish_game_setup()

func _finish_game_setup():
	_create_player()
	_apply_meta_bonuses()
	_apply_custom_config()
	_load_room()
	# Если кастомная игра — карта уже выбрана, не показываем экран выбора
	if _custom_config.is_empty():
		_show_card_selection()
	else:
		# Дальше идёт обычный геймплей
		pass

func _apply_meta_bonuses():
	# Применяем мета-баффы к игроку
	if not player or not is_instance_valid(player):
		return
	var Meta = load("res://scripts/meta_progress.gd")
	Meta.load_meta()
	# +урон по тиру убийств
	var dmg_tier = Meta.get_damage_tier()
	if dmg_tier > 0:
		player.attack_damage = int(player.attack_damage * (1.0 + dmg_tier * 0.05))
		for key in player.weapon_data:
			player.weapon_data[key]["damage"] = int(player.weapon_data[key]["damage"] * (1.0 + dmg_tier * 0.05))
	# +HP по тиру смертей
	var hp_tier = Meta.get_hp_tier()
	if hp_tier > 0:
		player.max_health += hp_tier * 10
		player.health = player.max_health
	# Стартовые монеты
	var start_coins = Meta.get_starting_coins()
	if start_coins > 0:
		player.coins = start_coins
		if player.has_signal("coins_changed"):
			player.coins_changed.emit(player.coins)
	# Стартовые heal-чарджи
	var heal_tier = Meta.get_starting_heal_tier()
	if heal_tier > 0:
		player.max_heal_charges += heal_tier
		player.heal_charges += heal_tier

func _apply_custom_config():
	if _custom_config.is_empty():
		return
	if not player or not is_instance_valid(player):
		return
	# Карта
	var card_id: String = _custom_config.get("card_id", "")
	if card_id != "":
		player.active_card = card_id
		# Активируем эффекты карты (как в _on_card_selected)
		_apply_card_effects(card_id)
	# Свитки
	var scrolls: Array = _custom_config.get("scrolls", [])
	for sid in scrolls:
		if "scrolls" in player and player.scrolls.size() < player.max_scrolls:
			player.scrolls.append(sid)
	# Стартовое оружие
	var weapon_id: int = _custom_config.get("weapon_id", 1)
	if "equip_weapon" in player:
		player.equip_weapon(weapon_id)
		player.has_wall_sword = true   # отмечаем что меч уже у нас, не появится на стене

func _apply_card_effects(card_id: String):
	# Дублирует логику из обработчика выбора карты в HUD
	if not player or not is_instance_valid(player):
		return
	match card_id:
		"backstab":      player.card_backstab_bonus = 0.6
		"acid_water":    player.card_acid_water = true
		"thorn_armor":   player.card_thorn_reduction = 0.8
		"close_combat":  player.card_close_range_bonus = 0.4
		"berserker":     player.card_low_hp_bonus = true
		"hunter":        player.card_kill_bonus = 0.002
		"critical":
			player.card_crit_bonus_chance = 0.10
			player.card_crit_bonus_damage = 0.20
		"second_chance": player.card_second_chance = true
		"speed_boots":   pass   # обрабатывается через active_card
		"dodge":         pass   # обрабатывается через active_card
		"invisibility":  pass
		"death_jar":
			player.death_jar_charges = 0
		"throw_weapon":  pass

func _load_deaths() -> void:
	var fa = FileAccess.open("user://deaths.dat", FileAccess.READ)
	if fa:
		total_deaths   = fa.get_32()
		insanity_level = fa.get_32()
		fa.close()

func _save_deaths() -> void:
	var fa = FileAccess.open("user://deaths.dat", FileAccess.WRITE)
	if fa:
		fa.store_32(total_deaths)
		fa.store_32(insanity_level)
		fa.close()

func _create_player():
	player = player_scene.instantiate()
	player.position = Vector2(60, 400)
	player.add_to_group("player")
	add_child(player)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.current_weapon = 0  # Start with fists, pick up sword from wall

	# Camera follows player
	var remote = RemoteTransform2D.new()
	remote.remote_path = camera.get_path()
	player.add_child(remote)

	# === Светильник игрока (оптимизировано) ===
	# На телефоне свет ПОЛНОСТЬЮ выключен (ambient поднят в _ambient) — это
	# убирает весь овердров от света, главный пожиратель FPS в 2D.
	# На ПК — рабочий свет + мягкое halo (огромный bloom и аура убраны).
	if not _low_end:
		var player_light = PointLight2D.new()
		player_light.color = Color(1.0, 0.90, 0.92)
		player_light.energy = 1.15
		player_light.texture = _create_light_texture()
		player_light.texture_scale = 2.0
		player_light.position = Vector2(0, -10)
		player_light.shadow_enabled = false
		player_light.blend_mode = Light2D.BLEND_MODE_ADD
		player.add_child(player_light)

		var bloom_inner = PointLight2D.new()
		bloom_inner.color = Color(0.95, 0.72, 0.85)
		bloom_inner.energy = 0.70
		bloom_inner.texture = _create_light_texture()
		bloom_inner.texture_scale = 3.0
		bloom_inner.position = Vector2(0, -10)
		bloom_inner.shadow_enabled = false
		bloom_inner.blend_mode = Light2D.BLEND_MODE_ADD
		player.add_child(bloom_inner)

	hud.update_health(player.health, player.max_health)

	# Sound: connect player signals if available
	if player.has_signal("attacked"):
		player.attacked.connect(func(): play_sfx("sword"))
	if player.has_signal("jumped"):
		player.jumped.connect(func(): play_sfx("jump"))
	if player.has_signal("landed"):
		player.landed.connect(func(): play_sfx("land"))

	# Connect screen shake signal
	if player.has_signal("screen_shake"):
		player.screen_shake.connect(_on_screen_shake)

	# === CS-FEATURES: соединяем сигналы игрока с overlay ===
	if cs_overlay:
		cs_overlay.add_to_group("cs_overlay")
		cs_overlay.crosshair_style = player.crosshair_style
		# ULTRAKILL-style: каждое убийство даёт +50 стиля, ещё больше при стрике
		if player.has_signal("killstreak_changed"):
			player.killstreak_changed.connect(func(s): cs_overlay.show_killstreak(s))
		# Базовое +50 за каждое убийство
		if player.has_signal("attacked"):
			pass  # отдельный сигнал ниже
		if player.has_signal("headshot_landed"):
			player.headshot_landed.connect(func(p): cs_overlay.show_headshot(p))
		if player.has_signal("inspect_requested"):
			player.inspect_requested.connect(func(wd): cs_overlay.show_inspect(wd))
		# BHOP / DASH
		if player.has_signal("bhop_perfect"):
			player.bhop_perfect.connect(func(stacks, world_pos): cs_overlay.on_bhop_perfect(stacks, world_pos))
		if player.has_signal("dash_used"):
			player.dash_used.connect(func(_charges): play_sfx("dash"))
	# === Звуковые подключения ===
	if player.has_signal("bhop_perfect"):
		player.bhop_perfect.connect(func(_s, _p): play_sfx("bhop"))
	if player.has_signal("headshot_landed"):
		player.headshot_landed.connect(func(_p): play_sfx("headshot"))
	if player.has_signal("footstep"):
		player.footstep.connect(func(): play_sfx("step"))
	if player.has_signal("weapon_picked"):
		player.weapon_picked.connect(func(_r): play_sfx("pickup"))

	# Coins, leveling, combo
	if player.has_signal("coins_changed"):
		player.coins_changed.connect(func(n): hud.update_coins(n))
	if player.has_signal("leveled_up"):
		player.leveled_up.connect(_on_player_leveled_up)

	# Hook up horror effects with new player ref
	if is_instance_valid(horror_effects):
		horror_effects.setup(player, total_deaths)

# Camera shake state
var cam_shake_intensity: float = 0.0
var cam_shake_timer: float = 0.0
var cam_shake_offset: Vector2 = Vector2.ZERO
var cam_base_offset: Vector2 = Vector2.ZERO

func _on_screen_shake(intensity: float, duration: float):
	if not settings_shake:
		return
	cam_shake_intensity = maxf(cam_shake_intensity, intensity)
	cam_shake_timer = maxf(cam_shake_timer, duration)

func _update_camera_shake(delta: float):
	if cam_shake_timer > 0:
		cam_shake_timer -= delta
		var t = cam_shake_timer / maxf(0.001, cam_shake_timer + delta)
		var s = cam_shake_intensity * t
		cam_shake_offset = Vector2(
			randf_range(-s, s),
			randf_range(-s, s)
		)
	else:
		cam_shake_offset = Vector2.ZERO
		cam_shake_intensity = 0.0
	camera.offset = cam_base_offset + cam_shake_offset

func _update_camera_lookahead(delta: float):
	if not is_instance_valid(player):
		return
	# Lookahead: offset camera slightly in movement direction
	var target_x = player.velocity.x * 0.06
	cam_base_offset.x = lerpf(cam_base_offset.x, target_x, 1.0 - exp(-5.0 * delta))
	# Vertical lookahead: peek down when falling
	var target_y = clampf(player.velocity.y * 0.03, -20.0, 30.0)
	cam_base_offset.y = lerpf(cam_base_offset.y, target_y, 1.0 - exp(-4.0 * delta))

func _create_light_texture() -> GradientTexture2D:
	# Мягкий "факельный" градиент: яркое ядро → быстрый спад → длинный шлейф в темноту
	var tex = GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.85),     # центр — не пересвечен
		Color(1, 1, 1, 0.55),     # середина
		Color(1, 1, 1, 0.18),     # быстро гаснет
		Color(1, 1, 1, 0.0),      # край — полная тьма
	])
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	tex.gradient = grad
	return tex

func _load_room():
	if current_room:
		current_room.queue_free()
		await current_room.tree_exited

	var room_script = load("res://scripts/room.gd")
	current_room = Node2D.new()
	current_room.set_script(room_script)
	add_child(current_room)
	move_child(current_room, 0)

	# Помечаем как мясную, ПЕРЕД setup() — палитра и наполнение зависят от флага
	if current_level == meat_room_level and not meat_room_done:
		current_room.is_meat_room = true
		meat_room_done = true
	# Помечаем как Rush B (если попали)
	if current_level == rush_b_level and not rush_b_done:
		current_room.is_rush_b = true
		rush_b_done = true

	# Сброс ACE-трекинга для новой комнаты
	ace_armed = true
	if player:
		player.room_damage_taken = 0
		# Сбрасываем модификатор предыдущего уровня (бонусы должны быть свежие)
		if "level_modifier" in player:
			player.level_modifier = ""
			player.damage_mult = 1.0
			player.taken_damage_mult = 1.0
		# Предлагаем модификатор с уровня 2+ (25% шанс — не каждый уровень)
		if current_level >= 2 and randf() < 0.25:
			call_deferred("_offer_level_modifier")

	current_room.setup(current_level, enemy_scene, player)
	current_room.room_cleared.connect(_on_room_cleared)
	current_room.door_used.connect(_on_door_used)

	# Параллакс-фон: подстраиваем палитру под текущий биом
	if background_layers and background_layers.has_method("set_biome"):
		var loc = clampi((current_level - 1) / 4, 0, 2)
		background_layers.set_biome(loc)

	# Показываем цель уровня если нестандартная
	if "objective" in current_room and current_room.objective != "default":
		var labels = {
			"kill_all": "ЦЕЛЬ: УБИТЬ ВСЕХ ВРАГОВ",
			"survive_60": "ЦЕЛЬ: ВЫЖИТЬ 60 СЕКУНД",
			"no_damage": "ЦЕЛЬ: ЗАЧИСТИТЬ БЕЗ УРОНА",
			"speedrun_30": "ЦЕЛЬ: ЗАЧИСТИТЬ ЗА 30 СЕК",
		}
		hud.show_message(labels.get(current_room.objective, "ЦЕЛЬ"), 4.0)

	# Pass death counter to room for world-space horror effects
	current_room.horror_total_deaths = total_deaths

	# Trigger no-exit effect on specific level
	if current_level == no_exit_level and is_instance_valid(horror_effects):
		horror_effects.trigger_no_exit()

	# Room name flash + minimap (start with only start room visible)
	if current_room.has_method("get_minimap_data"):
		hud.set_minimap(current_room.get_minimap_data(), current_room.minimap_current_idx)
		hud.update_progression(player.char_level if player else 1, 0, 60)
	hud.show_room_name(_get_room_event_label())

	# Start/continue ambient music
	if not music_ap or not is_instance_valid(music_ap):
		_start_music()
	else:
		music_time = 0.0  # reset phase on new room
	# Connect enemy death sounds + ULTRAKILL style
	for en in current_room.enemies:
		if is_instance_valid(en) and not en.died.is_connected(_on_enemy_sfx):
			en.died.connect(_on_enemy_sfx)
		if is_instance_valid(en) and cs_overlay and not en.died.is_connected(_on_enemy_died_style):
			en.died.connect(_on_enemy_died_style)
	current_room.challenge_complete.connect(_on_challenge_complete)
	current_room.trial_completed.connect(_on_trial_completed)
	if current_room.has_signal("craft_message"):
		current_room.craft_message.connect(_on_craft_message)
	if current_room.has_signal("open_craft_menu_request"):
		current_room.open_craft_menu_request.connect(_on_open_craft_menu)
	if current_room.has_signal("open_shop_menu_request"):
		current_room.open_shop_menu_request.connect(_on_open_shop_menu)
	# HUD сигналы магазина (подключаем единожды)
	if hud and not hud.shop_buy_selected.is_connected(_on_shop_buy):
		hud.shop_buy_selected.connect(_on_shop_buy)
	if hud and not hud.shop_closed.is_connected(_on_shop_closed):
		hud.shop_closed.connect(_on_shop_closed)

	# Player starts in the start cave
	var start_cave = null
	for cave in current_room.caves:
		if cave.type == "start":
			start_cave = cave
			break
	if start_cave:
		player.position = Vector2(start_cave.x, start_cave.floor_y - 10)
		print("START: player at ", player.position, " floor_y=", start_cave.floor_y)
	else:
		player.position = Vector2(100, current_room.floor_y - 10)
		print("NO START CAVE! floor_y=", current_room.floor_y, " caves=", current_room.caves.size())
	player.velocity = Vector2.ZERO
	# Snap camera to player immediately (no smoothing delay)
	camera.global_position = player.position

	# Reset per-level items
	player.has_lockpick = false
	player.ore_mined = 0
	# Keep pickaxe, resources, amulet, flask across levels
	if current_room.challenge_type != "lockpick" and current_room.challenge_type != "crystal":
		player.using_pickaxe = false

	# Лиминал-сумрак тёмный: с уровнем чуть глуше
	var dark_factor = maxf(0.04, 0.08 - current_level * 0.004)
	darkness.color = _ambient(Color(dark_factor * 0.85, dark_factor * 0.75, dark_factor * 1.20))

	hud.update_level(current_level)
	hud.update_enemies(current_room.enemies.size())
	if current_level == 1 and loop_count == 0:
		hud.show_controls_after_card = true  # Show controls AFTER card selection
	elif current_level == 5:
		hud.show_message("BOSS: GOLEM", 3.0)
	else:
		hud.show_message("Level " + str(current_level), 2.0)

	# Show story message after brief delay
	_show_story(current_level)

	# Spawn mimic on the designated level (not boss rooms, not level 1)
	if not mimic_done and current_level == mimic_level and not current_room.is_boss_room:
		_spawn_mimic()

	# Giant spider hallucination event
	if not spider_done and current_level == spider_level and not current_room.is_boss_room:
		# Delay a bit so player has time to look around first
		await get_tree().create_timer(4.0).timeout
		if is_instance_valid(player) and not player.is_dead:
			_start_spider_event()

func _start_spider_event() -> void:
	if spider_done: return
	spider_done = true

	# ── Hide all enemies ──
	spider_hidden_enemies.clear()
	if current_room:
		for en in current_room.enemies:
			if is_instance_valid(en):
				en.visible = false
				spider_hidden_enemies.append(en)

	# ── Silence music ──
	if music_ap and is_instance_valid(music_ap):
		var tween = create_tween()
		tween.tween_property(music_ap, "volume_db", -60.0, 1.5)

	# ── Spider node lives in world-space (child of main scene) ──
	var ev = Node2D.new()
	ev.set_script(spider_script)
	add_child(ev)
	spider_node = ev

	# ── Separate CanvasLayer just for the vignette ──
	spider_canvas = CanvasLayer.new()
	spider_canvas.layer = 50
	add_child(spider_canvas)
	var vig_node = Node2D.new()
	spider_canvas.add_child(vig_node)
	vig_node.draw.connect(func():
		if not is_instance_valid(spider_node): return
		var a = spider_node.vignette_alpha
		if a < 0.01: return
		var vs = vig_node.get_viewport_rect().size
		# Left / right bars
		vig_node.draw_rect(Rect2(0, 0, vs.x * 0.28, vs.y), Color(0, 0, 0, a * 0.80))
		vig_node.draw_rect(Rect2(vs.x * 0.72, 0, vs.x * 0.28, vs.y), Color(0, 0, 0, a * 0.80))
		# Top / bottom bars
		vig_node.draw_rect(Rect2(0, 0, vs.x, vs.y * 0.22), Color(0, 0, 0, a * 0.70))
		vig_node.draw_rect(Rect2(0, vs.y * 0.78, vs.x, vs.y * 0.22), Color(0, 0, 0, a * 0.70))
		# Corner blobs
		for cx3 in [0.0, vs.x]:
			for cy3 in [0.0, vs.y]:
				vig_node.draw_circle(Vector2(cx3, cy3), vs.x * 0.35, Color(0, 0, 0, a * 0.60))
	)
	ev.vignette_node = vig_node   # spider event triggers queue_redraw on it

	# Decide spawn side: opposite to player facing
	var side = -1 if player.facing_right else 1
	ev.setup(player, side)
	ev.event_ended.connect(_on_spider_event_ended)

func _on_spider_event_ended() -> void:
	spider_node = null

	# Screen flash (white)
	if hud and hud.has_method("show_message"):
		hud.show_message("", 0.0)

	# Brief flash overlay
	var flash_canvas = CanvasLayer.new()
	flash_canvas.layer = 150
	add_child(flash_canvas)
	var flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0.85)
	flash_rect.size  = get_viewport().get_visible_rect().size
	flash_canvas.add_child(flash_rect)

	# Fade flash out over 0.5s
	var tw = create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.5)
	await tw.finished
	flash_canvas.queue_free()

	# Remove spider canvas
	if is_instance_valid(spider_canvas):
		spider_canvas.queue_free()
		spider_canvas = null

	# ── Restore enemies ──
	for en in spider_hidden_enemies:
		if is_instance_valid(en):
			en.visible = true
	spider_hidden_enemies.clear()

	# ── Restore music ──
	if music_ap and is_instance_valid(music_ap):
		var tween2 = create_tween()
		tween2.tween_property(music_ap, "volume_db", 0.0, 1.5)

func _spawn_mimic():
	if mimic_done:
		return
	mimic_done = true

	var m = CharacterBody2D.new()
	m.set_script(mimic_script)

	# Spawn 160px to the side of the player (close, visible)
	var side = 1 if player.facing_right else -1
	var spawn_x = player.global_position.x + side * 160.0
	spawn_x = clampf(spawn_x, 80.0, current_room.room_width - 80.0)
	var spawn_y = player.global_position.y
	m.global_position = Vector2(spawn_x, spawn_y)

	# Add CollisionShape so it can land on floors
	var shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 6.0
	capsule.height = 16.0
	shape.shape = capsule
	shape.position = Vector2(0, -10)
	m.add_child(shape)

	add_child(m)
	m.setup(player, current_room)
	m.attacked_player.connect(_on_mimic_attacked_player)
	mimic_node = m

func _on_mimic_attacked_player():
	mimic_node = null
	if not is_instance_valid(player):
		return
	# Deal 3 HP damage
	player.take_damage(3, Vector2.ZERO)
	# Knock out player — 1.0s lying + 0.8s getting up
	player.is_knocked_out = true
	player.knockdown_timer = 1.8
	# Small screen shake
	_on_screen_shake(5.0, 0.4)
	# Start the psycho cutscene after a brief dramatic pause
	await get_tree().create_timer(0.3).timeout
	_start_psycho_cutscene()

func _start_psycho_cutscene():
	if psycho_active:
		return
	psycho_active = true
	psycho_frame  = 0
	psycho_timer  = 0.0

	# Load frames lazily on first use
	if psycho_textures.is_empty():
		for i in PSYCHO_TOTAL:
			var path = "res://sprites/psycho_eyes/frame_%03d.png" % i
			var fa = FileAccess.open(path, FileAccess.READ)
			if fa:
				var img = Image.new()
				if img.load_png_from_buffer(fa.get_buffer(fa.get_length())) == OK:
					psycho_textures.append(ImageTexture.create_from_image(img))
			else:
				psycho_textures.append(null)

	# Build fullscreen overlay canvas
	psycho_canvas = CanvasLayer.new()
	psycho_canvas.layer = 200
	add_child(psycho_canvas)

	psycho_draw_node = Node2D.new()
	psycho_canvas.add_child(psycho_draw_node)
	psycho_draw_node.draw.connect(_psycho_draw_frame)
	psycho_draw_node.queue_redraw()

func _psycho_draw_frame():
	if not psycho_active or psycho_frame >= psycho_textures.size():
		return
	var tex = psycho_textures[psycho_frame]
	var vs  = get_viewport().get_visible_rect().size
	# Black fill
	psycho_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y), Color.BLACK)
	# Video frame centered, scaled to fill height
	if tex:
		var scale = vs.y / 128.0
		var tw = 128.0 * scale
		var th = 128.0 * scale
		psycho_draw_node.draw_texture_rect(
			tex,
			Rect2((vs.x - tw) * 0.5, (vs.y - th) * 0.5, tw, th),
			false)

func _end_psycho_cutscene():
	psycho_active = false
	if is_instance_valid(psycho_canvas):
		psycho_canvas.queue_free()
		psycho_canvas    = null
		psycho_draw_node = null
	# Give player a brief get-up window if knockdown already ended
	if is_instance_valid(player) and not player.is_knocked_out:
		player.is_knocked_out  = true
		player.knockdown_timer = 0.8

# ── Death cutscene ─────────────────────────────────────────────────────────

func _start_death_cutscene():
	if death_cutscene_active:
		return
	death_cutscene_active = true
	death_frame  = 0
	death_timer  = 0.0

	# Lazy-load 168 frames on first death
	if death_textures.is_empty():
		for i in DEATH_TOTAL:
			var path = "res://sprites/watching_eyes/frame_%03d.png" % i
			var fa = FileAccess.open(path, FileAccess.READ)
			if fa:
				var img = Image.new()
				if img.load_png_from_buffer(fa.get_buffer(fa.get_length())) == OK:
					death_textures.append(ImageTexture.create_from_image(img))
				else:
					death_textures.append(null)
			else:
				death_textures.append(null)

	# Pause game world but keep process running
	get_tree().paused = true

	# Full-screen overlay above everything
	death_canvas = CanvasLayer.new()
	death_canvas.layer = 300
	death_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(death_canvas)

	death_draw_node = Node2D.new()
	death_draw_node.process_mode = Node.PROCESS_MODE_ALWAYS
	death_canvas.add_child(death_draw_node)
	death_draw_node.draw.connect(_death_draw_frame)
	death_draw_node.queue_redraw()

func _death_draw_frame():
	if not death_cutscene_active:
		return
	var vs  = get_viewport().get_visible_rect().size
	# Full black background
	death_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y), Color.BLACK)

	# Если кадры из sprites/watching_eyes/ есть — используем их
	var tex = null
	if death_frame < death_textures.size():
		tex = death_textures[death_frame]
	if tex:
		var scale = vs.y / 128.0
		var tw = 128.0 * scale
		var th = 128.0 * scale
		death_draw_node.draw_texture_rect(
			tex,
			Rect2((vs.x - tw) * 0.5, (vs.y - th) * 0.5, tw, th),
			false)
		return

	# ── Процедурный ролик "наблюдающие глаза" ──
	var t: float = float(death_frame) / float(DEATH_TOTAL)  # 0..1
	var cx = vs.x * 0.5
	var cy = vs.y * 0.5
	# Зыбкое багровое свечение по центру (пульсирует)
	var pulse = 0.5 + 0.5 * sin(t * TAU * 4.0)
	for r_ring in range(8, 0, -1):
		var rr = float(r_ring) * 60.0 * (0.6 + pulse * 0.4)
		var ac = 0.08 - r_ring * 0.008
		death_draw_node.draw_circle(Vector2(cx, cy), rr,
			Color(0.4, 0.05, 0.05, max(0.0, ac)))

	# Позиции "глаз" — 12 штук вокруг экрана, появляются по очереди
	var eye_positions = [
		Vector2(cx,        cy - 140),
		Vector2(cx - 220,  cy - 90),
		Vector2(cx + 220,  cy - 90),
		Vector2(cx - 320,  cy + 40),
		Vector2(cx + 320,  cy + 40),
		Vector2(cx - 160,  cy + 160),
		Vector2(cx + 160,  cy + 160),
		Vector2(cx,        cy + 220),
		Vector2(cx - 100,  cy - 200),
		Vector2(cx + 100,  cy - 200),
		Vector2(cx - 280,  cy + 200),
		Vector2(cx + 280,  cy + 200),
	]

	var seed_val = 13.0
	for i in eye_positions.size():
		# Каждый глаз появляется в свой момент времени
		var appear_at = float(i) / float(eye_positions.size()) * 0.7
		var local_t = clampf((t - appear_at) / 0.15, 0.0, 1.0)
		if local_t <= 0.0:
			continue
		var pos: Vector2 = eye_positions[i]
		# Глаз "следит" за центром экрана — зрачок чуть смещается в сторону игрока
		var look_dir = (Vector2(cx, cy) - pos).normalized()
		# Мигание: каждые 1.5 сек короткое моргание
		var blink_phase = fmod(t * 4.0 + float(i) * 0.7, 3.0)
		var blink = 1.0
		if blink_phase < 0.15:
			blink = blink_phase / 0.15
		elif blink_phase < 0.30:
			blink = 1.0 - (blink_phase - 0.15) / 0.15
		blink = clampf(blink, 0.05, 1.0)
		_draw_eye(pos, local_t, look_dir, blink, i, t)

	# В последние 20% — резкое затемнение/пульсация
	if t > 0.8:
		var fade_t = (t - 0.8) / 0.2
		# Финальный вспых багрового
		var flash_a = sin(fade_t * PI) * 0.5
		death_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y),
			Color(0.5, 0.0, 0.0, flash_a))
		# Затемнение к концу
		death_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y),
			Color(0, 0, 0, fade_t * 0.9))

	# Текст-шёпот меняется по ходу ролика
	var phrases = ["...", "ОНИ СМОТРЯТ", "ВСЕГДА", "ТЫ НЕ ОДИН", "СНОВА..."]
	var phrase_idx = int(t * float(phrases.size()))
	phrase_idx = clampi(phrase_idx, 0, phrases.size() - 1)
	var phrase = phrases[phrase_idx]
	var font := ThemeDB.fallback_font
	var fsize := 22
	var tw_ph = font.get_string_size(phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	# Лёгкое дрожание текста
	var jitter = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	var text_alpha = 0.4 + 0.6 * abs(sin(t * TAU * 2.0))
	death_draw_node.draw_string(font,
		Vector2(cx - tw_ph * 0.5, vs.y - 60) + jitter,
		phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
		Color(0.85, 0.1, 0.1, text_alpha))

func _draw_eye(pos: Vector2, appear_t: float, look_dir: Vector2, blink: float, idx: int, global_t: float):
	# Размер глаза варьируется
	var size_mult = 1.0 + (float(idx % 3) - 1.0) * 0.25
	var w = 38.0 * size_mult * appear_t
	var h = 22.0 * size_mult * appear_t * blink
	# Белок глаза (грязно-жёлтый, дрожит)
	var sclera_col = Color(0.85, 0.78, 0.55, appear_t)
	# Овал-белок: рисуем как заполненный круг с масштабированием
	var pts := PackedVector2Array()
	var segments = 24
	for s in segments:
		var a = float(s) / float(segments) * TAU
		pts.append(pos + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.5))
	death_draw_node.draw_colored_polygon(pts, sclera_col)
	# Кровавые прожилки
	for v in 4:
		var va = (float(v) / 4.0) * TAU + global_t * 0.5
		var v_start = pos + Vector2(cos(va) * w * 0.3, sin(va) * h * 0.3)
		var v_end   = pos + Vector2(cos(va) * w * 0.48, sin(va) * h * 0.48)
		death_draw_node.draw_line(v_start, v_end, Color(0.7, 0.1, 0.1, appear_t * 0.6), 1.0)
	# Радужка
	var iris_pos = pos + look_dir * (w * 0.15) * blink
	var iris_r = h * 0.55
	death_draw_node.draw_circle(iris_pos, iris_r, Color(0.5, 0.1, 0.1, appear_t))
	# Зрачок (пульсирует)
	var pupil_r = iris_r * (0.45 + 0.15 * sin(global_t * TAU * 5.0 + float(idx)))
	death_draw_node.draw_circle(iris_pos, pupil_r, Color(0.0, 0.0, 0.0, appear_t))
	# Блик
	death_draw_node.draw_circle(iris_pos + Vector2(-iris_r * 0.3, -iris_r * 0.3),
		iris_r * 0.18, Color(1.0, 1.0, 1.0, appear_t * 0.8))

func _end_death_cutscene():
	death_cutscene_active = false
	get_tree().paused = false
	if is_instance_valid(death_canvas):
		death_canvas.queue_free()
		death_canvas    = null
		death_draw_node = null
	_restart_game()

# ── Insanity sequence ──────────────────────────────────────────────────────

func _start_insanity_sequence() -> void:
	insanity_active = true
	insanity_t      = 0.0
	get_tree().paused = true

	insanity_canvas = CanvasLayer.new()
	insanity_canvas.layer = 400
	insanity_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(insanity_canvas)

	insanity_draw_node = Node2D.new()
	insanity_draw_node.process_mode = Node.PROCESS_MODE_ALWAYS
	insanity_canvas.add_child(insanity_draw_node)
	insanity_draw_node.draw.connect(_insanity_draw_frame)
	insanity_draw_node.queue_redraw()

func _insanity_draw_frame() -> void:
	if not insanity_active: return
	var nd  = insanity_draw_node
	var vs  = get_viewport().get_visible_rect().size
	var cx  = vs.x * 0.5
	var cy  = vs.y * 0.5

	# Determine which repetition and local time within it
	var t   = insanity_t
	var rep = 0
	var rt  = t
	for i in INSANITY_DURS.size():
		var dur: float = INSANITY_DURS[i]
		if rt < dur:
			rep = i
			break
		rt -= dur
		if i == INSANITY_DURS.size() - 1:
			rep = i
			rt  = dur

	var dur_rep: float = INSANITY_DURS[rep]

	# Phase markers (seconds into rep)
	var raise_start: float
	var stab_start:  float
	var fall_start:  float
	var fade_start:  float
	match rep:
		0: raise_start = 2.8; stab_start = 3.6; fall_start = 4.2; fade_start = 4.9
		1: raise_start = 0.4; stab_start = 1.4; fall_start = 2.2; fade_start = 3.3
		_: raise_start = 0.3; stab_start = 1.0; fall_start = 1.8; fade_start = 2.8

	# Fade-in alpha at rep start
	var fade_in  = clampf(rt / 0.35, 0.0, 1.0)
	# Fade-out alpha near rep end
	var fade_out = 1.0 - clampf((rt - fade_start) / (dur_rep - fade_start + 0.001), 0.0, 1.0)
	var alpha    = fade_in * fade_out

	# Derive sub-phase fractions
	var hero_raise = clampf((rt - raise_start) / 0.55, 0.0, 1.0)
	var hero_stab  = clampf((rt - stab_start)  / 0.45, 0.0, 1.0)
	var hero_fall  = clampf((rt - fall_start)  / 0.6,  0.0, 1.0)

	# Red blood tint on stab
	var red = clampf((rt - stab_start) / 0.25, 0.0, 1.0) * clampf((fade_start - rt) / 0.6, 0.0, 1.0)

	# Black background with slight red tint
	nd.draw_rect(Rect2(0, 0, vs.x, vs.y), Color(red * 0.22, 0.0, 0.0, 1.0))

	if alpha < 0.02: return

	# Quote text — only on rep 0, appears during pre-raise pause
	if rep == 0 and rt > 0.4 and rt < raise_start + 0.2:
		var ta = clampf((rt - 0.4) / 0.55, 0.0, 1.0) * alpha
		var f  = ThemeDB.fallback_font
		nd.draw_string(f, Vector2(0, cy - 80),
			"Безумие — это точное повторение",
			HORIZONTAL_ALIGNMENT_CENTER, vs.x, 15, Color(0.85, 0.82, 0.80, ta))
		nd.draw_string(f, Vector2(0, cy - 60),
			"одного и того же действия.",
			HORIZONTAL_ALIGNMENT_CENTER, vs.x, 15, Color(0.85, 0.82, 0.80, ta))
		nd.draw_string(f, Vector2(0, cy - 36),
			"Раз за разом, в надежде на изменение.",
			HORIZONTAL_ALIGNMENT_CENTER, vs.x, 13, Color(0.65, 0.62, 0.60, ta * 0.9))

	# Hero figure — at centre, scaled up, rotating when falling
	var hero_angle = hero_fall * deg_to_rad(88.0)
	var hx = cx
	var hy = cy + 40.0
	nd.draw_set_transform(Vector2(hx, hy), hero_angle, Vector2(3.8, 3.8))
	_draw_insanity_hero(nd, hero_raise, hero_stab, alpha)
	nd.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Blood pool spreading from fallen body
	if hero_fall > 0.25:
		var ba   = clampf((hero_fall - 0.25) / 0.45, 0.0, 1.0) * alpha
		var pool_cx = hx + sin(hero_angle) * 35.0 * 3.8 + 20.0
		var pool_cy = hy + 18.0
		var prx  = hero_fall * 52.0
		var pry  = hero_fall * 18.0
		var steps = int(pry * 1.6)
		for i in steps:
			var frac = float(i) / float(max(steps - 1, 1)) * 2.0 - 1.0
			var rw   = prx * sqrt(maxf(0.0, 1.0 - frac * frac))
			nd.draw_line(
				Vector2(pool_cx - rw, pool_cy + frac * pry),
				Vector2(pool_cx + rw, pool_cy + frac * pry),
				Color(0.45, 0.01, 0.01, ba * 0.75), 1.5)

func _draw_insanity_hero(nd: Node2D, raise_t: float, stab_t: float, alpha: float) -> void:
	# Coordinates match player.gd local draw space (origin = feet/hip)
	# Legs
	nd.draw_rect(Rect2(-4, -4, 3, 5), Color(0.25, 0.20, 0.15, alpha))
	nd.draw_rect(Rect2( 1, -4, 3, 5), Color(0.25, 0.20, 0.15, alpha))
	nd.draw_rect(Rect2(-5,  0, 5, 2), Color(0.40, 0.22, 0.10, alpha))
	nd.draw_rect(Rect2( 0,  0, 5, 2), Color(0.40, 0.22, 0.10, alpha))
	# Body
	nd.draw_rect(Rect2(-5, -16, 10, 13), Color(0.35, 0.35, 0.40, alpha))
	nd.draw_rect(Rect2(-4, -15,  8,  7), Color(0.42, 0.42, 0.48, alpha))
	nd.draw_rect(Rect2(-5,  -5, 10,  2), Color(0.45, 0.30, 0.12, alpha))
	# Head & helmet
	nd.draw_rect(Rect2(-4, -22, 8, 7), Color(0.90, 0.75, 0.55, alpha))
	nd.draw_rect(Rect2(-5, -24, 10, 5), Color(0.50, 0.50, 0.55, alpha))
	nd.draw_rect(Rect2(-5, -24, 10, 1), Color(0.60, 0.60, 0.65, alpha))
	nd.draw_rect(Rect2(-2, -21,  5, 2), Color(0.08, 0.08, 0.10, alpha))
	# Eyes — wide open, staring white with tiny dark pupils
	nd.draw_circle(Vector2( 1.5, -19.5), 2.2, Color(0.90, 0.88, 0.85, alpha))
	nd.draw_circle(Vector2( 1.5, -19.5), 0.8, Color(0.05, 0.05, 0.05, alpha))

	# Sword arm (right side, s=1)
	# raise_t=0: arm hanging at side   raise_t=1: arm raised overhead
	# stab_t =0: overhead              stab_t =1: plunged into chest
	var a_hang   = deg_to_rad(-80.0)       # arm hanging down-right
	var a_raised = deg_to_rad(-160.0)      # arm raised overhead-back
	var a_stab   = deg_to_rad(-85.0)       # driving down into torso
	var arm_ang  = lerpf(a_hang, a_raised, raise_t)
	if stab_t > 0.0:
		arm_ang = lerpf(a_raised, a_stab, stab_t)

	var arm_root = Vector2(5.0, -13.0)
	var arm_dir  = Vector2(cos(arm_ang), sin(arm_ang))
	var arm_tip  = arm_root + arm_dir * 9.0
	nd.draw_line(arm_root, arm_tip, Color(0.42, 0.42, 0.48, alpha), 3.0)

	# Sword extending from arm tip
	var blade_end = arm_tip + arm_dir * 17.0
	var perp = Vector2(-arm_dir.y, arm_dir.x)
	nd.draw_line(arm_root + perp * 2.0, arm_root - perp * 2.0,
		Color(0.65, 0.55, 0.25, alpha), 1.5)   # guard
	nd.draw_line(arm_tip, blade_end,
		Color(0.85, 0.85, 0.92, alpha * 0.9), 2.5)  # blade
	nd.draw_line(arm_tip + perp * 0.6, blade_end + perp * 0.6,
		Color(1.0, 1.0, 1.0, alpha * 0.28), 1.0)    # shine

	# Blood spurt from wound when stab > 0.55
	if stab_t > 0.55:
		var ba = clampf((stab_t - 0.55) / 0.3, 0.0, 1.0) * alpha
		for i in 6:
			var ang = arm_ang + (float(i) - 2.5) * 0.22
			var len = (4.0 + float(i) * 2.0) * ba
			nd.draw_line(arm_tip,
				arm_tip + Vector2(cos(ang) * len, sin(ang) * len),
				Color(0.58, 0.02, 0.02, ba * (0.4 + float(i) * 0.1)), 1.5)

func _end_insanity_sequence() -> void:
	insanity_active = false
	get_tree().paused = false
	if is_instance_valid(insanity_canvas):
		insanity_canvas.queue_free()
		insanity_canvas    = null
		insanity_draw_node = null
	_finish_game_setup()

# ───────────────────────────────────────────────────────────────────────────

func _process(delta):
	_update_camera_shake(delta)
	_update_camera_lookahead(delta)
	_update_cs_features(delta)
	if current_room and not current_room.is_cleared:
		hud.update_enemies(current_room.enemies.size())

	# ── Giant spider vignette alpha ──
	if is_instance_valid(spider_node):
		var target_v = 0.0
		match spider_node.phase:
			1: target_v = lerpf(0.0, 0.75, 1.0 - (spider_node.phase_timer / 99.0))  # WALK
			2: target_v = 0.85   # TENSION
			3: target_v = 0.90   # RUSH
			4: target_v = 0.70   # SLASH
			5: target_v = lerpf(0.85, 0.0, spider_node.dissolve_t)  # DISSOLVE
			_: target_v = 0.0
		spider_node.vignette_alpha = lerpf(spider_node.vignette_alpha, target_v,
			1.0 - exp(-6.0 * delta))
		spider_node.queue_redraw()

	# ── Psycho-eyes cutscene frame advance ──
	if psycho_active and is_instance_valid(psycho_draw_node):
		psycho_timer += delta
		var new_frame = int(psycho_timer * PSYCHO_FPS)
		if new_frame != psycho_frame:
			psycho_frame = new_frame
			if psycho_frame >= PSYCHO_TOTAL:
				_end_psycho_cutscene()
			else:
				psycho_draw_node.queue_redraw()

	# ── Insanity sequence advance ──
	if insanity_active and is_instance_valid(insanity_draw_node):
		insanity_t += delta
		var total_insanity: float = 0.0
		for d in INSANITY_DURS:
			total_insanity += float(d)
		if insanity_t >= total_insanity:
			_end_insanity_sequence()
		else:
			insanity_draw_node.queue_redraw()

	# ── Death cutscene frame advance ──
	if death_cutscene_active and is_instance_valid(death_draw_node):
		death_timer += delta
		var new_frame = int(death_timer * DEATH_FPS)
		if new_frame != death_frame:
			death_frame = new_frame
			if death_frame >= DEATH_TOTAL:
				_end_death_cutscene()
			else:
				death_draw_node.queue_redraw()

	# Background music — keep buffer filled
	_fill_music_buffer()
	# Sync progression display each frame (lightweight)
	if player and is_instance_valid(player):
		hud.update_progression(player.char_level, player.xp, player.xp_needed)

	# Safety: if player falls below map, teleport back to start
	if player and is_instance_valid(player) and not player.is_dead:
		if player.position.y > current_room.room_height + 100:
			var start_cave = null
			for cave in current_room.caves:
				if cave.type == "start":
					start_cave = cave
					break
			if start_cave:
				player.position = Vector2(start_cave.x, start_cave.floor_y - 10)
			else:
				player.position = Vector2(60, current_room.floor_y - 10)
			player.velocity = Vector2.ZERO

func _update_cs_features(delta: float):
	if not cs_overlay or not player or not is_instance_valid(player):
		return

	# === Синхронизация bhop/dash в overlay ===
	cs_overlay.bhop_stacks = player.bhop_stacks
	cs_overlay.update_dash(player.dash_charges, player.DASH_MAX_CHARGES)
	# Combo-награды: передаём текущий стиль-ранг игроку
	if cs_overlay.has_method("get_style_rank"):
		player.style_rank = cs_overlay.get_style_rank()
	# Передаём ВСЕ новые точки трейла из игрока в overlay
	if player.bhop_trail.size() > 0:
		for tp in player.bhop_trail:
			cs_overlay.add_trail_point(tp.pos, tp.life, tp.alpha_mult)
		player.bhop_trail.clear()

	# === AWP scope: зум камеры + overlay ===
	if player.is_scoping and not cs_overlay.is_scoping():
		cs_overlay.start_scope()
	elif not player.is_scoping and cs_overlay.is_scoping():
		cs_overlay.end_scope()
	# Плавный zoom камеры при скоупе ИЛИ при высоком bhop стэке
	if camera:
		var target_zoom_base = 2.9
		if player.bhop_stacks > 0:
			target_zoom_base -= player.bhop_stacks * 0.04
		# Psychedelic heartbeat: лёгкая пульсация zoom-а
		var psy_mult = 1.0
		if horror_effects and horror_effects.has_method("psy_camera_zoom_mult"):
			psy_mult = horror_effects.psy_camera_zoom_mult()
		var target_zoom_val = 4.2 if player.is_scoping else target_zoom_base
		var target_zoom = Vector2(target_zoom_val * psy_mult, target_zoom_val * psy_mult)
		camera.zoom = camera.zoom.lerp(target_zoom, 1.0 - exp(-8.0 * delta))
		# Mirror moment — переворот по X
		if horror_effects and horror_effects.has_method("psy_camera_flip_x"):
			if horror_effects.psy_camera_flip_x():
				camera.scale.x = -1.0
			else:
				camera.scale.x = 1.0
		# Glitch jump — мгновенный сдвиг offset
		if horror_effects and horror_effects.has_method("psy_camera_offset"):
			cam_base_offset += horror_effects.psy_camera_offset() * 0.5

	# === Crosshair: показываем для дальнобойного оружия ===
	var wd = player.weapon_data.get(player.current_weapon, {})
	var sp = wd.get("special", "")
	var is_ranged = sp in ["warp_arrow", "triple_arrow", "dart_throw", "necro_souls", "sniper"]
	cs_overlay.set_crosshair_visible(is_ranged)
	cs_overlay.crosshair_style = player.crosshair_style
	if is_ranged:
		var aim = player._get_aim_direction() if player.has_method("_get_aim_direction") else Vector2.RIGHT
		var dist = 90.0
		cs_overlay.crosshair_world_pos = player.global_position + Vector2(0, -10) + aim * dist
		cs_overlay.crosshair_aim_dir = aim

func _teleport_to_meat_room():
	# Принудительно создаём мясную комнату прямо здесь и сейчас
	meat_room_done = false  # позволяем создать заново
	if meat_room_level <= 0:
		meat_room_level = randi_range(3, 9)
	current_level = meat_room_level
	_load_room()
	if hud:
		hud.show_message("МЯСНАЯ КОМНАТА", 2.0)

func _teleport_to_rush_b():
	# DEBUG: телепорт в Rush B комнату
	rush_b_done = false
	if rush_b_level <= 0:
		rush_b_level = randi_range(2, 9)
	current_level = rush_b_level
	_load_room()
	if hud:
		hud.show_message("RUSH B!", 2.0)

func _unhandled_input(event):
	# DEBUG: "Ъ" / "]" — телепорт в мясную комнату
	if event is InputEventKey and event.pressed and event.keycode == KEY_BRACKETRIGHT:
		_teleport_to_meat_room()
		get_viewport().set_input_as_handled()
		return
	# DEBUG: "Х" / "[" — телепорт в Rush B комнату
	if event is InputEventKey and event.pressed and event.keycode == KEY_BRACKETLEFT:
		_teleport_to_rush_b()
		get_viewport().set_input_as_handled()
		return
	# DEBUG: "\\" / "Э" — выдать AWP Петли (CS-снайперка)
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSLASH:
		if player and is_instance_valid(player):
			player.equip_weapon(23)
		get_viewport().set_input_as_handled()
		return
	# Циклически переключить стиль crosshair: ";" / "Ж"
	if event is InputEventKey and event.pressed and event.keycode == KEY_SEMICOLON:
		if player and is_instance_valid(player):
			player.crosshair_style = (player.crosshair_style + 1) % 5
			if cs_overlay:
				cs_overlay.crosshair_style = player.crosshair_style
			var names = ["DEFAULT", "DOT", "CROSS", "T-SHAPE", "X"]
			if hud:
				hud.show_message("CROSSHAIR: " + names[player.crosshair_style], 1.2)
		get_viewport().set_input_as_handled()
		return

	# Settings screen intercepts all input
	if settings_open:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				settings_open = false
				hud.hide_settings()
			elif event.keycode == KEY_UP or event.keycode == KEY_W:
				settings_selection = max(0, settings_selection - 1)
				hud.update_settings(settings_selection, settings_master_vol, settings_sfx_vol, settings_shake)
			elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
				settings_selection = min(2, settings_selection + 1)
				hud.update_settings(settings_selection, settings_master_vol, settings_sfx_vol, settings_shake)
			elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
				match settings_selection:
					0:
						settings_master_vol = max(0.0, settings_master_vol - 10.0)
						AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(settings_master_vol / 100.0))
					1:
						settings_sfx_vol = max(0.0, settings_sfx_vol - 10.0)
					2:
						settings_shake = not settings_shake
				hud.update_settings(settings_selection, settings_master_vol, settings_sfx_vol, settings_shake)
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
				match settings_selection:
					0:
						settings_master_vol = min(100.0, settings_master_vol + 10.0)
						AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(settings_master_vol / 100.0))
					1:
						settings_sfx_vol = min(100.0, settings_sfx_vol + 10.0)
					2:
						settings_shake = not settings_shake
				hud.update_settings(settings_selection, settings_master_vol, settings_sfx_vol, settings_shake)
			get_viewport().set_input_as_handled()
		return

	# Level-up screen intercepts input
	if level_up_active:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_UP or event.keycode == KEY_W:
				level_up_selected = max(0, level_up_selected - 1)
				hud.update_level_up_sel(level_up_selected)
			elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
				level_up_selected = min(level_up_choices.size() - 1, level_up_selected + 1)
				hud.update_level_up_sel(level_up_selected)
			elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				player.apply_levelup(level_up_choices[level_up_selected]["id"])
				level_up_active = false
				get_tree().paused = false
				hud.hide_level_up()
				# Update progression display
				hud.update_progression(player.char_level, player.xp, player.xp_needed)
			get_viewport().set_input_as_handled()
		return

	# Boss bonus selection intercepts all input
	if boss_bonus_active:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_UP or event.keycode == KEY_W:
				boss_bonus_selected = max(0, boss_bonus_selected - 1)
				hud.update_boss_bonus_selection(boss_bonus_selected)
			elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
				boss_bonus_selected = min(boss_bonus_options.size() - 1, boss_bonus_selected + 1)
				hud.update_boss_bonus_selection(boss_bonus_selected)
			elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				_apply_boss_bonus(boss_bonus_options[boss_bonus_selected])
				boss_bonus_active = false
				get_tree().paused = false
				hud.hide_boss_bonus()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		# === PAUSE MENU ===
		if event.keycode == KEY_ESCAPE:
			if is_paused:
				_unpause()
			else:
				_pause()
			get_viewport().set_input_as_handled()
			return

		if is_paused:
			if event.keycode == KEY_UP or event.keycode == KEY_W:
				pause_menu_selection = max(0, pause_menu_selection - 1)
				hud.pause_selection = pause_menu_selection
				hud.draw_node.queue_redraw()
			elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
				pause_menu_selection = min(3, pause_menu_selection + 1)
				hud.pause_selection = pause_menu_selection
				hud.draw_node.queue_redraw()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				match pause_menu_selection:
					0: _unpause()  # Resume
					1:  # Settings
						settings_open = true
						hud.show_settings(settings_selection, settings_master_vol, settings_sfx_vol, settings_shake)
					2:  # Tutorial
						_unpause()
						tutorial_requested = true
						current_level = 0
						_load_tutorial_level()
					3:  # Quit
						get_tree().quit()
			get_viewport().set_input_as_handled()
			return

		# === DEBUG KEYS ===
		# P = trigger mimic event immediately
		if event.keycode == KEY_P:
			if not psycho_active and is_instance_valid(player) and not player.is_dead:
				mimic_done = false
				_spawn_mimic()
			get_viewport().set_input_as_handled()
		# O = trigger giant spider event immediately
		elif event.keycode == KEY_O:
			if not is_instance_valid(spider_node) and is_instance_valid(player) and not player.is_dead:
				spider_done = false
				_start_spider_event()
			get_viewport().set_input_as_handled()
		# T = skip to next room instantly
		elif event.keycode == KEY_T:
			current_level += 1
			_load_room()
			get_viewport().set_input_as_handled()
		# Y = force door challenge + unlock
		elif event.keycode == KEY_Y:
			if current_room and current_room.doors.size() > 0:
				var door = current_room.doors[0]
				# Force room cleared
				current_room.is_cleared = true
				# Trigger challenge event based on type
				match current_room.challenge_type:
					"lockpick":
						player.has_lockpick = true
						pending_door = door
						_start_crafting_then("lockpick")
					"guardians":
						if not current_room.challenge_started:
							pending_door = door
							current_room.start_guardian_challenge(enemy_scene)
							hud.show_message("GUARDIANS SPAWNED!", 2.0)
						elif not current_room.challenge_complete_flag:
							# Kill remaining guardians
							for g in current_room.door_guardians.duplicate():
								if is_instance_valid(g):
									g.queue_free()
									current_room.door_guardians.erase(g)
							current_room.challenge_complete_flag = true
							current_room.challenge_complete.emit()
						else:
							pending_door = door
							_complete_door()
					"crystal":
						if not current_room.challenge_started:
							player.ore_mined = player.ore_needed
							pending_door = door
							_start_crafting_then("crystal")
						elif not current_room.challenge_complete_flag:
							# Kill crystal attackers
							for a in current_room.crystal_attackers.duplicate():
								if is_instance_valid(a):
									a.queue_free()
									current_room.crystal_attackers.erase(a)
							current_room.challenge_complete_flag = true
							current_room.challenge_complete.emit()
						else:
							pending_door = door
							_complete_door()
				get_viewport().set_input_as_handled()
		# 6 = spawn portal skeleton at player position
		elif event.keycode == KEY_6:
			if current_room and player and is_instance_valid(player):
				current_room._spawn_portal()
				get_viewport().set_input_as_handled()
		# 7 = trigger future self boss fight directly
		elif event.keycode == KEY_7:
			_trigger_good_ending()
			get_viewport().set_input_as_handled()
		# 8 = spawn weapon chest near player
		elif event.keycode == KEY_8:
			if current_room and player and is_instance_valid(player):
				var px = player.global_position.x + 30
				var py = player.global_position.y
				current_room._place_chest(px, py)
				current_room.queue_redraw()
				get_viewport().set_input_as_handled()
		# 9 = use active item (scroll/card)
		elif event.keycode == KEY_9:
			if player and is_instance_valid(player):
				player._use_active_item()
				get_viewport().set_input_as_handled()
		# Tab = cycle active item slot
		elif event.keycode == KEY_TAB:
			if player and is_instance_valid(player):
				player._cycle_active_item()
				get_viewport().set_input_as_handled()
		# 0 = open weapon selection menu (debug)
		elif event.keycode == KEY_0:
			if player and is_instance_valid(player):
				hud.weapon_menu_visible = !hud.weapon_menu_visible
				hud.weapon_menu_selected = player.current_weapon
				if hud.weapon_menu_visible:
					player.is_dead = true
				else:
					player.is_dead = false
				get_viewport().set_input_as_handled()

func _on_open_shop_menu():
	if not current_room or not hud:
		return
	hud.open_shop_menu(current_room.get_shop_items_for_menu())

func _on_shop_buy(index: int):
	if not current_room:
		return
	current_room.buy_shop_item(index)
	# Обновляем список в HUD (после изменения "bought")
	hud.update_shop_items(current_room.get_shop_items_for_menu())

func _on_shop_closed():
	if current_room and current_room.has_method("close_shop"):
		current_room.close_shop()

func _on_open_craft_menu(station_type: String):
	if hud.is_menu_open():
		return
	hud.open_craft_menu(station_type)
	player.is_dead = true  # Freeze player while menu open

func _on_craft_recipe_selected(station_type: String, recipe_index: int):
	if not current_room or not player:
		return
	var result = current_room.try_craft_recipe(station_type, recipe_index)
	if result != "":
		hud.show_message(result, 2.0)

func _on_craft_message(text: String):
	hud.show_message(text, 2.0)

func _on_room_cleared():
	hud.update_enemies(0)
	# === ACE check (CS): зачистил без получения урона ===
	if ace_armed and player and is_instance_valid(player) and player.room_damage_taken <= 0:
		if cs_overlay:
			cs_overlay.show_ace()
		# Бонус — заряд лечения
		if "heal_charges" in player:
			player.heal_charges = min(player.heal_charges + 1, player.max_heal_charges + 1)
		ace_armed = false
		hud.show_message("ACE — +1 заряд лечения", 2.5)
	else:
		hud.show_message("Зачищено! Найди дверь", 3.0)
	# === RELIC DROP: 35% шанс предложить реликвию при зачистке (после уровня 2) ===
	if current_level >= 2 and randf() < 0.35:
		_offer_relic_choice()
	# Boss level bonus every 5 levels (case opening идёт изнутри _show_boss_bonus)
	if current_level % 5 == 0 and current_level > 0:
		call_deferred("_show_boss_bonus_case")

func _on_door_used(door):
	# Tutorial level — just go to level 1
	if current_level == 0:
		pending_door = door
		door.unlock()
		pending_door = null
		current_level = 1
		tutorial_requested = false
		await get_tree().create_timer(0.5).timeout
		_load_room()
		return

	# Boss room — door opens directly after defeating golem
	if current_room.is_boss_room:
		pending_door = door
		_complete_door()
		return

	pending_door = door

	match current_room.challenge_type:
		"lockpick":
			if not player.has_lockpick:
				hud.show_message("Find the pickaxe! Mine 6 ore to craft a lockpick!", 3.0)
				pending_door = null
				return
			# Show crafting animation then start lockpick
			_start_crafting_then("lockpick")
		"guardians":
			if current_room.challenge_complete_flag:
				_complete_door()
			elif not current_room.challenge_started:
				current_room.start_guardian_challenge(enemy_scene)
				hud.show_message("KILL THE GUARDIANS!", 3.0)
			else:
				hud.show_message("Kill the guardians first!", 2.0)
		"crystal":
			if current_room.challenge_complete_flag:
				_complete_door()
			elif not current_room.challenge_started or (current_room.crystal_node and current_room.crystal_node.is_destroyed):
				# Кристалл крафтится без условий по руде
				_start_crafting_then("crystal")
			else:
				hud.show_message("Defend the crystal!", 2.0)

func _on_trial_completed():
	# Reward: +50% max health
	var bonus = player.max_health / 2
	player.max_health += bonus
	player.heal(bonus)
	hud.update_health(player.health, player.max_health)
	hud.show_message("TRIAL COMPLETE! Max HP +" + str(bonus) + "!", 3.0)

func _on_challenge_complete():
	hud.show_message("Challenge Complete!", 2.0)
	await get_tree().create_timer(0.5).timeout
	if pending_door:
		_complete_door()
	elif current_room.doors.size() > 0:
		pending_door = current_room.doors[0]
		_complete_door()

func _complete_door():
	if pending_door:
		pending_door.unlock()
		pending_door = null
		hud.show_message("Door Unlocked!", 1.5)
		# Full heal + HP boost every 2 levels
		if current_level % 2 == 0:
			player.max_health += 15
			hud.show_message("Max HP +" + str(15) + "!", 2.0)
		player.health = player.max_health  # Full heal on level transition
		player.heal_charges = player.max_heal_charges
		hud.update_health(player.health, player.max_health)
		await get_tree().create_timer(1.0).timeout

		# Check if this is the final level — show choice instead of advancing
		if current_level >= 15:
			_show_final_choice()
			return

		current_level += 1
		# Weapon mutation every 3 levels
		if current_level % 3 == 0 and player and is_instance_valid(player):
			if player.has_method("add_weapon_mutation"):
				player.add_weapon_mutation()
		_load_room()

func _start_crafting_then(item: String):
	hud.start_crafting(item)
	# Freeze player during crafting
	player.is_dead = true  # Reuse dead flag to prevent input
	await hud.crafting_done
	player.is_dead = false
	if item == "lockpick":
		var diff = current_room.get_lockpick_difficulty()
		lockpick_ui.start_lockpick(diff)
	elif item == "crystal":
		current_room.start_crystal_placement()
		hud.show_message("CRYSTAL PLACED! DEFEND IT!", 3.0)

func _on_enemy_sfx(_enemy):
	play_sfx("death")
	# Мета-счётчик убийств
	var Meta = load("res://scripts/meta_progress.gd")
	Meta.on_kill()

func _on_enemy_died_style(_enemy):
	# ULTRAKILL: +50 за каждое убийство (хедшот / стрик дают доп. бонусы отдельно)
	if cs_overlay:
		cs_overlay.add_kill_style()

func _on_lockpick_success():
	_complete_door()

func _on_lockpick_failed():
	pending_door = null
	hud.show_message("Lockpick broken! Try again...", 2.0)

var _last_player_health: int = 999

func _on_player_health_changed(new_health):
	hud.update_health(new_health)
	if new_health < _last_player_health:
		play_sfx("hit")
	_last_player_health = new_health

# === SOUND ===

# Пул аудио-плееров — создаётся один раз, переиспользуется (без node-churn)
var _sfx_pool: Array = []
var _sfx_pool_idx: int = 0
const SFX_POOL_SIZE: int = 16
# Кэш сгенерированных аудио-волн (тип → PackedVector2Array)
# Заполняется лениво: первый play_sfx генерирует, дальше — переиспользование
var _sfx_wave_cache: Dictionary = {}

func _ensure_sfx_pool():
	if _sfx_pool.size() > 0:
		return
	for i in SFX_POOL_SIZE:
		var stream = AudioStreamGenerator.new()
		stream.mix_rate = 22050.0
		stream.buffer_length = 0.12
		var ap = AudioStreamPlayer.new()
		ap.stream = stream
		add_child(ap)
		_sfx_pool.append(ap)

func play_sfx(type: String):
	_ensure_sfx_pool()
	if _sfx_pool.is_empty():
		return
	# Берём следующий плеер из пула по кругу
	var ap: AudioStreamPlayer = _sfx_pool[_sfx_pool_idx]
	_sfx_pool_idx = (_sfx_pool_idx + 1) % _sfx_pool.size()
	ap.volume_db = linear_to_db(settings_sfx_vol / 100.0) - 8.0
	ap.play()
	var pb = ap.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb:
		return
	# Если есть кэш — отдаём готовые фреймы, без генерации
	if _sfx_wave_cache.has(type):
		var cached: PackedVector2Array = _sfx_wave_cache[type]
		var n = mini(cached.size(), pb.get_frames_available())
		for i in n:
			pb.push_frame(cached[i])
		return
	# Первый раз — генерируем и кэшируем
	var sr = 22050.0
	var frames = pb.get_frames_available()
	var cache_buf := PackedVector2Array()
	cache_buf.resize(frames)
	# Все ветки match ниже пишут в pb.push_frame. Параллельно собираем в cache_buf
	# через временную переменную last_frame (упрощение: после match скопируем фреймы).
	# Чтобы не переписывать каждую ветку — делаем хелпер через массив-аккумулятор.
	var _saved_frames := PackedVector2Array()
	_saved_frames.resize(frames)
	# Подмена: запоминаем все push_frame через перехват — НО проще: после match
	# повторно сгенерируем в cache_buf используя тот же код. Это не идеально, но
	# выполняется только ОДИН раз за тип. После — все вызовы идут через cache.
	# Для простоты — сохраняем фреймы в одну функцию-генератор:
	cache_buf = _generate_sfx_buffer(type, sr, frames)
	_sfx_wave_cache[type] = cache_buf
	# Сразу проигрываем закэшированный буфер
	var n2 = mini(cache_buf.size(), pb.get_frames_available())
	for i in n2:
		pb.push_frame(cache_buf[i])
	return  # пропускаем старый match-блок ниже
	match type:
		"hit":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 35)
				var n = randf_range(-1, 1) * env * 0.35
				pb.push_frame(Vector2(n, n))
		"sword":
			for i in frames:
				var t = float(i) / sr
				var freq = max(120.0, 700.0 - t * 2500.0)
				var env = exp(-t * 12)
				var s = sin(t * freq * TAU) * env * 0.22
				pb.push_frame(Vector2(s, s))
		"jump":
			for i in frames:
				var t = float(i) / sr
				var freq = 200.0 + t * 700.0
				var env = exp(-t * 18)
				var s = sin(t * freq * TAU) * env * 0.18
				pb.push_frame(Vector2(s, s))
		"land":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 55)
				# Averaged noise = much softer "thud" than raw white noise
				var n = (randf_range(-1,1) + randf_range(-1,1) + randf_range(-1,1)) / 3.0 * env * 0.06
				var bass = sin(t * 55 * TAU) * env * 0.05
				pb.push_frame(Vector2(n + bass, n + bass))
		"death":
			for i in frames:
				var t = float(i) / sr
				var freq = max(55.0, 350.0 - t * 1000.0)
				var env = exp(-t * 7)
				var s = sin(t * freq * TAU) * env * 0.22
				pb.push_frame(Vector2(s, s))
		"chest":
			for i in frames:
				var t = float(i) / sr
				var freq = 523.0 if t < 0.055 else 784.0
				var env = exp(-t * 11)
				var s = sin(t * freq * TAU) * env * 0.20
				pb.push_frame(Vector2(s, s))
		"bonus":
			for i in frames:
				var t = float(i) / sr
				var freqs = [523.0, 659.0, 784.0, 1047.0]
				var fi = mini(int(t / 0.025), 3)
				var env = exp(-t * 9)
				var s = sin(t * freqs[fi] * TAU) * env * 0.22
				pb.push_frame(Vector2(s, s))
		"step":
			# Тихий мягкий шаг — короткий приглушённый щелчок
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 80)
				var n = (randf_range(-1,1) + randf_range(-1,1)) / 2.0 * env * 0.04
				pb.push_frame(Vector2(n, n))
		"dash":
			# Свистящий взмах — быстрый whoosh
			for i in frames:
				var t = float(i) / sr
				var freq = 900.0 - t * 3000.0
				var env = exp(-t * 16)
				var n = randf_range(-1,1) * env * 0.10
				var s = sin(t * max(80.0, freq) * TAU) * env * 0.12
				pb.push_frame(Vector2(s + n, s + n))
		"pickup":
			# Яркий восходящий "звон" — приятный пикап
			for i in frames:
				var t = float(i) / sr
				var freq = 660.0 + t * 900.0
				var env = exp(-t * 9)
				var s = sin(t * freq * TAU) * env * 0.16
				pb.push_frame(Vector2(s, s))
		"bhop":
			# Тонкий "тик" — успешный bhop
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 60)
				var s = sin(t * 1200.0 * TAU) * env * 0.10
				pb.push_frame(Vector2(s, s))
		"headshot":
			# Резкий "крак" + звон — хедшот
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 28)
				var crack = randf_range(-1,1) * env * 0.18
				var ring = sin(t * 1600.0 * TAU) * exp(-t * 14) * 0.10
				pb.push_frame(Vector2(crack + ring, crack + ring))
		"heal":
			# Тёплый мягкий восходящий аккорд
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 6)
				var s = (sin(t * 440.0 * TAU) + sin(t * 554.0 * TAU) * 0.6) * env * 0.10
				pb.push_frame(Vector2(s, s))
		"explode":
			# Глубокий взрыв — бас + шум
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 9)
				var bass = sin(t * max(30.0, 120.0 - t * 300.0) * TAU) * env * 0.22
				var n = randf_range(-1,1) * env * 0.18
				pb.push_frame(Vector2(bass + n, bass + n))
		"shoot":
			# Тугой "тванг" лука
			for i in frames:
				var t = float(i) / sr
				var freq = 500.0 - t * 1400.0
				var env = exp(-t * 22)
				var s = sin(t * max(90.0, freq) * TAU) * env * 0.14
				pb.push_frame(Vector2(s, s))
	# Плеер из пула — не освобождаем, переиспользуется

func _generate_sfx_buffer(type: String, sr: float, frames: int) -> PackedVector2Array:
	# Чистая генерация: возвращает заполненный массив. Вызывается раз за тип.
	var buf := PackedVector2Array()
	buf.resize(frames)
	match type:
		"hit":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 35)
				var n = randf_range(-1, 1) * env * 0.35
				buf[i] = Vector2(n, n)
		"sword":
			for i in frames:
				var t = float(i) / sr
				var freq = max(120.0, 700.0 - t * 2500.0)
				var env = exp(-t * 12)
				var s = sin(t * freq * TAU) * env * 0.22
				buf[i] = Vector2(s, s)
		"jump":
			for i in frames:
				var t = float(i) / sr
				var freq = 200.0 + t * 700.0
				var env = exp(-t * 18)
				var s = sin(t * freq * TAU) * env * 0.18
				buf[i] = Vector2(s, s)
		"land":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 55)
				var n = (randf_range(-1,1) + randf_range(-1,1) + randf_range(-1,1)) / 3.0 * env * 0.06
				var bass = sin(t * 55 * TAU) * env * 0.05
				buf[i] = Vector2(n + bass, n + bass)
		"death":
			for i in frames:
				var t = float(i) / sr
				var freq = max(55.0, 350.0 - t * 1000.0)
				var env = exp(-t * 7)
				var s = sin(t * freq * TAU) * env * 0.22
				buf[i] = Vector2(s, s)
		"chest":
			for i in frames:
				var t = float(i) / sr
				var freq = 523.0 if t < 0.055 else 784.0
				var env = exp(-t * 11)
				var s = sin(t * freq * TAU) * env * 0.20
				buf[i] = Vector2(s, s)
		"bonus":
			for i in frames:
				var t = float(i) / sr
				var freqs = [523.0, 659.0, 784.0, 1047.0]
				var fi = mini(int(t / 0.025), 3)
				var env = exp(-t * 9)
				var s = sin(t * freqs[fi] * TAU) * env * 0.22
				buf[i] = Vector2(s, s)
		"step":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 80)
				var n = (randf_range(-1,1) + randf_range(-1,1)) / 2.0 * env * 0.04
				buf[i] = Vector2(n, n)
		"dash":
			for i in frames:
				var t = float(i) / sr
				var freq = 900.0 - t * 3000.0
				var env = exp(-t * 16)
				var n = randf_range(-1,1) * env * 0.10
				var s = sin(t * max(80.0, freq) * TAU) * env * 0.12
				buf[i] = Vector2(s + n, s + n)
		"pickup":
			for i in frames:
				var t = float(i) / sr
				var freq = 660.0 + t * 900.0
				var env = exp(-t * 9)
				var s = sin(t * freq * TAU) * env * 0.16
				buf[i] = Vector2(s, s)
		"bhop":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 60)
				var s = sin(t * 1200.0 * TAU) * env * 0.10
				buf[i] = Vector2(s, s)
		"headshot":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 28)
				var crack = randf_range(-1,1) * env * 0.18
				var ring = sin(t * 1600.0 * TAU) * exp(-t * 14) * 0.10
				buf[i] = Vector2(crack + ring, crack + ring)
		"heal":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 6)
				var s = (sin(t * 440.0 * TAU) + sin(t * 554.0 * TAU) * 0.6) * env * 0.10
				buf[i] = Vector2(s, s)
		"explode":
			for i in frames:
				var t = float(i) / sr
				var env = exp(-t * 9)
				var bass = sin(t * max(30.0, 120.0 - t * 300.0) * TAU) * env * 0.22
				var n = randf_range(-1,1) * env * 0.18
				buf[i] = Vector2(bass + n, bass + n)
		"shoot":
			for i in frames:
				var t = float(i) / sr
				var freq = 500.0 - t * 1400.0
				var env = exp(-t * 22)
				var s = sin(t * max(90.0, freq) * TAU) * env * 0.14
				buf[i] = Vector2(s, s)
	return buf

# === POST-BOSS BONUS ===

func _offer_level_modifier():
	# Выбор модификатора при загрузке нового уровня (с уровня 2+)
	if not hud or not player:
		return
	var Mods = load("res://scripts/level_modifiers.gd")
	var choices = Mods.roll_choices(3)
	if hud.has_method("show_modifier_choice"):
		hud.show_modifier_choice(choices)

func _on_modifier_chosen(mod_id: String):
	if player and "apply_level_modifier" in player:
		player.apply_level_modifier(mod_id)
		# elite_horde: помечаем — все спавнящиеся враги станут элитой
		if mod_id == "elite_horde" and current_room:
			current_room.set_meta("elite_horde", true)
		# dense_dark: уменьшаем свет
		if mod_id == "dense_dark":
			for c in player.get_children():
				if c is PointLight2D:
					c.energy *= 0.5
					c.texture_scale *= 0.7

func _offer_relic_choice():
	# Открываем HUD-меню выбора из 3 случайных реликвий
	if not hud or not player:
		return
	var Relics = load("res://scripts/relics.gd")
	var owned = player.relics if "relics" in player else []
	var choices = Relics.roll_choices(3, owned)
	if choices.is_empty():
		return
	if hud.has_method("show_relic_choice"):
		hud.show_relic_choice(choices)

func _on_relic_chosen(rid: String):
	if player and "add_relic" in player:
		player.add_relic(rid)

func _show_boss_bonus_case():
	# CS-стиль case opening: лента из 30 рандомных оружий → побеждает одно по weighted rarity
	if not cs_overlay or not player:
		_show_boss_bonus()
		return
	var weighted_pool = []
	var pool_ids = []
	# Все боевые оружия (1..23)
	for wid in player.weapon_data.keys():
		if wid == 0 or wid == player.current_weapon:
			continue
		var wd: Dictionary = player.weapon_data[wid]
		pool_ids.append(wid)
		# Веса по рарности
		var weight = 1
		match wd.get("rarity", "common"):
			"common":     weight = 100
			"uncommon":   weight = 40
			"rare":       weight = 18
			"epic":       weight = 8
			"legendary":  weight = 4
			"contraband": weight = 1
		for _i in weight:
			weighted_pool.append(wid)
	# Выбираем победителя
	var winner_id = weighted_pool[randi() % weighted_pool.size()] if weighted_pool.size() > 0 else 1
	# Формируем массив items для ленты (30 случайных + winner в нужном слоте)
	var items = []
	for _i in 30:
		var rid = pool_ids[randi() % pool_ids.size()]
		var wd: Dictionary = player.weapon_data[rid]
		items.append({
			"weapon_id": rid,
			"name": wd.get("name", ""),
			"rarity": wd.get("rarity", "common"),
			"color": wd.get("color", Color.WHITE),
			"glow": wd.get("glow", Color(1, 1, 1, 0)),
		})
	# В позицию 24 (за 6 от конца) кладём ВЫИГРЫШ
	var winner_idx = 24
	var winner_wd: Dictionary = player.weapon_data[winner_id]
	items[winner_idx] = {
		"weapon_id": winner_id,
		"name": winner_wd.get("name", ""),
		"rarity": winner_wd.get("rarity", "common"),
		"color": winner_wd.get("color", Color.WHITE),
		"glow": winner_wd.get("glow", Color(1, 1, 1, 0)),
	}
	cs_overlay.show_case_opening(items, winner_idx, Callable(self, "_on_case_closed"))

func _on_case_closed(weapon_id: int):
	# weapon_id == -1 → игрок пропустил, оставил своё оружие
	if weapon_id >= 0 and player and is_instance_valid(player) and "equip_weapon" in player:
		player.equip_weapon(weapon_id)
	# Теперь обычный boss-бонус выбора перка
	call_deferred("_show_boss_bonus")

func _show_boss_bonus():
	boss_bonus_active = true
	boss_bonus_selected = 0
	boss_bonus_options = [
		{"label": "+3 МАКС HP",       "desc": "Навсегда +3 к здоровью",   "type": "max_hp"},
		{"label": "+20% УРОН",         "desc": "Весь урон +20%",           "type": "damage_mult"},
		{"label": "БЫСТРЕЕ РОЛЛ",      "desc": "Откат ролла -0.3с",        "type": "extra_roll"},
		{"label": "ИММУНИТЕТ К ЯДУ",  "desc": "Яд не действует",          "type": "poison_immune"},
	]
	get_tree().paused = true
	hud.show_boss_bonus(boss_bonus_options, boss_bonus_selected)
	play_sfx("bonus")

func _apply_boss_bonus(bonus: Dictionary):
	if not player or not is_instance_valid(player):
		return
	match bonus.type:
		"max_hp":
			player.max_health += 3
			player.heal(3)
		"damage_mult":
			player.attack_damage = int(player.attack_damage * 1.2)
			if "crit_multiplier" in player:
				player.crit_multiplier += 0.2
		"extra_roll":
			if "roll_cooldown" in player:
				player.roll_cooldown = max(0.3, player.roll_cooldown - 0.3)
		"poison_immune":
			player.set_meta("poison_immune", true)
	hud.update_health(player.health, player.max_health)

func _show_card_selection():
	hud.show_card_selection()
	# Freeze player while choosing
	if player:
		player.is_dead = true
	if not hud.card_chosen.is_connected(_on_card_chosen):
		hud.card_chosen.connect(_on_card_chosen)

func _pause():
	is_paused = true
	pause_menu_selection = 0
	hud.pause_visible = true
	hud.pause_selection = 0
	get_tree().paused = true
	hud.draw_node.queue_redraw()

func _unpause():
	is_paused = false
	hud.pause_visible = false
	get_tree().paused = false
	hud.draw_node.queue_redraw()

func _on_card_chosen(card_id: String):
	if player:
		player.active_card = card_id
		player.is_dead = false
		# Apply card-specific bonuses
		match card_id:
			"backstab": player.card_backstab_bonus = 0.6
			"acid_water": player.card_acid_water = true
			"thorn_armor": player.card_thorn_reduction = 0.8
			"close_combat": player.card_close_range_bonus = 0.4
			"berserker": player.card_low_hp_bonus = true
			"hunter": player.card_kill_bonus = 0.002
			"critical":
				player.card_crit_bonus_chance = 0.10
				player.card_crit_bonus_damage = 0.20
			"second_chance": player.card_second_chance = true
		var card_names = {
			"invisibility": "Невидимость", "death_jar": "Банка Смерти",
			"throw_weapon": "Бросок", "speed_boots": "Ботинки Скорости",
			"dodge": "Уворот", "backstab": "Удар в Спину",
			"acid_water": "Кислотная Вода", "thorn_armor": "Шипастая Броня",
			"close_combat": "Ближний Бой", "berserker": "Берсерк",
			"hunter": "Охотник", "critical": "Критический Удар",
			"second_chance": "Второй Шанс",
		}
		hud.show_message("Карта: " + card_names.get(card_id, card_id), 3.0)

func _on_weapon_selected(weapon_id: int):
	if player and is_instance_valid(player):
		player.equip_weapon(weapon_id)
		player.is_dead = false

func _on_player_died():
	# Скрываем игровые кнопки, чтобы не мешали кнопкам экрана смерти/рестарта
	if mobile_controls and mobile_controls.has_method("set_active"):
		mobile_controls.set_active(false)
	total_deaths += 1
	_save_deaths()
	# Мета: считаем смерть и достигнутый уровень
	var Meta = load("res://scripts/meta_progress.gd")
	Meta.on_death()
	Meta.on_level_reached(current_level)
	await get_tree().create_timer(0.5).timeout
	if future_self_fight:
		# Died fighting future self — bad ending, loop resets
		_trigger_bad_ending()
	else:
		_start_death_cutscene()

func _restart_game():
	if player:
		player.queue_free()
		player = null
	if current_room:
		current_room.queue_free()
		current_room = null

	await get_tree().process_frame
	await get_tree().process_frame

	_start_game()

# === STORY / TIME LOOP SYSTEM ===

func _show_story(level: int):
	if level == 1 and loop_count > 0:
		# Returning from loop
		var msg = loop_messages[mini(loop_count - 1, loop_messages.size() - 1)]
		await get_tree().create_timer(1.0).timeout
		hud.show_story_text(msg, 4.0)
		return

	if story_messages.has(level):
		var messages = story_messages[level]
		await get_tree().create_timer(1.5).timeout
		for i in messages.size():
			hud.show_story_text(messages[i], 3.5)
			await get_tree().create_timer(4.0).timeout

func _on_boss_defeated():
	# Called when golem dies on level 15 — show final choice
	if current_level >= 15:
		await get_tree().create_timer(2.0).timeout
		_show_final_choice()
	else:
		# Normal boss defeated, proceed
		pass

func _show_final_choice():
	final_choice_active = true
	hud.show_final_choice()

func _on_final_choice(choice: String):
	final_choice_active = false
	hud.hide_final_choice()

	if choice == "escape":
		_trigger_bad_ending()
	elif choice == "save":
		_trigger_good_ending()

func _trigger_bad_ending():
	# Time loop resets — dramatic text then restart
	hud.show_story_text("Ты выбрал побег...", 3.0)
	await get_tree().create_timer(3.5).timeout
	hud.show_story_text("Но петлю нельзя обмануть.", 3.0)
	await get_tree().create_timer(3.5).timeout
	hud.show_story_text("Время возвращается назад.", 3.0)
	await get_tree().create_timer(3.5).timeout

	# Screen flash white then fade
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 1.0, 1.5)
	await tween.finished
	await get_tree().create_timer(1.0).timeout

	# Reset everything
	loop_count += 1
	future_self_fight = false
	if player:
		player.queue_free()
		player = null
	if current_room:
		current_room.queue_free()
		current_room = null
	await get_tree().process_frame
	await get_tree().process_frame

	# Fade back in
	var tween2 = create_tween()
	tween2.tween_property(flash, "color:a", 0.0, 2.0)
	_start_game()
	await tween2.finished
	flash.queue_free()

func _trigger_good_ending():
	future_self_fight = true
	hud.show_story_text("Ты выбрал спасти всех.", 3.0)
	await get_tree().create_timer(3.5).timeout
	hud.show_story_text("Но сначала... тебе нужно победить себя.", 3.5)
	await get_tree().create_timer(4.0).timeout

	# Flash transition to new arena
	var flash = ColorRect.new()
	flash.color = Color(0.3, 0.1, 0.5, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 1.0, 1.5)
	await tween.finished

	hud.show_story_text("'Я знаю тебя лучше, чем ты сам.'", 3.5)
	await get_tree().create_timer(2.0).timeout

	# Load special future self arena
	_load_future_arena()

	var tween2 = create_tween()
	tween2.tween_property(flash, "color:a", 0.0, 2.0)
	await tween2.finished
	flash.queue_free()

	await get_tree().create_timer(1.0).timeout
	hud.show_story_text("'Я — лучшая версия тебя.'", 3.5)
	await get_tree().create_timer(2.0).timeout
	hud.show_message("БОСС: БУДУЩИЙ ТЫ", 3.0)

func _load_future_arena():
	# Remove old room
	if current_room:
		current_room.queue_free()
		await current_room.tree_exited

	# Create a special arena room
	var room_script = load("res://scripts/room.gd")
	current_room = Node2D.new()
	current_room.set_script(room_script)
	add_child(current_room)
	move_child(current_room, 0)

	current_room.setup_future_arena(player)

	# Position player on left side
	var player_floor_y = float((current_room.grid_rows - 5) * current_room.tile_size)
	player.position = Vector2(200, player_floor_y - 20)
	player.velocity = Vector2.ZERO
	camera.global_position = player.position
	player.health = player.max_health
	hud.update_health(player.health, player.max_health)

	# Special dark purple atmosphere
	darkness.color = _ambient(Color(0.08, 0.04, 0.12))

	# Spawn future self on the right
	# floor is at grid row (grid_rows - 5), so pixel Y = (grid_rows - 5) * 16
	# Boss needs to be ABOVE the floor
	var boss_floor_y = float((current_room.grid_rows - 5) * current_room.tile_size)
	var future_boss = CharacterBody2D.new()
	var boss_script = load("res://scripts/future_self.gd")
	future_boss.set_script(boss_script)
	future_boss.position = Vector2(current_room.room_width - 200, boss_floor_y - 20)
	future_boss.setup(player)
	current_room.add_child(future_boss)
	future_boss.defeated.connect(_on_future_self_defeated)
	print("BOSS spawned at ", future_boss.position, " floor=", boss_floor_y)

func _on_future_self_defeated():
	future_self_fight = false
	hud.show_story_text("'Нет... как ты мог...'", 3.5)
	await get_tree().create_timer(4.0).timeout
	hud.show_story_text("'Ты сильнее, чем я думал.'", 3.5)
	await get_tree().create_timer(4.0).timeout
	hud.show_story_text("Петля разрывается.", 3.5)
	await get_tree().create_timer(4.0).timeout
	hud.show_story_text("Время освобождается.", 3.5)
	await get_tree().create_timer(4.0).timeout
	hud.show_story_text("Все спасены.", 3.5)
	await get_tree().create_timer(4.0).timeout

	# Victory screen
	_show_victory_screen()

func _show_victory_screen():
	get_tree().paused = true

	var victory = CanvasLayer.new()
	victory.layer = 100
	victory.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(victory)

	var vp = get_viewport().get_visible_rect().size

	# Black overlay ColorRect
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory.add_child(bg)

	# "КОНЕЦ"
	var lbl_end = Label.new()
	lbl_end.text = "КОНЕЦ"
	lbl_end.add_theme_font_size_override("font_size", 48)
	lbl_end.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.0))
	lbl_end.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl_end.position = Vector2(vp.x / 2 - 80, vp.y / 2 - 80)
	lbl_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory.add_child(lbl_end)

	# "Ты победил и жил счастливо"
	var lbl_happy = Label.new()
	lbl_happy.text = "Ты победил и жил счастливо"
	lbl_happy.add_theme_font_size_override("font_size", 20)
	lbl_happy.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.0))
	lbl_happy.position = Vector2(vp.x / 2 - 200, vp.y / 2)
	lbl_happy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory.add_child(lbl_happy)

	# "Так ведь?"
	var lbl_twist = Label.new()
	lbl_twist.text = "Так ведь?"
	lbl_twist.add_theme_font_size_override("font_size", 28)
	lbl_twist.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1, 0.0))
	lbl_twist.position = Vector2(vp.x / 2 - 80, vp.y / 2 + 60)
	lbl_twist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory.add_child(lbl_twist)

	# Helper: tween a label's alpha
	var set_alpha = func(lbl: Label, a: float):
		var c = lbl.get_theme_color("font_color")
		lbl.add_theme_color_override("font_color", Color(c.r, c.g, c.b, a))

	# Phase 0: fade screen to black (2s)
	var tw = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.tween_method(func(a): bg.color = Color(0, 0, 0, a), 0.0, 1.0, 2.0)
	await tw.finished

	# Phase 1: "КОНЕЦ" fades in (1.5s) then holds (2s)
	var tw2 = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw2.tween_method(func(a): set_alpha.call(lbl_end, a), 0.0, 1.0, 1.5)
	await tw2.finished
	await get_tree().create_timer(2.0, false, false, true).timeout

	# Phase 2: "Ты победил..." fades in (1.5s) then holds (3s)
	var tw3 = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw3.tween_method(func(a): set_alpha.call(lbl_happy, a), 0.0, 1.0, 1.5)
	await tw3.finished
	await get_tree().create_timer(3.0, false, false, true).timeout

	# Phase 3: "Так ведь?" fades in (1s) then blinks for 4s
	var tw4 = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw4.tween_method(func(a): set_alpha.call(lbl_twist, a), 0.0, 1.0, 1.0)
	await tw4.finished

	var blink_time = 0.0
	while blink_time < 4.0:
		await get_tree().process_frame
		blink_time += get_process_delta_time()
		var blink = 0.5 + sin(blink_time * 5.0) * 0.5
		set_alpha.call(lbl_twist, blink)

	get_tree().quit()

func _sync_minimap():
	if current_room and current_room.has_method("get_minimap_data"):
		hud.set_minimap(current_room.get_minimap_data(), current_room.minimap_current_idx)

func _on_player_leveled_up(choices: Array):
	level_up_active = true
	level_up_choices = choices
	level_up_selected = 0
	get_tree().paused = true
	hud.update_progression(player.char_level, player.xp, player.xp_needed)
	hud.show_level_up(choices)

func _get_room_event_label() -> String:
	if not current_room: return ""
	var ev = current_room.room_event if "room_event" in current_room else ""
	match ev:
		"merchant": return "⚑ Торговец"
		"altar":    return "✦ Алтарь"
		"cursed":   return "☠ Проклятая комната"
	if current_room.is_boss_room: return "⚔ БОСС"
	# Room type from minimap data
	if current_room.has_method("get_current_room_type"):
		return current_room.get_current_room_type()
	return ""

func _start_music():
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.5
	music_ap = AudioStreamPlayer.new()
	music_ap.stream = stream
	music_ap.volume_db = linear_to_db(settings_master_vol / 100.0) - 22.0
	add_child(music_ap)
	music_ap.play()
	music_pb = music_ap.get_stream_playback() as AudioStreamGeneratorPlayback
	music_time = 0.0

var music_tension: float = 0.0   # 0=спокойно, 1=бой. Плавно меняется.

# Заранее сгенерированная 8-сек петля музыки (бесшовная: все частоты дают
# целое число циклов за 8с). Раньше музыка синтезировалась КАЖДЫЙ кадр —
# тысячи sin/exp на кадр в GDScript = постоянные просадки на телефоне и
# старых ПК. Теперь генерим один раз на биом и просто копируем сэмплы.
var _music_loop: PackedVector2Array = PackedVector2Array()
var _music_loop_idx: int = 0
var _music_loop_biome: int = -1

func _generate_music_loop(biome: int) -> PackedVector2Array:
	var sr := 22050.0
	var loop_secs := 8.0
	var total := int(sr * loop_secs)
	var base_hz: float = [110.0, 98.0, 123.5, 92.5][biome]
	var buf := PackedVector2Array()
	buf.resize(total)
	for i in total:
		var t := float(i) / sr
		var d1 := sin(t * base_hz * TAU) * 0.06
		var d2 := sin(t * base_hz * 1.5 * TAU) * 0.035
		var beat := fmod(t, 4.0)
		var pad := sin(t * base_hz * 2.0 * TAU) * (exp(-beat * 0.4) * 0.04)
		var hi_beat := fmod(t, 8.0)
		var hi := sin(t * base_hz * 4.0 * TAU) * exp(-hi_beat * 1.5) * 0.025
		var wind := (sin(t * 0.7) * 0.5 + 0.5) * sin(t * 311.3) * 0.010
		var s := d1 + d2 + pad + hi + wind
		buf[i] = Vector2(s, s)
	return buf

func _fill_music_buffer():
	if not music_pb or not is_instance_valid(music_ap): return
	var frames = music_pb.get_frames_available()
	if frames < 64: return
	# Перегенерируем петлю только при смене биома (раз в 4 уровня)
	var biome = ((current_level - 1) / 4) % 4
	if biome != _music_loop_biome or _music_loop.is_empty():
		_music_loop = _generate_music_loop(biome)
		_music_loop_biome = biome
		_music_loop_idx = 0
	# Просто копируем сэмплы из петли (без синтеза) — почти бесплатно
	var n := _music_loop.size()
	for i in frames:
		music_pb.push_frame(_music_loop[_music_loop_idx])
		_music_loop_idx += 1
		if _music_loop_idx >= n:
			_music_loop_idx = 0

func _load_tutorial_level():
	# Simple hand-built tutorial room teaching: roll, wall climb, platform
	if current_room:
		current_room.queue_free()
		await current_room.tree_exited

	# Create a tutorial room using a stripped-down approach via room.gd
	var room_script = load("res://scripts/room.gd")
	current_room = Node2D.new()
	current_room.set_script(room_script)
	add_child(current_room)
	move_child(current_room, 0)

	# Use level 0 — room.gd setup will create tutorial layout
	current_room.setup(0, enemy_scene, player)
	current_room.room_cleared.connect(_on_room_cleared)
	current_room.door_used.connect(_on_door_used)
	current_room.challenge_complete.connect(_on_challenge_complete)
	if current_room.has_signal("craft_message"):
		current_room.craft_message.connect(_on_craft_message)
	if current_room.has_signal("open_craft_menu_request"):
		current_room.open_craft_menu_request.connect(_on_open_craft_menu)
	if current_room.has_signal("open_shop_menu_request"):
		current_room.open_shop_menu_request.connect(_on_open_shop_menu)
	# HUD сигналы магазина (подключаем единожды)
	if hud and not hud.shop_buy_selected.is_connected(_on_shop_buy):
		hud.shop_buy_selected.connect(_on_shop_buy)
	if hud and not hud.shop_closed.is_connected(_on_shop_closed):
		hud.shop_closed.connect(_on_shop_closed)

	# Place player at start
	var start_cave = null
	for cave in current_room.caves:
		if cave.type == "start":
			start_cave = cave
			break
	if start_cave:
		player.position = Vector2(start_cave.x, start_cave.floor_y - 10)
	else:
		player.position = Vector2(60, 400)
	camera.global_position = player.position

	# Tutorial messages
	hud.show_story_text([
		"ОБУЧЕНИЕ",
		"1. Shift - перекат (пролезь в щель)",
		"2. Стена + A/D - лезь по стене",
		"3. S на платформе - спрыгнуть",
		"Доберись до двери!",
	])

	# Set room brightness for tutorial
	darkness.color = _ambient(Color(0.3, 0.28, 0.25))
