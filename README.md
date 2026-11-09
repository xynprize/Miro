# Miro

Current combat work: [meeting 3 notes](docs/miromeeting3.md) · [ordered weapon tasks and gap assessment](docs/WEAPON_UPGRADE_TASKS.md).
Miro's Tower Escape: Last One Standing

Canonical repository: [xynprize/Miro.](https://github.com/xynprize/Miro.) (the name includes the final period). Julia's latest sprites are mapped in the [asset integration guide](docs/JULIA_ASSET_INTEGRATION.md).

[Library visual polish](docs/LIBRARY_VISUAL_POLISH.md): scenery, interface sprites and effects added while preserving Julia's original assets.

**Playable audio/stealth review:** [feature spec and build instructions](docs/AUDIO_AND_STEALTH_REVIEW.md). Start at the review menu; F10 returns to it. Music, voiced guard conversations, root login, suppressor cases and hiding recesses are implemented for review.

**Current focus:** [music mechanics handoff and ordered tasks](docs/MUSIC_MECHANICS_HANDOFF.md) — portable player pickup, stealth/offense points, beat unlocks and soundtrack branches (planned).

[Agreed soundtrack placement and section plan](docs/MUSIC_TRACKLIST.md) · [tempo/key analysis data](data/music/beat_analysis.json). Levels may use multiple tracks.

Soundtrack planning: [proposed music spec](docs/MUSIC_SPEC.md). Candidate beats are in `soundselection/beats` (Git LFS); run `git lfs pull` after cloning. Section playback is implemented; scoring/unlocks and the outro composition remain unfinished.

**Fran's playtesting:** [handoff and checklist](docs/FRAN_PLAYTEST_HANDOFF.md) · [report template](docs/PLAYTEST_REPORT_TEMPLATE.md) · [coding-agent prompt](docs/FRAN_AGENT_PROMPT.md).

Godot 4.7 / Forward+. Main scene: `scenes/main_menu.tscn`; gameplay intro: `scenes/intro.tscn`.

The playable first floor includes the cell opening, three escape choices, guard sight and searches, blanket stealth, combat, ladders, a sigil objective, and an intro completion screen.

See [intro guide](docs/INTRO.md) for controls, editing and verification. Use `Open Miro.ps1`, `Play Miro.ps1`, or the desktop shortcuts. Run `Run Checks.ps1` for the automated playthroughs.

The original movement sandbox remains in `scenes/asset_sandbox.tscn`.

All five floors now have editable scene scaffolds. See [Level 1 sources and authoring](docs/LEVEL_01_SCAFFOLD.md) and [Levels 2–5 sources and unfinished systems](docs/LEVELS_02_05.md). Launch a specific floor with `./Play Level.ps1 -Level 2`. Later floors contain draft dialogue and explicit mechanic/cinematic placeholders.

Playable milestone: linked five-floor progression, Level 3 sweeping cameras and one-second hacking, Level 5 two-attack boss and a skippable in-engine ending. Art remains provisional; see the per-floor guide for remaining work.

Latest controls: **1–5 select items, Q selects blanket, left click uses, N opens inventory, R reloads, C dashes, Ctrl crouches, Space twice double-jumps**. See [final controls and remote](docs/CONTROLS_REMOTE_HANDOFF.md). Blanket use requires shadows, with 5-second stealth and an 8-second cooldown; leaving cover or guard contact reveals Miro. The two jumps together reach approximately 65.17 pixels. See the [traversal handoff](docs/TRAVERSAL_FRAN_HANDOFF.md) for trapdoors and Fran’s playtest fixes. Dialogue uses a simpler bottom text/speaker panel. See [current decisions](docs/GAMEPLAY_DECISIONS.md). Build with `Build Windows.ps1`, then validate standalone startup using `Check Windows Build.ps1`.

Press **M** to toggle sound effects. `Check Exported Playthrough.ps1` verifies a continuous five-floor run in a separate QA export (64 checks), including the boss and watched ending.
