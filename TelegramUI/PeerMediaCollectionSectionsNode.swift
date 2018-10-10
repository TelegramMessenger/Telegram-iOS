import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

final class PeerMediaCollectionSectionsNode: ASDisplayNode {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let segmentedControl: UISegmentedControl
    private let separatorNode: ASDisplayNode
    
    var indexUpdated: ((Int) -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.segmentedControl = UISegmentedControl(items: [
            strings.SharedMedia_CategoryMedia,
            strings.SharedMedia_CategoryDocs,
            strings.SharedMedia_CategoryLinks,
            strings.SharedMedia_CategoryOther
        ])
        self.segmentedControl.selectedSegmentIndex = 0
        self.segmentedControl.tintColor = theme.rootController.navigationBar.accentTextColor
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.view.addSubview(self.segmentedControl)
        
        self.backgroundColor = self.theme.rootController.navigationBar.backgroundColor
        
        self.segmentedControl.addTarget(self, action: #selector(indexChanged), for: .valueChanged)
    }
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, additionalInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: PeerMediaCollectionInterfaceState) -> CGFloat {
        let panelHeight: CGFloat = 39.0 + additionalInset
        
        let controlHeight: CGFloat = 29.0
        let sideInset: CGFloat = 8.0
        transition.animateView {
            self.segmentedControl.frame = CGRect(origin: CGPoint(x: sideInset + leftInset, y: panelHeight - 11.0 - controlHeight), size: CGSize(width: width - sideInset * 2.0 - leftInset - rightInset, height: controlHeight))
        }
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            self.separatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
            self.backgroundColor = self.theme.rootController.navigationBar.backgroundColor
            self.segmentedControl.tintColor = theme.rootController.navigationBar.accentTextColor
        }
        
        return panelHeight
    }
    
    @objc func indexChanged() {
        self.indexUpdated?(self.segmentedControl.selectedSegmentIndex)
    }
}
