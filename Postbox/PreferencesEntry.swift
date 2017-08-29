import Foundation

public protocol PreferencesEntry: PostboxCoding {
    func isEqual(to: PreferencesEntry) -> Bool
}
