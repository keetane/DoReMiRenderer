# Third Party Notices

DoReMiRendererKit uses Apple platform APIs, Swift Package Manager, and the ZIP
library listed below.

## Apple APIs

- Swift Standard Library
- Foundation
- CoreGraphics
- CoreText
- SwiftUI
- XMLParser from Foundation

These APIs are provided as part of Apple's developer platforms and toolchains.

## ZIPFoundation

- Project: ZIPFoundation
- Repository: https://github.com/weichsel/ZIPFoundation
- License: MIT License
- Purpose: Reading `.mxl` ZIP archives and extracting `META-INF/container.xml`
  plus the referenced MusicXML rootfile.

ZIPFoundation is a general ZIP archive library. It is not a score rendering SDK
and does not provide MusicXML parsing, layout, rendering, interaction, or
playback behavior.

## External Score Rendering SDKs

No code, sample code, type definitions, API names, headers, binaries, or internal
implementation details from commercial or open source score rendering SDKs are
included in this repository.

The project policy is to avoid copying or imitating APIs or implementation
structures from SeeScoreLib, OSMD, VexFlow, Verovio, MuseScore, or similar
score rendering libraries. Public standards such as MusicXML may be used as
implementation references.

## Current Status

No GPL or LGPL dependencies are used by DoReMiRendererKit MVP0.
