extends CanvasLayer

# Стартовое меню: "Просто начать" + "Кастомная игра" + "Выход"
# В кастомной игре можно выбрать: карту, свитки (до 2), стартовое оружие,
# и выключить особые события (mimic, spider, no-exit, meat, rush B).

signal quick_start
signal custom_start(config: Dictionary)
signal exit_game

# === Данные карточек / свитков / событий ===
const CARDS: Array = [
	{"id": "", "name": "Без карты", "desc": "Никаких пассивок"},
	{"id": "invisibility", "name": "Невидимость", "desc": "Враги не видят вдали от факелов"},
	{"id": "death_jar", "name": "Банка Смерти", "desc": "Собирай яд, кидай R"},
	{"id": "throw_weapon", "name": "Бросок", "desc": "Кидай оружие (Q), x2 урон"},
	{"id": "speed_boots", "name": "Ботинки Скорости", "desc": "+50% скорость, +30% прыжок"},
	{"id": "dodge", "name": "Уворот", "desc": "25% шанс уворота (40% с клинками)"},
	{"id": "backstab", "name": "Удар в Спину", "desc": "+60% урон сзади"},
	{"id": "acid_water", "name": "Кислотная Вода", "desc": "Кислота лечит"},
	{"id": "thorn_armor", "name": "Шипастая Броня", "desc": "Шипы -80% урона"},
	{"id": "close_combat", "name": "Ближний Бой", "desc": "+40% урон вблизи"},
	{"id": "berserker", "name": "Берсерк", "desc": "+0.5% урон / 1% потерянного HP"},
	{"id": "hunter", "name": "Охотник", "desc": "+0.2% урон за убийство"},
	{"id": "critical", "name": "Крит. Удар", "desc": "+10% шанс крита, +20% урон"},
	{"id": "second_chance", "name": "Второй Шанс", "desc": "Воскрешение 1 раз"},
]

const SCROLLS: Array = [
	{"id": "dash", "name": "Рывок", "desc": "Быстрый рывок вперёд"},
	{"id": "kick", "name": "Удар ногой", "desc": "Толкнуть врага"},
	{"id": "speed_boost", "name": "Ускорение", "desc": "Временный +скорость"},
	{"id": "choke", "name": "Удушение", "desc": "Захват врага"},
	{"id": "slide", "name": "Подкат", "desc": "Скольжение"},
]

# Оружия — будут заполнены из player.weapon_data при открытии меню
var weapons_list: Array = []  # [{id, name, rarity, color}]

const EVENTS: Array = [
	{"id": "mimic", "name": "Мимик", "desc": "Сундук-монстр"},
	{"id": "spider", "name": "Гигантский паук", "desc": "Хоррор-сцена"},
	{"id": "no_exit", "name": "Нет выхода", "desc": "Стены сжимаются"},
	{"id": "meat_room", "name": "Мясная комната", "desc": "Кровавая локация"},
	{"id": "rush_b", "name": "RUSH B", "desc": "CS пасхалка"},
]

# === Состояние ===
var screen: String = "main"   # main | custom
var draw_node: Control = null

# Custom config (значения по умолчанию)
var sel_card_idx: int = 0
var sel_scroll_a: int = -1   # индекс в SCROLLS или -1 (пусто)
var sel_scroll_b: int = -1
var sel_weapon_idx: int = 0
var event_enabled: Dictionary = {}  # event_id → bool
var focus_section: int = 0   # 0=card, 1=scrolls, 2=weapon, 3=events, 4=buttons
var event_focus: int = 0      # индекс события в фокусе

# Buttons
var btn_quick: Button = null
var btn_custom: Button = null
var btn_exit: Button = null
var btn_start: Button = null
var btn_back: Button = null


func _ready() -> void:
	layer = 250
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true   # пауза мира
	# Подгружаем мета
	var Meta = load("res://scripts/meta_progress.gd")
	Meta.load_meta()

	# Defaults
	for ev in EVENTS:
		event_enabled[ev.id] = true

	# Главный draw_node под кнопками
	draw_node = Control.new()
	draw_node.anchor_left = 0
	draw_node.anchor_top = 0
	draw_node.anchor_right = 1
	draw_node.anchor_bottom = 1
	draw_node.offset_left = 0
	draw_node.offset_top = 0
	draw_node.offset_right = 0
	draw_node.offset_bottom = 0
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(draw_node)
	draw_node.draw.connect(_on_draw)

	_build_main_buttons()

var btn_daily: Button = null

func _build_main_buttons() -> void:
	_clear_buttons()
	btn_quick = _make_button("ПРОСТО НАЧАТЬ", Color(0.20, 0.55, 0.95))
	btn_quick.pressed.connect(_on_quick_pressed)
	add_child(btn_quick)

	btn_custom = _make_button("КАСТОМНАЯ ИГРА", Color(1.00, 0.55, 0.10))
	btn_custom.pressed.connect(_on_custom_pressed)
	add_child(btn_custom)

	btn_daily = _make_button("DAILY SEED", Color(0.40, 0.85, 0.40))
	btn_daily.pressed.connect(_on_daily_pressed)
	add_child(btn_daily)

	btn_exit = _make_button("ВЫЙТИ", Color(0.45, 0.10, 0.10))
	btn_exit.pressed.connect(_on_exit_pressed)
	add_child(btn_exit)

	_layout_main_buttons()
	draw_node.queue_redraw()

func _layout_main_buttons() -> void:
	var vs = get_viewport().get_visible_rect().size
	var cx = vs.x * 0.5
	var cy = vs.y * 0.5
	var bw = 280.0
	var bh = 42.0
	var gap = 10.0
	var y0 = cy - 60
	if btn_quick:
		btn_quick.position = Vector2(cx - bw * 0.5, y0)
		btn_quick.size = Vector2(bw, bh)
	if btn_custom:
		btn_custom.position = Vector2(cx - bw * 0.5, y0 + (bh + gap))
		btn_custom.size = Vector2(bw, bh)
	if btn_daily:
		btn_daily.position = Vector2(cx - bw * 0.5, y0 + (bh + gap) * 2)
		btn_daily.size = Vector2(bw, bh)
	if btn_exit:
		btn_exit.position = Vector2(cx - bw * 0.5, y0 + (bh + gap) * 3)
		btn_exit.size = Vector2(bw, bh)

func _build_custom_buttons() -> void:
	_clear_buttons()
	btn_back = _make_button("← НАЗАД", Color(0.4, 0.4, 0.45))
	btn_back.pressed.connect(_on_back_pressed)
	add_child(btn_back)

	btn_start = _make_button("НАЧАТЬ", Color(0.20, 0.75, 0.25))
	btn_start.pressed.connect(_on_start_custom_pressed)
	add_child(btn_start)

	_layout_custom_buttons()
	draw_node.queue_redraw()

func _layout_custom_buttons() -> void:
	var vs = get_viewport().get_visible_rect().size
	var bw = 160.0
	var bh = 36.0
	var y = vs.y - 60.0
	if btn_back:
		btn_back.position = Vector2(vs.x * 0.5 - bw - 10, y)
		btn_back.size = Vector2(bw, bh)
	if btn_start:
		btn_start.position = Vector2(vs.x * 0.5 + 10, y)
		btn_start.size = Vector2(bw, bh)

func _make_button(text: String, accent: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.85))
	var sb_norm = StyleBoxFlat.new()
	sb_norm.bg_color = Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6, 0.85)
	sb_norm.border_color = accent
	sb_norm.set_border_width_all(2)
	sb_norm.set_corner_radius_all(3)
	b.add_theme_stylebox_override("normal", sb_norm)
	var sb_hov = StyleBoxFlat.new()
	sb_hov.bg_color = Color(accent.r * 0.85, accent.g * 0.85, accent.b * 0.85, 0.95)
	sb_hov.border_color = Color(1, 1, 1)
	sb_hov.set_border_width_all(2)
	sb_hov.set_corner_radius_all(3)
	b.add_theme_stylebox_override("hover", sb_hov)
	return b

func _clear_buttons() -> void:
	for c in get_children():
		if c is Button:
			c.queue_free()
	btn_quick = null
	btn_custom = null
	btn_daily = null
	btn_exit = null
	btn_back = null
	btn_start = null

func set_weapon_list(weapon_data: Dictionary) -> void:
	weapons_list.clear()
	# id 1 = базовый меч; начинаем с него
	for wid in weapon_data.keys():
		if wid == 0:  # пропускаем "кулаки" (это no-weapon)
			continue
		var wd: Dictionary = weapon_data[wid]
		weapons_list.append({
			"id": wid,
			"name": wd.get("name", ""),
			"rarity": wd.get("rarity", "common"),
			"color": wd.get("color", Color.WHITE),
		})
	weapons_list.sort_custom(func(a, b): return a.id < b.id)
	sel_weapon_idx = 0  # начинаем с меча


# ─── Кнопки ───────────────────────────────────────────────
func _on_quick_pressed() -> void:
	_close_and_emit_quick()

func _on_daily_pressed() -> void:
	# Запускаем игру с детерм. сидом текущей даты
	var cfg = {
		"card_id": "",
		"scrolls": [],
		"weapon_id": 1,
		"events_enabled": {},
		"daily_seed": true,
	}
	_close_and_emit_custom(cfg)

func _on_custom_pressed() -> void:
	screen = "custom"
	_build_custom_buttons()

func _on_exit_pressed() -> void:
	exit_game.emit()
	get_tree().quit()

func _on_back_pressed() -> void:
	screen = "main"
	_build_main_buttons()

func _on_start_custom_pressed() -> void:
	var cfg = {
		"card_id": CARDS[sel_card_idx].id,
		"scrolls": [],
		"weapon_id": weapons_list[sel_weapon_idx].id if weapons_list.size() > 0 else 1,
		"events_enabled": event_enabled.duplicate(),
	}
	if sel_scroll_a >= 0:
		cfg.scrolls.append(SCROLLS[sel_scroll_a].id)
	if sel_scroll_b >= 0 and sel_scroll_b != sel_scroll_a:
		cfg.scrolls.append(SCROLLS[sel_scroll_b].id)
	_close_and_emit_custom(cfg)

func _close_and_emit_quick() -> void:
	get_tree().paused = false
	visible = false
	quick_start.emit()
	queue_free()

func _close_and_emit_custom(cfg: Dictionary) -> void:
	get_tree().paused = false
	visible = false
	custom_start.emit(cfg)
	queue_free()


# ─── Input для кастомного экрана (клавиатура) ──────────────
func _unhandled_input(event: InputEvent) -> void:
	if screen != "custom":
		return
	if not (event is InputEventKey and event.pressed):
		return
	var k = event.keycode
	# Tab / стрелки вверх-вниз: переключение секций
	if k == KEY_TAB or k == KEY_DOWN or k == KEY_S:
		focus_section = (focus_section + 1) % 5
		draw_node.queue_redraw()
		get_viewport().set_input_as_handled()
	elif k == KEY_UP or k == KEY_W:
		focus_section = (focus_section - 1 + 5) % 5
		draw_node.queue_redraw()
		get_viewport().set_input_as_handled()
	elif k == KEY_LEFT or k == KEY_A:
		_section_left()
	elif k == KEY_RIGHT or k == KEY_D:
		_section_right()
	elif k == KEY_SPACE or k == KEY_ENTER:
		_section_toggle()
	elif k == KEY_ESCAPE:
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _section_left() -> void:
	match focus_section:
		0:
			sel_card_idx = (sel_card_idx - 1 + CARDS.size()) % CARDS.size()
		2:
			if weapons_list.size() > 0:
				sel_weapon_idx = (sel_weapon_idx - 1 + weapons_list.size()) % weapons_list.size()
		3:
			event_focus = (event_focus - 1 + EVENTS.size()) % EVENTS.size()
	draw_node.queue_redraw()

func _section_right() -> void:
	match focus_section:
		0:
			sel_card_idx = (sel_card_idx + 1) % CARDS.size()
		2:
			if weapons_list.size() > 0:
				sel_weapon_idx = (sel_weapon_idx + 1) % weapons_list.size()
		3:
			event_focus = (event_focus + 1) % EVENTS.size()
	draw_node.queue_redraw()

func _section_toggle() -> void:
	# В секции свитков и событий — Space переключает выбор
	match focus_section:
		1:
			# Циклически меняем 1-й, потом 2-й свиток
			# Просто переключаем "первый пустой → следующий свиток"
			pass
		3:
			var ev_id = EVENTS[event_focus].id
			event_enabled[ev_id] = not event_enabled.get(ev_id, true)
	draw_node.queue_redraw()

# Клик мыши по UI элементам (свитки и события)
func _input(event: InputEvent) -> void:
	if screen != "custom":
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var mpos = event.position
	_handle_mouse_click(mpos)

func _handle_mouse_click(mpos: Vector2) -> void:
	# Клик по свиткам
	for i in SCROLLS.size():
		var rect = _scroll_rect(i)
		if rect.has_point(mpos):
			_toggle_scroll(i)
			draw_node.queue_redraw()
			return
	# Клик по событиям
	for i in EVENTS.size():
		var rect = _event_rect(i)
		if rect.has_point(mpos):
			var ev_id = EVENTS[i].id
			event_enabled[ev_id] = not event_enabled.get(ev_id, true)
			draw_node.queue_redraw()
			return
	# Клик по карточкам arrows
	var card_l = _card_arrow_rect(true)
	var card_r = _card_arrow_rect(false)
	if card_l.has_point(mpos):
		sel_card_idx = (sel_card_idx - 1 + CARDS.size()) % CARDS.size()
		draw_node.queue_redraw()
		return
	if card_r.has_point(mpos):
		sel_card_idx = (sel_card_idx + 1) % CARDS.size()
		draw_node.queue_redraw()
		return
	# Оружие arrows
	var w_l = _weapon_arrow_rect(true)
	var w_r = _weapon_arrow_rect(false)
	if w_l.has_point(mpos) and weapons_list.size() > 0:
		sel_weapon_idx = (sel_weapon_idx - 1 + weapons_list.size()) % weapons_list.size()
		draw_node.queue_redraw()
		return
	if w_r.has_point(mpos) and weapons_list.size() > 0:
		sel_weapon_idx = (sel_weapon_idx + 1) % weapons_list.size()
		draw_node.queue_redraw()
		return

func _toggle_scroll(i: int) -> void:
	# Если свиток выбран — снимаем; иначе добавляем в первый свободный слот
	if sel_scroll_a == i:
		sel_scroll_a = -1
	elif sel_scroll_b == i:
		sel_scroll_b = -1
	elif sel_scroll_a == -1:
		sel_scroll_a = i
	elif sel_scroll_b == -1:
		sel_scroll_b = i
	# Если оба заняты — игнорируем (можно сначала снять)


# === Геометрия секций ===
func _scroll_rect(i: int) -> Rect2:
	var vs = get_viewport().get_visible_rect().size
	var w = 110.0
	var h = 28.0
	var gap = 6.0
	var total_w = SCROLLS.size() * (w + gap) - gap
	var x0 = vs.x * 0.5 - total_w * 0.5
	var y0 = 220.0
	return Rect2(x0 + i * (w + gap), y0, w, h)

func _event_rect(i: int) -> Rect2:
	var vs = get_viewport().get_visible_rect().size
	var w = 140.0
	var h = 28.0
	var gap = 6.0
	var total_w = EVENTS.size() * (w + gap) - gap
	var x0 = vs.x * 0.5 - total_w * 0.5
	var y0 = 360.0
	return Rect2(x0 + i * (w + gap), y0, w, h)

func _card_arrow_rect(left: bool) -> Rect2:
	var vs = get_viewport().get_visible_rect().size
	var box_w = 320.0
	var cx = vs.x * 0.5
	var y = 120.0
	if left:
		return Rect2(cx - box_w * 0.5 - 30, y, 24, 36)
	else:
		return Rect2(cx + box_w * 0.5 + 6, y, 24, 36)

func _weapon_arrow_rect(left: bool) -> Rect2:
	var vs = get_viewport().get_visible_rect().size
	var box_w = 280.0
	var cx = vs.x * 0.5
	var y = 290.0
	if left:
		return Rect2(cx - box_w * 0.5 - 30, y, 24, 36)
	else:
		return Rect2(cx + box_w * 0.5 + 6, y, 24, 36)


# === DRAW ===
func _process(_delta: float) -> void:
	if draw_node:
		draw_node.queue_redraw()

func _on_draw() -> void:
	var vs = get_viewport().get_visible_rect().size
	# Тёмный фон
	draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0.03, 0.03, 0.05, 0.97))
	# Декоративные кровавые потёки сверху
	for i in 12:
		var x = float(i) * vs.x / 12.0 + sin(_time() + i) * 6.0
		var drip_h = 14.0 + sin(i * 0.7) * 8.0
		draw_node.draw_rect(Rect2(x, 0, 2, drip_h),
			Color(0.55, 0.05, 0.05, 0.55))
		draw_node.draw_circle(Vector2(x + 1, drip_h),
			2.2, Color(0.45, 0.04, 0.04, 0.7))

	var font := ThemeDB.fallback_font

	# Заголовок
	var title = "ПЕТЛЯ"
	var subtitle = "" if screen == "main" else "КАСТОМНАЯ ИГРА"
	var title_size = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 56)
	# Обводка
	for ox in [-3, -2, -1, 0, 1, 2, 3]:
		for oy in [-3, -2, -1, 0, 1, 2, 3]:
			if abs(ox) + abs(oy) <= 1: continue
			draw_node.draw_string(font, Vector2(vs.x * 0.5 - title_size.x * 0.5 + ox, 65 + oy),
				title, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(0, 0, 0, 0.8))
	draw_node.draw_string(font, Vector2(vs.x * 0.5 - title_size.x * 0.5, 65),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 56,
		Color(0.85, 0.08, 0.08))

	if subtitle != "":
		var sub_size = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_node.draw_string(font, Vector2(vs.x * 0.5 - sub_size.x * 0.5, 90),
			subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.85, 0.85))

	# Мета-стата в правом нижнем углу
	if screen == "main":
		var Meta = load("res://scripts/meta_progress.gd")
		var stats_x = vs.x - 240
		var stats_y = vs.y - 90
		# Полупрозрачная подложка
		draw_node.draw_rect(Rect2(stats_x - 8, stats_y - 16, 235, 132),
			Color(0.04, 0.03, 0.06, 0.7))
		draw_node.draw_string(font, Vector2(stats_x, stats_y),
			"ПАМЯТЬ ПЕТЛИ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1.00, 0.85, 0.20))
		draw_node.draw_string(font, Vector2(stats_x, stats_y + 14),
			"Убийства: %d   Смерти: %d" % [Meta.total_kills, Meta.total_deaths],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.85, 0.92))
		draw_node.draw_string(font, Vector2(stats_x, stats_y + 26),
			"Дальше всего: уровень %d" % Meta.furthest_level,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.85, 0.92))
		# Активные баффы
		var dmg_t = Meta.get_damage_tier()
		var hp_t = Meta.get_hp_tier()
		var coin_start = Meta.get_starting_coins()
		var heal_t = Meta.get_starting_heal_tier()
		var buffs = []
		if dmg_t > 0: buffs.append("+%d%% урон" % (dmg_t * 5))
		if hp_t > 0:  buffs.append("+%d HP" % (hp_t * 10))
		if coin_start > 0: buffs.append("+%d монет" % coin_start)
		if heal_t > 0: buffs.append("+%d лечений" % heal_t)
		var buffs_text = " · ".join(buffs) if buffs.size() > 0 else "—"
		draw_node.draw_string(font, Vector2(stats_x, stats_y + 42),
			"Баффы: " + buffs_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.95, 0.55))
		# Вехи-разлоки: открыто (зелёное ✓) или прогресс (серое)
		draw_node.draw_string(font, Vector2(stats_x, stats_y + 58),
			"РАЗЛОКИ:", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.00, 0.85, 0.20))
		var milestones = Meta.get_milestones()
		for mi in milestones.size():
			var m = milestones[mi]
			var done: bool = m[1]
			var line: String = ("✓ " + m[0]) if done else ("• %s (%s)" % [m[0], m[2]])
			var mcol: Color = Color(0.55, 0.95, 0.55) if done else Color(0.6, 0.6, 0.66)
			draw_node.draw_string(font, Vector2(stats_x, stats_y + 72 + mi * 12),
				line, HORIZONTAL_ALIGNMENT_LEFT, 230, 8, mcol)

	if screen == "custom":
		_draw_custom(vs)

func _draw_custom(vs: Vector2) -> void:
	var font := ThemeDB.fallback_font

	# === SECTION 1: CARD ===
	var card_y = 120.0
	var box_w = 320.0
	var box_h = 36.0
	var cx = vs.x * 0.5
	var card = CARDS[sel_card_idx]
	# Подсветка фокуса
	if focus_section == 0:
		draw_node.draw_rect(Rect2(cx - box_w * 0.5 - 4, card_y - 4, box_w + 8, box_h + 8),
			Color(1, 0.85, 0.2, 0.25))
	# Подпись секции
	draw_node.draw_string(font, Vector2(cx - 30, card_y - 14),
		"КАРТА", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.75, 0.8))
	# Стрелки
	_draw_arrow(_card_arrow_rect(true), true)
	_draw_arrow(_card_arrow_rect(false), false)
	# Сама карточка
	draw_node.draw_rect(Rect2(cx - box_w * 0.5, card_y, box_w, box_h),
		Color(0.10, 0.10, 0.14, 0.95))
	draw_node.draw_rect(Rect2(cx - box_w * 0.5, card_y, box_w, box_h),
		Color(0.35, 0.10, 0.10), false, 2.0)
	var name_size = font.get_string_size(card.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_node.draw_string(font, Vector2(cx - name_size.x * 0.5, card_y + 22),
		card.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
	# Описание под карточкой
	var desc_size = font.get_string_size(card.desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_node.draw_string(font, Vector2(cx - desc_size.x * 0.5, card_y + box_h + 16),
		card.desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.75, 0.78))

	# === SECTION 2: SCROLLS ===
	var sec2_y = 200.0
	draw_node.draw_string(font, Vector2(cx - 50, sec2_y),
		"СВИТКИ (до 2)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.75, 0.8))
	if focus_section == 1:
		var r = _scroll_rect(0)
		var rlast = _scroll_rect(SCROLLS.size() - 1)
		draw_node.draw_rect(Rect2(r.position.x - 4, r.position.y - 4,
			(rlast.position.x + rlast.size.x) - r.position.x + 8, r.size.y + 8),
			Color(1, 0.85, 0.2, 0.18))
	for i in SCROLLS.size():
		var sr = _scroll_rect(i)
		var sel = (i == sel_scroll_a or i == sel_scroll_b)
		var bg = Color(0.20, 0.50, 0.85, 0.85) if sel else Color(0.10, 0.10, 0.14, 0.9)
		draw_node.draw_rect(sr, bg)
		draw_node.draw_rect(sr, Color(0.4, 0.6, 0.9) if sel else Color(0.3, 0.3, 0.35),
			false, 1.5)
		var sn = SCROLLS[i].name
		var sn_size = font.get_string_size(sn, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_node.draw_string(font, Vector2(sr.position.x + sr.size.x * 0.5 - sn_size.x * 0.5,
			sr.position.y + 18),
			sn, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
		# Маркер слота
		if sel:
			var slot = "1" if i == sel_scroll_a else "2"
			draw_node.draw_string(font, Vector2(sr.position.x + 4, sr.position.y + 12),
				slot, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.4))

	# === SECTION 3: WEAPON ===
	var w_y = 290.0
	draw_node.draw_string(font, Vector2(cx - 80, w_y - 14),
		"СТАРТОВОЕ ОРУЖИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.75, 0.8))
	var wbox_w = 280.0
	if focus_section == 2:
		draw_node.draw_rect(Rect2(cx - wbox_w * 0.5 - 4, w_y - 4, wbox_w + 8, box_h + 8),
			Color(1, 0.85, 0.2, 0.25))
	_draw_arrow(_weapon_arrow_rect(true), true)
	_draw_arrow(_weapon_arrow_rect(false), false)
	draw_node.draw_rect(Rect2(cx - wbox_w * 0.5, w_y, wbox_w, box_h),
		Color(0.10, 0.10, 0.14, 0.95))
	if weapons_list.size() > 0:
		var w = weapons_list[sel_weapon_idx]
		var rar_col = _rarity_color(w.rarity)
		draw_node.draw_rect(Rect2(cx - wbox_w * 0.5, w_y, wbox_w, box_h),
			rar_col, false, 2.0)
		var wname = w.name
		var wname_size = font.get_string_size(wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_node.draw_string(font, Vector2(cx - wname_size.x * 0.5, w_y + 22),
			wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
		# Лейбл рарности справа
		var rar_label = _rarity_label(w.rarity)
		draw_node.draw_string(font, Vector2(cx + wbox_w * 0.5 - 100, w_y + box_h + 12),
			rar_label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, rar_col)

	# === SECTION 4: EVENTS ===
	var ev_y = 340.0
	draw_node.draw_string(font, Vector2(cx - 50, ev_y),
		"СОБЫТИЯ (клик чтобы выкл/вкл)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.75, 0.8))
	if focus_section == 3:
		var er0 = _event_rect(0)
		var erlast = _event_rect(EVENTS.size() - 1)
		draw_node.draw_rect(Rect2(er0.position.x - 4, er0.position.y - 4,
			(erlast.position.x + erlast.size.x) - er0.position.x + 8, er0.size.y + 8),
			Color(1, 0.85, 0.2, 0.18))
	for i in EVENTS.size():
		var er = _event_rect(i)
		var ev = EVENTS[i]
		var on = event_enabled.get(ev.id, true)
		var bg = Color(0.20, 0.55, 0.20, 0.85) if on else Color(0.30, 0.10, 0.10, 0.85)
		draw_node.draw_rect(er, bg)
		var border_c = Color(0.4, 0.85, 0.4) if on else Color(0.65, 0.25, 0.25)
		if focus_section == 3 and i == event_focus:
			border_c = Color(1, 1, 0.4)
		draw_node.draw_rect(er, border_c, false, 1.5)
		# Чекбокс ✓/✗
		var ch = "✓" if on else "✗"
		draw_node.draw_string(font, Vector2(er.position.x + 6, er.position.y + 19),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
		# Название
		draw_node.draw_string(font, Vector2(er.position.x + 22, er.position.y + 19),
			ev.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))

	# === Подсказка управления ===
	draw_node.draw_string(font, Vector2(20, vs.y - 16),
		"WASD/Стрелки — навигация · ENTER — переключить · ESC — назад · клик мышью тоже работает",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.55, 0.6))

func _draw_arrow(rect: Rect2, pointing_left: bool) -> void:
	var c = Color(0.85, 0.85, 0.9)
	var cx = rect.position.x + rect.size.x * 0.5
	var cy = rect.position.y + rect.size.y * 0.5
	var sz = 8.0
	if pointing_left:
		var pts = PackedVector2Array([
			Vector2(cx - sz, cy),
			Vector2(cx + sz * 0.5, cy - sz),
			Vector2(cx + sz * 0.5, cy + sz),
		])
		draw_node.draw_colored_polygon(pts, c)
	else:
		var pts = PackedVector2Array([
			Vector2(cx + sz, cy),
			Vector2(cx - sz * 0.5, cy - sz),
			Vector2(cx - sz * 0.5, cy + sz),
		])
		draw_node.draw_colored_polygon(pts, c)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":   return Color(0.32, 0.55, 0.95)
		"rare":       return Color(0.55, 0.30, 0.95)
		"epic":       return Color(0.92, 0.30, 0.85)
		"legendary":  return Color(1.00, 0.20, 0.15)
		"contraband": return Color(1.00, 0.85, 0.15)
	return Color(0.78, 0.78, 0.82)

func _rarity_label(rarity: String) -> String:
	match rarity:
		"uncommon":   return "MIL-SPEC"
		"rare":       return "RESTRICTED"
		"epic":       return "CLASSIFIED"
		"legendary":  return "COVERT"
		"contraband": return "★ CONTRABAND ★"
	return "CONSUMER"

func _time() -> float:
	return Time.get_ticks_msec() * 0.001
