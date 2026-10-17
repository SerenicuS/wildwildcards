extends RefCounted

# Cosmetic geometry only. Never consumed by combat rules, ammo, or bot logic.
const MODELS := {"peacemaker": "Peacemaker", "schofield": "Schofield", "python": "Python", "cobra": "Cobra"}
const FINISHES := {"iron": "Classic iron", "blued": "Blued steel", "silver": "Polished silver", "gold": "Ornate gold"}
const GRIPS := {"walnut": "Walnut", "ebony": "Ebony", "ivory": "Ivory-style", "engraved": "Engraved"}
const METALS := {"iron": Color("9ca8ac"), "blued": Color("40546e"), "silver": Color("dce6e9"), "gold": Color("d9ac53")}
const WOODS := {"walnut": Color("714b38"), "ebony": Color("2a2630"), "ivory": Color("e6d2a4"), "engraved": Color("a2734b")}
const LENGTHS := {"peacemaker": 32.0, "schofield": 31.0, "python": 48.0, "cobra": 20.0}

static func defaults() -> Dictionary:
	return {"revolver_model": "peacemaker", "revolver_finish": "iron", "revolver_grip": "walnut"}

static func randomized(rng: RandomNumberGenerator) -> Dictionary:
	var models: Array = MODELS.keys()
	var finishes: Array = FINISHES.keys()
	var grips: Array = GRIPS.keys()
	return {
		"revolver_model": models[rng.randi_range(0, models.size() - 1)],
		"revolver_finish": finishes[rng.randi_range(0, finishes.size() - 1)],
		"revolver_grip": grips[rng.randi_range(0, grips.size() - 1)]
	}

static func sanitize(value: Variant) -> Dictionary:
	var result := defaults()
	if value is Dictionary:
		for entry in [["revolver_model", MODELS], ["revolver_finish", FINISHES], ["revolver_grip", GRIPS]]:
			var choice: Variant = value.get(entry[0])
			if choice is String and entry[1].has(choice):
				result[entry[0]] = choice
	return result

static func describe(value: Dictionary) -> String:
	var look := sanitize(value)
	return "%s · %s · %s" % [MODELS[look.revolver_model], FINISHES[look.revolver_finish], GRIPS[look.revolver_grip]]

static func muzzle(value: Dictionary) -> Vector2:
	return Vector2(LENGTHS.get(value.get("revolver_model"), 32.0), -4)

static func draw_weapon(canvas: CanvasItem, value: Dictionary, reload_amount: float = 0.0, age: float = 0.0) -> void:
	var model: String = value.get("revolver_model", "peacemaker")
	var finish: String = value.get("revolver_finish", "iron")
	var grip: String = value.get("revolver_grip", "walnut")
	var metal: Color = METALS.get(finish, METALS.iron)
	var wood: Color = WOODS.get(grip, WOODS.walnut)
	var length: float = LENGTHS.get(model, 32.0)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(9, 0), Vector2(8, 17), Vector2(-5, 14)]), metal.darkened(0.35))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(7, 2), Vector2(6, 14), Vector2(-2, 12)]), wood)
	canvas.draw_circle(Vector2(3, 8), 0.9, metal.lightened(0.3))
	if grip == "engraved":
		for y in [4, 7, 10]:
			canvas.draw_line(Vector2(0, y), Vector2(6, y + 3), wood.darkened(0.5), 0.8, true)
	elif grip == "walnut":
		canvas.draw_line(Vector2(0, 3), Vector2(0, 10), wood.lightened(0.2), 0.8)
	canvas.draw_arc(Vector2(13, 4), 5, -0.5, 2.7, 12, metal.darkened(0.3), 1.5, true)
	canvas.draw_rect(Rect2(-2, -8, length + 2, 9), metal)
	canvas.draw_line(Vector2(14, -7), Vector2(length, -7), metal.lightened(0.25), 1)
	canvas.draw_rect(Rect2(length - 4, -11, 3, 3), metal.darkened(0.3))
	canvas.draw_line(Vector2(-2, -7), Vector2(-5, -11), metal.darkened(0.15), 2)
	match model:
		"schofield":
			canvas.draw_rect(Rect2(12, -10, 17, 3), metal.darkened(0.1))
			canvas.draw_circle(Vector2(15, 1), 3, metal.darkened(0.35))
			canvas.draw_circle(Vector2(15, 1), 1, metal.lightened(0.4))
			canvas.draw_rect(Rect2(0, -12, 5, 4), metal.lightened(0.2))
		"python":
			canvas.draw_rect(Rect2(13, 0, length - 13, 5), metal.darkened(0.2))
			canvas.draw_rect(Rect2(14, -12, length - 14, 4), metal)
			for x in [19, 27, 35]:
				canvas.draw_rect(Rect2(x, -11, 4, 2), metal.darkened(0.65))
		"cobra":
			canvas.draw_rect(Rect2(-4, -7, 8, 9), metal.darkened(0.15))
			canvas.draw_rect(Rect2(13, -7, 7, 10), metal)
		_:
			canvas.draw_rect(Rect2(14, -2, length - 14, 2), metal.darkened(0.3))
	var radius: float = 5.5 if model == "cobra" else 7.0
	canvas.draw_circle(Vector2(8, -3), radius, metal.darkened(0.28))
	canvas.draw_arc(Vector2(8, -3), radius - 2, 0, TAU, 12, metal.lightened(0.25), 1, true)
	if finish == "gold":
		canvas.draw_arc(Vector2(20, -4), 2, 0.2, PI * 1.6, 8, Color("80562b"), 0.8, true)
		canvas.draw_line(Vector2(23, -4), Vector2(length - 2, -4), Color("f9dea0"), 0.8)
	if reload_amount > 0.0:
		for chamber in range(5):
			var angle: float = chamber * TAU / 5.0 + age * 19.0
			canvas.draw_circle(Vector2(8, -3) + Vector2.from_angle(angle) * (radius - 3), 1.2, metal.darkened(0.65))
