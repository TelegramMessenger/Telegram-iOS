import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

public struct LocalBundleResourceId: MediaResourceId {
    public let name: String
    public let ext: String
    
    public var uniqueId: String {
        return "local-bundle-\(self.name)-\(self.ext)"
    }
    
    public var hashValue: Int {
        return self.name.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalBundleResourceId {
            return self.name == to.name && self.ext == to.ext
        } else {
            return false
        }
    }
}

public class LocalBundleResource: TelegramMediaResource {
    public let name: String
    public let ext: String
    
    public init(name: String, ext: String) {
        self.name = name
        self.ext = ext
    }
    
    public required init(decoder: PostboxDecoder) {
        self.name = decoder.decodeStringForKey("n", orElse: "")
        self.ext = decoder.decodeStringForKey("e", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.name, forKey: "n")
        encoder.encodeString(self.ext, forKey: "e")
    }
    
    public var id: MediaResourceId {
        return LocalBundleResourceId(name: self.name, ext: self.ext)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalBundleResource {
            return self.name == to.name && self.ext == to.ext
        } else {
            return false
        }
    }
}

private final class LocalBundleResourceCopyFile : MediaResourceDataFetchCopyLocalItem {
    let path: String
    init(path: String) {
        self.path = path
    }
    func copyTo(url: URL) -> Bool {
        do {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: self.path), to: url)
            return true
        } catch {
            return false
        }
    }
}

func fetchLocalBundleResource(postbox: Postbox, resource: LocalBundleResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        if let path = frameworkBundle.path(forResource: resource.name, ofType: resource.ext), let _ = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
            subscriber.putNext(.copyLocalItem(LocalBundleResourceCopyFile(path: path)))
            subscriber.putCompletion()
        }
        return EmptyDisposable
    }
}
