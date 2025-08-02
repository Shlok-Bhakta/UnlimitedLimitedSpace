extends Node2D
const objects: Dictionary[String, PackedScene] = {
	"Star": preload("res://scenes/Yeetables/stars.tscn"),
	"Planet": preload("res://scenes/Yeetables/planet.tscn"),
	"Satellite": preload("res://scenes/Yeetables/satelite.tscn")
}

@onready var universe_node: Node = %universe

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("fire"):
		var object_num = randi_range(0, len(objects.keys())-1)
		var star_scene: Resource = objects.get(objects.keys()[object_num])
		var star = star_scene.instantiate()
		star.call('set_type', objects.keys()[object_num])
		universe_node.add_child(star)
		var spawn_offset := Vector2.ZERO
		if star.has_node("AnimatedSprite2D"):
			var sprite: AnimatedSprite2D = star.get_node("AnimatedSprite2D")
			var tex_size := Vector2.ZERO
			var frame_tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			if frame_tex:
				tex_size = frame_tex.get_size() * sprite.scale
			var forward := Vector2.UP.rotated(self.global_rotation)
			var half_len = max(tex_size.x, tex_size.y) * 0.5
			spawn_offset = forward * half_len
		
		star.global_position = self.global_position + spawn_offset
		star.global_rotation = self.global_rotation
