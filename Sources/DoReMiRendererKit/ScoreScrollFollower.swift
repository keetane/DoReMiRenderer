import CoreGraphics

public struct ScoreScrollTarget: Hashable, Sendable {
    public let noteID: NoteID
    public let layoutFrame: CGRect
    public let targetContentOffset: CGPoint

    public init(noteID: NoteID, layoutFrame: CGRect, targetContentOffset: CGPoint) {
        self.noteID = noteID
        self.layoutFrame = layoutFrame
        self.targetContentOffset = targetContentOffset
    }
}

public struct ScoreScrollFollower: Sendable {
    public let margin: CGFloat

    public init(margin: CGFloat = 48) {
        self.margin = max(0, margin)
    }

    /// Returns a target content offset that brings `noteID` near the viewport center.
    ///
    /// The returned offset is measured in scaled content coordinates. If the note frame
    /// is already fully visible inside the viewport after applying `margin`, this method
    /// returns `nil`. Otherwise, the note center is moved toward the viewport center and
    /// the target offset is clamped to the scrollable content bounds.
    public func target(
        for noteID: NoteID,
        in layout: ScoreLayout,
        transform: ScoreViewportTransform
    ) -> ScoreScrollTarget? {
        guard transform.viewportSize.width > 0, transform.viewportSize.height > 0,
              let noteLayout = layout.noteByID[noteID] else {
            return nil
        }

        let scaledFrame = noteLayout.noteheadFrame.scaled(by: transform.scale)
        let viewportFrame = CGRect(origin: transform.contentOffset, size: transform.viewportSize)
        if viewportFrame.insetBy(dx: margin, dy: margin).contains(scaledFrame) {
            return nil
        }

        let maxOffset = CGPoint(
            x: max(0, transform.scaledContentSize.width - transform.viewportSize.width),
            y: max(0, transform.scaledContentSize.height - transform.viewportSize.height)
        )
        let centeredOffset = CGPoint(
            x: scaledFrame.midX - transform.viewportSize.width / 2,
            y: scaledFrame.midY - transform.viewportSize.height / 2
        )

        return ScoreScrollTarget(
            noteID: noteID,
            layoutFrame: noteLayout.noteheadFrame,
            targetContentOffset: CGPoint(
                x: centeredOffset.x.clamped(to: 0...maxOffset.x),
                y: centeredOffset.y.clamped(to: 0...maxOffset.y)
            )
        )
    }
}

private extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(
            x: origin.x * scale,
            y: origin.y * scale,
            width: size.width * scale,
            height: size.height * scale
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
