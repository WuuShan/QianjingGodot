extends Node2D
## 千境原型主场景：12×10 虚空装备栏 + 暂存库 + 法杖施法 + 假人
## 全部渲染由本节点 _draw() 完成（单通道，无子节点）

const CELL := 1.0          # 1 格 = 1 世界单位（Camera zoom 60 → 屏幕 60px）
const ZONE_W := 12
const ZONE_H := 10
const QUEUE_SLOTS := 10
const QUEUE_COL_W := 0.9
const QUEUE_ROW_H := 1.0

var grid: GridModel
var library: VirusLibrary
var wand_rt: WandRuntime
var wand_block: BlockInstance
var inventory: Array[BlockInstance] = []   # 暂存库（10 格）
var corpse: Array[BlockInstance] = []      # 尸体子背包

var player_pos := Vector2(13.0, 5.0)
var player_speed := 5.0
var dummy_pos := Vector2(14.5, 8.0)
var dummy_hp := 50.0
var dummy_max := 50.0
var projectiles: Array[Dictionary] = []    # {pos, dir, speed, damage}

# 拖拽状态
var _keys_now := {}
var _prev_keys := {}
var backpack_open := false               # 背包界面（装备栏+暂存库+尸体）默认关闭，B 开关
var drag_block: BlockInstance = null
var drag_source := -1   # 0=暂存库 1=尸体 2=网格
var drag_origin := Vector2i.ZERO
var mouse_world := Vector2.ZERO

func _ready() -> void:
	_register_defs()
	library = VirusLibrary.new()
	grid = GridModel.new()

	# 法杖 + 样例程序块
	wand_block = BlockInstance.new("wand_basic", 0, 0)
	var b1 := BlockInstance.new("bolt_1", 2, 2)
	var b2 := BlockInstance.new("bolt_2", 4, 0)
	var amp := BlockInstance.new("amp_1", 6, 3)
	var ext := BlockInstance.new("ext_1", 7, 3)
	grid.place(wand_block)
	grid.place(b1)
	grid.place(b2)
	grid.place(amp)
	grid.place(ext)

	# 作用域跟随法杖
	_refresh_zone()

	wand_rt = WandRuntime.new(wand_block, grid, library)
	wand_rt.on_release = _on_spell_release

	# 暂存库样例
	inventory.append(BlockInstance.new("bolt_1", 0, 0))
	inventory.append(BlockInstance.new("amp_1", 0, 0))

func _register_defs() -> void:
	Defs.register_block("wand_basic", "初火·法杖", Defs.GREEN, 1, 1,
		{"max_mana": 50.0, "mana_regen": 12.0, "cast_interval": 0.4}, ZONE_W, ZONE_H)
	Defs.register_block("bolt_1", "净化飞弹", Defs.BLUE, 1, 1,
		{"max_charge": 3.0, "damage": 10.0, "speed": 8.0})
	Defs.register_block("bolt_2", "重型净弹", Defs.BLUE, 2, 1,
		{"max_charge": 6.0, "damage": 18.0, "speed": 6.0})
	Defs.register_block("amp_1", "超频印记", Defs.YELLOW, 1, 1)
	Defs.register_block("ext_1", "棱镜核心", Defs.RED, 1, 1)
	Defs.register_block("shield_1", "护盾程序", Defs.BLUE, 1, 1)

func _refresh_zone() -> void:
	grid.clear_zones()
	grid.add_zone(Rect2i(wand_block.x, wand_block.y, ZONE_W, ZONE_H))

var _watched := [KEY_B, KEY_F, KEY_V, KEY_G, KEY_K, KEY_R]

func _key_just(key: Key) -> bool:
	return bool(_keys_now.get(key, false)) and not bool(_prev_keys.get(key, false))

func _snapshot_keys() -> void:
	_prev_keys = _keys_now.duplicate()
	for k in _watched:
		_keys_now[k] = Input.is_key_pressed(k)

func _process(delta: float) -> void:
	_snapshot_keys()
	wand_rt.tick(delta)
	_move_player(delta)
	_process_projectiles(delta)
	_process_drag(delta)
	_process_keys()
	queue_redraw()

func _move_player(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	player_pos += v.normalized() * player_speed * delta

func _process_keys() -> void:
	if _key_just(KEY_B) and drag_block == null:
		backpack_open = not backpack_open
	if _key_just(KEY_F):
		var p := library.feed(1, "worm")
		print("[喂库] 蓝×蠕虫 解析进度 %d/3（%s）" % [p, library.tier_name(p)])
	if _key_just(KEY_V):
		for b in grid.blocks:
			if int(b.def()["color"]) == 1 and b.has_virus_capacity():
				b.inject("worm")
				print("[注入] %s 装入蠕虫（%d/%d），100%% 成功" % [b.id, b.viruses.size(), b.virus_capacity()])
				return
		print("[注入] 所有蓝块容量已满")
	if _key_just(KEY_G):
		for b in grid.blocks:
			b.RemoveVirusPlaceholder if false else null
		print("[净空] 蓝块病毒已卸下")
	if _key_just(KEY_K):
		corpse.append(BlockInstance.new("bolt_2", 0, 0))
		corpse.append(BlockInstance.new("ext_1", 0, 0))
		print("[拾取] 尸体子背包生成：%d 个程序块" % corpse.size())

func _process_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["pos"] = p["pos"] + p["dir"] * float(p["speed"]) * delta
		projectiles[i] = p
		if Vector2(dummy_pos).distance_to(p["pos"]) < 0.55:
			_dummy_hit(float(p["damage"]))
			projectiles.remove_at(i)

func _dummy_hit(dmg: float) -> void:
	dummy_hp -= dmg
	if dummy_hp <= 0.0:
		print("[击杀] 假人病毒被消灭（累计伤害生效）")
		dummy_hp = dummy_max

# ---------- 拖拽 ----------

func _process_drag(delta: float) -> void:
	if drag_block == null:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) == false \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) == Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			pass
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_try_pick(get_global_mouse_position())
		return
	# 幽灵跟随
	mouse_world = get_global_mouse_position()

	if _key_just(KEY_R):
		drag_block.rotation = (drag_block.rotation + 1) % 4

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) == false:
		_drop(get_global_mouse_position())

func _try_pick(world: Vector2) -> void:
	if not backpack_open:
		return  # 背包关闭时不响应拾取
	# 网格上的块
	for b in grid.blocks:
		for cell in b.cells():
			if Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(world) < 0.6:
				drag_block = b
				drag_source = 2
				drag_origin = Vector2i(b.x, b.y)   # 记录原位，放不回去时退回
				grid.remove(b)
				return
	# 暂存库排队块
	for i in range(inventory.size()):
		var slot := _slot_pos(i)
		if slot.distance_to(world) < 0.6:
			drag_block = inventory[i]
			drag_source = 0
			inventory.remove_at(i)
			return
	# 尸体子背包
	for i in range(corpse.size()):
		var slot := _corpse_slot_pos(i)
		if slot.distance_to(world) < 0.6:
			drag_block = corpse[i]
			drag_source = 1
			corpse.remove_at(i)
			return

func _slot_pos(i: int) -> Vector2:
	var col := i % 2
	var row := i / 2
	return Vector2(-2.1 + col * 0.9, 6.6 - row * 1.0)

func _corpse_slot_pos(i: int) -> Vector2:
	return Vector2(-2.1 + (i % 2) * 0.9, 8.6 - (i / 2) * 1.0)

func _drop(world: Vector2) -> void:
	var b := drag_block
	var s := b.current_size()
	b.x = int(round(world.x - s.x / 2.0))
	b.y = int(round(world.y - s.y / 2.0))

	if grid.can_place(b):
		grid.place(b)
		if drag_source == 1:
			pass  # 从尸体拖出成功即消耗
		elif drag_source == 0:
			pass  # 从暂存库拖出成功即保持在外
	else:
		match drag_source:
			2:
				# 网格拿出的：退回原位
				b.x = drag_origin.x
				b.y = drag_origin.y
				if grid.can_place(b):
					grid.place(b)
				else:
					_to_stash(b)
			0:
				_to_stash(b)
			1:
				_to_stash(b)
	drag_block = null
	drag_source = -1

func _to_stash(b: BlockInstance) -> void:
	if inventory.size() < QUEUE_SLOTS:
		inventory.append(b)
		print("[暂存库] %s 入库（%d/10）" % [b.def()["display"], inventory.size()])
	else:
		var c := float(b.def()["price_coin"] if b.def().has("price_coin") else 0.0)
		print("[暂存库] 已满：%s 折算弃置" % b.def()["display"])

# ---------- 施法 ----------

func _on_spell_release(blue: BlockInstance, damage: float) -> void:
	var origin := player_pos
	var dir := Vector2.RIGHT
	dir = (Vector2(dummy_pos) - origin).normalized()
	projectiles.append({
		"pos": origin,
		"dir": dir,
		"speed": float(blue.def()["speed"]) if float(blue.def()["speed"]) > 0 else 8.0,
		"damage": damage,
	})

# ---------- 绘制 ----------

func _draw() -> void:
	_draw_player()
	_draw_dummy()
	_draw_projectiles()
	if not backpack_open:
		return  # 背包关闭：世界只显示玩家/假人/弹幕，虚空界面整体隐藏
	_draw_zone()
	_draw_stash()
	_draw_grid_blocks()
	_draw_queue_items()
	_draw_corpse_items()
	_draw_labels()
	_draw_drag_ghost()

func _draw_zone() -> void:
	var z := Rect2(Vector2(wand_block.x, wand_block.y), Vector2(ZONE_W, ZONE_H))
	draw_rect(z, Color(0.02, 0.02, 0.05, 0.95))
	var fc := Color(0.3, 1.0, 0.6, 0.9)
	var t := 0.08
	draw_rect(Rect2(Vector2(zx(z) - t, zy(z) + zh(z)), Vector2(zw(z) + t * 2, t)), fc)
	draw_rect(Rect2(Vector2(zx(z) - t, zy(z) - t), Vector2(zw(z) + t * 2, t)), fc)
	draw_rect(Rect2(Vector2(zx(z) - t, zy(z) - t), Vector2(t, zh(z) + t * 2)), fc)
	draw_rect(Rect2(Vector2(zx(z) + zw(z), zy(z) - t), Vector2(t, zh(z) + t * 2)), fc)

func zx(z: Rect2) -> float: return z.position.x
func zy(z: Rect2) -> float: return z.position.y
func zw(z: Rect2) -> float: return z.size.x
func zh(z: Rect2) -> float: return z.size.y

func _draw_stash() -> void:
	var qx := -2.7
	var qy := 0.7
	var qw := 1.9
	var qh := 6.4
	var fc := Color(0.3, 1.0, 0.6, 0.9)
	var t := 0.06
	draw_rect(Rect2(Vector2(qx, qy), Vector2(qw, qh)), Color(0.06, 0.06, 0.09, 0.9))
	draw_rect(Rect2(Vector2(qx - t, qy - t), Vector2(qw + t * 2, t)), fc)
	draw_rect(Rect2(Vector2(qx - t, qy + qh), Vector2(qw + t * 2, t)), fc)
	draw_rect(Rect2(Vector2(qx - t, qy), Vector2(t, qh)), fc)
	draw_rect(Rect2(Vector2(qx + qw, qy), Vector2(t, qh)), fc)
	draw_string(ThemeDB.fallback_font, Vector2(qx, qy - 0.2), "暂存库", HORIZONTAL_ALIGNMENT_LEFT, -1, 1, Color(0.7, 1.0, 0.8))

func _draw_labels() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(wand_block.x, wand_block.y - 0.25), "装备栏（程序运行区）", HORIZONTAL_ALIGNMENT_LEFT, -1, 1, Color(0.7, 1.0, 0.8))

func _draw_grid_blocks() -> void:
	for b in grid.blocks:
		var s := b.current_size()
		var col := Defs.color_of(int(b.def()["color"]))
		draw_rect(Rect2(Vector2(b.x, b.y), Vector2(s.x, s.y)), Color(col.r, col.g, col.b, 0.9))
		_draw_label_small(Vector2(b.x + 0.1, b.y + 0.3), b.def()["display"])
		_draw_label_small(Vector2(b.x + 0.1, b.y + 0.8), b.virus_text())

func _draw_label_small(pos: Vector2, text) -> void:
	draw_string(ThemeDB.fallback_font, pos, str(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 1, Color(0.1, 0.1, 0.15))

func _draw_queue_items() -> void:
	for i in range(inventory.size()):
		var b := inventory[i]
		var s := b.current_size()
		var fit := minf(0.72 / maxf(1, s.x), 0.72 / maxf(1, s.y))
		var sz := Vector2(s.x, s.y) * fit
		var col := Defs.color_of(int(b.def()["color"]))
		draw_rect(Rect2(_slot_pos(i), sz), col)
		_draw_label_small(_slot_pos(i) + Vector2(0.05, 0.4), b.virus_text())

func _draw_corpse_items() -> void:
	for i in range(corpse.size()):
		var b := corpse[i]
		var s := b.current_size()
		var fit := minf(0.72 / maxf(1, s.x), 0.72 / maxf(1, s.y))
		var sz := Vector2(s.x, s.y) * fit
		var col := Defs.color_of(int(b.def()["color"]))
		draw_rect(Rect2(_corpse_slot_pos(i), sz), col)

func _draw_player() -> void:
	draw_rect(Rect2(player_pos - Vector2(0.4, 0.4), Vector2(0.8, 0.8)), Color(0.9, 0.95, 1.0))

func _draw_dummy() -> void:
	var ratio := dummy_hp / dummy_max
	draw_rect(Rect2(dummy_pos - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), Color(1.0 - ratio * 0.8, 0.2 + ratio * 0.1, 0.25))
	draw_rect(Rect2(dummy_pos - Vector2(0.5, 0.75), Vector2(1.0 * ratio, 0.12)), Color(0.9, 0.3, 0.3))

func _draw_projectiles() -> void:
	for p in projectiles:
		draw_rect(Rect2(p["pos"] - Vector2(0.08, 0.08), Vector2(0.16, 0.16)), Color.WHITE)

func _draw_drag_ghost() -> void:
	if drag_block == null:
		return
	var s := drag_block.current_size()
	var mp := get_global_mouse_position()
	var top := Vector2(mp.x - s.x / 2.0, mp.y - s.y / 2.0)
	var target := Vector2i(int(round(mp.x - s.x / 2.0)), int(round(mp.y - s.y / 2.0)))
	var probe := BlockInstance.new(drag_block.id, target.x, target.y, drag_block.rotation)
	var valid := grid.can_place(probe)
	var col := Color(0.2, 0.9, 0.3, 0.5) if valid else Color(0.9, 0.2, 0.2, 0.5)
	draw_rect(Rect2(Vector2(target.x, target.y), Vector2(s.x, s.y)), col)
	draw_rect(Rect2(top, Vector2(s.x, s.y)), Color(1, 1, 1, 0.25))
