#if os(iOS)
import DoReMiRendererKit
import XCTest

@MainActor
final class SnapshotTests: XCTestCase {
    private let helper = ImageSnapshotHelper()

    func testSingleMelodySnapshot() throws {
        try assertSnapshot(xml: SnapshotFixtures.singleMelody, name: "single-melody")
    }

    func testGrandStaffSimpleSnapshot() throws {
        try assertSnapshot(xml: SnapshotFixtures.grandStaffSimple, name: "grand-staff-simple")
    }

    func testChordAndRestSnapshot() throws {
        try assertSnapshot(xml: SnapshotFixtures.chordAndRest, name: "chord-and-rest")
    }

    func testAccidentalsSnapshot() throws {
        try assertSnapshot(xml: SnapshotFixtures.accidentals, name: "accidentals")
    }

    func testLedgerLinesSnapshot() throws {
        try assertSnapshot(xml: SnapshotFixtures.ledgerLines, name: "ledger-lines")
    }

    func testLyricsAndFingeringSnapshot() throws {
        try assertSnapshot(xml: SnapshotFixtures.lyricsAndFingering, name: "lyrics-and-fingering")
    }

    func testKeySignatureTrebleSnapshot() throws {
        try assertSnapshot(xml: SnapshotFixtures.keySignatureTreble, name: "key-signature-treble")
    }

    func testCurrentNoteHighlightSnapshot() throws {
        let image = try SnapshotTestSupport.renderScore(
            xml: SnapshotFixtures.singleMelody,
            currentNoteSelector: { layout in layout.noteByID.keys.sorted { $0.rawValue < $1.rawValue }.first }
        )
        try helper.assertSnapshot(image, named: "current-note-highlight")
    }

    func testNoteColorOffStaffColorOnSnapshot() throws {
        try assertSnapshot(
            xml: SnapshotFixtures.singleMelody,
            name: "note-color-off-staff-color-on",
            style: SnapshotTestSupport.noteColorOffStaffColorOnStyle()
        )
    }

    func testNoteColorOnStaffColorOffSnapshot() throws {
        try assertSnapshot(
            xml: SnapshotFixtures.singleMelody,
            name: "note-color-on-staff-color-off",
            style: SnapshotTestSupport.noteColorOnStaffColorOffStyle()
        )
    }

    func testNoteColorOnStaffColorOnSnapshot() throws {
        try assertSnapshot(
            xml: SnapshotFixtures.singleMelody,
            name: "note-color-on-staff-color-on",
            style: SnapshotTestSupport.fullColorStyle()
        )
    }

    private func assertSnapshot(
        xml: String,
        name: String,
        style: ScoreStyle = SnapshotTestSupport.fullColorStyle(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let image = try SnapshotTestSupport.renderScore(xml: xml, style: style)
        try helper.assertSnapshot(image, named: name, file: file, line: line)
    }
}
#endif
