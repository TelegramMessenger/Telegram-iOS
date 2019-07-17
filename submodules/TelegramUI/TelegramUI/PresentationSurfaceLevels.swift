import Foundation
import Display

public extension PresentationSurfaceLevel {
    static let root = PresentationSurfaceLevel(rawValue: 0)
    static let calls = PresentationSurfaceLevel(rawValue: 1)
    static let overlayMedia = PresentationSurfaceLevel(rawValue: 2)
    static let notifications = PresentationSurfaceLevel(rawValue: 3)
    static let passcode = PresentationSurfaceLevel(rawValue: 4)
    static let update = PresentationSurfaceLevel(rawValue: 5)
}
