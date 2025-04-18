import Foundation
import AsyncDisplayKit

open class ContextReferenceContentNode: ASDisplayNode {
    override public init() {
        super.init()
    }
}

public final class ContextExtractedContentContainingNode: ASDisplayNode {
    public let contentNode: ContextExtractedContentNode
    public var contentRect: CGRect = CGRect()
    public var isExtractedToContextPreview: Bool = false
    public var willUpdateIsExtractedToContextPreview: ((Bool, ContainedViewLayoutTransition) -> Void)?
    public var isExtractedToContextPreviewUpdated: ((Bool) -> Void)?
    public var updateAbsoluteRect: ((CGRect, CGSize) -> Void)?
    public var applyAbsoluteOffset: ((CGPoint, ContainedViewLayoutTransitionCurve, Double) -> Void)?
    public var applyAbsoluteOffsetSpring: ((CGFloat, Double, CGFloat) -> Void)?
    public var layoutUpdated: ((CGSize, ListViewItemUpdateAnimation) -> Void)?
    public var updateDistractionFreeMode: ((Bool) -> Void)?
    public var requestDismiss: (() -> Void)?
    
    public override init() {
        self.contentNode = ContextExtractedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.contentNode.supernode === self {
            return self.contentNode.hitTest(self.view.convert(point, to: self.contentNode.view), with: event)
        } else {
            return nil
        }
    }
}

public final class ContextExtractedContentContainingView: UIView {
    public let contentView: ContextExtractedContentView
    public var contentRect: CGRect = CGRect()
    public var isExtractedToContextPreview: Bool = false
    public var willUpdateIsExtractedToContextPreview: ((Bool, ContainedViewLayoutTransition) -> Void)?
    public var isExtractedToContextPreviewUpdated: ((Bool) -> Void)?
    public var updateAbsoluteRect: ((CGRect, CGSize) -> Void)?
    public var applyAbsoluteOffset: ((CGPoint, ContainedViewLayoutTransitionCurve, Double) -> Void)?
    public var applyAbsoluteOffsetSpring: ((CGFloat, Double, CGFloat) -> Void)?
    public var layoutUpdated: ((CGSize, ListViewItemUpdateAnimation) -> Void)?
    public var updateDistractionFreeMode: ((Bool) -> Void)?
    public var requestDismiss: (() -> Void)?
    
    public override init(frame: CGRect) {
        self.contentView = ContextExtractedContentView()
        
        super.init(frame: frame)
        
        self.addSubview(self.contentView)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.contentView.superview === self {
            return self.contentView.hitTest(self.convert(point, to: self.contentView), with: event)
        } else {
            return nil
        }
    }
}

public final class ContextExtractedContentNode: ASDisplayNode {
    private var viewImpl: ContextExtractedContentView {
        return self.view as! ContextExtractedContentView
    }
    
    public var customHitTest: ((CGPoint) -> UIView?)? {
        didSet {
            if self.isNodeLoaded {
                self.viewImpl.customHitTest = self.customHitTest
            }
        }
    }

    override public init() {
        super.init()
        
        self.setViewBlock {
            return ContextExtractedContentView(frame: CGRect())
        }
    }
}

public final class ContextExtractedContentView: UIView {
    public var customHitTest: ((CGPoint) -> UIView?)?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self {
            return nil
        } else {
            return result
        }
    }
}

public final class ContextControllerContentNode: ASDisplayNode {
    public let sourceView: UIView
    public let controller: ViewController
    private let tapped: () -> Void
    
    public init(sourceView: UIView, controller: ViewController, tapped: @escaping () -> Void) {
        self.sourceView = sourceView
        self.controller = controller
        self.tapped = tapped
        
        super.init()
        
        self.addSubnode(controller.displayNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped()
        }
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.controller.displayNode, frame: CGRect(origin: CGPoint(), size: size))
    }
}

public enum ContextContentNode {
    case reference(view: UIView)
    case extracted(node: ContextExtractedContentContainingNode, keepInPlace: Bool)
    case controller(ContextControllerContentNode)
}
