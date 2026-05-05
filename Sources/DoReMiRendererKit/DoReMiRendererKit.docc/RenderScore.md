# Render Score

Render an existing ``ScoreLayout`` with ``ScoreCanvasView``.

```swift
struct ScoreScreen: View {
    let score: ScoreDocument
    let layout: ScoreLayout

    var body: some View {
        ScoreCanvasView(layout: layout, score: score, style: ScoreStyle())
    }
}
```

`ScoreLayout` is the coordinate source for rendering. The renderer does not
parse MusicXML and does not recalculate score coordinates.

`ScorePainter` and drawing adapters are internal implementation details in Phase
9. Use ``ScoreCanvasView`` for SDK rendering.

Use `scale` and `scrollAxes` on ``ScoreCanvasView`` when the score should be
displayed larger than the viewport. Zoom and scroll do not mutate the
``ScoreLayout`` coordinates.
