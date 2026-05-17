import CoreGraphics
import Foundation
import Testing
@testable import DoReMiRendererKit

@Test func parserReadsLyricsAndFingerings() throws {
    let result = try MusicXMLParser().parse(data: Data(lyricsFingeringXML.utf8))
    let note = try #require(result.score.parts.first?.measures.first?.notes.first)

    #expect(note.lyrics == [LyricAnnotation(text: "Do", syllabic: .single)])
    #expect(note.fingerings == [FingeringAnnotation(text: "1")])
}

@Test func layoutCreatesLyricAndFingeringElements() throws {
    let result = try MusicXMLParser().parse(data: Data(lyricsFingeringXML.utf8))
    let note = try #require(result.score.parts.first?.measures.first?.notes.first)
    let layout = try ScoreLayoutEngine().layout(score: result.score)

    let lyric = try #require(layout.elements.first { $0.kind == .lyric && $0.noteID == note.id })
    let fingering = try #require(layout.elements.first { $0.kind == .fingering && $0.noteID == note.id })

    #expect(lyric.annotation?.text == "Do")
    #expect(fingering.annotation?.text == "1")
    #expect(layout.elementByID[lyric.id]?.kind == .lyric)
    #expect(layout.elementByID[fingering.id]?.kind == .fingering)
    #expect(lyric.frame != .zero)
    #expect(fingering.frame != .zero)
}

@Test func painterDrawsLyricAndFingeringTextFromLayoutElements() throws {
    let result = try MusicXMLParser().parse(data: Data(lyricsFingeringXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)
    var context = AdvancedRecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: result.score, style: ScoreStyle(), into: &context)

    #expect(context.texts.contains("Do"))
    #expect(context.texts.contains("1"))
}

@Test func hitTestLyricAndFingeringReturnAssociatedNoteID() throws {
    let result = try MusicXMLParser().parse(data: Data(lyricsFingeringXML.utf8))
    let note = try #require(result.score.parts.first?.measures.first?.notes.first)
    let layout = try ScoreLayoutEngine().layout(score: result.score)
    let lyric = try #require(layout.elements.first { $0.kind == .lyric && $0.noteID == note.id })
    let fingering = try #require(layout.elements.first { $0.kind == .fingering && $0.noteID == note.id })

    #expect(layout.hitTest(point: lyric.frame.center, radius: 2).nearestNoteID == note.id)
    #expect(layout.hitTest(point: fingering.frame.center, radius: 2).nearestNoteID == note.id)
}

@Test func parserReadsKeyFifthsAndMode() throws {
    let result = try MusicXMLParser().parse(data: Data(keySignatureXML.utf8))
    let measure = try #require(result.score.parts.first?.measures.first)

    #expect(measure.keySignature == KeySignature(fifths: 2, mode: "major"))
}

@Test func layoutCreatesTrebleAndBassKeySignatureElements() throws {
    let result = try MusicXMLParser().parse(data: Data(grandStaffKeySignatureXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score, options: LayoutOptions(staffSpace: 10))
    let keyElements = layout.elements.filter { $0.kind == .keySignature }

    #expect(keyElements.count == 4)
    #expect(Set(keyElements.map(\.staffID)) == [StaffID(rawValue: "1"), StaffID(rawValue: "2")])
    #expect(keyElements.allSatisfy { $0.id.rawValue.contains("keySignature") })
    #expect(Set(keyElements.compactMap(\.accidental)) == ["sharp"])

    let treble = try #require(keyElements.first { $0.staffID == StaffID(rawValue: "1") })
    let bass = try #require(keyElements.first { $0.staffID == StaffID(rawValue: "2") })
    #expect(treble.frame.midY != bass.frame.midY)
}

@Test func keySignatureDoesNotChangePlaybackOrColorRuleIdentity() throws {
    let result = try MusicXMLParser().parse(data: Data(keySignatureXML.utf8))
    let renderer = DoReMiRenderer()
    let layout = try renderer.layout(score: result.score)
    let playback = renderer.makePlaybackSequence(score: result.score)
    let elementIDs = Set(layout.elementByID.keys)
    let style = ScoreStyle(
        staffLineStyle: .rule(ClefAwareStaffLineColorRule(defaultPalette: defaultEducationalPalette)),
        noteColorStyle: .rule(PitchClassNoteColorRule(palette: defaultEducationalPalette))
    )

    _ = layout.elements.map {
        style.colorResolver.resolvedStyle(for: $0, score: result.score, layout: layout, style: style, selection: nil)
    }

    #expect(renderer.makePlaybackSequence(score: result.score) == playback)
    #expect(Set(layout.elementByID.keys) == elementIDs)
}

@Test func parserReadsSoundTempoAndRepeatMetadata() throws {
    let result = try MusicXMLParser().parse(data: Data(tempoRepeatXML.utf8))
    let measure = try #require(result.score.parts.first?.measures.first)

    #expect(measure.tempoEvents.map(\.bpm) == [96])
    #expect(measure.repeatBarlines.map(\.direction) == [.backward])
    #expect(!result.diagnostics.contains { $0.code == "repeat.playbackExpansionUnsupported" })
}

@Test func parserRetainsRepeatEndingAndJumpMarkers() throws {
    let result = try MusicXMLParser().parse(data: Data(repeatEndingJumpXML.utf8))
    let measures = try #require(result.score.parts.first?.measures)

    #expect(measures[1].repeatBarlines.map(\.direction) == [.forward])
    #expect(measures[2].repeatEndings.contains { $0.numbers == [1] && $0.kind == .start })
    #expect(measures[2].repeatEndings.contains { $0.numbers == [1] && $0.kind == .stop })
    #expect(measures[3].repeatEndings.contains { $0.numbers == [2] && $0.kind == .start })
    #expect(measures[3].playbackJumpMarkers.contains { $0.kind == .fine })
    #expect(measures[4].playbackJumpMarkers.contains { $0.kind == .daCapoAlFine })
}

@Test func parserRetainsOneBarMeasureRepeatMetadata() throws {
    let result = try MusicXMLParser().parse(data: Data(measureRepeatXML.utf8))
    let measure = try #require(result.score.parts.first?.measures.first)

    #expect(measure.measureRepeat == MeasureRepeat(count: 1))
    var unsupportedMeasureRepeatDiagnostics: [RendererDiagnostic] = []
    for diagnostic in result.diagnostics {
        let elementName = diagnostic.location?.elementName
        if elementName == "measure-style" || elementName == "measure-repeat" {
            unsupportedMeasureRepeatDiagnostics.append(diagnostic)
        }
    }
    #expect(unsupportedMeasureRepeatDiagnostics.isEmpty)
}

@Test func playbackMetadataReportsTempoAndRepeatFallbackDiagnostics() throws {
    let renderer = DoReMiRenderer()
    let score = try renderer.parseMusicXML(data: Data(tempoRepeatXML.utf8))
    let events = renderer.makePlaybackSequence(score: score)
    let unexpandedEvents = renderer.makePlaybackSequence(
        score: score,
        options: PlaybackOptions(expandRepeats: false)
    )
    let metadata = renderer.makePlaybackMetadata(score: score)

    #expect(metadata.tempoEvents.map(\.bpm) == [96])
    #expect(metadata.repeatBarlines.map(\.direction) == [.backward])
    #expect(metadata.diagnostics.contains { $0.code == "repeat.startMissingFallback" })
    #expect(events.count == unexpandedEvents.count * 2)
    #expect(events.prefix(unexpandedEvents.count).map(\.noteIDs) == unexpandedEvents.map(\.noteIDs))
    #expect(events.suffix(unexpandedEvents.count).map(\.noteIDs) == unexpandedEvents.map(\.noteIDs))
}

@Test func complexMusicXMLFeaturesEmitSpecificDiagnostics() throws {
    let result = try MusicXMLParser().parse(data: Data(complexDiagnosticsXML.utf8))
    let codes = Set(result.diagnostics.map(\.code))

    #expect(!codes.contains("unsupported.tuplet.rendering"))
    #expect(!codes.contains("unsupported.slur.rendering"))
    #expect(codes.contains("unsupported.ornaments"))
    #expect(codes.contains("unsupported.grace.layout"))
    #expect(codes.contains("unsupported.transpose"))
}

@Test func parserRetainsBasicSlurAndTupletMeaningForLayout() throws {
    let result = try MusicXMLParser().parse(data: Data(slurTupletXML.utf8))
    let notes = try #require(result.score.parts.first?.measures.first?.notes)

    #expect(notes[0].slurs == [.start])
    #expect(notes[2].slurs == [.stop])
    #expect(notes[3].tuplet?.kind == .start)
    #expect(notes[3].tuplet?.actualNotes == 3)
    #expect(notes[3].tuplet?.normalNotes == 2)
    #expect(notes[5].tuplet?.kind == .stop)

    let layout = try ScoreLayoutEngine().layout(score: result.score)
    #expect(layout.elements.contains { $0.kind == .slur })
    #expect(layout.elements.contains { $0.kind == .tuplet && $0.tuplet?.number == "3" })
}

@Test func complexVoiceAndCrossStaffDiagnosticsComeFromLayout() throws {
    let result = try MusicXMLParser().parse(data: Data(crossStaffCollisionXML.utf8))
    let layoutResult = try ScoreLayoutEngine().layoutWithDiagnostics(score: result.score)
    let codes = Set(layoutResult.diagnostics.map(\.code))

    #expect(codes.contains("unsupported.voice.collisionAvoidance"))
    #expect(codes.contains("unsupported.crossStaff.notation"))
}

@Test func graceNotesAreNotIncludedInPlaybackEvents() throws {
    let renderer = DoReMiRenderer()
    let score = try renderer.parseMusicXML(data: Data(complexDiagnosticsXML.utf8))
    let events = renderer.makePlaybackSequence(score: score)

    #expect(events.count == 1)
}

private struct AdvancedRecordingDrawingContext: ScoreDrawingContext {
    var texts: [String] = []

    mutating func fill(_ rect: CGRect, color: ScoreColor) {}
    mutating func strokeLine(from start: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {}
    mutating func fillEllipse(in rect: CGRect, color: ScoreColor) {}
    mutating func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat) {}
    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?) {
        texts.append(text)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private let lyricsFingeringXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Advanced</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
    <note>
      <pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff>
      <lyric><syllabic>single</syllabic><text>Do</text></lyric>
      <notations><technical><fingering>1</fingering></technical></notations>
    </note>
  </measure></part>
</score-partwise>
"""

private let keySignatureXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Key</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions><key><fifths>2</fifths><mode>major</mode></key><clef><sign>G</sign><line>2</line></clef></attributes>
    <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
  </measure></part>
</score-partwise>
"""

private let slurTupletXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>S6 Advanced</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>12</divisions><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
    <note><pitch><step>C</step><octave>5</octave></pitch><duration>12</duration><voice>1</voice><type>quarter</type><notations><slur type="start"/></notations></note>
    <note><pitch><step>D</step><octave>5</octave></pitch><duration>12</duration><voice>1</voice><type>quarter</type></note>
    <note><pitch><step>E</step><octave>5</octave></pitch><duration>12</duration><voice>1</voice><type>quarter</type><notations><slur type="stop"/></notations></note>
    <note><pitch><step>F</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification><notations><tuplet type="start"/></notations></note>
    <note><pitch><step>G</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
    <note><pitch><step>A</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification><notations><tuplet type="stop"/></notations></note>
  </measure></part>
</score-partwise>
"""

private let grandStaffKeySignatureXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Grand Key</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes>
      <divisions>4</divisions><key><fifths>2</fifths></key>
      <clef number="1"><sign>G</sign><line>2</line></clef>
      <clef number="2"><sign>F</sign><line>4</line></clef>
    </attributes>
    <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
    <backup><duration>4</duration></backup>
    <note><pitch><step>D</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><staff>2</staff></note>
  </measure></part>
</score-partwise>
"""

private let tempoRepeatXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Tempo Repeat</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
    <direction><sound tempo="96"/></direction>
    <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
    <barline location="right"><repeat direction="backward"/></barline>
  </measure></part>
</score-partwise>
"""

private let repeatEndingJumpXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Repeat Ending Jump</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
    </measure>
    <measure number="2">
      <barline location="left"><repeat direction="forward"/></barline>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
    </measure>
    <measure number="3">
      <barline location="left"><ending number="1" type="start">1.</ending></barline>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
      <barline location="right"><ending number="1" type="stop"/><repeat direction="backward"/></barline>
    </measure>
    <measure number="4">
      <barline location="left"><ending number="2" type="start">2.</ending></barline>
      <direction><direction-type><words>Fine</words></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
      <barline location="right"><ending number="2" type="stop"/></barline>
    </measure>
    <measure number="5">
      <direction><direction-type><words>D.C. al Fine</words></direction-type></direction>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
    </measure>
  </part>
</score-partwise>
"""

private let measureRepeatXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Measure Repeat</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes>
      <divisions>4</divisions>
      <clef><sign>G</sign><line>2</line></clef>
      <measure-style><measure-repeat type="start">1</measure-repeat></measure-style>
    </attributes>
    <note><rest/><duration>16</duration><voice>1</voice><type>whole</type><staff>1</staff></note>
  </measure></part>
</score-partwise>
"""

private let complexDiagnosticsXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Complex</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes>
      <divisions>6</divisions><transpose><chromatic>2</chromatic></transpose>
      <clef><sign>G</sign><line>2</line></clef>
    </attributes>
    <note>
      <grace/><pitch><step>D</step><octave>4</octave></pitch><duration>0</duration><voice>1</voice><staff>1</staff>
      <notations><slur type="start"/><ornaments><trill-mark/></ornaments></notations>
    </note>
    <note>
      <pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff>
      <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
      <notations><tuplet type="start"/></notations>
    </note>
  </measure></part>
</score-partwise>
"""

private let crossStaffCollisionXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voices</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes>
      <divisions>4</divisions>
      <clef number="1"><sign>G</sign><line>2</line></clef>
      <clef number="2"><sign>F</sign><line>4</line></clef>
    </attributes>
    <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
    <backup><duration>4</duration></backup>
    <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>2</voice><staff>1</staff></note>
    <backup><duration>4</duration></backup>
    <note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><staff>2</staff></note>
  </measure></part>
</score-partwise>
"""
