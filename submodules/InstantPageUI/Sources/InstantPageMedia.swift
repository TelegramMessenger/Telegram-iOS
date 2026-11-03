import Foundation
import TelegramCore

public struct InstantPageMedia: Equatable {
    public let index: Int
    public let media: EngineMedia
    public let url: InstantPageUrlItem?
    public let caption: RichText?
    public let credit: RichText?
    
    public init(index: Int, media: EngineMedia, url: InstantPageUrlItem?, caption: RichText?, credit: RichText?) {
        self.index = index
        self.media = media
        self.url = url
        self.caption = caption
        self.credit = credit
    }
    
    public static func ==(lhs: InstantPageMedia, rhs: InstantPageMedia) -> Bool {
        return lhs.index == rhs.index && lhs.media == rhs.media && lhs.url == rhs.url && lhs.caption == rhs.caption && lhs.credit == rhs.credit
    }
}

func instantPageMediaMatchesNodeIdentity(_ lhs: InstantPageMedia, _ rhs: InstantPageMedia) -> Bool {
    if lhs.index != rhs.index {
        return false
    }
    if lhs.url != rhs.url || lhs.caption != rhs.caption || lhs.credit != rhs.credit {
        return false
    }
    if let lhsId = lhs.media.id, let rhsId = rhs.media.id {
        return lhsId == rhsId
    }
    return lhs == rhs
}

func instantPageMediaArraysMatchNodeIdentity(_ lhs: [InstantPageMedia], _ rhs: [InstantPageMedia]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if !instantPageMediaMatchesNodeIdentity(lhs[i], rhs[i]) {
            return false
        }
    }
    return true
}
