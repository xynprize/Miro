# Final controls and remote review — 7 November 2026

This supersedes earlier control tables and the pistol-only suppressor interpretation. It implements Ethan's explicit controls corrections, including moving C4 left to slot 2 and assigning the remote to slot 5 rather than F.

| Input | Action |
|---|---|
| A / D, arrows | Move |
| Space, then Space in the air | Jump, double jump |
| Space against a reachable ledge | Mount/mantle if the path and landing are clear |
| Left Ctrl | Crouch; cannot stand inside a low ceiling |
| C | Dash using the jump sprite and existing brief damage protection |
| 1–5 | Select a numbered item; does not automatically use it |
| Q | Select blanket, always outside the numbered inventory |
| Left click | Use selected item: shank, blanket, gun, remote, or detonate placed C4 |
| Right click | Focus: slower movement and aim reticle; with C4 selected, place a charge instead |
| R | Reload selected gun from finite reserve ammunition, with a one-second progress ring |
| E | Interact, loot, pickpocket or recover a nearby undetonated charge |
| N | Inventory: click two slots to swap; N/Escape closes |
| Hold a gun's numbered key | Fit a stored spare suppressor over one second; release cancels |
| Escape | Close an open inventory/remote, otherwise pause |
| Backspace | Retry the floor; R no longer restarts |
| Enter / Tab | Advance / skip story dialogue |
| M / F10 | Mute / return to menu |

Default order: **1 shank, 2 C4, 3 first gun, 4 second gun, 5 remote**. Q is always the blanket. Empty gun slots remain visible until looted. Slot rearrangement persists between floors in the current run. Magazine/reserve ammunition and C4 quantities appear separately beneath icons, never in place of slot numbers. The old mouse/suppressor instructional banner is removed; the bar shows only the selected item's relevant actions.

## Latest traversal clarification

See [Fran/traversal handoff](TRAVERSAL_FRAN_HANDOFF.md). The two jumps **combined** reproduce Fran's approximately 65.17-pixel height; gravity is 850. The blanket is now shadow-only, per Ethan's approval of Fran's report. Suitable orange connectors are five-second trapdoors, with ladder and return-route safety checks.

## Weapons and movement

Miro holds two guns. Picking a third retains explicit Z/X replacement or Escape cancel. Pistol/SMG suppressors each break after three actual shots; SMG bursts can consume all three quickly. Flamethrowers cannot use them. Julia's cases automatically fit a suppressor to the selected compatible unsuppressed gun, otherwise store a spare. Spares and attachment uses sit beside health, outside inventory slots. Attachments belong to their guns; switching or replacing guns does not transfer them. Empty triggers consume nothing.

Reload uses finite reserves: pistol magazine 8, SMG 24, flame fuel 30. Initial weapon loot supplies two reserve magazines; duplicate weapons supply reserve ammunition. Gun cases eject short-lived cosmetic shells. Miro's head is rendered from a separate region of the existing sprite so it can turn/tilt toward the cursor.

Mantling is deliberately small: contact with a wall, up to a 34-pixel rise and 22-pixel forward move, checked for headroom, clear travel and a landing surface. It is not a general climbing system. Crouching changes collision height, preserves feet position, and checks clearance before standing.

## C4

Right click drops a physical charge; E recovers it intact; left click detonates placed charges. Blasts are bounded and wall-occluded. A charge beside the Level 1 lock opens it. Required story charges cannot be spent on optional explosions. Later floors receive one extra charge for this mechanic; the ward still has five required charges across its three authored supports, plus one optional charge. Authored supports remain E interactions and detonate through the established ending sequence.

## Remote / MP3 acquisition and minimal puzzle

The sick Keeper at the first cell supplies the device when looted after death. The existing pickpocket path also takes it with the key, preserving a nonlethal route. Missing the device does not remove the existing physical Level 3 terminal. Ownership and service-mode unlock carry into later floors. Select its inventory slot and click to open; F is unbound.

1. Inspect the locked MP3 player and type `hack` (or `./unlock.sh`) to run Miro's stored unlock script.
2. `help` lists the small command vocabulary. `scan` finds a local access point only within 48 world pixels.
3. `login <password>` authenticates. Early maintenance ports have a root sticker; Level 3 keeps the overheard root clue and maintenance-slip fallback.
4. `lights test` blinks the first-floor service lamp. `cameras off` disables the optional second-floor corridor camera or starts the existing one-second mandatory Level 3 hack.
5. `music` reports MP3 mode; the existing floor soundtrack system continues playback. No new playlist, scoring or track-unlock system is claimed.

These are fictional, allowlisted in-game commands; no shell/network execution is involved. Unknown commands explain how to get help. The terminal is a paused, short puzzle rather than a real command-line emulator.

| Floor | Access point | Purpose |
|---|---|---|
| 1 | Middle passage, (500, 432), marked SERVICE PORT | Harmless lamp practice; no progression gate |
| 2 | Middle passage, (440, 432), marked SERVICE PORT | Optional camera at (720, 370); no story gate |
| 3 | Existing RemoteTerminal, around (300, 230) | Required checkpoint; password, local range, one-second operation and gate preserved |
| 4–5 | No extra access points | Keep demolition and boss pacing focused |

## Validation and review limits

New controls/movement checks: 24/24. Remote acquisition and early/mandatory hacking checks: 11/11. Full later-level traversal: 128/128. Music/world/suppressor integration: 42/42. Existing intro, physical input, security, projectile, weapon inventory, dialogue, stealth, narrative and ending checks also pass. Native automated screenshots verify the new bar, rearrangement panel and terminal; these are not a claimed manual playthrough.

Review focus: whether one-second reload/attachment feels right, mantle reach, the clarity of reserved C4, and optional-camera difficulty on Level 2. SVG weapon/remote art remains review art. Existing guard recordings are unchanged; this work adds no generated voice clips.
