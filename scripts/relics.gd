extends RefCounted

# Реликвии — пассивные артефакты которые игрок собирает за забег.
# Каждая реликвия модифицирует игрока, врагов или мир. Стопаются.

const ALL_RELICS: Array = [
	{
		"id": "bloody_pact",
		"name": "Кровавый Пакт",
		"desc": "+30% урон, но HP не восстанавливается",
		"icon_color": Color(0.85, 0.10, 0.10),
		"rarity": "rare",
	},
	{
		"id": "iron_skin",
		"name": "Железная Кожа",
		"desc": "−25% получаемого урона",
		"icon_color": Color(0.60, 0.60, 0.70),
		"rarity": "rare",
	},
	{
		"id": "feather_boots",
		"name": "Пёрышки",
		"desc": "+15% скорости, +1 чардж даша",
		"icon_color": Color(0.85, 0.95, 1.00),
		"rarity": "uncommon",
	},
	{
		"id": "vampire_fangs",
		"name": "Клыки Вампира",
		"desc": "Каждый удар возвращает 2% урона в HP",
		"icon_color": Color(0.55, 0.05, 0.20),
		"rarity": "legendary",
	},
	{
		"id": "lucky_coin",
		"name": "Счастливая Монета",
		"desc": "+50% монет с врагов",
		"icon_color": Color(1.00, 0.85, 0.20),
		"rarity": "uncommon",
	},
	{
		"id": "phoenix_feather",
		"name": "Перо Феникса",
		"desc": "Воскрешение 1 раз за забег с 50% HP",
		"icon_color": Color(1.00, 0.55, 0.10),
		"rarity": "legendary",
	},
	{
		"id": "rage_amulet",
		"name": "Амулет Ярости",
		"desc": "+1% урона за каждый 1% потерянного HP",
		"icon_color": Color(0.85, 0.20, 0.05),
		"rarity": "rare",
	},
	{
		"id": "soul_eater",
		"name": "Пожиратель Душ",
		"desc": "Каждое убийство: +1 макс HP",
		"icon_color": Color(0.40, 0.10, 0.60),
		"rarity": "epic",
	},
	{
		"id": "thunder_strike",
		"name": "Удар Грома",
		"desc": "Каждый 5-й удар оглушает врага на 2 сек",
		"icon_color": Color(1.00, 1.00, 0.30),
		"rarity": "rare",
	},
	{
		"id": "frost_aura",
		"name": "Ледяная Аура",
		"desc": "Враги в радиусе 80px замедлены −40%",
		"icon_color": Color(0.30, 0.85, 1.00),
		"rarity": "rare",
	},
	{
		"id": "swift_blade",
		"name": "Быстрый Клинок",
		"desc": "−25% cooldown атаки",
		"icon_color": Color(0.30, 0.70, 1.00),
		"rarity": "uncommon",
	},
	{
		"id": "explosive_arrows",
		"name": "Взрывные Стрелы",
		"desc": "Стрелы взрываются при попадании",
		"icon_color": Color(1.00, 0.45, 0.15),
		"rarity": "epic",
	},
	{
		"id": "ghost_step",
		"name": "Призрачный Шаг",
		"desc": "−1 сек cooldown даша",
		"icon_color": Color(0.65, 0.45, 0.95),
		"rarity": "uncommon",
	},
	{
		"id": "bomb_pouch",
		"name": "Сумка Бомб",
		"desc": "+1 заряд дымовухи и флешки в начале уровня",
		"icon_color": Color(0.45, 0.45, 0.50),
		"rarity": "uncommon",
	},
	{
		"id": "crit_master",
		"name": "Мастер Критов",
		"desc": "+20% шанс крита, +30% урон крита",
		"icon_color": Color(1.00, 0.30, 0.45),
		"rarity": "rare",
	},
	{
		"id": "frost_strike",
		"name": "Ледяной Удар",
		"desc": "Каждый 6-й удар замораживает врага на 2 сек",
		"icon_color": Color(0.55, 0.90, 1.00),
		"rarity": "rare",
	},
	{
		"id": "chain_lightning",
		"name": "Цепная Молния",
		"desc": "Удары бьют молнией по 2 соседним врагам",
		"icon_color": Color(1.00, 1.00, 0.30),
		"rarity": "epic",
	},
	# === Синергичные реликвии (ярко выражают архетип) ===
	{
		"id": "executioner",
		"name": "Палач",
		"desc": "Враги ниже 20% HP получают ДВОЙНОЙ урон",
		"icon_color": Color(0.95, 0.25, 0.15),
		"rarity": "rare",
	},
	{
		"id": "conductor",
		"name": "Проводник",
		"desc": "+35% урона по врагам со статусом (яд/огонь/лёд/шок)",
		"icon_color": Color(0.45, 0.85, 1.00),
		"rarity": "rare",
	},
	{
		"id": "regrowth",
		"name": "Прорастание",
		"desc": "Восстанавливает 1 HP каждые 4 секунды",
		"icon_color": Color(0.35, 0.90, 0.45),
		"rarity": "uncommon",
	},
]

# === АРХЕТИПЫ (Ярость / Тактика / Выживание) ===
# Собери несколько реликвий одного архетипа — получишь сет-бонус. Это даёт
# билдам направление вместо кучи разрозненных бонусов.
const ARCHETYPE_OF := {
	"bloody_pact": "rage", "rage_amulet": "rage", "thunder_strike": "rage",
	"swift_blade": "rage", "explosive_arrows": "rage", "bomb_pouch": "rage",
	"crit_master": "rage", "executioner": "rage",
	"lucky_coin": "tactics", "soul_eater": "tactics", "frost_aura": "tactics",
	"frost_strike": "tactics", "chain_lightning": "tactics", "conductor": "tactics",
	"iron_skin": "survival", "feather_boots": "survival", "vampire_fangs": "survival",
	"phoenix_feather": "survival", "ghost_step": "survival", "regrowth": "survival",
}

static func archetype_of(rid: String) -> String:
	return ARCHETYPE_OF.get(rid, "")

static func archetype_color(a: String) -> Color:
	match a:
		"rage":     return Color(0.95, 0.30, 0.20)   # красный
		"tactics":  return Color(0.35, 0.70, 1.00)   # синий
		"survival": return Color(0.40, 0.90, 0.45)   # зелёный
	return Color(0.7, 0.7, 0.7)

static func archetype_name(a: String) -> String:
	match a:
		"rage":     return "ЯРОСТЬ"
		"tactics":  return "ТАКТИКА"
		"survival": return "ВЫЖИВАНИЕ"
	return ""

# === ПАКТЫ АЛТАРЯ (risk/reward выбор) ===
# На алтаре Петли игрок берёт 1 из 3 пактов: сильный бонус ценой недостатка.
const ALL_PACTS := [
	{
		"id": "pact_blood", "name": "Пакт Крови", "desc": "+35% урон, но −25 макс HP",
		"icon_color": Color(0.85, 0.12, 0.12),
	},
	{
		"id": "pact_glass", "name": "Пакт Стекла", "desc": "+70% урон, но −50% макс HP",
		"icon_color": Color(0.90, 0.55, 0.95),
	},
	{
		"id": "pact_greed", "name": "Пакт Жадности", "desc": "×2 монет за забег, но враги быстрее",
		"icon_color": Color(1.00, 0.82, 0.20),
	},
	{
		"id": "pact_stone", "name": "Пакт Камня", "desc": "+40 макс HP и −20% урона по тебе, но −15% урон",
		"icon_color": Color(0.60, 0.62, 0.70),
	},
	{
		"id": "pact_swift", "name": "Пакт Скорости", "desc": "+25% скорость и +1 дэш, но −15 макс HP",
		"icon_color": Color(0.80, 0.95, 1.00),
	},
	{
		"id": "pact_loop", "name": "Пакт Петли", "desc": "Дарит случайную реликвию сейчас, но следующая комната — засада",
		"icon_color": Color(0.55, 0.20, 0.85),
	},
]

static func roll_pacts(count: int) -> Array:
	var pool := ALL_PACTS.duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

static func get_by_id(rid: String) -> Dictionary:
	for r in ALL_RELICS:
		if r.id == rid:
			return r
	return {}

# Случайные реликвии для предложения (3 штуки разных рарностей)
static func roll_choices(count: int, owned_ids: Array) -> Array:
	var pool = []
	for r in ALL_RELICS:
		if not (r.id in owned_ids):
			pool.append(r)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"common":     return Color(0.78, 0.78, 0.82)
		"uncommon":   return Color(0.32, 0.55, 0.95)
		"rare":       return Color(0.55, 0.30, 0.95)
		"epic":       return Color(0.92, 0.30, 0.85)
		"legendary":  return Color(1.00, 0.20, 0.15)
	return Color.WHITE
