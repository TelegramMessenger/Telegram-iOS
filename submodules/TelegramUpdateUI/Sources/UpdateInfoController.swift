import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ItemListUI
import PresentationDataUtils

private final class UpdateInfoControllerArguments {
    let openAppStorePage: () -> Void
    let linkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    
    init(openAppStorePage: @escaping () -> Void, linkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void) {
        self.openAppStorePage = openAppStorePage
        self.linkAction = linkAction
    }
}

private enum UpdateInfoControllerSection: Int32 {
    case info
    case update
}

private enum UpdateInfoControllerEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationAppIcon?, String, String, [MessageTextEntity])
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
            case let .info(lhsTheme, lhsIcon, lhsTitle, lhsText, lhsEntities):
                if case let .info(rhsTheme, rhsIcon, rhsTitle, rhsText, rhsEntities) = rhs, lhsTheme === rhsTheme, lhsIcon == rhsIcon, lhsTitle == rhsTitle, lhsText == rhsText, lhsEntities == rhsEntities {
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! UpdateInfoControllerArguments
        switch self {
            case let .info(theme, icon, title, text, entities):
                return UpdateInfoItem(theme: theme, appIcon: icon, title: title, text: text, entities: entities, sectionId: self.section, style: .blocks, linkItemAction: { action, itemLink in
                    arguments.linkAction(action, itemLink)
                })
            case let .update(_, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.openAppStorePage()
                })
        }
    }
}

private func updateInfoControllerEntries(theme: PresentationTheme, strings: PresentationStrings, appIcon: PresentationAppIcon?, appUpdateInfo: AppUpdateInfo) -> [UpdateInfoControllerEntry] {
    var entries: [UpdateInfoControllerEntry] = []
    
    entries.append(.info(theme, appIcon, strings.Update_AppVersion(appUpdateInfo.version).string, appUpdateInfo.text, appUpdateInfo.entities))
    entries.append(.update(theme, strings.Update_UpdateApp))
    
    return entries
}

public func updateInfoController(context: AccountContext, appUpdateInfo: AppUpdateInfo) -> ViewController {
    var dismissImpl: (() -> Void)?
    var linkActionImpl: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let navigateDisposable = MetaDisposable()
    actionsDisposable.add(navigateDisposable)
    
    let arguments = UpdateInfoControllerArguments(openAppStorePage: {
        context.sharedContext.applicationBindings.openAppStorePage()
    }, linkAction: { action, itemLink in
        linkActionImpl?(action, itemLink)
    })
    
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let appIcon: PresentationAppIcon?
        let appIcons = context.sharedContext.applicationBindings.getAvailableAlternateIcons()
        if let alternateIconName = context.sharedContext.applicationBindings.getAlternateIconName() {
            appIcon = appIcons.filter { $0.name == alternateIconName }.first
        } else {
            appIcon = appIcons.filter { $0.isDefault }.first
        }
        
        let leftNavigationButton = appUpdateInfo.blocking ? nil : ItemListNavigationButton(content: .text(presentationData.strings.Update_Skip), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Update_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: updateInfoControllerEntries(theme: presentationData.theme, strings: presentationData.strings, appIcon: appIcon, appUpdateInfo: appUpdateInfo), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(sharedContext: context.sharedContext, state: signal)
    controller.navigationPresentation = .modal
    linkActionImpl = { [weak controller, weak context] action, itemLink in
        if let strongController = controller, let context = context {
            context.sharedContext.handleTextLinkAction(context: context, peerId: nil, navigateDisposable: navigateDisposable, controller: strongController, action: action, itemLink: itemLink)
        }
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    return controller
}
