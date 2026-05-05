import DoReMiRendererKit
import Foundation
import Testing
@testable import DoReMiPalette

@Suite("Palette score loading")
struct PaletteScoreLoaderTests {
    @Test func sampleLoadSucceedsAndKeepsDiagnostics() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.validMusicXML, sourceName: "unit.musicxml")

        #expect(loaded.sourceName == "unit.musicxml")
        #expect(!loaded.score.parts.isEmpty)
        #expect(!loaded.layout.noteByID.isEmpty)
        #expect(!loaded.playbackEvents.isEmpty)
        #expect(loaded.diagnostics.isEmpty)
    }

    @Test func parseFailureThrows() {
        #expect(throws: Error.self) {
            _ = try PaletteScoreLoader().load(data: Data("<score-partwise>".utf8), sourceName: "broken.musicxml")
        }
    }

    @Test func unsupportedExtensionThrows() {
        #expect(throws: PaletteImportError.unsupportedExtension("txt")) {
            _ = try PaletteScoreLoader().scoreInput(for: "score.txt", data: Data())
        }
    }

    @Test func supportedFileExtensionsMapToScoreInput() throws {
        let loader = PaletteScoreLoader()
        let data = Data("fixture".utf8)

        _ = try loader.scoreInput(for: "score.musicxml", data: data)
        _ = try loader.scoreInput(for: "score.xml", data: data)
        _ = try loader.scoreInput(for: "score.mxl", data: data)
    }

    @Test func previousNextChangesCurrentNoteID() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.validMusicXML, sourceName: "unit.musicxml")
        var cursor = PalettePlaybackCursor(events: loaded.playbackEvents)
        let first = cursor.currentNoteID

        cursor.move(by: 1)

        #expect(cursor.currentNoteID != first)
        #expect(cursor.index == 1)
    }

    @Test func colorSettingsDoNotChangeLayoutIdentity() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.validMusicXML, sourceName: "unit.musicxml")
        let noteIDs = Set(loaded.layout.noteByID.keys)
        let elementIDs = Set(loaded.layout.elementByID.keys)

        _ = PaletteStyleFactory.makeStyle(noteColorVisible: true, staffColorVisible: false)
        _ = PaletteStyleFactory.makeStyle(noteColorVisible: false, staffColorVisible: true)

        #expect(Set(loaded.layout.noteByID.keys) == noteIDs)
        #expect(Set(loaded.layout.elementByID.keys) == elementIDs)
    }

    static let validMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Unit</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><rest/><duration>1</duration><voice>1</voice><type>quarter</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)
}
