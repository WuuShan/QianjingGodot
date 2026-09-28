class_name Defs
## 程序块定义注册表（静态）

const GREEN := 0
const BLUE := 1
const YELLOW := 2
const RED := 3

static var _blocks: Dictionary = {}

static func register_block(id: String, display: String, color: int, size_w: int, size_h: int, extra: Dictionary = {}, zone_w: int = 0, zone_h: int = 0) -> void:
	var data := {
		"id": id,
		"display": display,
		"color": color,
		"size_w": size_w,
		"size_h": size_h,
		"zone_w": zone_w,
		"zone_h": zone_h,
	}
	data.merge(extra, true)
	_blocks[id] = data

static func block(id: String) -> Dictionary:
	return _blocks.get(id, {})

static func color_of(color: int) -> Color:
	match color:
		GREEN:
			return Color(0.35, 0.9, 0.4)
		BLUE:
			return Color(0.35, 0.55, 1.0)
		YELLOW:
			return Color(1.0, 0.85, 0.3)
		_:
			return Color(1.0, 0.4, 0.4)
