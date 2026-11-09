# Current gameplay decisions

**Superseded controls/attachments:** see [Final controls and remote](CONTROLS_REMOTE_HANDOFF.md). Q is blanket, 1–5 select rearrangeable items, R reloads, slot 5 starts as remote. SMGs support three-shot suppressors. Earlier controls below describe the previous increment.

## Audio and stealth review — November 6, 2026

See [the implemented review spec](AUDIO_AND_STEALTH_REVIEW.md) for soundtrack sections, restrained leveling/ducking, ElevenLabs guard exchanges, case-sensitive root login with fallback, three-shot suppressor cases, enclosed hiding props and the new start/review menu. These additions preserve the existing timed blanket and platform geometry. Musical scoring/unlocks, portable-player acquisition and a final outro track remain open. Current main scene is the menu; F10 returns to it. Earlier menu/audio status below is historical.

## Playtest handoff clarification — November 6, 2026

Ethan reaffirmed that the blanket is the stealth tool for hiding in shadows when requesting [Fran's handoff](FRAN_PLAYTEST_HANDOFF.md). The build still supports the earlier requested timed activation anywhere. Whether shadows should become mandatory again was not explicitly specified; Fran should record this design question rather than assume the code already restricts activation. No gameplay rule was changed as part of the documentation handoff. An in-game level menu is also an outstanding deliverable; developer floor-launch shortcuts are not that menu.

## Latest user direction: mobile timed stealth and simpler dialogue

The user's dialogue reference establishes the broad layout only: a bottom text box with speaker identification. The implementation uses a plain Oil 6 panel, text/continue/skip controls on the left and a small speaker token/name on the right. Julia's existing Miro sprite supplies his token; other tokens remain code-native placeholders. Final portrait art is not required to use the UI.

The user's latest stealth request supersedes the original class guide's stationary shadow requirement. Press **2** after collecting supplies to activate stealth anywhere, including while moving or airborne. Current tunable defaults on `IntroPlayer`:

- Duration: **5 seconds**.
- Cooldown: **8 seconds**, starting when stealth ends.
- Walking and ladder speed: **55%** of normal.
- Walking, jumping and climbing preserve stealth.
- Contact with a living guard breaks stealth and immediately alerts that guard. A corpse does not break it.
- Attacking, firing, damage, dodging or pressing 2 again cancel stealth and start the cooldown. These cancellation rules are implementation defaults for balancing; duration/cooldown/speed were not numerically specified by the user.
- Dialogue, pause and completion screens freeze stealth timers.

Guards and security cameras cannot visually detect concealed Miro. Physical guard contact is checked independently of vision. The HUD shows remaining active time or cooldown. Shadow areas still provide visual landmarks but are no longer required for activation.

The nonlethal playthrough test uses natural patrols, elevated routes and timed activations. It finishes without kills, damage or confirmed detection. Dedicated tests cover activation outside cover and in midair, slower walking, jumping, duration, cooldown, pause/dialogue, live/dead guard contact and manual cancellation.

## Checkpoint and ward interpretation

The specification requires disabling Level 3's security checkpoint and traversing Level 4's sealed experimental area. The checkpoint's physical seal opens when the linked terminal hack completes. The ward has a manual release after its experiment records; this is a simple implementation of sealed access, not a new story revelation. Both gates are reusable editable scenes driven by blueprint milestone names.

## Windows build

Run `Build Windows.ps1` to create `build/windows/Miro.exe`. The release executable contains the game pack and level JSON. Build output is ignored by Git. Matching official Godot 4.7.2 export templates are installed locally; their archive checksum was verified against the release SHA-512 list.

Launch the executable normally for a new run. For development, `Miro.exe -- --level=3` starts a specific floor. Starting a later floor is an independent test entry; it does not fabricate completed earlier sigils. Release builds do not accept Godot scene path overrides, so this argument is handled by the game itself.

Source playthrough tests and standalone executable startup checks are separate validation steps. An exported five-floor startup smoke test does not constitute a full exported playthrough.

## Exported playthrough verification

`Check Exported Playthrough.ps1` builds a separate QA executable and runs a continuous physical playthrough from the intro through all five floors and the watched ending. It uses real scene transitions and inputs without teleporting actors or granting milestones. It verifies all five committed sigils and the boss/ending outcome (64 checks). QA automation is gated behind the `qa` export feature and is excluded from the normal release build. `Check Windows Build.ps1` separately smoke-tests each floor in the release executable.

## Sound effects

Seven effects were selected from the supplied Kenney All-in-1 archive: concrete steps, knife swing, impact, latch, sigil click, shot and collapse. Original archive paths are recorded in `assets/audio/sources.json`; original CC0 notices are retained beside the files and included in exported packs. Press **M** to mute/unmute; the preference persists in Godot's user settings directory. Stealth steps are quieter and slower. Audio does not change AI detection rules. No music or voiceover has been selected.
