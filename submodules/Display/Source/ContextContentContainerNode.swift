import Foundation
import AsyncDisplayKit

public final class ContextContentContainerNode: ASDisplayNode {
    public var contentNode: ContextContentNode?
    
    override public init() {
        super.init()
    }
    
    public func updateLayout(size: CGSize, scaledSize: CGSize, transition: ContainedViewLayoutTransition) {
        guard let contentNode = self.contentNode else {
            return
        }
        switch contentNode {
        case .reference:
            break
        case .extracted:
            break
        case let .controller(controller):
            transition.updatePosition(node: controller, position: CGPoint(x: scaledSize.width / 2.0, y: scaledSize.height / 2.0))
            transition.updateBounds(node: controller, bounds: CGRect(origin: CGPoint(), size: size))
            transition.updateTransformScale(node: controller, scale: scaledSize.width / size.width)
            controller.updateLayout(size: size, transition: transition)
            controller.controller.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
        }
    }
}
