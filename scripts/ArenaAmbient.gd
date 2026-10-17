extends Node2D

var configuration: Dictionary = {"kind": "none", "count": 0}
var clock: float = 0.0

func _draw() -> void:
	var kind: String = configuration.kind
	for i in range(mini(int(configuration.count), 16)):
		var color: Color = configuration.color
		var speed: float = configuration.speed
		match kind:
			"dust":
				var x: float = fposmod(i * 113.0 + clock * speed, 1280)
				var y: float = 442.0 + (i % 4) * 9 + sin(clock * 0.7 + i) * 3
				draw_line(Vector2(x, y), Vector2(x + 14 + i % 9, y), color, 1)
			"lantern":
				var position: Vector2 = configuration.positions[i]
				draw_circle(position, 18 + sin(clock * speed + i) * 2, color)
			"steam":
				var age: float = fposmod(clock * speed + i * 13, 90)
				color.a *= sin(PI * age / 90)
				draw_circle(configuration.origin + Vector2(sin(i + clock * 0.3) * 8 + age * 0.15, -age), 6 + age * 0.11, color)
			"mist":
				var x: float = fposmod(i * 199.0 + clock * speed, 1420) - 70
				var y: float = 446 + (i % 3) * 10 + sin(clock * 0.3 + i) * 3
				draw_line(Vector2(x, y), Vector2(x + 86, y), color, 6, true)
