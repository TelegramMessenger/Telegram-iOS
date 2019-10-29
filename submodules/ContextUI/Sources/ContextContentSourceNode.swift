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
    let sourceNode: ASDisplayNode
    let controller: ViewController
    private let tapped: () -> Void
    
    init(sourceNode: ASDisplayNode, controller: ViewController, tapped: @escaping () -> Void) {
        self.sourceNode = sourceNode
        self.controller = controller
        self.tapped = tapped
        
        super.init()
        
        self.addSubnode(controller.displayNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped()
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.controller.displayNode, frame: CGRect(origin: CGPoint(), size: size))
    }
}

enum ContextContentNode {
    case extracted(ContextExtractedContentContainingNode)
    case controller(ContextControllerContentNode)
}
