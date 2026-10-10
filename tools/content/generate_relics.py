#!/usr/bin/env python3
"""Writes resources/relics/*.tres and the pool list from the table below (design/KUROTSUKI_Liste.xlsx, sheet Relics).
Run from the repo root:  python3 tools/content/generate_relics.py
Effects: (stat, "A" flat | "P" percent, value). Behavior: (script file in scripts/relics/behaviors/, {params})."""
import os

OPS = {"A": 0, "P": 1}
DG, CR, SF, SV, EC, BL = "Dodge & Counter", "Crit & Execution", "Speed & Flow", "Survival", "Economy", "Bleed"

R = []  # (id, name, description, color (r,g,b), price, build, effects, behavior)
def add(id, name, desc, color, price, build, effects=(), behavior=None, cursed=False):
    R.append((id, name, desc, color, price, build, list(effects), behavior, cursed))

add("fox_mask", "Fox Mask", "Blocks the first hit you take in every room.", (1, 0.55, 0.2), 150, SV, [("free_hits_per_room", "A", 1)])
add("black_pearl", "Black Pearl", "+20% gold from rooms. Shops charge 20% less.", (0.65, 0.7, 0.95), 130, EC, [("gold_gain", "P", 0.2), ("shop_discount", "A", 0.2)])
add("oni_horn", "Oni Horn", "+25% damage, but -20% max HP.", (0.9, 0.2, 0.2), 140, CR, [("attack_damage", "P", 0.25), ("max_health", "P", -0.2)])
add("samurai_eye", "Samurai Eye", "A Perfect Dodge slows the enemies 0.3 s longer.", (0.4, 0.8, 1.0), 140, DG, [("perfect_slow_bonus", "A", 0.3)])
add("kurotsuki_eye", "Kurotsuki Eye", "A kill marks the nearest enemy: it takes +25% damage for 6 s.", (0.7, 0.2, 0.9), 170, CR, [], ("KurotsukiEye", {"bonus": 0.25, "time": 6.0}))
add("sakura_charm", "Sakura Charm", "A Finisher that kills heals you for 15% of the damage of that blow.", (1.0, 0.6, 0.75), 140, SV, [], ("SakuraCharm", {"ratio": 0.15}))
add("crow_feather", "Crow Feather", "Your dash leaves a trail that makes enemies bleed.", (0.3, 0.25, 0.45), 160, BL, [], ("CrowFeather", {"radius": 1.1, "time": 3.0, "bleed": 5.0}))
add("paper_lantern", "Paper Lantern", "For 1 s after you hit something, being hit does not take Flow away.", (1.0, 0.85, 0.5), 140, SF, [], ("PaperLantern", {"time": 1.0}))
add("broken_hilt", "Broken Katana Hilt", "Your Finisher also sends a slash wave forward.", (0.75, 0.75, 0.8), 170, SF, [], ("BrokenHilt", {"ratio": 0.6}))
add("moon_shard", "Moon Shard", "Whatever opens your Kata, it starts with at least 50% Flow.", (0.6, 0.7, 1.0), 160, SF, [], ("MoonShard", {"flow": 0.5}))
add("tengu_fan", "Tengu Fan", "A Perfect Dodge pushes the enemies around you away.", (0.9, 0.3, 0.3), 150, DG, [], ("TenguFan", {"radius": 5.0, "strength": 14.0}))
add("kitsune_tail", "Kitsune Tail", "After a Perfect Dodge: +30% speed and the enemies lose sight of you for 2 s.", (1.0, 0.6, 0.3), 160, DG, [], ("KitsuneTail", {"bonus": 0.3, "time": 2.0}))
add("jade_bead", "Jade Bead", "Every level up heals 30% of your HP.", (0.4, 0.9, 0.6), 130, SV, [], ("JadeBead", {"ratio": 0.3}))
add("daruma_doll", "Daruma Doll", "Once per biome, a deadly hit leaves you with 1 HP.", (0.9, 0.2, 0.2), 180, SV, [], ("DarumaDoll", {}))
add("shrine_bell", "Shrine Bell", "Boss and mini-boss rooms start with your Kata open and full of Flow.", (0.95, 0.85, 0.4), 150, SF, [], ("ShrineBell", {}))
add("onibi_flame", "Onibi Flame", "Kills have a 20% chance to leave a flame that makes enemies bleed.", (0.4, 0.5, 1.0), 160, BL, [], ("OnibiFlame", {"chance": 0.2, "radius": 1.6, "time": 8.0, "bleed": 6.0}))
add("iron_fan", "Iron Fan", "Your Heavy destroys the enemy projectiles in front of you.", (0.7, 0.75, 0.8), 130, DG, [], ("IronFan", {"range": 4.5}))
add("hannya_mask", "Hannya Mask", "Critical hits do +100% more damage, but -10% max HP.", (0.85, 0.15, 0.25), 150, CR, [("crit_damage", "A", 1.0), ("max_health", "P", -0.1)])
add("gold_frog", "Gold Frog", "Every coin you pick up heals 1 HP.", (1.0, 0.85, 0.2), 120, EC, [], ("GoldFrog", {"heal": 1.0}))
add("duel_scroll", "Scroll of Duels", "Duel and Arena rewards offer one more card.", (0.8, 0.7, 0.5), 170, SF, [("reward_cards", "A", 1)])
add("merchant_seal", "Merchant's Seal", "Shops have one more item, and sell Kata techniques twice as often.", (0.5, 0.9, 0.5), 160, EC, [("shop_extra_item", "A", 1), ("shop_technique_mult", "P", 1.0)])
add("whetstone", "Whetstone", "+15% damage while your Kata is open.", (0.7, 0.7, 0.75), 140, SF, [], ("Whetstone", {"bonus": 0.15}))
add("wanderer_map", "Wanderer's Map", "The minimap shows the type of the rooms next to the ones you know.", (0.8, 0.65, 0.4), 120, EC, [])
add("calligraphy_ink", "Calligrapher's Ink", "Master techniques appear more often in Duel and Arena rewards (+25%).", (0.3, 0.3, 0.45), 170, SF, [("master_chance", "A", 0.25)])
add("mountain_heart", "Heart of the Mountain", "+30 max HP, but -10% movement speed.", (0.55, 0.45, 0.4), 130, SV, [("max_health", "A", 30), ("move_speed", "P", -0.1)])
add("spirit_lantern", "Spirit Lantern", "Your Ultimate charges 25% faster, and kills during it make it last longer.", (0.7, 0.5, 1.0), 170, SF, [("ultimate_charge", "P", 0.25)], ("SpiritLantern", {"seconds": 0.5}))
add("soul_syphon", "Soul Syphon", "Every bleed tick on an enemy heals you for 50% of its damage.", (0.6, 0.2, 0.4), 170, BL, [], ("SoulSyphon", {"ratio": 0.5}))
add("vanish", "Vanish", "A Perfect Dodge makes you invisible for 0.8 s: the enemies start no new attacks.", (0.5, 0.45, 0.7), 160, DG, [], ("Vanish", {"time": 0.8}))

add("cursed_mirror", "Cursed Mirror", "A Perfect Dodge freezes time until you hit an enemy, and Finishers deal double damage, but you take 30% more damage.", (0.55, 0.1, 0.35), 180, SF, [], ("CursedMirror", {"damage_taken": 0.3, "finisher": 2.0, "max_freeze": 8.0}), True)

OUT = "resources/relics"
os.makedirs(OUT, exist_ok=True)

def esc(t):
    return t.replace("\\", "\\\\").replace('"', '\\"')

def num(v):
    return "%d.0" % v if float(v).is_integer() else repr(float(v))

for id, name, desc, color, price, build, effects, behavior, cursed in R:
    lines = ['[gd_resource type="Resource" script_class="RelicData" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/relics/RelicData.gd" id="1_data"]',
             '[ext_resource type="Script" path="res://scripts/upgrades/UpgradeEffect.gd" id="2_effect"]']
    if behavior:
        lines.append('[ext_resource type="Script" path="res://scripts/relics/behaviors/%s.gd" id="3_behavior"]' % behavior[0])
    lines.append("")
    for i, (stat, op, value) in enumerate(effects, 1):
        lines += ['[sub_resource type="Resource" id="Effect_%d"]' % i, 'script = ExtResource("2_effect")',
                  'stat = "%s"' % stat, "operation = %d" % OPS[op], "value = %s" % num(value), ""]
    lines += ["[resource]", 'script = ExtResource("1_data")', 'id = "%s"' % id, 'display_name = "%s"' % esc(name),
              'description = "%s"' % esc(desc), "color = Color(%s, %s, %s, 1)" % color,
              "effects = Array[Resource]([%s])" % ", ".join('SubResource("Effect_%d")' % i for i in range(1, len(effects) + 1))]
    if behavior:
        lines.append('behavior = ExtResource("3_behavior")')
        if behavior[1]:
            lines.append("params = {\n%s\n}" % ",\n".join('"%s": %s' % (k, num(v)) for k, v in behavior[1].items()))
    lines += ["price = %d" % price, 'build = "%s"' % build]
    if cursed:
        lines.append("cursed = true")
    with open("%s/%s.tres" % (OUT, id), "w") as f:
        f.write("\n".join(lines) + "\n")

pool = ['[gd_resource type="Resource" script_class="RelicPool" format=3]', "",
        '[ext_resource type="Script" path="res://scripts/relics/RelicPool.gd" id="1_pool"]']
for i, r in enumerate(R, 1):
    pool.append('[ext_resource type="Resource" path="res://%s/%s.tres" id="r%d"]' % (OUT, r[0], i))
pool += ["", "[resource]", 'script = ExtResource("1_pool")',
         "relics = Array[Resource]([%s])" % ", ".join('ExtResource("r%d")' % i for i in range(1, len(R) + 1))]
with open("%s/_pool.tres" % OUT, "w") as f:
    f.write("\n".join(pool) + "\n")
print("wrote %d relics" % len(R))
