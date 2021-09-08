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

private final class UsernameSetupControllerArguments {
    let account: Account
    
    let updatePublicLinkText: (String?, String) -> Void
    let shareLink: () -> Void
    
    init(account: Account, updatePublicLinkText: @escaping (String?, String) -> Void, shareLink: @escaping () -> Void) {
        self.account = account
        self.updatePublicLinkText = updatePublicLinkText
        self.shareLink = shareLink
    }
}

private enum UsernameSetupSection: Int32 {
    case link
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


private enum UsernameSetupEntry: ItemListNodeEntry {
    case editablePublicLink(PresentationTheme, PresentationStrings, String, String?, String)
    case publicLinkStatus(PresentationTheme, String, AddressNameValidationStatus, String)
    case publicLinkInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .editablePublicLink, .publicLinkStatus, .publicLinkInfo:
                return UsernameSetupSection.link.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .editablePublicLink:
                return 0
            case .publicLinkStatus:
                return 1
            case .publicLinkInfo:
                return 2
        }
    }
    
    static func ==(lhs: UsernameSetupEntry, rhs: UsernameSetupEntry) -> Bool {
        switch lhs {
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
        }
    }
    
    static func <(lhs: UsernameSetupEntry, rhs: UsernameSetupEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! UsernameSetupControllerArguments
        switch self {
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

private func usernameSetupControllerEntries(presentationData: PresentationData, view: PeerView, state: UsernameSetupControllerState) -> [UsernameSetupEntry] {
    var entries: [UsernameSetupEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramUser {
        let currentAddressName: String
        if let current = state.editingPublicLinkText {
            currentAddressName = current
        } else {
            if let addressName = peer.addressName {
                currentAddressName = addressName
            } else {
                currentAddressName = ""
            }
        }
        
        entries.append(.editablePublicLink(presentationData.theme, presentationData.strings, presentationData.strings.Username_Title, peer.addressName, currentAddressName))
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
                            statusText = presentationData.strings.Username_UsernameIsAvailable(currentAddressName).string
                        case .invalid:
                            statusText = presentationData.strings.Username_InvalidCharacters
                        case .taken:
                            statusText = presentationData.strings.Username_InvalidTaken
                    }
                case .checking:
                    statusText = presentationData.strings.Username_CheckingUsername
            }
            entries.append(.publicLinkStatus(presentationData.theme, currentAddressName, status, statusText))
        }
        
        var infoText = presentationData.strings.Username_Help
        infoText += "\n\n"
        let hintText = presentationData.strings.Username_LinkHint(currentAddressName.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")).string.replacingOccurrences(of: "]", with: "]()")
        infoText += hintText
        entries.append(.publicLinkInfo(presentationData.theme, infoText))
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
    })
    
    let peerView = context.account.viewTracker.peerView(context.account.peerId)
    |> deliverOnMainQueue
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get() |> deliverOnMainQueue, peerView)
        |> map { presentationData, state, view -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: usernameSetupControllerEntries(presentationData: presentationData, view: view, state: state), style: .blocks, focusItemTag: UsernameEntryTag.username, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.enableInteractiveDismiss = true
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
