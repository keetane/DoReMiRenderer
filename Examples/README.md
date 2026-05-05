# DoReMiRendererExample

This example app loads an original sample MusicXML file, parses it with
DoReMiRendererKit, lays it out, and renders it with `ScoreCanvasView`.

The app demonstrates:

- MusicXML parse to `ScoreDocument`.
- Layout through `DoReMiRenderer.layout(score:options:)`.
- SwiftUI Canvas rendering.
- Note color and staff color toggles.
- Current note highlighting.
- Tap selection through `ScoreCanvasView.onTap`.
- Previous and Next stepping through playback events.

## Build

```sh
xcodebuild build \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

If that simulator is not installed, list available devices:

```sh
xcrun simctl list devices available
```

Then replace the destination with an installed iPad simulator.

## Screenshot

Boot and run the app from Xcode or the Simulator, then capture:

```sh
xcrun simctl io booted screenshot /tmp/doremirenderer_example.png
```

## Asset Note

`DoReMiRendererExample/sample_melody.musicxml` is an original sample created for
this repository. See `../ASSET_LICENSES.md`.

