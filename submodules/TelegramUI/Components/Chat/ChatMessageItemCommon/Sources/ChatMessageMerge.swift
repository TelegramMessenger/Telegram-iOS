import Foundation

public enum ChatMessageMerge: Int32 {
    case none = 0
    case fullyMerged = 1
    case semanticallyMerged = 2

    public var merged: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
}
