import Postbox

public enum MediaResourceStatsCategory {
    case generic
    case image
    case video
    case audio
    case file
    case call
}

final class TelegramMediaResourceFetchTag: MediaResourceFetchTag {
    public let statsCategory: MediaResourceStatsCategory
    
    public init(statsCategory: MediaResourceStatsCategory) {
        self.statsCategory = statsCategory
    }
}
