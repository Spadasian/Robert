extends Node
## Everything that happens in the player's fight, as signals. The Kata and the relics listen to these;
## nothing here decides anything. Whoever causes an event emits it (attacks, dodge, Player.gd).
##
## info of hit_dealt / critical_hit / kill: { target: Node, damage: float, crit: bool, kind: "light" | "heavy" | "skill",
##   hit_count: int (hits of this swing so far), killed: bool, from_behind: bool }

signal light_attack
signal heavy_attack
signal hit_dealt(info: Dictionary)
signal critical_hit(info: Dictionary)
signal kill(info: Dictionary)
signal dodge # a dash started
signal perfect_dodge(source: Node) # a hit arrived just after a dash started: the dash made it miss
signal damage_taken(amount: float)
signal skill_used(skill: Node) # the button was pressed
signal skill_resolved(skill: Node) # the skill did its thing: the Kaeshi counter hit back, the Iaijutsu cut was made, the Ultimate began
signal bleed_tick(enemy: Node, damage: float) # an enemy lost health to bleeding
