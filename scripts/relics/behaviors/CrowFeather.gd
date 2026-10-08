extends RuleBehavior
## The dash leaves a trail on the floor that makes enemies bleed.

var trail_timer: float = 0.0


func on_tick(delta: float) -> void:
	if not host.player.dash.is_dashing:
		trail_timer = 0.0
		return
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.05
		host.spawn_zone(host.player.global_position, p("radius", 1.1), p("time", 3.0), 0.0, p("bleed", 5.0), Color(0.15, 0.1, 0.25, 0.4), "crow_feather")
