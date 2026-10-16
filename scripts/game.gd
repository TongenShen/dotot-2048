extends Control

const GRID := Board2048.GRID
const CELL := 104
const GAP := 12
const BOARD_X := 12
const BOARD_Y := 120
const BOARD_W := GRID * CELL + (GRID + 1) * GAP
const SLIDE_TIME := 0.09
const SWIPE_MIN := 24.0

const BG := Color("faf8ef")
const BOARD_BG := Color("bbada0")
const CELL_BG := Color("cdc1b4")
const TEXT_DARK := Color("776e65")
const TEXT_LIGHT := Color("f9f6f2")
const VEIL := Color(0.933, 0.894, 0.855, 0.73)
const SUPER := Color("e1d5c8")

const TILE_COLORS := {
	2: Color("eee4da"),
	4: Color("ede0c8"),
	8: Color("f2b179"),
	16: Color("f59563"),
	32: Color("f67c5f"),
	64: Color("f65e3b"),
	128: Color("edcf72"),
	256: Color("edcc61"),
	512: Color("edc850"),
	1024: Color("edc53f"),
	2048: Color("edc22e"),
}

var board := Board2048.new()
var nodes := {}
var layer: Control
var score_label: Label
var best_label: Label
var overlay: ColorRect
var overlay_text: Label
var busy := false
var over := false
var target_shown := false
var session := 0
var drag_from := Vector2.INF


func _ready() -> void:
	board.load_best()
	_build_ui()
	_new_game()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := _label("2048", 50, TEXT_DARK)
	title.position = Vector2(12, 4)
	add_child(title)

	var subtitle := _label("合并方块,冲击 2048", 15, TEXT_DARK)
	subtitle.position = Vector2(14, 66)
	add_child(subtitle)

	_score_box("得分", 308)
	_score_box("最高", 402)

	var button := Button.new()
	button.text = "新游戏"
	button.position = Vector2(12, 90)
	button.size = Vector2(110, 30)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_new_game)
	add_child(button)

	var keys := _label("方向键 / WASD / 拖动滑动 · R 重开", 14, TEXT_DARK)
	keys.position = Vector2(136, 96)
	add_child(keys)

	var board_panel := Panel.new()
	board_panel.position = Vector2(BOARD_X, BOARD_Y)
	board_panel.size = Vector2(BOARD_W, BOARD_W)
	board_panel.add_theme_stylebox_override("panel", _flat(BOARD_BG, 8))
	board_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_panel)

	for y in GRID:
		for x in GRID:
			var slot := Panel.new()
			slot.add_theme_stylebox_override("panel", _flat(CELL_BG, 6))
			slot.position = _cell_origin(Vector2i(x, y)) - Vector2(BOARD_X, BOARD_Y)
			slot.size = Vector2(CELL, CELL)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_panel.add_child(slot)

	layer = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	overlay = ColorRect.new()
	overlay.color = VEIL
	overlay.position = Vector2(BOARD_X, BOARD_Y)
	overlay.size = Vector2(BOARD_W, BOARD_W)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	overlay_text = _label("", 34, TEXT_DARK)
	overlay_text.size = Vector2(BOARD_W, BOARD_W)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_text)


func _score_box(caption: String, box_x: float) -> void:
	var panel := Panel.new()
	panel.position = Vector2(box_x, 10)
	panel.size = Vector2(86, 54)
	panel.add_theme_stylebox_override("panel", _flat(BOARD_BG, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var head := _label(caption, 13, Color("eee4da"))
	head.size = Vector2(86, 16)
	head.position = Vector2(0, 6)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(head)

	var value := _label("0", 22, TEXT_LIGHT)
	value.size = Vector2(86, 26)
	value.position = Vector2(0, 24)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(value)

	if caption == "得分":
		score_label = value
	else:
		best_label = value


func _cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(
		BOARD_X + GAP + cell.x * (CELL + GAP),
		BOARD_Y + GAP + cell.y * (CELL + GAP)
	)


func _pos_of(index: int) -> Vector2:
	return _cell_origin(Vector2i(index % GRID, int(index / GRID)))


func _flat(tint: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.set_corner_radius_all(radius)
	return box


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _paint(tile: Label, value: int) -> void:
	var tint: Color = TILE_COLORS.get(value, SUPER)
	tile.add_theme_stylebox_override("normal", _flat(tint, 6))
	tile.text = str(value)
	tile.add_theme_font_size_override("font_size", _font_size(value))
	tile.add_theme_color_override("font_color", TEXT_LIGHT if value >= 8 else TEXT_DARK)


func _font_size(value: int) -> int:
	var digits := len(str(value))
	if digits <= 2:
		return 46
	if digits == 3:
		return 36
	if digits == 4:
		return 28
	return 22


func _spawn_node(id: int, value: int, index: int, animate: bool) -> void:
	var tile := Label.new()
	tile.size = Vector2(CELL, CELL)
	tile.pivot_offset = Vector2(CELL, CELL) * 0.5
	tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.position = _pos_of(index)
	layer.add_child(tile)
	_paint(tile, value)
	nodes[id] = tile
	if animate:
		tile.scale = Vector2.ZERO
		var tween := tile.create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "scale", Vector2.ONE, 0.18)


func _slide_to(tile: Label, index: int) -> void:
	var tween := tile.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "position", _pos_of(index), SLIDE_TIME)


func _bounce(tile: Label) -> void:
	var tween := tile.create_tween()
	tween.tween_property(tile, "scale", Vector2(1.18, 1.18), 0.06)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.09)


func _new_game() -> void:
	session += 1
	busy = false
	over = false
	target_shown = false
	for tile in nodes.values():
		tile.queue_free()
	nodes.clear()
	overlay.visible = false
	board.reset()
	for id in board.tiles:
		_spawn_node(id, board.tiles[id]["v"], board.tiles[id]["p"], false)
	_refresh_score()


func _do_move(dir: int) -> void:
	if busy or over:
		return
	var result := board.move(dir)
	if not result["moved"]:
		return
	busy = true
	var current := session

	for slide in result["slides"]:
		_slide_to(nodes[slide["id"]], slide["to"])
	for merge in result["merges"]:
		_slide_to(nodes[merge["keep"]], merge["to"])
		_slide_to(nodes[merge["drop"]], merge["to"])

	await get_tree().create_timer(SLIDE_TIME + 0.01).timeout
	if current != session:
		return

	for merge in result["merges"]:
		var dropped: Label = nodes[merge["drop"]]
		dropped.queue_free()
		nodes.erase(merge["drop"])
		var kept: Label = nodes[merge["keep"]]
		_paint(kept, merge["v"])
		_bounce(kept)

	var spawned: Dictionary = result["spawn"]
	if not spawned.is_empty():
		_spawn_node(spawned["id"], spawned["v"], spawned["p"], true)

	_refresh_score()
	busy = false
	_check_state()


func _refresh_score() -> void:
	score_label.text = str(board.score)
	best_label.text = str(max(board.best, board.score))


func _check_state() -> void:
	if board.max_value() >= 2048 and not target_shown:
		target_shown = true
		_show_overlay("你达成 2048!\n\n按空格继续")
		return
	if not board.can_move():
		over = true
		_show_overlay("游戏结束\n%d 分\n\n按 R 重新开始" % board.score)


func _show_overlay(message: String) -> void:
	overlay_text.text = message
	overlay.visible = true


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var dir := -1
		match event.keycode:
			KEY_LEFT, KEY_A:
				dir = Board2048.LEFT
			KEY_RIGHT, KEY_D:
				dir = Board2048.RIGHT
			KEY_UP, KEY_W:
				dir = Board2048.UP
			KEY_DOWN, KEY_S:
				dir = Board2048.DOWN
			KEY_R:
				_new_game()
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE:
				if overlay.visible and not over:
					overlay.visible = false
				get_viewport().set_input_as_handled()
				return
		if dir >= 0:
			_do_move(dir)
			get_viewport().set_input_as_handled()
			return

	var pointer := event is InputEventMouseButton or event is InputEventScreenTouch
	if pointer and event.pressed:
		drag_from = event.position
	elif pointer and not event.pressed and drag_from != Vector2.INF:
		var delta: Vector2 = event.position - drag_from
		drag_from = Vector2.INF
		if max(absf(delta.x), absf(delta.y)) >= SWIPE_MIN:
			var dir := Board2048.LEFT if absf(delta.x) > absf(delta.y) else Board2048.UP
			if absf(delta.x) > absf(delta.y):
				dir = Board2048.LEFT if delta.x < 0 else Board2048.RIGHT
			else:
				dir = Board2048.UP if delta.y < 0 else Board2048.DOWN
			_do_move(dir)
			get_viewport().set_input_as_handled()
