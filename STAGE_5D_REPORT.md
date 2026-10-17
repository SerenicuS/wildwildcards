# Stage 5D — Expanded Character Customization

Implemented in the existing shared procedural character renderer, menu and profile architecture. Godot 4.7.2 imports and launches the project without script/resource errors.

## Changes

- Six hats: original Drifter, Wide Brim and Gambler retained; new Cattleman, Outlaw and Cavalry silhouettes.
- Five outerwear styles: Frontier Jacket, Long Duster, Western Poncho, Gambler Waistcoat and Outlaw Coat. Waistcoat includes a narrower cut and contrasting shirt sleeves; coats have different hems/lapels.
- Original None, Bandana and Sheriff Badge retained; Neckerchief, Decorative Belt and Gloves added. The existing single accessory slot is the compatibility rule: selecting one replaces the previous accessory. Gloves follow both animated hands.
- Eleven outfit colors, including all four original colors and Black, Brown, Tan, Dark Red, Navy, Forest Green and Cream. Hat/accessory tint selectors offer the seven curated colors and Original, which preserves legacy artwork. Hatbands retain the outfit accent.
- Existing Customize preview and Equip/Cancel flow extended with Clothing & Colors and Outfit Presets pages. All clothing and revolvers use the same combat/Profile/WANTED portrait renderer. Maximum-length preset names stay inside the menu.
- Up to five named presets store the complete sanitized appearance, including revolver model/finish/grip. Save New snapshots the draft; Load previews without equipping; Rename and confirmed Delete save immediately. Presets intentionally exclude elimination effects.
- Saved-profile and separate Local P1/P2 targets share the same cosmetic data. Local clothing/gun overrides remain in memory, survive rematches and never equip the primary saved profile. P1 follows the saved profile until overridden; P2 retains its existing default look.
- Gauntlet generation draws expanded valid cosmetics from the shared catalogs using its existing cosmetic RNG.
- Profile schema 4 adds `outfit_style`, `hat_color`, `accessory_color` and a bounded `outfit_presets` array. Existing `outfit` remains the color ID. Versions 1–3 retain identity, old cosmetics, guns, statistics, finisher, Gauntlet records and reset revisions. Transactional writes and backup recovery are retained. Statistics reset preserves presets; full profile reset clears them and refreshes the recovery backup.

Combat resolution, bot decisions/personality, turn timing, controls, arena selection/progression, audio, display configuration and finisher behavior were not changed.

## Files changed for this stage

| File | Purpose |
| --- | --- |
| `scripts/CharacterAppearance.gd` | Expanded catalogs, defaults, validation and shared random cosmetic generation |
| `scripts/Arena.gd` | Shared hat/outerwear/accessory/tint rendering and animated gloves |
| `scripts/MainMenu.gd` | Clothing/colors, local targets, presets, preview and confirmed deletion |
| `scripts/ProfileManager.gd` | Schema 4 migration, transactional preset APIs and reset preservation |
| `scripts/GameManager.gd` | Apply the complete independent local appearances |
| `scripts/GauntletRun.gd` | Use shared expanded cosmetic generator |
| `tests/test_expanded_appearance_data.gd` | Migration, presets, rollback, resets, corruption, restart and randomization |
| `tests/test_expanded_appearance.gd` | Native rendering, menu interaction, portraits and mode integration |
| `tests/test_expanded_appearance_performance.gd` | Five-style Compatibility-renderer benchmark |
| Corresponding new test `.gd.uid` files | Godot-generated script identities |
| `README.md` | Current customization, persistence, local targets and test instructions |
| `STAGE_5D_REPORT.md` | This implementation/test report |

Other existing working-tree changes from earlier stages were retained.

## Validation performed

All final runs below passed with zero failures. Test save/settings fixtures are isolated under `.godot/`; the player's real profile and settings were not used.

| New test | Checks | Coverage |
| --- | ---: | --- |
| `test_expanded_appearance_data.gd` | 231 | Versions 1–3, old backup bytes preserved, all five slots, capacity guard, rename/delete, independent snapshots, failed-save rollback, safe reset recovery, malformed fields, 200 generated opponents |
| Same data test with `--verify` in a fresh process | 3 | Equipped clothing/colors and preset/revolver persistence |
| `test_expanded_appearance.gd` | 55 | Frozen rendered pixel distinction for every catalog option, tint isolation, layout bounds including long names, Equip/Cancel, preset UI, explicit deletion confirmation/cancel callbacks, separate local appearance, mirrored muzzle positions for every outerwear style, stable node counts, Solo/Gauntlet/Profile/WANTED integration |
| `test_expanded_appearance_performance.gd` | 10 | Stable nodes and frame budget for all five outerwear styles with shots/shields |

**299 Stage 5D checks passed.** Native confirmation-dialog callbacks were exercised directly; ordinary menu controls were exercised with synthesized mouse events.

Existing regression suites also passed: profile data (1,049), profile UI (26), developer resets (51), revolvers (117), menu (63), multiplayer (57), combat visuals (101), elimination effects (50), arenas (242), Gauntlet data (1,271), Gauntlet integration (48), Gauntlet edge cases including rapid transitions (115), difficulty/timing (86), flow (21), fullscreen (17), audio (67), turn tick (25), bot personalities (25,308), combat rules (23,739). Total: **52,453 regression checks**.

Final headless editor import succeeded. Screenshots of Customize, Clothing, Presets, Profile, Local and the complete cosmetic gallery were captured under `.godot/expanded_*.png` and visually reviewed.

### Performance sample

Native Compatibility renderer on Intel UHD Graphics 630, production 60 FPS cap, two fighters with combat effects, 90 measured frames per style after warmup:

| Style | Average frame time | Average draw calls |
| --- | ---: | ---: |
| Frontier Jacket | 16.67 ms | 93.5 |
| Long Duster | 16.89 ms | 101.5 |
| Western Poncho | 16.70 ms | 99.5 |
| Gambler Waistcoat | 16.67 ms | 105.5 |
| Outlaw Coat | 16.69 ms | 101.5 |

No additional scene nodes accumulated. New cosmetics use native polygons, lines and rectangles without textures, shaders or particle systems.

## Limitations

- The existing artwork is small and geometric. Clothing silhouettes are intentionally simple; fine details are easiest to inspect in the larger WANTED portrait or enlarged revolver preview.
- One accessory can be equipped at a time. Layered combinations such as badge plus gloves are not part of this stage.
- Presets are shared local-profile snapshots; they do not save elimination effects or independently persist guest profiles. Local target equipment is session-only.
- Performance was sampled on the available Intel UHD 630 device, not every low-end GPU or display configuration.
