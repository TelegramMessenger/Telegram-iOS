import Foundation

public protocol PreferencesEntry: Coding {
    func isEqual(to: PreferencesEntry) -> Bool
}
