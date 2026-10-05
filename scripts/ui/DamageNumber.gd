extends Label3D
## Floating damage number: rises and fades, then removes itself.


func play(amount: float) -> void:
	text = str(int(round(amount)))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.2, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(queue_free)
