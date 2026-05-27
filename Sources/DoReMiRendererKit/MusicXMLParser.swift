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
    private var currentKeySignature: KeySignature?
    private var currentTimeSignature: TimeSignature?
    private var currentMeasureTempoEvents: [TempoEvent] = []
    private var currentMeasureRepeatBarlines: [RepeatBarline] = []
    private var currentMeasureRepeatEndings: [RepeatEnding] = []
    private var currentMeasureRepeat: MeasureRepeat?
    private var currentMeasurePlaybackJumpMarkers: [PlaybackJumpMarker] = []
    private var currentMusicXMLTranspose: MusicXMLTranspose?
    private var transposeBuilder: MusicXMLTransposeBuilder?

    private var noteBuilder: NoteBuilder?
    private var lyricBuilder: LyricBuilder?
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
        case "score-part":
            currentPartID = attributeDict["id"]
        case "part":
            partIndex += 1
            measureIndex = -1
            currentPartID = attributeDict["id"] ?? "P\(partIndex + 1)"
            currentMeasures = []
            currentOnset = 0
            xmlNoteOrdinal = 0
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
            currentKeySignature = nil
            currentTimeSignature = nil
            currentMeasureTempoEvents = []
            currentMeasureRepeatBarlines = []
            currentMeasureRepeatEndings = []
            currentMeasureRepeat = nil
            currentMeasurePlaybackJumpMarkers = []
            currentMusicXMLTranspose = nil
            transposeBuilder = nil
        case "note":
            noteBuilder = NoteBuilder()
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
                noteBuilder?.ties.append(tieKind)
            }
        case "slur":
            if let type = attributeDict["type"], let slurKind = MusicXMLSlurKind(rawValue: type) {
                noteBuilder?.slurs.append(slurKind)
            }
        case "sound":
            if let tempo = attributeDict["tempo"] {
                recordTempo(tempo)
            }
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
            recordDiagnostic(
                severity: .warning,
                code: "tempo.metronomeUnsupported",
                elementName: elementName,
                message: "Metronome direction metadata is recognized but detailed metronome conversion is not supported in Phase 11F."
            )
        case "time-modification":
            noteBuilder?.hasTimeModification = true
        case "tuplet":
            noteBuilder?.hasTupletNotation = true
            if let type = attributeDict["type"], let tupletKind = MusicXMLTupletKind(rawValue: type) {
                noteBuilder?.tupletKind = tupletKind
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
        case "beam":
            break
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
                keySignature: currentKeySignature,
                timeSignature: currentTimeSignature,
                tempoEvents: currentMeasureTempoEvents,
                repeatBarlines: currentMeasureRepeatBarlines,
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
            currentMeasureClef = clef
            currentClefsByStaff[StaffID(rawValue: pendingClefNumber ?? "1")] = clef
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
            noteBuilder?.staffID = StaffID(rawValue: text.isEmpty ? "1" : text)
        case "accidental":
            noteBuilder?.accidental = text
        case "type":
            if parentElement == "note" {
                noteBuilder?.noteValueKind = NoteValueKind(musicXMLType: text)
            }
        case "syllabic":
            lyricBuilder?.syllabic = LyricSyllabic(rawValue: text) ?? .unknown
        case "text":
            if parentElement == "lyric" {
                lyricBuilder?.text += text
            }
        case "words":
            recordPlaybackJumpMarker(text)
        case "lyric":
            if let lyricBuilder, !lyricBuilder.text.isEmpty {
                noteBuilder?.lyrics.append(LyricAnnotation(text: lyricBuilder.text, syllabic: lyricBuilder.syllabic))
            }
            lyricBuilder = nil
        case "fingering":
            if parentElement == "technical", !text.isEmpty {
                noteBuilder?.fingerings.append(FingeringAnnotation(text: text))
            }
        case "barline":
            pendingBarlineLocation = nil
        case "transpose":
            currentMusicXMLTranspose = transposeBuilder?.make()
            transposeBuilder = nil
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
        movementTitle ?? workTitle ?? movementNumber
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
            ties: builder.ties,
            slurs: builder.slurs,
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

        let kind: PlaybackJumpMarkerKind?
        if normalized.contains("DC") && normalized.contains("CODA") {
            kind = .daCapoAlCoda
        } else if normalized.contains("DS") && normalized.contains("FINE") {
            kind = .dalSegnoAlFine
        } else if normalized.contains("DS") && normalized.contains("CODA") {
            kind = .dalSegnoAlCoda
        } else if normalized.contains("DC") && normalized.contains("FINE") {
            kind = .daCapoAlFine
        } else if normalized == "FINE" || normalized.contains(" FINE") {
            kind = .fine
        } else if normalized.contains("DS") {
            kind = .dalSegno
        } else if normalized.contains("SEGNO") {
            kind = .segno
        } else if normalized.contains("TO CODA") {
            kind = .toCoda
        } else if normalized.contains("CODA") {
            kind = .coda
        } else if normalized.contains("DC") {
            kind = .daCapo
        } else {
            kind = nil
        }

        if let kind {
            currentMeasurePlaybackJumpMarkers.append(PlaybackJumpMarker(kind: kind, text: text))
        }
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
    var ties: [MusicXMLTieKind] = []
    var slurs: [MusicXMLSlurKind] = []
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
    "dot",
    "voice",
    "staff",
    "chord",
    "backup",
    "forward",
    "accidental",
    "tie",
    "lyric",
    "syllabic",
    "text",
    "notations",
    "technical",
    "fingering",
    "direction",
    "direction-type",
    "metronome",
    "beat-unit",
    "per-minute",
    "sound",
    "barline",
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
