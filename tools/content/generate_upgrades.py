#!/usr/bin/env python3
"""Writes resources/upgrades/*.tres (and the pool list) from the table below.
The table follows design/KUROTSUKI_Liste.xlsx (sheet Upgrades, rows marked DA / MODIFIC).
Run from the repo root:  python3 tools/content/generate_upgrades.py
Names and descriptions are the text shown in the game (English). Effects: (stat, "A" flat | "P" percent, value).
A behavior is (script file in scripts/upgrades/behaviors/, {params})."""
import os

RARITY = {"Common": 0, "Rare": 1, "Epic": 2, "Legendary": 3, "Cursed": 4}
OPS = {"A": 0, "P": 1}
DG, CR, SF, SV, EC, CO = "Dodge & Counter", "Crit & Execution", "Speed & Flow", "Survival", "Economy", "Corruption"

U = []  # (id, name, rarity, build, description, [effects], behavior or None)
def add(id, name, rarity, build, desc, effects=(), behavior=None, character=""):
    U.append((id, name, rarity, build, desc, list(effects), behavior, character))

# ---- the first ten (some values changed after the list review)
add("blood_edge", "Blood Edge", "Common", CR, "+15% attack damage", [("attack_damage", "P", 0.15)])
add("crimson_meal", "Crimson Meal", "Rare", SV, "Heal 6% of the damage you deal", [("lifesteal", "A", 0.06)])
add("dark_breath", "Dark Breath", "Epic", CO, "Each kill adds 3 Corruption", [("corruption_on_hit", "A", 3)])
add("executioner", "Executioner", "Rare", CR, "+50% damage against enemies below 30% HP", [("execute_bonus", "A", 0.5)])
add("iron_skin", "Iron Skin", "Common", SV, "-10% damage taken", [("damage_taken", "P", -0.10)])
add("keen_edge", "Keen Edge", "Rare", CR, "+10% critical chance", [("crit_chance", "A", 0.10)])
add("sakura_step", "Sakura Step", "Common", SF, "+15% movement speed", [("move_speed", "P", 0.15)])
add("shadow_step", "Shadow Step", "Epic", DG, "+1 dodge charge", [("dodge_charges", "A", 1)])
add("swift_blade", "Swift Blade", "Common", SF, "+15% attack speed", [("attack_speed", "P", 0.15)])
add("vital_spirit", "Vital Spirit", "Common", SV, "+20 max HP", [("max_health", "A", 20)])

# ---- Dodge & Counter
add("ghost_sandals", "Ghost Sandals", "Common", DG, "Dash charges come back 15% faster", [("dash_recharge", "A", 0.15)])
add("long_stride", "Long Stride", "Common", DG, "Your dash goes 25% farther", [("dash_distance", "A", 0.25)])
add("phantom_window", "Phantom Window", "Rare", DG, "The Perfect Dodge window is 40% longer", [("perfect_window", "A", 0.4)])
add("riposte_edge", "Riposte Edge", "Rare", DG, "After a Perfect Dodge your next hit does +50% damage (3 s)", [], ("RiposteEdge", {"bonus": 0.5, "time": 3.0}))
add("slipstream", "Slipstream", "Common", DG, "After a dash you move 20% faster for 2 s", [], ("Slipstream", {"bonus": 0.2, "time": 2.2}))
add("mirror_step", "Mirror Step", "Epic", DG, "A Perfect Dodge gives your dash charge back", [], ("MirrorStep", {}))
add("quick_recovery", "Quick Recovery", "Common", DG, "Each hit you land recharges your dash by 0.2 s", [], ("QuickRecovery", {"seconds": 0.2}))
add("time_slip", "Time Slip", "Epic", DG, "A Perfect Dodge slows the enemies 0.5 s longer", [("perfect_slow_bonus", "A", 0.5)])
add("twin_moons", "Twin Moons", "Legendary", DG, "+2 dodge charges", [("dodge_charges", "A", 2)])
add("lucky_thread", "Lucky Thread", "Common", DG, "10% chance that a hit you take does nothing", [("evade_chance", "A", 0.10)])

# ---- Crit & Execution
add("sharp_focus", "Sharp Focus", "Common", CR, "+5% critical chance", [("crit_chance", "A", 0.05)])
add("heavy_hands", "Heavy Hands", "Common", CR, "Critical hits do +25% more damage", [("crit_damage", "A", 0.25)])
add("killing_intent", "Killing Intent", "Rare", CR, "Enemies below 40% HP (instead of 30%) count as wounded, and you do +25% damage to them", [("execute_threshold", "A", 0.10), ("execute_bonus", "A", 0.25)])
add("soul_reaper", "Soul Reaper", "Rare", CR, "Each kill charges your Ultimate by 5%", [], ("SoulReaper", {"ratio": 0.05}))
add("bloodthirst", "Bloodthirst", "Common", SV, "Heal +2% of the damage you deal", [("lifesteal", "A", 0.02)])
add("bleeding_cut", "Bleeding Cut", "Rare", CR, "Critical hits make the enemy bleed for 3 s", [], ("BleedingCut", {"dps_ratio": 0.3, "time": 3.0}))
add("finish_them", "Finish Them", "Rare", CR, "Heavy does +30% damage to enemies below 40% HP", [], ("FinishThem", {"bonus": 0.3, "threshold": 0.4}))
add("deadeye", "Deadeye", "Epic", CR, "Your first hit on each enemy has +15% critical chance", [], ("Deadeye", {"bonus": 0.15}))
add("overkill_wave", "Overkill Wave", "Epic", CR, "Damage beyond a kill hurts nearby enemies (50%)", [], ("OverkillWave", {"ratio": 0.5, "radius": 4.0}))
add("death_mark", "Death Mark", "Epic", CR, "Light attacks kill enemies below 10% HP outright", [], ("DeathMark", {"threshold": 0.10}))
add("lethal_rhythm", "Lethal Rhythm", "Legendary", CR, "Every 5th light hit in a row is a guaranteed critical hit (taking damage resets it)", [], ("LethalRhythm", {"every": 5}))
add("falcon_eye", "Falcon Eye", "Common", CR, "+7% critical chance", [("crit_chance", "A", 0.07)])
add("backstab_instinct", "Backstab Instinct", "Rare", CR, "Hits on an enemy's back have +30% critical chance", [], ("BackstabInstinct", {"bonus": 0.30}))
add("perfect_aim", "Perfect Aim", "Epic", CR, "After a Perfect Dodge you have +40% critical chance for 3 s", [], ("PerfectAim", {"bonus": 0.40, "time": 3.0}))
add("crit_momentum", "Crit Momentum", "Epic", CR, "Each critical hit gives +4% critical chance for 4 s (stacks up to 5 times)", [], ("CritMomentum", {"bonus": 0.04, "time": 4.0, "max_stacks": 5}))
add("dragon_fang", "Dragon Fang", "Legendary", CR, "+25% critical chance and critical hits do +50% more damage", [("crit_chance", "A", 0.25), ("crit_damage", "A", 0.5)])

# ---- Speed & Flow
add("light_grip", "Light Grip", "Common", SF, "+10% attack speed", [("attack_speed", "P", 0.10)])
add("wind_walker", "Wind Walker", "Common", SF, "+10% movement speed", [("move_speed", "P", 0.10)])
add("flow_seeker", "Flow Seeker", "Rare", SF, "You gain 20% more Flow", [("flow_gain", "A", 0.2)])
add("lingering_mist", "Lingering Mist", "Rare", SF, "Your Kata stays open 1 s longer without activity", [("kata_timeout_bonus", "A", 1.0)])
add("opening_strike", "Opening Strike", "Common", SF, "The first hit after your Kata opens does +40% damage", [], ("OpeningStrike", {"bonus": 0.4}))
add("rhythm_keeper", "Rhythm Keeper", "Rare", SF, "You lose 50% less Flow when hit", [("flow_loss", "A", -0.5)])
add("finisher_edge", "Finisher Edge", "Rare", SF, "Heavy recharges 20% faster", [("heavy_cooldown", "A", -0.2)])
add("heavy_momentum", "Heavy Momentum", "Rare", SF, "Heavy does +25% damage", [("heavy_damage", "A", 0.25)])
add("combo_spark", "Combo Spark", "Epic", SF, "While your Kata is open, every 3rd light hit sends a slash wave forward (60% damage, 8 m)", [], ("ComboSpark", {"every": 3, "ratio": 0.6}))
add("whirl_training", "Whirl Training", "Common", SF, "Heavy reaches 15% farther", [("heavy_range", "A", 0.15)])
add("second_wind", "Second Wind", "Epic", SF, "After a Finisher your Kata opens again with 30% Flow", [], ("SecondWind", {"flow": 0.3}))
add("skill_haste", "Skill Haste", "Common", SF, "Iaijutsu and Kaeshi recharge 15% faster", [("skill_cooldown", "A", -0.15)])
add("blade_storm", "Blade Storm", "Legendary", SF, "+35% attack speed and +15% movement speed", [("attack_speed", "P", 0.35), ("move_speed", "P", 0.15)])

# ---- Survival
add("iron_will", "Iron Will", "Common", SV, "+10% max HP", [("max_health", "P", 0.10)])
add("stone_skin", "Stone Skin", "Common", SV, "-8% damage taken", [("damage_taken", "P", -0.08)])
add("bamboo_heart", "Bamboo Heart", "Common", SV, "Heal 10% of your HP when you clear a fight room", [], ("BambooHeart", {"ratio": 0.10}))
add("second_chance", "Second Chance", "Epic", SV, "Once per run, a deadly hit leaves you with 30% HP", [], ("SecondChance", {"ratio": 0.3}))
add("armor_plate", "Armor Plate", "Rare", SV, "A 15 damage shield comes back in every room", [], ("ArmorPlate", {"amount": 15.0}))
add("warm_tea", "Warm Tea", "Common", SV, "Heal 15% HP the first time you enter a Shop in each biome", [], ("WarmTea", {"ratio": 0.15}))
add("last_stand", "Last Stand", "Rare", SV, "Below 30% HP: +25% damage and -20% damage taken", [], ("LastStand", {"threshold": 0.3, "damage": 0.25, "defense": 0.2}))
add("spiked_armor", "Spiked Armor", "Rare", SV, "Enemies that hit you take 8 damage", [], ("SpikedArmor", {"damage": 8.0}))
add("lifebloom", "Lifebloom", "Rare", SV, "+15 max HP and heal 20 HP on every level up", [("max_health", "A", 15)], ("Lifebloom", {"heal": 20.0}))
add("calm_mind", "Calm Mind", "Rare", SV, "+1 hit ignored in every room", [("free_hits_per_room", "A", 1)])
add("guardian_spirit", "Guardian Spirit", "Epic", SV, "A Perfect Dodge gives you a 20 damage shield", [], ("GuardianSpirit", {"amount": 20.0}))
add("adrenaline", "Adrenaline", "Rare", SV, "After you are hit: +30% attack speed for 3 s", [], ("Adrenaline", {"bonus": 0.3, "time": 3.0}))
add("iron_constitution", "Iron Constitution", "Legendary", SV, "+50 max HP and -15% damage taken", [("max_health", "A", 50), ("damage_taken", "P", -0.15)])

# ---- Economy and utility
add("merchants_eye", "Merchant's Eye", "Common", EC, "+15% gold from rooms", [("gold_gain", "P", 0.15)])
add("haggler", "Haggler", "Common", EC, "Shops charge 10% less", [("shop_discount", "A", 0.10)])
add("scholars_brush", "Scholar's Brush", "Common", EC, "+10% EXP from enemies", [("xp_gain", "A", 0.10)])
add("wide_view", "Wide View", "Epic", EC, "Level ups offer 4 upgrades instead of 3", [("choice_count", "A", 1)])
add("reroll_token", "Reroll Token", "Rare", EC, "Once per run you can reroll a level up choice (key R)", [("rerolls", "A", 1)])

# ---- Style upgrades of the characters (their own character sees them about 3 times more often)
add("dream_echo", "Dream Echo", "Epic", SF, "Every dash leaves a clone that cuts the spot a moment later", [], ("DreamEcho", {"damage_ratio": 0.8, "radius": 2.2, "delay": 0.3, "cooldown": 1.0}), "yume")
add("quick_hands", "Quick Hands", "Rare", SF, "Every 3rd light hit in a row: +15% attack speed for 2 s", [], ("QuickHands", {"every": 3, "bonus": 0.15, "time": 2.0}), "yume")
add("silk_step", "Silk Step", "Rare", DG, "After a Perfect Dodge the enemies lose sight of you for 1 s", [], ("SilkStep", {"time": 1.0}), "yume")

add("weapon_master", "Weapon Master", "Common", SF, "Your basic attack reaches 15% farther", [("attack_range", "P", 0.15)])

# ---- Cursed (offered only after the Corruption bar reached 50% once in a run): strong, with a price
add("cursed_blade", "Cursed Blade", "Cursed", CO, "+60% attack damage, but -25% max HP", [("attack_damage", "P", 0.60), ("max_health", "P", -0.25)])
add("cursed_rhythm", "Cursed Rhythm", "Cursed", CO, "The Flow grows twice as fast, but the Kata closes after 1.5 s of silence", [("flow_gain", "P", 1.0), ("kata_timeout_bonus", "A", -1.5)])
add("cursed_haste", "Cursed Haste", "Cursed", CO, "+40% attack speed, but your dash recharges 35% slower", [("attack_speed", "P", 0.40), ("dash_recharge", "P", -0.35)])
add("cursed_wound", "Cursed Wound", "Cursed", CO, "Bleeding hurts 60% more, but -15% max HP", [("bleed_power", "P", 0.60), ("max_health", "P", -0.15)])

OUT = "resources/upgrades"
os.makedirs(OUT, exist_ok=True)

def esc(text):
    return text.replace("\\", "\\\\").replace('"', '\\"')

def num(v):
    return repr(float(v)) if not float(v).is_integer() else "%d.0" % v

for id, name, rarity, build, desc, effects, behavior, character in U:
    lines = ['[gd_resource type="Resource" script_class="UpgradeData" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/upgrades/UpgradeData.gd" id="1_data"]',
             '[ext_resource type="Script" path="res://scripts/upgrades/UpgradeEffect.gd" id="2_effect"]']
    if behavior:
        lines.append('[ext_resource type="Script" path="res://scripts/upgrades/behaviors/%s.gd" id="3_behavior"]' % behavior[0])
    lines.append("")
    for i, (stat, op, value) in enumerate(effects, 1):
        lines += ['[sub_resource type="Resource" id="Effect_%d"]' % i, 'script = ExtResource("2_effect")',
                  'stat = "%s"' % stat, "operation = %d" % OPS[op], "value = %s" % num(value), ""]
    lines += ["[resource]", 'script = ExtResource("1_data")', 'id = "%s"' % id, 'display_name = "%s"' % esc(name),
              'description = "%s"' % esc(desc)]
    if RARITY[rarity]:
        lines.append("rarity = %d" % RARITY[rarity])
    lines.append("effects = Array[Resource]([%s])" % ", ".join('SubResource("Effect_%d")' % i for i in range(1, len(effects) + 1)))
    if behavior:
        lines.append('behavior = ExtResource("3_behavior")')
        if behavior[1]:
            body = ",\n".join('"%s": %s' % (k, num(v)) for k, v in behavior[1].items())
            lines.append("params = {\n%s\n}" % body)
    if character:
        lines.append('character = "%s"' % character)
    lines.append('build = "%s"' % build)
    with open("%s/%s.tres" % (OUT, id), "w") as f:
        f.write("\n".join(lines) + "\n")

# the list the UpgradeManager reads (Cursed upgrades are in it but only offered once Corruption reached 50%)
pool = ['[gd_resource type="Resource" script_class="UpgradePool" format=3]', "",
        '[ext_resource type="Script" path="res://scripts/upgrades/UpgradePool.gd" id="1_pool"]']
for i, u in enumerate(U, 1):
    pool.append('[ext_resource type="Resource" path="res://%s/%s.tres" id="u%d"]' % (OUT, u[0], i))
pool += ["", "[resource]", 'script = ExtResource("1_pool")',
         "upgrades = Array[Resource]([%s])" % ", ".join('ExtResource("u%d")' % i for i in range(1, len(U) + 1))]
with open("%s/_pool.tres" % OUT, "w") as f:
    f.write("\n".join(pool) + "\n")
print("wrote %d upgrades" % len(U))
