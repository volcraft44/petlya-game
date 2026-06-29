extends CharacterBody2D

signal health_changed(new_health)
signal died
signal screen_shake(intensity: float, duration: float)
signal jumped
signal landed
signal attacked
# CS-фичи
signal killstreak_changed(streak: int)         # эмитится когда стрик растёт (1, 2, 3...)
signal killstreak_reset                         # эмитится при получении урона
signal headshot_landed(world_pos: Vector2)     # хедшот по врагу
signal inspect_requested(weapon_data: Dictionary)  # запрос показа инспекта
signal bhop_perfect(stacks: int, world_pos: Vector2)  # успешный bhop
signal dash_used(remaining_charges: int)              # дашнули
signal footstep                                        # шаг (для звука)
signal weapon_picked(rarity: String)                   # подобрал оружие

@export var speed: float = 130.0
@export var jump_force: float = -360.0
@export var max_health: int = 100
@export var attack_damage: int = 20
@export var attack_cooldown: float = 0.22

var health: int
var gravity: float = 980.0
var facing_right: bool = true
var is_attacking: bool = false
var is_shielding: bool = false
var can_attack: bool = true
var attack_timer: float = 0.0
var attack_anim_timer: float = 0.0
var invincible: bool = false
var invincible_timer: float = 0.0
var is_dead: bool = false

# Knocked-out by mimic hit — plays lying-down → get-up animation
var is_knocked_out: bool = false
var knockdown_timer: float = 0.0   # counts from knockdown_duration → 0

# Coyote time — can jump briefly after walking off edge
var coyote_timer: float = 0.0
var coyote_time: float = 0.10
var was_on_floor: bool = false

# Переменная высота прыжка (Hollow Knight): держишь пробел — высокий прыжок,
# отпустил рано на взлёте — подъём обрезается → низкий прыжок.
var is_jump_rising: bool = false
const JUMP_CUT_VELOCITY := -120.0

# Hollow Knight: при касании шипов в паркур-ямах — небольшой урон и возврат
# на последнюю безопасную точку (где стоял), а не смерть.
var last_safe_pos: Vector2 = Vector2.ZERO
var _safe_pos_cd: float = 0.0

# Hit-stop — freeze for a few frames when landing a hit
var hit_stop_timer: float = 0.0

# Landing squash — squish sprite on landing
var land_squash_timer: float = 0.0

# Screen shake
var shake_intensity: float = 0.0
var shake_timer: float = 0.0

# Jump buffer — pressed jump slightly before landing
var jump_buffer_timer: float = 0.0
var jump_buffer_time: float = 0.12

# Acceleration / deceleration for snappy movement
var velocity_x_target: float = 0.0

# Dodge roll
var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_duration: float = 0.3
var roll_speed: float = 220.0
var roll_cooldown_timer: float = 0.0
var roll_cooldown: float = 0.5
var roll_direction: float = 0.0
var roll_extend: float = 0.0   # продление кувырка пока негде встать (низкий потолок)
var normal_collision_mask: int = 0

# Swing combo
var swing_index: int = 0
var combo_reset_timer: float = 0.0
var combo_reset_time: float = 0.5

# Attack direction: 0 = horizontal, 1 = up, -1 = down
var attack_direction: int = 0

# Ledge grab
var is_grabbing_ledge: bool = false
var ledge_target_y: float = 0.0
var climb_timer: float = 0.0
var climb_duration: float = 0.25

# Wall slide / wall jump
var is_wall_sliding: bool = false
var wall_slide_speed: float = 40.0
var wall_jump_force: Vector2 = Vector2(180, -280)
var wall_dir: int = 0  # -1 left wall, 1 right wall, 0 none
var wall_jump_cooldown: float = 0.0

# Ladder climbing
var is_on_vine: bool = false
var vine_climb_speed: float = 80.0

# Drop through one-way platforms
var drop_through_timer: float = 0.0

# Stun (from boss mega strike)
var is_stunned: bool = false
var stun_timer: float = 0.0

# Heal ability (H key)
var heal_charges: int = 3
var max_heal_charges: int = 3
var heal_amount: int = 20
# Питьё зелья: персонаж стоит и не атакует, ХП пополняется ПОСТЕПЕННО.
var is_drinking: bool = false
var drink_timer: float = 0.0
var drink_heal_amount: int = 0
var drink_given: int = 0          # сколько HP уже влито за это питьё
const DRINK_TIME := 1.4           # пьётся быстрее

# Blade upgrade (from chests)
var has_blade: bool = false

# Lockpick item (crafted from ore)
var has_lockpick: bool = false

# Pickaxe (drops from special mob)
var has_pickaxe: bool = false
var using_pickaxe: bool = false  # Q to switch weapon

# Ore mining (отмычка теперь крафтится бесплатно у наковальни — поле оставлено для совместимости)
var ore_mined: int = 0
var ore_needed: int = 0

# New resource system
var iron_ore: int = 0
var gold_ore: int = 0
var iron_ingot: int = 0
var gold_ingot: int = 0
var has_pearl: bool = false

# Amulet (heals 1 HP every 10s)
var has_amulet: bool = false
var amulet_timer: float = 0.0
var amulet_heal_interval: float = 10.0

# Flask (from grate, heals 20 HP on F)
var has_flask: bool = false
var flask_charges: int = 0

# Sword tier: 0=normal, 1=blade, 2=merged
var sword_tier: int = 0

var blade_cooldown: float = 0.12  # faster than normal 0.22

# === WEAPON SYSTEM ===
# 0=fists (no weapon), 1=sword (default, from wall), 2=long_sword, 3=dual_blades,
# 4=hammer, 5=vampire_blades, 6=golden_hammer, 7=knife
var current_weapon: int = 0
var has_wall_sword: bool = false  # pulled sword from wall on level 1

# Weapon stats: {name, damage, cooldown, range, blade_len, color, description}
var weapon_data: Dictionary = {
	0: {"name": "Кулаки", "damage": 5, "cooldown": 0.3, "range": 15, "blade_len": 8, "speed_mult": 1.0,
		"color": Color(0.9, 0.8, 0.7), "glow": Color(1,1,1,0), "heal_on_kill": false, "rarity": "common"},
	1: {"name": "Меч", "damage": 20, "cooldown": 0.22, "range": 22, "blade_len": 22, "speed_mult": 1.0,
		"color": Color(0.85, 0.85, 0.92), "glow": Color(1,1,1,0.15), "heal_on_kill": false, "rarity": "common"},
	2: {"name": "Длинный Меч", "damage": 35, "cooldown": 0.4, "range": 35, "blade_len": 32, "speed_mult": 0.85,
		"color": Color(0.7, 0.75, 0.85), "glow": Color(0.5,0.6,0.8,0.2), "heal_on_kill": false, "rarity": "uncommon"},
	3: {"name": "Клинки", "damage": 12, "cooldown": 0.1, "range": 20, "blade_len": 18, "speed_mult": 1.15,
		"color": Color(0.4, 0.85, 1.0), "glow": Color(0.3,0.7,1,0.3), "heal_on_kill": false, "rarity": "uncommon"},
	4: {"name": "Молот", "damage": 50, "cooldown": 0.55, "range": 28, "blade_len": 20, "speed_mult": 0.7,
		"color": Color(0.55, 0.55, 0.6), "glow": Color(0.8,0.6,0.3,0.2), "heal_on_kill": false, "rarity": "rare"},
	5: {"name": "Клинки Вампира", "damage": 15, "cooldown": 0.12, "range": 22, "blade_len": 20, "speed_mult": 1.1,
		"color": Color(0.9, 0.15, 0.2), "glow": Color(1,0.1,0.2,0.4), "heal_on_kill": true, "rarity": "legendary"},
	6: {"name": "Золотой Молот", "damage": 70, "cooldown": 0.5, "range": 30, "blade_len": 22, "speed_mult": 0.75,
		"color": Color(1.0, 0.85, 0.2), "glow": Color(1,0.9,0.3,0.4), "heal_on_kill": false, "rarity": "legendary"},
	7: {"name": "Нож", "damage": 65, "cooldown": 0.18, "range": 14, "blade_len": 12, "speed_mult": 1.2,
		"color": Color(0.8, 0.8, 0.85), "glow": Color(1,1,1,0.1), "heal_on_kill": false, "rarity": "rare"},
	8: {"name": "Искажённый Лук", "damage": 25, "cooldown": 0.8, "range": 180, "blade_len": 16, "speed_mult": 0.9,
		"color": Color(0.4, 0.1, 0.6), "glow": Color(0.6,0.2,0.9,0.3), "heal_on_kill": false, "rarity": "rare",
		"special": "warp_arrow"},  # Shoots forward + behind target
	9: {"name": "Когтистая Рука", "damage": 18, "cooldown": 0.5, "range": 40, "blade_len": 18, "speed_mult": 1.0,
		"color": Color(0.6, 0.15, 0.1), "glow": Color(0.8,0.2,0.1,0.3), "heal_on_kill": false, "rarity": "rare",
		"special": "grab_throw"},  # Grabs and throws enemy
	10: {"name": "Рука Змея", "damage": 8, "cooldown": 0.6, "range": 35, "blade_len": 20, "speed_mult": 1.0,
		"color": Color(0.2, 0.7, 0.15), "glow": Color(0.1,0.8,0.2,0.3), "heal_on_kill": false, "rarity": "legendary",
		"special": "constrict"},  # Wraps enemy, DOT for 4s, max 3 targets
	11: {"name": "Тетрадь Смерти", "damage": 0, "cooldown": 2.0, "range": 120, "blade_len": 10, "speed_mult": 1.0,
		"color": Color(0.1, 0.1, 0.1), "glow": Color(0.3,0.0,0.0,0.5), "heal_on_kill": false, "rarity": "epic",
		"special": "death_note"},  # Marks enemy, dies in 40s
	12: {"name": "Книга Некроманта", "damage": 15, "cooldown": 0.7, "range": 150, "blade_len": 12, "speed_mult": 0.9,
		"color": Color(0.3, 0.0, 0.4), "glow": Color(0.5,0.1,0.7,0.4), "heal_on_kill": false, "rarity": "legendary",
		"special": "necro_souls"},  # Shoots souls, +1 per kill
	13: {"name": "Топор", "damage": 40, "cooldown": 0.45, "range": 25, "blade_len": 20, "speed_mult": 0.85,
		"color": Color(0.5, 0.5, 0.55), "glow": Color(0.7,0.4,0.2,0.2), "heal_on_kill": false, "rarity": "uncommon",
		"special": "combo_execute"},  # 3rd hit = instant kill (not bosses)
	14: {"name": "Цепь", "damage": 20, "cooldown": 1.0, "range": 60, "blade_len": 30, "speed_mult": 0.9,
		"color": Color(0.5, 0.5, 0.5), "glow": Color(0.6,0.6,0.6,0.2), "heal_on_kill": false, "rarity": "epic",
		"special": "chain_pull"},  # Pulls enemy to you, then strangles
	15: {"name": "Якорь", "damage": 80, "cooldown": 1.3, "range": 35, "blade_len": 24, "speed_mult": 0.6,
		"color": Color(0.35, 0.35, 0.4), "glow": Color(0.4,0.4,0.5,0.2), "heal_on_kill": false, "rarity": "rare",
		"special": "aoe_slam"},  # Slow but AOE, 2-hit kill
	16: {"name": "Тройной Лук", "damage": 18, "cooldown": 0.6, "range": 160, "blade_len": 14, "speed_mult": 0.95,
		"color": Color(0.6, 0.5, 0.2), "glow": Color(0.8,0.7,0.3,0.2), "heal_on_kill": false, "rarity": "uncommon",
		"special": "triple_arrow"},  # 3 arrows in spread
	17: {"name": "Моргенштерн", "damage": 55, "cooldown": 1.0, "range": 40, "blade_len": 28, "speed_mult": 0.7,
		"color": Color(0.4, 0.4, 0.45), "glow": Color(0.6,0.3,0.1,0.3), "heal_on_kill": false, "rarity": "rare",
		"special": "spin_attack"},  # Spin for 4s, hit everything around
	18: {"name": "Дротики", "damage": 12, "cooldown": 0.3, "range": 100, "blade_len": 10, "speed_mult": 1.1,
		"color": Color(0.6, 0.6, 0.6), "glow": Color(0.7,0.7,0.7,0.1), "heal_on_kill": false, "rarity": "uncommon",
		"special": "dart_throw"},  # Fast ranged, 6 hits to kill
	19: {"name": "Копьё", "damage": 45, "cooldown": 0.6, "range": 32, "blade_len": 30, "speed_mult": 0.9,
		"color": Color(0.55, 0.5, 0.4), "glow": Color(0.7,0.6,0.4,0.2), "heal_on_kill": false, "rarity": "uncommon",
		"special": "spear_thrust"},  # 3 thrusts to kill, RMB = lunge
	20: {"name": "Меч и Щит", "damage": 30, "cooldown": 0.35, "range": 24, "blade_len": 22, "speed_mult": 0.95,
		"color": Color(0.9, 0.85, 0.5), "glow": Color(1,0.9,0.4,0.5), "heal_on_kill": false, "rarity": "legendary",
		"special": "sword_shield_combo"},  # 1-sword, 2-sword, 3-shield bash (blocks + kills ~3 combos)
	21: {"name": "Золотая Палка", "damage": 7, "cooldown": 0.3, "range": 28, "blade_len": 26, "speed_mult": 1.0,
		"color": Color(1.0, 0.9, 0.3), "glow": Color(1,0.95,0.5,0.5), "heal_on_kill": false, "rarity": "legendary",
		"special": "golden_staff_combo"},  # 1-hit, 2-hit, 3-spin AOE + reflect (4s)
	22: {"name": "Факел", "damage": 5, "cooldown": 0.4, "range": 20, "blade_len": 16, "speed_mult": 1.0,
		"color": Color(1.0, 0.6, 0.1), "glow": Color(1,0.5,0.1,0.5), "heal_on_kill": false, "rarity": "legendary",
		"special": "fire_dot"},  # 4 hits (20dmg) + fire DOT helps kill in ~3 hits
	23: {"name": "AWP Петли", "damage": 9999, "cooldown": 1.8, "range": 600, "blade_len": 28, "speed_mult": 0.65,
		"color": Color(0.20, 0.20, 0.25), "glow": Color(0.95, 0.10, 0.10, 0.55), "heal_on_kill": false,
		"rarity": "contraband", "special": "sniper"},  # ПКМ — scope, ЛКМ — one-shot kill (кроме боссов)
}
var weapon_pickup_msg: String = ""
var weapon_msg_timer: float = 0.0

# Special weapon state
var necro_souls: int = 1  # Necromancer book soul count
var _last_enemy_count: int = -1  # Track enemy deaths for necro book
var dart_stacks: int = 0  # Dart kill stacks: +speed, +range per kill (max 10)
var grab_target: CharacterBody2D = null  # Claw grab target
var grab_timer: float = 0.0  # 3s squeeze
var axe_combo: int = 0    # Axe combo counter
var chain_target: CharacterBody2D = null  # Chain pull target
var chain_timer: float = 0.0
var chain_anim: float = 0.0  # таймер анимации броска/натяжения цепи
var spin_active: bool = false  # Morningstar spin
var spin_timer: float = 0.0
var constrict_targets: Array = []  # Snake hand targets
var death_note_targets: Array = []  # {enemy, timer, name}
# --- Запись имён Тетрадью Смерти ---
var dn_writing: bool = false
var dn_queue: Array = []            # враги в очереди на запись
var dn_write_cd: float = 0.0
const DN_WRITE_INTERVAL := 0.18     # секунд на одно имя (не долго)
const DN_RADIUS := 160.0            # ~10 блоков (tile 16)
const DN_DEATH_TIME := 6.0          # через сколько умирает записанный
const DN_NAMES := ["Райто", "Эл", "Миса", "Кира", "Рюк", "Рем", "Соитиро",
	"Найт", "Мелло", "Матт", "Ниа", "Така", "Сайу", "Аидзава", "Моги",
	"Укита", "Мацуда", "Идэ", "Ватари", "Хигучи"]

func _dn_already(e) -> bool:
	for dt in death_note_targets:
		if dt.enemy == e:
			return true
	return false

func _start_death_note_writing():
	if dn_writing:
		return
	var room = _find_room()
	if room == null:
		return
	dn_queue.clear()
	# Все враги в радиусе
	for e in room.enemies:
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= DN_RADIUS:
			if not _dn_already(e):
				dn_queue.append(e)
	# Босс комнаты (отдельная нода) — тоже в радиусе
	if "golem_boss" in room and room.golem_boss != null and is_instance_valid(room.golem_boss):
		if room.golem_boss.has_method("take_damage") and \
			global_position.distance_to(room.golem_boss.global_position) <= DN_RADIUS:
			if not _dn_already(room.golem_boss):
				dn_queue.append(room.golem_boss)
	if dn_queue.is_empty():
		weapon_pickup_msg = "Нет целей рядом"
		weapon_msg_timer = 0.6
		return
	dn_writing = true
	dn_write_cd = DN_WRITE_INTERVAL
	can_attack = false
	attack_timer = 2.0   # кулдаун, чтобы не спамить
	weapon_pickup_msg = "ЗАПИСЬ..."
	weapon_msg_timer = 0.8

func _update_death_note_writing(delta: float):
	if not dn_writing:
		return
	velocity.x = 0.0   # игрок не двигается во время записи
	dn_write_cd -= delta
	if dn_write_cd > 0.0:
		return
	dn_write_cd = DN_WRITE_INTERVAL
	# Записываем следующего живого врага из очереди
	while not dn_queue.is_empty():
		var e = dn_queue.pop_front()
		if is_instance_valid(e):
			var nm: String = DN_NAMES[randi() % DN_NAMES.size()]
			death_note_targets.append({"enemy": e, "timer": DN_DEATH_TIME, "name": nm})
			if "death_note_timer_display" in e:
				e.death_note_timer_display = DN_DEATH_TIME
			if "death_note_name" in e:
				e.death_note_name = nm
			weapon_pickup_msg = "delete: " + nm
			weapon_msg_timer = 0.7
			break
	if dn_queue.is_empty():
		dn_writing = false
var spear_lunge: bool = false
var spear_lunge_timer: float = 0.0
var staff_spin_timer: float = 0.0  # Golden staff 4s spin reflect
var shield_bash_timer: float = 0.0  # Sword&Shield 3rd hit block

# Ground slam (double-tap S in air)
var ground_slam: bool = false
var slam_tap_timer: float = 0.0  # Time window for double-tap
var slam_first_tap: bool = false

# Fire DOT targets (torch weapon)
var fire_targets: Array = []  # {enemy, timer, tick}

# Weapon mutations (gained every 3 levels)
var weapon_mutations: Array = []
var mutation_has_lifesteal: bool = false
var mutation_has_chain: bool = false

# === CARD SYSTEM ===
# Cards chosen at start of each run, affects gameplay
var active_card: String = ""  # "", "invisibility", "death_jar", "throw_weapon", "speed_boots", "dodge"
# Invisibility: not detected by non-boss enemies unless near torch
var is_invisible: bool = false
var invis_break_timer: float = 0.0  # Cooldown after combat before invisibility restores
# Death jar: collect poison, throw it
var death_jar_charges: int = 0
var death_jar_max: int = 3
# Throw weapon: can throw current weapon
var throw_weapon_cooldown: float = 0.0
# Speed boots: +50% speed, +5% damage taken, +30% jump
# Applied in _physics_process
# Dodge: 25% passive dodge chance (40% with dual blades)
# Applied in take_damage

# Poison DOT (from fly enemy or poison traps)
var poison_timer: float = 0.0
var poison_damage: float = 0.0
var poison_tick_timer: float = 0.0

# Worm infection (from Zombie Corpse)
var worm_count: int = 0        # stacks (max 3)
var worm_timer: float = 0.0    # total remaining duration
var worm_tick_timer: float = 0.0
var worm_phase: float = 0.0    # visual animation

# === SCROLL SYSTEM ===
# Scrolls drop from enemies (1 per 2 levels, max 2)
var scrolls: Array = []  # Array of scroll IDs: "dash", "kick", "speed_boost", "choke", "slide"
var max_scrolls: int = 2
var scroll_cooldowns: Dictionary = {}  # {scroll_id: remaining_cd}
# Active item slot: 0/1 = scroll slots, 2 = card ability
var active_item_slot: int = 0
# Scroll ability params
var scroll_dash_active: bool = false
var scroll_dash_timer: float = 0.0
var scroll_speed_active: bool = false
var scroll_speed_timer: float = 0.0
var scroll_choke_target: CharacterBody2D = null
var scroll_choke_timer: float = 0.0
var scroll_slide_active: bool = false
var scroll_slide_timer: float = 0.0

# === CRIT SYSTEM ===
var crit_chance: float = 0.10  # 10% base
var crit_multiplier: float = 1.5

# === CARD BONUSES ===
var card_backstab_bonus: float = 0.0  # +60% from behind
var card_acid_water: bool = false  # acid water heals
var card_thorn_reduction: float = 0.0  # thorns 80% less
var card_close_range_bonus: float = 0.0  # +40% close range
var card_low_hp_bonus: bool = false  # +0.5% per 1% lost HP
var card_kill_bonus: float = 0.0  # +0.2% per kill accumulated
var card_kill_count: int = 0
var card_crit_bonus_chance: float = 0.0  # +10%
var card_crit_bonus_damage: float = 0.0  # +20%
var card_second_chance: bool = false  # revive once
var card_second_chance_used: bool = false

# Net trap (from stealth enemy)
var is_netted: bool = false
var net_timer: float = 0.0

# Spider web trap + escape minigame
var is_webbed: bool = false
var web_timer: float = 0.0
var web_cursor: float = 0.0       # 0..1 position in bar
var web_cursor_dir: float = 1.0
var web_target_start: float = 0.35
var web_success_count: int = 0
const WEB_BAR_W: float = 120.0
const WEB_TARGET_W: float = 0.22   # 22% of bar width
const WEB_CURSOR_SPEED: float = 1.6 # bar widths per second

# === COINS & ECONOMY ===
var coins: int = 0
signal coins_changed(n: int)

# === CS FEATURES ===
# Киллстрик (UT-style). Растёт с каждым убийством, обнуляется при получении урона.
var killstreak: int = 0
# Урон, полученный в текущей комнате (для ACE)
var room_damage_taken: int = 0
# Inspect — Q после простоя 2 сек запускает анимацию
var inspect_idle_timer: float = 0.0
var is_inspecting: bool = false
var inspect_anim_timer: float = 0.0
const INSPECT_IDLE_THRESHOLD: float = 2.0
const INSPECT_DURATION: float = 2.4
# AWP-scope state
var is_scoping: bool = false
var scope_zoom_target: float = 1.8
# Гранаты убраны по просьбе игрока (стартовое значение 0 — нигде не выдаются).
var smoke_grenades: int = 0
var flash_grenades: int = 0
# Crosshair style (для дальнобойного оружия)
var crosshair_style: int = 2  # 0=arrow, 1=dot, 2=cross (default), 3=t-shape, 4=x

# === STYLE COMBO REWARDS ===
# Текущий ULTRAKILL-ранг (0=D ... 7=U). Обновляется из main.gd.
# Высокий ранг даёт пассивные бонусы — стимул держать стиль.
var style_rank: int = 0

# === RELICS ===
# Список ID собранных за забег реликвий — пассивные бонусы.
var relics: Array = []
var _thunder_hit_count: int = 0     # для Удара Грома
var _frost_hit_count: int = 0       # для Ледяного Удара
var _phoenix_used: bool = false      # перо феникса однократное

# === LEVEL MODIFIER ===
var level_modifier: String = ""      # активный мод на текущий уровень
var _blood_pact_tick: float = 0.0    # для Пакта Крови (−2 HP/сек)
var damage_mult: float = 1.0         # глобальный множитель урона от модов
var taken_damage_mult: float = 1.0   # множитель получаемого урона

# === Atmospheric sparks (всегда летают вокруг игрока) ===
var aura_sparks: Array = []   # [{offset, vy, life, max_life, color}]
var _spark_cd: float = 0.0

# === Game-feel particles (пыль приземления, шаги) ===
var feel_particles: Array = []   # [{pos, vel, life, max_life, size, color}]
var _footstep_cd: float = 0.0
var _last_landing_vy: float = 0.0

# === Acid trail (психоделические призраки) ===
var _acid_trail: Array = []   # [{pos: Vector2 (мировая), life, vel_dir}]
var _acid_cd: float = 0.0

# === BHOP (Perfect-timed jump combo) ===
# CS-стандарт окно 0.10 сек. Каждый прыжок в окне = +15% скорости, до 2x.
const BHOP_WINDOW: float = 0.25     # окно после приземления чтобы поймать bhop
const BHOP_GROUND_TOLERANCE: float = 0.35  # если стоишь на полу дольше — комбо сбросится
const BHOP_STEP: float = 0.15       # +15% за стэк
const BHOP_MAX_STACKS: int = 6      # 6 * 15% = +90% (до ~1.9x)
var bhop_stacks: int = 0
var bhop_window_t: float = 0.0      # активное окно ловли
var bhop_ground_t: float = 0.0      # время на полу (для сброса)
var bhop_was_on_floor: bool = false
var bhop_perfect_flash_t: float = 0.0   # вспышка "PERFECT"
var bhop_trail: Array = []          # [{pos, life, max_life, alpha_mult}]
const BHOP_TRAIL_LIFE: float = 0.5
# Anti-spam: два условия, оба обязательны для PERFECT BHOP:
# 1) Space должен быть ОТПУЩЕН между прыжками (нельзя зажать)
# 2) Между двумя прыжками должен пройти MIN_INTERVAL сек (нельзя спам-мэшить)
var bhop_space_released: bool = true
var bhop_time_since_jump: float = 999.0   # время с последнего прыжка
var bhop_pressed_grounded: bool = false   # прыжок нажат стоя на земле в окне
const BHOP_MIN_INTERVAL: float = 0.30    # минимум сек между бhop'ами

# === DASH (ULTRAKILL-style charges) ===
const DASH_MAX_CHARGES: int = 2
const DASH_RECHARGE_TIME: float = 1.5
# Дэш в духе Celeste: чёткий рывок ~4 тайла, не длинный полёт и не микро-рывок.
const DASH_DURATION: float = 0.15
const DASH_SPEED: float = 440.0
var dash_charges: float = 3.0       # дробное, чтобы плавно копилось
var dash_active: bool = false
var dash_timer: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var dash_invuln: bool = false

# === CHARACTER LEVELING ===
var xp: int = 0
var xp_needed: int = 60
var char_level: int = 1
signal leveled_up(choices: Array)

# === PARRY ===
var parry_window: float = 0.0
var parry_window_duration: float = 0.22
var parry_flash_timer: float = 0.0

# === KILL COMBO ===
var combo_kill_count: int = 0
var combo_kill_timer: float = 0.0
var combo_kill_timer_max: float = 3.5

# === SWORD TRAIL ===
var sword_trail: Array = []

# Dust particles when running / landing
var dust_timer: float = 0.0
var dust_particles: Array = []  # [{pos, vel, life, size}]

# Roll trail ghost silhouettes
var roll_trail: Array = []  # [{pos, facing, life}]

# Damage flash (red vignette)
var damage_flash_timer: float = 0.0

var attack_area: Area2D
var attack_shape: CollisionShape2D
var body_collision: CollisionShape2D

func _ready():
	health = max_health
	normal_collision_mask = 4 | 8 | 32  # walls + doors + one-way platforms

	# Прощающий хитбокс: ~70% от спрайта (спрайт ~10x22). Уже и ниже самого
	# персонажа, ступни остаются на уровне пола — в спорных касаниях игра за
	# игрока (меньше незаслуженных задеваний, легче пролезать в щели).
	body_collision = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(7, 16)            # 70% ширины, ~73% высоты спрайта
	body_collision.shape = rect
	body_collision.position = Vector2(0, -8)   # низ хитбокса = ступни (y=0)
	add_child(body_collision)

	attack_area = Area2D.new()
	attack_area.collision_layer = 16
	attack_area.collision_mask = 2
	attack_area.monitoring = true
	attack_area.monitorable = true
	add_child(attack_area)

	attack_shape = CollisionShape2D.new()
	var attack_rect = RectangleShape2D.new()
	attack_rect.size = Vector2(22, 18)
	attack_shape.shape = attack_rect
	attack_shape.position = Vector2(15, -11)
	attack_shape.disabled = true
	attack_area.add_child(attack_shape)

	attack_area.body_entered.connect(_on_attack_hit)

	collision_layer = 1
	collision_mask = normal_collision_mask

func _process(delta):
	if is_dead:
		return

	# Scroll cooldowns
	for sid in scroll_cooldowns:
		if scroll_cooldowns[sid] > 0:
			scroll_cooldowns[sid] -= delta

	# Scroll active effects
	if scroll_dash_active:
		scroll_dash_timer -= delta
		if scroll_dash_timer <= 0:
			scroll_dash_active = false

	if scroll_speed_active:
		scroll_speed_timer -= delta
		if scroll_speed_timer <= 0:
			scroll_speed_active = false

	if scroll_choke_target and is_instance_valid(scroll_choke_target):
		scroll_choke_timer -= delta
		scroll_choke_target.global_position = global_position + Vector2((-1 if facing_right else 1) * 8, 0)
		scroll_choke_target.velocity = Vector2.ZERO
		if scroll_choke_timer <= 0:
			scroll_choke_target.take_damage(99999, Vector2.ZERO)
			scroll_choke_target = null
	elif scroll_choke_target:
		scroll_choke_target = null

	if scroll_slide_active:
		scroll_slide_timer -= delta
		if scroll_slide_timer <= 0:
			scroll_slide_active = false
			body_collision.shape.size = Vector2(7, 16)
			body_collision.position = Vector2(0, -8)

	if weapon_msg_timer > 0:
		weapon_msg_timer -= delta

	# Track enemy deaths for necro book + dart stacks
	if current_weapon == 12 or current_weapon == 18:
		var track_room = _find_room()
		if track_room:
			var alive = 0
			for e in track_room.enemies:
				if is_instance_valid(e):
					alive += 1
			if _last_enemy_count >= 0 and alive < _last_enemy_count:
				var kills = _last_enemy_count - alive
				if current_weapon == 12:
					necro_souls += kills
				if current_weapon == 18:
					dart_stacks = mini(dart_stacks + kills, 10)
			_last_enemy_count = alive

	# Death Note countdown
	var i = death_note_targets.size() - 1
	while i >= 0:
		var dt = death_note_targets[i]
		dt.timer -= delta
		if is_instance_valid(dt.enemy):
			if "death_note_timer_display" in dt.enemy:
				dt.enemy.death_note_timer_display = dt.timer
			dt.enemy.queue_redraw()
		if dt.timer <= 0:
			if is_instance_valid(dt.enemy) and dt.enemy.has_method("take_damage"):
				# Боссы/мини-боссы/толстые враги НЕ ван-шотятся: им наносится
				# крупный, но конечный урон (≈40% макс. HP). Обычные враги —
				# мгновенная смерть.
				var is_tough := false
				if "is_miniboss" in dt.enemy and dt.enemy.is_miniboss:
					is_tough = true
				if "is_boss" in dt.enemy and dt.enemy.is_boss:
					is_tough = true
				var mhp := 0
				if "max_health" in dt.enemy:
					mhp = int(dt.enemy.max_health)
				if mhp > 250:
					is_tough = true
				if is_tough:
					var dn_dmg := maxi(60, int(mhp * 0.40))
					dt.enemy.take_damage(dn_dmg, Vector2.ZERO)
				else:
					dt.enemy.take_damage(99999, Vector2.ZERO)
			death_note_targets.remove_at(i)
		elif not is_instance_valid(dt.enemy):
			death_note_targets.remove_at(i)
		i -= 1

	# Fire DOT (torch weapon)
	var fi = fire_targets.size() - 1
	while fi >= 0:
		var ft = fire_targets[fi]
		ft.timer -= delta
		ft.tick -= delta
		if is_instance_valid(ft.enemy):
			# Не все цели — обычные enemy. Skeleton portal и боссы не имеют этих полей.
			if "is_on_fire" in ft.enemy:
				ft.enemy.is_on_fire = true
			if "fire_timer_display" in ft.enemy:
				ft.enemy.fire_timer_display = ft.timer
			ft.enemy.queue_redraw()
		if ft.tick <= 0:
			ft.tick = 1.0
			if is_instance_valid(ft.enemy) and ft.enemy.has_method("take_damage"):
				ft.enemy.take_damage(2 * ft.get("stacks", 1), Vector2.ZERO)  # урон x стаки
		if ft.timer <= 0 or not is_instance_valid(ft.enemy):
			if is_instance_valid(ft.enemy) and "is_on_fire" in ft.enemy:
				ft.enemy.is_on_fire = false
			fire_targets.remove_at(fi)
		fi -= 1

	# Constrict (snake hand) — poison DOT, kills in ~5s
	var ci = constrict_targets.size() - 1
	while ci >= 0:
		var ct = constrict_targets[ci]
		ct.timer -= delta
		ct.tick -= delta
		if is_instance_valid(ct.enemy):
			if "is_poisoned" in ct.enemy:
				ct.enemy.is_poisoned = true
			ct.enemy.queue_redraw()
		if ct.tick <= 0:
			ct.tick = 1.0
			if is_instance_valid(ct.enemy) and ct.enemy.has_method("take_damage"):
				ct.enemy.take_damage(4 * ct.get("stacks", 1), Vector2.ZERO)  # урон x стаки
		if ct.timer <= 0 or not is_instance_valid(ct.enemy):
			if is_instance_valid(ct.enemy) and "is_poisoned" in ct.enemy:
				ct.enemy.is_poisoned = false
			constrict_targets.remove_at(ci)
		ci -= 1

	# Chain pull
	if chain_target and is_instance_valid(chain_target):
		chain_timer -= delta
		chain_anim += delta
		queue_redraw()  # анимация цепи каждый кадр пока активна
		if chain_timer > 2.0:
			# Pulling phase (1 second) — pull enemy toward player fast
			var pull_dir = (global_position - chain_target.global_position).normalized()
			var pull_dist = global_position.distance_to(chain_target.global_position)
			chain_target.velocity = pull_dir * max(300, pull_dist * 3)
			chain_target.velocity.y = min(chain_target.velocity.y, 0)  # Don't push down
		elif chain_timer > 0:
			# Strangling phase (2 seconds) — hold in place, DOT
			chain_target.global_position = global_position + Vector2(20 if facing_right else -20, 0)
			chain_target.velocity = Vector2.ZERO
			if fmod(chain_timer, 0.5) < delta and chain_target.has_method("take_damage"):
				chain_target.take_damage(15, Vector2.ZERO)
		else:
			# Final kill damage
			if chain_target.has_method("take_damage"):
				chain_target.take_damage(100, Vector2.ZERO)
			chain_target = null

	# Claw grab — hold enemy and squeeze for 3 seconds
	if grab_target and is_instance_valid(grab_target):
		grab_timer -= delta
		grab_target.global_position = global_position + Vector2(20 if facing_right else -20, 0)
		grab_target.velocity = Vector2.ZERO
		if fmod(grab_timer, 0.5) < delta and grab_target.has_method("take_damage"):
			grab_target.take_damage(18, Vector2.ZERO)
		if grab_timer <= 0:
			if grab_target.has_method("take_damage"):
				grab_target.take_damage(30, Vector2.ZERO)
			grab_target = null
	elif grab_target:
		grab_target = null

	# Morningstar spin
	if spin_active:
		spin_timer -= delta
		if spin_timer <= 0:
			spin_active = false
		# Hit all nearby enemies
		_spin_hit_nearby(35)

	# Golden Staff spin (4s reflect)
	if staff_spin_timer > 0:
		staff_spin_timer -= delta
		invincible = true
		invincible_timer = staff_spin_timer
		# Hit nearby enemies every 0.5s during spin
		if fmod(staff_spin_timer, 0.5) < delta:
			var spin_room = _find_room()
			if spin_room:
				for enemy in spin_room.enemies:
					if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < 45:
						var ekb = (enemy.global_position - global_position).normalized()
						enemy.take_damage(7, ekb)
		if staff_spin_timer <= 0:
			staff_spin_timer = 0

	# Shield bash block
	if shield_bash_timer > 0:
		shield_bash_timer -= delta

	# Spear lunge — dash forward and hit enemies
	if spear_lunge:
		spear_lunge_timer -= delta
		var lunge_dir = 1.0 if facing_right else -1.0
		velocity.x = lunge_dir * 350
		# Hit enemies during lunge
		for body in attack_area.get_overlapping_bodies():
			if body.has_method("take_damage"):
				var kb = Vector2(lunge_dir, -0.3).normalized()
				body.take_damage(weapon_data[19].damage * 2, kb)
		if spear_lunge_timer <= 0:
			spear_lunge = false
			is_attacking = false
			attack_shape.disabled = true

	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	if is_attacking:
		attack_anim_timer -= delta
		if attack_anim_timer <= 0:
			is_attacking = false
			attack_shape.disabled = true

	if invincible and not is_rolling:
		invincible_timer -= delta
		if invincible_timer <= 0:
			invincible = false

	# Roll
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			# Не вставать в блоках: если над головой низкий потолок — продолжаем
			# катиться (до разумного предела), пока не выкатимся туда, где можно
			# встать в полный рост.
			if not _can_stand_here() and roll_extend < 0.8:
				roll_extend += delta
				roll_timer = 0.0   # держим кувырок активным, едем дальше
			else:
				is_rolling = false
				roll_extend = 0.0
				invincible = false
				collision_layer = 1
				collision_mask = normal_collision_mask
				# Возвращаем обычный (прощающий) хитбокс.
				body_collision.shape.size = Vector2(7, 16)
				body_collision.position = Vector2(0, -8)

	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta

	if wall_jump_cooldown > 0:
		wall_jump_cooldown -= delta

	# Combo reset
	if combo_reset_timer > 0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0:
			swing_index = 0
			axe_combo = 0

	# Amulet passive heal
	if has_amulet and health < max_health and not is_dead:
		amulet_timer -= delta
		if amulet_timer <= 0:
			amulet_timer = amulet_heal_interval
			heal(1)

	# Ledge grab — just hang, wait for player input (handled in _physics_process)

	# Перерисовка спрайта через кадр (30 Гц) — для пиксель-арта незаметно,
	# а _draw игрока тяжёлый (~150 вызовов). Позиция двигается трансформом
	# каждый физ-кадр, так что движение остаётся плавным.
	# Ключевые события (урон, атака, рывок) делают queue_redraw() сами.
	if Engine.get_process_frames() % 2 == 0:
		queue_redraw()

var _cached_room: Node2D = null

func _find_room() -> Node2D:
	# Кэшируем ссылку на комнату — раньше скан всех детей сцены делался
	# до 17 раз за кадр, это давало просадки. Пересканируем только если
	# кэш пуст или комната уничтожена (смена уровня).
	if _cached_room != null and is_instance_valid(_cached_room):
		return _cached_room
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child != self and child.has_method("get_ladder_at"):
				_cached_room = child
				return child
	_cached_room = null
	return null

func stun(duration: float):
	is_stunned = true
	stun_timer = duration
	velocity = Vector2.ZERO

func _physics_process(delta):
	# Тетрадь Смерти: во время записи имён игрок стоит на месте.
	if dn_writing:
		_update_death_note_writing(delta)
		velocity.x = 0.0
		velocity.y += gravity * delta   # гравитация работает (не зависает в воздухе)
		move_and_slide()
		return

	# Лечение-зелье: пьём, в это время нельзя двигаться/бить, ХП растёт плавно.
	if is_drinking:
		drink_timer -= delta
		velocity.x = 0.0
		velocity.y += gravity * delta
		move_and_slide()
		queue_redraw()
		# Постепенное пополнение HP по мере питья.
		if not is_dead:
			var prog := 1.0 - clampf(drink_timer / DRINK_TIME, 0.0, 1.0)
			var should_have := int(round(prog * drink_heal_amount))
			if should_have > drink_given:
				heal(should_have - drink_given)
				drink_given = should_have
		if drink_timer <= 0.0 or is_dead:
			if not is_dead and drink_given < drink_heal_amount:
				heal(drink_heal_amount - drink_given)   # доливаем остаток
			is_drinking = false
			can_attack = true
			weapon_pickup_msg = ""
		return

	# Автоатака при ЗАЖАТОЙ ЛКМ — бьём с максимальной скоростью оружия,
	# кликать повторно не нужно. (Кулдаун оружия сам ограничивает темп.)
	if not is_dead and can_attack and not is_rolling and not is_grabbing_ledge \
		and staff_spin_timer <= 0 and not is_webbed \
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_do_attack()

	# === CS-trackers ===
	# Idle-таймер для инспекта: растёт когда стоим и ничего не нажимаем
	var any_movement_input = Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") \
		or Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") \
		or Input.is_action_pressed("jump") \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if is_inspecting:
		inspect_anim_timer -= delta
		if inspect_anim_timer <= 0.0:
			is_inspecting = false
		inspect_idle_timer = 0.0
	elif any_movement_input or is_attacking or is_rolling or is_dead:
		inspect_idle_timer = 0.0
	else:
		inspect_idle_timer += delta

	# Дэш-чарджи восстанавливаются МГНОВЕННО, как только персонаж коснулся
	# пола (не в воздухе/на лестнице/уступе). Так дэш — наземный инструмент.
	if not dash_active and is_on_floor() and not is_on_vine and not is_grabbing_ledge:
		dash_charges = float(DASH_MAX_CHARGES)

	# Anti-spam: если Space НЕ нажат — значит игрок его отпустил, готов к новому прыжку
	if not Input.is_action_pressed("jump"):
		bhop_space_released = true
	# Время с прошлого прыжка — нужно для блокировки спам-мэша
	bhop_time_since_jump += delta

	# ULTRAKILL: bhop сбрасывается при столкновении со стеной или карабкании
	if bhop_stacks > 0:
		if is_on_wall() or is_wall_sliding or is_grabbing_ledge:
			_reset_bhop_combo("collision")

	# Acid trail (психоделические RGB-призраки за движением)
	_acid_cd -= delta
	var moving_fast = abs(velocity.x) > 50.0 or abs(velocity.y) > 100.0
	if moving_fast and _acid_cd <= 0.0 and not is_dead:
		_acid_cd = 0.10
		_acid_trail.append({
			"pos": global_position,
			"life": 0.4,
			"max_life": 0.4,
			"facing": facing_right,
		})
	for tr in _acid_trail:
		tr.life -= delta
	_acid_trail = _acid_trail.filter(func(p): return p.life > 0.0)

	# LEVEL MODIFIER: Пакт Крови — −2 HP/сек постоянно
	if level_modifier == "blood_pact_level" and not is_dead:
		_blood_pact_tick += delta
		if _blood_pact_tick >= 0.5:
			_blood_pact_tick = 0.0
			health = maxi(1, health - 1)   # минимум 1 HP — не убивает
			health_changed.emit(health)
			queue_redraw()

	# Атмосферные искры вокруг игрока (реже — экономия CPU)
	_spark_cd -= delta
	if _spark_cd <= 0.0 and not is_dead and aura_sparks.size() < 5:
		_spark_cd = randf_range(0.18, 0.35)
		# Случайные dream-цвета
		var palette = [
			Color(0.95, 0.65, 0.85),
			Color(0.65, 0.95, 0.95),
			Color(0.85, 0.75, 1.00),
			Color(1.00, 0.85, 0.95),
		]
		aura_sparks.append({
			"offset": Vector2(randf_range(-14, 14), randf_range(-22, -2)),
			"vy": randf_range(-12, -4),
			"life": randf_range(0.8, 1.6),
			"max_life": 1.4,
			"color": palette[randi() % palette.size()],
		})
	for sp in aura_sparks:
		sp.offset.y += sp.vy * delta
		sp.offset.x += sin(Time.get_ticks_msec() * 0.005 + sp.life) * 0.3
		sp.life -= delta
	aura_sparks = aura_sparks.filter(func(s): return s.life > 0.0)

	# Окно bhop — приоткрывается в момент приземления
	if bhop_window_t > 0.0:
		bhop_window_t -= delta

	# Tracking приземления:
	var on_floor_now = is_on_floor()
	if on_floor_now and not bhop_was_on_floor and velocity.y >= -1.0:
		# Только что коснулись пола → открываем окно bhop
		bhop_window_t = BHOP_WINDOW
		bhop_ground_t = 0.0
	bhop_was_on_floor = on_floor_now
	if on_floor_now:
		bhop_ground_t += delta
		# Если стоим на полу слишком долго — комбо сброшено
		if bhop_ground_t > BHOP_GROUND_TOLERANCE and bhop_stacks > 0:
			_reset_bhop_combo("idle")

	# Активный dash — двигаемся в направлении dash_dir игнорируя гравитацию
	if dash_active:
		dash_timer -= delta
		velocity = dash_dir * DASH_SPEED
		move_and_slide()
		queue_redraw()
		if dash_timer <= 0.0:
			dash_active = false
			dash_invuln = false
			collision_layer = 1   # возвращаем "player" слой
			# Плавный выход (Celeste-feel): сохраняем часть импульса, чтобы не
			# было резкого стопа, но и не уносило. Вертикаль гасим.
			velocity.x = dash_dir.x * 175.0
			if dash_dir.y < 0.0:
				velocity.y = maxf(velocity.y, -150.0)   # мягкий остаток подъёма
			elif dash_dir.y > 0.0:
				velocity.y = 120.0
			else:
				velocity.y = 0.0
		return  # пропускаем остальной физпроцесс — даш сам по себе

	# Если игрок убегает от стэка — теряем (отпустил направление в воздухе)
	if bhop_stacks > 0 and not on_floor_now:
		if not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"):
			# Не сразу — пусть будет момент, ловим первые 0.3 сек
			pass  # мягкое поведение: не сбрасываем сразу

	# Добавляем точку трейла если в bhop-движении (стэки ≥ 2) или дашаем
	if (bhop_stacks >= 2 or dash_active) and (Time.get_ticks_msec() % 2 == 0):
		bhop_trail.append({
			"pos": global_position,
			"life": BHOP_TRAIL_LIFE,
			"max_life": BHOP_TRAIL_LIFE,
			"alpha_mult": clampf(float(bhop_stacks) / float(BHOP_MAX_STACKS), 0.4, 1.0) if bhop_stacks > 0 else 0.9,
		})

	# Вспышка PERFECT
	if bhop_perfect_flash_t > 0.0:
		bhop_perfect_flash_t -= delta
	if is_dead:
		return

	# Knocked-out by mimic
	if is_knocked_out:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y = min(velocity.y + 980.0 * delta, 600.0)
		else:
			velocity.y = 0.0
		move_and_slide()
		knockdown_timer -= delta
		if knockdown_timer <= 0.0:
			is_knocked_out = false
		queue_redraw()
		return

	# Parry window: starts when shield is first pressed
	var shielding_now = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not is_rolling and not is_dead
	if shielding_now and not is_shielding:
		parry_window = parry_window_duration
	parry_window = maxf(0.0, parry_window - delta)
	parry_flash_timer = maxf(0.0, parry_flash_timer - delta)

	# Kill combo timer
	if combo_kill_timer > 0:
		combo_kill_timer -= delta
		if combo_kill_timer <= 0:
			combo_kill_count = 0

	# Sword trail: record tip position during attack animation
	if is_attacking and attack_anim_timer > 0:
		var wd2 = weapon_data.get(current_weapon, weapon_data[1])
		var s2 = 1.0 if facing_right else -1.0
		var tip = global_position + Vector2(s2 * wd2.get("blade_len", 20), -10)
		sword_trail.append({"pos": tip, "life": 0.13, "max_life": 0.13,
			"col": wd2.get("glow", Color(1, 0.9, 0.4, 0.5))})
		if sword_trail.size() > 10:
			sword_trail.pop_front()
	# Decay trail
	for _pt in sword_trail:
		_pt["life"] -= delta
	sword_trail = sword_trail.filter(func(p): return p["life"] > 0)

	# Hit-stop — freeze everything briefly when hitting an enemy
	if hit_stop_timer > 0:
		hit_stop_timer -= delta
		return  # Skip all movement while frozen

	# Coyote time + landing squash
	if is_on_floor():
		if not was_on_floor:
			# Just landed — пыль приземления, сила зависит от скорости падения
			land_squash_timer = 0.14
			landed.emit()
			_spawn_landing_dust(_last_landing_vy)
			queue_redraw()
		coyote_timer = coyote_time
		was_on_floor = true
		# Запоминаем последнюю БЕЗОПАСНУЮ точку на полу (для HK-возврата с шипов).
		# Обновляем пока стоим на твёрдом полу — это и есть точка, откуда прыгал.
		if not is_dead and not invincible:
			_safe_pos_cd -= delta
			if _safe_pos_cd <= 0.0:
				_safe_pos_cd = 0.1
				last_safe_pos = global_position
	else:
		if was_on_floor:
			coyote_timer = coyote_time
		coyote_timer -= delta
		was_on_floor = false
		_last_landing_vy = velocity.y  # запоминаем скорость падения для силы пыли

	# Footstep particles — мелкие частицы при беге по земле
	if is_on_floor() and abs(velocity.x) > 60.0 and not is_rolling:
		_footstep_cd -= delta
		if _footstep_cd <= 0.0:
			_footstep_cd = 0.16
			_spawn_footstep()

	# Обновление game-feel частиц (с лимитом — защита от роста)
	for fp in feel_particles:
		fp.vel.y += 180.0 * delta   # лёгкая гравитация
		fp.pos += fp.vel * delta
		fp.life -= delta
	feel_particles = feel_particles.filter(func(p): return p.life > 0.0)
	if feel_particles.size() > 40:
		feel_particles = feel_particles.slice(feel_particles.size() - 40)

	if land_squash_timer > 0:
		land_squash_timer -= delta
		queue_redraw()

	# Jump buffer countdown
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	# Net trap handling
	if is_netted:
		net_timer -= delta
		velocity = Vector2.ZERO
		if net_timer <= 0:
			is_netted = false
		queue_redraw()
		return

	# Spider web trap handling
	if is_webbed:
		web_timer -= delta
		web_cursor += web_cursor_dir * WEB_CURSOR_SPEED * delta
		if web_cursor >= 1.0:
			web_cursor = 1.0
			web_cursor_dir = -1.0
		elif web_cursor < 0.0:
			web_cursor = 0.0
			web_cursor_dir = 1.0
		velocity = Vector2.ZERO
		if web_timer <= 0:
			is_webbed = false
		queue_redraw()
		return

	# Poison DOT
	if poison_timer > 0:
		poison_timer -= delta
		poison_tick_timer -= delta
		if poison_tick_timer <= 0:
			poison_tick_timer = 0.5
			health -= int(poison_damage)
			health_changed.emit(health)
			if health <= 0:
				is_dead = true
				died.emit()

	# Worm infection DOT
	if worm_count > 0:
		worm_phase += delta * 3.0
		worm_timer -= delta
		worm_tick_timer -= delta
		if worm_tick_timer <= 0:
			worm_tick_timer = 3.0
			var dmg = worm_count * 3
			health -= dmg
			health_changed.emit(health)
			if health <= 0:
				is_dead = true
				died.emit()
		if worm_timer <= 0:
			worm_count = 0
			worm_timer = 0.0
		queue_redraw()

	# Throw weapon cooldown
	if throw_weapon_cooldown > 0:
		throw_weapon_cooldown -= delta

	# Invisibility update — breaks on combat, restores after 4s, also off near torches
	if active_card == "invisibility":
		if invis_break_timer > 0:
			invis_break_timer -= delta
			is_invisible = false
		else:
			is_invisible = true
			var invis_room = _find_room()
			if invis_room and invis_room.has_method("get_nearest_torch_dist"):
				var torch_dist = invis_room.get_nearest_torch_dist(global_position)
				if torch_dist < 160:  # Match torch light radius (~2.5 * 64)
					is_invisible = false
	else:
		is_invisible = false

	# Stun handling
	if is_stunned:
		stun_timer -= delta
		velocity.x *= 0.9
		velocity.y += gravity * delta
		move_and_slide()
		if stun_timer <= 0:
			is_stunned = false
		queue_redraw()
		return

	# Ledge climbing - easy jump off in any direction
	if is_grabbing_ledge:
		# A or D alone = jump off to that side (no need for Space)
		if Input.is_action_just_pressed("move_left"):
			is_grabbing_ledge = false
			facing_right = false
			velocity = Vector2(-180, -250)
			return
		elif Input.is_action_just_pressed("move_right"):
			is_grabbing_ledge = false
			facing_right = true
			velocity = Vector2(180, -250)
			return
		# Space or W = climb up onto the ledge
		elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_up"):
			is_grabbing_ledge = false
			position.y = ledge_target_y - 14
			velocity = Vector2(0, -60)
			return
		# S = drop down
		elif Input.is_action_just_pressed("move_down"):
			is_grabbing_ledge = false
			velocity = Vector2(0, 50)
			return
		else:
			velocity = Vector2.ZERO
			position.y = lerp(position.y, ledge_target_y - 12, delta * 12)
		return

	# Ladder climbing — find the room node (sibling, not parent)
	var was_on_vine = is_on_vine
	is_on_vine = false
	var room = _find_room()
	if room:
		var lad = room.get_ladder_at(global_position.x, global_position.y)
		if not lad.is_empty():
			# W = grab ladder instantly
			if Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") or was_on_vine:
				is_on_vine = true
				velocity.y = 0
				velocity.x = 0
				if Input.is_action_pressed("move_up"):
					velocity.y = -vine_climb_speed
				elif Input.is_action_pressed("move_down"):
					velocity.y = vine_climb_speed
				# Snap to ladder center
				global_position.x = lerpf(global_position.x, lad.x, delta * 15)
				# Jump off
				if Input.is_action_just_pressed("jump"):
					is_on_vine = false
					velocity.y = jump_force * 0.8
				# Left/Right exits ladder
				if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
					if not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"):
						is_on_vine = false
				# Reached floor
				if is_on_floor() and not Input.is_action_pressed("move_down"):
					is_on_vine = false

	# Переменная высота прыжка (плавно, без резкого обрыва): пока летим вверх
	# и пробел ОТПУЩЕН — добавляем повышенную гравитацию, и подъём плавно
	# скругляется. Держишь дольше — выше. Высота полностью аналоговая.
	var jump_held := Input.is_action_pressed("jump") or Input.is_action_pressed("move_up")
	if is_jump_rising and velocity.y >= 0.0:
		is_jump_rising = false   # достигли вершины — режим управления высотой окончен

	if not is_on_vine:
		if velocity.y > 0:
			# Fast-fall: apply extra gravity when falling — Dead Cells feel
			velocity.y += gravity * 1.5 * delta
		elif is_jump_rising and not jump_held:
			# Подъём с ОТПУЩЕННЫМ прыжком — гасим взлёт сильнее (но плавно).
			velocity.y += gravity * 3.0 * delta
		else:
			velocity.y += gravity * delta

	# Ground slam — double-tap S in air
	if slam_tap_timer > 0:
		slam_tap_timer -= delta
		if slam_tap_timer <= 0:
			slam_first_tap = false
	if not is_on_floor() and not is_on_vine and not ground_slam:
		if Input.is_action_just_pressed("move_down"):
			if slam_first_tap:
				# Second tap — activate slam!
				ground_slam = true
				slam_first_tap = false
				velocity.y = 600
				velocity.x = 0
			else:
				slam_first_tap = true
				slam_tap_timer = 0.3  # 300ms window for double tap
	if ground_slam:
		velocity.x = 0
		velocity.y = maxf(velocity.y, 600)
		if is_on_floor():
			ground_slam = false
			# AOE damage on landing
			_ground_slam_hit()

	# Drop through one-way platforms on S
	if drop_through_timer > 0:
		drop_through_timer -= delta
		if drop_through_timer <= 0:
			drop_through_timer = 0
			set_collision_mask_value(6, true)
	elif is_on_floor() and Input.is_action_just_pressed("move_down") and not is_on_vine:
		drop_through_timer = 0.18
		velocity.y = 50
		position.y += 4
		set_collision_mask_value(6, false)

	if is_rolling:
		velocity.x = roll_direction * roll_speed
		# Record trail positions
		if fmod(roll_timer * 20, 1.0) < 0.5:
			roll_trail.append({"pos": global_position, "facing": facing_right, "life": 0.2})
		move_and_slide()
		return

	if ground_slam:
		move_and_slide()
		queue_redraw()
		return

	var dir = 0.0
	if Input.is_action_pressed("move_left"):
		dir = -1.0
		if not is_attacking:
			facing_right = false
	elif Input.is_action_pressed("move_right"):
		dir = 1.0
		if not is_attacking:
			facing_right = true

	var wd_move = weapon_data.get(current_weapon, weapon_data[1])
	# Замедление от тяжёлого оружия убрано — ходим с полной скоростью всегда.
	var current_speed = speed
	if active_card == "speed_boots":
		current_speed *= 1.5
	if scroll_speed_active:
		current_speed *= 1.8
	if is_attacking:
		current_speed *= 0.55
	# Банихоп убран — никакого ускорения от стэков прыжков.

	# Snappy acceleration: instant start, quick stop
	var target_vx = dir * current_speed
	if dir != 0.0:
		velocity.x = lerpf(velocity.x, target_vx, 1.0 - exp(-20.0 * delta))  # Fast accel
	else:
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-25.0 * delta))  # Slightly slower stop

	# Wall slide detection
	is_wall_sliding = false
	wall_dir = 0
	if not is_on_floor() and is_on_wall() and velocity.y > 0 and wall_jump_cooldown <= 0:
		# Check which wall we're touching
		if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			var space = get_world_2d().direct_space_state
			# Check left
			var ql = PhysicsRayQueryParameters2D.create(
				global_position + Vector2(0, -10),
				global_position + Vector2(-8, -10), 4)
			var rl = space.intersect_ray(ql)
			# Check right
			var qr = PhysicsRayQueryParameters2D.create(
				global_position + Vector2(0, -10),
				global_position + Vector2(8, -10), 4)
			var rr = space.intersect_ray(qr)

			if not rl.is_empty() and Input.is_action_pressed("move_left"):
				is_wall_sliding = true
				wall_dir = -1
			elif not rr.is_empty() and Input.is_action_pressed("move_right"):
				is_wall_sliding = true
				wall_dir = 1

	if is_wall_sliding:
		velocity.y = min(velocity.y, wall_slide_speed)
		# Face away from wall
		facing_right = wall_dir < 0

	# Jump buffer: register jump press slightly early
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_up"):
		jump_buffer_timer = jump_buffer_time
		# Для bhop: запоминаем, был ли прыжок нажат ИМЕННО стоя на земле в окне.
		# Забуференный (в воздухе) прыжок НЕ даёт perfect bhop — нужен точный тайминг.
		bhop_pressed_grounded = is_on_floor() and bhop_window_t > 0.0

	# Perform jump: floor, coyote, or wall
	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			var jf = jump_force
			if active_card == "speed_boots":
				jf *= 1.3
			velocity.y = jf
			is_jump_rising = true   # включаем переменную высоту прыжка
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			jumped.emit()
		elif is_wall_sliding:
			# Wall jump - jump away from wall
			velocity.x = -wall_dir * wall_jump_force.x
			velocity.y = wall_jump_force.y
			is_wall_sliding = false
			facing_right = wall_dir < 0
			wall_jump_cooldown = 0.15  # Brief cooldown to prevent re-sticking
		# Ledge grab отключён — мешал bhop'у

	var side = 1 if facing_right else -1
	# Only update attack position when not attacking (attack sets its own position)
	if not is_attacking:
		attack_shape.position = Vector2(15 * side, -11)

	move_and_slide()

	# Spawn run dust
	if is_on_floor() and abs(velocity.x) > 40:
		dust_timer -= delta
		if dust_timer <= 0:
			dust_timer = 0.08
			dust_particles.append({
				"pos": global_position + Vector2(randf_range(-4, 4), 0),
				"vel": Vector2(randf_range(-20, 20), randf_range(-15, -5)),
				"life": randf_range(0.15, 0.25),
				"max_life": 0.2,
				"size": randf_range(1.5, 3.0)
			})

	# Landing dust burst
	if is_on_floor() and not was_on_floor and abs(velocity.y) > 80:
		for _di in 6:
			dust_particles.append({
				"pos": global_position + Vector2(randf_range(-6, 6), 0),
				"vel": Vector2(randf_range(-35, 35), randf_range(-25, -8)),
				"life": randf_range(0.2, 0.35),
				"max_life": 0.3,
				"size": randf_range(2.0, 4.0)
			})

	# Tick dust
	for dp in dust_particles:
		dp["life"] -= delta
		dp["pos"] += dp["vel"] * delta
	dust_particles = dust_particles.filter(func(p): return p["life"] > 0)

	# Tick roll trail
	for rt in roll_trail:
		rt["life"] -= delta
	roll_trail = roll_trail.filter(func(t): return t["life"] > 0)

	# Damage flash timer
	if damage_flash_timer > 0:
		damage_flash_timer -= delta

func _check_ledge_grab():
	var side = 1 if facing_right else -1
	var space = get_world_2d().direct_space_state

	var check_x = global_position.x + side * 10
	var wall_and_plat_mask = 4 | 32  # walls + one-way platforms

	# Ray downward from ahead to find platform top
	var feet_from = Vector2(check_x, global_position.y - 20)
	var feet_to = Vector2(check_x, global_position.y + 5)
	var q1 = PhysicsRayQueryParameters2D.create(feet_from, feet_to, wall_and_plat_mask)
	var r1 = space.intersect_ray(q1)

	if r1.is_empty():
		return

	var platform_y = r1.position.y
	var is_oneway = (r1.collider.collision_layer & 32) != 0

	var diff = global_position.y - platform_y
	if diff < -5 or diff > 25:
		return

	if platform_y < 35:
		return

	# Headroom check — only for solid walls, not one-way platforms
	if not is_oneway:
		var head_from = Vector2(check_x, platform_y - 5)
		var head_to = Vector2(check_x, platform_y - 28)
		var q2 = PhysicsRayQueryParameters2D.create(head_from, head_to, 4)
		var r2 = space.intersect_ray(q2)
		if not r2.is_empty():
			return

	# Edge check - skip for one-way platforms
	if not is_oneway:
		var above_from = Vector2(global_position.x, platform_y - 5)
		var above_to = Vector2(global_position.x, platform_y + 5)
		var q3 = PhysicsRayQueryParameters2D.create(above_from, above_to, 4)
		var r3 = space.intersect_ray(q3)
		if not r3.is_empty() and abs(r3.position.y - platform_y) < 4:
			return

	is_grabbing_ledge = true
	ledge_target_y = platform_y
	climb_timer = climb_duration
	velocity = Vector2.ZERO

func _unhandled_input(event):
	if is_dead or is_knocked_out:
		return

	# Web escape minigame: press Space when cursor is in green zone
	if is_webbed and event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if web_cursor >= web_target_start and web_cursor <= web_target_start + WEB_TARGET_W:
			web_success_count += 1
			if web_success_count >= 3:
				is_webbed = false
				web_timer = 0.0
				web_success_count = 0
		get_viewport().set_input_as_handled()
		queue_redraw()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if can_attack and not is_rolling and not is_grabbing_ledge and staff_spin_timer <= 0:
				_do_attack()

		# Right mouse button — special attacks
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var wd = weapon_data.get(current_weapon, weapon_data[1])
			var special = wd.get("special", "")
			# Spear lunge
			if special == "spear_thrust" and not spear_lunge:
				# Find nearest enemy within 4 blocks (64px) and leap at them
				var spear_room = _find_room()
				var leap_target = null
				var leap_dist = 64.0
				if spear_room:
					for enemy in spear_room.enemies:
						if is_instance_valid(enemy):
							var d = global_position.distance_to(enemy.global_position)
							if d < leap_dist:
								leap_dist = d
								leap_target = enemy
				spear_lunge = true
				spear_lunge_timer = 0.35
				is_attacking = true
				attack_anim_timer = 0.35
				attack_shape.disabled = false
				var lside = 1 if facing_right else -1
				attack_shape.position = Vector2(20 * lside, -11)
				attack_shape.shape.size = Vector2(35, 18)
				if leap_target:
					# Jump toward enemy
					var dir_to = (leap_target.global_position - global_position)
					velocity.x = dir_to.x * 4
					velocity.y = min(-200, dir_to.y * 3 - 150)
					if dir_to.x > 0:
						facing_right = true
					else:
						facing_right = false
				else:
					# No target — just dash forward
					velocity.x = lside * 350
					velocity.y = -120
			# Chain pull — ЦЕПЬ кидается в сторону ПРИЦЕЛА (как лук): целимся
			# мышкой/направлением и цепляем врага, который лучше всего совпал
			# с лучом прицеливания.
			elif special == "chain_pull" and chain_target == null:
				var aim := _get_aim_direction()
				var chain_room = _find_room()
				if chain_room:
					var best_enemy = null
					var best_score = 0.55      # минимальное совпадение с прицелом (cos угла)
					var max_range = 170.0      # дальность цепи
					for enemy in chain_room.enemies:
						if is_instance_valid(enemy):
							var to_e = enemy.global_position - global_position
							var d = to_e.length()
							if d > 8.0 and d < max_range:
								var aligned = aim.dot(to_e / d)
								if aligned > best_score:
									best_score = aligned
									best_enemy = enemy
					if best_enemy:
						chain_target = best_enemy
						chain_timer = 3.0
						chain_anim = 0.0
						facing_right = best_enemy.global_position.x >= global_position.x
						weapon_pickup_msg = "ЗАЦЕП!"
						weapon_msg_timer = 1.0
					else:
						weapon_pickup_msg = "ПРОМАХ"
						weapon_msg_timer = 0.5
			# Morningstar spin
			elif special == "spin_attack" and not spin_active:
				spin_active = true
				spin_timer = 4.0
			# Necro book — RMB releases ALL souls in a circle
			elif special == "necro_souls" and necro_souls > 0 and can_attack:
				_necro_soul_burst()
			# Ranged weapons (bows, darts)
			elif special in ["warp_arrow", "triple_arrow", "dart_throw", "sniper"]:
				if can_attack:
					_do_ranged_attack(special)

	# === DASH (ULTRAKILL): LCtrl ===
	if event is InputEventKey and event.pressed and event.keycode == KEY_CTRL and not event.echo:
		if not is_dead and not dash_active and dash_charges >= 1.0:
			_do_dash()

	# Throw weapon card — Q key, ИЛИ инспект оружия если простаиваем (CS-flex)
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		if active_card == "throw_weapon" and throw_weapon_cooldown <= 0 and current_weapon > 0:
			_throw_current_weapon()
		elif inspect_idle_timer >= INSPECT_IDLE_THRESHOLD and not is_inspecting and not is_dead:
			_start_inspect()

	# Гранаты убраны по просьбе игрока.

	# === Snipe / AWP scope (ПКМ при наличии AWP в руках) ===
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var wd_sn = weapon_data.get(current_weapon, {})
		if wd_sn.get("special", "") == "sniper":
			is_scoping = event.pressed
			# Сигналим overlay через main.gd; main.gd слушает _process игрока

	# Dodge roll on C (раньше был на Shift, освобождён для long-jump)
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		if not is_rolling and roll_cooldown_timer <= 0 and not is_grabbing_ledge:
			_do_roll()

	# Weapon switch: 1 = sword/blade, 2 = pickaxe
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		using_pickaxe = false
	if event is InputEventKey and event.pressed and event.keycode == KEY_2:
		if has_pickaxe:
			using_pickaxe = true

	# Свитки: X — использовать ближайший доступный свиток (удобная общая кнопка).
	# 3/4 оставлены как альтернатива на ПК для выбора слота.
	if event is InputEventKey and event.pressed and event.keycode == KEY_X and not is_dead:
		_use_next_scroll()
	if event is InputEventKey and event.pressed and event.keycode == KEY_3:
		if scrolls.size() > 0:
			_use_scroll(0)
	if event is InputEventKey and event.pressed and event.keycode == KEY_4:
		if scrolls.size() > 1:
			_use_scroll(1)


	# Heal on H — лечит 20% от макс HP. Теперь это ПИТЬЁ ЗЕЛЬЯ ~3 сек:
	# заряд тратится сразу, и всё время питья нельзя двигаться/бить.
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if heal_charges > 0 and health < max_health and not is_dead \
			and not is_drinking and not dn_writing and not is_rolling:
			heal_charges -= 1
			_start_drinking(maxi(1, int(max_health * 0.20)))

	# Flask on F — то же зелье из фляги
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if has_flask and flask_charges > 0 and health < max_health and not is_dead \
			and not is_drinking and not dn_writing and not is_rolling:
			flask_charges -= 1
			_start_drinking(maxi(1, int(max_health * 0.20)))

func _start_drinking(amount: int) -> void:
	is_drinking = true
	drink_timer = DRINK_TIME
	drink_heal_amount = amount
	drink_given = 0
	can_attack = false
	velocity.x = 0.0
	weapon_pickup_msg = "Пьёт зелье…"
	weapon_msg_timer = DRINK_TIME

func _do_attack():
	_break_invisibility()
	var wd = weapon_data.get(current_weapon, weapon_data[1])
	var special = wd.get("special", "")

	# Ranged weapons shoot on LMB too
	if special in ["warp_arrow", "triple_arrow", "dart_throw", "necro_souls"]:
		_do_ranged_attack(special)
		return

	# Тетрадь Смерти — запускаем запись имён (а не обычная атака)
	if special == "death_note":
		_start_death_note_writing()
		return

	is_attacking = true
	can_attack = false
	attack_timer = wd.cooldown
	attack_anim_timer = min(wd.cooldown * 0.6, 0.15)
	attack_shape.disabled = false
	attacked.emit()

	# Determine attack direction based on held keys
	if Input.is_action_pressed("move_up"):
		attack_direction = 1  # up
	elif Input.is_action_pressed("move_down"):
		attack_direction = -1  # down
	else:
		attack_direction = 0  # horizontal

	# Position attack hitbox based on direction and weapon range
	var side = 1 if facing_right else -1
	var rng = wd.range
	match attack_direction:
		1:  # up
			attack_shape.position = Vector2(0, -28)
			attack_shape.shape.size = Vector2(rng, rng)
		-1:  # down
			attack_shape.position = Vector2(0, 6)
			attack_shape.shape.size = Vector2(rng, rng)
		_:  # horizontal
			attack_shape.position = Vector2((rng * 0.7) * side, -11)
			attack_shape.shape.size = Vector2(rng, 18)

	combo_reset_timer = combo_reset_time

	var is_aoe_weapon = special in ["aoe_slam", "spin_attack"]
	var hit_one = false
	for body in attack_area.get_overlapping_bodies():
		if not is_aoe_weapon and hit_one:
			break  # Non-AOE weapons hit only one target
		if _on_attack_hit(body):
			hit_one = true

	swing_index = (swing_index + 1) % 3

func _can_stand_here() -> bool:
	# Есть ли над головой место, чтобы встать в полный рост (стоячий хитбокс
	# ~16px над ступнями) и не оказаться в блоках. Читаем сетку комнаты.
	var room = _find_room()
	if room == null or not ("grid" in room):
		return true
	var ts: int = room.tile_size
	if ts <= 0:
		return true
	var gx: int = int(global_position.x / ts)
	if gx < 0 or gx >= room.grid_cols:
		return true
	# Тайлы, которые займёт стоячий хитбокс (от ступней вверх на ~15px).
	var r0: int = int((global_position.y - 15.0) / ts)
	var r1: int = int((global_position.y - 1.0) / ts)
	for rr in range(r0, r1 + 1):
		if rr >= 0 and rr < room.grid_rows and room.grid[rr][gx] == 1:
			return false
	return true

func _do_roll():
	is_rolling = true
	roll_extend = 0.0
	roll_timer = roll_duration
	roll_cooldown_timer = roll_cooldown
	invincible = true

	collision_layer = 0
	collision_mask = 4 | 32  # walls + one-way platforms

	# Shrink collision to 1 tile height (16px) so player can roll through gaps
	body_collision.shape.size = Vector2(10, 10)
	body_collision.position = Vector2(0, -5)

	if Input.is_action_pressed("move_left"):
		roll_direction = -1.0
	elif Input.is_action_pressed("move_right"):
		roll_direction = 1.0
	else:
		roll_direction = 1.0 if facing_right else -1.0

	is_attacking = false
	attack_shape.disabled = true

func _on_attack_hit(body) -> bool:
	if body.has_method("take_damage") and is_attacking:
		var wd = weapon_data.get(current_weapon, weapon_data[1])
		var dmg = wd.damage
		# Pickaxe deals very low damage to monsters (incentivize switching)
		if using_pickaxe:
			dmg = max(5, dmg / 4)

		var dir = 1.0 if body.global_position.x > global_position.x else -1.0

		# --- Card damage bonuses ---
		# Backstab: +60% if hitting enemy from behind
		if card_backstab_bonus > 0 and "facing_right" in body:
			var enemy_faces_right = body.facing_right
			var attacking_from_behind = (enemy_faces_right and global_position.x > body.global_position.x) or \
				(not enemy_faces_right and global_position.x < body.global_position.x)
			if attacking_from_behind:
				dmg = int(dmg * (1.0 + card_backstab_bonus))

		# Close range: +40% within 24px (1.5 blocks)
		if card_close_range_bonus > 0:
			if global_position.distance_to(body.global_position) < 24:
				dmg = int(dmg * (1.0 + card_close_range_bonus))

		# Low HP bonus: +0.5% per 1% HP lost
		if card_low_hp_bonus:
			var hp_pct_lost = 1.0 - (float(health) / float(max_health))
			var bonus = hp_pct_lost * 0.5  # 50% HP lost = +25% dmg
			dmg = int(dmg * (1.0 + bonus))

		# Kill bonus: +0.2% per kill accumulated
		if card_kill_bonus > 0:
			dmg = int(dmg * (1.0 + card_kill_count * card_kill_bonus))

		# === STYLE COMBO REWARD: урон растёт с рангом ===
		# C(1)=+8%, B(2)=+16%, A(3)=+24%, S(4)=+32%, SS(5)=+40%, SSS(6)=+50%, U(7)=+65%
		if style_rank >= 1:
			var style_dmg_mult = [0.0, 0.08, 0.16, 0.24, 0.32, 0.40, 0.50, 0.65][style_rank]
			dmg = int(dmg * (1.0 + style_dmg_mult))

		# === LEVEL MODIFIER damage multiplier ===
		if damage_mult != 1.0:
			dmg = int(dmg * damage_mult)

		# === РЕЛИКВИИ (pre-crit) ===
		if "bloody_pact" in relics:
			dmg = int(dmg * 1.30)
		if "rage_amulet" in relics:
			var hp_lost_pct = 1.0 - float(health) / float(max_health)
			dmg = int(dmg * (1.0 + hp_lost_pct))

		# === CS HEADSHOT ===
		# Если игрок атакует сверху (attack_direction == 1) ИЛИ игрок выше центра врага
		# на 8px+ — считаем хедшотом (x2 урон).
		var is_headshot = false
		if attack_direction == 1:
			is_headshot = true
		elif (global_position.y + 4.0) < (body.global_position.y - 6.0):
			is_headshot = true
		if is_headshot and not ("is_boss" in body and body.is_boss):
			dmg = int(dmg * 2.0)
			var hs_pos = body.global_position + Vector2(0, -12)
			headshot_landed.emit(hs_pos)

		# Crit chance
		var total_crit = crit_chance + card_crit_bonus_chance
		var total_crit_mult = crit_multiplier + card_crit_bonus_damage
		var is_crit = randf() < total_crit

		# === СИНЕРГИИ оружия + карты ===
		var Syn = load("res://scripts/synergies.gd")
		var syn = Syn.find_active(current_weapon, active_card)
		if syn:
			match syn.id:
				"shadow_assassin":
					# Удары сзади = автокрит
					if "facing_right" in body:
						var en_face = body.facing_right
						var from_behind = (en_face and global_position.x > body.global_position.x) or \
							(not en_face and global_position.x < body.global_position.x)
						if from_behind:
							is_crit = true
				"berserker_blade":
					if float(health) / max_health < 0.30:
						dmg = int(dmg * 2.5)
				"death_blow":
					if global_position.distance_to(body.global_position) < 24:
						dmg = int(dmg * 1.6)

		if is_crit:
			dmg = int(dmg * total_crit_mult)
			# РЕЛИКВИЯ: Мастер Критов — доп +30% урона критов
			if "crit_master" in relics:
				dmg = int(dmg * 1.30)
			# СИНЕРГИЯ: Взрывной Охотник — критические выстрелы взрываются (для луков)
			if syn and syn.id == "explosive_hunter":
				var room_eh = _find_room()
				if room_eh:
					for other in room_eh.enemies:
						if other != body and is_instance_valid(other) \
							and body.global_position.distance_to(other.global_position) < 50.0:
							if other.has_method("take_damage"):
								other.take_damage(int(dmg * 0.6), Vector2.ZERO)
			weapon_pickup_msg = "КРИТ!"
			weapon_msg_timer = 0.4

		var knockback = Vector2(dir, -0.3).normalized()
		# Adjust knockback direction for vertical attacks
		if attack_direction == 1:  # up
			knockback = Vector2(dir * 0.3, -1.0).normalized()
		elif attack_direction == -1:  # down
			knockback = Vector2(dir * 0.3, 0.8).normalized()

		# Hammer has extra knockback
		if current_weapon == 4 or current_weapon == 6:
			knockback *= 1.8

		var special = wd.get("special", "")

		# Axe combo execute — 3rd hit kills non-bosses
		if special == "combo_execute":
			axe_combo += 1
			if axe_combo >= 3:
				axe_combo = 0
				if not ("is_boss" in body and body.is_boss):
					dmg = 99999  # Instant kill

		# Цепь больше НЕ цепляет при касании в ближнем бою — только прицельным
		# броском по ПКМ (см. блок chain_pull в обработке ПКМ).

		# Snake hand — poison (kills in ~5s)
		if special == "constrict":
			var already = false
			for ct in constrict_targets:
				if ct.enemy == body:
					ct.timer = 5.0  # Reset poison
					ct.stacks = mini(ct.get("stacks", 1) + 1, 5)  # стак до x5
					already = true
			if not already:
				constrict_targets.append({"enemy": body, "timer": 5.0, "tick": 1.0, "stacks": 1})

		# Death note — пометка по удару убрана: теперь запись имён по области
		# (см. _start_death_note_writing). Здесь ничего не делаем.

		# Sword & Shield combo — 3rd swing = shield bash (blocks + extra dmg)
		if special == "sword_shield_combo" and swing_index == 2:
			dmg = wd.damage * 3
			knockback *= 2.0
			shield_bash_timer = 0.5
			invincible = true
			invincible_timer = 0.5
			weapon_pickup_msg = "ЩИТ!"
			weapon_msg_timer = 0.5

		# Golden Staff combo — 3rd swing = spin AOE + 4s reflect
		if special == "golden_staff_combo" and swing_index == 2:
			var staff_room = _find_room()
			if staff_room:
				for enemy in staff_room.enemies:
					if enemy != body and is_instance_valid(enemy):
						if global_position.distance_to(enemy.global_position) < 45:
							var ekb = (enemy.global_position - global_position).normalized()
							enemy.take_damage(dmg * 2, ekb)
			dmg = wd.damage * 2
			staff_spin_timer = 4.0
			invincible = true
			invincible_timer = 4.0
			weapon_pickup_msg = "ВРАЩЕНИЕ!"
			weapon_msg_timer = 1.0

		# Torch — set enemy on fire
		if special == "fire_dot":
			var already_burning = false
			for ft in fire_targets:
				if ft.enemy == body:
					ft.timer = 10.0  # Reset fire duration
					ft.stacks = mini(ft.get("stacks", 1) + 1, 5)  # стак до x5
					already_burning = true
					break
			if not already_burning:
				fire_targets.append({"enemy": body, "timer": 10.0, "tick": 1.0, "stacks": 1})

		body.take_damage(dmg, knockback)
		_spawn_damage_number(body.global_position, dmg, is_crit)

		# === STYLE COMBO REWARD: lifesteal на ранге S+ ===
		if style_rank >= 4 and health < max_health and not ("bloody_pact" in relics):
			var ls_pct = [0.0, 0.0, 0.0, 0.0, 0.02, 0.03, 0.05, 0.08][style_rank]
			var healed = maxi(1, int(dmg * ls_pct))
			health = min(max_health, health + healed)
			health_changed.emit(health)

		# === РЕЛИКВИЯ: Клыки Вампира — 2% урона в HP ===
		if "vampire_fangs" in relics and health < max_health and not ("bloody_pact" in relics):
			var vamp = maxi(1, int(dmg * 0.02))
			health = min(max_health, health + vamp)
			health_changed.emit(health)

		# === РЕЛИКВИЯ: Удар Грома — каждый 5-й удар станит ===
		if "thunder_strike" in relics:
			_thunder_hit_count += 1
			if _thunder_hit_count >= 5:
				_thunder_hit_count = 0
				if "is_stunned" in body and "stun_timer" in body:
					body.is_stunned = true
					body.stun_timer = 2.0

		# === РЕЛИКВИЯ: Ледяной Удар — каждый 6-й удар замораживает ===
		if "frost_strike" in relics:
			_frost_hit_count += 1
			if _frost_hit_count >= 6:
				_frost_hit_count = 0
				if "frozen_timer" in body:
					body.frozen_timer = 2.0

		# === РЕЛИКВИЯ: Цепная Молния — бьёт по 2 соседним ===
		if "chain_lightning" in relics:
			var chain_room = _find_room()
			if chain_room:
				var hit_others = 0
				for other in chain_room.enemies:
					if other == body or not is_instance_valid(other):
						continue
					if body.global_position.distance_to(other.global_position) < 90.0:
						if other.has_method("take_damage"):
							other.take_damage(int(dmg * 0.5), Vector2.ZERO)
							if "shocked_timer" in other:
								other.shocked_timer = 0.8
							hit_others += 1
							if hit_others >= 2:
								break

		# Hit-stop: freeze for a few frames on hit
		# По боссам уменьшаем заморозку — длинные паузы при ударах ощущаются как "залипание"
		var is_boss_target = ("is_boss" in body and body.is_boss)
		if is_crit:
			hit_stop_timer = 0.025 if is_boss_target else 0.07
			screen_shake.emit(4.0, 0.25)
			# Crit flash: briefly tint enemy white
			if body.has_method("flash_white"):
				body.flash_white()
		else:
			hit_stop_timer = 0.012 if is_boss_target else 0.04
			screen_shake.emit(1.5, 0.1)

		# Claw grab — hold and squeeze for 3s
		if special == "grab_throw" and grab_target == null:
			grab_target = body
			grab_timer = 3.0
			weapon_pickup_msg = "ЗАХВАТ!"
			weapon_msg_timer = 1.0

		# Vampire blades: heal 10% max HP on kill
		if wd.heal_on_kill:
			if "health" in body and body.health <= 0:
				heal(int(max_health * 0.1))

		# Necromancer: +1 soul on kill
		if special == "necro_souls":
			if "health" in body and body.health <= 0:
				necro_souls += 1

		# Track kills for card bonus
		if "health" in body and body.health <= 0:
			card_kill_count += 1

		# Weapon mutations
		for mut in weapon_mutations:
			match mut:
				"poison":
					var already_p = false
					for ct in constrict_targets:
						if ct.enemy == body:
							ct.timer = 5.0
							ct.stacks = mini(ct.get("stacks", 1) + 1, 5)
							already_p = true
							break
					if not already_p:
						constrict_targets.append({"enemy": body, "timer": 5.0, "tick": 1.0, "stacks": 1})
				"fire":
					var already_f = false
					for ft in fire_targets:
						if ft.enemy == body:
							ft.timer = 8.0
							ft.stacks = mini(ft.get("stacks", 1) + 1, 5)
							already_f = true
							break
					if not already_f:
						fire_targets.append({"enemy": body, "timer": 8.0, "tick": 1.0, "stacks": 1})
				"lifesteal":
					heal(1)
				"chain":
					var r2 = _find_room()
					if r2:
						for ce in r2.enemies:
							if ce != body and is_instance_valid(ce):
								if global_position.distance_to(ce.global_position) < 80:
									ce.take_damage(int(dmg * 0.4), Vector2.ZERO)
									break

		return true
	return false

# Кэш скрипта цифры урона — компилируется ОДИН раз за сессию, не на каждый удар
static var _dmg_number_script: GDScript = null

func _spawn_damage_number(world_pos: Vector2, amount: int, crit: bool):
	var parent = get_parent()
	if not parent:
		return
	# Компилируем скрипт лишь однажды и переиспользуем
	if _dmg_number_script == null:
		_dmg_number_script = GDScript.new()
		_dmg_number_script.source_code = """
extends Node2D
var amount: int = 0
var is_crit: bool = false
var life: float = 0.75
var vel: Vector2 = Vector2(0, -55)

func _process(delta):
	life -= delta
	if life <= 0:
		queue_free()
		return
	position += vel * delta
	vel.y += 25 * delta
	queue_redraw()

func _draw():
	var a = life / 0.75
	if is_crit:
		draw_string(ThemeDB.fallback_font, Vector2(-14, 0), "КРИТ! " + str(amount),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.1, a))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-8, 0), str(amount),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.4, 0.3, a))
"""
		_dmg_number_script.reload()
	var node = Node2D.new()
	node.set_script(_dmg_number_script)
	node.set("amount", amount)
	node.set("is_crit", crit)
	node.global_position = world_pos + Vector2(randf_range(-6, 6), -20)
	parent.add_child(node)

func add_weapon_mutation():
	var possible = ["poison", "fire", "lifesteal", "explosive", "chain"]
	var available = possible.filter(func(m): return not weapon_mutations.has(m))
	if available.is_empty():
		return
	var mut = available[randi() % available.size()]
	weapon_mutations.append(mut)
	weapon_pickup_msg = "МУТАЦИЯ: " + mut.to_upper() + "!"
	weapon_msg_timer = 2.5
	if mut == "lifesteal": mutation_has_lifesteal = true
	if mut == "chain": mutation_has_chain = true
	if mut == "explosive": attack_damage += 3
	queue_redraw()

func equip_weapon(weapon_id: int):
	if weapon_id < 0 or not weapon_data.has(weapon_id):
		return
	current_weapon = weapon_id
	var wd = weapon_data[weapon_id]
	attack_damage = wd.damage
	attack_cooldown = wd.cooldown
	has_blade = weapon_id in [3, 5, 10]  # Fast weapons
	# CS-стиль: показываем имя + лейбл рарности
	var rar = wd.get("rarity", "common")
	var rar_labels = {
		"common": "[CONSUMER]", "uncommon": "[MIL-SPEC]", "rare": "[RESTRICTED]",
		"epic": "[CLASSIFIED]", "legendary": "[COVERT]", "contraband": "[★ CONTRABAND ★]",
	}
	weapon_pickup_msg = rar_labels.get(rar, "") + " " + wd.name
	weapon_msg_timer = 3.0
	# Pickup flash на весь экран — цвет по рарности
	var rar_colors = {
		"common": Color(0.78, 0.78, 0.82),
		"uncommon": Color(0.32, 0.55, 0.95),
		"rare": Color(0.55, 0.30, 0.95),
		"epic": Color(0.92, 0.30, 0.85),
		"legendary": Color(1.00, 0.20, 0.15),
		"contraband": Color(1.00, 0.85, 0.15),
	}
	for cs in get_tree().get_nodes_in_group("cs_overlay"):
		if cs.has_method("pickup_flash"):
			cs.pickup_flash(rar_colors.get(rar, Color.WHITE), 0.4)
			break
	weapon_picked.emit(rar)
	# Reset all special weapon states
	axe_combo = 0
	dart_stacks = 0
	spin_active = false
	spin_timer = 0.0
	spear_lunge = false
	spear_lunge_timer = 0.0
	chain_target = null
	chain_timer = 0.0
	chain_anim = 0.0
	is_drinking = false
	drink_timer = 0.0
	grab_target = null
	grab_timer = 0.0
	ground_slam = false
	staff_spin_timer = 0.0
	shield_bash_timer = 0.0
	is_attacking = false
	attack_timer = 0.0
	attack_anim_timer = 0.0
	can_attack = true
	attack_shape.disabled = true
	queue_redraw()

func is_parrying() -> bool:
	return is_shielding and parry_window > 0.0

func trigger_parry_flash():
	parry_flash_timer = 0.3
	screen_shake.emit(2.5, 0.15)
	queue_redraw()

func on_kill(xp_gain: int, coins_gain: int):
	# РЕЛИКВИЯ: Lucky Coin — +50% монет
	if "lucky_coin" in relics:
		coins_gain = int(coins_gain * 1.5)
	# LEVEL MODIFIER: Алчность — x2 монет
	if level_modifier == "rich_run":
		coins_gain = int(coins_gain * 2.0)
	# LEVEL MODIFIER: Сгущённый Мрак — +10 монет
	if level_modifier == "dense_dark":
		coins_gain += 10
	# LEVEL MODIFIER: Элитная Орда — x3 монет
	if level_modifier == "elite_horde":
		coins_gain = int(coins_gain * 3.0)
	# Coins with combo bonus
	var bonus = coins_gain + int(coins_gain * combo_kill_count * 0.25)
	coins += bonus
	coins_changed.emit(coins)
	# РЕЛИКВИЯ: Soul Eater — +1 макс HP за убийство
	if "soul_eater" in relics:
		max_health += 1
		health = min(health + 1, max_health)
		health_changed.emit(health)
	# Kill combo
	combo_kill_count += 1
	combo_kill_timer = combo_kill_timer_max
	card_kill_count += 1
	# Killstreak (UT-style)
	killstreak += 1
	if killstreak >= 2:
		killstreak_changed.emit(killstreak)
	# XP leveling
	xp += xp_gain
	if xp >= xp_needed:
		xp -= xp_needed
		xp_needed = int(xp_needed * 1.5)
		char_level += 1
		leveled_up.emit(_get_levelup_choices())

func _get_levelup_choices() -> Array:
	var all = [
		{"id": "damage",      "label": "+20% урон",         "desc": "Все атаки бьют сильнее"},
		{"id": "speed",       "label": "+15% скорость",      "desc": "Движение и атаки быстрее"},
		{"id": "max_hp",      "label": "+30 макс HP",        "desc": "Увеличивает максимальное здоровье"},
		{"id": "heal_charge", "label": "+1 заряд лечения",   "desc": "Дополнительный заряд исцеления"},
		{"id": "crit",        "label": "+10% крит шанс",     "desc": "Чаще наносить критические удары"},
	]
	all.shuffle()
	return all.slice(0, 3)

func apply_levelup(choice_id: String):
	match choice_id:
		"damage":
			attack_damage = int(attack_damage * 1.2)
			for key in weapon_data:
				weapon_data[key]["damage"] = int(weapon_data[key]["damage"] * 1.2)
		"speed":
			speed *= 1.15
		"max_hp":
			max_health += 30
			health = min(health + 15, max_health)
			health_changed.emit(health)
		"heal_charge":
			heal_charges += 1
		"crit":
			crit_chance += 0.10

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO):
	if invincible or is_rolling or is_dead or dash_invuln:
		return

	_break_invisibility()

	# Dodge card: passive dodge chance
	if active_card == "dodge":
		var dodge_chance = 0.25
		if current_weapon == 3 or current_weapon == 5:  # dual blades
			dodge_chance = 0.40
		if randf() < dodge_chance:
			# Dodged! Show effect
			weapon_pickup_msg = "УВОРОТ!"
			weapon_msg_timer = 0.8
			return

	# Speed boots: +5% more damage taken
	if active_card == "speed_boots":
		amount = int(amount * 1.05)

	# Spike reduction card
	if card_thorn_reduction > 0:
		if knockback_dir.y < -0.5:
			amount = int(amount * (1.0 - card_thorn_reduction))
			if amount < 1:
				amount = 1

	# РЕЛИКВИЯ: Железная Кожа — −25% урона
	if "iron_skin" in relics:
		amount = maxi(1, int(amount * 0.75))
	# LEVEL MODIFIER множитель получаемого урона
	if taken_damage_mult != 1.0:
		amount = maxi(1, int(amount * taken_damage_mult))

	health -= amount
	health_changed.emit(health)
	damage_flash_timer = 0.35
	queue_redraw()

	# CS: ломаем стрик и трекаем урон для ACE
	if killstreak > 0:
		killstreak = 0
		killstreak_reset.emit()
	room_damage_taken += amount
	# BHOP: получили урон — сброс комбо
	if bhop_stacks > 0:
		_reset_bhop_combo("hit")

	velocity = knockback_dir * 140
	velocity.y = -120
	move_and_slide()

	invincible = true
	invincible_timer = 0.8

	if health <= 0:
		# РЕЛИКВИЯ: Перо Феникса — воскрешение
		if "phoenix_feather" in relics and not _phoenix_used:
			_phoenix_used = true
			health = int(max_health * 0.5)
			health_changed.emit(health)
			invincible = true
			invincible_timer = 3.0
			weapon_pickup_msg = "ПЕРО ФЕНИКСА!"
			weapon_msg_timer = 2.0
			return
		# Second chance card: revive once
		if card_second_chance and not card_second_chance_used:
			card_second_chance_used = true
			health = int(max_health * 0.5)
			health_changed.emit(health)
			invincible = true
			invincible_timer = 3.0
			weapon_pickup_msg = "ВТОРОЙ ШАНС!"
			weapon_msg_timer = 2.0
			# Stun all nearby enemies
			var revive_room = _find_room()
			if revive_room:
				for enemy in revive_room.enemies:
					if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < 120:
						if "is_stunned" in enemy:
							enemy.is_stunned = true
							enemy.stun_timer = 5.0
			return
		is_dead = true
		died.emit()

func _get_aim_direction() -> Vector2:
	# На ПК луки и AWP наводятся МЫШКОЙ — стреляем в сторону курсора.
	if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
		var to_mouse := get_global_mouse_position() - (global_position + Vector2(0, -10))
		if to_mouse.length() > 4.0:
			return to_mouse.normalized()
	# Телефон / нет мыши: 8-направленное прицеливание (WASD/джойстик) или взгляд.
	var aim := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		aim.y -= 1.0
	if Input.is_action_pressed("move_down"):
		aim.y += 1.0
	if Input.is_action_pressed("move_left"):
		aim.x -= 1.0
	if Input.is_action_pressed("move_right"):
		aim.x += 1.0
	if aim == Vector2.ZERO:
		aim.x = 1.0 if facing_right else -1.0
	return aim.normalized()

func _do_ranged_attack(special: String):
	_break_invisibility()
	can_attack = false
	var wd = weapon_data.get(current_weapon, weapon_data[1])
	var cd = wd.cooldown
	if special == "dart_throw":
		cd = maxf(0.15, cd - dart_stacks * 0.01)  # Slightly faster, min 0.15
	attack_timer = cd

	var dir = _get_aim_direction()
	var projectile_script_ref = preload("res://scripts/projectile.gd")

	match special:
		"warp_arrow":
			# Shoot arrow forward
			_spawn_player_proj(dir, wd.damage, projectile_script_ref)
			# Shoot second arrow from behind the nearest enemy
			var room = _find_room()
			if room:
				var closest_enemy = null
				var closest_dist = INF
				for enemy in room.enemies:
					if is_instance_valid(enemy):
						var edist = global_position.distance_to(enemy.global_position)
						if edist < 300 and edist < closest_dist:
							# Только враги в направлении прицела (конус ~60°)
							var to_enemy = (enemy.global_position - global_position).normalized()
							if to_enemy.dot(dir) > 0.5:
								closest_dist = edist
								closest_enemy = enemy
				if closest_enemy:
					# Spawn arrow behind the enemy, shooting toward the enemy
					var behind_pos = closest_enemy.global_position + (-dir * 40)
					var toward_enemy = (closest_enemy.global_position - behind_pos).normalized()
					var proj2 = Area2D.new()
					proj2.set_script(projectile_script_ref)
					proj2.projectile_type = 0
					proj2.direction = toward_enemy
					proj2.damage = wd.damage
					proj2.speed = 250
					proj2.is_player_projectile = true
					proj2.gravity_affect = 5.0
					proj2.global_position = behind_pos
					proj2.rotation = toward_enemy.angle()
					get_parent().add_child(proj2)
		"triple_arrow":
			# 3 arrows: up-angled, straight(skip middle), down-angled
			_spawn_player_proj(dir.rotated(-0.3), wd.damage, projectile_script_ref)
			_spawn_player_proj(dir, wd.damage, projectile_script_ref)
			_spawn_player_proj(dir.rotated(0.3), wd.damage, projectile_script_ref)
		"dart_throw":
			_spawn_dart(dir, wd.damage, projectile_script_ref)
		"necro_souls":
			# LMB always shoots 1 soul projectile
			_spawn_player_proj(dir, wd.damage, projectile_script_ref)
		"sniper":
			# AWP — мгновенный луч-снаряд с гигантской дальностью + сильная отдача
			_spawn_sniper_shot(dir, projectile_script_ref)
			# Отдача камеры
			screen_shake.emit(7.0, 0.20)

func _spawn_sniper_shot(dir: Vector2, proj_script):
	var proj = Area2D.new()
	proj.set_script(proj_script)
	proj.projectile_type = 0  # arrow visual
	proj.direction = dir.normalized()
	proj.damage = 9999            # one-shot (бронебойка)
	proj.speed = 1800             # фактически луч — мгновенный
	proj.is_player_projectile = true
	proj.gravity_affect = 0.0     # летит строго прямо
	proj.lifetime = 1.2
	proj.global_position = global_position + Vector2(0, -10) + dir.normalized() * 14
	proj.rotation = dir.angle()
	get_parent().add_child(proj)

func _spawn_dart(dir: Vector2, dmg: int, proj_script):
	var proj = Area2D.new()
	proj.set_script(proj_script)
	proj.projectile_type = 0
	proj.direction = dir.normalized()
	proj.damage = dmg
	proj.speed = 280 + dart_stacks * 15  # Faster per stack
	proj.is_player_projectile = true
	proj.gravity_affect = 2.0  # Very flat trajectory
	proj.lifetime = 3.0 + dart_stacks * 0.3  # Longer range per stack
	proj.global_position = global_position + Vector2(0, -10) + dir.normalized() * 12
	proj.rotation = dir.angle()
	get_parent().add_child(proj)

func _necro_soul_burst():
	_break_invisibility()
	can_attack = false
	var wd = weapon_data.get(current_weapon, weapon_data[1])
	attack_timer = 1.5  # Longer cooldown for burst
	var projectile_script_ref = preload("res://scripts/projectile.gd")
	var count = necro_souls
	for si in count:
		var angle = (float(si) / float(count)) * TAU
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_player_proj(dir, wd.damage, projectile_script_ref)
	weapon_pickup_msg = str(count) + " ДУШ!"
	weapon_msg_timer = 1.5
	necro_souls = 1  # Reset to 1 base soul

func _spawn_player_proj(dir: Vector2, dmg: int, proj_script):
	var proj = Area2D.new()
	proj.set_script(proj_script)
	proj.projectile_type = 0  # arrow type visual
	proj.direction = dir.normalized()
	proj.damage = dmg
	proj.speed = 250
	proj.is_player_projectile = true
	proj.gravity_affect = 5.0  # Player projectiles fly straighter
	proj.global_position = global_position + Vector2(0, -10) + dir.normalized() * 12
	proj.rotation = dir.angle()
	get_parent().add_child(proj)

func _spin_hit_nearby(hit_range: float):
	# Hit all enemies in range every 0.3s
	if fmod(spin_timer, 0.3) > 0.15:
		return
	var room = _find_room()
	if not room:
		return
	for enemy in room.enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < hit_range:
			var kb = (enemy.global_position - global_position).normalized()
			enemy.take_damage(weapon_data[17].damage, kb)

func _cycle_active_item():
	var total = scrolls.size() + (1 if active_card != "" else 0)
	if total == 0:
		return
	active_item_slot = (active_item_slot + 1) % total
	queue_redraw()
	# Show what's selected
	var names = {"dash": "Рывок", "kick": "Удар ногой", "speed_boost": "Ускорение", "choke": "Удушение", "slide": "Подкат"}
	var card_display = {"invisibility": "Невидимость", "death_jar": "Банка Смерти", "throw_weapon": "Бросок оружия",
		"speed_boots": "Ботинки Скорости", "dodge": "Уворот", "backstab": "Удар в Спину",
		"acid_water": "Кислотная Вода", "thorn_armor": "Шипастая Броня", "close_combat": "Ближний Бой",
		"berserker": "Берсерк", "hunter": "Охотник", "critical": "Крит. Удар", "second_chance": "Второй Шанс"}
	if active_item_slot < scrolls.size():
		weapon_pickup_msg = "► " + names.get(scrolls[active_item_slot], scrolls[active_item_slot])
	else:
		weapon_pickup_msg = "► " + card_display.get(active_card, active_card)
	weapon_msg_timer = 0.8

func _use_active_item():
	var total = scrolls.size() + (1 if active_card != "" else 0)
	if total == 0:
		return
	# Clamp slot in case inventory shrank
	if active_item_slot >= total:
		active_item_slot = 0
	if active_item_slot < scrolls.size():
		_use_scroll(active_item_slot)
	else:
		_use_card_active()

func _use_card_active():
	match active_card:
		"death_jar":
			if death_jar_charges <= 0:
				weapon_pickup_msg = "Банка пуста!"
				weapon_msg_timer = 0.8
				return
			death_jar_charges -= 1
			# Throw a poison splash in facing direction
			var dir = Vector2(1 if facing_right else -1, -0.3).normalized()
			var room = _find_room()
			if room:
				for enemy in room.enemies:
					if is_instance_valid(enemy):
						var d = global_position.distance_to(enemy.global_position)
						var ex_dir = (enemy.global_position - global_position).normalized()
						if d < 100 and ex_dir.dot(dir) > 0.3:
							enemy.take_damage(25, dir)
							if enemy.has_method("apply_poison"):
								enemy.apply_poison(5.0)
			weapon_pickup_msg = "Банка брошена! (осталось %d)" % death_jar_charges
			weapon_msg_timer = 1.0
			screen_shake.emit(1.5, 0.1)
		"throw_weapon":
			if throw_weapon_cooldown > 0:
				weapon_pickup_msg = "КД: %.1f" % throw_weapon_cooldown
				weapon_msg_timer = 0.5
			elif current_weapon > 0:
				_throw_current_weapon()
		_:
			weapon_pickup_msg = "Пассивный эффект"
			weapon_msg_timer = 0.6

func pickup_scroll(scroll_id: String):
	if scrolls.size() >= max_scrolls:
		weapon_pickup_msg = "СВИТКИ ПОЛНЫ (макс 2)"
		weapon_msg_timer = 1.5
		return
	scrolls.append(scroll_id)
	scroll_cooldowns[scroll_id] = 0.0
	var scroll_names = {"dash": "РЫВОК", "kick": "УДАР НОГОЙ", "speed_boost": "УСКОРЕНИЕ", "choke": "УДУШЕНИЕ", "slide": "ПОДКАТ"}
	weapon_pickup_msg = "СВИТОК: " + scroll_names.get(scroll_id, scroll_id)
	weapon_msg_timer = 2.0

func _use_next_scroll():
	# Использует первый свиток не на кулдауне (удобная одна кнопка X / СВИТ).
	if scrolls.is_empty():
		weapon_pickup_msg = "Нет свитков"
		weapon_msg_timer = 0.6
		return
	for i in scrolls.size():
		var sid = scrolls[i]
		if scroll_cooldowns.get(sid, 0.0) <= 0.0:
			_use_scroll(i)
			return
	# Все на кулдауне — покажем минимальный КД
	var best := 99.0
	for sid in scrolls:
		best = minf(best, scroll_cooldowns.get(sid, 0.0))
	weapon_pickup_msg = "Свитки на КД: %.1f" % best
	weapon_msg_timer = 0.6

func _use_scroll(slot: int):
	if slot >= scrolls.size():
		return
	var sid = scrolls[slot]
	if scroll_cooldowns.get(sid, 0.0) > 0:
		weapon_pickup_msg = "КД: %.1f" % scroll_cooldowns[sid]
		weapon_msg_timer = 0.5
		return

	var scroll_room = _find_room()
	match sid:
		"dash":
			# Dash forward/back, AOE damage x2 to enemies hit
			scroll_cooldowns[sid] = 8.0
			scroll_dash_active = true
			scroll_dash_timer = 0.25
			var dash_dir = 1.0 if facing_right else -1.0
			velocity.x = dash_dir * 500
			velocity.y = -50
			invincible = true
			invincible_timer = 0.3
			# Hit enemies along dash path
			if scroll_room:
				for enemy in scroll_room.enemies:
					if is_instance_valid(enemy):
						var ex = enemy.global_position.x
						var dist_y = abs(enemy.global_position.y - global_position.y)
						var in_path = false
						if dash_dir > 0:
							in_path = ex > global_position.x and ex < global_position.x + 100
						else:
							in_path = ex < global_position.x and ex > global_position.x - 100
						if in_path and dist_y < 25:
							var kb = (enemy.global_position - global_position).normalized()
							enemy.take_damage(attack_damage * 2, kb)
		"kick":
			# Kick pushback 6 blocks (96px), shieldmen 3 blocks, bosses immune
			scroll_cooldowns[sid] = 4.0
			if scroll_room:
				var nearest = null
				var nearest_dist = 30.0
				for enemy in scroll_room.enemies:
					if is_instance_valid(enemy):
						var d = global_position.distance_to(enemy.global_position)
						if d < nearest_dist:
							nearest = enemy
							nearest_dist = d
				if nearest:
					var kick_dir = 1.0 if nearest.global_position.x > global_position.x else -1.0
					var push_px = 96.0
					if "is_boss" in nearest and nearest.is_boss:
						push_px = 0  # Bosses immune
					elif nearest.enemy_class == 3:  # SHIELDMAN
						push_px = 48.0  # 3 blocks
					nearest.velocity.x = kick_dir * push_px * 8
					nearest.velocity.y = -80
					nearest.take_damage(10, Vector2(kick_dir, -0.3).normalized())
					weapon_pickup_msg = "УДАР!"
					weapon_msg_timer = 0.5
		"speed_boost":
			# Speed +80% for 10s
			scroll_cooldowns[sid] = 20.0
			scroll_speed_active = true
			scroll_speed_timer = 10.0
			weapon_pickup_msg = "УСКОРЕНИЕ!"
			weapon_msg_timer = 1.0
		"choke":
			# Silent strangle nearest enemy within 30px from behind, 3s kill
			scroll_cooldowns[sid] = 4.0
			if scroll_room:
				var best = null
				var best_d = 30.0
				for enemy in scroll_room.enemies:
					if is_instance_valid(enemy):
						var d = global_position.distance_to(enemy.global_position)
						if d < best_d:
							# Check if behind enemy
							var behind = (enemy.facing_right and global_position.x > enemy.global_position.x) or \
								(not enemy.facing_right and global_position.x < enemy.global_position.x)
							if behind:
								best = enemy
								best_d = d
				if best:
					scroll_choke_target = best
					scroll_choke_timer = 3.0
					weapon_pickup_msg = "УДУШЕНИЕ..."
					weapon_msg_timer = 1.0
				else:
					weapon_pickup_msg = "НУЖНО СЗАДИ!"
					weapon_msg_timer = 1.0
					scroll_cooldowns[sid] = 0.0  # Don't waste CD
		"slide":
			# Slide tackle, knockdown + 3s stun
			scroll_cooldowns[sid] = 10.0
			scroll_slide_active = true
			scroll_slide_timer = 0.3
			var slide_dir = 1.0 if facing_right else -1.0
			velocity.x = slide_dir * 350
			velocity.y = 0
			# Shrink hitbox
			body_collision.shape.size = Vector2(10, 10)
			body_collision.position = Vector2(0, -5)
			if scroll_room:
				for enemy in scroll_room.enemies:
					if is_instance_valid(enemy):
						var d = global_position.distance_to(enemy.global_position)
						if d < 50 and "is_stunned" in enemy:
							enemy.is_stunned = true
							enemy.stun_timer = 3.0
							enemy.take_damage(10, Vector2(slide_dir, -0.5).normalized())

func _ground_slam_hit():
	var slam_room = _find_room()
	if not slam_room:
		return
	var slam_range = 50.0
	for enemy in slam_room.enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < slam_range:
			var kb = (enemy.global_position - global_position).normalized()
			kb.y = -0.5
			enemy.take_damage(15, kb)

func _throw_current_weapon():
	var wd = weapon_data.get(current_weapon, weapon_data[1])
	var dir = Vector2(1, 0) if facing_right else Vector2(-1, 0)
	var proj_script_ref = preload("res://scripts/projectile.gd")
	var proj = Area2D.new()
	proj.set_script(proj_script_ref)
	proj.projectile_type = 2  # HAMMER visual — spinning
	proj.direction = dir
	proj.damage = wd.damage * 2  # Double damage when thrown
	proj.speed = 200
	proj.is_player_projectile = true
	proj.gravity_affect = 80.0
	proj.rotation_speed = 10.0
	proj.global_position = global_position + Vector2(0, -10) + dir * 10
	proj.rotation = dir.angle()
	get_parent().add_child(proj)
	throw_weapon_cooldown = 3.0
	weapon_pickup_msg = "БРОСОК!"
	weapon_msg_timer = 1.0

func _break_invisibility():
	if active_card == "invisibility":
		invis_break_timer = 4.0
		is_invisible = false

func apply_poison(duration: float, dmg_per_tick: float):
	poison_timer = duration
	poison_damage = dmg_per_tick
	poison_tick_timer = 0.5

func apply_net(duration: float):
	is_netted = true
	net_timer = duration

func apply_worm_infection():
	worm_count = mini(worm_count + 1, 3)  # max 3 stacks
	worm_timer = 5.0                       # each new bite resets 5 sec duration
	worm_tick_timer = 3.0
	queue_redraw()

func start_web(duration: float):
	if is_webbed:
		return  # Don't restart if already webbed
	is_webbed = true
	web_timer = duration
	web_cursor = 0.0
	web_cursor_dir = 1.0
	web_success_count = 0
	# Randomize the target zone position each time
	web_target_start = randf_range(0.1, 1.0 - WEB_TARGET_W - 0.1)

func heal(amount: int):
	# РЕЛИКВИЯ: Кровавый Пакт — лечение заблокировано
	if "bloody_pact" in relics:
		return
	health = min(health + amount, max_health)
	health_changed.emit(health)

func apply_level_modifier(mod_id: String):
	# Применяется в начале уровня. Сбрасывается при загрузке нового.
	level_modifier = mod_id
	damage_mult = 1.0
	taken_damage_mult = 1.0
	match mod_id:
		"berserk":
			damage_mult = 1.5
			max_health = int(max_health * 0.7)
			health = min(health, max_health)
		"lightspeed":
			speed *= 1.4
		"rich_run":
			pass  # монеты x2 обрабатывается в on_kill
		"double_or_nothing":
			damage_mult = 2.0
			taken_damage_mult = 2.0
		"iron_walls":
			pass  # обработка в take_damage
		"blood_pact_level":
			damage_mult = 1.25
		"dense_dark":
			pass  # обработка свет в main.gd
		"elite_horde":
			pass  # обработка в room (все элиты)
		"glass_cannon":
			damage_mult = 3.0
			max_health = 1
			health = 1
		"no_modifier":
			pass

func add_relic(rid: String):
	if rid in relics:
		return
	relics.append(rid)
	# Мгновенные эффекты при подборе
	match rid:
		"feather_boots":
			speed *= 1.15
			# +1 чардж даша делается через main.gd (DASH_MAX_CHARGES — const)
		"swift_blade":
			attack_cooldown *= 0.75
		"crit_master":
			crit_chance += 0.20
		"ghost_step":
			# −1 сек cd даша применит main.gd через DASH_RECHARGE_TIME
			pass
		"bomb_pouch":
			# Гранаты убраны — перк теперь даёт немного скорости.
			speed *= 1.05

var dbg_draw_ms: float = 0.0

func _draw():
	var _pdt0 := Time.get_ticks_usec()
	_draw_body2()
	dbg_draw_ms = (Time.get_ticks_usec() - _pdt0) / 1000.0

func _draw_body2():
	# ── Acid trail: 3 RGB-ghost копии следа за движением ──
	for tr in _acid_trail:
		var life_frac = tr.life / tr.max_life
		var local_pos = tr.pos - global_position
		var a = life_frac * 0.40
		# Красный сдвиг
		draw_rect(Rect2(local_pos.x - 4, local_pos.y - 18, 8, 16),
			Color(1.0, 0.20, 0.45, a * 0.65))
		# Зелёный
		draw_rect(Rect2(local_pos.x - 4 + 3, local_pos.y - 18, 8, 16),
			Color(0.20, 1.0, 0.55, a * 0.55))
		# Синий
		draw_rect(Rect2(local_pos.x - 4 - 3, local_pos.y - 18, 8, 16),
			Color(0.30, 0.55, 1.0, a * 0.55))

	# ── Soft shadow под ногами (овальное затемнение пола) ──
	if not is_dead and is_on_floor():
		var pts = PackedVector2Array()
		var segs = 14
		var rx = 9.0
		var ry = 2.5
		for s in segs:
			var a = float(s) / segs * TAU
			pts.append(Vector2(cos(a) * rx, 1.5 + sin(a) * ry))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.35))

	# ── Game-feel частицы: пыль приземления, шаги ──
	for fp in feel_particles:
		var lf = fp.life / fp.max_life
		var a = clampf(lf * 1.4, 0.0, 1.0) * 0.6
		var sz = fp.size * (0.5 + lf * 0.5)
		draw_circle(fp.pos, sz, Color(fp.color.r, fp.color.g, fp.color.b, a))

	# ── Атмосферные искры вокруг игрока (мерцают, поднимаются) ──
	for sp in aura_sparks:
		var life_frac = sp.life / sp.max_life
		var fade_in = clampf((1.0 - life_frac) / 0.2, 0.0, 1.0)
		var fade_out = clampf(life_frac / 0.4, 0.0, 1.0)
		var a = fade_in * fade_out * 0.75
		# Glow
		draw_circle(sp.offset, 2.5,
			Color(sp.color.r, sp.color.g, sp.color.b, a * 0.25))
		# Core
		draw_circle(sp.offset, 1.0,
			Color(sp.color.r, sp.color.g, sp.color.b, a * 0.95))
		# Bright center
		draw_circle(sp.offset, 0.5,
			Color(1, 1, 1, a))

	# ── Inspect: подсвечиваем оружие в воздухе если в режиме инспекта ──
	if is_inspecting and not is_dead:
		var wd_in = weapon_data.get(current_weapon, {})
		var blade_len = wd_in.get("blade_len", 22)
		var w_col = wd_in.get("color", Color.WHITE)
		var spin = (INSPECT_DURATION - inspect_anim_timer) * 4.0  # 4 оборота за анимацию
		var lift_y = -30.0 + sin((INSPECT_DURATION - inspect_anim_timer) * 3.0) * 4.0
		draw_set_transform(Vector2(0, lift_y), spin, Vector2.ONE)
		# Лёгкое свечение
		var glow_col = wd_in.get("glow", Color(1, 1, 1, 0))
		draw_circle(Vector2.ZERO, blade_len * 1.0,
			Color(glow_col.r, glow_col.g, glow_col.b, glow_col.a * 0.55))
		# Клинок
		draw_rect(Rect2(-blade_len * 0.5, -2, blade_len, 4), w_col)
		# Рукоять
		draw_rect(Rect2(blade_len * 0.5 - 3, -3, 3, 6), Color(0.45, 0.30, 0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── Индикатор прицела для дальнобойного оружия (луки/дротик) ──
	if not is_dead and not is_knocked_out:
		var wd_aim = weapon_data.get(current_weapon, {})
		var sp_aim = wd_aim.get("special", "")
		if sp_aim in ["warp_arrow", "triple_arrow", "dart_throw", "necro_souls", "chain_pull"]:
			var aim_dir = _get_aim_direction()
			var start = Vector2(0, -10)
			var aim_color = Color(1.0, 0.85, 0.3, 0.55)
			# Пунктирная линия прицела (5 коротких сегментов)
			for i in 5:
				var p1 = start + aim_dir * (8 + i * 8)
				var p2 = start + aim_dir * (12 + i * 8)
				draw_line(p1, p2, aim_color, 1.0)
			# Маленький треугольник-стрелка на конце
			var tip = start + aim_dir * 50
			var perp = Vector2(-aim_dir.y, aim_dir.x)
			var t1 = tip
			var t2 = tip - aim_dir * 5 + perp * 3
			var t3 = tip - aim_dir * 5 - perp * 3
			draw_colored_polygon(PackedVector2Array([t1, t2, t3]), aim_color)

	# ── Анимированная ЦЕПЬ до зацепленного врага ──
	if chain_target and is_instance_valid(chain_target) and not is_dead:
		var hand := Vector2(0, -10)
		var tgt := chain_target.global_position - global_position + Vector2(0, -8)
		var reach := clampf(chain_anim / 0.16, 0.0, 1.0)   # выброс цепи к цели
		var endp := hand.lerp(tgt, reach)
		var dir_n := (endp - hand)
		if dir_n.length() > 1.0:
			dir_n = dir_n.normalized()
		else:
			dir_n = Vector2(1, 0)
		var perp := Vector2(-dir_n.y, dir_n.x)
		var wob := (1.0 - reach) * 5.0                     # дрожь при броске
		var segs := 8
		var prev := hand
		for i in range(1, segs + 1):
			var t := float(i) / segs
			var p := hand.lerp(endp, t)
			p += perp * sin(t * PI) * wob * (1.0 if (i % 2 == 0) else -1.0)
			draw_line(prev, p, Color(0.52, 0.54, 0.60), 2.5)   # тёмное звено
			draw_circle(p, 1.7, Color(0.74, 0.76, 0.82))       # блик звена
			prev = p
		draw_circle(endp, 3.2, Color(0.88, 0.89, 0.94))        # металлический крюк

	# ── Анимация питья зелья ──
	if is_drinking and not is_dead:
		var prog := 1.0 - clampf(drink_timer / DRINK_TIME, 0.0, 1.0)  # 0→1
		var side := 1.0 if facing_right else -1.0
		# Рука поднимает бутылку ко рту, наклон растёт по мере питья.
		var tilt := -0.5 - prog * 0.8
		draw_set_transform(Vector2(4.0 * side, -18.0), tilt * side, Vector2.ONE)
		# Бутылочка
		draw_rect(Rect2(-2.5, -7, 5, 9), Color(0.25, 0.55, 0.85, 0.9))   # стекло
		draw_rect(Rect2(-1.5, -10, 3, 3), Color(0.45, 0.32, 0.18))       # горлышко/пробка
		# Остаток зелья убывает
		var liq := (1.0 - prog) * 7.0
		draw_rect(Rect2(-2.0, 2 - liq, 4, liq), Color(0.95, 0.25, 0.35, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Кольцо прогресса над головой
		var cseg := 20
		var ring := PackedVector2Array()
		for i in range(int(cseg * prog) + 1):
			var a := -PI / 2 + float(i) / cseg * TAU
			ring.append(Vector2(0, -30) + Vector2(cos(a), sin(a)) * 5.0)
		for i in range(1, ring.size()):
			draw_line(ring[i - 1], ring[i], Color(0.4, 1.0, 0.5, 0.9), 1.6)

	# ── Knocked-out by mimic ──
	if is_knocked_out:
		var frac = clampf(knockdown_timer, 0.0, 1.0)  # 1=flat, 0=standing
		if frac > 0.35:
			# Lying flat — rotated 90°
			draw_set_transform(Vector2(0.0, -4.0), deg_to_rad(90.0), Vector2(1.0, 1.0))
			draw_rect(Rect2(-12, -5,  24, 10), Color(0.35, 0.35, 0.40))  # body
			draw_rect(Rect2(-13, -5,   8,  7), Color(0.90, 0.75, 0.55))  # head
			draw_rect(Rect2(-14, -6,  10,  4), Color(0.50, 0.50, 0.55))  # helmet
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			# Getting up — tilt back to vertical over 0.35s
			var angle = deg_to_rad(90.0) * (frac / 0.35)
			draw_set_transform(Vector2(0.0, -4.0), angle, Vector2(1.0, 1.0))
			draw_rect(Rect2(-5, -18, 10, 22), Color(0.35, 0.35, 0.40))
			draw_rect(Rect2(-4, -22,  8,  7), Color(0.90, 0.75, 0.55))
			draw_rect(Rect2(-5, -24, 10,  4), Color(0.50, 0.50, 0.55))
			draw_rect(Rect2(-3,  -21,  2,  1), Color(0.35, 0.65, 0.95))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# Sword trail
	for i in range(1, sword_trail.size()):
		var a1 = sword_trail[i - 1]["life"] / sword_trail[i - 1]["max_life"]
		var a2 = sword_trail[i]["life"] / sword_trail[i]["max_life"]
		var p1 = to_local(sword_trail[i - 1]["pos"])
		var p2 = to_local(sword_trail[i]["pos"])
		var gc = sword_trail[i]["col"]
		var alpha = (a1 + a2) * 0.35
		draw_line(p1, p2, Color(gc.r, gc.g, gc.b, alpha), 3.0 * a2 + 0.5)

	# Parry flash — gold burst when parry succeeds
	if parry_flash_timer > 0:
		var pf = parry_flash_timer / 0.3
		draw_circle(Vector2(0, -10), 18 * pf, Color(1, 0.9, 0.2, pf * 0.5))
		for i in 6:
			var ang = i * TAU / 6
			var r = 20 * pf
			draw_line(Vector2(0, -10), Vector2(cos(ang) * r, -10 + sin(ang) * r),
				Color(1, 0.9, 0.2, pf * 0.8), 2.0)

	# Draw dust particles (world-space positions converted to local)
	for dp in dust_particles:
		var a = dp["life"] / dp["max_life"]
		var lpos = to_local(dp["pos"])
		draw_circle(lpos, dp["size"] * a, Color(0.7, 0.6, 0.45, a * 0.6))

	# Net trap visual — mesh over player
	if is_netted:
		var alpha = 0.7
		# Net mesh lines
		for i in 5:
			var y = -20 + i * 5
			draw_line(Vector2(-8, y), Vector2(8, y), Color(0.5, 0.4, 0.3, alpha), 1.0)
		for i in 4:
			var x = -8 + i * 5
			draw_line(Vector2(x, -20), Vector2(x, 2), Color(0.5, 0.4, 0.3, alpha), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-8, -26),
			"СЕТЬ", HORIZONTAL_ALIGNMENT_CENTER, -1, 6, Color(0.9, 0.6, 0.3, 0.9))
		var time_left = "%.1f" % net_timer
		draw_string(ThemeDB.fallback_font, Vector2(-6, -2),
			time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 6, Color(1, 0.5, 0.3))

	# Spider web trap visual + minigame bar
	if is_webbed:
		# Web threads covering player
		for wi in 10:
			var wa = (float(wi) / 10.0) * TAU
			var wr = 8.0 + sin(wa * 3) * 3.0
			draw_line(Vector2(0, -11), Vector2(cos(wa) * wr, -11 + sin(wa) * wr), Color(0.88, 0.88, 0.96, 0.55), 0.7)
		# Crosshatch web
		for wj in 4:
			var wy = -18 + wj * 5
			draw_line(Vector2(-10, wy), Vector2(10, wy), Color(0.88, 0.88, 0.96, 0.4), 0.6)
		for wk in 4:
			var wx = -9 + wk * 6
			draw_line(Vector2(wx, -20), Vector2(wx, 2), Color(0.88, 0.88, 0.96, 0.4), 0.6)
		# Minigame bar (above player)
		var bw = WEB_BAR_W
		var bx = -bw / 2.0
		var by = -52.0
		# Bar background
		draw_rect(Rect2(bx - 1, by - 1, bw + 2, 12), Color(0.05, 0.05, 0.1, 0.85))
		draw_rect(Rect2(bx, by, bw, 10), Color(0.2, 0.15, 0.3, 0.9))
		# Target zone (bright green)
		draw_rect(Rect2(bx + web_target_start * bw, by, WEB_TARGET_W * bw, 10), Color(0.15, 0.9, 0.2, 0.85))
		# Cursor line
		var cx = bx + web_cursor * bw
		draw_line(Vector2(cx, by - 3), Vector2(cx, by + 13), Color(1, 1, 1, 1.0), 2.5)
		# Success dots below bar
		for di in 3:
			var dot_c = Color(0.15, 0.9, 0.2, 1.0) if di < web_success_count else Color(0.3, 0.3, 0.4, 0.7)
			draw_circle(Vector2(bx + bw * 0.5 - 12 + di * 12, by + 17), 4.0, dot_c)
		# Timer bar
		var time_frac = web_timer / 4.0
		draw_rect(Rect2(bx, by - 5, bw * time_frac, 2), Color(0.8, 0.3, 0.9, 0.8))
		# Label
		draw_string(ThemeDB.fallback_font, Vector2(bx, by - 11),
			"ПАУТИНА  [ПРОБЕЛ] чтобы вырваться",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.9, 0.8, 1.0, 0.95))

	# Worm infection visual
	if worm_count > 0:
		var wt = worm_phase
		for wi in worm_count * 2:
			var wx = sin(wt + wi * 1.3) * 5 + (wi - worm_count) * 3.0
			var wy_base = -4 - wi * 2.5
			var wy = wy_base + cos(wt * 1.1 + wi) * 2
			var wa = 0.6 + sin(wt + wi) * 0.3
			draw_circle(Vector2(wx, wy), 1.8, Color(0.65, 0.82, 0.2, wa))
			draw_line(Vector2(wx, wy), Vector2(wx + sin(wt + wi) * 4, wy - 3),
				Color(0.55, 0.72, 0.15, wa * 0.7), 1.0)
		# Worm count text
		if worm_count > 1:
			draw_string(ThemeDB.fallback_font, Vector2(-10, -36),
				"×%d черви" % worm_count,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.7, 0.9, 0.2, 0.9))

	# Poison DOT visual — green tint
	if poison_timer > 0:
		draw_circle(Vector2(0, -10), 12, Color(0.1, 0.8, 0.1, 0.1))
		var pt = poison_timer * 4
		for i in 3:
			var bx = sin(pt + i * 2) * 6
			var by = -5 - i * 5 - fmod(pt, 1.0) * 4
			draw_circle(Vector2(bx, by), 1.5, Color(0.2, 0.9, 0.1, 0.6))

	# Golden Staff spin visual — rotating circle
	if staff_spin_timer > 0:
		var t = Time.get_ticks_msec() * 0.008
		var spin_alpha = min(staff_spin_timer / 4.0, 1.0) * 0.4
		draw_circle(Vector2(0, -10), 30, Color(1, 0.9, 0.3, spin_alpha * 0.3))
		for si in 6:
			var sa = t + si * TAU / 6
			var sx = cos(sa) * 25
			var sy = -10 + sin(sa) * 8
			draw_circle(Vector2(sx, sy), 3, Color(1, 0.95, 0.5, spin_alpha))
		# Reflect text
		var blink = 0.5 + sin(t * 3) * 0.5
		draw_string(ThemeDB.fallback_font, Vector2(-20, -30),
			"ОТРАЖЕНИЕ", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(1, 0.9, 0.3, blink))

	# Shield bash visual
	if shield_bash_timer > 0:
		var s = 1 if facing_right else -1
		draw_rect(Rect2(s * 8, -20, s * 6, 16), Color(0.9, 0.85, 0.5, 0.7))
		draw_rect(Rect2(s * 9, -18, s * 4, 12), Color(1, 0.95, 0.6, 0.5))
		draw_string(ThemeDB.fallback_font, Vector2(-10, -26),
			"БЛОК!", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(1, 0.9, 0.4, 0.9))

	# Ground slam visual — downward streaks
	if ground_slam:
		for i in 4:
			var sx = randf_range(-6, 6)
			draw_line(Vector2(sx, -20), Vector2(sx, 5), Color(1, 0.8, 0.3, 0.6), 1.5)
		draw_circle(Vector2(0, 0), 8, Color(1, 0.6, 0.2, 0.3))

	# Invisibility visual
	if is_invisible:
		modulate.a = 0.3
	elif modulate.a < 1.0 and not is_rolling:
		modulate.a = 1.0

	# Active card indicator (top-left of player)
	if active_card != "":
		var card_col = Color(0.5, 0.5, 0.5, 0.4)
		match active_card:
			"invisibility": card_col = Color(0.3, 0.8, 1.0, 0.4)
			"death_jar": card_col = Color(0.2, 0.9, 0.1, 0.4)
			"throw_weapon": card_col = Color(1.0, 0.6, 0.2, 0.4)
			"speed_boots": card_col = Color(1.0, 1.0, 0.3, 0.4)
			"dodge": card_col = Color(0.8, 0.4, 1.0, 0.4)
		draw_circle(Vector2(-8, -24), 3, card_col)

	# Stun visual effect — stars around head
	if is_stunned:
		var t = stun_timer * 5
		for i in 5:
			var angle = t + i * TAU / 5
			var sx = cos(angle) * 10
			var sy = sin(angle) * 5 - 22
			draw_circle(Vector2(sx, sy), 2.0, Color(1, 1, 0.3, 0.8))
		draw_string(ThemeDB.fallback_font, Vector2(-8, -30),
			"СТАН", HORIZONTAL_ALIGNMENT_CENTER, -1, 6, Color(1, 0.3, 0.3, 0.9))

	# Roll animation — flat/compressed (fits through 1-tile gaps)
	if is_rolling:
		# Roll trail ghosts
		for rt in roll_trail:
			var a = rt["life"] / 0.2 * 0.3
			var lpos = to_local(rt["pos"])
			draw_circle(lpos + Vector2(0, -5), 6, Color(0.5, 0.5, 0.8, a))

		var roll_progress = 1.0 - (roll_timer / roll_duration)
		var roll_angle = roll_progress * TAU * 2.0
		var s = 1 if roll_direction > 0 else -1
		# Flat rolling ball — only ~10px tall (1 tile = 16px)
		draw_circle(Vector2(0, -5), 6, Color(0.35, 0.35, 0.4))
		draw_circle(Vector2(0, -5), 4.5, Color(0.42, 0.42, 0.48))
		# Spinning limb indicator
		var lx = cos(roll_angle) * 4
		var ly = sin(roll_angle) * 4
		draw_line(Vector2(0, -5), Vector2(lx, -5 + ly), Color(0.6, 0.6, 0.65), 2.0)
		# Speed trail
		draw_line(Vector2(-s * 8, -7), Vector2(-s * 14, -7), Color(1, 1, 1, 0.2), 1.0)
		draw_line(Vector2(-s * 7, -3), Vector2(-s * 12, -3), Color(1, 1, 1, 0.15), 1.0)
		# Dust particles
		if fmod(roll_progress * 10, 1.0) < 0.5:
			draw_circle(Vector2(-s * 6, -1), 1.5, Color(0.6, 0.5, 0.3, 0.3))
		return

	# Wall slide animation
	if is_wall_sliding:
		var s = 1 if facing_right else -1
		var slide_offset = sin(Time.get_ticks_msec() * 0.005) * 1

		# Body pressed against wall
		draw_rect(Rect2(-5, -16, 10, 13), Color(0.35, 0.35, 0.4))
		draw_rect(Rect2(-4, -15, 8, 7), Color(0.42, 0.42, 0.48))
		# Head looking out
		draw_rect(Rect2(-4, -22, 8, 7), Color(0.9, 0.75, 0.55))
		draw_rect(Rect2(-5, -24, 10, 5), Color(0.5, 0.5, 0.55))
		draw_rect(Rect2(s, -21, 2, 1), Color(0.35, 0.65, 0.95))
		# Arms gripping wall
		draw_rect(Rect2(-s * 5, -18, 3, 4), Color(0.9, 0.75, 0.55))
		draw_rect(Rect2(-s * 5, -10, 3, 3), Color(0.9, 0.75, 0.55))
		# Legs bent
		draw_rect(Rect2(-3, -4 + slide_offset, 3, 5), Color(0.25, 0.2, 0.15))
		draw_rect(Rect2(1, -4 - slide_offset, 3, 4), Color(0.25, 0.2, 0.15))
		# Friction sparks
		if fmod(Time.get_ticks_msec(), 200.0) < 100:
			draw_circle(Vector2(-s * 4, -6), 1.5, Color(1, 0.8, 0.3, 0.4))
		return

	# Ladder climbing animation
	if is_on_vine:
		var climb_anim = sin(Time.get_ticks_msec() * 0.008) * 3
		# Body (facing forward on ladder)
		draw_rect(Rect2(-5, -18, 10, 14), Color(0.35, 0.35, 0.4))
		draw_rect(Rect2(-4, -17, 8, 8), Color(0.42, 0.42, 0.48))
		# Head
		draw_rect(Rect2(-4, -24, 8, 7), Color(0.9, 0.75, 0.55))
		draw_rect(Rect2(-5, -26, 10, 5), Color(0.5, 0.5, 0.55))
		# Eyes
		draw_rect(Rect2(-2, -23, 2, 1), Color(0.35, 0.65, 0.95))
		draw_rect(Rect2(1, -23, 2, 1), Color(0.35, 0.65, 0.95))
		# Arms gripping ladder rungs (alternating reach)
		draw_rect(Rect2(-7, -18 + climb_anim, 3, 2), Color(0.9, 0.75, 0.55))
		draw_rect(Rect2(5, -14 - climb_anim, 3, 2), Color(0.9, 0.75, 0.55))
		# Legs on rungs
		draw_rect(Rect2(-4, -4 + climb_anim, 3, 5), Color(0.25, 0.2, 0.15))
		draw_rect(Rect2(2, -4 - climb_anim, 3, 5), Color(0.25, 0.2, 0.15))
		# Boots
		draw_rect(Rect2(-5, 0 + climb_anim, 4, 2), Color(0.3, 0.22, 0.12))
		draw_rect(Rect2(2, 0 - climb_anim, 4, 2), Color(0.3, 0.22, 0.12))
		return

	# Ledge grab animation
	if is_grabbing_ledge:
		var s = 1 if facing_right else -1
		draw_rect(Rect2(-5, -24, 10, 13), Color(0.35, 0.35, 0.4))
		draw_rect(Rect2(s * 4, -28, 3, 6), Color(0.9, 0.75, 0.55))
		draw_rect(Rect2(-s * 2, -28, 3, 6), Color(0.9, 0.75, 0.55))
		draw_rect(Rect2(-4, -22, 8, 7), Color(0.9, 0.75, 0.55))
		draw_rect(Rect2(-5, -24, 10, 4), Color(0.5, 0.5, 0.55))
		draw_rect(Rect2(-3, -11, 3, 6), Color(0.25, 0.2, 0.15))
		draw_rect(Rect2(1, -11, 3, 5), Color(0.25, 0.2, 0.15))
		return

	if invincible and fmod(invincible_timer, 0.2) < 0.1:
		return

	var s = 1 if facing_right else -1

	# Landing squash + jump stretch
	var squash_x = 1.0
	var squash_y = 1.0
	if land_squash_timer > 0:
		var t = land_squash_timer / 0.12
		squash_x = 1.0 + t * 0.35   # wide
		squash_y = 1.0 - t * 0.22   # short
	elif not is_on_floor() and velocity.y < -50:
		# Jump stretch: tall and thin
		var t = clampf(-velocity.y / 360.0, 0.0, 1.0)
		squash_x = 1.0 - t * 0.15
		squash_y = 1.0 + t * 0.18
	if squash_x != 1.0 or squash_y != 1.0:
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(squash_x, squash_y))

	# --- LEGS ---
	var leg_anim = sin(Time.get_ticks_msec() * 0.01) * 3 if abs(velocity.x) > 5 else 0
	draw_rect(Rect2(-4, -4, 3, 5 + leg_anim), Color(0.25, 0.2, 0.15))
	draw_rect(Rect2(1, -4, 3, 5 - leg_anim), Color(0.25, 0.2, 0.15))
	draw_rect(Rect2(-5, 0 + leg_anim, 5, 2), Color(0.4, 0.22, 0.1))
	draw_rect(Rect2(0, 0 - leg_anim, 5, 2), Color(0.4, 0.22, 0.1))

	# --- BODY ---
	draw_rect(Rect2(-5, -16, 10, 13), Color(0.35, 0.35, 0.4))
	draw_rect(Rect2(-4, -15, 8, 7), Color(0.42, 0.42, 0.48))
	draw_rect(Rect2(-5, -5, 10, 2), Color(0.45, 0.3, 0.12))
	draw_rect(Rect2(-1, -5, 2, 2), Color(0.75, 0.65, 0.2))

	# --- HEAD ---
	draw_rect(Rect2(-4, -22, 8, 7), Color(0.9, 0.75, 0.55))
	draw_rect(Rect2(-5, -24, 10, 5), Color(0.5, 0.5, 0.55))
	draw_rect(Rect2(-5, -24, 10, 1), Color(0.6, 0.6, 0.65))
	draw_rect(Rect2(-3 + s, -21, 5, 2), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(s, -21, 2, 1), Color(0.35, 0.65, 0.95))

	# --- WEAPON ---
	if using_pickaxe:
		_draw_pickaxe(s)
	else:
		_draw_sword(s)

	# Reset squash transform
	if squash_x != 1.0 or squash_y != 1.0:
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 1.0))

	# --- HEAL CHARGES indicator ---
	if heal_charges > 0:
		for i in heal_charges:
			draw_circle(Vector2(-6 + i * 5, -28), 2, Color(0.3, 0.9, 0.3, 0.6))

func _draw_sword(s: int):
	var wd = weapon_data.get(current_weapon, weapon_data[0])
	var blade_col = wd.color
	var blade_trail = Color(wd.glow.r, wd.glow.g, wd.glow.b, 0.2)
	var blade_glow = wd.glow
	var blade_len = wd.blade_len
	var anim_dur = max(0.05, wd.cooldown * 0.6)
	var blade_w = 2.5
	var is_hammer_type = current_weapon == 4 or current_weapon == 6
	var is_dual = current_weapon == 3 or current_weapon == 5
	var is_knife = current_weapon == 7

	# No weapon = fists
	if current_weapon == 0:
		if is_attacking:
			var sp = 1.0 - (attack_anim_timer / anim_dur)
			var fist_x = s * (8 + sp * 12)
			draw_circle(Vector2(fist_x, -12), 3, Color(0.9, 0.8, 0.65))
		return

	if is_hammer_type:
		blade_w = 4.0
	if is_knife:
		blade_w = 1.8

	if is_attacking:
		var swing_progress = clampf(1.0 - (attack_anim_timer / anim_dur), 0, 1)
		var base = Vector2(s * 5, -12)

		if attack_direction == 1:  # UP
			var angle = lerp(-1.2, 0.2, swing_progress)
			var tip = base + Vector2(sin(angle) * 6 * s, -cos(angle) * blade_len)
			var trail_angle = lerp(-1.2, 0.2, max(0, swing_progress - 0.3))
			var trail_tip = base + Vector2(sin(trail_angle) * 6 * s, -cos(trail_angle) * (blade_len - 2))
			draw_line(trail_tip, tip, blade_trail, blade_w + 1)
			draw_line(base, tip, blade_col, blade_w)
			if is_hammer_type:
				_draw_hammer_head(tip, angle - PI/2)
			draw_line(base + Vector2(-3, 0), base + Vector2(3, 0), Color(0.6, 0.5, 0.2), 2.5)
		elif attack_direction == -1:  # DOWN
			var angle = lerp(-0.2, 1.2, swing_progress)
			var tip = base + Vector2(sin(angle) * 6 * s, cos(angle) * blade_len)
			var trail_angle = lerp(-0.2, 1.2, max(0, swing_progress - 0.3))
			var trail_tip = base + Vector2(sin(trail_angle) * 6 * s, cos(trail_angle) * (blade_len - 2))
			draw_line(trail_tip, tip, blade_trail, blade_w + 1)
			draw_line(base, tip, blade_col, blade_w)
			if is_hammer_type:
				_draw_hammer_head(tip, angle + PI/2)
			draw_line(base + Vector2(-3, 0), base + Vector2(3, 0), Color(0.6, 0.5, 0.2), 2.5)
		else:  # Horizontal
			var swing_angle: float
			match swing_index:
				0: swing_angle = lerp(-0.6, 1.0, swing_progress)
				1: swing_angle = lerp(1.0, -0.6, swing_progress)
				_: swing_angle = lerp(-1.2, 0.8, swing_progress)
			var extra_len = 2 if swing_index == 2 else 0
			var tip = base + Vector2(cos(swing_angle) * (blade_len + extra_len) * s, sin(swing_angle) * (6 + extra_len * 3))
			var trail_s = max(0, swing_progress - 0.3)
			var trail_angle2: float
			match swing_index:
				0: trail_angle2 = lerp(-0.6, 1.0, trail_s)
				1: trail_angle2 = lerp(1.0, -0.6, trail_s)
				_: trail_angle2 = lerp(-1.2, 0.8, trail_s)
			var trail_tip = base + Vector2(cos(trail_angle2) * (blade_len - 1) * s, sin(trail_angle2) * 6)
			draw_line(trail_tip, tip, blade_trail, blade_w + 1.5)
			draw_line(base, tip, blade_col, blade_w)
			draw_line(base + Vector2(0, -1), tip + Vector2(0, -1), blade_glow, 1.0)
			if is_hammer_type:
				_draw_hammer_head(tip, swing_angle)
			draw_line(base + Vector2(0, -3), base + Vector2(0, 3), Color(0.6, 0.5, 0.2), 2.5)

		# Dual blades: draw second blade mirrored
		if is_dual:
			var base2 = Vector2(-s * 3, -14)
			var off_angle = lerp(0.5, -0.8, clampf(swing_progress, 0, 1))
			var tip2 = base2 + Vector2(cos(off_angle) * (blade_len - 4) * s, sin(off_angle) * 5)
			draw_line(base2, tip2, blade_col, blade_w - 0.5)
			draw_line(base2 + Vector2(0, -3), base2 + Vector2(0, 3), Color(0.6, 0.5, 0.2), 2.0)
	else:
		# Idle weapon display
		var sx = s * 7
		if is_hammer_type:
			# Hammer resting on shoulder
			draw_line(Vector2(sx, -10), Vector2(sx - s * 2, -18), Color(0.5, 0.35, 0.15), 2.0)
			_draw_hammer_head(Vector2(sx - s * 2, -18), -0.5 * s)
		elif is_dual:
			draw_line(Vector2(sx, -15), Vector2(sx + s * 7, -10), blade_col, 2.0)
			draw_line(Vector2(-sx, -14), Vector2(-sx - s * 5, -11), blade_col, 1.5)
			draw_line(Vector2(sx, -16), Vector2(sx, -12), Color(0.55, 0.42, 0.2), 2.0)
		else:
			draw_line(Vector2(sx, -15), Vector2(sx + s * 8, -10), blade_col, 2.0)
			draw_line(Vector2(sx, -16), Vector2(sx, -12), Color(0.55, 0.42, 0.2), 2.0)

	# Weapon name popup
	if weapon_msg_timer > 0:
		var alpha = min(weapon_msg_timer, 1.0)
		var rarity_col: Color
		match wd.rarity:
			"common": rarity_col = Color(0.8, 0.8, 0.8, alpha)
			"uncommon": rarity_col = Color(0.3, 0.9, 0.3, alpha)
			"rare": rarity_col = Color(0.3, 0.5, 1.0, alpha)
			"legendary": rarity_col = Color(1.0, 0.8, 0.1, alpha)
			_: rarity_col = Color(1, 1, 1, alpha)
		draw_string(ThemeDB.fallback_font, Vector2(-weapon_pickup_msg.length() * 3, -38 - (3.0 - weapon_msg_timer) * 5),
			weapon_pickup_msg, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, rarity_col)

func _draw_hammer_head(pos: Vector2, angle: float):
	var wd = weapon_data.get(current_weapon, weapon_data[4])
	var col = wd.color
	var perp = Vector2(cos(angle + PI/2), sin(angle + PI/2))
	var fwd = Vector2(cos(angle), sin(angle))
	# Hammer head rectangle
	draw_line(pos + perp * 5, pos - perp * 5, col, 5.0)
	draw_line(pos + perp * 4 + fwd * 2, pos - perp * 4 + fwd * 2, Color(col.r * 0.8, col.g * 0.8, col.b * 0.8), 3.0)

func _draw_pickaxe(s: int):
	if is_attacking:
		var anim_dur = 0.15
		var swing_progress = 1.0 - (attack_anim_timer / anim_dur)
		var base = Vector2(s * 3, -12)

		var angle: float
		var handle_end: Vector2

		if attack_direction == 1:  # UP attack
			angle = lerp(0.5, -1.2, swing_progress)
			handle_end = base + Vector2(sin(angle) * 5 * s, -cos(angle) * 18)
		elif attack_direction == -1:  # DOWN attack
			angle = lerp(-0.5, 1.2, swing_progress)
			handle_end = base + Vector2(sin(angle) * 5 * s, cos(angle) * 18)
		else:  # Horizontal
			angle = lerp(-0.8, 1.2, swing_progress) * s
			handle_end = base + Vector2(cos(angle) * 18, sin(angle) * 8)

		# Handle (brown)
		draw_line(base, handle_end, Color(0.55, 0.35, 0.15), 2.5)
		# Pickaxe head (iron gray) - perpendicular to handle
		var dir_vec = (handle_end - base).normalized()
		var perp = Vector2(-dir_vec.y, dir_vec.x)
		var head_pos = handle_end
		draw_line(head_pos - perp * 5, head_pos + perp * 5, Color(0.6, 0.6, 0.65), 3.0)
		# Point tip
		draw_line(head_pos + perp * 5, head_pos + perp * 7 + dir_vec * 3, Color(0.7, 0.7, 0.75), 2.0)
		# Sparks when mining
		if swing_progress > 0.7:
			draw_circle(handle_end + Vector2(randf_range(-3, 3), randf_range(-3, 3)), 1.5, Color(1, 0.8, 0.3, 0.6))
	else:
		# Idle pickaxe - held over shoulder
		var sx = s * 6
		# Handle
		draw_line(Vector2(sx, -8), Vector2(sx + s * 6, -20), Color(0.55, 0.35, 0.15), 2.5)
		# Head
		var hx = sx + s * 6
		draw_line(Vector2(hx - 4, -22), Vector2(hx + 4, -18), Color(0.6, 0.6, 0.65), 3.0)
		# Point
		draw_line(Vector2(hx + 4, -18), Vector2(hx + 6, -17), Color(0.7, 0.7, 0.75), 2.0)

# ───────────────────────────────────────────────────────────────────
# CS FEATURES: Inspect / Smoke / Flash
# ───────────────────────────────────────────────────────────────────

func hazard_bounce() -> void:
	# Hollow Knight-стиль: коснулся шипов в паркур-яме — небольшой урон и
	# возврат на последнюю безопасную точку. Не смерть, не бесконечная петля
	# (take_damage даёт неуязвимость на 0.8с).
	if is_dead or invincible or dash_invuln or is_rolling:
		return
	if last_safe_pos == Vector2.ZERO:
		last_safe_pos = global_position
	take_damage(24, Vector2.ZERO)   # ×3 урона от шипов
	if is_dead:
		return
	global_position = last_safe_pos
	velocity = Vector2.ZERO
	is_jump_rising = false
	dash_active = false
	screen_shake.emit(2.5, 0.12)

func apply_contact_push(dir: Vector2) -> void:
	# Лёгкий отпор от тела врага: выталкиваем игрока наружу, чтобы он не мог
	# стоять внутри хитбокса. Толчок мягкий — намерение игрока двигаться важнее,
	# но «влипнуть» во врага уже нельзя.
	if is_dead or is_rolling or dash_active:
		return
	global_position += dir * 0.9
	velocity.x += dir.x * 70.0
	if dir.y < 0.0:
		velocity.y = minf(velocity.y, dir.y * 50.0)

func _add_bhop_stack(_label: String) -> void:
	# Банихоп убран по просьбе игрока — функция оставлена пустой, чтобы старые
	# вызовы (выход из дэша и т.п.) ничего не делали.
	pass

func _reset_bhop_combo(_reason: String) -> void:
	if bhop_stacks > 0:
		bhop_stacks = 0

func _do_dash() -> void:
	# Направление: текущий ввод или взгляд если ввод пустой
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	if dir == Vector2.ZERO:
		dir = Vector2(1 if facing_right else -1, 0)
	dash_dir = dir.normalized()
	if dash_dir.x != 0:
		facing_right = dash_dir.x > 0
	dash_active = true
	dash_timer = DASH_DURATION
	dash_invuln = true
	dash_charges -= 1.0
	dash_used.emit(int(dash_charges))
	# Фазим сквозь врагов (но НЕ сквозь стены)
	collision_layer = 0    # враги нас не видят
	# collision_mask оставляем — стены/полы остаются
	# Прерываем падение/прыжок
	velocity = Vector2.ZERO
	# Сотрясение
	screen_shake.emit(2.0, 0.10)
	_break_invisibility()

func _spawn_landing_dust(fall_vy: float) -> void:
	# Сила пыли зависит от скорости падения
	var strength = clampf(fall_vy / 400.0, 0.25, 1.5)
	var count = int(4 + strength * 8)
	for i in count:
		var side = -1.0 if i % 2 == 0 else 1.0
		var spd = randf_range(25.0, 70.0) * strength
		feel_particles.append({
			"pos": Vector2(randf_range(-5, 5), 1.0),
			"vel": Vector2(side * spd + randf_range(-15, 15), randf_range(-30, -8) * strength),
			"life": randf_range(0.25, 0.5),
			"max_life": 0.5,
			"size": randf_range(1.5, 3.5) * strength,
			"color": Color(0.75, 0.72, 0.78),
		})

func _spawn_footstep() -> void:
	footstep.emit()
	# Маленькое облачко за спиной при беге
	var back = -1.0 if facing_right else 1.0
	feel_particles.append({
		"pos": Vector2(back * 6.0, 1.0),
		"vel": Vector2(back * randf_range(10, 30), randf_range(-18, -6)),
		"life": randf_range(0.2, 0.35),
		"max_life": 0.35,
		"size": randf_range(1.2, 2.4),
		"color": Color(0.70, 0.68, 0.74),
	})

func _start_inspect() -> void:
	is_inspecting = true
	inspect_anim_timer = INSPECT_DURATION
	inspect_idle_timer = 0.0
	var wd = weapon_data.get(current_weapon, weapon_data[1])
	inspect_requested.emit(wd)

func _throw_smoke_grenade() -> void:
	var smoke_script = load("res://scripts/smoke_cloud.gd")
	if not smoke_script:
		return
	var dir = _get_aim_direction()
	# Прикидываем точку приземления: летит как граната — баллистика
	var proj = Area2D.new()
	proj.set_script(load("res://scripts/projectile.gd"))
	proj.projectile_type = 3  # GRENADE-подобный, но мы перехватим в _on_grenade_land
	proj.is_grenade = false   # не взрывается стандартно
	proj.direction = dir
	proj.speed = 280.0
	proj.damage = 0
	proj.is_player_projectile = true
	proj.gravity_affect = 280.0
	proj.lifetime = 1.0
	proj.global_position = global_position + Vector2(0, -10) + dir * 12
	# Хак: помечаем что эта "граната" должна стать дымом
	proj.set_meta("becomes_smoke", true)
	get_parent().add_child(proj)
	weapon_pickup_msg = "Дымовая граната!"
	weapon_msg_timer = 0.8

func _throw_flash_grenade() -> void:
	var dir = _get_aim_direction()
	var proj = Area2D.new()
	proj.set_script(load("res://scripts/projectile.gd"))
	proj.projectile_type = 3
	proj.is_grenade = false
	proj.direction = dir
	proj.speed = 320.0
	proj.damage = 0
	proj.is_player_projectile = true
	proj.gravity_affect = 280.0
	proj.lifetime = 0.9
	proj.global_position = global_position + Vector2(0, -10) + dir * 12
	proj.set_meta("becomes_flash", true)
	get_parent().add_child(proj)
	weapon_pickup_msg = "Флешка!"
	weapon_msg_timer = 0.8
