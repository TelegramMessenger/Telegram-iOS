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
    
    /*return Signal { subscriber in
        if resource.performer.isEmpty || resource.performer.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "unknown artist" || resource.title.isEmpty {
            subscriber.putError(.generic)
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
            
            let title = resource.title.lowercased()
            let isMix = title.contains("remix") || title.contains("mixed")
            
            let fetchDisposable = MetaDisposable()
            
            let disposable = fetchHttpResource(url: metaUrl).start(next: { result in
                if case let .dataPart(_, data, _, complete) = result, complete {
                    guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                        subscriber.putError(.generic)
                        return
                    }
                    
                    guard let results = dict["results"] as? [Any] else {
                        subscriber.putError(.generic)
                        return
                    }
                    
                    var matchingResult: Any?
                    for result in results {
                        if let result = result as? [String: Any] {
                            let title = ((result["trackCensoredName"] as? String) ?? (result["trackName"] as? String))?.lowercased() ?? ""
                            let resultIsMix = title.contains("remix") || title.contains("mixed")
                            if isMix == resultIsMix {
                                matchingResult = result
                                break
                            }
                        }
                    }
                    
                    if matchingResult == nil {
                        matchingResult = results.first
                    }
                    
                    guard let result = matchingResult as? [String: Any] else {
                        subscriber.putError(.generic)
                        return
                    }
                    
                    guard var artworkUrl = result["artworkUrl100"] as? String else {
                        subscriber.putError(.generic)
                        return
                    }
                    
                    if !resource.isThumbnail {
                        artworkUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                    }
                    
                    if artworkUrl.isEmpty {
                        subscriber.putError(.generic)
                        return
                    } else {
                        fetchDisposable.set(engine.resources.httpData(url: artworkUrl).start(next: { next in
                            let file = EngineTempBox.shared.tempFile(fileName: "image.jpg")
                            let _ = try? next.write(to: URL(fileURLWithPath: file.path))
                            subscriber.putNext(.moveTempFile(file: file))
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
    }*/
}
