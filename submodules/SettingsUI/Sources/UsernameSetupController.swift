import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import ShareController
import UndoUI
import InviteLinksUI

private final class UsernameSetupControllerArguments {
    let account: Account
    
    let updatePublicLinkText: (String?, String) -> Void
    let shareLink: () -> Void
    
    let activateLink: (String) -> Void
    let deactivateLink: (String) -> Void
    
    init(account: Account, updatePublicLinkText: @escaping (String?, String) -> Void, shareLink: @escaping () -> Void, activateLink: @escaping (String) -> Void, deactivateLink: @escaping (String) -> Void) {
        self.account = account
        self.updatePublicLinkText = updatePublicLinkText
        self.shareLink = shareLink
        self.activateLink = activateLink
        self.deactivateLink = deactivateLink
    }
}

private enum UsernameSetupSection: Int32 {
    case link
    case additional
}

public enum UsernameEntryTag: ItemListItemTag {
    case username
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? UsernameEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum UsernameSetupEntryId: Hashable {
    case index(Int32)
    case username(String)
}

private enum UsernameSetupEntry: ItemListNodeEntry {
    case publicLinkHeader(PresentationTheme, String)
    case editablePublicLink(PresentationTheme, PresentationStrings, String, String?, String)
    case publicLinkStatus(PresentationTheme, String, AddressNameValidationStatus, String)
    case publicLinkInfo(PresentationTheme, String)
    
    case additionalLinkHeader(PresentationTheme, String)
    case additionalLink(PresentationTheme, TelegramPeerUsername, Int32)
    case additionalLinkInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .publicLinkHeader, .editablePublicLink, .publicLinkStatus, .publicLinkInfo:
                return UsernameSetupSection.link.rawValue
            case .additionalLinkHeader, .additionalLink, .additionalLinkInfo:
                return UsernameSetupSection.additional.rawValue
        }
    }
    
    var stableId: UsernameSetupEntryId {
        switch self {
            case .publicLinkHeader:
                return .index(0)
            case .editablePublicLink:
                return .index(1)
            case .publicLinkStatus:
                return .index(2)
            case .publicLinkInfo:
                return .index(3)
            case .additionalLinkHeader:
                return .index(4)
            case let .additionalLink(_, username, _):
                return .username(username.username)
            case .additionalLinkInfo:
                return .index(5)
        }
    }
    
    static func ==(lhs: UsernameSetupEntry, rhs: UsernameSetupEntry) -> Bool {
        switch lhs {
            case let .publicLinkHeader(lhsTheme, lhsText):
                if case let .publicLinkHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .editablePublicLink(lhsTheme, lhsStrings, lhsPrefix, lhsCurrentText, lhsText):
                if case let .editablePublicLink(rhsTheme, rhsStrings, rhsPrefix, rhsCurrentText, rhsText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPrefix == rhsPrefix, lhsCurrentText == rhsCurrentText, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkInfo(lhsTheme, lhsText):
                if case let .publicLinkInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkStatus(lhsTheme, lhsAddressName, lhsStatus, lhsText):
                if case let .publicLinkStatus(rhsTheme, rhsAddressName, rhsStatus, rhsText) = rhs, lhsTheme === rhsTheme, lhsAddressName == rhsAddressName, lhsStatus == rhsStatus, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .additionalLinkHeader(lhsTheme, lhsText):
                if case let .additionalLinkHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .additionalLink(lhsTheme, lhsAddressName, lhsIndex):
                if case let .additionalLink(rhsTheme, rhsAddressName, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsAddressName == rhsAddressName, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .additionalLinkInfo(lhsTheme, lhsText):
                if case let .additionalLinkInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: UsernameSetupEntry, rhs: UsernameSetupEntry) -> Bool {
        switch lhs {
        case .publicLinkHeader:
            switch rhs {
            case  .publicLinkHeader:
                return false
            default:
                return true
            }
        case .editablePublicLink:
            switch rhs {
            case .publicLinkHeader, .editablePublicLink:
                return false
            default:
                return true
            }
        case .publicLinkStatus:
            switch rhs {
            case .publicLinkHeader, .editablePublicLink, .publicLinkStatus:
                return false
            default:
                return true
            }
        case .publicLinkInfo:
            switch rhs {
            case .publicLinkHeader, .editablePublicLink, .publicLinkStatus, .publicLinkInfo:
                return false
            default:
                return true
            }
        case .additionalLinkHeader:
            switch rhs {
            case .publicLinkHeader, .editablePublicLink, .publicLinkStatus, .publicLinkInfo, .additionalLinkHeader:
                return false
            default:
                return true
            }
        case let .additionalLink(_, _, lhsIndex):
            switch rhs {
            case let .additionalLink(_, _, rhsIndex):
                return lhsIndex < rhsIndex
            case .publicLinkHeader, .editablePublicLink, .publicLinkStatus, .publicLinkInfo, .additionalLinkHeader:
                return false
            default:
                return true
            }
        case .additionalLinkInfo:
            switch rhs {
            case .publicLinkHeader, .editablePublicLink, .publicLinkStatus, .publicLinkInfo, .additionalLinkHeader, .additionalLink, .additionalLinkInfo:
                return false
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! UsernameSetupControllerArguments
        switch self {
            case let .publicLinkHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .editablePublicLink(theme, _, prefix, currentText, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: prefix, textColor: theme.list.itemPrimaryTextColor), text: text, placeholder: "", type: .username, spacing: 10.0, clearType: .always, tag: UsernameEntryTag.username, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePublicLinkText(currentText, updatedText)
                }, action: {
                })
            case let .publicLinkInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { action in
                    if case .tap = action {
                        arguments.shareLink()
                    }
                })
            case let .publicLinkStatus(theme, _, status, text):
                var displayActivity = false
                let string: NSAttributedString
                switch status {
                    case .invalidFormat:
                        string = NSAttributedString(string: text, textColor: theme.list.freeTextErrorColor)
                    case let .availability(availability):
                        switch availability {
                            case .available:
                                string = NSAttributedString(string: text, textColor: theme.list.freeTextSuccessColor)
                            case .invalid, .taken:
                                string = NSAttributedString(string: text, textColor: theme.list.freeTextErrorColor)
                        }
                    case .checking:
                        string = NSAttributedString(string: text, textColor: theme.list.freeTextColor)
                        displayActivity = true
                }
                return ItemListActivityTextItem(displayActivity: displayActivity, presentationData: presentationData, text: string, sectionId: self.section)
            case let .additionalLinkHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .additionalLink(_, link, _):
                return AdditionalLinkItem(presentationData: presentationData, username: link, sectionId: self.section, style: .blocks, tapAction: {
                    if !link.flags.contains(.isEditable) {
                        if link.isActive {
                            arguments.deactivateLink(link.username)
                        } else {
                            arguments.activateLink(link.username)
                        }
                    }
                })
            case let .additionalLinkInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct UsernameSetupControllerState: Equatable {
    let editingPublicLinkText: String?
    let addressNameValidationStatus: AddressNameValidationStatus?
    let updatingAddressName: Bool
    
    init() {
        self.editingPublicLinkText = nil
        self.addressNameValidationStatus = nil
        self.updatingAddressName = false
    }
    
    init(editingPublicLinkText: String?, addressNameValidationStatus: AddressNameValidationStatus?, updatingAddressName: Bool) {
        self.editingPublicLinkText = editingPublicLinkText
        self.addressNameValidationStatus = addressNameValidationStatus
        self.updatingAddressName = updatingAddressName
    }
    
    static func ==(lhs: UsernameSetupControllerState, rhs: UsernameSetupControllerState) -> Bool {
        if lhs.editingPublicLinkText != rhs.editingPublicLinkText {
            return false
        }
        if lhs.addressNameValidationStatus != rhs.addressNameValidationStatus {
            return false
        }
        if lhs.updatingAddressName != rhs.updatingAddressName {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditingPublicLinkText(_ editingPublicLinkText: String?) -> UsernameSetupControllerState {
        return UsernameSetupControllerState(editingPublicLinkText: editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName)
    }
    
    func withUpdatedAddressNameValidationStatus(_ addressNameValidationStatus: AddressNameValidationStatus?) -> UsernameSetupControllerState {
        return UsernameSetupControllerState(editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: addressNameValidationStatus, updatingAddressName: self.updatingAddressName)
    }
    
    func withUpdatedUpdatingAddressName(_ updatingAddressName: Bool) -> UsernameSetupControllerState {
        return UsernameSetupControllerState(editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName)
    }
}

private func usernameSetupControllerEntries(presentationData: PresentationData, view: PeerView, state: UsernameSetupControllerState, temporaryOrder: [String]?) -> [UsernameSetupEntry] {
    var entries: [UsernameSetupEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramUser {
        let currentUsername: String
        if let current = state.editingPublicLinkText {
            currentUsername = current
        } else {
            if let username = peer.editableUsername {
                currentUsername = username
            } else {
                currentUsername = ""
            }
        }
        
        entries.append(.publicLinkHeader(presentationData.theme, presentationData.strings.Username_Username))
        entries.append(.editablePublicLink(presentationData.theme, presentationData.strings, presentationData.strings.Username_Title, peer.editableUsername, currentUsername))
        if let status = state.addressNameValidationStatus {
            let statusText: String
            switch status {
                case let .invalidFormat(error):
                    switch error {
                        case .startsWithDigit:
                            statusText = presentationData.strings.Username_InvalidStartsWithNumber
                        case .startsWithUnderscore:
                            statusText = presentationData.strings.Username_InvalidStartsWithUnderscore
                        case .endsWithUnderscore:
                            statusText = presentationData.strings.Username_InvalidEndsWithUnderscore
                        case .invalidCharacters:
                            statusText = presentationData.strings.Username_InvalidCharacters
                        case .tooShort:
                            statusText = presentationData.strings.Username_InvalidTooShort
                    }
                case let .availability(availability):
                    switch availability {
                        case .available:
                            statusText = presentationData.strings.Username_UsernameIsAvailable(currentUsername).string
                        case .invalid:
                            statusText = presentationData.strings.Username_InvalidCharacters
                        case .taken:
                            statusText = presentationData.strings.Username_InvalidTaken
                    }
                case .checking:
                    statusText = presentationData.strings.Username_CheckingUsername
            }
            entries.append(.publicLinkStatus(presentationData.theme, currentUsername, status, statusText))
        }
        
        var infoText = presentationData.strings.Username_Help
        
        let otherUsernames = peer.usernames.filter { !$0.flags.contains(.isEditable) }
        
        if otherUsernames.isEmpty {
            infoText += "\n\n"
            let hintText = presentationData.strings.Username_LinkHint(currentUsername.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")).string.replacingOccurrences(of: "]", with: "]()")
            infoText += hintText
        }
        entries.append(.publicLinkInfo(presentationData.theme, infoText))
        
        if !otherUsernames.isEmpty {
            entries.append(.additionalLinkHeader(presentationData.theme, presentationData.strings.Username_LinksOrder))
            
            var usernames = peer.usernames
            if let temporaryOrder = temporaryOrder {
                var usernamesMap: [String: TelegramPeerUsername] = [:]
                for username in usernames {
                    usernamesMap[username.username] = username
                }
                var sortedUsernames: [TelegramPeerUsername] = []
                for username in temporaryOrder {
                    if let username = usernamesMap[username] {
                        sortedUsernames.append(username)
                    }
                }
                usernames = sortedUsernames
            }
            var i: Int32 = 0
            for username in usernames {
                entries.append(.additionalLink(presentationData.theme, username, i))
                i += 1
            }
            
            entries.append(.additionalLinkInfo(presentationData.theme, presentationData.strings.Username_LinksOrderInfo))
        }
    }
    
    return entries
}

public func usernameSetupController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(UsernameSetupControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: UsernameSetupControllerState())
    let updateState: ((UsernameSetupControllerState) -> UsernameSetupControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let arguments = UsernameSetupControllerArguments(account: context.account, updatePublicLinkText: { currentText, text in
        if text.isEmpty {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameValidationStatus(nil)
            }
        } else if currentText == text {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameValidationStatus(nil).withUpdatedAddressNameValidationStatus(nil)
            }
        } else {
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text)
            }
            
            checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .account, name: text)
            |> deliverOnMainQueue).start(next: { result in
                updateState { state in
                    return state.withUpdatedAddressNameValidationStatus(result)
                }
            }))
        }
    }, shareLink: {
        let _ = (context.account.postbox.loadedPeerWithId(context.account.peerId)
        |> take(1)
        |> deliverOnMainQueue).start(next: { peer in
            var currentAddressName: String = peer.addressName ?? ""
            updateState { state in
                if let current = state.editingPublicLinkText {
                    currentAddressName = current
                }
                return state
            }
            if !currentAddressName.isEmpty {
                dismissInputImpl?()
                let shareController = ShareController(context: context, subject: .url("https://t.me/\(currentAddressName)"))
                shareController.actionCompleted = {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                }
                presentControllerImpl?(shareController, nil)
            }
        })
    }, activateLink: { name in
        dismissInputImpl?()
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.Username_ActivateAlertTitle, text: presentationData.strings.Username_ActivateAlertText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Username_ActivateAlertShow, action: {
            let _ = context.engine.peers.toggleAddressNameActive(domain: .account, name: name, active: true).start(error: { error in
                let errorText: String
                switch error {
                case .activeLimitReached:
                    errorText = presentationData.strings.Username_ActiveLimitReachedError
                default:
                    errorText = presentationData.strings.Login_UnknownError
                }
                presentControllerImpl?(textAlertController(context: context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            })
        })]), nil)
    }, deactivateLink: { name in
        dismissInputImpl?()
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.Username_DeactivateAlertTitle, text: presentationData.strings.Username_DeactivateAlertText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Username_DeactivateAlertHide, action: {
            let _ = context.engine.peers.toggleAddressNameActive(domain: .account, name: name, active: false).start()
        })]), nil)
    })
    
    let temporaryOrder = Promise<[String]?>(nil)
    
    let peerView = context.account.viewTracker.peerView(context.account.peerId)
    |> deliverOnMainQueue
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get() |> deliverOnMainQueue,
        peerView,
        temporaryOrder.get()
    )
    |> map { presentationData, state, view, temporaryOrder -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let peer = peerViewMainPeer(view)
        
        var rightNavigationButton: ItemListNavigationButton?
        if let peer = peer as? TelegramUser {
            var doneEnabled = true
            
            if let addressNameValidationStatus = state.addressNameValidationStatus {
                switch addressNameValidationStatus {
                case .availability(.available):
                    break
                default:
                    doneEnabled = false
                }
            }
            
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: state.updatingAddressName ? .activity : .bold, enabled: doneEnabled, action: {
                var updatedAddressNameValue: String?
                updateState { state in
                    if state.editingPublicLinkText != peer.addressName {
                        updatedAddressNameValue = state.editingPublicLinkText
                    }
                    
                    if updatedAddressNameValue != nil {
                        return state.withUpdatedUpdatingAddressName(true)
                    } else {
                        return state
                    }
                }
                
                if let updatedAddressNameValue = updatedAddressNameValue {
                    updateAddressNameDisposable.set((context.engine.peers.updateAddressName(domain: .account, name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue)
                    |> deliverOnMainQueue).start(error: { _ in
                        updateState { state in
                            return state.withUpdatedUpdatingAddressName(false)
                        }
                    }, completed: {
                        updateState { state in
                            return state.withUpdatedUpdatingAddressName(false)
                        }
                        
                        dismissImpl?()
                    }))
                } else {
                    dismissImpl?()
                }
            })
        }
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Username_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: usernameSetupControllerEntries(presentationData: presentationData, view: view, state: state, temporaryOrder: temporaryOrder), style: .blocks, focusItemTag: UsernameEntryTag.username, animateChanges: true)
            
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.enableInteractiveDismiss = true
    
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [UsernameSetupEntry]) -> Signal<Bool, NoError> in
        let fromEntry = entries[fromIndex]
        guard case let .additionalLink(_, fromUsername, _) = fromEntry else {
            return .single(false)
        }
        var referenceId: String?
        var beforeAll = false
        var afterAll = false
        
        var maxIndex: Int?
        
        var currentUsernames: [String] = []
        var i = 0
        for entry in entries {
            switch entry {
            case let .additionalLink(_, link, _):
                currentUsernames.append(link.username)
                if !link.isActive && maxIndex == nil {
                    maxIndex = max(0, i - 1)
                }
                i += 1
            default:
                break
            }
        }
        
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .additionalLink(_, toUsername, _):
                    if toUsername.isActive {
                        referenceId = toUsername.username
                    } else {
                        afterAll = true
                    }
                default:
                    if entries[toIndex] < fromEntry {
                        beforeAll = true
                    } else {
                        afterAll = true
                    }
            }
        } else {
            afterAll = true
        }

        var previousIndex: Int?
        for i in 0 ..< currentUsernames.count {
            if currentUsernames[i] == fromUsername.username {
                previousIndex = i
                currentUsernames.remove(at: i)
                break
            }
        }

        var didReorder = false
        if let referenceId = referenceId {
            var inserted = false
            for i in 0 ..< currentUsernames.count {
                if currentUsernames[i] == referenceId {
                    if fromIndex < toIndex {
                        didReorder = previousIndex != i + 1
                        currentUsernames.insert(fromUsername.username, at: i + 1)
                    } else {
                        didReorder = previousIndex != i
                        currentUsernames.insert(fromUsername.username, at: i)
                    }
                    inserted = true
                    break
                }
            }
            if !inserted {
                didReorder = previousIndex != currentUsernames.count
                if let maxIndex = maxIndex {
                    currentUsernames.insert(fromUsername.username, at: maxIndex)
                } else {
                    currentUsernames.append(fromUsername.username)
                }
            }
        } else if beforeAll {
            didReorder = previousIndex != 0
            currentUsernames.insert(fromUsername.username, at: 0)
        } else if afterAll {
            didReorder = previousIndex != currentUsernames.count
            if let maxIndex = maxIndex {
                currentUsernames.insert(fromUsername.username, at: maxIndex)
            } else {
                currentUsernames.append(fromUsername.username)
            }
        }

        temporaryOrder.set(.single(currentUsernames))
        
        if didReorder {
            DispatchQueue.main.async {
                dismissInputImpl?()
            }
        }
        
        return .single(didReorder)
    })
    
    controller.setReorderCompleted({ (entries: [UsernameSetupEntry]) -> Void in
        var currentUsernames: [TelegramPeerUsername] = []
        for entry in entries {
            switch entry {
            case let .additionalLink(_, username, _):
                currentUsernames.append(username)
            default:
                break
            }
        }
        let _ = (context.engine.peers.reorderAddressNames(domain: .account, names: currentUsernames)
        |> deliverOnMainQueue).start(completed: {
            temporaryOrder.set(.single(nil))
        })
    })
    
    controller.beganInteractiveDragging = {
        dismissInputImpl?()
    }
    
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    
    return controller
}
