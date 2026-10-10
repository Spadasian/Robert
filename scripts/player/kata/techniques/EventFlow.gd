extends TechniqueBehavior
## Flow driven by params, so a new Flow is only a new .tres:
##   light_gain      a light swing that connects (first enemy of the swing)
##   crit_gain       a critical hit          dodge_gain    a dash
##   perfect_gain    a Perfect Dodge         skill_gain    Iaijutsu / Kaeshi / Moonlit Storm
##   behind_gain     a hit on an enemy's back
##   per_second      Flow that grows with time (it does NOT keep the Kata open by itself)
##   loss_when_hit   Flow lost when hit      halve_when_hit  Flow is halved when hit (Still Water)


func on_event(kata: Node, event: String, payload: Dictionary) -> void:
	match event:
		"hit_dealt":
			if payload.get("kind", "") == "bleed" or payload.get("hit_count", 1) > 1:
				return
			if payload.get("kind", "") in ["light", "shuriken"]:
				kata.add_flow(param("light_gain", 0.0))
			if payload.get("from_behind", false):
				kata.add_flow(param("behind_gain", 0.0))
		"critical_hit":
			kata.add_flow(param("crit_gain", 0.0))
		"dodge":
			kata.add_flow(param("dodge_gain", 0.0))
		"perfect_dodge":
			kata.add_flow(param("perfect_gain", 0.0))
		"skill_resolved":
			var skill: Node = payload.get("skill")
			if is_instance_valid(skill) and skill.get_slot() != "rmb":
				kata.add_flow(param("skill_gain", 0.0))
		"damage_taken":
			if param("halve_when_hit", false):
				kata.set_flow(kata.flow_value * 0.5)
			kata.add_flow(-param("loss_when_hit", 0.0))


func on_tick(kata: Node, delta: float) -> void:
	var rate: float = param("per_second", 0.0)
	if rate > 0.0:
		kata.add_flow(rate * delta, false)
