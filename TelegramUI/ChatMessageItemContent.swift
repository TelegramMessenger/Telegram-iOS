import Foundation
import Display

class ChatMessageItemContent {
    func attach(node: ASDisplayNode) {
        preconditionFailure()
    }
    
    func detach() {
        preconditionFailure()
    }
    
    func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        preconditionFailure()
    }
}
