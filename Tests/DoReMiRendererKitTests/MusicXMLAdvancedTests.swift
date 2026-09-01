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

@Test func parserReadsArticulationsDynamicsAndWedges() throws {
    let result = try MusicXMLParser().parse(data: Data(expressionCoverageXML.utf8))
    let measure = try #require(result.score.parts.first?.measures.first)
    let notes = measure.notes

    #expect(notes[0].articulations.contains(.staccato))
    #expect(notes[1].articulations.contains(.accent))
    #expect(notes[2].articulations.contains(.tenuto))
    #expect(notes[3].articulations.contains(.fermata))
    #expect(measure.directions.contains {
        if case .dynamic(.p) = $0.kind { return true }
        return false
    })
    #expect(measure.directions.contains {
        if case .dynamic(.f) = $0.kind { return true }
        return false
    })
    #expect(measure.directions.contains {
        if case .wedge(.crescendo) = $0.kind { return true }
        return false
    })
    #expect(measure.directions.contains {
        if case .wedge(.stop) = $0.kind { return true }
        return false
    })
    #expect(!result.diagnostics.contains { $0.code == "unsupported.articulations" || $0.code == "unsupported.dynamics" })
}

@Test func parserReadsTiedNotationMetronomeStemBarStyleAndPedal() throws {
    let result = try MusicXMLParser().parse(data: Data(musicXMLWarningCoverageXML.utf8))
    let measure = try #require(result.score.parts.first?.measures.first)
    let notes = measure.notes

    #expect(notes[0].ties == [.start])
    #expect(notes[0].stemDirection == .up)
    #expect(notes[1].ties == [.stop])
    #expect(notes[1].stemDirection == .down)
    #expect(measure.rightBarlineStyle == .lightHeavy)
    #expect(measure.tempoEvents == [
        TempoEvent(
            bpm: 72,
            onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
            source: .metronome,
            measureID: measure.id
        ),
    ])
    #expect(measure.directions.contains {
        if case .pedal(.start) = $0.kind { return true }
        return false
    })
    #expect(!result.diagnostics.contains { diagnostic in
        ["unsupported.tied", "unsupported.stem", "unsupported.bar-style", "unsupported.pedal", "tempo.metronomeUnsupported"]
            .contains(diagnostic.code)
    })
}

@Test func layoutAndPainterUseStemBarStyleAndPedalMetadata() throws {
    let result = try MusicXMLParser().parse(data: Data(musicXMLWarningCoverageXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)

    let notes = try #require(result.score.parts.first?.measures.first?.notes)
    let upStem = try #require(layout.elements.first { $0.noteID == notes[0].id && $0.kind == .stem })
    let downStem = try #require(layout.elements.first { $0.noteID == notes[1].id && $0.kind == .stem })
    let upNoteLayout = try #require(layout.noteByID[notes[0].id])
    let downNoteLayout = try #require(layout.noteByID[notes[1].id])
    #expect(upStem.frame.midY < upNoteLayout.noteheadCenter.y)
    #expect(downStem.frame.midY > downNoteLayout.noteheadCenter.y)
    #expect(layout.elements.contains { $0.kind == .barline && $0.barlineStyle == .lightHeavy })
    #expect(layout.elements.contains { $0.kind == .pedal && $0.pedal?.kind == .start })
}

@Test func layoutCreatesArticulationDynamicsAndHairpinElements() throws {
    let result = try MusicXMLParser().parse(data: Data(expressionCoverageXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)

    #expect(layout.elements.contains { $0.kind == .articulation && $0.articulation?.kind == .staccato })
    #expect(layout.elements.contains { $0.kind == .articulation && $0.articulation?.kind == .accent })
    #expect(layout.elements.contains { $0.kind == .articulation && $0.articulation?.kind == .tenuto })
    #expect(layout.elements.contains { $0.kind == .articulation && $0.articulation?.kind == .fermata })
    #expect(layout.elements.contains { $0.kind == .dynamic && $0.dynamic?.mark == .p })
    #expect(layout.elements.contains { $0.kind == .dynamic && $0.dynamic?.mark == .f })
    #expect(layout.elements.contains { $0.kind == .hairpin && $0.hairpin?.kind == .crescendo })
    #expect(layout.elements.filter { $0.kind == .articulation || $0.kind == .dynamic || $0.kind == .hairpin }.allSatisfy { $0.frame != .zero })

    let notes = result.score.parts.first?.measures.first?.notes ?? []
    for kind in [ScoreArticulationKind.staccato, .tenuto, .fermata] {
        let note = try #require(notes.first { $0.articulations.contains(kind) })
        let noteLayout = try #require(layout.noteByID[note.id])
        let articulation = try #require(layout.elements.first { $0.noteID == note.id && $0.articulation?.kind == kind }?.articulation)
        #expect(abs(articulation.point.y - noteLayout.noteheadCenter.y) < noteLayout.noteheadFrame.height * 1.9)
    }

    let dynamic = try #require(layout.elements.first { $0.kind == .dynamic }?.frame)
    let hairpin = try #require(layout.elements.first { $0.kind == .hairpin }?.frame)
    #expect(abs(dynamic.midY - hairpin.midY) >= 8)
}

@Test func expressionLanesAvoidNotationAndTextCollisions() throws {
    let result = try MusicXMLParser().parse(data: Data(expressionCollisionLaneXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)

    let protectedKinds: Set<ScoreElementKind> = [.notehead, .rest, .stem, .flag, .beam, .accidental, .dot, .ledgerLine, .lyric, .fingering, .articulation]
    let protectedFrames = layout.elements
        .filter { protectedKinds.contains($0.kind) }
        .map { $0.frame.insetBy(dx: -3, dy: -3) }
    let directionElements = layout.elements.filter { $0.kind == .dynamic || $0.kind == .hairpin }

    #expect(!directionElements.isEmpty)
    #expect(directionElements.allSatisfy { directionElement in
        !protectedFrames.contains { directionElement.frame.intersects($0) }
    })
}

@Test func articulationLanesAvoidBeamAndFlagCollisions() throws {
    let result = try MusicXMLParser().parse(data: Data(articulationBeamCollisionXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)
    let articulationFrames = layout.elements
        .filter { $0.kind == .articulation }
        .map(\.frame)
    let notationFrames = layout.elements
        .filter { [.notehead, .stem, .flag, .beam, .accidental, .dot, .ledgerLine].contains($0.kind) }
        .map { $0.frame.insetBy(dx: -2, dy: -2) }

    #expect(!articulationFrames.isEmpty)
    #expect(!layout.elements.filter { $0.kind == .beam }.isEmpty)
    #expect(articulationFrames.allSatisfy { articulationFrame in
        !notationFrames.contains { articulationFrame.intersects($0) }
    })
}

@Test func layoutCreatesCrossMeasureHairpinOnSameSystem() throws {
    let result = try MusicXMLParser().parse(data: Data(crossMeasureHairpinXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score, options: LayoutOptions(pageWidth: 1200))

    let hairpin = try #require(layout.elements.first { $0.kind == .hairpin && $0.hairpin?.kind == .crescendo })
    let secondMeasure = try #require(layout.measures.first { $0.measureID.rawValue == "0.2" })
    #expect(hairpin.frame.minX < secondMeasure.frame.minX)
    #expect(hairpin.frame.maxX > secondMeasure.frame.minX)
}

@Test func dynamicMarkShiftsLeftWhenItWouldCollideWithLowNotehead() throws {
    let result = try MusicXMLParser().parse(data: Data(dynamicCollisionXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)
    let note = try #require(result.score.parts.first?.measures.first?.notes.first)
    let noteLayout = try #require(layout.noteLayout(for: note.id))
    let dynamic = try #require(layout.elements.first { $0.kind == .dynamic && $0.dynamic?.mark == .mf })

    #expect(dynamic.frame.midX <= noteLayout.noteheadCenter.x)
    #expect(!dynamic.frame.intersects(noteLayout.noteheadFrame.insetBy(dx: -1, dy: -1)))
    #expect(noteLayout.noteheadCenter.x - dynamic.frame.midX <= 32)
}

@Test func dynamicMarkAvoidsCrossStaffCentralCollision() throws {
    let result = try MusicXMLParser().parse(data: Data(dynamicGrandStaffCollisionXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)
    let note = try #require(result.score.parts.first?.measures.first?.notes.first { $0.staffID.rawValue == "2" })
    let noteLayout = try #require(layout.noteLayout(for: note.id))
    let dynamic = try #require(layout.elements.first { $0.kind == .dynamic && $0.dynamic?.mark == .mf })

    #expect(dynamic.staffID?.rawValue == "1")
    #expect(dynamic.frame.midX <= noteLayout.noteheadCenter.x)
    #expect(!dynamic.frame.intersects(noteLayout.noteheadFrame.insetBy(dx: -1, dy: -1)))
    #expect(noteLayout.noteheadCenter.x - dynamic.frame.midX <= 32)
}

@Test func dynamicMarkAvoidsRepeatBarlineInGrandStaff() throws {
    let result = try MusicXMLParser().parse(data: Data(dynamicGrandStaffCollisionXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)
    let dynamic = try #require(layout.elements.first { $0.kind == .dynamic && $0.dynamic?.mark == .mf })
    let repeatBarline = try #require(layout.elements.first { $0.kind == .barline && $0.repeatBarline?.direction == .forward })

    #expect(!dynamic.frame.intersects(repeatBarline.frame.insetBy(dx: -4, dy: -4)))
}

@Test func hairpinAvoidsGrandStaffNoteCollision() throws {
    let result = try MusicXMLParser().parse(data: Data(hairpinGrandStaffCollisionXML.utf8))
    let layout = try ScoreLayoutEngine().layout(score: result.score)
    let hairpin = try #require(layout.elements.first { $0.kind == .hairpin && $0.hairpin?.kind == .crescendo })
    let lowerStaffNote = try #require(result.score.parts.first?.measures.first?.notes.first { $0.staffID.rawValue == "2" })
    let lowerStaffNoteLayout = try #require(layout.noteLayout(for: lowerStaffNote.id))

    #expect(!hairpin.frame.intersects(lowerStaffNoteLayout.noteheadFrame.insetBy(dx: -6, dy: -6)))
    #expect(abs(hairpin.frame.midY - lowerStaffNoteLayout.noteheadCenter.y) >= lowerStaffNoteLayout.noteheadFrame.height * 0.6)
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

@Test func fingeringHonorsPlacementAndAvoidsBeamedStemGeometry() throws {
    let result = try MusicXMLParser().parse(data: Data(fingeringCollisionXML.utf8))
    let notes = try #require(result.score.parts.first?.measures.first?.notes)
    #expect(notes[0].fingerings == [FingeringAnnotation(text: "4")])
    #expect(notes[2].fingerings == [FingeringAnnotation(text: "2", placement: .below)])

    let layout = try ScoreLayoutEngine().layout(score: result.score)
    let upperFingering = try #require(layout.elements.first { $0.kind == .fingering && $0.noteID == notes[0].id })
    let lowerFingering = try #require(layout.elements.first { $0.kind == .fingering && $0.noteID == notes[2].id })
    let lowerNoteLayout = try #require(layout.noteLayout(for: notes[2].id))
    let beamFrames = layout.elements.filter { $0.kind == .beam }.map(\.frame)
    let upperStemFrames = layout.elements
        .filter { $0.kind == .stem && ($0.noteID == notes[0].id || $0.noteID == notes[1].id) }
        .map(\.frame)

    #expect(lowerFingering.frame.minY > lowerNoteLayout.noteheadFrame.maxY)
    #expect(beamFrames.allSatisfy { !upperFingering.frame.insetBy(dx: -1, dy: -1).intersects($0) })
    #expect(upperStemFrames.allSatisfy { !upperFingering.frame.insetBy(dx: -1, dy: -1).intersects($0) })
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

@Test func parserRetainsSymbolicSegnoAndCodaAndExpandsDalSegnoAlCoda() throws {
    let result = try MusicXMLParser().parse(data: Data(symbolicDalSegnoCodaXML.utf8))
    let measures = try #require(result.score.parts.first?.measures)

    #expect(measures[0].playbackJumpMarkers.contains { $0.kind == .segno })
    #expect(measures[1].playbackJumpMarkers.contains { $0.kind == .toCoda })
    #expect(measures[2].playbackJumpMarkers.contains { $0.kind == .dalSegnoAlCoda })
    #expect(measures[3].playbackJumpMarkers.contains { $0.kind == .coda })
    #expect(!result.diagnostics.contains { $0.code == "unsupported.segno" || $0.code == "unsupported.coda" })

    let layout = try ScoreLayoutEngine().layout(score: result.score)
    let jumpMarkerKinds = Set(layout.elements.compactMap { $0.playbackJumpMarker?.marker.kind })
    #expect(jumpMarkerKinds.isSuperset(of: [.segno, .toCoda, .dalSegnoAlCoda, .coda]))

    let builder = PlaybackSequenceBuilder()
    let events = builder.build(score: result.score)
    let metadata = builder.metadata(score: result.score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.1", "0.2", "0.4", "0.5"])
    #expect(!metadata.diagnostics.contains { diagnostic in
        diagnostic.code == "jump.dsSegnoMissing"
            || diagnostic.code == "jump.toCodaMissing"
            || diagnostic.code == "jump.codaMissing"
            || diagnostic.code == "jump.codaUnsupported"
    })
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

private let fingeringCollisionXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Fingerings</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
    <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>16th</type><stem>up</stem><beam number="1">begin</beam><beam number="2">begin</beam><notations><technical><fingering>4</fingering></technical></notations></note>
    <note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration><type>16th</type><stem>up</stem><beam number="1">end</beam><beam number="2">end</beam><notations><technical><fingering>3</fingering></technical></notations></note>
    <note><pitch><step>G</step><octave>4</octave></pitch><duration>2</duration><type>eighth</type><stem>down</stem><notations><technical><fingering placement="below">2</fingering></technical></notations></note>
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

private let expressionCoverageXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Expression</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <direction placement="below"><direction-type><dynamics><p/></dynamics></direction-type><staff>1</staff></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff><notations><articulations><staccato/></articulations></notations></note>
      <direction placement="below"><direction-type><wedge type="crescendo"/></direction-type><staff>1</staff></direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff><notations><articulations><accent/></articulations></notations></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff><notations><articulations><tenuto/></articulations></notations></note>
      <direction placement="below"><direction-type><wedge type="stop"/></direction-type><staff>1</staff></direction>
      <direction placement="below"><direction-type><dynamics><f/></dynamics></direction-type><staff>1</staff></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff><notations><fermata/></notations></note>
    </measure>
  </part>
</score-partwise>
"""

private let musicXMLWarningCoverageXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Warning Coverage</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <direction placement="below">
        <direction-type>
          <metronome><beat-unit>quarter</beat-unit><per-minute>72</per-minute></metronome>
          <pedal type="start"/>
        </direction-type>
        <staff>1</staff>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
        <stem>up</stem>
        <notations><tied type="start"/></notations>
      </note>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
        <stem>down</stem>
        <notations><tied type="stop"/></notations>
      </note>
      <barline location="right"><bar-style>light-heavy</bar-style></barline>
    </measure>
  </part>
</score-partwise>
"""

private let expressionCollisionLaneXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Expression Collision Lanes</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <direction placement="below"><direction-type><dynamics><mf/></dynamics></direction-type><staff>1</staff></direction>
      <direction placement="below"><direction-type><wedge type="crescendo"/></direction-type><staff>1</staff></direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
        <notations><articulations><staccato/></articulations></notations>
        <lyric><syllabic>single</syllabic><text>Do</text></lyric>
      </note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <direction placement="below"><direction-type><wedge type="stop"/></direction-type><staff>1</staff></direction>
    </measure>
  </part>
</score-partwise>
"""

private let articulationBeamCollisionXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Articulation Beam Collision</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>8</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>G</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><staff>1</staff>
        <notations><articulations><staccato/></articulations></notations>
      </note>
      <note>
        <pitch><step>A</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><staff>1</staff>
        <notations><articulations><tenuto/></articulations></notations>
      </note>
      <note>
        <pitch><step>B</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><staff>1</staff>
        <notations><fermata/></notations>
      </note>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><staff>1</staff></note>
    </measure>
  </part>
</score-partwise>
"""

private let crossMeasureHairpinXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Cross Measure Hairpin</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <direction placement="below"><direction-type><wedge type="crescendo"/></direction-type><staff>1</staff></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
    </measure>
    <measure number="2">
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <direction placement="below"><direction-type><wedge type="stop"/></direction-type><staff>1</staff></direction>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><pitch><step>B</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
    </measure>
  </part>
</score-partwise>
"""

private let dynamicCollisionXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Dynamic Collision</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <direction placement="below"><direction-type><dynamics><mf/></dynamics></direction-type><staff>1</staff></direction>
      <note><pitch><step>A</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
    </measure>
  </part>
</score-partwise>
"""

private let symbolicDalSegnoCodaXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Symbolic D.S. Coda</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <direction placement="above"><direction-type><segno/></direction-type></direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    </measure>
    <measure number="2">
      <direction placement="above"><direction-type><words>To 𝄌</words></direction-type></direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    </measure>
    <measure number="3">
      <direction placement="above"><direction-type><words>Dal Segno al Coda</words></direction-type></direction>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    </measure>
    <measure number="4">
      <direction placement="above"><direction-type><coda/></direction-type></direction>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    </measure>
    <measure number="5">
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    </measure>
  </part>
</score-partwise>
"""

private let dynamicGrandStaffCollisionXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Dynamic Grand Staff Collision</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="below"><direction-type><dynamics><mf/></dynamics></direction-type><staff>1</staff></direction>
      <barline location="left"><repeat direction="forward"/></barline>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>2</staff></note>
      <backup><duration>4</duration></backup>
      <note><pitch><step>B</step><octave>4</octave></pitch><duration>4</duration><voice>2</voice><type>quarter</type><staff>1</staff></note>
    </measure>
  </part>
</score-partwise>
"""

private let hairpinGrandStaffCollisionXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Hairpin Grand Staff Collision</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="below"><direction-type><wedge type="crescendo"/></direction-type><staff>1</staff></direction>
      <note><pitch><step>B</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <direction placement="below"><direction-type><wedge type="stop"/></direction-type><staff>1</staff></direction>
      <backup><duration>4</duration></backup>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>2</voice><type>whole</type><staff>2</staff></note>
    </measure>
  </part>
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
