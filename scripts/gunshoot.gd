extends Node2D
const objects: Dictionary[String, PackedScene] = {
	"Star": preload("res://scenes/Yeetables/stars.tscn"),
	"Planet": preload("res://scenes/Yeetables/planet.tscn"),
	"Satellite": preload("res://scenes/Yeetables/satelite.tscn")
}

@onready var universe_node: Node = %universe
@onready var planet_button: Button = %ShootSelector/PlanetButton
@onready var group: ButtonGroup = planet_button.button_group

signal spawn_object(obj: Node2D)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if get_viewport().gui_get_hovered_control() != null:
			return
		_shoot_selected()

func _shoot_selected() -> void:
	var pressed: BaseButton = group.get_pressed_button()
	if pressed == null:
		pressed = %ShootSelector/PlanetButton
	var name_to_key: Dictionary = {
		"StarButton": "Star",
		"PlanetButton": "Planet",
		"SateliteButton": "Satellite",
		"Star": "Star",
		"Planet": "Planet",
		"Satellite": "Satellite",
	}
	var key: String = name_to_key.get(pressed.name, "Planet")
	if not objects.has(key):
		return
	var scene: PackedScene = objects[key]
	var node = scene.instantiate()
	if node.has_method("set_type"):
		node.call("set_type", key)
	universe_node.add_child(node)
	var spawn_offset := Vector2.ZERO
	if node.has_node("AnimatedSprite2D"):
		var sprite: AnimatedSprite2D = node.get_node("AnimatedSprite2D")
		var tex_size := Vector2.ZERO
		var frame_tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if frame_tex:
			tex_size = frame_tex.get_size() * sprite.scale
		var forward := Vector2.UP.rotated(self.global_rotation)
		var half_len = max(tex_size.x, tex_size.y) * 0.5
		spawn_offset = forward * half_len
	node.global_position = self.global_position + spawn_offset
	node.global_rotation = self.global_rotation
	spawn_object.emit(node)
