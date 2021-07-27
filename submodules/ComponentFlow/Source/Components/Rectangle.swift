import Foundation
import UIKit

public final class Rectangle: Component {
    private let color: UIColor
    private let width: CGFloat?
    private let height: CGFloat?
    
    public init(color: UIColor, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.color = color
        self.width = width
        self.height = height
    }

    public static func ==(lhs: Rectangle, rhs: Rectangle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.width != rhs.width {
            return false
        }
        if lhs.height != rhs.height {
            return false
        }
        return true
    }
    
    public func update(view: UIView, availableSize: CGSize, transition: Transition) -> CGSize {
        var size = availableSize
        if let width = self.width {
            size.width = min(size.width, width)
        }
        if let height = self.height {
            size.height = min(size.height, height)
        }

        view.backgroundColor = self.color

        return size
    }
}
