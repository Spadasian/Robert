# Roadmap KUROTSUKI: ENDLESS NIGHT

Actualizat la finalul sesiunii în care s-au făcut F1–F5, Perfect Dodge, economia și Yume.

## Livrat (și testat headless)
- **F1** fundații + 70+ upgrade-uri (stat-uri noi, bleed/stun/slow/mark, scut, level up, reroll)
- **F2** 29 relicve (Treasure + Shop rar), inclusiv Cursed Mirror
- **F3** 38 tehnici Kata, sloturi extra (Dual Flow, Double Opening), Finisher-e cu efecte reale
- **F4** 10 prevestiri de Arenă (ceață volumetrică Forward+, săgeți, eclipsă etc.), Ultimate doar din kill-uri
- **F5** Corruption → Possessed, upgrade-uri Cursed
- Perfect Dodge reglat (near-miss, slow 0,7 s, feedback vizual), economie −40%, Warm Tea o dată pe biom
- Upgrade-uri de critic (Falcon Eye, Backstab Instinct, Perfect Aim, Crit Momentum)
- **C1** sistem de personaje: `CharacterData`, Character Select după mod, Kazuma (110 HP, 11 dmg, Keen Eye), RMB +4,
  Iaijutsu 1,0×, lifesteal, `attack_range`, `starting_corruption`
- **C2 Yume**: tessen, Butterfly Twist, Twin Cuts, Leaping Cut, Phantom Step, Mirror Dream, Dream Clones,
  upgrade-urile ei (Dream Echo, Quick Hands, Silk Step); modelele armelor (4 GLB în `art/weapons/`)

## Urmează (în ordine)
1. **Takeda** (C3): kanabō, Heavy Hand, Wide Sweep, Earth Crush, Shield Charge (amețește la perete, cooldown 8 s),
   Stone Stance (5 s, −60% damage primit, mișcare −30%, cooldown 14 s), The Mountain (unde de șoc în jurul lui 5 s),
   upgrade-urile lui (Quake Heavy, War Drum).
2. **Kurotsuki** (C4): gheare, Born Cursed, Cursed Edge, Blood Cut, Shadow Pass, Absorb, Awakening (Possessed ×1,25, 18 s,
   cere ≥ 50% Corruption), upgrade-urile lui (Blood Tithe, Dark Pact, Night Hunger).
3. **Echilibrare** după testele utilizatorului (dificultatea primului biom, Duel/Arenă, prețuri, cifrele Perfect Dodge,
   Corruption/Possessed, damage-ul nou RMB +4, Twin Cuts, Phantom Step).
4. Conținut nefăcut: inamici și boss-i noi, camere Event/Shrine, Soul Shards (meta-progresie), upgrade-uri de stil pentru
   Kazuma (Duelist's Poise, Perfect Form), modelele 3D ale personajelor (Blender, sesiunea locală), animații (păr/haine în Possessed).
5. Curățenie: `PROJECT_BRIEF.md` e istoric; coloană „Implementat" în Excel-uri.

## Întrebări deschise
- Pasiva lui Kazuma: Keen Eye (confirmat). Shuriken-urile lui Yume scalează cu damage-ul ei (confirmat).
- Kaeshi rămâne neschimbat (contra 2× damage), nota cu „40% din atacul parat" nu se aplică.

## Surse de design
`design/KUROTSUKI_Liste.xlsx` (upgrade-uri, relicve, Kata, prevestiri, Corruption) și `design/KUROTSUKI_Personaje.xlsx`
(stat-uri, pasive, abilități; foaia Decizii-finale). Deciziile utilizatorului sunt în coloanele galbene.
