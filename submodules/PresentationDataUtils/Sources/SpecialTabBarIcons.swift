import Foundation

public func useSpecialTabBarIcons() -> Bool {
    return (Date(timeIntervalSince1970: 1608800400)...Date(timeIntervalSince1970: 1609545600)).contains(Date())
}
