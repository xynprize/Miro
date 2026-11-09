# Last Man Standing
## Proposed Game Design Specification — Narrative and Gameplay Foundation

### Game overview

A single-player, 2D action/stealth platformer built in Godot. A former Keeper escapes from the upper cells of a prison tower, descending through an institution he once served. As he uncovers evidence of persecution, experimentation, and a spreading illness, his brother repeatedly tries to stop him.

The player leaves a distinctive sigil on each floor. In the ending, these marks are revealed as demolition charges. After fatally wounding his brother and escaping into the woods, the protagonist detonates them, destroying the tower.

**Target:** Desktop  
**Target runtime:** 15–25 minutes  
**Structure:** Five short, handcrafted levels  
**Playable characters:** One  
**Major speaking characters:** The protagonist and his brother  
**Gameplay assets:** Kenney All in 1 Game Assets  
**Animated cinematics:** Planned production through Higgsfield

### Approved revision — 6 November 2026

Ethan explicitly updated the story and combat scope. [Narrative update](NARRATIVE_UPDATE.md) specifies the five-floor reveal, guard speech bubbles, Miro’s inner dialogue and Level 4 demolition emphasis. [Weapon tasks](WEAPON_UPGRADE_TASKS.md) specifies the requested firearms additions. These amendments take precedence over conflicting original draft details below; unrelated progression remains unchanged.

Miro is immune to a sickness created by the tower. The tower imprisons and experiments on him to reproduce his resistance as a cure, while portraying his defiance as dangerous. This truth is revealed in Level 5. His brother is the tower physician: sincerely protective, complicit in the betrayal, and trapped in the institution’s account of his own purpose. Levels 1–2 introduce play and unease; Level 3 requires hacking; Level 4 places most of the C4; Level 5 contains the final confrontation.

### Approved controls and traversal revision — 7 November 2026

[Final controls and remote](CONTROLS_REMOTE_HANDOFF.md) and [Fran/traversal reconciliation](TRAVERSAL_FRAN_HANDOFF.md) record Ethan’s subsequent instructions. Q selects a shadow-only blanket; numbered slots are rearrangeable. Two jumps together reproduce Fran’s 65.17-pixel reference height at gravity 850. Optional timed trapdoors preserve ladder access and required story gates.

### Creative pillars

1. **Descent reveals complicity.** Each floor exposes more of the institution’s crimes and the protagonist’s involvement.
2. **The brother is a person before he is a boss.** Recurring encounters establish affection, resentment, and conflicting loyalties.
3. **Evidence supports competing interpretations.** The illness is dangerous; the Keepers’ response is cruel. Neither fact cancels the other.
4. **The ending changes the meaning of the journey.** The marks left during escape become the means of destruction.
5. **A small, complete experience.** Reusable enemies, compact levels, short dialogue, and one fixed ending.

### Narrative rules

The protagonist’s history is initially unknown to the player. Amnesia is not required: he can remember his past while revealing it gradually through dialogue and environmental details.

The protagonist was imprisoned for treason after opposing the Keepers’ treatment of symptomatic people. The precise act that led to his arrest must be established before scripting.

The brother is the tower physician. He remains loyal to the order and believes it can be restored. He has participated in, permitted, or defended its abuses; affection for his brother does not erase that responsibility.

The brother relationship is revealed before the final level, giving players time to experience it.

The ending leaves the morality of the protagonist’s decision unresolved. It clearly communicates what he does and whom he leaves behind.

### Core gameplay loop

Explore a floor → evade or fight Keepers → discover a short story beat → place a sigil at a designated location → descend.

Movement includes running, jumping, and ladder climbing. Combat uses a short-range weapon, readable enemy attacks, and brief recovery windows. Stealth uses cover and line of sight.

Sigils are placed through the normal interaction action at fixed locations. No free-placement explosives, crafting, or demolition simulation are required.

### Level progression

| Level | Gameplay purpose | Narrative purpose | Brother’s presence |
|---|---|---|---|
| **1 — The Prisoner** | Teach movement, interaction, combat, and the first sigil placement | Establish imprisonment for treason and the Keepers’ authority | Speaks from beyond a locked gate; knows the protagonist personally |
| **2 — The Symptoms** | Introduce cover and patrol avoidance | Show visible illness alongside evidence of indiscriminate persecution | Offers surrender and hints at their shared past |
| **3 — The Order** | Navigate a security checkpoint and disable its controls | Reveal the protagonist’s former rank and confirm the brothers’ relationship | Appeals to their shared responsibility for the order |
| **4 — The Ward** | Traverse a sealed experimental area and place the penultimate sigil | Show both abusive experiments and credible evidence that containment matters | Warns that destroying the institution could destroy something irreplaceable |
| **5 — The Brother** | Place the final sigil, defeat the brother, and escape | Resolve the personal conflict while leaving the moral conflict open | Fights, is fatally wounded, and still addresses the protagonist as his brother |

Each floor contains one essential story beat. Optional environmental details deepen the conflict without being necessary to understand the ending.

### The final encounter

The brother blocks the exit because he believes escape and sabotage threaten others. Before combat, he offers one last opportunity to rebuild the order together.

The boss uses two readable attacks and clear vulnerability windows. Defeat leads into a brief scripted exchange rather than an additional combat phase.

Dying, the brother expresses both affection and conviction. The immunity and tower-origin revelation occurs before combat in the mandatory lab exchange. His dying warning concerns the sick people already established, rather than introducing another twist.

The protagonist leaves him behind.

Outside, the player reaches a fixed viewpoint in the woods. The protagonist looks back. The sigils activate in sequence, revealing their shared purpose. The tower collapses through a cinematic.

The protagonist lowers his head. Fade to black.

No epilogue establishes which brother was ultimately correct.

### Sigil design

Use one recognizable emblem throughout gameplay and cinematics.

Before the ending, sigils appear to be acts of defiance. Their consistent placement on structural or energy junctions provides subtle foreshadowing.

The fiction must establish how a former Keeper possesses this capability and why the charges can destroy the tower. This can be conveyed through a brief environmental clue rather than technical exposition.

All five floor sigils remain required. Under the approved revision, Level 4 also has two additional fixed support placements carrying two charges each: five charges on that floor, nine across the tower. Premature detonation is unavailable.

### Art and cinematic production

Audit the owned Kenney collection before committing to tile size, character proportions, or pixel-art presentation. Select a compatible environment, character, interface, and effects set as the visual baseline.

Distinguish the brothers using silhouettes, colors, and equipment that the selected assets can support. Represent symptoms with restrained overlays, tint changes, particles, or altered movement where practical.

Use Higgsfield for three priority sequences:

- Opening imprisonment.
- The aftermath of the brothers’ fight.
- The forest viewpoint and tower destruction.

Use in-engine dialogue for intermediate encounters. Prepare consistent character and location reference sheets before generating cinematics.

Cinematics require subtitles and skip controls. Skipping must apply the same progression changes as watching. Keep still-image versions available if animated sequences are not ready.

### Implementation requirements

Use reusable scenes for the player, guard, cover zone, security control, sigil anchor, level exit, boss, and cinematic player.

Track the current floor, completed sigil placements, narrative milestones, boss outcome, and ending completion.

Restarting a floor restores its entry state. Interacting twice with a sigil cannot duplicate placement. Cinematics cannot trigger twice or leave movement disabled after skipping.

The tower destruction is a prepared cinematic, not simulated structural destruction.

### Scope and completion criteria

The first complete build must include:

- Five traversable floors with working objectives.
- One reusable standard enemy and one brother boss.
- Functional combat, cover, damage, and retries.
- Five required sigil placements.
- Recurring brother encounters.
- Evidence of both institutional cruelty and genuine illness.
- Fatal confrontation, outdoor escape, and tower destruction.
- Subtitles, pause, cinematic skipping, and a complete exported playthrough.

If the original seven-day schedule still applies, cut extra enemy types, elaborate security puzzles, optional rooms, and intermediate animated cinematics first.

### Decisions to settle before production

- What specific act constituted the protagonist’s treason?
- What does the illness demonstrably do, and what remains uncertain?
- Who remains in the tower when it is destroyed?
- What concrete evidence supports the brother’s warning?
- What gives the sigils their destructive power?
- Is the seven-day production window still a requirement?