class_name WandRuntime
extends RefCounted
## 法杖运行时：作用域内蓝块按邻接优先充能，充满即释放

var wand: BlockInstance
var grid: GridModel
var library: VirusLibrary
var mana: float = 0.0
var cast_timer: float = 0.0
var cast_count: int = 0
var on_release: Callable  # (blue: BlockInstance, damage: float)

func _init(wand_block: BlockInstance, grid_ref: GridModel, lib: VirusLibrary) -> void:
	wand = wand_block
	grid = grid_ref
	library = lib
	mana = float(wand.def()["max_mana"])

func tick(delta: float) -> void:
	var d := wand.def()
	mana = minf(mana + float(d["mana_regen"]) * delta, float(d["max_mana"]))
	cast_timer -= delta
	if cast_timer > 0.0:
		return
	for blue in grid.cast_order(Vector2i(wand.x, wand.y)):
		if blue.charge >= float(blue.def()["max_charge"]):
			continue
		if mana < float(blue.def()["max_charge"]):
			break
		mana -= float(blue.def()["max_charge"])
		blue.charge = float(blue.def()["max_charge"])
		var dmg := float(blue.def()["damage"])
		on_release.call(blue, dmg)
		blue.charge = 0.0
		cast_timer = float(d["cast_interval"])
		cast_count += 1
		return
	cast_timer = float(d["cast_interval"])
