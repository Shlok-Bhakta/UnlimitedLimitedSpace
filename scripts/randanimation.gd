extends AnimatedSprite2D

func _ready():
	var anims := sprite_frames.get_animation_names()
	if anims.size() > 0:
		var pick := anims[randi() % anims.size()]
		play(pick)
