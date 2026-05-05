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
}
