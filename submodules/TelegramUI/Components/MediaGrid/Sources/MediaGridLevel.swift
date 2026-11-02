import Foundation
import CoreGraphics

public enum MediaGridLevel: Int, CaseIterable, Comparable {
    case one = 1
    case three = 3
    case five = 5
    case fifteen = 15
    case thirtyOne = 31

    public var columns: Int {
        return self.rawValue
    }

    public var isInteractive: Bool {
        switch self {
        case .one, .three, .five:
            return true
        case .fifteen, .thirtyOne:
            return false
        }
    }

    public var showsCamera: Bool {
        return self == .three
    }

    private var index: Int {
        return MediaGridLevel.allCases.firstIndex(of: self)!
    }

    public var zoomedIn: MediaGridLevel? {
        let index = self.index
        return index > 0 ? MediaGridLevel.allCases[index - 1] : nil
    }

    public var zoomedOut: MediaGridLevel? {
        let index = self.index
        return index + 1 < MediaGridLevel.allCases.count ? MediaGridLevel.allCases[index + 1] : nil
    }

    public func zoomedIn(within levels: [MediaGridLevel]) -> MediaGridLevel? {
        return levels.filter { $0 < self }.max()
    }

    public func zoomedOut(within levels: [MediaGridLevel]) -> MediaGridLevel? {
        return levels.filter { $0 > self }.min()
    }

    public func nearest(within levels: [MediaGridLevel]) -> MediaGridLevel {
        if levels.isEmpty || levels.contains(self) {
            return self
        }
        let position = log(CGFloat(self.columns))
        return levels.min(by: { abs(log(CGFloat($0.columns)) - position) < abs(log(CGFloat($1.columns)) - position) }) ?? self
    }

    public func rotated(toLandscape: Bool, within levels: [MediaGridLevel]) -> MediaGridLevel {
        return (toLandscape ? self.zoomedOut(within: levels) : self.zoomedIn(within: levels)) ?? self
    }

    public static func defaultLevel(isLandscape: Bool) -> MediaGridLevel {
        return isLandscape ? .five : .three
    }

    public func rotated(toLandscape: Bool) -> MediaGridLevel {
        return (toLandscape ? self.zoomedOut : self.zoomedIn) ?? self
    }

    public static func < (lhs: MediaGridLevel, rhs: MediaGridLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
