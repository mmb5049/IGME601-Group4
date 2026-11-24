extends CanvasLayer

class_name DarkenUI

var current_highlight:CanvasLayer = null
var highlight_past_layer = 0

var current_highlight_3D: Node3D = null
var previous_materials: Dictionary = {}
var highlight_material := StandardMaterial3D.new()

func _ready():
	highlight_material.albedo_color = Color(1.0, 0.85, 0.2)
	highlight_material.emission_enabled = true
	highlight_material.emission = Color(1.0, 0.7, 0.1)
	highlight_material.emission_energy_multiplier = 1.5

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
		node.material_overlay = highlight_material

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
		restore_3D_highlight()
