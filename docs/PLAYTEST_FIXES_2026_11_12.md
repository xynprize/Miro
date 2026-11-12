# Live playtest fixes — 12 November 2026

The active playtest executable was kept running while these changes were developed. Passive, foreground-only game capture remains local under `tmp/live-playtest-20261112-video*`.

## Gameplay and guard behavior

- Level 2 Alden accepts held strangling; the tutorial key prerequisite applies only on Level 1. A held victim cannot turn or attack during the interaction.
- Search turns and obstacle replanning have a short hold; repeated hops are limited, occupied body landings are rejected, opposing guards leave extra space, and excess unseen pursuers cover downstairs instead of crowding the landing.
- Ward reinforcements wait when the nearby landing is already crowded. Named reinforcements do not reuse a dead or living character's identity.
- The knife pose and hit direction follow the aimed cursor/controller direction. Guitar blocking and projectile deflection require right click/controller focus; frontal melee can be blocked. Niro attacks longer before recovery.
- The Foundation has two pre-boss waves per upper storey and bounded reinforcements during all four encounters. Retry restarts the appropriate music cue.
- Remote-story markers retain automatic triggers and no longer draw doors. The real exit remains a door.
- A nearby unconscious guard can be looted without accidentally entering an adjacent vent.

## Layout and pickups

- Hiding openings are named VENT. Adjacent storeys connect through offset openings; W/S travels and E exits. Closed story gates constrain travel.
- Vent openings reserve clear wall space. Background fixtures and furniture avoid them; paintings check their complete frame and plaque against geometry and furniture.
- Warning fixtures avoid windows. Turrets on authored Levels 2–4 attach to a suitable nearby vertical stone face, with ladder/door clearance and legacy security checkpoint IDs retained.
- The ward-seal light moves clear of its label, with its gameplay light position kept in sync. Fixture clearance is cached rather than rescanned every redraw.
- The microscope sits centered on the table behind both bottles. Pale table bottles heal half a heart; red flasks heal a full heart. Consumed pickups persist across retries.
- Checkpoints cannot advance below unfinished earlier-storey objectives; unsafe older checkpoint positions migrate back to entry while retaining saved progress and kit.

## Dialogue and voice

Confirmed named deaths are stored per run, separately from lifetime statistics. Scripted named reports cover possible victims on the preceding floor and use the actual conversation speaker's voice ID. Other discoveries use truthful shared lines rather than a fixed, incorrect victim name. No-kill runs use existing neutral dialogue, even if noise makes the run HUNTED. Family reactions use authored son/daughter metadata with a neutral child fallback. Only the required replacement/report clips were installed; the offline voice audit covers 998 required lines.

## Verification and limits

The regression suite was completed through resumed runs, with focused reruns after the final changes. Added coverage includes vent travel, current-run reactions, checkpoint migration, Alden, guitar defense, aiming, reinforcement placement, and layout clearance. Exported playthrough checks cover the five-level route. Geometry checks do not replace a final visual review of the rebuilt game; the user's ongoing screenshots are from the older executable.
