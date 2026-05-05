# Load MusicXML

Use ``DoReMiRenderer/parseMusicXML(data:)`` or ``DoReMiRenderer/parse(input:)``
with ``ScoreInput/musicXMLData(_:)``.

```swift
let score = try DoReMiRenderer().parse(input: .musicXMLData(data))
```

For unsupported-feature reporting, use diagnostics:

```swift
let result = try DoReMiRenderer().parseWithDiagnostics(input: .musicXMLData(data))
let diagnostics = result.diagnostics
```

MVP0 supports a minimal `score-partwise` subset. `score-timewise` is not
implemented.

