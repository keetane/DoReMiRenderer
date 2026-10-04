import Foundation
import Testing
@testable import DoReMiRendererKit

@Test func chordTiesKeepOneOuterCurveWithoutRemovingSourceTies() throws {
    for direction in ["up", "down"] {
        let notes = ["start", "stop"].map { tie in
            ["C", "E", "G"].enumerated().map { index, step in
                "<note>\(index == 0 ? "" : "<chord/>")<pitch><step>\(step)</step><octave>4</octave></pitch><duration>1</duration><tie type=\"\(tie)\"/><type>quarter</type><stem>\(direction)</stem></note>"
            }.joined()
        }.joined()
        let xml = """
        <score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
        <part id="P1"><measure number="1"><attributes><divisions>1</divisions><clef><sign>G</sign><line>2</line></clef></attributes>\(notes)</measure></part></score-partwise>
        """
        let renderer = DoReMiRenderer()
        let score = try renderer.parse(input: .musicXMLData(Data(xml.utf8)))
        let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 1024))
        let ties = layout.elements.compactMap(\.curve).filter { $0.kind == .tie }
        #expect(ties.count == 1)
        #expect(score.parts[0].measures[0].notes.filter { $0.ties.contains(.start) }.count == 3)
        #expect(score.parts[0].measures[0].notes.filter { $0.ties.contains(.stop) }.count == 3)
        let curve = try #require(ties.first)
        let source = try #require(layout.noteByID[curve.startNoteID])
        #expect(source.pitch?.step == (direction == "up" ? .c : .g))
        #expect(layout.noteByID.count == 6)
    }
}

@Test func tiesUseRenderedStemSideAndOuterHeadEdges() throws {
    for direction in ["up", "down"] {
        let xml = """
        <score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
        <part id="P1"><measure number="1"><attributes><divisions>2</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
        <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration><tie type="start"/><type>eighth</type><stem>\(direction)</stem><beam number="1">begin</beam></note>
        <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration><tie type="stop"/><type>eighth</type><stem>\(direction)</stem><beam number="1">end</beam></note>
        </measure></part></score-partwise>
        """
        let renderer = DoReMiRenderer()
        let score = try renderer.parse(input: .musicXMLData(Data(xml.utf8)))
        let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 1024))
        let tie = try #require(layout.elements.first { $0.kind == .tie }?.curve)
        let start = try #require(layout.noteByID[tie.startNoteID])
        let end = try #require(layout.noteByID[tie.endNoteID])
        let stem = try #require(layout.elements.first { $0.kind == .stem && $0.noteID == tie.startNoteID })
        #expect(tie.start.x == start.noteheadFrame.minX + start.noteheadFrame.width * 0.2)
        #expect(tie.end.x == end.noteheadFrame.maxX - end.noteheadFrame.width * 0.2)
        #expect((tie.control.y - start.noteheadCenter.y) * (stem.frame.midY - start.noteheadCenter.y) < 0)
        if stem.frame.midY < start.noteheadCenter.y {
            #expect(tie.start.y > start.noteheadFrame.maxY)
        } else {
            #expect(tie.start.y < start.noteheadFrame.minY)
        }
    }
}

@Test(.enabled(if: FileManager.default.fileExists(atPath: "sample/app-bundle-hold/Canon_in_D.mxl")))
func canonWebNotesRemainInsideEveryMeasure() throws {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("sample/app-bundle-hold/Canon_in_D.mxl")
    let renderer = DoReMiRenderer()
    let score = try renderer.parse(input: .mxlData(Data(contentsOf: url)))
    let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 1024))
    for group in Dictionary(grouping: layout.measures, by: \.systemIndex).values {
        #expect(group.count >= 3)
    }
    let slur24 = try #require(layout.elements.first { $0.measureID == MeasureID(partIndex: 0, measureNumber: "24") && $0.kind == .slur }?.curve)
    let slurStart = try #require(layout.noteByID[slur24.startNoteID])
    let slurEnd = try #require(layout.noteByID[slur24.endNoteID])
    let beam24 = try #require(layout.elements.compactMap(\.beam).first { $0.noteIDs.contains(slur24.startNoteID) })
    #expect(beam24.primary.start.y < slurStart.noteheadCenter.y)
    #expect(slur24.control.y > max(slurStart.noteheadFrame.maxY, slurEnd.noteheadFrame.maxY))
    #expect(slur24.start.x == slurStart.noteheadFrame.minX + slurStart.noteheadFrame.width * 0.2)
    #expect(slur24.end.x == slurEnd.noteheadFrame.maxX - slurEnd.noteheadFrame.width * 0.2)
    let crossMeasureTies = layout.elements.compactMap(\.curve).filter {
        $0.kind == .tie && layout.noteByID[$0.startNoteID]?.measureID != layout.noteByID[$0.endNoteID]?.measureID
    }
    #expect(crossMeasureTies.count == 4)
    for tie in crossMeasureTies {
        let start = try #require(layout.noteByID[tie.startNoteID])
        let end = try #require(layout.noteByID[tie.endNoteID])
        #expect(tie.start.x == start.noteheadFrame.minX + start.noteheadFrame.width * 0.2)
        #expect(tie.end.x == end.noteheadFrame.maxX - end.noteheadFrame.width * 0.2)
    }
    let targetMeasures = layout.measures.filter { (17...19).contains($0.measureIndex) }
    #expect(targetMeasures.count == 3)
    #expect(Set(targetMeasures.map(\.systemIndex)).count == 1)
    let system = try #require(layout.systems.first { $0.index == targetMeasures.first?.systemIndex })
    #expect(abs(try #require(targetMeasures.last).frame.maxX - system.frame.maxX) < 0.01)
    for start in Array(stride(from: 36, through: 48, by: 3)) + [70, 73] {
        let row = layout.measures.filter { ((start - 1)...(start + 1)).contains($0.measureIndex) }
        #expect(row.count == 3)
        #expect(Set(row.map(\.systemIndex)).count == 1)
        let rowSystem = try #require(layout.systems.first { $0.index == row.first?.systemIndex })
        #expect(abs(try #require(row.last).frame.maxX - rowSystem.frame.maxX) < 0.01)
    }
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
