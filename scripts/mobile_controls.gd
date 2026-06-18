extends CanvasLayer

# === Мобильные виртуальные кнопки управления ===
# Показываются только на сенсорных устройствах (Android/iOS).
# Координаты — в логическом пространстве вьюпорта (stretch=canvas_items),
# поэтому позиции тача и отрисовка всегда совпадают.

var draw_node: Control = null

# Логический размер вьюпорта (из project settings, стабилен при canvas_items)
var vw: float = 1280.0
var vh: float = 768.0

# Описание кнопок храним обычными словарями (без типизированного inner-class,
# чтобы избежать проблем с аннотациями типов).
var buttons: Array = []          # [{rect, label, action, special, pressed, tid}]
var touch_map: Dictionary = {}   # touch_id -> индекс кнопки

# Кнопки активны только во время игры. В меню они скрыты, чтобы не
# перехватывать тач у кнопок меню ("ПРОСТО НАЧАТЬ" и т.п.).
var active: bool = false

const ALPHA_IDLE: float    = 0.40
const ALPHA_PRESSED: float = 0.80

# Показать/скрыть игровые кнопки. Вызывается из main.gd при старте игры и
# при возврате в меню.
func set_active(a: bool) -> void:
	active = a
	if draw_node:
		draw_node.visible = a
	if not a:
		# Сбрасываем все зажатия, чтобы движение не "залипло"
		for b in buttons:
			if b["pressed"]:
				b["pressed"] = false
				b["tid"] = -1
				_fire_release_all(b)
		touch_map.clear()
		if draw_node:
			draw_node.queue_redraw()

func _fire_release_all(b) -> void:
	if b["action"] != "":
		_send_action(b["action"], false)
	elif b["special"] != "":
		_send_special(b["special"], false)

func _ready() -> void:
	# Только сенсорные устройства
	if not (OS.has_feature("mobile") or OS.get_name() == "Android"
			or OS.get_name() == "iOS" or DisplayServer.is_touchscreen_available()):
		queue_free()
		return

	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Берём логический размер вьюпорта из настроек проекта
	vw = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	vh = float(ProjectSettings.get_setting("display/window/size/viewport_height", 768))

	draw_node = Control.new()
	draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

	_create_buttons()
	# Стартуем скрытыми — main.gd включит при старте игры
	draw_node.visible = active

func _create_buttons() -> void:
	# Раскладка в духе Dead Cells: слева — крупные ←/→ под большой палец и
	# отдельные ↑/↓ для лестниц/спуска; справа — кластер действий, где
	# Прыжок и Атака самые большие и в зоне досягаемости пальца.
	buttons.clear()

	var pad := 30.0
	var gap := 14.0
	var H := vh
	var W := vw

	# ════════ ЛЕВО — движение ════════
	# Большие ←/→ внизу, рядом; ↑/↓ — пара повыше слева.
	var mw := 132.0   # ширина крупной кнопки движения
	var mh := 124.0   # высота
	var left_x := pad
	var right_x := pad + mw + gap
	var move_y := H - pad - mh

	_add(Rect2(left_x,  move_y, mw, mh), "◀", "move_left", "")
	_add(Rect2(right_x, move_y, mw, mh), "▶", "move_right", "")

	# ↑ (лезть по лестнице) и ↓ (спуск/слезть) — над движением
	var uw := 100.0
	var uh := 82.0
	var up_y := move_y - gap - uh
	_add(Rect2(left_x,            up_y, uw, uh), "▲", "move_up", "")
	_add(Rect2(left_x + uw + gap, up_y, uw, uh), "▼", "move_down", "")

	# ════════ ПРАВО — действия ════════
	# Бриллиант: ПРЫЖОК (низ-право) и АТАКА (слева от него) — крупные.
	# РЫВОК и СПЕЦ — повыше. ЛЕЧ и E — маленькие сверху.
	var jbs := 132.0   # Прыжок — самая большая
	var abs_ := 120.0  # Атака — большая
	var mbs := 92.0    # рывок / спец
	var ssb := 76.0    # лечение / взаимодействие

	var jump_x := W - pad - jbs
	var jump_y := H - pad - jbs
	_add(Rect2(jump_x, jump_y, jbs, jbs), "ПРЫГ", "jump", "")

	var atk_x := jump_x - gap - abs_
	var atk_y := H - pad - abs_
	_add(Rect2(atk_x, atk_y, abs_, abs_), "АТАКА", "", "lmb")

	# РЫВОК над атакой, СПЕЦ над прыжком
	var dash_x := atk_x + (abs_ - mbs) * 0.5
	var dash_y := atk_y - gap - mbs
	_add(Rect2(dash_x, dash_y, mbs, mbs), "РЫВОК", "", "ctrl")

	var spec_x := jump_x + (jbs - mbs) * 0.5
	var spec_y := jump_y - gap - mbs
	_add(Rect2(spec_x, spec_y, mbs, mbs), "СПЕЦ", "", "rmb")

	# ЛЕЧ и E — маленькие, ещё выше
	_add(Rect2(dash_x + (mbs - ssb) * 0.5, dash_y - gap - ssb, ssb, ssb), "ЛЕЧ", "", "h_key")
	_add(Rect2(spec_x + (mbs - ssb) * 0.5, spec_y - gap - ssb, ssb, ssb), "E", "interact", "")

	if draw_node:
		draw_node.queue_redraw()

func _add(rect: Rect2, label: String, action: String, special: String) -> void:
	buttons.append({
		"rect": rect,
		"label": label,
		"action": action,
		"special": special,
		"pressed": false,
		"tid": -1,
	})

# ─────────────────── ВВОД (TOUCH) ───────────────────

func _input(event: InputEvent) -> void:
	if not active:
		return  # В меню не перехватываем тач — пусть кнопки меню работают
	if event is InputEventScreenTouch:
		_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		# Эмуляция мыши из тача включена (нужна для кнопок меню). Чтобы
		# нажатия по нашим кнопкам (особенно D-pad) не превращались в
		# фантомные клики-атаки по игроку — поглощаем мышь в зоне кнопок.
		if _button_at(event.position) >= 0:
			get_viewport().set_input_as_handled()

func _touch(tid: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		var idx := _button_at(pos)
		if idx >= 0 and buttons[idx]["tid"] == -1:
			buttons[idx]["tid"] = tid
			buttons[idx]["pressed"] = true
			touch_map[tid] = idx
			_fire(idx, true)
			draw_node.queue_redraw()
			get_viewport().set_input_as_handled()
	else:
		if touch_map.has(tid):
			var idx: int = touch_map[tid]
			buttons[idx]["tid"] = -1
			buttons[idx]["pressed"] = false
			touch_map.erase(tid)
			_fire(idx, false)
			draw_node.queue_redraw()
			get_viewport().set_input_as_handled()

func _drag(tid: int, pos: Vector2) -> void:
	# Если палец уже держит кнопку — проверяем, не съехал ли с неё
	if touch_map.has(tid):
		var cur: int = touch_map[tid]
		if not buttons[cur]["rect"].has_point(pos):
			buttons[cur]["tid"] = -1
			buttons[cur]["pressed"] = false
			touch_map.erase(tid)
			_fire(cur, false)
			# мог переехать на соседнюю кнопку
			var idx := _button_at(pos)
			if idx >= 0 and buttons[idx]["tid"] == -1:
				buttons[idx]["tid"] = tid
				buttons[idx]["pressed"] = true
				touch_map[tid] = idx
				_fire(idx, true)
			draw_node.queue_redraw()

func _button_at(pos: Vector2) -> int:
	for i in buttons.size():
		if buttons[i]["rect"].has_point(pos):
			return i
	return -1

# ─────────────────── ОТПРАВКА ВВОДА В ИГРУ ───────────────────

func _fire(idx: int, pressed: bool) -> void:
	var b = buttons[idx]
	if b["action"] != "":
		_send_action(b["action"], pressed)
	else:
		_send_special(b["special"], pressed)

func _send_action(name: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
	# Прыжок служит и кнопкой подтверждения в меню (выбор карты/оружия),
	# т.к. отдельной кнопки ui_accept на телефоне нет. D-pad навигирует
	# через move_* (меню их уже слушает), Прыжок — подтверждает.
	if name == "jump":
		var ev2 := InputEventAction.new()
		ev2.action = "ui_accept"
		ev2.pressed = pressed
		ev2.strength = 1.0 if pressed else 0.0
		Input.parse_input_event(ev2)

func _send_special(sp: String, pressed: bool) -> void:
	match sp:
		"lmb":
			_send_mouse(MOUSE_BUTTON_LEFT, pressed)
		"rmb":
			_send_mouse(MOUSE_BUTTON_RIGHT, pressed)
		"ctrl":
			_send_key(KEY_CTRL, pressed)
		"h_key":
			_send_key(KEY_H, pressed)

func _send_mouse(btn: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	# Шлём из центра экрана — вне зон кнопок, иначе наш же клик поглотится
	# фильтром эмулированной мыши в _input. Направление атаки берётся из
	# зажатых стрелок, а не из позиции, так что центр безопасен.
	ev.position = Vector2(vw * 0.5, vh * 0.45)
	Input.parse_input_event(ev)

func _send_key(kc: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = kc
	ev.physical_keycode = kc
	ev.pressed = pressed
	ev.echo = false
	Input.parse_input_event(ev)

# ─────────────────── ОТРИСОВКА ───────────────────

# Базовый цвет кнопки по её функции (цветовая кодировка как в экшен-играх)
func _button_color(b) -> Color:
	var act: String = b["action"]
	var sp: String = b["special"]
	if act in ["move_left", "move_right", "move_up", "move_down"]:
		return Color(0.20, 0.22, 0.30)   # движение — нейтральный тёмный
	if act == "jump":
		return Color(0.18, 0.50, 0.95)   # прыжок — синий
	if sp == "lmb":
		return Color(0.90, 0.25, 0.20)   # атака — красный
	if sp == "rmb":
		return Color(0.95, 0.60, 0.12)   # спец — оранжевый
	if sp == "ctrl":
		return Color(0.60, 0.25, 0.95)   # рывок — фиолетовый
	if sp == "h_key":
		return Color(0.20, 0.75, 0.40)   # лечение — зелёный
	if act == "interact":
		return Color(0.85, 0.80, 0.20)   # взаимодействие — жёлтый
	return Color(0.25, 0.25, 0.30)

func _on_draw() -> void:
	if not draw_node:
		return
	var font := ThemeDB.fallback_font

	for b in buttons:
		var rect: Rect2 = b["rect"]
		var pressed: bool = b["pressed"]
		var col := _button_color(b)
		var is_move: bool = b["action"] in ["move_left", "move_right", "move_up", "move_down"]
		# При нажатии — ярче и насыщеннее
		var fill := col
		fill.a = ALPHA_PRESSED if pressed else ALPHA_IDLE
		if pressed:
			fill = fill.lightened(0.25)
			fill.a = ALPHA_PRESSED
		var border_col := Color(1, 1, 1, 0.65 if pressed else 0.35)

		var center := rect.position + rect.size * 0.5
		if is_move:
			# Движение — закруглённый прямоугольник (рисуем прямоугольник + рамка)
			draw_node.draw_rect(rect, fill, true)
			draw_node.draw_rect(rect, border_col, false, 3.0)
		else:
			# Действия — круг (удобнее для большого пальца)
			var r := minf(rect.size.x, rect.size.y) * 0.5
			draw_node.draw_circle(center, r, fill)
			draw_node.draw_arc(center, r, 0, TAU, 32, border_col, 3.0, true)

		# Подпись по центру. Стрелки крупнее, текст-подписи мельче.
		var fs := 40 if is_move else (22 if b["label"].length() <= 1 else 17)
		var ts := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tx := center.x - ts.x * 0.5
		var ty := center.y + ts.y * 0.5 - 5.0
		draw_node.draw_string(font, Vector2(tx, ty), b["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.97))
