# Mesaj de pornire pentru o sesiune nouă (Chat / Cowork)

Copiază textul de mai jos ca **primul mesaj** într-o conversație nouă. Dacă folosești Cowork, alege mai întâi folderul
proiectului Godot (cel clonat din `https://github.com/Spadasian/Robert`, branch `claude/blender-3d-model-sharpen-a6uev1`).

---

Lucrăm la jocul **KUROTSUKI: ENDLESS NIGHT** (Godot 4.7.2, GDScript, 3D izometric, roguelite de acțiune). Eu nu sunt
programator și vorbesc română: explică-mi în română, simplu, și spune-mi exact ce fișiere se schimbă. Codul, numele
și textele din joc sunt în engleză. Lucrăm pas cu pas (construiești → testez → repari), prioritate: gameplay >
responsivitate > stabilitate > artă. Nu crea Pull Request-uri decât dacă îți cer.

Înainte de orice, citește din folderul proiectului, în ordinea asta:
1. `CLAUDE.md` (regulile, arhitectura, deciziile jocului, capcane)
2. `design/ROADMAP.md` (ce e făcut și ce urmează)
3. `design/KUROTSUKI_Personaje.xlsx`, foaia **Decizii-finale** (personajele)
4. `tests/README.md` (cum se rulează testele)

Stadiul: sunt gata sistemele F1–F5 (upgrade-uri, relicve, Kata, Arena, Corruption/Possessed), sistemul de personaje
(Character Select) și personajele **Kazuma** și **Yume**. Urmează **Takeda**, apoi **Kurotsuki**, apoi echilibrare.

Dacă nu poți rula Godot (testele headless), scrie codul atent, spune-mi ce să testez eu în Godot și ce rezultat
așteptăm, iar eu îți dau înapoi textul erorilor din panoul Output. Când terminăm o etapă, spune-mi ce fișiere s-au
schimbat ca să le salvez în Git.

Începem cu: **Takeda** (arma kanabō, pasiva Heavy Hand, abilitățile alese în foaia Decizii-finale).

---

## Dacă lucrezi fără acces la Git/Godot în Chat
- Claude nu poate face `git push` din Chat/Cowork și nu poate rula Godot decât dacă ai instalat unelte local. După fiecare
  etapă, salvează schimbările în Git cu GitHub Desktop (sau `git add . && git commit && git push`).
- Testele se rulează pe PC: `godot --headless --path . --import`, apoi `godot --headless --path . --script tests/<test>.gd`.
