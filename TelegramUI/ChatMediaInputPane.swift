import Foundation
import AsyncDisplayKit
import Display

struct ChatMediaInputPaneScrollState {
    let absoluteOffset: CGFloat?
    let relativeChange: CGFloat
}

class ChatMediaInputPane: ASDisplayNode {
    var collectionListPanelOffset: CGFloat = 0.0
    
    func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
    }
}
