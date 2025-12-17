extends Node2D
class_name Projectile

const ExplosionScene = preload("res://effects/explosion.tscn")

var speed: float = 300.0
var damage: int = 0
var target: Node2D = null
var shooter_faction: int = 0
var projectile_color: Color = Color(1, 0.8, 0)  # Yellow/orange

func setup(target_node: Node2D, dmg: int, faction: int, proj_speed: float = 300.0) -> void:
	target = target_node
	damage = dmg
	shooter_faction = faction
	speed = proj_speed

func _process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		# Target died, remove projectile with small explosion
		spawn_miss_effect()
		queue_free()
		return

	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta

	# Rotate to face direction
	rotation = direction.angle()

	# Check if hit
	if global_position.distance_to(target.global_position) < 12:
		hit_target()

func hit_target() -> void:
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)

	spawn_hit_effect()
	queue_free()

func spawn_hit_effect() -> void:
	var explosion = ExplosionScene.instantiate()
	explosion.global_position = global_position
	explosion.setup(12.0, Color(1, 0.5, 0))  # Small orange explosion
	get_parent().add_child(explosion)

func spawn_miss_effect() -> void:
	var explosion = ExplosionScene.instantiate()
	explosion.global_position = global_position
	explosion.setup(8.0, Color(0.5, 0.5, 0.5))  # Small gray puff
	get_parent().add_child(explosion)

func _draw() -> void:
	# Draw projectile as a small elongated shape
	var length = 8.0
	var width = 3.0

	# Main body
	draw_rect(Rect2(-length/2, -width/2, length, width), projectile_color)

	# Bright tip
	draw_circle(Vector2(length/2, 0), width/2, Color(1, 1, 0.8))

	# Trail
	draw_line(Vector2(-length, 0), Vector2(-length/2, 0), Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.5), 2.0)
