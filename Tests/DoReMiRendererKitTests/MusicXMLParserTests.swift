import Foundation
import Testing
@testable import DoReMiRendererKit

@Test func parserReadsSingleMelodyAttributesAndDeterministicIDs() throws {
    let result = try parseMusicXML(singleMelodyXML)
    let measure = try #require(result.score.parts.first?.measures.first)

    #expect(result.score.parts.first?.id == "P1")
    #expect(result.score.parts.first?.name == "Piano")
    #expect(measure.keySignature == KeySignature(fifths: 0))
    #expect(measure.timeSignature == TimeSignature(beats: 4, beatType: 4))
    #expect(measure.clef == Clef(kind: .treble))
    #expect(measure.notes.map(\.pitch) == [
        Pitch(step: .c, octave: 4),
        Pitch(step: .d, octave: 4),
    ])
    #expect(measure.notes.map(\.onset) == [
        MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
        MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
    ])

    let resultAgain = try parseMusicXML(singleMelodyXML)
    #expect(result.score.parts.flatMap(\.measures).flatMap(\.notes).map(\.id) ==
        resultAgain.score.parts.flatMap(\.measures).flatMap(\.notes).map(\.id))
}

@Test func parserReadsScoreTitleMetadata() throws {
    let result = try parseMusicXML(titledScoreXML)

    #expect(result.score.title == "Movement Title")
    #expect(!result.diagnostics.contains { $0.code == "unsupported.work-title" || $0.code == "unsupported.movement-title" })
}

@Test func parserFallsBackToWorkTitleWhenMovementTitleIsPlaceholderSubtitle() throws {
    let result = try parseMusicXML(workTitleWithPlaceholderSubtitleXML)

    #expect(result.score.title == "美女と野獣")
}

@Test func parserKeepsGrandStaffNoteIDsUniqueForSameVoiceAndOnset() throws {
    let notes = try parseMusicXML(grandStaffXML).score.parts.flatMap(\.measures).flatMap(\.notes)

    #expect(notes.count == 2)
    #expect(Set(notes.map(\.id)).count == notes.count)
    #expect(Set(notes.map(\.staffID)) == [StaffID(rawValue: "1"), StaffID(rawValue: "2")])
    #expect(Set(notes.map(\.onset)) == [MusicalTime(ticks: 0, ticksPerQuarterNote: 4)])
}

@Test func parserReadsChordAndRestAtExpectedOnsets() throws {
    let notes = try parseMusicXML(chordAndRestXML).score.parts.flatMap(\.measures).flatMap(\.notes)

    #expect(notes.count == 3)
    #expect(notes[0].pitch == Pitch(step: .c, octave: 4))
    #expect(notes[1].pitch == Pitch(step: .e, octave: 4))
    #expect(notes[1].isChordTone)
    #expect(notes[1].onset == notes[0].onset)
    #expect(notes[1].chordOrdinal == 1)
    #expect(notes[2].pitch == nil)
    #expect(notes[2].onset == MusicalTime(ticks: 4, ticksPerQuarterNote: 4))
}

@Test func parserReadsNoteValueKindsAndDots() throws {
    let notes = try parseMusicXML(noteValuesAndDotsXML).score.parts.flatMap(\.measures).flatMap(\.notes)

    #expect(notes.map(\.noteValueKind) == [.whole, .half, .quarter, .eighth, .sixteenth, .thirtySecond])
    #expect(notes.map(\.dotCount) == [0, 1, 0, 0, 0, 0])
    #expect(notes[4].pitch == nil)
    #expect(notes[5].pitch == Pitch(step: .g, octave: 4))
}

@Test func parserReadsMusicXMLBeamTags() throws {
    let notes = try parseMusicXML(beamedNotesXML).score.parts.flatMap(\.measures).flatMap(\.notes)

    #expect(notes.map(\.beams) == [
        [MusicXMLBeam(number: 1, value: .begin), MusicXMLBeam(number: 2, value: .begin)],
        [MusicXMLBeam(number: 1, value: .continue), MusicXMLBeam(number: 2, value: .continue)],
        [MusicXMLBeam(number: 1, value: .end), MusicXMLBeam(number: 2, value: .end)],
    ])
}

@Test func parserReadsMidMeasureClefChangesWithOnset() throws {
    let measures = try parseMusicXML(midMeasureClefXML).score.parts.flatMap(\.measures)
    let first = try #require(measures.first)
    let second = try #require(measures.dropFirst().first)

    #expect(first.clefsByStaff[StaffID(rawValue: "2")] == Clef(kind: .bass))
    #expect(first.clefChanges == [
        ClefChange(
            staffID: StaffID(rawValue: "2"),
            clef: Clef(kind: .treble),
            onset: MusicalTime(ticks: 3, ticksPerQuarterNote: 1)
        ),
    ])
    #expect(second.effectiveClefsByStaff[StaffID(rawValue: "2")] == Clef(kind: .treble))
}

@Test func parserAppliesBackupAndForwardToOnsets() throws {
    let notes = try parseMusicXML(backupForwardXML).score.parts.flatMap(\.measures).flatMap(\.notes)

    #expect(notes.map(\.voiceID) == [VoiceID(rawValue: "1"), VoiceID(rawValue: "2"), VoiceID(rawValue: "2")])
    #expect(notes.map(\.onset) == [
        MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
        MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
        MusicalTime(ticks: 6, ticksPerQuarterNote: 4),
    ])
}

@Test func parserReadsAccidentalsTiesAndReportsUnsupportedElements() throws {
    let result = try parseMusicXML(accidentalTieUnsupportedXML)
    let notes = result.score.parts.flatMap(\.measures).flatMap(\.notes)

    #expect(notes[0].pitch == Pitch(step: .f, octave: 4, alter: 1))
    #expect(notes[0].accidental == "sharp")
    #expect(notes[0].ties == [.start])
    #expect(notes[1].ties == [.stop])
    let transpose = try #require(result.score.parts.first?.measures.first?.musicXMLTranspose)
    #expect(transpose.chromatic == 2)
    #expect(result.diagnostics.contains { $0.severity == .warning && $0.code == "unsupported.transpose" })
}

@Test func scoreTimewiseFailsWhenUnsupportedPolicyIsFail() throws {
    let parser = MusicXMLParser(unsupportedFeaturePolicy: .fail)
    do {
        _ = try parser.parse(data: Data(scoreTimewiseXML.utf8))
        Issue.record("Expected score-timewise to fail")
    } catch MusicXMLParserError.unsupportedFeature(let diagnostic) {
        #expect(diagnostic.code == "unsupported.score-timewise")
    }
}

@Test func scoreTimewiseIgnorePolicyReturnsWarningAndEmptyScore() throws {
    let result = try MusicXMLParser(unsupportedFeaturePolicy: .ignoreWithWarning).parse(data: Data(scoreTimewiseXML.utf8))

    #expect(result.score.parts.isEmpty)
    #expect(result.diagnostics.contains { $0.severity == .warning && $0.code == "unsupported.score-timewise" })
}

@Test func unsupportedElementsFailWhenPolicyIsFail() throws {
    let parser = MusicXMLParser(unsupportedFeaturePolicy: .fail)

    do {
        _ = try parser.parse(data: Data(accidentalTieUnsupportedXML.utf8))
        Issue.record("Expected unsupported transpose to fail")
    } catch MusicXMLParserError.unsupportedFeature(let diagnostic) {
        #expect(diagnostic.code == "unsupported.transpose")
    }
}

private func parseMusicXML(_ xml: String) throws -> ParseResult {
    try MusicXMLParser().parse(data: Data(xml.utf8))
}

private let singleMelodyXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
      </note>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let titledScoreXML = """
<score-partwise version="4.0">
  <work><work-title>Work Title</work-title></work>
  <movement-title>Movement Title</movement-title>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let workTitleWithPlaceholderSubtitleXML = """
<score-partwise version="4.0">
  <work><work-title>美女と野獣</work-title></work>
  <movement-title>Subtitle</movement-title>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1"><measure number="1"/></part>
</score-partwise>
"""

private let grandStaffXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>1</staff>
      </note>
      <backup><duration>4</duration></backup>
      <note>
        <pitch><step>C</step><octave>3</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>2</staff>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let chordAndRestXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Part</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>1</staff>
      </note>
      <note>
        <chord/><pitch><step>E</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>1</staff>
      </note>
      <note>
        <rest/><duration>4</duration><voice>1</voice><staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let noteValuesAndDotsXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Part</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>16</divisions></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>64</duration><voice>1</voice><staff>1</staff><type>whole</type></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>48</duration><voice>1</voice><staff>1</staff><type>half</type><dot/></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>16</duration><voice>1</voice><staff>1</staff><type>quarter</type></note>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>8</duration><voice>1</voice><staff>1</staff><type>eighth</type></note>
      <note><rest/><duration>4</duration><voice>1</voice><staff>1</staff><type>16th</type></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><staff>1</staff><type>32nd</type></note>
    </measure>
  </part>
</score-partwise>
"""

private let beamedNotesXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>1</duration><voice>1</voice><type>16th</type><staff>1</staff>
        <beam number="1">begin</beam><beam number="2">begin</beam>
      </note>
      <note>
        <pitch><step>D</step><octave>5</octave></pitch>
        <duration>1</duration><voice>1</voice><type>16th</type><staff>1</staff>
        <beam number="1">continue</beam><beam number="2">continue</beam>
      </note>
      <note>
        <pitch><step>E</step><octave>5</octave></pitch>
        <duration>1</duration><voice>1</voice><type>16th</type><staff>1</staff>
        <beam number="1">end</beam><beam number="2">end</beam>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let backupForwardXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Part</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>8</duration><voice>1</voice><staff>1</staff>
      </note>
      <backup><duration>8</duration></backup>
      <note>
        <pitch><step>G</step><octave>3</octave></pitch>
        <duration>4</duration><voice>2</voice><staff>1</staff>
      </note>
      <forward><duration>2</duration></forward>
      <note>
        <pitch><step>A</step><octave>3</octave></pitch>
        <duration>2</duration><voice>2</voice><staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let midMeasureClefXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>3</octave></pitch>
        <duration>3</duration><voice>1</voice><type>half</type><staff>2</staff>
      </note>
      <attributes>
        <clef number="2"><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>1</duration><voice>1</voice><type>quarter</type><staff>2</staff>
      </note>
    </measure>
    <measure number="2">
      <note>
        <pitch><step>F</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><type>whole</type><staff>2</staff>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let accidentalTieUnsupportedXML = """
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Part</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <transpose><chromatic>2</chromatic></transpose>
      </attributes>
      <note>
        <pitch><step>F</step><alter>1</alter><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>1</staff>
        <accidental>sharp</accidental>
        <tie type="start"/>
      </note>
      <note>
        <pitch><step>F</step><alter>1</alter><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>1</staff>
        <tie type="stop"/>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let scoreTimewiseXML = """
<score-timewise version="4.0">
  <part-list><score-part id="P1"><part-name>Part</part-name></score-part></part-list>
  <measure number="1"><part id="P1"/></measure>
</score-timewise>
"""
