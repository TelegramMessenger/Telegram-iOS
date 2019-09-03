import Foundation
import AsyncDisplayKit
import Display

public final class ContextExtractedContentContainingNode: ASDisplayNode {
    public let contentNode: ContextExtractedContentNode
    public var contentRect: CGRect = CGRect()
    public var isExtractedToContextPreview: Bool = false
    public var willUpdateIsExtractedToContextPreview: ((Bool) -> Void)?
    public var isExtractedToContextPreviewUpdated: ((Bool) -> Void)?
    public var updateAbsoluteRect: ((CGRect, CGSize) -> Void)?
    public var applyAbsoluteOffset: ((CGFloat, ContainedViewLayoutTransitionCurve, Double) -> Void)?
    public var applyAbsoluteOffsetSpring: ((CGFloat, Double, CGFloat) -> Void)?
    public var layoutUpdated: ((CGSize) -> Void)?
    public var updateDistractionFreeMode: ((Bool) -> Void)?
    
    public override init() {
        self.contentNode = ContextExtractedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
}

public final class ContextExtractedContentNode: ASDisplayNode {
}

final class ContextControllerContentNode: ASDisplayNode {
    let controller: ViewController
    
    init(controller: ViewController) {
        self.controller = controller
        
        super.init()
        
        self.addSubnode(controller.displayNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.controller.displayNode, frame: CGRect(origin: CGPoint(), size: size))
        self.controller.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
    }
}

enum ContextContentNode {
    case extracted(ContextExtractedContentContainingNode)
    case controller(ContextControllerContentNode)
}
