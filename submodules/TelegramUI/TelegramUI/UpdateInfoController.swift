import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData

private final class UpdateInfoControllerArguments {
    let openAppStorePage: () -> Void
    
    init(openAppStorePage: @escaping () -> Void) {
        self.openAppStorePage = openAppStorePage
    }
}

private enum UpdateInfoControllerSection: Int32 {
    case info
    case update
}

private enum UpdateInfoControllerEntry: ItemListNodeEntry {
    case info(PresentationTheme, String, String, [MessageTextEntity])
    case update(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return UpdateInfoControllerSection.info.rawValue
            case .update:
                return UpdateInfoControllerSection.update.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .info:
                return 0
            case .update:
                return 1
        }
    }
    
    static func ==(lhs: UpdateInfoControllerEntry, rhs: UpdateInfoControllerEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsTitle, lhsText, lhsEntities):
                if case let .info(rhsTheme, rhsTitle, rhsText, rhsEntities) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsEntities == rhsEntities {
                    return true
                } else {
                    return false
                }
            case let .update(lhsTheme, lhsTitle):
                if case let .update(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: UpdateInfoControllerEntry, rhs: UpdateInfoControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: UpdateInfoControllerArguments) -> ListViewItem {
        switch self {
            case let .info(theme, title, text, entities):
                let text = stringWithAppliedEntities(text, entities: entities, baseColor: theme.list.itemPrimaryTextColor, linkColor: theme.list.itemAccentColor, baseFont: Font.regular(14.0), linkFont: Font.regular(14.0), boldFont: Font.bold(14.0), italicFont: Font.italic(14.0), boldItalicFont: Font.semiboldItalic(14.0), fixedFont: Font.monospace(14.0))
                return ItemListSectionHeaderItem(theme: theme, text: text.string, sectionId: self.section)
            case let .update(theme, title):
                return ItemListActionItem(theme: theme, title: title, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.openAppStorePage()
                })
        }
    }
}

private func updateInfoControllerEntries(theme: PresentationTheme, strings: PresentationStrings, appUpdateInfo: AppUpdateInfo) -> [UpdateInfoControllerEntry] {
    var entries: [UpdateInfoControllerEntry] = []
    
    entries.append(.info(theme, strings.Update_AppVersion(appUpdateInfo.version).0, appUpdateInfo.text, appUpdateInfo.entities))
    entries.append(.update(theme, strings.Update_UpdateApp))
    
    return entries
}

public func updateInfoController(context: AccountContext, appUpdateInfo: AppUpdateInfo) -> ViewController {
    var dismissImpl: (() -> Void)?
    
    let arguments = UpdateInfoControllerArguments(openAppStorePage: {
        context.sharedContext.applicationBindings.openAppStorePage()
    })
    
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState<UpdateInfoControllerEntry>, UpdateInfoControllerEntry.ItemGenerationArguments)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Update_Skip), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Update_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: updateInfoControllerEntries(theme: presentationData.theme, strings: presentationData.strings, appUpdateInfo: appUpdateInfo), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(sharedContext: context.sharedContext, state: signal)
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    return controller
}
