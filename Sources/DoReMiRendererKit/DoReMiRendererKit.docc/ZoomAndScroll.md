# Zoom And Scroll

`ScoreCanvasView` can render scaled content inside a SwiftUI scroll view.

```swift
ScoreCanvasView(
    layout: layout,
    score: score,
    style: style,
    currentNoteID: currentNoteID,
    scale: 2.0,
    scrollAxes: [.horizontal, .vertical],
    followsCurrentNote: true
) { result in
    currentNoteID = result.nearestNoteID
}
```

``ScoreLayout`` remains the source of truth for coordinates. Scaling is applied
only in the display layer.

Use ``ScoreViewportTransform`` when app code needs explicit conversion between
view coordinates and layout coordinates:

```swift
let transform = ScoreViewportTransform(
    scale: 2,
    contentOffset: CGPoint(x: 40, y: 20),
    viewportSize: viewportSize,
    contentSize: layout.canvasSize
)

let layoutPoint = transform.layoutPoint(fromViewPoint: CGPoint(x: 200, y: 100))
```

With the values above, the layout point is `(120, 60)`. Content offset is
measured in scaled view-space points.

Use ``ScoreScrollFollower`` when you need a calculated target offset instead of
`ScoreCanvasView`'s built-in current-note follow behavior:

```swift
let target = ScoreScrollFollower().target(
    for: currentNoteID,
    in: layout,
    transform: transform
)
```

The target offset is measured in scaled content coordinates. If the note is
already visible inside the viewport margin, no target is returned. Otherwise,
the note frame is moved toward the viewport center and clamped to the scrollable
content bounds.

Pinch zoom, horizontal page navigation, and advanced viewport management are not
implemented in MVP0.
