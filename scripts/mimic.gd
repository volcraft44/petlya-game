extends CharacterBody2D

signal attacked_player

enum State { WALK, CROUCH, LEAP, DONE }

var state: State = State.WALK

# Timers
var walk_timer:   float = 3.5   # walks for this long before leaping
var crouch_timer: float = 0.0
const CROUCH_DUR: float = 0.55  # crouching / winding up

# Walk behaviour
var walk_dir:       int   = 1       # 1 = right, -1 = left
var walk_change:    float = 0.0     # countdown to change direction
const WALK_SPEED:   float = 75.0
const LEAP_SPEED_X: float = 230.0
const LEAP_SPEED_Y: float = -340.0

var facing_right:   bool  = true
var player_ref              = null
var room_ref                = null
var alive:          bool  = true

# Visual state
var land_squash:    float = 0.0     # 0..1, set on landing, decays
var anim_time:      float = 0.0     # drives leg swing etc.

func setup(p_player: CharacterBody2D, p_room: Node2D) -> void:
	player_ref = p_player
	room_ref   = p_room
	walk_dir   = 1 if randf() > 0.5 else -1
	walk_change = randf_range(0.8, 1.6)
	collision_layer = 0
	collision_mask  = 4   # walls only

# ─────────────────── physics ───────────────────

func _physics_process(delta: float) -> void:
	if not alive:
		return

	anim_time += delta

	# Gravity
	var was_floor = is_on_floor()
	if not is_on_floor():
		velocity.y = min(velocity.y + 650.0 * delta, 650.0)

	# Landing squash
	if not was_floor and is_on_floor():
		land_squash = 1.0
	land_squash = maxf(land_squash - delta * 5.0, 0.0)

	match state:
		State.WALK:   _do_walk(delta)
		State.CROUCH: _do_crouch(delta)
		State.LEAP:   _do_leap()
		State.DONE:
			velocity.x = 0.0

	# Face player while walking / crouching
	if state in [State.WALK, State.CROUCH] and is_instance_valid(player_ref):
		facing_right = player_ref.global_position.x > global_position.x

	move_and_slide()
	queue_redraw()

# ─────────────────── states ───────────────────

func _do_walk(delta: float) -> void:
	walk_timer -= delta

	# Random direction changes
	walk_change -= delta
	if walk_change <= 0.0:
		walk_dir   = -walk_dir
		walk_change = randf_range(0.8, 1.8)
	if is_on_wall():
		walk_dir = -walk_dir

	velocity.x = walk_dir * WALK_SPEED

	# Transition: crouch to leap
	if walk_timer <= 0.0:
		state        = State.CROUCH
		crouch_timer = CROUCH_DUR
		velocity.x   = 0.0

func _do_crouch(delta: float) -> void:
	velocity.x  = 0.0
	crouch_timer -= delta
	if crouch_timer <= 0.0:
		_launch_leap()

func _launch_leap() -> void:
	if not is_instance_valid(player_ref):
		state = State.DONE
		return
	state = State.LEAP
	var diff = player_ref.global_position - global_position
	facing_right = diff.x >= 0.0
	velocity.x   = sign(diff.x) * LEAP_SPEED_X
	velocity.y   = LEAP_SPEED_Y

func _do_leap() -> void:
	if not is_instance_valid(player_ref):
		return
	var diff = player_ref.global_position - global_position
	# Hit when close enough
	if abs(diff.x) < 18.0 and abs(diff.y) < 32.0:
		state = State.DONE
		alive = false
		attacked_player.emit()
		queue_free()

# ─────────────────── draw ───────────────────

func _draw() -> void:
	var s = 1 if facing_right else -1

	match state:
		State.WALK:   _draw_walk(s)
		State.CROUCH: _draw_crouch(s)
		State.LEAP:   _draw_leap(s)

func _draw_walk(s: int) -> void:
	var la = sin(anim_time * 10.0) * 3.0 if abs(velocity.x) > 5.0 else 0.0

	# Squash on landing
	if land_squash > 0.0:
		var sx = 1.0 + land_squash * 0.3
		var sy = 1.0 - land_squash * 0.2
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))

	_draw_body(s, la)

	if land_squash > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_crouch(s: int) -> void:
	# Wind-up: crouches low, arms back
	var t = 1.0 - (crouch_timer / CROUCH_DUR)   # 0→1 as crouch progresses
	var sq_x = 1.0 + t * 0.35
	var sq_y = 1.0 - t * 0.30
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sq_x, sq_y))

	_draw_body(s, 0.0)

	# Arms pulled back (drawn on top)
	draw_rect(Rect2(-s * 5, -14, -s * 6, 3), Color(0.42, 0.42, 0.48))   # arm pulling back
	draw_rect(Rect2(-s * 9, -15, s * 3, 3), Color(0.9, 0.75, 0.55))     # fist

	# Pulsing red eyes during charge-up
	var pulse = abs(sin(anim_time * 20.0))
	draw_circle(Vector2(float(s), -20.0), 1.5 + pulse, Color(1.0, 0.08, 0.05))
	draw_circle(Vector2(float(s), -20.0), 4.0 + pulse * 2.0, Color(1.0, 0.08, 0.05, 0.3))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_leap(s: int) -> void:
	# Stretch tall while airborne
	var vy_frac = clampf(-velocity.y / 340.0, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 - vy_frac * 0.15, 1.0 + vy_frac * 0.20))

	# Legs tucked
	draw_rect(Rect2(-4, -6, 3, 4), Color(0.25, 0.2, 0.15))
	draw_rect(Rect2( 1, -6, 3, 4), Color(0.25, 0.2, 0.15))
	draw_rect(Rect2(-5, -3, 5, 2), Color(0.4, 0.22, 0.1))
	draw_rect(Rect2( 0, -3, 5, 2), Color(0.4, 0.22, 0.1))

	# Body
	draw_rect(Rect2(-5, -16, 10, 13), Color(0.35, 0.35, 0.4))
	draw_rect(Rect2(-4, -15,  8,  7), Color(0.42, 0.42, 0.48))
	draw_rect(Rect2(-5,  -5, 10,  2), Color(0.45, 0.30, 0.12))

	# Head
	draw_rect(Rect2(-4, -22, 8, 7), Color(0.9, 0.75, 0.55))
	draw_rect(Rect2(-5, -24, 10, 5), Color(0.5, 0.5, 0.55))
	draw_rect(Rect2(-5, -24, 10, 1), Color(0.6, 0.6, 0.65))
	draw_rect(Rect2(-3 + s, -21, 5, 2), Color(0.08, 0.08, 0.1))

	# Blazing red eyes
	draw_circle(Vector2(float(s), -20.0), 2.0, Color(1.0, 0.08, 0.05))
	draw_circle(Vector2(float(s), -20.0), 5.0, Color(1.0, 0.08, 0.05, 0.35))

	# Arms lunging forward
	draw_rect(Rect2(s * 5, -17, s * 8, 3), Color(0.42, 0.42, 0.48))
	draw_rect(Rect2(s * 12, -18, s * 3, 4), Color(0.9, 0.75, 0.55))

	# Speed lines
	for i in 3:
		var sy2 = -8.0 - float(i) * 5.0
		var ln  = 14.0 + float(i) * 5.0
		draw_line(Vector2(-s * 4.0, sy2),
			Vector2(-s * (4.0 + ln), sy2),
			Color(1.0, 1.0, 1.0, 0.25 - float(i) * 0.06), 1.2)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ─── shared body (walk + crouch) ───

func _draw_body(s: int, la: float) -> void:
	# LEGS — exact player palette
	draw_rect(Rect2(-4, -4, 3, 5 + int(la)), Color(0.25, 0.2,  0.15))
	draw_rect(Rect2( 1, -4, 3, 5 - int(la)), Color(0.25, 0.2,  0.15))
	draw_rect(Rect2(-5,  0 + int(la), 5, 2), Color(0.4,  0.22, 0.1))
	draw_rect(Rect2( 0,  0 - int(la), 5, 2), Color(0.4,  0.22, 0.1))

	# BODY — exact player palette
	draw_rect(Rect2(-5, -16, 10, 13), Color(0.35, 0.35, 0.4))
	draw_rect(Rect2(-4, -15,  8,  7), Color(0.42, 0.42, 0.48))
	draw_rect(Rect2(-5,  -5, 10,  2), Color(0.45, 0.30, 0.12))
	draw_rect(Rect2(-1,  -5,  2,  2), Color(0.75, 0.65, 0.2))

	# HEAD — exact player palette
	draw_rect(Rect2(-4, -22, 8, 7), Color(0.9,  0.75, 0.55))
	draw_rect(Rect2(-5, -24, 10, 5), Color(0.5,  0.5,  0.55))
	draw_rect(Rect2(-5, -24, 10, 1), Color(0.6,  0.6,  0.65))
	draw_rect(Rect2(-3 + s, -21, 5, 2), Color(0.08, 0.08, 0.1))

	# Eyes — RED (the only difference from the player)
	var pulse = abs(sin(anim_time * 4.0)) * 0.2
	draw_circle(Vector2(float(s), -20.0), 1.5, Color(1.0, 0.08, 0.05))
	draw_circle(Vector2(float(s), -20.0), 3.0 + pulse, Color(1.0, 0.08, 0.05, 0.25))

	# SWORD — exact player basic sword
	draw_rect(Rect2(s * 4, -19, s * 2, 2), Color(0.55, 0.42, 0.2))             # handle
	draw_line(Vector2(s * 4.0, -14.0), Vector2(s * 9.0, -14.0),
		Color(0.65, 0.55, 0.25), 2.0)                                            # guard
	draw_line(Vector2(s * 6.0, -20.0), Vector2(s * 16.0, -10.0),
		Color(0.85, 0.85, 0.92), 2.5)                                            # blade
	draw_line(Vector2(s * 7.0, -19.0), Vector2(s * 15.0, -11.0),
		Color(1.0, 1.0, 1.0, 0.3), 1.0)                                          # shine
