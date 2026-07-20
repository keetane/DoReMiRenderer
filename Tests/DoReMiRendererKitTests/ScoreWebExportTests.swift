import Foundation
import Testing
@testable import DoReMiRendererKit

@Test func webRenderPlanPreservesSDKLayoutCoordinatesAndStableNoteIDs() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let noteID = NoteID(rawValue: "web-note")
    let flatNoteID = NoteID(rawValue: "web-flat-note")
    let ledgerNoteID = NoteID(rawValue: "web-ledger-note")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: noteID,
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: flatNoteID,
                        pitch: Pitch(step: .b, octave: 4, alter: -1),
                        onset: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: ledgerNoteID,
                        pitch: Pitch(step: .c, octave: 6),
                        onset: MusicalTime(ticks: 8, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 0, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])
    let renderer = DoReMiRenderer()
    let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 960))
    let plan = renderer.makeWebRenderPlan(score: score, layout: layout)

    #expect(plan.formatVersion == ScoreWebRenderPlan.formatVersion)
    #expect(plan.canvas.width == Double(layout.canvasSize.width))
    #expect(plan.canvas.height == Double(layout.canvasSize.height))
    #expect(plan.commands.contains { $0.kind == .strokeLine })
    #expect(plan.commands.contains { $0.kind == .drawText && $0.fontName == "Bravura" })
    #expect(plan.commands.contains { $0.kind == .drawText && $0.fontRole == .smufl })
    #expect(ScoreWebFontRole(fontName: "TimesNewRomanPS-BoldMT") == .serifBold)
    #expect(ScoreWebFontRole(fontName: "Georgia-Italic") == .serifItalic)
    #expect(ScoreWebFontRole(fontName: nil) == .sansSerif)
    let anchor = try #require(plan.noteAnchors.first { $0.noteID == noteID })
    let expectedNote = try #require(layout.noteLayout(for: noteID))
    #expect(anchor.center.x == Double(expectedNote.noteheadCenter.x))
    #expect(anchor.center.y == Double(expectedNote.noteheadCenter.y))
    #expect(anchor.midiNumber == 60)
    #expect(anchor.colorPitchClass == 0)
    let flatAnchor = try #require(plan.noteAnchors.first { $0.noteID == flatNoteID })
    #expect(flatAnchor.midiNumber == 70)
    #expect(flatAnchor.colorPitchClass == 11)
    #expect(anchor.systemIndex == layout.systems.first?.index)
    #expect(plan.staffLines?.count == layout.staffLines.count)
    #expect(plan.staffLines?.allSatisfy { $0.pitchClass != nil } == true)
    #expect(plan.ledgerLines?.count == layout.ledgerLines.count)
    #expect(plan.ledgerLines?.contains { $0.noteID == ledgerNoteID && $0.colorPitchClass == 0 } == true)
    #expect(plan.systems?.map(\.index) == layout.systems.map(\.index))
    #expect(plan.initialKeySignature == ScoreWebKeySignature(KeySignature(fifths: 0, mode: "major")))

    let encoded = try JSONEncoder().encode(plan)
    let decoded = try JSONDecoder().decode(ScoreWebRenderPlan.self, from: encoded)
    #expect(decoded == plan)
}

@Test func responsiveWebLayoutProfileClampsSmallContainersAndCapsMeasuresPerSystem() {
    let profile = ScoreWebLayoutProfile(
        staffSpace: 12,
        systemSpacing: 82,
        measureSpacing: 0,
        interStaffWhitespace: 90,
        maximumMeasuresPerSystem: 4
    )
    let options = profile.layoutOptions(containerWidth: 240)
    let a4Scale: CGFloat = 842 / 1_800

    #expect(options.pageWidth == 842)
    #expect(options.staffSpace == 12 * a4Scale)
    #expect(options.systemSpacing == 82 * a4Scale)
    #expect(options.measureSpacing == 0)
    #expect(options.interStaffWhitespace == 90 * a4Scale)
    #expect(options.maximumMeasuresPerSystem == 4)
    #expect(options.displayMode == .print)
    #expect(!options.showPageMargins)
    #expect(options.repeatsSystemPrefixAtLineBreaks)
    #expect(options.anchorsShortNoteGroupsRhythmically)
    #expect(options.usesExpandedExpressionLanes)
    #expect(options.usesCompactMeasureSpacing)
    #expect(options.justifiesFinalSystem)
    #expect(options.fullyJustifiesFinalSystem)
    #expect(options.usesDurationSensitiveShortNoteSpacing)
    #expect(options.titleScale == 0.82)
    #expect(options.titleGapAboveFirstStaff == 120 * a4Scale)
    #expect(!options.showsPedalMarkings)
    #expect(options.noteheadSizeAdjustment == 2 * a4Scale)
    #expect(options.horizontalMarginAdjustment == 20 * a4Scale)
    #expect(options.stemAttachmentInset == 2 * a4Scale)
    #expect(options.timeSignatureScale == 1.5)
    #expect(options.timeSignatureFontSize == 36 * a4Scale)
    #expect(options.timeSignatureDigitInset == 4 * a4Scale)
    #expect(options.notationScale == a4Scale)
}

@Test func webA4NotationScaleReducesFixedSMuFLGlyphFloors() {
    let a4Scale: CGFloat = 842 / 1_800
    let frame = CGRect(x: 0, y: 0, width: 8, height: 4)
    let nativePolicy = SMuFLGlyphSizePolicy()
    let webPolicy = SMuFLGlyphSizePolicy(minimumScale: a4Scale)

    #expect(nativePolicy.noteheadSize(for: frame, noteValue: .quarter) == 20)
    #expect(webPolicy.noteheadSize(for: frame, noteValue: .quarter) < nativePolicy.noteheadSize(for: frame, noteValue: .quarter))
    #expect(webPolicy.clefSize(for: frame) < nativePolicy.clefSize(for: frame))
    #expect(webPolicy.accidentalSize(for: frame) < nativePolicy.accidentalSize(for: frame))
    #expect(webPolicy.flagSize(for: frame) < nativePolicy.flagSize(for: frame))
    #expect(webPolicy.repeatDotSize(for: frame) < nativePolicy.repeatDotSize(for: frame))
}

@Test func webCompactProfileKeepsFourRhythmCoverageMeasuresInOneSystem() throws {
    let staffID = StaffID(rawValue: "1")
    let quarter = MusicalTime(ticks: 12, ticksPerQuarterNote: 12)
    let eighth = MusicalTime(ticks: 6, ticksPerQuarterNote: 12)
    let tripletEighth = MusicalTime(ticks: 4, ticksPerQuarterNote: 12)
    let sixteenth = MusicalTime(ticks: 3, ticksPerQuarterNote: 12)

    func notes(
        measureIndex: Int,
        count: Int,
        duration: MusicalTime,
        kind: NoteValueKind
    ) -> [ScoreNote] {
        (0..<count).map { index in
            ScoreNote(
                id: NoteID(rawValue: "web-spacing-\(measureIndex)-\(index)"),
                pitch: Pitch(step: .c, octave: 4),
                onset: MusicalTime(ticks: duration.ticks * index, ticksPerQuarterNote: 12),
                duration: duration,
                noteValueKind: kind,
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID
            )
        }
    }

    let measures = [
        Measure(id: MeasureID(partIndex: 0, measureNumber: "1"), number: "1", notes: notes(measureIndex: 1, count: 4, duration: quarter, kind: .quarter), clef: Clef(kind: .treble), timeSignature: TimeSignature(beats: 4, beatType: 4)),
        Measure(id: MeasureID(partIndex: 0, measureNumber: "2"), number: "2", notes: notes(measureIndex: 2, count: 8, duration: eighth, kind: .eighth), clef: Clef(kind: .treble), timeSignature: TimeSignature(beats: 4, beatType: 4)),
        Measure(id: MeasureID(partIndex: 0, measureNumber: "3"), number: "3", notes: notes(measureIndex: 3, count: 12, duration: tripletEighth, kind: .eighth), clef: Clef(kind: .treble), timeSignature: TimeSignature(beats: 4, beatType: 4)),
        Measure(id: MeasureID(partIndex: 0, measureNumber: "4"), number: "4", notes: notes(measureIndex: 4, count: 16, duration: sixteenth, kind: .sixteenth), clef: Clef(kind: .treble), timeSignature: TimeSignature(beats: 4, beatType: 4)),
    ]
    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: measures)])
    let renderer = DoReMiRenderer()
    let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 1_024))

    #expect(layout.systems.count == 1)
    #expect(Set(layout.measures.map(\.systemIndex)) == Set([0]))
    let system = try #require(layout.systems.first)
    #expect(abs(system.frame.minX - (layout.canvasSize.width - system.frame.maxX)) < 0.01)
}

@Test func webDurationSensitiveSpacingTightensShortNotesAndTerminalInsets() throws {
    let staffID = StaffID(rawValue: "1")
    let quarter = MusicalTime(ticks: 12, ticksPerQuarterNote: 12)
    let eighth = MusicalTime(ticks: 6, ticksPerQuarterNote: 12)
    let sixteenth = MusicalTime(ticks: 3, ticksPerQuarterNote: 12)

    func notes(
        prefix: String,
        count: Int,
        duration: MusicalTime,
        kind: NoteValueKind
    ) -> [ScoreNote] {
        (0..<count).map { index in
            ScoreNote(
                id: NoteID(rawValue: "\(prefix)-\(index)"),
                pitch: Pitch(step: .c, octave: 4),
                onset: MusicalTime(ticks: duration.ticks * index, ticksPerQuarterNote: 12),
                duration: duration,
                noteValueKind: kind,
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID
            )
        }
    }

    let measure1 = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "1"),
        number: "1",
        notes: notes(prefix: "quarter", count: 4, duration: quarter, kind: .quarter),
        clef: Clef(kind: .treble),
        timeSignature: TimeSignature(beats: 4, beatType: 4)
    )
    let measure2 = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "2"),
        number: "2",
        notes: notes(prefix: "eighth", count: 8, duration: eighth, kind: .eighth),
        clef: Clef(kind: .treble),
        timeSignature: TimeSignature(beats: 4, beatType: 4)
    )
    let measure3 = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "3"),
        number: "3",
        notes: notes(prefix: "sixteenth", count: 16, duration: sixteenth, kind: .sixteenth),
        clef: Clef(kind: .treble),
        timeSignature: TimeSignature(beats: 4, beatType: 4)
    )
    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: [measure1, measure2, measure3])])
    let renderer = DoReMiRenderer()

    var legacyOptions = renderer.webLayoutOptions(containerWidth: 1_024)
    legacyOptions.justifiesFinalSystem = false
    legacyOptions.usesDurationSensitiveShortNoteSpacing = false
    var compactOptions = legacyOptions
    compactOptions.usesDurationSensitiveShortNoteSpacing = true

    let legacy = try renderer.layout(score: score, options: legacyOptions)
    let compact = try renderer.layout(score: score, options: compactOptions)
    let legacyEighthMeasure = try #require(legacy.measures.first { $0.measureID == measure2.id })
    let compactEighthMeasure = try #require(compact.measures.first { $0.measureID == measure2.id })
    let legacySixteenthMeasure = try #require(legacy.measures.first { $0.measureID == measure3.id })
    let compactSixteenthMeasure = try #require(compact.measures.first { $0.measureID == measure3.id })
    let legacySixteenthFirst = try #require(legacy.noteByID[NoteID(rawValue: "sixteenth-0")])
    let legacySixteenthSecond = try #require(legacy.noteByID[NoteID(rawValue: "sixteenth-1")])
    let compactSixteenthFirst = try #require(compact.noteByID[NoteID(rawValue: "sixteenth-0")])
    let compactSixteenthSecond = try #require(compact.noteByID[NoteID(rawValue: "sixteenth-1")])
    let legacyLast = try #require(legacy.noteByID[NoteID(rawValue: "sixteenth-15")])
    let compactLast = try #require(compact.noteByID[NoteID(rawValue: "sixteenth-15")])
    let legacyBarline = try #require(legacy.elementByID[ScoreElementID(rawValue: "0.3.barline.right")])
    let compactBarline = try #require(compact.elementByID[ScoreElementID(rawValue: "0.3.barline.right")])

    #expect(compactEighthMeasure.frame.width < legacyEighthMeasure.frame.width)
    #expect(compactSixteenthMeasure.frame.width < legacySixteenthMeasure.frame.width)
    #expect(compactSixteenthSecond.noteheadCenter.x - compactSixteenthFirst.noteheadCenter.x
        < legacySixteenthSecond.noteheadCenter.x - legacySixteenthFirst.noteheadCenter.x)
    #expect(compactSixteenthSecond.noteheadCenter.x - compactSixteenthFirst.noteheadCenter.x
        >= compactSixteenthFirst.noteheadFrame.width * 1.1)
    #expect(compactBarline.frame.minX - compactLast.noteheadFrame.maxX
        < legacyBarline.frame.minX - legacyLast.noteheadFrame.maxX)
    #expect(compactBarline.frame.minX - compactLast.noteheadFrame.maxX >= 10)
}

@Test func webRenderBundleKeepsPlaybackIdentityAndUsesSDKTransposeLayouts() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let noteID = NoteID(rawValue: "web-transpose-note")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: noteID,
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4),
                tempoEvents: [TempoEvent(bpm: 120, onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4), source: .sound, measureID: measureID)]
            ),
        ]),
    ])
    let renderer = DoReMiRenderer()
    let bundle = try renderer.makeWebRenderBundle(score: score, containerWidth: 960, displayTransposeRange: -1...1)

    #expect(bundle.primaryPlan.playbackEvents?.count == 1)
    #expect(bundle.primaryPlan.playbackEvents?.first?.noteIDs == [noteID])
    #expect(bundle.primaryPlan.playbackEvents?.first?.measureNumber == "1")
    #expect(bundle.transposeVariants.map(\.semitones) == [-1, 1])
    let raisedPlan = try #require(bundle.transposeVariants.first { $0.semitones == 1 }?.plan)
    #expect(raisedPlan.noteAnchors.first?.noteID == noteID)
    #expect(raisedPlan.noteAnchors.first?.midiNumber == 61)
    #expect(raisedPlan.playbackEvents == nil)
}

@Test func webPlaybackTimelineKeepsWrittenPitchDurationsForBrowserAudio() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "quarter"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "half"),
                        pitch: Pitch(step: .d, octave: 4),
                        onset: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 8, ticksPerQuarterNote: 4),
                        noteValueKind: .half,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4),
                tempoEvents: [TempoEvent(bpm: 120, onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4), source: .sound, measureID: measureID)]
            ),
        ]),
    ])

    let events = ScoreWebPlaybackTimelineBuilder().build(score: score)
    let quarter = try #require(events.first { $0.noteIDs == [NoteID(rawValue: "quarter")] })
    let half = try #require(events.first { $0.noteIDs == [NoteID(rawValue: "half")] })

    #expect(abs(quarter.soundDurationSeconds - 0.5) < 0.001)
    #expect(quarter.tempoBPM == 120)
    #expect(abs((quarter.midiSoundDurationSeconds?[60, default: 0] ?? 0) - 0.5) < 0.001)
    #expect(abs(half.soundDurationSeconds - 1.0) < 0.001)
    #expect(half.tempoBPM == 120)
    #expect(abs((half.midiSoundDurationSeconds?[62, default: 0] ?? 0) - 1.0) < 0.001)
}

@Test func printSystemGapDefaultsToTheIOSPDFReadingRhythmAndCanBeOverridden() {
    #expect(LayoutOptions().printSystemGap == 68)
    #expect(LayoutOptions(printSystemGap: 44).printSystemGap == 44)
    #expect(LayoutOptions(printSystemGap: -1).printSystemGap == 0)
}

@Test func webProfileKeepsIOSLayoutDefaultsUntouched() {
    let defaults = LayoutOptions()
    #expect(defaults.interStaffWhitespace == nil)
    #expect(!defaults.repeatsSystemPrefixAtLineBreaks)
    #expect(!defaults.anchorsShortNoteGroupsRhythmically)
    #expect(!defaults.usesExpandedExpressionLanes)
    #expect(!defaults.usesCompactMeasureSpacing)
    #expect(!defaults.justifiesFinalSystem)
    #expect(!defaults.fullyJustifiesFinalSystem)
    #expect(!defaults.usesDurationSensitiveShortNoteSpacing)
    #expect(defaults.titleScale == 1)
    #expect(defaults.titleGapAboveFirstStaff == nil)
    #expect(defaults.showsPedalMarkings)
    #expect(defaults.noteheadSizeAdjustment == 0)
    #expect(defaults.horizontalMarginAdjustment == 0)
    #expect(defaults.stemAttachmentInset == 0)
    #expect(defaults.timeSignatureScale == 1)
    #expect(defaults.timeSignatureFontSize == nil)
    #expect(defaults.timeSignatureDigitInset == 0)
}
