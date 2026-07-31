@tool
extends Node2D
## 灰盒测试房：按技巧分区，用 8px 网格的 ASCII 图生成地形。
## @tool：编辑器里打开场景即可看到生成结果（编辑器中只铺地形/标记/文字，不放角色与道具）。
## 分区思路参考 Strawberry Jam Collab 的教学房 —— 一个技巧一间小房，房内只放该技巧需要的地形，
## 门口写清操作与判定要点，练成了再往右走。掉坑自动在本区入口重生。
##
## 图例：'#' 实体地形 / '.' 空 / 'P' 出生点 / 'T' Theo / 'J' 水母 / 'x' 目标标记（无碰撞）
## 每区 16 行、宽度 = 行字符串长度；地面固定在第 14/15 行（顶面 y=112）。
## 区与区之间留 ZONE_GAP 格的坑作为分界，坑宽 2 格可直接跳过去。

const TILE := 8.0
const ZONE_GAP := 2
const FLOOR_ROW := 14
const KILL_Y := 220.0
const SOLID_COLOR := Color(0.22, 0.25, 0.32)
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
			"................########",
			"...P............########",
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
		"hint": "地面横向 K，冲刺还没结束时按 J。水平速度 260，普通跳跨不过的坑一次过。",
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
			"##############......############",
			"##############......############",
		],
	},
	{
		"title": "5  Hyper / Wavedash",
		"hint": "地面斜下 K 立刻按 J = Hyper（325 低平跳）。跳起后马上斜下 K 撞地再 J = Wavedash。",
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
			"..............................x.",
			"................................",
			"##################....##########",
			"##################....##########",
		],
	},
	{
		"title": "6  Ultra（超级冲刺）",
		"hint": "从台子上跳下，空中斜下 K，撞地那一下按 J。撞地会转成水平滑行并提速 1.2 倍再乘 Hyper 倍率。",
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
			"##########......................",
			"##########...................x..",
			"####################....########",
			"####################....########",
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
	{
		"title": "11  抛接 Theo / 水母",
		"hint": "Shift 拾取，再按 Shift 朝面向抛出。持物时不能抓墙。水母抛出后先升后缓降。",
		"rows": [
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"..........J.....................",
			"................................",
			"................................",
			"................................",
			"................................",
			"..........................x.....",
			"........T.......................",
			"##################......########",
			"##################......########",
		],
	},
]

var _player: Node2D
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
	var theo_scene: PackedScene = load("res://scenes/components/theo.tscn")
	var jelly_scene: PackedScene = load("res://scenes/components/jellyfish.tscn")

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
						add_child(_player)
					"T":
						if editor: continue
						var theo: Node2D = theo_scene.instantiate()
						theo.global_position = _cell_center(x_tile + col, row_index)
						add_child(theo)
					"J":
						if editor: continue
						var jelly: Node2D = jelly_scene.instantiate()
						jelly.global_position = _cell_center(x_tile + col, row_index)
						add_child(jelly)
					"x":
						_add_marker(markers, x_tile + col, row_index)
		_add_label(labels, zone, x_tile, width)
		_zone_bounds.append(Vector2(x_tile * TILE, (x_tile + width) * TILE))
		_zone_spawns.append(_zone_entrance(rows, x_tile))
		x_tile += width + ZONE_GAP

## 掉出世界底部就回到所在分区的入口重生（参考 Strawberry Jam 的教学房：失败立刻重来）。
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player) or _player.global_position.y < KILL_Y:
		return
	_player.global_position = _spawn_for(_player.global_position.x)
	_player.velocity = Vector2.ZERO
	_player.dash_count = _player.max_dashes
	_player.stamina = _player.max_stamina

func _spawn_for(x: float) -> Vector2:
	for index in _zone_bounds.size():
		if x < _zone_bounds[index].y:
			return _zone_spawns[index]
	return _zone_spawns[_zone_spawns.size() - 1]

## 分区入口：地面行第一块实体的正上方
func _zone_entrance(rows: Array, x_tile: int) -> Vector2:
	var floor_row: String = rows[FLOOR_ROW]
	for col in floor_row.length():
		if floor_row[col] == "#":
			return _cell_floor(x_tile + col + 1, FLOOR_ROW - 1)
	return _cell_floor(x_tile + 1, FLOOR_ROW - 1)

func _add_solid(terrain: StaticBody2D, visuals: Node2D, col: int, row: int, cols: int) -> void:
	var size := Vector2(cols * TILE, TILE)
	var origin := Vector2(col * TILE, row * TILE)
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = origin + size * 0.5
	terrain.add_child(shape)
	var visual := ColorRect.new()
	visual.position = origin
	visual.size = size
	visual.color = SOLID_COLOR
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visuals.add_child(visual)

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

func _cell_center(col: int, row: int) -> Vector2:
	return Vector2(col * TILE + TILE * 0.5, row * TILE + TILE * 0.5)
