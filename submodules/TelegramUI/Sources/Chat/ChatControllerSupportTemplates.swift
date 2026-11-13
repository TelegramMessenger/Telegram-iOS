import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import UndoUI
import SupportTemplates
import SupportContactConfirmScreen

extension ChatControllerImpl {
    var supportTemplatesAreAvailable: Bool {
        guard let manager = self.context.supportTemplates, self.supportOccupationPeerId != nil else {
            return false
        }
        return manager.templates.files.values.contains(where: { !$0.questions.isEmpty })
    }

    func setupSupportTemplates() {
        guard let manager = self.context.supportTemplates else {
            return
        }
        self.chatDisplayNode.textInputPanelNode?.supportTemplatesAction = { [weak self] in
            self?.supportTemplatesButtonPressed()
        }
        self.chatDisplayNode.textInputPanelNode?.supportHardwareTabAction = { [weak self] in
            self?.supportTemplatesHardwareTab()
        }
        self.supportTemplatesSettingsDisposable.set((self.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.supportSettings))
        |> map { entry -> Bool in
            return (entry?.get(SupportSettings.self) ?? .default).templatesAutocomplete
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            self?.supportTemplatesAutocomplete = value
        }))
        self.supportTemplatesStateObserver = manager.addStateObserver { [weak self] _ in
            guard let self else {
                return
            }
            let isShown = self.presentationInterfaceState.inputTextPanelState.accessoryItems.contains(.supportTemplates)
            if isShown != self.supportTemplatesAreAvailable {
                self.updateChatPresentationInterfaceState(animated: true, interactive: false, { $0 })
            }
        }
    }

    func supportTemplatesButtonPressed() {
        if self.chatDisplayNode.supportTemplatesPanel != nil {
            self.supportTemplatesCancel()
            return
        }
        if !self.supportTemplatesAutocomplete && self.supportTemplatesExpandKey() {
            return
        }
        self.supportTemplatesOpen()
    }

    func supportTemplatesHardwareTab() {
        guard self.supportTemplatesAreAvailable else {
            return
        }
        if self.supportTemplatesAutocomplete {
            self.supportTemplatesOpen()
        } else {
            let _ = self.supportTemplatesExpandKey()
        }
    }

    func supportTemplatesClose() {
        guard self.chatDisplayNode.supportTemplatesPanel != nil else {
            return
        }
        self.chatDisplayNode.supportTemplatesPanel = nil
        self.chatDisplayNode.textInputPanelNode?.supportTemplatesPanelIsOpen = false
        self.chatDisplayNode.requestLayout(.animated(duration: 0.3, curve: .spring))
    }

    private func supportTemplatesCancel() {
        self.chatDisplayNode.textInputPanelNode?.ensureFocused()
        self.supportTemplatesClose()
    }

    private func supportTemplatesOpen() {
        guard self.chatDisplayNode.supportTemplatesPanel == nil, let manager = self.context.supportTemplates else {
            return
        }
        let state = self.presentationInterfaceState
        let panel = SupportTemplatesChatInputContextPanelNode(context: self.context, theme: state.theme, strings: state.strings, fontSize: state.fontSize, chatPresentationContext: self.chatDisplayNode.controllerInteraction.presentationContext, templates: {
            return manager.templates
        })
        panel.chosen = { [weak self] question in
            self?.supportTemplateChosen(value: question.value, replacing: nil)
        }
        panel.cancelled = { [weak self] in
            self?.supportTemplatesCancel()
        }
        panel.lostFocus = { [weak self] in
            self?.supportTemplatesClose()
        }
        self.chatDisplayNode.supportTemplatesPanel = panel
        self.chatDisplayNode.textInputPanelNode?.supportTemplatesPanelIsOpen = true
        self.chatDisplayNode.requestLayout(.animated(duration: 0.3, curve: .spring))
    }

    private func supportTemplatesExpandKey() -> Bool {
        guard let manager = self.context.supportTemplates, let composer = self.chatDisplayNode.textInputPanelNode?.supportComposerTextAndSelection, let expansion = manager.templates.expansion(text: composer.text, selection: composer.selection) else {
            return false
        }
        self.supportTemplateChosen(value: expansion.value, replacing: expansion.range)
        return true
    }

    private func supportTemplateChosen(value: String, replacing range: NSRange?) {
        if supportTemplateValueIsContact(value) {
            self.supportTemplateContactChosen(value: value, replacing: range)
            return
        }
        let textInputPanelNode = self.chatDisplayNode.textInputPanelNode
        textInputPanelNode?.ensureFocused()
        self.supportTemplatesClose()
        textInputPanelNode?.supportInsertTemplateValue(value, replacing: range)
    }

    private func supportTemplateContactToast(_ text: String) {
        self.present(UndoOverlayController(presentationData: self.presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in
            return false
        }), in: .current)
    }

    private func supportTemplateContactChosen(value: String, replacing range: NSRange?) {
        guard let contact = SupportTemplateContact(value: value) else {
            self.supportTemplateContactToast(self.presentationData.strings.Support_ContactTemplates_Malformed)
            return
        }
        let state = self.presentationInterfaceState
        guard state.interfaceState.editMessage == nil else {
            self.supportTemplateContactToast(self.presentationData.strings.Support_ContactTemplates_FinishEditing)
            return
        }
        let inputState = state.interfaceState.effectiveInputState
        let composer = self.chatDisplayNode.textInputPanelNode?.supportComposerTextAndSelection ?? (inputState.inputText.string, NSRange(location: inputState.selectionRange.lowerBound, length: inputState.selectionRange.count))
        let text = contact.textToSend(composerText: composer.0, selection: composer.1, replacing: range)
        let restoresKeyboard = self.chatDisplayNode.supportTemplatesPanel != nil || state.inputMode == .text
        let media = TelegramMediaContact(firstName: contact.firstName, lastName: contact.lastName, phoneNumber: contact.phone, peerId: nil, vCardData: nil)
        let _ = (combineLatest(
            self.context.engine.messages.supportSendSwitchesChat() |> take(1),
            self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] sendSwitchesChat, accountPeer in
            guard let self else {
                return
            }
            let params = SupportContactConfirmScreenParams(context: self.context, presentationData: self.presentationData, theme: state.theme, wallpaper: state.chatWallpaper, accountPeer: accountPeer, text: text, contact: media, canSendWithoutSwitching: sendSwitchesChat)
            let screen = SupportContactConfirmScreen(params: params, completion: { [weak self] action in
                guard let self else {
                    return
                }
                switch action {
                case .send:
                    self.supportTemplateSendContact(media, comment: contact.comment, replacing: range, restoresKeyboard: restoresKeyboard, handleSupportSwitch: true)
                case .sendWithoutSwitching:
                    self.supportTemplateSendContact(media, comment: contact.comment, replacing: range, restoresKeyboard: restoresKeyboard, handleSupportSwitch: false)
                case .cancel:
                    if restoresKeyboard {
                        self.chatDisplayNode.textInputPanelNode?.ensureFocused()
                    }
                }
            })
            self.supportTemplatesClose()
            self.chatDisplayNode.dismissInput()
            self.present(screen, in: .window(.root))
        })
    }

    private func supportTemplateSendContact(_ media: TelegramMediaContact, comment: String, replacing range: NSRange?, restoresKeyboard: Bool, handleSupportSwitch: Bool) {
        guard let textInputPanelNode = self.chatDisplayNode.textInputPanelNode else {
            return
        }
        if restoresKeyboard {
            textInputPanelNode.ensureFocused()
        }
        textInputPanelNode.supportInsertTemplateValue(comment, replacing: range)
        if self.presentationInterfaceState.sendPaidMessageStars != nil {
            let count = Int32(ceil(CGFloat(textInputPanelNode.inputTextState.inputText.length) / 4096.0)) + 1
            self.presentPaidMessageAlertIfNeeded(count: count, completion: { [weak self] postpone in
                self?.chatDisplayNode.sendCurrentMessage(postpone: postpone, handleSupportSwitch: handleSupportSwitch, supportContact: media)
            })
        } else {
            self.chatDisplayNode.sendCurrentMessage(handleSupportSwitch: handleSupportSwitch, supportContact: media)
        }
    }
}
