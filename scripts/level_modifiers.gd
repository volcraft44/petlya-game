extends RefCounted

# Модификаторы уровня — выбираешь перед стартом для разнообразия.
# Каждый = бафф + дебафф (risk/reward).

const ALL_MODIFIERS: Array = [
	{
		"id": "berserk",
		"name": "Берсерк",
		"desc": "+50% урон, но −30% максимум HP",
		"icon_color": Color(0.90, 0.15, 0.10),
	},
	{
		"id": "lightspeed",
		"name": "Световая Скорость",
		"desc": "+40% скорости, но враги тоже",
		"icon_color": Color(0.30, 0.85, 1.00),
	},
	{
		"id": "rich_run",
		"name": "Алчность",
		"desc": "+100% монет, но враги +30% HP",
		"icon_color": Color(1.00, 0.85, 0.20),
	},
	{
		"id": "double_or_nothing",
		"name": "Удвоить или Ничего",
		"desc": "x2 урон у тебя И у врагов",
		"icon_color": Color(0.85, 0.30, 0.85),
	},
	{
		"id": "iron_walls",
		"name": "Железные Стены",
		"desc": "−50% урона от снарядов, но милишники +50%",
		"icon_color": Color(0.55, 0.55, 0.70),
	},
	{
		"id": "blood_pact_level",
		"name": "Пакт Крови",
		"desc": "+25% урон, но −2 HP/сек постоянно",
		"icon_color": Color(0.70, 0.10, 0.10),
	},
	{
		"id": "dense_dark",
		"name": "Сгущённый Мрак",
		"desc": "Свет в 2× меньше, но +10 монет за каждого врага",
		"icon_color": Color(0.15, 0.15, 0.30),
	},
	{
		"id": "elite_horde",
		"name": "Элитная Орда",
		"desc": "Каждый враг — элитный, но +200% монет",
		"icon_color": Color(0.95, 0.55, 0.10),
	},
	{
		"id": "glass_cannon",
		"name": "Стеклянная Пушка",
		"desc": "x3 урон, но 1 HP",
		"icon_color": Color(0.95, 0.95, 1.00),
	},
	{
		"id": "no_modifier",
		"name": "Без модификатора",
		"desc": "Обычный уровень — без бонусов и штрафов",
		"icon_color": Color(0.65, 0.65, 0.70),
	},
]

static func roll_choices(count: int) -> Array:
	var pool = ALL_MODIFIERS.duplicate()
	pool.shuffle()
	# Гарантированно даём "без модификатора" как один из вариантов
	var result = pool.slice(0, min(count - 1, pool.size() - 1))
	result.append(ALL_MODIFIERS[ALL_MODIFIERS.size() - 1])
	return result
