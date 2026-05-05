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
- Resolve note, staff line, ledger line, accidental, and highlight colors through `ScoreStyle` and `ScoreColorResolver`.
- Perform MVP0 hit testing with `ScoreLayout.hitTest(point:radius:)`.
- Generate playback step events without audio output.
- Run iOS Simulator snapshot tests for basic rendering regression coverage.
- Read basic lyrics, fingering, key signatures, tempo metadata, and repeat
  metadata with explicit diagnostics for unsupported advanced notation.

## Not Supported

- `score-timewise`
- Full MusicXML coverage
- Repeat playback expansion
- Slur, ornament, tuplet bracket, beam, and grace-note engraving
- Encrypted or unusual MXL archive layouts
- Publishing-quality engraving
- Complex multi-voice collision avoidance
- Audio playback, AVFoundation, MIDI
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

Playback events are for cursor and highlight stepping. Audio playback is not implemented in MVP0.

Tempo and repeat metadata can be inspected without changing playback event
ordering:

```swift
let metadata = renderer.makePlaybackMetadata(score: score)
let tempoEvents = metadata.tempoEvents
let repeatWarnings = metadata.diagnostics
```

Repeat playback expansion is intentionally unsupported in Phase 11F.

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
keyboard highlight for the current note. Audio playback is not implemented.

The integration design and SDK/App responsibility boundary are documented in
[DOREMI_PALETTE_INTEGRATION.md](DOREMI_PALETTE_INTEGRATION.md).

Phase 13 and later focus on real-app readiness: QA, import verification, UI
tuning, file persistence, audio playback, practice mode, and real iPad /
TestFlight preparation. See [ROADMAP.md](ROADMAP.md).

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
- [LEGAL_GUIDELINES.md](LEGAL_GUIDELINES.md)

## Legal Disclaimer

The legal and licensing files in this repository are project hygiene records, not legal advice. Before selling, publishing, or externally distributing this SDK, obtain review from a qualified legal professional.
