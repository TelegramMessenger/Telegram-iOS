import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import UndoUI
import SupportTemplates

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
            return
        }
        let textInputPanelNode = self.chatDisplayNode.textInputPanelNode
        textInputPanelNode?.ensureFocused()
        self.supportTemplatesClose()
        textInputPanelNode?.supportInsertTemplateValue(value, replacing: range)
    }
}
