# KUROTSUKI: ENDLESS NIGHT — instrucțiuni pentru Claude

Joc de acțiune roguelite 3D izometric, **Godot 4.7.2**, GDScript, fără plugin-uri, renderer **Forward+**.
Citește și `design/ROADMAP.md` (ce e făcut / ce urmează) și `tests/README.md` (cum rulezi testele).
`PROJECT_BRIEF.md` este istoric (parțial depășit).

## Cum lucrăm cu utilizatorul (reguli fixe)
- Utilizatorul **nu este programator** și vorbește **română**. Explicațiile către el sunt în română, simple, practice;
  codul, numele, comentariile și textele din joc sunt în **engleză**. Spune exact ce fișiere s-au schimbat.
- Lucrează incremental: **BUILD → RUN → TEST → FIX**. După fiecare fază, utilizatorul testează înainte de următoarea.
- Prioritate: gameplay > responsivitate > stabilitate > arhitectură > artă. Sisteme simple, fără supra-inginerie.
- Pune întrebări înainte să construiești liste/funcții mari, când ți se cere ("pune întrebări înainte"). Folosește
  Excel-urile din `design/` ca sursă de decizie (coloanele galbene = deciziile lui).
- **Nu crea Pull Request** decât la cerere. Dezvoltă pe branch-ul `claude/blender-3d-model-sharpen-a6uev1` din
  `Spadasian/Robert` (numele e istoric), commit cu mesaje clare, push la sfârșit.
- Nu pune identificatori de model în repo (commit-uri, cod, comentarii).
- Modelul 3D al lui Kazuma și celelalte modele se fac separat, în Blender (sesiunea locală a utilizatorului).

## Identitatea jocului (decizii luate)
- **Kata**: lanț Opening → Flow → Finisher (+ un slot Master rar). Nu există la început; prima tehnică o trezește.
  Fiecare verigă goală nu face nimic. Tehnici doar din Mini-boss, Boss (non-final), Duel, Arenă și rar Shop (scump).
  Ordinea ofertelor: 1 = 3 Opening, 2 = 3 Flow, 3 = 3 Finisher, apoi mixt. Master doar după ce lanțul e complet.
  Dual Flow / Double Opening dau un al doilea slot. Opening-urile legate de skill-uri se declanșează când skill-ul
  **se întâmplă** (tăietura, contra), nu la apăsarea tastei (`skill_resolved`), și se leagă de **slot** (Shift / Q).
- Fără timere de presiune, fără HP-pentru-aur. Economie: recompense de aur mai mici (−40%), Arena plătește după dificultate.
- **Ultimate (E)** se încarcă doar din kill-uri (`ultimate_hit_charge` poate fi crescut de un upgrade).
- **Perfect Dodge**: dash în ultimele ~0,13 s înainte de lovitura inamicului (sau lovitură care ajunge în 0,12 s din dash);
  inamicii încetinesc 0,7 s la 20% viteză; efecte pe ecran (tentă, culori, strălucire). Constantele sunt în `Player.gd`.
- **Corruption / Possessed**: crește cu 1,5 la kill; praguri 25/50/75% (+5/+20/+30% damage; 50% deblochează Cursed;
  75% margine mov); la 100% Possessed 15 s (rage), apoi cooldown 20 s. Constantele sunt în `CorruptionComponent.gd`.
- **Damage**: RMB = damage de bază + 4 plat; Iaijutsu = 1,0×; vindecările „la kill" sunt **lifesteal** (stat `lifesteal`).
- **Personaje** (toate deblocate, aleg după modul de joc în Character Select): Kazuma (roșu, katana, Keen Eye +8% critic),
  Yume (sakura, tessen, Butterfly Twist) — implementate; **Takeda** (verde, kanabō) și **Kurotsuki** (mov închis, gheare)
  urmează, conform `design/KUROTSUKI_Personaje.xlsx` (foaia **Decizii-finale**). Același sistem Kata la toți.

## Arhitectura pe scurt
- Autoload: `MetaProgression`, `AudioManager`, `VFX`, `SaveManager`, `GameManager` (mod, personaj ales, schimbat scene).
- Straturi de coliziune 3D: 1 world, 2 player, 3 enemy (4), 4 player_hitbox (8), 5 enemy_hitbox (16), 6 hurtbox (32).
- Grupuri: `player`, `enemy`, `hud`, `room_manager`, `run_manager`, `camera_rig`, `pickup`, `upgrade_manager`,
  `technique_manager`, `omen_choice`, `projectile`, `decoy`, `arrow_strike`.
- Statistici: `StatsComponent` (`final = (base + plat) × (1 + procente)`). Orice upgrade/relicvă/pasivă schimbă stat-uri
  prin `UpgradeEffect` sau are un `RuleBehavior` (`scripts/rules/`, hook-uri on_*; întrebări: damage_multiplier etc.).
- Kata: `KataComponent` + `KataEvents` + `TechniqueManager`; tehnicile sunt `TechniqueData` (`.tres`) + script
  `TechniqueBehavior` (`scripts/player/kata/techniques/`).
- Skill-uri: `PlayerSkill` (sloturi rmb / shift / q / e după `input_action`); LMB = `AttackComponent`; fiecare
  personaj poate înlocui skill-urile prin `CharacterData.skill_scenes` și atacul de bază prin `CharacterData.attack`.
- Camere: `Room.gd`, `RoomManager`, `DuelRoom`, `ArenaRoom` (+ `ArenaOmens.gd`, 10 prevestiri), `ShopRoom`, `TreasureRoom`.
- Inamicii: `Enemy` (stări în `EnemyStatus`: bleed, stun, slow, mark; timp global în `EnemyTime`), `Bandit`, `Archer`,
  `Ninja`, `Boss`, `MiniBoss`.

## Conținut generat din tabele (nu edita `.tres` de mână)
Rulează din rădăcina proiectului:
- `python3 tools/content/generate_upgrades.py` → `resources/upgrades/*.tres` + `_pool.tres`
- `python3 tools/content/generate_relics.py` → `resources/relics/`
- `python3 tools/content/generate_techniques.py` → `resources/techniques/`
- `python3 tools/content/generate_characters.py` → `resources/characters/` (citește `design/KUROTSUKI_Personaje.xlsx`, cere `openpyxl`)

## Capcane învățate
- După ce adaugi un `class_name` sau scripturi noi: `godot --headless --path . --import` (altfel „Identifier not found").
- Un `class_name` care folosește un autoload (de ex. `VFX`) poate da eroare de compilare: folosește `preload` în loc de `class_name`.
- În `.tscn`, grupurile se pun în antetul nodului (`groups=["player"]`); o linie `groups = [...]` separată se ignoră.
- Array-uri tipate în `.tscn`: `Array[Resource]([...])`; `Array[Resource]` nu primește un `Array` simplu din cod.
- În scripturi `--script` autoload-urile nu sunt identificatori: `root.get_node("GameManager")`.
- Jolt: zonele (`Area3D`) nu văd corpuri statice decât dacă setarea proiectului e activată; lovitura proiectilelor
  verifică pereții cu un ray.
- Testele headless: nu reutiliza obiecte eliberate; plasează manechinele departe de jucător; un jucător care moare strică testul.
- Nu crea fișiere `.xlsx` de recalculat cu LibreOffice în sandbox (nu merge); scrie valorile direct cu `openpyxl`.

## Cum verifici munca
Rulează suita din `tests/` (vezi `tests/README.md`) — toate trebuie să dea `ALL PASSED`; apoi un run `quick` și unul
`standard`. Rezultatele vizuale (efecte, lumini, modele) le judecă utilizatorul când joacă.
