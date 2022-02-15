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
import AttachmentUI
import TelegramStringFormatting

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

private func areMessagesEqual(_ lhsMessage: Message, _ rhsMessage: Message) -> Bool {
    if lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.id != rhsMessage.id || lhsMessage.flags != rhsMessage.flags {
        return false
    }
    return true
}

private enum AttachmentFileEntry: ItemListNodeEntry {
    case selectFromGallery(PresentationTheme, String)
    case selectFromFiles(PresentationTheme, String)
    
    case recentHeader(PresentationTheme, String)
    case file(Int32, PresentationTheme, Message)
  
    var section: ItemListSectionId {
        switch self {
            case .selectFromGallery, .selectFromFiles:
                return AttachmentFileSection.select.rawValue
            case .recentHeader, .file:
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
            case let .file(index, _, _):
                return 3 + index
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
            case let .file(lhsIndex, lhsTheme, lhsMessage):
                if case let .file(rhsIndex, rhsTheme, rhsMessage) = rhs, lhsIndex != rhsIndex, lhsTheme === rhsTheme, areMessagesEqual(lhsMessage, rhsMessage) {
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
            case let .file(_, _, message):
                let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile
                let label: String
                if let file = file {
                    label = dataSizeString(file.size ?? 0, formatting: DataSizeStringFormatting(strings: presentationData.strings, decimalSeparator: "."))
                } else {
                    label = ""
                }
                return ItemListDisclosureItem(presentationData: presentationData, title: file?.fileName ?? "", label: label, sectionId: self.section, style: .blocks, action: {
                
                })
        }
    }
}

private func attachmentFileControllerEntries(presentationData: PresentationData, recentDocuments: [Message]?) -> [AttachmentFileEntry] {
    var entries: [AttachmentFileEntry] = []
    
    entries.append(.selectFromGallery(presentationData.theme, presentationData.strings.Attachment_SelectFromGallery))
    entries.append(.selectFromFiles(presentationData.theme, presentationData.strings.Attachment_SelectFromFiles))
    
    if let _ = recentDocuments {
//        entries.append(.recentHeader(presentationData.theme, "RECENTLY SENT FILES".uppercased()))
//        var i: Int32 = 0
//        for file in recentDocuments {
//            entries.append(.file(i, presentationData.theme, file))
//            i += 1
//        }
    }

    return entries
}

private class AttachmentFileControllerImpl: ItemListController, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = {}
}

public func attachmentFileController(context: AccountContext, presentGallery: @escaping () -> Void, presentFiles: @escaping () -> Void) -> AttachmentContainable {
    let actionsDisposable = DisposableSet()
    
    var dismissImpl: (() -> Void)?
    let arguments = AttachmentFileControllerArguments(openGallery: {
        presentGallery()
    }, openFiles: {
        presentFiles()
    })
    
    let recentDocuments: Signal<[Message]?, NoError> = .single(nil)
    |> then(
        context.engine.messages.searchMessages(location: .recentDocuments, query: "", state: nil)
        |> map { result -> [Message]? in
            return result.0.messages
        }
    )

    let signal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, recentDocuments)
    |> map { presentationData, recentDocuments -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Attachment_File), leftNavigationButton: ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        }), rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: attachmentFileControllerEntries(presentationData: presentationData, recentDocuments: recentDocuments), style: .blocks, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = AttachmentFileControllerImpl(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true)
    }
    return controller
}
