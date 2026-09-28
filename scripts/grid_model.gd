class_name GridModel
extends RefCounted
## 网格模型：作用域（跟随法杖）+ 占用 + 摆放 + 邻接优先施法序列

const W := 16
const H := 12

signal placed(b: BlockInstance)
signal removed(b: BlockInstance)

var zones: Array[Rect2i] = []
var cell_owner: Dictionary = {}
var blocks: Array[BlockInstance] = []

func clear_zones() -> void:
	zones.clear()

func add_zone(z: Rect2i) -> void:
	zones.append(z)

func in_any_zone(cell: Vector2i) -> bool:
	for z in zones:
		if z.has_point(cell):
			return true
	return false

func has_wand() -> bool:
	for b in blocks:
		if int(b.def()["color"]) == Defs.GREEN:
			return true
	return false

func block_at(cell: Vector2i) -> BlockInstance:
	return cell_owner.get(cell)

func can_place(b: BlockInstance) -> bool:
	for cell in b.cells():
		if not in_any_zone(cell):
			return false
		if cell_owner.has(cell):
			return false
	# 虚空规则：绿块（法杖）是地基——没有绿块时，其他颜色不可放置
	if int(b.def()["color"]) != Defs.GREEN and not has_wand():
		return false
	return true

func place(b: BlockInstance) -> void:
	blocks.append(b)
	for cell in b.cells():
		cell_owner[cell] = b
	placed.emit(b)

func remove(b: BlockInstance) -> void:
	blocks.erase(b)
	for cell in b.cells():
		cell_owner.erase(cell)
	removed.emit(b)

## 邻接优先施法序列：BFS 穿透空格（限作用域内），按 距离→行→列 排序
func cast_order(origin: Vector2i) -> Array[BlockInstance]:
	var dist := {}
	if not in_any_zone(origin):
		return []
	dist[origin] = 0
	var queue: Array[Vector2i] = [origin]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var nxt: Vector2i = cur + d
			if dist.has(nxt) or not in_any_zone(nxt):
				continue
			dist[nxt] = int(dist[cur]) + 1
			queue.append(nxt)
	var keyed := []
	for b in blocks:
		if int(b.def()["color"]) != 1:
			continue
		var best := 1 << 30
		for cell in b.cells():
			if dist.has(cell):
				best = mini(best, int(dist[cell]))
		keyed.append([best, b.y, b.x, b])
	keyed.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	var out: Array[BlockInstance] = []
	for k in keyed:
		out.append(k[3])
	return out
