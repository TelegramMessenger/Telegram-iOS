import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import QuickShareScreen

extension ChatControllerImpl {
    func displayQuickShare(node: ASDisplayNode, gesture: ContextGesture) {
        guard !"".isEmpty else {
            return
        }
        let controller = QuickShareScreen(context: self.context, sourceNode: node, gesture: gesture)
        self.presentInGlobalOverlay(controller)
    }
}
