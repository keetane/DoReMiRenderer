import Foundation
import Testing
@testable import DoReMiRendererKit

@Test(.enabled(if: FileManager.default.fileExists(atPath: "sample/app-bundle-hold/Canon_in_D.mxl")))
func canonWebNotesRemainInsideEveryMeasure() throws {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("sample/app-bundle-hold/Canon_in_D.mxl")
    let renderer = DoReMiRenderer()
    let score = try renderer.parse(input: .mxlData(Data(contentsOf: url)))
    let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 1024))
    for measure in layout.measures {
        for note in layout.noteByID.values where note.measureID == measure.measureID {
            #expect(note.noteheadFrame.minX >= measure.frame.minX - 0.01,
                    "\(measure.measureID): \(note.noteID) crosses start")
            #expect(note.noteheadFrame.maxX <= measure.frame.maxX + 0.01,
                    "\(measure.measureID): \(note.noteID) crosses end by \(note.noteheadFrame.maxX - measure.frame.maxX)pt")
        }
    }
}

@Test func webCascadingSystemBreaksReserveEveryClefPrefix() throws {
    var measures: [Measure] = []
    for number in 1...40 {
        let notes: [ScoreNote] = (0..<8).map { index in
                ScoreNote(
                    id: NoteID(rawValue: "prefix-\(number)-\(index)"),
                    pitch: Pitch(step: .g, octave: 4),
                    onset: MusicalTime(ticks: index, ticksPerQuarterNote: 2),
                    duration: MusicalTime(ticks: 1, ticksPerQuarterNote: 2),
                    noteValueKind: .eighth,
                    voiceID: VoiceID(rawValue: "1"),
                    staffID: StaffID(rawValue: "1")
                )
            }
        measures.append(Measure(
            id: MeasureID(partIndex: 0, measureNumber: String(number)),
            number: String(number),
            notes: notes,
            clef: number == 1 ? Clef(kind: .treble) : nil,
            keySignature: number == 1 ? KeySignature(fifths: 2, mode: "major") : nil,
            timeSignature: number == 1 ? TimeSignature(beats: 4, beatType: 4) : nil
        ))
    }
    let renderer = DoReMiRenderer()
    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: measures)])
    let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 1024))
    #expect(layout.systems.count > 3)
    for measure in layout.measures {
        for note in layout.noteByID.values where note.measureID == measure.measureID {
            #expect(note.noteheadFrame.minX >= measure.frame.minX)
            #expect(note.noteheadFrame.maxX <= measure.frame.maxX)
        }
    }
}
