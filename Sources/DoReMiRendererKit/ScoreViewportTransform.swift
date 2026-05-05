import CoreGraphics

public struct ScoreViewportTransform: Hashable, Sendable {
    public var scale: CGFloat
    public var contentOffset: CGPoint
    public var viewportSize: CGSize
    public var contentSize: CGSize

    public init(
        scale: CGFloat = 1,
        contentOffset: CGPoint = .zero,
        viewportSize: CGSize = .zero,
        contentSize: CGSize = .zero
    ) {
        self.scale = max(scale, Self.minimumScale)
        self.contentOffset = contentOffset
        self.viewportSize = viewportSize
        self.contentSize = contentSize
    }

    /// Converts a point in viewport coordinates into the unscaled ScoreLayout coordinate space.
    ///
    /// The content offset is measured in scaled view-space points. For example,
    /// `point: (200, 100)`, `scale: 2`, and `contentOffset: (40, 20)` maps to
    /// layout point `(120, 60)`.
    public func layoutPoint(fromViewPoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x + contentOffset.x) / scale,
            y: (point.y + contentOffset.y) / scale
        )
    }

    public func viewPoint(fromLayoutPoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * scale - contentOffset.x,
            y: point.y * scale - contentOffset.y
        )
    }

    public var scaledContentSize: CGSize {
        CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
    }

    public static let minimumScale: CGFloat = 0.01
}

