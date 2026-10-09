class_name ArenaOmens
extends RefCounted
## The omens of an Arena (design/KUROTSUKI_Liste.xlsx, sheet Arena_Omens). The player is offered 3 random ones;
## the harder the omen, the better the reward. ArenaRoom applies the numbers and the special effects (by `id`).
##
## hp / damage: enemy multipliers          extra: more enemies per wave       heavy: Heavies in the last wave
## waves: enemies per wave (per group)     groups: 2 = two groups at once, from opposite sides (Twin Suns)
## speed: enemy speed multiplier           xp / gold: rewards                 master: chance of a Master card
## rerolls: rerolls of the technique offer  sky: atmosphere (Forward+): fog_density, fog_color, ambient_color,
##   ambient_energy, sun_color, sun_energy

const LIST: Array[Dictionary] = [
	{"id": "pale_moon", "name": "Pale Moon", "difficulty": "Easy", "color": Color(0.8, 0.85, 1.0), "hp": 1.0, "damage": 1.0,
		"extra": 0, "heavy": 0, "xp": 40, "gold": 30, "master": 0.0,
		"text": "Normal enemies.", "reward": "Technique + 40 EXP + 30 gold"},
	{"id": "blood_moon", "name": "Blood Moon", "difficulty": "Medium", "color": Color(1.0, 0.55, 0.3), "hp": 1.3, "damage": 1.25,
		"extra": 1, "heavy": 1, "xp": 90, "gold": 60, "master": 0.0,
		"text": "Enemies +30% health, +25% damage, one more per wave, a Heavy in the last wave.", "reward": "Technique + 90 EXP + 60 gold"},
	{"id": "black_storm", "name": "Black Storm", "difficulty": "Hard", "color": Color(0.75, 0.35, 1.0), "hp": 1.6, "damage": 1.5,
		"extra": 2, "heavy": 2, "xp": 180, "gold": 120, "master": 0.35,
		"text": "Enemies +60% health, +50% damage, two more per wave, two Heavies in the last wave.", "reward": "Technique + 180 EXP + 120 gold, 35% chance of a Master technique"},
	{"id": "fog_of_ghosts", "name": "Fog of Ghosts", "difficulty": "Medium", "color": Color(0.6, 0.75, 0.85), "xp": 100,
		"text": "A thick fog: the enemies fade into it and appear only when they are close.", "reward": "Technique + 100 EXP",
		"sky": {"fog_density": 0.05, "fog_color": Color(0.55, 0.62, 0.75), "ambient_color": Color(0.5, 0.55, 0.7), "ambient_energy": 0.7, "sun_energy": 0.6}},
	{"id": "iron_rain", "name": "Iron Rain", "difficulty": "Medium", "color": Color(0.7, 0.72, 0.8), "xp": 70, "gold": 70,
		"text": "Arrows rain on marked spots of the floor for the whole fight. Move, or dash through them.", "reward": "Technique + 70 gold + 70 EXP",
		"sky": {"ambient_color": Color(0.4, 0.42, 0.55), "ambient_energy": 0.55, "sun_energy": 0.6}},
	{"id": "eclipse", "name": "Eclipse", "difficulty": "Hard", "color": Color(0.9, 0.35, 0.25), "gold": 150, "speed": 1.3,
		"text": "Enemies are 30% faster, and the first attack of each one shows no warning.", "reward": "Technique + 150 gold",
		"sky": {"ambient_color": Color(0.55, 0.2, 0.2), "ambient_energy": 0.45, "sun_color": Color(1.0, 0.45, 0.3), "sun_energy": 0.3}},
	{"id": "hunger_moon", "name": "Hunger Moon", "difficulty": "Hard", "color": Color(0.85, 0.2, 0.3), "rerolls": 1,
		"text": "Nothing heals you in the arena: no healing, no life on kill.", "reward": "Technique, with one reroll of the offer",
		"sky": {"ambient_color": Color(0.5, 0.2, 0.25), "ambient_energy": 0.5, "sun_color": Color(1.0, 0.4, 0.35), "sun_energy": 0.55}},
	{"id": "silent_night", "name": "Silent Night", "difficulty": "Very hard", "color": Color(0.35, 0.45, 0.9), "hp": 1.4, "master": 0.5,
		"text": "The Ultimate does not charge. Enemies have +40% health.", "reward": "Technique, 50% chance of a Master technique",
		"sky": {"ambient_color": Color(0.15, 0.2, 0.45), "ambient_energy": 0.4, "sun_color": Color(0.5, 0.6, 1.0), "sun_energy": 0.25}},
	{"id": "crimson_tide", "name": "Crimson Tide", "difficulty": "Medium", "color": Color(0.95, 0.3, 0.35), "xp": 90,
		"text": "Enemies explode when they die: step away from the red circle.", "reward": "Technique + 90 EXP",
		"sky": {"ambient_color": Color(0.65, 0.3, 0.35), "ambient_energy": 0.6}},
	{"id": "twin_suns", "name": "Twin Suns", "difficulty": "Hard", "color": Color(1.0, 0.85, 0.35), "waves": [5, 6], "groups": 2, "xp": 120, "gold": 80,
		"text": "Two waves, but each one comes as two groups at once, from opposite sides.", "reward": "Technique + 120 EXP + 80 gold"},
]

const DEFAULTS: Dictionary = {
	"hp": 1.0, "damage": 1.0, "extra": 0, "heavy": 0, "xp": 0, "gold": 0, "master": 0.0, "speed": 1.0,
	"rerolls": 0, "waves": [4, 5, 6], "groups": 1, "sky": {},
}


## Every omen with all the numbers filled in.
static func all() -> Array:
	var result: Array = []
	for entry in LIST:
		var omen: Dictionary = DEFAULTS.duplicate(true)
		omen.merge(entry, true)
		result.append(omen)
	return result


static func find(omen_id: String) -> Dictionary:
	for omen in all():
		if omen.id == omen_id:
			return omen
	return {}


## `count` different random omens.
static func pick(count: int = 3) -> Array:
	var omens: Array = all()
	omens.shuffle()
	return omens.slice(0, count)
