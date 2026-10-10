#!/usr/bin/env python3
"""Writes resources/characters/*.tres from design/KUROTSUKI_Personaje.xlsx (sheet Stats: the columns Kazuma, Yume,
Takeda, Kurotsuki) and the table below. Run from the repo root:  python3 tools/content/generate_characters.py
Needs openpyxl. Stats that equal the base value are not written (only the differences)."""
import os, warnings
import openpyxl
warnings.filterwarnings("ignore")

XLSX = "design/KUROTSUKI_Personaje.xlsx"
OUT = "resources/characters"
# weapon model per character: (glb, position, rotation degrees, scale). The models are Y-up: rotating 90 degrees around X
# turns the tip forward (+Z); the position puts the grip in the hand of the swing.
MODELS = {
 "Kazuma": ("res://art/weapons/katana_kazuma.glb", (0.0, 0.0, 0.9), (90.0, 0.0, 0.0), 1.8),
 "Yume": ("res://art/weapons/tessen_yume.glb", (0.0, 0.0, 0.75), (90.0, 0.0, 0.0), 2.6),
 "Takeda": ("res://art/weapons/kanabo_takeda.glb", (0.0, 0.0, 1.1), (90.0, 0.0, 0.0), 1.3),
 "Kurotsuki": ("res://art/weapons/tekko_kagi_kurotsuki.glb", (0.0, 0.0, 0.7), (90.0, 0.0, 0.0), 3.2),
}
# The basic attack per character (see CharacterData.attack). Kazuma: the swing of the katana as it was.
ATTACKS = {
 "Kazuma": {},
 "Yume": {"cooldown": 0.30, "swing_time": 0.09, "arc": 110.0, "reach": 0.9, "hits": 2, "hit_gap": 0.10, "damage_ratio": 0.6, "color": (0.98, 0.72, 0.88)},
}
# Skills that replace the default ones of Player.tscn (Kazuma uses the defaults).
SKILL_SCENES = {
 "Yume": {"rmb": "res://scenes/player/skills/LeapingCut.tscn", "shift": "res://scenes/player/skills/yume/PhantomStep.tscn",
          "q": "res://scenes/player/skills/yume/MirrorDream.tscn", "e": "res://scenes/player/skills/yume/DreamClones.tscn"},
}
# id: (name, role, color, weapon, implemented, passive (name, text, effects [(stat, op, value)], behavior script or None, params),
#      cursed_unlocked, skills {slot: name}, description)
C = {
 "Kazuma": ("kazuma", "Ronin duelist", (0.85, 0.15, 0.15), "Katana", True,
            ("Keen Eye", "+8% critical chance.", [("crit_chance", "A", 0.08)], None, {}), False,
            {"lmb": "Katana Slash", "rmb": "Heavy", "shift": "Iaijutsu", "q": "Kaeshi", "e": "Moonlit Storm"},
            "Precise and balanced. Plays on timing: Perfect Dodge, Iaijutsu, counters."),
 "Yume": ("yume", "Blade dancer", (0.97, 0.7, 0.85), "Tessen (war fans)", True,
          ("Butterfly Twist", "Every dash throws 3 shuriken (5 damage each) in a fan opposite to the dash.", [], "ButterflyTwist", {"damage": 5.0, "base_attack": 9.0, "cooldown": 1.0, "spread": 18.0}), False,
          {"lmb": "Twin Cuts", "rmb": "Leaping Cut", "shift": "Phantom Step", "q": "Mirror Dream", "e": "Dream Clones"},
          "Fast and fragile. Hit and run with many small blows."),
 "Takeda": ("takeda", "Resilient general", (0.25, 0.65, 0.3), "Kanabo (iron club)", False,
            ("Heavy Hand", "Your RMB deals +15% damage, reaches 10% farther and knocks enemies back.", [], None, {}), False,
            {"lmb": "Wide Sweep", "rmb": "Earth Crush", "shift": "Shield Charge", "q": "Stone Stance", "e": "The Mountain"},
            "Slow and hard to stop. Heavy blows that crush and push."),
 "Kurotsuki": ("kurotsuki", "Curse of the night", (0.3, 0.1, 0.4), "Steel claws (tekko-kagi)", False,
               ("Born Cursed", "Starts every run with 15% Corruption and the Cursed upgrades unlocked.", [], None, {}), True,
               {"lmb": "Cursed Edge", "rmb": "Blood Cut", "shift": "Shadow Pass", "q": "Absorb", "e": "Awakening"},
               "Risk and reward. Bleed and Corruption, built around Possessed."),
}
OPS = {"A": 0, "P": 1}

wb = openpyxl.load_workbook(XLSX, data_only=True)
ws = wb["Stats"]
header = [c.value for c in ws[1]]
col = {name: header.index(name) for name in C}
base_col = header.index("Bază actuală (joc)")
rows = [r for r in ws.iter_rows(min_row=2, values_only=True) if r[0] and r[col["Kazuma"]] is not None]

def num(v):
    f = float(v)
    return "%d.0" % f if f.is_integer() else repr(f)

def esc(t):
    return t.replace("\\", "\\\\").replace('"', '\\"')

os.makedirs(OUT, exist_ok=True)
for name, (cid, role, color, weapon, implemented, passive, cursed, skills, desc) in C.items():
    stats = {}
    for r in rows:
        value = r[col[name]]
        if isinstance(value, (int, float)) and abs(float(value) - float(r[base_col])) > 1e-9:
            stats[r[0]] = value
    pname, ptext, effects, behavior, params = passive
    model = MODELS[name]
    lines = ['[gd_resource type="Resource" script_class="CharacterData" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/characters/CharacterData.gd" id="1_data"]',
             '[ext_resource type="Script" path="res://scripts/upgrades/UpgradeEffect.gd" id="2_effect"]',
             '[ext_resource type="PackedScene" path="%s" id="3_weapon"]' % model[0]]
    if behavior:
        lines.append('[ext_resource type="Script" path="res://scripts/characters/passives/%s.gd" id="4_passive"]' % behavior)
    scenes = SKILL_SCENES.get(name, {})
    for slot, path in scenes.items():
        lines.append('[ext_resource type="PackedScene" path="%s" id="5_%s"]' % (path, slot))
    lines.append("")
    for i, (stat, op, value) in enumerate(effects, 1):
        lines += ['[sub_resource type="Resource" id="Effect_%d"]' % i, 'script = ExtResource("2_effect")',
                  'stat = "%s"' % stat, "operation = %d" % OPS[op], "value = %s" % num(value), ""]
    lines += ["[resource]", 'script = ExtResource("1_data")', 'id = "%s"' % cid, 'display_name = "%s"' % name,
              'role = "%s"' % esc(role), 'description = "%s"' % esc(desc), "color = Color(%s, %s, %s, 1)" % color,
              'weapon = "%s"' % esc(weapon), 'weapon_scene = ExtResource("3_weapon")',
              "weapon_position = Vector3(%s, %s, %s)" % tuple(num(v) for v in model[1]),
              "weapon_rotation = Vector3(%s, %s, %s)" % tuple(num(v) for v in model[2]), "weapon_scale = %s" % num(model[3])]
    attack = ATTACKS.get(name, {})
    if attack:
        items = []
        for k, v in attack.items():
            items.append('"%s": Color(%s, %s, %s, 1)' % ((k,) + tuple(v)) if isinstance(v, tuple) else '"%s": %s' % (k, num(v) if not isinstance(v, int) else v))
        lines.append("attack = {\n%s\n}" % ",\n".join(items))
    if not implemented:
        lines.append("implemented = false")
    lines.append("stats = {\n%s\n}" % ",\n".join('"%s": %s' % (k, num(v)) for k, v in stats.items()))
    lines += ['passive_name = "%s"' % esc(pname), 'passive_text = "%s"' % esc(ptext),
              "passive_effects = Array[Resource]([%s])" % ", ".join('SubResource("Effect_%d")' % i for i in range(1, len(effects) + 1))]
    if behavior:
        lines.append('passive_behavior = ExtResource("4_passive")')
        lines.append("passive_params = {\n%s\n}" % ",\n".join('"%s": %s' % (k, num(v)) for k, v in params.items()))
    if scenes:
        lines.append("skill_scenes = {\n%s\n}" % ",\n".join('"%s": ExtResource("5_%s")' % (slot, slot) for slot in scenes))
    if cursed:
        lines.append("cursed_unlocked = true")
    lines.append("skill_names = {\n%s\n}" % ",\n".join('"%s": "%s"' % (k, esc(v)) for k, v in skills.items()))
    with open("%s/%s.tres" % (OUT, cid), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(name, stats)
