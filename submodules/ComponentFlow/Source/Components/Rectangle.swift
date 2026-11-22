import Foundation
import UIKit

public final class Rectangle: Component {
    private let color: UIColor
    private let width: CGFloat?
    private let height: CGFloat?
    private let tag: NSObject?
    
    public init(color: UIColor, width: CGFloat? = nil, height: CGFloat? = nil, tag: NSObject? = nil) {
        self.color = color
        self.width = width
        self.height = height
        self.tag = tag
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
    
    public final class View: UIView, ComponentTaggedView {
        fileprivate var componentTag: NSObject?
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func matches(tag: Any) -> Bool {
            if let componentTag = self.componentTag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        var size = availableSize
        if let width = self.width {
            size.width = min(size.width, width)
        }
        if let height = self.height {
            size.height = min(size.height, height)
        }

        view.backgroundColor = self.color
        view.componentTag = self.tag

        return size
    }
}
