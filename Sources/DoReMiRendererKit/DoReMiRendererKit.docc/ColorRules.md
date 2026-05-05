# Color Rules

Use ``ScoreStyle`` and color rules to control note, staff line, ledger line,
accidental, and highlight color behavior.

```swift
let style = ScoreStyle(
    staffLineStyle: .pitchClass(defaultPalette: defaultEducationalPalette, clefOverrides: [:]),
    noteColorStyle: .pitchClass(defaultEducationalPalette),
    ledgerLineStyle: .matchNotePitch,
    accidentalStyle: .matchNotePitch
)
```

Renderers do not decide pitch colors directly. Color decisions belong to
``ColorRule``, ``ColorContext``, ``ScoreColorResolver``, and the styling layer.

