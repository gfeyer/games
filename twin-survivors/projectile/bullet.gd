extends Area2D
class_name Bullet

signal hit(position: Vector2)

@export var speed: float = 500.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var aoe_radius: float = 0.0
var owner_player_id: int = 1

# Visual references
@onready var trail_particles: GPUParticles2D = $TrailParticles
@onready var impact_particles: GPUParticles2D = $ImpactParticles
@onready var aoe_particles: GPUParticles2D = $AOEParticles

var time_alive: float = 0.0


func _ready() -> void:
	add_to_group("projectiles")

	# Connect body entered signal
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	time_alive += delta
	if time_alive >= lifetime:
		queue_free()

	# Check screen bounds
	var viewport_rect = get_viewport_rect()
	if not viewport_rect.grow(50).has_point(global_position):
		queue_free()


func setup(spawn_pos: Vector2, dir: Vector2, player_id: int) -> void:
	global_position = spawn_pos
	direction = dir.normalized()
	rotation = direction.angle()
	owner_player_id = player_id
	damage = GameManager.get_damage(player_id)
	aoe_radius = GameManager.get_aoe_radius(player_id)


func _on_body_entered(body: Node2D) -> void:
	if body is Zombie or body is Boss:
		deal_damage_to_enemy(body)
		spawn_impact_effect()

		if aoe_radius > 0:
			deal_aoe_damage()

		destroy()


func deal_damage_to_enemy(enemy: Node2D) -> void:
	enemy.take_damage(damage)


func deal_aoe_damage() -> void:
	if aoe_radius <= 0:
		return

	# Find all zombies and bosses in radius
	var enemies: Array[Node] = []
	enemies.append_array(get_tree().get_nodes_in_group("zombies"))
	enemies.append_array(get_tree().get_nodes_in_group("bosses"))

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= aoe_radius:
			# Damage falls off with distance
			var falloff = 1.0 - (dist / aoe_radius) * 0.5
			var aoe_damage = max(1, int(damage * falloff))
			enemy.take_damage(aoe_damage)

	# Show AOE effect
	if aoe_particles:
		aoe_particles.emitting = true


func spawn_impact_effect() -> void:
	if impact_particles:
		impact_particles.emitting = true
	hit.emit(global_position)


func destroy() -> void:
	# Stop moving
	set_physics_process(false)

	# Disable collision (deferred to avoid physics query errors)
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)

	# Hide bullet sprite
	$BulletSprite.visible = false

	if trail_particles:
		trail_particles.emitting = false

	# Wait for particles to finish
	await get_tree().create_timer(0.3).timeout
	queue_free()
