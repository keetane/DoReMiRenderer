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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

