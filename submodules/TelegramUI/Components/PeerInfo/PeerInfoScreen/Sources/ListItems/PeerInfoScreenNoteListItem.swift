import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramCore
import AccountContext
import ComponentFlow
import TextFieldComponent

final class PeerInfoScreenNoteListItem: PeerInfoScreenItem {
    let id: AnyHashable
    let initialValue: NSAttributedString
    let valueUpdated: (NSAttributedString) -> Void
    let requestLayout: (Bool) -> Void
    
    init(
        id: AnyHashable,
        initialValue: NSAttributedString,
        valueUpdated: @escaping (NSAttributedString) -> Void,
        requestLayout: @escaping (Bool) -> Void
    ) {
        self.id = id
        self.initialValue = initialValue
        self.valueUpdated = valueUpdated
        self.requestLayout = requestLayout
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenNoteListItemNode()
    }
}

final class PeerInfoScreenNoteListItemNode: PeerInfoScreenItemNode {
    private let maskNode: ASImageNode
    private let textField = ComponentView<Empty>()
    private let textFieldExternalState = TextFieldComponent.ExternalState()
    
    private let state = EmptyComponentState()
    
    private let bottomSeparatorNode: ASDisplayNode
        
    private var item: PeerInfoScreenNoteListItem?
    private var presentationData: PresentationData?
    private var theme: PresentationTheme?
    
    override init() {
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
            
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
                        
        super.init()
        
        self.addSubnode(self.bottomSeparatorNode)
        
        self.addSubnode(self.maskNode)
    }
    
    func focus() {
        if let textView = self.textField.view as? TextFieldComponent.View {
            textView.activateInput()
        }
    }
    
    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenNoteListItem else {
            return 10.0
        }
        
        var resetText: NSAttributedString?
        if self.item?.initialValue != item.initialValue {
            resetText = item.initialValue
        }
        
        self.item = item
        self.presentationData = presentationData
        self.theme = presentationData.theme
                
        let sideInset: CGFloat = 1.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
     
        self.state._updated = { [weak self] transition, _ in
            guard let self else {
                return
            }
            self.item?.requestLayout(!transition.animation.isImmediate)
        }
        
        var characterLimit: Int = 128
        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["contact_note_length_limit"] as? Double {
            characterLimit = Int(value)
        }
        
        self.textField.parentState = self.state
        let textFieldSize = self.textField.update(
            transition: .immediate,
            component: AnyComponent(TextFieldComponent(context: context, theme: presentationData.theme, strings: presentationData.strings, externalState: self.textFieldExternalState, fontSize: 17.0, textColor: presentationData.theme.list.itemPrimaryTextColor, accentColor: presentationData.theme.list.itemAccentColor, insets: UIEdgeInsets(top: 9.0, left: 8.0, bottom: 10.0, right: 8.0), hideKeyboard: false, customInputView: nil, placeholder: NSAttributedString(string: presentationData.strings.PeerInfo_AddNotesPlaceholder, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPlaceholderTextColor), resetText: resetText, isOneLineWhenUnfocused: false, characterLimit: characterLimit, formatMenuAvailability: .available([.bold, .italic, .underline, .strikethrough, .spoiler]), lockedFormatAction: {}, present: { c in }, paste: { _ in })),
            environment: {},
            containerSize: CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude)
        )
        let textFieldFrame = CGRect(origin: CGPoint(x: sideInset, y: 3.0), size: textFieldSize)
        let height: CGFloat = 4.0 + textFieldSize.height
        if let textFieldView = self.textField.view {
            if textFieldView.superview == nil {
                self.view.addSubview(textFieldView)
            }
            transition.updateFrame(view: textFieldView, frame: textFieldFrame)
        }
        item.valueUpdated(self.textFieldExternalState.text)
       
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        return height
    }
}
