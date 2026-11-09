# Combat and narrative review handoff — 6 November 2026

**Superseded controls/attachments:** see [Final controls and remote](CONTROLS_REMOTE_HANDOFF.md). Q is blanket, 1–5 select rearrangeable items, R reloads, slot 5 starts as remote. SMGs support three-shot suppressors. Earlier controls below describe the previous increment.

## Delivered

This increment completes the requested review implementation of the two-gun inventory, pistol/SMG/flamethrower guard loadouts, mouse aiming, swept projectiles, visible casings/flames, inventory icons and pistol-only three-shot suppressors. See WEAPON_UPGRADE_TASKS.md for controls, tuning and asset provenance.

It also implements Ethan's subsequent story direction: red blood; anchored guard speech bubbles; silent Miro thought bubbles; Level 4's five-charge demolition emphasis; the mandatory final reveal of immunity, tower-created sickness and involuntary cure research; and the brother's conflicted physician identity. See NARRATIVE_UPDATE.md. The original spec now explicitly records these approved amendments. Level 3's required root login and checkpoint gate remain intact.

## Controls for review

- Mouse aims; left click fires. Hold for SMG/flame. 4 retains keyboard fire.
- Q switches carried guns. Third distinct weapon: Z replaces slot 1, X replaces slot 2, Escape cancels. Gameplay pauses for this choice.
- Original 1 shank, 2 blanket, 3 C4, E interaction and C dodge remain.
- Suppressors come from Julia's crates. Only pistol rounds consume the three charges. Fourth pistol round is loud; SMG/flame always alert nearby guards.
- The ward starts with five reserved demolition charges: two new fixed support interactions use two each; the original fourth sigil uses one. Other floors retain their established placements.

## Verification

- Weapon inventory/fire: 16/16; earlier mouse projectile checks: 5/5.
- Narrative/bubble/red-blood checks: 10/10.
- Later-level physical traversal and objectives: 128/128, including both new charge supports and boss defeat.
- Level 3 security: 19/19; gates/loot: 10/10; brother: 15/15; ending: 11/11.
- Music/world/voice integration: 41/41; scripted dialogue layout: 5/5.
- Intro: 44/44; input checks: no failures. Stealth, scaffold and audio suites also passed during this implementation.
- Exported QA playthrough from an isolated directory: 68/68. Pack audit: nine music tracks, sixteen voice clips, new weapon assets and inner-dialogue JSON present; credentials/source recordings excluded.
- Native Metal-rendered screenshots verify real textures, replacement UI and both bubble styles. These are automated review captures, not a claimed manual playthrough. Native capture exit can report two ObjectDB cleanup warnings; gameplay checks show no script errors.
- Windows and unsigned macOS review exports rebuilt locally: `build/windows/Miro.exe`, `build/macos/Miro.zip`. Windows execution was not tested on a Windows machine.

## Review limits and next tasks

Weapon art is original SVG placeholder art. Existing credited Kenney audio is reused for pistol/SMG; the flame puff is original synthesized audio. Existing ElevenLabs guard clips are unchanged. New Miro thoughts and revised story prose are text-only; no new voice-generation spending is claimed.

Optional early-floor hacking, bounded camera reinforcements, turrets/drones/traps and final art/audio polish remain separate meeting tasks. Do not remove the mandatory Level 3 hack. Preserve the existing retry/loadout rules and level geometry unless Ethan explicitly changes them. Human playtesting should focus on weapon balance, early-floor onboarding, bubble distraction/readability and whether the final exchange lands emotionally.
