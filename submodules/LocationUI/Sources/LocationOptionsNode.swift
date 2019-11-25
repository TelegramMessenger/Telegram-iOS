import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import SegmentedControlNode

final class LocationOptionsNode: ASDisplayNode {
    private var presentationData: PresentationData
    
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let segmentedControlNode: SegmentedControlNode
    private let interaction: LocationPickerInteraction
    
    init(presentationData: PresentationData, interaction: LocationPickerInteraction) {
        self.presentationData = presentationData
        self.interaction = interaction
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: self.presentationData.theme), items: [SegmentedControlItem(title: self.presentationData.strings.Map_Map), SegmentedControlItem(title: self.presentationData.strings.Map_Satellite), SegmentedControlItem(title: self.presentationData.strings.Map_Hybrid)], selectedIndex: 0)
                
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.segmentedControlNode)
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            guard let strongSelf = self else {
                return
            }
            switch index {
                case 0:
                    strongSelf.interaction.updateMapMode(.map)
                case 1:
                    strongSelf.interaction.updateMapMode(.sattelite)
                case 2:
                    strongSelf.interaction.updateMapMode(.hybrid)
                default:
                    break
            }
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.separatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: self.presentationData.theme))
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(x: 0.0, y: size.height, width: size.width, height: UIScreenPixel))
        
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: size.width - 16.0), transition: .immediate)
        self.segmentedControlNode.frame = CGRect(origin: CGPoint(x: floor((size.width - controlSize.width) / 2.0), y: 0.0), size: controlSize)
    }
}
