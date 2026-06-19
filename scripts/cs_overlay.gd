extends CanvasLayer

# Единый оверлей CS-фич: killstreak / ACE / HEADSHOT / scope / inspect / case opening.
# Layer = 200 (поверх HUD-150, под смертельной катсценой-300).

var _draw_node: Node2D = null
var _time: float = 0.0

# ── ULTRAKILL-style Style Rank ──
# Очки стиля копятся с убийств / хедшотов / комбо.
# Они затухают со временем. По очкам определяется ранг: D → C → B → A → S → SS → SSS → U.
const STYLE_RANKS: Array = ["D", "C", "B", "A", "S", "SS", "SSS", "U"]
const STYLE_THRESHOLDS: Array = [0.0, 250.0, 600.0, 1100.0, 1700.0, 2500.0, 3600.0, 5000.0]
const STYLE_RANK_NAMES: Array = [
	"DESTRUCTIVE",
	"CHAOTIC",
	"BRUTAL",
	"ANARCHIC",
	"SUPREME",
	"SADISTIC",
	"SOULSLAYER",
	"ULTRAKILL",
]
const STYLE_RANK_COLORS: Array = [
	Color(0.70, 0.70, 0.75),   # D — серый
	Color(0.30, 0.65, 1.00),   # C — синий
	Color(0.30, 0.95, 0.30),   # B — зелёный
	Color(1.00, 0.95, 0.20),   # A — жёлтый
	Color(1.00, 0.55, 0.10),   # S — оранжевый
	Color(1.00, 0.20, 0.15),   # SS — красный
	Color(0.95, 0.10, 0.50),   # SSS — розово-кровавый
	Color(1.00, 1.00, 1.00),   # U — белый (ULTRAKILL!)
]

var style_points: float = 0.0
var _prev_rank_idx: int = -1
var _style_decay_base: float = 35.0     # минимум очков/сек когда нет действий
var _style_decay_grace: float = 1.6     # секунды бездействия пока не начинается затухание
var _style_grace_t: float = 0.0
var _rank_up_flash_t: float = 0.0       # вспышка при росте ранга
var _style_actions: Array = []          # [{text, points, life, max_life, color}]
const STYLE_ACTION_LIFE: float = 2.4

# ── Headshot popups (world-space) ──
var _headshots: Array = []   # [{world_pos, t, dur}]

# ── ACE banner ──
var _ace_t: float = -1.0
var _ace_dur: float = 3.0

# ── Inspect overlay ──
var _inspect_t: float = -1.0
var _inspect_dur: float = 0.0
var _inspect_weapon: Dictionary = {}

# ── Scope (AWP) ──
var _scope_active: bool = false
var _scope_t: float = 0.0  # анимация открытия

# ── Crosshair ──
var crosshair_style: int = 0  # 0=arrow(default), 1=dot, 2=cross, 3=t-shape, 4=x
var _show_crosshair_for_ranged: bool = false  # включается при дальнобойном оружии
var crosshair_world_pos: Vector2 = Vector2.ZERO  # позиция в мире (от игрока + aim dir)
var crosshair_aim_dir: Vector2 = Vector2.RIGHT

# === BHOP / Dash visuals ===
var bhop_stacks: int = 0           # текущие стэки (обновляются из player)
var bhop_trail: Array = []         # массив точек {pos, life, max_life, alpha_mult} (мировые)
var bhop_perfect_popups: Array = []  # [{world_pos, t, dur, stacks}]
var dash_charges: float = 3.0      # текущие чарджи
var dash_max_charges: int = 3
var _speed_world_pos: Vector2 = Vector2.ZERO  # позиция игрока в мире (для эффектов FOV)

# ── Flash effect (полноэкранная белая вспышка) ──
var _flash_t: float = -1.0
var _flash_dur: float = 0.7

# ── Case opening ──
var _case_active: bool = false
var _case_t: float = 0.0
var _case_items: Array = []           # массив словарей-весов [{weapon_id, rarity}]
var _case_offset: float = 0.0         # текущий горизонтальный сдвиг ленты
var _case_target_offset: float = 0.0
var _case_speed: float = 0.0
var _case_winner_idx: int = 0
var _case_phase: String = "rolling"   # rolling | reveal | done
var _case_reveal_t: float = 0.0
var _case_on_close: Callable           # вызывается с weapon_id когда игрок жмёт пробел


# === RARITY COLORS (CS-стиль) ===
const RARITY_COLORS: Dictionary = {
	"common":    Color(0.78, 0.78, 0.82),   # Consumer Grade — белый
	"uncommon":  Color(0.32, 0.55, 0.95),   # Mil-Spec — синий
	"rare":      Color(0.55, 0.30, 0.95),   # Restricted — фиолет
	"epic":      Color(0.92, 0.30, 0.85),   # Classified — розовый
	"legendary": Color(1.00, 0.20, 0.15),   # Covert — красный
	"contraband":Color(1.00, 0.85, 0.15),   # Contraband — золото
}
const RARITY_LABELS: Dictionary = {
	"common":    "CONSUMER GRADE",
	"uncommon":  "MIL-SPEC",
	"rare":      "RESTRICTED",
	"epic":      "CLASSIFIED",
	"legendary": "COVERT",
	"contraband":"★ CONTRABAND ★",
}

static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

static func rarity_label(rarity: String) -> String:
	return RARITY_LABELS.get(rarity, "")


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Node2D.new()
	_draw_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)


func _process(delta: float) -> void:
	_time += delta

	# === ULTRAKILL style decay ===
	if _style_grace_t > 0.0:
		_style_grace_t -= delta
	else:
		# Затухание зависит от текущего ранга — выше ранг = быстрее теряем
		var rank_idx = _get_rank_index()
		var decay_mult = 1.0 + rank_idx * 0.45
		style_points = max(0.0, style_points - _style_decay_base * decay_mult * delta)
	if _rank_up_flash_t > 0.0:
		_rank_up_flash_t -= delta
	# Обновляем "actions" (логи). .filter() создаёт лямбду+массив каждый вызов —
	# пропускаем когда список пуст (обычный случай вне боя).
	if _style_actions.size() > 0:
		for a in _style_actions:
			a.life -= delta
		_style_actions = _style_actions.filter(func(a): return a.life > 0.0)

	if _ace_t > 0.0:
		_ace_t -= delta
		if _ace_t <= 0.0:
			_ace_t = -1.0

	if _inspect_t > 0.0:
		_inspect_t -= delta
		if _inspect_t <= 0.0:
			_inspect_t = -1.0

	if _headshots.size() > 0:
		for h in _headshots:
			h.t -= delta
		_headshots = _headshots.filter(func(h): return h.t > 0.0)

	# BHOP trail decay
	if bhop_trail.size() > 0:
		for p in bhop_trail:
			p.life -= delta
		bhop_trail = bhop_trail.filter(func(p): return p.life > 0.0)
	if bhop_perfect_popups.size() > 0:
		for pp in bhop_perfect_popups:
			pp.t -= delta
		bhop_perfect_popups = bhop_perfect_popups.filter(func(pp): return pp.t > 0.0)

	if _scope_active:
		_scope_t = minf(1.0, _scope_t + delta * 5.0)
	else:
		_scope_t = maxf(0.0, _scope_t - delta * 6.0)

	if _flash_t > 0.0:
		_flash_t -= delta
	if _pickup_flash_t > 0.0:
		_pickup_flash_t -= delta

	if _case_active:
		_update_case(delta)

	# Throttle: рисуем через кадр — экономия CPU
	if Engine.get_process_frames() % 2 == 0:
		_draw_node.queue_redraw()


# ────────────────────────────────────────────────────────────────────────────
# API
# ────────────────────────────────────────────────────────────────────────────

# ULTRAKILL: главный API — add_style(amount, label, color)
func add_style(amount: float, label: String, color: Color = Color(1, 1, 1)) -> void:
	var prev_rank = _get_rank_index()
	style_points += amount
	_style_grace_t = _style_decay_grace
	_style_actions.push_front({
		"text": label,
		"points": int(amount),
		"life": STYLE_ACTION_LIFE,
		"max_life": STYLE_ACTION_LIFE,
		"color": color,
	})
	# Лимит на длину истории
	if _style_actions.size() > 6:
		_style_actions.resize(6)
	# Rank-up flash
	var new_rank = _get_rank_index()
	if new_rank > prev_rank:
		_rank_up_flash_t = 0.8

# Совместимость: старый API вызывается из main.gd при killstreak_changed
func show_killstreak(streak: int) -> void:
	if streak < 2:
		return
	# Чем выше стрик, тем больше очков
	var bonus = 25 + (streak - 2) * 15
	var rank_idx_now = _get_rank_index()
	var col = STYLE_RANK_COLORS[clampi(rank_idx_now, 0, STYLE_RANK_COLORS.size() - 1)]
	var label = "KILLSTREAK ×%d" % streak
	add_style(float(bonus), label, col)

func show_ace() -> void:
	_ace_t = _ace_dur
	# ACE = огромный кусок стиля
	add_style(500.0, "ACE — NO DAMAGE", Color(1.0, 0.85, 0.15))

func show_headshot(world_pos: Vector2) -> void:
	_headshots.append({"world_pos": world_pos, "t": 0.9, "dur": 0.9})
	add_style(75.0, "HEADSHOT", Color(1.0, 0.85, 0.15))

# Вызывается из главного скрипта при каждом обычном убийстве
func add_kill_style() -> void:
	add_style(50.0, "KILL", Color(0.85, 0.85, 0.92))

# === BHOP API ===
# Bhop НЕ добавляет очков стиля — он только СОХРАНЯЕТ текущий ранг
# (сбрасывает таймер затухания), плюс показывает попап и трейл.
# Иначе бы спам bhop'ом раскачивал ранг до ULTRAKILL без боя — имба.
func on_bhop_perfect(stacks: int, world_pos: Vector2) -> void:
	bhop_stacks = stacks
	# Освежаем grace-таймер чтобы текущий ранг не падал
	_style_grace_t = _style_decay_grace
	var col = Color(1.0, 0.9, 0.2)  # золото
	if stacks >= 5:
		col = Color(1.0, 0.4, 0.2)   # огонь
	if stacks >= 6:
		col = Color(1.0, 0.2, 0.9)   # ULTRA
	bhop_perfect_popups.append({
		"world_pos": world_pos + Vector2(0, -22),
		"t": 0.6,
		"dur": 0.6,
		"stacks": stacks,
		"color": col,
	})

func on_bhop_reset() -> void:
	bhop_stacks = 0

func update_dash(charges: float, max_charges: int) -> void:
	dash_charges = charges
	dash_max_charges = max_charges

func add_trail_point(world_pos: Vector2, life: float, alpha_mult: float) -> void:
	bhop_trail.append({
		"pos": world_pos,
		"life": life,
		"max_life": life,
		"alpha_mult": alpha_mult,
	})


func _get_rank_index() -> int:
	var idx = 0
	for i in STYLE_THRESHOLDS.size():
		if style_points >= STYLE_THRESHOLDS[i]:
			idx = i
	return idx

# Публичный геттер ранга для combo-наград (0=D ... 7=U)
func get_style_rank() -> int:
	return _get_rank_index()

func _get_rank_progress() -> float:
	# Прогресс внутри текущей рамки [threshold_curr .. threshold_next)
	var idx = _get_rank_index()
	if idx >= STYLE_THRESHOLDS.size() - 1:
		return 1.0
	var lo = STYLE_THRESHOLDS[idx]
	var hi = STYLE_THRESHOLDS[idx + 1]
	return clampf((style_points - lo) / max(1.0, hi - lo), 0.0, 1.0)

func show_inspect(weapon: Dictionary, duration: float = 2.4) -> void:
	_inspect_weapon = weapon
	_inspect_dur = duration
	_inspect_t = duration

func start_scope() -> void:
	_scope_active = true

func end_scope() -> void:
	_scope_active = false

func is_scoping() -> bool:
	return _scope_active or _scope_t > 0.05

func flash_screen(duration: float = 0.7) -> void:
	_flash_dur = duration
	_flash_t = duration

# Цветная вспышка при подбирании оружия — цвет рарности
var _pickup_flash_t: float = 0.0
var _pickup_flash_color: Color = Color.WHITE
func pickup_flash(color: Color, duration: float = 0.35) -> void:
	_pickup_flash_t = duration
	_pickup_flash_color = color

func set_crosshair_visible(visible_: bool) -> void:
	_show_crosshair_for_ranged = visible_

func show_case_opening(items: Array, winner_idx: int, on_close: Callable) -> void:
	_case_active = true
	_case_items = items
	_case_winner_idx = winner_idx
	_case_phase = "rolling"
	_case_t = 0.0
	_case_offset = 0.0
	_case_speed = 1400.0
	# Цель: сдвинуть так, чтобы winner_idx оказался в центре экрана
	var item_w = 110.0
	# Изначальная лента: winner_idx нужно увидеть после прокрутки минимум 30 элементов
	_case_target_offset = (winner_idx + items.size() * 3) * item_w
	_case_reveal_t = 0.0
	_case_on_close = on_close
	get_tree().paused = true

func _update_case(delta: float) -> void:
	if _case_phase == "rolling":
		# Эфф деселерация — двигаемся как затухающий импульс
		var remaining = _case_target_offset - _case_offset
		_case_speed = max(80.0, remaining * 0.7)  # быстрое начало → замедление
		var step = _case_speed * delta
		_case_offset += step
		# Лента "тикает" — звук был бы тут, но мы рисуем индикатор
		if remaining < 1.5:
			_case_offset = _case_target_offset
			_case_phase = "reveal"
			_case_reveal_t = 0.0
	elif _case_phase == "reveal":
		_case_reveal_t += delta
		# Закрывается на пробел/Enter в _input
	# done — ждёт ввод

func _input(event: InputEvent) -> void:
	if _case_active and _case_phase == "reveal":
		if event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			# Забрать оружие
			var winner_id = _case_items[_case_winner_idx].get("weapon_id", 1)
			_case_active = false
			get_tree().paused = false
			get_viewport().set_input_as_handled()
			if _case_on_close.is_valid():
				_case_on_close.call(winner_id)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			# Пропустить — НЕ забирать (-1 = ничего не экипировать)
			_case_active = false
			get_tree().paused = false
			get_viewport().set_input_as_handled()
			if _case_on_close.is_valid():
				_case_on_close.call(-1)


# ────────────────────────────────────────────────────────────────────────────
# DRAW
# ────────────────────────────────────────────────────────────────────────────

func _on_draw() -> void:
	var vs = _viewport_size()
	var vp = get_viewport()
	var ct = vp.get_canvas_transform() if vp else Transform2D.IDENTITY

	# BHOP trail (мировые точки)
	if bhop_trail.size() > 0:
		_draw_bhop_trail(ct)

	# BHOP "PERFECT" попапы
	if bhop_perfect_popups.size() > 0:
		_draw_bhop_popups(ct)

	# Headshot popups (на мировые координаты)
	if _headshots.size() > 0:
		for h in _headshots:
			var screen_pos = ct * h.world_pos
			_draw_headshot_popup(screen_pos, h.t / h.dur)

	# ULTRAKILL style rank (если есть очки стиля)
	if style_points > 0.0 or _rank_up_flash_t > 0.0:
		_draw_style_rank(vs)

	# Dash charges в углу (CS-стиль слотов)
	_draw_dash_charges(vs)
	# BHOP speed-bar
	if bhop_stacks > 0:
		_draw_bhop_speed(vs)

	# ACE
	if _ace_t > 0.0:
		_draw_ace(vs)

	# Inspect
	if _inspect_t > 0.0:
		_draw_inspect(vs)

	# Scope (AWP)
	if _scope_t > 0.0:
		_draw_scope(vs)

	# Crosshair для дальнобойного оружия (если не в режиме scope)
	if _show_crosshair_for_ranged and not is_scoping() and crosshair_style != 0:
		_draw_crosshair(vs)

	# Case opening
	if _case_active:
		_draw_case(vs)

	# Flashbang
	if _flash_t > 0.0:
		var phase = _flash_t / _flash_dur
		var a = clampf(phase * 1.5, 0.0, 1.0)
		_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y), Color(1, 1, 1, a))

	# Pickup flash — лёгкая цветная вспышка по рарности оружия
	if _pickup_flash_t > 0.0:
		var pf = _pickup_flash_t / 0.35
		var pa = sin(pf * PI) * 0.30
		_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y),
			Color(_pickup_flash_color.r, _pickup_flash_color.g, _pickup_flash_color.b, pa))
		# По краям сильнее (виньетка-flash)
		_draw_node.draw_rect(Rect2(0, 0, 30, vs.y),
			Color(_pickup_flash_color.r, _pickup_flash_color.g, _pickup_flash_color.b, pa * 1.2))
		_draw_node.draw_rect(Rect2(vs.x - 30, 0, 30, vs.y),
			Color(_pickup_flash_color.r, _pickup_flash_color.g, _pickup_flash_color.b, pa * 1.2))

# ── ULTRAKILL-style Style Rank (буквы D/C/B/A/S/SS/SSS/U справа) ──
func _draw_style_rank(vs: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var rank_idx = _get_rank_index()
	var rank_letter: String = STYLE_RANKS[rank_idx]
	var rank_name: String = STYLE_RANK_NAMES[rank_idx]
	var rank_col: Color = STYLE_RANK_COLORS[rank_idx]
	var progress = _get_rank_progress()

	# Базовая alpha — чем меньше очков, тем прозрачнее (на низком стиле почти не мешает)
	var base_alpha = clampf(style_points / 80.0, 0.0, 1.0)
	# Rank-up вспышка
	var flash = clampf(_rank_up_flash_t / 0.8, 0.0, 1.0)
	var flash_alpha = flash * 0.85

	# Позиция: правый край, чуть выше центра
	var anchor_x = vs.x - 30.0
	var anchor_y = vs.y * 0.40

	# === Большая буква ранга (~110pt) ===
	# Дополнительный размер из-за rank-up flash
	var letter_fsize = int(110 + flash * 20)
	var letter_size = font.get_string_size(rank_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_fsize)
	var lx = anchor_x - letter_size.x
	var ly = anchor_y

	# Чёрная "плита" подложка за буквой (как в ULTRAKILL — слегка наклонённый прямоугольник)
	var plate_w = letter_size.x + 22
	var plate_h = 78.0
	# Тёмный фон
	_draw_node.draw_rect(Rect2(lx - 10, ly - plate_h + 6, plate_w, plate_h),
		Color(0.04, 0.04, 0.06, base_alpha * 0.78))
	# Цветная полоса слева (рарность ранга)
	_draw_node.draw_rect(Rect2(lx - 10, ly - plate_h + 6, 4, plate_h),
		Color(rank_col.r, rank_col.g, rank_col.b, base_alpha))
	# Вспышка фона при подъёме ранга
	if flash > 0.0:
		_draw_node.draw_rect(Rect2(lx - 14, ly - plate_h + 2, plate_w + 8, plate_h + 8),
			Color(rank_col.r, rank_col.g, rank_col.b, flash_alpha * 0.35))

	# Жирная "тень-обводка" за буквой
	for ox in [-3, -2, -1, 0, 1, 2, 3]:
		for oy in [-3, -2, -1, 0, 1, 2, 3]:
			if abs(ox) + abs(oy) <= 1: continue
			_draw_node.draw_string(font, Vector2(lx + ox, ly + oy),
				rank_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_fsize,
				Color(0, 0, 0, base_alpha * 0.55))
	# Сама буква (цвет ранга)
	_draw_node.draw_string(font, Vector2(lx, ly),
		rank_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_fsize,
		Color(rank_col.r, rank_col.g, rank_col.b, clampf(base_alpha + flash * 0.5, 0.0, 1.0)))

	# === Название ранга (мелким, под буквой) ===
	var name_fsize = 14
	var n_size = font.get_string_size(rank_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fsize)
	var name_x = anchor_x - n_size.x
	var name_y = ly + 16
	# Обводка
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0: continue
			_draw_node.draw_string(font, Vector2(name_x + ox, name_y + oy),
				rank_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fsize,
				Color(0, 0, 0, base_alpha))
	_draw_node.draw_string(font, Vector2(name_x, name_y),
		rank_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fsize,
		Color(rank_col.r, rank_col.g, rank_col.b, base_alpha))

	# === Прогресс-бар к следующему рангу (вертикальный, слева от плиты) ===
	var bar_x = lx - 18
	var bar_y = ly - plate_h + 8
	var bar_w = 4.0
	var bar_h = plate_h - 8.0
	# Фон
	_draw_node.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h),
		Color(0.1, 0.1, 0.12, base_alpha * 0.7))
	# Заполнение снизу вверх
	var fill_h = bar_h * progress
	_draw_node.draw_rect(Rect2(bar_x, bar_y + bar_h - fill_h, bar_w, fill_h),
		Color(rank_col.r, rank_col.g, rank_col.b, base_alpha * 0.95))

	# === Цифра очков под названием ===
	var pts_text = "%d" % int(style_points)
	var p_size = font.get_string_size(pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var p_x = anchor_x - p_size.x
	var p_y = name_y + 16
	_draw_node.draw_string(font, Vector2(p_x, p_y),
		pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.85, 0.85, 0.88, base_alpha * 0.85))

	# === Combo-бонус: что даёт текущий ранг ===
	var bonus_text = ""
	if rank_idx >= 4:
		bonus_text = "+УРОН +ВАМПИРИЗМ"
	elif rank_idx >= 1:
		bonus_text = "+УРОН"
	if bonus_text != "":
		var b_size = font.get_string_size(bonus_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		_draw_node.draw_string(font, Vector2(anchor_x - b_size.x, p_y + 13),
			bonus_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(rank_col.r, rank_col.g, rank_col.b, base_alpha * 0.8))

	# === Лог действий (всплывают и тают, выше плиты) ===
	var log_x = anchor_x
	var log_y = ly - plate_h - 4
	for i in _style_actions.size():
		var a = _style_actions[i]
		var life_frac = a.life / a.max_life
		# Появление+уход
		var fade_in = clampf((1.0 - life_frac) / 0.15, 0.0, 1.0)
		var fade_out = clampf(life_frac / 0.4, 0.0, 1.0)
		var act_alpha = fade_in * fade_out
		# Текст: "+50 KILL"
		var line = "+%d  %s" % [a.points, a.text]
		var line_fsize = 14
		var line_size = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_fsize)
		var line_x = log_x - line_size.x
		var line_y = log_y - i * 18 - (1.0 - life_frac) * 4.0  # лёгкое всплытие
		# Чёрная обводка
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				if ox == 0 and oy == 0: continue
				_draw_node.draw_string(font, Vector2(line_x + ox, line_y + oy),
					line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_fsize,
					Color(0, 0, 0, act_alpha * 0.85))
		# Цветной текст
		_draw_node.draw_string(font, Vector2(line_x, line_y),
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_fsize,
			Color(a.color.r, a.color.g, a.color.b, act_alpha))

# ── ACE ──
func _draw_ace(vs: Vector2) -> void:
	var prog = 1.0 - _ace_t / _ace_dur
	var scale_in = clampf(prog / 0.20, 0.0, 1.0)
	var fade_out = clampf(_ace_t / 0.7, 0.0, 1.0)
	var alpha = scale_in * fade_out
	var cx = vs.x * 0.5
	var cy = vs.y * 0.45
	var font := ThemeDB.fallback_font
	# Золотая рамка
	var box_w = 280.0
	var box_h = 90.0
	# тёмная подложка
	_draw_node.draw_rect(Rect2(cx - box_w * 0.5, cy - box_h * 0.5, box_w, box_h),
		Color(0.02, 0.02, 0.02, alpha * 0.78))
	# золотая внутренняя рамка
	_draw_node.draw_rect(Rect2(cx - box_w * 0.5, cy - box_h * 0.5, box_w, box_h),
		Color(1.0, 0.85, 0.15, alpha), false, 2.5)
	# текст
	var fsize_ace = 56
	var ace_text = "ACE"
	var ace_size = font.get_string_size(ace_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize_ace)
	# обводка
	for ox in [-2, -1, 0, 1, 2]:
		for oy in [-2, -1, 0, 1, 2]:
			_draw_node.draw_string(font, Vector2(cx - ace_size.x * 0.5 + ox, cy + 6 + oy),
				ace_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize_ace,
				Color(0, 0, 0, alpha * 0.85))
	_draw_node.draw_string(font, Vector2(cx - ace_size.x * 0.5, cy + 6),
		ace_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize_ace,
		Color(1.0, 0.85, 0.15, alpha))
	# подпись
	var sub = "Зачищено без урона"
	var sub_size = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	_draw_node.draw_string(font, Vector2(cx - sub_size.x * 0.5, cy + 28),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(1, 1, 1, alpha * 0.7))

# ── BHOP trail (полупрозрачные кружки-силуэты позади игрока) ──
func _draw_bhop_trail(ct: Transform2D) -> void:
	# Цвет зависит от текущих стэков
	var base_col := Color(1.0, 0.85, 0.15)  # 2-3 стэка золото
	if bhop_stacks >= 4:
		base_col = Color(1.0, 0.45, 0.15)   # 4-5 огонь
	if bhop_stacks >= 6:
		base_col = Color(1.0, 0.20, 0.85)   # 6 ULTRA розовый
	for p in bhop_trail:
		var life_frac = p.life / p.max_life
		var screen_p = ct * p.pos
		# Мягкий "след" — полупрозрачный круг с радужным glow
		var alpha = life_frac * 0.45 * p.alpha_mult
		_draw_node.draw_circle(screen_p + Vector2(0, -10),
			9.0 + (1.0 - life_frac) * 4.0,
			Color(base_col.r, base_col.g, base_col.b, alpha))
		# Ядро поярче
		_draw_node.draw_circle(screen_p + Vector2(0, -10),
			4.0 * life_frac,
			Color(1, 1, 1, alpha * 1.3))

# ── Dash зарядки (в нижнем правом углу, как магазин в CS) ──
func _draw_dash_charges(vs: Vector2) -> void:
	var slot_w = 14.0
	var slot_h = 4.0
	var gap = 3.0
	var total_w = dash_max_charges * slot_w + (dash_max_charges - 1) * gap
	var x0 = vs.x - total_w - 12.0
	var y0 = vs.y - 24.0
	var font := ThemeDB.fallback_font
	# Лейбл
	_draw_node.draw_string(font, Vector2(x0 - 30, y0 + 12),
		"DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.85, 0.92, 0.75))
	# Слоты
	for i in dash_max_charges:
		var sx = x0 + i * (slot_w + gap)
		# Фон
		_draw_node.draw_rect(Rect2(sx, y0 + 6, slot_w, slot_h),
			Color(0.08, 0.08, 0.12, 0.75))
		# Заполнение — дробное если идёт перезарядка
		var fill_frac = clampf(dash_charges - float(i), 0.0, 1.0)
		if fill_frac > 0.0:
			# Цвет: золото если заряд готов, оранжевый если идёт перезарядка
			var col = Color(1.0, 0.85, 0.20) if fill_frac >= 1.0 else Color(1.0, 0.55, 0.10)
			_draw_node.draw_rect(Rect2(sx, y0 + 6, slot_w * fill_frac, slot_h), col)
		# Тонкая рамка
		_draw_node.draw_rect(Rect2(sx, y0 + 6, slot_w, slot_h),
			Color(0.6, 0.6, 0.65, 0.5), false, 1.0)

# ── BHOP speed bar (под HP-баром) ──
func _draw_bhop_speed(vs: Vector2) -> void:
	var bar_x = 10.0
	var bar_y = 108.0
	var bar_w = 160.0
	var bar_h = 6.0
	# Фон
	_draw_node.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h),
		Color(0.08, 0.08, 0.10, 0.8))
	# Заполнение — пропорционально стэкам
	var max_stacks = 6.0
	var frac = clampf(float(bhop_stacks) / max_stacks, 0.0, 1.0)
	# Цвет градиентом по стэкам
	var col = Color(1.0, 0.85, 0.20)
	if bhop_stacks >= 4:
		col = Color(1.0, 0.45, 0.15)
	if bhop_stacks >= 6:
		col = Color(1.0, 0.20, 0.85)
	_draw_node.draw_rect(Rect2(bar_x, bar_y, bar_w * frac, bar_h), col)
	# Тонкие деления между стэками
	for i in range(1, 6):
		var x = bar_x + bar_w * (float(i) / max_stacks)
		_draw_node.draw_line(Vector2(x, bar_y), Vector2(x, bar_y + bar_h),
			Color(0, 0, 0, 0.55), 1.0)
	# Текст справа: "BHOP ×N" + % скорости
	var font := ThemeDB.fallback_font
	var pct = int(bhop_stacks * 15)
	var txt = "BHOP ×%d  +%d%%" % [bhop_stacks, pct]
	# Чёрная обводка
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0: continue
			_draw_node.draw_string(font, Vector2(bar_x + ox, bar_y - 4 + oy),
				txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.85))
	_draw_node.draw_string(font, Vector2(bar_x, bar_y - 4),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)

# ── BHOP "PERFECT" попапы ──
func _draw_bhop_popups(ct: Transform2D) -> void:
	var font := ThemeDB.fallback_font
	for pp in bhop_perfect_popups:
		var life_frac = pp.t / pp.dur
		var rise = (1.0 - life_frac) * 18.0
		var alpha = clampf(life_frac * 1.8, 0.0, 1.0)
		var screen_p = ct * pp.world_pos
		var txt = "PERFECT"
		if pp.stacks >= 4:
			txt = "PERFECT ×%d" % pp.stacks
		var fsize = 14
		var s_size = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var x = screen_p.x - s_size.x * 0.5
		var y = screen_p.y - rise
		# Чёрная обводка
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				if ox == 0 and oy == 0: continue
				_draw_node.draw_string(font, Vector2(x + ox, y + oy),
					txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
					Color(0, 0, 0, alpha * 0.85))
		_draw_node.draw_string(font, Vector2(x, y),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
			Color(pp.color.r, pp.color.g, pp.color.b, alpha))

# ── Headshot popup ──
func _draw_headshot_popup(pos: Vector2, life_frac: float) -> void:
	var rise = (1.0 - life_frac) * 26.0  # поднимается вверх
	var alpha = clampf(life_frac * 1.6, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var fsize = 13
	var txt = "HEADSHOT"
	var size = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var x = pos.x - size.x * 0.5
	var y = pos.y - 26 - rise
	# Чёрная обводка
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0: continue
			_draw_node.draw_string(font, Vector2(x + ox, y + oy),
				txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, alpha))
	# Жёлтый текст
	_draw_node.draw_string(font, Vector2(x, y),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
		Color(1.0, 0.85, 0.10, alpha))
	# Маленькая иконка-череп слева
	var sx = x - 12
	var sy = y - 8
	_draw_node.draw_circle(Vector2(sx, sy + 4), 4, Color(0.95, 0.92, 0.8, alpha))
	_draw_node.draw_circle(Vector2(sx - 1.5, sy + 3), 0.9, Color(0, 0, 0, alpha))
	_draw_node.draw_circle(Vector2(sx + 1.5, sy + 3), 0.9, Color(0, 0, 0, alpha))

# ── Inspect ──
func _draw_inspect(vs: Vector2) -> void:
	var prog = 1.0 - _inspect_t / _inspect_dur
	var fade_in = clampf(prog / 0.20, 0.0, 1.0)
	var fade_out = clampf(_inspect_t / 0.30, 0.0, 1.0)
	var alpha = fade_in * fade_out
	# Затемнение фона
	_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y),
		Color(0, 0, 0, alpha * 0.55))

	# Карточка оружия
	var cx = vs.x * 0.5
	var cy = vs.y * 0.5
	var box_w = 360.0
	var box_h = 200.0
	var rarity = _inspect_weapon.get("rarity", "common")
	var rar_col = rarity_color(rarity)

	# Тёмная подложка
	_draw_node.draw_rect(Rect2(cx - box_w * 0.5, cy - box_h * 0.5, box_w, box_h),
		Color(0.05, 0.05, 0.07, alpha * 0.95))
	# Цветная рамка рарности
	_draw_node.draw_rect(Rect2(cx - box_w * 0.5, cy - box_h * 0.5, box_w, box_h),
		Color(rar_col.r, rar_col.g, rar_col.b, alpha), false, 2.5)
	# Цветная полоса сверху (как в CS UI)
	_draw_node.draw_rect(Rect2(cx - box_w * 0.5 + 2, cy - box_h * 0.5 + 2, box_w - 4, 22),
		Color(rar_col.r, rar_col.g, rar_col.b, alpha * 0.75))

	# Лейбл рарности (на верхней полосе)
	var font := ThemeDB.fallback_font
	var rar_text = rarity_label(rarity)
	var rar_size = font.get_string_size(rar_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	_draw_node.draw_string(font, Vector2(cx - rar_size.x * 0.5, cy - box_h * 0.5 + 17),
		rar_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0, 0, 0, alpha))

	# Название оружия
	var name_text = _inspect_weapon.get("name", "Оружие")
	var n_size = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	_draw_node.draw_string(font, Vector2(cx - n_size.x * 0.5, cy - 36),
		name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color(1, 1, 1, alpha))

	# Вращающийся силуэт оружия — простой прямоугольник по color оружия
	var spin = (_inspect_dur - _inspect_t) * 3.0  # медленное вращение
	var w_col = _inspect_weapon.get("color", Color.WHITE)
	var blade_len = _inspect_weapon.get("blade_len", 22)
	# Эффект свечения
	var glow_col = _inspect_weapon.get("glow", Color(1, 1, 1, 0))
	_draw_node.draw_circle(Vector2(cx, cy + 5), blade_len * 1.4,
		Color(glow_col.r, glow_col.g, glow_col.b, glow_col.a * alpha * 0.6))
	# Сам "клинок" — поворачивается
	_draw_node.draw_set_transform(Vector2(cx, cy + 5), spin, Vector2.ONE)
	_draw_node.draw_rect(Rect2(-blade_len * 0.5, -2, blade_len, 4),
		Color(w_col.r, w_col.g, w_col.b, alpha))
	_draw_node.draw_rect(Rect2(blade_len * 0.5 - 3, -3, 3, 6),
		Color(0.45, 0.30, 0.15, alpha))  # рукоять
	_draw_node.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Damage / Cooldown инфа
	var dmg = _inspect_weapon.get("damage", 0)
	var cd = _inspect_weapon.get("cooldown", 0.0)
	var stats = "УРОН %d   ⏱ %.2fс" % [dmg, cd]
	var s_size = font.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	_draw_node.draw_string(font, Vector2(cx - s_size.x * 0.5, cy + 60),
		stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.85, 0.85, 0.85, alpha))

# ── Scope (AWP) ──
func _draw_scope(vs: Vector2) -> void:
	var k = _scope_t
	# Чёрные полосы сверху/снизу
	var bar_h = vs.y * 0.5 * k
	_draw_node.draw_rect(Rect2(0, 0, vs.x, bar_h), Color(0, 0, 0, 1))
	_draw_node.draw_rect(Rect2(0, vs.y - bar_h, vs.x, bar_h), Color(0, 0, 0, 1))
	# Центральная "трубка прицела" — большой круг и прицельные линии
	var cx = vs.x * 0.5
	var cy = vs.y * 0.5
	var radius = vs.y * 0.42
	# Тонкие чёрные углы (виньетка кругом)
	for r_step in 18:
		var rr = radius + r_step * 8
		var ac = 0.06 * k
		# Внешние "уголки" — заполняем прямоугольниками вокруг круга
		_draw_node.draw_arc(Vector2(cx, cy), rr, 0.0, TAU, 64,
			Color(0, 0, 0, ac), 9.0)
	# Тонкое чёрное кольцо
	_draw_node.draw_arc(Vector2(cx, cy), radius, 0.0, TAU, 80,
		Color(0, 0, 0, 0.95 * k), 3.0)
	_draw_node.draw_arc(Vector2(cx, cy), radius - 2, 0.0, TAU, 80,
		Color(0.05, 0.05, 0.05, 0.9 * k), 1.5)
	# Перекрестие
	var cross_col = Color(0, 0, 0, 0.95 * k)
	# Длинные горизонтальные линии (с разрывом по центру)
	_draw_node.draw_line(Vector2(cx - radius, cy), Vector2(cx - 12, cy), cross_col, 1.5)
	_draw_node.draw_line(Vector2(cx + 12, cy), Vector2(cx + radius, cy), cross_col, 1.5)
	# Длинные вертикальные
	_draw_node.draw_line(Vector2(cx, cy - radius), Vector2(cx, cy - 12), cross_col, 1.5)
	_draw_node.draw_line(Vector2(cx, cy + 12), Vector2(cx, cy + radius), cross_col, 1.5)
	# Маленький "точечный" центр
	_draw_node.draw_rect(Rect2(cx - 1, cy - 1, 2, 2), Color(0.1, 1.0, 0.2, k * 0.9))
	# Метки шкалы
	var font := ThemeDB.fallback_font
	for i in range(-4, 5):
		if i == 0: continue
		var mark_y = cy + i * (radius * 0.15)
		_draw_node.draw_line(Vector2(cx - 6, mark_y), Vector2(cx + 6, mark_y),
			cross_col, 1.0)

# ── Crosshair (кастомизируемый, в мире за игроком) ──
func _draw_crosshair(vs: Vector2) -> void:
	var vp = get_viewport()
	if not vp:
		return
	var ct = vp.get_canvas_transform()
	# Позиция прицела в экранных координатах — мировая точка ahead направления
	var screen_pos = ct * crosshair_world_pos
	var col = Color(0.30, 1.0, 0.30, 0.85)
	var sz = 8.0
	match crosshair_style:
		1:  # dot
			_draw_node.draw_circle(screen_pos, 1.6, col)
			_draw_node.draw_circle(screen_pos, 0.9, Color(1, 1, 1, 0.9))
		2:  # cross — классический CS-крест
			_draw_node.draw_line(Vector2(screen_pos.x - sz, screen_pos.y),
				Vector2(screen_pos.x - 2, screen_pos.y), col, 1.5)
			_draw_node.draw_line(Vector2(screen_pos.x + 2, screen_pos.y),
				Vector2(screen_pos.x + sz, screen_pos.y), col, 1.5)
			_draw_node.draw_line(Vector2(screen_pos.x, screen_pos.y - sz),
				Vector2(screen_pos.x, screen_pos.y - 2), col, 1.5)
			_draw_node.draw_line(Vector2(screen_pos.x, screen_pos.y + 2),
				Vector2(screen_pos.x, screen_pos.y + sz), col, 1.5)
		3:  # t-shape (без нижней)
			_draw_node.draw_line(Vector2(screen_pos.x - sz, screen_pos.y),
				Vector2(screen_pos.x - 2, screen_pos.y), col, 1.5)
			_draw_node.draw_line(Vector2(screen_pos.x + 2, screen_pos.y),
				Vector2(screen_pos.x + sz, screen_pos.y), col, 1.5)
			_draw_node.draw_line(Vector2(screen_pos.x, screen_pos.y - sz),
				Vector2(screen_pos.x, screen_pos.y - 2), col, 1.5)
		4:  # X
			_draw_node.draw_line(Vector2(screen_pos.x - sz, screen_pos.y - sz),
				Vector2(screen_pos.x - 2, screen_pos.y - 2), col, 1.5)
			_draw_node.draw_line(Vector2(screen_pos.x + 2, screen_pos.y + 2),
				Vector2(screen_pos.x + sz, screen_pos.y + sz), col, 1.5)
			_draw_node.draw_line(Vector2(screen_pos.x - sz, screen_pos.y + sz),
				Vector2(screen_pos.x - 2, screen_pos.y + 2), col, 1.5)
			_draw_node.draw_line(Vector2(screen_pos.x + 2, screen_pos.y - 2),
				Vector2(screen_pos.x + sz, screen_pos.y - sz), col, 1.5)

# ── Case opening ──
func _draw_case(vs: Vector2) -> void:
	# Полное затемнение
	_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0, 0, 0, 0.88))
	var cx = vs.x * 0.5
	var cy = vs.y * 0.5
	var font := ThemeDB.fallback_font

	if _case_phase == "rolling":
		var title = "ОТКРЫТИЕ КЕЙСА"
		var t_size = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		_draw_node.draw_string(font, Vector2(cx - t_size.x * 0.5, cy - 130),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.95))

		var item_w = 110.0
		var item_h = 90.0
		var strip_y = cy - item_h * 0.5
		# Маска по бокам — затемнение
		_draw_node.draw_rect(Rect2(0, strip_y - 6, vs.x, item_h + 12),
			Color(0.03, 0.03, 0.05, 0.95))
		# Жёлтая стрелка-указатель сверху и снизу центра
		var arr = PackedVector2Array([
			Vector2(cx, strip_y - 6),
			Vector2(cx - 8, strip_y - 18),
			Vector2(cx + 8, strip_y - 18),
		])
		_draw_node.draw_colored_polygon(arr, Color(1, 0.85, 0.15))
		var arr2 = PackedVector2Array([
			Vector2(cx, strip_y + item_h + 6),
			Vector2(cx - 8, strip_y + item_h + 18),
			Vector2(cx + 8, strip_y + item_h + 18),
		])
		_draw_node.draw_colored_polygon(arr2, Color(1, 0.85, 0.15))

		# Лента предметов
		var item_count = _case_items.size()
		# Сколько слотов помещается на экране
		var slots_visible = int(vs.x / item_w) + 4
		var start_slot = int(_case_offset / item_w) - slots_visible / 2
		for s in range(start_slot, start_slot + slots_visible):
			var slot_x = cx + (s * item_w - _case_offset)
			if slot_x < -item_w or slot_x > vs.x + item_w:
				continue
			# Берём элемент циклически
			var item_idx = ((s % item_count) + item_count) % item_count
			var item = _case_items[item_idx]
			_draw_case_card(Vector2(slot_x, strip_y), Vector2(item_w - 4, item_h), item)
	elif _case_phase == "reveal":
		var winner = _case_items[_case_winner_idx]
		var rar = winner.get("rarity", "common")
		var rar_col = rarity_color(rar)
		# Большая карточка-наградa
		var card_w = 360.0
		var card_h = 220.0
		_draw_node.draw_rect(Rect2(cx - card_w * 0.5, cy - card_h * 0.5, card_w, card_h),
			Color(0.05, 0.05, 0.08, 0.95))
		_draw_node.draw_rect(Rect2(cx - card_w * 0.5, cy - card_h * 0.5, card_w, card_h),
			rar_col, false, 3.0)
		# Лучи света из центра
		var beam_a = 0.3 + 0.1 * sin(_case_reveal_t * 4.0)
		for i in 12:
			var ang = float(i) / 12.0 * TAU + _case_reveal_t * 0.4
			var bx = cx + cos(ang) * card_w * 0.6
			var by = cy + sin(ang) * card_h * 0.6
			_draw_node.draw_line(Vector2(cx, cy), Vector2(bx, by),
				Color(rar_col.r, rar_col.g, rar_col.b, beam_a), 2.0)
		# Поверх — карточка ещё раз для затирания лучей
		_draw_node.draw_rect(Rect2(cx - card_w * 0.5, cy - card_h * 0.5, card_w, card_h),
			Color(0.05, 0.05, 0.08, 0.92))
		_draw_node.draw_rect(Rect2(cx - card_w * 0.5, cy - card_h * 0.5, card_w, card_h),
			rar_col, false, 3.0)
		# Текст рарности
		var rar_text = rarity_label(rar)
		var rar_size = font.get_string_size(rar_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		_draw_node.draw_string(font, Vector2(cx - rar_size.x * 0.5, cy - 70),
			rar_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, rar_col)
		# Название
		var name = winner.get("name", "")
		var n_size = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		_draw_node.draw_string(font, Vector2(cx - n_size.x * 0.5, cy - 40),
			name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))
		# "Силуэт" оружия — кружок цвета
		var w_col = winner.get("color", Color.WHITE)
		var glow_col = winner.get("glow", Color(1, 1, 1, 0))
		_draw_node.draw_circle(Vector2(cx, cy + 20), 36,
			Color(glow_col.r, glow_col.g, glow_col.b, glow_col.a * 0.7))
		_draw_node.draw_rect(Rect2(cx - 22, cy + 18, 44, 5), w_col)
		# Подсказка
		_draw_node.draw_string(font, Vector2(cx - 120, cy + 90),
			"[ПРОБЕЛ] забрать    [ESC] оставить своё", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(1, 1, 1, 0.7 + 0.3 * sin(_case_reveal_t * 6.0)))

func _draw_case_card(pos: Vector2, size: Vector2, item: Dictionary) -> void:
	var rar = item.get("rarity", "common")
	var rar_col = rarity_color(rar)
	# Карточка фон
	_draw_node.draw_rect(Rect2(pos.x + 2, pos.y, size.x, size.y),
		Color(0.08, 0.08, 0.12, 0.95))
	# Цветная полоска снизу по рарности (как в CS)
	_draw_node.draw_rect(Rect2(pos.x + 2, pos.y + size.y - 5, size.x, 5),
		rar_col)
	# Кружок-иконка
	var w_col = item.get("color", Color.WHITE)
	_draw_node.draw_circle(Vector2(pos.x + size.x * 0.5 + 2, pos.y + size.y * 0.35),
		14, w_col)
	# Название
	var font := ThemeDB.fallback_font
	var name = item.get("name", "")
	var n_size = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	_draw_node.draw_string(font, Vector2(pos.x + size.x * 0.5 + 2 - n_size.x * 0.5, pos.y + size.y * 0.7),
		name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))


func _viewport_size() -> Vector2:
	var vp = get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return Vector2(1280, 720)
