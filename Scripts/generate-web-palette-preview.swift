import Foundation

private let midiRange = 36...84

private func spelling(for midi: Int) -> (step: String, alter: Int?, octave: Int) {
    let pitchClass = ((midi % 12) + 12) % 12
    let octave = midi / 12 - 1
    switch pitchClass {
    case 0: return ("C", nil, octave)
    case 1: return ("C", 1, octave)
    case 2: return ("D", nil, octave)
    case 3: return ("D", 1, octave)
    case 4: return ("E", nil, octave)
    case 5: return ("F", nil, octave)
    case 6: return ("F", 1, octave)
    case 7: return ("G", nil, octave)
    case 8: return ("G", 1, octave)
    case 9: return ("A", nil, octave)
    case 10: return ("A", 1, octave)
    default: return ("B", nil, octave)
    }
}

private func noteXML(midi: Int) -> String {
    let pitch = spelling(for: midi)
    let alter = pitch.alter.map { "<alter>\($0)</alter>" } ?? ""
    let staff = midi < 60 ? 2 : 1
    return """
        <note>
          <pitch><step>\(pitch.step)</step>\(alter)<octave>\(pitch.octave)</octave></pitch>
          <duration>1</duration>
          <voice>1</voice>
          <type>eighth</type>
          <staff>\(staff)</staff>
        </note>
    """
}

private let attributesXML = """
    <attributes>
      <divisions>2</divisions>
      <key><fifths>0</fifths></key>
      <time><beats>4</beats><beat-type>4</beat-type></time>
      <staves>2</staves>
      <clef number="1"><sign>G</sign><line>2</line></clef>
      <clef number="2"><sign>F</sign><line>4</line></clef>
    </attributes>
"""

private let notes = midiRange.map(noteXML)
private let measures = stride(from: 0, to: notes.count, by: 8).enumerated().map { index, offset in
    let body = notes[offset..<min(offset + 8, notes.count)].joined(separator: "\n")
    return """
      <measure number="\(index + 1)">
        \(index == 0 ? attributesXML : "")
    \(body)
      </measure>
    """
}.joined(separator: "\n")

private let document = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>C2-C6 Palette Preview</work-title></work>
  <identification>
    <creator type="composer">DoReMi Palette generated preview</creator>
    <rights>Generated project fixture for pitch-class colour QA.</rights>
  </identification>
  <part-list>
    <score-part id="P1"><part-name>Palette Preview</part-name></score-part>
  </part-list>
  <part id="P1">
\(measures)
  </part>
</score-partwise>
"""

FileHandle.standardOutput.write(Data(document.utf8))
