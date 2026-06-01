import CoreGraphics
import CoreText
import Foundation

enum SMuFLGlyph: Hashable, Sendable {
    case trebleClef
    case bassClef
    case accidentalSharp
    case accidentalFlat
    case accidentalNatural
    case accidentalDoubleSharp
    case accidentalDoubleFlat
    case restWhole
    case restHalf
    case restQuarter
    case restEighth
    case restSixteenth
    case restThirtySecond
    case repeatDot
    case repeatOneBar
    case timeSignatureDigit(Int)
    case noteheadWhole
    case noteheadHalf
    case noteheadBlack
    case flagEighthUp
    case flagEighthDown
    case flagSixteenthUp
    case flagSixteenthDown
    case flagThirtySecondUp
    case flagThirtySecondDown
    case segno
    case coda

    var string: String {
        String(UnicodeScalar(codepoint)!)
    }

    var fallback: String {
        switch self {
        case .trebleClef:
            "𝄞"
        case .bassClef:
            "𝄢"
        case .accidentalSharp:
            "#"
        case .accidentalFlat:
            "b"
        case .accidentalNatural:
            "n"
        case .accidentalDoubleSharp:
            "x"
        case .accidentalDoubleFlat:
            "bb"
        case .restWhole:
            "whole"
        case .restHalf:
            "half"
        case .restQuarter:
            "𝄽"
        case .restEighth:
            "𝄾"
        case .restSixteenth, .restThirtySecond:
            "𝄿"
        case .repeatDot:
            "•"
        case .repeatOneBar:
            "%"
        case let .timeSignatureDigit(value):
            String(value)
        case .noteheadWhole, .noteheadHalf:
            "○"
        case .noteheadBlack:
            "●"
        case .flagEighthUp, .flagEighthDown, .flagSixteenthUp, .flagSixteenthDown, .flagThirtySecondUp, .flagThirtySecondDown:
            "♪"
        case .segno:
            "𝄋"
        case .coda:
            "𝄌"
        }
    }

    private var codepoint: Int {
        switch self {
        case .trebleClef:
            0xE050
        case .bassClef:
            0xE062
        case .accidentalSharp:
            0xE262
        case .accidentalFlat:
            0xE260
        case .accidentalNatural:
            0xE261
        case .accidentalDoubleSharp:
            0xE263
        case .accidentalDoubleFlat:
            0xE264
        case .restWhole:
            0xE4E3
        case .restHalf:
            0xE4E4
        case .restQuarter:
            0xE4E5
        case .restEighth:
            0xE4E6
        case .restSixteenth:
            0xE4E7
        case .restThirtySecond:
            0xE4E8
        case .repeatDot:
            0xE044
        case .repeatOneBar:
            0xE500
        case let .timeSignatureDigit(value):
            0xE080 + max(0, min(9, value))
        case .noteheadWhole:
            0xE0A2
        case .noteheadHalf:
            0xE0A3
        case .noteheadBlack:
            0xE0A4
        case .flagEighthUp:
            0xE240
        case .flagEighthDown:
            0xE241
        case .flagSixteenthUp:
            0xE242
        case .flagSixteenthDown:
            0xE243
        case .flagThirtySecondUp:
            0xE244
        case .flagThirtySecondDown:
            0xE245
        case .segno:
            0xE047
        case .coda:
            0xE048
        }
    }
}

enum SMuFLFont {
    static let fontName = "Bravura"
    static let resourceName = "Bravura"
    static let resourceExtension = "otf"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var registered = false
    nonisolated(unsafe) private static var registrationAttempted = false

    static func registeredFontName() -> String? {
        registerIfNeeded() ? fontName : nil
    }

    static func registerIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if registered {
            return true
        }
        if registrationAttempted {
            return false
        }
        registrationAttempted = true

        guard let fontURL = Bundle.module.url(
            forResource: resourceName,
            withExtension: resourceExtension,
            subdirectory: "Fonts"
        ) ?? Bundle.module.url(
            forResource: resourceName,
            withExtension: resourceExtension
        ) else {
            return false
        }

        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
            registered = true
            return true
        }

        let font = CTFontCreateWithName(fontName as CFString, 12, nil)
        if CTFontCopyPostScriptName(font) as String == fontName {
            registered = true
            return true
        }

        return false
    }
}

struct SMuFLGlyphSizePolicy: Sendable {
    let clefScale: CGFloat = 0.90
    let timeSignatureScale: CGFloat = 1.00
    let blackNoteheadScale: CGFloat = 2.55
    let hollowNoteheadScale: CGFloat = 2.55
    let accidentalScale: CGFloat = 1.08
    let keySignatureAccidentalScale: CGFloat = 1.08
    let restScale: CGFloat = 2.08
    let flagScale: CGFloat = 1.00
    let repeatDotScale: CGFloat = 0.70

    func clefSize(for frame: CGRect) -> CGFloat {
        max(20, frame.height * clefScale)
    }

    func timeSignatureSize(for frame: CGRect) -> CGFloat {
        max(20, frame.height * timeSignatureScale)
    }

    func noteheadSize(for frame: CGRect, noteValue: NoteValueKind) -> CGFloat {
        let scale: CGFloat
        switch noteValue {
        case .whole, .half:
            scale = hollowNoteheadScale
        case .quarter, .eighth, .sixteenth, .thirtySecond, .other:
            scale = blackNoteheadScale
        }
        return max(20, frame.height * scale)
    }

    func accidentalSize(for frame: CGRect) -> CGFloat {
        max(12, frame.height * accidentalScale)
    }

    func keySignatureAccidentalSize(for frame: CGRect) -> CGFloat {
        max(12, frame.height * keySignatureAccidentalScale)
    }

    func restSize(for frame: CGRect, noteValue: NoteValueKind) -> CGFloat {
        let baselineMinimum: CGFloat = switch noteValue {
        case .whole, .half:
            34
        case .quarter, .eighth, .sixteenth, .thirtySecond, .other:
            38
        }
        let scaledMinimum = min(baselineMinimum, frame.height * 2.46)
        return max(scaledMinimum, frame.height * restScale)
    }

    func flagSize(for frame: CGRect) -> CGFloat {
        max(14, frame.height * flagScale)
    }

    func repeatDotSize(for frame: CGRect) -> CGFloat {
        max(4, frame.height * repeatDotScale)
    }
}

extension SMuFLGlyph {
    static func rest(for noteValue: NoteValueKind) -> SMuFLGlyph {
        switch noteValue {
        case .whole:
            .restWhole
        case .half:
            .restHalf
        case .quarter:
            .restQuarter
        case .eighth:
            .restEighth
        case .sixteenth:
            .restSixteenth
        case .thirtySecond:
            .restThirtySecond
        case .other:
            .restQuarter
        }
    }

    static func notehead(for noteValue: NoteValueKind) -> SMuFLGlyph {
        switch noteValue {
        case .whole:
            .noteheadWhole
        case .half:
            .noteheadHalf
        case .quarter, .eighth, .sixteenth, .thirtySecond, .other:
            .noteheadBlack
        }
    }

    static func accidental(for value: String) -> SMuFLGlyph? {
        switch value {
        case "sharp":
            .accidentalSharp
        case "flat":
            .accidentalFlat
        case "natural":
            .accidentalNatural
        case "double-sharp":
            .accidentalDoubleSharp
        case "flat-flat":
            .accidentalDoubleFlat
        default:
            nil
        }
    }
}
