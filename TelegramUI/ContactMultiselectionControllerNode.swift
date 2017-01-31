import Display
import AsyncDisplayKit
import UIKit
import Postbox
import TelegramCore

final class ContactMultiselectionControllerNode: ASDisplayNode {
    let contactListNode: ContactListNode
    let tokenListNode: EditableTokenListNode
    
    private let account: Account
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((PeerId) -> Void)?
    
    var editableTokens: [EditableTokenListToken] = []
    
    init(account: Account) {
        self.account = account
        self.contactListNode = ContactListNode(account: account, presentation: .natural(displaySearch: false, options: []), selectionState: ContactListNodeGroupSelectionState())
        self.tokenListNode = EditableTokenListNode()
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = UIColor.white
        
        self.addSubnode(self.contactListNode)
        self.addSubnode(self.tokenListNode)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        let tokenListHeight = self.tokenListNode.updateLayout(tokens: self.editableTokens, width: layout.size.width, transition: transition)
        transition.updateFrame(node: self.tokenListNode, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: tokenListHeight)))
        
        insets.top += tokenListHeight
        
        self.contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, intrinsicInsets: insets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight), transition: transition)
        
        self.contactListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
}
