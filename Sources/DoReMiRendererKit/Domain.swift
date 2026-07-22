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

public struct MusicXMLTranspose: Hashable, Codable, Sendable {
    public let diatonic: Int?
    public let chromatic: Int?
    public let octaveChange: Int?
    public let doublesAtOctave: Bool

    public init(
        diatonic: Int? = nil,
        chromatic: Int? = nil,
        octaveChange: Int? = nil,
        doublesAtOctave: Bool = false
    ) {
        self.diatonic = diatonic
        self.chromatic = chromatic
        self.octaveChange = octaveChange
        self.doublesAtOctave = doublesAtOctave
    }
}

public struct ScoreDocument: Hashable, Codable, Sendable {
    public let parts: [ScorePart]
    public let title: String?
    /// Composer credit resolved from MusicXML metadata when available.
    public let composer: String?

    public init(parts: [ScorePart], title: String? = nil, composer: String? = nil) {
        self.parts = parts
        self.title = title
        self.composer = composer
    }

    private enum CodingKeys: String, CodingKey {
        case parts
        case title
        case composer
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parts = try container.decode([ScorePart].self, forKey: .parts)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        composer = try container.decodeIfPresent(String.self, forKey: .composer)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(parts, forKey: .parts)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(composer, forKey: .composer)
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

public struct ClefChange: Hashable, Codable, Sendable {
    public let staffID: StaffID
    public let clef: Clef
    public let onset: MusicalTime

    public init(staffID: StaffID, clef: Clef, onset: MusicalTime) {
        self.staffID = staffID
        self.clef = clef
        self.onset = onset
    }
}

public struct Measure: Hashable, Codable, Sendable {
    public let id: MeasureID
    public let number: String
    public let notes: [ScoreNote]
    public let clef: Clef?
    public let clefsByStaff: [StaffID: Clef]
    public let effectiveClefsByStaff: [StaffID: Clef]
    public let clefChanges: [ClefChange]
    public let keySignature: KeySignature?
    public let timeSignature: TimeSignature?
    public let tempoEvents: [TempoEvent]
    public let directions: [ScoreDirection]
    public let repeatBarlines: [RepeatBarline]
    public let leftBarlineStyle: BarlineStyle?
    public let rightBarlineStyle: BarlineStyle?
    public let repeatEndings: [RepeatEnding]
    public let measureRepeat: MeasureRepeat?
    public let playbackJumpMarkers: [PlaybackJumpMarker]
    public let musicXMLTranspose: MusicXMLTranspose?

    public init(
        id: MeasureID,
        number: String,
        notes: [ScoreNote],
        clef: Clef? = nil,
        clefsByStaff: [StaffID: Clef] = [:],
        effectiveClefsByStaff: [StaffID: Clef] = [:],
        clefChanges: [ClefChange] = [],
        keySignature: KeySignature? = nil,
        timeSignature: TimeSignature? = nil,
        tempoEvents: [TempoEvent] = [],
        directions: [ScoreDirection] = [],
        repeatBarlines: [RepeatBarline] = [],
        leftBarlineStyle: BarlineStyle? = nil,
        rightBarlineStyle: BarlineStyle? = nil,
        repeatEndings: [RepeatEnding] = [],
        measureRepeat: MeasureRepeat? = nil,
        playbackJumpMarkers: [PlaybackJumpMarker] = [],
        musicXMLTranspose: MusicXMLTranspose? = nil
    ) {
        self.id = id
        self.number = number
        self.notes = notes
        self.clef = clef
        self.clefsByStaff = clefsByStaff
        self.effectiveClefsByStaff = effectiveClefsByStaff
        self.clefChanges = clefChanges
        self.keySignature = keySignature
        self.timeSignature = timeSignature
        self.tempoEvents = tempoEvents
        self.directions = directions
        self.repeatBarlines = repeatBarlines
        self.leftBarlineStyle = leftBarlineStyle
        self.rightBarlineStyle = rightBarlineStyle
        self.repeatEndings = repeatEndings
        self.measureRepeat = measureRepeat
        self.playbackJumpMarkers = playbackJumpMarkers
        self.musicXMLTranspose = musicXMLTranspose
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

public enum MusicXMLStemDirection: String, Hashable, Codable, Sendable {
    case up
    case down
    case none
    case double
}

public enum MusicXMLSlurKind: String, Hashable, Codable, Sendable {
    case start
    case stop
}

public enum MusicXMLBeamValue: String, Hashable, Codable, Sendable {
    case begin
    case `continue`
    case end
    case forwardHook = "forward hook"
    case backwardHook = "backward hook"
}

public struct MusicXMLBeam: Hashable, Codable, Sendable {
    public let number: Int
    public let value: MusicXMLBeamValue

    public init(number: Int = 1, value: MusicXMLBeamValue) {
        self.number = max(1, number)
        self.value = value
    }
}

public enum MusicXMLTupletKind: String, Hashable, Codable, Sendable {
    case start
    case stop
}

public enum ScoreArticulationKind: String, Hashable, Codable, Sendable {
    case staccato
    case accent
    case tenuto
    case marcato
    case fermata
}

public enum ScoreDirectionPlacement: String, Hashable, Codable, Sendable {
    case above
    case below
    case unspecified
}

public enum DynamicMark: String, Hashable, Codable, Sendable {
    case ppp
    case pp
    case p
    case mp
    case mf
    case f
    case ff
    case fff

    public var velocityScale: Double {
        switch self {
        case .ppp: 0.30
        case .pp: 0.42
        case .p: 0.55
        case .mp: 0.72
        case .mf: 0.92
        case .f: 1.12
        case .ff: 1.28
        case .fff: 1.42
        }
    }
}

public enum ScoreWedgeKind: String, Hashable, Codable, Sendable {
    case crescendo
    case diminuendo
    case stop
}

public enum PedalMarkKind: String, Hashable, Codable, Sendable {
    case start
    case stop
    case change
    case continuePedal = "continue"
}

public enum ScoreDirectionKind: Hashable, Codable, Sendable {
    case dynamic(DynamicMark)
    case wedge(ScoreWedgeKind)
    case pedal(PedalMarkKind)
}

public struct ScoreDirection: Hashable, Codable, Sendable {
    public let kind: ScoreDirectionKind
    public let onset: MusicalTime
    public let staffID: StaffID?
    public let placement: ScoreDirectionPlacement

    public init(
        kind: ScoreDirectionKind,
        onset: MusicalTime,
        staffID: StaffID? = nil,
        placement: ScoreDirectionPlacement = .unspecified
    ) {
        self.kind = kind
        self.onset = onset
        self.staffID = staffID
        self.placement = placement
    }
}

public struct TupletInfo: Hashable, Codable, Sendable {
    public let kind: MusicXMLTupletKind?
    public let actualNotes: Int?
    public let normalNotes: Int?

    public init(kind: MusicXMLTupletKind? = nil, actualNotes: Int? = nil, normalNotes: Int? = nil) {
        self.kind = kind
        self.actualNotes = actualNotes
        self.normalNotes = normalNotes
    }
}

public enum NoteValueKind: String, Hashable, Codable, Sendable {
    case whole
    case half
    case quarter
    case eighth
    case sixteenth
    case thirtySecond
    case sixtyFourth
    case other

    public init(musicXMLType: String?) {
        switch musicXMLType {
        case "whole":
            self = .whole
        case "half":
            self = .half
        case "quarter":
            self = .quarter
        case "eighth":
            self = .eighth
        case "16th":
            self = .sixteenth
        case "32nd":
            self = .thirtySecond
        case "64th":
            self = .sixtyFourth
        default:
            self = .other
        }
    }

    public init(duration: MusicalTime) {
        let quarters = Double(duration.ticks) / Double(duration.ticksPerQuarterNote)
        if quarters >= 3.5 {
            self = .whole
        } else if quarters >= 1.5 {
            self = .half
        } else if quarters >= 0.75 {
            self = .quarter
        } else if quarters >= 0.375 {
            self = .eighth
        } else if quarters >= 0.1875 {
            self = .sixteenth
        } else if quarters >= 0.09375 {
            self = .thirtySecond
        } else {
            self = .sixtyFourth
        }
    }
}

public struct ScoreNote: Hashable, Codable, Sendable {
    public let id: NoteID
    public let pitch: Pitch?
    public let onset: MusicalTime
    public let duration: MusicalTime
    public let noteValueKind: NoteValueKind
    public let dotCount: Int
    public let voiceID: VoiceID
    public let staffID: StaffID
    public let isChordTone: Bool
    public let chordOrdinal: Int
    public let accidental: String?
    public let stemDirection: MusicXMLStemDirection?
    public let ties: [MusicXMLTieKind]
    public let slurs: [MusicXMLSlurKind]
    public let beams: [MusicXMLBeam]
    public let articulations: [ScoreArticulationKind]
    public let lyrics: [LyricAnnotation]
    public let fingerings: [FingeringAnnotation]
    public let isGrace: Bool
    public let hasTimeModification: Bool
    public let hasTupletNotation: Bool
    public let tuplet: TupletInfo?

    public init(
        id: NoteID,
        pitch: Pitch?,
        onset: MusicalTime,
        duration: MusicalTime,
        noteValueKind: NoteValueKind? = nil,
        dotCount: Int = 0,
        voiceID: VoiceID,
        staffID: StaffID,
        isChordTone: Bool = false,
        chordOrdinal: Int = 0,
        accidental: String? = nil,
        stemDirection: MusicXMLStemDirection? = nil,
        ties: [MusicXMLTieKind] = [],
        slurs: [MusicXMLSlurKind] = [],
        beams: [MusicXMLBeam] = [],
        articulations: [ScoreArticulationKind] = [],
        lyrics: [LyricAnnotation] = [],
        fingerings: [FingeringAnnotation] = [],
        isGrace: Bool = false,
        hasTimeModification: Bool = false,
        hasTupletNotation: Bool = false,
        tuplet: TupletInfo? = nil
    ) {
        self.id = id
        self.pitch = pitch
        self.onset = onset
        self.duration = duration
        self.noteValueKind = noteValueKind ?? NoteValueKind(duration: duration)
        self.dotCount = max(0, dotCount)
        self.voiceID = voiceID
        self.staffID = staffID
        self.isChordTone = isChordTone
        self.chordOrdinal = chordOrdinal
        self.accidental = accidental
        self.stemDirection = stemDirection
        self.ties = ties
        self.slurs = slurs
        self.beams = beams
        self.articulations = articulations
        self.lyrics = lyrics
        self.fingerings = fingerings
        self.isGrace = isGrace
        self.hasTimeModification = hasTimeModification
        self.hasTupletNotation = hasTupletNotation
        self.tuplet = tuplet
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
    public let measureID: MeasureID?

    public init(bpm: Double, onset: MusicalTime, source: TempoSource, measureID: MeasureID? = nil) {
        self.bpm = bpm
        self.onset = onset
        self.source = source
        self.measureID = measureID
    }
}

public enum RepeatDirection: String, Hashable, Codable, Sendable {
    case forward
    case backward
}

public enum BarlineStyle: String, Hashable, Codable, Sendable {
    case regular
    case dotted
    case dashed
    case heavy
    case lightLight = "light-light"
    case lightHeavy = "light-heavy"
    case heavyLight = "heavy-light"
    case heavyHeavy = "heavy-heavy"
    case none
    case tick
    case short

    public init?(musicXMLValue: String) {
        self.init(rawValue: musicXMLValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public struct RepeatBarline: Hashable, Codable, Sendable {
    public let direction: RepeatDirection
    public let times: Int?

    public init(direction: RepeatDirection, times: Int? = nil) {
        self.direction = direction
        self.times = times
    }
}

public enum RepeatEndingKind: String, Hashable, Codable, Sendable {
    case start
    case stop
    case discontinue
    case unknown
}

public struct RepeatEnding: Hashable, Codable, Sendable {
    public let numbers: [Int]
    public let kind: RepeatEndingKind

    public init(numbers: [Int], kind: RepeatEndingKind) {
        self.numbers = numbers
        self.kind = kind
    }
}

public enum PlaybackJumpMarkerKind: String, Hashable, Codable, Sendable {
    case fine
    case daCapo
    case daCapoAlFine
    case daCapoAlCoda
    case dalSegno
    case dalSegnoAlFine
    case dalSegnoAlCoda
    case segno
    case coda
    case toCoda
}

public struct PlaybackJumpMarker: Hashable, Codable, Sendable {
    public let kind: PlaybackJumpMarkerKind
    public let text: String

    public init(kind: PlaybackJumpMarkerKind, text: String) {
        self.kind = kind
        self.text = text
    }
}

public enum ScoreElementKind: Hashable, Codable, Sendable {
    case notehead
    case rest
    case stem
    case flag
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
    case articulation
    case dynamic
    case hairpin
    case pedal
    case tie
    case slur
    case tuplet
    case repeatEnding
    case measureRepeat
    case playbackJumpMarker
}

public struct MeasureRepeat: Hashable, Codable, Sendable {
    public let count: Int

    public init(count: Int = 1) {
        self.count = max(1, count)
    }
}
