extends Node2D

const G: float = 4.0 * PI * PI

# --- High-arcade rubber-bandy defaults ---
@export var dt_sim: float = 5.0e-3
@export var gravity_strength: float = 60.0
@export var eps_len: float = 1.0e-5

# Chaos/timewarp
@export var chaos_noise_angle_deg: float = 5.0
@export var chaos_speed_gate: float = 320.0
@export var timewarp_enabled: bool = false
@export var timewarp_factor: float = 1.3
@export var timewarp_duration: float = 0.06

# Rubber-band gravity mix
@export var inv2_strength: float = 1.0         # weight of inverse-square (reduced)
@export var band_strength: float = 1.2         # weight of elastic band (reduced)
@export var band_power: float = 1.25           # softer nonlinearity
@export var band_radius_scale: float = 18.0    # larger r_eq to avoid tight whips

# Inner repulsion bubble to make collisions rare
@export var repel_enabled: bool = true
@export var repel_radius: float = 16.0
@export var repel_strength: float = 60.0

# Damping and soft speed cap
@export var damping_base: float = 0.006
@export var damping_high_speed: float = 0.010
@export var vmax_soft: float = 620.0
@export var vmax_smooth_width: float = 260.0

# Tangential bias instead of snap-to-orbit
@export var tangential_bias: float = 0.08
@export var tangential_bias_jitter: float = 0.18

# Slingshot boost
@export var slingshot_boost: float = 0.28
@export var slingshot_cooldown: float = 0.7

# Scoring (event-driven, near-miss emphasis)
@export var score: int = 0
var score_accum: float = 0.0
var combo: float = 1.0
@export var combo_gain_woosh: float = 0.12
@export var combo_gain_chain: float = 0.18
@export var combo_decay_idle: float = 0.12
@export var score_rate: float = 1.0
@export var woosh_base: float = 10.0
@export var close_shave_base: float = 2.0
@export var curvature_rate: float = 0.6
@export var chain_window: float = 1.0
@export var chain_mult_per_link: float = 0.25
@export var near_miss_radius: float = 30.0

# Type score weights (still used for flavor)
@export var score_satellite: int = 5
@export var score_planet: int = 3
@export var score_star: int = 0

# Legacy params kept for compatibility but unused/repurposed
@export var damping: float = 0.0   # not used directly
@export var max_speed: float = 0.0 # not used (soft cap instead)
@export var snap_orbit: bool = false
@export var snap_lerp: float = 0.0
@export var orbit_radial_tol: float = 0.0
@export var orbit_speed_low: float = 0.0
@export var orbit_speed_high: float = 0.0

var _eps2: float = 0.0

@onready var space_ship: AnimatedSprite2D = $SpaceShip
@onready var score_label: Label = %ScoreLabel

# Per-body runtime state
var _prev_dr_map: Dictionary = {}       # body -> Vector2 (to preferred primary)
var _slingshot_cd: Dictionary = {}      # body -> float (seconds)
var _last_primary: Dictionary = {}      # body -> Node
var _chain_timer: float = 0.0
var _last_chain_id: int = -1

# Collision-driven loss state
var _lost_this_frame: bool = false
@onready var panel: Panel = %LosePanel

func _on_area_collision_entered(_body: Node) -> void:
	var score_label_2: Label = panel.get_node("Score")
	score_label_2.text = "Score: " + str(score)
	panel.visible = true

func _on_restart_pressed() -> void:
	score = 0
	score_accum = 0
	score_label.text = "Score: " + str(score)
	for child in get_children(): child.queue_free()
	panel.visible = false

func _ready() -> void:
	_eps2 = max(1.0e-10, eps_len * eps_len)

func _process(delta: float) -> void:
	# print(_lost_this_frame)
	pass

func _physics_process(delta: float) -> void:
	var bodies: Array = _collect_bodies()
	if bodies.is_empty():
		return

	var step_dt: float = dt_sim
	_step_rubber_band(bodies, step_dt)
	_update_score_events(bodies, step_dt)

	# Loss check after physics step; if any collision signal fired this frame, handle loss.
	if _lost_this_frame:
		# TODO: replace with your game-over flow (emit signal, change scene, show UI, etc.)
		# For now, zero combo as placeholder visible effect.
		combo = 1.0
		# Optional: print for debugging
		#print("LOSS TRIGGERED this frame")

	# cool down slingshot cds
	for b in bodies:
		var t: float = _slingshot_cd.get(b, 0.0)
		_slingshot_cd[b] = max(0.0, t - delta)

	if _chain_timer > 0.0:
		_chain_timer = max(0.0, _chain_timer - delta)

func _collect_bodies() -> Array:
	var out: Array = []
	for n in get_children():
		if n.get('Type') in ['Star', 'Planet', 'Satellite']:
			out.append(n)
	return out
# Removed old polling-based _detect_loss in favor of signal-driven approach

# Debug helper: print connection status for collision areas to diagnose why signals may not fire
func _debug_dump_area_connections() -> void:
	var bodies: Array = _collect_bodies()
	for b in bodies:
		var area_node: Node = b.get_node_or_null("CollisionArea")
		if area_node == null:
			for c in b.get_children():
				if c is Area2D:
					area_node = c
					break
		var area: Area2D = area_node as Area2D
		if area == null:
			print("[Universe] No Area2D found for body: ", b.name)
			continue
		print("[Universe] Area2D for ", b.name, " monitoring=", area.monitoring, " monitorable=", area.monitorable)
		print("  connected body_entered:", area.is_connected("body_entered", Callable(self, "_on_body_collision_entered")))
		print("  connected area_entered:", area.is_connected("area_entered", Callable(self, "_on_area_collision_entered")))
		print("  layers=", area.collision_layer, " mask=", area.collision_mask)

# Debug helper: print connection status for collision areas to diagnose why signals may not fire
# Keep ONLY one definition; remove duplicates if any existed.
func _debug_dump_area_connections_once() -> void:
	var bodies: Array = _collect_bodies()
	for b in bodies:
		var area_node: Node = b.get_node_or_null("CollisionArea")
		if area_node == null:
			for c in b.get_children():
				if c is Area2D:
					area_node = c
					break
		var area: Area2D = area_node as Area2D
		if area == null:
			print("[Universe] No Area2D found for body: ", b.name)
			continue
		print("[Universe] Area2D for ", b.name, " monitoring=", area.monitoring, " monitorable=", area.monitorable)
		print("  connected body_entered:", area.is_connected("body_entered", Callable(self, "_on_body_collision_entered")))
		print("  connected area_entered:", area.is_connected("area_entered", Callable(self, "_on_area_collision_entered")))
		print("  layers=", area.collision_layer, " mask=", area.collision_mask)


func _type_gravity_scale(n: Node) -> float:
	var t: String = n.get('Type')
	if t == 'Satellite':
		return 1.2
	if t == 'Planet':
		return 1.0
	if t == 'Star':
		return 1.3 # stars as chaos engines
	return 1.0

func _type_speed_scale(n: Node) -> float:
	var t: String = n.get('Type')
	if t == 'Satellite':
		return 1.5
	if t == 'Planet':
		return 1.0
	if t == 'Star':
		return 0.8
	return 1.0

func _equilibrium_radius(mass: float) -> float:
	# Soft preferred radius grows sublinearly with mass
	return band_radius_scale * sqrt(max(1.0, mass))

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
		# slight stickiness to last primary
		if _last_primary.get(node, null) == other:
			score *= 1.25
		if score > best_score:
			best_score = score
			best = other
	return best

func _pair_accel(a: Node, b: Node) -> Vector2:
	var dr: Vector2 = b.position - a.position
	var r2: float = dr.length_squared() + _eps2
	var r: float = sqrt(r2)
	var dir: Vector2 = dr / max(1e-6, r)

	# Inverse-square component
	var inv2: float = inv2_strength * gravity_strength * G / (r2)
	# Clamp inverse-square spike for stability
	inv2 = min(inv2, gravity_strength * 200.0)

	# Elastic band around r_eq
	var r_eq: float = _equilibrium_radius(b.Mass)
	# GDScript ternary uses: value_if_true if condition else value_if_false
	var sgn: float = 1.0 if r > r_eq else -0.5 # slight outward push if too close
	var band_mag: float = band_strength * pow(abs(r - r_eq), band_power)
	# Soften band near small r to avoid explosions
	var soften: float = clamp(float(r) / max(1.0, r_eq), 0.25, 1.0)
	var band: float = sgn * band_mag * soften / max(10.0, r_eq) # normalize roughly

	# Inner repulsion bubble
	var repel: float = 0.0
	if repel_enabled and r < repel_radius:
		var t: float = clamp((repel_radius - r) / max(1e-6, repel_radius), 0.0, 1.0)
		repel = repel_strength * (t * t)
		# Lateral peel to prevent pogo along the normal
		var tangent: Vector2 = Vector2(-dir.y, dir.x)
		var peel: float = repel_strength * 0.15 * t
		return (dir * (inv2 + band + repel) + tangent * peel) * b.Mass * _type_gravity_scale(a)

	var a_mag: float = inv2 + band + repel
	var mass_scale: float = _type_gravity_scale(a)
	return dir * a_mag * b.Mass * mass_scale

func _apply_soft_cap_and_damping(v: Vector2) -> Vector2:
	var speed: float = v.length()
	# speed-adaptive damping
	var damp: float = damping_base + damping_high_speed * smoothstep(0.0, vmax_soft, speed)
	v *= (1.0 - damp)
	# soft cap
	if speed > vmax_soft:
		var over: float = speed - vmax_soft
		var k: float = clamp(smoothstep(0.0, vmax_smooth_width, over), 0.0, 1.0)
		v -= v.normalized() * (over * 0.5 * k)
	return v

func _noise_deflect(vec: Vector2, speed: float, proximity_gate: float) -> Vector2:
	if speed < chaos_speed_gate:
		return vec
	var ang_deg: float = randf_range(-chaos_noise_angle_deg, chaos_noise_angle_deg) * proximity_gate
	return vec.rotated(deg_to_rad(ang_deg))

func _try_slingshot(body: Node, primary: Node, dt: float) -> void:
	var prev: Vector2 = _prev_dr_map.get(body, Vector2.ZERO)
	var now: Vector2 = body.position - primary.position
	if prev == Vector2.ZERO:
		_prev_dr_map[body] = now
		return
	# Pericenter detection: radial distance turning from decreasing to increasing
	var dr_prev: float = prev.length()
	var dr_now: float = now.length()
	# Use GDScript conditional expression
	var turning: int = -1 if dr_prev > dr_now else 1
	_prev_dr_map[body] = now
	if turning <= 0:
		return
	# cooldown
	if _slingshot_cd.get(body, 0.0) > 0.0:
		return
	# compute tangential boost
	var rs: float = max(1e-6, dr_now)
	var tangent: Vector2 = Vector2(-now.y, now.x).normalized()
	var v_circ: float = sqrt(max(0.0, gravity_strength * G * primary.Mass / rs))
	var boost := slingshot_boost * v_circ
	body.Velocity += tangent * boost
	_slingshot_cd[body] = slingshot_cooldown

	# timewarp burst — DISABLED to prevent visible teleporting/instability
	# If re-enabling, do proper global substepping, not per-body warps.

func _tangential_bias(body: Node, primary: Node, dt: float) -> void:
	var drs: Vector2 = body.position - primary.position
	var rs: float = max(1e-6, drs.length())
	var tangent: Vector2 = Vector2(-drs.y, drs.x).normalized()
	var v_circ: float = sqrt(max(0.0, gravity_strength * G * primary.Mass / rs))
	var jitter: float = 1.0 + randf_range(-tangential_bias_jitter, tangential_bias_jitter)
	var v_target: Vector2 = tangent * v_circ * jitter
	body.Velocity = body.Velocity.lerp(v_target, tangential_bias)

func _step_rubber_band(bodies: Array, dt: float) -> void:
	var N := bodies.size()
	var acc: Array = []
	acc.resize(N)
	for i in N:
		acc[i] = Vector2.ZERO

	# pairwise forces
	for i in N:
		var a = bodies[i]
		for j in (i + 1):
			if j >= N:
				break
			var b = bodies[j]
			var ab: Vector2 = _pair_accel(a, b)
			var ba: Vector2 = -_pair_accel(b, a) # symmetric but with each other's mass/type
			acc[i] += ab
			acc[j] += ba

	# integrate velocity
	for i in N:
		var node = bodies[i]
		node.Velocity += dt * acc[i]

	# apply per-body chaos, cap, moves
	for i in N:
		var node2 = bodies[i]
		var v: Vector2 = node2.Velocity * _type_speed_scale(node2)
		var speed: float = v.length()

		# noise deflection stronger when close to any body
		var prox_gate: float = 0.0
		for k in N:
			if k == i: continue
			var other = bodies[k]
			var r: float = (node2.position - other.position).length()
			prox_gate = max(prox_gate, clamp((near_miss_radius - r) / max(near_miss_radius, 1.0), 0.0, 1.0))
		v = _noise_deflect(v, speed, prox_gate)

		# clamp per-frame displacement to avoid tunneling/teleport feel
		var max_step: float = vmax_soft * 0.02
		var vlen := v.length()
		if vlen * dt > max_step and vlen > 1e-6:
			v = v.normalized() * (max_step / dt)

		# soft cap and damping
		v = _apply_soft_cap_and_damping(v)

		node2.Velocity = v
		node2.position += dt * node2.Velocity

	# tangential bias and slingshot near preferred primary
	for i in N:
		var body = bodies[i]
		var primary := _preferred_primary(bodies, body)
		if primary == null:
			continue
		_last_primary[body] = primary
		_tangential_bias(body, primary, dt)
		_try_slingshot(body, primary, dt)

func _curvature(v: Vector2, a: Vector2) -> float:
	var vlen: float = v.length()
	if vlen <= 1e-5:
		return 0.0
	return clamp(abs(v.cross(a)) / max(1e-6, pow(vlen, 3.0)), 0.0, 0.1)

func _type_score(n: Node) -> int:
	var t: String = n.get('Type')
	if t == 'Satellite':
		return score_satellite
	if t == 'Planet':
		return score_planet
	return score_star

func _update_score_events(bodies: Array, dt: float) -> void:
	var woosh_points: float = 0.0
	var shave_points: float = 0.0
	var curve_points: float = 0.0
	var any_event := false

	# Compute quick per-body curvature and near-miss checks
	for i in bodies.size():
		var b = bodies[i]
		var p := _preferred_primary(bodies, b)
		if p == null:
			continue

		# Near-miss scoring
		var r: float = (b.position - p.position).length()
		if r < near_miss_radius:
			var t: float = clamp((near_miss_radius - r) / max(near_miss_radius, 1.0), 0.0, 1.0)
			shave_points += close_shave_base * (0.2 + 0.8 * t)
			any_event = true

		# Woosh scoring if slingshot just happened (cooldown just reset)
		if _slingshot_cd.get(b, 0.0) >= (slingshot_cooldown - dt * 1.5):
			var rs: float = max(1e-6, r)
			var v_circ: float = sqrt(max(0.0, gravity_strength * G * p.Mass / rs))
			var spd: float = b.Velocity.length()
			if spd > 0.7 * v_circ:
				woosh_points += woosh_base * (spd / max(1.0, v_circ))
				any_event = true
				# chain logic
				if _last_chain_id != p.get_instance_id():
					_chain_timer = chain_window
					_last_chain_id = p.get_instance_id()
					combo += combo_gain_chain

		# Curvature drip
		# approximate acceleration from neighbor forces we already had: reuse pair accel magnitude against primary
		var acc_mag: float = _pair_accel(b, p).length()
		curve_points += curvature_rate * _curvature(b.Velocity, b.Velocity.normalized() * acc_mag) * 100.0

	# Combo updates
	if any_event:
		combo += combo_gain_woosh
	else:
		combo = max(1.0, combo - combo_decay_idle)

	# Chain multiplier
	var chain_mult := 1.0 + (chain_mult_per_link * (1.0 if _chain_timer > 0.0 else 0.0))

	var total := (woosh_points + shave_points + curve_points) * combo * chain_mult * score_rate
	score_accum += total
	score = int(score_accum)
	score_label.text = "Score:" + str(score)

func _on_child_entered_tree(node: Node) -> void:
	if node.get('Type') in ['Star', 'Planet', 'Satellite']:
		var kick: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * 20.0
		node.call('set_velocity', kick)


func _on_star_spawn_point_spawn_object(obj: Node2D) -> void:
	var area_node: Node = obj.get_child(1)
	if area_node.get_class() != "Area2D":
		print("AAAAAAAAA")
	area_node.connect("area_entered", Callable(self, "_on_area_collision_entered"))
	
