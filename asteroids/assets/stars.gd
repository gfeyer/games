extends Node2D

@export var star_count: int = 150
@export var parallax_factor: float = 0.1

var stars: Array[Dictionary] = []
var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	generate_stars()
	queue_redraw()

func generate_stars() -> void:
	for i in range(star_count):
		var star = {
			"position": Vector2(randf() * screen_size.x, randf() * screen_size.y),
			"size": randf_range(1.0, 3.0),
			"brightness": randf_range(0.3, 1.0),
			"twinkle_speed": randf_range(1.0, 3.0),
			"twinkle_offset": randf() * TAU
		}
		stars.append(star)

func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var time = Time.get_ticks_msec() / 1000.0

	for star in stars:
		var twinkle = (sin(time * star.twinkle_speed + star.twinkle_offset) + 1.0) / 2.0
		var alpha = star.brightness * (0.5 + 0.5 * twinkle)

		var color = Color(1.0, 1.0, 1.0, alpha)

		# Some stars have slight color tint
		if star.brightness > 0.7:
			var tint = fmod(star.twinkle_offset, 3.0)
			if tint < 1.0:
				color = Color(0.8, 0.9, 1.0, alpha)  # Blue tint
			elif tint < 2.0:
				color = Color(1.0, 1.0, 0.8, alpha)  # Yellow tint

		draw_circle(star.position, star.size, color)

		# Add glow to brighter stars
		if star.size > 2.0:
			var glow_color = color
			glow_color.a *= 0.3
			draw_circle(star.position, star.size * 2, glow_color)
