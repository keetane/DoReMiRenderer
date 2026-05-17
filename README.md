# DoReMiRendererKit

DoReMiRendererKit is an experimental Swift score rendering kit for loading MusicXML or MXL, producing stable score layout IDs and coordinates, and rendering colored notes and staff lines in SwiftUI.

Status: `0.1.0-mvp0`, experimental. Public APIs may change before `1.0`.

The Phase 13+ app-execution roadmap is tracked in [ROADMAP.md](ROADMAP.md), and the DoReMi Palette app integration boundary is described in [DOREMI_PALETTE_INTEGRATION.md](DOREMI_PALETTE_INTEGRATION.md).

## Supported Scope

- Parse a minimal `score-partwise` MusicXML subset.
- Parse standard MXL archives that contain `META-INF/container.xml` and a MusicXML rootfile.
- Build a deterministic `ScoreDocument`.
- Build a minimal `ScoreLayout`.
- Render with SwiftUI `Canvas` through `ScoreCanvasView`.
- Draw basic whole, half, quarter, eighth, dotted-note, and rest differences for
  MVP rhythm readability.
- Use bundled Bravura SMuFL glyphs for clefs, accidentals, rests, repeat dots,
  time-signature digits, noteheads, and flags, with SDK-side size and anchor
  tuning for iPad learning readability.
- Resolve note, staff line, ledger line, accidental, and highlight colors through `ScoreStyle` and `ScoreColorResolver`.
- Prefix notation uses the standard order `clef -> key signature -> time
  signature`, with expanded SDK layout spacing so clefs, display-transposed key
  signatures, time signatures, and the first note/rest do not collide.
- When note colors are enabled, note accidentals match the associated displayed
  note pitch color. Key-signature accidentals use pitch-class color in the
  current MVP.
- Perform MVP0 hit testing with `ScoreLayout.hitTest(point:radius:)`.
- Generate playback step events without audio output.
- DoReMi Palette consumes playback events for generated-tone audio, Practice
  Mode, repeat/jump playback, keyboard highlight, and piano transpose.
- Run iOS Simulator snapshot tests for basic rendering regression coverage.
- Read basic lyrics, fingering, key signatures, tempo metadata, and repeat
  metadata with explicit diagnostics for unsupported advanced notation.
- DoReMi Palette can transpose generated playback and keyboard highlights by
  `-12...+12` semitones while leaving the score written-pitch.
- DoReMi Palette includes a Palette Editor MVP with 12 pitch-class ON/OFF
  controls, a C2-C6 keyboard preview, and a generated C2-C6 score preview.
  Arbitrary RGB editing and octave-specific color enablement are future work.

## Not Supported

- `score-timewise`
- Full MusicXML coverage
- Full repeat/jump navigation beyond documented S7-S10 MVP cases
- Ornament, grace-note engraving, and publishing-quality slur/beam/tuplet engraving
- Encrypted or unusual MXL archive layouts
- Publishing-quality engraving
- Complex multi-voice collision avoidance
- SDK-owned audio playback, MIDI, score-display transposition, key-signature
  redraw, and MusicXML `<transpose>` / transposing-instrument support
- Pinch zoom, advanced automatic scroll follow, and horizontal page navigation
- Complex selection state, multiple selection, drag, annotations

See [MVP0_LIMITATIONS.md](MVP0_LIMITATIONS.md) for the complete list.

## Installation

Add the package to an iOS 17+ or macOS 14+ Swift Package or Xcode project.

```swift
.package(url: "<repository-url>", from: "0.1.0")
```

Then add `DoReMiRendererKit` to the target dependencies.

## Basic Usage

```swift
import DoReMiRendererKit

let renderer = DoReMiRenderer()
let score = try renderer.parseMusicXML(data: musicXMLData)
let layout = try renderer.layout(score: score)
let playbackEvents = renderer.makePlaybackSequence(score: score)
```

External apps should use `DoReMiRenderer` as the primary facade. Parser, layout
engine, painter, drawing adapter, and playback builder implementation types are
not public API in Phase 9.

## Parse MusicXML

```swift
let score = try DoReMiRenderer().parse(input: .musicXMLData(musicXMLData))
```

Use diagnostics when you need unsupported-feature details:

```swift
let result = try DoReMiRenderer().parseWithDiagnostics(input: .musicXMLData(musicXMLData))
let score = result.score
let diagnostics = result.diagnostics
```

For local sample-set checks, see [MUSICXML_COMPATIBILITY.md](MUSICXML_COMPATIBILITY.md).
Private samples should live in ignored `LocalSamples/`; generated reports contain
diagnostic metadata only, not score contents.

## Parse MXL

```swift
let score = try DoReMiRenderer().parse(input: .mxlData(mxlData))
```

MXL support reads `META-INF/container.xml`, resolves the first MusicXML rootfile, and passes that MusicXML data to the existing parser.

## Layout Score

```swift
let layout = try renderer.layout(
    score: score,
    options: LayoutOptions(pageWidth: 980, staffSpace: 16)
)
```

`ScoreLayout` is the coordinate source for rendering and hit testing.
Apps can inspect layout records and lookup tables, but should not construct
layout records directly.

## Render With ScoreCanvasView

```swift
import SwiftUI
import DoReMiRendererKit

struct ScoreScreen: View {
    let score: ScoreDocument
    let layout: ScoreLayout

    var body: some View {
        ScoreCanvasView(layout: layout, score: score, style: ScoreStyle())
    }
}
```

Enable scaled scroll display by passing a scale and scroll axes:

```swift
ScoreCanvasView(
    layout: layout,
    score: score,
    style: style,
    currentNoteID: currentNoteID,
    scale: 1.5,
    scrollAxes: [.horizontal, .vertical],
    followsCurrentNote: true
) { result in
    currentNoteID = result.nearestNoteID
}
```

`ScoreViewportTransform` defines view-to-layout and layout-to-view coordinate
conversion. `ScoreLayout` coordinates remain unchanged by zoom or scroll.

Use `ScoreScrollFollower` when app code needs an explicit target offset for a
current note:

```swift
let transform = ScoreViewportTransform(
    scale: scale,
    contentOffset: contentOffset,
    viewportSize: viewportSize,
    contentSize: layout.canvasSize
)

let target = ScoreScrollFollower().target(
    for: currentNoteID,
    in: layout,
    transform: transform
)
```

The helper reads `ScoreLayout.noteByID` and returns a scaled content offset
without changing layout coordinates or playback data.

## Color Notes And Staff Lines

```swift
let style = ScoreStyle(
    staffLineStyle: .pitchClass(defaultPalette: defaultEducationalPalette, clefOverrides: [:]),
    noteColorStyle: .pitchClass(defaultEducationalPalette),
    ledgerLineStyle: .matchNotePitch,
    accidentalStyle: .matchNotePitch
)
```

Renderers do not decide colors directly. Colors are resolved through `ScoreStyle`, `ColorRule`, `ColorContext`, and `ScoreColorResolver`.

## Hit Testing

```swift
let result = layout.hitTest(point: tapPoint, radius: 18)
let noteID = result.nearestNoteID
```

In SwiftUI, `ScoreCanvasView` exposes an MVP0 `onTap` closure:

```swift
ScoreCanvasView(layout: layout, score: score, style: style) { result in
    print(result.nearestNoteID as Any)
}
```

## Playback Events

```swift
let events = renderer.makePlaybackSequence(
    score: score,
    options: PlaybackOptions(includeRests: false)
)
```

Playback events are for cursor, highlight stepping, and app-side generated-tone
playback.

Tempo and repeat metadata can be inspected through playback metadata:

```swift
let metadata = renderer.makePlaybackMetadata(score: score)
let tempoEvents = metadata.tempoEvents
let repeatWarnings = metadata.diagnostics
```

Phase S7 expands simple forward/backward repeat sections in the playback
sequence. Phase S8 adds one clear first/second ending repeat section and limited
D.C. al Fine expansion for jump-only scores. Phase S9 adds visual first/second
ending brackets and numbers. Phase S10 adds jump-only D.S. al Fine, D.C. al
Coda, and D.S. al Coda expansion. The score and layout are not duplicated for
playback; repeated passes reuse the original `NoteID` values. Nested repeats,
third endings, mixed repeat+jump structures, multiple Segno/Coda markers,
complex jumps, and system-crossing ending brackets remain unsupported or
diagnostic-only.

## MusicXML Compatibility

Phase 11F adds basic lyrics, fingering, key signature, tempo metadata, repeat
metadata, and specific diagnostics for complex MusicXML features. See
[MUSICXML_COMPATIBILITY.md](MUSICXML_COMPATIBILITY.md) for scope, private sample
policy, diagnostic priority rules, and fixture extraction policy.

## Example App

Build the example app:

```sh
xcodebuild build \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

Capture a simulator screenshot:

```sh
xcrun simctl io booted screenshot /tmp/doremirenderer_example.png
```

See [Examples/README.md](Examples/README.md) for more details.

## DoReMi Palette App

Phase 12 adds the iPad-first DoReMi Palette integration app:

```sh
xcodebuild build \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

The app loads a bundled self-authored MusicXML sample on launch, renders it with
`ScoreCanvasView`, supports `.musicxml`, `.xml`, and `.mxl` import, shows
diagnostics in Japanese, persists display settings, and displays a simple piano
keyboard highlight for the current note. Phase 15 adds MVP generated-tone audio
playback with Play / Pause / Stop / Reset, tempo selection, and synchronized
score and keyboard highlights.

The integration design and SDK/App responsibility boundary are documented in
[DOREMI_PALETTE_INTEGRATION.md](DOREMI_PALETTE_INTEGRATION.md).

Phase 13 and later focus on real-app readiness: QA, import verification, UI
tuning, file persistence, audio playback, practice mode, and real iPad /
TestFlight preparation. See [ROADMAP.md](ROADMAP.md).

Phase 13 app QA is tracked in [APP_QA_CHECKLIST.md](APP_QA_CHECKLIST.md).
Self-authored import fixtures for `.musicxml`, `.xml`, `.mxl`, invalid
MusicXML, and unsupported extension checks live under
`Apps/DoReMiPalette/TestImportFiles/`. Phase 13 also adds regression coverage
for keyboard highlight behavior, display settings persistence, diagnostics
presentation, and app-level import/state transitions. Full library/recent-file
persistence is handled in Phase 14.

Phase 14 completes the MVP Library / Recent files flow in the app. Bundled
samples and imported scores have distinct metadata records, recent imported
files are shown in a Library sheet, duplicate imports update the existing item,
items can be removed from Recent files, and missing or unresolved files show a
Japanese recovery message instead of replacing the current score. The app stores
metadata only; raw MusicXML and MXL contents are not persisted. Security-scoped
bookmark handling is intentionally minimal and may require reselecting files
depending on the provider.

Phase 15 adds app-side playback runtime and simple generated audio. The SDK
still only provides `PlaybackEvent` and metadata; AVFoundation is used only by
the DoReMi Palette app. Audio quality, background playback, repeat expansion,
complex tuplet timing, and transposition-aware playback remain future work.

Notation symbols now use the Bravura SMuFL font for clefs, accidentals, rests,
repeat dots, time-signature digits, noteheads, and flags. SMuFL is used only as
a glyph source: MusicXML interpretation, `ScoreLayout` coordinates, IDs, hit
testing, color resolution, and playback remain in DoReMiRendererKit. See
[SMUFL_INTEGRATION_PLAN.md](SMUFL_INTEGRATION_PLAN.md),
[ASSET_LICENSES.md](ASSET_LICENSES.md), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the integration and
license details. The renderer also applies an internal category-based size
policy so noteheads, accidentals, rests, flags, clefs, and time signatures stay
readable on iPad without moving glyph selection into the app. The current
SMuFL tuning keeps common notehead sizes visually close, anchors flags to stem
ends, uses slightly smaller accidentals than the first pass, and spaces clef /
key / time-signature prefixes to avoid overlap.

Phase S6 adds MVP Core Graphics path rendering for same-system tie/slur curves,
safe simple beam groups, mixed eighth/sixteenth secondary beam checks, and basic
triplet brackets while keeping SMuFL glyphs for notation shapes. Phase S7 adds
simple repeat playback expansion, Phase S8 adds first/second ending playback
expansion, and Phase S9 adds visible ending brackets. For Phase 17B TestFlight
readiness, the app can ship bundled MXL samples. The current bundled sample set
is the five user-provided `.mxl` files copied from `sample/`; earlier QA
MusicXML fixtures are no longer part of the app sample catalog.

DoReMi Palette also includes a Print MVP and a score layout switcher. The app
can display either the existing horizontal one-row score (`横一段`) or an A4-width
score layout (`A4`) that wraps measures into systems. The toolbar `印刷` button
always generates the PDF from the A4 layout, even when the on-screen view is in
horizontal mode. The SDK provides `ScoreGraphicsRenderer` for drawing an
existing layout into a `CGContext`; the app does not reparse MusicXML or
recalculate score coordinates for printing.

## Snapshot Tests

Basic iOS Simulator snapshot tests cover single melody, grand staff, chord/rest,
accidentals, ledger lines, lyrics/fingering, key signatures, current-note
highlight, and note/staff color combinations. Baselines are stored in
`Tests/DoReMiRendererKitTests/__Snapshots__`.
See [DEVELOPMENT.md](DEVELOPMENT.md) for recording and diff artifact details.

## License And Notices

- [LICENSE](LICENSE)
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- [ASSET_LICENSES.md](ASSET_LICENSES.md)
- [PRIVACY_NOTES.md](PRIVACY_NOTES.md)
- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)
- [TESTFLIGHT_CHECKLIST.md](TESTFLIGHT_CHECKLIST.md)
- [LEGAL_GUIDELINES.md](LEGAL_GUIDELINES.md)

## Legal Disclaimer

The legal and licensing files in this repository are project hygiene records, not legal advice. Before selling, publishing, or externally distributing this SDK, obtain review from a qualified legal professional.

## Practice Mode MVP

DoReMi Palette now includes an app-side Practice Mode. It lets the user step
through the current score one event at a time, shows written note names and
solfege, keeps score and keyboard highlights in sync, and provides a small color
palette selector. Practice Mode is separate from automatic audio playback:
enabling practice stops playback, and pressing Play returns to normal playback.

Practice Mode remains MVP-level: no scoring, microphone input, MIDI keyboard
input, AI analysis, or transposition-aware note-name display yet.

### Bundled MXL Samples

The previous bundled QA MusicXML samples were removed from the app bundle when
the sample set was replaced with user-provided `.mxl` files from `sample/`.
The Library now exposes these bundled MXL samples:

- `Canon in D`
- `Fur Elise - Beginner Piano`
- `Happy Birthday To You Piano`
- `Ode to Joy Easy Variation`
- `The Entertainer`

`Canon in D` is the default launch score. `12 Variations of Twinkle Twinkle
Little Star` was removed from the bundled sample list because its dense repeat
structure makes the repeat-expanded playback too long for a default learning
sample. The app transpose control is a key
picker (`C`, `C#`, `D`, ...) rather than a semitone +/- control; playback,
keyboard highlights, and the rendered score use the selected key together.

### Palette Editor MVP

The app-level palette editor opens from the toolbar palette button. It preserves
the existing palette selection and Note Color / Staff Color switches, then adds
pitch-class enablement for `C`, `C#`, `D`, ... `B`. Disabled pitch classes fall
back to neutral ink in score notes and keyboard previews/highlights. The preview
score is generated in app memory from C2 through C6 and is not a bundled
MusicXML asset.

This remains an app feature: the SDK receives regular `ScoreStyle` color rules,
and the renderer does not know about app UI state.

## Phase 16.5 Stabilization

Before Phase 17 real-device/TestFlight preparation, the project uses a
stabilization gate focused on notation, playback, scroll follow, and Practice
Mode coexistence. The main checks are:

- `Rhythm Values Sample` for note values, rests, repeated pitches, and playback
  timing.
- `Notation Coverage Sample` for common symbol visibility and known unsupported
  notation.
- SDK and app tests for layout bounds, current-note follow, generated-tone
  playback, attack/continuation highlighting, and Practice/Playback handoff.

Phase 16.5 does not add SMuFL fonts or new notation families. It stabilizes the
current Core Graphics renderer and app playback path before the Phase 17 gate.

## Phase 17A Real iPad QA

Phase 17A is the first physical-device gate before TestFlight preparation. The
current real iPad status is:

- `iPad Pro 2nd` on iPadOS `26.4.2` is detected by Xcode command-line tools.
- DoReMi Palette builds successfully for the physical iPad destination.
- Codex-side install / launch through `devicectl` is blocked by a local
  CoreDeviceService timeout, so runtime, audio, import, Library, Diagnostics,
  and settings QA still need Xcode Run or a recovered CoreDevice environment.

The detailed checklist is tracked in
[APP_QA_CHECKLIST.md](APP_QA_CHECKLIST.md).
