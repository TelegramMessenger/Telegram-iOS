import UIKit
import AsyncDisplayKit

public enum PointerStyle {
    case `default`
    case rectangle(CGSize)
    case circle
    case caret
    case lift
    case hover
}

@available(iOSApplicationExtension 13.4, iOS 13.4, *)
private final class PointerInteractionImpl: NSObject, UIPointerInteractionDelegate {
    weak var pointerInteraction: UIPointerInteraction?
    
    private let style: PointerStyle
    
    private let willEnter: () -> Void
    private let willExit: () -> Void
    
    init(style: PointerStyle, willEnter: @escaping () -> Void, willExit: @escaping () -> Void) {
        self.style = style
        self.willEnter = willEnter
        self.willExit = willExit
        
        super.init()
    }
    
    deinit {
        if let pointerInteraction = self.pointerInteraction {
            pointerInteraction.view?.removeInteraction(pointerInteraction)
        }
    }
    
    func setup(view: UIView) {
        let pointerInteraction = UIPointerInteraction(delegate: self)
        view.addInteraction(pointerInteraction)
        self.pointerInteraction = pointerInteraction
    }
    
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        var pointerStyle: UIPointerStyle? = nil
        if let interactionView = interaction.view {
            let targetedPreview = UITargetedPreview(view: interactionView)
            switch self.style {
                case .default:
                    let horizontalPadding: CGFloat = 10.0
                    let verticalPadding: CGFloat = 4.0
                    let minHeight: CGFloat = 40.0
                    let size: CGSize = CGSize(width: targetedPreview.size.width + horizontalPadding * 2.0, height: max(minHeight, targetedPreview.size.height + verticalPadding * 2.0))
                    pointerStyle = UIPointerStyle(effect: .highlight(targetedPreview), shape: .roundedRect(CGRect(origin: CGPoint(x: targetedPreview.view.center.x - size.width / 2.0, y: targetedPreview.view.center.y - size.height / 2.0), size: size), radius: UIPointerShape.defaultCornerRadius))
                case let .rectangle(size):
                    pointerStyle = UIPointerStyle(effect: .highlight(targetedPreview), shape: .roundedRect(CGRect(origin: CGPoint(x: targetedPreview.view.center.x - size.width / 2.0, y: targetedPreview.view.center.y - size.height / 2.0), size: size), radius: UIPointerShape.defaultCornerRadius))
                case .circle:
                    let maxSide = max(targetedPreview.size.width, targetedPreview.size.height)
                    pointerStyle = UIPointerStyle(effect: .highlight(targetedPreview), shape: .path(UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: CGSize(width: maxSide, height: maxSide)))))
                case .caret:
                    pointerStyle = UIPointerStyle(shape: .verticalBeam(length: 24.0), constrainedAxes: .vertical)
                case .lift:
                    pointerStyle = UIPointerStyle(effect: .lift(targetedPreview))
                case .hover:
                    pointerStyle = UIPointerStyle(effect: .hover(targetedPreview, preferredTintMode: .none, prefersShadow: false, prefersScaledContent: false))
            }
        }
        return pointerStyle
    }

    func pointerInteraction(_ interaction: UIPointerInteraction, willEnter region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        guard let _ = interaction.view else {
            return
        }

        animator.addAnimations {
            self.willEnter()
        }
     }

    func pointerInteraction(_ interaction: UIPointerInteraction, willExit region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        guard let _ = interaction.view else {
            return
        }

        animator.addAnimations {
            self.willExit()
        }
    }
}

public final class PointerInteraction {
    private var impl: AnyObject?
    private let style: PointerStyle
    
    private let willEnter: () -> Void
    private let willExit: () -> Void
    
    @available(iOSApplicationExtension 13.4, iOS 13.4, *)
    private func withImpl(_ f: (PointerInteractionImpl) -> Void) {
        if self.impl == nil {
            self.impl = PointerInteractionImpl(style: self.style, willEnter: self.willEnter, willExit: self.willExit)
        }
        f(self.impl as! PointerInteractionImpl)
    }
    
    public convenience init(node: ASDisplayNode, style: PointerStyle = .default, willEnter: @escaping () -> Void = {}, willExit: @escaping () -> Void = {}) {
        self.init(view: node.view, style: style, willEnter: willEnter, willExit: willExit)
    }
    
    public init(view: UIView, style: PointerStyle = .default, willEnter: @escaping () -> Void = {}, willExit: @escaping () -> Void = {}) {
        self.style = style
        self.willEnter = willEnter
        self.willExit = willExit
        if #available(iOSApplicationExtension 13.4, iOS 13.4, *) {
            self.withImpl { impl in
                impl.setup(view: view)
            }
        }
    }
}
