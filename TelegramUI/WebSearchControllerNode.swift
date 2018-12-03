import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

class WebSearchControllerNode: ASDisplayNode {
    private let segmentedBackgroundNode: ASDisplayNode
    private let segmentedSeparatorNode: ASDisplayNode
    private let segmentedControl: UISegmentedControl
    
    private let toolbarBackgroundNode: ASDisplayNode
    private let toolbarSeparatorNode: ASDisplayNode
    private let cancelButton: HighlightableButtonNode
    private let sendButton: HighlightableButtonNode
    private let attributionNode: ASImageNode
    
    private let account: Account
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        
        self.segmentedBackgroundNode = ASDisplayNode()
        self.segmentedBackgroundNode.backgroundColor = theme.rootController.navigationBar.backgroundColor
        
        self.segmentedSeparatorNode = ASDisplayNode()
        self.segmentedSeparatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        self.segmentedControl = UISegmentedControl(items: [strings.WebSearch_Images, strings.WebSearch_GIFs, strings.WebSearch_RecentSectionTitle])
        self.segmentedControl.tintColor = theme.rootController.navigationBar.accentTextColor
        self.segmentedControl.selectedSegmentIndex = 0
        
        self.toolbarBackgroundNode = ASDisplayNode()
        self.toolbarBackgroundNode.backgroundColor = theme.rootController.navigationBar.backgroundColor
        
        self.toolbarSeparatorNode = ASDisplayNode()
        self.toolbarSeparatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        self.attributionNode = ASImageNode()
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(strings.Common_Cancel, with: Font.regular(17.0), with: theme.rootController.navigationBar.accentTextColor, for: .normal)
        self.sendButton = HighlightableButtonNode()
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = theme.chatList.backgroundColor
        
        self.addSubnode(self.segmentedBackgroundNode)
        self.addSubnode(self.segmentedSeparatorNode)
        self.view.addSubview(self.segmentedControl)
        self.segmentedControl.addTarget(self, action: #selector(self.indexChanged), for: .valueChanged)
        
        self.addSubnode(self.toolbarBackgroundNode)
        self.addSubnode(self.toolbarSeparatorNode)
        self.addSubnode(self.cancelButton)
        self.addSubnode(self.sendButton)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        let segmentedHeight: CGFloat = 40.0
        let panelY: CGFloat = insets.top - UIScreenPixel - 4.0
        
        transition.updateFrame(node: self.segmentedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelY), size: CGSize(width: layout.size.width, height: segmentedHeight)))
        transition.updateFrame(node: self.segmentedSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelY + segmentedHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        var controlSize = self.segmentedControl.sizeThatFits(layout.size)
        controlSize.width = layout.size.width - 8.0 * 2.0
        
        transition.updateFrame(view: self.segmentedControl, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - controlSize.width) / 2.0), y: panelY + floor((segmentedHeight - controlSize.height) / 2.0)), size: controlSize))
    }
    
    @objc private func indexChanged() {
//        if self.segmentedControl.selectedSegmentIndex == 0 {
//            self.chatController?.displayNode.isHidden = false
//            self.listNode.isHidden = true
//        } else {
//            self.chatController?.displayNode.isHidden = true
//            self.listNode.isHidden = false
//        }
    }
}
