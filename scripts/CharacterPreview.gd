extends "res://scripts/Arena.gd"

var coat_override: Color = Color.TRANSPARENT

func _ready() -> void:
	active = true

func _draw() -> void:
	_draw_fighter(Vector2.ZERO, 1.0, coat_override if coat_override.a > 0 else player_coat(), 0)
