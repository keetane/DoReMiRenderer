# Getting Started

Import the package and use ``DoReMiRenderer`` as the main entry point.

```swift
import DoReMiRendererKit

let renderer = DoReMiRenderer()
let score = try renderer.parseMusicXML(data: musicXMLData)
let layout = try renderer.layout(score: score)
let events = renderer.makePlaybackSequence(score: score)
```

The renderer facade keeps parser, layout, and playback responsibilities separate
while giving app code a compact integration surface.

Implementation types such as the direct parser, layout engine, painter, drawing
adapter, and playback builder are internal. External apps should integrate
through the facade, ``ScoreCanvasView``, and public output records.
