# Level 1: The Prisoner

Open `scenes/intro.tscn` in Godot and press F5, or use the Miro Play desktop shortcut. This is now the project's main scene. Renderer: Forward+ (Vulkan verified on the RTX 5070).

## Play

The authoritative bindings are in [Final controls and remote](CONTROLS_REMOTE_HANDOFF.md). Default slots: 1 shank, 2 C4, 3–4 guns, 5 remote; Q selects blanket, left click uses, right click focuses (or places C4), R reloads, N rearranges inventory, Backspace retries. Space twice double-jumps; C dashes; Ctrl crouches.

Miro wakes with amnesia in Cell 07. The corrupt Keeper extorts payment for medicine, then begins visibly coughing and hunching. Search the bed to retrieve the secretly assembled C4, shank, and blanket. His memory loss does not erase the practical skills in his hands. The opening deliberately leaves his identity, the illness, and the familiar voice unresolved.

Escape choices:

- **Quiet:** approach the bars, wait for the Keeper to turn away within reach, press E to take the key, then E to unlock. Hide in the first recess just outside the cell by selecting Q and clicking. Wait for the search to end and the guard to face away before leaving. The next recess and elevated shelves give further opportunities to avoid patrols.
- **Lethal:** face the nearby unaware Keeper and select 1 and left-click, then E to loot the key and optional weapon; E unlocks the cell. The corpse remains discoverable.
- **Loud:** use 3 near the lock. The breach opens the door and draws investigation. It does not automatically kill the guard. One C4 charge is always reserved for the objective below.

Follow the upper gallery to the barred voice encounter, descend the ladder, cross the middle passage, descend again, set the sigil at the lower support, and reach the lower-right gate. Raised shelves provide alternatives to walking through guards. The intro ends with the escape route and casualty count; Level 2 is deliberately not implemented.

## Detection rules

Guards use facing, range, vertical separation, and a physics ray against solid world geometry. Brief sightings build suspicion; a sustained sighting confirms detection. A hidden player is not visible. Movement, climbing and jumping preserve concealment. Contact with a living guard immediately reveals Miro and alerts that guard. Attacking, firing, taking damage, dodging or manual cancellation also end stealth and start its cooldown. Timers pause during dialogue and pause menus. Guards telegraph a melee strike before hitting; the player has three hearts and a damage recovery window.

Losing sight starts a search at a fixed last-known position. It does not track the hidden player's current position. Seeing a corpse starts a search at the corpse without revealing Miro. Bodies are remembered once per witness, avoiding endless retriggered searches. Noise attracts investigation; only actual sight confirms Miro's location. Guards stay on their own platforms and cannot climb ladders.

## Editing

See [Level 1 scaffold](LEVEL_01_SCAFFOLD.md) for the editable blueprint, named beats, reusable scene hierarchy and requirement-to-implementation map.

- `scenes/intro.tscn`: saved, editable level hierarchy. Move interactables and guards in the editor; paint `StoneFloors` using the TileSet.
- `assets/environment/prison_tiles.tres`: Julia's three original textures, 28 x 28 placement grid with 28 x 27 atlas regions, and solid collision polygons.
- Reusable scenes: `intro_player`, `guard`, `cover_zone`, `ladder`, `sigil_anchor`, `level_exit`.
- `scripts/intro_level.gd`: story, interactions, floor state, dialogue, contextual controls and completion.
- `scripts/intro_guard.gd`: perception and patrol / suspicious / alert / search states.
- `scripts/intro_player.gd`: movement, ladder, dodge, inventory and attacks; extends the supplied BaseCharacter foundation.
- `scripts/prison_art.gd`: editable code-native masonry and prop placeholders. Final bed, guard, cage, torch and gate sprites can replace these as Julia supplies them. No AI bitmap generation was used. Julia's six original PNGs are unchanged.
- `tools/build_intro.gd`: reproducible initial scene authoring tool. **It overwrites intro.tscn; do not rerun over hand-edited level work.** Runtime does not invoke the builder.

The supplied Oil 6 colors guide masonry, props, guards and interface. The brighter highlights and shadow recesses distinguish interactive spaces. The example platformer image informed height variation, not its colors.

## Specification precedence

Read all five supplied reference documents: class guide, both meetings, game specification and all eight pages of the PDF (including its flowcharts). Latest user direction takes precedence where these differ: protagonist is Miro, amnesia is explicit, the Keeper becomes ill after the opening exchange, and basic blanket stealth is introduced here rather than deferred entirely to Level 2. The scene follows the tiered reference sketch with the later floors linked through the completion screen. The latest stealth direction replaces stationary shadow-only concealment.

## Verification

Run `Run Checks.ps1` from the project directory. It rejects engine/script errors even if Godot returns exit code zero.

- 44 interaction, perception, progression and physical traversal checks, including a continuous shank-route playthrough.
- 45 checks with the full physical route entered through the C4 breach.
- Continuous natural-patrol pickpocket/stealth playthrough: no teleporting, no guard-state changes, no kills, no damage, no confirmed detection.
- 15 keyboard/lifecycle checks: actual key events for dialogue, skip, supplies, pause/resume, blanket, attack, jump, dodge, death and R scene reload; also two-hit frontal combat and remembered-location searching.
- Forward+ rendered captures inspected for the opening, cell, full layout and lower objective.

All route tests use real Godot physics and player movement. Focused perception tests position actors explicitly to cover particular visibility cases; they do not substitute for the continuous playthroughs. Human pacing and art polish can be refined from this playable implementation.

The initial intro was pushed in commit `40e1c5a`. Subsequent local changes are visible in Git status.
