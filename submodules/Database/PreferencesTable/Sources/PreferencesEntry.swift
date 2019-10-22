import Foundation
import PostboxCoding
import PostboxDataTypes

public protocol PreferencesEntry: PostboxCoding {
    var relatedResources: [MediaResourceId] { get }
    
    func isEqual(to: PreferencesEntry) -> Bool
}

public extension PreferencesEntry {
    var relatedResources: [MediaResourceId] {
        return []
    }
}
