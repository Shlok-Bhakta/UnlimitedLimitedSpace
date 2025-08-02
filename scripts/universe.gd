extends Node2D

const G: float = 4.0 * PI * PI

@export var dt_sim: float = 5.0e-3
@export var gravity_strength: float = 60.0
@export var eps_len: float = 1.0e-5
@export var damping: float = 0.005
@export var max_speed: float = 400.0
@export var snap_orbit: bool = true
@export var snap_lerp: float = 0.35

var _eps2: float = 0.0

@onready var space_ship: AnimatedSprite2D = $SpaceShip

func _ready() -> void:
	_eps2 = max(1.0e-10, eps_len * eps_len)

func _physics_process(_delta: float) -> void:
	var bodies := _collect_bodies()
	if bodies.is_empty():
		return
	_step_arcade(bodies, dt_sim)

func _collect_bodies() -> Array:
	var out: Array = []
	for n in get_children():
		if n.get('Type') in ['Star', 'Planet', 'Satellite']:
			out.append(n)
	return out

func _step_arcade(bodies: Array, dt: float) -> void:
	var N := bodies.size()
	var acc: Array = []
	acc.resize(N)
	for i in N:
		acc[i] = Vector2.ZERO
	for i in N:
		var a = bodies[i]
		for j in (i + 1):
			if j >= N:
				break
			var b = bodies[j]
			var dr: Vector2 = b.position - a.position
			var r2: float = dr.length_squared() + _eps2
			var inv_r: float = 1.0 / sqrt(r2)
			var inv_r3: float = inv_r * inv_r * inv_r
			var base: Vector2 = gravity_strength * G * dr * inv_r3
			var mass_scale_a: float = _type_gravity_scale(a)
			var mass_scale_b: float = _type_gravity_scale(b)
			acc[i] += base * b.Mass * mass_scale_a
			acc[j] -= base * a.Mass * mass_scale_b
	for i in N:
		var node = bodies[i]
		node.Velocity += dt * acc[i]
	for i in N:
		var node2 = bodies[i]
		var v: Vector2 = node2.Velocity * _type_speed_scale(node2)
		var vlen: float = v.length()
		if vlen > max_speed:
			node2.Velocity = v * (max_speed / vlen)
		node2.Velocity *= (1.0 - damping)
		node2.position += dt * node2.Velocity
	if snap_orbit:
		for i in N:
			var orbiter = bodies[i]
			if orbiter.get('Type') == 'Star':
				continue
			var target := _preferred_primary(bodies, orbiter)
			if target == null:
				continue
			var drs: Vector2 = orbiter.position - target.position
			var rs: float = max(1e-6, drs.length())
			var tangent: Vector2 = Vector2(-drs.y, drs.x).normalized()
			var v_circ: float = sqrt(max(0.0, gravity_strength * G * target.Mass / rs))
			var v_target: Vector2 = tangent * v_circ
			orbiter.Velocity = orbiter.Velocity.lerp(v_target, snap_lerp)

func _preferred_primary(bodies: Array, node: Node) -> Node:
	var best: Node = null
	var best_score: float = -INF
	for other in bodies:
		if other == node:
			continue
		var t: String = other.get('Type')
		var r2: float = (node.position - other.position).length_squared()
		var score: float = 0.0
		if t == 'Star':
			score = 1000.0 / max(1e-6, r2)
		elif t == 'Planet':
			score = 200.0 / max(1e-6, r2)
		elif t == 'Satellite':
			score = 20.0 / max(1e-6, r2)
		if score > best_score:
			best_score = score
			best = other
	return best

func _type_gravity_scale(n: Node) -> float:
	var t: String = n.get('Type')
	if t == 'Satellite':
		return 1.5
	if t == 'Planet':
		return 1.0
	if t == 'Star':
		return 1.0
	return 1.0

func _type_speed_scale(n: Node) -> float:
	var t: String = n.get('Type')
	if t == 'Satellite':
		return 1.5
	if t == 'Planet':
		return 1.0
	if t == 'Star':
		return 0.6
	return 1.0

func _on_child_entered_tree(node: Node) -> void:
	if node.get('Type') in ['Star', 'Planet', 'Satellite']:
		var kick: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * 20.0
		node.call('set_velocity', kick)
