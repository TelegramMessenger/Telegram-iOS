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
    public let tintColor: UIColor?
    public let textShadowColor: UIColor?
    public let textShadowBlur: CGFloat?
    public let textStroke: (UIColor, CGFloat)?
    public let highlightColor: UIColor?
    public let highlightInset: UIEdgeInsets
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
        tintColor: UIColor? = nil,
        textShadowColor: UIColor? = nil,
        textShadowBlur: CGFloat? = nil,
        textStroke: (UIColor, CGFloat)? = nil,
        highlightColor: UIColor? = nil,
        highlightInset: UIEdgeInsets = .zero,
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
        self.tintColor = tintColor
        self.textShadowColor = textShadowColor
        self.textShadowBlur = textShadowBlur
        self.textStroke = textStroke
        self.highlightColor = highlightColor
        self.highlightInset = highlightInset
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
        if lhs.tintColor != rhs.tintColor {
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
        
        if lhs.highlightInset != rhs.highlightInset {
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
        
        // VoiceOver: one static-text element reading the text shown (see MultilineTextComponent.View); a call site's
        // own settings win.
        private var explicitIsAccessibilityElement: Bool?
        private var explicitAccessibilityLabel: String??
        private var explicitAccessibilityTraits: UIAccessibilityTraits?
        
        override public var isAccessibilityElement: Bool {
            get {
                if let explicitIsAccessibilityElement = self.explicitIsAccessibilityElement {
                    return explicitIsAccessibilityElement
                }
                if self.isHidden || self.alpha < 0.01 {
                    return false
                }
                guard let label = self.accessibilityLabel, !label.isEmpty else {
                    return false
                }
                // Silent when an element drawn over it already speaks these words (a hand-labelled area beside it).
                return !accessibilityTextIsSpokenByCoveringElement(self, text: label)
            } set(value) {
                self.explicitIsAccessibilityElement = value
            }
        }
        
        override public var accessibilityLabel: String? {
            get {
                if let explicitAccessibilityLabel = self.explicitAccessibilityLabel {
                    return explicitAccessibilityLabel
                }
                if self.explicitIsAccessibilityElement == false {
                    // Turned off by the call site: nothing to announce from here either.
                    return nil
                }
                return self.textView.attributedText.flatMap { accessibilityDisplayedText($0) }
            } set(value) {
                self.explicitAccessibilityLabel = .some(value)
            }
        }
        
        override public var accessibilityTraits: UIAccessibilityTraits {
            get {
                if let explicitAccessibilityTraits = self.explicitAccessibilityTraits {
                    return explicitAccessibilityTraits
                }
                if self.explicitIsAccessibilityElement == false {
                    return []
                }
                // A link only when activating it does something (a tap handler is set). Inside the chat's history
                // subtree (see `accessibilityIsInsideViewElementsSubtree` for the boundary) the old result is kept.
                if self.textView.tapAttributeAction == nil || self.textView.accessibilityLinks().isEmpty || accessibilityIsInsideViewElementsSubtree(self) {
                    return .staticText
                }
                return [.staticText, .link]
            } set(value) {
                self.explicitAccessibilityTraits = value
            }
        }
        
        /// Activating a text with links follows its first link, as a tap on it does (the inner text view handles taps).
        override public func accessibilityActivate() -> Bool {
            if self.isAccessibilityElement, let tapAttributeAction = self.textView.tapAttributeAction, let link = self.textView.accessibilityLinks().first, !accessibilityIsInsideViewElementsSubtree(self) {
                tapAttributeAction(link.attributes, link.index)
                return true
            }
            return super.accessibilityActivate()
        }
        
        /// Several links: each one as a custom action named by its text. Built only when VoiceOver asks.
        override public var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
            get {
                if let explicit = super.accessibilityCustomActions, !explicit.isEmpty {
                    return explicit
                }
                guard self.textView.tapAttributeAction != nil, !accessibilityIsInsideViewElementsSubtree(self) else {
                    return nil
                }
                let links = self.textView.accessibilityLinks()
                if links.count < 2 {
                    return nil
                }
                return links.map { link in
                    return UIAccessibilityCustomAction(name: link.text, actionHandler: { [weak self] _ in
                        guard let self, let tapAttributeAction = self.textView.tapAttributeAction else {
                            return false
                        }
                        tapAttributeAction(link.attributes, link.index)
                        return true
                    })
                }
            } set(value) {
                super.accessibilityCustomActions = value
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func attributeSubstring(name: String, index: Int) -> (String, String)? {
            return self.textView.attributeSubstring(name: name, index: index)
        }
        
        public func update(component: BalancedTextComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
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
            self.textView.linkHighlightInset = component.highlightInset
            self.textView.highlightAttributeAction = component.highlightAction
            self.textView.tapAttributeAction = component.tapAction
            self.textView.longTapAttributeAction = component.longTapAction
            
            var bestSize: (availableWidth: CGFloat, info: TextNodeLayout)
            
            let info  = self.textView.updateLayoutFullInfo(availableSize)
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
            
            if let tintColor = component.tintColor {
                transition.setTintColor(layer: self.textView.layer, color: tintColor)
            }
            
            self.textView.frame = CGRect(origin: CGPoint(), size: bestSize.info.size)
            return bestSize.info.size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
