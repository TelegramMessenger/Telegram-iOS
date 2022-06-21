import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import SegmentedControlNode

final class LocationOptionsNode: ASDisplayNode {
    private var presentationData: PresentationData
    
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let segmentedControlNode: SegmentedControlNode
    
    init(presentationData: PresentationData, updateMapMode: @escaping (LocationMapMode) -> Void) {
        self.presentationData = presentationData
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: self.presentationData.theme), items: [SegmentedControlItem(title: self.presentationData.strings.Map_Map), SegmentedControlItem(title: self.presentationData.strings.Map_Satellite), SegmentedControlItem(title: self.presentationData.strings.Map_Hybrid)], selectedIndex: 0)
                
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.segmentedControlNode)
        
        self.segmentedControlNode.selectedIndexChanged = { index in
            switch index {
                case 0:
                    updateMapMode(.map)
                case 1:
                    updateMapMode(.sattelite)
                case 2:
                    updateMapMode(.hybrid)
                default:
                    break
            }
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
        self.separatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: self.presentationData.theme))
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(x: 0.0, y: size.height, width: size.width, height: UIScreenPixel))
        
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: size.width - 16.0 - leftInset - rightInset), transition: .immediate)
        self.segmentedControlNode.frame = CGRect(origin: CGPoint(x: floor((size.width - controlSize.width) / 2.0), y: 0.0), size: controlSize)
    }
}
