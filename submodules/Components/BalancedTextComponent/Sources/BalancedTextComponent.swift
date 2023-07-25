import Foundation
import UIKit
import ComponentFlow
import Display
import Markdown

public final class BalancedTextComponent: Component {
    public enum TextContent: Equatable {
        case plain(NSAttributedString)
        case markdown(text: String, attributes: MarkdownAttributes)
    }
    
    public let text: TextContent
    public let balanced: Bool
    public let horizontalAlignment: NSTextAlignment
    public let verticalAlignment: TextVerticalAlignment
    public let truncationType: CTLineTruncationType
    public let maximumNumberOfLines: Int
    public let lineSpacing: CGFloat
    public let cutout: TextNodeCutout?
    public let insets: UIEdgeInsets
    public let textShadowColor: UIColor?
    public let textShadowBlur: CGFloat?
    public let textStroke: (UIColor, CGFloat)?
    public let highlightColor: UIColor?
    public let highlightAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)?
    public let tapAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    public let longTapAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    
    public init(
        text: TextContent,
        balanced: Bool = true,
        horizontalAlignment: NSTextAlignment = .natural,
        verticalAlignment: TextVerticalAlignment = .top,
        truncationType: CTLineTruncationType = .end,
        maximumNumberOfLines: Int = 1,
        lineSpacing: CGFloat = 0.0,
        cutout: TextNodeCutout? = nil,
        insets: UIEdgeInsets = UIEdgeInsets(),
        textShadowColor: UIColor? = nil,
        textShadowBlur: CGFloat? = nil,
        textStroke: (UIColor, CGFloat)? = nil,
        highlightColor: UIColor? = nil,
        highlightAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)? = nil,
        tapAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil,
        longTapAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil
    ) {
        self.text = text
        self.balanced = balanced
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.truncationType = truncationType
        self.maximumNumberOfLines = maximumNumberOfLines
        self.lineSpacing = lineSpacing
        self.cutout = cutout
        self.insets = insets
        self.textShadowColor = textShadowColor
        self.textShadowBlur = textShadowBlur
        self.textStroke = textStroke
        self.highlightColor = highlightColor
        self.highlightAction = highlightAction
        self.tapAction = tapAction
        self.longTapAction = longTapAction
    }
    
    public static func ==(lhs: BalancedTextComponent, rhs: BalancedTextComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.balanced != rhs.balanced {
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
        if lhs.textShadowBlur != rhs.textShadowBlur {
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
        
        if let lhsHighlightColor = lhs.highlightColor, let rhsHighlightColor = rhs.highlightColor {
            if !lhsHighlightColor.isEqual(rhsHighlightColor) {
                return false
            }
        } else if (lhs.highlightColor != nil) != (rhs.highlightColor != nil) {
            return false
        }
        
        return true
    }
    
    public final class View: UIView {
        private let textView: ImmediateTextView
        
        override public init(frame: CGRect) {
            self.textView = ImmediateTextView()
            
            super.init(frame: frame)
            
            self.addSubview(self.textView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func attributeSubstring(name: String, index: Int) -> (String, String)? {
            return self.textView.attributeSubstring(name: name, index: index)
        }
        
        public func update(component: BalancedTextComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let attributedString: NSAttributedString
            switch component.text {
            case let .plain(string):
                attributedString = string
            case let .markdown(text, attributes):
                attributedString = parseMarkdownIntoAttributedString(text, attributes: attributes)
            }
            
            self.textView.attributedText = attributedString
            self.textView.maximumNumberOfLines = component.maximumNumberOfLines
            self.textView.truncationType = component.truncationType
            self.textView.textAlignment = component.horizontalAlignment
            self.textView.verticalAlignment = component.verticalAlignment
            self.textView.lineSpacing = component.lineSpacing
            self.textView.cutout = component.cutout
            self.textView.insets = component.insets
            self.textView.textShadowColor = component.textShadowColor
            self.textView.textShadowBlur = component.textShadowBlur
            self.textView.textStroke = component.textStroke
            self.textView.linkHighlightColor = component.highlightColor
            self.textView.highlightAttributeAction = component.highlightAction
            self.textView.tapAttributeAction = component.tapAction
            self.textView.longTapAttributeAction = component.longTapAction
            
            var bestSize: (availableWidth: CGFloat, info: TextNodeLayout)
            
            let info = self.textView.updateLayoutFullInfo(availableSize)
            bestSize = (availableSize.width, info)
            
            if component.balanced && info.numberOfLines > 1 {
                let measureIncrement = 8.0
                var measureWidth = info.size.width
                measureWidth -= measureIncrement
                while measureWidth > 0.0 {
                    let otherInfo = self.textView.updateLayoutFullInfo(CGSize(width: measureWidth, height: availableSize.height))
                    if otherInfo.numberOfLines > bestSize.info.numberOfLines {
                        break
                    }
                    if (otherInfo.size.width - otherInfo.trailingLineWidth) < (bestSize.info.size.width - bestSize.info.trailingLineWidth) {
                        bestSize = (measureWidth, otherInfo)
                    }
                    
                    measureWidth -= measureIncrement
                }
                
                let bestInfo = self.textView.updateLayoutFullInfo(CGSize(width: bestSize.availableWidth, height: availableSize.height))
                bestSize = (availableSize.width, bestInfo)
            }
            
            self.textView.frame = CGRect(origin: CGPoint(), size: bestSize.info.size)
            return bestSize.info.size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
