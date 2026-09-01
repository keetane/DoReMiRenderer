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
    let ledgerColors = plan.ledgerLines?
        .filter { $0.noteID == ledgerNoteID }
        .map(\.colorPitchClass)
    #expect(ledgerColors == [9, 0])
    #expect(plan.systems?.map(\.index) == layout.systems.map(\.index))
    #expect(plan.pages?.map(\.systemIndices) == layout.pages.map(\.systemIndices))
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
    let a4Scale = ScoreWebLayoutProfile.a4NotationScale

    #expect(options.pageWidth == 595)
    #expect(options.pageHeight == 842)
    #expect(options.staffSpace == 12 * a4Scale)
    #expect(options.systemSpacing == 82 * a4Scale)
    #expect(options.measureSpacing == 0)
    #expect(options.interStaffWhitespace == 90 * a4Scale)
    #expect(options.maximumMeasuresPerSystem == 4)
    #expect(options.displayMode == .print)
    #expect(!options.showPageMargins)
    #expect(options.printSystemGap == 68 * a4Scale)
    #expect(options.repeatsSystemPrefixAtLineBreaks)
    #expect(options.anchorsShortNoteGroupsRhythmically)
    #expect(options.usesExpandedExpressionLanes)
    #expect(options.usesCompactMeasureSpacing)
    #expect(!options.justifiesFinalSystem)
    #expect(!options.fullyJustifiesFinalSystem)
    #expect(options.usesDurationSensitiveShortNoteSpacing)
    #expect(options.allowsAggressiveShortNoteCompression)
    #expect(options.titleScale == 0.82)
    #expect(options.titleGapAboveFirstStaff == 120 * a4Scale)
    #expect(options.titleVerticalOffset == 60 * a4Scale)
    #expect(options.showsGrandStaffBrace)
    #expect(!options.showsPedalMarkings)
    #expect(options.noteheadSizeAdjustment == 2 * a4Scale)
    #expect(options.horizontalMarginAdjustment == 20 * a4Scale)
    #expect(options.stemAttachmentInset == 2 * a4Scale)
    #expect(options.timeSignatureScale == 1.5)
    #expect(options.timeSignatureFontSize == 36 * a4Scale)
    #expect(options.timeSignatureDigitInset == 4 * a4Scale)
    #expect(options.notationScale == a4Scale)
    let noteheadWidth = options.staffSpace * 1.45
        - options.notationScale
        + options.noteheadSizeAdjustment
    #expect(abs(noteheadWidth - 10) < 0.001)
}

@Test func webProfileWrapsVeryDenseSixteenthMeasuresWithoutOverflow() throws {
    let staffID = StaffID(rawValue: "1")
    func denseMeasure(number: String) -> Measure {
        let notes = (0..<40).map { index in
            ScoreNote(
                id: NoteID(rawValue: "dense-web-\(number)-\(index)"),
                pitch: Pitch(step: index.isMultiple(of: 3) ? .c : .d, octave: 5),
                onset: MusicalTime(ticks: index, ticksPerQuarterNote: 4),
                duration: MusicalTime(ticks: 1, ticksPerQuarterNote: 4),
                noteValueKind: .sixteenth,
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID
            )
        }
        return Measure(
            id: MeasureID(partIndex: 0, measureNumber: number),
            number: number,
            notes: notes,
            clef: number == "1" ? Clef(kind: .treble) : nil,
            timeSignature: number == "1" ? TimeSignature(beats: 10, beatType: 4) : nil
        )
    }

    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: [
        denseMeasure(number: "1"),
        denseMeasure(number: "2"),
    ])])
    let renderer = DoReMiRenderer()
    let compressed = try renderer.layout(
        score: score,
        options: renderer.webLayoutOptions(containerWidth: 1_024)
    )
    // Readable 8pt sixteenth-note spacing intentionally wraps these two
    // 40-note measures instead of shrinking their noteheads into one row.
    #expect(compressed.systems.count == 2)
    #expect(compressed.measures.map(\.systemIndex) == [0, 1])
    for measure in compressed.measures {
        let anchors = compressed.noteByID.values.filter { $0.measureID == measure.measureID }
        #expect(anchors.allSatisfy { note in
            note.noteheadFrame.minX >= measure.frame.minX
                && note.noteheadFrame.maxX <= measure.frame.maxX
        })
    }
}

@Test func webShortTerminalInsetsDoNotForceAnEarlySystemBreak() throws {
    let fixtureURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Examples/WebCanvasViewer/Fixtures/measure-spacing-coverage.musicxml")
    let score = try DoReMiRenderer().parseMusicXML(data: Data(contentsOf: fixtureURL))
    let renderer = DoReMiRenderer()
    let layout = try renderer.layout(
        score: score,
        options: renderer.webLayoutOptions(containerWidth: 1_024)
    )
    // The first three measures fit the fixed A4 reader width with the same
    // 11pt short-note floor used by rendering. The dense final measure starts
    // a new, non-justified system instead of turning the first row into a
    // premature two-measure system.
    #expect(layout.measures.map(\.systemIndex) == [0, 0, 0, 1])
    let finalMeasure = try #require(layout.measures.last)
    #expect(finalMeasure.frame.width < layout.canvasSize.width * 0.75)

    let tupletMeasure = try #require(score.parts.first?.measures.first { $0.number == "3" })
    let tupletNotes = tupletMeasure.notes
        .filter { $0.staffID.rawValue == "1" && $0.tuplet != nil }
        .sorted { $0.onset < $1.onset }
    let tupletX = try tupletNotes.map { note in
        try #require(layout.noteLayout(for: note.id)).noteheadCenter.x
    }
    let tupletGaps = zip(tupletX, tupletX.dropFirst()).map { $1 - $0 }
    #expect(tupletGaps.allSatisfy { $0 >= 11 })
}

@Test func webAggressiveShortSpacingKeepsSixteenthRestsOnTheSameGridAsNotes() throws {
    let staffID = StaffID(rawValue: "1")
    func measure(id: String, restsAt: Set<Int>) -> Measure {
        let notes = (0..<8).map { index in
            ScoreNote(
                id: NoteID(rawValue: "\(id)-\(index)"),
                pitch: restsAt.contains(index) ? nil : Pitch(step: .c, octave: 5),
                onset: MusicalTime(ticks: index, ticksPerQuarterNote: 4),
                duration: MusicalTime(ticks: 1, ticksPerQuarterNote: 4),
                noteValueKind: .sixteenth,
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID
            )
        }
        return Measure(
            id: MeasureID(partIndex: 0, measureNumber: id),
            number: id,
            notes: notes,
            clef: Clef(kind: .treble),
            timeSignature: TimeSignature(beats: 2, beatType: 4)
        )
    }

    let renderer = DoReMiRenderer()
    let options = renderer.webLayoutOptions(containerWidth: 1_024)
    let pitched = try renderer.layout(
        score: ScoreDocument(parts: [ScorePart(id: "P1", measures: [measure(id: "notes", restsAt: [])])]),
        options: options
    )
    let mixed = try renderer.layout(
        score: ScoreDocument(parts: [ScorePart(id: "P1", measures: [measure(id: "rests", restsAt: [1, 4, 6])])]),
        options: options
    )

    let noteXs = try (0..<8).map { index in
        try #require(pitched.noteLayout(for: NoteID(rawValue: "notes-\(index)"))).noteheadCenter.x
    }
    let restXs = try (0..<8).map { index in
        try #require(mixed.noteLayout(for: NoteID(rawValue: "rests-\(index)"))).noteheadCenter.x
    }
    let noteGaps = zip(noteXs, noteXs.dropFirst()).map { $1 - $0 }
    let restGaps = zip(restXs, restXs.dropFirst()).map { $1 - $0 }

    for (noteGap, restGap) in zip(noteGaps, restGaps) {
        #expect(abs(noteGap - restGap) < 0.001)
    }
}

@Test func webShortSpacingIgnoresSustainedEventsOnAnotherStaff() throws {
    let upperStaff = StaffID(rawValue: "1")
    let lowerStaff = StaffID(rawValue: "2")
    let upperNotes = (0..<8).map { index in
        ScoreNote(
            id: NoteID(rawValue: "upper-sixteenth-\(index)"),
            pitch: Pitch(step: .c, octave: 5),
            onset: MusicalTime(ticks: index, ticksPerQuarterNote: 4),
            duration: MusicalTime(ticks: 1, ticksPerQuarterNote: 4),
            noteValueKind: .sixteenth,
            voiceID: VoiceID(rawValue: "1"),
            staffID: upperStaff
        )
    }
    let lowerWholeRest = ScoreNote(
        id: NoteID(rawValue: "lower-whole-rest"),
        pitch: nil,
        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
        duration: MusicalTime(ticks: 8, ticksPerQuarterNote: 4),
        noteValueKind: .whole,
        voiceID: VoiceID(rawValue: "1"),
        staffID: lowerStaff
    )
    let measure = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "1"),
        number: "1",
        notes: upperNotes + [lowerWholeRest],
        clef: Clef(kind: .treble),
        timeSignature: TimeSignature(beats: 2, beatType: 4)
    )
    let renderer = DoReMiRenderer()
    let layout = try renderer.layout(
        score: ScoreDocument(parts: [ScorePart(id: "P1", measures: [measure])]),
        options: renderer.webLayoutOptions(containerWidth: 1_024)
    )
    let noteXs = try upperNotes.map {
        try #require(layout.noteLayout(for: $0.id)).noteheadCenter.x
    }
    let gaps = zip(noteXs, noteXs.dropFirst()).map { $1 - $0 }

    let firstGap = try #require(gaps.first)
    #expect(gaps.allSatisfy { abs($0 - firstGap) < 0.001 })
    #expect(firstGap >= 11)
}

@Test func webShortSpacingUsesReadableSixteenthAndShorterGaps() throws {
    #expect(aggressiveShortNoteMinimumGap(for: 2) == 11)
    #expect(aggressiveShortNoteMinimumGap(for: 3) == 11)
    #expect(aggressiveShortNoteMinimumGap(for: 4) == 11)
}

@Test func webTitleOffsetMovesOnlyTheTitleAndPreservesFirstSystemPosition() throws {
    let staffID = StaffID(rawValue: "1")
    let measure = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "1"),
        number: "1",
        notes: [
            ScoreNote(
                id: NoteID(rawValue: "title-offset-note"),
                pitch: Pitch(step: .c, octave: 4),
                onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                noteValueKind: .quarter,
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID
            ),
        ],
        clef: Clef(kind: .treble),
        timeSignature: TimeSignature(beats: 4, beatType: 4)
    )
    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: [measure])], title: "Title Offset", composer: "Layout Composer")
    let renderer = DoReMiRenderer()
    var baselineOptions = renderer.webLayoutOptions(containerWidth: 1_024)
    baselineOptions.titleVerticalOffset = 0
    let shiftedOptions = renderer.webLayoutOptions(containerWidth: 1_024)

    let baseline = try renderer.layout(score: score, options: baselineOptions)
    let shifted = try renderer.layout(score: score, options: shiftedOptions)
    let baselineTitle = try #require(baseline.title)
    let shiftedTitle = try #require(shifted.title)
    let composer = try #require(shifted.composer)
    let baselineFirstSystem = try #require(baseline.systems.first)
    let shiftedFirstSystem = try #require(shifted.systems.first)

    // Page normalization can retain a sub-point top inset; the title offset
    // remains visually exact while the first staff stays fixed.
    #expect(abs((shiftedTitle.frame.minY - baselineTitle.frame.minY) - shiftedOptions.titleVerticalOffset) < 0.2)
    #expect(abs(shiftedFirstSystem.frame.minY - baselineFirstSystem.frame.minY) < 0.001)
    #expect(composer.frame.minY > shiftedTitle.frame.maxY)
    #expect(composer.frame.maxX <= shifted.canvasSize.width)
}

@Test func webProfileDrawsGrandStaffBraceForTwoStaffScore() throws {
    let upperStaff = StaffID(rawValue: "1")
    let lowerStaff = StaffID(rawValue: "2")
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let onset = MusicalTime(ticks: 0, ticksPerQuarterNote: 4)
    let duration = MusicalTime(ticks: 4, ticksPerQuarterNote: 4)
    let measure = Measure(
        id: measureID,
        number: "1",
        notes: [
            ScoreNote(id: NoteID(rawValue: "brace-upper"), pitch: Pitch(step: .c, octave: 4), onset: onset, duration: duration, noteValueKind: .quarter, voiceID: VoiceID(rawValue: "1"), staffID: upperStaff),
            ScoreNote(id: NoteID(rawValue: "brace-lower"), pitch: Pitch(step: .c, octave: 3), onset: onset, duration: duration, noteValueKind: .quarter, voiceID: VoiceID(rawValue: "1"), staffID: lowerStaff),
        ],
        clefsByStaff: [upperStaff: Clef(kind: .treble), lowerStaff: Clef(kind: .bass)],
        timeSignature: TimeSignature(beats: 4, beatType: 4)
    )
    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: [measure])])
    let renderer = DoReMiRenderer()
    let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 1_024))
    let plan = renderer.makeWebRenderPlan(score: score, layout: layout)

    #expect(layout.grandStaffBrackets.count == layout.systems.count)
    #expect(layout.grandStaffBrackets.allSatisfy { $0.frame.height > 0 })
    let braceCurves = plan.commands.filter { $0.kind == .strokeQuadraticCurve }.count
    #expect(braceCurves >= layout.grandStaffBrackets.count * 2)
    let staves = layout.staves.sorted { $0.frame.minY < $1.frame.minY }
    let connectorLines = plan.commands.filter { command in
        guard command.kind == .strokeLine,
              let start = command.start,
              let end = command.end
        else {
            return false
        }
        return abs(start.y - Double(staves[0].frame.maxY)) < 0.01
            && abs(end.y - Double(staves[1].frame.minY)) < 0.01
    }
    #expect(connectorLines.count >= 2)
}

@Test func webComposerWithoutTitleReservesHeaderSpaceAboveFirstSystem() throws {
    let staffID = StaffID(rawValue: "1")
    let measure = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "1"),
        number: "1",
        notes: [
            ScoreNote(
                id: NoteID(rawValue: "credit-only-note"),
                pitch: Pitch(step: .c, octave: 4),
                onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                noteValueKind: .quarter,
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID
            ),
        ],
        clef: Clef(kind: .treble),
        timeSignature: TimeSignature(beats: 4, beatType: 4)
    )
    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: [measure])], composer: "Credit Only")
    let renderer = DoReMiRenderer()
    let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 1_024))

    let composer = try #require(layout.composer)
    let firstSystem = try #require(layout.systems.first)
    #expect(composer.frame.maxY < firstSystem.frame.minY)
}

@Test func webA4NotationScaleReducesFixedSMuFLGlyphFloors() {
    let a4Scale = ScoreWebLayoutProfile.a4NotationScale
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

@Test func webCompactProfileReflowsDenseCoverageAtTenPointNoteheadScale() throws {
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

    // The enlarged 10pt Web notehead keeps all notation proportional. This
    // dense four-measure coverage fixture therefore reflows rather than
    // compressing symbols below their readable size.
    #expect(layout.systems.count > 1)
    #expect(layout.systems.allSatisfy { system in
        layout.measures.filter { $0.systemIndex == system.index }.count <= 4
    })
    #expect(Set(layout.measures.map(\.systemIndex)).count == layout.systems.count)
    #expect(layout.systems.allSatisfy {
        abs($0.frame.minX - (layout.canvasSize.width - $0.frame.maxX)) < 0.01
    })
    let finalSystem = try #require(layout.systems.last)
    let finalMeasures = layout.measures.filter { $0.systemIndex == finalSystem.index }
    #expect(finalMeasures.count == 1)
    #expect((try #require(finalMeasures.first)).frame.width < finalSystem.frame.width * 0.5)
}

@Test func webRenderPlanUsesFixedA4PagesAndMovesOverflowToLaterPages() throws {
    let staffID = StaffID(rawValue: "1")
    let duration = MusicalTime(ticks: 4, ticksPerQuarterNote: 4)
    let measures = (1...32).map { number in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(number)"),
            number: "\(number)",
            notes: [
                ScoreNote(
                    id: NoteID(rawValue: "a4-page-\(number)"),
                    pitch: Pitch(step: .c, octave: 4),
                    onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                    duration: duration,
                    noteValueKind: .quarter,
                    voiceID: VoiceID(rawValue: "1"),
                    staffID: staffID
                ),
            ],
            clef: Clef(kind: .treble),
            timeSignature: TimeSignature(beats: 4, beatType: 4)
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: measures)])
    let renderer = DoReMiRenderer()
    var options = renderer.webLayoutOptions(containerWidth: 1_024)
    options.maximumMeasuresPerSystem = 1
    let layout = try renderer.layout(score: score, options: options)
    let plan = renderer.makeWebRenderPlan(score: score, layout: layout)
    let pages = try #require(plan.pages)

    #expect(pages.count > 1)
    #expect(pages.allSatisfy { $0.frame.width == 595 && $0.frame.height == 842 })
    #expect(pages.flatMap { $0.systemIndices } == layout.systems.map { $0.index })
    #expect(plan.canvas.height == Double(pages.count * 842))
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
        timeSignature: nil
    )
    let measure3 = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "3"),
        number: "3",
        notes: notes(prefix: "sixteenth", count: 16, duration: sixteenth, kind: .sixteenth),
        clef: nil,
        timeSignature: nil
    )
    let score = ScoreDocument(parts: [ScorePart(id: "P1", measures: [measure1, measure2, measure3])])
    let renderer = DoReMiRenderer()

    var legacyOptions = renderer.webLayoutOptions(containerWidth: 1_024)
    legacyOptions.pageWidth = 2_000
    legacyOptions.pageHeight = nil
    legacyOptions.maximumMeasuresPerSystem = 3
    legacyOptions.repeatsSystemPrefixAtLineBreaks = false
    legacyOptions.justifiesFinalSystem = false
    legacyOptions.usesDurationSensitiveShortNoteSpacing = false
    legacyOptions.allowsAggressiveShortNoteCompression = false
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
    let compactEighthFirst = try #require(compact.noteByID[NoteID(rawValue: "eighth-0")])
    let compactEighthLast = try #require(compact.noteByID[NoteID(rawValue: "eighth-7")])
    let legacyLast = try #require(legacy.noteByID[NoteID(rawValue: "sixteenth-15")])
    let compactLast = try #require(compact.noteByID[NoteID(rawValue: "sixteenth-15")])

    #expect(compactEighthMeasure.frame.width < legacyEighthMeasure.frame.width)
    #expect(compactSixteenthMeasure.frame.width < legacySixteenthMeasure.frame.width)
    #expect(compactSixteenthSecond.noteheadCenter.x - compactSixteenthFirst.noteheadCenter.x
        < legacySixteenthSecond.noteheadCenter.x - legacySixteenthFirst.noteheadCenter.x)
    #expect(compactSixteenthSecond.noteheadCenter.x - compactSixteenthFirst.noteheadCenter.x
        >= compactSixteenthFirst.noteheadFrame.width)
    #expect(compactSixteenthMeasure.frame.maxX - compactLast.noteheadFrame.maxX
        < legacySixteenthMeasure.frame.maxX - legacyLast.noteheadFrame.maxX)
    // Short-value terminal insets are deliberately compact, while retaining a
    // visible barline clearance at A4 notation scale.
    #expect(compactSixteenthMeasure.frame.maxX - compactLast.noteheadFrame.maxX >= 7)
    let compactEighthLeadingGap = compactEighthFirst.noteheadFrame.minX - compactEighthMeasure.frame.minX
    let compactEighthTrailingGap = compactEighthMeasure.frame.maxX - compactEighthLast.noteheadFrame.maxX
    // A system/measure prefix keeps its own clearance at the start, while the
    // final short note still receives the compact terminal inset.
    #expect(compactEighthTrailingGap < compactEighthLeadingGap)
    #expect(compactEighthTrailingGap >= 7)
    let compactSixteenthLeadingGap = compactSixteenthFirst.noteheadFrame.minX - compactSixteenthMeasure.frame.minX
    let compactSixteenthTrailingGap = compactSixteenthMeasure.frame.maxX - compactLast.noteheadFrame.maxX
    #expect(abs(compactSixteenthLeadingGap - compactSixteenthTrailingGap) < 0.6)
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

    let defaultBundle = try renderer.makeWebRenderBundle(score: score, containerWidth: 960)
    let defaultSemitoneChoices = Set(defaultBundle.transposeVariants.map(\.semitones) + [0])
    #expect(defaultSemitoneChoices == Set(-6...5))
    #expect(defaultSemitoneChoices.count == 12)
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

@Test func webPlaybackTimelineMergesDuplicateSoundingPitchDurations() {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let onset = MusicalTime(ticks: 0, ticksPerQuarterNote: 4)
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(id: NoteID(rawValue: "unison-short"), pitch: Pitch(step: .c, octave: 4), onset: onset, duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4), noteValueKind: .quarter, voiceID: VoiceID(rawValue: "1"), staffID: staffID),
                    ScoreNote(id: NoteID(rawValue: "unison-long"), pitch: Pitch(step: .c, octave: 4), onset: onset, duration: MusicalTime(ticks: 8, ticksPerQuarterNote: 4), noteValueKind: .half, voiceID: VoiceID(rawValue: "2"), staffID: staffID),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4),
                tempoEvents: [TempoEvent(bpm: 120, onset: onset, source: .sound, measureID: measureID)]
            ),
        ]),
    ])

    let event = ScoreWebPlaybackTimelineBuilder().build(score: score).first
    #expect(event?.midiSoundDurationSeconds?.count == 1)
    #expect(abs((event?.midiSoundDurationSeconds?[60] ?? 0) - 1.0) < 0.001)
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
    #expect(defaults.titleVerticalOffset == 0)
    #expect(defaults.showsPedalMarkings)
    #expect(defaults.noteheadSizeAdjustment == 0)
    #expect(defaults.horizontalMarginAdjustment == 0)
    #expect(defaults.stemAttachmentInset == 0)
    #expect(defaults.timeSignatureScale == 1)
    #expect(defaults.timeSignatureFontSize == nil)
    #expect(defaults.timeSignatureDigitInset == 0)
}
