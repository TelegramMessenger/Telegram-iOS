import Foundation
import UIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import UrlEscaping

public struct ExternalMusicAlbumArtResourceId: MediaResourceId {
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
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? ExternalMusicAlbumArtResourceId {
            return self.title == to.title && self.performer == to.performer && self.isThumbnail == to.isThumbnail
        } else {
            return false
        }
    }
}

public class ExternalMusicAlbumArtResource: TelegramMediaResource {
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public init(title: String, performer: String, isThumbnail: Bool) {
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    public required init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.performer = decoder.decodeStringForKey("p", orElse: "")
        self.isThumbnail = decoder.decodeInt32ForKey("th", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.performer, forKey: "p")
        encoder.encodeInt32(self.isThumbnail ? 1 : 0, forKey: "th")
    }
    
    public var id: MediaResourceId {
        return ExternalMusicAlbumArtResourceId(title: self.title, performer: self.performer, isThumbnail: self.isThumbnail)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? ExternalMusicAlbumArtResource {
            return self.title == to.title && self.performer == to.performer && self.isThumbnail == to.isThumbnail
        } else {
            return false
        }
    }
}

public func fetchExternalMusicAlbumArtResource(account: Account, resource: ExternalMusicAlbumArtResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        if resource.performer.isEmpty || resource.performer.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "unknown artist" || resource.title.isEmpty {
            subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
            subscriber.putCompletion()
            return EmptyDisposable
        } else {
            let excludeWords: [String] = [
                " vs. ",
                " vs ",
                " versus ",
                " ft. ",
                " ft ",
                " featuring ",
                " feat. ",
                " feat ",
                " presents ",
                " pres. ",
                " pres ",
                " and ",
                " & ",
                " . "
            ]
            
            var performer = resource.performer
            
            for word in excludeWords {
                performer = performer.replacingOccurrences(of: word, with: " ")
            }
            
            let metaUrl = "https://itunes.apple.com/search?term=\(urlEncodedStringFromString("\(performer) \(resource.title)"))&entity=song&limit=4"
            
            let fetchDisposable = MetaDisposable()
            
            let disposable = fetchHttpResource(url: metaUrl).start(next: { result in
                if case let .dataPart(_, data, _, complete) = result, complete {
                    guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    }
                    
                    guard let results = dict["results"] as? [Any] else {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    }
                    
                    guard let result = results.first as? [String: Any] else {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    }
                    
                    guard var artworkUrl = result["artworkUrl100"] as? String else {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    }
                    
                    if !resource.isThumbnail {
                        artworkUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                    }
                    
                    if artworkUrl.isEmpty {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        subscriber.putCompletion()
                        return
                    } else {
                        fetchDisposable.set(fetchHttpResource(url: artworkUrl).start(next: { next in
                            subscriber.putNext(next)
                        }, completed: {
                            subscriber.putCompletion()
                        }))
                    }
                }
            })
            
            return ActionDisposable {
                disposable.dispose()
                fetchDisposable.dispose()
            }
        }
    }
}
