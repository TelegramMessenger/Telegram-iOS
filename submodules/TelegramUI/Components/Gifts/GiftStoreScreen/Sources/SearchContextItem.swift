import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import ContextUI
import TextFieldComponent
import MultilineTextComponent
import BundleIconComponent

final class SearchContextItem: ContextMenuCustomItem {
    let context: AccountContext
    let placeholder: String
    let value: String
    let valueChanged: (String) -> Void
    
    init(
        context: AccountContext,
        placeholder: String,
        value: String,
        valueChanged: @escaping (String) -> Void
    ) {
        self.context = context
        self.placeholder = placeholder
        self.value = value
        self.valueChanged = valueChanged
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return SearchContextItemNode(
            presentationData: presentationData,
            item: self,
            getController: getController,
            actionSelected: actionSelected
        )
    }
}

private final class SearchContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol, ASScrollViewDelegate {
    private let item: SearchContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let state = EmptyComponentState()
    private let icon = ComponentView<Empty>()
    private let inputField = ComponentView<Empty>()
    private let inputFieldExternalState = TextFieldComponent.ExternalState()
    private let inputPlaceholderView = ComponentView<Empty>()
    private let inputClear = ComponentView<Empty>()
    private var inputText = ""
    
    private var validLayout: CGSize?
    
    init(presentationData: PresentationData, item: SearchContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        super.init()
        
        self.state._updated = { [weak self] transition, _ in
            guard let self, let size = self.validLayout else {
                return
            }
            self.internalUpdateLayout(size: size, transition: transition)
        }
    }
    
    func internalUpdateLayout(size: CGSize, transition: ComponentTransition) {
        let iconSize = self.icon.update(
            transition: .immediate,
            component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Search", tintColor: self.presentationData.theme.contextMenu.primaryColor)),
            environment: {},
            containerSize: size
        )
        let iconFrame = CGRect(origin: CGPoint(x: 17.0, y: floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
        if let iconView = self.icon.view {
            if iconView.superview == nil {
                self.view.addSubview(iconView)
            }
            transition.setFrame(view: iconView, frame: iconFrame)
        }
        
        let inputInset: CGFloat = 42.0
        
        self.inputField.parentState = self.state
        let inputFieldSize = self.inputField.update(
            transition: .immediate,
            component: AnyComponent(TextFieldComponent(
                context: self.item.context,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                externalState: self.inputFieldExternalState,
                fontSize: self.presentationData.listsFontSize.baseDisplaySize,
                textColor: self.presentationData.theme.contextMenu.primaryColor,
                accentColor: self.presentationData.theme.contextMenu.primaryColor,
                insets: UIEdgeInsets(top: 8.0, left: 2.0, bottom: 8.0, right: 2.0),
                hideKeyboard: false,
                customInputView: nil,
                resetText: nil,
                isOneLineWhenUnfocused: false,
                emptyLineHandling: .notAllowed,
                formatMenuAvailability: .none,
                returnKeyType: .search,
                lockedFormatAction: {
                },
                present: { _ in
                },
                paste: { _ in
                },
                returnKeyAction: nil,
                backspaceKeyAction: nil
            )),
            environment: {},
            containerSize: CGSize(width: size.width - inputInset - 40.0, height: size.height)
        )
        let inputFieldFrame = CGRect(origin: CGPoint(x: inputInset, y: floorToScreenPixels((size.height - inputFieldSize.height) / 2.0)), size: inputFieldSize)
        if let inputFieldView = self.inputField.view as? TextFieldComponent.View {
            if inputFieldView.superview == nil {
                self.view.addSubview(inputFieldView)
            }
            transition.setFrame(view: inputFieldView, frame: inputFieldFrame)
        }
                    
        if self.inputText != self.inputFieldExternalState.text.string {
            self.inputText = self.inputFieldExternalState.text.string
            self.item.valueChanged(self.inputText)
        }
        
        let inputPlaceholderSize = self.inputPlaceholderView.update(
            transition: .immediate,
            component: AnyComponent(
                MultilineTextComponent(text: .plain(NSAttributedString(
                    string: self.item.placeholder,
                    font: Font.regular(self.presentationData.listsFontSize.baseDisplaySize),
                    textColor: self.presentationData.theme.contextMenu.secondaryColor
                )))
            ),
            environment: {},
            containerSize: size
        )
        let inputPlaceholderFrame = CGRect(origin: CGPoint(x: inputInset + 10.0, y: floorToScreenPixels(inputFieldFrame.midY - inputPlaceholderSize.height / 2.0)), size: inputPlaceholderSize)
        if let inputPlaceholderView = self.inputPlaceholderView.view {
            if inputPlaceholderView.superview == nil {
                inputPlaceholderView.isUserInteractionEnabled = false
                self.view.addSubview(inputPlaceholderView)
            }
            inputPlaceholderView.frame = inputPlaceholderFrame
            inputPlaceholderView.isHidden = self.inputFieldExternalState.hasText
        }
        
        let inputClearSize = self.inputClear.update(
            transition: .immediate,
            component: AnyComponent(
                Button(
                    content: AnyComponent(
                        BundleIconComponent(name: "Components/Search Bar/Clear", tintColor: self.presentationData.theme.contextMenu.secondaryColor, maxSize: CGSize(width: 24.0, height: 24.0))
                    ),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let inputFieldView = self.inputField.view as? TextFieldComponent.View {
                            inputFieldView.updateText(NSAttributedString(), selectionRange: 0..<0)
                        }
                    }
                )
            ),
            environment: {},
            containerSize: CGSize(width: 30.0, height: 30.0)
        )
        let inputClearFrame = CGRect(origin: CGPoint(x: size.width - inputClearSize.width - 16.0, y: floorToScreenPixels(inputFieldFrame.midY - inputClearSize.height / 2.0)), size: inputClearSize)
        if let inputClearView = self.inputClear.view {
            if inputClearView.superview == nil {
                self.view.addSubview(inputClearView)
            }
            inputClearView.frame = inputClearFrame
            inputClearView.isHidden = !self.inputFieldExternalState.hasText
        }
    }
    
    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let maxWidth: CGFloat = 220.0
        let height: CGFloat = 42.0
        
        return (CGSize(width: maxWidth, height: height), { size, transition in
            self.validLayout = size
            self.internalUpdateLayout(size: size, transition: ComponentTransition(transition))
        })
    }
    
    func updateTheme(presentationData: PresentationData) {

    }
    
    var isActionEnabled: Bool {
        return true
    }
    
    func performAction() {
    }
    
    func setIsHighlighted(_ value: Bool) {
    }
    
    func canBeHighlighted() -> Bool {
        return false
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
    }
}
