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

