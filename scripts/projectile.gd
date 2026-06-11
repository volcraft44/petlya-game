extends Area2D

enum Type { ARROW, BOLT, HAMMER, GRENADE, WEB }

var projectile_type: int = Type.ARROW
var direction: Vector2 = Vector2.RIGHT
var speed: float = 150.0
var damage: int = 1
var gravity_affect: float = 0.0
var lifetime: float = 4.0
var has_hit: bool = false
var rotation_speed: float = 0.0
var is_player_projectile: bool = false  # Player projectiles hit enemies, not player

# For grenade
var explode_timer: float = 0.0
var is_grenade: bool = false
var explosion_radius: float = 40.0

# Bottle sprite for HAMMER type
var bottle_sprite: Sprite2D = null
var bottle_tex: Texture2D = null
static var _bottle_tex_cache: Texture2D = null

func _ready():
	collision_layer = 0
	if is_player_projectile:
		collision_mask = 2 | 4  # enemies + walls
	else:
		collision_mask = 1 | 4  # player + walls

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()

	match projectile_type:
		Type.ARROW:
			circle.radius = 3
			speed = 180.0
			gravity_affect = 30.0
		Type.BOLT:
			circle.radius = 3
			speed = 220.0
			gravity_affect = 15.0
		Type.HAMMER:
			circle.radius = 5
			speed = 130.0
			gravity_affect = 200.0
			rotation_speed = 8.0
			damage = 2
		Type.GRENADE:
			circle.radius = 4
			speed = 120.0
			gravity_affect = 300.0
			is_grenade = true
			explode_timer = 1.5
			damage = 2
		Type.WEB:
			circle.radius = 5
			speed = 130.0
			gravity_affect = 80.0
			lifetime = 3.0

	shape.shape = circle
	add_child(shape)

	# Load bottle sprite for hammer/bottle type — текстура кэшируется static
	if projectile_type == Type.HAMMER:
		if _bottle_tex_cache == null:
			if ResourceLoader.exists("res://sprites/bottle.png"):
				_bottle_tex_cache = load("res://sprites/bottle.png")
			else:
				var img = Image.new()
				if img.load(ProjectSettings.globalize_path("res://sprites/bottle.png")) == OK:
					_bottle_tex_cache = ImageTexture.create_from_image(img)
		bottle_tex = _bottle_tex_cache
		if bottle_tex:
			bottle_sprite = Sprite2D.new()
			bottle_sprite.texture = bottle_tex
			bottle_sprite.scale = Vector2(0.5, 0.5)
			add_child(bottle_sprite)

	body_entered.connect(_on_hit)

func setup(p_type: int, dir: Vector2, p_damage: int = 1):
	projectile_type = p_type
	direction = dir.normalized()
	damage = p_damage

func _physics_process(delta):
	if has_hit:
		return

	direction.y += gravity_affect * delta / speed
	position += direction * speed * delta
	rotation += rotation_speed * delta

	lifetime -= delta

	if is_grenade:
		explode_timer -= delta
		if explode_timer <= 0:
			_explode()
			return

	if lifetime <= 0:
		# Если это была "псевдо-граната" дыма/флешки — разворачиваем эффект
		if has_meta("becomes_smoke"):
			_deploy_smoke()
		elif has_meta("becomes_flash"):
			_deploy_flash()
		queue_free()

	queue_redraw()

func _deploy_smoke():
	var smoke = Node2D.new()
	smoke.set_script(load("res://scripts/smoke_cloud.gd"))
	smoke.global_position = global_position
	get_parent().add_child(smoke)

func _deploy_flash():
	# Слепим всех врагов в радиусе и моргаем экран
	var radius = 220.0
	var parent = get_parent()
	if parent and "enemies" in parent:
		for en in parent.enemies:
			if is_instance_valid(en) and global_position.distance_to(en.global_position) < radius:
				if "flash_blind_timer" in en:
					en.flash_blind_timer = 2.5
	# Полноэкранная вспышка через cs_overlay
	var tree = get_tree()
	if tree:
		var root = tree.root
		for c in root.get_children():
			if c is Node and c.has_node("CanvasLayer"):
				pass
		# Ищем cs_overlay по группе или у main
		for c in tree.get_nodes_in_group("cs_overlay"):
			if c.has_method("flash_screen"):
				c.flash_screen(0.9)
				break

func _on_hit(body):
	if has_hit:
		return

	if is_grenade:
		_explode()
		return

	# Псевдо-граната дыма/флешки взрывается при первом столкновении
	if has_meta("becomes_smoke"):
		_deploy_smoke()
		has_hit = true
		queue_free()
		return
	if has_meta("becomes_flash"):
		_deploy_flash()
		has_hit = true
		queue_free()
		return

	if projectile_type == Type.WEB:
		if body.has_method("start_web"):
			body.start_web(4.0)
		has_hit = true
		queue_free()
		return

	if body.has_method("take_damage"):
		var kb = direction.normalized()
		var final_dmg = damage
		# === CS HEADSHOT (для стрел/болтов игрока) ===
		if is_player_projectile and projectile_type in [Type.ARROW, Type.BOLT]:
			# Проверяем что попали в верхнюю треть врага
			if global_position.y < (body.global_position.y - 6.0):
				if not ("is_boss" in body and body.is_boss):
					final_dmg = int(final_dmg * 2.0)
					var players = get_tree().get_nodes_in_group("player")
					for p in players:
						if p.has_signal("headshot_landed"):
							p.headshot_landed.emit(body.global_position + Vector2(0, -12))
							break
		body.take_damage(final_dmg, kb)

	has_hit = true
	queue_free()

func _explode():
	has_hit = true
	# Damage player if nearby
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.global_position.distance_to(global_position) < explosion_radius:
			if p.has_method("take_damage"):
				var dir = (p.global_position - global_position).normalized()
				p.take_damage(damage, dir)

	# Visual explosion effect - spawn particles node
	var explosion = Node2D.new()
	explosion.set_script(load("res://scripts/explosion_effect.gd"))
	explosion.global_position = global_position
	get_parent().add_child(explosion)

	queue_free()

func _draw():
	if has_hit:
		return

	match projectile_type:
		Type.ARROW:
			draw_line(Vector2(-8, 0), Vector2(4, 0), Color(0.5, 0.35, 0.15), 1.5)
			draw_line(Vector2(4, 0), Vector2(6, 0), Color(0.6, 0.6, 0.65), 1.5)
			# Fletching
			draw_line(Vector2(-8, 0), Vector2(-10, -2), Color(0.7, 0.7, 0.7), 1.0)
			draw_line(Vector2(-8, 0), Vector2(-10, 2), Color(0.7, 0.7, 0.7), 1.0)
		Type.BOLT:
			draw_line(Vector2(-6, 0), Vector2(4, 0), Color(0.4, 0.3, 0.1), 2.0)
			draw_line(Vector2(4, 0), Vector2(6, 0), Color(0.55, 0.55, 0.6), 2.0)
			draw_line(Vector2(4, -2), Vector2(6, 0), Color(0.55, 0.55, 0.6), 1.0)
			draw_line(Vector2(4, 2), Vector2(6, 0), Color(0.55, 0.55, 0.6), 1.0)
		Type.HAMMER:
			# Bottle sprite handles drawing — only fallback if no texture
			if not bottle_tex:
				draw_rect(Rect2(-3, -2, 6, 7), Color(0.15, 0.5, 0.15))
				draw_rect(Rect2(-2, -2, 4, 6), Color(0.2, 0.6, 0.2))
				draw_rect(Rect2(-1, -5, 2, 4), Color(0.15, 0.5, 0.15))
				draw_rect(Rect2(-1, -6, 2, 1), Color(0.6, 0.4, 0.1))
		Type.GRENADE:
			draw_circle(Vector2.ZERO, 4, Color(0.3, 0.3, 0.3))
			draw_circle(Vector2.ZERO, 3, Color(0.4, 0.35, 0.3))
			# Fuse
			var fuse_glow = Color(1, 0.5, 0, 0.8) if fmod(explode_timer, 0.3) < 0.15 else Color(1, 0.2, 0, 0.5)
			draw_line(Vector2(0, -4), Vector2(2, -7), fuse_glow, 1.5)
			draw_circle(Vector2(2, -7), 2, fuse_glow)
		Type.WEB:
			# Sticky web blob with threads
			draw_circle(Vector2.ZERO, 5, Color(0.85, 0.85, 0.95, 0.85))
			draw_circle(Vector2.ZERO, 3, Color(0.95, 0.95, 1.0, 0.9))
			for wi in 6:
				var wa = wi * TAU / 6 + lifetime * 2
				draw_line(Vector2.ZERO, Vector2(cos(wa) * 7, sin(wa) * 7), Color(0.9, 0.9, 1.0, 0.5), 0.8)
