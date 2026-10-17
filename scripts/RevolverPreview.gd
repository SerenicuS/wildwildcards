extends Control

const Revolver = preload("res://scripts/RevolverAppearance.gd")
var configuration: Dictionary = Revolver.defaults()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_configuration(value: Dictionary) -> void:
	configuration = Revolver.sanitize(value)
	queue_redraw()

func _draw() -> void:
	# Enlarged to show engraving while keeping the complete hammer/grip in frame.
	draw_set_transform(size * 0.5 - Vector2(70, 8), 0, Vector2(3.5, 3.5))
	Revolver.draw_weapon(self, configuration)
	draw_set_transform(Vector2.ZERO)
