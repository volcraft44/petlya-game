extends Node2D

signal event_ended

enum Phase { APPEAR, WALK, TENSION, RUSH, SLASH, DISSOLVE, DONE }
var phase: Phase = Phase.APPEAR

var phase_timer: float  = 0.0
var player_ref          = null

var spider_x: float     = 0.0
var spider_y: float     = 0.0
var facing_right: bool  = false

var appear_alpha: float = 0.0
var dissolve_t:  float  = 0.0
var leg_phase:   float  = 0.0
var body_bob:    float  = 0.0
var dissolve_pts: Array = []

var vignette_alpha: float = 0.0
var vignette_node         = null

var step_ap: AudioStreamPlayer = null
var step_pb                    = null
var step_interval: float       = 0.80
var step_countdown: float      = 0.40

var slash_timer: float = 0.0
var slash_dir:   int   = 1

const BW:       float = 110.0
const BH:       float =  60.0
const LEG_SEG1: float =  90.0
const LEG_SEG2: float =  75.0
const WALK_SPEED: float =  28.0
const RUSH_SPEED: float = 120.0

# 8 legs: [x_frac of BW, y_frac of BH, base_angle, phase_offset]
const LEG_DATA = [
	[-0.55, -0.5, -1.25,  0.00],
	[-0.80, -0.3, -0.85,  PI  ],
	[-0.85,  0.1, -0.55,  0.00],
	[-0.60,  0.35,-0.25,  PI  ],
	[ 0.55, -0.5,  1.25,  0.00],
	[ 0.80, -0.3,  0.85,  PI  ],
	[ 0.85,  0.1,  0.55,  0.00],
	[ 0.60,  0.35, 0.25,  PI  ],
]

# ─────────────────── setup ────────────────────────────────────────

func setup(p_player, spawn_side: int) -> void:
	player_ref   = p_player
	spider_y     = p_player.global_position.y
	spider_x     = p_player.global_position.x + spawn_side * 1000.0
	facing_right = spawn_side < 0
	phase_timer  = 1.2

	var stream           = AudioStreamGenerator.new()
	stream.mix_rate      = 22050.0
	stream.buffer_length = 0.15
	step_ap              = AudioStreamPlayer.new()
	step_ap.stream       = stream
	step_ap.volume_db    = -4.0
	add_child(step_ap)
	step_ap.play()
	step_pb = step_ap.get_stream_playback()

# ─────────────────── process ──────────────────────────────────────

func _process(delta: float) -> void:
	leg_phase  += delta * 2.8
	body_bob    = sin(leg_phase * 0.55) * 2.5
	phase_timer -= delta

	match phase:
		Phase.APPEAR:
			appear_alpha = minf(appear_alpha + delta * 0.9, 1.0)
			if phase_timer <= 0.0:
				phase       = Phase.WALK
				phase_timer = 99.0

		Phase.WALK:
			_move_toward(delta, WALK_SPEED)
			_tick_steps(delta)
			if is_instance_valid(player_ref):
				var dist2d = Vector2(spider_x, spider_y).distance_to(player_ref.global_position)
				# Force tension after 5s even if player runs away
				if dist2d < 320.0 or phase_timer <= 94.0:
					phase       = Phase.TENSION
					phase_timer = 1.8

		Phase.TENSION:
			_move_toward(delta, 10.0)
			_tick_steps(delta)
			step_interval = 0.55
			if phase_timer <= 0.0:
				phase         = Phase.RUSH
				step_interval = 0.22

		Phase.RUSH:
			_move_toward(delta, RUSH_SPEED)
			_tick_steps(delta)
			if is_instance_valid(player_ref):
				var dist2d = Vector2(spider_x, spider_y).distance_to(player_ref.global_position)
				if dist2d < 90.0:
					_trigger_slash()

		Phase.SLASH:
			slash_timer -= delta
			if slash_timer <= 0.0:
				_begin_dissolve()

		Phase.DISSOLVE:
			dissolve_t = minf(dissolve_t + delta * 1.6, 1.0)
			for p in dissolve_pts:
				p["pos"]  += p["vel"] * delta
				p["vel"]  += Vector2(0, 220) * delta
				p["life"] -= delta
			if dissolve_t >= 1.0:
				phase = Phase.DONE
				event_ended.emit()
				queue_free()
				return

	queue_redraw()
	if is_instance_valid(vignette_node):
		vignette_node.queue_redraw()

# ─────────────────── helpers ──────────────────────────────────────

func _move_toward(delta: float, spd: float) -> void:
	if not is_instance_valid(player_ref): return
	var target = player_ref.global_position
	var diff   = Vector2(target.x - spider_x, target.y - spider_y)
	facing_right = diff.x >= 0.0
	if diff.length_squared() > 1.0:
		var step = diff.normalized() * spd * delta
		spider_x += step.x
		spider_y += step.y

func _tick_steps(delta: float) -> void:
	step_countdown -= delta
	if step_countdown <= 0.0:
		step_countdown = step_interval
		_play_footstep()

func _trigger_slash() -> void:
	phase       = Phase.SLASH
	slash_timer = 0.85
	slash_dir   = 1 if facing_right else -1
	if is_instance_valid(player_ref):
		player_ref.is_attacking      = true
		player_ref.attack_anim_timer = 0.4
		player_ref.attack_timer      = 0.4

func _begin_dissolve() -> void:
	phase      = Phase.DISSOLVE
	dissolve_t = 0.0
	for i in 55:
		var ang  = randf() * TAU
		var spd2 = randf_range(30.0, 240.0)
		dissolve_pts.append({
			"pos":  Vector2(spider_x, spider_y - BH),
			"vel":  Vector2(cos(ang) * spd2, sin(ang) * spd2 - 80.0),
			"life": randf_range(0.4, 1.1),
			"max":  1.1,
			"r":    randf_range(0.05, 0.25),
			"size": randf_range(4.0, 14.0),
		})

func _play_footstep() -> void:
	if step_pb == null: return
	var frames = int(22050.0 * 0.14)
	var buf    = PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var t   = float(i) / 22050.0
		var env = exp(-t * 22.0)
		var s2  = (sin(TAU * 48.0 * t) * 0.65
				 + sin(TAU * 95.0 * t + sin(t * 380.0) * 3.5) * 0.35) * env
		buf[i]  = Vector2(clampf(s2 * 0.75, -1.0, 1.0),
						  clampf(s2 * 0.75, -1.0, 1.0))
	step_pb.push_buffer(buf)

# ─────────────────── draw ─────────────────────────────────────────

func _draw() -> void:
	if phase == Phase.DONE: return

	var alpha = appear_alpha
	if phase == Phase.DISSOLVE:
		alpha = 1.0 - dissolve_t * dissolve_t

	var px = spider_x
	var py = spider_y
	var s  = 1 if facing_right else -1

	# Dissolve burst particles
	if phase == Phase.DISSOLVE:
		for p in dissolve_pts:
			if p["life"] > 0.0:
				var a = (p["life"] / p["max"]) * alpha
				draw_circle(p["pos"], p["size"] * a,
					Color(p["r"], 0.0, p["r"] * 0.5, a * 0.9))
		if alpha < 0.05: return

	# Silk drag-lines trailing from abdomen
	for i in 6:
		var off_x = (-2.5 + float(i)) * 16.0
		draw_line(
			Vector2(px + off_x, py - BH * 0.4),
			Vector2(px + off_x + randf_range(-5.0, 5.0), py - BH * 2.0),
			Color(0.7, 0.7, 0.6, alpha * 0.18), 0.8)

	_draw_legs(px, py, s, alpha)
	_draw_body(px, py, s, alpha)

	# Slash arc — player swings, hits nothing
	if phase == Phase.SLASH and slash_timer > 0.3 and is_instance_valid(player_ref):
		var t2  = 1.0 - (slash_timer - 0.3) / 0.55
		var pp  = player_ref.global_position
		var r   = 28.0 + t2 * 22.0
		var sa  = (1.0 - t2) * 0.85
		for i in 6:
			var ang = (-0.7 + float(i) * 0.28) * float(slash_dir)
			draw_line(pp + Vector2(0, -12),
				pp + Vector2(cos(ang) * r, -12.0 + sin(ang) * r),
				Color(0.95, 0.95, 1.0, sa), 2.2)

# ─────────────────── legs ─────────────────────────────────────────

func _draw_legs(px: float, py: float, _s: int, alpha: float) -> void:
	for ld in LEG_DATA:
		var root_x:   float = px + ld[0] * BW
		var root_y:   float = py - BH * 0.5 + ld[1] * BH
		var base_ang: float = ld[2]
		var ph_off:   float = ld[3]

		var swing = sin(leg_phase + ph_off) * 0.22
		var ang1  = base_ang + swing
		var knee  = Vector2(root_x + cos(ang1) * LEG_SEG1,
							root_y + sin(ang1) * LEG_SEG1)
		var ang2  = ang1 + (0.5 if base_ang > 0 else -0.5) + swing * 0.5
		var tip   = Vector2(knee.x + cos(ang2) * LEG_SEG2,
							knee.y + sin(ang2) * LEG_SEG2)

		draw_line(Vector2(root_x, root_y), knee,
			Color(0.08, 0.04, 0.08, alpha), 6.0)
		draw_line(knee, tip,
			Color(0.12, 0.06, 0.12, alpha * 0.85), 4.0)

		# Hair spikes along upper segment
		for h in 4:
			var t2  = float(h) / 3.0
			var hp  = Vector2(root_x, root_y).lerp(knee, t2)
			var perp = Vector2(-sin(ang1), cos(ang1)) * randf_range(4.0, 9.0)
			draw_line(hp, hp + perp,
				Color(0.18, 0.08, 0.18, alpha * 0.5), 1.0)

# ─────────────────── body ─────────────────────────────────────────

func _draw_body(px: float, py: float, s: int, alpha: float) -> void:
	var by = py - BH + body_bob

	# Abdomen — large rear oval
	var ab_cx = px - s * BW * 0.4
	_draw_ellipse(ab_cx, by + 15.0, BW * 0.55, BH * 0.72, alpha,
		Color(0.07, 0.03, 0.08))
	# Hourglass stripes
	for i in 3:
		_draw_ellipse(ab_cx, by + 5.0 + float(i) * 12.0,
			BW * 0.2, 5.0, alpha * 0.6, Color(0.35, 0.08, 0.05))
	# Body hair
	for h in 16:
		var ang = float(h) / 16.0 * TAU
		var hx  = ab_cx + cos(ang) * BW * 0.52
		var hy  = by + 15.0 + sin(ang) * BH * 0.68
		draw_line(Vector2(hx, hy),
			Vector2(hx + cos(ang) * 10.0, hy + sin(ang) * 7.0),
			Color(0.2, 0.07, 0.22, alpha * 0.45), 1.0)

	# Cephalothorax — front oval
	var ct_cx = px + s * BW * 0.18
	_draw_ellipse(ct_cx, by - 4.0, BW * 0.42, BH * 0.55, alpha,
		Color(0.10, 0.04, 0.11))

	# Chelicerae / mandibles
	var fang_base = Vector2(ct_cx + s * BW * 0.35, by + BH * 0.18)
	for side2 in [-1, 1]:
		var tip_x = fang_base.x + s * 28.0
		var tip_y = fang_base.y + side2 * 22.0 + 18.0
		draw_line(fang_base, Vector2(tip_x, tip_y),
			Color(0.15, 0.08, 0.10, alpha), 7.0)
		draw_circle(Vector2(tip_x, tip_y), 5.0,
			Color(0.22, 0.12, 0.12, alpha))

	# Drool
	var drool_x   = ct_cx + s * BW * 0.42
	var drool_len = 18.0 + abs(sin(leg_phase * 1.3)) * 14.0
	draw_line(Vector2(drool_x, by + BH * 0.25),
		Vector2(drool_x, by + BH * 0.25 + drool_len),
		Color(0.55, 0.75, 0.3, alpha * 0.55), 2.0)

	# 8 glowing eyes
	var eye_positions = [
		Vector2( 0.22, -0.35), Vector2(-0.10, -0.42),
		Vector2( 0.10, -0.28), Vector2(-0.22, -0.32),
		Vector2( 0.28, -0.20), Vector2(-0.28, -0.22),
		Vector2( 0.05, -0.48), Vector2(-0.05, -0.20),
	]
	var eye_pulse = 0.6 + abs(sin(leg_phase * 1.1)) * 0.4
	for ep in eye_positions:
		var ex = ct_cx + ep.x * BW * 0.7
		var ey = by    + ep.y * BH
		draw_circle(Vector2(ex, ey), 7.0 * eye_pulse,
			Color(0.85, 0.15, 0.05, alpha * 0.18))
		draw_circle(Vector2(ex, ey), 3.5,
			Color(0.90, 0.20, 0.05, alpha))
		draw_circle(Vector2(ex + 1.0, ey - 1.0), 1.0,
			Color(1.0, 0.8, 0.6, alpha * 0.8))

# ─────────────────── ellipse helper ───────────────────────────────

func _draw_ellipse(cx: float, cy: float, rx: float, ry: float,
		alpha: float, col: Color) -> void:
	var pts   = PackedVector2Array()
	for i in 21:
		var a = float(i) / 20.0 * TAU
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, alpha), 3.5)
	var steps = int(ry * 1.8)
	for i in steps:
		var t2    = (float(i) / float(steps)) * 2.0 - 1.0
		var row_w = rx * sqrt(maxf(0.0, 1.0 - t2 * t2))
		draw_line(Vector2(cx - row_w, cy + t2 * ry),
				  Vector2(cx + row_w, cy + t2 * ry),
				  Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, alpha * 0.92), 1.5)

# (vignette drawn by CanvasLayer node in main.gd)
