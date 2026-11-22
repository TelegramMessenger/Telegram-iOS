import Foundation
import CoreGraphics

enum QrStudioPresentation {
    static let openDuration: Double = 0.4
    static let closeDuration: Double = 0.3

    static func offset(translation: CGFloat) -> CGFloat {
        if translation >= 0.0 {
            return translation
        }
        return -(-translation).squareRoot() * 3.0
    }

    static func shouldDismiss(offset: CGFloat, velocity: CGFloat, height: CGFloat) -> Bool {
        if velocity < -100.0 {
            return false
        }
        if offset > min(120.0, height * 0.18) {
            return true
        }
        return velocity > 600.0 && offset > 10.0
    }
}
