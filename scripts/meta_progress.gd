extends RefCounted

# Мета-прогрессия — копится между забегами и даёт перманентные баффы.
# Сохраняется в user://meta.save (числа кол-во убийств, смертей, монет).
# По метрикам — открываются "тиры" пассивных бонусов.

const SAVE_PATH := "user://meta.save"

# Состояние (загружается из файла)
static var total_kills: int = 0
static var total_deaths: int = 0
static var total_coins: int = 0
static var furthest_level: int = 1
static var _loaded: bool = false

static func load_meta() -> void:
	if _loaded:
		return
	_loaded = true
	var fa = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if fa:
		total_kills = fa.get_32()
		total_deaths = fa.get_32()
		total_coins = fa.get_32()
		furthest_level = fa.get_32()
		fa.close()

static func save_meta() -> void:
	var fa = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if fa:
		fa.store_32(total_kills)
		fa.store_32(total_deaths)
		fa.store_32(total_coins)
		fa.store_32(furthest_level)
		fa.close()

static func on_kill() -> void:
	load_meta()
	total_kills += 1
	if total_kills % 25 == 0:   # каждые 25 убийств — автосейв
		save_meta()

static func on_death() -> void:
	load_meta()
	total_deaths += 1
	save_meta()

static func on_level_reached(lvl: int) -> void:
	load_meta()
	if lvl > furthest_level:
		furthest_level = lvl
		save_meta()

static func add_coins_collected(c: int) -> void:
	load_meta()
	total_coins += c

# === ТИРЫ БАФФОВ ===
# Каждый тир открывается по своей метрике
static func get_damage_tier() -> int:
	load_meta()
	# +5% урон за каждые 50 убийств, до 5 тиров (25% макс)
	return mini(5, total_kills / 50)

static func get_hp_tier() -> int:
	load_meta()
	# +10 HP за каждые 3 смерти (как "память петли") до 5 тиров
	return mini(5, total_deaths / 3)

static func get_starting_coins() -> int:
	load_meta()
	# Каждые 500 собранных монет = +50 стартовых до 200
	return mini(200, (total_coins / 500) * 50)

static func get_starting_heal_tier() -> int:
	load_meta()
	# +1 heal charge за достижение каждых 5 уровней
	return mini(3, furthest_level / 5)

# === ВЕХИ-РАЗЛОКИ (контентные, а не только цифры) ===
static func unlocked_starting_relic() -> bool:
	load_meta()
	return furthest_level >= 3      # дошёл до 3 уровня → каждый забег с реликвией

static func unlocked_extra_heal_start() -> bool:
	load_meta()
	return total_deaths >= 5        # «память петли»: 5 смертей → +1 стартовый хил

# Список вех для показа в меню: [название, открыто?, прогресс_текст].
static func get_milestones() -> Array:
	load_meta()
	return [
		["Стартовая реликвия", furthest_level >= 3, "уровень %d/3" % mini(furthest_level, 3)],
		["+1 стартовый хил", total_deaths >= 5, "смертей %d/5" % mini(total_deaths, 5)],
	]
