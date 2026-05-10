# SMuFL Integration Plan

This document records the planned SMuFL music font integration for
DoReMiRendererKit and DoReMi Palette. It is a planning document only: no font
file, renderer change, Info.plist change, snapshot baseline update, or public
API change is part of this step.

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

### Phase S6: Tie / Slur / Beam Refinement

Purpose:

- Improve remaining Core Graphics path symbols after glyph rendering stabilizes.

Work:

- Refine tie curves.
- Refine slur curves.
- Improve beam grouping.
- Improve stem direction.
- Add minimal collision improvements where safe.

Completion:

- The notation coverage sample shows tie, slur, and beam behavior clearly
  enough for MVP learning use, while advanced engraving remains future work.

## Relationship To QA Samples

- `notation_coverage_grand_staff.musicxml` is the before/after comparison score
  for SMuFL symbol rendering.
- `rhythm_values_sample.musicxml` remains the before/after comparison score for
  note values and generated-tone playback timing.
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

## Not In This Planning Step

- Do not add Bravura or any other font file.
- Do not change `Info.plist`.
- Do not change renderer code.
- Do not update snapshot baselines.
- Do not change implementation code.
- Do not change public API.
- Do not add external dependencies.
