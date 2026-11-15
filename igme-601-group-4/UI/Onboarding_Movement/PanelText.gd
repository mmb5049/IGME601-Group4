extends PanelContainer

var fade_tween: Tween

func fade_in() -> void:
	modulate.a = 0.0
	visible = true

	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	fade_out()


func fade_out() -> void:
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(hide)
