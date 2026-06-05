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

### 11F-4 Tempo Metadata And Phase S7/S8 Repeat Playback

Purpose: read tempo and repeat metadata, and expand simple repeat playback
sections without changing `ScoreDocument` or `ScoreLayout`.

Completion criteria:

- `<sound tempo="">` produces `TempoEvent`
- repeat barlines produce `RepeatBarline`
- simple forward/backward repeat sections expand in `PlaybackSequenceBuilder`
  for two passes
- unsupported repeat structures emit diagnostics
- non-repeat playback event order and grouping are unchanged
- metadata is available through the facade
- score titles are taken from non-placeholder movement/work titles first, then
  MusicXML `<credit-type>title</credit-type>` / `<credit-words>` metadata when
  work and movement titles are absent

S7/S8/S9 repeat playback and visual MVP support:

- Supported: one or more simple, non-nested forward/backward repeat sections.
- Supported in Phase S8: one clear first/second ending repeat section.
- Supported in Phase S9: same-system first/second ending bracket and number
  rendering from layout elements.
- Supported in Phase S8: basic D.C. al Fine expansion only for jump-only scores
  without repeats/endings.
- Fallback: a backward repeat without a start repeats from the beginning and
  emits `repeat.startMissingFallback`.
- Diagnostic-only: unmatched starts, nested repeats, repeat counts outside the
  MVP two-pass behavior, third endings, ambiguous endings, mixed repeat/jump
  structures, and complex jumps. Clear D.C./D.S./Fine/Coda jump-only scores,
  including symbolic MusicXML `<segno/>` / `<coda/>` and MusicXML `<sound>`
  jump attributes such as `segno`, `coda`, `tocoda`, `dalsegno`, `dacapo`, and
  `fine`, are supported by the Phase S10 playback/layout path.

### 11F-5 Complex MusicXML Diagnostics

Purpose: avoid silent failure for tuplets, slurs, ornaments, grace notes,
cross-staff/staff changes, transposition, and complex voice collisions.

Completion criteria:

- basic tuplets keep MusicXML duration timing and can render an MVP bracket;
  complex tuplets warn about rendering limits
- slur, ornament, grace, transposition, and advanced beam limitations have
  specific codes or documented MVP limits
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

## Notation Symbol Coverage

Common notation symbols are tracked in `NOTATION_SUPPORT_MATRIX.md`. The matrix
separates parser support, domain retention, layout support, renderer support,
app visibility, and playback impact so partially-supported features are not
mistaken for complete engraving support.

The self-authored `notation_coverage_grand_staff.musicxml` sample is the public
QA fixture for broad symbol coverage. It includes supported MVP symbols such as
clefs, time and key signatures, accidentals, rest values, dotted notes, chords,
ledger lines, and repeat barlines, plus limited or diagnostic symbols such as
dynamics. Articulation / Dynamics MVP coverage is tracked with the
self-authored `articulation_dynamics_coverage_sample.musicxml`, which exercises
staccato, accent, tenuto, fermata, dynamic marks, and simple hairpins without
using third-party score content. The tuned MVP keeps staccato, tenuto, and
fermata close to the owning note, selects above/below fermata glyphs by
placement, gives dynamic text / hairpins basic vertical separation, and draws
cross-measure hairpins within a system with MVP split continuation at system
breaks. The self-authored
`s6_notation_refinement_grand_staff.musicxml` sample is the focused Phase S6
fixture for tie/slur curves, simple beams, mixed eighth/sixteenth beams,
triplet brackets, and collision review. The self-authored
`s7_repeat_playback_sample.musicxml` sample is the focused Phase S7 fixture for
verifying intro -> repeated section -> outro playback order. The self-authored
`s8_repeat_endings_sample.musicxml` sample is the focused Phase S8 fixture for
verifying intro -> repeated body -> first ending -> repeated body -> second
ending -> outro playback order.
`s9_repeat_visuals_sample.musicxml` sample is the focused Phase S9 fixture for
verifying first/second ending visual brackets and unsupported D.S. diagnostics
without changing the S8 playback order.
Phase S10 adds focused jump-playback samples for D.C. al Fine, D.S. al Fine,
D.C. al Coda, and D.S. al Coda, plus a diagnostic sample for nested repeats,
third endings, excessive repeat counts, and ambiguous jump/repeat mixtures.
Clear jump-only S10 samples expand in `PlaybackSequenceBuilder`; unsafe mixed
structures remain warning-backed diagnostics.

Current Phase 16.5 stabilization status:

- Rhythm values, dots, common rests, explicit MusicXML `<stem>` directions
  where safe, flags, MusicXML `<beam>`
  begin/continue/end grouping with safe inferred fallback, mixed
  eighth/sixteenth beam checks, ledger lines,
  clefs, accidentals, key signatures, time signatures, repeat barlines, basic
  triplet brackets, and attack/continuation highlights are visible at MVP
  quality.
- Tie `<tie>` data affects playback and continuation highlighting. Basic
  same-system MusicXML notation `<tied>` pairs render MVP tie curves; complex
  and system-crossing tie chains remain limited.
- Dynamic text is rendered as MVP staff text, and pedal directions render as
  basic `Ped.` / `*` text. `<sound tempo="">` and simple metronome
  `<beat-unit>` / `<per-minute>` markings are retained for playback metadata,
  but visible tempo words remain future work.
- Basic MusicXML `bar-style` variants are retained on left/right barlines and
  rendered for common thin/heavy combinations. Less common dotted, dashed,
  tick, and short styles currently fall back to the nearest MVP line style.
- DoReMi Palette supports a piano-focused transpose setting for generated
  playback, keyboard highlight, current-note sounding text, and sounding-key
  text. Phase T2 adds optional display transpose: when `譜面も移調` is enabled,
  `ScoreLayout` is rebuilt from the original score with transposed display
  pitch, MVP key signatures, and simple accidentals while preserving original
  note IDs and playback events.
- Prefix notation is laid out in standard engraving order (`clef -> key
  signature -> time signature`) with MVP collision-safe spacing for bass clefs,
  display-transposed key signatures, and first note/rest placement. Clef changes
  that appear inside a measure are retained with their musical onset, drawn as
  smaller in-measure clefs before the following notes, and used for subsequent
  note staff-position calculation; the active clef carries into later measures.
  Measures with in-measure clefs reserve additional horizontal space for the clef
  insertion and trailing flagged notation.
- Note accidentals inherit the associated displayed note's pitch color when
  note colors are enabled, including display-transposed layouts. Key-signature
  accidentals use pitch-class color in the current MVP.
- MusicXML `<transpose>` metadata is parsed and reported through diagnostics.
  Automatic transposing-instrument concert-pitch conversion is not applied by
  default in the piano MVP.
- Unsupported or partial items must be reflected in `NOTATION_SUPPORT_MATRIX.md`
  so the app does not silently imply full engraving support.

Unsupported or partial symbols must be handled in one of two ways:

- emit or preserve a specific diagnostic when parser/runtime support is not
  available; or
- record the current support state in `NOTATION_SUPPORT_MATRIX.md` and
  `MVP0_LIMITATIONS.md` when the feature is intentionally deferred.

Renderer code must continue to consume only `ScoreLayout` and domain-derived
layout elements. It must not parse MusicXML or infer unsupported notation from
source text.

## SMuFL Rendering Status

The SMuFL rendering track is documented in
[SMUFL_INTEGRATION_PLAN.md](SMUFL_INTEGRATION_PLAN.md). Bravura 1.392 is now
bundled as a Swift Package resource under the SIL Open Font License and is used
only as a symbol-shape provider. MusicXML compatibility remains parser/domain
work, and coordinates remain `ScoreLayout` / `ElementLayout` work.

Current SMuFL-rendered symbol families include clefs, accidentals, rests, repeat
dots, time-signature digits, noteheads, and flags. The SDK renderer applies
category-specific glyph sizes so those supported symbols remain readable on
iPad while still using `ScoreLayout` frames and IDs. The current renderer pass
  also keeps notehead sizes visually close across whole/half/black values,
  enlarges common noteheads, shortens stems, uses direction-specific flag glyphs
  near stem ends, keeps note accidentals close to noteheads, balances rest sizes, and spaces
clef/key/time prefixes to keep the Notation Coverage Sample inspectable.
ScoreLayoutEngine now normalizes measure widths for sparse and pickup
measures: normal measures keep a readable minimum, first-measure pickup
candidates and trailing incomplete final bars keep a 75% normal-width minimum,
and prefix width remains part of the layout budget. Non-final wrapped systems
use MVP justification; final systems are intentionally not fully justified.
This is an MVP spacing guard, not full publishing-quality MusicXML system
layout.
Dynamics and articulations remain diagnostic-only unless they are represented by
existing text annotations.
Partial and unsupported symbols must remain explicit in
`NOTATION_SUPPORT_MATRIX.md`, `MVP0_LIMITATIONS.md`, or diagnostics; SMuFL
adoption must not hide unsupported MusicXML interpretation behind prettier
fallback drawing.
