import DoReMiRendererKit
import Foundation

struct PalettePlaybackCursor: Equatable {
    private(set) var events: [PlaybackEvent]
    private(set) var index: Int
    private(set) var currentNoteIDs: Set<NoteID>

    init(events: [PlaybackEvent]) {
        self.events = events
        self.index = 0
        self.currentNoteIDs = Set(events.first?.noteIDs ?? [])
    }

    var currentNoteID: NoteID? {
        events[safe: index]?.noteIDs.first
    }

    var currentEvent: PlaybackEvent? {
        events[safe: index]
    }

    var stepSummary: String {
        guard !events.isEmpty else {
            return "Step 0/0"
        }
        return "Step \(index + 1)/\(events.count)"
    }

    mutating func reset(events: [PlaybackEvent]) {
        self = PalettePlaybackCursor(events: events)
    }

    mutating func move(by offset: Int) {
        guard !events.isEmpty else {
            currentNoteIDs = []
            index = 0
            return
        }
        index = min(max(index + offset, 0), events.count - 1)
        currentNoteIDs = Set(events[index].noteIDs)
    }

    mutating func select(noteID: NoteID) {
        if let eventIndex = events.firstIndex(where: { $0.noteIDs.contains(noteID) }) {
            index = eventIndex
            currentNoteIDs = Set(events[eventIndex].noteIDs)
        } else {
            currentNoteIDs = [noteID]
        }
    }

    mutating func setIndex(_ index: Int) {
        guard !events.isEmpty else {
            self.index = 0
            currentNoteIDs = []
            return
        }
        self.index = min(max(index, 0), events.count - 1)
        currentNoteIDs = Set(events[self.index].noteIDs)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct PalettePracticeSession: Equatable {
    private(set) var events: [PlaybackEvent]
    private(set) var index: Int
    private(set) var isEnabled: Bool

    init(events: [PlaybackEvent] = [], isEnabled: Bool = false) {
        self.events = events
        self.index = 0
        self.isEnabled = isEnabled
    }

    var currentEvent: PlaybackEvent? {
        events[safe: index]
    }

    var currentNoteID: NoteID? {
        currentEvent?.noteIDs.first
    }

    var currentNoteIDs: Set<NoteID> {
        Set(currentEvent?.noteIDs ?? [])
    }

    var isRest: Bool {
        currentEvent?.midiPitches.isEmpty ?? false
    }

    var stepSummary: String {
        guard !events.isEmpty else {
            return "練習 0/0"
        }
        return "練習 \(index + 1)/\(events.count)"
    }

    mutating func configure(events: [PlaybackEvent]) {
        self.events = events
        index = 0
    }

    mutating func setEnabled(_ enabled: Bool, startingAt startIndex: Int? = nil) {
        isEnabled = enabled
        if let startIndex {
            index = clampedIndex(startIndex)
        } else if enabled {
            index = clampedIndex(index)
        }
    }

    mutating func move(by offset: Int) {
        guard !events.isEmpty else {
            index = 0
            return
        }
        index = clampedIndex(index + offset)
    }

    mutating func reset() {
        index = 0
    }

    mutating func select(noteID: NoteID) {
        guard let eventIndex = events.firstIndex(where: { $0.noteIDs.contains(noteID) }) else {
            return
        }
        index = eventIndex
    }

    mutating func setIndex(_ newIndex: Int) {
        index = clampedIndex(newIndex)
    }

    private func clampedIndex(_ candidate: Int) -> Int {
        guard !events.isEmpty else {
            return 0
        }
        return min(max(candidate, 0), events.count - 1)
    }
}
