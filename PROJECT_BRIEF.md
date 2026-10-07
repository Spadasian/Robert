# KUROTSUKI: ENDLESS NIGHT — Project Brief (handoff for Claude)

> Read this first. It explains what we are building, how we work together, what is already done, and what comes next.
> The human collaborator is NOT a professional programmer and speaks **Romanian**. All explanations to them must be in Romanian. Code, identifiers and code comments stay in English.

---

## 1. The game

- **Title (provisional):** Kurotsuki: Endless Night
- **Genre:** action roguelite, real-time combat, dark fantasy, feudal Japan, single-player.
- **Engine:** Godot **4.7.2 stable** (Windows), GDScript only, no external plugins.
- **Camera / world (decided, differs from the first idea):** the world is **3D** with a **fixed isometric orthographic camera** (Hades style). Gameplay happens on a flat plane (X and Z axes); no jumping, no vertical gameplay. The mouse is the aim target. Art is currently **placeholder primitives** (capsules, boxes); real hand-painted dark Japanese fantasy art comes at the end (Phase 20), probably modeled in Blender.
- **Art direction (later):** hand-painted dark Japanese fantasy, saturated but dark colors (violet, indigo, dark red, green, brown, grey), dramatic lighting, not photorealistic, not generic anime.
- **Run length target:** 20–40 minutes. The first vertical slice will be shorter.
- **Core loop:** Menu → select character → start run → generated map → combat room → reward → next room → elite / event / shop / treasure → mini-boss → next area → boss → victory/death → permanent progression (Soul Shards) → new run.

### Controls (PC)
WASD move · mouse = aim · Left click = basic attack · Right click = skill (Iaijutsu, not built yet) · Space = dash/dodge · Q = ability (free in the slice) · E = ultimate (not built yet) · Esc = pause (not built yet). Interaction key proposed: **F** (for the shop; not yet confirmed by the user). Defined in the Input Map in `project.godot`, never hardcoded keys in scripts (except KEY_R restart and KEY_1/2/3 in the upgrade screen, both temporary/simple).

### Vertical slice scope (the ONLY goal of milestone 1)
Player **Kazuma** (Ronin, katana); enemies Bandit, Heavy Bandit, Archer, Ninja; rooms: 4 Combat, 1 Elite, 1 Treasure, 1 Shop, 1 Boss; boss **Lord Kageyama** (2 phases); 10 upgrades; 3 relics; Soul Shards permanent currency; basic save/load; procedural room selection; basic functional HUD. Must be playable start to finish. Future classes (Yume, Takeda, Kurotsuki) are NOT part of milestone 1.

### Systems still described in the original spec
- **Corruption:** numeric 0–100 with thresholds 25/50/75/100. Higher corruption should give damage/ability bonuses, visual effects, unlock upgrades; serious consequences at 100%. **Only the number exists now; effects are deliberately postponed.** User said: "we'll decide later what corruption does". A proposal was made (damage bonuses per threshold, Cursed upgrades at 75%, "Berserk" at 100%) and is NOT approved yet.
- **Upgrade rarities:** COMMON, RARE, EPIC, LEGENDARY, CURSED (each with icon, name, description, effects, rarity value). Slice uses mostly Common/Rare/Epic.
- **Relics:** passive items, separate from upgrades (examples: Fox Mask, Black Pearl, Oni Horn, Sakura Charm, Kurotsuki Eye). 3 needed in the slice. Not started.
- **Permanent progression:** Soul Shards spent on Max HP, starting gold, healing, unlock characters/upgrades/relics/areas. Save in a separate `SaveManager`; only permanent data is saved (unlocked characters, permanent upgrades, unlocked relics, defeated bosses, Soul Shards, general progress), never run objects.
- **Audio / VFX:** simple placeholders only, late (Phase 20).

---

## 2. How we work (rules from the user — keep following them)

1. **Incremental.** Build → Run → Test → Fix → Continue. Never generate a giant project at once. Fix errors before adding the next system.
2. Follow the phase order below unless there is a strong technical reason not to. Do not jump to polish.
3. **Explain in Romanian, practically.** Say EXACTLY which file is created/modified, where, node types, Inspector values, and give complete scripts when something must be created by hand. Do not assume the user already created a file or node.
4. When possible, edit the project files directly (the repo is the Godot project; the user downloads the branch and opens `project.godot` in Godot) and explain what changed.
5. The user tests in Godot and reports "a mers" / "functionează" or pastes the exact error text from Godot's Output panel. Claude **cannot run Godot** in the cloud session, so all code is written blind and verified only by the user. Be careful with syntax; re-read generated `.tscn` text.
6. Simple, robust, readable GDScript. Small classes, clear names, comments only where useful. No over-engineering, no plugins, no speculative systems.
7. **Priorities:** gameplay > responsiveness > stability > clean architecture > art > VFX > audio > polish.
8. Do **not** open a pull request unless asked. Work on branch `claude/blender-3d-model-sharpen-a6uev1` of `spadasian/robert` (the branch name is historical; the first message was about sharpening a Blender model, then the project became this Godot game). Commit with clear messages and push.

---

## 3. Development phases and status

| Phase | Content | Status |
|---|---|---|
| 1 | Project setup | done |
| 2 | Player movement | done |
| 3 | Camera | done |
| 4 | Basic attack | done |
| 5 | Enemy base class | done |
| 6 | Bandit (navigation, telegraphed melee) | done |
| 7 | Combat / damage / death, dash with i-frames | done |
| 8 | Room system | done |
| 9 | Room transitions | done |
| 10 | Reward system (gold pickup) | done |
| 11 | Upgrade system (data + stats, then choice screen) | done |
| 12 | Procedural run generation | done |
| 13 | Elite enemy | Heavy Bandit + Elite room done (user's last confirmed test was Phase 12; Phase 13 was pushed but the user has only reported the HUD `room_label` parse error, which was fixed — **Phase 13 is not yet confirmed working**) |
| 14 | Shop | next (waiting on the user to confirm key **F** for interaction) |
| 15 | Boss (Lord Kageyama) | todo |
| 16 | Run completion / death screens (replace the placeholder that reloads the scene) | todo |
| 17 | Soul Shards | todo |
| 18 | Save system (`SaveManager`) | todo |
| 19 | UI polish | todo |
| 20 | Art / audio polish | todo |

Still missing from the slice list: Archer and Ninja enemies, Treasure room, Shop room, Boss room, 3 relics, Iaijutsu skill (RMB), ultimate (E), pause menu (Esc), main menu / character select, Soul Shards, save/load.

---

## 4. Architecture

### Scene layout of a run (`scenes/world/Run.tscn`, the main scene)
```
Run (Node3D)
├─ WorldEnvironment, Sun (DirectionalLight3D)
├─ CurrentRoom (Node3D)          ← RoomManager instantiates the current room here
├─ Player (instance of scenes/player/Player.tscn)
├─ CameraRig (instance)
├─ HUD (CanvasLayer instance)
├─ RunManager (Node)             ← run state: gold (later upgrades/relics/map)
├─ RoomManager (Node)            ← builds the run plan, loads rooms, transitions, spawns rewards
├─ UpgradeChoice (CanvasLayer)   ← 3-card pause screen
└─ UpgradeManager (Node)         ← picks/applies upgrades; upgrade_pool is set in the Inspector
```
Managers are normal nodes in the Run scene (not autoloads) so they reset with the run. Planned autoloads only for truly global things later: `GameManager` (scene switching) and `SaveManager`.

### Player (`scenes/player/Player.tscn`, CharacterBody3D, group `player`)
Small components instead of one giant script:
`AimComponent` (mouse → ground plane → aim direction) · `AttackComponent` on `WeaponPivot` (slash with Hitbox) · `DashComponent` (charges, cooldown, i-frames) · `HealthComponent` · `StatsComponent` (all upgradeable numbers) · `CorruptionComponent` · `Hurtbox`. `Player.gd` only handles movement, facing, taking damage, death.

### Data-driven content (Godot Resources, `class_name`)
- `RoomData` (id, name, room_type enum COMBAT/ELITE/TREASURE/SHOP/EVENT/SHRINE/BOSS, scene, difficulty, reward_gold) → `resources/rooms/*.tres`
- `UpgradeData` (id, name, description, icon, rarity enum, effects) + `UpgradeEffect` (stat, operation ADD|PERCENT, value) → `resources/upgrades/*.tres`. **New upgrade = new `.tres` + add it to `UpgradeManager.upgrade_pool` in Run.tscn; no code change.** Special effects (execute damage, corruption on hit, life on kill) are stats read by `CombatManager`.
- Not yet created: `EnemyData`, `CharacterData`, `RelicData`, `BossData` (enemy stats currently live as exported variables on each enemy scene root).

### Stats
`final = (base + sum(ADD)) * (1 + sum(PERCENT))`. Base stats are in `StatsComponent.base_stats`: max_health 100, attack_damage 10, attack_speed 1, move_speed 6, dodge_charges 1, damage_taken 1 (multiplier), crit_chance 0, execute_bonus 0, corruption_on_hit 0, life_on_kill 0. Components call `stats.get_stat("name")`.

### Combat
`Hitbox` (Area3D) → on touching a `Hurtbox` of another team calls `CombatManager.calculate_damage()` (crit, execute bonus) → `hurtbox.receive_hit(damage, source)` → owner's script reacts (enemy `Enemy._on_hit_received`, player `_on_hit_received` applies `damage_taken` and dash invulnerability) → `CombatManager.after_hit()` (corruption on hit, life on kill). `CombatManager` is a static helper class (`RefCounted`), not a node.

### Enemies
`Enemy.gd` (base: health, hit flash, damage numbers, `defeated` signal, death shrink) → `Bandit.gd` extends it by path (CHASE → WINDUP (telegraph red zone) → ATTACK → RECOVER state machine, `NavigationAgent3D` pathing around obstacles). **Heavy Bandit = same script with different exported values** (HP 120, speed 2.2, damage 20, windup 0.8). `TrainingDummy.tscn` is a test dummy (not in rooms).

### Rooms
Every room scene has root script `Room.gd` and required nodes: `Level` (NavigationRegion3D with `NavBaker.gd`, containing floor/walls/props as StaticBody3D so the navmesh bakes at runtime), `PlayerSpawn` (Marker3D), `EnemySpawns` (Marker3D children with `EnemySpawnPoint.gd`, pick `enemy_scene` in Inspector), `Enemies`, `RewardSpawn` (Marker3D), `Exit` (Area3D + `DoorVisual`). Door is red/closed until all enemies die, then cyan/open; entering it emits `exit_reached`. Room scenes were generated with a Python helper (not in the repo); new rooms can also be duplicated and edited in the Godot editor.

### Procedural generation
`RunGenerator.generate(pool, layout, rng)` → ordered list of `RoomData`. Layout = room-type numbers (`RoomManager.layout`, currently `0,0,0,1,3,0,6` = Combat, Combat, Combat, Elite, Shop, Combat, Boss). Types with no rooms in the pool are skipped (so Shop/Boss slots are ignored until those rooms exist). Shuffle-bag per type, no immediate repeats, difficulty target rises 1→3, weight `1/(1+|difficulty−target|)`. `RoomManager.run_seed` (0 = random) is printed to Output as `Run seed:` for reproducible runs. After the last room the scene reloads (placeholder for Phase 16).

### Flow details
- Room cleared → gold pickup appears at `RewardSpawn`; uncollected pickups (group `pickup`, method `collect()`) are auto-collected when the player enters the exit (user requirement; any future item must also join group `pickup` and implement `collect()`).
- 0.6 s after clear → `UpgradeChoice` pauses the game with 3 non-duplicate upgrades chosen by rarity weight (click or keys 1/2/3).
- Door → fade out (HUD `Fade`), load next room, camera snaps (`CameraRig.snap_to_target`), fade in.
- Player death → "YOU DIED, press R" → reload scene.

---

## 5. Conventions and gotchas (important when editing files by hand)

- **Collision layers (3D):** 1 world · 2 player · 3 enemy (value 4) · 4 player_hitbox (8) · 5 enemy_hitbox (16) · 6 hurtbox (32). Player body mask = 5 (world + enemies), becomes 1 while dashing (passes through enemies). Enemy bodies mask 7. Hitbox mask 32, hurtbox layer 32, team strings `"player"` / `"enemy"` prevent friendly fire.
- **Groups:** `player`, `enemy`, `hud`, `room_manager`, `run_manager`, `camera_rig`, `pickup`.
- **`.tscn` groups must be in the node header:** `[node name="Player" type="CharacterBody3D" groups=["player"]]`. A separate `groups = [...]` property line is silently ignored (this caused a bug once).
- **Camera:** `CameraRig` follows the player; the Camera3D is orthographic, size 14, yaw 45°, pitch ≈ −35°. `Player.CAMERA_YAW_DEGREES = 45` must match, so W moves "up" on screen.
- Aiming uses a ray from the camera to a horizontal plane at weapon height (0.9).
- Typed exports of arrays in `.tscn` use `Array[Resource]([...])`, int arrays `PackedInt32Array(...)`.
- `class_name` is used for `RoomData`, `UpgradeData`, `UpgradeEffect`, `CombatManager`, `RunGenerator`; the editor registers them when the project is opened.
- Node refs use `@onready` and `$Path`; `Enemy` subclasses call `super._ready()`.
- Everything is placeholder art: Player = blue capsule with a yellow "nose" showing facing; Bandit = brown capsule; Heavy Bandit = bigger dark capsule; red translucent quad = attack telegraph.
- HUD is a minimal functional placeholder (HP bar, Gold, Corruption number, Room x/y, center messages, death text, fade).

---

## 6. File map

```
project.godot                      main scene = res://scenes/world/Run.tscn, Input Map, layer names
scenes/world/    Run.tscn, CameraRig.tscn, GoldPickup.tscn
scenes/player/   Player.tscn
scenes/enemies/  Bandit.tscn, HeavyBandit.tscn, TrainingDummy.tscn
scenes/rooms/    Room_Combat_01..04.tscn, Room_Elite_01.tscn
scenes/ui/       HUD.tscn, UpgradeChoice.tscn, DamageNumber.tscn
scripts/player/  Player, AimComponent, AttackComponent, DashComponent, StatsComponent, CorruptionComponent, CameraRig
scripts/combat/  Hitbox, Hurtbox, HealthComponent, CombatManager
scripts/enemies/ Enemy (base), Bandit
scripts/rooms/   Room, RoomManager, RoomData, EnemySpawnPoint, NavBaker, Pickup
scripts/procedural/ RunGenerator
scripts/managers/   RunManager
scripts/upgrades/   UpgradeData, UpgradeEffect, UpgradeManager
scripts/ui/      HUD, UpgradeChoice, DamageNumber
resources/rooms/    Room_*.tres (RoomData)
resources/upgrades/ 10 upgrades: blood_edge, shadow_step, iron_skin, sakura_step, executioner,
                    dark_breath, swift_blade, vital_spirit, keen_edge, crimson_meal
```
Empty (reserved) folders exist for the rest of the planned structure (`scripts/bosses`, `scripts/save`, `resources/characters|enemies|relics`, `art/`, `audio/`, `shaders/`, ...).

**Upgrades:** Blood Edge (+20% damage, Common) · Shadow Step (+1 dodge charge, Epic) · Iron Skin (−15% damage taken, Common) · Sakura Step (+15% move speed, Common) · Executioner (+50% damage vs enemies below 30% HP, Rare) · Dark Breath (each hit adds 3 Corruption to the player, Epic) · Swift Blade (+20% attack speed, Common) · Vital Spirit (+25 max HP, Common) · Keen Edge (+10% crit, Rare) · Crimson Meal (heal 3 HP on kill, Rare).

---

## 7. Open decisions / next steps

1. **Confirm Phase 13** (Heavy Bandit + Elite room) works; the user must report.
2. **Phase 14 – Shop:** room type SHOP, no enemies, 3 upgrades for sale for gold (uses `RunManager.spend_gold` and `UpgradeManager.get_random_choices`), interact with **F** (proposed, awaiting confirmation). Room exit is open immediately (a room with no enemies counts as cleared).
3. Missing enemies: **Archer** (ranged projectile), **Ninja** (fast, short dash/teleport) — need new scripts extending `Enemy`.
4. **Phase 15 – Boss Lord Kageyama:** phase 1 melee combo + dash; phase 2 more aggressive with special attacks. Boss room type 6 closes the run.
5. **Treasure room** (type 2) and **3 relics** (`RelicData`, passive effects through `StatsComponent` modifiers).
6. **Corruption effects** — decide later with the user (see §1).
7. Skills still unbuilt: Iaijutsu (RMB), ultimate (E), pause (Esc), main menu/character select.
8. Known simplifications to revisit: Bandit has no stagger; enemy stats are exported variables instead of `EnemyData`; run end just reloads the scene; HUD/art/audio are placeholders; no cooldown UI for dash; all rooms use the same layout size (22×22) with exit on the east wall.
9. User was asked, and has not yet answered: key **F** for interaction.

---

## 8. UPDATE 2026-10-07 — merged with the user's local version (read this first, it overrides sections 3 and 6 where they differ)

The user uploaded a much more advanced local version of the game (made in another Claude session). It was merged into this branch; **the user's files won over the older versions in this brief**. The merge was checked only statically (every `res://` path in scenes, scripts, resources and `project.godot` exists); **nobody has run it from this repository yet**.

What the repo now contains (from file names; not all verified in the editor):
- **Flow:** main scene is `scenes/ui/MainMenu.tscn`; `scenes/world/Run.tscn` and `Main.tscn`; `EndScreen`, `PauseMenu`, `VolumeSliders`, `SoulShrine` in `scenes/ui` + `scripts/ui`.
- **Autoloads** (in `project.godot`): `MetaProgression`, `AudioManager`, `VFX`, `SaveManager`, `GameManager` (all in `scripts/managers`).
- **Enemies:** Bandit, Heavy Bandit, **Archer** (+ `Arrow`), **Ninja** (+ `Shuriken`), **Boss** (`scenes/enemies/Boss.tscn`, `scripts/enemies/Boss.gd`, room `Room_Boss_01`), TrainingDummy.
- **Player skills** (`scripts/player/skills`, `scenes/player/skills`): `PlayerSkill` base, `IaijutsuSkill`, `KaeshiSkill`, `UltimateSkill`; `CorruptionVfx` for Corruption visuals.
- **Relics:** `RelicData` + `resources/relics` (Fox Mask, Black Pearl, Oni Horn), `RelicPedestal`.
- **Meta progression:** `MetaProgression`, `MetaUpgradeData`, `resources/meta` (hungry_blade, pouch, vitality), `SaveManager`.
- **Rooms:** `ShopRoom` + `ShopStand`, `TreasureRoom`, Boss room; the older Shop/Treasure implementation (Interactable, ShopPedestal, TreasureChest) was deleted as a duplicate.
- **Audio:** `audio/sfx`, `audio/music`, `audio/ambience`; `tools/audio/generate_audio.py` generates them.
- Input Map: also `interact` = F, `pause` = Esc, `skill`, `ability`, `ultimate`.
- **Repo layout fix:** the user's scripts were uploaded to the repo root by mistake; they were moved into `scripts/`. The user's local project has the correct layout (`res://scripts/...`), so do not upload script folders to the root again.

## 9. The 3D character model (Blender) — status

Reference: the user's 2D concept sheet (`concept_sheet`, "Kazuma Ronin T-pose turnaround") is the visual target. Workflow so far is documented by the scripts in `art/blender_tools/` (run in Blender 5.2.2 Scripting tab; keep each script under ~120 lines, longer pastes get truncated):
- Blender file: `Kazuma V3.blend` (in the user's Downloads). Objects: `Kazuma_high` (sculpt, double-shelled skin, `kazuma_color` attribute, no UVs — baking colors from it FAILS, do not retry), `Kazuma_low`, `Kazuma_game` (repaired low-poly, ~45k verts, holes filled, original UV layout kept), `Meshy_textured` (Meshy model with painted texture; white pauldrons/orange scarf/different face, katana still attached, so not used).
- Material `Kazuma_game_mat_old` uses the OLD good texture; `04a_rebake_face.py` re-projects the face from the sheet panel FACE DETAIL (mapping: `u = 0.54232*x + 0.08431`, `v = 0.77637*z - 0.92188` on object coordinates, image `concept_sheet`) into a new image `Kazuma_color_v4`. Its result was never verified (the preview script stopped writing new images on the user's machine).
- Remaining: verify `Kazuma_color_v4`; body details from the sheet (back, belts, patterns); rig (bones for scarf, sleeves, skirt, ponytail); export `.glb` to Godot to replace the blue capsule.
- Claude cloud sessions cannot reach Blender. The user has a Blender MCP connector in a local session; that is the better place to finish the model.
