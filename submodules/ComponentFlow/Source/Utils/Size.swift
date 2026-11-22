import Foundation
import UIKit

public extension CGSize {
    func centered(in rect: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: rect.minX + floor((rect.width - self.width) / 2.0), y: rect.minY + floor((rect.height - self.height) / 2.0)), size: self)
    }

    func centered(around position: CGPoint) -> CGRect {
        return CGRect(origin: CGPoint(x: position.x - self.width / 2.0, y: position.y - self.height / 2.0), size: self)
    }

    func leftCentered(in rect: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: rect.minX, y: rect.minY + floor((rect.height - self.height) / 2.0)), size: self)
    }

    func rightCentered(in rect: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: rect.maxX - self.width, y: rect.minY + floor((rect.height - self.height) / 2.0)), size: self)
    }

    func topCentered(in rect: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: rect.minX + floor((rect.width - self.width) / 2.0), y: 0.0), size: self)
    }

    func bottomCentered(in rect: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: rect.minX + floor((rect.width - self.width) / 2.0), y: rect.maxY - self.height), size: self)
    }
}
