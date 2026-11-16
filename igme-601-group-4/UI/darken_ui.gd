extends CanvasLayer

class_name DarkenUI

var current_highlight:CanvasLayer = null
var highlight_past_layer = 0

func highlight_UI(ui:CanvasLayer):
	show()
	if current_highlight:
		current_highlight.layer = highlight_past_layer
	highlight_past_layer = ui.layer
	ui.layer = layer + 1
	current_highlight = ui

func clear():
	hide()
	if current_highlight:
		current_highlight.layer = highlight_past_layer
