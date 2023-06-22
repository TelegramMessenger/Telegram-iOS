import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ShareController
import AppBundle

public final class ReportPeerDetailsActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let theme: PresentationTheme
    let placeholderText: String
    let textUpdated: (String) -> Void
    
    public init(context: AccountContext, theme: PresentationTheme, placeholderText: String, textUpdated: @escaping (String) -> Void) {
        self.context = context
        self.theme = theme
        self.placeholderText = placeholderText
        self.textUpdated = textUpdated
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ReportPeerDetailsActionSheetItemNode(theme: theme, presentationTheme: self.theme, context: self.context, placeholderText: self.placeholderText, textUpdated: self.textUpdated)
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ReportPeerDetailsActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let inputFieldNode: ShareInputFieldNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    init(theme: ActionSheetControllerTheme, presentationTheme: PresentationTheme, context: AccountContext, placeholderText: String, textUpdated: @escaping (String) -> Void) {
        self.theme = theme
        
        self.inputFieldNode = ShareInputFieldNode(theme: ShareInputFieldNodeTheme(presentationTheme: presentationTheme), placeholder: placeholderText)
        
        self.accessibilityArea = AccessibilityAreaNode()
            
        super.init(theme: theme)
        
        self.hasSeparator = false
        
        self.addSubnode(self.inputFieldNode)
        
        self.inputFieldNode.updateText = { text in
            textUpdated(String(text.prefix(512)))
        }
        self.inputFieldNode.updateHeight = { [weak self] in
            self?.requestLayout?()
        }
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let inputHeight = self.inputFieldNode.updateLayout(width: constrainedSize.width, transition: .immediate)
        self.inputFieldNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: constrainedSize.width, height: inputHeight))
        
        let size = CGSize(width: constrainedSize.width, height: inputHeight)
       
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
