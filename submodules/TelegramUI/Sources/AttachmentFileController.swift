import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import ItemListPeerActionItem

private final class AttachmentFileControllerArguments {
    let openGallery: () -> Void
    let openFiles: () -> Void
   
    init(openGallery: @escaping () -> Void, openFiles: @escaping () -> Void) {
        self.openGallery = openGallery
        self.openFiles = openFiles
    }
}

private enum AttachmentFileSection: Int32 {
    case select
    case recent
}

private enum AttachmentFileEntry: ItemListNodeEntry {
    case selectFromGallery(PresentationTheme, String)
    case selectFromFiles(PresentationTheme, String)
    
    case recentHeader(PresentationTheme, String)
  
    var section: ItemListSectionId {
        switch self {
            case .selectFromGallery, .selectFromFiles:
                return AttachmentFileSection.select.rawValue
            case .recentHeader:
                return AttachmentFileSection.recent.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .selectFromGallery:
                return 0
            case .selectFromFiles:
                return 1
            case .recentHeader:
                return 2
        }
    }
    
    static func ==(lhs: AttachmentFileEntry, rhs: AttachmentFileEntry) -> Bool {
        switch lhs {
            case let .selectFromGallery(lhsTheme, lhsText):
                if case let .selectFromGallery(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .selectFromFiles(lhsTheme, lhsText):
                if case let .selectFromFiles(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .recentHeader(lhsTheme, lhsText):
                if case let .recentHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: AttachmentFileEntry, rhs: AttachmentFileEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AttachmentFileControllerArguments
        switch self {
            case let .selectFromGallery(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.imageIcon(presentationData.theme), title: text, alwaysPlain: false, sectionId: self.section, height: .generic, editing: false, action: {
                    arguments.openGallery()
                })
            case let .selectFromFiles(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.cloudIcon(presentationData.theme), title: text, alwaysPlain: false, sectionId: self.section, height: .generic, editing: false, action: {
                    arguments.openFiles()
                })
            case let .recentHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        }
    }
}

private func attachmentFileControllerEntries(presentationData: PresentationData) -> [AttachmentFileEntry] {
    var entries: [AttachmentFileEntry] = []
    
    entries.append(.selectFromGallery(presentationData.theme, presentationData.strings.Attachment_SelectFromGallery))
    entries.append(.selectFromFiles(presentationData.theme, presentationData.strings.Attachment_SelectFromFiles))
    
    entries.append(.recentHeader(presentationData.theme, "RECENTLY SENT FILES".uppercased()))

    return entries
}

public func attachmentFileController(context: AccountContext, presentGallery: @escaping () -> Void, presentFiles: @escaping () -> Void) -> ViewController {
    let actionsDisposable = DisposableSet()
    
    var dismissImpl: (() -> Void)?
    let arguments = AttachmentFileControllerArguments(openGallery: {
        presentGallery()
    }, openFiles: {
        presentFiles()
    })

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Attachment_File), leftNavigationButton: ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        }), rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: attachmentFileControllerEntries(presentationData: presentationData), style: .blocks, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true)
    }
    return controller
}
