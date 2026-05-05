# Playback Events

Generate playback step events without audio output:

```swift
let events = DoReMiRenderer().makePlaybackSequence(
    score: score,
    options: PlaybackOptions(includeRests: false)
)
```

Events are sorted by onset. Notes with the same onset are grouped into one event.
Rests are included only when ``PlaybackOptions/includeRests`` is true.

Audio playback, AVFoundation, MIDI, and realtime scheduling are not implemented
in MVP0.

