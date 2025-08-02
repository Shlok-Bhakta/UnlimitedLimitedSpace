extends Node2D

# ---- Units & constants (AU, years, solar masses) ----
const G        : float = 4.0 * PI * PI      # AU^3 / yr^2 / M_sun
const EPS2     : float = 1e-6               # softening in AU^2 to avoid singularities
const SEC_PER_YEAR := 365.25 * 24.0 * 3600.0

@export var time_scale: float = 100000000.0         # 1.0 => 1 sim-second per real second; increase to speed up
@onready var space_ship: AnimatedSprite2D = $SpaceShip

func _physics_process(delta: float) -> void:
	# Collect bodies from direct children each frame.
	var bodies := _collect_bodies()
	if bodies.is_empty():
		return

	# Convert engine delta (seconds) -> simulation years.
	var dt: float = (delta * time_scale) / SEC_PER_YEAR

	# -- Acceleration at t
	var a1 := _compute_acc(bodies)

	# -- Half-kick + drift
	for b in bodies:
		b.Velocity += 0.5 * dt * a1[b]
		b.position += dt * b.Velocity   # Move by directly setting position (Vector2)

	# -- Acceleration at t + dt
	var a2 := _compute_acc(bodies)

	# -- Second half-kick
	for b in bodies:
		b.Velocity += 0.5 * dt * a2[b]


func _collect_bodies() -> Array:
	var out: Array = []
	# get_children() returns direct children; that matches your scene setup. :contentReference[oaicite:1]{index=1}
	for n in get_children():
		# In GDScript you can test property membership with `'prop' in object`. :contentReference[oaicite:2]{index=2}
		if n.get('Type') in ['Star', 'Planet', 'Satellite']:
			out.append(n)
	return out


func _compute_acc(bodies: Array) -> Dictionary:
	# Returns a Dictionary: node -> Vector2 acceleration (AU / yr^2)
	var acc := {}
	for b in bodies:
		acc[b] = Vector2.ZERO

	var N := bodies.size()
	for i in range(N):
		var a = bodies[i]
		for j in range(i + 1, N):
			var b = bodies[j]
			var dr: Vector2 = b.position - a.position
			var r2: float = dr.length_squared() + EPS2
			var inv_r: float = 1.0 / sqrt(r2)
			var inv_r3: float = inv_r * inv_r * inv_r
			# Base vector for mutual acceleration (per unit mass):
			var base: Vector2 = G * dr * inv_r3
			# a feels b, and b feels a (equal & opposite)
			acc[a] += base * b.Mass
			acc[b] -= base * a.Mass
	return acc



func _on_child_entered_tree(node: Node) -> void:
	if node.get('Type') in ['Star', 'Planet', 'Satellite']:
		var initial_velocity: Vector2 = space_ship.global_position.direction_to(get_global_mouse_position()) * 100
		node.call('set_velocity', initial_velocity)
		
