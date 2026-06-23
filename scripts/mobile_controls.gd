extends CanvasLayer

# === Мобильное управление в стиле Dead Cells ===
# Слева — плавающий виртуальный джойстик (появляется там, где коснулся палец).
# Справа — круглые кнопки действий.
# Координаты в логическом пространстве вьюпорта (stretch=canvas_items).

var draw_node: Control = null

var vw: float = 1280.0
var vh: float = 768.0

# Кнопки действий (правая часть). {rect, label, action, special, pressed, tid}
var buttons: Array = []
var touch_map: Dictionary = {}   # touch_id -> индекс кнопки

# ── Виртуальный джойстик (левая часть экрана) ──
var joy_tid: int = -1
var joy_origin: Vector2 = Vector2.ZERO
var joy_pos: Vector2 = Vector2.ZERO
var joy_radius: float = 110.0       # макс. ход стика
var joy_deadzone: float = 0.22      # мёртвая зона по горизонтали
var joy_vert_zone: float = 0.55     # порог по вертикали (лестницы/спуск)
# Какие направления сейчас "нажаты" джойстиком — чтобы корректно отпускать
var _dir_state := {"move_left": false, "move_right": false, "move_up": false, "move_down": false}

var active: bool = false

const ALPHA_IDLE: float    = 0.38
const ALPHA_PRESSED: float = 0.82

func set_active(a: bool) -> void:
	active = a
	if draw_node:
		draw_node.visible = a
	if not a:
		_release_joystick()
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
	if not (OS.has_feature("mobile") or OS.get_name() == "Android"
			or OS.get_name() == "iOS" or DisplayServer.is_touchscreen_available()):
		queue_free()
		return

	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	vw = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	vh = float(ProjectSettings.get_setting("display/window/size/viewport_height", 768))

	draw_node = Control.new()
	draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

	_create_buttons()
	draw_node.visible = active

func _create_buttons() -> void:
	# Движение — джойстик слева. Кнопки распределены по краям:
	#  • низ-право: основной кластер (ПРЫГ, АТАКА, РЫВОК, СПЕЦ) под большой палец
	#  • верх-право: вспомогательные (E — взаимодействие, ЛЕЧ) — не мешают
	buttons.clear()

	var pad := 28.0
	var gap := 16.0
	var H := vh
	var W := vw

	# Всё в зоне большого пальца справа-снизу. Две главные кнопки (АТАКА,
	# ПРЫЖОК) — самые большие и в самом удобном месте. Над ними — рывок и спец.
	# Лечение и E — на правом краю чуть выше (легко дотянуться), не в углу.
	var big := 150.0    # главные: прыжок/атака
	var mid := 104.0    # рывок/спец
	var sml := 92.0     # лечение / E

	# Прыжок — правый нижний угол
	var jump_x := W - pad - big
	var jump_y := H - pad - big
	_add(Rect2(jump_x, jump_y, big, big), "ПРЫЖ", "jump", "")

	# Атака — слева от прыжка (низ выровнен)
	var atk_x := jump_x - gap - big
	var atk_y := jump_y
	_add(Rect2(atk_x, atk_y, big, big), "АТАКА", "", "lmb")

	# Рывок над атакой, Спец над прыжком
	var dash_x := atk_x + (big - mid) * 0.5
	var dash_y := atk_y - gap - mid
	_add(Rect2(dash_x, dash_y, mid, mid), "РЫВОК", "", "ctrl")

	var spec_x := jump_x + (big - mid) * 0.5
	var spec_y := jump_y - gap - mid
	_add(Rect2(spec_x, spec_y, mid, mid), "СПЕЦ", "", "rmb")

	# E (двери/предметы) — правый край, выше спеца (часто нужна — близко)
	var e_x := W - pad - sml
	var e_y := spec_y - gap - sml
	_add(Rect2(e_x, e_y, sml, sml), "E", "", "e_key")
	# Лечение — слева от E
	_add(Rect2(e_x - gap - sml, e_y, sml, sml), "ЛЕЧ", "", "h_key")

	# Пауза — верх по центру (нужна редко)
	_add(Rect2(W * 0.5 - 34, pad, 68, 68), "II", "", "esc_key")

	if draw_node:
		draw_node.queue_redraw()

func _add(rect: Rect2, label: String, action: String, special: String) -> void:
	buttons.append({
		"rect": rect, "label": label, "action": action,
		"special": special, "pressed": false, "tid": -1,
	})

# Левая половина экрана (но не под кнопками) = зона джойстика
func _in_joy_zone(pos: Vector2) -> bool:
	return pos.x < vw * 0.5

# ─────────────────── ВВОД ───────────────────

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		# Глотаем эмулированную мышь над кнопками/джойстиком, чтобы не было
		# фантомных кликов по игроку (эмуляция нужна для кнопок меню).
		if _button_at(event.position) >= 0 or (joy_tid != -1 and _in_joy_zone(event.position)):
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
		elif joy_tid == -1 and _in_joy_zone(pos):
			# Запускаем джойстик в точке касания
			joy_tid = tid
			joy_origin = pos
			joy_pos = pos
			draw_node.queue_redraw()
			get_viewport().set_input_as_handled()
	else:
		if tid == joy_tid:
			_release_joystick()
			draw_node.queue_redraw()
			get_viewport().set_input_as_handled()
		elif touch_map.has(tid):
			var idx: int = touch_map[tid]
			buttons[idx]["tid"] = -1
			buttons[idx]["pressed"] = false
			touch_map.erase(tid)
			_fire(idx, false)
			draw_node.queue_redraw()
			get_viewport().set_input_as_handled()

func _drag(tid: int, pos: Vector2) -> void:
	if tid == joy_tid:
		joy_pos = pos
		_update_joystick()
		draw_node.queue_redraw()
		return
	# Палец на кнопке съехал за её пределы — отпускаем
	if touch_map.has(tid):
		var cur: int = touch_map[tid]
		if not buttons[cur]["rect"].has_point(pos):
			buttons[cur]["tid"] = -1
			buttons[cur]["pressed"] = false
			touch_map.erase(tid)
			_fire(cur, false)
			draw_node.queue_redraw()

func _button_at(pos: Vector2) -> int:
	for i in buttons.size():
		if buttons[i]["rect"].has_point(pos):
			return i
	return -1

# ── Логика джойстика ──
func _update_joystick() -> void:
	var delta := joy_pos - joy_origin
	# Ограничиваем ход стика
	if delta.length() > joy_radius:
		delta = delta.normalized() * joy_radius
		joy_pos = joy_origin + delta
	var nx := delta.x / joy_radius   # -1..1
	var ny := delta.y / joy_radius   # -1..1 (вниз положительно)

	_set_dir("move_left",  nx < -joy_deadzone, absf(nx))
	_set_dir("move_right", nx >  joy_deadzone, absf(nx))
	_set_dir("move_up",    ny < -joy_vert_zone, absf(ny))
	_set_dir("move_down",  ny >  joy_vert_zone, absf(ny))

func _set_dir(action: String, want: bool, strength: float) -> void:
	if want:
		# Аналоговая сила для плавности
		Input.action_press(action, clampf(strength, 0.0, 1.0))
		_dir_state[action] = true
	elif _dir_state[action]:
		Input.action_release(action)
		_dir_state[action] = false

func _release_joystick() -> void:
	joy_tid = -1
	for a in _dir_state.keys():
		if _dir_state[a]:
			Input.action_release(a)
			_dir_state[a] = false

# ─────────────────── ОТПРАВКА ВВОДА КНОПОК ───────────────────

func _fire(idx: int, pressed: bool) -> void:
	var b = buttons[idx]
	if b["action"] != "":
		_send_action(b["action"], pressed)
	else:
		_send_special(b["special"], pressed)

func _send_action(name: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(name)
	else:
		Input.action_release(name)
	# Прыжок = подтверждение в меню (выбор карт/оружия)
	if name == "jump":
		if pressed:
			Input.action_press("ui_accept")
		else:
			Input.action_release("ui_accept")

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
		"e_key":
			# Двери/предметы ловят именно клавишу E (а не action), плюс
			# "interact" в input map тоже привязан к E — так работает всё.
			_send_key(KEY_E, pressed)
		"esc_key":
			# Пауза/настройки — шлём Escape (только на нажатие, не на отпускание)
			if pressed:
				_send_key(KEY_ESCAPE, true)
				_send_key(KEY_ESCAPE, false)

func _send_mouse(btn: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	# Из центра экрана — вне зон кнопок, чтобы наш фильтр мыши не съел это
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

func _button_color(b) -> Color:
	var act: String = b["action"]
	var sp: String = b["special"]
	if act == "jump":
		return Color(0.18, 0.50, 0.95)
	if sp == "lmb":
		return Color(0.90, 0.25, 0.20)
	if sp == "rmb":
		return Color(0.95, 0.60, 0.12)
	if sp == "ctrl":
		return Color(0.60, 0.25, 0.95)
	if sp == "h_key":
		return Color(0.20, 0.75, 0.40)
	if sp == "e_key":
		return Color(0.85, 0.80, 0.20)
	return Color(0.25, 0.25, 0.30)

func _on_draw() -> void:
	if not draw_node:
		return
	var font := ThemeDB.fallback_font

	# ── Джойстик ──
	if joy_tid != -1:
		var ring := Color(1, 1, 1, 0.22)
		draw_node.draw_circle(joy_origin, joy_radius, Color(0.10, 0.12, 0.18, 0.30))
		draw_node.draw_arc(joy_origin, joy_radius, 0, TAU, 40, ring, 4.0, true)
		# Стик
		var knob := joy_pos
		draw_node.draw_circle(knob, 46.0, Color(0.35, 0.55, 0.95, 0.70))
		draw_node.draw_arc(knob, 46.0, 0, TAU, 32, Color(1, 1, 1, 0.6), 3.0, true)
	else:
		# Подсказка: круг-призрак внизу слева
		var hint := Vector2(vw * 0.16, vh - 150.0)
		draw_node.draw_arc(hint, 70.0, 0, TAU, 40, Color(1, 1, 1, 0.10), 3.0, true)

	# ── Кнопки действий ──
	for b in buttons:
		var rect: Rect2 = b["rect"]
		var pressed: bool = b["pressed"]
		var col := _button_color(b)
		var fill := col
		fill.a = ALPHA_PRESSED if pressed else ALPHA_IDLE
		if pressed:
			fill = fill.lightened(0.25)
			fill.a = ALPHA_PRESSED
		var border_col := Color(1, 1, 1, 0.65 if pressed else 0.35)
		var center := rect.position + rect.size * 0.5
		var r := minf(rect.size.x, rect.size.y) * 0.5
		draw_node.draw_circle(center, r, fill)
		draw_node.draw_arc(center, r, 0, TAU, 32, border_col, 3.0, true)

		var fs := 22 if b["label"].length() <= 1 else 17
		var ts := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_node.draw_string(font, Vector2(center.x - ts.x * 0.5, center.y + ts.y * 0.5 - 5.0),
			b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.97))
