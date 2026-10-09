#!/usr/bin/env python3
"""Writes resources/techniques/*.tres and the pool list from the table below (design/KUROTSUKI_Liste.xlsx, sheet Kata).
Run from the repo root:  python3 tools/content/generate_techniques.py
category: 0 Opening, 1 Flow, 2 Finisher, 3 Master. rarity: 0 common, 1 rare, 2 epic, 3 legendary."""
import os

OP, FL, FI, MA = 0, 1, 2, 3
T = []  # (id, name, description, category, rarity, color, script, params)
def add(id, name, desc, cat, rarity, color, script, params=None):
    T.append((id, name, desc, cat, rarity, color, script, params or {}))

# ---- Openings
add("quick_draw", "Quick Draw", "Opening: dashing starts the Kata, with a little Flow already built.", OP, 0, (0.4, 0.8, 1), "QuickDraw", {"start_flow": 0.25})
add("riposte_step", "Riposte Step", "Opening: a Perfect Dodge starts the Kata with a lot of Flow.", OP, 1, (0.5, 0.95, 1), "RiposteStep", {"start_flow": 0.6})
add("ghost_step", "Ghost Step", "Opening: a hit on an enemy's back starts the Kata.", OP, 0, (0.7, 0.6, 1), "GhostStep", {"start_flow": 0.3})
add("wounded_resolve", "Wounded Resolve", "Opening: taking damage starts the Kata with 40% Flow. Pain becomes focus.", OP, 1, (0.95, 0.35, 0.35), "EventOpening", {"event": "damage_taken", "start_flow": 0.4})
add("crescent_entry", "Crescent Entry", "Opening: the Iaijutsu cut starts the Kata (when the cut is made, not when you press the key).", OP, 1, (0.55, 0.85, 1), "SkillOpening", {"skill": "Iaijutsu", "start_flow": 0.35})
add("shadow_vault", "Shadow Vault", "Opening: a Kaeshi counter starts the Kata (when it hits back, not when you press the key).", OP, 1, (0.55, 0.5, 0.9), "SkillOpening", {"skill": "Kaeshi", "start_flow": 0.35})
add("hunters_mark", "Hunter's Mark", "Opening: a kill starts the Kata and marks the nearest enemy (+20% damage taken, 4 s).", OP, 1, (0.9, 0.5, 0.3), "EventOpening", {"event": "kill", "start_flow": 0.3, "mark_bonus": 0.2, "mark_time": 4.0})
add("critical_spark", "Critical Spark", "Opening: a critical hit starts the Kata.", OP, 1, (1, 0.9, 0.4), "EventOpening", {"event": "critical_hit", "start_flow": 0.3})
add("thousand_cuts", "Thousand Cuts", "Opening: the first hit on an unhurt enemy starts the Kata.", OP, 0, (0.8, 0.8, 0.85), "EventOpening", {"event": "hit_dealt", "needs_full_health": True, "start_flow": 0.25})

# ---- Flows
add("crimson_rhythm", "Crimson Rhythm", "Flow: every connecting light swing is worth more than the one before. Getting hit breaks the rhythm.", FL, 0, (0.9, 0.2, 0.3), "CrimsonRhythm", {"base_gain": 0.15, "streak_gain": 0.07, "loss_when_hit": 0.3})
add("untouched_edge", "Untouched Edge", "Flow: builds fast and your blade is 25% quicker while you are not hit. The first hit you take wipes both.", FL, 1, (0.9, 0.95, 1), "UntouchedEdge", {"gain_per_hit": 0.4, "attack_speed": 0.25})
add("crit_current", "Crit Current", "Flow: critical hits add a lot of Flow.", FL, 1, (1, 0.85, 0.35), "EventFlow", {"light_gain": 0.05, "crit_gain": 0.4, "loss_when_hit": 0.25})
add("dancing_blade", "Dancing Blade", "Flow: every dash adds Flow.", FL, 0, (0.45, 0.85, 0.95), "EventFlow", {"light_gain": 0.05, "dodge_gain": 0.2, "loss_when_hit": 0.25})
add("still_water", "Still Water", "Flow: slowly fills by itself (it does not keep the Kata open alone). Taking damage halves it.", FL, 1, (0.4, 0.6, 1), "EventFlow", {"light_gain": 0.05, "per_second": 0.2, "halve_when_hit": True})
add("perfect_tempo", "Perfect Tempo", "Flow: a Perfect Dodge adds 50% Flow.", FL, 1, (0.5, 1, 0.9), "EventFlow", {"light_gain": 0.05, "perfect_gain": 0.5, "loss_when_hit": 0.25})
add("skill_weaver", "Skill Weaver", "Flow: the Iaijutsu cut, a Kaeshi counter and Moonlit Storm starting add Flow.", FL, 1, (0.75, 0.55, 1), "EventFlow", {"light_gain": 0.05, "skill_gain": 0.3, "loss_when_hit": 0.25})
add("backstab_rhythm", "Backstab Rhythm", "Flow: hits on an enemy's back add Flow.", FL, 0, (0.6, 0.4, 0.8), "EventFlow", {"light_gain": 0.05, "behind_gain": 0.3, "loss_when_hit": 0.25})

# ---- Finishers
add("moon_sever", "Moon Sever", "Finisher: a huge slash, wider and harder with Flow.", FI, 1, (1, 0.9, 0.5), "MoonSever", {"flow_bonus": 1.0, "scale": 1.6})
add("crimson_execution", "Crimson Execution", "Finisher: enemies left below 30% health die on the spot.", FI, 2, (0.9, 0.15, 0.2), "CrimsonExecution", {"flow_bonus": 0.6, "execute_below": 0.3})
add("whirlwind", "Whirlwind", "Finisher: the slash becomes a circle around you.", FI, 0, (0.6, 0.9, 0.8), "Whirlwind", {"flow_bonus": 0.8, "scale": 1.5})
add("gale_slash", "Gale Slash", "Finisher: the slash also sends a wave that pierces 12 m forward.", FI, 1, (0.6, 0.95, 1), "GaleSlash", {"flow_bonus": 0.6, "wave_ratio": 0.7})
add("twin_fang", "Twin Fang", "Finisher: the arc is followed by a quick thrust straight ahead (60% damage).", FI, 1, (1, 0.5, 0.5), "TwinFang", {"flow_bonus": 0.6, "ratio": 0.6, "delay": 0.18})
add("blood_harvest", "Blood Harvest", "Finisher: every enemy the slash hits heals you 3 HP.", FI, 1, (0.8, 0.1, 0.3), "BloodHarvest", {"flow_bonus": 0.6, "heal": 3.0})
add("shatter", "Shatter", "Finisher: the enemies it hits are stunned 1.5 s and take +25% damage for 4 s.", FI, 2, (0.7, 0.85, 1), "Shatter", {"flow_bonus": 0.6, "stun": 1.5, "mark_bonus": 0.25, "mark_time": 4.0})
add("spirit_cleave", "Spirit Cleave", "Finisher: +20% damage for every enemy in the arc when you strike.", FI, 2, (0.55, 0.9, 0.7), "SpiritCleave", {"flow_bonus": 0.6, "per_enemy": 0.2})
add("crimson_rain", "Crimson Rain", "Finisher: leaves a pool in front of you that makes the enemies bleed for 3 s.", FI, 1, (0.85, 0.1, 0.25), "CrimsonRain", {"flow_bonus": 0.6, "radius": 2.6, "time": 3.0, "bleed": 6.0, "distance": 3.0})
add("tremor", "Tremor", "Finisher: the ground in front of you shakes and hurts everything on it for 3 s.", FI, 1, (0.8, 0.65, 0.35), "Tremor", {"flow_bonus": 0.6, "radius": 2.8, "time": 3.0, "damage_ratio": 1.2, "distance": 3.0})
add("storm_step", "Storm Step", "Finisher: you cannot be hurt from the strike until its recovery ends.", FI, 1, (0.5, 0.7, 1), "StormStep", {"flow_bonus": 0.6})

# ---- Masters
add("perfect_draw", "Perfect Draw", "Master: a Perfect Dodge makes your next Finisher a guaranteed critical hit.", MA, 3, (1, 0.85, 0.3), "PerfectDraw")
add("shadow_doppelganger", "Shadow Doppelganger", "Master: a shadow repeats every Finisher a moment later.", MA, 3, (0.45, 0.35, 0.7), "ShadowDoppelganger", {"echo_damage": 0.6})
add("echo_opening", "Echo Opening", "Master: after a Finisher the Kata opens again at once, with 30% Flow.", MA, 3, (0.7, 0.9, 1), "EchoOpening", {"flow": 0.3})
add("dual_flow", "Dual Flow", "Master: a second Flow slot. Find another Flow technique and both work together.", MA, 3, (1, 0.6, 0.9), "DualFlow")
add("double_opening", "Double Opening", "Master: a second Opening slot. Either Opening can start the Kata.", MA, 3, (0.6, 1, 0.8), "DoubleOpening")
add("perfect_silence", "Perfect Silence", "Master: a Perfect Dodge freezes every enemy for 1 s.", MA, 3, (0.85, 0.95, 1), "PerfectSilence", {"time": 1.0})
add("blood_oath", "Blood Oath", "Master: each kill in the room adds +1% damage to your next Finisher (max +100%).", MA, 3, (0.75, 0.05, 0.15), "BloodOath", {"per_kill": 0.01, "max_bonus": 1.0})
add("phantom_cut", "Phantom Cut", "Master: every 4th light hit leaves a phantom slash that strikes half a second later.", MA, 3, (0.7, 0.6, 1), "PhantomCut", {"every": 4, "ratio": 1.0, "delay": 0.5})
add("eternal_flow", "Eternal Flow", "Master: the Kata never closes by itself, but the Flow slowly drains.", MA, 3, (0.4, 0.9, 1), "EternalFlow", {"decay": 0.05})
add("moonlit_execution", "Moonlit Execution", "Master: with the Flow full, your Finisher is always a critical hit.", MA, 3, (1, 0.95, 0.7), "MoonlitExecution")

OUT = "resources/techniques"
os.makedirs(OUT, exist_ok=True)

def esc(t):
    return t.replace("\\", "\\\\").replace('"', '\\"')

def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % esc(v)
    if isinstance(v, int):
        return str(v)
    return repr(float(v))

for f in os.listdir(OUT):  # remove techniques that are no longer in the table
    if f.endswith(".tres") and f[:-5] not in [t[0] for t in T] and f != "_pool.tres":
        os.remove(os.path.join(OUT, f))

for id, name, desc, cat, rarity, color, script, params in T:
    lines = ['[gd_resource type="Resource" script_class="TechniqueData" load_steps=3 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/player/kata/TechniqueData.gd" id="1_data"]',
             '[ext_resource type="Script" path="res://scripts/player/kata/techniques/%s.gd" id="2_behavior"]' % script, "",
             "[resource]", 'script = ExtResource("1_data")', 'id = "%s"' % id, 'display_name = "%s"' % esc(name),
             'description = "%s"' % esc(desc), "category = %d" % cat, "rarity = %d" % rarity,
             "color = Color(%s, %s, %s, 1)" % color, 'behavior = ExtResource("2_behavior")']
    lines.append("params = {\n%s\n}" % ",\n".join('"%s": %s' % (k, val(v)) for k, v in params.items()) if params else "params = {\n\n}")
    with open("%s/%s.tres" % (OUT, id), "w") as f:
        f.write("\n".join(lines) + "\n")

pool = ['[gd_resource type="Resource" script_class="TechniquePool" format=3]', "",
        '[ext_resource type="Script" path="res://scripts/player/kata/TechniquePool.gd" id="1_pool"]']
for i, t in enumerate(T, 1):
    pool.append('[ext_resource type="Resource" path="res://%s/%s.tres" id="t%d"]' % (OUT, t[0], i))
pool += ["", "[resource]", 'script = ExtResource("1_pool")',
         "techniques = Array[Resource]([%s])" % ", ".join('ExtResource("t%d")' % i for i in range(1, len(T) + 1))]
with open("%s/_pool.tres" % OUT, "w") as f:
    f.write("\n".join(pool) + "\n")
print(len(T), "techniques")
