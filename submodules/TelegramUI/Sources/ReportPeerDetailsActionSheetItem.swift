import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ShareController
import AppBundle

public final class ReportPeerDetailsActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let placeholderText: String
    
    public init(context: AccountContext, placeholderText: String) {
        self.context = context
        self.placeholderText = placeholderText
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ReportPeerDetailsActionSheetItemNode(theme: theme, context: self.context, placeholderText: self.placeholderText)
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ReportPeerDetailsActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let inputFieldNode: ShareInputFieldNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    init(theme: ActionSheetControllerTheme, context: AccountContext, placeholderText: String) {
        self.theme = theme
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.inputFieldNode = ShareInputFieldNode(theme: ShareInputFieldNodeTheme(presentationTheme: presentationData.theme), placeholder: placeholderText)
        
        self.accessibilityArea = AccessibilityAreaNode()
            
        super.init(theme: theme)
        
        self.hasSeparator = false
        
        self.addSubnode(self.inputFieldNode)
        
//        self.inputFieldNode.
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let inputHeight = self.inputFieldNode.updateLayout(width: constrainedSize.width, transition: .immediate)
        self.inputFieldNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: constrainedSize.width, height: inputHeight))
       
        return CGSize(width: constrainedSize.width, height: inputHeight)
    }
    
    override func layout() {
        super.layout()
    }
}
