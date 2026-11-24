extends CanvasLayer

class_name DarkenUI

var current_highlight:CanvasLayer = null
var highlight_past_layer = 0

var current_highlight_3D: Node3D = null
var previous_materials: Dictionary = {}

var outline_material := ShaderMaterial.new()

func _ready():
	var outline_shader = load("res://UI/Onboarding_Enemy/outline.gdshader")
	outline_material.shader = outline_shader
	outline_material.set_shader_parameter("outline_width", 0.001)
	
func highlight_UI(ui:CanvasLayer):
	show()
	if current_highlight:
		current_highlight.layer = highlight_past_layer
	highlight_past_layer = ui.layer
	ui.layer = layer + 1
	current_highlight = ui

func highlight_3D(node: Node3D):
	show()

	restore_3D_highlight()

	current_highlight_3D = node
	apply_highlight(node)


func apply_highlight(node: Node):
	if node is MeshInstance3D:
		previous_materials[node] = node.material_overlay
		node.material_overlay = outline_material

	for child in node.get_children():
		apply_highlight(child)


func restore_3D_highlight():
	for mesh in previous_materials:
		if is_instance_valid(mesh):
			mesh.material_overlay = previous_materials[mesh]

	previous_materials.clear()
	current_highlight_3D = null
	
func clear():
	hide()

	if current_highlight:
		current_highlight.layer = highlight_past_layer
		current_highlight = null

	restore_3D_highlight()
