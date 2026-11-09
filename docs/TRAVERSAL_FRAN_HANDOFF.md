# Traversal, trapdoors and Fran's playtest — 7 November 2026

Source reviewed: [Fran's commit 935bda0](https://github.com/ethanrxla/Miro/commit/935bda06249c6539960e089a8e6fe605704597b6). The original report is preserved in [PLAYTEST_REPORT_FRAN_2026_11_07.md](PLAYTEST_REPORT_FRAN_2026_11_07.md). Its results describe that earlier build; they are not substituted for checks of this version. Changes are pushed only to the organization repository.

## Confirmed direction implemented

Ethan explicitly authorized Fran's shadow-only blanket rule. Q selects the blanket; left click activates it in cover. Leaving cover reveals Miro and starts the existing cooldown. Fran's horizontal margin and jumping tolerance are preserved. The 5-second duration, 8-second cooldown, movement reduction and contact reveal remain.

Ethan subsequently clarified the jump reference: **two jumps combined must equal the height of Fran's corrected single jump**. Fran reported approximately 65.17 pixels at gravity 850. Two separate −242.37 impulses, with the second near the first apex, measure **65.165 pixels total** in the 60 Hz engine test. A single press is roughly half the rise. The second jump is a new Space press, not an automatically taller first jump. Early second presses spend remaining momentum and can reach less height. Gravity remains 850. Wall mounting is separately bounded and collision checked.

## Orange connector trapdoors

Suitable orange connector tiles become E-operated trapdoors. Activation requires standing over the hatch, so merely approaching one does not steal E from a nearby terminal or story prop. Collision is removed for five seconds. The countdown pauses with gameplay. Closing waits until the opening is free of Miro, guards and placed C4.

Connectors intersecting ladder corridors remain ordinary floor. Hatches before the Level 3 checkpoint or Level 4 ward gate remain locked until that gate opens: otherwise dropping could strand Miro on the wrong side of a mandatory terminal. Other hatches open immediately. Opening hatches does not complete or bypass story milestones.

## Placement and interaction audit

Checked all five floors for crates/cases, hiding spaces, service ports, note/terminal/charge markers and trapdoors. Props must have clear standing space and usable ground. Ladder exclusion uses the full ladder rectangle, not only its midpoint. Access to nearby props and remote connections is line-of-sight checked. Nearest eligible interaction priority prevents crates, bodies or loose charges from accidentally overriding a closer story station.

Corrected six clipped or buried authored markers without changing the floor geometry:

- Level 1 QuarantineOrder → (870, 376).
- Level 2 TransferLedger → (658, 404), clear of the neighboring step edge.
- Level 3 RankRecord → (570, 180).
- Level 4 WardRelease → (430, 208).
- Level 4 ContainmentEvidence → (600, 376).
- Level 4 WardChargeLower → (500, 656), clear floor beside the overhanging ledge.

Blueprints, interactive scene nodes and editor plan markers are aligned. Existing collision-free background dressing remains decorative. The checkpoint password and required hack are retained. The level-select menu already exists in this branch; the report's “not implemented” menu finding refers to its older build.

## Current verification

- Traversal/access audit: **39/39**, including measured combined jump height, trapdoor duration, pause, occupied closing, gate safety, every prop/marker's clearance, and upward ladder exit on both ladders of all five floors.
- Later-level physical traversal: **128/128**.
- Nonlethal intro: **zero failures**, no kills, no damage and no confirmed detection. The route uses the revised two-part jump only when needed and waits for blanket cooldown before entering the final shadow.
- Intro: **44/44**; shadow-only blanket: **16/16**.
- Controls/movement: **24/24**; remote: **11/11**; weapons: **16/16**.
- Security, gates/loot, music/voice/world, boss, ending, dialogue layout and narrative/bubble regressions pass.

Automated checks and native-render captures support this handoff. They do not replace a human feel/pacing pass. Review double-jump timing, trapdoor readability and E selection around moving guards. Windows/macOS review exports are rebuilt locally; native Windows execution is not claimed.
