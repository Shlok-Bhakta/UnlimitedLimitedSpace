extends CharacterBody2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var M: float = 1
var V: Vector2 = Vector2.ZERO

func instantiate(mass: float, velocity: Vector2):
	M = mass
	V = velocity
	call_deferred('_apply_scale')

func _apply_scale():
	var min_mass = 1.0
	var max_mass = 200.0
	var max_scale = 5.0

	var scale_factor = log(M + 1.0) / log(max_mass + 1.0) * max_scale
	
	sprite_2d.scale *= scale_factor
	label.text = str(M)

func _physics_process(delta: float) -> void:
	pass
