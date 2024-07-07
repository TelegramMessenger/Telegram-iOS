import Foundation
import Postbox
import TelegramCore

public enum WebsiteType {
    case generic
    case twitter
    case instagram
}

public func websiteType(of websiteName: String?) -> WebsiteType {
    if let websiteName = websiteName?.lowercased() {
        if websiteName == "twitter" {
            return .twitter
        } else if websiteName == "instagram" {
            return .instagram
        }
    }
    return .generic
}

public enum InstantPageType {
    case generic
    case album
}

public func instantPageType(of webpage: TelegramMediaWebpageLoadedContent) -> InstantPageType {
    if let type = webpage.type, type == "telegram_album" {
        return .album
    }
    
    switch websiteType(of: webpage.websiteName) {
        case .instagram, .twitter:
            return .album
        default:
            return .generic
    }
}

public func defaultWebpageImageSizeIsSmall(webpage: TelegramMediaWebpageLoadedContent) -> Bool {
    let type = websiteType(of: webpage.websiteName)
    
    let mainMedia: Media?
    switch type {
    case .instagram, .twitter:
        mainMedia = webpage.story ?? webpage.image ?? webpage.file
    default:
        mainMedia = webpage.story ?? webpage.file ?? webpage.image
    }
    
    if let image = mainMedia as? TelegramMediaImage {
        if let type = webpage.type, (["photo", "video", "embed", "gif", "document", "telegram_album"] as [String]).contains(type) {
        } else if let type = webpage.type, (["article"] as [String]).contains(type) {
            return true
        } else if let _ = largestImageRepresentation(image.representations)?.dimensions {
            if webpage.instantPage == nil {
                return true
            }
        }
    }
    
    return false
}

