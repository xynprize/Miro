# MIRO — Reactive Art Direction & Branching Artwork Specification

**Document:** `artspec.md`  
**Project:** Miro (Godot 4.x)  
**Version:** 1.0 — November 7, 2026  
**Status:** Design specification; no assets are embedded or downloaded by this file  
**Jam deadline:** November 10, 2026

---

## 1. Creative vision

Miro begins in a prison tower with no explanation of why he is incarcerated. Across five levels, paintings, engravings, and prints become a quiet narrative layer: the prison seems to *respond to the player's decisions*. Art suggests imprisonment, disconnection, deception, faith, survival, or freedom without confirming whether the prison is literally changing or Miro is interpreting it differently.

**Core mechanic: The Reactive Gallery.** Specific frames have a stable world position but their artwork is selected at a checkpoint based on Miro's actions. Players who solve problems through stealth, surveillance manipulation, confrontation, endurance, or curiosity will encounter different visual stories. The artwork is foreshadowing, not a morality meter.

**Design principles**

- Use authentic reproductions, never AI-generated imitations passed off as originals.
- Honor the work's meaning while allowing creative thematic interpretation.
- Make the change visible on *returning to or entering* an area, not as a distracting instant texture pop in front of the player.
- Keep all five gameplay levels and essential objectives completable regardless of art branch.
- Preserve uncertainty about Miro's backstory: the art poses questions, not plot spoilers.
- All 27 unique works below are eligible for the project's **art pool**, subject to selecting a properly licensed reproduction for each. A single playthrough need not display all 27.

## 2. Themes and artistic vocabulary

| Theme | Intended emotion / narrative meaning | Leading works (IDs from catalog) |
|---|---|---|
| Escape | A possible world outside, flight toward the unknown | A11, A12, A13, A14, A24 |
| Trapped | Repetition, enclosure, mechanical punishment | A01, A02, A06 |
| Loneliness | Being alone even when others exist | A03, A04, A27 |
| Distrust | Observation, misdirection, unreliable allies | A05, A06, A09, A10, A16 |
| Alienation | Separation from society or one's own identity | A07, A08, A06 |
| Betrayal | Friendship or belief turned against the self | A09, A10, A05 |
| Confusion | Distorted reality, nightmares, uncertain truth | A16, A17, A15, A14 |
| Survival | Endurance against overwhelming forces | A18, A19, A23 |
| Defiance | Refusal to yield to unjust power | A20, A21, A23 |
| Blackhat | Unauthorized control, deception, forbidden knowledge | A22, A05, A17 |
| Isolation | Vast empty spaces, self-reliance, disconnection | A03, A24, A15, A18 |
| Faith | Trust, redemption, determination, or a moral horizon | A25, A26, A21, A11, A27 |

**Note:** “Blackhat” is a game-design interpretation, not a claim about a historical artwork's original subject. “Faith” can be religious, philosophical, or a commitment to hope; it does not automatically mean the protagonist is religious.

## 3. Complete art catalog — 27 unique works

The list combines **every distinct work mentioned in our prior art discussions**, de-duplicating repeats. Some items are *prints/engravings*, not technically paintings; they are retained because they suit the game.

**Rights legend:**
- **OA** — the linked museum object or specific Commons file was checked as publicly marked public domain / CC0 / open use. Recheck the image-file notice when actually downloading.
- **VERIFY** — historical artwork appears public domain, but the *specific downloadable image file* and its terms must be checked before shipping.
- **OA-ALT** — museum object page is not currently offering the download; the linked alternate file is expressly marked CC0.

| ID | Work (year / medium) | Artist | Main themes | Intended use | Source & rights |
|---|---|---|---|---|---|
| **A01** | *Prisoners Exercising* / *The Prison Courtyard* (1890, painting, after Gustave Doré) | Vincent van Gogh | trapped, isolation | Prison introduction; looping oppression | [Commons candidate file](https://commons.wikimedia.org/wiki/File:Vincent_van_Gogh_-_The_Prison_Courtyard_(1890).jpg) — **OA** |
| **A02** | *The Round Tower*, from *Imaginary Prisons* (c. 1749–50, print) | Giovanni Battista Piranesi | trapped, confusion | Impossible architecture; claustrophobic halls | [Met](https://www.metmuseum.org/art/collection/search/337725) — **OA** |
| **A03** | *The Monk by the Sea* (c. 1808–10, painting) | Caspar David Friedrich | loneliness, isolation | Silent cell and empty spaces | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Monk_by_the_Sea.jpg) — **OA** |
| **A04** | *The Bedroom* (1888, painting) | Vincent van Gogh | loneliness, isolation | Absence, memory of home | [Art Institute of Chicago](https://www.artic.edu/artworks/28560) — **VERIFY** (`is_public_domain`) |
| **A05** | *The Fortune-Teller* (c. 1630s, painting) | Georges de La Tour | distrust, betrayal, blackhat | Manipulation, hidden motives | [Met](https://www.metmuseum.org/art/collection/search/436838) — **OA** |
| **A06** | *The Railway* (1873, painting) | Édouard Manet | distrust, alienation, trapped | A barrier between observer and subject | [NGA](https://www.nga.gov/artworks/43624-railway) — **OA** |
| **A07** | *Paris Street; Rainy Day* (1877, painting) | Gustave Caillebotte | alienation, loneliness | Crowds with no connection | [Art Institute of Chicago](https://www.artic.edu/artworks/20684) — **VERIFY** (`is_public_domain`) |
| **A08** | *A Sunday on La Grande Jatte — 1884* (1884–86, painting) | Georges Seurat | alienation, distrust | Surveillance disguised as ordinary life | [Art Institute of Chicago](https://www.artic.edu/artworks/27992) — **VERIFY** (`is_public_domain`) |
| **A09** | *The Kiss of Judas* / *The Arrest of Christ* (c. 1304–06, fresco) | Giotto di Bondone | betrayal, distrust, faith | Trust violated; ally as threat | [Commons candidate file](https://commons.wikimedia.org/wiki/File:Kiss_of_Judas_by_Giotto.jpg) — **VERIFY** |
| **A10** | *The Denial of Saint Peter* (1610, painting) | Caravaggio | betrayal, distrust, faith | The cost of a denial | [Met](https://www.metmuseum.org/art/collection/search/437986) — **OA** |
| **A11** | *The Flight into Egypt* (1470s, painting) | Cosmè Tura | escape, faith, survival | Escape by necessity | [Met](https://www.metmuseum.org/art/collection/search/437849) — **OA** |
| **A12** | *Wheat Field with Cypresses* (1889, painting) | Vincent van Gogh | escape, faith, survival | Freedom is near but uncertain | [Met](https://www.metmuseum.org/art/collection/search/436535) — **OA** |
| **A13** | *Bridge over a Pond of Water Lilies* (1899, painting) | Claude Monet | escape, faith | Stillness, a route across an obstacle | [Commons file donated by Met](https://commons.wikimedia.org/wiki/File:Bridge_over_a_Pond_of_Water_Lilies_MET_DT1854.jpg) — **OA-ALT** |
| **A14** | *The Starry Night* (1889, painting) | Vincent van Gogh | escape, confusion, faith | Distant world; turbulent hope | [Commons public-domain reproduction](https://commons.wikimedia.org/wiki/File:Vincent_Van_Gogh_Starry_Night.jpg) — **OA** |
| **A15** | *Cypresses* (1889, painting) | Vincent van Gogh | confusion, isolation, blackhat | Looming silhouette, unstable reality | [Met](https://www.metmuseum.org/art/collection/search/437980) — **OA** |
| **A16** | *The Sleep of Reason Produces Monsters* (1799, aquatint/etching) | Francisco Goya | confusion, distrust, isolation | Paranoia and cognitive uncertainty | [NGA](https://www.nga.gov/artworks/7502-el-sueno-de-la-razon-produce-monstruos-sleep-reason-produces-monsters) — **OA** |
| **A17** | *The Temptation of Saint Anthony* (c. 1550–75, painting) | Anonymous Netherlandish artist; historically associated with Bruegel | confusion, blackhat, faith | Temptation and technological obsession | [NGA](https://www.nga.gov/artworks/41602-temptation-saint-anthony) — **OA** |
| **A18** | *The Gulf Stream* (1899; reworked by 1906, painting) | Winslow Homer | survival, isolation | Hope at the edge of defeat | [Met](https://www.metmuseum.org/art/collection/search/11122) — **OA** |
| **A19** | *The Voyage of Life: Manhood* (1842, painting) | Thomas Cole | survival, faith | Resisting the storm | [NGA](https://www.nga.gov/artworks/52452-voyage-life-manhood) — **OA** |
| **A20** | *The Death of Socrates* (1787, painting) | Jacques-Louis David | defiance, faith | Convictions versus authority | [Met](https://www.metmuseum.org/art/collection/search/436105) — **OA** |
| **A21** | *Joan of Arc* (1879, painting) | Jules Bastien-Lepage | defiance, faith | Courage and a perceived calling | [Met](https://www.metmuseum.org/art/collection/search/435621) — **OA** |
| **A22** | *The Alchemist* (after 1558, engraving) | Pieter Bruegel the Elder (design); Philips Galle (engraving) | blackhat, confusion | Unauthorized experiments; forbidden control | [Met](https://www.metmuseum.org/art/collection/search/366817) — **OA** |
| **A23** | *Under the Wave off Kanagawa* / *The Great Wave* (c. 1830–32, woodblock print) | Katsushika Hokusai | survival, defiance | Peril at overwhelming scale | [Met](https://www.metmuseum.org/art/collection/search/36491) — **OA** |
| **A24** | *Wanderer above the Sea of Fog* (c. 1818, painting) | Caspar David Friedrich | isolation, escape, faith | The view beyond confinement | [Commons high-resolution file](https://commons.wikimedia.org/wiki/File:Caspar_David_Friedrich_-_Wanderer_above_the_Sea_of_Fog.jpeg) — **OA** |
| **A25** | *The Voyage of Life: Old Age* (1842, painting) | Thomas Cole | faith, escape | Release, surrender, salvation | [NGA](https://www.nga.gov/artworks/52453-voyage-life-old-age) — **OA** |
| **A26** | *Saint Jerome in His Study* (1514, engraving) | Albrecht Dürer | faith, isolation | Reflection and quiet purpose | [NGA](https://www.nga.gov/artworks/6642-saint-jerome-his-study) — **OA** |
| **A27** | *The Milkmaid* (c. 1660, painting) | Johannes Vermeer | loneliness, faith, survival | Normal life remembered; a refuge from violence | [Rijksmuseum](https://www.rijksmuseum.nl/en/collection/object/The-Milkmaid--42dd0e658c2979aec8e144d2357c55c0) — **OA** |

### Catalog caveats

1. The original *Starry Night* is public domain; **do not pull the promotional/display image from MoMA's site without clearance**. The Commons file above identifies itself as a public-domain reproduction.
2. The Met's current [*Bridge over a Pond of Water Lilies* page](https://www.metmuseum.org/art/collection/search/437127) does **not** offer a downloadable image. A separately archived image donated under **CC0** is linked at A13; use *that specific file* instead of assuming the current site file is open.
3. The *Temptation of Saint Anthony* linked above is **credited by NGA to an anonymous artist**, not definitively to Pieter Bruegel. Do not credit it as a Bruegel original.
4. The *The Alchemist*, *The Great Wave*, *Saint Jerome in His Study*, *The Round Tower*, and Goya's *The Sleep of Reason Produces Monsters* are prints, not paintings.
5. Historical artworks and their digital reproductions can have different copyright statuses. For entries marked **VERIFY**, confirm the selected *file page* before import. Do not mistake a search result preview for a license.
6. These associations are creative interpretation, not a claim about the painters' intent. Source artwork credit should preserve the correct historical attribution.

## 4. Player behavior → branch selection

### 4.1 Five branches, not five separate game campaigns

| Branch ID | Player tendency | Symbolic meaning | Preferred themes |
|---|---|---|---|
| `ghost` | Remains undetected, bypasses threats, uses blanket concealment | To disappear is to escape | escape, loneliness, isolation |
| `blackhat` | Reprograms cameras, exploits security, controls the prison's technology | The observed becomes the observer | blackhat, distrust, confusion |
| `defiant` | Chooses avoidable direct confrontations; uses aggression when alternatives exist | Resists domination openly | defiance, betrayal, survival |
| `survivor` | Escapes alarms and reaches objectives after near-failure | Endures in spite of fear or injury | survival, trapped, loneliness |
| `seeker` | Inspects paintings, finds hidden clues, explores rather than rushing | Searches for truth, meaning, or faith | faith, betrayal, escape |

`neutral` is the no-signal state when Miro has not yet made enough meaningful choices; it is not a sixth playstyle.

**Important:** Players can be hybrids. One dominant branch is selected per art checkpoint for the jam build; post-jam, use secondary style to affect captions or lighting. Scores are descriptive **behavior profiles**, not a good/evil judgment.

### 4.2 Track real existing gameplay events

Create a run-local `PlayerBehavior` autoload. Subscribe to gameplay signals; don't add special inputs just for the art system. Use each unique encounter/objective only once to prevent farming.

| Event / source | Once-per rule | Score change |
|---|---|---|
| Objective completed without detection/alarm | Once per objective | `ghost += 3` |
| Successfully bypass an optional guard without being spotted | Per unique guard; max three per level | `ghost += 1` |
| Blanket concealment evades an approaching enemy | Per unique encounter; max two per level | `ghost += 1` |
| Successfully reprogram a security camera | Per unique camera; max two per level | `blackhat += 3` |
| Gain control of an optional security console | Once per console | `blackhat += 2` |
| Defeat an **optional** guard through open combat | Per unique guard; max two per level | `defiant += 2` |
| Voluntarily escalate a confrontation when stealth remained possible | Once per encounter; max two per level | `defiant += 2` |
| Survive an alert and successfully escape enemy pursuit | Once per alert sequence; max two per level | `survivor += 2` |
| Finish an objective after a low-health event (≤ 30% health) | Once per objective | `survivor += 2` |
| Inspect a unique art frame | Max two frames per level | `seeker += 1` |
| Discover an optional lore clue | Once per unique clue; max two per level | `seeker += 2` |

**Do not score mandatory actions:** Level 1 requires beating guards; those mandatory enemies should not push every player toward `defiant`. Likewise, the scripted final detonation is not evidence of an aggressive playstyle, because everyone must do it.

**Suggested data contract:**

```gdscript
# PlayerBehavior.gd (autoload interface, illustrative pseudocode)
signal behavior_changed
var style_scores := {
    "ghost": 0,
    "blackhat": 0,
    "defiant": 0,
    "survivor": 0,
    "seeker": 0
}
var rewarded_event_ids := {}  # encounter_id + action -> true
var viewed_art_ids := {}       # art_id -> true
var selected_branch := "neutral"
```

Do **not** award points every frame in `_process()`. Game events should provide stable unique IDs. Clamp per-level rewards according to the table. Debug builds should log exactly *why* each score increased.

### 4.3 Branch decision algorithm

At each `art_checkpoint` (usually after a level objective or before entering a meaningful new room):

1. Total the capped run scores above.
2. If all scores are zero, choose `neutral`.
3. Find the largest score. If there is a **unique** leader, choose it.
4. If there is a tie and the previously selected non-neutral branch is tied for first, retain it.
5. For any other tie, use `neutral` until there is a clear leader.
6. Freeze that checkpoint's result for the rest of the visit. Recalculate only at the next checkpoint.
7. Save `selected_branch`, style scores, event IDs, and assigned artwork IDs in run state if save/load is supported.

**Avoid a feedback loop:** Viewing a painting may slightly increase `seeker`, but never make the art required for progression, and never re-score the same art frame merely because its image changed.

## 5. Art location and branch matrix

Each row is **one reactive frame anchor** located near the end of the listed level. At the associated checkpoint, the artwork is assigned according to the selected behavior branch. Across all possible branches, this matrix references **all 27 unique works** from the catalog.

| Level / anchor ID | Neutral | Ghost | Blackhat | Defiant | Survivor | Seeker |
|---|---|---|---|---|---|---|
| **L1 — Tower Exit** `frame_tower_exit` | A01 *Prisoners Exercising* | A03 *Monk by the Sea* | A22 *The Alchemist* | A20 *Death of Socrates* | A18 *The Gulf Stream* | A26 *Saint Jerome* |
| **L2 — Stealth Corridor** `frame_stealth_hall` | A02 *The Round Tower* | A04 *The Bedroom* | A05 *The Fortune-Teller* | A21 *Joan of Arc* | A07 *Paris Street; Rainy Day* | A27 *The Milkmaid* |
| **L3 — Security Control** `frame_control_room` | A16 *Sleep of Reason* | A06 *The Railway* | A17 *Temptation of Saint Anthony* | A10 *Denial of Saint Peter* | A15 *Cypresses* | A09 *Kiss of Judas* |
| **L4 — Demolition Approach** `frame_c4_route` | A08 *La Grande Jatte* | A11 *Flight into Egypt* | A22 *The Alchemist* | A23 *The Great Wave* | A19 *Voyage of Life: Manhood* | A13 *Bridge over a Pond of Water Lilies* |
| **L5 — Escape Threshold** `frame_final_exit` | A14 *The Starry Night* | A24 *Wanderer above the Sea of Fog* | A15 *Cypresses* | A20 *The Death of Socrates* | A12 *Wheat Field with Cypresses* | A25 *Voyage of Life: Old Age* |

**Creative rationale:**

- **L1 — Beat guards / learn controls:** Miro first sees incarceration or a different response to the first confrontation.
- **L2 — Stealth:** Art reflects absence, deceit, disconnection, or the possibility of ordinary life beyond the walls.
- **L3 — Reprogram cameras:** The prison's gaze is reversed; art focuses on surveillance, uncertain truth, and betrayal.
- **L4 — Plant C4 / stealth or fight:** Pictures shift between ordinary social order, destructive force, flight, and resilience.
- **L5 — Boss / escape / detonation:** The final frame mirrors what surviving the prison has *meant* to this player.

### 5.1 Optional secondary displays (post-jam)

- Put two small nonreactive paintings in each level as fixed environmental props, selected from the same approved pool.
- Add an **archive gallery** in the menu to view unlocked works, title/artist/year, and where the image came from.
- If the player returns after a major incident, replace an earlier neutral painting with a related work; this suggests the prison is watching without forcing another full level branch.
- Consider contextualizing paintings with very short prison-authored labels (e.g., `SUBJECT IS STILL HERE`) separate from the historical artist credit, so no artist is falsely quoted.

## 6. Branch narrative beats

| Branch | Visual progression | Optional ending-panel line (original game copy) |
|---|---|---|
| Ghost | Empty horizons → hidden spaces → solitary wanderer | “They never saw him leave.” |
| Blackhat | Alchemy / manipulation → distorted perceptions → uneasy cypresses | “He learned who was watching.” |
| Defiant | Socrates / Joan of Arc → confrontation with forces greater than the self | “He would not kneel.” |
| Survivor | The endangered figure → storm → an open wheat field | “He remained.” |
| Seeker | Study / everyday life → questions of loyalty → final voyage | “He left with questions.” |
| Neutral | Repetitive prison → crowds and detachment → turbulent sky | “The walls kept their secrets.” |

These are **optional original caption drafts**, not quotations from historical artworks. They should be rewritten if the game's ultimate reveal changes. The jam build only needs changing paintings; do not build branching cutscenes or six full endings before November 10.

## 7. Implementation architecture (Godot)

### 7.1 Files and scenes

```text
res://
  assets/art/
    A01_prisoners_exercising.webp
    A02_round_tower.webp
    ...
    A27_milkmaid.webp
  data/
    art_catalog.json             # id, title, artist, year, themes, image path, attribution
    art_branch_matrix.json       # frame slot -> branch -> artwork id
  scenes/props/
    art_frame.tscn               # frame mesh or Sprite2D + texture surface
  scripts/autoload/
    player_behavior.gd           # score accumulator + unique-event dedup
    art_director.gd              # select branch and apply image
  docs/
    artspec.md
    art_rights_manifest.csv      # local file, rights evidence, date checked, attribution
```

The `.webp` paths above are **planned local filenames**, not created assets. Godot's import pipeline handles image-to-texture import. If the world is 3D, render into the frame material's albedo texture; if 2D, assign the texture to `Sprite2D` or `TextureRect`. Keep art images out of dynamic network requests.

### 7.2 Art catalog schema

```json
{
  "id": "A20",
  "title": "The Death of Socrates",
  "artist": "Jacques-Louis David",
  "year": "1787",
  "medium": "oil on canvas",
  "themes": ["defiance", "faith"],
  "asset_path": "res://assets/art/A20_death_of_socrates.webp",
  "source_url": "https://www.metmuseum.org/art/collection/search/436105",
  "license_status": "verified_public_domain",
  "attribution": "Jacques-Louis David, The Death of Socrates, 1787. The Metropolitan Museum of Art."
}
```

The implementation must validate that every matrix reference points to an actual catalog entry with a local image. On failure, render the `neutral` image for that slot; if that is missing, use a procedural blank-framed placeholder and log an error. **Never crash or block gameplay because a painting is absent.**

### 7.3 Runtime lifecycle

```text
Gameplay event
    ↓
PlayerBehavior: apply capped, unique event score
    ↓
Player reaches art checkpoint
    ↓
ArtDirector: compute branch; consult matrix
    ↓
Assign texture to upcoming frame; cache selection
    ↓
Player enters gallery/corridor and sees the outcome
```

- Build frames as data-driven props; do not duplicate five nearly identical scenes per branch.
- Do not swap textures during a combat animation or directly under the player's camera.
- A room's artwork should remain fixed once seen. If deliberately revisiting the room, change it only after a new story milestone.
- If performance is constrained, preload only images for the current level or resource-load them ahead of entering each room.
- Keep a debug overlay showing `ghost / blackhat / defiant / survivor / seeker`, selected branch, and upcoming artwork ID. Remove it from release builds.

### 7.4 Image and presentation standards

- Download originals from the catalog's **verified image page**, not Google Images thumbnails.
- Keep an archival master outside the game; optimize a playable copy to **1024–2048 px on its longest side**, smaller if the frame is never inspected up close.
- Preserve aspect ratio and include a mat/frame so artwork is never distorted.
- Use a shared visual presentation language: dark antique frames, low-key illumination, restrained labels, and strong contrast against industrial prison geometry.
- Prefer subtle environmental changes (light temperature, angle, dust) over altering historical imagery. If deliberately edited, credit the original and indicate modifications in the project records.
- For a jam, a texture change and a low-key inspection tooltip are enough. Shader glitch, live distortion, and image interpolation are stretch goals.

## 8. Rights and commercial-use workflow

**Goal: All 27 entries can remain in the design; only distributable image files with documented rights enter the commercial build.** The work being old does not automatically clear any random downloadable file.

For every downloaded asset, record:

```text
art_id, original_artist, work_title, institution_or_uploader,
source_object_url, exact_file_url, rights_label, rights_evidence_url,
accessed_date, license_reviewed_by, local_master_filename,
processed_game_filename, modifications, attribution_text
```

**Release gate:**

1. Confirm the selected object/file is marked **Public Domain**, **CC0**, or another license permitting commercial redistribution and modifications (comply with any obligations).
2. Save the exact file-page URL and rights notice/screenshot in project records.
3. Recheck entries marked **VERIFY** in Section 3; they are *not* automatically approved for export.
4. For Art Institute of Chicago works, inspect the artwork API's `is_public_domain` field and its image licensing terms.
5. For Commons works, inspect the **specific file page**, including the file's licensing and photograph/reproduction details. The A09 Giotto file also lists uploader CC BY-SA 4.0/GFDL terms alongside the public-domain reproduction rationale, so resolve the applicable reuse basis before bundling this particular photograph (or choose a clearer CC0 file). For Rijksmuseum, inspect the item's copyright designation.
6. Add voluntary credits when practical; avoid implying museum endorsement or using museum logos.
7. For global distribution, consider country-specific reproduction rights. These status notes are research guidance, not a guarantee for every jurisdiction.

**Official guidance:**

- [Met Open Access FAQ](https://www.metmuseum.org/policies/frequently-asked-questions-image-and-data-resources)
- [National Gallery of Art free images and Open Access](https://www.nga.gov/artworks/free-images-and-open-access)
- [Art Institute of Chicago API rights/public-domain filter](https://api.artic.edu/docs/)
- [Rijksmuseum Collection Online reuse guidance](https://data.rijksmuseum.nl/about/)

## 9. November 7–10 build plan

### Saturday, Nov 7 — mechanism and minimum art pool

- Implement `PlayerBehavior` tracking **stealth, reprogramming, optional combat, survival, and art interaction** through existing event signals.
- Build one reusable `art_frame.tscn` prop.
- Implement `ArtDirector.select_branch()` with neutral fallback.
- Make the **L2 and L3 frame slots** visibly change based on run behavior with a small verified asset subset.
- Confirm no frame change breaks an objective or collision.

### Sunday, Nov 8 — complete and feature-freeze

- Add the remaining three frame anchors (L1, L4, L5) and full matrix data.
- Import as many cleared artworks from the pool as practical; any missing entry falls back cleanly.
- Complete five-level start-to-finish progression; freeze the mechanic before Sunday night.
- Do not build a painting-collection UI, special cutscene, or six gameplay endings for the jam.

### Monday, Nov 9 — test and submit

- Playtest stealth, combat-heavy, camera-hacking, and near-failure runs; inspect both branch scores and selected paintings.
- Verify ties, fresh save, scene transitions, and missing texture fallbacks.
- Test the **exported** Godot build, inspect the license manifest for every actually bundled art image, and prepare jam-page credits.
- Submit early if the jam allows it.

### Tuesday, Nov 10 — buffer only

- Verify download/upload and submission status; fix only emergency issues.

**Definition of done for jam:** five anchored frames; one deterministic branch decision per checkpoint; at least three distinct gameplay paths visibly produce different artwork; no broken references; every bundled artwork has rights evidence; the game remains fully completable. **It is okay if some of the 27 catalog entries are future content rather than shipped art by the jam deadline.**

## 10. Post-jam expansion ideas (out of scope for November 10)

- **Art that remembers:** a painting viewed early returns later changed in placement, crop, or accompanying caption, referencing something the player did.
- **Hybrid themes:** pair a dominant style with a secondary style (`ghost + seeker` yields solitude plus hope; `defiant + blackhat` yields rebellion through surveillance subversion).
- **Hidden lore by study:** let inspection reveal optional fragments about Miro's incarceration, but never make these mandatory for the basic ending.
- **Museum gallery:** an archive unlocks all 27 works over multiple playthroughs with historical credit and source links.
- **Convergent multiple endings:** different imagery and a small epilogue can reflect choices while preserving one canonical escape route and avoiding massive branching level production.
- **Unreliable environment:** frames subtly rearrange between visits as an unsettling suggestion that the prison tracks Miro's decisions.

---

## 11. Acceptance tests

- [ ] All 27 unique titles have a stable ID and one source entry.
- [ ] All 12 requested themes map to at least one piece.
- [ ] Every catalog ID is reachable in the branch matrix across possible playthroughs.
- [ ] Mandatory guard fights and mandatory C4 events never force a branch.
- [ ] Each unique behavior event scores at most once and respects per-level caps.
- [ ] No recorded behavior selects neutral; an unambiguous leading score selects its branch.
- [ ] Scores and art choices persist across scene changes.
- [ ] Every frame has a fallback if its chosen image cannot load.
- [ ] A change is applied at a checkpoint, not mid-combat.
- [ ] At least three playtest styles produce visibly different paintings.
- [ ] Every **shipped** art file has an explicit commercial-use rights review.
- [ ] No third-party logos or unverifiable museum images are bundled.
- [ ] Godot exported build still runs start-to-finish with art system enabled.

**Core takeaway:** The player's route through the game stays manageable, but the paintings become a dynamic language through which the prison comments on Miro's behavior. The same five levels can feel different on multiple playthroughs.
