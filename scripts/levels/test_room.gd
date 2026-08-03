@tool
extends Node2D
## 灰盒测试房：按技巧分区，用 8px 网格的 ASCII 图生成地形。
## @tool：编辑器里打开场景即可看到生成结果（编辑器中只铺地形/标记/文字，不放角色与道具）。
## 分区思路参考 Strawberry Jam Collab 的教学房 —— 一个技巧一间小房，房内只放该技巧需要的地形，
## 门口写清操作与判定要点，练成了再往右走。掉坑自动在本区入口重生。
##
## 图例：'#' 实体地形 / '.' 空 / 'P' 出生点 / 'x' 目标标记（无碰撞）
## 每区 16 行、宽度 = 行字符串长度；地面固定在第 14/15 行（顶面 y=112）。
## 区与区之间留 ZONE_GAP 格的坑作为分界，坑宽 2 格可直接跳过去。

const TILE := 8.0
const ZONE_GAP := 2
const FLOOR_ROW := 14
## 死亡带顶面所在行：地面下 3 砖，掉坑立刻死、立刻在本区存档点复活
const DEATH_ROW := 17
## 分隔墙从第 0 行铺到这一行，剩下的 DOOR 两行是门洞（16px，站立 11px 能过）
const DIVIDER_BOTTOM_ROW := 11
const SOLID_COLOR := Color(0.22, 0.25, 0.32)
const DIVIDER_COLOR := Color(0.15, 0.17, 0.22)
const DEATH_COLOR := Color(0.72, 0.18, 0.22)
const CHECKPOINT_COLOR := Color(0.35, 0.85, 0.45)
const TARGET_COLOR := Color(0.98, 0.85, 0.35, 0.55)

const ZONES: Array[Dictionary] = [
	{
		"title": "1  跑跳 / 土狼时间 / 输入缓存",
		"hint": "A D 跑，J 跳（按住越久跳越高）。走出台面 0.1s 内仍能起跳；落地前 0.12s 按 J 也会被记住。",
		"rows": [
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"................x.......",
			"........................",
			"................######..",
			"...P............######..",
			"########################",
			"########################",
		],
	},
	{
		"title": "2  下蹲 / 低通道",
		"hint": "地面按 S 下蹲，碰撞盒 8x11 变 8x6 且底边不动。下蹲时不能走（只有 DuckFriction 在减速），所以要么带着速度滑进去，要么蹲着按 K 冲过这条 1 格高的缝。",
		"rows": [
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........####............",
			".............x..........",
			"########################",
			"########################",
		],
	},
	{
		"title": "3  Dash / Extended Dash",
		"hint": "K 八向冲刺，落地补 dash 有 0.1s 冷却：落地那一瞬再按 K 可连出两段冲刺。",
		"rows": [
			"............................",
			"............................",
			"............................",
			"............................",
			"............................",
			"............................",
			"............................",
			"............................",
			"............................",
			"............................",
			"............................",
			"............................",
			"......................x.....",
			"............................",
			"############......##########",
			"############......##########",
		],
	},
	{
		"title": "4  Super（超级跳）",
		"hint": "地面横向 K，冲刺还没结束时按 J。实测射程 85px；普通跳只有 40px、跳+空中冲 65px，都跨不过这个 10 砖坑。",
		"rows": [
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"...........................x....",
			"................................",
			"##############..........########",
			"##############..........########",
		],
	},
	{
		"title": "5  Hyper / Wavedash",
		"hint": "地面斜下 K 立刻按 J = Hyper（射程 110px）。跳起后马上斜下 K 撞地再 J = Wavedash（114px）。10 砖坑挡掉普通跳 40px 与跳+空中冲 65px。",
		"rows": [
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"..............................x.....",
			"....................................",
			"################..........##########",
			"################..........##########",
		],
	},
	{
		"title": "6  Ultra（超级冲刺）",
		"hint": "从台子上跑出边缘立刻斜下 K，撞地那一下按住 J。撞地转水平滑行提速 1.2 倍再乘 Hyper 倍率，起跳点在台子附近，所以坑放得近一些。",
		"rows": [
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"....................................",
			"...##########.......................",
			"...##########.................x.....",
			"################..........##########",
			"################..........##########",
		],
	},
	{
		"title": "7  墙跳 / SuperWallJump / Wallbounce",
		"hint": "贴墙按 J 弹开（130）。纯上方向 K 冲刺时贴墙按 J = SuperWallJump（170, -160）。左右交替爬上去。",
		"rows": [
			"........................",
			".........x..............",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"......##...##...........",
			"########################",
			"########################",
		],
	},
	{
		"title": "8  攀爬 / 爬墙跳 / Wallboost",
		"hint": "Shift 抓墙（贴合不下滑，体力 110）。按住 Shift 不给方向按 J = 垂直爬墙跳，跳后 0.2s 内推离墙面退还体力 = Wallboost，可无限上墙。到顶按住上方向翻墙。",
		"rows": [
			"..............x.........",
			"........................",
			"..........############..",
			"..........##............",
			"..........##............",
			"..........##............",
			"..........##............",
			"..........##............",
			"..........##............",
			"..........##............",
			"..........##............",
			"..........##............",
			"..........##............",
			"..........##............",
			"########################",
			"########################",
		],
	},
	{
		"title": "9  角落修正 / Cornerkick",
		"hint": "天花板上有一道正好 1 格（8px）的缝。站上小台子向上 K 冲刺，偏一点也会被横移最多 4px 塞进缝里。",
		"rows": [
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"...........x............",
			"........................",
			"###########.############",
			"........................",
			"........................",
			"........................",
			"..........###...........",
			"..........###...........",
			"########################",
			"########################",
		],
	},
	{
		"title": "10  Cornerboost / 撞墙速度保留",
		"hint": "全速撞墙后 0.06s 内离开墙面，撞墙前的水平速度会被还原，不必重新加速。跳到墙顶看看。",
		"rows": [
			"........................",
			"........................",
			"........................",
			"........................",
			"..................x.....",
			"........................",
			"..................##....",
			"..................##....",
			"..................##....",
			"..................##....",
			"..................##....",
			"..................##....",
			"..................##....",
			"..................##....",
			"########################",
			"########################",
			],
		},
	]

var _player: Node2D
var _current_zone := -1
var _zone_bounds: Array[Vector2] = []
var _zone_spawns: Array[Vector2] = []

func _ready() -> void:
	# 编辑器里重复触发 _ready 时只清掉上一次生成的容器，别碰外部挂进来的节点
	var old := get_node_or_null("Generated")
	if old:
		old.free()
	var editor := Engine.is_editor_hint()
	var generated := Node2D.new()
	generated.name = "Generated"
	add_child(generated)
	var terrain := StaticBody2D.new()
	terrain.name = "Terrain"
	generated.add_child(terrain)
	var visuals := Node2D.new()
	visuals.name = "TerrainVisuals"
	generated.add_child(visuals)
	var markers := Node2D.new()
	markers.name = "Markers"
	generated.add_child(markers)
	var labels := Node2D.new()
	labels.name = "Labels"
	generated.add_child(labels)

	var player_scene: PackedScene = load("res://scenes/player/player.tscn")

	var x_tile := 0
	for zone in ZONES:
		var rows: Array = zone["rows"]
		var width := 0
		for row in rows:
			width = maxi(width, (row as String).length())
		for row_index in rows.size():
			var row: String = rows[row_index]
			var run_start := -1
			for col in range(row.length() + 1):
				var solid := col < row.length() and row[col] == "#"
				if solid and run_start < 0:
					run_start = col
				elif not solid and run_start >= 0:
					_add_solid(terrain, visuals, x_tile + run_start, row_index, col - run_start)
					run_start = -1
				if col >= row.length():
					continue
				match row[col]:
					"P":
						if editor: continue
						_player = player_scene.instantiate()
						_player.global_position = _cell_floor(x_tile + col, row_index)
						_player.set("show_controller_debug", true)
						_player.set("kill_plane_y", float(DEATH_ROW * TILE))
						add_child(_player)
					"x":
						_add_marker(markers, x_tile + col, row_index)
		_add_label(labels, zone, x_tile, width)
		var entrance := _zone_entrance(rows, x_tile)
		_add_checkpoint(markers, entrance)
		_zone_bounds.append(Vector2(x_tile * TILE, (x_tile + width) * TILE))
		_zone_spawns.append(entrance)
		# 区间用 2 砖厚的高墙隔开，只在贴地的两行留门洞（16px，站立 11px 能过）
		_add_divider(terrain, visuals, x_tile + width)
		x_tile += width + ZONE_GAP
	_add_death_band(visuals, x_tile)

## 玩家跨区时更新存盘点；掉坑死亡由 player.gd 的 kill_plane_y 统一处理（_add_checkpoint 已设好）。
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player): return
	var zone := _zone_for(_player.global_position.x)
	if zone != _current_zone:
		_current_zone = zone
		_player.set_checkpoint(_zone_spawns[zone])

func _zone_for(x: float) -> int:
	for index in _zone_bounds.size():
		if x < _zone_bounds[index].y:
			return index
	return _zone_bounds.size() - 1

## 分区入口：地面行第一块实体的上方第一个空格（有些区入口上面还压着台子）
func _zone_entrance(rows: Array, x_tile: int) -> Vector2:
	var floor_row: String = rows[FLOOR_ROW]
	var col := 1
	for index in floor_row.length():
		if floor_row[index] == "#":
			col = index + 1
			break
	for row in range(FLOOR_ROW - 1, 0, -1):
		var line: String = rows[row]
		var below: String = rows[row + 1]
		if col < line.length() and line[col] == "." and below[col] == "#":
			return _cell_floor(x_tile + col, row)
	return _cell_floor(x_tile + col, FLOOR_ROW - 1)

## 分区之间的高墙：顶到第 DIVIDER_BOTTOM_ROW 行，贴地两行留门洞，脚下补上通行地面
func _add_divider(terrain: StaticBody2D, visuals: Node2D, col: int) -> void:
	var top := Vector2(col * TILE, 0.0)
	var top_size := Vector2(ZONE_GAP * TILE, (DIVIDER_BOTTOM_ROW + 1) * TILE)
	_add_body(terrain, visuals, top, top_size, DIVIDER_COLOR)
	var walk := Vector2(col * TILE, FLOOR_ROW * TILE)
	var walk_size := Vector2(ZONE_GAP * TILE, 2.0 * TILE)
	_add_body(terrain, visuals, walk, walk_size, SOLID_COLOR)

## 存档点：分区入口的绿色立柱（掉坑后回到这里）
func _add_checkpoint(markers: Node2D, entrance: Vector2) -> void:
	var visual := ColorRect.new()
	visual.size = Vector2(2.0, 2.0 * TILE)
	visual.position = Vector2(entrance.x - 1.0, entrance.y - visual.size.y)
	visual.color = CHECKPOINT_COLOR
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers.add_child(visual)

## 死亡带：坑底的红色区域，只做视觉提示，判定在 _physics_process 里按 DEATH_ROW 走
func _add_death_band(visuals: Node2D, cols: int) -> void:
	var visual := ColorRect.new()
	visual.position = Vector2(0.0, DEATH_ROW * TILE)
	visual.size = Vector2(cols * TILE, 2.0 * TILE)
	visual.color = DEATH_COLOR
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visuals.add_child(visual)

func _add_body(terrain: StaticBody2D, visuals: Node2D, origin: Vector2, size: Vector2, color: Color) -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = origin + size * 0.5
	terrain.add_child(shape)
	var visual := ColorRect.new()
	visual.position = origin
	visual.size = size
	visual.color = color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visuals.add_child(visual)

func _add_solid(terrain: StaticBody2D, visuals: Node2D, col: int, row: int, cols: int) -> void:
	_add_body(terrain, visuals, Vector2(col * TILE, row * TILE), Vector2(cols * TILE, TILE), SOLID_COLOR)

func _add_marker(markers: Node2D, col: int, row: int) -> void:
	var visual := ColorRect.new()
	visual.position = Vector2(col * TILE, row * TILE + TILE * 0.5)
	visual.size = Vector2(TILE, TILE * 0.5)
	visual.color = TARGET_COLOR
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers.add_child(visual)

func _add_label(labels: Node2D, zone: Dictionary, x_tile: int, width: int) -> void:
	var label := Label.new()
	label.position = Vector2(x_tile * TILE + 4.0, 4.0)
	label.size = Vector2(width * TILE - 8.0, 48.0)
	label.text = "%s\n%s" % [zone["title"], zone["hint"]]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(label)

# 'P' 所在格：脚底贴在该格底边，正好站在下一行的地面上
func _cell_floor(col: int, row: int) -> Vector2:
	return Vector2(col * TILE + TILE * 0.5, (row + 1) * TILE)

