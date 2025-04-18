import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import UrlEscaping

public struct ExternalMusicAlbumArtResourceId {
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public init(title: String, performer: String, isThumbnail: Bool) {
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    public var uniqueId: String {
        return "ext-album-art-\(isThumbnail ? "thump" : "full")-\(self.title.replacingOccurrences(of: "/", with: "_"))-\(self.performer.replacingOccurrences(of: "/", with: "_"))"
    }
    
    public var hashValue: Int {
        return self.title.hashValue &* 31 &+ self.performer.hashValue
    }
}

public class ExternalMusicAlbumArtResource: Equatable {
    public let file: FileMediaReference?
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public init(file: FileMediaReference?, title: String, performer: String, isThumbnail: Bool) {
        self.file = file
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    public var id: EngineMediaResource.Id {
        return EngineMediaResource.Id(ExternalMusicAlbumArtResourceId(title: self.title, performer: self.performer, isThumbnail: self.isThumbnail).uniqueId)
    }

    public static func ==(lhs: ExternalMusicAlbumArtResource, rhs: ExternalMusicAlbumArtResource) -> Bool {
        if lhs.file?.media.fileId != rhs.file?.media.fileId {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.performer != rhs.performer {
            return false
        }
        if lhs.isThumbnail != rhs.isThumbnail {
            return false
        }
        return true
    }
}

public func fetchExternalMusicAlbumArtResource(engine: TelegramEngine, file: FileMediaReference?, resource: ExternalMusicAlbumArtResource) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
    return engine.resources.fetchAlbumCover(file: file, title: resource.title, performer: resource.performer, isThumbnail: resource.isThumbnail)
}
