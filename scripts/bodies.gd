extends Node2D

@export var Mass: float = 1
@export var Velocity: Vector2 = Vector2.ZERO
@export var Radius: float = 20
@export var Type: String = ""

	#var scale_factor = log(M + 1.0) / log(max_mass + 1.0) * max_scale
	
	#sprite_2d.scale *= scale_factor

#func _physics_process(delta: float) -> void:
	#pass
	
func _process(delta: float) -> void:
	look_at(Velocity)

func set_velocity(v: Vector2):
	Velocity = v
	
func set_type(type: String):
	Type = type
	if Type == 'Satellite':
		Mass = 0.1
	elif Type == 'Planet':
		Mass = 500
	elif Type == 'Star':
		Mass = 10000
