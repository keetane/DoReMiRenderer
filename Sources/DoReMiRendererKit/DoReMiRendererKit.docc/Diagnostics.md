# Diagnostics

Parser and input-layer diagnostics report unsupported or invalid input where the
MVP0 implementation can identify it.

```swift
let result = try DoReMiRenderer().parseWithDiagnostics(input: .musicXMLData(data))
for diagnostic in result.diagnostics {
    print(diagnostic.message)
}
```

MXL failures include invalid archives, missing `container.xml`, invalid
container data, missing rootfile entries, and missing referenced rootfiles.

