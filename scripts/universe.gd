extends Node2D

const G: float = 4.0 * PI * PI

@export var dt_sim: float = 5.0e-3
@export var gravity_strength: float = 60.0
@export var eps_len: float = 1.0e-5
@export var damping: float = 0.005
@export var max_speed: float = 400.0
@export var snap_orbit: bool = true
@export var snap_lerp: float = 0.35
@export var score: int = 0
var score_accum: float = 0.0
var combo: float = 1.0
@export var combo_gain: float = 0.05
@export var combo_decay: float = 0.1
@export var score_rate: float = 1.0
@export var orbit_radial_tol: float = 0.6
@export var orbit_speed_low: float = 0.6
@export var orbit_speed_high: float = 1.4
@export var score_satellite: int = 5
@export var score_planet: int = 3
@export var score_star: int = 0

var _eps2: float = 0.0

@onready var space_ship: AnimatedSprite2D = $SpaceShip
@onready var score_label: Label = %ScoreLabel

func _ready() -> void:
	_eps2 = max(1.0e-10, eps_len * eps_len)

func _physics_process(_delta: float) -> void:
	var bodies := _collect_bodies()
	if bodies.is_empty():
		return
	_step_arcade(bodies, dt_sim)
	_update_score(bodies)

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

func _is_orbiting(primary: Node, body: Node) -> bool:
	var dr: Vector2 = body.position - primary.position
	var r: float = max(1e-6, dr.length())
	var v: Vector2 = body.Velocity
	var dir_r: Vector2 = dr / r
	var radial: float = v.dot(dir_r)
	var tangential: float = abs(v.cross(dir_r))
	var v_circ: float = sqrt(max(0.0, gravity_strength * G * primary.Mass / r))
	if abs(radial) > orbit_radial_tol * v_circ:
		return false
	if tangential < orbit_speed_low * v_circ:
		return false
	if tangential > orbit_speed_high * v_circ:
		return false
	return true

func _type_score(n: Node) -> int:
	var t: String = n.get('Type')
	if t == 'Satellite':
		return score_satellite
	if t == 'Planet':
		return score_planet
	return score_star

func _update_score(bodies: Array) -> void:
	var orbit_points: float = 0.0
	var orbiting_any := false
	for body in bodies:
		var primary := _preferred_primary(bodies, body)
		if primary == null:
			continue
		if _is_orbiting(primary, body):
			orbiting_any = true
			orbit_points += float(_type_score(body))
	if orbiting_any:
		combo += combo_gain
	else:
		combo = max(1.0, combo - combo_decay)
	score_accum += orbit_points * combo * score_rate
	score = int(score_accum)
	score_label.text = str(score)
	#print("score:", score, " combo:", combo)

func _on_child_entered_tree(node: Node) -> void:
	if node.get('Type') in ['Star', 'Planet', 'Satellite']:
		var kick: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * 20.0
		node.call('set_velocity', kick)
