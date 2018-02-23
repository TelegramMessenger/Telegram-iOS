import Foundation
import AsyncDisplayKit
import Display
import Postbox

final class ShareLoadingContainerNode: ASDisplayNode, ShareContentContainerNode {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let activityIndicator: ActivityIndicator
    
    init(theme: PresentationTheme) {
        self.activityIndicator = ActivityIndicator(type: ActivityIndicatorType.custom(theme.actionSheet.controlAccentColor, 50.0, 2.0))
        
        super.init()
        
        self.addSubnode(self.activityIndicator)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func updateLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let nodeHeight: CGFloat = 125.0
        
        let indicatorSize = self.activityIndicator.calculateSizeThatFits(size)
        transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: size.height - nodeHeight + floor((nodeHeight - indicatorSize.height) / 2.0)), size: indicatorSize))
        
        self.contentOffsetUpdated?(-size.height + 64.0, transition)
    }
    
    func updateSelectedPeers() {
    }
}
