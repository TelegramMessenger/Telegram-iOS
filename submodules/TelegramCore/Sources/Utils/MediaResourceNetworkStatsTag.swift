import Postbox

public enum MediaResourceStatsCategory {
    case generic
    case image
    case video
    case audio
    case file
    case call
    case stickers
    case voiceMessages
}

final class TelegramMediaResourceFetchTag: MediaResourceFetchTag {
    public let statsCategory: MediaResourceStatsCategory
    
    public init(statsCategory: MediaResourceStatsCategory, userContentType: MediaResourceUserContentType?) {
        switch userContentType {
        case .file:
            self.statsCategory = .file
        case .image:
            self.statsCategory = .image
        case .video:
            self.statsCategory = .video
        case .audio:
            self.statsCategory = .audio
        case .sticker:
            self.statsCategory = .stickers
        case .audioVideoMessage:
            self.statsCategory = .voiceMessages
        default:
            self.statsCategory = statsCategory
        }
    }
}
