# Hit Testing

Hit testing uses ``ScoreLayout`` coordinates and layout elements.

```swift
let result = layout.hitTest(point: tapPoint, radius: 18)
let noteID = result.nearestNoteID
```

In SwiftUI, pass an MVP0 tap closure to ``ScoreCanvasView``:

```swift
ScoreCanvasView(layout: layout, score: score, style: style) { result in
    currentNoteID = result.nearestNoteID
}
```

Zoom and scroll coordinate transforms are not implemented in MVP0.

