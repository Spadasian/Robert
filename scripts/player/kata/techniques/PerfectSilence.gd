extends TechniqueBehavior
## Master: a Perfect Dodge freezes every enemy for a moment (even with the Kata closed).


func on_event(_kata: Node, event: String, _payload: Dictionary) -> void:
	if event == "perfect_dodge":
		EnemyTime.slow(0.0, param("time", 1.0))
