import Foundation

enum MusicXMLParserError: Error, Hashable, Sendable {
    case invalidDocument(String)
    case unsupportedFeature(RendererDiagnostic)
}

extension MusicXMLParserError: RendererDiagnosticReporting {
    var diagnostic: RendererDiagnostic {
        switch self {
        case .invalidDocument(let message):
            RendererDiagnostic(
                severity: .error,
                code: "musicxml.invalidDocument",
                message: message
            )
        case .unsupportedFeature(let diagnostic):
            diagnostic
        }
    }
}

struct MusicXMLParser: Sendable {
    let unsupportedFeaturePolicy: UnsupportedFeaturePolicy

    init(unsupportedFeaturePolicy: UnsupportedFeaturePolicy = .ignoreWithWarning) {
        self.unsupportedFeaturePolicy = unsupportedFeaturePolicy
    }

    func parse(data: Data) throws -> ParseResult {
        let delegate = MusicXMLParserDelegate(policy: unsupportedFeaturePolicy)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            let message = parser.parserError?.localizedDescription ?? "Unable to parse MusicXML data"
            throw MusicXMLParserError.invalidDocument(message)
        }
        return try delegate.finish()
    }
}

private final class MusicXMLParserDelegate: NSObject, XMLParserDelegate {
    private let policy: UnsupportedFeaturePolicy
    private var diagnostics: [RendererDiagnostic] = []
    private var fatalUnsupportedDiagnostic: RendererDiagnostic?
    private var warnedUnsupportedElements: Set<String> = []
    private var elementStack: [String] = []
    private var textBuffer = ""
    private var rootElement: String?
    private var workTitle: String?
    private var movementTitle: String?
    private var movementNumber: String?
    private var creditTitle: String?
    private var currentCreditType: String?

    private var partListNames: [String: String] = [:]
    private var parts: [ScorePart] = []
    private var currentPartID: String?
    private var currentMeasures: [Measure] = []
    private var partIndex = -1
    private var measureIndex = -1
    private var currentMeasureNumber = ""
    private var currentMeasureNotes: [ScoreNote] = []
    private var divisions = 1
    private var currentOnset = 0
    private var previousNoteOnset = 0
    private var previousNoteDuration = 0
    private var xmlNoteOrdinal = 0
    private var chordOrdinal = 0
    private var currentMeasureClef: Clef?
    private var currentClefsByStaff: [StaffID: Clef] = [:]
    private var currentMeasureEffectiveClefsByStaff: [StaffID: Clef] = [:]
    private var currentMeasureClefChanges: [ClefChange] = []
    private var activeClefsByStaff: [StaffID: Clef] = [:]
    private var currentKeySignature: KeySignature?
    private var currentTimeSignature: TimeSignature?
    private var currentMeasureTempoEvents: [TempoEvent] = []
    private var currentMeasureDirections: [ScoreDirection] = []
    private var currentMeasureRepeatBarlines: [RepeatBarline] = []
    private var currentMeasureLeftBarlineStyle: BarlineStyle?
    private var currentMeasureRightBarlineStyle: BarlineStyle?
    private var currentMeasureRepeatEndings: [RepeatEnding] = []
    private var currentMeasureRepeat: MeasureRepeat?
    private var currentMeasurePlaybackJumpMarkers: [PlaybackJumpMarker] = []
    private var currentMusicXMLTranspose: MusicXMLTranspose?
    private var transposeBuilder: MusicXMLTransposeBuilder?

    private var noteBuilder: NoteBuilder?
    private var lyricBuilder: LyricBuilder?
    private var directionBuilder: DirectionBuilder?
    private var metronomeBuilder: MetronomeBuilder?
    private var pendingClefNumber: String?
    private var pendingClefSign: String?
    private var pendingBarlineLocation: String?

    init(policy: UnsupportedFeaturePolicy) {
        self.policy = policy
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if rootElement == nil {
            rootElement = elementName
            if elementName == "score-timewise" {
                recordUnsupported("score-timewise", message: "score-timewise MusicXML is not supported in Phase 2")
            } else if elementName != "score-partwise" {
                recordUnsupported(elementName, message: "Root element \(elementName) is not supported")
            }
        }

        elementStack.append(elementName)
        textBuffer = ""

        if !recognizedMusicXMLElements.contains(elementName) {
            recordUnsupported(elementName, message: "\(elementName) is not supported in Phase 2")
        }

        switch elementName {
        case "credit":
            currentCreditType = nil
        case "score-part":
            currentPartID = attributeDict["id"]
        case "part":
            partIndex += 1
            measureIndex = -1
            currentPartID = attributeDict["id"] ?? "P\(partIndex + 1)"
            currentMeasures = []
            currentOnset = 0
            xmlNoteOrdinal = 0
            activeClefsByStaff = [:]
        case "measure":
            measureIndex += 1
            currentMeasureNumber = attributeDict["number"] ?? String(measureIndex + 1)
            currentMeasureNotes = []
            currentOnset = 0
            previousNoteOnset = 0
            previousNoteDuration = 0
            chordOrdinal = 0
            currentMeasureClef = nil
            currentClefsByStaff = [:]
            currentMeasureEffectiveClefsByStaff = activeClefsByStaff
            currentMeasureClefChanges = []
            currentKeySignature = nil
            currentTimeSignature = nil
            currentMeasureTempoEvents = []
            currentMeasureDirections = []
            currentMeasureRepeatBarlines = []
            currentMeasureLeftBarlineStyle = nil
            currentMeasureRightBarlineStyle = nil
            currentMeasureRepeatEndings = []
            currentMeasureRepeat = nil
            currentMeasurePlaybackJumpMarkers = []
            currentMusicXMLTranspose = nil
            transposeBuilder = nil
        case "note":
            noteBuilder = NoteBuilder()
        case "direction":
            directionBuilder = DirectionBuilder(
                onset: MusicalTime(ticks: currentOnset, ticksPerQuarterNote: divisions),
                placement: ScoreDirectionPlacement(rawValue: attributeDict["placement"] ?? "") ?? .unspecified
            )
        case "lyric":
            lyricBuilder = LyricBuilder()
        case "chord":
            noteBuilder?.isChordTone = true
        case "rest":
            noteBuilder?.isRest = true
        case "dot":
            if noteBuilder != nil {
                noteBuilder?.dotCount += 1
            }
        case "clef":
            pendingClefNumber = attributeDict["number"]
            pendingClefSign = nil
        case "tie":
            if let type = attributeDict["type"], let tieKind = MusicXMLTieKind(rawValue: type) {
                appendTie(tieKind)
            }
        case "tied":
            if let type = attributeDict["type"], let tieKind = MusicXMLTieKind(rawValue: type) {
                appendTie(tieKind)
            }
        case "slur":
            if let type = attributeDict["type"], let slurKind = MusicXMLSlurKind(rawValue: type) {
                noteBuilder?.slurs.append(slurKind)
            }
        case "sound":
            if let tempo = attributeDict["tempo"] {
                recordTempo(tempo)
            }
            recordSoundJumpMarkers(attributes: attributeDict)
        case "barline":
            pendingBarlineLocation = attributeDict["location"]
        case "repeat":
            recordRepeat(direction: attributeDict["direction"], times: attributeDict["times"])
        case "ending":
            recordRepeatEnding(number: attributeDict["number"], type: attributeDict["type"])
        case "measure-repeat":
            if let repeatType = attributeDict["type"], repeatType != "start" {
                recordDiagnostic(
                    severity: .warning,
                    code: "unsupported.measureRepeatType",
                    elementName: elementName,
                    message: "MusicXML measure-repeat type \(repeatType) is recognized but only one-bar repeat start is rendered in the MVP."
                )
            }
        case "metronome":
            metronomeBuilder = MetronomeBuilder(
                onset: directionBuilder?.onset ?? MusicalTime(ticks: currentOnset, ticksPerQuarterNote: divisions),
                measureID: MeasureID(partIndex: partIndex, measureNumber: currentMeasureNumber)
            )
        case "pedal":
            if let type = attributeDict["type"], let pedalKind = PedalMarkKind(rawValue: type) {
                directionBuilder?.kinds.append(.pedal(pedalKind))
            }
        case "segno":
            if directionBuilder != nil {
                recordPlaybackJumpMarker(kind: .segno, text: "Segno")
            }
        case "coda":
            if directionBuilder != nil {
                recordPlaybackJumpMarker(kind: .coda, text: "Coda")
            }
        case "time-modification":
            noteBuilder?.hasTimeModification = true
        case "tuplet":
            noteBuilder?.hasTupletNotation = true
            if let type = attributeDict["type"], let tupletKind = MusicXMLTupletKind(rawValue: type) {
                noteBuilder?.tupletKind = tupletKind
            }
        case "staccato":
            noteBuilder?.articulations.append(.staccato)
        case "accent":
            noteBuilder?.articulations.append(.accent)
        case "tenuto":
            noteBuilder?.articulations.append(.tenuto)
        case "strong-accent":
            noteBuilder?.articulations.append(.marcato)
        case "detached-legato":
            recordDiagnostic(
                severity: .warning,
                code: "unsupported.detachedLegato",
                elementName: elementName,
                message: "MusicXML detached-legato is recognized but not rendered or applied to playback in the Articulation MVP."
            )
        case "fermata":
            noteBuilder?.articulations.append(.fermata)
        case "beam":
            if parentElement == "note" {
                noteBuilder?.pendingBeamNumber = Int(attributeDict["number"] ?? "") ?? 1
            }
        case "wedge":
            if let type = attributeDict["type"], let kind = ScoreWedgeKind(rawValue: type) {
                directionBuilder?.kinds.append(.wedge(kind))
            } else {
                recordDiagnostic(
                    severity: .warning,
                    code: "unsupported.wedgeType",
                    elementName: elementName,
                    message: "MusicXML wedge type \(attributeDict["type"] ?? "missing") is not supported by the dynamics MVP."
                )
            }
        case "ornaments":
            recordDiagnostic(
                severity: .warning,
                code: "unsupported.ornaments",
                elementName: elementName,
                message: "Ornaments are recognized but not rendered or expanded for playback in Phase 11F."
            )
        case "grace":
            noteBuilder?.isGrace = true
            recordDiagnostic(
                severity: .warning,
                code: "unsupported.grace.layout",
                elementName: elementName,
                message: "Grace-note layout and playback are not supported in Phase 11F."
            )
        case "transpose":
            transposeBuilder = MusicXMLTransposeBuilder()
            recordDiagnostic(
                severity: .warning,
                code: "unsupported.transpose",
                elementName: elementName,
                message: "MusicXML transpose metadata is recognized for diagnostics, but automatic transposing-instrument concert pitch conversion is not applied by the piano transpose MVP."
            )
        case "double":
            transposeBuilder?.doublesAtOctave = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "credit-type":
            currentCreditType = nonEmptyText(text)
        case "credit-words":
            recordCreditWords(text)
        case "credit":
            currentCreditType = nil
        case "work-title":
            workTitle = nonEmptyText(text)
        case "movement-title":
            movementTitle = nonEmptyText(text)
        case "movement-number":
            movementNumber = nonEmptyText(text)
        case "part-name":
            if let currentPartID {
                partListNames[currentPartID] = text
            }
        case "part":
            let partID = currentPartID ?? "P\(partIndex + 1)"
            parts.append(ScorePart(id: partID, name: partListNames[partID], measures: currentMeasures))
            currentPartID = nil
        case "measure":
            let measure = Measure(
                id: MeasureID(partIndex: partIndex, measureNumber: currentMeasureNumber),
                number: currentMeasureNumber,
                notes: currentMeasureNotes,
                clef: currentMeasureClef,
                clefsByStaff: currentClefsByStaff,
                effectiveClefsByStaff: currentMeasureEffectiveClefsByStaff,
                clefChanges: currentMeasureClefChanges,
                keySignature: currentKeySignature,
            timeSignature: currentTimeSignature,
            tempoEvents: currentMeasureTempoEvents,
            directions: currentMeasureDirections,
            repeatBarlines: currentMeasureRepeatBarlines,
            leftBarlineStyle: currentMeasureLeftBarlineStyle,
            rightBarlineStyle: currentMeasureRightBarlineStyle,
            repeatEndings: currentMeasureRepeatEndings,
                measureRepeat: currentMeasureRepeat,
                playbackJumpMarkers: currentMeasurePlaybackJumpMarkers,
                musicXMLTranspose: currentMusicXMLTranspose
            )
            currentMeasures.append(measure)
        case "divisions":
            divisions = max(Int(text) ?? divisions, 1)
        case "fifths":
            currentKeySignature = KeySignature(fifths: Int(text) ?? 0, mode: currentKeySignature?.mode)
        case "mode":
            currentKeySignature = KeySignature(fifths: currentKeySignature?.fifths ?? 0, mode: text)
        case "beats":
            currentTimeSignature = TimeSignature(beats: Int(text) ?? 4, beatType: currentTimeSignature?.beatType ?? 4)
        case "beat-type":
            currentTimeSignature = TimeSignature(beats: currentTimeSignature?.beats ?? 4, beatType: Int(text) ?? 4)
        case "diatonic":
            if parentElement == "transpose" {
                transposeBuilder?.diatonic = Int(text)
            }
        case "chromatic":
            if parentElement == "transpose" {
                transposeBuilder?.chromatic = Int(text)
            }
        case "octave-change":
            if parentElement == "transpose" {
                transposeBuilder?.octaveChange = Int(text)
            }
        case "sign":
            pendingClefSign = text
        case "clef":
            let clef = Clef(kind: clefKind(forSign: pendingClefSign))
            let staffID = StaffID(rawValue: pendingClefNumber ?? "1")
            let onset = MusicalTime(ticks: currentOnset, ticksPerQuarterNote: divisions)
            if currentOnset <= 0 {
                currentMeasureClef = clef
                currentClefsByStaff[staffID] = clef
                currentMeasureEffectiveClefsByStaff[staffID] = clef
            } else {
                currentMeasureClefChanges.append(ClefChange(staffID: staffID, clef: clef, onset: onset))
            }
            activeClefsByStaff[staffID] = clef
            pendingClefNumber = nil
            pendingClefSign = nil
        case "step":
            noteBuilder?.step = PitchStep(rawValue: text.lowercased())
        case "alter":
            noteBuilder?.alter = Int(text) ?? 0
        case "octave":
            noteBuilder?.octave = Int(text)
        case "duration":
            if parentElement == "backup" {
                currentOnset -= Int(text) ?? 0
            } else if parentElement == "forward" {
                currentOnset += Int(text) ?? 0
            } else {
                noteBuilder?.duration = Int(text) ?? 0
            }
        case "actual-notes":
            noteBuilder?.tupletActualNotes = Int(text)
        case "normal-notes":
            noteBuilder?.tupletNormalNotes = Int(text)
        case "voice":
            noteBuilder?.voiceID = VoiceID(rawValue: text.isEmpty ? "1" : text)
        case "staff":
            if parentElement == "direction" {
                directionBuilder?.staffID = StaffID(rawValue: text.isEmpty ? "1" : text)
            } else {
                noteBuilder?.staffID = StaffID(rawValue: text.isEmpty ? "1" : text)
            }
        case "accidental":
            noteBuilder?.accidental = text
        case "type":
            if parentElement == "note" {
                noteBuilder?.noteValueKind = NoteValueKind(musicXMLType: text)
            }
        case "stem":
            noteBuilder?.stemDirection = MusicXMLStemDirection(rawValue: text)
        case "bar-style":
            if parentElement == "barline", let style = BarlineStyle(musicXMLValue: text) {
                if pendingBarlineLocation == "left" {
                    currentMeasureLeftBarlineStyle = style
                } else {
                    currentMeasureRightBarlineStyle = style
                }
            }
        case "beat-unit":
            if parentElement == "metronome" {
                metronomeBuilder?.beatUnit = text
            }
        case "per-minute":
            if parentElement == "metronome" {
                metronomeBuilder?.perMinute = text
            }
        case "syllabic":
            lyricBuilder?.syllabic = LyricSyllabic(rawValue: text) ?? .unknown
        case "text":
            if parentElement == "lyric" {
                lyricBuilder?.text += text
            }
        case "words":
            recordPlaybackJumpMarker(text)
        case "p", "pp", "ppp", "mp", "mf", "f", "ff", "fff":
            if parentElement == "dynamics", let mark = DynamicMark(rawValue: elementName) {
                directionBuilder?.kinds.append(.dynamic(mark))
            }
        case "lyric":
            if let lyricBuilder, !lyricBuilder.text.isEmpty {
                noteBuilder?.lyrics.append(LyricAnnotation(text: lyricBuilder.text, syllabic: lyricBuilder.syllabic))
            }
            lyricBuilder = nil
        case "fingering":
            if parentElement == "technical", !text.isEmpty {
                noteBuilder?.fingerings.append(FingeringAnnotation(text: text))
            }
        case "beam":
            if parentElement == "note",
               let beamValue = MusicXMLBeamValue(rawValue: text) {
                let beamNumber = noteBuilder?.pendingBeamNumber ?? 1
                noteBuilder?.beams.append(MusicXMLBeam(
                    number: beamNumber,
                    value: beamValue
                ))
            }
            noteBuilder?.pendingBeamNumber = nil
        case "barline":
            pendingBarlineLocation = nil
        case "metronome":
            recordMetronomeTempo()
            metronomeBuilder = nil
        case "transpose":
            currentMusicXMLTranspose = transposeBuilder?.make()
            transposeBuilder = nil
        case "direction":
            if let directionBuilder {
                for kind in directionBuilder.kinds {
                    currentMeasureDirections.append(ScoreDirection(
                        kind: kind,
                        onset: directionBuilder.onset,
                        staffID: directionBuilder.staffID,
                        placement: directionBuilder.placement
                    ))
                }
            }
            directionBuilder = nil
        case "measure-repeat":
            let count = Int(text) ?? 1
            if count != 1 {
                recordDiagnostic(
                    severity: .warning,
                    code: "unsupported.measureRepeatCount",
                    elementName: elementName,
                    message: "MusicXML measure-repeat count \(count) is recognized but only one-bar repeat rendering is supported in the MVP."
                )
            }
            currentMeasureRepeat = MeasureRepeat(count: count)
        case "note":
            finishNote()
        default:
            break
        }

        _ = elementStack.popLast()
        textBuffer = ""
    }

    func finish() throws -> ParseResult {
        if rootElement == "score-timewise" {
            let diagnostic = RendererDiagnostic(
                severity: .error,
                code: "unsupported.score-timewise",
                message: "score-timewise MusicXML is not supported in Phase 2",
                location: MusicXMLLocation(elementName: "score-timewise")
            )
            if policy == .fail {
                throw MusicXMLParserError.unsupportedFeature(diagnostic)
            }
            return ParseResult(score: ScoreDocument(parts: [], title: scoreTitle), diagnostics: diagnostics)
        }
        if policy == .fail, let fatalUnsupportedDiagnostic {
            throw MusicXMLParserError.unsupportedFeature(fatalUnsupportedDiagnostic)
        }
        return ParseResult(score: ScoreDocument(parts: parts, title: scoreTitle), diagnostics: diagnostics)
    }

    private var parentElement: String? {
        guard elementStack.count >= 2 else { return nil }
        return elementStack[elementStack.count - 2]
    }

    private var scoreTitle: String? {
        if let movementTitle, !isPlaceholderTitle(movementTitle) {
            return movementTitle
        }
        if let workTitle, !isPlaceholderTitle(workTitle) {
            return workTitle
        }
        if let creditTitle, !isPlaceholderTitle(creditTitle) {
            return creditTitle
        }
        return movementNumber
    }

    private func isPlaceholderTitle(_ title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "subtitle" || normalized == "title" || normalized == "untitled"
    }

    private func nonEmptyText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func finishNote() {
        guard let builder = noteBuilder else { return }
        let duration = max(builder.duration, 0)
        let onset = builder.isChordTone ? previousNoteOnset : currentOnset
        let noteChordOrdinal: Int
        if builder.isChordTone {
            chordOrdinal += 1
            noteChordOrdinal = chordOrdinal
        } else {
            chordOrdinal = 0
            noteChordOrdinal = 0
        }
        let voiceID = builder.voiceID ?? VoiceID(rawValue: "1")
        let staffID = builder.staffID ?? StaffID(rawValue: "1")
        let musicalOnset = MusicalTime(ticks: onset, ticksPerQuarterNote: divisions)
        let id = NoteID(
            documentIndex: 0,
            partIndex: partIndex,
            measureIndex: measureIndex,
            xmlNoteOrdinal: xmlNoteOrdinal,
            voiceID: voiceID,
            staffID: staffID,
            onset: musicalOnset,
            chordOrdinal: noteChordOrdinal
        )

        let pitch: Pitch?
        if builder.isRest {
            pitch = nil
        } else if let step = builder.step, let octave = builder.octave {
            pitch = Pitch(step: step, octave: octave, alter: builder.alter)
        } else {
            pitch = nil
            recordUnsupported("note", message: "Pitched note is missing pitch data")
        }

        currentMeasureNotes.append(ScoreNote(
            id: id,
            pitch: pitch,
            onset: musicalOnset,
            duration: MusicalTime(ticks: duration, ticksPerQuarterNote: divisions),
            noteValueKind: builder.noteValueKind,
            dotCount: builder.dotCount,
            voiceID: voiceID,
            staffID: staffID,
            isChordTone: builder.isChordTone,
            chordOrdinal: noteChordOrdinal,
            accidental: builder.accidental,
            stemDirection: builder.stemDirection,
            ties: builder.ties,
            slurs: builder.slurs,
            beams: builder.beams,
            articulations: builder.articulations,
            lyrics: builder.lyrics,
            fingerings: builder.fingerings,
            isGrace: builder.isGrace,
            hasTimeModification: builder.hasTimeModification,
            hasTupletNotation: builder.hasTupletNotation,
            tuplet: builder.tupletInfo
        ))

        xmlNoteOrdinal += 1
        previousNoteOnset = onset
        previousNoteDuration = duration
        if !builder.isChordTone {
            currentOnset += duration
        }
        noteBuilder = nil
    }

    private func clefKind(forSign sign: String?) -> ClefKind {
        switch sign {
        case "G": .treble
        case "F": .bass
        case "C": .alto
        default: .unknown
        }
    }

    private func recordUnsupported(_ elementName: String, message: String) {
        guard warnedUnsupportedElements.insert(elementName).inserted else {
            return
        }
        recordDiagnostic(
            severity: policy == .fail ? .error : .warning,
            code: "unsupported.\(elementName)",
            elementName: elementName,
            message: message,
            deduplicate: false
        )
    }

    private func recordDiagnostic(
        severity: DiagnosticSeverity,
        code: String,
        elementName: String,
        message: String,
        deduplicate: Bool = true
    ) {
        if deduplicate {
            let key = "\(code).\(currentPartID ?? "").\(currentMeasureNumber)"
            guard warnedUnsupportedElements.insert(key).inserted else {
                return
            }
        }
        let diagnostic = RendererDiagnostic(
            severity: policy == .fail && severity == .warning ? .error : severity,
            code: code,
            message: message,
            location: MusicXMLLocation(
                elementName: elementName,
                partID: currentPartID,
                measureNumber: currentMeasureNumber.isEmpty ? nil : currentMeasureNumber
            )
        )
        diagnostics.append(diagnostic)
        if policy == .fail, fatalUnsupportedDiagnostic == nil {
            fatalUnsupportedDiagnostic = diagnostic
        }
    }

    private func recordTempo(_ value: String) {
        guard let bpm = Double(value), bpm > 0 else {
            recordDiagnostic(
                severity: .warning,
                code: "tempo.invalid",
                elementName: "sound",
                message: "Invalid MusicXML tempo value: \(value)"
            )
            return
        }

        currentMeasureTempoEvents.append(TempoEvent(
            bpm: bpm,
            onset: MusicalTime(ticks: currentOnset, ticksPerQuarterNote: divisions),
            source: .sound,
            measureID: MeasureID(partIndex: partIndex, measureNumber: currentMeasureNumber)
        ))
    }

    private func recordCreditWords(_ rawText: String) {
        guard let text = nonEmptyText(rawText), !isPlaceholderTitle(text) else {
            return
        }
        let normalizedType = currentCreditType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        if normalizedType == "title" || normalizedType == "movement title" || normalizedType == "work title" {
            creditTitle = creditTitle ?? text
        }
    }

    private func recordSoundJumpMarkers(attributes: [String: String]) {
        let hasDaCapo = soundAttributeIsEnabled(attributes["dacapo"])
        let hasDalSegno = attributes["dalsegno"].flatMap(nonEmptyText) != nil
        let hasFine = attributes["fine"].flatMap(nonEmptyText) != nil || soundAttributeIsEnabled(attributes["fine"])
        let hasToCoda = attributes["tocoda"].flatMap(nonEmptyText) != nil
        let hasCodaInstruction = hasToCoda || (hasDaCapo || hasDalSegno) && attributes["coda"].flatMap(nonEmptyText) != nil

        if let segnoLabel = attributes["segno"].flatMap(nonEmptyText) {
            recordPlaybackJumpMarker(kind: .segno, text: segnoLabel)
        }
        if let codaLabel = attributes["coda"].flatMap(nonEmptyText), !hasCodaInstruction {
            recordPlaybackJumpMarker(kind: .coda, text: codaLabel)
        }
        if hasToCoda {
            recordPlaybackJumpMarker(kind: .toCoda, text: attributes["tocoda"].flatMap(nonEmptyText) ?? "To Coda")
        }

        if hasDalSegno && hasCodaInstruction {
            recordPlaybackJumpMarker(kind: .dalSegnoAlCoda, text: "D.S. al Coda")
        } else if hasDalSegno && hasFine {
            recordPlaybackJumpMarker(kind: .dalSegnoAlFine, text: "D.S. al Fine")
        } else if hasDalSegno {
            recordPlaybackJumpMarker(kind: .dalSegno, text: "D.S.")
        } else if hasDaCapo && hasCodaInstruction {
            recordPlaybackJumpMarker(kind: .daCapoAlCoda, text: "D.C. al Coda")
        } else if hasDaCapo && hasFine {
            recordPlaybackJumpMarker(kind: .daCapoAlFine, text: "D.C. al Fine")
        } else if hasDaCapo {
            recordPlaybackJumpMarker(kind: .daCapo, text: "D.C.")
        } else if hasFine {
            recordPlaybackJumpMarker(kind: .fine, text: "Fine")
        }
    }

    private func soundAttributeIsEnabled(_ value: String?) -> Bool {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return false
        }
        switch value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased() {
        case "no", "false", "0":
            return false
        default:
            return true
        }
    }

    private func appendTie(_ kind: MusicXMLTieKind) {
        guard noteBuilder?.ties.contains(kind) == false else {
            return
        }
        noteBuilder?.ties.append(kind)
    }

    private func recordMetronomeTempo() {
        guard let builder = metronomeBuilder else {
            return
        }
        let rawTempo = builder.perMinute.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let perMinute = Double(rawTempo), perMinute > 0 else {
            if !rawTempo.isEmpty {
                recordDiagnostic(
                    severity: .warning,
                    code: "tempo.metronomeInvalid",
                    elementName: "metronome",
                    message: "Invalid MusicXML metronome per-minute value: \(rawTempo)"
                )
            }
            return
        }
        let quarterBPM = perMinute * metronomeBeatUnitQuarterMultiplier(builder.beatUnit)
        currentMeasureTempoEvents.append(TempoEvent(
            bpm: quarterBPM,
            onset: builder.onset,
            source: .metronome,
            measureID: builder.measureID
        ))
    }

    private func metronomeBeatUnitQuarterMultiplier(_ beatUnit: String) -> Double {
        switch beatUnit.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "whole":
            return 4
        case "half":
            return 2
        case "quarter", "":
            return 1
        case "eighth":
            return 0.5
        case "16th":
            return 0.25
        case "32nd":
            return 0.125
        default:
            recordDiagnostic(
                severity: .warning,
                code: "tempo.metronomeBeatUnitUnsupported",
                elementName: "beat-unit",
                message: "MusicXML metronome beat-unit \(beatUnit) is not supported; using quarter-note BPM."
            )
            return 1
        }
    }

    private func recordRepeat(direction: String?, times: String?) {
        guard let direction, let repeatDirection = RepeatDirection(rawValue: direction) else {
            recordDiagnostic(
                severity: .warning,
                code: "repeat.invalid",
                elementName: "repeat",
                message: "Invalid or missing MusicXML repeat direction."
            )
            return
        }

        let repeatTimes: Int?
        if let times, !times.isEmpty {
            repeatTimes = Int(times)
            if repeatTimes == nil {
                recordDiagnostic(
                    severity: .warning,
                    code: "repeat.countInvalid",
                    elementName: "repeat",
                    message: "Invalid MusicXML repeat times value: \(times). Repeat playback will use the MVP default."
                )
            }
        } else {
            repeatTimes = nil
        }

        currentMeasureRepeatBarlines.append(RepeatBarline(direction: repeatDirection, times: repeatTimes))
    }

    private func recordRepeatEnding(number: String?, type: String?) {
        let numbers = parseEndingNumbers(number)
        if numbers.isEmpty {
            recordDiagnostic(
                severity: .warning,
                code: "repeat.endingInvalid",
                elementName: "ending",
                message: "MusicXML ending is missing a usable number; ending playback expansion will ignore it."
            )
        }

        let kind = RepeatEndingKind(rawValue: type ?? "") ?? .unknown
        if kind == .unknown {
            recordDiagnostic(
                severity: .warning,
                code: "repeat.endingTypeUnsupported",
                elementName: "ending",
                message: "MusicXML ending type \(type ?? "missing") is not supported by the repeat ending MVP."
            )
        }

        currentMeasureRepeatEndings.append(RepeatEnding(numbers: numbers, kind: kind))
    }

    private func parseEndingNumbers(_ number: String?) -> [Int] {
        guard let number else {
            return []
        }
        return number
            .split { character in
                character == "," || character == " " || character == ";"
            }
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func recordPlaybackJumpMarker(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        let normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: ".", with: "")
        let compact = normalized
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
        let containsSegnoSymbol = text.contains("\u{1D10B}") || normalized.contains("SEGNO")
        let containsCodaSymbol = text.contains("\u{1D10C}") || normalized.contains("CODA")
        let containsDalSegno = compact.contains("DS") || normalized.contains("DAL SEGNO")
        let containsToCoda = normalized.contains("TO CODA")
            || normalized.contains("TO \u{1D10C}")
            || compact.contains("TOCODA")

        let kind: PlaybackJumpMarkerKind?
        if compact.contains("DC") && containsCodaSymbol {
            kind = .daCapoAlCoda
        } else if containsDalSegno && normalized.contains("FINE") {
            kind = .dalSegnoAlFine
        } else if containsDalSegno && containsCodaSymbol {
            kind = .dalSegnoAlCoda
        } else if compact.contains("DC") && normalized.contains("FINE") {
            kind = .daCapoAlFine
        } else if normalized == "FINE" || normalized.contains(" FINE") {
            kind = .fine
        } else if containsDalSegno {
            kind = .dalSegno
        } else if containsSegnoSymbol {
            kind = .segno
        } else if containsToCoda {
            kind = .toCoda
        } else if containsCodaSymbol {
            kind = .coda
        } else if compact.contains("DC") {
            kind = .daCapo
        } else {
            kind = nil
        }

        if let kind {
            recordPlaybackJumpMarker(kind: kind, text: text)
        }
    }

    private func recordPlaybackJumpMarker(kind: PlaybackJumpMarkerKind, text: String) {
        guard !currentMeasurePlaybackJumpMarkers.contains(where: { $0.kind == kind && $0.text == text }) else {
            return
        }
        currentMeasurePlaybackJumpMarkers.append(PlaybackJumpMarker(kind: kind, text: text))
    }
}

private struct NoteBuilder {
    var isRest = false
    var isChordTone = false
    var step: PitchStep?
    var alter = 0
    var octave: Int?
    var duration = 0
    var noteValueKind: NoteValueKind?
    var dotCount = 0
    var voiceID: VoiceID?
    var staffID: StaffID?
    var accidental: String?
    var stemDirection: MusicXMLStemDirection?
    var ties: [MusicXMLTieKind] = []
    var slurs: [MusicXMLSlurKind] = []
    var beams: [MusicXMLBeam] = []
    var pendingBeamNumber: Int?
    var articulations: [ScoreArticulationKind] = []
    var lyrics: [LyricAnnotation] = []
    var fingerings: [FingeringAnnotation] = []
    var isGrace = false
    var hasTimeModification = false
    var hasTupletNotation = false
    var tupletKind: MusicXMLTupletKind?
    var tupletActualNotes: Int?
    var tupletNormalNotes: Int?

    var tupletInfo: TupletInfo? {
        guard hasTimeModification || hasTupletNotation || tupletKind != nil || tupletActualNotes != nil || tupletNormalNotes != nil else {
            return nil
        }
        return TupletInfo(kind: tupletKind, actualNotes: tupletActualNotes, normalNotes: tupletNormalNotes)
    }
}

private struct LyricBuilder {
    var syllabic: LyricSyllabic = .unknown
    var text = ""
}

private struct DirectionBuilder {
    var onset: MusicalTime
    var placement: ScoreDirectionPlacement
    var staffID: StaffID?
    var kinds: [ScoreDirectionKind] = []
}

private struct MetronomeBuilder {
    var onset: MusicalTime
    var measureID: MeasureID
    var beatUnit = "quarter"
    var perMinute = ""
}

private struct MusicXMLTransposeBuilder {
    var diatonic: Int?
    var chromatic: Int?
    var octaveChange: Int?
    var doublesAtOctave = false

    func make() -> MusicXMLTranspose {
        MusicXMLTranspose(
            diatonic: diatonic,
            chromatic: chromatic,
            octaveChange: octaveChange,
            doublesAtOctave: doublesAtOctave
        )
    }
}

private let recognizedMusicXMLElements: Set<String> = [
    "score-partwise",
    "score-timewise",
    "credit",
    "credit-type",
    "credit-words",
    "work",
    "work-number",
    "work-title",
    "movement-number",
    "movement-title",
    "part-list",
    "score-part",
    "part-name",
    "part",
    "measure",
    "attributes",
    "divisions",
    "key",
    "fifths",
    "mode",
    "time",
    "beats",
    "beat-type",
    "clef",
    "sign",
    "line",
    "note",
    "pitch",
    "step",
    "alter",
    "octave",
    "rest",
    "duration",
    "type",
    "stem",
    "dot",
    "voice",
    "staff",
    "chord",
    "backup",
    "forward",
    "accidental",
    "tie",
    "tied",
    "lyric",
    "syllabic",
    "text",
    "notations",
    "articulations",
    "staccato",
    "accent",
    "tenuto",
    "strong-accent",
    "detached-legato",
    "fermata",
    "technical",
    "fingering",
    "direction",
    "direction-type",
    "metronome",
    "beat-unit",
    "per-minute",
    "pedal",
    "segno",
    "coda",
    "sound",
    "barline",
    "bar-style",
    "repeat",
    "ending",
    "measure-style",
    "measure-repeat",
    "time-modification",
    "actual-notes",
    "normal-notes",
    "normal-type",
    "normal-dot",
    "beam",
    "staff-details",
    "staff-type",
    "staff-lines",
    "print",
    "part-symbol",
    "wedge",
    "dynamics",
    "ppp",
    "pp",
    "p",
    "mp",
    "mf",
    "f",
    "ff",
    "fff",
    "words",
    "transpose",
    "diatonic",
    "octave-change",
    "double",
    "grace",
    "tuplet",
    "slur",
    "ornaments",
    "chromatic",
]
