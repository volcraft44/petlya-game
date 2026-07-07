extends CharacterBody2D

signal died(enemy)
signal telegraph_started(pos)   # враг начал ЗАМАХ — main проигрывает аудио-телеграф

# Enemy types
enum EnemyClass { ARCHER, CROSSBOW, THROWER, SHIELDMAN, FLY, STEALTH, MAGE, SPIDER,
	SUMMONER, RAT, MUMMY, BEETLE, MOSQUITO, ZOMBIE_CORPSE,
	KNIGHT, HERETIC, DOG, BRUTE }

# Классы с программной анимацией — выносим в константу, чтобы не создавать
# массив каждый кадр у каждого врага.
const ANIMATED_CLASSES := [EnemyClass.FLY, EnemyClass.STEALTH, EnemyClass.MAGE,
	EnemyClass.SPIDER, EnemyClass.SUMMONER, EnemyClass.RAT, EnemyClass.MUMMY,
	EnemyClass.BEETLE, EnemyClass.MOSQUITO, EnemyClass.ZOMBIE_CORPSE,
	EnemyClass.KNIGHT, EnemyClass.HERETIC, EnemyClass.DOG, EnemyClass.BRUTE]

# Станящие атаки: некоторые враги (тяжёлые/дробящие) глушат игрока ударом.
var stuns_on_hit: bool = false
var stun_power: float = 0.0

# === Dead Cells-цикл ближнего боя: ЗАМАХ → УДАР → восстановление ===
# Урон прилетает ПОСЛЕ телеграфа — у игрока есть окно, чтобы уйти/увернуться.
var pending_melee: bool = false
var pending_melee_timer: float = 0.0
# Флинч и стойкость: лёгкие враги вздрагивают от каждого удара (замах сбивается),
# тяжёлые держат poise ударов прежде чем вздрогнуть.
var flinch_timer: float = 0.0
var poise: int = 0
var poise_counter: int = 0
# Дети призывателя (лимит, чтобы не лагало)
var summoner_children: Array = []

@export var enemy_class: int = EnemyClass.SHIELDMAN
@export var speed: float = 35.0
@export var max_health: int = 3
@export var damage: int = 1
@export var detection_range: float = 150.0
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 1.5

var health: int
var gravity: float = 650.0
var player: CharacterBody2D = null
var can_attack: bool = true
var attack_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var is_hit: bool = false
var hit_flash_timer: float = 0.0
var hit_shake_timer: float = 0.0
var facing_right: bool = false
var patrol_dir: float = 1.0
var patrol_timer: float = 0.0
var is_attacking_melee: bool = false
var melee_anim_timer: float = 0.0
var is_blocking: bool = false
# Контактный отпор: толкаем игрока, если он влез в хитбокс врага.
var contact_cd: float = 0.0
var contact_radius: float = 14.0

# Spear variant (longer range shieldman)
var is_spear: bool = false
var spear_range: float = 40.0

# Crystal targeting (for crystal defense challenge)
var crystal_target: Node2D = null

# Shield stun mechanic
var shield_hit_count: int = 0
var shield_hits_to_stun: int = 3
var is_stunned: bool = false
var stun_timer: float = 0.0

# CS-эффекты: дымовуха и флешка
var smoke_blind_timer: float = 0.0   # пока > 0 — игрок невидим для меня
var flash_blind_timer: float = 0.0   # пока > 0 — стою, шатаюсь, не атакую

# Статусы: заморозка + электричество
var frozen_timer: float = 0.0       # > 0 = не двигается, ice-tint
var shocked_timer: float = 0.0      # > 0 = эл. shocked, jitter + цепляет
var stun_duration: float = 3.0
var shield_broken: bool = false  # Permanent shield break after 3 hits

# Leap attack mechanic (shieldman)
var is_preparing_leap: bool = false
var leap_prep_timer: float = 0.0
var leap_prep_duration: float = 2.0
var is_leaping: bool = false
var leap_target: Vector2 = Vector2.ZERO
var leap_cooldown_timer: float = 0.0
var leap_cooldown: float = 6.0
var leap_landed: bool = false

# Special drops
var drops_pickaxe: bool = false
var drops_pearl: bool = false

# Crit flash (set by player)
var white_flash_timer: float = 0.0

# Telegraph (pre-attack warning)
var telegraph_timer: float = 0.0
var telegraph_duration: float = 0.0

# Death particles
var is_dying: bool = false
var death_timer: float = 0.0
var death_particles: Array = []  # [{pos, vel, life, color}]

# Status effects (set by player)
var is_on_fire: bool = false
var fire_timer_display: float = 0.0
var death_note_timer_display: float = -1.0  # -1 = not marked
var death_note_name: String = ""             # записанное имя (Тетрадь Смерти)
var is_poisoned: bool = false

# FLY enemy
var fly_hover_y: float = 0.0  # target hover height
var fly_sin_offset: float = 0.0  # bobbing
var fly_spit_cooldown: float = 0.0

# STEALTH enemy
var is_hidden: bool = false
var stealth_wall_x: float = 0.0
var stealth_ambush_range: float = 50.0
var net_thrown: bool = false
var net_cooldown: float = 0.0

# Mini-boss variant
var is_miniboss: bool = false

# === ELITE AFFIX SYSTEM ===
# Враг может быть "элитным" со случайным аффиксом — буст + особое поведение.
var elite_affix: String = ""   # "", "explosive", "fast", "armored", "ghostly", "healer"
var elite_color: Color = Color.WHITE
var _elite_heal_cd: float = 0.0
var _elite_ghost_t: float = 0.0     # таймер фазирования для ghostly
var _elite_pulse: float = 0.0       # для пульсирующей ауры

# MAGE enemy
var mage_teleport_cooldown: float = 0.0
var mage_charge_timer: float = 0.0  # charges up orbs before shooting
var mage_orbs_active: Array = []  # orbiting orbs [{angle, radius}]

# SPIDER enemy
var spider_web_used: bool = false  # can only web once per fight
var spider_web_cooldown: float = 0.0
var spider_jump_timer: float = 0.0
var spider_leg_phase: float = 0.0  # leg animation

# SUMMONER enemy
var summoner_spawn_timer: float = 4.0
var summoner_rat_count: int = 0      # how many live rats this summoner made
var summoner_flee_dir: float = 1.0   # flee horizontal direction

# RAT enemy
var rat_squeak_timer: float = 0.0   # visual squeak bubble timer

# MUMMY enemy
var mummy_beetle_children: Array = []  # live beetle nodes
var mummy_beetle_timer: float = 3.0
var mummy_anim_phase: float = 0.0

# BEETLE enemy
var beetle_jump_cooldown: float = 1.5
var beetle_crawl_phase: float = 0.0
var beetle_parent_mummy: Node2D = null  # mummy this beetle belongs to

# MOSQUITO enemy
var mosquito_wing_phase: float = 0.0
var mosquito_bite_cooldown: float = 0.0

# ZOMBIE_CORPSE enemy
var zombie_worm_phase: float = 0.0
var zombie_anim_phase: float = 0.0

# KNIGHT enemy — heavy armored, blocks 1 frontal hit on 5s CD, 1.7s windup before attack
var knight_block_timer: float = 0.0    # > 0 = block on cooldown
var knight_block_active: bool = false  # absorbs next frontal hit
var knight_windup_timer: float = 0.0   # countdown before heavy swing lands
var knight_is_winding_up: bool = false

# HERETIC enemy — spawns in groups of 5, pitchfork + torch, enrages when teammate dies
var heretic_torch_phase: float = 0.0
var heretic_group: Array = []          # refs to other herectics in this spawn group
var heretic_rage_timer: float = 0.0   # counts down after first group member dies
var heretic_is_enraged: bool = false

# DOG enemy — very fast pack hunter, lunges from distance, enrages at 50% HP
var dog_lunge_timer: float = 0.0      # cooldown between lunges
var dog_howl_timer: float = 0.0       # howl to buff nearby dogs
var dog_leg_phase: float = 0.0
var dog_is_enraged: bool = false

# Projectile scene reference
var projectile_script = preload("res://scripts/projectile.gd")

# Compiled once for the whole session — never recompile on every hit/death
static var _burst_script_cache: GDScript = null
static var _blood_script_cache: GDScript = null

# Sprite animation for enemies
var enemy_sprite: Sprite2D = null
var shoot_textures: Array = []
var walk_textures: Array = []
var smoke_textures: Array = []  # Thrower idle smoking
var jump_textures: Array = []   # Shieldman in-air animation
var block_textures: Array = []  # Shieldman blocking animation
var sprite_frame_height: float = 288.0  # natural pixel height of a single frame
var sprite_frame: int = 0
var sprite_timer: float = 0.0
var sprite_fps: float = 8.0
var sprite_scale_val: float = 0.12
var is_shooting_anim: bool = false
var shoot_anim_timer: float = 0.0
var has_sprite_anim: bool = false
var pending_shot: bool = false
var pending_shot_timer: float = 0.0
var pending_shot_dir: Vector2 = Vector2.ZERO
var shot_delay: float = 0.4  # animation plays this long before projectile spawns
var is_smoking: bool = false
var smoke_timer: float = 0.0

# Статический кэш спрайтов — грузится ОДИН раз за сессию, не на каждого врага
static var _sprite_cache: Dictionary = {}

func _load_sprite_set(folder: String, count: int) -> Array:
	# Кэшированная загрузка набора кадров
	if _sprite_cache.has(folder):
		return _sprite_cache[folder]
	var arr: Array = []
	for i in count:
		var tex = _try_load_tex("res://sprites/%s/frame_%03d.png" % [folder, i])
		if tex: arr.append(tex)
	_sprite_cache[folder] = arr
	return arr

func _load_enemy_sprites():
	match enemy_class:
		EnemyClass.ARCHER, EnemyClass.CROSSBOW:
			shoot_textures = _load_sprite_set("skeleton_shoot", 48)
			walk_textures = _load_sprite_set("skeleton_walk", 36)
			sprite_scale_val = 0.13
		EnemyClass.SHIELDMAN:
			walk_textures = _load_sprite_set("shieldman_walk", 48)
			jump_textures = _load_sprite_set("shieldman_jump", 48)
			block_textures = _load_sprite_set("shieldman_block", 72)
			sprite_scale_val = 0.09
			sprite_frame_height = 432.0
		_:
			# All other enemies use programmatic _draw() until custom sprites are supplied
			has_sprite_anim = false
			return

	has_sprite_anim = shoot_textures.size() > 0 or walk_textures.size() > 0 or jump_textures.size() > 0 or block_textures.size() > 0
	if has_sprite_anim:
		enemy_sprite = Sprite2D.new()
		var sprite_h = sprite_frame_height * sprite_scale_val
		enemy_sprite.position = Vector2(0, -sprite_h / 2.0)
		enemy_sprite.scale = Vector2(sprite_scale_val, sprite_scale_val)
		add_child(enemy_sprite)
		if walk_textures.size() > 0:
			enemy_sprite.texture = walk_textures[0]

func _try_load_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		return load(res_path)
	# Load raw bytes via FileAccess — works without .import files
	var fa = FileAccess.open(res_path, FileAccess.READ)
	if fa:
		var bytes = fa.get_buffer(fa.get_length())
		fa.close()
		var img = Image.new()
		if img.load_png_from_buffer(bytes) == OK:
			return ImageTexture.create_from_image(img)
	return null

func _ready():
	health = max_health

	var body_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(10, 20)
	body_shape.shape = rect
	body_shape.position = Vector2(0, -10)
	add_child(body_shape)

	collision_layer = 2
	collision_mask = 4 | 1  # walls + player

	# Contact damage area
	var hurt_area = Area2D.new()
	hurt_area.collision_layer = 0
	hurt_area.collision_mask = 1
	var hurt_shape = CollisionShape2D.new()
	var hurt_rect = RectangleShape2D.new()
	hurt_rect.size = Vector2(12, 22)
	hurt_shape.shape = hurt_rect
	hurt_shape.position = Vector2(0, -10)
	hurt_area.add_child(hurt_shape)
	add_child(hurt_area)

	if enemy_class == EnemyClass.SHIELDMAN:
		hurt_area.body_entered.connect(_on_touch_player)

	# ВАЖНО: если setup() уже отработал (спавн из комнаты идёт setup→add_child),
	# НЕ вызываем _setup_class повторно — иначе дефолты класса ПЕРЕТРУТ
	# тировые HP/урон, заданные комнатой (старый баг «то легко, то невозможно»).
	if not _setup_done:
		_setup_class()

	# Load sprite animations for all enemy types
	_load_enemy_sprites()

var _setup_done: bool = false

func setup(p_class: int, p_health: int, p_speed: float, p_damage: int):
	enemy_class = p_class
	# СНАЧАЛА дефолты класса, ПОТОМ переданные значения — комната полностью
	# управляет балансом HP/урона (тиры сложности), а не дефолты класса.
	_setup_class()
	if p_health > 0:
		max_health = p_health
		health = max_health
	if p_damage > 0:
		damage = p_damage
	if p_speed > 0.0:
		speed = p_speed
	_setup_done = true

func make_elite(affix: String) -> void:
	# Превращает врага в элитного — баффы зависят от аффикса.
	elite_affix = affix
	match affix:
		"explosive":
			elite_color = Color(1.0, 0.45, 0.10)
			max_health = int(max_health * 1.3)
			health = max_health
		"fast":
			elite_color = Color(0.30, 0.95, 1.0)
			speed *= 1.7
			attack_cooldown *= 0.7
			max_health = int(max_health * 1.1)
			health = max_health
		"armored":
			elite_color = Color(0.70, 0.70, 0.80)
			max_health = int(max_health * 2.2)
			health = max_health
		"ghostly":
			elite_color = Color(0.65, 0.45, 0.95)
			max_health = int(max_health * 1.2)
			health = max_health
		"healer":
			elite_color = Color(0.30, 1.0, 0.45)
			max_health = int(max_health * 1.5)
			health = max_health
	# Элита крупнее по урону
	damage = int(damage * 1.25)

func _setup_class():
	match enemy_class:
		EnemyClass.ARCHER:
			attack_range = 160.0
			attack_cooldown = 2.0
			speed = 25.0
		EnemyClass.CROSSBOW:
			attack_range = 180.0
			attack_cooldown = 3.0
			speed = 20.0
		EnemyClass.THROWER:
			attack_range = 120.0
			attack_cooldown = 2.5
			speed = 30.0
		EnemyClass.SHIELDMAN:
			if is_spear:
				attack_range = spear_range
				attack_cooldown = 2.0
				speed = 28.0
			else:
				attack_range = 22.0
				attack_cooldown = 1.8
				speed = 30.0
			max_health += 20
			health = max_health
		EnemyClass.FLY:
			attack_range = 120.0
			attack_cooldown = 2.5
			speed = 45.0
			detection_range = 200.0
			fly_spit_cooldown = 1.5
			gravity = 0.0  # Flies don't fall
			max_health = max(max_health / 2, 10)  # Less HP, fragile
			health = max_health
		EnemyClass.STEALTH:
			attack_range = 60.0
			attack_cooldown = 2.0
			speed = 40.0
			detection_range = 120.0
			is_hidden = true  # Start hidden in wall
			net_cooldown = 2.0
			max_health += 10
			health = max_health
		EnemyClass.MAGE:
			max_health = 15
			health = max_health
			damage = 2
			speed = 40.0
			detection_range = 160.0
			attack_range = 140.0
			attack_cooldown = 2.0
		EnemyClass.SPIDER:
			attack_range = 16.0
			attack_cooldown = 1.2
			speed = 55.0
			detection_range = 200.0
			gravity = 800.0
		EnemyClass.SUMMONER:
			speed = 38.0
			detection_range = 220.0
			attack_range = 9999.0  # never melee, only summons
			attack_cooldown = 4.0
			max_health = 35
			health = max_health
		EnemyClass.RAT:
			speed = 90.0
			attack_range = 12.0
			attack_cooldown = 0.9
			detection_range = 180.0
			max_health = 1
			health = 1
			damage = 12
		EnemyClass.MUMMY:
			speed = 22.0
			attack_range = 20.0
			attack_cooldown = 1.6
			detection_range = 160.0
			damage = 25
			mummy_beetle_timer = 3.0
		EnemyClass.BEETLE:
			speed = 28.0
			attack_range = 14.0
			attack_cooldown = 0.8
			detection_range = 140.0
			max_health = 1
			health = 1
			damage = 10
		EnemyClass.MOSQUITO:
			speed = 48.0
			attack_range = 14.0
			attack_cooldown = 1.2
			detection_range = 200.0
			gravity = 0.0  # flies
			max_health = 20
			health = 20
			damage = 0  # damage via poison DOT only
		EnemyClass.ZOMBIE_CORPSE:
			speed = 26.0
			attack_range = 20.0
			attack_cooldown = 1.8
			detection_range = 140.0
			damage = 20
		EnemyClass.KNIGHT:
			speed = 28.0
			attack_range = 26.0
			attack_cooldown = 0.8   # cooldown AFTER windup swing completes
			detection_range = 160.0
			max_health = 60
			health = max_health
			damage = 40
		EnemyClass.HERETIC:
			speed = 45.0
			attack_range = 24.0
			attack_cooldown = 1.5
			detection_range = 150.0
			max_health = 20
			health = max_health
			damage = 18
		EnemyClass.DOG:
			speed = 100.0
			attack_range = 18.0
			attack_cooldown = 0.9
			detection_range = 200.0
			max_health = 50
			health = max_health
			damage = 25
			dog_lunge_timer = 0.0
			dog_howl_timer = randf_range(5.0, 10.0)
		EnemyClass.BRUTE:
			# Тяжёлый громила: бьёт медленно (2с кд, долгий замах), но КАЖДЫЙ
			# удар оглушает и наносит много урона. Появляется со 2-й локации.
			speed = 30.0
			attack_range = 30.0
			attack_cooldown = 2.0
			detection_range = 190.0
			max_health = 110
			health = max_health
			damage = 38
			contact_radius = 22.0
			stuns_on_hit = true
			stun_power = 1.1

	# Станящие удары у тяжёлых/дробящих врагов (которым это подходит).
	match enemy_class:
		EnemyClass.SHIELDMAN:
			stuns_on_hit = true
			stun_power = 0.5
		EnemyClass.MUMMY:
			stuns_on_hit = true
			stun_power = 0.6
		EnemyClass.KNIGHT:
			stuns_on_hit = true
			stun_power = 0.45
		EnemyClass.ZOMBIE_CORPSE:
			stuns_on_hit = true
			stun_power = 0.4

	# СТОЙКОСТЬ (poise): сколько ударов враг держит, не вздрагивая.
	# 0 = вздрагивает от каждого удара (и замах сбивается) — лёгкие враги.
	# Тяжёлые продавливают атаку сквозь пару ударов — их надо уважать.
	match enemy_class:
		EnemyClass.SHIELDMAN, EnemyClass.MUMMY:
			poise = 2
		EnemyClass.KNIGHT, EnemyClass.BRUTE:
			poise = 3
		EnemyClass.ZOMBIE_CORPSE, EnemyClass.DOG:
			poise = 1
		_:
			poise = 0

func _process(delta):
	# === ЗАМАХ → УДАР (Dead Cells) ===
	# Урон прилетает ПОСЛЕ телеграфа. Стан/заморозка сбивают замах.
	if pending_melee:
		pending_melee_timer -= delta
		queue_redraw()
		if is_stunned or frozen_timer > 0.0:
			pending_melee = false
		elif pending_melee_timer <= 0.0:
			pending_melee = false
			_strike_melee()

	# Stun timer
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false
			if shield_broken:
				is_blocking = false
		# Still update sprite while stunned
		if has_sprite_anim and enemy_sprite:
			_update_sprite_anim(delta)
		queue_redraw()
		return

	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	if is_hit:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0:
			is_hit = false
	if hit_shake_timer > 0:
		hit_shake_timer -= delta

	if white_flash_timer > 0:
		white_flash_timer -= delta
		queue_redraw()

	if telegraph_timer > 0:
		telegraph_timer -= delta
		queue_redraw()

	# Tick death particles (enemy is freed in take_damage, but Portal Eye uses separate logic)
	if death_particles.size() > 0:
		for p in death_particles:
			p.life -= delta
			p.pos += p.vel * delta
			p.vel.y += 300 * delta
		death_particles = death_particles.filter(func(p): return p.life > 0)
		queue_redraw()

	if is_attacking_melee:
		melee_anim_timer -= delta
		if melee_anim_timer <= 0:
			is_attacking_melee = false

	# Leap attack logic (shieldman)
	if enemy_class == EnemyClass.SHIELDMAN:
		leap_cooldown_timer = max(0, leap_cooldown_timer - delta)

		if is_preparing_leap:
			leap_prep_timer -= delta
			if leap_prep_timer <= 0:
				# Launch leap!
				is_preparing_leap = false
				is_leaping = true
				leap_landed = false
				if player and is_instance_valid(player):
					leap_target = player.global_position
					var dir = (leap_target - global_position).normalized()
					velocity = Vector2(dir.x * 250, -300)

		if is_leaping and is_on_floor() and velocity.y >= 0:
			# Landed
			is_leaping = false
			leap_landed = true
			leap_cooldown_timer = leap_cooldown
			if player and is_instance_valid(player):
				var dist = global_position.distance_to(player.global_position)
				if dist < 30:
					# Hit player! Deal damage and start attacking
					var dir = (player.global_position - global_position).normalized()
					player.take_damage(mini(damage + 10, 40), dir)  # Leap: damage+10, capped at 40
					can_attack = true
					attack_timer = 0
				else:
					# Missed! Stun self for 4 seconds
					is_stunned = true
					stun_timer = 4.0
					velocity = Vector2.ZERO

	patrol_timer -= delta
	if patrol_timer <= 0:
		patrol_dir *= -1
		patrol_timer = randf_range(2.0, 4.0)

	# Pending shot delay (animation plays first, then shoot)
	if pending_shot:
		pending_shot_timer -= delta
		if pending_shot_timer <= 0:
			pending_shot = false
			_fire_projectile(pending_shot_dir)

	# Дальние враги (вне экрана, видимая зона ~220px при зуме 2.9) не
	# анимируются и не перерисовываются — большая экономия CPU в толпе.
	if player and is_instance_valid(player):
		if global_position.distance_squared_to(player.global_position) > 400.0 * 400.0:
			return

	# Sprite animation update
	if has_sprite_anim and enemy_sprite:
		if is_shooting_anim:
			shoot_anim_timer -= delta
			if shoot_anim_timer <= 0:
				is_shooting_anim = false
		_update_sprite_anim(delta)

	# Only redraw when something visual is actually changing.
	var needs_draw = (is_hit or is_stunned or is_attacking_melee
		or telegraph_timer > 0 or white_flash_timer > 0
		or is_on_fire or is_poisoned or death_note_timer_display >= 0
		or frozen_timer > 0 or shocked_timer > 0
		or has_sprite_anim or is_miniboss or drops_pearl or drops_pickaxe)
	# Элита анимирует ауру — через кадр
	if elite_affix != "" and Engine.get_process_frames() % 2 == 0:
		needs_draw = true
	# Враги с программной анимацией — перерисовка через кадр (30 Гц).
	# ANIMATED_CLASSES — константа (раньше массив создавался КАЖДЫЙ кадр у
	# каждого врага = лишняя аллокация + поиск, заметно на телефоне).
	if Engine.get_process_frames() % 2 == 0 and enemy_class in ANIMATED_CLASSES:
		needs_draw = true
	if needs_draw:
		queue_redraw()

func _physics_process(delta):
	velocity.y += gravity * delta

	# CS таймеры
	if smoke_blind_timer > 0.0:
		smoke_blind_timer -= delta
	if flash_blind_timer > 0.0:
		flash_blind_timer -= delta

	# Статусы: заморозка и shock
	if frozen_timer > 0.0:
		frozen_timer -= delta
		velocity.x = 0.0
		move_and_slide()
		return    # полностью не двигаемся пока заморожены
	if shocked_timer > 0.0:
		shocked_timer -= delta

	# Сон ИИ вне экрана: враги далеко от игрока (видимая зона ~220px) не считают
	# ИИ — большая экономия CPU в комнатах с толпой. Гравитация и оседание на
	# пол остаются, чтобы никто не провалился. Боссы/минибоссы не спят.
	if player and is_instance_valid(player) and not is_miniboss:
		if global_position.distance_squared_to(player.global_position) > 900.0 * 900.0:
			move_and_slide()
			return

	# === КОНТАКТНЫЙ ОТПОР ===
	# Нельзя стоять «внутри» врага и безнаказанно лупить — если игрок прижался
	# к хитбоксу, его выталкивает наружу и по кулдауну наносит лёгкий урон.
	# Летающие враги (муха/комар) бьют иначе — их не касается.
	if contact_cd > 0.0:
		contact_cd -= delta
	if player and is_instance_valid(player) and not is_dying \
		and enemy_class != EnemyClass.FLY and enemy_class != EnemyClass.MOSQUITO \
		and not ("is_dead" in player and player.is_dead) \
		and not ("dash_active" in player and player.dash_active):
		var cr := contact_radius + (12.0 if is_miniboss else 0.0)
		var pd := global_position.distance_to(player.global_position)
		if pd < cr:
			var push := player.global_position - global_position
			if push.length() < 0.5:
				push = Vector2((1.0 if randf() < 0.5 else -1.0), -0.3)
			push = push.normalized()
			if player.has_method("apply_contact_push"):
				player.apply_contact_push(push)
			if contact_cd <= 0.0:
				contact_cd = 0.7
				player.take_damage(maxi(1, int(damage * 0.5)), push)

	# === ФЛИНЧ: враг вздрогнул от удара — короткая пауза (окно для комбо) ===
	if flinch_timer > 0.0:
		flinch_timer -= delta
		velocity.x = knockback_velocity.x
		knockback_velocity *= 0.85
		move_and_slide()
		return

	# === ЗАМАХ: стоим на месте — телеграф честный, игрок успевает уйти ===
	if pending_melee:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		return

	# === ELITE поведение ===
	if elite_affix != "":
		_elite_pulse += delta
		if elite_affix == "healer":
			# Лечит соседних врагов раз в 2 сек
			_elite_heal_cd -= delta
			if _elite_heal_cd <= 0.0:
				_elite_heal_cd = 2.0
				var room = get_parent()
				if room and "enemies" in room:
					for other in room.enemies:
						if other != self and is_instance_valid(other) \
							and global_position.distance_to(other.global_position) < 110.0:
							if "health" in other and "max_health" in other:
								other.health = min(other.max_health, other.health + 8)
								if "white_flash_timer" in other:
									other.white_flash_timer = 0.15
		elif elite_affix == "ghostly":
			# Периодически становится "призрачным" — не сталкивается с игроком
			_elite_ghost_t += delta
			var ghost_phase = fmod(_elite_ghost_t, 4.0)
			if ghost_phase < 1.2:
				collision_mask = 4   # только стены, игнор игрока
			else:
				collision_mask = 4 | 1

	# Stunned - no movement, just stand there
	if is_stunned:
		velocity.x = 0
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		return

	# Флешка — стоим оглушённые, "шатаемся"
	if flash_blind_timer > 0.0:
		velocity.x = sin(flash_blind_timer * 8.0) * 15.0
		move_and_slide()
		return

	# В дыму — враг не видит игрока. Бродим лениво.
	if smoke_blind_timer > 0.0:
		velocity.x = sin(Time.get_ticks_msec() * 0.002) * speed * 0.3
		can_attack = false
		move_and_slide()
		return

	var move_x = 0.0
	var dist_to_player = INF
	var dir_to_player = Vector2.ZERO

	# Crystal targeting: enemies attack ONLY the crystal
	if crystal_target and is_instance_valid(crystal_target) and not crystal_target.is_destroyed:
		var dir_to_crystal = crystal_target.global_position - global_position
		var dist_to_crystal = dir_to_crystal.length()
		facing_right = dir_to_crystal.x > 0

		if dist_to_crystal > attack_range + 5:
			move_x = sign(dir_to_crystal.x) * speed
		elif can_attack:
			_attack_crystal()

		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
			velocity.x = move_x

		move_and_slide()
		if is_on_wall():
			patrol_dir *= -1
		return

	# FLY: flies, ignores gravity, spits poison
	if enemy_class == EnemyClass.FLY:
		velocity.y -= gravity * delta  # Cancel gravity
		fly_sin_offset += delta * 3.0
		if player and is_instance_valid(player):
			# Check invisibility
			if player.is_invisible:
				# Can't see player, hover randomly
				velocity.x = sin(fly_sin_offset * 0.5) * 20
				velocity.y = cos(fly_sin_offset) * 15
			else:
				dir_to_player = player.global_position - global_position
				dist_to_player = dir_to_player.length()
				facing_right = dir_to_player.x > 0
				# Hover above player, keep distance
				var target_y = player.global_position.y - 60
				velocity.y = (target_y - global_position.y) * 2.0 + sin(fly_sin_offset) * 20
				if dist_to_player > 80:
					velocity.x = sign(dir_to_player.x) * speed * 1.2
				elif dist_to_player < 40:
					velocity.x = -sign(dir_to_player.x) * speed
				else:
					velocity.x = sin(fly_sin_offset * 0.7) * 30
				# Spit poison
				fly_spit_cooldown -= delta
				if fly_spit_cooldown <= 0 and dist_to_player < 120 and dist_to_player > 20:
					_spit_poison(dir_to_player.normalized())
					fly_spit_cooldown = 2.5
		move_and_slide()
		return

	# STEALTH: hides in wall, ambushes player
	if enemy_class == EnemyClass.STEALTH:
		if is_hidden:
			velocity = Vector2.ZERO
			if player and is_instance_valid(player) and not player.is_invisible:
				var dist = global_position.distance_to(player.global_position)
				if dist < stealth_ambush_range:
					# AMBUSH!
					is_hidden = false
					velocity.x = sign(player.global_position.x - global_position.x) * 200
					velocity.y = -200
			move_and_slide()
			return
		else:
			# Active — chase player and throw net
			if player and is_instance_valid(player) and not player.is_invisible:
				dir_to_player = player.global_position - global_position
				dist_to_player = dir_to_player.length()
				facing_right = dir_to_player.x > 0
				if dist_to_player > 30:
					velocity.x = sign(dir_to_player.x) * speed * 1.3
				net_cooldown -= delta
				if dist_to_player < 60 and net_cooldown <= 0 and not net_thrown:
					_throw_net()
					net_cooldown = 10.0

	# SPIDER: fast chase, jump, web attack
	if enemy_class == EnemyClass.SPIDER:
		spider_leg_phase += delta * 8.0
		spider_jump_timer = maxf(0.0, spider_jump_timer - delta)
		spider_web_cooldown = maxf(0.0, spider_web_cooldown - delta)
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			if dist_to_player < detection_range:
				# Shoot web if medium distance and not used yet
				if not spider_web_used and spider_web_cooldown <= 0 and dist_to_player > 50 and dist_to_player < 140 and is_on_floor():
					_spider_shoot_web(dir_to_player.normalized())
					spider_web_used = true
					spider_web_cooldown = 6.0
				# Jump towards player
				elif dist_to_player > attack_range * 3 and is_on_floor() and spider_jump_timer <= 0:
					velocity.y = -320
					velocity.x = sign(dir_to_player.x) * speed * 1.8
					spider_jump_timer = 1.5
				elif is_on_floor() and spider_jump_timer <= 0 and (is_on_wall() or player.global_position.y < global_position.y - 28):
						# Анти-застревание: упёрся в стену или игрок выше — прыжок
						velocity.y = -345
						velocity.x = sign(dir_to_player.x) * speed * 1.5
						spider_jump_timer = 0.8
				elif dist_to_player > attack_range:
					velocity.x = sign(dir_to_player.x) * speed
				elif can_attack:
					_melee_attack()
			else:
				velocity.x = patrol_dir * speed * 0.3
				facing_right = patrol_dir > 0
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		if is_on_wall():
			patrol_dir *= -1
		return

	# SUMMONER: flees from player, summons rats periodically
	if enemy_class == EnemyClass.SUMMONER:
		summoner_spawn_timer -= delta
		if summoner_spawn_timer <= 0:
			summoner_spawn_timer = 4.0
			_summoner_spawn_rats()
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			var flee_x = -sign(dir_to_player.x) * speed
			if is_on_wall():
				summoner_flee_dir *= -1.0
				flee_x = summoner_flee_dir * speed
			if dist_to_player < 200:
				velocity.x = flee_x
			elif dist_to_player > 380:
				# Too far — drift back so player doesn't lose it
				velocity.x = sign(dir_to_player.x) * speed * 0.4
			else:
				velocity.x *= 0.75
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		return

	# RAT: very fast, charges directly at player
	if enemy_class == EnemyClass.RAT:
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			if dist_to_player < detection_range:
				if dist_to_player > attack_range:
					velocity.x = sign(dir_to_player.x) * speed
				elif can_attack:
					_melee_attack()
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		if is_on_wall(): patrol_dir *= -1
		return

	# MUMMY: slow melee, ticks beetle swarm
	if enemy_class == EnemyClass.MUMMY:
		mummy_anim_phase += delta * 1.5
		mummy_beetle_timer -= delta
		if mummy_beetle_timer <= 0:
			mummy_beetle_timer = 2.5
			# Clean dead beetles only when about to spawn (not every frame)
			var live: Array = []
			for b in mummy_beetle_children:
				if is_instance_valid(b):
					live.append(b)
			mummy_beetle_children = live
			_mummy_spawn_beetle()
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			if dist_to_player < detection_range:
				if dist_to_player > attack_range:
					velocity.x = sign(dir_to_player.x) * speed
				elif can_attack:
					_melee_attack()
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		if is_on_wall(): patrol_dir *= -1
		return

	# BEETLE: crawl slowly, jump when player close or mummy is hit
	if enemy_class == EnemyClass.BEETLE:
		beetle_crawl_phase += delta * 6.0
		beetle_jump_cooldown = maxf(0.0, beetle_jump_cooldown - delta)
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			var mummy_hit = beetle_parent_mummy and is_instance_valid(beetle_parent_mummy) and beetle_parent_mummy.is_hit
			if (dist_to_player < 50 or mummy_hit) and beetle_jump_cooldown <= 0 and is_on_floor():
				# Jump at player!
				velocity.y = -260
				velocity.x = sign(dir_to_player.x) * 120
				beetle_jump_cooldown = 2.0
			elif dist_to_player < detection_range and dist_to_player > attack_range:
				velocity.x = sign(dir_to_player.x) * speed
			elif dist_to_player <= attack_range and can_attack:
				_melee_attack()
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		if is_on_wall(): patrol_dir *= -1
		return

	# MOSQUITO: flies, applies poison on contact
	if enemy_class == EnemyClass.MOSQUITO:
		velocity.y -= gravity * delta  # cancel gravity (flies)
		mosquito_wing_phase += delta * 18.0
		mosquito_bite_cooldown = maxf(0.0, mosquito_bite_cooldown - delta)
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			var target_y = player.global_position.y - 20
			velocity.y = (target_y - global_position.y) * 2.5 + sin(mosquito_wing_phase * 0.3) * 10
			if dist_to_player > attack_range * 2:
				velocity.x = sign(dir_to_player.x) * speed
			elif dist_to_player < attack_range:
				# Bite — apply poison DOT, 2 dmg/sec for 10 sec
				# apply_poison(duration, dmg_per_0.5s_tick): 1.0 → 2 dmg/sec
				if mosquito_bite_cooldown <= 0:
					mosquito_bite_cooldown = attack_cooldown
					if player.has_method("apply_poison"):
						player.apply_poison(10.0, 1.0)
					is_attacking_melee = true
					melee_anim_timer = 0.2
			else:
				velocity.x = sin(mosquito_wing_phase * 0.12) * 30
		move_and_slide()
		return

	# ZOMBIE_CORPSE: slow shambling melee, infects with worms on hit
	if enemy_class == EnemyClass.ZOMBIE_CORPSE:
		zombie_anim_phase += delta * 1.8
		zombie_worm_phase += delta * 4.0
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			if dist_to_player < detection_range:
				if dist_to_player > attack_range:
					velocity.x = sign(dir_to_player.x) * speed
				elif can_attack:
					_zombie_melee_attack()
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		if is_on_wall(): patrol_dir *= -1
		return

	# KNIGHT: heavy plate armor, 1.7s windup before massive swing, blocks 1 frontal hit
	if enemy_class == EnemyClass.KNIGHT:
		knight_block_timer = maxf(0.0, knight_block_timer - delta)
		knight_block_active = knight_block_timer <= 0.0 and not is_stunned
		# Windup countdown — deliver blow at the end
		if knight_is_winding_up:
			knight_windup_timer -= delta
			if knight_windup_timer <= 0:
				knight_is_winding_up = false
				if player and is_instance_valid(player):
					var d = global_position.distance_to(player.global_position)
					if d < attack_range + 16:
						if player.has_method("is_parrying") and player.is_parrying():
							is_stunned = true
							stun_timer = 3.5
							knockback_velocity = (global_position - player.global_position).normalized() * 250
							knockback_velocity.y = -180
							if player.has_method("trigger_parry_flash"):
								player.trigger_parry_flash()
						else:
							var kdir = (player.global_position - global_position).normalized()
							player.take_damage(damage, kdir)
				can_attack = false
				attack_timer = attack_cooldown
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			if dist_to_player < detection_range and not knight_is_winding_up:
				if dist_to_player > attack_range:
					move_x = sign(dir_to_player.x) * speed
				elif can_attack:
					# Begin the 1.7s windup
					knight_is_winding_up = true
					knight_windup_timer = 1.7
					telegraph_timer = 1.7
					telegraph_duration = 1.7
					can_attack = false
					attack_timer = attack_cooldown + 1.7
			elif not knight_is_winding_up:
				move_x = patrol_dir * speed * 0.3
				facing_right = patrol_dir > 0
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
			velocity.x = move_x
		move_and_slide()
		if is_on_wall(): patrol_dir *= -1
		return

	# HERETIC: robed cultist, pitchfork + torch, spawns in groups of 5
	if enemy_class == EnemyClass.HERETIC:
		heretic_torch_phase += delta * 5.0
		if heretic_rage_timer > 0:
			heretic_rage_timer -= delta
			heretic_is_enraged = true
			if heretic_rage_timer <= 0:
				heretic_is_enraged = false
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			var eff_speed = speed * (1.45 if heretic_is_enraged else 1.0)
			if dist_to_player < detection_range:
				if dist_to_player > attack_range:
					velocity.x = sign(dir_to_player.x) * eff_speed
				elif can_attack:
					_heretic_attack()
			else:
				velocity.x = patrol_dir * eff_speed * 0.3
				facing_right = patrol_dir > 0
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		if is_on_wall(): patrol_dir *= -1
		return

	# DOG: very fast pack hunter, lunge attacks, enrages at 50% HP
	if enemy_class == EnemyClass.DOG:
		dog_leg_phase += delta * 14.0
		dog_lunge_timer = maxf(0.0, dog_lunge_timer - delta)
		dog_howl_timer -= delta
		# Enrage when below half HP (one-time speed boost)
		if not dog_is_enraged and health < max_health / 2:
			dog_is_enraged = true
			speed = minf(speed * 1.3, 160.0)
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			if dist_to_player < detection_range:
				# Howl periodically — visual telegraph only, no permanent stat mutation
				if dog_howl_timer <= 0:
					dog_howl_timer = randf_range(8.0, 14.0)
					telegraph_timer = 0.5
					telegraph_duration = 0.5
				# Lunge: jump at player when at medium distance
				if dist_to_player > 55 and dist_to_player < 140 and dog_lunge_timer <= 0 and is_on_floor():
					velocity.y = -290
					velocity.x = sign(dir_to_player.x) * speed * 1.7
					dog_lunge_timer = 2.2
				elif dist_to_player > attack_range:
					velocity.x = sign(dir_to_player.x) * speed
				elif can_attack:
					_melee_attack()
			else:
				velocity.x = patrol_dir * speed * 0.4
				facing_right = patrol_dir > 0
		if knockback_velocity.length() > 10:
			velocity.x = knockback_velocity.x
			knockback_velocity *= 0.85
		else:
			knockback_velocity = Vector2.ZERO
		move_and_slide()
		if is_on_wall(): patrol_dir *= -1
		return

	# MAGE: floats, keeps distance, teleports, shoots orbs
	if enemy_class == EnemyClass.MAGE:
		velocity.y -= gravity * delta  # cancel gravity (floats)
		if player and is_instance_valid(player):
			dir_to_player = player.global_position - global_position
			dist_to_player = dir_to_player.length()
			facing_right = dir_to_player.x > 0
			# Hover and keep distance
			var target_y = player.global_position.y - 40
			velocity.y = (target_y - global_position.y) * 1.5
			if dist_to_player > 100:
				velocity.x = sign(dir_to_player.x) * speed
			elif dist_to_player < 55:
				velocity.x = -sign(dir_to_player.x) * speed * 0.8
			else:
				velocity.x = 0
			# Teleport when hit or player gets too close
			mage_teleport_cooldown -= delta
			if (is_hit or dist_to_player < 30) and mage_teleport_cooldown <= 0:
				# Teleport to a random position offset from player
				var tp_offset = Vector2(randf_range(-140, 140), randf_range(-80, -20))
				global_position += tp_offset
				mage_teleport_cooldown = 3.0
				hit_flash_timer = 0.2
			# Shoot 3 orbs spread
			if dist_to_player < 140 and can_attack:
				_mage_shoot(dir_to_player)
		move_and_slide()
		return

	if player and is_instance_valid(player):
		dir_to_player = player.global_position - global_position
		dist_to_player = dir_to_player.length()

		# Check player invisibility — is_invisible is already false when player is near torch
		var player_visible = not player.is_invisible
		# Forward vision: enemies only see player in front of them
		var player_in_front = true
		if not is_hit:  # When hit, enemy turns to face attacker
			if facing_right and dir_to_player.x < 0:
				player_in_front = false
			elif not facing_right and dir_to_player.x > 0:
				player_in_front = false
		# Very close = always detect (heard footsteps)
		if dist_to_player < 30:
			player_in_front = true
		if (not player_visible or not player_in_front) and enemy_class != EnemyClass.FLY:
			# Can't see player, patrol
			move_x = patrol_dir * speed * 0.3
			facing_right = patrol_dir > 0
		elif dist_to_player < detection_range:
			facing_right = dir_to_player.x > 0
			match enemy_class:
				EnemyClass.ARCHER, EnemyClass.CROSSBOW:
					if dist_to_player < attack_range * 0.5:
						move_x = -sign(dir_to_player.x) * speed
					elif dist_to_player > attack_range:
						move_x = sign(dir_to_player.x) * speed * 0.6
					if dist_to_player < attack_range and can_attack:
						_ranged_attack(dir_to_player)

				EnemyClass.THROWER:
					if dist_to_player < attack_range * 0.4:
						move_x = -sign(dir_to_player.x) * speed
					elif dist_to_player > attack_range * 0.8:
						move_x = sign(dir_to_player.x) * speed * 0.5
					if dist_to_player < attack_range and can_attack:
						_throw_attack(dir_to_player)

				EnemyClass.BRUTE:
					# Громила медленно идёт к игроку и бьёт тяжёлым станящим ударом.
					if dist_to_player > attack_range:
						move_x = sign(dir_to_player.x) * speed
					elif can_attack:
						_melee_attack()

				EnemyClass.SHIELDMAN:
					var block_range = attack_range + 10 if is_spear else 40.0
					is_blocking = dist_to_player < block_range and dist_to_player > 10 and not shield_broken
					# Don't move during leap prep
					if is_preparing_leap:
						move_x = 0
						velocity.x = 0
					elif is_leaping:
						pass  # Airborne, velocity set by leap
					elif dist_to_player > 60 and dist_to_player < 150 and leap_cooldown_timer <= 0 and not is_preparing_leap and is_on_floor():
						# Start leap preparation (player is medium distance)
						is_preparing_leap = true
						leap_prep_timer = leap_prep_duration
						move_x = 0
					elif dist_to_player > attack_range:
						move_x = sign(dir_to_player.x) * speed
					elif can_attack:
						_melee_attack()
		else:
			move_x = patrol_dir * speed * 0.3
			facing_right = patrol_dir > 0
	else:
		move_x = patrol_dir * speed * 0.3
		facing_right = patrol_dir > 0

	if is_leaping:
		pass  # Don't override leap velocity
	elif knockback_velocity.length() > 10:
		velocity.x = knockback_velocity.x
		knockback_velocity *= 0.85
	else:
		knockback_velocity = Vector2.ZERO
		velocity.x = move_x

	move_and_slide()

	if is_on_wall():
		patrol_dir *= -1
		patrol_timer = randf_range(2.0, 4.0)
	# Wall bounce knockback
	if is_on_wall() and knockback_velocity.length() > 60:
		knockback_velocity.x *= -0.5

func _update_sprite_anim(delta):
	# Choose animation based on state
	var use_shoot = is_shooting_anim or is_preparing_leap or is_leaping or is_attacking_melee
	var textures: Array

	# Thrower: randomly smokes when idle (not shooting, not chasing)
	if enemy_class == EnemyClass.THROWER and smoke_textures.size() > 0:
		if not use_shoot and not is_smoking and abs(velocity.x) < 5 and randf() < 0.005:
			is_smoking = true
			smoke_timer = 3.0
			sprite_frame = 0
		if is_smoking:
			smoke_timer -= delta
			if smoke_timer <= 0:
				is_smoking = false
			textures = smoke_textures
		elif use_shoot:
			textures = shoot_textures
		else:
			textures = walk_textures
	elif enemy_class == EnemyClass.SHIELDMAN:
		# Shieldman: block > jump > walk priority
		if (is_blocking or is_stunned) and block_textures.size() > 0:
			textures = block_textures
		elif not is_on_floor() and jump_textures.size() > 0:
			textures = jump_textures
		else:
			textures = walk_textures if walk_textures.size() > 0 else block_textures
	else:
		textures = shoot_textures if use_shoot else walk_textures

	if textures.size() == 0:
		return
	enemy_sprite.flip_h = !facing_right
	if is_hit:
		enemy_sprite.modulate = Color(2, 0.5, 0.5, 1)
	elif is_preparing_leap:
		var flash = abs(sin(leap_prep_timer * 8))
		enemy_sprite.modulate = Color(1 + flash, 1 - flash * 0.5, 1 - flash * 0.5, 1)
	elif is_stunned:
		enemy_sprite.modulate = Color(0.6, 0.6, 0.8, 1)
	elif is_smoking:
		enemy_sprite.modulate = Color(0.9, 0.9, 0.95, 1)  # Slight grey tint while smoking
	else:
		enemy_sprite.modulate = Color(1, 1, 1, 1)

	var fps = sprite_fps
	if is_smoking:
		fps = 5.0  # Slower animation for smoking
	sprite_timer += delta * fps
	if sprite_timer >= 1.0:
		sprite_timer -= 1.0
		sprite_frame = (sprite_frame + 1) % textures.size()
		enemy_sprite.texture = textures[sprite_frame]

func _ranged_attack(dir: Vector2):
	telegraph_timer = 0.3
	telegraph_duration = 0.3
	can_attack = false
	attack_timer = attack_cooldown + shot_delay
	# Start shoot animation FIRST, projectile spawns after delay
	is_shooting_anim = true
	shoot_anim_timer = 0.8
	sprite_frame = 0
	sprite_timer = 0.0
	pending_shot = true
	pending_shot_timer = shot_delay
	pending_shot_dir = dir

func _fire_projectile(dir: Vector2):
	match enemy_class:
		EnemyClass.ARCHER:
			_spawn_projectile(0, dir.normalized())
		EnemyClass.CROSSBOW:
			var base_dir = dir.normalized()
			_spawn_projectile(1, base_dir)
			_spawn_projectile(1, base_dir.rotated(0.15))
			_spawn_projectile(1, base_dir.rotated(-0.15))

func _throw_attack(dir: Vector2):
	telegraph_timer = 0.3
	telegraph_duration = 0.3
	can_attack = false
	attack_timer = attack_cooldown

	var rand = randf()
	if rand < 0.5:
		_spawn_projectile(2, dir.normalized() + Vector2(0, -0.3))
	else:
		_spawn_projectile(3, dir.normalized() + Vector2(0, -0.4))

func _spawn_projectile(type: int, dir: Vector2):
	var proj = Area2D.new()
	proj.set_script(projectile_script)
	proj.projectile_type = type
	proj.direction = dir.normalized()
	proj.damage = damage
	proj.global_position = global_position + Vector2(0, -10) + dir.normalized() * 10
	proj.rotation = dir.angle()
	get_parent().add_child(proj)

func flash_white():
	white_flash_timer = 0.12
	queue_redraw()

func _melee_attack():
	# Dead Cells-цикл: ЗАМАХ (читаемый телеграф — можно уйти/увернуться или
	# сбить лёгкому врагу) → УДАР (урон прилетает ТОЛЬКО после замаха) →
	# восстановление (кулдаун). Никакого мгновенного урона.
	var tele: float = 0.28
	if stuns_on_hit:
		tele = 0.5      # тяжёлые замахиваются дольше — читается издалека
	elif enemy_class == EnemyClass.ZOMBIE_CORPSE:
		tele = 0.38
	elif enemy_class == EnemyClass.RAT or enemy_class == EnemyClass.BEETLE:
		tele = 0.16     # рой кусает быстро, но и умирает с одного удара
	telegraph_timer = tele
	telegraph_duration = tele
	can_attack = false
	attack_timer = attack_cooldown
	pending_melee = true
	pending_melee_timer = tele
	telegraph_started.emit(global_position)   # аудио-«тень» атаки

func _strike_melee():
	# Момент удара — после замаха. Игрок мог уйти: проверяем дистанцию заново.
	is_attacking_melee = true
	melee_anim_timer = 0.22
	if not (player and is_instance_valid(player)):
		return
	var dist = global_position.distance_to(player.global_position)
	var dirp = (player.global_position - global_position).normalized()
	# Рывок вперёд в момент удара — атака живая, а не «стоит и тыкает»
	velocity.x = dirp.x * 110.0
	if dist >= attack_range + 14.0:
		return   # игрок УСПЕЛ отойти — удар в пустоту
	# Парирование: точный блок в момент удара оглушает врага
	if player.has_method("is_parrying") and player.is_parrying():
		is_stunned = true
		stun_timer = 2.5
		knockback_velocity = -dirp * 220
		knockback_velocity.y = -160
		if player.has_method("trigger_parry_flash"):
			player.trigger_parry_flash()
		return
	var final_dmg: int = damage
	if enemy_class == EnemyClass.HERETIC and randf() < 0.35:
		final_dmg = int(damage * 1.3)   # факельный удар еретика
	player.take_damage(final_dmg, dirp)
	if enemy_class == EnemyClass.ZOMBIE_CORPSE and player.has_method("apply_worm_infection"):
		player.apply_worm_infection()
	if stuns_on_hit and not player.is_dead and player.has_method("stun"):
		player.stun(stun_power)

func _attack_crystal():
	can_attack = false
	attack_timer = attack_cooldown
	is_attacking_melee = true
	melee_anim_timer = 0.25

	if crystal_target and is_instance_valid(crystal_target) and not crystal_target.is_destroyed:
		crystal_target.take_damage(damage)

func _spit_poison(dir: Vector2):
	# Fly spits a poison projectile
	var proj = Area2D.new()
	proj.set_script(projectile_script)
	proj.projectile_type = 3  # GRENADE type (re-use, explodes as poison)
	proj.direction = dir
	proj.damage = 10
	proj.global_position = global_position + dir * 10
	proj.rotation = dir.angle()
	get_parent().add_child(proj)
	# Also apply DOT if player is hit (handled in projectile hit)
	is_shooting_anim = true
	shoot_anim_timer = 0.3

func _throw_net():
	# Stealth enemy throws a net at the player
	if not player or not is_instance_valid(player):
		return
	var dist = global_position.distance_to(player.global_position)
	if dist < 60:
		net_thrown = true
		# Net the player for 7 seconds
		if player.has_method("apply_net"):
			player.apply_net(7.0)
		is_attacking_melee = true
		melee_anim_timer = 0.5

func _clear_sprite_for_programmatic_draw():
	# Called after setup() on dynamically spawned enemies so _ready()'s
	# default sprite (loaded as SHIELDMAN) doesn't render over _draw()
	if enemy_sprite and is_instance_valid(enemy_sprite):
		enemy_sprite.visible = false
	has_sprite_anim = false

func _summoner_spawn_rats():
	if not get_parent() or not player or not is_instance_valid(player):
		return
	# ЛИМИТЫ (перф + честность): максимум 4 живые крысы НА призывателя,
	# и глобальный потолок врагов в комнате — 40.
	summoner_children = summoner_children.filter(func(r): return is_instance_valid(r))
	if summoner_children.size() >= 4:
		return
	var room = get_parent()
	if room and "enemies" in room and room.enemies.size() >= 40:
		return
	var spawn_n: int = mini(2, 4 - summoner_children.size())
	var enemy_gd = load("res://scripts/enemy.gd")
	for i in spawn_n:
		var rat = CharacterBody2D.new()
		rat.set_script(enemy_gd)
		rat.enemy_class = EnemyClass.RAT  # set BEFORE add_child → _ready() skips shieldman sprites
		get_parent().add_child(rat)
		rat.setup(EnemyClass.RAT, 10, 90.0, 10)
		rat.player = player
		rat.global_position = global_position + Vector2(randf_range(-25, 25), -5)
		summoner_children.append(rat)
	# Visual effect — glow hands
	telegraph_timer = 0.4
	telegraph_duration = 0.4

func _mummy_spawn_beetle():
	if not get_parent() or not player or not is_instance_valid(player):
		return
	# ЛИМИТЫ: максимум 3 жука на мумию + глобальный потолок комнаты 40.
	mummy_beetle_children = mummy_beetle_children.filter(func(b): return is_instance_valid(b))
	if mummy_beetle_children.size() >= 3:
		return
	var mroom = get_parent()
	if mroom and "enemies" in mroom and mroom.enemies.size() >= 40:
		return
	var enemy_gd = load("res://scripts/enemy.gd")
	var beetle = CharacterBody2D.new()
	beetle.set_script(enemy_gd)
	beetle.enemy_class = EnemyClass.BEETLE  # set BEFORE add_child → _ready() skips shieldman sprites
	get_parent().add_child(beetle)
	beetle.setup(EnemyClass.BEETLE, 8, 28.0, 8)
	beetle.player = player
	beetle.beetle_parent_mummy = self
	var ang = randf() * TAU
	beetle.global_position = global_position + Vector2(cos(ang) * 20, sin(ang) * 5 - 5)
	mummy_beetle_children.append(beetle)

func _zombie_melee_attack():
	# Через общий Dead Cells-цикл (замах → удар); черви вешаются в _strike_melee.
	_melee_attack()

func _spider_shoot_web(dir: Vector2):
	if not player or not is_instance_valid(player):
		return
	var proj = Area2D.new()
	proj.set_script(projectile_script)
	proj.projectile_type = 4  # WEB
	proj.direction = dir
	proj.damage = 0
	proj.global_position = global_position + Vector2(0, -10) + dir * 12
	proj.rotation = dir.angle()
	get_parent().add_child(proj)
	velocity = -dir * 40
	telegraph_timer = 0.25
	telegraph_duration = 0.25

func _on_touch_player(body):
	if body.has_method("take_damage") and can_attack and enemy_class == EnemyClass.SHIELDMAN and not is_stunned:
		_melee_attack()

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO):
	# Stunned enemies take DOUBLE damage
	if is_stunned:
		health -= amount * 2
		is_hit = true
		hit_flash_timer = 0.15
		knockback_velocity = knockback_dir * 100
		knockback_velocity.y = -60
		if health <= 0:
			_notify_player_kill()
			died.emit(self)
			queue_free()
		return

	# Shieldman blocks from front
	if enemy_class == EnemyClass.SHIELDMAN and is_blocking:
		var attack_from_front = (facing_right and knockback_dir.x < 0) or (not facing_right and knockback_dir.x > 0)
		if attack_from_front:
			# Shield hit! Count it
			shield_hit_count += 1
			knockback_velocity = knockback_dir * 50
			is_hit = true
			hit_flash_timer = 0.1

			if shield_hit_count >= shield_hits_to_stun:
				# STUNNED! Shield breaks PERMANENTLY
				is_stunned = true
				stun_timer = stun_duration
				is_blocking = false
				shield_broken = true  # Shield destroyed forever
				knockback_velocity = knockback_dir * 120
				knockback_velocity.y = -60
			return

	# Knight parries 1 frontal hit, then 5s cooldown before next parry
	if enemy_class == EnemyClass.KNIGHT and knight_block_active and not is_stunned:
		var from_front = (facing_right and knockback_dir.x < 0) or (not facing_right and knockback_dir.x > 0)
		if from_front:
			knight_block_active = false
			knight_block_timer = 5.0
			is_hit = true
			hit_flash_timer = 0.12
			knockback_velocity = knockback_dir * 35  # slight push
			# Visual spark flash
			white_flash_timer = 0.1
			return

	# Enraged herectics take +50% damage (vulnerable while berserk)
	var final_amount = amount
	if enemy_class == EnemyClass.HERETIC and heretic_is_enraged:
		final_amount = int(amount * 1.5)
	# ELITE armored — получает на 45% меньше урона
	if elite_affix == "armored":
		final_amount = maxi(1, int(final_amount * 0.55))

	health -= final_amount
	is_hit = true
	hit_flash_timer = 0.15
	hit_shake_timer = 0.08
	_miniboss_check_enrage()   # мини-босс входит в ярость на 50% HP
	knockback_velocity = knockback_dir * 130
	knockback_velocity.y = -80
	# Armored — меньше отлетает
	if elite_affix == "armored":
		knockback_velocity *= 0.5

	# === ФЛИНЧ / СТОЙКОСТЬ (Dead Cells) ===
	# Лёгкие враги (poise 0) вздрагивают от КАЖДОГО удара и их замах сбивается —
	# агрессия игрока вознаграждается. Тяжёлые держат poise ударов и продавливают
	# свой замах — их атаку нужно уважать и уворачиваться.
	poise_counter += 1
	if poise_counter > poise:
		poise_counter = 0
		flinch_timer = 0.22
		if pending_melee and poise == 0:
			pending_melee = false   # замах лёгкого врага ПРЕРВАН ударом

	# Blood splatter burst
	_spawn_blood_splatter(knockback_dir)

	if health <= 0:
		_notify_player_kill()
		_spawn_death_particles()
		# Большая лужа крови при смерти (#25)
		var death_parent = get_parent()
		if death_parent and "decals" in death_parent and death_parent.decals:
			death_parent.decals.add_blood(global_position + Vector2(0, 3), 2.2)
		if enemy_class == EnemyClass.HERETIC:
			_heretic_on_death()
		# ELITE explosive — взрыв при смерти (урон по площади)
		if elite_affix == "explosive":
			_elite_explode()
		died.emit(self)
		queue_free()

func _elite_explode() -> void:
	var parent = get_parent()
	if not parent:
		return
	# Визуальный взрыв
	var explosion = Node2D.new()
	explosion.set_script(load("res://scripts/explosion_effect.gd"))
	explosion.global_position = global_position
	parent.add_child(explosion)
	# Урон игроку если рядом
	if player and is_instance_valid(player) and \
		global_position.distance_to(player.global_position) < 70.0:
		if player.has_method("take_damage"):
			var kb = (player.global_position - global_position).normalized()
			player.take_damage(damage + 4, kb)
	# Урон другим врагам (элита может убить своих — хаос)
	if "enemies" in parent:
		for other in parent.enemies:
			if other != self and is_instance_valid(other) \
				and global_position.distance_to(other.global_position) < 70.0:
				if other.has_method("take_damage"):
					var kb2 = (other.global_position - global_position).normalized()
					other.take_damage(20, kb2)

func _notify_player_kill():
	if not player or not is_instance_valid(player) or not player.has_method("on_kill"):
		return
	var xp_values = {
		EnemyClass.ARCHER: 8, EnemyClass.CROSSBOW: 10, EnemyClass.THROWER: 12,
		EnemyClass.SHIELDMAN: 15, EnemyClass.FLY: 8, EnemyClass.STEALTH: 20,
		EnemyClass.MAGE: 25, EnemyClass.SPIDER: 18,
		EnemyClass.SUMMONER: 30, EnemyClass.RAT: 2, EnemyClass.MUMMY: 22,
		EnemyClass.BEETLE: 2, EnemyClass.MOSQUITO: 12, EnemyClass.ZOMBIE_CORPSE: 18,
		EnemyClass.KNIGHT: 40, EnemyClass.HERETIC: 15, EnemyClass.DOG: 12
	}
	var xp_val = xp_values.get(enemy_class, 10)
	if is_miniboss: xp_val *= 3
	var coin_val = randi_range(1, 3) * (3 if is_miniboss else 1)
	player.on_kill(xp_val, coin_val)

func _spawn_death_particles():
	var parent = get_parent()
	if not parent:
		return
	# Pick a color based on enemy type
	var col = Color(0.9, 0.2, 0.1)
	match enemy_class:
		EnemyClass.ARCHER:   col = Color(0.8, 0.5, 0.1)
		EnemyClass.CROSSBOW: col = Color(0.5, 0.2, 0.8)
		EnemyClass.THROWER:  col = Color(0.2, 0.7, 0.2)
		EnemyClass.SHIELDMAN: col = Color(0.2, 0.4, 0.9)
		EnemyClass.FLY:      col = Color(0.1, 0.8, 0.6)
		EnemyClass.STEALTH:  col = Color(0.1, 0.1, 0.1)
		EnemyClass.SPIDER:        col = Color(0.1, 0.05, 0.15)
		EnemyClass.SUMMONER:      col = Color(0.4, 0.2, 0.6)
		EnemyClass.RAT:           col = Color(0.5, 0.4, 0.35)
		EnemyClass.MUMMY:         col = Color(0.8, 0.7, 0.4)
		EnemyClass.BEETLE:        col = Color(0.2, 0.5, 0.1)
		EnemyClass.MOSQUITO:      col = Color(0.1, 0.4, 0.15)
		EnemyClass.ZOMBIE_CORPSE: col = Color(0.2, 0.4, 0.1)
		EnemyClass.KNIGHT:        col = Color(0.45, 0.50, 0.60)
		EnemyClass.HERETIC:       col = Color(0.75, 0.30, 0.05)
		EnemyClass.DOG:           col = Color(0.50, 0.35, 0.22)
	# Spawn a burst node
	var burst = Node2D.new()
	burst.set_script(_make_burst_script())
	burst.global_position = global_position + Vector2(0, -10)
	burst.set_meta("color", col)
	parent.add_child(burst)

func _make_burst_script() -> GDScript:
	# Compile once per session — reuse for every death burst
	if _burst_script_cache:
		return _burst_script_cache
	var src = """
extends Node2D
var particles = []
var life = 0.7

func _ready():
	var col = get_meta("color")
	for i in 14:
		var angle = (i / 14.0) * TAU + randf_range(-0.2, 0.2)
		var spd = randf_range(60, 160)
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd - 40),
			"life": randf_range(0.3, 0.7),
			"max_life": 0.0,
			"size": randf_range(2, 5),
			"col": col.lightened(randf_range(0, 0.3))
		})
		particles[-1]["max_life"] = particles[-1]["life"]

func _process(delta):
	life -= delta
	if life <= 0:
		queue_free()
		return
	for p in particles:
		if p["life"] > 0:
			p["life"] -= delta
			p["pos"] += p["vel"] * delta
			p["vel"].y += 350 * delta
	queue_redraw()

func _draw():
	for p in particles:
		if p["life"] > 0:
			var a = p["life"] / p["max_life"]
			var c = p["col"]
			c.a = a
			var sz = p["size"] * a
			draw_rect(Rect2(p["pos"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)
"""
	var script = GDScript.new()
	script.source_code = src
	script.reload()
	_burst_script_cache = script
	return script

func _spawn_blood_splatter(knockback_dir: Vector2):
	var parent = get_parent()
	if not parent:
		return
	var burst = Node2D.new()
	burst.set_script(_make_blood_burst_script())
	burst.global_position = global_position + Vector2(0, -10)
	burst.set_meta("dir", knockback_dir)
	parent.add_child(burst)
	# Постоянное кровавое пятно на полу под врагом (#25)
	if "decals" in parent and parent.decals:
		parent.decals.add_blood(global_position + Vector2(0, 2), 1.0)

func _make_blood_burst_script() -> GDScript:
	# Compile once per session — reuse for every blood splatter
	if _blood_script_cache:
		return _blood_script_cache
	var src = """
extends Node2D
var particles = []
var life = 0.35

func _ready():
	var dir = get_meta("dir")
	var base_angle = dir.angle() if dir.length() > 0.01 else 0.0
	for i in 8:
		var spread = randf_range(-0.7, 0.7)
		var angle = base_angle + spread
		var spd = randf_range(40, 110)
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd - 20),
			"life": randf_range(0.25, 0.35),
			"max_life": 0.0,
			"size": randf_range(1, 3),
			"col": Color(0.7, 0.05, 0.05).darkened(randf_range(0, 0.2))
		})
		particles[-1]["max_life"] = particles[-1]["life"]

func _process(delta):
	life -= delta
	if life <= 0:
		queue_free()
		return
	for p in particles:
		if p["life"] > 0:
			p["life"] -= delta
			p["pos"] += p["vel"] * delta
			p["vel"].y += 300 * delta
	queue_redraw()

func _draw():
	for p in particles:
		if p["life"] > 0:
			var a = p["life"] / p["max_life"]
			var c = p["col"]
			c.a = a
			var sz = p["size"] * a
			draw_rect(Rect2(p["pos"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)
"""
	var script = GDScript.new()
	script.source_code = src
	script.reload()
	_blood_script_cache = script
	return script

func make_miniboss():
	is_miniboss = true
	max_health = max_health * 3
	health = max_health
	damage = damage * 2
	speed = speed * 1.3
	detection_range = detection_range * 1.5
	scale = Vector2(1.4, 1.4)
	poise = maxi(poise, 3)   # мини-босса не застанишь одним ударом

# Фаза ярости мини-босса (ниже 50% HP): быстрее, агрессивнее, чаще бьёт.
var miniboss_enraged: bool = false
func _miniboss_check_enrage():
	if is_miniboss and not miniboss_enraged and max_health > 0 \
		and float(health) / float(max_health) <= 0.5:
		miniboss_enraged = true
		speed *= 1.4
		attack_cooldown *= 0.6
		damage = int(damage * 1.25)
		white_flash_timer = 0.4   # заметная вспышка при переходе в ярость

func _mage_shoot(dir: Vector2):
	telegraph_timer = 0.35
	telegraph_duration = 0.35
	can_attack = false
	attack_timer = 2.2
	for i in 3:
		var spread = (i - 1) * 0.25
		_spawn_projectile(0, dir.normalized().rotated(spread))

var _low_end_draw: bool = (OS.get_name() == "Android" or OS.get_name() == "iOS")

# Упрощённый враг для телефона: ~8 отрисовок вместо ~100. Боссы/минибоссы
# рисуются детально (их мало, они важны визуально).
func _draw_simple(s: int) -> void:
	# Тень
	draw_rect(Rect2(-7, 1, 14, 3), Color(0, 0, 0, 0.35))
	var col := Color(0.64, 0.60, 0.52)   # костяной по умолчанию
	if is_hit or white_flash_timer > 0:
		col = Color(1, 1, 1)
	elif frozen_timer > 0:
		col = Color(0.6, 0.85, 1.0)
	elif is_on_fire:
		col = Color(1.0, 0.5, 0.2)
	elif is_poisoned:
		col = Color(0.5, 0.9, 0.3)
	# Тело + голова
	draw_rect(Rect2(-6, -20, 12, 20), col)
	draw_rect(Rect2(-5, -29, 10, 9), col.lightened(0.08))
	# Глаза по направлению
	draw_rect(Rect2(s * 2 - 1, -26, 2, 2), Color(0.1, 0.0, 0.0))
	# Подсказка атаки
	if is_attacking_melee:
		draw_rect(Rect2(s * 6, -16, s * 9, 3), Color(0.85, 0.85, 0.9))
	# Телеграф замаха (мобильная версия): «!» над головой
	if pending_melee:
		draw_string(ThemeDB.fallback_font, Vector2(-3, -32), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.3, 0.1, 0.95))
	# HP-полоска при ранении
	if health < max_health and max_health > 0:
		var f = clampf(float(health) / float(max_health), 0.0, 1.0)
		draw_rect(Rect2(-9, -35, 18, 2), Color(0.2, 0, 0, 0.7))
		draw_rect(Rect2(-9, -35, 18.0 * f, 2), Color(0.95, 0.2, 0.2))
	# Тетрадь Смерти: имя + таймер
	if death_note_timer_display >= 0:
		if death_note_name != "":
			draw_string(ThemeDB.fallback_font, Vector2(-24, -44),
				death_note_name, HORIZONTAL_ALIGNMENT_CENTER, 48, 7, Color(0.95, 0.85, 0.85, 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(-8, -28),
			"%.0fс" % death_note_timer_display, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.85, 0.1, 0.1))

func _draw():
	var s = 1 if facing_right else -1
	if _low_end_draw and not is_miniboss:
		_draw_simple(s)
		return
	var _was_shaking = hit_shake_timer > 0

	# === Soft shadow под ногами (привязывает к полу) ===
	if not is_stunned and is_on_floor():
		var sh_pts = PackedVector2Array()
		var segs = 14
		var sh_rx = 9.0
		var sh_ry = 2.5
		for sg in segs:
			var a = float(sg) / segs * TAU
			sh_pts.append(Vector2(cos(a) * sh_rx, 2.0 + sin(a) * sh_ry))
		draw_colored_polygon(sh_pts, Color(0, 0, 0, 0.40))

	# === Статусы: заморозка (ледяная корка) и shock (молнии) ===
	if frozen_timer > 0.0:
		# Ледяная корка — голубой полупрозрачный овал + кристаллы
		draw_circle(Vector2(0, -10), 14, Color(0.45, 0.85, 1.0, 0.55))
		for i in 4:
			var a = float(i) / 4.0 * TAU
			var p = Vector2(cos(a), sin(a)) * 11.0 + Vector2(0, -10)
			draw_rect(Rect2(p.x - 1, p.y - 2, 2, 4), Color(0.85, 0.95, 1.0, 0.85))
	if shocked_timer > 0.0:
		# Молнии — короткие случайные зигзаги от центра
		for i in 3:
			var a1 = randf() * TAU
			var a2 = a1 + randf_range(-0.5, 0.5)
			var p1 = Vector2(cos(a1), sin(a1)) * 8 + Vector2(0, -10)
			var p2 = Vector2(cos(a2), sin(a2)) * 14 + Vector2(0, -10)
			draw_line(p1, p2, Color(1.0, 1.0, 0.4, 0.85), 1.2)

	# === ELITE аура — пульсирующее цветное кольцо ===
	if elite_affix != "":
		var pulse = 0.55 + 0.45 * sin(_elite_pulse * 3.5)
		# Внешнее свечение
		draw_circle(Vector2(0, -10), 20.0 + pulse * 4.0,
			Color(elite_color.r, elite_color.g, elite_color.b, 0.10 * pulse))
		draw_circle(Vector2(0, -10), 14.0,
			Color(elite_color.r, elite_color.g, elite_color.b, 0.14 * pulse))
		# Кольцо-обводка
		draw_arc(Vector2(0, -10), 16.0, 0.0, TAU, 24,
			Color(elite_color.r, elite_color.g, elite_color.b, 0.55 * pulse), 1.5)
		# Орбитальные точки (3 шт вращаются)
		for oi in 3:
			var oa = _elite_pulse * 2.0 + oi * (TAU / 3.0)
			var op = Vector2(cos(oa), sin(oa)) * 16.0 + Vector2(0, -10)
			draw_circle(op, 2.0, elite_color)
			draw_circle(op, 1.0, Color(1, 1, 1, 0.9))
		# Ghostly — враг полупрозрачный во время фазы
		if elite_affix == "ghostly":
			var gp = fmod(_elite_ghost_t, 4.0)
			if gp < 1.2:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				# рисуем поверх полупрозрачную "дымку" чтобы показать фазинг
				draw_circle(Vector2(0, -10), 12.0, Color(0.65, 0.45, 0.95, 0.20))

	# Hit shake transform
	if hit_shake_timer > 0:
		var shake = Vector2(randf_range(-2.5, 2.5), randf_range(-1.5, 1.5))
		draw_set_transform(shake, 0.0, Vector2.ONE)

	# Use sprite if available (archer, crossbow, shieldman)
	if has_sprite_anim and enemy_class in [EnemyClass.ARCHER, EnemyClass.CROSSBOW, EnemyClass.SHIELDMAN, EnemyClass.THROWER]:
		# Draw leap warning on top of sprite
		if enemy_class == EnemyClass.SHIELDMAN and is_preparing_leap:
			var progress = 1.0 - (leap_prep_timer / leap_prep_duration)
			var warn_r = 25 * progress
			draw_arc(Vector2(0, -10), warn_r, 0, TAU, 16, Color(1, 0.2, 0.1, 0.5 * progress), 2.0)
			draw_rect(Rect2(-1, -32, 3, 6), Color(1, 0.2, 0.1, 0.8))
			draw_rect(Rect2(-1, -24, 3, 3), Color(1, 0.2, 0.1, 0.8))
	elif enemy_class == EnemyClass.FLY:
		_draw_fly(s)
	elif enemy_class == EnemyClass.STEALTH:
		_draw_stealth(s)
	elif enemy_class == EnemyClass.MAGE:
		_draw_mage(s)
	elif enemy_class == EnemyClass.SPIDER:
		_draw_spider(s)
	elif enemy_class == EnemyClass.SUMMONER:
		_draw_summoner(s)
	elif enemy_class == EnemyClass.RAT:
		_draw_rat(s)
	elif enemy_class == EnemyClass.MUMMY:
		_draw_mummy(s)
	elif enemy_class == EnemyClass.BEETLE:
		_draw_beetle(s)
	elif enemy_class == EnemyClass.MOSQUITO:
		_draw_mosquito(s)
	elif enemy_class == EnemyClass.ZOMBIE_CORPSE:
		_draw_zombie(s)
	elif enemy_class == EnemyClass.KNIGHT:
		_draw_knight(s)
	elif enemy_class == EnemyClass.HERETIC:
		_draw_heretic(s)
	elif enemy_class == EnemyClass.DOG:
		_draw_dog(s)
	elif enemy_class == EnemyClass.BRUTE:
		_draw_brute(s)
	else:
		match enemy_class:
			EnemyClass.ARCHER: _draw_archer(s)
			EnemyClass.CROSSBOW: _draw_crossbow(s)
			EnemyClass.THROWER: _draw_thrower(s)
			EnemyClass.SHIELDMAN: _draw_shieldman(s)

	# === ТЕЛЕГРАФ ЗАМАХА: «!» + растущее красное кольцо — атаку видно заранее ===
	if pending_melee:
		var tfrac: float = 1.0 - clampf(pending_melee_timer / maxf(0.01, telegraph_duration), 0.0, 1.0)
		draw_circle(Vector2(0, -12), 4.0 + 12.0 * tfrac, Color(1.0, 0.2, 0.08, 0.14))
		draw_string(ThemeDB.fallback_font, Vector2(-3, -32), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.3, 0.1, 0.95))

	# Pearl drop indicator
	if drops_pearl:
		var bob = sin(Time.get_ticks_msec() * 0.004) * 2
		# Pearl circle
		draw_circle(Vector2(0, -30 + bob), 4, Color(0.85, 0.85, 0.95, 0.7))
		draw_circle(Vector2(0, -30 + bob), 2.5, Color(0.95, 0.95, 1.0, 0.9))
		draw_circle(Vector2(-1, -31 + bob), 1, Color(1, 1, 1, 0.6))
		# Glow
		draw_circle(Vector2(0, -30 + bob), 7, Color(0.9, 0.9, 1.0, 0.12))

	# Pickaxe drop indicator (floating icon above head)
	if drops_pickaxe:
		var bob = sin(Time.get_ticks_msec() * 0.004) * 2
		# Mini pickaxe icon
		draw_line(Vector2(-3, -30 + bob), Vector2(3, -36 + bob), Color(0.55, 0.35, 0.15), 2.0)
		draw_line(Vector2(1, -37 + bob), Vector2(5, -34 + bob), Color(0.7, 0.7, 0.75), 2.5)
		# Glow
		draw_circle(Vector2(0, -33 + bob), 6, Color(1, 0.8, 0.3, 0.15))

	# Hit flash overlay
	if is_hit:
		draw_rect(Rect2(-6, -22, 12, 22), Color(1, 1, 1, 0.5))

	# Stun stars
	if is_stunned:
		var t = Time.get_ticks_msec() * 0.003
		for i in 3:
			var angle = t + i * TAU / 3
			var sx = cos(angle) * 8
			var sy = -26 + sin(angle * 2) * 2
			_draw_star(Vector2(sx, sy), 2.5, Color(1, 1, 0.3, 0.9))

		# Shield crack indicator
		if enemy_class == EnemyClass.SHIELDMAN:
			var shield_x = s * 9
			# Cracks on shield area
			draw_line(Vector2(shield_x - 2, -18), Vector2(shield_x + 1, -12), Color(0.9, 0.8, 0.2, 0.7), 1.0)
			draw_line(Vector2(shield_x, -16), Vector2(shield_x - 2, -8), Color(0.9, 0.8, 0.2, 0.7), 1.0)

	# Fire visual
	if is_on_fire:
		var t = Time.get_ticks_msec() * 0.006
		for i in 4:
			var fx = sin(t + i * 1.5) * 4
			var fy = -5 - i * 4 - fmod(t + i, 1.0) * 3
			var fr = 3.0 - i * 0.5
			draw_circle(Vector2(fx, fy), fr, Color(1, 0.5 + i * 0.1, 0.1, 0.6))
		draw_circle(Vector2(0, -10), 8, Color(1, 0.4, 0.1, 0.1))

	# Poison visual
	if is_poisoned:
		var t = Time.get_ticks_msec() * 0.005
		draw_circle(Vector2(0, -10), 10, Color(0.1, 0.7, 0.1, 0.15))
		for pi in 3:
			var bx = sin(t + pi * 2.1) * 5
			var by = -4 - pi * 5 - fmod(t + pi, 1.0) * 3
			draw_circle(Vector2(bx, by), 2, Color(0.2, 0.9, 0.1, 0.5))

	# Death Note timer + имя
	if death_note_timer_display >= 0:
		if death_note_name != "":
			draw_string(ThemeDB.fallback_font, Vector2(-24, -44),
				death_note_name, HORIZONTAL_ALIGNMENT_CENTER, 48, 7, Color(0.95, 0.85, 0.85, 0.9))
		var timer_text = "%.0f" % death_note_timer_display
		draw_string(ThemeDB.fallback_font, Vector2(-8, -28),
			timer_text + "с", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.8, 0.1, 0.1, 0.9))
		# Skull icon
		draw_circle(Vector2(0, -36), 4, Color(0.2, 0.05, 0.05, 0.8))
		draw_rect(Rect2(-2, -39, 1, 2), Color(0.8, 0.1, 0.1, 0.7))
		draw_rect(Rect2(1, -39, 1, 2), Color(0.8, 0.1, 0.1, 0.7))

	# Telegraph flash: orange/red aura when about to attack
	if telegraph_timer > 0:
		var t = telegraph_timer / maxf(0.001, telegraph_duration)
		var pulse = abs(sin(Time.get_ticks_msec() * 0.03))
		draw_circle(Vector2(0, -11), 14 + pulse * 4, Color(1.0, 0.4, 0.0, 0.35 * t))
		draw_circle(Vector2(0, -11), 10, Color(1.0, 0.6, 0.1, 0.2 * t))

	# White flash on crit hit
	if white_flash_timer > 0:
		var a = white_flash_timer / 0.12
		draw_rect(Rect2(-8, -24, 16, 24), Color(1, 1, 1, 0.85 * a))

	# Mini-boss crown and HP bar
	if is_miniboss:
		# Аура ЯРОСТИ (ниже 50% HP): пульсирующее красное кольцо + шипы короны.
		if miniboss_enraged:
			var ep = 0.5 + 0.5 * sin(_elite_pulse * 6.0)
			draw_circle(Vector2(0, -12), 20.0 + ep * 4.0, Color(1.0, 0.15, 0.05, 0.10 + ep * 0.10))
			draw_arc(Vector2(0, -12), 18.0, 0, TAU, 20, Color(1.0, 0.25, 0.10, 0.55), 1.5)
		var crown_col := Color(1.0, 0.30, 0.10, 0.95) if miniboss_enraged else Color(1, 0.8, 0.1, 0.9)
		draw_rect(Rect2(-5, -30, 10, 4), crown_col)
		draw_rect(Rect2(-6, -34, 4, 4), crown_col)
		draw_rect(Rect2(-1, -36, 2, 6), crown_col)
		draw_rect(Rect2(3, -34, 4, 4), crown_col)
		var hp_pct = float(health) / float(max_health)
		draw_rect(Rect2(-12, -38, 24, 3), Color(0.1, 0.1, 0.1, 0.8))
		draw_rect(Rect2(-12, -38, 24 * hp_pct, 3), Color(1.0 - hp_pct, hp_pct * 0.8, 0.1, 0.9))

	# Reset hit shake transform
	if _was_shaking:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_star(pos: Vector2, size: float, color: Color):
	# Simple 4-point star
	draw_line(pos + Vector2(-size, 0), pos + Vector2(size, 0), color, 1.5)
	draw_line(pos + Vector2(0, -size), pos + Vector2(0, size), color, 1.5)
	draw_line(pos + Vector2(-size * 0.6, -size * 0.6), pos + Vector2(size * 0.6, size * 0.6), color, 1.0)
	draw_line(pos + Vector2(size * 0.6, -size * 0.6), pos + Vector2(-size * 0.6, size * 0.6), color, 1.0)

func _draw_archer(s: int):
	var t = Time.get_ticks_msec() * 0.005
	var moving = abs(velocity.x) > 8
	var lf = sin(t * 3.8) * 2.5 if moving else 0.0  # front leg offset
	var bob = sin(t * 3.8) * 0.7 if moving else 0.0  # body bob (half period)
	# Legs — opposite phase for natural stride
	draw_rect(Rect2(-3, -3 + lf,  3, 4), Color(0.3, 0.22, 0.15))
	draw_rect(Rect2( 1, -3 - lf,  3, 4), Color(0.3, 0.22, 0.15))
	# Body
	draw_rect(Rect2(-4, -14 + bob, 8, 12), Color(0.35, 0.28, 0.18))
	draw_rect(Rect2(-3, -13 + bob, 6,  5), Color(0.25, 0.20, 0.12))
	# Hood
	draw_rect(Rect2(-4, -20 + bob, 8, 7), Color(0.30, 0.25, 0.15))
	draw_rect(Rect2(-3, -19 + bob, 6, 5), Color(0.25, 0.20, 0.12))
	# Eye
	draw_rect(Rect2(s, -17 + bob, 2, 1), Color(0.9, 0.3, 0.2))
	# Bow
	var bow_x = s * 7
	draw_arc(Vector2(bow_x, -12 + bob), 8,
		-PI/2 * s + PI/2, PI/2 * s + PI/2, 12, Color(0.5, 0.35, 0.15), 1.5)
	# String + nocked arrow when drawing bow
	if is_shooting_anim or telegraph_timer > 0:
		var pull = float(-s * 4)  # string pulled toward body
		draw_line(Vector2(bow_x, -20 + bob), Vector2(bow_x + pull, -12 + bob), Color(0.85, 0.85, 0.85), 0.9)
		draw_line(Vector2(bow_x + pull, -12 + bob), Vector2(bow_x, -4 + bob),  Color(0.85, 0.85, 0.85), 0.9)
		# Arrow
		draw_line(Vector2(bow_x + pull - s*2, -12 + bob), Vector2(bow_x + s*5, -12 + bob), Color(0.5, 0.35, 0.15), 1.5)
		draw_rect(Rect2(bow_x + s*4, -13 + bob, 2, 2), Color(0.65, 0.65, 0.70))
	else:
		draw_line(Vector2(bow_x, -20 + bob), Vector2(bow_x, -4 + bob), Color(0.7, 0.7, 0.7), 0.5)
	# Quiver on back
	draw_rect(Rect2(-s * 5, -18 + bob, 3, 10), Color(0.4, 0.28, 0.12))

func _draw_crossbow(s: int):
	var t = Time.get_ticks_msec() * 0.005
	var moving = abs(velocity.x) > 8
	var lf = sin(t * 3.5) * 2.5 if moving else 0.0
	var bob = sin(t * 3.5) * 0.6 if moving else 0.0
	# Legs
	draw_rect(Rect2(-3, -3 + lf, 3, 4), Color(0.22, 0.22, 0.25))
	draw_rect(Rect2( 1, -3 - lf, 3, 4), Color(0.22, 0.22, 0.25))
	# Heavy armor body
	draw_rect(Rect2(-5, -15 + bob, 10, 13), Color(0.30, 0.30, 0.35))
	draw_rect(Rect2(-4, -14 + bob,  8,  6), Color(0.38, 0.38, 0.42))
	# Head with half-helm
	draw_rect(Rect2(-4, -21 + bob, 8, 7), Color(0.85, 0.70, 0.50))
	draw_rect(Rect2(-4, -21 + bob, 8, 3), Color(0.40, 0.40, 0.45))
	# Eyes
	draw_rect(Rect2(s, -19 + bob, 2, 1), Color(0.2, 0.2, 0.2))
	# Crossbow — raised when aiming
	var cx = s * 8
	var raise = bob + (-3 if (is_shooting_anim or telegraph_timer > 0) else 0)
	draw_rect(Rect2(cx - 2, -13 + raise, 4, 2), Color(0.4, 0.3, 0.15))
	draw_line(Vector2(cx,       -13 + raise), Vector2(cx - 4*s, -17 + raise), Color(0.4, 0.4, 0.4), 1.5)
	draw_line(Vector2(cx,       -13 + raise), Vector2(cx - 4*s,  -9 + raise), Color(0.4, 0.4, 0.4), 1.5)
	draw_line(Vector2(cx - 4*s, -17 + raise), Vector2(cx - 4*s,  -9 + raise), Color(0.6, 0.6, 0.6), 0.5)
	# Bolt loaded when aiming
	if is_shooting_anim or telegraph_timer > 0:
		draw_line(Vector2(cx - s*5, -13 + raise), Vector2(cx + s*2, -13 + raise), Color(0.6, 0.5, 0.25), 1.2)
	# Bolt rack on belt
	for i in 3:
		draw_line(Vector2(-s*3 + i*2, -4), Vector2(-s*3 + i*2, -1), Color(0.5, 0.4, 0.2), 1.0)

func _draw_thrower(s: int):
	# Legs
	draw_rect(Rect2(-3, -3, 3, 4), Color(0.28, 0.2, 0.15))
	draw_rect(Rect2(1, -3, 3, 4), Color(0.28, 0.2, 0.15))
	# Body
	draw_rect(Rect2(-5, -16, 10, 14), Color(0.4, 0.3, 0.2))
	draw_rect(Rect2(-4, -15, 8, 6), Color(0.45, 0.35, 0.22))
	# Bandolier
	draw_line(Vector2(-4, -15), Vector2(4, -8), Color(0.3, 0.25, 0.15), 2.0)
	draw_circle(Vector2(-2, -9), 2, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2(2, -10), 2, Color(0.3, 0.3, 0.3))
	# Head
	draw_rect(Rect2(-4, -22, 8, 7), Color(0.85, 0.7, 0.5))
	# Bandana
	draw_rect(Rect2(-4, -22, 8, 3), Color(0.6, 0.15, 0.1))
	# Eye
	draw_rect(Rect2(s * 1, -20, 2, 2), Color(0.15, 0.15, 0.15))
	# Hammer in hand
	var hx = s * 8
	draw_line(Vector2(hx, -14), Vector2(hx, -6), Color(0.45, 0.3, 0.12), 2.0)
	draw_rect(Rect2(hx - 3, -17, 6, 4), Color(0.5, 0.5, 0.55))

func _draw_shieldman(s: int):
	# Leap preparation visual - shaking + red warning
	if is_preparing_leap:
		var shake = sin(leap_prep_timer * 30) * 2
		var progress = 1.0 - (leap_prep_timer / leap_prep_duration)
		# Warning circle expanding
		var warn_r = 25 * progress
		draw_arc(Vector2(0, -10), warn_r, 0, TAU, 16, Color(1, 0.2, 0.1, 0.5 * progress), 2.0)
		# Exclamation mark
		draw_rect(Rect2(-1, -32, 3, 6), Color(1, 0.2, 0.1, 0.8))
		draw_rect(Rect2(-1, -24, 3, 3), Color(1, 0.2, 0.1, 0.8))
		# Apply shake offset for the rest of the draw
		draw_set_transform(Vector2(shake, 0))

	# Leaping visual - tucked pose
	if is_leaping:
		draw_set_transform(Vector2(0, 0), velocity.angle() * 0.3)

	# Legs with greaves
	draw_rect(Rect2(-4, -3, 3, 4), Color(0.35, 0.35, 0.38))
	draw_rect(Rect2(1, -3, 3, 4), Color(0.35, 0.35, 0.38))
	# Heavy plate armor body
	draw_rect(Rect2(-5, -16, 10, 14), Color(0.4, 0.4, 0.45))
	draw_rect(Rect2(-4, -15, 8, 7), Color(0.48, 0.48, 0.52))
	# Shoulder pads
	draw_rect(Rect2(-6, -16, 3, 4), Color(0.45, 0.45, 0.5))
	draw_rect(Rect2(3, -16, 3, 4), Color(0.45, 0.45, 0.5))
	# Full helm
	draw_rect(Rect2(-4, -22, 8, 7), Color(0.45, 0.45, 0.5))
	draw_rect(Rect2(-4, -22, 8, 2), Color(0.52, 0.52, 0.56))
	# Visor slit
	draw_rect(Rect2(-3 + s, -19, 5, 1), Color(0.08, 0.08, 0.1))

	# Eyes glow based on state
	if is_stunned:
		# Dazed eyes - swirly
		draw_rect(Rect2(s - 1, -19, 3, 1), Color(0.8, 0.8, 0.2))
	else:
		draw_rect(Rect2(s, -19, 2, 1), Color(0.6, 0.15, 0.1))

	# Shield
	if shield_broken:
		# Broken shield pieces on the ground
		draw_rect(Rect2(s * 3, -2, 4, 3), Color(0.4, 0.12, 0.08, 0.5))
		draw_rect(Rect2(s * 6, -1, 3, 2), Color(0.45, 0.15, 0.1, 0.4))
		draw_rect(Rect2(s * 1, 0, 2, 1), Color(0.35, 0.1, 0.06, 0.3))
	elif is_blocking and not is_stunned:
		var sx = s * 9
		draw_rect(Rect2(sx - 4, -20, 7, 17), Color(0.5, 0.15, 0.1))
		draw_rect(Rect2(sx - 3, -19, 5, 15), Color(0.55, 0.2, 0.12))
		draw_rect(Rect2(sx - 1, -15, 2, 2), Color(0.7, 0.6, 0.2))
		# Shield hit indicators (cracks)
		if shield_hit_count > 0:
			for i in shield_hit_count:
				var crack_y = -17 + i * 5
				draw_line(Vector2(sx - 2, crack_y), Vector2(sx + 2, crack_y + 3), Color(0.3, 0.1, 0.05), 1.0)
		# Rivets
		draw_circle(Vector2(sx, -18), 1, Color(0.6, 0.55, 0.3))
		draw_circle(Vector2(sx, -6), 1, Color(0.6, 0.55, 0.3))
	elif is_stunned:
		# Shield lowered/dropped during stun
		var sx = s * 5
		draw_rect(Rect2(sx - 3, -6, 6, 7), Color(0.45, 0.12, 0.08, 0.7))

	# Weapon - spear or sword
	if is_spear:
		# Spear variant
		if is_attacking_melee:
			var swing_progress = 1.0 - (melee_anim_timer / 0.25)
			# Thrust forward
			var thrust_x = lerp(float(s * 5), float(s * 28), swing_progress)
			draw_line(Vector2(s * 3, -12), Vector2(thrust_x, -12), Color(0.5, 0.35, 0.15), 2.0)
			# Spear tip
			var tip_points = PackedVector2Array([
				Vector2(thrust_x, -15), Vector2(thrust_x + s * 6, -12), Vector2(thrust_x, -9)
			])
			draw_colored_polygon(tip_points, Color(0.75, 0.75, 0.8))
		elif not is_stunned:
			# Idle spear - held diagonally
			draw_line(Vector2(s * 4, -6), Vector2(s * 12, -26), Color(0.5, 0.35, 0.15), 2.0)
			# Spear tip
			var tip_points = PackedVector2Array([
				Vector2(s * 12, -29), Vector2(s * 14, -26), Vector2(s * 12, -23)
			])
			draw_colored_polygon(tip_points, Color(0.75, 0.75, 0.8))
		else:
			# Spear drooping
			draw_line(Vector2(s * 5, -6), Vector2(s * 14, 0), Color(0.5, 0.35, 0.15), 2.0)
	else:
		# Sword - horizontal swing like player
		if is_attacking_melee:
			var swing_progress = 1.0 - (melee_anim_timer / 0.25)
			var base = Vector2(s * 5, -12)
			var angle = lerp(-0.6, 1.0, swing_progress) * s
			var tip = base + Vector2(cos(angle) * 18, sin(angle) * 8 - 2)
			draw_line(base, tip, Color(0.8, 0.8, 0.85), 2.5)
			draw_line(base + Vector2(0, -3), base + Vector2(0, 3), Color(0.6, 0.5, 0.2), 2.0)
		elif not is_stunned:
			draw_line(Vector2(s * 6, -16), Vector2(s * 7, -3), Color(0.7, 0.7, 0.78), 2.0)
			draw_line(Vector2(s * 4, -16), Vector2(s * 8, -16), Color(0.5, 0.4, 0.2), 1.5)
		else:
			# Sword drooping during stun
			draw_line(Vector2(s * 5, -8), Vector2(s * 8, 0), Color(0.6, 0.6, 0.65), 2.0)

	# Reset transform after leap/prep drawing
	if is_preparing_leap or is_leaping:
		draw_set_transform(Vector2.ZERO)

func _draw_fly(s: int):
	var wing_anim = sin(fly_sin_offset * 8) * 0.4
	# Body — dark green/black
	draw_circle(Vector2(0, -8), 5, Color(0.15, 0.2, 0.1))
	draw_circle(Vector2(0, -8), 3.5, Color(0.2, 0.3, 0.15))
	# Head
	draw_circle(Vector2(s * 4, -10), 3, Color(0.1, 0.15, 0.08))
	# Eyes — big red compound eyes
	draw_circle(Vector2(s * 5, -12), 2.2, Color(0.9, 0.1, 0.05))
	draw_circle(Vector2(s * 5, -12), 1.0, Color(1, 0.3, 0.1))
	draw_circle(Vector2(s * 3, -11), 1.8, Color(0.8, 0.1, 0.05))
	# Wings — semi-transparent, flapping
	var w1_y = -14 + wing_anim * 6
	var w2_y = -14 - wing_anim * 4
	draw_line(Vector2(-3, -10), Vector2(-10, w1_y), Color(0.6, 0.7, 0.8, 0.4), 2.0)
	draw_line(Vector2(3, -10), Vector2(10, w2_y), Color(0.6, 0.7, 0.8, 0.4), 2.0)
	# Wing shapes
	draw_circle(Vector2(-10, w1_y), 4, Color(0.7, 0.8, 0.9, 0.2))
	draw_circle(Vector2(10, w2_y), 4, Color(0.7, 0.8, 0.9, 0.2))
	# Legs — thin dangling
	for i in 3:
		var lx = -2 + i * 2
		draw_line(Vector2(lx, -4), Vector2(lx + sin(fly_sin_offset + i), 2), Color(0.1, 0.1, 0.05), 0.5)
	# Poison drip
	if fly_spit_cooldown < 0.5:
		draw_circle(Vector2(s * 5, -7), 1.5, Color(0.2, 0.9, 0.1, 0.7))

func _draw_stealth(s: int):
	if is_hidden:
		# Only show faint glowing eyes in the wall
		var eye_alpha = 0.3 + sin(Time.get_ticks_msec() * 0.003) * 0.15
		draw_circle(Vector2(-3, -12), 1.5, Color(0.9, 0.2, 0.1, eye_alpha))
		draw_circle(Vector2(3, -12), 1.5, Color(0.9, 0.2, 0.1, eye_alpha))
		return
	# Visible — dark humanoid with cloak
	# Body
	draw_rect(Rect2(-4, -20, 8, 16), Color(0.12, 0.1, 0.15))
	# Cloak edges
	draw_line(Vector2(-4, -20), Vector2(-6, -2), Color(0.08, 0.06, 0.1), 1.5)
	draw_line(Vector2(4, -20), Vector2(6, -2), Color(0.08, 0.06, 0.1), 1.5)
	# Hood
	draw_circle(Vector2(0, -20), 5, Color(0.1, 0.08, 0.12))
	# Eyes — red glow under hood
	draw_circle(Vector2(-2 * s, -21), 1.5, Color(1, 0.15, 0.1, 0.9))
	draw_circle(Vector2(2 * s, -21), 1.5, Color(1, 0.15, 0.1, 0.9))
	# Legs
	draw_line(Vector2(-2, -4), Vector2(-3, 0), Color(0.1, 0.1, 0.1), 1.5)
	draw_line(Vector2(2, -4), Vector2(3, 0), Color(0.1, 0.1, 0.1), 1.5)
	# Net in hand
	if net_cooldown > 8:
		draw_circle(Vector2(s * 6, -14), 3, Color(0.5, 0.4, 0.3, 0.5))
		draw_arc(Vector2(s * 6, -14), 3, 0, TAU, 8, Color(0.6, 0.5, 0.4), 0.5)

func _draw_mage(s: int):
	# Robe
	draw_rect(Rect2(-5, -18, 10, 18), Color(0.25, 0.10, 0.45))
	draw_rect(Rect2(-4, -17, 8, 8), Color(0.32, 0.14, 0.55))
	# Hood
	draw_rect(Rect2(-5, -26, 10, 9), Color(0.20, 0.08, 0.38))
	draw_rect(Rect2(-3, -24, 6, 6), Color(0.15, 0.06, 0.30))
	# Glowing eyes
	var t = Time.get_ticks_msec() * 0.005
	var glow = 0.7 + sin(t) * 0.3
	draw_circle(Vector2(-2, -21), 2.0, Color(0.6, 0.1, 1.0, glow))
	draw_circle(Vector2(2, -21), 2.0, Color(0.6, 0.1, 1.0, glow))
	draw_circle(Vector2(-2, -21), 1.0, Color(1, 0.8, 1.0, glow))
	draw_circle(Vector2(2, -21), 1.0, Color(1, 0.8, 1.0, glow))
	# Staff
	var sx = s * 7
	draw_line(Vector2(sx, -20), Vector2(sx, 0), Color(0.45, 0.30, 0.15), 2.0)
	draw_circle(Vector2(sx, -22), 4, Color(0.6, 0.1, 1.0, 0.8))
	draw_circle(Vector2(sx, -22), 2, Color(0.9, 0.6, 1.0, glow))
	# Orbiting particles
	var ot = Time.get_ticks_msec() * 0.003
	for oi in 3:
		var oa = ot + oi * TAU / 3
		draw_circle(Vector2(cos(oa) * 10, -10 + sin(oa) * 5), 2.5, Color(0.7, 0.2, 1.0, 0.7))

func _draw_spider(s: int):
	var t = spider_leg_phase
	# Abdomen
	draw_circle(Vector2(-s * 3, -7), 8.0, Color(0.08, 0.04, 0.12))
	draw_circle(Vector2(-s * 3, -7), 6.0, Color(0.15, 0.07, 0.20))
	draw_rect(Rect2(-s * 5, -10, 4, 5), Color(0.85, 0.05, 0.05, 0.85))  # hourglass
	# Head
	draw_circle(Vector2(s * 4, -13), 5.5, Color(0.12, 0.06, 0.18))
	# 4 eyes (2 pairs, no loop)
	var eg = 0.6 + sin(t * 0.8) * 0.3
	draw_circle(Vector2(s * 3, -16), 1.2, Color(0.9, 0.1, 0.1, eg))
	draw_circle(Vector2(s * 5, -16), 1.2, Color(0.9, 0.1, 0.1, eg))
	draw_circle(Vector2(s * 3, -14), 1.0, Color(0.9, 0.1, 0.1, eg * 0.7))
	draw_circle(Vector2(s * 5, -14), 1.0, Color(0.9, 0.1, 0.1, eg * 0.7))
	# 8 legs — 4 left, 4 right, computed without per-leg loops
	var lob = sin(t) * 2.0  # leg bob alternates
	var bx = s * 2.0
	draw_line(Vector2(bx, -12), Vector2(bx + s * 6, -8 + lob), Color(0.18, 0.09, 0.24), 1.6)
	draw_line(Vector2(bx, -11), Vector2(bx + s * 7, -4 - lob), Color(0.18, 0.09, 0.24), 1.6)
	draw_line(Vector2(bx, -10), Vector2(bx + s * 6, 0 + lob), Color(0.18, 0.09, 0.24), 1.6)
	draw_line(Vector2(bx, -9), Vector2(bx + s * 5, 3 - lob), Color(0.18, 0.09, 0.24), 1.3)
	draw_line(Vector2(bx, -12), Vector2(bx - s * 6, -8 - lob), Color(0.14, 0.07, 0.19), 1.6)
	draw_line(Vector2(bx, -11), Vector2(bx - s * 7, -4 + lob), Color(0.14, 0.07, 0.19), 1.6)
	draw_line(Vector2(bx, -10), Vector2(bx - s * 6, 0 - lob), Color(0.14, 0.07, 0.19), 1.6)
	draw_line(Vector2(bx, -9), Vector2(bx - s * 5, 3 + lob), Color(0.14, 0.07, 0.19), 1.3)
	# Fangs
	draw_line(Vector2(s * 6, -13), Vector2(s * 9, -11), Color(0.6, 0.6, 0.7), 1.5)
	# Web gland
	if not spider_web_used:
		draw_circle(Vector2(-s * 10, -7), 2.0, Color(0.9, 0.9, 1.0, 0.7))

func _draw_summoner(s: int):
	# Robe (dark purple-brown, hooded)
	draw_rect(Rect2(-5, -20, 10, 20), Color(0.18, 0.08, 0.28))
	draw_rect(Rect2(-4, -18, 8, 10), Color(0.24, 0.11, 0.36))
	# Hood
	draw_rect(Rect2(-5, -29, 10, 10), Color(0.14, 0.06, 0.22))
	draw_circle(Vector2(0, -26), 5.5, Color(0.14, 0.06, 0.22))
	# Face in shadow
	draw_circle(Vector2(0, -24), 4.0, Color(0.08, 0.04, 0.12))
	# Glowing eyes
	var t = Time.get_ticks_msec() * 0.004
	var eg = 0.5 + sin(t) * 0.4
	draw_circle(Vector2(-2, -25), 1.5, Color(0.8, 0.4, 1.0, eg))
	draw_circle(Vector2(2, -25), 1.5, Color(0.8, 0.4, 1.0, eg))
	# Hands raised when summoning
	if telegraph_timer > 0:
		var prog = telegraph_timer / maxf(0.001, telegraph_duration)
		draw_circle(Vector2(-s * 8, -16), 3.5 * prog, Color(0.7, 0.3, 1.0, 0.8 * prog))
		draw_circle(Vector2(s * 8, -16), 3.5 * prog, Color(0.7, 0.3, 1.0, 0.8 * prog))
	else:
		draw_line(Vector2(-s * 4, -16), Vector2(-s * 8, -18), Color(0.22, 0.10, 0.30), 2.0)
		draw_line(Vector2(s * 4, -16), Vector2(s * 8, -18), Color(0.22, 0.10, 0.30), 2.0)
	# Spawn timer indicator (small dots above head)
	var frac = 1.0 - (summoner_spawn_timer / 4.0)
	for di in 4:
		var dc = Color(0.6, 0.2, 0.9, 0.9) if float(di) / 4.0 < frac else Color(0.3, 0.15, 0.4, 0.5)
		draw_circle(Vector2(-4 + di * 3, -34), 1.8, dc)

func _draw_rat(s: int):
	# Tiny oval body
	draw_circle(Vector2(0, -6), 5.5, Color(0.38, 0.30, 0.26))
	draw_circle(Vector2(0, -6), 4.0, Color(0.48, 0.38, 0.32))
	# Head
	draw_circle(Vector2(s * 5, -9), 4.0, Color(0.40, 0.32, 0.28))
	# Ears
	draw_circle(Vector2(s * 4, -13), 2.2, Color(0.55, 0.35, 0.35))
	draw_circle(Vector2(s * 6, -12), 1.8, Color(0.55, 0.35, 0.35))
	# Eyes (beady, red)
	draw_circle(Vector2(s * 6, -10), 1.2, Color(0.9, 0.1, 0.1))
	draw_circle(Vector2(s * 6, -10), 0.5, Color(1, 0.5, 0.5))
	# Nose
	draw_circle(Vector2(s * 8, -9), 0.8, Color(0.9, 0.5, 0.5))
	# Tail (wiggly)
	var t = Time.get_ticks_msec() * 0.006
	var tx0 = Vector2(-s * 5, -4)
	var tx1 = Vector2(-s * 9, -2 + sin(t) * 2)
	var tx2 = Vector2(-s * 12, 0 + sin(t + 1) * 2)
	draw_line(tx0, tx1, Color(0.35, 0.25, 0.22), 1.2)
	draw_line(tx1, tx2, Color(0.35, 0.25, 0.22), 0.8)
	# Legs (fast tiny stubs)
	var leg_bob = sin(t * 3) * 1.5
	draw_line(Vector2(-3, -3), Vector2(-4, 1 + leg_bob), Color(0.38, 0.30, 0.26), 1.2)
	draw_line(Vector2(0, -3), Vector2(0, 1 - leg_bob), Color(0.38, 0.30, 0.26), 1.2)
	draw_line(Vector2(3, -3), Vector2(4, 1 + leg_bob), Color(0.38, 0.30, 0.26), 1.2)

func _draw_mummy(s: int):
	var t = mummy_anim_phase
	# Body (wrapped bandages)
	draw_rect(Rect2(-5, -20, 10, 20), Color(0.75, 0.68, 0.48))
	# Bandage strips (horizontal)
	for bi in 5:
		var by = -18 + bi * 4
		var bx_off = sin(t + bi) * 0.8
		draw_line(Vector2(-5 + bx_off, by), Vector2(5 + bx_off, by), Color(0.88, 0.82, 0.62, 0.7), 0.8)
	# Head
	draw_circle(Vector2(0, -25), 6.0, Color(0.78, 0.70, 0.50))
	# Scarab beetle emblem on chest
	draw_circle(Vector2(0, -12), 4.0, Color(0.1, 0.35, 0.55))
	draw_circle(Vector2(0, -12), 2.5, Color(0.15, 0.50, 0.75))
	# Scarab legs
	for si in 3:
		var sa = -1.0 + si
		draw_line(Vector2(-4, -12), Vector2(-7, -10 + sa * 2), Color(0.1, 0.3, 0.5), 0.8)
		draw_line(Vector2(4, -12), Vector2(7, -10 + sa * 2), Color(0.1, 0.3, 0.5), 0.8)
	# Hollow eye sockets — glowing orange-yellow
	var eg = 0.7 + sin(t * 2) * 0.25
	draw_circle(Vector2(-2, -26), 2.0, Color(0.02, 0.02, 0.02))
	draw_circle(Vector2(2, -26), 2.0, Color(0.02, 0.02, 0.02))
	draw_circle(Vector2(-2, -26), 1.2, Color(1.0, 0.7, 0.1, eg))
	draw_circle(Vector2(2, -26), 1.2, Color(1.0, 0.7, 0.1, eg))
	# Outstretched arms
	draw_line(Vector2(-5, -16), Vector2(-12, -18 + sin(t) * 1.5), Color(0.75, 0.68, 0.48), 2.5)
	draw_line(Vector2(5, -16), Vector2(12, -18 + sin(t + PI) * 1.5), Color(0.75, 0.68, 0.48), 2.5)

func _draw_beetle(s: int):
	var t = beetle_crawl_phase
	# Shell (oval, iridescent dark green)
	draw_circle(Vector2(0, -5), 6.5, Color(0.08, 0.28, 0.08))
	draw_circle(Vector2(0, -5), 5.0, Color(0.12, 0.40, 0.14))
	draw_circle(Vector2(0, -5), 3.5, Color(0.18, 0.52, 0.20))
	# Shell split line
	draw_line(Vector2(0, -1), Vector2(0, -10), Color(0.05, 0.20, 0.05), 0.8)
	# Head
	draw_circle(Vector2(s * 5, -6), 3.5, Color(0.10, 0.25, 0.10))
	# Antennae
	draw_line(Vector2(s * 6, -9), Vector2(s * 9, -14), Color(0.08, 0.20, 0.08), 0.8)
	draw_line(Vector2(s * 5, -9), Vector2(s * 10, -12), Color(0.08, 0.20, 0.08), 0.8)
	# Eyes
	draw_circle(Vector2(s * 7, -7), 1.0, Color(0.9, 0.7, 0.1))
	# 6 legs (alternating)
	for li in 3:
		var leg_y = -8 + li * 2.5
		var bob = sin(t + li * 1.2) * 2.0
		draw_line(Vector2(-3, leg_y), Vector2(-8, leg_y + 4 + bob), Color(0.08, 0.22, 0.08), 1.0)
		draw_line(Vector2(3, leg_y), Vector2(8, leg_y + 4 - bob), Color(0.08, 0.22, 0.08), 1.0)

func _draw_mosquito(s: int):
	var t = mosquito_wing_phase
	# Wings — 2 lines per side (fast flap)
	var wa = sin(t) * 5.0
	draw_line(Vector2(0, -11), Vector2(-11, -16 + wa), Color(0.5, 0.85, 0.5, 0.45), 1.0)
	draw_line(Vector2(0, -11), Vector2(11, -16 + wa), Color(0.5, 0.85, 0.5, 0.45), 1.0)
	# Thorax
	draw_circle(Vector2(0, -10), 3.5, Color(0.10, 0.22, 0.10))
	# Abdomen stripe
	draw_line(Vector2(0, -7), Vector2(-s * 4, 1), Color(0.12, 0.28, 0.12), 3.5)
	draw_line(Vector2(-s * 1, -4), Vector2(-s * 3, -2), Color(0.7, 0.85, 0.2, 0.7), 1.0)
	# Head + proboscis
	draw_circle(Vector2(s * 3, -13), 3.0, Color(0.10, 0.20, 0.10))
	draw_circle(Vector2(s * 4, -14), 1.3, Color(0.8, 0.1, 0.1, 0.9))
	draw_line(Vector2(s * 4, -11), Vector2(s * 9, -9), Color(0.5, 0.7, 0.2), 1.2)
	# Poison glow when biting
	if is_attacking_melee:
		draw_circle(Vector2(s * 9, -9), 3.5, Color(0.2, 0.9, 0.2, 0.45))

func _draw_zombie(s: int):
	var t = zombie_anim_phase
	var wt = zombie_worm_phase
	# Body
	draw_rect(Rect2(-5, -20, 10, 20), Color(0.22, 0.30, 0.18))
	draw_rect(Rect2(-4, -17, 8, 8), Color(0.28, 0.38, 0.22))
	# Torn rags
	draw_line(Vector2(-5, -12), Vector2(-7, -6), Color(0.35, 0.28, 0.18, 0.7), 1.5)
	# Head
	draw_circle(Vector2(0, -26), 6.0, Color(0.24, 0.32, 0.18))
	draw_circle(Vector2(-2, -27), 2.0, Color(0.02, 0.04, 0.02))
	draw_circle(Vector2(2, -27), 2.0, Color(0.02, 0.04, 0.02))
	draw_circle(Vector2(-2, -27), 0.9, Color(0.9, 0.85, 0.3, 0.6))
	draw_circle(Vector2(2, -27), 0.9, Color(0.9, 0.85, 0.3, 0.6))
	draw_rect(Rect2(-3, -22, 6, 2), Color(0.18, 0.10, 0.08))
	# Arms — animate with pre-computed offset stored in anim phase
	var arm_swing = sin(t) * 2.5
	draw_line(Vector2(-5, -16), Vector2(-13, -14 + arm_swing), Color(0.22, 0.30, 0.18), 3.0)
	draw_line(Vector2(5, -16), Vector2(13, -14 - arm_swing), Color(0.22, 0.30, 0.18), 3.0)
	# 2 worms (not 4 — cuts sin/cos calls in half)
	for wi in 2:
		var wx = sin(wt + wi * 2.2) * 3.5 + (wi - 1) * 4.0
		var wy = -4 - wi * 3
		draw_circle(Vector2(wx, wy), 1.5, Color(0.7, 0.85, 0.3, 0.7))
		draw_line(Vector2(wx, wy), Vector2(wx + 2, wy - 3), Color(0.6, 0.75, 0.25, 0.55), 0.8)

# ────────────────────────────────────────────────────────────
#  LOCATION 3 ENEMIES
# ────────────────────────────────────────────────────────────

func _heretic_attack():
	# Через общий Dead Cells-цикл; факельный бонус учитывается в _strike_melee.
	_melee_attack()

func _heretic_on_death():
	# Notify all living group members: enter 4-second rage
	for h in heretic_group:
		if is_instance_valid(h) and h != self:
			h.heretic_rage_timer = 4.0
			h.heretic_is_enraged = true

func _draw_knight(s: int):
	var t = Time.get_ticks_msec() * 0.001
	# === GREAVES & BOOTS ===
	draw_rect(Rect2(-4, -4, 3, 5), Color(0.42, 0.44, 0.52))
	draw_rect(Rect2(1,  -4, 3, 5), Color(0.42, 0.44, 0.52))
	draw_rect(Rect2(-5, -2, 3, 3), Color(0.35, 0.36, 0.44))  # boot left
	draw_rect(Rect2( 2, -2, 3, 3), Color(0.35, 0.36, 0.44))  # boot right
	# === PLATE BODY ===
	draw_rect(Rect2(-6, -18, 12, 15), Color(0.44, 0.46, 0.55))
	draw_rect(Rect2(-5, -17, 10,  7), Color(0.52, 0.54, 0.64))  # chest highlight
	# Breastplate ridge
	draw_line(Vector2(0, -18), Vector2(0, -5), Color(0.60, 0.62, 0.72), 1.0)
	# === PAULDRONS ===
	draw_rect(Rect2(-9, -19, 4, 5), Color(0.48, 0.50, 0.60))
	draw_rect(Rect2( 5, -19, 4, 5), Color(0.48, 0.50, 0.60))
	# === FULL HELM ===
	draw_rect(Rect2(-5, -28, 10, 11), Color(0.46, 0.48, 0.58))
	draw_rect(Rect2(-5, -28, 10,  3), Color(0.54, 0.56, 0.66))  # top ridge
	# Visor slit (T-shaped)
	draw_rect(Rect2(-4 + s, -24, 7, 1), Color(0.08, 0.08, 0.10))
	draw_rect(Rect2(s,      -26, 2, 4), Color(0.08, 0.08, 0.10))
	# Eyes glow: red while winding up, blue otherwise
	var eye_col = Color(1.0, 0.15, 0.05, 0.9) if knight_is_winding_up else Color(0.2, 0.4, 1.0, 0.6 + sin(t * 2.0) * 0.3)
	draw_circle(Vector2(-2, -24), 1.3, eye_col)
	draw_circle(Vector2( 2, -24), 1.3, eye_col)
	# === SHIELD (left arm) — raised when blocking, lowered on cooldown ===
	var sh_x = s * 8  # shield on facing side (front hand)
	if knight_block_active and not is_stunned:
		# Shield raised and forward
		draw_rect(Rect2(sh_x - 2, -22, 5, 18), Color(0.35, 0.18, 0.10))
		draw_rect(Rect2(sh_x - 1, -21, 3, 16), Color(0.45, 0.22, 0.12))
		draw_circle(Vector2(sh_x + 1, -14), 3, Color(0.65, 0.55, 0.20))   # boss
	else:
		# Shield lowered / on back
		draw_rect(Rect2(sh_x - 1, -14, 4, 12), Color(0.32, 0.16, 0.08, 0.7))
	# === GREATSWORD (right arm) ===
	var sw_x = s * 7
	if knight_is_winding_up:
		# Sword raised overhead — windup pose
		var prog = 1.0 - (knight_windup_timer / 1.7)
		var lift = lerp(-28.0, -38.0, prog)
		var tilt = lerp(0.0, -0.9 * s, prog)
		# Glow intensifies as windup nears completion
		var glow_a = prog * 0.8
		draw_circle(Vector2(sw_x, lift - 4), 8.0 * prog, Color(1.0, 0.3, 0.1, glow_a * 0.5))
		draw_line(Vector2(sw_x, -14), Vector2(sw_x + tilt * 10, lift), Color(0.78, 0.78, 0.84), 3.0)
		draw_line(Vector2(sw_x - 3, -14), Vector2(sw_x + 3, -14), Color(0.62, 0.50, 0.22), 2.5)  # guard
		# Blade edge glow
		draw_line(Vector2(sw_x, lift), Vector2(sw_x + tilt * 12, lift - 4), Color(1.0, 0.9, 0.7, glow_a), 1.5)
	elif is_attacking_melee:
		# Downswing
		var swing = (1.0 - (melee_anim_timer / 0.3))
		var angle = lerp(-1.4, 0.8, swing) * s
		var tip = Vector2(sw_x, -14) + Vector2(cos(angle) * 28, sin(angle) * 14)
		draw_line(Vector2(sw_x, -14), tip, Color(0.78, 0.78, 0.84), 3.0)
		draw_line(Vector2(sw_x - 3, -14), Vector2(sw_x + 3, -14), Color(0.62, 0.50, 0.22), 2.5)
	else:
		# Idle — sword held at side
		draw_line(Vector2(sw_x, -4), Vector2(sw_x + s * 2, -24), Color(0.72, 0.72, 0.80), 3.0)
		draw_line(Vector2(sw_x - 3, -8), Vector2(sw_x + 3, -8), Color(0.62, 0.50, 0.22), 2.5)

func _draw_heretic(s: int):
	var t = heretic_torch_phase
	# Enrage: body flickers orange-red
	var rage_tint = Color(1.0, 0.45, 0.1, 0.30) if heretic_is_enraged else Color(0, 0, 0, 0)
	# === ROBE ===
	var robe_col = Color(0.38, 0.28, 0.18)
	draw_rect(Rect2(-5, -22, 10, 22), robe_col)
	draw_rect(Rect2(-4, -20,  8,  9), Color(0.46, 0.34, 0.22))
	if heretic_is_enraged:
		draw_rect(Rect2(-5, -22, 10, 22), rage_tint)
	# Torn hem
	draw_line(Vector2(-5, 0), Vector2(-7, -4), robe_col, 1.5)
	draw_line(Vector2( 0, 0), Vector2( 1, -3), robe_col, 1.2)
	draw_line(Vector2( 5, 0), Vector2( 7, -4), robe_col, 1.5)
	# === HOOD ===
	draw_circle(Vector2(0, -27), 6.5, Color(0.32, 0.22, 0.14))
	draw_circle(Vector2(0, -26), 4.5, Color(0.12, 0.08, 0.06))  # shadow under hood
	# Eyes — orange, brighter when enraged
	var eye_g = 0.8 + sin(t * 1.5) * 0.2
	var eye_r = 1.0 if heretic_is_enraged else 0.8
	draw_circle(Vector2(-2 * s, -27), 1.6, Color(eye_r, 0.40 * eye_g, 0.02, eye_g))
	draw_circle(Vector2( 2 * s, -27), 1.6, Color(eye_r, 0.40 * eye_g, 0.02, eye_g))
	# === PITCHFORK (right hand, s direction) ===
	var px = s * 7
	if is_attacking_melee:
		var swing = 1.0 - (melee_anim_timer / 0.3)
		var thrust = lerp(float(s * 7), float(s * 18), swing)
		draw_line(Vector2(s * 4, -14), Vector2(thrust, -14), Color(0.48, 0.32, 0.12), 2.0)
		# Three tines
		for ti in 3:
			var ty = -17 + ti * 3
			draw_line(Vector2(thrust, ty), Vector2(thrust + s * 4, ty - 2), Color(0.68, 0.60, 0.50), 1.5)
	else:
		draw_line(Vector2(s * 4, -6), Vector2(px, -22), Color(0.48, 0.32, 0.12), 2.0)
		for ti in 3:
			var ty = -22 + ti * 3
			draw_line(Vector2(px, ty), Vector2(px + s * 3, ty - 3), Color(0.68, 0.60, 0.50), 1.5)
	# === TORCH (left hand) ===
	var tx = -s * 7
	draw_line(Vector2(-s * 4, -12), Vector2(tx, -22), Color(0.42, 0.30, 0.14), 2.0)
	draw_rect(Rect2(tx - 2, -26, 4, 5), Color(0.38, 0.25, 0.12))  # torch head
	# Flame flicker — 3 layers
	var flicker = sin(t * 3.7) * 2.0
	draw_circle(Vector2(tx, -28 + flicker * 0.3), 3.5, Color(1.0, 0.55, 0.05, 0.80))
	draw_circle(Vector2(tx + sin(t * 5) * 1.2, -31 + flicker * 0.5), 2.2, Color(1.0, 0.80, 0.10, 0.70))
	draw_circle(Vector2(tx, -33 + flicker),                           1.2, Color(1.0, 1.00, 0.60, 0.50))

func _draw_brute(s: int):
	# Тяжёлый громила: крупный, мускулистый, с огромными кулаками. Во время
	# замаха (telegraph) светится красным — видно, что сейчас прилетит.
	var winding := telegraph_timer > 0.0
	var skin := Color(0.40, 0.30, 0.32) if not winding else Color(0.55, 0.28, 0.26)
	var dark := Color(0.26, 0.19, 0.21)
	# Ноги
	draw_rect(Rect2(-7, -7, 5, 7), dark)
	draw_rect(Rect2(2, -7, 5, 7), dark)
	# Массивный торс
	draw_rect(Rect2(-11, -30, 22, 24), skin)
	draw_rect(Rect2(-9, -29, 18, 8), Color(skin.r + 0.08, skin.g + 0.06, skin.b + 0.06))
	# Плечи-горы
	draw_rect(Rect2(-15, -30, 6, 9), skin)
	draw_rect(Rect2(9, -30, 6, 9), skin)
	# Маленькая голова, вжатая в плечи
	draw_rect(Rect2(-5, -38, 10, 9), Color(skin.r + 0.05, skin.g + 0.03, skin.b + 0.03))
	# Злые глаза
	var eye := Color(1.0, 0.85, 0.2, 0.95) if not winding else Color(1.0, 0.2, 0.1, 1.0)
	draw_circle(Vector2(-2.5, -34), 1.4, eye)
	draw_circle(Vector2(2.5, -34), 1.4, eye)
	# Огромный кулак на стороне взгляда (заносится при замахе)
	var fist_x := s * 15.0
	var fist_y := -20.0 - (8.0 if winding else 0.0)
	draw_rect(Rect2(fist_x - 5, fist_y - 5, 10, 10), dark)
	draw_rect(Rect2(fist_x - 4, fist_y - 4, 8, 4), skin)
	# Связка кулака с телом
	draw_line(Vector2(s * 9, -24), Vector2(fist_x, fist_y), skin, 4.0)

func _draw_dog(s: int):
	var t = dog_leg_phase
	var enr = dog_is_enraged
	# Body color: tawny brown, darker when enraged
	var body_col  = Color(0.50, 0.36, 0.22) if not enr else Color(0.60, 0.22, 0.12)
	var body_dark = Color(0.38, 0.26, 0.16) if not enr else Color(0.45, 0.16, 0.08)
	# === BODY (low, horizontal oval) ===
	draw_circle(Vector2(-s * 2, -9),  7.5, body_dark)
	draw_circle(Vector2(-s * 2, -9),  5.5, body_col)
	# === NECK & HEAD ===
	draw_circle(Vector2(s * 4, -13), 4.5, body_col)
	# Snout
	draw_circle(Vector2(s * 7, -12), 3.2, body_dark)
	draw_circle(Vector2(s * 9, -11), 1.8, Color(0.22, 0.12, 0.10))  # nose tip
	# Ears (pointy)
	var ear_points_l = PackedVector2Array([Vector2(s * 2, -17), Vector2(s * 0, -24), Vector2(s * 4, -18)])
	var ear_points_r = PackedVector2Array([Vector2(s * 4, -17), Vector2(s * 5, -23), Vector2(s * 6, -17)])
	draw_colored_polygon(ear_points_l, body_col)
	draw_colored_polygon(ear_points_r, body_col)
	# Eyes — red when enraged, amber otherwise
	var eye_col = Color(1.0, 0.10, 0.05) if enr else Color(0.9, 0.60, 0.10)
	draw_circle(Vector2(s * 6, -14), 1.6, eye_col)
	draw_circle(Vector2(s * 6, -14), 0.7, Color(0.02, 0.02, 0.02))
	# Teeth when attacking
	if is_attacking_melee or (telegraph_timer > 0):
		draw_rect(Rect2(s * 7, -13, 2, 1), Color(0.95, 0.95, 0.9))
		draw_rect(Rect2(s * 9, -13, 2, 1), Color(0.95, 0.95, 0.9))
	# === TAIL ===
	var tail_wag = sin(t * 0.7) * 4.0
	var tail_x = -s * 8
	draw_line(Vector2(-s * 7, -10), Vector2(tail_x, -14 + tail_wag), body_col, 2.0)
	draw_line(Vector2(tail_x, -14 + tail_wag), Vector2(tail_x - s * 3, -18 + tail_wag), body_col, 1.5)
	# === 4 LEGS (alternating pairs) ===
	var lob_f = sin(t) * 3.5          # front pair bob
	var lob_b = sin(t + PI) * 3.5     # back pair (opposite phase)
	# Front legs
	draw_line(Vector2(s * 3, -5), Vector2(s * 4 + 1, 1 + lob_f), body_dark, 2.0)
	draw_line(Vector2(s * 2, -5), Vector2(s * 1 - 1, 1 - lob_f), body_dark, 2.0)
	# Back legs
	draw_line(Vector2(-s * 4, -5), Vector2(-s * 5 + 1, 1 + lob_b), body_dark, 2.0)
	draw_line(Vector2(-s * 5, -5), Vector2(-s * 4 - 1, 1 - lob_b), body_dark, 2.0)
	# Enrage glow aura
	if enr:
		draw_circle(Vector2(0, -9), 13.0, Color(1.0, 0.15, 0.05, 0.12))
