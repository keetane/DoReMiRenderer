# MusicXML Compatibility

This document is the primary design note for Phase 11F advanced MusicXML
compatibility work.

## Phase 11F Scope

Phase 11F expands MusicXML handling beyond the MVP0 subset while preserving the
core architecture: the parser reads MusicXML, domain models hold music meaning,
layout computes all coordinates, rendering consumes only `ScoreLayout`, styling
resolves colors, interaction hit-tests layout elements, and playback remains
independent of SwiftUI and rendering.

Unsupported elements must produce diagnostics instead of silent failure. Real
MusicXML files used for validation are local/private inputs only. Public test
fixtures must be short self-authored MusicXML snippets that reproduce a feature
without copying copyrighted score content.

## Phase 11F Plan

### 11F-1 Diagnostics Collection

Purpose: scan private `.musicxml`, `.xml`, and `.mxl` sample sets and aggregate
parse diagnostics without storing score contents.

Completion criteria:

- ignored local input directory policy exists
- diagnostics executable can scan recursively
- missing input directory is a successful skip
- `MUSICXML_COMPATIBILITY_REPORT.md` is generated without MusicXML contents
- scanner/report tests cover success, failure, aggregation, and skipped input

### 11F-2 Lyrics And Fingering

Purpose: read `<lyric>` and `<notations><technical><fingering>`, attach them to
notes, create annotation layout elements, draw them from layout coordinates, and
make them hit-testable.

Completion criteria:

- parser stores lyric and fingering annotation data on `ScoreNote`
- layout emits `.lyric` and `.fingering` elements with stable IDs
- renderer draws annotation text from `ElementLayout.annotation`
- hit testing returns associated `NoteID`
- unit tests and iOS snapshots cover basic lyrics/fingering

### 11F-3 Key Signature And Accidental Stability

Purpose: improve key signature layout while preserving accidental and color-rule
responsibility boundaries.

Completion criteria:

- `<key><fifths>` and `<key><mode>` remain parsed into `KeySignature`
- layout emits `.keySignature` elements for treble/bass staves
- key signature coordinates are layout-derived
- renderer draws key signature glyphs as layout elements
- ColorRule changes do not alter layout or playback identity

### 11F-4 Tempo And Repeat Metadata

Purpose: read tempo and repeat metadata for future playback without implementing
audio playback or repeat expansion.

Completion criteria:

- `<sound tempo="">` produces `TempoEvent`
- repeat barlines produce `RepeatBarline`
- unsupported repeat expansion emits diagnostics
- playback event order and grouping are unchanged
- metadata is available through the facade

### 11F-5 Complex MusicXML Diagnostics

Purpose: avoid silent failure for tuplets, slurs, ornaments, grace notes,
cross-staff/staff changes, transposition, and complex voice collisions.

Completion criteria:

- tuplets keep MusicXML duration timing and warn about rendering
- slur, ornament, grace, transposition, and beam limitations have specific codes
- layout reports complex voice collision and cross-staff notation limitations
- grace notes are not treated as normal playback events
- unsupported diagnostics are specific enough for prioritization

## Local Sample Policy

Keep third-party or private scores outside source control. The default local input directory is:

```text
LocalSamples/
```

`LocalSamples/` is ignored by git. Do not commit private samples, licensed scores, generated sample archives, or report files that reveal private path names unless they have been reviewed for release.

The diagnostics report records file paths, diagnostic severities, diagnostic codes, locations, and messages only. It does not include MusicXML score contents.

## Run

```sh
swift run DoReMiRendererDiagnostics \
  --input LocalSamples \
  --output MUSICXML_COMPATIBILITY_REPORT.md
```

If the input directory does not exist, the command writes a skipped report and exits successfully.

## Scan Scope

The scanner searches recursively for:

- `.musicxml`
- `.xml`
- `.mxl`

No MusicXML feature expansion is implemented in Phase 11F-1. The executable only loads samples through the existing parser facade and aggregates diagnostics.

## Aggregation

The report includes:

- files scanned
- diagnostics found
- counts by severity
- counts by severity and code
- per-file diagnostic code summaries
- diagnostic details without score contents

## Priority Rules

High priority diagnostics affect onset, NoteID stability, staff/voice/chord
interpretation, pitch/accidental/key/transposition correctness, layout
coordinates, or playback event grouping.

Medium priority diagnostics affect display quality but can safely remain as
warnings in Phase 11F, including lyrics, fingering, key signature display,
tempo metadata, repeat metadata, slur display, and tie display refinement.

Low priority diagnostics cover ornament details, publishing-quality engraving,
decorative text, advanced beams, and other notation details that do not affect
identity, timing, or basic display correctness.

## Fixture Extraction Policy

Do not copy measures from real/private MusicXML files into tests. When a private
sample reveals a missing feature, create a new short self-authored fixture that
only reproduces the needed MusicXML element. Record public fixtures in
`ASSET_LICENSES.md`.
