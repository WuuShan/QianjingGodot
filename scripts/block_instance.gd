class_name BlockInstance
extends RefCounted
## 运行时程序块实例：定义 + 网格坐标 + 旋转 + 病毒槽 + 充能

var id: String
var x: int
var y: int
var rotation: int = 0
var viruses: Array = []
var charge: float = 0.0

func _init(block_id: String, px: int, py: int, rot: int = 0) -> void:
	id = block_id
	x = px
	y = py
	rotation = rot

func def() -> Dictionary:
	return Defs.block(id)

func current_size() -> Vector2i:
	var d := def()
	if rotation % 2 == 0:
		return Vector2i(int(d["size_w"]), int(d["size_h"]))
	return Vector2i(int(d["size_h"]), int(d["size_w"]))

func cells() -> Array[Vector2i]:
	var s := current_size()
	var out: Array[Vector2i] = []
	for dy in range(s.y):
		for dx in range(s.x):
			out.append(Vector2i(x + dx, y + dy))
	return out

func virus_capacity() -> int:
	var d := def()
	return int(d["size_w"]) * int(d["size_h"])

func has_virus_capacity() -> bool:
	return viruses.size() < virus_capacity()

func inject(virus: String) -> void:
	viruses.append(virus)

func virus_text() -> String:
	return "毒 %d/%d" % [viruses.size(), virus_capacity()]
