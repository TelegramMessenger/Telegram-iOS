import Foundation
import UIKit
import AccountContext
import Display
import PresentationDataUtils
import SupportTemplates
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import UndoUI

private func supportTemplatesSizeText(presentationData: PresentationData) -> String {
    return dataSizeString(supportTemplatesMaxFileSize, formatting: DataSizeStringFormatting(presentationData: presentationData))
}

public func supportTemplatesErrorText(_ error: SupportTemplatesError, presentationData: PresentationData) -> String {
    let strings = presentationData.strings
    switch error {
    case let .file(name, problem):
        switch problem {
        case .wrongName:
            return strings.Support_Templates_ErrorWrongName.replacingOccurrences(of: "{name}", with: name)
        case .notText:
            return strings.Support_Templates_ErrorNotText.replacingOccurrences(of: "{name}", with: name)
        case .noTemplates:
            return strings.Support_Templates_ErrorNoTemplates.replacingOccurrences(of: "{name}", with: name)
        case .tooLarge:
            return strings.Support_Templates_ErrorTooLarge.replacingOccurrences(of: "{size}", with: supportTemplatesSizeText(presentationData: presentationData)).replacingOccurrences(of: "{name}", with: name)
        }
    case let .importFailed(name):
        return strings.Support_Templates_ErrorImport.replacingOccurrences(of: "{name}", with: name)
    case let .unreadable(name):
        return strings.Support_Templates_ErrorUnreadable.replacingOccurrences(of: "{name}", with: name)
    case let .invalidUrl(name, url):
        return strings.Support_Templates_ErrorInvalidUrl.replacingOccurrences(of: "{url}", with: url).replacingOccurrences(of: "{name}", with: name)
    case let .updateFailed(name, url, problem):
        let text: String
        switch problem {
        case let .fetch(.network(description)):
            text = strings.Support_Templates_ErrorUpdateNetwork.replacingOccurrences(of: "{reason}", with: description)
        case .fetch(.noData):
            text = strings.Support_Templates_ErrorUpdateNoData
        case let .fetch(.http(status)):
            text = strings.Support_Templates_ErrorUpdateHttp.replacingOccurrences(of: "{status}", with: "\(status)")
        case .fetch(.tooLarge):
            text = strings.Support_Templates_ErrorUpdateTooLarge.replacingOccurrences(of: "{size}", with: supportTemplatesSizeText(presentationData: presentationData))
        case .notText:
            text = strings.Support_Templates_ErrorUpdateNotText
        case .noTemplates:
            text = strings.Support_Templates_ErrorUpdateNoTemplates
        }
        return text.replacingOccurrences(of: "{url}", with: url).replacingOccurrences(of: "{name}", with: name)
    case let .saveFailed(name):
        return strings.Support_Templates_ErrorSave.replacingOccurrences(of: "{name}", with: name)
    }
}

public func supportTemplatesFileChangeErrorText(_ error: SupportTemplatesFileChangeError, presentationData: PresentationData) -> String {
    let strings = presentationData.strings
    switch error {
    case .wrongName:
        return strings.Support_Templates_FileErrorWrongName
    case .nameTaken:
        return strings.Support_Templates_FileErrorNameTaken
    case .fileMissing:
        return strings.Support_Templates_FileErrorMissing
    case .invalidUrl:
        return strings.Support_Templates_FileErrorInvalidUrl
    case let .fetch(.network(description)):
        return strings.Support_Templates_FileErrorNetwork.replacingOccurrences(of: "{reason}", with: description)
    case .fetch(.noData):
        return strings.Support_Templates_FileErrorNoData
    case let .fetch(.http(status)):
        return strings.Support_Templates_FileErrorHttp.replacingOccurrences(of: "{status}", with: "\(status)")
    case .fetch(.tooLarge):
        return strings.Support_Templates_FileErrorTooLarge.replacingOccurrences(of: "{size}", with: supportTemplatesSizeText(presentationData: presentationData))
    case .notText:
        return strings.Support_Templates_FileErrorNotText
    case .noTemplates:
        return strings.Support_Templates_FileErrorNoTemplates
    case .saveFailed:
        return strings.Support_Templates_FileErrorSave
    }
}

public func supportPresentTemplatesReloadResult(context: AccountContext, result: SupportTemplatesReloadResult, successText: String, elevatedLayout: Bool, present: @escaping (ViewController) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var updated: String?
    if !result.updatedFiles.isEmpty {
        updated = presentationData.strings.Support_Templates_Updated.replacingOccurrences(of: "{files}", with: result.updatedFiles.joined(separator: ", "))
    }
    if result.errors.isEmpty {
        let text = updated.flatMap { "\(successText) \($0)" } ?? successText
        present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: elevatedLayout, action: { _ in
            return false
        }))
    } else {
        let text = (result.errors.map { supportTemplatesErrorText($0, presentationData: presentationData) } + (updated.flatMap { [$0] } ?? [])).joined(separator: "\n\n")
        present(textAlertController(context: context, title: presentationData.strings.Support_Templates_ErrorsTitle, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
        })]))
    }
}

public func supportReloadTemplatesAction(context: AccountContext, present: @escaping (ViewController) -> Void) -> () -> Void {
    guard let supportContext = context.supportContext, let manager = context.supportTemplates else {
        return {}
    }
    let reload: () -> Void = {
        guard supportContext.allowsHardwarePress(of: .reloadTemplates) else {
            return
        }
        manager.reload(completion: { result in
            Queue.mainQueue().async {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                supportPresentTemplatesReloadResult(context: context, result: result, successText: presentationData.strings.Support_Templates_Reloaded, elevatedLayout: true, present: present)
            }
        })
    }
    return reload
}

public func supportTemplatesReloadKeyShortcuts(context: AccountContext, strings: PresentationStrings, present: @escaping (ViewController) -> Void) -> [KeyShortcut] {
    guard let supportContext = context.supportContext else {
        return []
    }
    return supportKeyShortcuts(combos: supportContext.shortcutCombos(.reloadTemplates), title: supportShortcutTitle(.reloadTemplates, strings: strings), perform: supportReloadTemplatesAction(context: context, present: present))
}

public func supportShortcutTitle(_ action: SupportShortcutAction, strings: PresentationStrings) -> String {
    switch action {
    case .previousChat:
        return strings.Support_Shortcuts_PreviousChat
    case .nextChat:
        return strings.Support_Shortcuts_NextChat
    case .previousOpenedChat:
        return strings.Support_Shortcuts_PreviousOpenedChat
    case .nextOpenedChat:
        return strings.Support_Shortcuts_NextOpenedChat
    case .muteChat:
        return strings.Support_Shortcuts_MuteChat
    case .sendAndStay:
        return strings.Support_Shortcuts_SendAndStay
    case .closeChat:
        return strings.Support_Shortcuts_CloseChat
    case .reloadTemplates:
        return strings.Support_Templates_Reload
    case .showCurrentChat:
        return strings.Support_Shortcuts_ShowCurrentChat
    case .openAbuseBot:
        return strings.Support_Shortcuts_OpenAbuseBot
    }
}

public func supportKeyShortcuts(combos: [SupportKeyCombo], title: String?, wantsPriorityOverText: Bool = false, perform: @escaping () -> Void) -> [KeyShortcut] {
    return combos.enumerated().map { index, combo in
        return KeyShortcut(title: index == 0 ? (title ?? "") : "", input: supportKeyCommandInput(combo.key), modifiers: supportKeyCommandModifiers(combo.modifiers), wantsPriorityOverText: wantsPriorityOverText, action: perform)
    }
}

private func supportKeyCommandInput(_ key: String) -> String {
    switch key {
    case SupportKeyCombo.escapeKey:
        return UIKeyCommand.inputEscape
    case SupportKeyCombo.upKey:
        return UIKeyCommand.inputUpArrow
    case SupportKeyCombo.downKey:
        return UIKeyCommand.inputDownArrow
    case "Left":
        return UIKeyCommand.inputLeftArrow
    case "Right":
        return UIKeyCommand.inputRightArrow
    default:
        if key.hasPrefix("F"), Int(key.dropFirst()) != nil {
            return "UIKeyInput\(key)"
        }
        return key
    }
}

private func supportKeyCommandModifiers(_ modifiers: SupportKeyCombo.Modifiers) -> UIKeyModifierFlags {
    var result: UIKeyModifierFlags = []
    if modifiers.contains(.shift) {
        result.insert(.shift)
    }
    if modifiers.contains(.control) {
        result.insert(.control)
    }
    if modifiers.contains(.alternate) {
        result.insert(.alternate)
    }
    if modifiers.contains(.command) {
        result.insert(.command)
    }
    return result
}
