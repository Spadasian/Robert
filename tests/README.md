# Teste headless (Godot 4.7.2)

Fiecare fișier `*_test.gd` pornește jocul fără fereastră, simulează situații și scrie `ok` / `FAIL`, apoi
`RESULT: ALL PASSED` sau `N FAILED`. Nu sunt teste Godot "oficiale": sunt scripturi `SceneTree`.

## Cum se rulează (din folderul proiectului)

```
godot --headless --path . --import                 # o dată, și după ce adaugi clase/scripturi noi (class_name)
godot --headless --path . --script tests/kata_test.gd
godot --headless --path . --script tests/run_test.gd -- quick      # un run întreg (Quick), lent
godot --headless --path . --script tests/run_test.gd -- standard   # un run întreg (Standard), foarte lent
```

Pe Windows `godot` este executabilul Godot 4.7.2 (de ex. `Godot_v4.7.2-stable_win64_console.exe`). Pentru un rezultat
scurt: `... 2>&1 | grep "FAIL\|RESULT\|SCRIPT"`.

## Ce acoperă fiecare

| Test | Ce verifică |
|---|---|
| `kata_test` | lanțul Kata (Opening → Flow → Finisher), Perfect Dodge, lovitură din spate |
| `technique_test` | pool-ul de tehnici, ordinea ofertelor, Shop, efectele tehnicilor de bază |
| `heavy_test` | RMB (Heavy) = damage + 4, Iaijutsu |
| `xp_test` | EXP, level up, alegerea upgrade-urilor |
| `f1_test` | stat-urile noi și upgrade-urile (comportamente, bleed, scut, Warm Tea, upgrade-uri de critic) |
| `f2_test` | relicvele (Shop, Treasure, efecte) |
| `f3_test` | cele 38 de tehnici Kata, sloturile extra, Finisher-ele pe manechine, skill-urile pe sloturi |
| `f4_test` | prevestirile Arenei (ceață, săgeți, lumină), Ultimate doar din kill-uri, bani din Arenă |
| `f5_test` | Corruption, Possessed, upgrade-urile Cursed, Cursed Mirror |
| `c1_test` | personaje (CharacterData, Character Select, Kazuma), lifesteal, attack_range, Kata pe sloturi |
| `yume_test` | Yume: Twin Cuts, Butterfly Twist, Leaping Cut, Phantom Step, Mirror Dream, Dream Clones, upgrade-urile ei |
| `perfect_test` | Perfect Dodge (fereastra, anti-dublare, tentă pe ecran, strălucirea inamicilor) |
| `miniboss_test`, `special_rooms_test` | mini-boss cu variante, Duel, Arenă, uși speciale |
| `run_test` | un run complet (`quick` sau `standard`) |

## Note
- `miniboss_test` scrie uneori "SCRIPT ERROR ... get_first_node_in_group" la oprire, dar raportează `ALL PASSED`
  (zgomot la închidere).
- Unele teste durează 1-2 minute; au un watchdog care se oprește singur.
- Testele care aleg upgrade-uri singure sunt influențate de hazard (un scut sau o evaziune pot schimba cifrele).
  Dacă un test cade rar, rulează-l din nou și verifică dacă hazardul e cauza.
- Un test nou: copiază structura unui test existent (`extends SceneTree`, `_initialize` pornește `Run.tscn`).
- `tools/inspect_glb.gd` arată structura unui model `.glb` (noduri, dimensiuni).
