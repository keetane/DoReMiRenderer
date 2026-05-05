import Testing
@testable import DoReMiRendererKit

@Test(arguments: [
    (PitchStep.c, 4, -6),
    (.d, 4, -5),
    (.e, 4, -4),
    (.f, 4, -3),
    (.g, 4, -2),
    (.a, 4, -1),
    (.b, 4, 0),
    (.c, 5, 1),
    (.d, 5, 2),
    (.e, 5, 3),
])
func trebleStaffPositionUsesB4AsMiddleLine(step: PitchStep, octave: Int, expected: Int) {
    let position = staffPosition(pitch: Pitch(step: step, octave: octave), clef: Clef(kind: .treble))

    #expect(position.stepsFromMiddleLine == expected)
}

@Test(arguments: [
    (PitchStep.e, 2, -6),
    (.f, 2, -5),
    (.g, 2, -4),
    (.a, 2, -3),
    (.b, 2, -2),
    (.c, 3, -1),
    (.d, 3, 0),
    (.e, 3, 1),
    (.f, 3, 2),
    (.g, 3, 3),
])
func bassStaffPositionUsesD3AsMiddleLine(step: PitchStep, octave: Int, expected: Int) {
    let position = staffPosition(pitch: Pitch(step: step, octave: octave), clef: Clef(kind: .bass))

    #expect(position.stepsFromMiddleLine == expected)
}

@Test func staffPositionIgnoresAccidentals() {
    let natural = staffPosition(pitch: Pitch(step: .c, octave: 4), clef: Clef(kind: .treble))
    let sharp = staffPosition(pitch: Pitch(step: .c, octave: 4, alter: 1), clef: Clef(kind: .treble))
    let flat = staffPosition(pitch: Pitch(step: .c, octave: 4, alter: -1), clef: Clef(kind: .treble))

    #expect(natural == sharp)
    #expect(natural == flat)
}
