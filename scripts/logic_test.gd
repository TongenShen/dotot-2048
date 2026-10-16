extends SceneTree

const BoardScript := preload("res://scripts/board.gd")

var failures := 0


func _init() -> void:
	_test_moves()
	_test_deadlock()
	_test_fuzz()
	print("---- failures: %d" % failures)
	quit(1 if failures > 0 else 0)


func _board(rows: Array) -> BoardScript:
	var b = BoardScript.new()
	b.tiles.clear()
	b.cells.resize(16)
	b.cells.fill(0)
	b.next_id = 1
	b.score = 0
	b.best = 0
	for y in 4:
		for x in 4:
			var v: int = rows[y][x]
			if v != 0:
				var id: int = b.next_id
				b.next_id += 1
				b.tiles[id] = {"v": v, "p": y * 4 + x}
				b.cells[y * 4 + x] = id
	return b


func _row(b, y: int, skip := -1) -> Array:
	var out := []
	for x in 4:
		var p := y * 4 + x
		out.append(0 if p == skip else b.value_at(p))
	return out


func _col(b, x: int, skip := -1) -> Array:
	var out := []
	for y in 4:
		var p := y * 4 + x
		out.append(0 if p == skip else b.value_at(p))
	return out


func _flat(b, skip := -1) -> Array:
	var out := []
	for p in 16:
		out.append(0 if p == skip else b.value_at(p))
	return out


func _expect(label: String, got: Array, want: Array) -> void:
	if got != want:
		failures += 1
		print("FAIL  %s\n      got  %s\n      want %s" % [label, got, want])
	else:
		print("ok    %s" % label)


func _spawn_at(res: Dictionary) -> int:
	return int(res["spawn"].get("p", -1))


func _test_moves() -> void:
	var b := _board([[2, 2, 4, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var res: Dictionary = b.move(BoardScript.LEFT)
	_expect("left 2,2,4,4 -> 4,8", _row(b, 0, _spawn_at(res)), [4, 8, 0, 0])
	if res["gained"] != 12:
		failures += 1
		print("FAIL  gained should be 12, got %s" % res["gained"])
	if b.score != 12:
		failures += 1
		print("FAIL  score should be 12, got %s" % b.score)

	b = _board([[4, 2, 2, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	res = b.move(BoardScript.LEFT)
	_expect("left 4,2,2,4 -> 4,4,4 with no chain merge", _row(b, 0, _spawn_at(res)), [4, 4, 4, 0])

	b = _board([[4, 4, 4, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	res = b.move(BoardScript.LEFT)
	_expect("left 4,4,4,4 -> 8,8", _row(b, 0, _spawn_at(res)), [8, 8, 0, 0])

	b = _board([[2, 2, 0, 0], [2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	res = b.move(BoardScript.UP)
	_expect("up 2,2/2,2 rows -> row0 4,4", _row(b, 0, _spawn_at(res)), [4, 4, 0, 0])
	_expect("up leaves row1 empty", _row(b, 1, _spawn_at(res)), [0, 0, 0, 0])

	b = _board([[2, 4, 2, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	res = b.move(BoardScript.LEFT)
	if res["moved"]:
		failures += 1
		print("FAIL  left on 2,4,2,4 must be a no-op")
	elif not res["spawn"].is_empty():
		failures += 1
		print("FAIL  a no-op move must not spawn")
	else:
		print("ok    no-op move: no spawn, moved=false")

	b = _board([[2, 0, 0, 0], [4, 0, 0, 0], [8, 0, 0, 0], [16, 0, 0, 0]])
	res = b.move(BoardScript.RIGHT)
	_expect("right packs column 3", _col(b, 3, _spawn_at(res)), [2, 4, 8, 16])
	_expect("right empties column 0", _col(b, 0, _spawn_at(res)), [0, 0, 0, 0])

	b = _board([[2, 0, 0, 0], [2, 0, 0, 0], [4, 0, 0, 0], [4, 0, 0, 0]])
	res = b.move(BoardScript.DOWN)
	_expect("down merges into bottom rows", _col(b, 0, _spawn_at(res)), [0, 0, 4, 8])

	b = _board([[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [2, 2, 2, 2]])
	var before := b.tiles.size()
	res = b.move(BoardScript.LEFT)
	var want_count: int = before - res["merges"].size() + 1
	if b.tiles.size() != want_count:
		failures += 1
		print("FAIL  tile count %d, expected %d" % [b.tiles.size(), want_count])
	else:
		print("ok    every merge consumes one tile and spawns one")

	b = _board([[2, 2, 4, 4], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var reported_before := b.tiles.size()
	res = b.move(BoardScript.LEFT)
	if res["slides"].size() + res["merges"].size() * 2 != reported_before:
		failures += 1
		print("FAIL  animation report must cover every tile: slides=%d merges=%d tiles_before=%d" % [
			res["slides"].size(), res["merges"].size(), reported_before])
	else:
		print("ok    slides+merges account for every tile that moved")


func _test_deadlock() -> void:
	var start := [
		[2, 4, 8, 16],
		[4, 16, 2, 4],
		[2, 4, 8, 16],
		[16, 2, 4, 8],
	]
	var b := _board(start)
	if b.can_move():
		failures += 1
		print("FAIL  deadlock board must report can_move() == false")
	else:
		print("ok    deadlock detected")
	for dir in 4:
		if b.move(dir)["moved"]:
			failures += 1
			print("FAIL  direction %d moved a deadlock board" % dir)
	var want := []
	for line_values in start:
		for v in line_values:
			want.append(v)
	_expect("deadlock board unchanged", _flat(b), want)

	var b2 := _board([
		[2, 4, 8, 16],
		[4, 16, 2, 4],
		[2, 4, 8, 16],
		[16, 2, 4, 4],
	])
	if not b2.can_move():
		failures += 1
		print("FAIL  a board with a mergeable pair must stay playable")
	else:
		print("ok    full board with one mergeable pair is playable")


func _test_fuzz() -> void:
	randomize()
	var b := _board([[0, 0, 0, 0], [0, 2, 0, 0], [0, 0, 2, 0], [0, 0, 0, 0]])
	var real_moves := 0
	for step in 4000:
		if not b.can_move():
			break
		var res: Dictionary = b.move(randi() % 4)
		if res["moved"]:
			real_moves += 1
		if not _consistent(b):
			failures += 1
			print("FAIL  inconsistent board at step %d: %s" % [step, _flat(b)])
			break
	print("ok    random play: %d moves, score=%d, best tile=%d" % [real_moves, b.score, b.max_value()])
	if b.max_value() < 32:
		failures += 1
		print("FAIL  random play never reached 32: %s" % [_flat(b)])


func _consistent(b) -> bool:
	var seen := {}
	for p in b.cells.size():
		var id = b.cells[p]
		if id == 0:
			continue
		if not b.tiles.has(id) or seen.has(id):
			return false
		seen[id] = true
		if b.tiles[id]["p"] != p:
			return false
	return b.tiles.size() == seen.size()
