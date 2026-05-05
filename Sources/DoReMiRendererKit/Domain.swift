import Foundation

public struct NoteID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(
        documentIndex: Int,
        partIndex: Int,
        measureIndex: Int,
        xmlNoteOrdinal: Int,
        voiceID: VoiceID,
        staffID: StaffID,
        onset: MusicalTime,
        chordOrdinal: Int
    ) {
        rawValue = [
            documentIndex,
            partIndex,
            measureIndex,
            xmlNoteOrdinal,
            voiceID.rawValue,
            staffID.rawValue,
            onset.ticks,
            onset.ticksPerQuarterNote,
            chordOrdinal,
        ]
        .map(String.init(describing:))
        .joined(separator: ".")
    }
}

public struct ScoreElementID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct MeasureID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(partIndex: Int, measureNumber: String) {
        rawValue = "\(partIndex).\(measureNumber)"
    }
}

public struct VoiceID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct StaffID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct MusicalTime: Codable, Sendable, Comparable, Hashable {
    public let ticks: Int
    public let ticksPerQuarterNote: Int

    public init(ticks: Int, ticksPerQuarterNote: Int) {
        precondition(ticksPerQuarterNote > 0, "ticksPerQuarterNote must be positive")
        self.ticks = ticks
        self.ticksPerQuarterNote = ticksPerQuarterNote
    }

    public static func < (lhs: MusicalTime, rhs: MusicalTime) -> Bool {
        lhs.ticks * rhs.ticksPerQuarterNote < rhs.ticks * lhs.ticksPerQuarterNote
    }

    public static func == (lhs: MusicalTime, rhs: MusicalTime) -> Bool {
        lhs.ticks * rhs.ticksPerQuarterNote == rhs.ticks * lhs.ticksPerQuarterNote
    }

    public func hash(into hasher: inout Hasher) {
        let divisor = greatestCommonDivisor(ticks, ticksPerQuarterNote)
        hasher.combine(ticks / divisor)
        hasher.combine(ticksPerQuarterNote / divisor)
    }

    public static func + (lhs: MusicalTime, rhs: MusicalTime) -> MusicalTime {
        let denominator = leastCommonMultiple(lhs.ticksPerQuarterNote, rhs.ticksPerQuarterNote)
        let lhsTicks = lhs.ticks * denominator / lhs.ticksPerQuarterNote
        let rhsTicks = rhs.ticks * denominator / rhs.ticksPerQuarterNote
        return MusicalTime(ticks: lhsTicks + rhsTicks, ticksPerQuarterNote: denominator)
    }

    public static func - (lhs: MusicalTime, rhs: MusicalTime) -> MusicalTime {
        let denominator = leastCommonMultiple(lhs.ticksPerQuarterNote, rhs.ticksPerQuarterNote)
        let lhsTicks = lhs.ticks * denominator / lhs.ticksPerQuarterNote
        let rhsTicks = rhs.ticks * denominator / rhs.ticksPerQuarterNote
        return MusicalTime(ticks: lhsTicks - rhsTicks, ticksPerQuarterNote: denominator)
    }
}

private func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
    var a = abs(lhs)
    var b = abs(rhs)
    while b != 0 {
        let remainder = a % b
        a = b
        b = remainder
    }
    return a
}

private func leastCommonMultiple(_ lhs: Int, _ rhs: Int) -> Int {
    abs(lhs / greatestCommonDivisor(lhs, rhs) * rhs)
}

public enum PitchStep: String, CaseIterable, Hashable, Codable, Sendable {
    case c
    case d
    case e
    case f
    case g
    case a
    case b

    fileprivate var diatonicIndex: Int {
        switch self {
        case .c: 0
        case .d: 1
        case .e: 2
        case .f: 3
        case .g: 4
        case .a: 5
        case .b: 6
        }
    }
}

public enum PitchClass: String, CaseIterable, Hashable, Codable, Sendable {
    case c
    case d
    case e
    case f
    case g
    case a
    case b
}

public struct Pitch: Hashable, Codable, Sendable {
    public let step: PitchStep
    public let octave: Int
    public let alter: Int

    public init(step: PitchStep, octave: Int, alter: Int = 0) {
        self.step = step
        self.octave = octave
        self.alter = alter
    }

    public var pitchClass: PitchClass {
        PitchClass(rawValue: step.rawValue)!
    }

    fileprivate var diatonicNumber: Int {
        octave * 7 + step.diatonicIndex
    }
}

public enum ClefKind: String, Hashable, Codable, Sendable {
    case treble
    case bass
    case alto
    case tenor
    case unknown
}

public struct Clef: Hashable, Codable, Sendable {
    public let kind: ClefKind

    public init(kind: ClefKind) {
        self.kind = kind
    }
}

public struct StaffPosition: Hashable, Codable, Sendable {
    public let stepsFromMiddleLine: Int

    public init(stepsFromMiddleLine: Int) {
        self.stepsFromMiddleLine = stepsFromMiddleLine
    }
}

public func staffPosition(pitch: Pitch, clef: Clef) -> StaffPosition {
    let referencePitch: Pitch
    switch clef.kind {
    case .treble:
        referencePitch = Pitch(step: .b, octave: 4)
    case .bass:
        referencePitch = Pitch(step: .d, octave: 3)
    case .alto, .tenor, .unknown:
        referencePitch = Pitch(step: .b, octave: 4)
    }
    return StaffPosition(stepsFromMiddleLine: pitch.diatonicNumber - referencePitch.diatonicNumber)
}

public struct KeySignature: Hashable, Codable, Sendable {
    public let fifths: Int
    public let mode: String?

    public init(fifths: Int, mode: String? = nil) {
        self.fifths = fifths
        self.mode = mode
    }
}

public struct TimeSignature: Hashable, Codable, Sendable {
    public let beats: Int
    public let beatType: Int

    public init(beats: Int, beatType: Int) {
        self.beats = beats
        self.beatType = beatType
    }
}

public struct ScoreDocument: Hashable, Codable, Sendable {
    public let parts: [ScorePart]

    public init(parts: [ScorePart]) {
        self.parts = parts
    }
}

public struct ScorePart: Hashable, Codable, Sendable {
    public let id: String
    public let name: String?
    public let measures: [Measure]

    public init(id: String, name: String? = nil, measures: [Measure]) {
        self.id = id
        self.name = name
        self.measures = measures
    }
}

public struct Measure: Hashable, Codable, Sendable {
    public let id: MeasureID
    public let number: String
    public let notes: [ScoreNote]
    public let clef: Clef?
    public let clefsByStaff: [StaffID: Clef]
    public let keySignature: KeySignature?
    public let timeSignature: TimeSignature?
    public let tempoEvents: [TempoEvent]
    public let repeatBarlines: [RepeatBarline]

    public init(
        id: MeasureID,
        number: String,
        notes: [ScoreNote],
        clef: Clef? = nil,
        clefsByStaff: [StaffID: Clef] = [:],
        keySignature: KeySignature? = nil,
        timeSignature: TimeSignature? = nil,
        tempoEvents: [TempoEvent] = [],
        repeatBarlines: [RepeatBarline] = []
    ) {
        self.id = id
        self.number = number
        self.notes = notes
        self.clef = clef
        self.clefsByStaff = clefsByStaff
        self.keySignature = keySignature
        self.timeSignature = timeSignature
        self.tempoEvents = tempoEvents
        self.repeatBarlines = repeatBarlines
    }
}

public struct MusicXMLLocation: Hashable, Codable, Sendable {
    public let elementName: String?
    public let partID: String?
    public let measureNumber: String?

    public init(elementName: String? = nil, partID: String? = nil, measureNumber: String? = nil) {
        self.elementName = elementName
        self.partID = partID
        self.measureNumber = measureNumber
    }
}

public enum DiagnosticSeverity: String, Hashable, Codable, Sendable {
    case info
    case warning
    case error
}

public struct RendererDiagnostic: Hashable, Codable, Sendable {
    public let severity: DiagnosticSeverity
    public let code: String
    public let message: String
    public let location: MusicXMLLocation?

    public init(
        severity: DiagnosticSeverity,
        code: String,
        message: String,
        location: MusicXMLLocation? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.location = location
    }
}

public protocol RendererDiagnosticReporting: Error {
    var diagnostic: RendererDiagnostic { get }
}

public enum UnsupportedFeaturePolicy: Hashable, Codable, Sendable {
    case ignoreWithWarning
    case fail
}

public struct ParseResult: Sendable {
    public let score: ScoreDocument
    public let diagnostics: [RendererDiagnostic]

    public init(score: ScoreDocument, diagnostics: [RendererDiagnostic]) {
        self.score = score
        self.diagnostics = diagnostics
    }
}

public enum MusicXMLTieKind: String, Hashable, Codable, Sendable {
    case start
    case stop
}

public struct ScoreNote: Hashable, Codable, Sendable {
    public let id: NoteID
    public let pitch: Pitch?
    public let onset: MusicalTime
    public let duration: MusicalTime
    public let voiceID: VoiceID
    public let staffID: StaffID
    public let isChordTone: Bool
    public let chordOrdinal: Int
    public let accidental: String?
    public let ties: [MusicXMLTieKind]
    public let lyrics: [LyricAnnotation]
    public let fingerings: [FingeringAnnotation]
    public let isGrace: Bool
    public let hasTimeModification: Bool
    public let hasTupletNotation: Bool

    public init(
        id: NoteID,
        pitch: Pitch?,
        onset: MusicalTime,
        duration: MusicalTime,
        voiceID: VoiceID,
        staffID: StaffID,
        isChordTone: Bool = false,
        chordOrdinal: Int = 0,
        accidental: String? = nil,
        ties: [MusicXMLTieKind] = [],
        lyrics: [LyricAnnotation] = [],
        fingerings: [FingeringAnnotation] = [],
        isGrace: Bool = false,
        hasTimeModification: Bool = false,
        hasTupletNotation: Bool = false
    ) {
        self.id = id
        self.pitch = pitch
        self.onset = onset
        self.duration = duration
        self.voiceID = voiceID
        self.staffID = staffID
        self.isChordTone = isChordTone
        self.chordOrdinal = chordOrdinal
        self.accidental = accidental
        self.ties = ties
        self.lyrics = lyrics
        self.fingerings = fingerings
        self.isGrace = isGrace
        self.hasTimeModification = hasTimeModification
        self.hasTupletNotation = hasTupletNotation
    }
}

public enum LyricSyllabic: String, Hashable, Codable, Sendable {
    case single
    case begin
    case middle
    case end
    case unknown
}

public struct LyricAnnotation: Hashable, Codable, Sendable {
    public let text: String
    public let syllabic: LyricSyllabic

    public init(text: String, syllabic: LyricSyllabic = .unknown) {
        self.text = text
        self.syllabic = syllabic
    }
}

public struct FingeringAnnotation: Hashable, Codable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public enum TempoSource: String, Hashable, Codable, Sendable {
    case sound
    case metronome
}

public struct TempoEvent: Hashable, Codable, Sendable {
    public let bpm: Double
    public let onset: MusicalTime
    public let source: TempoSource

    public init(bpm: Double, onset: MusicalTime, source: TempoSource) {
        self.bpm = bpm
        self.onset = onset
        self.source = source
    }
}

public enum RepeatDirection: String, Hashable, Codable, Sendable {
    case forward
    case backward
}

public struct RepeatBarline: Hashable, Codable, Sendable {
    public let direction: RepeatDirection

    public init(direction: RepeatDirection) {
        self.direction = direction
    }
}

public enum ScoreElementKind: Hashable, Codable, Sendable {
    case notehead
    case rest
    case stem
    case beam
    case accidental
    case dot
    case ledgerLine
    case staffLine
    case clef
    case timeSignature
    case keySignature
    case barline
    case lyric
    case fingering
}
