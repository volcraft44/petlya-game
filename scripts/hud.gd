extends CanvasLayer

var health_max: int = 100
var health_current: int = 100
var current_level: int = 1
var enemies_remaining: int = 0
var message_text: String = ""
var message_timer: float = 0.0

# ── Атмосферный HUD: время и капли крови ──
var hud_time: float = 0.0
var blood_drips: Array = []   # [{x, y, vy, life, max_life, w}]
var _blood_spawn_cd: float = 0.0
var _prev_health: int = 100
var _hp_hit_flash: float = 0.0  # вспышка при получении урона
# Переиспользуемые RNG для HP-бара
var _hp_rng_meat: RandomNumberGenerator = RandomNumberGenerator.new()
var _hp_rng_edge: RandomNumberGenerator = RandomNumberGenerator.new()
# Кэш миникарты: тайлы рисуются в текстуру и переотрисовываются только при изменении
var _mm_texture: ImageTexture = null
var _mm_image: Image = null
var _mm_explored_count: int = -1     # сравниваем количество исследованных тайлов
var _mm_cached_cols: int = 0
var _mm_cached_rows: int = 0

# Controls tutorial (level 1 only)
var show_controls: bool = false
var show_controls_after_card: bool = false
var controls_alpha: float = 1.0

# Crafting animation
var is_crafting: bool = false
var craft_timer: float = 0.0
var craft_duration: float = 2.5
var craft_item: String = ""  # "lockpick" or "crystal"

signal crafting_done
signal craft_recipe_selected(station_type: String, recipe_index: int)

# Crafting menu (Minecraft-style)
var craft_menu_open: bool = false
var craft_menu_station: String = ""  # "furnace", "anvil", "grate"
var craft_menu_selected: int = 0  # Currently highlighted recipe

# === Shop menu (стиль как у печки) ===
var shop_menu_open: bool = false
var shop_items: Array = []   # передаётся из room.gd: [{label, price, type, ...}]
var shop_selected: int = 0
signal shop_buy_selected(index: int)
signal shop_closed

# Story text (time loop lore)
var story_text: String = ""
var story_timer: float = 0.0
var story_alpha: float = 0.0

# Final choice screen
var final_choice_visible: bool = false
var final_choice_selected: int = 0  # 0 = escape, 1 = save
signal final_choice_made(choice: String)

# Card selection screen
var card_selection_visible: bool = false
var card_options: Array = []  # 3 card names to choose from
var card_selected: int = 0
signal card_chosen(card_name: String)

# Debug weapon selector
var weapon_menu_visible: bool = false
var weapon_menu_selected: int = 0
signal weapon_selected(weapon_id: int)

# Pause menu (drawn by HUD, controlled by main.gd)
var pause_visible: bool = false
var pause_selection: int = 0

# Settings screen
var settings_visible: bool = false
var settings_selection: int = 0
var settings_master_vol: float = 80.0
var settings_sfx_vol: float = 60.0
var settings_shake: bool = true

# === ECONOMY & PROGRESSION ===
var coins: int = 0
var char_level: int = 1
var xp: int = 0
var xp_needed: int = 60

# Kill combo display
var combo_count: int = 0
var combo_display_timer: float = 0.0

# Level-up screen
var level_up_visible: bool = false
var level_up_choices: Array = []
var level_up_selected: int = 0
signal level_up_chosen(choice_id: String)
signal relic_chosen(rid: String)
signal modifier_chosen(mod_id: String)

# Relic choice UI (используется и для модификаторов уровня)
var relic_menu_open: bool = false
var relic_choices: Array = []
var relic_selected: int = 0
var relic_menu_mode: String = "relic"   # "relic" или "modifier"

# Room name flash
var room_name_text: String = ""
var room_name_timer: float = 0.0

# Mini-map
var minimap_rooms: Array = []
var minimap_current: int = -1

var all_cards: Array = [
	{"id": "invisibility", "name": "Невидимость", "desc": "Враги не видят тебя\nвдали от факелов\n[Пассивно]", "color": Color(0.3, 0.8, 1.0)},
	{"id": "death_jar", "name": "Банка Смерти", "desc": "Собирай яд из луж\nкидай на врагов\n[R - бросить]", "color": Color(0.2, 0.9, 0.1)},
	{"id": "throw_weapon", "name": "Бросок", "desc": "Кидай оружие\nс двойным уроном\n[Q - бросить]", "color": Color(1.0, 0.6, 0.2)},
	{"id": "speed_boots", "name": "Ботинки Скорости", "desc": "+50% скорость\n+30% прыжок +5% урон\n[Пассивно]", "color": Color(1.0, 1.0, 0.3)},
	{"id": "dodge", "name": "Уворот", "desc": "25% шанс уворота\n40% с клинками\n[Пассивно]", "color": Color(0.8, 0.4, 1.0)},
	{"id": "backstab", "name": "Удар в Спину", "desc": "+60% урона сзади\n[Пассивно]", "color": Color(0.6, 0.1, 0.1)},
	{"id": "acid_water", "name": "Кислотная Вода", "desc": "Ядовитые лужи\nвосстанавливают HP\n[Пассивно]", "color": Color(0.1, 0.9, 0.5)},
	{"id": "thorn_armor", "name": "Шипастая Броня", "desc": "Шипы наносят\nна 80% меньше урона\n[Пассивно]", "color": Color(0.5, 0.5, 0.6)},
	{"id": "close_combat", "name": "Ближний Бой", "desc": "+40% урона вблизи\n(1-2 блока)\n[Пассивно]", "color": Color(0.9, 0.3, 0.1)},
	{"id": "berserker", "name": "Берсерк", "desc": "+0.5% урона за\nкаждый 1% потерянного HP\n[Пассивно]", "color": Color(0.8, 0.1, 0.2)},
	{"id": "hunter", "name": "Охотник", "desc": "+0.2% к урону\nза каждое убийство\n[Пассивно]", "color": Color(0.4, 0.7, 0.2)},
	{"id": "critical", "name": "Критический Удар", "desc": "+10% шанс крита\n+20% урон крита\n[Пассивно]", "color": Color(1.0, 0.5, 0.0)},
	{"id": "second_chance", "name": "Второй Шанс", "desc": "Воскрешение 1 раз\n50% HP, стан врагов\n[Пассивно]", "color": Color(1.0, 1.0, 1.0)},
]

# Boss bonus screen
var boss_bonus_visible: bool = false
var boss_bonus_options: Array = []
var boss_bonus_selected: int = 0

@onready var draw_node: Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = Control.new()
	draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

func _process(delta):
	hud_time += delta

	# Detect HP drop → trigger blood flash
	if health_current < _prev_health:
		_hp_hit_flash = 0.5
	_prev_health = health_current
	if _hp_hit_flash > 0.0:
		_hp_hit_flash -= delta

	# Update blood drips (gravity)
	for d in blood_drips:
		d.vy += 220.0 * delta
		d.y  += d.vy * delta
		d.life -= delta
	# Prune dead drips
	blood_drips = blood_drips.filter(func(d): return d.life > 0.0 and d.y < 600.0)

	# Spawn new drips from HP bar — чаще при низком HP
	var hp_frac_p = float(health_current) / max(health_max, 1)
	_blood_spawn_cd -= delta
	if _blood_spawn_cd <= 0.0 and not (health_current <= 0):
		# Чем меньше HP — тем чаще капает (и хотя бы одна капля иногда даже на полном HP)
		var spawn_rate = 0.15 + (1.0 - hp_frac_p) * 0.3
		_blood_spawn_cd = randf_range(spawn_rate, spawn_rate * 2.5)
		# Капля стекает с конца заполненной части HP-бара
		var bar_w_local = 160.0
		var fill_w = bar_w_local * hp_frac_p
		if fill_w > 4.0:
			var dx = 10.0 + randf() * fill_w
			blood_drips.append({
				"x": dx,
				"y": 20.0,  # снизу HP-бара (y=6+14)
				"vy": randf_range(10.0, 30.0),
				"life": randf_range(1.2, 2.5),
				"max_life": 2.5,
				"w": randf_range(1.0, 2.0),
			})

	# Combo + room name timers
	if combo_display_timer > 0:
		combo_display_timer -= delta
	if room_name_timer > 0:
		room_name_timer -= delta
	# Throttle: HUD не нужен 180 FPS, рисуем через кадр — экономия CPU
	if Engine.get_process_frames() % 2 == 0:
		draw_node.queue_redraw()

	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_text = ""
	if is_crafting:
		craft_timer -= delta
		if craft_timer <= 0:
			is_crafting = false
			crafting_done.emit()
	# Story text fade
	if story_timer > 0:
		story_timer -= delta
		if story_timer > 0.5:
			story_alpha = min(story_alpha + delta * 3, 1.0)
		else:
			story_alpha = max(story_alpha - delta * 2, 0.0)
		if story_timer <= 0:
			story_text = ""
			story_alpha = 0.0
	# Card selection input
	if card_selection_visible and not show_controls:
		if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"):
			card_selected = max(0, card_selected - 1)
		elif Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"):
			card_selected = min(card_options.size() - 1, card_selected + 1)
		elif Input.is_action_just_pressed("ui_accept"):
			var chosen = card_options[card_selected]
			card_selection_visible = false
			card_chosen.emit(chosen.id)
			if show_controls_after_card:
				show_controls_after_card = false
				show_controls = true

	# Weapon menu input
	if weapon_menu_visible:
		if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
			weapon_menu_selected = max(0, weapon_menu_selected - 1)
		elif Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
			weapon_menu_selected = min(22, weapon_menu_selected + 1)
		elif Input.is_action_just_pressed("ui_accept"):
			weapon_menu_visible = false
			weapon_selected.emit(weapon_menu_selected)
		elif Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
			weapon_menu_visible = false

	# Final choice input
	if final_choice_visible:
		if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("move_left"):
			final_choice_selected = 0
		elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("move_right"):
			final_choice_selected = 1
		elif Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_ENTER):
			final_choice_visible = false
			var choice = "escape" if final_choice_selected == 0 else "save"
			final_choice_made.emit(choice)
	# Перерисовку запускает throttle выше (каждый 2-й кадр). Безусловный
	# redraw здесь убран — он сводил throttle на нет и рисовал HUD каждый кадр.

func show_story_text(text: String, duration: float = 3.0):
	story_text = text
	story_timer = duration
	story_alpha = 0.0

func show_final_choice():
	final_choice_visible = true
	final_choice_selected = 0

func hide_final_choice():
	final_choice_visible = false

func show_card_selection():
	# Pick 3 random cards from all_cards
	var shuffled = all_cards.duplicate()
	shuffled.shuffle()
	card_options = [shuffled[0], shuffled[1], shuffled[2]]
	card_selected = 1  # Start in middle
	card_selection_visible = true

func start_crafting(item: String):
	is_crafting = true
	craft_timer = craft_duration
	craft_item = item

func show_relic_choice(choices: Array):
	relic_menu_open = true
	relic_menu_mode = "relic"
	relic_choices = choices
	relic_selected = 0
	get_tree().paused = true
	draw_node.queue_redraw()

func show_modifier_choice(choices: Array):
	relic_menu_open = true
	relic_menu_mode = "modifier"
	relic_choices = choices
	relic_selected = 0
	get_tree().paused = true
	draw_node.queue_redraw()

func close_relic_choice():
	relic_menu_open = false
	relic_choices = []
	get_tree().paused = false
	draw_node.queue_redraw()

func _draw_relic_choice(screen_size: Vector2):
	if relic_choices.is_empty():
		return
	# Затемнение
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y),
		Color(0, 0, 0, 0.78))
	var cx = screen_size.x * 0.5
	var cy = screen_size.y * 0.5
	var font := ThemeDB.fallback_font
	# Заголовок
	var title = "ВЫБЕРИ МОДИФИКАТОР УРОВНЯ" if relic_menu_mode == "modifier" else "ВЫБЕРИ РЕЛИКВИЮ"
	var t_size = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_node.draw_string(font, Vector2(cx - t_size.x * 0.5, cy - 140),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.85, 0.20))

	# 3 карточки
	var card_w = 200.0
	var card_h = 200.0
	var gap = 16.0
	var total_w = relic_choices.size() * card_w + (relic_choices.size() - 1) * gap
	var start_x = cx - total_w * 0.5
	for i in relic_choices.size():
		var r = relic_choices[i]
		var x = start_x + i * (card_w + gap)
		var y = cy - card_h * 0.5
		var is_sel = (i == relic_selected)
		# Фон
		draw_node.draw_rect(Rect2(x, y, card_w, card_h),
			Color(0.08, 0.06, 0.10, 0.95))
		# Рамка (цветная по рарности)
		var rar_col = r.icon_color
		var border_w = 3.0 if is_sel else 1.5
		draw_node.draw_rect(Rect2(x, y, card_w, card_h),
			Color(rar_col.r, rar_col.g, rar_col.b, 1.0 if is_sel else 0.7),
			false, border_w)
		# Иконка-кружок
		draw_node.draw_circle(Vector2(x + card_w * 0.5, y + 50), 26, rar_col)
		draw_node.draw_circle(Vector2(x + card_w * 0.5, y + 50), 18,
			Color(rar_col.r * 0.55, rar_col.g * 0.55, rar_col.b * 0.55))
		# Название
		var n_size = font.get_string_size(r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_node.draw_string(font, Vector2(x + card_w * 0.5 - n_size.x * 0.5, y + 100),
			r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
		# Описание (с переносом по строкам)
		var desc = r.desc
		var d_size = font.get_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_node.draw_string(font, Vector2(x + 10, y + 130),
			desc, HORIZONTAL_ALIGNMENT_LEFT, card_w - 20, 10,
			Color(0.85, 0.85, 0.92, 0.9))
		# Лейбл рарности (только для реликвий)
		if relic_menu_mode == "relic" and r.has("rarity"):
			var rar_text = r.rarity.to_upper()
			var rr_size = font.get_string_size(rar_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
			draw_node.draw_string(font, Vector2(x + card_w * 0.5 - rr_size.x * 0.5, y + card_h - 12),
				rar_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, rar_col)

	# Подсказка
	draw_node.draw_string(font, Vector2(cx - 110, cy + 130),
		"A/D — выбор · Enter — взять · Esc — пропустить",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.65))

func open_shop_menu(items: Array):
	shop_menu_open = true
	shop_items = items
	shop_selected = 0
	# Перематываем на первый непокупленный
	for i in shop_items.size():
		if not shop_items[i].get("bought", false):
			shop_selected = i
			break

func close_shop_menu():
	shop_menu_open = false
	shop_closed.emit()

func is_shop_open() -> bool:
	return shop_menu_open

func update_shop_items(items: Array):
	# Обновить состояние (например после покупки)
	shop_items = items

func open_craft_menu(station_type: String):
	craft_menu_open = true
	craft_menu_station = station_type
	craft_menu_selected = 0

func close_craft_menu():
	craft_menu_open = false
	craft_menu_station = ""
	# Unfreeze player
	var player = _get_player()
	if player:
		player.is_dead = false

func is_menu_open() -> bool:
	return craft_menu_open

func _get_recipes(station: String, player) -> Array:
	# Returns array of {name, ingredients, can_craft, result_desc}
	var recipes = []
	if not player:
		return recipes

	match station:
		"furnace":
			recipes.append({
				"name": "Iron Ingot",
				"ingredients": "Iron Ore x1",
				"can_craft": player.iron_ore > 0,
				"result_desc": "Smelt iron ore into ingot"
			})
			recipes.append({
				"name": "Gold Ingot",
				"ingredients": "Gold Ore x1",
				"can_craft": player.gold_ore > 0,
				"result_desc": "Smelt gold ore into ingot"
			})
		"anvil":
			recipes.append({
				"name": "Lockpick",
				"ingredients": "Iron Ingot + Pickaxe",
				"can_craft": player.iron_ingot > 0 and player.has_pickaxe and not player.has_lockpick,
				"result_desc": "Craft a lockpick for doors"
			})
			recipes.append({
				"name": "Merged Sword",
				"ingredients": "Iron Ingot + Blade",
				"can_craft": player.iron_ingot > 0 and player.has_blade and player.sword_tier < 2,
				"result_desc": "Forge a stronger sword (+20 DMG)"
			})
			recipes.append({
				"name": "Amulet",
				"ingredients": "Gold Ingot + Pearl",
				"can_craft": player.gold_ingot > 0 and player.has_pearl,
				"result_desc": "Heals 1 HP every 10 seconds"
			})
		"grate":
			var room = _get_room()
			var grate_used = room.grate_used_this_level if room else false
			recipes.append({
				"name": "Fill Flask",
				"ingredients": "Grate liquid",
				"can_craft": not grate_used,
				"result_desc": "Flask +3 charges [F to use]"
			})
	return recipes

func _unhandled_input(event):
	if show_controls and event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		show_controls = false
		get_viewport().set_input_as_handled()
		if draw_node:
			draw_node.queue_redraw()
		return

	# === Relic choice input ===
	if relic_menu_open and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				relic_selected = (relic_selected - 1 + relic_choices.size()) % relic_choices.size()
				draw_node.queue_redraw()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				relic_selected = (relic_selected + 1) % relic_choices.size()
				draw_node.queue_redraw()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				if relic_selected >= 0 and relic_selected < relic_choices.size():
					var rid = relic_choices[relic_selected].id
					if relic_menu_mode == "modifier":
						modifier_chosen.emit(rid)
					else:
						relic_chosen.emit(rid)
				close_relic_choice()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				close_relic_choice()
				get_viewport().set_input_as_handled()
		return

	# === Shop menu input ===
	if shop_menu_open and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE, KEY_E:
				close_shop_menu()
				get_viewport().set_input_as_handled()
			KEY_W, KEY_UP:
				_shop_navigate(-1)
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				_shop_navigate(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				if shop_selected >= 0 and shop_selected < shop_items.size():
					if not shop_items[shop_selected].get("bought", false):
						shop_buy_selected.emit(shop_selected)
				get_viewport().set_input_as_handled()
		return

	if not craft_menu_open:
		return

	if event is InputEventKey and event.pressed:
		var recipes = _get_recipes(craft_menu_station, _get_player())
		match event.keycode:
			KEY_ESCAPE, KEY_E:
				close_craft_menu()
				get_viewport().set_input_as_handled()
			KEY_W, KEY_UP:
				craft_menu_selected = max(0, craft_menu_selected - 1)
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				craft_menu_selected = min(recipes.size() - 1, craft_menu_selected + 1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				if craft_menu_selected >= 0 and craft_menu_selected < recipes.size():
					if recipes[craft_menu_selected].can_craft:
						craft_recipe_selected.emit(craft_menu_station, craft_menu_selected)
						# Re-check recipes after crafting
				get_viewport().set_input_as_handled()
			KEY_1:
				if recipes.size() > 0 and recipes[0].can_craft:
					craft_menu_selected = 0
					craft_recipe_selected.emit(craft_menu_station, 0)
				get_viewport().set_input_as_handled()
			KEY_2:
				if recipes.size() > 1 and recipes[1].can_craft:
					craft_menu_selected = 1
					craft_recipe_selected.emit(craft_menu_station, 1)
				get_viewport().set_input_as_handled()
			KEY_3:
				if recipes.size() > 2 and recipes[2].can_craft:
					craft_menu_selected = 2
					craft_recipe_selected.emit(craft_menu_station, 2)
				get_viewport().set_input_as_handled()

func update_health(current: int, max_hp: int = -1):
	health_current = current
	if max_hp > 0:
		health_max = max_hp

func update_level(level: int):
	current_level = level

func update_enemies(count: int):
	enemies_remaining = count

func show_message(text: String, duration: float = 2.0):
	message_text = text
	message_timer = duration

func _on_draw():
	var screen_size = draw_node.get_viewport_rect().size
	# === TOP-LEFT: HP BAR (мясо/кровь) ===
	var hp_x = 10.0
	var hp_y = 6.0
	var bar_w = 160.0
	var bar_h = 14.0
	var hp_frac = float(health_current) / max(health_max, 1)

	# Тёмная "панель"-фон (грязно-кровавая)
	draw_node.draw_rect(Rect2(5, 3, bar_w + 80, 22), Color(0.06, 0.02, 0.02, 0.7))
	# Чёрная "ямка" под мясо — тут видна кость когда HP мало
	draw_node.draw_rect(Rect2(hp_x, hp_y, bar_w, bar_h), Color(0.05, 0.02, 0.02, 0.95))
	# Костяные риски на пустом фоне (видны на пустой части)
	for bi in 6:
		var bx = hp_x + 4.0 + bi * 26.0
		draw_node.draw_rect(Rect2(bx, hp_y + 3, 2, bar_h - 6),
			Color(0.35, 0.30, 0.26, 0.35))

	# Пульсация — частота зависит от HP (низкий = частое биение)
	var pulse_speed = 2.0 + (1.0 - hp_frac) * 6.0
	var pulse = 0.5 + 0.5 * sin(hud_time * TAU * pulse_speed * 0.5)
	var fill_w = bar_w * hp_frac
	# Лёгкое "дыхание" — изменение высоты на ±1px при низком HP
	var breath_off = 0.0
	if hp_frac < 0.4:
		breath_off = pulse * 1.0

	# Слои мяса — рисуем горизонтальными полосами разного оттенка
	if fill_w > 0.0:
		# 1) Тёмная подложка (мышца глубокая)
		draw_node.draw_rect(Rect2(hp_x, hp_y, fill_w, bar_h),
			Color(0.30, 0.04, 0.04, 0.95))
		# 2) Основная плоть — средний красный
		draw_node.draw_rect(Rect2(hp_x, hp_y + 2, fill_w, bar_h - 4),
			Color(0.62, 0.10, 0.10))
		# 3) Сухожилия — светлые тонкие полоски (горизонтальные)
		for s in range(3):
			var sy = hp_y + 3.5 + s * 3.0
			var stripe_alpha = 0.5 + 0.3 * sin(hud_time * 0.8 + s * 1.2)
			draw_node.draw_rect(Rect2(hp_x + 1, sy, fill_w - 2, 1.0),
				Color(0.95, 0.65, 0.55, stripe_alpha * 0.55))
		# 4) "Жирок" — пятна (детерм. RNG, переиспользуем)
		_hp_rng_meat.seed = 42
		var spots = int(fill_w / 18.0)  # реже
		for sp in spots:
			var spx = hp_x + 2 + _hp_rng_meat.randf() * (fill_w - 4)
			var spy = hp_y + 2 + _hp_rng_meat.randf() * (bar_h - 4)
			var sr = 1.0 + _hp_rng_meat.randf() * 1.5
			draw_node.draw_circle(Vector2(spx, spy), sr,
				Color(0.98, 0.75, 0.65, 0.45))
		# 5) Тёмные вены — меньше сегментов
		var vein_count = 2  # было 4
		for v in vein_count:
			var vy = hp_y + 5 + v * 4.0
			var vx0 = hp_x + 1
			var vx1 = hp_x + fill_w - 1
			var segs = max(2, int(fill_w / 28.0))  # вдвое меньше сегментов
			var px = vx0
			var py = vy
			for sg in segs:
				var nx = vx0 + (vx1 - vx0) * float(sg + 1) / float(segs)
				var ny = vy + sin(hud_time * 0.4 + v * 1.7 + sg * 0.9) * 0.8
				draw_node.draw_line(Vector2(px, py), Vector2(nx, ny),
					Color(0.18, 0.02, 0.02, 0.8), 1.0)
				px = nx
				py = ny
		# 6) Биение — пульсирующее красное свечение на правом крае (где обрыв)
		var pulse_w = 6.0
		var glow_alpha = 0.3 + pulse * 0.4
		draw_node.draw_rect(Rect2(hp_x + fill_w - pulse_w, hp_y - breath_off,
			pulse_w, bar_h + breath_off * 2.0),
			Color(0.95, 0.20, 0.15, glow_alpha))
		# 7) Рваный край справа — зубчатый обрыв "разорванного мяса"
		_hp_rng_edge.seed = int(hud_time * 8.0) & 0xFFFF  # медленно меняется
		var jag_n = 4  # было 5
		for j in jag_n:
			var jy = hp_y + j * (bar_h / jag_n)
			var jh = bar_h / jag_n
			var jut = _hp_rng_edge.randf_range(-1.5, 3.5)
			draw_node.draw_rect(Rect2(hp_x + fill_w, jy, jut, jh),
				Color(0.50, 0.08, 0.08))
		# 8) Если HP < 30% — поверх ярко-красный "альфа-флэш" от боли
		if hp_frac < 0.30:
			var pain = 0.4 + 0.4 * sin(hud_time * 8.0)
			draw_node.draw_rect(Rect2(hp_x, hp_y, fill_w, bar_h),
				Color(1.0, 0.0, 0.0, pain * 0.25))

	# Капли крови, что уже падают (под HP-баром)
	for d in blood_drips:
		var life_frac = d.life / d.max_life
		var dc = Color(0.55, 0.05, 0.05, clampf(life_frac * 1.5, 0.0, 0.9))
		# вытянутая капля
		draw_node.draw_rect(Rect2(d.x - d.w * 0.5, d.y, d.w, 3.0 + d.vy * 0.02), dc)
		# "хвост" сверху (соединение с баром, если близко)
		if d.y < 30.0:
			draw_node.draw_line(Vector2(d.x, 20.0), Vector2(d.x, d.y),
				Color(0.45, 0.03, 0.03, 0.8 * life_frac), 1.0)

	# Чёрная "обводка" — рваная, прерывистая
	draw_node.draw_rect(Rect2(hp_x, hp_y, bar_w, bar_h),
		Color(0.0, 0.0, 0.0, 0.55), false, 1.5)

	# Вспышка при получении урона — белая обводка-импульс
	if _hp_hit_flash > 0.0:
		draw_node.draw_rect(Rect2(hp_x - 2, hp_y - 2, bar_w + 4, bar_h + 4),
			Color(1.0, 0.2, 0.2, _hp_hit_flash * 1.4), false, 2.0)

	# Череп-иконка слева (вместо мультяшного сердечка)
	_draw_skull_icon(Vector2(hp_x - 2, hp_y - 2), hp_frac)

	# Numeric HP text — с обводкой, дрожащий при низком HP
	var hp_text = str(health_current) + "/" + str(health_max)
	var hp_tx = bar_w + 15.0
	var hp_ty = 18.0
	if hp_frac < 0.30:
		hp_tx += randf_range(-0.8, 0.8)
		hp_ty += randf_range(-0.8, 0.8)
	# Чёрная обводка
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0: continue
			draw_node.draw_string(ThemeDB.fallback_font,
				Vector2(hp_tx + ox, hp_ty + oy),
				hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.9))
	var hp_text_col = Color(0.95, 0.20, 0.20) if hp_frac > 0.3 else Color(1.0, 0.45, 0.45)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(hp_tx, hp_ty),
		hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, hp_text_col)

	# === SECOND ROW: Loop counter + Enemies ===
	# Грязно-каменная панель
	draw_node.draw_rect(Rect2(5, 27, 200, 16), Color(0.08, 0.05, 0.04, 0.55))
	# Тонкая красная нить-разделитель снизу
	draw_node.draw_rect(Rect2(5, 42, 200, 1), Color(0.4, 0.05, 0.05, 0.6))
	# "ПЕТЛЯ" № — мерцающие цифры
	var loop_text = "ПЕТЛЯ №" + str(current_level)
	var loop_flicker = 0.85 + 0.15 * sin(hud_time * 1.3)
	# Чёрная обводка
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0: continue
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(10 + ox, 39 + oy),
				loop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.85))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(10, 39),
		loop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.85, 0.10, 0.10, loop_flicker))
	# "Осталось" вместо "Enemies"
	var enemy_text = "осталось: " + str(enemies_remaining)
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0: continue
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(95 + ox, 39 + oy),
				enemy_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.85))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(95, 39),
		enemy_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.72, 0.62))

	# === THIRD ROW: Heal + Blade ===
	var player = _get_player()
	if player:
		draw_node.draw_rect(Rect2(5, 45, 200, 16), Color(0.06, 0.03, 0.03, 0.5))
		# Heal charges — флаконы тёмно-красного зелья (с лёгким бликом)
		for i in player.heal_charges:
			var fx = 12.0 + i * 10.0
			var fy = 53.0
			# Стекло флакона (тёмная подложка)
			draw_node.draw_rect(Rect2(fx - 3, fy - 4, 6, 7), Color(0.08, 0.05, 0.05, 0.9))
			# Жидкость — кровавая, чуть пульсирует
			var liq_pulse = 0.5 + 0.5 * sin(hud_time * 2.0 + i * 0.9)
			draw_node.draw_rect(Rect2(fx - 2, fy - 3, 4, 5),
				Color(0.55 + liq_pulse * 0.2, 0.05, 0.05))
			# Блик
			draw_node.draw_rect(Rect2(fx - 2, fy - 3, 1, 5),
				Color(1.0, 0.4, 0.4, 0.4))
			# Пробка
			draw_node.draw_rect(Rect2(fx - 2, fy - 5, 4, 1), Color(0.30, 0.20, 0.10))
		if player.heal_charges > 0:
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(42, 57),
				"[H] исцелить", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				Color(0.65, 0.15, 0.15, 0.85))

		# Blade/sword tier indicator + damage
		if player.has_blade or player.sword_tier > 0:
			var blade_text = ""
			match player.sword_tier:
				0: blade_text = "BLADE"
				1: blade_text = "BLADE"
				2: blade_text = "MERGED"
			if player.attack_damage > 20:
				blade_text += " DMG:" + str(player.attack_damage)
			var blade_col = Color(1, 0.6, 0.2, 0.9) if player.sword_tier >= 2 else Color(0.4, 0.85, 1.0, 0.9)
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(110, 57),
				blade_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, blade_col)

		# Flask charges
		if player.has_flask and player.flask_charges > 0:
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(180, 57),
				"[F]x" + str(player.flask_charges), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.8, 0.9, 0.8))

		# === CS gadgets — гранаты ===
		if "smoke_grenades" in player and player.smoke_grenades > 0:
			# Иконка-смок: серый облачко
			var sx = 5
			var sy = 73
			draw_node.draw_rect(Rect2(sx, sy, 130, 14), Color(0.06, 0.06, 0.08, 0.55))
			# Smoke icon
			draw_node.draw_circle(Vector2(sx + 8, sy + 7), 5, Color(0.7, 0.7, 0.75))
			draw_node.draw_circle(Vector2(sx + 12, sy + 5), 3.5, Color(0.8, 0.8, 0.83))
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(sx + 20, sy + 11),
				"[G] x" + str(player.smoke_grenades), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(0.85, 0.85, 0.9))
		if "flash_grenades" in player and player.flash_grenades > 0:
			var fx2 = 80
			var fy2 = 73
			# Flash icon — белая вспышка с лучами
			draw_node.draw_circle(Vector2(fx2 + 8, fy2 + 7), 4, Color(1, 1, 0.85))
			for i in 6:
				var ang = float(i) / 6.0 * TAU
				var p1 = Vector2(fx2 + 8 + cos(ang) * 5, fy2 + 7 + sin(ang) * 5)
				var p2 = Vector2(fx2 + 8 + cos(ang) * 8, fy2 + 7 + sin(ang) * 8)
				draw_node.draw_line(p1, p2, Color(1, 1, 0.6), 1.0)
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(fx2 + 20, fy2 + 11),
				"[V] x" + str(player.flash_grenades), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(1, 1, 0.6))

		# === Активная СИНЕРГИЯ оружия+карты ===
		if "current_weapon" in player and "active_card" in player:
			var Syn = load("res://scripts/synergies.gd")
			var syn = Syn.find_active(player.current_weapon, player.active_card)
			if syn:
				var sy = 100
				var sx = 5
				draw_node.draw_rect(Rect2(sx, sy, 220, 14),
					Color(syn.color.r * 0.4, syn.color.g * 0.4, syn.color.b * 0.4, 0.8))
				draw_node.draw_rect(Rect2(sx, sy, 220, 14),
					syn.color, false, 1.5)
				var s_text = "★ " + syn.name
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(sx + 6, sy + 10),
					s_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(1, 1, 1))

		# Killstreak счётчик (мини-индикатор)
		if "killstreak" in player and player.killstreak >= 2:
			var kx = 5
			var ky = 90
			var ks_text = "KILLSTREAK ×" + str(player.killstreak)
			# Чёрная обводка
			for ox in [-1, 0, 1]:
				for oy in [-1, 0, 1]:
					if ox == 0 and oy == 0: continue
					draw_node.draw_string(ThemeDB.fallback_font, Vector2(kx + ox, ky + oy),
						ks_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0))
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(kx, ky),
				ks_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.85, 0.10))

		# Amulet indicator
		if player.has_amulet:
			draw_node.draw_circle(Vector2(210, 53), 4, Color(0.9, 0.7, 0.2, 0.7))
			draw_node.draw_circle(Vector2(210, 53), 2, Color(1, 0.9, 0.4, 0.9))

		# === ITEM HOTBAR (bottom-left): Scrolls + Card  [9]=use  [Tab]=cycle ===
		var has_items = player.scrolls.size() > 0 or player.active_card != ""
		if has_items:
			var scroll_names = {"dash": "Рывок", "kick": "Удар", "speed_boost": "Скор.", "choke": "Удуш.", "slide": "Подкат"}
			var card_short = {"invisibility": "Невид.", "death_jar": "Банка", "throw_weapon": "Бросок",
				"speed_boots": "Ботинки", "dodge": "Уворот", "backstab": "Удар_сзади",
				"acid_water": "Кислота", "thorn_armor": "Броня", "close_combat": "Ближний",
				"berserker": "Берсерк", "hunter": "Охотник", "critical": "Крит", "second_chance": "Воскр."}
			var card_colors_map = {"invisibility": Color(0.3, 0.8, 1.0), "death_jar": Color(0.2, 0.9, 0.1),
				"throw_weapon": Color(1.0, 0.6, 0.2), "speed_boots": Color(1.0, 1.0, 0.3),
				"dodge": Color(0.8, 0.4, 1.0), "backstab": Color(0.6, 0.1, 0.1),
				"acid_water": Color(0.1, 0.9, 0.5), "thorn_armor": Color(0.5, 0.5, 0.6),
				"close_combat": Color(0.9, 0.3, 0.1), "berserker": Color(0.8, 0.1, 0.2),
				"hunter": Color(0.4, 0.7, 0.2), "critical": Color(1.0, 0.5, 0.0),
				"second_chance": Color(1.0, 1.0, 1.0)}
			var items = []
			for si in player.scrolls.size():
				var sid = player.scrolls[si]
				items.append({"label": scroll_names.get(sid, sid),
					"cd": player.scroll_cooldowns.get(sid, 0.0),
					"color": Color(0.9, 0.8, 0.3), "is_card": false})
			if player.active_card != "":
				var is_active_type = player.active_card in ["death_jar", "throw_weapon"]
				items.append({"label": card_short.get(player.active_card, player.active_card),
					"cd": player.throw_weapon_cooldown if player.active_card == "throw_weapon" else 0.0,
					"color": card_colors_map.get(player.active_card, Color(0.7, 0.7, 1.0)),
					"is_card": true, "passive": not is_active_type})
			var slot_w = 62.0
			var bar_x = 5.0
			var bar_y = screen_size.y - 30.0
			var total_w = items.size() * slot_w + 4
			draw_node.draw_rect(Rect2(bar_x - 2, bar_y - 12, total_w + 4, 38), Color(0, 0, 0, 0.5))
			var active_slot = player.active_item_slot if player.active_item_slot < items.size() else 0
			for i in items.size():
				var item = items[i]
				var sx = bar_x + i * slot_w
				var is_sel = i == active_slot
				var bg_col = Color(0.15, 0.15, 0.15, 0.7) if not is_sel else Color(0.3, 0.25, 0.05, 0.85)
				draw_node.draw_rect(Rect2(sx, bar_y, slot_w - 2, 22), bg_col)
				if is_sel:
					draw_node.draw_rect(Rect2(sx, bar_y, slot_w - 2, 22), Color(1, 0.9, 0.3, 0.9), false, 1.5)
				if item.cd > 0:
					var cd_frac = clampf(item.cd / 20.0, 0.0, 1.0)
					draw_node.draw_rect(Rect2(sx, bar_y, (slot_w - 2) * cd_frac, 22), Color(0, 0, 0, 0.5))
				var label_col = item.color if item.cd <= 0 else Color(0.5, 0.5, 0.5)
				if item.get("passive", false):
					label_col = Color(label_col.r, label_col.g, label_col.b, 0.6)
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(sx + 3, bar_y + 13),
					item.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, label_col)
				if item.cd > 0:
					draw_node.draw_string(ThemeDB.fallback_font, Vector2(sx + slot_w - 20, bar_y + 13),
						"%.0f" % item.cd, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.4, 0.4))
				if item.is_card:
					var ic = item.color if item.cd <= 0 else Color(0.4, 0.4, 0.4)
					draw_node.draw_colored_polygon(PackedVector2Array([
						Vector2(sx + slot_w - 8, bar_y + 5), Vector2(sx + slot_w - 4, bar_y + 11),
						Vector2(sx + slot_w - 8, bar_y + 17), Vector2(sx + slot_w - 12, bar_y + 11)]), ic)
				else:
					draw_node.draw_rect(Rect2(sx + slot_w - 12, bar_y + 7, 8, 8), Color(0.8, 0.7, 0.4, 0.6))
					draw_node.draw_rect(Rect2(sx + slot_w - 12, bar_y + 7, 8, 8), Color(0.9, 0.8, 0.5, 0.4), false, 1.0)
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(bar_x, bar_y - 8),
				"[9] использовать  [Tab] след.", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 0.6, 0.6, 0.7))

		# === FOURTH ROW: Pickaxe / Ore / Lockpick ===
		if player.has_pickaxe or _has_ore_level():
			draw_node.draw_rect(Rect2(5, 63, 250, 16), Color(0, 0, 0, 0.35))
			var row_y = 75

			if player.has_pickaxe:
				var weapon_text = "[2] Pickaxe" if player.using_pickaxe else "[1] Sword"
				var weapon_col = Color(0.8, 0.6, 0.3, 0.9) if player.using_pickaxe else Color(0.7, 0.7, 0.8, 0.7)
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(10, row_y),
					weapon_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, weapon_col)

			# Старая полоска "Ore" убрана — теперь железо отображается на миникарте

			# Lockpick indicator
			if player.has_lockpick:
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(160, row_y),
					"LOCKPICK", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.8, 0.3, 0.9))

		# === FIFTH ROW: Resources (iron, gold, pearl, ingots) ===
		var has_resources = player.iron_ore > 0 or player.gold_ore > 0 or player.iron_ingot > 0 or player.gold_ingot > 0 or player.has_pearl
		if has_resources:
			draw_node.draw_rect(Rect2(5, 81, 300, 16), Color(0, 0, 0, 0.35))
			var rx = 10
			var ry = 93
			if player.iron_ore > 0:
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(rx, ry),
					"Fe:" + str(player.iron_ore), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.65, 0.55, 0.8))
				rx += 35
			if player.iron_ingot > 0:
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(rx, ry),
					"Fe bar:" + str(player.iron_ingot), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.75, 0.6, 0.9))
				rx += 50
			if player.gold_ore > 0:
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(rx, ry),
					"Au:" + str(player.gold_ore), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.85, 0.2, 0.8))
				rx += 35
			if player.gold_ingot > 0:
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(rx, ry),
					"Au bar:" + str(player.gold_ingot), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 0.3, 0.9))
				rx += 50
			if player.has_pearl:
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(rx, ry),
					"Pearl", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.9, 1.0, 0.9))

	# === TOP-RIGHT: Challenge/Boss info ===
	var cur_room = _get_room()
	if cur_room and cur_room.is_boss_room and cur_room.golem_boss and is_instance_valid(cur_room.golem_boss):
		var golem = cur_room.golem_boss
		var boss_cx = screen_size.x / 2
		# Boss HP bar (centered at top)
		var boss_bar_w = 200.0
		draw_node.draw_rect(Rect2(boss_cx - boss_bar_w / 2 - 2, 5, boss_bar_w + 4, 18), Color(0, 0, 0, 0.6))
		var boss_hp_frac = float(golem.health) / golem.max_health
		var boss_hp_col = Color(0.9, 0.3, 0.1) if boss_hp_frac < 0.5 else Color(0.8, 0.5, 0.1)
		draw_node.draw_rect(Rect2(boss_cx - boss_bar_w / 2, 7, boss_bar_w * boss_hp_frac, 14), boss_hp_col)
		draw_node.draw_rect(Rect2(boss_cx - boss_bar_w / 2, 7, boss_bar_w, 14), Color(0.5, 0.5, 0.5, 0.4), false, 1.0)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(boss_cx - 20, 19),
			"GOLEM", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 0.8, 0.3))
		# Phase text
		var phase_text = ""
		match golem.phase:
			0: phase_text = "ROAR!"
			1: phase_text = "ROCKS!"
			2: phase_text = "TIRED (" + str(2 - golem.hits_in_tired) + " hits left)"
			3: phase_text = "ANGRY ROCKS!"
			4: phase_text = "TIRED (" + str(2 - golem.hits_in_tired) + " hits left)"
			5: phase_text = "DEFEATED"
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(boss_cx - 30, 34),
			phase_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 1, 0.5, 0.8))
	elif cur_room:
		var challenge_text = ""
		var challenge_color = Color(0.8, 0.8, 0.8, 0.6)
		match cur_room.challenge_type:
			"lockpick":
				challenge_text = "Door: Lockpick"
				challenge_color = Color(0.9, 0.8, 0.3, 0.6)
			"guardians":
				if cur_room.challenge_complete_flag:
					challenge_text = "Guardians: DEFEATED"
					challenge_color = Color(0.3, 0.9, 0.3, 0.8)
				elif cur_room.challenge_started:
					challenge_text = "Guardians: " + str(cur_room.door_guardians.size()) + " left"
					challenge_color = Color(1, 0.4, 0.3, 0.8)
				else:
					challenge_text = "Door: Guardians"
					challenge_color = Color(0.9, 0.5, 0.2, 0.6)
			"crystal":
				if cur_room.challenge_complete_flag:
					challenge_text = "Crystal: DEFENDED"
					challenge_color = Color(0.3, 0.9, 0.3, 0.8)
				elif cur_room.challenge_started and cur_room.crystal_node and not cur_room.crystal_node.is_destroyed:
					challenge_text = "Crystal: " + str(cur_room.crystal_attackers.size()) + " attackers | HP: " + str(cur_room.crystal_node.health)
					challenge_color = Color(0.4, 0.85, 1.0, 0.8)
				elif cur_room.challenge_started and cur_room.crystal_node and cur_room.crystal_node.is_destroyed:
					challenge_text = "Crystal: DESTROYED (retry)"
					challenge_color = Color(1, 0.2, 0.2, 0.8)
				else:
					challenge_text = "Door: Mine ore -> Place Crystal"
					challenge_color = Color(0.4, 0.85, 1.0, 0.6)

		if current_level >= 5:
			challenge_text += "  [2x DMG!]"

		var cx = screen_size.x - 230
		draw_node.draw_rect(Rect2(cx - 5, 3, 235, 16), Color(0, 0, 0, 0.4))
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx, 15),
			challenge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, challenge_color)

		# Trial info
		if cur_room.trial_active:
			var trial_text = "TRIAL: " + str(cur_room.trial_enemies.size()) + " enemies left"
			draw_node.draw_rect(Rect2(cx - 5, 21, 235, 16), Color(0, 0, 0, 0.4))
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx, 33),
				trial_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.3, 0.3, 0.9))
		elif cur_room.trial_complete:
			draw_node.draw_rect(Rect2(cx - 5, 21, 235, 16), Color(0, 0, 0, 0.4))
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx, 33),
				"TRIAL COMPLETE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 1, 0.3, 0.8))

	# Controls hint (bottom)
	var hint_y = screen_size.y - 12
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(10, hint_y),
		"LMB:Attack  Shift:Roll  Space:Jump  H:Heal  F:Flask  1:Sword 2:Pick  E:Interact", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.5, 0.7))

	# === CRAFTING ANIMATION ===
	if is_crafting:
		var progress = 1.0 - (craft_timer / craft_duration)
		var cx = screen_size.x / 2
		var cy = screen_size.y / 2 - 30

		# Dark overlay
		draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.55))

		# "CRAFTING" title at top
		var title_col = Color(1, 0.85, 0.3, 0.9 + sin(Time.get_ticks_msec() * 0.006) * 0.1)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 40, 40),
			"CRAFTING", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, title_col)

		# Item name below
		var item_name = "Lockpick" if craft_item == "lockpick" else "Crystal"
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 30, 62),
			item_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.8, 0.8, 0.8, 0.8))

		# Anvil base
		draw_node.draw_rect(Rect2(cx - 20, cy + 15, 40, 6), Color(0.35, 0.35, 0.38))
		draw_node.draw_rect(Rect2(cx - 14, cy + 21, 28, 10), Color(0.3, 0.3, 0.33))
		draw_node.draw_rect(Rect2(cx - 8, cy + 31, 16, 6), Color(0.28, 0.28, 0.3))

		# Hammer animation (swinging down)
		var hammer_angle = sin(progress * TAU * 4) * 0.8
		var hammer_base = Vector2(cx + 25, cy - 10)
		var hammer_end = hammer_base + Vector2(cos(-1.2 + hammer_angle) * 22, sin(-1.2 + hammer_angle) * 22)
		draw_node.draw_line(hammer_base, hammer_end, Color(0.5, 0.35, 0.15), 3.0)
		# Hammer head
		var h_dir = (hammer_end - hammer_base).normalized()
		var h_perp = Vector2(-h_dir.y, h_dir.x)
		draw_node.draw_line(hammer_end - h_perp * 6, hammer_end + h_perp * 6, Color(0.5, 0.5, 0.55), 4.0)

		# Sparks on hit (when hammer is near bottom)
		if sin(progress * TAU * 4) < -0.3:
			for i in 4:
				var spark_x = cx + randf_range(-15, 15)
				var spark_y = cy + randf_range(5, 15)
				draw_node.draw_circle(Vector2(spark_x, spark_y), randf_range(1, 2.5), Color(1, 0.7 + randf() * 0.3, 0.2, 0.8))

		# Ore pieces around anvil (shrinking as progress goes)
		var ore_count = int((1.0 - progress) * 6)
		for i in ore_count:
			var ox = cx - 35 + i * 12
			var oy = cy + 20
			draw_node.draw_rect(Rect2(ox, oy, 6, 6), Color(0.55, 0.45, 0.3, 0.7))
			draw_node.draw_rect(Rect2(ox + 1, oy + 1, 2, 2), Color(0.8, 0.7, 0.5, 0.5))

		# Crafted item appearing (fades in during last 30%)
		if progress > 0.7:
			var item_alpha = (progress - 0.7) / 0.3
			if craft_item == "lockpick":
				# Lockpick shape
				var lx = cx
				var ly = cy + 8
				draw_node.draw_line(Vector2(lx - 8, ly), Vector2(lx + 5, ly), Color(0.8, 0.7, 0.4, item_alpha), 2.5)
				draw_node.draw_line(Vector2(lx + 5, ly), Vector2(lx + 5, ly + 4), Color(0.8, 0.7, 0.4, item_alpha), 2.0)
				draw_node.draw_line(Vector2(lx + 2, ly), Vector2(lx + 2, ly + 3), Color(0.8, 0.7, 0.4, item_alpha), 1.5)
				# Glow
				draw_node.draw_circle(Vector2(lx, ly), 10, Color(1, 0.9, 0.4, item_alpha * 0.25))
			else:
				# Crystal shape
				var lx = cx
				var ly = cy + 5
				var pts = PackedVector2Array([
					Vector2(lx, ly - 10), Vector2(lx + 7, ly - 3),
					Vector2(lx + 5, ly + 6), Vector2(lx - 5, ly + 6),
					Vector2(lx - 7, ly - 3)
				])
				draw_node.draw_colored_polygon(pts, Color(0.3, 0.8, 1.0, item_alpha * 0.8))
				draw_node.draw_circle(Vector2(lx, ly), 12, Color(0.4, 0.9, 1.0, item_alpha * 0.2))

		# Progress bar
		var craft_bw = 120
		var craft_bx = cx - craft_bw / 2
		var craft_by = cy + 50
		draw_node.draw_rect(Rect2(craft_bx, craft_by, craft_bw, 8), Color(0.2, 0.2, 0.2, 0.8))
		draw_node.draw_rect(Rect2(craft_bx + 1, craft_by + 1, (craft_bw - 2) * progress, 6), Color(1, 0.75, 0.2, 0.9))

	# === CRAFTING MENU ===
	if craft_menu_open:
		_draw_craft_menu(screen_size)

	# === SHOP MENU ===
	if shop_menu_open:
		_draw_shop_menu(screen_size)

	# === RELIC CHOICE ===
	if relic_menu_open:
		_draw_relic_choice(screen_size)

	# Controls tutorial overlay
	if show_controls:
		_draw_controls(screen_size)

	# Message
	if message_text != "":
		var msg_alpha = min(message_timer, 1.0)
		draw_node.draw_string(ThemeDB.fallback_font,
			Vector2(320 - message_text.length() * 3, 60),
			message_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14,
			Color(1, 1, 0.5, msg_alpha))

	# Story text (time loop lore)
	_draw_story_text(screen_size)

	# Final choice screen
	_draw_final_choice(screen_size)

	# Card selection screen
	if card_selection_visible:
		_draw_card_selection(screen_size)

	# Debug weapon menu
	if weapon_menu_visible:
		_draw_weapon_menu(screen_size)

	# Weapon mutations display (colored dots near HP bar)
	var p2 = _get_player()
	if p2 and "weapon_mutations" in p2 and p2.weapon_mutations.size() > 0:
		var muts = p2.weapon_mutations
		var mut_colors = {"poison": Color(0.2,0.9,0.1), "fire": Color(1,0.4,0.1),
			"lifesteal": Color(0.9,0.1,0.3), "explosive": Color(1,0.8,0.1), "chain": Color(0.3,0.6,1.0)}
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(5, 100), "МУТ:", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.8,0.8,0.8,0.7))
		for mi in muts.size():
			var mc = mut_colors.get(muts[mi], Color.WHITE)
			draw_node.draw_circle(Vector2(32 + mi * 14, 95), 5, mc)
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(28 + mi * 14, 99), muts[mi][0].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)

	# Coins + XP bar + minimap (always visible)
	_draw_coins_xp(screen_size)
	_draw_minimap(screen_size)

	# Kill combo (temporary, center screen)
	if combo_display_timer > 0:
		_draw_combo(screen_size)

	# Room name flash
	if room_name_timer > 0:
		_draw_room_name(screen_size)

	# Boss bonus screen
	if boss_bonus_visible and boss_bonus_options.size() > 0:
		_draw_boss_bonus(screen_size)

	# Level-up screen
	if level_up_visible and level_up_choices.size() > 0:
		_draw_level_up(screen_size)

	# Pause menu
	if pause_visible:
		_draw_pause_menu(screen_size)

	# Settings screen (drawn on top of pause)
	if settings_visible:
		_draw_settings_screen(screen_size)

func _draw_card_selection(screen_size: Vector2):
	# Dark overlay
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.7))

	# Title
	var title = "ВЫБЕРИ КАРТУ"
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(screen_size.x / 2 - 60, 60),
		title, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1, 0.9, 0.4))

	# Draw 3 cards
	var card_w = 120.0
	var card_h = 160.0
	var gap = 20.0
	var total_w = card_options.size() * card_w + (card_options.size() - 1) * gap
	var start_x = (screen_size.x - total_w) / 2
	var card_y = (screen_size.y - card_h) / 2

	for i in card_options.size():
		var card = card_options[i]
		var cx = start_x + i * (card_w + gap)
		var selected = (i == card_selected)

		# Card background
		var bg_col = Color(0.15, 0.15, 0.2, 0.9) if not selected else Color(0.2, 0.2, 0.35, 0.95)
		draw_node.draw_rect(Rect2(cx, card_y, card_w, card_h), bg_col)

		# Border (highlighted if selected)
		var border_col = card.color if selected else Color(0.4, 0.4, 0.4, 0.5)
		var border_w = 3.0 if selected else 1.0
		draw_node.draw_rect(Rect2(cx, card_y, card_w, card_h), border_col, false, border_w)

		# Selected glow
		if selected:
			draw_node.draw_rect(Rect2(cx - 2, card_y - 2, card_w + 4, card_h + 4),
				Color(card.color.r, card.color.g, card.color.b, 0.15))

		# Card icon (colored circle)
		var icon_cx = cx + card_w / 2
		var icon_cy = card_y + 35
		draw_node.draw_circle(Vector2(icon_cx, icon_cy), 18, Color(card.color.r, card.color.g, card.color.b, 0.3))
		draw_node.draw_circle(Vector2(icon_cx, icon_cy), 12, card.color)
		draw_node.draw_arc(Vector2(icon_cx, icon_cy), 18, 0, TAU, 24, card.color, 2.0)

		# Card name
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx + 5, card_y + 70),
			card.name, HORIZONTAL_ALIGNMENT_LEFT, card_w - 10, 10, Color.WHITE)

		# Description (multi-line)
		var lines = card.desc.split("\n")
		for li in lines.size():
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx + 5, card_y + 88 + li * 14),
				lines[li], HORIZONTAL_ALIGNMENT_LEFT, card_w - 10, 8,
				Color(0.7, 0.7, 0.7))

		# Selected indicator
		if selected:
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx + card_w / 2 - 10, card_y + card_h - 8),
				"▼ ENTER ▼", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, card.color)

	# Instructions
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(screen_size.x / 2 - 80, card_y + card_h + 30),
		"← A/D для выбора, ENTER →", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.6, 0.6, 0.6))

func _draw_weapon_menu(screen_size: Vector2):
	# Dark overlay
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.75))

	var p = _get_player()
	if not p:
		return

	var title = "ВЫБЕРИ ОРУЖИЕ (W/S + Enter, Esc = отмена)"
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(screen_size.x / 2 - 120, 30),
		title, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1, 0.9, 0.4))

	var menu_w = 300.0
	var item_h = 22.0
	var menu_x = (screen_size.x - menu_w) / 2
	var menu_y = 45.0
	var visible_items = 16
	# Scroll offset so selected item is visible
	var scroll = max(0, weapon_menu_selected - visible_items + 3)

	for i in range(scroll, mini(23, scroll + visible_items)):
		var wd = p.weapon_data.get(i, null)
		if not wd:
			continue
		var y = menu_y + (i - scroll) * item_h
		var selected = (i == weapon_menu_selected)

		# Background
		var bg = Color(0.2, 0.2, 0.3, 0.8) if selected else Color(0.1, 0.1, 0.15, 0.5)
		draw_node.draw_rect(Rect2(menu_x, y, menu_w, item_h - 2), bg)

		# Selection border
		if selected:
			draw_node.draw_rect(Rect2(menu_x, y, menu_w, item_h - 2), wd.color, false, 2.0)

		# Weapon color dot
		draw_node.draw_circle(Vector2(menu_x + 10, y + item_h / 2 - 1), 4, wd.color)

		# Rarity color
		var rarity_col: Color
		match wd.rarity:
			"common": rarity_col = Color(0.7, 0.7, 0.7)
			"uncommon": rarity_col = Color(0.3, 0.9, 0.3)
			"rare": rarity_col = Color(0.3, 0.5, 1.0)
			"legendary": rarity_col = Color(1.0, 0.8, 0.1)
			_: rarity_col = Color.WHITE

		# Name
		var name_col = Color.WHITE if selected else Color(0.7, 0.7, 0.7)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(menu_x + 22, y + 14),
			str(i) + ". " + wd.name, HORIZONTAL_ALIGNMENT_LEFT, 150, 9, name_col)

		# Stats
		var stats = "DMG:" + str(wd.damage) + " SPD:" + str(snapped(1.0 / wd.cooldown, 0.1))
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(menu_x + 175, y + 14),
			stats, HORIZONTAL_ALIGNMENT_LEFT, 80, 8, Color(0.6, 0.6, 0.6))

		# Rarity tag
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(menu_x + 260, y + 14),
			wd.rarity, HORIZONTAL_ALIGNMENT_LEFT, 40, 7, rarity_col)

	# Selected weapon details at bottom
	var sel_wd = p.weapon_data.get(weapon_menu_selected, null)
	if sel_wd:
		var detail_y = menu_y + visible_items * item_h + 5
		var special = sel_wd.get("special", "")
		var desc = sel_wd.name + "  |  Урон: " + str(sel_wd.damage) + "  Скорость: x" + str(sel_wd.speed_mult)
		if special != "":
			desc += "  Спец: " + special
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(menu_x, detail_y),
			desc, HORIZONTAL_ALIGNMENT_LEFT, menu_w, 9, sel_wd.color)

func _draw_controls(screen_size: Vector2):
	# Semi-transparent overlay
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.35))

	var cx = screen_size.x / 2
	var cy = screen_size.y / 2
	var box_w = 320.0
	var box_h = 290.0
	var bx = cx - box_w / 2
	var by = cy - box_h / 2

	# Panel background
	draw_node.draw_rect(Rect2(bx, by, box_w, box_h), Color(0.08, 0.08, 0.12, 0.95))
	draw_node.draw_rect(Rect2(bx + 1, by + 1, box_w - 2, box_h - 2), Color(0.4, 0.35, 0.2, 0.4), false, 2.0)

	var font = ThemeDB.fallback_font
	var y = by + 28
	var col_key = Color(1, 0.85, 0.4)
	var col_txt = Color(0.85, 0.85, 0.9)
	var col_title = Color(1, 0.7, 0.2)
	var sz = 11
	var gap = 22

	draw_node.draw_string(font, Vector2(cx - 50, y), "CONTROLS", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, col_title)
	y += gap + 8

	var controls = [
		["WASD", "Move"],
		["Space", "Jump / Wall Jump"],
		["LMB", "Attack"],
		["S + LMB", "Attack Down"],
		["W + LMB", "Attack Up"],
		["RMB", "Shield"],
		["Shift", "Dodge Roll"],
		["S", "Drop Through Platform"],
		["W", "Climb Ladder"],
		["E", "Interact with Door"],
		["H", "Heal"],
	]

	for c in controls:
		draw_node.draw_string(font, Vector2(bx + 15, y), c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col_key)
		draw_node.draw_string(font, Vector2(bx + 110, y), c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col_txt)
		y += gap

	y += 6
	var pulse = sin(Time.get_ticks_msec() * 0.004) * 0.3 + 0.7
	draw_node.draw_string(font, Vector2(cx - 60, y), "[Enter] Continue", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1, 1, 0.6, pulse))

func _shop_navigate(dir: int):
	if shop_items.is_empty():
		return
	var tries = shop_items.size()
	var idx = shop_selected
	while tries > 0:
		idx = (idx + dir + shop_items.size()) % shop_items.size()
		if not shop_items[idx].get("bought", false):
			shop_selected = idx
			return
		tries -= 1
	# Все куплены — оставляем текущий выбор

func _draw_shop_menu(screen_size: Vector2):
	# Стиль повторяет _draw_craft_menu для целостности UI
	var menu_w = 320.0
	var menu_h = 60.0 + max(1, shop_items.size()) * 42.0 + 16.0
	var mx = screen_size.x / 2 - menu_w / 2
	var my = screen_size.y / 2 - menu_h / 2

	# Затемнение фона
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.6))

	# Внешняя золотая рамка + тёмный фон
	draw_node.draw_rect(Rect2(mx - 2, my - 2, menu_w + 4, menu_h + 4), Color(0.45, 0.32, 0.08, 0.95))
	draw_node.draw_rect(Rect2(mx, my, menu_w, menu_h), Color(0.10, 0.08, 0.06, 0.97))

	# Title bar
	var title_col = Color(1.0, 0.85, 0.20)
	draw_node.draw_rect(Rect2(mx, my, menu_w, 26), Color(0.22, 0.18, 0.10, 0.95))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + menu_w / 2 - 22, my + 18),
		"ЛАВКА", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, title_col)

	# Иконка мешка с монетами слева
	draw_node.draw_circle(Vector2(mx + 14, my + 13), 7, Color(0.85, 0.65, 0.15))
	draw_node.draw_circle(Vector2(mx + 14, my + 13), 5, Color(1.0, 0.85, 0.20))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 11, my + 17),
		"$", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.2, 0.15, 0.05))

	# Текущий баланс справа в шапке
	var player = _get_player()
	if player and "coins" in player:
		var coin_text = "Монет: %d" % player.coins
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + menu_w - 90, my + 18),
			coin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.20))
		# Маленькая монетка перед текстом
		draw_node.draw_circle(Vector2(mx + menu_w - 96, my + 14), 3, Color(1.0, 0.85, 0.20))

	# Recipes / items
	var rarity_colors: Dictionary = {
		"common":     Color(0.78, 0.78, 0.82),
		"uncommon":   Color(0.32, 0.55, 0.95),
		"rare":       Color(0.55, 0.30, 0.95),
		"epic":       Color(0.92, 0.30, 0.85),
		"legendary":  Color(1.00, 0.20, 0.15),
		"contraband": Color(1.00, 0.85, 0.15),
	}

	var ry = my + 34
	for i in shop_items.size():
		var item = shop_items[i]
		var is_selected = (i == shop_selected)
		var is_bought = item.get("bought", false)
		var price = item.get("price", 0)
		var can_buy = (not is_bought) and (player == null or player.coins >= price)

		# Selection highlight
		if is_selected and not is_bought:
			draw_node.draw_rect(Rect2(mx + 4, ry, menu_w - 8, 38), Color(0.30, 0.22, 0.08, 0.85))
			draw_node.draw_rect(Rect2(mx + 4, ry, 3, 38), title_col)

		# Number
		var num_col = title_col if not is_bought else Color(0.4, 0.4, 0.4, 0.5)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 12, ry + 16),
			"[" + str(i + 1) + "]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, num_col)

		# Rarity dot (для оружий)
		var x_after_num = mx + 38
		if item.get("type", "") == "weapon":
			var rar = item.get("rarity", "common")
			var dot_col = rarity_colors.get(rar, Color(0.8, 0.8, 0.8))
			if is_bought:
				dot_col.a = 0.3
			draw_node.draw_circle(Vector2(x_after_num + 4, ry + 16), 4, dot_col)
			x_after_num += 14

		# Name
		var name_col = Color(1, 0.95, 0.8)
		if is_bought:
			name_col = Color(0.45, 0.45, 0.45, 0.5)
		elif not can_buy:
			name_col = Color(0.85, 0.55, 0.55, 0.85)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(x_after_num, ry + 16),
			item.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, name_col)

		# Описание под названием (для selected)
		if is_selected and not is_bought:
			var desc = item.get("desc", "")
			if desc != "":
				draw_node.draw_string(ThemeDB.fallback_font, Vector2(x_after_num, ry + 30),
					desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.65, 0.78, 0.55, 0.85))

		# Price (правый край)
		if is_bought:
			# Зачёркнутая
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + menu_w - 65, ry + 16),
				"ПРОДАНО", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.5, 0.5, 0.5))
		else:
			var price_x = mx + menu_w - 50
			# Монетка
			draw_node.draw_circle(Vector2(price_x - 6, ry + 13), 4, Color(1.0, 0.85, 0.20))
			var price_col = Color(1.0, 0.85, 0.20) if can_buy else Color(0.8, 0.3, 0.2, 0.85)
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(price_x + 2, ry + 17),
				str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, price_col)

		# Separator
		draw_node.draw_line(Vector2(mx + 8, ry + 38), Vector2(mx + menu_w - 8, ry + 38),
			Color(0.30, 0.22, 0.10, 0.5), 1.0)

		ry += 42

	# Footer hint
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 10, my + menu_h - 8),
		"W/S — выбор   Enter — купить   E/Esc — выйти",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.55, 0.45, 0.75))

func _draw_craft_menu(screen_size: Vector2):
	var player = _get_player()
	var recipes = _get_recipes(craft_menu_station, player)

	# Menu dimensions
	var menu_w = 280.0
	var menu_h = 60.0 + recipes.size() * 40.0
	var mx = screen_size.x / 2 - menu_w / 2
	var my = screen_size.y / 2 - menu_h / 2

	# Dark overlay
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.6))

	# Menu background
	draw_node.draw_rect(Rect2(mx - 2, my - 2, menu_w + 4, menu_h + 4), Color(0.4, 0.35, 0.25, 0.9))
	draw_node.draw_rect(Rect2(mx, my, menu_w, menu_h), Color(0.12, 0.1, 0.08, 0.95))

	# Title bar
	var title_col = Color(0.9, 0.5, 0.1)
	var title_text = ""
	match craft_menu_station:
		"furnace":
			title_text = "FURNACE"
			title_col = Color(1, 0.5, 0.15)
		"anvil":
			title_text = "ANVIL"
			title_col = Color(0.7, 0.7, 0.8)
		"grate":
			title_text = "GRATE"
			title_col = Color(0.3, 0.7, 0.9)

	draw_node.draw_rect(Rect2(mx, my, menu_w, 24), Color(0.2, 0.18, 0.14, 0.9))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + menu_w / 2 - 25, my + 17),
		title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, title_col)

	# Station icon
	match craft_menu_station:
		"furnace":
			# Fire icon
			draw_node.draw_rect(Rect2(mx + 8, my + 5, 10, 14), Color(0.15, 0.08, 0.05))
			var t = Time.get_ticks_msec() * 0.005
			draw_node.draw_rect(Rect2(mx + 10, my + 9, 6, 8), Color(1, 0.5, 0.1, 0.5 + sin(t) * 0.2))
			draw_node.draw_rect(Rect2(mx + 11, my + 7, 4, 5), Color(1, 0.8, 0.2, 0.4 + sin(t * 1.5) * 0.2))
		"anvil":
			# Anvil icon
			draw_node.draw_rect(Rect2(mx + 8, my + 12, 14, 4), Color(0.48, 0.48, 0.52))
			draw_node.draw_rect(Rect2(mx + 10, my + 8, 10, 5), Color(0.42, 0.42, 0.46))
			draw_node.draw_rect(Rect2(mx + 12, my + 16, 6, 3), Color(0.35, 0.35, 0.38))
		"grate":
			# Grate bars
			for i in 4:
				draw_node.draw_rect(Rect2(mx + 8 + i * 4, my + 6, 2, 12), Color(0.5, 0.5, 0.55))
			draw_node.draw_rect(Rect2(mx + 7, my + 14, 16, 4), Color(0.2, 0.5, 0.7, 0.4))

	# Recipes
	var ry = my + 32
	for i in recipes.size():
		var recipe = recipes[i]
		var is_selected = i == craft_menu_selected
		var can = recipe.can_craft

		# Selection highlight
		if is_selected:
			draw_node.draw_rect(Rect2(mx + 4, ry, menu_w - 8, 36), Color(0.3, 0.25, 0.15, 0.7))
			draw_node.draw_rect(Rect2(mx + 4, ry, 3, 36), title_col)

		# Recipe number
		var num_col = title_col if can else Color(0.4, 0.4, 0.4, 0.5)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 12, ry + 14),
			"[" + str(i + 1) + "]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, num_col)

		# Recipe name
		var name_col = Color(1, 0.95, 0.8) if can else Color(0.5, 0.5, 0.5, 0.6)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 38, ry + 14),
			recipe.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, name_col)

		# Ingredients
		var ing_col = Color(0.7, 0.65, 0.5, 0.8) if can else Color(0.4, 0.4, 0.4, 0.5)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 38, ry + 28),
			recipe.ingredients, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ing_col)

		# Result description (right side)
		if is_selected:
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 160, ry + 28),
				recipe.result_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 0.8, 0.6, 0.7))

		# Can't craft indicator
		if not can:
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + menu_w - 55, ry + 14),
				"NO MAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.3, 0.2, 0.6))

		# Separator line
		draw_node.draw_line(Vector2(mx + 8, ry + 36), Vector2(mx + menu_w - 8, ry + 36),
			Color(0.3, 0.25, 0.2, 0.4), 1.0)

		ry += 40

	# Footer
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 10, my + menu_h - 8),
		"W/S:Select  Enter:Craft  E/Esc:Close", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.5, 0.6))

	# Player inventory summary (bottom of menu)
	if player:
		var inv_y = my + menu_h - 22
		var inv_x = mx + 10
		draw_node.draw_rect(Rect2(mx + 4, inv_y - 4, menu_w - 8, 14), Color(0.15, 0.12, 0.1, 0.8))
		var inv_parts = []
		if player.iron_ore > 0: inv_parts.append("Fe:" + str(player.iron_ore))
		if player.iron_ingot > 0: inv_parts.append("FeBar:" + str(player.iron_ingot))
		if player.gold_ore > 0: inv_parts.append("Au:" + str(player.gold_ore))
		if player.gold_ingot > 0: inv_parts.append("AuBar:" + str(player.gold_ingot))
		if player.has_pearl: inv_parts.append("Pearl")
		if player.has_pickaxe: inv_parts.append("Pickaxe")
		if player.has_blade: inv_parts.append("Blade")
		var inv_text = " | ".join(inv_parts) if inv_parts.size() > 0 else "No materials"
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(inv_x, inv_y + 6),
			inv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 0.6, 0.5, 0.7))

func _has_ore_level() -> bool:
	var cur_room = _get_room()
	if cur_room:
		return cur_room.challenge_type == "lockpick" or cur_room.challenge_type == "crystal"
	return false

func _get_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _get_room():
	var main = get_parent()
	if main and "current_room" in main:
		return main.current_room
	return null

func _draw_story_text(screen_size: Vector2):
	if story_text == "" or story_alpha <= 0:
		return
	var cx = screen_size.x / 2
	var cy = screen_size.y * 0.75
	# Dark background bar
	var text_len = story_text.length() * 7
	draw_node.draw_rect(Rect2(cx - text_len / 2 - 20, cy - 16, text_len + 40, 32),
		Color(0, 0, 0, 0.7 * story_alpha))
	# Text
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - text_len / 2, cy + 4),
		story_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.8, 0.9, 1.0, story_alpha))

func _draw_final_choice(screen_size: Vector2):
	if not final_choice_visible:
		return
	var cx = screen_size.x / 2
	var cy = screen_size.y / 2

	# Darken background
	draw_node.draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.75))

	# Title
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 100, cy - 70),
		"ПЕТЛЯ ПОДХОДИТ К КОНЦУ", HORIZONTAL_ALIGNMENT_CENTER, -1, 20,
		Color(0.8, 0.6, 1.0))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 80, cy - 45),
		"Что ты выберешь?", HORIZONTAL_ALIGNMENT_CENTER, -1, 14,
		Color(0.7, 0.7, 0.7))

	# Option 1: Escape (left)
	var esc_color = Color(1, 0.3, 0.3) if final_choice_selected == 0 else Color(0.5, 0.3, 0.3)
	var esc_bg = Color(0.3, 0.05, 0.05, 0.8) if final_choice_selected == 0 else Color(0.15, 0.05, 0.05, 0.5)
	draw_node.draw_rect(Rect2(cx - 170, cy - 15, 150, 60), esc_bg)
	draw_node.draw_rect(Rect2(cx - 170, cy - 15, 150, 60), esc_color, false, 2.0)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 155, cy + 10),
		"СБЕЖАТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, esc_color)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 160, cy + 30),
		"Спастись самому", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.6, 0.4, 0.4))

	# Option 2: Save (right)
	var save_color = Color(0.3, 1.0, 0.5) if final_choice_selected == 1 else Color(0.2, 0.5, 0.3)
	var save_bg = Color(0.05, 0.2, 0.05, 0.8) if final_choice_selected == 1 else Color(0.05, 0.1, 0.05, 0.5)
	draw_node.draw_rect(Rect2(cx + 20, cy - 15, 150, 60), save_bg)
	draw_node.draw_rect(Rect2(cx + 20, cy - 15, 150, 60), save_color, false, 2.0)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx + 35, cy + 10),
		"СПАСТИ ВСЕХ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, save_color)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx + 30, cy + 30),
		"Сразиться с собой", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.4, 0.6, 0.4))

	# Controls hint
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 60, cy + 70),
		"[A/D] выбрать  [Enter] подтвердить", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.4, 0.4, 0.4))

func _draw_skull_icon(pos: Vector2, hp_frac: float):
	# Иконка черепа слева от HP-бара. При низком HP глаза горят красным.
	var bone = Color(0.78, 0.74, 0.62)
	var bone_dark = Color(0.45, 0.40, 0.32)
	var px = pos.x
	var py = pos.y
	# Череп: круглая верхняя часть + челюсть
	draw_node.draw_circle(Vector2(px + 9, py + 8), 7.0, bone)
	# Челюсть (трапеция)
	var jaw_pts = PackedVector2Array([
		Vector2(px + 3,  py + 12),
		Vector2(px + 15, py + 12),
		Vector2(px + 13, py + 17),
		Vector2(px + 5,  py + 17),
	])
	draw_node.draw_colored_polygon(jaw_pts, bone)
	# Зубы (тёмные риски на челюсти)
	for ti in 4:
		draw_node.draw_rect(Rect2(px + 5 + ti * 2.5, py + 13, 1.0, 3.0), bone_dark)
	# Глазницы (тёмные)
	var eye_dark = Color(0.05, 0.02, 0.02)
	draw_node.draw_circle(Vector2(px + 6.5, py + 8), 2.0, eye_dark)
	draw_node.draw_circle(Vector2(px + 11.5, py + 8), 2.0, eye_dark)
	# Светящиеся красные точки в глазах — ярче при низком HP
	var glow = clampf(1.0 - hp_frac, 0.0, 1.0)
	var blink = 0.6 + 0.4 * sin(hud_time * 4.0)
	var eye_glow = Color(1.0, 0.15, 0.10, 0.5 + glow * blink * 0.5)
	draw_node.draw_circle(Vector2(px + 6.5, py + 8), 0.9, eye_glow)
	draw_node.draw_circle(Vector2(px + 11.5, py + 8), 0.9, eye_glow)
	# Тёмная трещина на черепе
	draw_node.draw_line(Vector2(px + 9, py + 1), Vector2(px + 7, py + 5),
		bone_dark, 1.0)
	draw_node.draw_line(Vector2(px + 7, py + 5), Vector2(px + 9, py + 7),
		bone_dark, 1.0)

func _draw_heart(node: Control, pos: Vector2, color: Color):
	var pixels = [
		Vector2(1, 0), Vector2(2, 0), Vector2(4, 0), Vector2(5, 0),
		Vector2(0, 1), Vector2(1, 1), Vector2(2, 1), Vector2(3, 1), Vector2(4, 1), Vector2(5, 1), Vector2(6, 1),
		Vector2(0, 2), Vector2(1, 2), Vector2(2, 2), Vector2(3, 2), Vector2(4, 2), Vector2(5, 2), Vector2(6, 2),
		Vector2(1, 3), Vector2(2, 3), Vector2(3, 3), Vector2(4, 3), Vector2(5, 3),
		Vector2(2, 4), Vector2(3, 4), Vector2(4, 4),
		Vector2(3, 5),
	]
	for p in pixels:
		node.draw_rect(Rect2(pos + p * 1.5, Vector2(1.5, 1.5)), color)

func _draw_pause_menu(screen_size: Vector2):
	# Dark overlay
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.8))

	var cx = screen_size.x / 2
	var cy = screen_size.y / 2

	# Title
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 30, cy - 70),
		"ПАУЗА", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 0.9, 0.4))

	# Menu items
	var items = ["Продолжить", "Настройки", "Обучение", "Выйти"]
	var item_h = 28.0
	var menu_w = 160.0
	var start_y = cy - 30

	for i in items.size():
		var y = start_y + i * item_h
		var selected = (i == pause_selection)
		var bg = Color(0.3, 0.3, 0.4, 0.8) if selected else Color(0.15, 0.15, 0.2, 0.5)
		draw_node.draw_rect(Rect2(cx - menu_w / 2, y, menu_w, item_h - 4), bg)
		if selected:
			draw_node.draw_rect(Rect2(cx - menu_w / 2, y, menu_w, item_h - 4), Color(1, 0.9, 0.4, 0.6), false, 2.0)
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - menu_w / 2 + 8, y + 3),
				">", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.4))
		var text_col = Color(1, 1, 1) if selected else Color(0.6, 0.6, 0.6)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 40, y + 3),
			items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_col)

	# Controls hint
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 60, start_y + items.size() * item_h + 20),
		"W/S - выбор, Enter - ОК, Esc - назад", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.5, 0.5, 0.5))

func show_boss_bonus(options: Array, selected: int):
	boss_bonus_visible = true
	boss_bonus_options = options
	boss_bonus_selected = selected
	draw_node.queue_redraw()

func update_boss_bonus_selection(sel: int):
	boss_bonus_selected = sel
	draw_node.queue_redraw()

func hide_boss_bonus():
	boss_bonus_visible = false
	draw_node.queue_redraw()

func _draw_boss_bonus(screen_size: Vector2):
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.78))
	var cx = screen_size.x / 2.0
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx, screen_size.y * 0.22),
		"✦ БОНУС ПОБЕДИТЕЛЯ ✦", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 0.85, 0.2))
	for i in boss_bonus_options.size():
		var opt = boss_bonus_options[i]
		var oy = screen_size.y * 0.35 + i * 44.0
		var is_sel = (i == boss_bonus_selected)
		var bg = Color(0.55, 0.45, 0.08, 0.85) if is_sel else Color(0.12, 0.10, 0.08, 0.70)
		draw_node.draw_rect(Rect2(cx - 90, oy - 16, 180, 36), bg)
		if is_sel:
			draw_node.draw_rect(Rect2(cx - 90, oy - 16, 180, 36), Color(1, 0.85, 0.2, 0.7), false, 2.0)
		var tc = Color(1, 1, 1) if is_sel else Color(0.75, 0.75, 0.75)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 78, oy - 2),
			opt.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - 78, oy + 12),
			opt.desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.65, 0.65, 0.65, 0.85))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx, screen_size.y * 0.82),
		"W/S выбор   Enter принять", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.5, 0.5, 0.5))

func show_settings(sel: int, master: float, sfx: float, shake: bool):
	settings_visible = true
	settings_selection = sel
	settings_master_vol = master
	settings_sfx_vol = sfx
	settings_shake = shake
	draw_node.queue_redraw()

func update_settings(sel: int, master: float, sfx: float, shake: bool):
	settings_selection = sel
	settings_master_vol = master
	settings_sfx_vol = sfx
	settings_shake = shake
	draw_node.queue_redraw()

func hide_settings():
	settings_visible = false
	draw_node.queue_redraw()

func _draw_settings_screen(screen_size: Vector2):
	var cx = screen_size.x / 2.0
	var cy = screen_size.y / 2.0

	# Overlay (slightly less dark than pause so pause shows underneath)
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.6))

	# Panel
	var pw = 240.0
	var ph = 160.0
	draw_node.draw_rect(Rect2(cx - pw / 2, cy - ph / 2, pw, ph), Color(0.08, 0.08, 0.12, 0.97))
	draw_node.draw_rect(Rect2(cx - pw / 2, cy - ph / 2, pw, ph), Color(0.4, 0.4, 0.6, 0.8), false, 2.0)

	# Title
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx, cy - ph / 2 + 16),
		"НАСТРОЙКИ", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 0.9, 0.4))

	# Items: master vol, sfx vol, screen shake
	var labels = ["Громкость:", "Звуки:", "Тряска экрана:"]
	var row_h = 36.0
	var start_y = cy - ph / 2 + 48.0

	for i in 3:
		var ry = start_y + i * row_h
		var selected = (i == settings_selection)
		var label_col = Color(1, 1, 1) if selected else Color(0.6, 0.6, 0.6)

		# Highlight row
		if selected:
			draw_node.draw_rect(Rect2(cx - pw / 2 + 6, ry - 2, pw - 12, 26), Color(0.25, 0.25, 0.35, 0.7))

		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx - pw / 2 + 14, ry + 14),
			labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_col)

		# Value display
		if i == 0:
			_draw_vol_slider(cx + 10, ry + 6, settings_master_vol, selected)
		elif i == 1:
			_draw_vol_slider(cx + 10, ry + 6, settings_sfx_vol, selected)
		else:
			var toggle_text = "ВКЛ" if settings_shake else "ВЫКЛ"
			var toggle_col = Color(0.3, 1, 0.3) if settings_shake else Color(1, 0.4, 0.4)
			draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx + 14, ry + 14),
				toggle_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, toggle_col)

	# Hint
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx, cy + ph / 2 - 14),
		"A/D — изменить   Esc — назад", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.5, 0.5, 0.5))

func _draw_vol_slider(x: float, y: float, value: float, selected: bool):
	var bar_w = 80.0
	var bar_h = 8.0
	var filled = bar_w * (value / 100.0)
	draw_node.draw_rect(Rect2(x, y + 4, bar_w, bar_h), Color(0.2, 0.2, 0.2))
	var bar_col = Color(0.4, 0.8, 1.0) if selected else Color(0.3, 0.5, 0.7)
	draw_node.draw_rect(Rect2(x, y + 4, filled, bar_h), bar_col)
	draw_node.draw_rect(Rect2(x, y + 4, bar_w, bar_h), Color(0.5, 0.5, 0.6, 0.5), false, 1.0)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(x + bar_w + 6, y + 14),
		str(int(value)) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.8))

# ===================== ECONOMY / PROGRESSION API =====================

func update_coins(n: int):
	coins = n
	draw_node.queue_redraw()

func update_progression(level: int, xp_val: int, xp_max: int):
	char_level = level
	xp = xp_val
	xp_needed = xp_max
	draw_node.queue_redraw()

func show_combo(count: int):
	combo_count = count
	combo_display_timer = 2.5 if count >= 2 else 0.0
	draw_node.queue_redraw()

func show_room_name(name: String):
	room_name_text = name
	room_name_timer = 2.5
	draw_node.queue_redraw()

func show_level_up(choices: Array):
	level_up_visible = true
	level_up_choices = choices
	level_up_selected = 0
	draw_node.queue_redraw()

func update_level_up_sel(sel: int):
	level_up_selected = sel
	draw_node.queue_redraw()

func hide_level_up():
	level_up_visible = false
	draw_node.queue_redraw()

func set_minimap(rooms: Array, current: int):
	minimap_rooms = rooms
	minimap_current = current
	draw_node.queue_redraw()

# ===================== DRAW FUNCTIONS =====================

func _draw_coins_xp(screen_size: Vector2):
	# Coins — top right area
	var cx2 = screen_size.x - 10.0
	draw_node.draw_rect(Rect2(cx2 - 90, 3, 90, 18), Color(0, 0, 0, 0.5))
	draw_node.draw_circle(Vector2(cx2 - 80, 12), 5, Color(1, 0.85, 0.2))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx2 - 72, 17),
		str(coins), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.3))

	# XP bar + level — below coins
	draw_node.draw_rect(Rect2(cx2 - 90, 23, 90, 10), Color(0, 0, 0, 0.5))
	var xp_frac = float(xp) / max(xp_needed, 1)
	draw_node.draw_rect(Rect2(cx2 - 88, 25, 86 * xp_frac, 6), Color(0.4, 0.8, 1.0))
	draw_node.draw_rect(Rect2(cx2 - 88, 25, 86, 6), Color(0.5, 0.5, 0.7, 0.4), false, 1.0)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx2 - 88, 33),
		"Lv" + str(char_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.7, 0.9, 1.0))

func _draw_combo(screen_size: Vector2):
	if combo_count < 2: return
	var cx3 = screen_size.x / 2.0
	var cy3 = screen_size.y * 0.30
	var a = minf(combo_display_timer, 1.0)
	var scale = 1.0 + (1.0 - minf(combo_display_timer / 2.5, 1.0)) * 0.3
	var col = Color(1, 0.85, 0.2, a) if combo_count < 5 else Color(1, 0.4, 0.1, a)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx3, cy3),
		"x" + str(combo_count) + " КОМБО!", HORIZONTAL_ALIGNMENT_CENTER, -1,
		int(20 * scale), col)

func _draw_room_name(screen_size: Vector2):
	var a = minf(room_name_timer, 1.0) * minf(room_name_timer, 1.5) / 1.5
	var cx4 = screen_size.x / 2.0
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx4, screen_size.y * 0.15),
		room_name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1, 0.9, 0.6, a))

func _draw_minimap(screen_size: Vector2):
	# Сначала пытаемся детальную пиксельную миникарту
	var room = _get_room()
	if room and room.has_method("get_minimap_detailed"):
		_draw_detailed_minimap(screen_size, room)
		return
	# Фоллбэк на старую "rooms-grid" миникарту
	_draw_grid_minimap(screen_size)

func _draw_detailed_minimap(screen_size: Vector2, room):
	var data: Dictionary = room.get_minimap_detailed()
	var gcols: int = data.grid_cols
	var grows: int = data.grid_rows
	var tile_size: float = data.tile_size

	# Размер миникарты — масштабируем грид
	var map_w = 180.0
	var map_h = map_w * float(grows) / float(gcols)
	var px = map_w / float(gcols)   # пикселей миникарты на тайл
	var py = map_h / float(grows)
	var mx = screen_size.x - map_w - 10.0
	var my = screen_size.y - map_h - 36.0

	# Фон-панель + заголовок
	draw_node.draw_rect(Rect2(mx - 5, my - 18, map_w + 10, map_h + 22),
		Color(0.03, 0.03, 0.05, 0.88))
	draw_node.draw_rect(Rect2(mx - 5, my - 18, map_w + 10, map_h + 22),
		Color(0.3, 0.25, 0.20, 0.8), false, 1.0)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx - 3, my - 6),
		"КАРТА", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.85, 0.92, 0.85))

	# Фон неисследованной области — глухой "туман войны"
	draw_node.draw_rect(Rect2(mx, my, map_w, map_h), Color(0.06, 0.05, 0.07, 0.85))

	# 1) Рисуем тайлы через кэш-текстуру. Перерисовываем Image только при изменении explored.
	var grid_data = data.grid
	var explored_data: Array = data.get("explored", [])
	var has_fog: bool = explored_data.size() > 0
	# Считаем количество исследованных тайлов как простой хэш
	var explored_count = 0
	if has_fog:
		for r in grows:
			for c in gcols:
				if explored_data[r][c]: explored_count += 1
	# Пересоздаём image если карта/размер изменились
	if _mm_image == null or _mm_cached_cols != gcols or _mm_cached_rows != grows:
		_mm_image = Image.create(gcols, grows, false, Image.FORMAT_RGBA8)
		_mm_texture = ImageTexture.create_from_image(_mm_image)
		_mm_cached_cols = gcols
		_mm_cached_rows = grows
		_mm_explored_count = -1   # форсируем обновление
	# Перерисовываем image только если изменилось количество исследованных
	if _mm_explored_count != explored_count:
		_mm_explored_count = explored_count
		var transparent = Color(0, 0, 0, 0)
		var wall_col_img = Color(0.45, 0.42, 0.40, 0.95)
		var floor_col_img = Color(0.16, 0.16, 0.20, 0.85)
		for r in grows:
			var row_data = grid_data[r]
			var er = explored_data[r] if has_fog else null
			for c in gcols:
				if has_fog and not er[c]:
					_mm_image.set_pixel(c, r, transparent)
					continue
				var is_solid = (row_data[c] == 1)
				_mm_image.set_pixel(c, r, wall_col_img if is_solid else floor_col_img)
		_mm_texture.update(_mm_image)
	# Растягиваем кэш-текстуру на размер миникарты — 1 draw call
	draw_node.draw_texture_rect(_mm_texture,
		Rect2(mx, my, map_w, map_h), false)

	# Helper: исследована ли клетка под этим world_pos
	var is_explored = func(world_pos) -> bool:
		if not has_fog:
			return true
		var wx = world_pos.x if not (world_pos is Dictionary) else world_pos.x
		var wy = world_pos.y if not (world_pos is Dictionary) else world_pos.y
		if world_pos is Dictionary:
			wx = world_pos.x
			wy = world_pos.y
		var col = int(wx / tile_size)
		var row = int(wy / tile_size)
		if row < 0 or row >= grows or col < 0 or col >= gcols:
			return false
		return explored_data[row][col]

	# 2) Факелы — мягкие оранжевые точки
	for t in data.torches:
		if not is_explored.call(t): continue
		var p = _world_to_minimap(t, mx, my, tile_size, px, py)
		draw_node.draw_circle(p, 1.5, Color(1.0, 0.55, 0.15, 0.85))

	# 3) Железо — оранжевые крестики
	for ob in data.iron_ore:
		if not is_explored.call(ob): continue
		var p = _world_to_minimap(ob, mx, my, tile_size, px, py)
		draw_node.draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), Color(0.85, 0.45, 0.10))
		draw_node.draw_rect(Rect2(p.x - 0.5, p.y - 0.5, 1, 1), Color(1.0, 0.65, 0.20))

	# 4) Золото — жёлтые
	for gb in data.gold_ore:
		if not is_explored.call(gb): continue
		var p = _world_to_minimap(gb, mx, my, tile_size, px, py)
		draw_node.draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), Color(1.0, 0.85, 0.20))

	# 5) Сундуки — коричневые, открытые — серые
	for ch in data.chests:
		if not is_explored.call(ch): continue
		var p = _world_to_minimap(ch, mx, my, tile_size, px, py)
		var c = Color(0.55, 0.35, 0.10) if not ch.opened else Color(0.40, 0.40, 0.40, 0.5)
		draw_node.draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), c)

	# 6) Бочки — красные точки (взрывоопасные)
	for b in data.barrels:
		if not is_explored.call(b): continue
		var p = _world_to_minimap(b, mx, my, tile_size, px, py)
		draw_node.draw_circle(p, 1.4, Color(0.75, 0.10, 0.10))

	# 7) Торговец — мерцающая золотая монета
	if data.merchant != null and is_explored.call(data.merchant):
		var p = _world_to_minimap(data.merchant, mx, my, tile_size, px, py)
		var blink = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		draw_node.draw_circle(p, 3.0, Color(1, 0.85, 0.2, blink))
		draw_node.draw_circle(p, 2.0, Color(0.6, 0.4, 0.0))

	# 8) Двери — красные стрелочки (выход)
	for d in data.doors:
		if not is_explored.call(d): continue
		var p = _world_to_minimap(d, mx, my, tile_size, px, py)
		draw_node.draw_colored_polygon(PackedVector2Array([
			Vector2(p.x - 3, p.y - 3),
			Vector2(p.x + 3, p.y),
			Vector2(p.x - 3, p.y + 3),
		]), Color(1.0, 0.40, 0.10))

	# 9) Игрок — белая мигающая точка с обводкой
	var player = _get_player()
	if player and is_instance_valid(player):
		var p = _world_to_minimap(
			{"x": player.global_position.x, "y": player.global_position.y},
			mx, my, tile_size, px, py)
		var blink = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		draw_node.draw_circle(p, 3.2, Color(1, 1, 1, blink))
		draw_node.draw_circle(p, 1.8, Color(0.30, 1.0, 0.30, 0.95))

	# 10) Легенда снизу
	var ly = my + map_h + 4
	var leg_x = mx
	# Железо
	draw_node.draw_rect(Rect2(leg_x, ly, 4, 4), Color(0.85, 0.45, 0.10))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(leg_x + 6, ly + 5),
		"железо", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7, 0.7, 0.7))
	# Сундук
	draw_node.draw_rect(Rect2(leg_x + 42, ly, 4, 4), Color(0.55, 0.35, 0.10))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(leg_x + 48, ly + 5),
		"сундук", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7, 0.7, 0.7))
	# Дверь
	draw_node.draw_rect(Rect2(leg_x + 86, ly, 4, 4), Color(1.0, 0.4, 0.1))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(leg_x + 92, ly + 5),
		"выход", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7, 0.7, 0.7))
	# Торговец
	draw_node.draw_circle(Vector2(leg_x + 128, ly + 2), 2, Color(1, 0.85, 0.2))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(leg_x + 133, ly + 5),
		"торг.", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7, 0.7, 0.7))

func _world_to_minimap(world_pos, mx: float, my: float, tile_size: float, px: float, py: float) -> Vector2:
	# world_pos может быть Vector2 или Dictionary {x, y}
	var wx = 0.0
	var wy = 0.0
	if world_pos is Dictionary:
		wx = world_pos.x
		wy = world_pos.y
	else:
		wx = world_pos.x
		wy = world_pos.y
	var col = wx / tile_size
	var row = wy / tile_size
	return Vector2(mx + col * px, my + row * py)

func _draw_grid_minimap(screen_size: Vector2):
	if minimap_rooms.size() == 0: return
	var cell_w = 22.0
	var cell_h = 14.0
	var gap = 3.0  # corridor width

	# Figure out grid size from room data
	var max_rx = 0
	var max_ry = 0
	for rm in minimap_rooms:
		if rm.get("active", false):
			max_rx = maxi(max_rx, rm.get("rx", 0))
			max_ry = maxi(max_ry, rm.get("ry", 0))
	var cols = max_rx + 1
	var rows = max_ry + 1

	var map_w = cols * cell_w + (cols - 1) * gap
	var map_h = rows * cell_h + (rows - 1) * gap
	var mx = screen_size.x - map_w - 10
	var my = screen_size.y - map_h - 36  # above hotbar

	# Background panel
	draw_node.draw_rect(Rect2(mx - 5, my - 16, map_w + 10, map_h + 20), Color(0, 0, 0, 0.72))
	draw_node.draw_rect(Rect2(mx - 5, my - 16, map_w + 10, map_h + 20), Color(0.3, 0.3, 0.4, 0.5), false, 1.0)
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx - 3, my - 5),
		"КАРТА", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 0.6, 0.7, 0.8))

	var blink = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.5

	# Helper to get cell center
	var cell_center = func(rx: int, ry: int) -> Vector2:
		return Vector2(mx + rx * (cell_w + gap) + cell_w * 0.5,
					   my + ry * (cell_h + gap) + cell_h * 0.5)

	# Pass 1: draw corridors between visited adjacent rooms
	for i in minimap_rooms.size():
		var rm = minimap_rooms[i]
		if not rm.get("active", false): continue
		if not rm.get("visited", false) and i != minimap_current: continue
		var rx = rm.get("rx", 0)
		var ry = rm.get("ry", 0)
		var c1 = cell_center.call(rx, ry)
		for ni in rm.get("neighbors", []):
			var rm2 = minimap_rooms[ni]
			if not rm2.get("visited", false) and ni != minimap_current: continue
			var c2 = cell_center.call(rm2.get("rx", 0), rm2.get("ry", 0))
			draw_node.draw_line(c1, c2, Color(0.4, 0.4, 0.55, 0.8), 2.0)

	# Pass 2: draw room boxes
	for i in minimap_rooms.size():
		var rm = minimap_rooms[i]
		if not rm.get("active", false): continue
		var visited = rm.get("visited", false)
		var is_current = (i == minimap_current)
		if not visited and not is_current: continue

		var rx = rm.get("rx", 0)
		var ry = rm.get("ry", 0)
		var cell_rect = Rect2(mx + rx * (cell_w + gap), my + ry * (cell_h + gap), cell_w, cell_h)
		var center = cell_center.call(rx, ry)

		# Room fill colour
		var col: Color
		if is_current:
			col = Color(1.0, 1.0, 0.3, 0.65 + blink * 0.25)
		elif rm.get("is_door", false):
			col = Color(0.9, 0.5, 0.1, 0.85)
		elif rm.get("is_start", false):
			col = Color(0.2, 0.75, 0.25, 0.85)
		elif rm.get("is_merchant", false):
			col = Color(0.9, 0.75, 0.1, 0.85)
		else:
			col = Color(0.32, 0.32, 0.45, 0.8)
		draw_node.draw_rect(cell_rect, col)

		# Border
		var border_col = Color(1, 0.9, 0.3, 0.9) if is_current else Color(0.55, 0.55, 0.65, 0.5)
		draw_node.draw_rect(cell_rect, border_col, false, 1.0)

		# Icons
		if is_current:
			# White player dot
			draw_node.draw_circle(center, 2.5, Color(1, 1, 1, 0.95))
		elif rm.get("is_door", false):
			# Exit arrow: small ▶
			draw_node.draw_colored_polygon(PackedVector2Array([
				Vector2(center.x - 3, center.y - 3), Vector2(center.x + 4, center.y),
				Vector2(center.x - 3, center.y + 3)]), Color(1, 0.85, 0.3))
		elif rm.get("is_start", false):
			# S letter approximated as small rect pair
			draw_node.draw_rect(Rect2(center.x - 2, center.y - 4, 5, 2), Color(1, 1, 1, 0.85))
			draw_node.draw_rect(Rect2(center.x - 2, center.y - 1, 5, 2), Color(1, 1, 1, 0.85))
			draw_node.draw_rect(Rect2(center.x - 2, center.y + 2, 5, 2), Color(1, 1, 1, 0.85))
		elif rm.get("is_merchant", false):
			# Coin symbol
			draw_node.draw_circle(center, 3.5, Color(1, 0.85, 0.2))
			draw_node.draw_circle(center, 3.5, Color(0.6, 0.4, 0.0), false, 1.0)

	# Legend
	var ly = my + map_h + 4
	draw_node.draw_rect(Rect2(mx - 1, ly, 6, 5), Color(1, 1, 0.3)); draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 8, ly + 5), "ты", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7,0.7,0.7))
	draw_node.draw_rect(Rect2(mx + 24, ly, 6, 5), Color(0.9, 0.5, 0.1)); draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 33, ly + 5), "выход", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7,0.7,0.7))
	draw_node.draw_circle(Vector2(mx + 70, ly + 2), 3, Color(1, 0.85, 0.2)); draw_node.draw_string(ThemeDB.fallback_font, Vector2(mx + 76, ly + 5), "торг.", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7,0.7,0.7))

func _draw_level_up(screen_size: Vector2):
	var cx5 = screen_size.x / 2.0
	var cy5 = screen_size.y / 2.0
	draw_node.draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color(0, 0, 0, 0.75))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx5, cy5 - 80),
		"✦ УРОВЕНЬ " + str(char_level) + " ✦", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0.4, 0.9, 1.0))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx5, cy5 - 58),
		"Выбери улучшение:", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.75, 0.75, 0.75))
	for i in level_up_choices.size():
		var ch = level_up_choices[i]
		var oy = cy5 - 30.0 + i * 46.0
		var is_sel = (i == level_up_selected)
		var bg = Color(0.2, 0.5, 0.7, 0.85) if is_sel else Color(0.1, 0.1, 0.15, 0.75)
		draw_node.draw_rect(Rect2(cx5 - 110, oy - 14, 220, 38), bg)
		if is_sel:
			draw_node.draw_rect(Rect2(cx5 - 110, oy - 14, 220, 38), Color(0.4, 0.9, 1.0, 0.7), false, 2.0)
		var tc = Color(1, 1, 1) if is_sel else Color(0.7, 0.7, 0.7)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx5 - 98, oy + 2),
			ch.get("label", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tc)
		draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx5 - 98, oy + 16),
			ch.get("desc", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.65, 0.65, 0.65, 0.9))
	draw_node.draw_string(ThemeDB.fallback_font, Vector2(cx5, cy5 + 90),
		"W/S выбор   Enter принять", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.5, 0.5, 0.5))
