import Foundation
import LegacyComponents

public final class LegacyCache {
    private let impl: TGCache
    
    public init(path: String) {
        self.impl = TGCache(cachesPath: path)
    }
    
    public func path(forCachedData id: String) -> String? {
        return self.impl.path(forCachedData: id)
    }
}
