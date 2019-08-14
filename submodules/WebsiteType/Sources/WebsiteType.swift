import Foundation

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
