# SMuFL Integration Plan

This document records the SMuFL music font integration plan and implementation
status for DoReMiRendererKit and DoReMi Palette. S1-S5 are implemented; S6
remains planned.

## Purpose

DoReMiRendererKit currently draws score symbols with SwiftUI Canvas and Core
Graphics shapes. That keeps `NoteID`, `ScoreElementID`, `ScoreLayout`, hit
testing, color rules, and playback stable, but the visual quality of music
symbols is still MVP-level.

SMuFL-compliant fonts are planned as a way to improve symbol shapes for:

- treble clefs
- bass clefs
- rests
- accidentals
- repeat symbols
- dynamics
- flags
- noteheads
- time signature digits
- articulation symbols

SMuFL is not a score layout engine. MusicXML parsing, domain meaning,
coordinates, IDs, hit testing, color resolution, and playback event generation
remain owned by DoReMiRendererKit.

## Candidate Fonts

### Primary Candidate: Bravura

- SMuFL-compliant music font.
- Distributed under the SIL Open Font License.
- Commercial app bundling must be re-checked before external distribution.
- Font files must not be sold by themselves.
- Derived font naming and Reserved Font Name conditions must follow the OFL.
- The exact version, source URL, license, and redistribution notes must be
  recorded before the font is added.

### Alternative Candidates

- Leland
- Petaluma
- Other SMuFL-compliant fonts

Early implementation should treat Bravura as the first candidate and keep other
fonts as comparison options unless licensing, rendering, or bundle integration
issues require a change.

## Legal And License Policy

- Verify the chosen font license before adding any font file.
- Record bundled font assets in `ASSET_LICENSES.md`.
- Record font name, version, license, and distribution source in
  `THIRD_PARTY_NOTICES.md`.
- Include or link the SIL Open Font License text as required by the license.
- Do not sell the font by itself.
- Follow OFL conditions if any derived font is ever created.
- Re-check license, asset, and third-party notices before TestFlight, App Store,
  or external SDK distribution.
- This document is project planning, not legal advice; obtain expert review
  when needed before external distribution.

## Technical Architecture

```text
MusicXML
  -> Parser
  -> Domain Model
  -> ScoreLayout / ElementLayout
  -> ScorePainter
  -> SMuFL glyph + Core Graphics path
  -> SwiftUI Canvas
```

Responsibilities:

Parser:

- Reads MusicXML symbol meaning such as clefs, rests, accidentals, repeats,
  dynamics, and articulations.
- Passes music meaning into the domain model.
- Does not own drawing coordinates.

Domain:

- Stores music meaning.
- Keeps MusicXML meaning separate from visual style.
- Should not generally store SMuFL codepoints directly.

Layout:

- Creates `ElementLayout` records for symbols.
- Generates stable `ScoreElementID` values.
- Owns coordinates, frames, glyph anchors, and related `NoteID` references.
- Remains the only source of drawing coordinates even when glyphs are used.

Renderer:

- Consumes `ScoreLayout`, `NoteLayout`, and `ElementLayout`.
- Draws the requested SMuFL glyph or Core Graphics path at layout coordinates.
- Does not read MusicXML.
- Does not infer coordinates.
- Does not own color-rule decisions; it follows `ScoreStyle` and
  `ScoreColorResolver`.

App:

- Uses `ScoreCanvasView` and SDK public read models.
- Does not manage glyph maps or font rendering internals.
- Does not reparse MusicXML or reinterpret SMuFL glyphs.

The existing rules remain unchanged: no SVG DOM parsing, no WebView rendering
path, no app-side coordinate inference, and no `NoteID` regeneration.

## Core Graphics Note-Value Hotfix

Before SMuFL font integration, DoReMiRendererKit uses a Core Graphics hotfix for
basic learning readability:

- `NoteValueKind` stores whole, half, quarter, eighth, sixteenth, and fallback
  note-value meaning from MusicXML `<type>` or duration fallback.
- Layout emits notehead, stem, flag, dot, and rest elements with stable
  `ScoreElementID` values.
- Whole notes use hollow noteheads with no stem.
- Half notes use hollow noteheads with a stem.
- Quarter notes use filled noteheads with a stem.
- Eighth notes use filled noteheads with a stem and flag.
- Dots and common rest values are layout elements.
- Stem direction is MVP single-voice logic: notes below the middle staff line
  use upward stems, and notes on or above the middle staff line use downward
  stems.
- Chord tones in the same part/measure/staff/voice/onset share one MVP stem
  direction before rendering. This remains a layout responsibility and should
  continue to feed SMuFL notehead/flag glyph selection later.
- Current-note scroll follow is independent of SMuFL. It is driven by
  `ScoreLayout.noteByID` and layout-coordinate anchors, not glyph bounds or
  rendered image analysis.

This hotfix is intentionally shaped so the same domain/layout meaning can feed
Phase S5 SMuFL glyph selection later. SMuFL should replace the visual glyph
shapes, not the `ScoreLayout` coordinates, IDs, hit testing, color rules, or
playback semantics.

## Drawing Split

### SMuFL Glyph Candidates

- treble clef
- bass clef
- alto / tenor clef in the future
- sharp
- flat
- natural
- double sharp / double flat in the future
- whole rest
- half rest
- quarter rest
- eighth rest
- sixteenth rest
- repeat dots
- dynamic symbols such as `p`, `mf`, and `f`
- time signature digits
- notehead glyphs
- flag glyphs
- articulation marks

### Core Graphics Path Candidates

- staff lines
- ledger lines
- stems
- beams
- ties
- slurs
- current-note highlight
- selection overlay
- colored staff lines
- measure and system bounds
- simple barlines

### Mixed Policy

- Noteheads may remain Core Graphics shapes at first if that keeps IDs,
  hit-test frames, and color handling stable.
- Clefs, rests, accidentals, repeats, and dynamics are safer first glyph
  migration targets.
- Ties and slurs should remain Core Graphics curves rather than SMuFL glyphs.
- Beam grouping should be improved as Core Graphics paths after basic glyph
  rendering is stable.

## Implementation Phases

### Phase S1: SMuFL Integration Preparation

Purpose:

- Decide the first font candidate.
- Confirm license and redistribution requirements.
- Define bundle placement and glyph mapping.
- Plan snapshot and fallback behavior.

Work:

- Confirm whether Bravura is acceptable.
- Decide font file placement.
- Plan `Info.plist` `Fonts provided by application` updates.
- Design `SMUFLGlyph` or an equivalent internal glyph map.
- Plan `ASSET_LICENSES.md` and `THIRD_PARTY_NOTICES.md` updates.
- Define baseline update rules for symbol snapshots.

Completion:

- License, placement, glyph map, fallback, and snapshot-update policies are
  documented before implementation begins.

### Phase S2: SMuFL Font Registration

Purpose:

- Make the selected SMuFL font available to the iOS app and SDK Example.

Work:

- Add the font file.
- Include it in app bundles.
- Update `Info.plist`.
- Verify Core Text / SwiftUI Canvas font lookup.
- Add a fallback path for font loading failure.
- Record license and asset notices.

Completion:

- A test glyph can be drawn on Canvas.
- Snapshot tests confirm the glyph appears or the fallback path is used.

### Phase S3: Clef / Accidental / Rest Glyph Rendering

Purpose:

- Render treble clef, bass clef, accidentals, and rests with SMuFL glyphs.

Work:

- Map clef glyphs.
- Map accidental glyphs.
- Map rest glyphs.
- Adjust glyph anchors from layout data.
- Preserve note, staff, and accidental color behavior.
- Update snapshots intentionally.

Completion:

- `notation_coverage_grand_staff.musicxml` shows clefs, accidentals, and rests
  with music-font glyphs.

### Phase S4: Repeat / Dynamics / Time Signature Glyph Rendering

Purpose:

- Improve repeat symbols, dynamics, and time signature digits.

Work:

- Draw repeat dots with barline combinations.
- Draw dynamics such as `p`, `mf`, and `f`.
- Draw time signature digits.
- Adjust spacing while keeping layout as the coordinate source.
- Update snapshots intentionally.

Completion:

- The notation coverage sample shows repeat, dynamics, and time signatures in a
  recognizable music-font style.

### Phase S5: Notehead / Flag Glyph Rendering

Purpose:

- Improve notehead and flag shapes while preserving hit-test and color
  behavior.

Work:

- Map whole, half, quarter, and eighth noteheads.
- Map flag glyphs.
- Preserve filled / hollow semantics.
- Preserve `NoteID`, `ScoreElementID`, and hit-test frames.
- Keep note colors readable for filled and hollow noteheads.
- Update snapshots intentionally.

Completion:

- `rhythm_values_sample.musicxml` clearly distinguishes whole, half, quarter,
  and eighth notes.

## Phase S1-S5 Implementation Status

S1 through S5 are implemented in the SDK renderer path.

- Adopted font: Bravura 1.392.
- License: SIL Open Font License 1.1, with the bundled text in
  `Sources/DoReMiRendererKit/Resources/Fonts/OFL.txt`.
- Placement: `Sources/DoReMiRendererKit/Resources/Fonts/Bravura.otf`, bundled
  as a Swift Package resource so DoReMi Palette and the SDK Example use the
  same renderer asset.
- Registration: `SMuFLFont` registers Bravura with Core Text at process scope.
  If registration or resource lookup fails, `ScorePainter` falls back to the
  existing Core Graphics/simple text shapes.
- Glyph map: `SMuFLGlyph` maps clefs, accidentals, rests, repeat dots, time
  signature digits, noteheads, and flags.
- Renderer behavior: `ScorePainter` selects glyphs from `ElementLayout` /
  `NoteLayout` meaning data. Parser, domain, app UI, playback, hit testing, and
  scroll follow do not interpret SMuFL codepoints.
- Size policy: `SMUFLGlyphSizePolicy` keeps glyph sizing internal to the SDK
  renderer. The current readability pass scales noteheads, accidentals, rests,
  flags, clefs, repeat dots, and time-signature digits by category while
  preserving `ScoreLayout` as the coordinate source. Whole/half/black
  noteheads use a close visual scale so common note values do not appear
  mismatched; the latest tuning makes noteheads larger for iPad learning
  readability, shortens stems further, uses direction-specific flag glyphs near
  stem ends, pulls note accidentals closer to noteheads, gives rests a more
  consistent readable size, and keeps clef/key/time prefix spacing wide enough
  to avoid overlap.
- Layout frames: notehead, accidental, flag, clef, key signature, and time
  signature frames are expanded or spaced only enough to keep glyph placement,
  hit testing, clipping, and snapshot rendering aligned with the visible glyphs.
- `Info.plist`: no app-level font declaration is required for this phase
  because the SDK registers the package resource explicitly with Core Text.
- Dynamics: still diagnostic-only unless represented by existing text
  annotations. Full dynamic layout/rendering remains outside S1-S5.

### Phase S6: Tie / Slur / Beam / Tuplet Refinement

Status: implemented at MVP quality for the Phase S6 QA sample.

Purpose:

- Improve remaining Core Graphics path symbols after glyph rendering stabilizes.
- Add a focused grand-staff QA sample for tie, slur, beam, triplet, and basic
  collision review.

Work:

- Render same-system tie curves from layout elements.
- Render same-system slur curves from layout elements.
- Infer safe MVP beam groups for adjacent flagged notes in the same
  measure/staff/voice, with rests and unsafe changes breaking groups.
- The S6 follow-up tuning orients tie/slur curves to the opposite stem side and
  carries explicit beam start/end segments so beams connect from stem tip to
  stem tip.
- Mixed eighth/sixteenth beam groups use a primary beam plus MVP secondary
  beam segments for adjacent sixteenth-note runs.
- Render basic triplet brackets and number `3` for simple same-measure tuplet
  groups.
- Add the self-authored `S6 Notation Refinement Sample` and make it the current
  default app launch sample while retaining all previous bundled samples.
- Add minimal spacing/bounds checks where safe.

Completion:

- The S6 notation refinement sample shows tie, slur, beam, and triplet behavior
  clearly enough for MVP learning use, while advanced engraving remains future
  work.

Remaining S6 limitations:

- System-crossing tie/slur curves are not fully engraved.
- Advanced beam slope, cross-staff beaming, nested beam groups, and multi-voice
  beam collision handling remain future work.
- Tuplet support targets basic 3:2 groups; nested, complex, and system-crossing
  tuplets remain limited.
- Collision avoidance is still pragmatic spacing, not a full engraving engine.

## Relationship To QA Samples

- `notation_coverage_grand_staff.musicxml` is the before/after comparison score
  for SMuFL symbol rendering.
- `rhythm_values_sample.musicxml` remains the before/after comparison score for
  note values and generated-tone playback timing.
- `s6_notation_refinement_grand_staff.musicxml` is the focused default QA score
  for Phase S6 tie/slur/beam/triplet checks.
- SMuFL phases will likely require snapshot baseline updates.
- Baselines must be updated only after confirming the diff is an intentional
  visual improvement.
- Existing bundled samples, Library / Recent files, playback, practice mode,
  diagnostics, and app settings must remain unaffected.

## Phase 16.5 And Phase 17 Relationship

Phase 16.5 keeps the current Core Graphics renderer as the stabilization
baseline before any SMuFL snapshot churn. The current `NoteValueKind`,
notehead/stem/flag/rest layout elements, layout bounds, scroll follow, and
attack/continuation highlight behavior must remain valid when SMuFL glyphs are
introduced later.

SMuFL is not required for Phase 17 or TestFlight preparation unless it is chosen
as a separate notation-quality track. Phase 17 can proceed with the Core
Graphics MVP renderer if `APP_QA_CHECKLIST.md` and `NOTATION_SUPPORT_MATRIX.md`
accurately describe the remaining notation limits.

## Test Policy

Unit tests:

- glyph mapping tests
- fallback glyph tests
- clef, rest, and accidental mapping tests
- unknown glyph fallback tests
- color application tests
- layout identity unchanged when glyph rendering changes

Snapshot tests:

- notation coverage grand staff
- rhythm values sample
- clef / rest / accidental specific cases
- note color ON/OFF
- staff color ON/OFF

App tests:

- sample catalog remains valid
- `ScoreCanvasView` still renders
- Library / Recent files are unaffected
- Playback and Practice Mode are unaffected

## Stop Conditions

Stop and redesign before implementation if:

- SMuFL requires abandoning `ScoreLayout` coordinates.
- Renderer would need to read MusicXML.
- App code would need to reinterpret MusicXML or glyphs.
- `NoteID` or `ScoreElementID` stability would be lost.
- Hit-test frames would drift materially from drawn symbols.
- Snapshot diffs are too broad to confirm as intentional.
- Font license terms are not suitable for commercial app or SDK distribution.
- GPL/LGPL dependencies become necessary.
- Font loading is not stable on iOS.

## Not In S1-S5 Implementation

- Phase S6 tie/slur/beam refinement, Phase S7 repeat playback expansion,
  Phase S8 repeat-ending playback hardening, and Phase S9 repeat-ending visual
  bracket rendering are separate tracks from SMuFL glyph
  adoption. They keep the same `ScoreLayout` coordinate source and do not move
  notation interpretation into the app.
- Do not replace `ScoreLayout` coordinates or hit-test frames.
- Do not move glyph selection into the app.
- Do not add external rendering engines or GPL/LGPL dependencies.
