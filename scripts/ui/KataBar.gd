extends Control
## The Kata on the HUD, above the skill slots: [Opening] -> [Flow bar] -> [Finisher]. Lit up while a Kata runs;
## the thin line under the Flow bar is the time left before it closes; the Finisher glows when Flow is high.

const BOX := Vector2(150.0, 40.0)
const GAP: float = 26.0

var kata: Node


func setup(kata_component: Node) -> void:
	kata = kata_component
	kata.kata_changed.connect(queue_redraw)
	custom_minimum_size = Vector2(BOX.x * 3.0 + GAP * 2.0, BOX.y + 22.0)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	if kata == null:
		return
	var font: Font = ThemeDB.fallback_font
	var open: bool = kata.is_open
	var opening: Resource = kata.get_technique(TechniqueData.Category.OPENING)
	var flow: Resource = kata.get_technique(TechniqueData.Category.FLOW)
	var finisher: Resource = kata.get_technique(TechniqueData.Category.FINISHER)
	var origin := Vector2(0.0, 0.0)

	# 1. Opening
	_draw_box(Rect2(origin, BOX), opening.color, open, opening.display_name, font)
	# 2. Flow bar
	var flow_rect := Rect2(origin + Vector2(BOX.x + GAP, 0.0), BOX)
	draw_rect(flow_rect, Color(0.08, 0.07, 0.12, 0.85))
	var fill := Rect2(flow_rect.position, Vector2(BOX.x * clampf(kata.flow_value / kata.flow_cap, 0.0, 1.0), BOX.y))
	if open:
		draw_rect(fill, Color(flow.color.r, flow.color.g, flow.color.b, 0.75))
	draw_rect(flow_rect, flow.color if open else Color(0.4, 0.4, 0.5, 0.8), false, 2.0)
	_draw_label(flow.display_name, flow_rect, font, open)
	if open:
		var left: float = clampf(1.0 - kata.idle_time / kata.open_timeout, 0.0, 1.0)
		draw_rect(Rect2(flow_rect.position + Vector2(0.0, BOX.y + 5.0), Vector2(BOX.x * left, 3.0)), Color(1, 1, 1, 0.6))
	# 3. Finisher
	var ready_glow: float = kata.flow_value / kata.flow_cap if open else 0.0
	var finisher_rect := Rect2(origin + Vector2((BOX.x + GAP) * 2.0, 0.0), BOX)
	_draw_box(finisher_rect, finisher.color, open and ready_glow > 0.0, finisher.display_name, font)
	if open and ready_glow >= 0.99:
		draw_rect(finisher_rect.grow(3.0), Color(1.0, 0.85, 0.4, 0.9), false, 3.0)
	# arrows between the boxes
	for index in 2:
		var arrow_x: float = BOX.x * (index + 1) + GAP * index + GAP * 0.5
		draw_string(font, Vector2(arrow_x - 6.0, BOX.y * 0.7), ">", HORIZONTAL_ALIGNMENT_CENTER, 12.0, 20, Color(1, 1, 1, 0.6 if open else 0.25))


func _draw_box(rect: Rect2, color: Color, lit: bool, text: String, font: Font) -> void:
	draw_rect(rect, Color(color.r, color.g, color.b, 0.35) if lit else Color(0.08, 0.07, 0.12, 0.85))
	draw_rect(rect, color if lit else Color(0.4, 0.4, 0.5, 0.8), false, 2.0)
	_draw_label(text, rect, font, lit)


func _draw_label(text: String, rect: Rect2, font: Font, lit: bool) -> void:
	draw_string(font, rect.position + Vector2(0.0, BOX.y * 0.64), text, HORIZONTAL_ALIGNMENT_CENTER, BOX.x, 15,
		Color(1, 1, 1, 1.0 if lit else 0.55))
