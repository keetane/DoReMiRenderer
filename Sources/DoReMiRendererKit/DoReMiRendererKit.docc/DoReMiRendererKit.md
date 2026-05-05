# DoReMiRendererKit

Load MusicXML or MXL, build a deterministic score layout, render with SwiftUI
Canvas, hit test layout elements, and generate playback step events.

@Metadata {
    @TechnologyRoot
}

## Overview

DoReMiRendererKit `0.1.0-mvp0` is experimental. It prioritizes stable IDs,
layout coordinates, color resolution, and integration boundaries over
publishing-quality engraving.

Use ``DoReMiRenderer`` as the preferred facade for parsing, layout, and playback
event generation.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:LoadMusicXML>
- <doc:LoadMXL>
- <doc:MusicXMLCompatibility>

### Display

- <doc:RenderScore>
- <doc:ZoomAndScroll>
- <doc:ColorRules>
- <doc:HitTesting>

### Playback And Diagnostics

- <doc:PlaybackEvents>
- <doc:Diagnostics>

### Project Notes

- <doc:AppIntegration>
- <doc:MVP0Limitations>
- <doc:LegalAndThirdPartyNotices>
