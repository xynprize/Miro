# Weapon upgrade tasks

**Superseded controls/attachments:** see [Final controls and remote](CONTROLS_REMOTE_HANDOFF.md). Q is blanket, 1–5 select rearrangeable items, R reloads, slot 5 starts as remote. SMGs support three-shot suppressors. Earlier controls below describe the previous increment.

Requested after updating the organization repository to `8de4093`.

## Meeting notes received

The supplied [meeting 3 notes](miromeeting3.md) are now preserved verbatim in the repository. They record intended behavior and reported problem areas, not reproducible bug reports or proof that every listed system is absent.

## Meeting gaps to verify

- **Bindings, stealth cooldown, C4 and retries:** reproduce each reported issue before changing the established rules. The notes provide no exact failure steps, so keep regression checks and new player-perspective observations separate.
- **Hacking scope clarification:** Ethan confirmed that Level 3 RemoteTerminal and its physical checkpoint gate remain mandatory story progression. Optional terminal/panel encounters apply before Level 3 where consistent with `mirospec.md`; do not add a bypass to the Level 3 gate.
- **Camera response:** current cameras direct existing guards to investigate. Additional reinforcement spawning is a separate missing behavior, requiring bounded spawn counts and authored positions; do not call current investigation reinforcement spawning.
- **Ground dodge:** use the existing jump-frame sprite during a rapid forward dodge near the ground. Validate collision, ladder entry/exit and action cancellation.
- **Traversal:** verify return routes to upper tiers, ladder transitions and required jumps. Wall-slide/climb are possibilities in the notes, not automatically mandatory new mechanics.
- **Brother:** retain the existing playable boss and Godot ending while reviewing dialogue clarity, remote representation and a modified/recolored Miro appearance. A new external cinematic tool is not needed.
- **Encounter library:** cameras already exist; turrets, drones and traps remain separate reusable encounter work. Scope these after basic attacks and weapon mechanics.
- **Assets and polish:** preserve Julia's keeper/crate artwork and decorative mushrooms; check inventory visibility, missing animations, music transitions and voiced conversations in actual play.
- **Delivery:** credits, submission requirements and downloadable release distribution need their own review. The notes' Sunday/Monday schedule is historical planning, not a newly assigned calendar deadline.

The explicit weapon request adds requirements beyond this meeting: three armed guard classes, two carried guns, mouse aim, visible projectiles/casings, flamethrower effects, inventory icons and three-use suppressors.

## Ordered implementation

1. **COMBAT-01 — Meeting bugs and asset inventory.** Import the meeting notes, reproduce reported problems, and inventory Julia's art and the licensed library. Locate suitable pistol, SMG, flamethrower, shank, C4, blanket, bullet, casing and flame assets. Preserve attribution and distinguish final art from placeholders.
2. **COMBAT-02 — Two-slot weapon inventory.** Model pistol, SMG and flamethrower separately with ammo/fuel and selected slot. Miro can carry at most two guns. Picking up a third opens an explicit replace-slot/cancel choice; never silently discard a gun. Display gun, blanket, shank and C4 icons and quantities. Preserve existing melee/explosive controls while defining weapon switching.
3. **COMBAT-03 — Mouse aiming and visible fire.** Aim in world coordinates through the camera transform. Implement muzzle position/direction, visible bullet travel or a tracer, muzzle flash and ejected casings. Sweep bullet collisions between frames to avoid tunneling; walls block shots and damage applies once. Casings are cosmetic, bounded and cleaned up. UI clicks must not fire weapons.
4. **COMBAT-04 — Three guard classes.** Equip light guards with pistols, assault guards with SMGs and heavy guards with flamethrowers. Give each clear visual/readable attack tells, range, cooldown and matching loot. Tune threats without silently redesigning level geometry.
5. **COMBAT-05 — Flame behavior.** Implement a visible short-range flame stream with wall occlusion, controlled damage cadence, fuel consumption and bounded effects. No suppressor compatibility. Do not assume persistent fire spread or destructible architecture is required.
6. **COMBAT-06 — Julia's crates and suppressors.** Use Julia's crate asset for accessible, sensible suppressor pickups. A suppressor has exactly three fired-shot uses; empty triggers do not consume it. Treat it as pistol-only for the first implementation: the user excluded flamethrowers and described SMG use as impractical. Document this interpretation for review. Suppressed shots should be silent to guard hearing; visual detection remains possible. This supersedes the existing reduced 90-unit noise prototype.
7. **COMBAT-07 — Audio and verification.** Distinct weapon firing effects, full unsuppressed guard-hearing events, quiet suppressed presentation, and flame audio. Verify both player and guard shots, walls, aim at different viewport sizes, two-slot replacement/cancel, burst consumption, exactly three suppressed rounds, flame restrictions, death/retry and campaign progression. Rebuild the review exports and update the handoff with actual results.

## Current implementation status

Implemented for review: two carried guns, independent ammo/fuel, Q switching, explicit Z/X replacement or Escape cancel on a third distinct gun, inventory icons, world-space mouse aim, swept wall-blocked projectiles, casings, pistol/SMG/flamethrower guard loadouts and matching corpse loot. Guards telegraph for 0.65 seconds, fire bounded bursts, and recover. SMG/flame can be held on the left mouse button; pistol remains one round per press. Keyboard 4 remains available. Flame has short-range swept collision, fuel use and controlled damage cadence; no persistent fire simulation.

The suppressor is pistol-only and lasts three fired rounds. SMG/flame neither consume its charges nor receive suppression. Unsuppressed player and guard fire alert nearby guards. Julia's crate supplies the suppressor. Weapon/flame SVGs are original review placeholders, not Julia art or third-party finds. SMG audio reuses the credited Kenney shot at higher pitch; flame audio is an original synthesized puff. Effects remain under the existing Effects bus.

A native-render check caught textures loaded temporarily in `_draw` becoming white rectangles. Strong shared texture references fix this. The new tests cover inventory choice/cancel, independent ammo, projectile travel, suppression, wall occlusion, flame fuel/damage, enemy hits and dodge immunity. The broader campaign tests preserve hacking, C4, stealth, boss, music and ending behavior.

Level 3's required terminal/password/checkpoint gate remains intact. The explicit later narrative update adds two fixed charge stations to Level 4 without changing geometry; see [narrative update](NARRATIVE_UPDATE.md). Optional pre-Level-3 hacking, new reinforcement spawns and turret/drone/trap encounters remain separate meeting tasks; they are not claimed as implemented here.
