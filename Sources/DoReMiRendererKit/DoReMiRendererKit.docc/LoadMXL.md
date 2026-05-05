# Load MXL

Use ``DoReMiRenderer/parseMXL(data:)`` or ``DoReMiRenderer/parse(input:)`` with
``ScoreInput/mxlData(_:)``.

```swift
let score = try DoReMiRenderer().parse(input: .mxlData(mxlData))
```

MXL loading reads `META-INF/container.xml`, resolves the first MusicXML rootfile,
and passes that MusicXML data to the existing MusicXML parser.

Encrypted archives, unusual layouts, and non-file root entries are not supported
in MVP0.

