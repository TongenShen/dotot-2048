class_name Board2048
extends RefCounted

const GRID := 4
const LEFT := 0
const RIGHT := 1
const UP := 2
const DOWN := 3
const SAVE_PATH := "user://2048.cfg"

var tiles := {}
var cells := []
var next_id := 1
var score := 0
var best := 0


func reset() -> void:
	tiles.clear()
	cells.resize(GRID * GRID)
	cells.fill(0)
	next_id = 1
	score = 0
	spawn()
	spawn()


func cell_for(dir: int, line: int, idx: int) -> int:
	match dir:
		LEFT:
			return line * GRID + idx
		RIGHT:
			return line * GRID + (GRID - 1 - idx)
		UP:
			return idx * GRID + line
		DOWN:
			return (GRID - 1 - idx) * GRID + line
	return -1


func value_at(pos: int) -> int:
	var id: int = cells[pos]
	if id == 0:
		return 0
	return tiles[id]["v"]


func max_value() -> int:
	var highest := 0
	for id in tiles:
		var v: int = tiles[id]["v"]
		if v > highest:
			highest = v
	return highest


func has_space() -> bool:
	for i in cells.size():
		if cells[i] == 0:
			return true
	return false


func can_move() -> bool:
	if has_space():
		return true
	for y in GRID:
		for x in GRID:
			var v := value_at(y * GRID + x)
			if x + 1 < GRID and value_at(y * GRID + x + 1) == v:
				return true
			if y + 1 < GRID and value_at((y + 1) * GRID + x) == v:
				return true
	return false


func move(dir: int) -> Dictionary:
	var slides := []
	var merges := []
	var gained := 0
	var moved := false
	var next_cells := cells.duplicate()
	next_cells.fill(0)
	for line in GRID:
		var seq := []
		for idx in GRID:
			var found: int = cells[cell_for(dir, line, idx)]
			if found != 0:
				seq.append(found)
		var out := 0
		var k := 0
		while k < seq.size():
			var dst := cell_for(dir, line, out)
			var id: int = seq[k]
			var other: int = seq[k + 1] if k + 1 < seq.size() else 0
			if other != 0 and tiles[id]["v"] == tiles[other]["v"]:
				var doubled: int = tiles[id]["v"] * 2
				tiles[id]["v"] = doubled
				tiles[id]["p"] = dst
				tiles[other]["p"] = dst
				next_cells[dst] = id
				tiles.erase(other)
				gained += doubled
				merges.append({"keep": id, "drop": other, "to": dst, "v": doubled})
				moved = true
				k += 2
			else:
				if tiles[id]["p"] != dst:
					moved = true
				tiles[id]["p"] = dst
				next_cells[dst] = id
				slides.append({"id": id, "to": dst})
				k += 1
			out += 1
	cells = next_cells
	score += gained
	var result := {
		"moved": moved,
		"gained": gained,
		"slides": slides,
		"merges": merges,
		"spawn": {},
	}
	if moved:
		result["spawn"] = spawn()
		if score > best:
			best = score
			save_best()
	return result


func spawn() -> Dictionary:
	var empty := []
	for i in cells.size():
		if cells[i] == 0:
			empty.append(i)
	if empty.is_empty():
		return {}
	var pos: int = empty[randi() % empty.size()]
	var v := 4 if randf() < 0.1 else 2
	var id := next_id
	next_id += 1
	tiles[id] = {"v": v, "p": pos}
	cells[pos] = id
	return {"id": id, "p": pos, "v": v}


func load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = int(cf.get_value("game", "best", 0))


func save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "best", best)
	cf.save(SAVE_PATH)
