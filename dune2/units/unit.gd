extends CharacterBody2D
class_name Unit

signal selected
signal deselected
signal destroyed
signal arrived_at_destination

const ExplosionScene = preload("res://effects/explosion.tscn")
const ProjectileScene = preload("res://effects/projectile.tscn")
const MuzzleFlashScene = preload("res://effects/muzzle_flash.tscn")
const TracerScene = preload("res://effects/tracer.gd")

@export var unit_type: String = "unit"
@export var faction: int = Constants.Faction.ATREIDES

var unit_data: Dictionary = {}
var max_health: int = 100
var current_health: int = 100
var move_speed: float = 100.0
var damage: int = 0
var attack_range: int = 0
var attack_speed: float = 1.0
var sight_range: int = 3

var is_selected: bool = false
var target_position: Vector2 = Vector2.ZERO
var attack_target: Node2D = null
var is_moving: bool = false
var attack_cooldown: float = 0.0
var has_move_order: bool = false  # Player issued move command - don't auto-attack

var vision_id: int = 0
static var _next_vision_id: int = 0

func _ready() -> void:
	add_to_group("units")
	add_to_group("selectable")
	# Faction groups are set in setup() after faction is assigned

	vision_id = _next_vision_id
	_next_vision_id += 1

	if unit_type in Constants.UNITS:
		unit_data = Constants.UNITS[unit_type]
		max_health = unit_data.get("health", 100)
		current_health = max_health
		move_speed = unit_data.get("speed", 100.0)
		damage = unit_data.get("damage", 0)
		attack_range = unit_data.get("attack_range", 0)
		attack_speed = unit_data.get("attack_speed", 1.0)
		sight_range = unit_data.get("sight_range", 3)

func _physics_process(delta: float) -> void:
	if is_moving:
		move_towards_target(delta)

	if attack_target and is_instance_valid(attack_target):
		process_attack(delta)
	elif not has_move_order:
		# Auto-attack: scan for nearby enemies if we can attack (but not if player issued move order)
		if damage > 0:
			scan_for_enemies()

	update_vision()

func scan_for_enemies() -> void:
	var enemy_group = "enemy_units" if faction == Constants.Faction.ATREIDES else "player_units"
	var sight_distance = sight_range * Constants.TILE_SIZE

	var closest_enemy: Node2D = null
	var closest_distance: float = sight_distance

	# Check enemy units
	for enemy in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	# Also check enemy buildings
	var enemy_building_group = "enemy_buildings" if faction == Constants.Faction.ATREIDES else "player_buildings"
	for building in get_tree().get_nodes_in_group(enemy_building_group):
		if not is_instance_valid(building):
			continue
		var distance = global_position.distance_to(building.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = building

	if closest_enemy:
		attack(closest_enemy)

func setup(type: String, pos: Vector2, owner_faction: int) -> void:
	unit_type = type
	faction = owner_faction
	global_position = pos

	# Add to correct faction group
	if faction == Constants.Faction.ATREIDES:
		add_to_group("player_units")
	else:
		add_to_group("enemy_units")

	if type in Constants.UNITS:
		unit_data = Constants.UNITS[type]
		max_health = unit_data.get("health", 100)
		current_health = max_health
		move_speed = unit_data.get("speed", 100.0)
		damage = unit_data.get("damage", 0)
		attack_range = unit_data.get("attack_range", 0)
		attack_speed = unit_data.get("attack_speed", 1.0)
		sight_range = unit_data.get("sight_range", 3)

	GameManager.register_unit(self, faction)

func move_to(pos: Vector2, player_order: bool = true) -> void:
	# Clamp target position to map bounds with margin
	var margin = 16.0  # Keep units slightly inside the map
	var map_size = Vector2(Constants.MAP_WIDTH, Constants.MAP_HEIGHT) * Constants.TILE_SIZE
	target_position = pos.clamp(Vector2(margin, margin), map_size - Vector2(margin, margin))
	is_moving = true
	attack_target = null
	has_move_order = player_order  # If player issued this move, don't auto-attack

func move_towards_target(delta: float) -> void:
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)

	if distance < 5:
		is_moving = false
		velocity = Vector2.ZERO
		has_move_order = false  # Arrived, can auto-attack again
		arrived_at_destination.emit()
		return

	velocity = direction * move_speed
	move_and_slide()

	# Face movement direction
	var new_rotation = direction.angle() + PI / 2
	if rotation != new_rotation:
		rotation = new_rotation
		queue_redraw()  # Redraw to update health bar position

func attack(target: Node2D) -> void:
	attack_target = target
	has_move_order = false  # Attack command overrides move order

	# Move into range if needed
	var distance = global_position.distance_to(target.global_position)
	if distance > attack_range * Constants.TILE_SIZE:
		var direction = (target.global_position - global_position).normalized()
		var attack_pos = target.global_position - direction * (attack_range - 1) * Constants.TILE_SIZE
		move_to(attack_pos, false)  # Internal movement, not a player move order

func process_attack(delta: float) -> void:
	if not attack_target or not is_instance_valid(attack_target):
		attack_target = null
		return

	var distance = global_position.distance_to(attack_target.global_position)
	if distance > attack_range * Constants.TILE_SIZE:
		# Target out of range, move closer
		attack(attack_target)
		return

	# Stop moving to attack
	is_moving = false
	velocity = Vector2.ZERO

	# Face target
	var direction = (attack_target.global_position - global_position).normalized()
	var new_rotation = direction.angle() + PI / 2
	if rotation != new_rotation:
		rotation = new_rotation
		queue_redraw()

	# Attack cooldown
	attack_cooldown -= delta
	if attack_cooldown <= 0:
		perform_attack()
		attack_cooldown = attack_speed

func perform_attack() -> void:
	if not attack_target or not is_instance_valid(attack_target):
		return

	# Spawn muzzle flash
	spawn_muzzle_flash()

	# For tanks: spawn projectile (damage dealt on hit)
	# For infantry: instant damage with tracer
	if unit_type == "tank":
		spawn_projectile()
	else:
		# Instant hit with tracer effect
		spawn_tracer()
		if attack_target.has_method("take_damage"):
			attack_target.take_damage(damage)

func spawn_muzzle_flash() -> void:
	var flash = MuzzleFlashScene.instantiate()
	# Position at front of unit
	var offset = Vector2(0, -16).rotated(rotation - PI/2)
	flash.global_position = global_position + offset
	get_parent().add_child(flash)

func spawn_projectile() -> void:
	var projectile = ProjectileScene.instantiate()
	var offset = Vector2(0, -16).rotated(rotation - PI/2)
	projectile.global_position = global_position + offset
	projectile.setup(attack_target, damage, faction, 250.0)
	get_parent().add_child(projectile)

func spawn_tracer() -> void:
	if not attack_target or not is_instance_valid(attack_target):
		return
	var tracer = Node2D.new()
	tracer.set_script(TracerScene)
	var offset = Vector2(0, -16).rotated(rotation - PI/2)
	tracer.setup(global_position + offset, attack_target.global_position)
	get_parent().add_child(tracer)

func stop() -> void:
	is_moving = false
	attack_target = null
	velocity = Vector2.ZERO
	has_move_order = false

func take_damage(dmg: int) -> void:
	current_health -= dmg
	queue_redraw()
	if current_health <= 0:
		die()

func die() -> void:
	# Spawn death explosion
	spawn_death_explosion()

	destroyed.emit()
	GameManager.unregister_unit(self, faction)
	queue_free()

func spawn_death_explosion() -> void:
	var explosion = ExplosionScene.instantiate()
	explosion.global_position = global_position
	# Larger explosion for tanks
	var size = 25.0 if unit_type == "tank" else 18.0
	explosion.setup(size, Color(1, 0.5, 0))
	get_parent().add_child(explosion)

func select() -> void:
	is_selected = true
	selected.emit()
	queue_redraw()

func deselect() -> void:
	is_selected = false
	deselected.emit()
	queue_redraw()

func get_health_percent() -> float:
	return float(current_health) / float(max_health)

func update_vision() -> void:
	var grid_pos = Constants.world_to_grid(global_position)
	# Vision update will be called from main game

func get_grid_position() -> Vector2i:
	return Constants.world_to_grid(global_position)

func _draw() -> void:
	# Base unit drawing (circle)
	var radius = 12.0
	var base_color = Constants.COLORS["atreides"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen"]
	draw_circle(Vector2.ZERO, radius, base_color)

	# Border
	var border_color = Constants.COLORS["atreides_light"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen_light"]
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, border_color, 2.0)

	# Direction indicator
	draw_line(Vector2.ZERO, Vector2(0, -radius - 4), border_color, 2.0)

	# Selection indicator (rotates with unit)
	if is_selected:
		draw_arc(Vector2.ZERO, radius + 4, 0, TAU, 32, Color.WHITE, 2.0)

	# Health bar - draw in screen space (counter-rotate)
	var health_bar_width = radius * 2.0
	var health_bar_height = 4.0
	var health_bar_y = -radius - 10

	# Calculate screen-aligned position
	var health_bar_pos = Vector2(-health_bar_width / 2, health_bar_y).rotated(-rotation)

	draw_set_transform(health_bar_pos, -rotation)

	draw_rect(Rect2(Vector2.ZERO, Vector2(health_bar_width, health_bar_height)), Color(0.2, 0.2, 0.2))

	var health_percent = get_health_percent()
	var health_color = Constants.COLORS["health_green"]
	if health_percent < 0.3:
		health_color = Constants.COLORS["health_red"]
	elif health_percent < 0.6:
		health_color = Constants.COLORS["health_yellow"]

	draw_rect(Rect2(Vector2.ZERO, Vector2(health_bar_width * health_percent, health_bar_height)), health_color)
