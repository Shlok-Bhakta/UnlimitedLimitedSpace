extends AnimatedSprite2D

@onready var timer: Timer = $Timer

@export var move_acceleration: float = 600.0      # Movement force
@export var max_speed: float = 400.0              # Maximum linear speed
@export var friction: float = 64.0                # Higher = more slippery
@export var rotation_acceleration: float = 300.0  # Angular acceleration (deg/s^2)
@export var max_angular_speed: float = 250.0      # Maximum angular speed (deg/s)
@export var rotation_friction: float = 32.0        # Higher = more slippery (rotational)

var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0

func _process(delta):
	var angular_accel = 0.0
	if Input.is_action_pressed("rotate_left"):
		angular_accel -= rotation_acceleration
	if Input.is_action_pressed("rotate_right"):
		angular_accel += rotation_acceleration
	angular_velocity += angular_accel * delta
	angular_velocity = clamp(angular_velocity, -max_angular_speed, max_angular_speed)
	rotation_degrees += angular_velocity * delta
	if angular_velocity > 0:
		angular_velocity = max(angular_velocity - rotation_friction * delta, 0)
	elif angular_velocity < 0:
		angular_velocity = min(angular_velocity + rotation_friction * delta, 0)
	var thrust = Vector2.ZERO
	var direction = Vector2.UP.rotated(rotation)
	if Input.is_action_pressed("forward"):
		thrust += direction * move_acceleration
		if not (Input.is_action_pressed("rotate_left") or Input.is_action_pressed("rotate_right")):
			angular_velocity *= 0.95
	if Input.is_action_pressed("backward"):
		thrust -= direction * move_acceleration
		if not (Input.is_action_pressed("rotate_left") or Input.is_action_pressed("rotate_right")):
			angular_velocity *= 0.95
	velocity += thrust * delta
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
		
	if Input.is_action_pressed("rotate_left"):
		play("moving", 2)
	elif Input.is_action_pressed("rotate_right"):
		play("moving", 2)
	elif Input.is_action_pressed("forward"):
		play("moving", 2)
	elif Input.is_action_pressed("backward"):
		play("moving", 2)
	else:
		play("still")
	

		
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	position += velocity * delta
