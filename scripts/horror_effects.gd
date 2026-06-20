extends CanvasLayer

# Screen-space horror effects layer (layer = 150)
# Setup: call setup(player, deaths) after adding to scene tree.
# Trigger once-per-run no-exit effect via trigger_no_exit().

# ── Player reference ──
var _player = null

# ── Window shake (двигает само окно ОС) ──
var _win_shake_t:         float   = -1.0   # время оставшееся (< 0 = неактивно)
var _win_shake_dur:       float   = 0.0    # полная длительность текущего shake
var _win_shake_intensity: float   = 0.0    # максимальное смещение в пикселях
var _win_shake_origin:    Vector2i = Vector2i.ZERO  # позиция окна до shake
var _win_shake_bhop_cd:   float   = 0.0   # cooldown между bhop-толчками

# ── Drawing node ──
var _draw_node: Node2D = null

# ── Vignette (always-on) ──
var _vignette_t: float = 0.0

# ── Eyes in darkness — max 2 pairs of simple red dots ──
var _eyes:    Array = []   # [{pos, t, dur, blink_cd}], max 2
var _eyes_cd: float = 0.0  # cooldown before spawning next pair

# ── Player echo / ghost ──
var _echo_ring:    Array   = []    # ring buffer of Vector2 world positions
var _echo_ring_sz: int     = 192
var _echo_head:    int     = 0
var _echo_cd:      float   = 0.0
var _echo_t:       float   = -1.0
var _echo_dur:     float   = 0.0
var _echo_pos:     Vector2 = Vector2.ZERO  # screen-space ghost position (sampled once per trigger)

# ── Silhouette ──
var _sil_cd:   float   = 0.0
var _sil_t:    float   = -1.0
var _sil_dur:  float   = 0.0
var _sil_pos:  Vector2 = Vector2.ZERO

# ── Glitch — burst system ──
var _glitch_cd:        float = 0.0   # cooldown between bursts
var _glitch_hit_t:     float = -1.0  # time remaining in current hit flash
var _glitch_gap_t:     float = -1.0  # gap between hits within a burst
var _glitch_hits_left: int   = 0     # hits remaining in current burst
var _glitch_strips:    Array = []    # [{y, h, dx, bright}] for current hit

# ── No-exit room ──
var _noexit_active: bool  = false
var _noexit_t:      float = -1.0

# ── VHS / Hopelessness atmosphere ──
var _vhs_t:           float = 0.0          # глобальное время
var _vhs_track_y:     float = 0.0          # позиция полосы трекинга (плывёт вниз)
var _vhs_track_speed: float = 35.0         # px/sec
var _vhs_sync_t:      float = -1.0         # таймер сбойной "пляски" кадра
var _vhs_sync_cd:     float = 8.0          # интервал между сбоями
var _vhs_sync_off:    float = 0.0          # текущее смещение по Y
var _vhs_noise_seed:  int   = 0            # сид для статика (меняется каждый кадр)
var _vhs_intensity:   float = 0.85         # 0..1 общая интенсивность VHS

# ── Cinematic atmosphere (всегда включён) — зерно, тонировка, пылинки ──
var _cine_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _cine_dust: Array = []   # [{x_screen, y_screen, vx, vy, alpha, life}]
var _cine_dust_cd: float = 0.0
var cine_intensity: float = 1.0    # 0..1, можно занижать если мешает
var cine_tint: Color = Color(0.85, 0.92, 1.0)   # лёгкий холодный синий уход
var cine_warmth: Color = Color(1.10, 0.95, 0.80)  # тёплый для контр-баланса в свете

# === PSYCHEDELIC SYSTEM (общий мастер-интенсив + все эффекты) ===
var psy_intensity: float = 1.0  # 0..1 — общая интенсивность психоделии
# 1) Hue cycling — палитра дышит цветом
var _hue_phase: float = 0.0
# 2) Sacred geometry — мандалы в фоне (медленные)
var _sacred_t: float = 0.0
# 3) Floating cubes на дальнем плане
var _float_cubes: Array = []   # [{x, y, size, vx, vy, rot, vrot, hue}]
# 4) Star field (далёкие искорки)
var _stars: Array = []         # [{x, y, alpha, phase}]
# 5) Rainbow waves (раз в 30-60 сек)
var _rainbow_t: float = -1.0
var _rainbow_cd: float = 25.0
# 6) Acid flash (раз в 60-90 сек, 0.25 сек)
var _acid_t: float = -1.0
var _acid_cd: float = 50.0
# 7) Glitch jump (раз в 45-90 сек, мгновенный сдвиг)
var _glitch_jump_cd: float = 30.0
var _glitch_jump_t: float = -1.0
var _glitch_jump_offset: Vector2 = Vector2.ZERO
# 8) Hallucination silhouettes (раз в 25-50 сек)
var _halluc_cd: float = 18.0
var _halluc_list: Array = []   # [{pos_screen, t, dur}]
# 9) Eyes from walls (раз в 35-70 сек)
var _eye_cd: float = 22.0
var _eye_t: float = -1.0
var _eye_pos: Vector2 = Vector2.ZERO
# 10) Mirror moment (раз в 90-180 сек, 0.4 сек)
var _mirror_cd: float = 70.0
var _mirror_t: float = -1.0
# 11) Текстовые мерцания в углах (раз в 20-40 сек)
var _corner_text_cd: float = 15.0
var _corner_text_t: float = -1.0
var _corner_text: String = ""
var _corner_text_pos: int = 0
const CORNER_TEXTS: Array = [
	"ТЫ ЗДЕСЬ?", "ОНИ ТУТ", "СЛУШАЙ", "СПИШЬ?",
	"СНОВА", "ПОМНИ", "БЕГИ", "СМОТРИ"
]
# Доступ извне (для main.gd камеры — heartbeat / mirror / glitch jump)
func psy_camera_zoom_mult() -> float:
	# Лёгкое "сердцебиение" zoom-а
	return 1.0 + sin(_vhs_t * TAU * 0.45) * 0.012 * psy_intensity
func psy_camera_flip_x() -> bool:
	return _mirror_t > 0.0
func psy_camera_offset() -> Vector2:
	return _glitch_jump_offset

# ── Шёпоты безнадёжности (короткие фразы внизу) ──
var _whisper_cd:    float  = 18.0
var _whisper_t:     float  = -1.0
var _whisper_dur:   float  = 0.0
var _whisper_text:  String = ""
var _whisper_pool:  Array  = [
	"Снова...",
	"Опять то же место",
	"Ты не выберешься",
	"Это уже было",
	"Петля не кончается",
	"Сдайся",
	"Никто не спасёт",
	"Ты помнишь?",
	"Всё повторится",
	"Беги. Это не поможет.",
	"Они ждут",
	"Конца нет",
]
# Счётчик "ленты" — для REC-индикатора
var _vhs_tape_secs: float = 0.0
# Пере-используемые RNG, чтобы не плодить аллокации
var _vhs_rng_band: RandomNumberGenerator = RandomNumberGenerator.new()
var _vhs_rng_static: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	layer = 150
	# Pre-fill ring buffer
	_echo_ring.resize(_echo_ring_sz)
	for i in _echo_ring_sz:
		_echo_ring[i] = Vector2.ZERO

	# Randomize initial cooldowns so effects don't all fire at once
	_eyes_cd   = randf_range(15.0, 40.0)
	_echo_cd   = randf_range(50.0, 130.0)
	_sil_cd    = randf_range(70.0, 170.0)
	_glitch_cd = randf_range(18.0, 50.0)

	# Create draw node
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)

func setup(p_player, p_deaths: int) -> void:
	_player = p_player
	# p_deaths available for future frequency scaling; stored implicitly via setup call
	var _d = p_deaths  # suppress unused-parameter lint
	# Подключаем сигналы для движения окна
	if _player:
		if not _player.died.is_connected(_on_player_died):
			_player.died.connect(_on_player_died)
		if not _player.bhop_perfect.is_connected(_on_bhop_perfect):
			_player.bhop_perfect.connect(_on_bhop_perfect)

# ── Window shake: публичный вызов (можно использовать из других скриптов) ──
func _win_safe_pos(base: Vector2i, offset: Vector2i) -> Vector2i:
	# Ограничиваем смещение от стартовой позиции — не улетит на другой монитор
	var MAX_OFFSET = 90
	var p = base + offset
	p.x = clampi(p.x, _win_shake_origin.x - MAX_OFFSET, _win_shake_origin.x + MAX_OFFSET)
	p.y = clampi(p.y, _win_shake_origin.y - MAX_OFFSET, _win_shake_origin.y + MAX_OFFSET)
	return p

func trigger_window_shake(intensity: float, duration: float) -> void:
	# Не перебиваем более сильный shake
	if _win_shake_t > 0.0 and intensity <= _win_shake_intensity:
		return
	_win_shake_origin    = DisplayServer.window_get_position()
	_win_shake_t         = duration
	_win_shake_dur       = duration
	_win_shake_intensity = intensity

# ── Колбэки сигналов игрока ──
func _on_player_died() -> void:
	# Смерть: резкое сильное сотрясение окна на 1.5 сек
	trigger_window_shake(50.0, 1.5)

func _on_bhop_perfect(stacks: int, _world_pos: Vector2) -> void:
	# Bhop: при 3+ стэках толкаем окно, кулдаун чтобы не спамило
	if stacks >= 3 and _win_shake_bhop_cd <= 0.0:
		var intensity = clampf(float(stacks) * 7.0, 20.0, 50.0)
		trigger_window_shake(intensity, 0.35)
		_win_shake_bhop_cd = 0.7

func trigger_no_exit() -> void:
	if not _noexit_active:
		_noexit_active = true
		_noexit_t      = 12.0

func _process(delta: float) -> void:
	# ── Window shake update ──
	if _win_shake_bhop_cd > 0.0:
		_win_shake_bhop_cd -= delta
	if _win_shake_t >= 0.0:
		_win_shake_t -= delta
		if _win_shake_t >= 0.0:
			# Затухание: ближе к концу — слабее
			var decay = _win_shake_t / _win_shake_dur
			var cur_intensity = _win_shake_intensity * decay
			var offset = Vector2i(
				int(randf_range(-cur_intensity, cur_intensity)),
				int(randf_range(-cur_intensity, cur_intensity))
			)
			DisplayServer.window_set_position(_win_safe_pos(_win_shake_origin, offset))
		else:
			# Shake закончился — возвращаем окно на место
			DisplayServer.window_set_position(_win_shake_origin)
			_win_shake_t = -1.0

	_vignette_t += delta
	_vhs_t      += delta
	_vhs_tape_secs += delta
	_vhs_noise_seed = (_vhs_noise_seed + 1) & 0xFFFF

	# === PSYCHEDELIC ticks ===
	_hue_phase += delta * 0.06       # очень медленно вращается hue
	_sacred_t += delta

	var vs_init = _viewport_size()
	# Плавающие кубы / звёзды / радуга больше НЕ рисуются (ambient-постобработка
	# убрана ради FPS), поэтому их обновление — пустая трата. Полностью
	# пропускаем расчёт.

	# Acid flash
	if _acid_t < 0.0:
		_acid_cd -= delta
		if _acid_cd <= 0.0:
			_acid_t = 0.30
			_acid_cd = randf_range(60.0, 100.0)
	else:
		_acid_t -= delta
		if _acid_t < 0.0:
			_acid_t = -1.0

	# Glitch jump
	if _glitch_jump_t < 0.0:
		_glitch_jump_cd -= delta
		if _glitch_jump_cd <= 0.0:
			_glitch_jump_t = 0.08
			_glitch_jump_offset = Vector2(randf_range(-8, 8), randf_range(-5, 5))
			_glitch_jump_cd = randf_range(45.0, 90.0)
	else:
		_glitch_jump_t -= delta
		if _glitch_jump_t < 0.0:
			_glitch_jump_t = -1.0
			_glitch_jump_offset = Vector2.ZERO

	# Hallucination silhouettes
	if _halluc_list.size() == 0:
		_halluc_cd -= delta
		if _halluc_cd <= 0.0:
			_halluc_cd = randf_range(25.0, 55.0)
			var dur = randf_range(0.4, 0.8)
			_halluc_list.append({
				"pos": Vector2(randf_range(60, vs_init.x - 60), randf_range(80, vs_init.y - 80)),
				"t": dur, "dur": dur,
				"variant": randi() % 3,
			})
	else:
		for h in _halluc_list:
			h.t -= delta
		_halluc_list = _halluc_list.filter(func(h): return h.t > 0.0)

	# Eyes from walls
	if _eye_t < 0.0:
		_eye_cd -= delta
		if _eye_cd <= 0.0:
			_eye_cd = randf_range(35.0, 75.0)
			_eye_t = 1.4
			_eye_pos = Vector2(randf_range(40, vs_init.x - 40), randf_range(40, vs_init.y - 40))
	else:
		_eye_t -= delta
		if _eye_t < 0.0:
			_eye_t = -1.0

	# Mirror moment
	if _mirror_t < 0.0:
		_mirror_cd -= delta
		if _mirror_cd <= 0.0:
			_mirror_t = 0.45
			_mirror_cd = randf_range(90.0, 180.0)
	else:
		_mirror_t -= delta
		if _mirror_t < 0.0:
			_mirror_t = -1.0

	# Corner text flashes
	if _corner_text_t < 0.0:
		_corner_text_cd -= delta
		if _corner_text_cd <= 0.0:
			_corner_text_cd = randf_range(20.0, 45.0)
			_corner_text_t = 1.3
			_corner_text = CORNER_TEXTS[randi() % CORNER_TEXTS.size()]
			_corner_text_pos = randi() % 4   # 0=TL, 1=TR, 2=BL, 3=BR
	else:
		_corner_text_t -= delta
		if _corner_text_t < 0.0:
			_corner_text_t = -1.0

	# === Кинематографические пылинки ===
	_cine_dust_cd -= delta
	var vs_cd = _viewport_size()
	if _cine_dust_cd <= 0.0 and _cine_dust.size() < 24:
		_cine_dust_cd = randf_range(0.15, 0.40)
		_cine_dust.append({
			"x": randf() * vs_cd.x,
			"y": randf() * vs_cd.y,
			"vx": randf_range(-8.0, 8.0),
			"vy": randf_range(-4.0, -1.0),  # плывут вверх
			"alpha": 0.0,
			"life": randf_range(4.0, 10.0),
			"max_life": 8.0,
		})
	for d in _cine_dust:
		d.x += d.vx * delta
		d.y += d.vy * delta
		d.life -= delta
		# Fade in первые 1.5 сек, fade out последние 1.5 сек
		d.alpha = clampf(min(d.life, d.max_life - d.life) * 0.7, 0.0, 0.6)
	_cine_dust = _cine_dust.filter(func(d): return d.life > 0.0)

	# Полоса трекинга плывёт вниз и зацикливается
	var vs_vhs = _viewport_size()
	_vhs_track_y += _vhs_track_speed * delta
	if _vhs_track_y > vs_vhs.y + 40.0:
		_vhs_track_y = -40.0
		# Случайно изменим скорость для разнообразия
		_vhs_track_speed = randf_range(25.0, 55.0)

	# Сбой синхронизации — раз в ~6-14 сек короткий "прыжок" картинки
	if _vhs_sync_t < 0.0:
		_vhs_sync_cd -= delta
		if _vhs_sync_cd <= 0.0:
			_vhs_sync_t   = randf_range(0.08, 0.25)
			_vhs_sync_off = randf_range(-12.0, 12.0)
			_vhs_sync_cd  = randf_range(6.0, 14.0)
	else:
		_vhs_sync_t -= delta
		if _vhs_sync_t < 0.0:
			_vhs_sync_t   = -1.0
			_vhs_sync_off = 0.0

	# Шёпоты — раз в 14-30 секунд мелькает фраза снизу на 2.5 сек
	if _whisper_t < 0.0:
		_whisper_cd -= delta
		if _whisper_cd <= 0.0:
			_whisper_dur  = randf_range(2.0, 3.5)
			_whisper_t    = _whisper_dur
			_whisper_text = _whisper_pool[randi() % _whisper_pool.size()]
			_whisper_cd   = randf_range(14.0, 30.0)
	else:
		_whisper_t -= delta
		if _whisper_t < 0.0:
			_whisper_t = -1.0

	# ── Ring buffer: record player world positions ──
	if _player and is_instance_valid(_player):
		_echo_ring[_echo_head] = _player.global_position
		_echo_head = (_echo_head + 1) % _echo_ring_sz

	# ── Eyes — up to 2 pairs of red dots in dark corners ──
	_eyes_cd -= delta
	if _eyes_cd <= 0.0 and _eyes.size() < 2:
		var vs   = _viewport_size()
		var dur  = randf_range(4.0, 9.0)
		# Always place in corner/edge dark zones
		var side = randi() % 4
		var pos: Vector2
		match side:
			0: pos = Vector2(randf_range(18, 80),           randf_range(18, 70))
			1: pos = Vector2(randf_range(vs.x - 80, vs.x - 18), randf_range(18, 70))
			2: pos = Vector2(randf_range(18, 80),           randf_range(vs.y - 80, vs.y - 30))
			3: pos = Vector2(randf_range(vs.x - 80, vs.x - 18), randf_range(vs.y - 80, vs.y - 30))
		_eyes.append({ "pos": pos, "t": dur, "dur": dur, "blink_t": 0.0 })
		_eyes_cd = randf_range(12.0, 35.0)
	# Update active pairs
	for i in range(_eyes.size() - 1, -1, -1):
		_eyes[i].t       -= delta
		_eyes[i].blink_t += delta
		if _eyes[i].t < 0.0:
			_eyes.remove_at(i)

	# ── Echo ──
	if _echo_t < 0.0:
		_echo_cd -= delta
		if _echo_cd <= 0.0:
			_echo_dur = randf_range(7.0, 11.0)
			_echo_t   = _echo_dur
			_echo_cd  = randf_range(50.0, 130.0)
			# Sample world position from 2.4s ago (approx 144 frames at 60fps)
			var lag_frames = 144
			var old_idx = (_echo_head - lag_frames + _echo_ring_sz) % _echo_ring_sz
			var old_world = _echo_ring[old_idx]
			if old_world != Vector2.ZERO and _player and is_instance_valid(_player):
				var vp = get_viewport()
				if vp:
					_echo_pos = vp.get_canvas_transform() * old_world
				else:
					_echo_pos = old_world
	else:
		_echo_t -= delta
		# Keep echo pos updated each frame while active (world→screen can shift with camera)
		if _echo_t >= 0.0 and _player and is_instance_valid(_player):
			var lag_frames = 144
			var old_idx = (_echo_head - lag_frames + _echo_ring_sz) % _echo_ring_sz
			var old_world = _echo_ring[old_idx]
			if old_world != Vector2.ZERO:
				var vp = get_viewport()
				if vp:
					_echo_pos = vp.get_canvas_transform() * old_world
		if _echo_t < 0.0:
			_echo_t = -1.0

	# ── Silhouette ──
	if _sil_t < 0.0:
		_sil_cd -= delta
		if _sil_cd <= 0.0:
			_sil_dur = randf_range(0.8, 2.0)
			_sil_t   = _sil_dur
			_sil_cd  = randf_range(70.0, 170.0)
			var vs2 = _viewport_size()
			var side2 = randi() % 2
			var sx = randf_range(20, 50) if side2 == 0 else randf_range(vs2.x - 50, vs2.x - 20)
			_sil_pos = Vector2(sx, vs2.y - 80)
	else:
		_sil_t -= delta
		if _sil_t < 0.0:
			_sil_t = -1.0

	# ── Glitch burst system ──
	if _glitch_hit_t >= 0.0:
		# In an active hit flash
		_glitch_hit_t -= delta
		if _glitch_hit_t < 0.0:
			_glitch_hit_t = -1.0
			if _glitch_hits_left > 0:
				_glitch_gap_t = randf_range(0.05, 0.16)  # brief gap before next hit
	elif _glitch_gap_t >= 0.0:
		# Waiting between hits
		_glitch_gap_t -= delta
		if _glitch_gap_t < 0.0:
			_glitch_gap_t = -1.0
			_start_glitch_hit()
	else:
		# Idle — countdown to next burst
		_glitch_cd -= delta
		if _glitch_cd <= 0.0:
			_glitch_cd = randf_range(18.0, 60.0)
			_glitch_hits_left = randi_range(2, 5)
			_start_glitch_hit()

	# ── No-exit ──
	if _noexit_t >= 0.0:
		_noexit_t -= delta
		if _noexit_t < 0.0:
			_noexit_t      = -1.0
			_noexit_active = false

	# Throttle: рисуем не каждый кадр (через раз) — экономит ~50% CPU на overlay
	if Engine.get_process_frames() % 2 == 0:
		_draw_node.queue_redraw()

func _start_glitch_hit() -> void:
	_glitch_hits_left -= 1
	_glitch_hit_t      = randf_range(0.04, 0.11)
	_glitch_strips.clear()
	var vs = _viewport_size()
	# 4–10 horizontal strips simulating shifted scanline blocks
	for _i in randi_range(4, 10):
		_glitch_strips.append({
			"y":      randf_range(0.0, vs.y),
			"h":      randf_range(2.0, 22.0),
			"dx":     randf_range(-80.0, 80.0),
			"bright": randf() > 0.65,
		})
	# One strong tear line
	_glitch_strips.append({
		"y":      randf_range(vs.y * 0.15, vs.y * 0.85),
		"h":      randf_range(1.0, 4.0),
		"dx":     randf_range(-140.0, 140.0),
		"bright": true,
	})

func _on_draw() -> void:
	var vs = _viewport_size()
	# Ambient-постобработка (кинематик-фильтр, психоделия, VHS) УБРАНА:
	# она рисовала ~250 прямоугольников КАЖДЫЙ кадр поверх всего экрана —
	# это главный источник лагов, и цветные фильтры были не к месту.
	# Оставляем только лёгкую виньетку и осмысленные хоррор-вспышки.
	_draw_vignette(vs)
	var any_active := false
	if _eyes.size() > 0:
		_draw_eyes()
		any_active = true
	if _echo_t >= 0.0:
		_draw_echo()
		any_active = true
	if _sil_t >= 0.0:
		_draw_silhouette(vs)
		any_active = true
	if _glitch_hit_t >= 0.0:
		_draw_glitch(vs)
		any_active = true
	if _noexit_active and _noexit_t >= 0.0:
		_draw_noexit(vs)
		any_active = true
	if _whisper_t >= 0.0:
		_draw_whisper(vs)
		any_active = true
	# Перерисовываем только пока активна анимация эффекта или трясётся окно.
	# В покое HUD-оверлей статичен и не жрёт CPU/GPU.
	if any_active or _win_shake_t >= 0.0:
		_draw_node.queue_redraw()

# ── Vignette ──────────────────────────────────────────────────────────────────
func _draw_vignette(vs: Vector2) -> void:
	var strength = 1.0 + sin(_vignette_t * 0.4) * 0.18
	var steps    = 14
	for i in steps:
		var t     = float(i) / float(steps)
		var alpha = pow(1.0 - t, 2.0) * 0.09 * strength
		var inset = float(i) * 3.5
		var c     = Color(0.0, 0.0, 0.0, alpha)
		# Four edge rects fading inward
		_draw_node.draw_rect(Rect2(0,                 0,                   vs.x, inset + 3.5), c)
		_draw_node.draw_rect(Rect2(0,                 vs.y - inset - 3.5,  vs.x, inset + 3.5), c)
		_draw_node.draw_rect(Rect2(0,                 0,                   inset + 3.5, vs.y), c)
		_draw_node.draw_rect(Rect2(vs.x - inset - 3.5, 0,                  inset + 3.5, vs.y), c)

# ── Eyes in darkness — simple red dots ───────────────────────────────────────
func _draw_eyes() -> void:
	for e in _eyes:
		var elapsed  = e.dur - e.t
		var fade_in  = clampf(elapsed / 0.6, 0.0, 1.0)
		var fade_out = clampf(e.t / 0.8, 0.0, 1.0)
		var alpha    = fade_in * fade_out
		# Slow blink: every ~4s, closes for 0.2s
		var bp = fmod(e.blink_t, 4.2)
		if bp > 4.0:
			alpha *= 1.0 - clampf((bp - 4.0) / 0.1, 0.0, 1.0)
		elif bp > 4.1:
			alpha *= clampf((bp - 4.1) / 0.1, 0.0, 1.0)
		if alpha < 0.01:
			continue
		var pos = e.pos
		# Two dots, 10px apart — just tiny glowing red points
		for side in [-5.0, 5.0]:
			var ep = pos + Vector2(side, 0.0)
			# Very faint outer glow
			_draw_node.draw_circle(ep, 5.5, Color(0.7, 0.0, 0.0, alpha * 0.12))
			# The dot itself — small, dim red
			_draw_node.draw_circle(ep, 2.2, Color(0.82, 0.04, 0.04, alpha * 0.85))

# ── Player echo / ghost ───────────────────────────────────────────────────────
func _draw_echo() -> void:
	if _echo_pos == Vector2.ZERO:
		return
	var elapsed  = _echo_dur - _echo_t
	var fade_in  = clampf(elapsed / 1.5, 0.0, 1.0)
	var fade_out = clampf(_echo_t / 1.5, 0.0, 1.0)
	var alpha    = fade_in * fade_out * 0.35

	_draw_node.draw_set_transform(_echo_pos, 0.0, Vector2(1.8, 1.8))

	# Player silhouette rects (coords relative to origin = feet)
	# Legs
	_draw_node.draw_rect(Rect2(-4, -8, 3, 8),   Color(0.25, 0.20, 0.15, alpha))
	_draw_node.draw_rect(Rect2( 1, -8, 3, 8),   Color(0.25, 0.20, 0.15, alpha))
	# Body
	_draw_node.draw_rect(Rect2(-5, -18, 10, 10), Color(0.35, 0.35, 0.40, alpha))
	# Head
	_draw_node.draw_rect(Rect2(-4, -26, 8, 8),  Color(0.90, 0.75, 0.55, alpha))
	# Helmet
	_draw_node.draw_rect(Rect2(-5, -28, 10, 4), Color(0.50, 0.50, 0.55, alpha))

	_draw_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))

# ── Silhouette ────────────────────────────────────────────────────────────────
func _draw_silhouette(vs: Vector2) -> void:
	var elapsed  = _sil_dur - _sil_t
	var fade_in  = clampf(elapsed / 0.3, 0.0, 1.0)
	var fade_out = clampf(_sil_t / 0.3, 0.0, 1.0)
	var alpha    = fade_in * fade_out * 0.72

	var sc = Color(0.04, 0.02, 0.05, alpha)
	var sx = _sil_pos.x
	var sy = _sil_pos.y

	# Head circle
	_draw_node.draw_circle(Vector2(sx, sy - 52), 11.0, sc)
	# Body
	_draw_node.draw_rect(Rect2(sx - 8, sy - 41, 16, 30), sc)
	# Left arm
	_draw_node.draw_rect(Rect2(sx - 18, sy - 40, 10, 5), sc)
	# Right arm
	_draw_node.draw_rect(Rect2(sx + 8,  sy - 40, 10, 5), sc)
	# Left leg
	_draw_node.draw_rect(Rect2(sx - 8, sy - 11, 6, 20), sc)
	# Right leg
	_draw_node.draw_rect(Rect2(sx + 2,  sy - 11, 6, 20), sc)

# ── Glitch — realistic digital artifact ──────────────────────────────────────
func _draw_glitch(vs: Vector2) -> void:
	# Strong chromatic aberration — red channel left, blue right
	_draw_node.draw_rect(Rect2(-16, 0, vs.x, vs.y), Color(1.0, 0.0, 0.0, 0.06))
	_draw_node.draw_rect(Rect2( 16, 0, vs.x, vs.y), Color(0.0, 0.0, 1.0, 0.06))

	# Horizontal block shifts — the core of a digital glitch
	for strip in _glitch_strips:
		var col: Color
		if strip.bright:
			# Bright phosphor spike — washed-out greenish-white
			col = Color(0.82, 0.92, 0.80, 0.42)
		else:
			# Dark signal dropout
			col = Color(0.0, 0.0, 0.0, 0.60)
		_draw_node.draw_rect(Rect2(strip.dx, strip.y, vs.x, strip.h), col)

	# Brief white flash at the very start of each hit (first 20% of hit duration)
	var flash_a = clampf(_glitch_hit_t / 0.02, 0.0, 1.0) * 0.18
	if flash_a > 0.0:
		_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y), Color(1.0, 1.0, 1.0, flash_a))

# ── No-exit room ──────────────────────────────────────────────────────────────
func _draw_noexit(vs: Vector2) -> void:
	var elapsed  = 12.0 - _noexit_t
	var fade_in  = clampf(elapsed / 1.2, 0.0, 1.0)
	var fade_out = clampf(_noexit_t / 1.2, 0.0, 1.0)
	var alpha    = fade_in * fade_out

	var stone_c = Color(0.28, 0.26, 0.24, alpha * 0.92)
	var crack_c = Color(0.15, 0.14, 0.12, alpha * 0.85)

	# Top stone bar
	_draw_node.draw_rect(Rect2(0, 0, vs.x, 32), stone_c)
	# Bottom stone bar
	_draw_node.draw_rect(Rect2(0, vs.y - 32, vs.x, 32), stone_c)

	# Crack lines on top bar
	var crack_xs = [vs.x * 0.1, vs.x * 0.3, vs.x * 0.5, vs.x * 0.68, vs.x * 0.85]
	for cx in crack_xs:
		_draw_node.draw_line(Vector2(cx, 0),         Vector2(cx - 4, 32), crack_c, 1.0)
		_draw_node.draw_line(Vector2(cx - 4, 32),    Vector2(cx + 3, 18), crack_c, 0.7)

	# Crack lines on bottom bar
	for cx in crack_xs:
		_draw_node.draw_line(Vector2(cx, vs.y - 32), Vector2(cx + 5, vs.y), crack_c, 1.0)
		_draw_node.draw_line(Vector2(cx + 5, vs.y),  Vector2(cx - 2, vs.y - 16), crack_c, 0.7)

	# Centered text "выхода нет"
	var text_alpha = fade_in * fade_out
	_draw_node.draw_string(ThemeDB.fallback_font,
		Vector2(vs.x * 0.5, vs.y * 0.5 + 5),
		"выхода нет",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
		Color(0.75, 0.70, 0.65, text_alpha))

# ── Liminal/Dreamy atmosphere overlay (Lucid Blocks-style) ──────────────────
func _draw_cinematic(vs: Vector2) -> void:
	var k = cine_intensity
	var t = _vhs_t  # глобальное время для пульсаций

	# 1) Двух-тоновая цветокоррекция: верх — холодный teal/cyan, низ — pink/purple
	# Как dream-pop постер. Тонко.
	# Верхняя половина — teal-aqua вуаль
	_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y * 0.55),
		Color(0.20, 0.50, 0.55, 0.10 * k))
	# Нижняя — magenta-pink
	_draw_node.draw_rect(Rect2(0, vs.y * 0.45, vs.x, vs.y * 0.55),
		Color(0.55, 0.18, 0.45, 0.08 * k))

	# 2) Тонкий "хейз" — мягкое полупрозрачное молочное марево
	# Пульсирует медленно, создаёт ощущение жары/тумана
	var haze_pulse = 0.5 + 0.5 * sin(t * 0.3)
	_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y),
		Color(0.85, 0.88, 0.95, 0.04 * k * haze_pulse))

	# 3) Зерно — мягкое цветное, в палитре сцены (teal/pink)
	_cine_rng.seed = _vhs_noise_seed + 12345
	for i in 28:
		var gx = _cine_rng.randf() * vs.x
		var gy = _cine_rng.randf() * vs.y
		var ga = _cine_rng.randf_range(0.04, 0.10) * k
		# Случайный teal или pink оттенок
		var pick = _cine_rng.randf()
		var gc: Color
		if pick < 0.5:
			gc = Color(0.45, 0.85, 0.95, ga)  # teal
		else:
			gc = Color(0.95, 0.55, 0.85, ga)  # pink
		_draw_node.draw_rect(Rect2(gx, gy, 1.0, 1.0), gc)

	# 4) Пылинки — флюоресцентные, светящиеся, более крупные. Цвет варьируется.
	for d in _cine_dust:
		var a = d.alpha * k
		# Сдвигаем цвет в зависимости от позиции по экрану — top=teal, bottom=pink
		var t_pos = clampf(d.y / vs.y, 0.0, 1.0)
		var dust_col = Color(0.55, 0.85, 0.95).lerp(Color(0.95, 0.55, 0.85), t_pos)
		# Большой мягкий halo
		_draw_node.draw_circle(Vector2(d.x, d.y), 5.0,
			Color(dust_col.r, dust_col.g, dust_col.b, a * 0.10))
		# Средний glow
		_draw_node.draw_circle(Vector2(d.x, d.y), 2.5,
			Color(dust_col.r, dust_col.g, dust_col.b, a * 0.32))
		# Яркое ядро
		_draw_node.draw_circle(Vector2(d.x, d.y), 1.0,
			Color(1.0, 1.0, 1.0, a * 0.85))

	# 5) Параллельные горизонтальные "лучи света" — еле заметные, медленно плывут
	# Создают ощущение что в комнате льётся sunset-свет через окно
	var beam_count = 4
	for bi in beam_count:
		var by_base = vs.y * (0.1 + bi * 0.20)
		var by_wave = sin(t * 0.15 + bi * 1.7) * 12.0
		var by = by_base + by_wave
		_draw_node.draw_rect(Rect2(0, by, vs.x, 32.0),
			Color(1.0, 0.95, 0.85, 0.012 * k))

	# 6) Lens streaks — пинковые/teal, очень тонкие
	for i in 3:
		var sy = vs.y * (0.18 + i * 0.30)
		var streak_col = Color(0.85, 0.65, 0.95) if i % 2 == 0 else Color(0.65, 0.95, 0.95)
		_draw_node.draw_line(
			Vector2(0, sy),
			Vector2(vs.x * 0.4, sy - 22),
			Color(streak_col.r, streak_col.g, streak_col.b, 0.035 * k), 1.2)

# ── PSYCHEDELIC overlay (все эффекты вместе, дозировано) ────────────────────
func _draw_psychedelic(vs: Vector2) -> void:
	var k = psy_intensity
	if k <= 0.0:
		return
	var t = _vhs_t

	# (Star field, floating cubes, sacred geometry убраны по запросу — "космос" мешал)

	# 4) Hue-cycling overlay — глобальный медленный сдвиг цвета
	var hue = fmod(_hue_phase, 1.0)
	var hue_col = Color.from_hsv(hue, 0.35, 1.0, 0.06 * k)
	_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y), hue_col)

	# 5) Rainbow wave (когда активна)
	if _rainbow_t > 0.0:
		var wave_alpha = clampf(_rainbow_t / 2.5, 0.0, 1.0) * 0.18 * k
		# 6 цветных полос плывут вверх
		var bands = 8
		for i in bands:
			var band_y = fmod(t * 60.0 + i * (vs.y / bands), vs.y + 80.0) - 40.0
			var band_hue = float(i) / float(bands)
			var bc = Color.from_hsv(band_hue, 0.85, 1.0, wave_alpha)
			_draw_node.draw_rect(Rect2(0, band_y, vs.x, 24), bc)

	# 6) Acid flash — короткая полная инверсия (имитация белым/чёрным)
	if _acid_t > 0.0:
		var phase = _acid_t / 0.30
		# Быстрый яркий пик
		var pulse = sin(phase * PI)
		_draw_node.draw_rect(Rect2(0, 0, vs.x, vs.y),
			Color(1.0, 0.85, 1.0, 0.55 * pulse * k))
		# RGB-разъезд края экрана сильно увеличивается
		_draw_node.draw_rect(Rect2(0, 0, 16, vs.y),
			Color(1, 0, 0, 0.3 * pulse * k))
		_draw_node.draw_rect(Rect2(vs.x - 16, 0, 16, vs.y),
			Color(0, 0.5, 1, 0.3 * pulse * k))

	# 7) Hallucination silhouettes — призрачные силуэты "монстров"
	for h in _halluc_list:
		var life_frac = h.t / h.dur
		var fade_in = clampf((1.0 - life_frac) / 0.2, 0.0, 1.0)
		var fade_out = clampf(life_frac / 0.3, 0.0, 1.0)
		var a = fade_in * fade_out * 0.45 * k
		_draw_hallucination(h.pos, h.variant, a)

	# 8) Eyes from walls — открывающийся глаз
	if _eye_t > 0.0:
		var life_frac = _eye_t / 1.4
		var fade = sin(life_frac * PI)
		var a = fade * 0.7 * k
		_draw_psy_eye(_eye_pos, a, t)

	# 9) Corner text flashes
	if _corner_text_t > 0.0:
		var life_frac = _corner_text_t / 1.3
		var a = clampf(min(life_frac, 1.0 - life_frac) * 2.5, 0.0, 1.0) * 0.85 * k
		_draw_corner_text(vs, _corner_text, _corner_text_pos, a)

	# 10) Subtle постоянная chromatic aberration (по краям)
	# Уже частично делается через рамки, добавим лёгкие цветные ободки
	_draw_node.draw_rect(Rect2(0, 0, 4, vs.y),
		Color(1, 0.2, 0.4, 0.06 * k))
	_draw_node.draw_rect(Rect2(vs.x - 4, 0, 4, vs.y),
		Color(0.2, 0.5, 1, 0.06 * k))

func _draw_hallucination(pos: Vector2, variant: int, alpha: float) -> void:
	match variant:
		0:
			# Высокий силуэт-человек
			_draw_node.draw_rect(Rect2(pos.x - 6, pos.y - 18, 12, 14),
				Color(0.1, 0.0, 0.15, alpha))
			_draw_node.draw_circle(Vector2(pos.x, pos.y - 22), 6,
				Color(0.1, 0.0, 0.15, alpha))
			# Глаза-точки
			_draw_node.draw_circle(Vector2(pos.x - 2, pos.y - 23), 1,
				Color(1, 0.2, 0.3, alpha * 1.3))
			_draw_node.draw_circle(Vector2(pos.x + 2, pos.y - 23), 1,
				Color(1, 0.2, 0.3, alpha * 1.3))
		1:
			# Шарик с щупальцами
			_draw_node.draw_circle(pos, 8,
				Color(0.5, 0.0, 0.4, alpha))
			for i in 6:
				var a = float(i) / 6.0 * TAU + alpha * 4.0
				var end = pos + Vector2(cos(a), sin(a)) * 18
				_draw_node.draw_line(pos, end,
					Color(0.5, 0.0, 0.4, alpha * 0.6), 1.5)
		2:
			# Кружок-глаз
			_draw_node.draw_circle(pos, 10,
				Color(0.95, 0.85, 0.7, alpha))
			_draw_node.draw_circle(pos, 5,
				Color(0.55, 0.05, 0.1, alpha))
			_draw_node.draw_circle(pos, 2.5,
				Color(0, 0, 0, alpha))

func _draw_psy_eye(pos: Vector2, alpha: float, time_var: float) -> void:
	# Открывающийся "глаз в стене"
	var w = 24.0
	var h = 12.0
	# Подложка-тёмный овал (как "разрыв" в стене)
	var bg_pts = PackedVector2Array()
	for s in 18:
		var a = float(s) / 18.0 * TAU
		bg_pts.append(pos + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.5))
	_draw_node.draw_colored_polygon(bg_pts, Color(0.02, 0.02, 0.05, alpha * 0.8))
	# Белок
	var sclera_pts = PackedVector2Array()
	for s in 18:
		var a = float(s) / 18.0 * TAU
		sclera_pts.append(pos + Vector2(cos(a) * w * 0.42, sin(a) * h * 0.4))
	_draw_node.draw_colored_polygon(sclera_pts,
		Color(0.85, 0.78, 0.65, alpha))
	# Радужка следит за центром экрана (имитация)
	var iris_pos = pos + Vector2(sin(time_var) * 3.0, cos(time_var) * 1.0)
	_draw_node.draw_circle(iris_pos, h * 0.4,
		Color(0.55, 0.10, 0.10, alpha))
	_draw_node.draw_circle(iris_pos, h * 0.18,
		Color(0, 0, 0, alpha))
	# Блик
	_draw_node.draw_circle(iris_pos + Vector2(-1, -1), 1,
		Color(1, 1, 1, alpha * 0.8))

func _draw_corner_text(vs: Vector2, txt: String, corner: int, alpha: float) -> void:
	var font := ThemeDB.fallback_font
	var fsize = 12
	var s = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var margin = 14.0
	var x = margin
	var y = margin + s.y
	match corner:
		0: x = margin; y = margin + s.y
		1: x = vs.x - margin - s.x; y = margin + s.y
		2: x = margin; y = vs.y - margin
		3: x = vs.x - margin - s.x; y = vs.y - margin
	# Лёгкое дрожание
	x += randf_range(-0.7, 0.7)
	y += randf_range(-0.7, 0.7)
	# Чёрная обводка
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0: continue
			_draw_node.draw_string(font, Vector2(x + ox, y + oy),
				txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
				Color(0, 0, 0, alpha))
	# Цвет: розово-кровавый
	_draw_node.draw_string(font, Vector2(x, y),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
		Color(0.95, 0.30, 0.55, alpha))

# ── VHS overlay ───────────────────────────────────────────────────────────────
func _draw_vhs(vs: Vector2) -> void:
	var k = _vhs_intensity

	# 1) Сканлайны — реже (каждые 4 px) — заметно дешевле, выглядит так же
	var scan_a = 0.10 * k
	var y_off = fmod(_vhs_t * 18.0, 4.0)
	var yy = -y_off
	while yy < vs.y:
		_draw_node.draw_rect(Rect2(0.0, yy, vs.x, 1.0),
			Color(0.0, 0.0, 0.0, scan_a))
		yy += 4.0

	# 2) Хроматическая аберрация на краях — красный/синий "разъезжается"
	var ca_a = 0.06 * k
	var bw = 8.0
	_draw_node.draw_rect(Rect2(0.0, 0.0, bw, vs.y),
		Color(1.0, 0.0, 0.0, ca_a))
	_draw_node.draw_rect(Rect2(vs.x - bw, 0.0, bw, vs.y),
		Color(0.0, 0.4, 1.0, ca_a))

	# 3) Полоса трекинга (tape head) — широкая яркая полоса плывёт вниз
	var ty = _vhs_track_y + _vhs_sync_off
	var bar_h = 26.0
	_draw_node.draw_rect(Rect2(0.0, ty, vs.x, bar_h),
		Color(1.0, 1.0, 1.0, 0.07 * k))
	_draw_node.draw_rect(Rect2(0.0, ty + bar_h - 4.0, vs.x, 4.0),
		Color(0.0, 0.0, 0.0, 0.30 * k))
	# Шум внутри полосы — переиспользуемый RNG
	_vhs_rng_band.seed = _vhs_noise_seed
	for i in 4:  # было 10
		var ry = ty + _vhs_rng_band.randf() * bar_h
		var rw = _vhs_rng_band.randf_range(40.0, vs.x)
		var rx = _vhs_rng_band.randf() * (vs.x - rw)
		var rh = _vhs_rng_band.randf_range(1.0, 3.0)
		_draw_node.draw_rect(Rect2(rx, ry, rw, rh),
			Color(1.0, 1.0, 1.0, _vhs_rng_band.randf_range(0.05, 0.20) * k))

	# 4) Статичный шум — переиспользуемый RNG, меньше точек
	_vhs_rng_static.seed = _vhs_noise_seed + 7777
	for i in 25:  # было 90
		var dx = _vhs_rng_static.randf() * vs.x
		var dy = _vhs_rng_static.randf() * vs.y
		var da = _vhs_rng_static.randf_range(0.05, 0.18) * k
		var dc = _vhs_rng_static.randf()
		_draw_node.draw_rect(Rect2(dx, dy, 1.0, 1.0),
			Color(dc, dc, dc, da))

	# 5) Сбой синхронизации — короткий "прыжок" части кадра
	if _vhs_sync_t > 0.0:
		var split_y = randf() * vs.y
		var slice_h = randf_range(20.0, 80.0)
		# Тёмная полоска-щель
		_draw_node.draw_rect(Rect2(0.0, split_y, vs.x, 2.0),
			Color(0.0, 0.0, 0.0, 0.45 * k))
		_draw_node.draw_rect(Rect2(0.0, split_y + slice_h, vs.x, 2.0),
			Color(0.0, 0.0, 0.0, 0.45 * k))
		# RGB-разъезд в этой полосе
		_draw_node.draw_rect(Rect2(-6.0, split_y, vs.x, slice_h),
			Color(1.0, 0.0, 0.0, 0.10 * k))
		_draw_node.draw_rect(Rect2(6.0, split_y, vs.x, slice_h),
			Color(0.0, 0.6, 1.0, 0.10 * k))

	# 6) Лёгкий зеленовато-сепия оттенок (старая лента) — едва заметный
	_draw_node.draw_rect(Rect2(0.0, 0.0, vs.x, vs.y),
		Color(0.10, 0.18, 0.05, 0.04 * k))

	# 7) REC-индикатор и фейк-таймкод в левом верхнем углу
	var font := ThemeDB.fallback_font
	# Красная пульсирующая точка
	var rec_alpha = 0.55 + 0.45 * sin(_vhs_t * TAU * 1.2)
	_draw_node.draw_circle(Vector2(18.0, 18.0), 4.0,
		Color(1.0, 0.1, 0.1, rec_alpha))
	_draw_node.draw_string(font, Vector2(28.0, 22.0),
		"REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.95, 0.95, 0.95, 0.85))
	# Таймкод HH:MM:SS
	var total = int(_vhs_tape_secs)
	var hh = total / 3600
	var mm = (total / 60) % 60
	var ss = total % 60
	var tc = "%02d:%02d:%02d" % [hh, mm, ss]
	_draw_node.draw_string(font, Vector2(18.0, 36.0),
		tc, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.85, 0.85, 0.85, 0.7))
	# Подпись "PLAY ▶" / счётчик петли (мерцает)
	if int(_vhs_t * 2.0) % 8 < 7:
		_draw_node.draw_string(font, Vector2(vs.x - 90.0, 22.0),
			"PLAY ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.95, 0.95, 0.95, 0.7))

# ── Whisper (фразы безнадёжности внизу экрана) ───────────────────────────────
func _draw_whisper(vs: Vector2) -> void:
	var elapsed  = _whisper_dur - _whisper_t
	var fade_in  = clampf(elapsed / 0.5, 0.0, 1.0)
	var fade_out = clampf(_whisper_t / 0.6, 0.0, 1.0)
	var a = fade_in * fade_out * 0.85
	var font := ThemeDB.fallback_font
	var fsize := 14
	var tw = font.get_string_size(_whisper_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	# Лёгкое дрожание
	var jitter = Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7))
	var base = Vector2(vs.x * 0.5 - tw * 0.5, vs.y - 80.0) + jitter
	# Тёмная "обводка"
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0: continue
			_draw_node.draw_string(font, base + Vector2(ox, oy),
				_whisper_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
				Color(0, 0, 0, a))
	# Красноватый текст
	_draw_node.draw_string(font, base,
		_whisper_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
		Color(0.85, 0.20, 0.20, a))

# ── Helpers ───────────────────────────────────────────────────────────────────
func _viewport_size() -> Vector2:
	var vp = get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return Vector2(1280, 720)
