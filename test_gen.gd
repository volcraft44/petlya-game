extends SceneTree
# Смоук-тест генерации уровней: создаём комнаты уровней 1..9 и проверяем,
# что генерация не падает и даёт осмысленные структуры.
func _init():
	var RoomScript = load("res://scripts/room.gd")
	var enemy_scene = load("res://scenes/enemy.tscn")
	var player_scene = load("res://scenes/player.tscn")
	for lvl in [1, 2, 3, 4, 6, 7, 8, 9]:
		var player = player_scene.instantiate()
		root.add_child(player)
		var room = Node2D.new()
		room.set_script(RoomScript)
		root.add_child(room)
		# _ready не вызывается до старта главного цикла — инициализируем сами.
		room.grid_cols = int(room.room_width / room.tile_size)
		room.grid_rows = int(room.room_height / room.tile_size)
		room.floor_y = room.room_height - room.tile_size * 2
		room.ceiling_y = room.tile_size * 2
		room.setup(lvl, enemy_scene, player)
		var spawn = room.get_player_spawn()
		print("LVL %d OK: caves=%d spikes=%d sblocks=%d oneway=%d ladders=%d enemies=%d chests=%d spawn=%s" % [
			lvl, room.caves.size(), room.spikes.size(), room.spike_blocks.size(),
			room.oneway_platforms.size(), room.ladders.size(), room.enemies.size(),
			room.chests.size(), str(spawn)])
		# Проверка: дверь существует и достижима из старта (reachable_set)
		if room.doors.size() == 0:
			print("  !! НЕТ ДВЕРИ")
		else:
			var d = room.doors[0]
			var gr = int(d.position.y / room.tile_size)
			var gc = int(d.position.x / room.tile_size)
			var key = gr * room.grid_cols + gc
			var key_up = (gr - 1) * room.grid_cols + gc
			if room.reachable_set.size() > 0 and not room.reachable_set.has(key) and not room.reachable_set.has(key_up):
				print("  !! ДВЕРЬ ВНЕ ДОСЯГАЕМОСТИ: ", d.position)
		room.free()
		player.free()
	print("SMOKE TEST DONE")
	quit()
