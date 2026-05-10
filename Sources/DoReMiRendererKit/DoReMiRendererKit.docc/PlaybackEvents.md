# Playback Events

Generate playback step events from score data:

```swift
let events = DoReMiRenderer().makePlaybackSequence(
    score: score,
    options: PlaybackOptions(includeRests: false)
)
```

Events are sorted by onset. Notes with the same onset are grouped into one event.
Rests are included only when ``PlaybackOptions/includeRests`` is true.

DoReMiRendererKit does not implement audio output or import AVFoundation. Apps
can consume these events in their own playback runtime. DoReMi Palette Phase 15
uses app-side generated-tone audio for MVP playback.
