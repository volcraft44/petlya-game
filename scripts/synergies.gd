extends RefCounted

# Синергии оружия + карты. Если у игрока совпадает пара —
# применяется доп. эффект. Показывается уведомление.

const SYNERGIES: Array = [
	{
		"id": "blood_thirst",
		"weapon_ids": [5],   # Клинки Вампира
		"card_id": "berserker",
		"name": "ЖАЖДА КРОВИ",
		"desc": "Клинки Вампира + Берсерк: вампиризм +50%",
		"color": Color(0.95, 0.15, 0.20),
	},
	{
		"id": "shadow_assassin",
		"weapon_ids": [7],   # Нож
		"card_id": "backstab",
		"name": "ТЕНЕВОЙ УБИЙЦА",
		"desc": "Нож + Удар в Спину: атаки сзади = крит",
		"color": Color(0.40, 0.10, 0.60),
	},
	{
		"id": "iron_dance",
		"weapon_ids": [3, 5],   # Клинки / Клинки Вампира
		"card_id": "dodge",
		"name": "ЖЕЛЕЗНЫЙ ТАНЕЦ",
		"desc": "Клинки + Уворот: после уворота 1 сек неуязвимости",
		"color": Color(0.30, 0.80, 1.00),
	},
	{
		"id": "rush_hour",
		"weapon_ids": [3, 16, 18],   # быстрые: Клинки, Тройной Лук, Дротики
		"card_id": "speed_boots",
		"name": "ЧАС ПИК",
		"desc": "Быстрое оружие + Ботинки: +25% скорости атаки",
		"color": Color(1.00, 0.85, 0.20),
	},
	{
		"id": "death_storm",
		"weapon_ids": [11],   # Тетрадь Смерти
		"card_id": "hunter",
		"name": "ШТОРМ СМЕРТИ",
		"desc": "Тетрадь + Охотник: цель умирает в 2 раза быстрее",
		"color": Color(0.15, 0.15, 0.15),
	},
	{
		"id": "death_blow",
		"weapon_ids": [4, 6, 15],   # тяжёлое: Молот, Зол. Молот, Якорь
		"card_id": "close_combat",
		"name": "СМЕРТЕЛЬНЫЙ УДАР",
		"desc": "Тяжёлое оружие + Ближний Бой: +60% урона вблизи",
		"color": Color(1.00, 0.50, 0.10),
	},
	{
		"id": "berserker_blade",
		"weapon_ids": [2],   # Длинный Меч
		"card_id": "low_hp",
		"name": "БЕРСЕРК-МЕЧ",
		"desc": "Длинный Меч + Берсерк: при <30% HP — урон x2.5",
		"color": Color(0.85, 0.10, 0.15),
	},
	{
		"id": "explosive_hunter",
		"weapon_ids": [8, 16],   # Луки
		"card_id": "critical",
		"name": "ВЗРЫВНОЙ ОХОТНИК",
		"desc": "Лук + Крит: критические выстрелы взрываются",
		"color": Color(1.00, 0.65, 0.10),
	},
]

static func find_active(weapon_id: int, card_id: String) -> Dictionary:
	# Возвращает первую активную синергию или {}
	for s in SYNERGIES:
		if card_id == s.card_id and weapon_id in s.weapon_ids:
			return s
	return {}
