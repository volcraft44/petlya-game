extends CanvasLayer

# === Мобильные виртуальные кнопки управления ===
# Показываются только на сенсорных устройствах (Android/iOS)

var draw_node: Control = null

# Масштабный коэффициент (относительно 720p)
var sf: float = 1.0
var vp: Vector2 = Vector2.ZERO

# Описание одной кнопки
class Btn:
	var rect: Rect2
	var label: String
	var color: Color
	var action: String       # InputEventAction (move_left, jump, interact...)
	var special: String      # "lmb", "rmb", "ctrl", "h_key", "f_key", "c_key"
	var is_pressed: bool = false
	var touch_id: int = -1

var buttons: Array = []
var touch_map: Dictionary = {}  # touch_id -> button index

const ALPHA_IDLE: float    = 0.45
const ALPHA_PRESSED: float = 0.75

func _ready():
	# Показываем только на сенсорных устройствах
	if not (OS.get_name() == "Android" or OS.get_name() == "iOS"
			or DisplayServer.is_touchscreen_available()):
		queue_free()
		return

	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Control-нода для отрисовки (как в hud.gd)
	draw_node = Control.new()
	draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_node.draw.connect(_on_draw)
	add_child(draw_node)

	# Масштаб по высоте экрана
	vp = get_viewport().get_visible_rect().size
	sf = vp.y / 720.0

	_create_buttons()

# Масштабирование
func _s(v: float) -> float:
	return v * sf

func _create_buttons():
	buttons.clear()

	var W := vp.x
	var H := vp.y
	var pad := _s(18)
	var gap := _s(7)
	var bs  := _s(78)    # стандартный размер кнопки

	# ═══════════════ ЛЕВАЯ СТОРОНА: D-PAD ═══════════════
	# Расположение: нижний левый угол, крест ← ↑ ↓ →
	#
	#        [↑]
	#   [←] [  ] [→]
	#        [↓]
	#
	var lx := pad
	var ly := H - pad - bs * 3 - gap * 2  # верх крестовины

	_btn(Rect2(lx + bs + gap, ly,               bs, bs), "↑",  Color(0.75,0.75,0.85), "move_up")
	_btn(Rect2(lx,            ly + bs + gap,     bs, bs), "←",  Color(0.75,0.75,0.85), "move_left")
	_btn(Rect2(lx + (bs+gap)*2, ly + bs + gap,  bs, bs), "→",  Color(0.75,0.75,0.85), "move_right")
	_btn(Rect2(lx + bs + gap, ly + (bs+gap)*2,  bs, bs), "↓",  Color(0.75,0.75,0.85), "move_down")

	# ═══════════════ ПРАВАЯ СТОРОНА: ACTION-КНОПКИ ═══════════════
	#
	# [ЛЕЧ] [СПЕ] [E]
	#  [РЫВ] [АТК] [ПРЫЖОК]
	#
	var rx := W - pad   # правый край
	var ry := H - pad   # нижний край

	var jbs := _s(100)  # прыжок — большая кнопка
	var sbs := _s(68)   # маленькие кнопки (лечение, спец и т.д.)

	# Нижний ряд: РЫВОК | АТАКА | ПРЫЖОК
	var jump_x := rx - jbs
	var atk_x  := jump_x - gap - bs
	var dash_x := atk_x  - gap - bs

	_btn(Rect2(jump_x, ry - jbs,         jbs, jbs), "ПРЫЖОК", Color(0.15,0.40,1.00), "jump")
	_btn_sp(Rect2(atk_x,  ry - bs,         bs,  bs), "АТК",    Color(1.00,0.25,0.15), "lmb")
	_btn_sp(Rect2(dash_x, ry - bs,         bs,  bs), "РЫВ",    Color(0.55,0.15,1.00), "ctrl")

	# Средний ряд: ЛЕЧЕНИЕ | СПЕЦ | ВЗАИМ
	var mid_y := ry - bs - gap - sbs
	_btn_sp(Rect2(jump_x + jbs - sbs, mid_y,   sbs, sbs), "E",    Color(0.20,0.75,0.30), "e_key")
	_btn_sp(Rect2(atk_x + bs - sbs,   mid_y,   sbs, sbs), "СПЕ",  Color(1.00,0.70,0.10), "rmb")
	_btn_sp(Rect2(dash_x + bs - sbs,  mid_y,   sbs, sbs), "ЛЕЧ",  Color(0.90,0.15,0.50), "h_key")

	draw_node.queue_redraw()

# Добавить кнопку с action
func _btn(rect: Rect2, label: String, color: Color, action: String):
	var b := Btn.new()
	b.rect    = rect
	b.label   = label
	b.color   = Color(color.r, color.g, color.b, ALPHA_IDLE)
	b.action  = action
	b.special = ""
	buttons.append(b)

# Добавить кнопку со специальным вводом
func _btn_sp(rect: Rect2, label: String, color: Color, special: String):
	var b := Btn.new()
	b.rect    = rect
	b.label   = label
	b.color   = Color(color.r, color.g, color.b, ALPHA_IDLE)
	b.action  = ""
	b.special = special
	buttons.append(b)

# ─────────────────── ВВОД (TOUCH) ───────────────────

func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)

func _handle_touch(tid: int, pos: Vector2, pressed: bool):
	if pressed:
		for i in buttons.size():
			var b = buttons[i]
			if b.rect.has_point(pos) and b.touch_id == -1:
				b.touch_id    = tid
				b.is_pressed  = true
				touch_map[tid] = i
				_press(i)
				draw_node.queue_redraw()
				get_viewport().set_input_as_handled()
				break
	else:
		if tid in touch_map:
			var i: int = touch_map[tid]
			var b = buttons[i]
			b.touch_id   = -1
			b.is_pressed = false
			touch_map.erase(tid)
			_release(i)
			draw_node.queue_redraw()
			get_viewport().set_input_as_handled()

func _handle_drag(tid: int, pos: Vector2):
	if tid in touch_map:
		var old_i: int = touch_map[tid]
		var old_b = buttons[old_i]
		if not old_b.rect.has_point(pos):
			# Палец вышел за кнопку — отпускаем
			old_b.touch_id   = -1
			old_b.is_pressed = false
			touch_map.erase(tid)
			_release(old_i)
			draw_node.queue_redraw()
			# Проверяем, не попал ли в другую кнопку
			for i in buttons.size():
				var b = buttons[i]
				if b.rect.has_point(pos) and b.touch_id == -1:
					b.touch_id   = tid
					b.is_pressed = true
					touch_map[tid] = i
					_press(i)
					draw_node.queue_redraw()
					break
	else:
		# Касание не было на кнопке — проверяем новое положение
		for i in buttons.size():
			var b = buttons[i]
			if b.rect.has_point(pos) and b.touch_id == -1:
				b.touch_id   = tid
				b.is_pressed = true
				touch_map[tid] = i
				_press(i)
				draw_node.queue_redraw()
				get_viewport().set_input_as_handled()
				break

# ─────────────────── НАЖАТИЕ / ОТПУСКАНИЕ ───────────────────

func _press(idx: int):
	var b = buttons[idx]
	if b.action != "":
		_action(b.action, true)
	else:
		_special(b.special, true)

func _release(idx: int):
	var b = buttons[idx]
	if b.action != "":
		_action(b.action, false)
	else:
		_special(b.special, false)

func _action(name: String, pressed: bool):
	var ev := InputEventAction.new()
	ev.action   = name
	ev.pressed  = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)

func _special(sp: String, pressed: bool):
	match sp:
		"lmb":
			_mouse_btn(MOUSE_BUTTON_LEFT as MouseButton, pressed)
		"rmb":
			_mouse_btn(MOUSE_BUTTON_RIGHT as MouseButton, pressed)
		"ctrl":
			_key(KEY_CTRL, pressed)
		"e_key":
			_action("interact", pressed)
		"h_key":
			_key(KEY_H, pressed)
		"f_key":
			_key(KEY_F, pressed)
		"c_key":
			_key(KEY_C, pressed)

func _mouse_btn(btn: MouseButton, pressed: bool):
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed      = pressed
	ev.position     = get_viewport().get_mouse_position()
	Input.parse_input_event(ev)

func _key(kc: int, pressed: bool):
	var ev := InputEventKey.new()
	ev.keycode  = kc
	ev.pressed  = pressed
	ev.echo     = false
	Input.parse_input_event(ev)

# ─────────────────── ОТРИСОВКА ───────────────────

func _on_draw():
	if not draw_node:
		return
	var font      := ThemeDB.fallback_font
	var font_size := int(_s(16))

	for b in buttons:
		var rect = b.rect
		var col = b.color

		if b.is_pressed:
			col = Color(
				minf(col.r + 0.25, 1.0),
				minf(col.g + 0.25, 1.0),
				minf(col.b + 0.25, 1.0),
				ALPHA_PRESSED
			)

		# Заливка кнопки
		draw_node.draw_rect(rect, col, true)
		# Рамка
		draw_node.draw_rect(rect, Color(1, 1, 1, 0.35 if not b.is_pressed else 0.65), false, _s(2.0))

		# Текст по центру
		var ts := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var tx := rect.position.x + (rect.size.x - ts.x) * 0.5
		var ty := rect.position.y + (rect.size.y + ts.y) * 0.5 - _s(3)
		draw_node.draw_string(font, Vector2(tx, ty), b.label, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, Color.WHITE)
