#if os(iOS)
import Foundation

enum SnapshotFixtures {
    static let singleMelody = """
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Snapshot Melody</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>4</divisions>
            <key><fifths>0</fifths></key>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
          <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
          <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
        </measure>
      </part>
    </score-partwise>
    """

    static let grandStaffSimple = """
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Snapshot Piano</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>4</divisions>
            <clef number="1"><sign>G</sign><line>2</line></clef>
            <clef number="2"><sign>F</sign><line>4</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
          <backup><duration>4</duration></backup>
          <note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><staff>2</staff></note>
        </measure>
      </part>
    </score-partwise>
    """

    static let chordAndRest = """
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Snapshot Chord</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes><divisions>4</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
          <note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
          <note><chord/><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
          <note><rest/><duration>4</duration><voice>1</voice><staff>1</staff></note>
        </measure>
      </part>
    </score-partwise>
    """

    static let accidentals = """
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Snapshot Accidentals</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes><divisions>4</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
          <note><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff><accidental>sharp</accidental></note>
          <note><pitch><step>B</step><alter>-1</alter><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff><accidental>flat</accidental></note>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff><accidental>natural</accidental></note>
        </measure>
      </part>
    </score-partwise>
    """

    static let ledgerLines = """
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Snapshot Ledger</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes><divisions>4</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
          <note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
          <note><pitch><step>A</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
        </measure>
      </part>
    </score-partwise>
    """

    static let lyricsAndFingering = """
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Snapshot Lyrics</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes><divisions>4</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff>
            <lyric><syllabic>single</syllabic><text>Do</text></lyric>
            <notations><technical><fingering>1</fingering></technical></notations>
          </note>
          <note>
            <pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff>
            <lyric><syllabic>single</syllabic><text>Re</text></lyric>
            <notations><technical><fingering>2</fingering></technical></notations>
          </note>
        </measure>
      </part>
    </score-partwise>
    """

    static let keySignatureTreble = """
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Snapshot Key</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>4</divisions><key><fifths>2</fifths><mode>major</mode></key>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
          <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><staff>1</staff></note>
        </measure>
      </part>
    </score-partwise>
    """
}
#endif
