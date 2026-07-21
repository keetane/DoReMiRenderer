import Foundation

public struct RendererConfiguration: Hashable, Codable, Sendable {
    public var unsupportedFeaturePolicy: UnsupportedFeaturePolicy

    public init(unsupportedFeaturePolicy: UnsupportedFeaturePolicy = .ignoreWithWarning) {
        self.unsupportedFeaturePolicy = unsupportedFeaturePolicy
    }

    public static let `default` = RendererConfiguration()
}

public struct DoReMiRenderer: Sendable {
    public let configuration: RendererConfiguration

    public init(configuration: RendererConfiguration = .default) {
        self.configuration = configuration
    }

    public func parseMusicXML(data: Data) throws -> ScoreDocument {
        try parseMusicXMLWithDiagnostics(data: data).score
    }

    public func parseMusicXMLWithDiagnostics(data: Data) throws -> ParseResult {
        try MusicXMLParser(unsupportedFeaturePolicy: configuration.unsupportedFeaturePolicy).parse(data: data)
    }

    public func parseMXL(data: Data) throws -> ScoreDocument {
        try parseMXLWithDiagnostics(data: data).score
    }

    public func parseMXLWithDiagnostics(data: Data) throws -> ParseResult {
        let musicXMLData = try MXLLoader().loadMusicXMLData(from: data)
        return try parseMusicXMLWithDiagnostics(data: musicXMLData)
    }

    public func parse(input: ScoreInput) throws -> ScoreDocument {
        try parseWithDiagnostics(input: input).score
    }

    public func parseWithDiagnostics(input: ScoreInput) throws -> ParseResult {
        switch input {
        case .musicXMLData(let data):
            return try parseMusicXMLWithDiagnostics(data: data)
        case .mxlData(let data):
            return try parseMXLWithDiagnostics(data: data)
        }
    }

    public func layout(score: ScoreDocument, options: LayoutOptions = .default) throws -> ScoreLayout {
        try ScoreLayoutEngine().layout(score: score, options: options)
    }

    public func layoutWithDiagnostics(score: ScoreDocument, options: LayoutOptions = .default) throws -> ScoreLayoutResult {
        try ScoreLayoutEngine().layoutWithDiagnostics(score: score, options: options)
    }

    public func makePlaybackSequence(
        score: ScoreDocument,
        options: PlaybackOptions = .default
    ) -> [PlaybackEvent] {
        PlaybackSequenceBuilder().build(score: score, options: options)
    }

    public func makePlaybackMetadata(score: ScoreDocument) -> PlaybackMetadata {
        PlaybackSequenceBuilder().metadata(score: score)
    }

    /// Produces a platform-neutral Canvas command stream for a browser client.
    ///
    /// The result is JSON-encodable and retains the coordinates and stable note
    /// identities calculated by `ScoreLayout`. Web clients must render this
    /// plan directly instead of re-parsing MusicXML or recomputing positions.
    public func makeWebRenderPlan(
        score: ScoreDocument,
        layout: ScoreLayout,
        style: ScoreStyle = ScoreStyle(),
        selection: ScoreSelection? = nil,
        currentNoteIDs: Set<NoteID> = [],
        continuationNoteIDs: Set<NoteID> = []
    ) -> ScoreWebRenderPlan {
        let playbackEvents = ScoreWebPlaybackTimelineBuilder().build(score: score)
        return ScoreWebRenderPlanBuilder().build(
            score: score,
            layout: layout,
            style: style,
            selection: selection,
            currentNoteIDs: currentNoteIDs,
            continuationNoteIDs: continuationNoteIDs,
            playbackEvents: playbackEvents
        )
    }

    /// Produces the browser transport used by DoReMi Palette Web. Every display
    /// transpose option is laid out by the SDK; the browser only selects one of
    /// these plans and never changes score coordinates itself.
    public func makeWebRenderBundle(
        score: ScoreDocument,
        containerWidth: Double,
        // One chromatic octave, with the written key near the centre. Keeping
        // a single representative per pitch class avoids duplicate octave
        // choices such as a second C one octave below the source score.
        displayTransposeRange: ClosedRange<Int> = -6...5,
        style: ScoreStyle = ScoreStyle()
    ) throws -> ScoreWebRenderBundle {
        let clampedLower = max(-12, displayTransposeRange.lowerBound)
        let clampedUpper = min(12, displayTransposeRange.upperBound)
        let transposeValues = clampedLower <= clampedUpper ? Array(clampedLower...clampedUpper) : [0]
        let playbackEvents = ScoreWebPlaybackTimelineBuilder().build(score: score)
        var webStyle = style
        webStyle.measureNumberDisplayMode = .systemLeading

        func plan(for semitones: Int, includesPlayback: Bool) throws -> ScoreWebRenderPlan {
            var options = webLayoutOptions(containerWidth: containerWidth)
            options.displayTransposeSemitones = semitones
            let layout = try self.layout(score: score, options: options)
            return ScoreWebRenderPlanBuilder().build(
                score: score,
                layout: layout,
                style: webStyle,
                selection: nil,
                currentNoteIDs: [],
                continuationNoteIDs: [],
                playbackEvents: includesPlayback ? playbackEvents : nil
            )
        }

        let primaryPlan = try plan(for: 0, includesPlayback: true)
        let variants = try transposeValues
            .filter { $0 != 0 }
            .map { ScoreWebTransposeVariant(semitones: $0, plan: try plan(for: $0, includesPlayback: false)) }
        return ScoreWebRenderBundle(primaryPlan: primaryPlan, transposeVariants: variants)
    }

    /// Returns the standard responsive reading layout used by the Web Canvas bridge.
    public func webLayoutOptions(containerWidth: Double) -> LayoutOptions {
        ScoreWebLayoutProfile.responsive.layoutOptions(containerWidth: containerWidth)
    }
}
