class_name DuelArena
extends Node2D

const Arenas = preload("res://scripts/ArenaDefinitions.gd")
var arena_id: String = Arenas.DEFAULT_ID
var backdrop: Node2D
var ambient: Node2D

const Appearance = preload("res://scripts/CharacterAppearance.gd")
const Revolver = preload("res://scripts/RevolverAppearance.gd")
var player_appearance: Dictionary = Appearance.defaults()
var opponent_appearance: Dictionary = {"hat": "classic", "outfit": "rust", "accessory": "none", "coat_color": Color("ec8b73")}

func _ready() -> void:
	backdrop = preload("res://scripts/ArenaBackdrop.gd").new()
	backdrop.show_behind_parent = true
	add_child(backdrop)
	ambient = preload("res://scripts/ArenaAmbient.gd").new()
	ambient.show_behind_parent = true
	add_child(ambient)
	set_arena_id(arena_id)

func set_arena_id(value: String) -> void:
	var data: Dictionary = Arenas.definition(value)
	arena_id = data.id
	if is_instance_valid(backdrop):
		backdrop.set_definition(data)
		ambient.configuration = data.ambient
		ambient.clock = clock
		ambient.queue_redraw()

func set_player_appearance(value: Dictionary) -> void:
	player_appearance = Appearance.sanitize(value)
	queue_redraw()

func set_opponent_appearance(value: Dictionary) -> void:
	opponent_appearance = Appearance.sanitize(value)
	if value.has("coat_color"):
		opponent_appearance["coat_color"] = value["coat_color"]
	queue_redraw()

func player_coat() -> Color:
	return Appearance.COLORS[player_appearance.outfit]

func opponent_coat() -> Color:
	if opponent_appearance.has("coat_color"):
		return opponent_appearance.coat_color
	return Appearance.COLORS.get(opponent_appearance.outfit, Color("ec8b73"))

var clock: float = 0.0
var effect_age: float = 10.0
var actions: Array = [0, 0]
var fired: Array = [false, false]
var alive: Array = [true, true]
var clash: bool = false
var active: bool = false

func reset() -> void:
	effect_age = 10.0
	alive = [true, true]
	actions = [0, 0]
	fired = [false, false]
	clash = false
	queue_redraw()

func reveal(result: Dictionary) -> void:
	# Own the resolved visual snapshot; animation never writes combat state.
	actions = result.actions.duplicate()
	fired = result.fired.duplicate()
	alive = [result.left.alive, result.right.alive]
	clash = result.clash
	effect_age = 0.0
	queue_redraw()

func action_pose(index: int) -> Dictionary:
	var age: float = effect_age
	var hand := Vector2(48, -95)
	var angle: float = 0.0
	var reload_amount: float = 0.0
	var shield_alpha: float = 0.0
	if fired[index]:
		var kick: float = pow(maxf(0.0, 1.0 - age / 0.18), 2.0)
		hand += Vector2(-13, -5) * kick
		angle = -0.17 * kick
	elif actions[index] == DuelRules.Action.SHOOT:
		# An empty trigger gets a small aim twitch, never a flash or projectile.
		var click: float = sin(PI * clampf(age / 0.16, 0.0, 1.0))
		hand.x += click * 3.0
		angle = -0.045 * click
	elif actions[index] == DuelRules.Action.RELOAD:
		reload_amount = sin(PI * clampf(age / 0.55, 0.0, 1.0))
		hand += Vector2(-12, 18) * reload_amount
		angle = 0.6 * reload_amount
	elif actions[index] == DuelRules.Action.SHIELD and age < 0.68:
		var brace: float = minf(age / 0.06, 1.0) * minf((0.68 - age) / 0.2, 1.0)
		hand += Vector2(-10, -8) * brace
		angle = -0.25 * brace
		shield_alpha = minf(1.0, (0.68 - age) / 0.2)
	return {"hand": hand, "angle": angle, "reload": reload_amount,
		"shield": shield_alpha, "flash": fired[index] and age < 0.09}

func _world_point(index: int, point: Vector2) -> Vector2:
	var facing: float = 1.0 if index == 0 else -1.0
	var bob: float = sin(clock * 3.0 + index) * 2.0 if alive[index] else 0.0
	return Vector2(350 if index == 0 else 930, 472 + bob) + Vector2(point.x * facing, point.y)

func bullet_trail(index: int) -> Dictionary:
	if not fired[index] or effect_age >= 0.16:
		return {}
	var start := muzzle_world(index)
	var end := Vector2(640, 377) if clash else _world_point(1 - index,
		Vector2(77, -95) if actions[1 - index] == DuelRules.Action.SHIELD else Vector2(0, -95))
	var distance: float = start.distance_to(end)
	var progress: float = clampf(effect_age / 0.1, 0.0, 1.0)
	var head: Vector2 = start.lerp(end, progress)
	var tail: Vector2 = start.lerp(end, maxf(0.0, progress - 65.0 / distance))
	return {"head": head, "tail": tail, "end": end,
		"alpha": minf(1.0, (0.16 - effect_age) / 0.06)}

func muzzle_world(index: int) -> Vector2:
	var pose := action_pose(index)
	var app: Dictionary = player_appearance if index == 0 else opponent_appearance
	return _world_point(index, pose.hand + Revolver.muzzle(app).rotated(pose.angle))

func _process(delta: float) -> void:
	if active:
		clock += delta
		effect_age += delta
		if is_instance_valid(ambient):
			ambient.clock = clock
			ambient.queue_redraw()
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(350, 473), 48, Color(0.04, 0.08, 0.12, 0.35))
	draw_circle(Vector2(930, 473), 48, Color(0.04, 0.08, 0.12, 0.35))
	_draw_fighter(Vector2(350, 472), 1.0, player_coat(), 0)
	_draw_fighter(Vector2(930, 472), -1.0, opponent_coat(), 1)
	for i in range(2):
		var trail := bullet_trail(i)
		if not trail.is_empty():
			draw_line(trail.tail, trail.head, Color(1.0, 0.76, 0.39, trail.alpha * 0.35), 7.0, true)
			draw_line(trail.tail, trail.head, Color(1.0, 0.9, 0.64, trail.alpha), 2.0, true)
			draw_circle(trail.head, 2.5, Color(1.0, 0.96, 0.81, trail.alpha))
		if fired[i] and not clash and actions[1 - i] == DuelRules.Action.SHIELD:
			_draw_sparks(_world_point(1 - i, Vector2(77, -95)), effect_age - 0.09, Color("b9f4ff"))
	if clash:
		_draw_sparks(Vector2(640, 377), effect_age - 0.09, Color("ffdb93"))

func _draw_sparks(point: Vector2, age: float, tint: Color) -> void:
	if age < 0.0 or age >= 0.24:
		return
	var fade: float = 1.0 - age / 0.24
	draw_circle(point, 9.0 * fade, Color(tint, fade * 0.6))
	for i in range(7):
		var direction := Vector2.from_angle(i * TAU / 7.0 + 0.2)
		var reach: float = 9.0 + age * (90.0 + (i % 3) * 35.0)
		var tip := point + direction * reach + Vector2(0, age * age * 110.0)
		draw_line(tip - direction * 7.0 * fade, tip, Color(tint, fade), 2.0, true)

func _draw_fighter(origin: Vector2, facing: float, coat: Color, index: int) -> void:
	var age: float = effect_age
	var action: int = actions[index]
	var fall: float = clampf(age * 4.0, 0.0, 1.0) if not alive[index] else 0.0
	var bob: float = sin(clock * 3.0 + index) * 2.0 if alive[index] else 0.0
	var fighter_transform := Transform2D(-facing * fall * 1.45, Vector2(facing, 1), 0.0, origin + Vector2(0, bob))
	draw_set_transform_matrix(fighter_transform)
	draw_line(Vector2(-17, -42), Vector2(-21, -4), Color("142330"), 17)
	draw_line(Vector2(13, -42), Vector2(21, -4), Color("142330"), 17)
	draw_rect(Rect2(-33, -10, 27, 10), Color("0c1724"))
	draw_rect(Rect2(8, -10, 28, 10), Color("0c1724"))
	var app: Dictionary = player_appearance if index == 0 else opponent_appearance
	_draw_outerwear(app.get("outfit_style", "frontier"), coat)
	draw_rect(Rect2(-30, -49, 59, 9), Color("503737"))
	draw_rect(Rect2(-4, -49, 11, 9), Color("edc27e"))
	draw_circle(Vector2(0, -123), 23, Color("e9bc91"))
	_draw_hat(app.get("hat", "classic"), coat, app.get("hat_color", "original"))
	_draw_accessory(app.get("accessory", "none"), app.get("accessory_color", "original"))
	draw_circle(Vector2(13, -127), 2.5, Color("142330"))
	draw_line(Vector2(4, -108), Vector2(22, -109), Color("80594a"), 3)
	var pose := action_pose(index)
	var hand: Vector2 = pose.hand
	var sleeve: Color = Color("e7d8b6") if app.get("outfit_style") == "waistcoat" else coat
	if pose.reload > 0.0:
		draw_line(Vector2(-20, -85), hand + Vector2(-5, 8), sleeve.darkened(0.1), 12)
		draw_circle(hand + Vector2(-5, 8), 6, Appearance.COLORS.get(app.get("accessory_color"), Color("503737")) if app.accessory == "gloves" else Color("e9bc91"))
	draw_line(Vector2(16, -91), hand, sleeve.lightened(0.12), 16)
	var hand_color: Color = Appearance.COLORS.get(app.get("accessory_color"), Color("503737")) if app.accessory == "gloves" else Color("e9bc91")
	draw_circle(hand, 8, hand_color)
	# Revolver, cylinder and flash share the hand's recoil/reload transform.
	draw_set_transform_matrix(fighter_transform * Transform2D(pose.angle, hand))
	Revolver.draw_weapon(self, app, pose.reload, age)
	if pose.flash:
		var flash_scale: float = 1.0 - age / 0.11
		draw_set_transform_matrix(fighter_transform * Transform2D(pose.angle, hand) * Transform2D(0.0, Revolver.muzzle(app)))
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(15, -13) * flash_scale,
			Vector2(12, -4) * flash_scale, Vector2(29, -1) * flash_scale,
			Vector2(14, 4) * flash_scale, Vector2(19, 11) * flash_scale]), Color("ffc56b"))
		draw_circle(Vector2(5, 0), 5.0 * flash_scale, Color("fff3ba"))
	draw_set_transform_matrix(fighter_transform)
	if pose.shield > 0.0:
		var alpha: float = pose.shield
		draw_colored_polygon(PackedVector2Array([Vector2(41, -143), Vector2(64, -130),
			Vector2(79, -94), Vector2(66, -52), Vector2(42, -29), Vector2(56, -90)]), Color(0.26, 0.74, 0.95, alpha * 0.18))
		draw_arc(Vector2(4, -82), 74, -1.12, 1.12, 28, Color(0.3, 0.85, 1.0, alpha), 5, true)
		draw_arc(Vector2(4, -82), 68, -0.9, 0.9, 22, Color(0.75, 0.96, 1.0, alpha * 0.7), 1.5, true)
	if age < 0.45 and action == DuelRules.Action.RELOAD:
		draw_rect(Rect2(5, -193 - age * 24, 9, 18), Color("ffdc88"))
	if not alive[index] and age < 0.18:
		draw_circle(Vector2(0, -90), 37, Color(1, 0.65, 0.5, 0.65))
	if alive[index] and not alive[1 - index]:
		draw_line(Vector2(-23, -90), Vector2(-41, -127), sleeve, 12)
	draw_set_transform(Vector2.ZERO)

func _draw_hat(style: String, coat: Color, tint: String = "original") -> void:
	var crown: Color = Appearance.COLORS.get(tint, Color("64464a"))
	var brim: Color = Appearance.COLORS.get(tint, Color("49363a"))
	match style:
		"cattleman":
			draw_colored_polygon(PackedVector2Array([Vector2(-40,-152), Vector2(-32,-140), Vector2(33,-140), Vector2(41,-152), Vector2(30,-148), Vector2(-31,-148)]), brim)
			draw_colored_polygon(PackedVector2Array([Vector2(-24,-146),Vector2(-22,-174),Vector2(-10,-178),Vector2(0,-170),Vector2(11,-178),Vector2(24,-173),Vector2(26,-146)]), crown)
			draw_line(Vector2(-22,-149),Vector2(24,-149),coat,5)
		"outlaw":
			draw_colored_polygon(PackedVector2Array([Vector2(-41,-145),Vector2(38,-140),Vector2(34,-132),Vector2(-37,-137)]), brim)
			draw_colored_polygon(PackedVector2Array([Vector2(-26,-142),Vector2(-15,-176),Vector2(14,-167),Vector2(24,-139)]), crown)
			draw_line(Vector2(-24,-147),Vector2(22,-144),coat,5)
		"cavalry":
			draw_line(Vector2(-38,-143),Vector2(40,-143),brim,9)
			draw_colored_polygon(PackedVector2Array([Vector2(-24,-146),Vector2(-16,-175),Vector2(15,-175),Vector2(25,-146)]), crown)
			draw_line(Vector2(-24,-149),Vector2(25,-149),Color("edc27e"),4)
			draw_line(Vector2(14,-160),Vector2(20,-154),Color("edc27e"),2)
			draw_line(Vector2(20,-160),Vector2(14,-154),Color("edc27e"),2)
		"wide_brim":
			draw_rect(Rect2(-41, -146, 84, 8), Color("49363a") if tint == "original" else crown)
			draw_colored_polygon(PackedVector2Array([Vector2(-28, -146), Vector2(-20, -162),
				Vector2(20, -162), Vector2(28, -146)]), Color("795447") if tint == "original" else crown)
			draw_rect(Rect2(-25, -149, 50, 5), coat)
		"gambler":
			draw_rect(Rect2(-33, -146, 68, 7), Color("342d39") if tint == "original" else crown)
			draw_rect(Rect2(-21, -181, 42, 38), Color("544355") if tint == "original" else crown)
			draw_rect(Rect2(-21, -151, 42, 7), coat)
		_:
			draw_rect(Rect2(-32, -146, 67, 8), Color("49363a") if tint == "original" else crown)
			draw_rect(Rect2(-22, -168, 44, 27), Color("64464a") if tint == "original" else crown)
			draw_rect(Rect2(-22, -148, 44, 7), coat)

func _draw_accessory(accessory: String, tint: String = "original") -> void:
	var color: Color = Appearance.COLORS.get(tint, Color("b94743"))
	if accessory == "bandana":
		draw_colored_polygon(PackedVector2Array([Vector2(-20, -103), Vector2(21, -103),
			Vector2(0, -82)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(-18, -102), Vector2(-36, -93),
			Vector2(-26, -82)]), Color("903c3e") if tint == "original" else color.darkened(0.2))
	elif accessory == "badge":
		var points := PackedVector2Array()
		for i in range(10):
			points.append(Vector2(-13, -81) + Vector2.from_angle(-PI / 2 + i * PI / 5) * (8 if i % 2 == 0 else 3.8))
		draw_colored_polygon(points, Color("f3ce7b") if tint == "original" else color)
		draw_circle(Vector2(-13, -81), 2, Color("ad713e"))

	elif accessory == "neckerchief":
		draw_line(Vector2(-19,-101),Vector2(19,-101),color,8)
		draw_colored_polygon(PackedVector2Array([Vector2(8,-101),Vector2(21,-77),Vector2(5,-82),Vector2(0,-101)]),color)
	elif accessory == "belt":
		draw_rect(Rect2(-31,-51,62,13),color)
		for x in [-24,-14,16,26]:
			draw_circle(Vector2(x,-45),2,Color("edc27e"))
		draw_rect(Rect2(-6,-52,15,15),Color("edc27e"),false,3)

func _draw_outerwear(style: String, coat: Color) -> void:
	if style == "duster" or style == "outlaw":
		var hem: float = -7 if style == "duster" else -20
		draw_colored_polygon(PackedVector2Array([Vector2(-28,-101),Vector2(27,-101),Vector2(39,hem),Vector2(10,hem),Vector2(0,-45),Vector2(-9,hem),Vector2(-40,hem)]),coat.darkened(0.12))
	if style == "waistcoat":
		draw_colored_polygon(PackedVector2Array([Vector2(-23,-101),Vector2(22,-101),Vector2(22,-48),Vector2(12,-34),Vector2(0,-43),Vector2(-12,-34),Vector2(-23,-48)]),coat)
		draw_line(Vector2(-22,-99),Vector2(-22,-49),coat.darkened(0.3),5)
	else:
		draw_rect(Rect2(-29,-101,57,63),coat)
		draw_rect(Rect2(-29,-101,13,63),coat.darkened(0.3))
	match style:
		"poncho":
			draw_colored_polygon(PackedVector2Array([Vector2(-20,-108),Vector2(20,-108),Vector2(46,-57),Vector2(0,-35),Vector2(-46,-57)]),coat)
			draw_line(Vector2(-35,-59),Vector2(0,-43),coat.darkened(0.35),5)
			draw_line(Vector2(0,-43),Vector2(35,-59),coat.darkened(0.35),5)
		"waistcoat":
			draw_colored_polygon(PackedVector2Array([Vector2(-13,-102),Vector2(13,-102),Vector2(0,-71)]),Color("e7d8b6"))
			for y in [-69,-59]:
				draw_circle(Vector2(0,y),2,Color("edc27e"))
		"outlaw":
			draw_line(Vector2(-22,-101),Vector2(-8,-74),coat.lightened(0.25),9)
			draw_line(Vector2(22,-101),Vector2(8,-74),coat.lightened(0.25),9)
		"duster":
			draw_line(Vector2(-15,-99),Vector2(-6,-53),coat.lightened(0.2),6)
			draw_line(Vector2(15,-99),Vector2(6,-53),coat.lightened(0.2),6)
