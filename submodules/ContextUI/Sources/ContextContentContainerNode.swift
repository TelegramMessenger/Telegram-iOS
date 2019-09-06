import Foundation
import AsyncDisplayKit
import Display

final class ContextContentContainerNode: ASDisplayNode {
    var contentNode: ContextContentNode?
    
    override init() {
        super.init()
    }
    
    func updateLayout(size: CGSize, scaledSize: CGSize, transition: ContainedViewLayoutTransition) {
        guard let contentNode = self.contentNode else {
            return
        }
        switch contentNode {
        case .extracted:
            break
        case let .controller(controller):
            transition.updatePosition(node: controller, position: CGPoint(x: scaledSize.width / 2.0, y: scaledSize.height / 2.0))
            transition.updateBounds(node: controller, bounds: CGRect(origin: CGPoint(), size: size))
            transition.updateTransformScale(node: controller, scale: scaledSize.width / size.width)
            controller.updateLayout(size: size, transition: transition)
            controller.controller.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: transition)
        }
    }
}
