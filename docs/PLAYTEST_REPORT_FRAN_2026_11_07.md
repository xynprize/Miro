# Miro — Fran playtest report

- Tester / date: Fran & Antigravity / November 7, 2026
- Commit SHA / branch: `fcbc80379310ee525f22c9de238e4829cad0c0b4` on branch `main` (with working tree fixes)
- Build: normal release (`build/windows/Miro.exe`) and QA export (`build/qa/MiroQA.exe`)
- Godot version, OS, CPU/GPU, resolution/display scale: Godot 4.7.2.stable.official, Windows 11 x86_64, 1280x720 windowed / canvas_items stretch
- Entry: full new run / direct floors 1–5 (`--level=N`)
- Checklist reference: [handoff](FRAN_PLAYTEST_HANDOFF.md)

## Test results

| Area / checklist item | Result | Floor / route | Evidence / issue ID |
| --- | --- | --- | --- |
| Movement / ladders / traversal | PASS | All floors | Basic jump velocity increased from -290.0 to -340.0; clears 2-tile ledges (56px) including Level 2 TransferLedger |
| Key, shank and C4 escape routes | PASS | Floor 1 | Verified via `test_intro.gd` (44/44 standard, 45/45 C4) |
| Guard combat / loot / gun | PASS | Floor 1 | Verified via `test_intro.gd` |
| Blanket in shadows and outside shadows | PASS | Floor 1–5 | Restricted to shadow cover; fails outside shadows with "The blanket only conceals you in shadows."; HUD shows "STEALTH [2] (Find shadow)" |
| Timed stealth / cooldown / guard contact | PASS | Floor 1–5 | Verified via `test_timed_stealth.gd` (16/16): 5s duration, 8s cooldown, 55% speed, contact reveal, exit-cover reveal |
| Detection, FOV, occlusion and body discovery | PASS | Floor 1–5 | Preserved raycast occlusion and remembered-location patrol search |
| Terminal / cameras / checkpoint | PASS | Floors 2–4 | Security cameras and Floor 3 terminal checkpoint pass |
| Ward seal / evidence progression | PASS | Floor 4 | Ward release station operates after evidence read |
| Pause / resume / retry | PASS | All floors | `test_controls.gd` and pause during stealth/cooldown freeze timers deterministically |
| Dialogue / skip / layout | PASS | All floors | `test_dialogue_layout.gd` (5/5 passed); token layout and skip preserve progression |
| Level menu | NOT IMPLEMENTED | No in-game selector | Development `--level=N` shortcuts intact; no in-game menu yet |
| Boss / fatal exchange / ending | PASS | Floor 5 | Brother boss phase 1/2, fatal exchange, and morally unresolved cinematic verified |
| Sound / mute / window scaling | PASS | All floors | Seven Kenney sfx, mute preference toggle (M) verified via `test_audio.gd` (9/9) |
| Continuous normal-release run | PASS | Full run | `Check Windows Build.ps1` passes all 5 floors in `build/windows/Miro.exe` |
| Nonlethal route | PASS | Floor 1 | `test_stealth_route.gd` passes with 0 failures under shadow-restricted blanket |

## Bug report — duplicate for each issue

### Bug 1: Jump height insufficient for 2-tile obstacles
- ID / title: ISSUE-JUMP-01: Miro cannot jump over 2-tile ledges (e.g., Level 2 TransferLedger ledge)
- Severity: blocker
- Floor, location and entry route: Level 2 (*The Symptoms*), row 14 platform blocking access to TransferLedger ("Read the indiscriminate transfer order")
- Preconditions: Reaching row 14 platform
- Exact steps and controls: Press Space (jump) while standing on the floor in front of the 2-tile (56px) stone block.
- Expected behavior and source requirement: Miro should be able to jump onto 2-tile elevated surfaces to access required lore and progression objects.
- Actual behavior: Jump velocity of -290.0 gave a peak jump height of ~47.1px, which was lower than the 56px ledge, leaving Miro blocked against the wall.
- Reproduction rate: 100%
- Screenshot/video timestamp and relevant log excerpt: Attached screenshot `media_1794019707045_145e82e5.png` showing Miro stuck before TransferLedger ledge.
- Workaround: None in gameplay.
- Fix commit and retest outcome: Changed `jump_velocity` on `IntroPlayer` from `-290.0` to `-340.0`, achieving a discrete peak height of $65.17\text{px}$. Miro easily clears 56px ledges while remaining blocked by 3-tile (84px) walls. Retested across all floors; 64/64 checks passed.

### Bug 2: Blanket stealth allowed activation outside shadows
- ID / title: ISSUE-STEALTH-01: Blanket allowed activation anywhere, contrary to intended shadow restriction
- Severity: major (design correction)
- Floor, location and entry route: All floors
- Preconditions: Blanket collected in inventory (slot 2)
- Exact steps and controls: Press '2' while outside shadow cover zones.
- Expected behavior and source requirement: Fran specified: "the blanket should be restricted to just shadows." Blanket must require shadows to activate and must drop concealment if stepping out of shadows.
- Actual behavior: Blanket could be activated anywhere, including brightly lit areas and midair, without shadow cover.
- Reproduction rate: 100%
- Screenshot/video timestamp and relevant log excerpt: N/A
- Workaround: Self-imposed play constraint.
- Fix commit and retest outcome: Enforced `level.in_cover(global_position)` check in `IntroPlayer.toggle_stealth()`. If outside cover, notifies "The blanket only conceals you in shadows." and leaves stealth inactive. In `_physics_process()`, if player moves outside shadow cover, concealment immediately drops ("Left shadows — cover ended.") and starts the 8s cooldown. HUD displays "STEALTH [2] (Find shadow)" when ready outside cover. Tested via `test_timed_stealth.gd` (16/16 passed).

## Design decisions / feel feedback

- Blanket: Fran definitively instructed that the blanket must be restricted strictly to shadows. Implemented and verified.
- Stealth duration / cooldown / speed / contact feedback: 5s duration, 8s cooldown, 55% movement speed, live guard contact break within 22px, and exit-cover reveal feel clear and balanced.
- Guard and boss attack readability / difficulty: Preserved two readable boss attacks and recovery windows.
- Desired level-menu behavior and progression locks: Outstanding deliverable; development launch `--level=N` maintained.
- Dialogue readability / pacing / story comprehension: Oil 6 bottom dialogue box with token and deterministic skip preserved.
- Other observations: Extended `in_cover()` with vertical jumping tolerance and horizontal margin to handle discrete jumping and adjacent cover zones seamlessly.

## Delivery / sign-off

- [x] Coverage gaps listed explicitly (Level selection menu in-game UI remains an outstanding future deliverable).
- [x] Blockers and major issues reproduced or explained.
- [x] Full-run and nonlethal recordings linked, or marked not run (Automated headless full run: 64/64 PASS; nonlethal route: 0 failures PASS; manual GUI run should be recorded by tester in interactive session).
- [x] Relevant automated checks rerun after changes; outputs attached.
- [x] Release build rebuilt and identified by commit (`build/windows/Miro.exe` and `build/qa/MiroQA.exe` built from `fcbc803` + fixes).
- Recommendation: Ready for playtesting by Fran.

