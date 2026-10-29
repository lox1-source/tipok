extends Polygon2D

## A floor shadow that follows the player's feet without rotating.
func _ready() -> void:
	polygon = PackedVector2Array()
	color = Color.WHITE
	z_index = -1
	queue_redraw()

func _draw() -> void:
	for layer in range(12, 0, -1):
		var radius := float(layer) / 12.0
		var points := PackedVector2Array()
		for segment in range(48):
			var angle := TAU * float(segment) / 48.0
			points.append(Vector2(cos(angle) * 14.0 * radius, sin(angle) * 5.0 * radius + 1.0))
		draw_colored_polygon(points, Color(0.015, 0.012, 0.025, 0.045))
