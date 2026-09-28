class_name VirusLibrary
extends RefCounted
## 病毒库：条目 =「块类型 × 病毒类型」，解析进度 0~3 决定威胁等级
## 0=高危(负面高) 1=严重(中) 2=一般(低) 3=安全(无)

var progress: Dictionary = {}

func key_of(color: int, virus: String) -> String:
	return "%d:%s" % [color, virus]

func progress_of(color: int, virus: String) -> int:
	return int(progress.get(key_of(color, virus), 0))

func tier_of(color: int, virus: String) -> int:
	return mini(progress_of(color, virus), 3)

func feed(color: int, virus: String) -> int:
	var k := key_of(color, virus)
	var p := progress_of(color, virus)
	if p < 3:
		progress[k] = p + 1
	return mini(progress[k], 3)

func tier_name(tier: int) -> String:
	match tier:
		0: return "高危"
		1: return "严重"
		2: return "一般"
		_: return "安全"
