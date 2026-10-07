extends Label3D
## Floating damage number: rises and fades, then removes itself.


func play(amount: float) -> void:
	play_text(str(int(round(amount))))


## Same effect with any text, e.g. "BLOCKED".
func play_text(new_text: String) -> void:
	text = new_text
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.2, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(queue_free)
