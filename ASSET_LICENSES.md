# Asset Licenses

## Example MusicXML

`Examples/DoReMiRendererExample/DoReMiRendererExample/sample_melody.musicxml`

- Origin: Original sample created for DoReMiRendererExample.
- Contains copyrighted third party music: No.
- Permitted project use: commercial, test, demo, screenshot, and documentation use
  within DoReMiRendererKit and DoReMiRendererExample.
- Redistribution outside this repository: governed by the repository `LICENSE`
  unless a separate written permission is provided.

## Other Assets

## Bravura SMuFL Font

`Sources/DoReMiRendererKit/Resources/Fonts/Bravura.otf`

- Font name: Bravura
- Version: 1.392, from the upstream Bravura SMuFL metadata.
- Source: Steinberg Bravura repository, https://github.com/steinbergmedia/bravura
- License: SIL Open Font License, Version 1.1.
- License file: `Sources/DoReMiRendererKit/Resources/Fonts/OFL.txt`
- Purpose: SMuFL music-symbol glyph rendering in DoReMiRendererKit.
- Permitted project use: bundled app, SDK example, test, demo, screenshot, and
  documentation use subject to the SIL Open Font License.
- Distribution notes: the font must not be sold by itself. The reserved font
  name "Bravura" must be respected if a derived font is ever created. License
  and notice records must be rechecked before TestFlight, App Store, or other
  external distribution.

## DoReMi Palette Bundled MXL Samples

`Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/`

- `Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl`
- `Ode_to_Joy_Easy_variation.mxl`

- Origin: copied from the local `sample/` replacement set. The local XML copies
  in `sample/github/` match the XML payloads embedded in the bundled MXL files.
- Upstream repository: musetrainer/library,
  https://github.com/musetrainer/library.
- Upstream repository statement: the README and GitHub About describe the
  repository as "Public domain MusicXML files."
- Upstream license-file audit on 2026-05-21: the repository root listed
  `.vscode/`, `README.md`, `index.html`, `poetry.lock`, `pyproject.toml`,
  `scores/`, and `scripts/`; no `LICENSE`, `COPYING`, or `NOTICE` file was
  present. Direct raw checks for `LICENSE`, `COPYING`, and `NOTICE` returned
  404.
- Rights scope: public-domain status of the underlying composition is separate
  from the MusicXML transcription, arrangement, fingering, and export data. The
  bundled files should be treated as third-party score assets and rechecked
  before App Store release or broader redistribution.

### Happy Birthday To You Piano

- TestFlight bundle status: excluded from the DoReMi Palette app bundle and
  user-facing Library as of the 2026-05-21 pre-TestFlight sample rights review.
- Former bundled file: `Happy_Birthday_To_You_Piano.mxl`
- Local source XML: `sample/github/Happy_Birthday_To_You_Piano.xml`
- Local development copy: `sample/Happy_Birthday_To_You_Piano.mxl`
- Upstream file URL:
  https://github.com/musetrainer/library/blob/master/scores/Happy_Birthday_To_You_Piano.mxl
- Upstream raw URL:
  https://raw.githubusercontent.com/musetrainer/library/master/scores/Happy_Birthday_To_You_Piano.mxl
- Metadata audit on 2026-05-21:
  - `work-title`: `Happy Birthday To You`
  - `creator`: `Arranged by Manjuprasad`
  - `rights`: not present
  - `software`: `MuseScore 2.3.2`
  - `encoding-date`: `2018-10-24`
  - `source`: `http://musescore.com/user/27657013/scores/5282628`
- Composition status: the song is widely reported as public domain after the
  2016 U.S. settlement, but jurisdiction and score-data rights remain separate.
- TestFlight classification: excluded / development fixture only. The upstream
  repository claims public-domain MusicXML status, but this file has a named
  arranger and no embedded rights grant, so the conservative pre-TestFlight
  decision is not to ship it in the app bundle. Reconsider only if the
  arrangement and MuseScore export redistribution rights are confirmed.

### Ode to Joy Easy Variation

- Bundled file: `Ode_to_Joy_Easy_variation.mxl`
- Local source XML: `sample/github/Ode_to_Joy_Easy_variation.xml`
- Upstream file URL:
  https://github.com/musetrainer/library/blob/master/scores/Ode_to_Joy_Easy_variation.mxl
- Upstream raw URL:
  https://raw.githubusercontent.com/musetrainer/library/master/scores/Ode_to_Joy_Easy_variation.mxl
- Metadata audit on 2026-05-21:
  - `work-title`: not present
  - `movement-title`: not present
  - `creator`: not present
  - `rights`: not present
  - `software`: `MuseScore 2.3.2`
  - `encoding-date`: `2020-12-22`
  - `source`: not present
- Composition status: Beethoven's underlying composition is public domain, but
  this easy-variation MusicXML/export data still lacks an embedded rights grant.
- TestFlight classification: acceptable with caution for internal TestFlight,
  based on the upstream public-domain repository statement. Recheck before App
  Store release.

### Fur Elise - Beginner Piano

- Bundled file: `Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl`
- Local source XML:
  `sample/github/Fur_Elise_-_Beethoven_-_for_beginner_piano.xml`
- Upstream file URL:
  https://github.com/musetrainer/library/blob/master/scores/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl
- Upstream raw URL:
  https://raw.githubusercontent.com/musetrainer/library/master/scores/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl
- Metadata audit on 2026-05-21:
  - `work-title`: not present
  - `movement-title`: not present
  - `creator`: not present
  - `rights`: not present
  - `software`: `MuseScore 3.6.1`
  - `encoding-date`: `2021-02-23`
  - `source`: `https://musescore.com/classicman/scores/33816`
- Composition status: Beethoven's underlying composition is public domain, but
  the beginner arrangement and MusicXML/export data still lack an embedded
  rights grant.
- TestFlight classification: acceptable with caution for internal TestFlight,
  based on the upstream public-domain repository statement. Recheck the
  arrangement/source-score redistribution rights before App Store release.

## DoReMi Palette Import QA Fixtures

`Apps/DoReMiPalette/TestImportFiles/`

- Origin: Original short MusicXML fixtures created for Phase 13 import QA.
- Contains copyrighted third party music: No.
- Included files: `.musicxml`, `.xml`, generated `.mxl`, invalid MusicXML, and
  unsupported-extension text fixture.
- Permitted project use: commercial, test, demo, screenshot, and documentation
  use within DoReMiRendererKit and DoReMiPalette.
- Redistribution outside this repository: governed by the repository `LICENSE`
  unless a separate written permission is provided.

## DoReMi Palette Expression MVP Sample

`Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/articulation_dynamics_coverage_sample.musicxml`

- Origin: Original short MusicXML fixture created in this repository for the
  Articulation / Dynamics MVP.
- Contains copyrighted third party music: No.
- Includes: staccato, accent, tenuto, strong-accent, upward/downward flagged
  fermata, fermata rest, dynamic marks, same-measure and cross-measure
  crescendo / decrescendo, and basic collision-lane coverage for visual and
  playback QA.
- Permitted project use: commercial, test, demo, screenshot, app build, and
  documentation use within DoReMiRendererKit and DoReMiPalette.
- Redistribution outside this repository: governed by the repository `LICENSE`
  unless a separate written permission is provided.

## DoReMi Palette D.S. / Coda Behavior Sample

`Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/ds_coda_behavior_sample.musicxml`

- Origin: Original short MusicXML fixture created in this repository for
  D.S. / Coda visual and playback QA.
- Contains copyrighted third party music: No.
- Includes: symbolic `<segno/>`, `To Coda`, `D.S. al Coda`, symbolic
  `<coda/>`, and a short original melody designed to make playback order easy
  to verify.
- Expected playback path: measures 1, 2, 3, 4, then D.S. back to 1, continue
  through 2 and 3, jump To Coda, then measures 5, 6, and 7.
- Permitted project use: commercial, test, demo, screenshot, app build, and
  documentation use within DoReMiRendererKit and DoReMiPalette.
- Redistribution outside this repository: governed by the repository `LICENSE`
  unless a separate written permission is provided.

## DoReMi Palette App Icon

`Apps/DoReMiPalette/DoReMiPalette/Resources/DoReMi_icon.png`

`Apps/DoReMiPalette/DoReMiPalette/Assets.xcassets/AppIcon.appiconset/`

- Origin: User-provided app icon asset from
  `/Users/keetane/Downloads/DoReMi_icon.png`, resized into iOS app icon slots
  for DoReMi Palette.
- Contains copyrighted third party music: No.
- Permitted project use: commercial, test, demo, screenshot, app build, and
  documentation use within DoReMiRendererKit and DoReMiPalette, subject to the
  user's ownership or permission for the provided source image.
- Redistribution outside this repository: governed by the repository `LICENSE`
  and any separate rights attached to the user-provided source image.

## MXL Test Fixture

`Tests/DoReMiRendererKitTests/MXLLoaderTests.swift` creates an in-memory `.mxl`
fixture from original MusicXML test data.

- Origin: Original test melody created for DoReMiRendererKit.
- Contains copyrighted third party music: No.
- Permitted project use: commercial, test, demo, screenshot, and documentation use
  within DoReMiRendererKit and DoReMiRendererExample.
- Redistribution outside this repository: governed by the repository `LICENSE`
  unless a separate written permission is provided.

## Snapshot Fixtures And Baselines

`Tests/DoReMiRendererKitTests/SnapshotTesting/SnapshotFixtures.swift`
contains original MusicXML snippets used to render snapshot baselines, including
Phase 11F lyrics/fingering and key signature fixtures.

`Tests/DoReMiRendererKitTests/__Snapshots__/`

- Origin: Generated by DoReMiRendererKit from original snapshot fixture MusicXML.
- Contains copyrighted third party music: No.
- Permitted project use: commercial, test, demo, screenshot, and documentation use
  within DoReMiRendererKit and DoReMiRendererExample.
- Redistribution outside this repository: governed by the repository `LICENSE`
  unless a separate written permission is provided.

No additional non-code assets are included in MVP0.

## Phase 17B TestFlight Readiness Audit

As of the bundled MXL sample replacement, app sample assets are the
user-provided MXL files listed above, the user-provided DoReMi Palette app icon,
and the Bravura 1.392 SMuFL font under the SIL Open Font License. No GPL/LGPL
asset or dependency is intentionally included.
