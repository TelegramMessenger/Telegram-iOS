import Foundation
import UIKit
import ComponentFlow
import Display

public final class MultilineTextComponent: Component {
    public let text: NSAttributedString
    public let horizontalAlignment: NSTextAlignment
    public let verticalAlignment: TextVerticalAlignment
    public var truncationType: CTLineTruncationType
    public var maximumNumberOfLines: Int
    public var lineSpacing: CGFloat
    public var cutout: TextNodeCutout?
    public var insets: UIEdgeInsets
    public var textShadowColor: UIColor?
    public var textStroke: (UIColor, CGFloat)?
    
    public init(
        text: NSAttributedString,
        horizontalAlignment: NSTextAlignment = .natural,
        verticalAlignment: TextVerticalAlignment = .top,
        truncationType: CTLineTruncationType = .end,
        maximumNumberOfLines: Int = 1,
        lineSpacing: CGFloat = 0.0,
        cutout: TextNodeCutout? = nil,
        insets: UIEdgeInsets = UIEdgeInsets(),
        textShadowColor: UIColor? = nil,
        textStroke: (UIColor, CGFloat)? = nil
    ) {
        self.text = text
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.truncationType = truncationType
        self.maximumNumberOfLines = maximumNumberOfLines
        self.lineSpacing = lineSpacing
        self.cutout = cutout
        self.insets = insets
        self.textShadowColor = textShadowColor
        self.textStroke = textStroke
    }
    
    public static func ==(lhs: MultilineTextComponent, rhs: MultilineTextComponent) -> Bool {
        if !lhs.text.isEqual(to: rhs.text) {
            return false
        }
        if lhs.horizontalAlignment != rhs.horizontalAlignment {
            return false
        }
        if lhs.verticalAlignment != rhs.verticalAlignment {
            return false
        }
        if lhs.truncationType != rhs.truncationType {
            return false
        }
        if lhs.maximumNumberOfLines != rhs.maximumNumberOfLines {
            return false
        }
        if lhs.lineSpacing != rhs.lineSpacing {
            return false
        }
        if lhs.cutout != rhs.cutout {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        
        if let lhsTextShadowColor = lhs.textShadowColor, let rhsTextShadowColor = rhs.textShadowColor {
            if !lhsTextShadowColor.isEqual(rhsTextShadowColor) {
                return false
            }
        } else if (lhs.textShadowColor != nil) != (rhs.textShadowColor != nil) {
            return false
        }
        
        if let lhsTextStroke = lhs.textStroke, let rhsTextStroke = rhs.textStroke {
            if !lhsTextStroke.0.isEqual(rhsTextStroke.0) {
                return false
            }
            if lhsTextStroke.1 != rhsTextStroke.1 {
                return false
            }
        } else if (lhs.textShadowColor != nil) != (rhs.textShadowColor != nil) {
            return false
        }
        
        return true
    }
    
    public final class View: TextView {
        public func update(component: MultilineTextComponent, availableSize: CGSize) -> CGSize {
            let makeLayout = TextView.asyncLayout(self)
            let (layout, apply) = makeLayout(TextNodeLayoutArguments(
                attributedString: component.text,
                backgroundColor: nil,
                maximumNumberOfLines: component.maximumNumberOfLines,
                truncationType: component.truncationType,
                constrainedSize: availableSize,
                alignment: component.horizontalAlignment,
                verticalAlignment: component.verticalAlignment,
                lineSpacing: component.lineSpacing,
                cutout: component.cutout,
                insets: component.insets,
                textShadowColor: component.textShadowColor,
                textStroke: component.textStroke,
                displaySpoilers: false
            ))
            let _ = apply()
            
            return layout.size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}
