import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import SegmentedControlNode

final class PeerMediaCollectionSectionsNode: ASDisplayNode {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let segmentedControlNode: SegmentedControlNode
    private let separatorNode: ASDisplayNode
    
    var indexUpdated: ((Int) -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
                
        let items = [
            strings.SharedMedia_CategoryMedia,
            strings.SharedMedia_CategoryDocs,
            strings.SharedMedia_CategoryLinks,
            strings.SharedMedia_CategoryOther
        ]
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: theme), items: items.map { SegmentedControlItem(title: $0) }, selectedIndex: 0)
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
        
        super.init()
        
        self.backgroundColor = self.theme.rootController.navigationBar.opaqueBackgroundColor
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            self?.indexUpdated?(index)
        }
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.segmentedControlNode)
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, additionalInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: PeerMediaCollectionInterfaceState) -> CGFloat {
        let panelHeight: CGFloat = 39.0 + additionalInset
        let sideInset: CGFloat = 8.0
        
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: width - sideInset * 2.0 - leftInset - rightInset), transition: transition)
        transition.updateFrame(node: self.segmentedControlNode, frame: CGRect(origin: CGPoint(x: sideInset + leftInset, y: panelHeight - 8.0 - controlSize.height), size: controlSize))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            self.separatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
            self.backgroundColor = self.theme.rootController.navigationBar.opaqueBackgroundColor
            self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: self.theme))
        }
        
        return panelHeight
    }
}
