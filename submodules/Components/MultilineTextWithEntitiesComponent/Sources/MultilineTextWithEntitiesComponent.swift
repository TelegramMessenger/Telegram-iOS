import Foundation
import UIKit
import ComponentFlow
import Display
import Markdown
import TextNodeWithEntities
import AccountContext
import AnimationCache
import MultiAnimationRenderer

public final class MultilineTextWithEntitiesComponent: Component {
    public enum TextContent: Equatable {
        case plain(NSAttributedString)
        case markdown(text: String, attributes: MarkdownAttributes)
    }
    
    public let context: AccountContext?
    public let animationCache: AnimationCache?
    public let animationRenderer: MultiAnimationRenderer?
    public let placeholderColor: UIColor?
    
    public let text: TextContent
    public let horizontalAlignment: NSTextAlignment
    public let verticalAlignment: TextVerticalAlignment
    public let truncationType: CTLineTruncationType
    public let maximumNumberOfLines: Int
    public let lineSpacing: CGFloat
    public let cutout: TextNodeCutout?
    public let insets: UIEdgeInsets
    public let textShadowColor: UIColor?
    public let textStroke: (UIColor, CGFloat)?
    public let highlightColor: UIColor?
    public let highlightAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)?
    public let tapAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    public let longTapAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    
    public init(
        context: AccountContext?,
        animationCache: AnimationCache?,
        animationRenderer: MultiAnimationRenderer?,
        placeholderColor: UIColor?,
        text: TextContent,
        horizontalAlignment: NSTextAlignment = .natural,
        verticalAlignment: TextVerticalAlignment = .top,
        truncationType: CTLineTruncationType = .end,
        maximumNumberOfLines: Int = 1,
        lineSpacing: CGFloat = 0.0,
        cutout: TextNodeCutout? = nil,
        insets: UIEdgeInsets = UIEdgeInsets(),
        textShadowColor: UIColor? = nil,
        textStroke: (UIColor, CGFloat)? = nil,
        highlightColor: UIColor? = nil,
        highlightAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)? = nil,
        tapAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil,
        longTapAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil
    ) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.placeholderColor = placeholderColor
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
        self.highlightColor = highlightColor
        self.highlightAction = highlightAction
        self.tapAction = tapAction
        self.longTapAction = longTapAction
    }
    
    public static func ==(lhs: MultilineTextWithEntitiesComponent, rhs: MultilineTextWithEntitiesComponent) -> Bool {
        if lhs.text != rhs.text {
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
        let textNode: ImmediateTextNodeWithEntities
        
        public override init(frame: CGRect) {
            self.textNode = ImmediateTextNodeWithEntities()
            
            super.init(frame: frame)
            
            self.addSubview(self.textNode.view)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func update(component: MultilineTextWithEntitiesComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let attributedString: NSAttributedString
            switch component.text {
            case let .plain(string):
                attributedString = string
            case let .markdown(text, attributes):
                attributedString = parseMarkdownIntoAttributedString(text, attributes: attributes)
            }
            
            let previousText = self.textNode.attributedText?.string
            
            self.textNode.attributedText = attributedString
            self.textNode.maximumNumberOfLines = component.maximumNumberOfLines
            self.textNode.truncationType = component.truncationType
            self.textNode.textAlignment = component.horizontalAlignment
            self.textNode.verticalAlignment = component.verticalAlignment
            self.textNode.lineSpacing = component.lineSpacing
            self.textNode.cutout = component.cutout
            self.textNode.insets = component.insets
            self.textNode.textShadowColor = component.textShadowColor
            self.textNode.textStroke = component.textStroke
            self.textNode.linkHighlightColor = component.highlightColor
            self.textNode.highlightAttributeAction = component.highlightAction
            self.textNode.tapAttributeAction = component.tapAction
            self.textNode.longTapAttributeAction = component.longTapAction
                        
            if case let .curve(duration, _) = transition.animation, let previousText = previousText, previousText != attributedString.string {
                if let snapshotView = self.snapshotView(afterScreenUpdates: false) {
                    snapshotView.center = self.center
                    self.superview?.addSubview(snapshotView)
                    
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
                }
            }
            
            let size = self.textNode.updateLayout(availableSize)
            self.textNode.frame = CGRect(origin: .zero, size: size)
            
            self.textNode.visibility = true
            if let context = component.context, let animationCache = component.animationCache, let animationRenderer = component.animationRenderer, let placeholderColor = component.placeholderColor {
                self.textNode.arguments = TextNodeWithEntities.Arguments(
                    context: context,
                    cache: animationCache,
                    renderer: animationRenderer,
                    placeholderColor: placeholderColor,
                    attemptSynchronous: false
                )
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
