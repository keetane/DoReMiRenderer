import Foundation

enum PalettePlaybackState: String, Equatable {
    case stopped
    case playing
    case paused

    var displayText: String {
        switch self {
        case .stopped:
            return "停止中"
        case .playing:
            return "再生中"
        case .paused:
            return "一時停止"
        }
    }
}
