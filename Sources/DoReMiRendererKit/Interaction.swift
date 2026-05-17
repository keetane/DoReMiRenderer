import CoreGraphics

public struct HitTestResult: Sendable {
    public let point: CGPoint
    public let elements: [ElementLayout]
    public let nearestNoteID: NoteID?

    init(point: CGPoint, elements: [ElementLayout], nearestNoteID: NoteID?) {
        self.point = point
        self.elements = elements
        self.nearestNoteID = nearestNoteID
    }
}

/// Future extension point for richer interaction state.
///
/// MVP0 uses `ScoreCanvasView`'s `onTap` closure as the primary interaction API.
/// Full selection-state management, including `scoreDidSelect(noteID:)`, is reserved for MVP1 or later.
protocol ScoreInteractionHandler {
    func scoreDidTap(_ result: HitTestResult)
    func scoreDidSelect(noteID: NoteID)
}

public extension ScoreLayout {
    func hitTest(point: CGPoint, radius: CGFloat = 12) -> HitTestResult {
        let matchedElements = elements(at: point, radius: radius)
        return HitTestResult(
            point: point,
            elements: matchedElements,
            nearestNoteID: nearestNoteID(at: point, radius: radius, matchedElements: matchedElements)
        )
    }

    func elements(at point: CGPoint, radius: CGFloat) -> [ElementLayout] {
        let hitFrame = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        return elements
            .filter { element in
                element.frame.insetBy(dx: -radius, dy: -radius).contains(point)
                    || element.frame.intersects(hitFrame)
            }
            .sorted { lhs, rhs in
                let lhsPriority = hitTestPriority(lhs.kind)
                let rhsPriority = hitTestPriority(rhs.kind)
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                return distanceSquared(from: point, to: lhs.frame.center) < distanceSquared(from: point, to: rhs.frame.center)
            }
    }

    private func nearestNoteID(
        at point: CGPoint,
        radius: CGFloat,
        matchedElements: [ElementLayout]
    ) -> NoteID? {
        let radiusSquared = radius * radius
        let candidates = noteByID.values
            .filter { $0.pitch != nil }
            .map { noteLayout in
                (noteLayout.noteID, distanceSquared(from: point, to: noteLayout.noteheadCenter))
            }
            .filter { $0.1 <= radiusSquared }
            .sorted { $0.1 < $1.1 }

        if let nearest = candidates.first {
            return nearest.0
        }

        return matchedElements.first { element in
            switch element.kind {
            case .notehead, .accidental, .stem, .flag, .beam, .dot, .lyric, .fingering, .tie, .slur, .tuplet:
                return element.noteID != nil
            default:
                return false
            }
        }?.noteID
    }
}

private func hitTestPriority(_ kind: ScoreElementKind) -> Int {
    switch kind {
    case .notehead:
        return 1
    case .accidental:
        return 2
    case .rest:
        return 3
    case .stem:
        return 4
    case .flag, .beam:
        return 5
    case .tie, .slur, .tuplet:
        return 6
    case .dot:
        return 7
    case .lyric:
        return 8
    case .fingering:
        return 9
    case .staffLine:
        return 10
    case .barline, .repeatEnding, .measureRepeat, .playbackJumpMarker:
        return 11
    case .ledgerLine, .clef, .timeSignature, .keySignature:
        return 12
    }
}

private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
    let dx = lhs.x - rhs.x
    let dy = lhs.y - rhs.y
    return dx * dx + dy * dy
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
