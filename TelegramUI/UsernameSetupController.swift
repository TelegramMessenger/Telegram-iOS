import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class UsernameSetupControllerArguments {
    let account: Account
    
    let updatePublicLinkText: (String?, String) -> Void
    
    init(account: Account, updatePublicLinkText: @escaping (String?, String) -> Void) {
        self.account = account
        self.updatePublicLinkText = updatePublicLinkText
    }
}

private enum UsernameSetupSection: Int32 {
    case link
}

private enum UsernameSetupEntry: ItemListNodeEntry {
    case editablePublicLink(String?, String)
    case publicLinkStatus(String, AddressNameValidationStatus)
    case publicLinkInfo(String)
    
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
            case let .editablePublicLink(lhsCurrentText, lhsText):
                if case let .editablePublicLink(rhsCurrentText, rhsText) = rhs, lhsCurrentText == rhsCurrentText, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkInfo(text):
                if case .publicLinkInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .publicLinkStatus(addressName, status):
                if case .publicLinkStatus(addressName, status) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: UsernameSetupEntry, rhs: UsernameSetupEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: UsernameSetupControllerArguments) -> ListViewItem {
        switch self {
            case let .editablePublicLink(currentText, text):
                return ItemListSingleLineInputItem(title: NSAttributedString(string: "t.me/", textColor: .black), text: text, placeholder: "", sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePublicLinkText(currentText, updatedText)
                }, action: {
                    
                })
            case let .publicLinkInfo(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
            case let .publicLinkStatus(addressName, status):
                var displayActivity = false
                let text: NSAttributedString
                switch status {
                    case let .invalidFormat(error):
                        switch error {
                        case .startsWithDigit:
                            text = NSAttributedString(string: "Names can't start with a digit.", textColor: UIColor(0xcf3030))
                        case .startsWithUnderscore:
                            text = NSAttributedString(string: "Names can't start with an underscore.", textColor: UIColor(0xcf3030))
                        case .endsWithUnderscore:
                            text = NSAttributedString(string: "Names can't end with an underscore.", textColor: UIColor(0xcf3030))
                        case .tooShort:
                            text = NSAttributedString(string: "Names must have at least 5 characters.", textColor: UIColor(0xcf3030))
                        case .invalidCharacters:
                            text = NSAttributedString(string: "Sorry, this name is invalid.", textColor: UIColor(0xcf3030))
                        }
                    case let .availability(availability):
                        switch availability {
                        case .available:
                            text = NSAttributedString(string: "\(addressName) is available.", textColor: UIColor(0x26972c))
                        case .invalid:
                            text = NSAttributedString(string: "Sorry, this name is invalid.", textColor: UIColor(0xcf3030))
                        case .taken:
                            text = NSAttributedString(string: "\(addressName) is already taken.", textColor: UIColor(0xcf3030))
                        }
                    case .checking:
                        text = NSAttributedString(string: "Checking name...", textColor: UIColor(0x6d6d72))
                        displayActivity = true
                }
                return ItemListActivityTextItem(displayActivity: displayActivity, text: text, sectionId: self.section)
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

private func usernameSetupControllerEntries(view: PeerView, state: UsernameSetupControllerState) -> [UsernameSetupEntry] {
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
        
        entries.append(.editablePublicLink(peer.addressName, currentAddressName))
        if let status = state.addressNameValidationStatus {
            entries.append(.publicLinkStatus(currentAddressName, status))
        }
        entries.append(.publicLinkInfo("You can shoose a username on Telegram. If you do, other people will be able to find you by this username and contact you without knowing your phone number.\n\nYou can user a-z, 0-9 and underscores. Minimum length is 5 characters."))
    }
    
    return entries
}

public func usernameSetupController(account: Account) -> ViewController {
    let statePromise = ValuePromise(UsernameSetupControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: UsernameSetupControllerState())
    let updateState: ((UsernameSetupControllerState) -> UsernameSetupControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let arguments = UsernameSetupControllerArguments(account: account, updatePublicLinkText: { currentText, text in
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
            
            checkAddressNameDisposable.set((validateAddressNameInteractive(account: account, domain: .account, name: text)
                |> deliverOnMainQueue).start(next: { result in
                    updateState { state in
                        return state.withUpdatedAddressNameValidationStatus(result)
                    }
                }))
        }
    })
    
    let peerView = account.viewTracker.peerView(account.peerId)
        |> deliverOnMainQueue
    
    let signal = combineLatest(statePromise.get() |> deliverOnMainQueue, peerView)
        |> map { state, view -> (ItemListControllerState, (ItemListNodeState<UsernameSetupEntry>, UsernameSetupEntry.ItemGenerationArguments)) in
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
                
                rightNavigationButton = ItemListNavigationButton(title: "Done", style: state.updatingAddressName ? .activity : .bold, enabled: doneEnabled, action: {
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
                        updateAddressNameDisposable.set((updateAddressName(account: account, domain: .account, name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue)
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
            
            let leftNavigationButton = ItemListNavigationButton(title: "Cancel", style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            let controllerState = ItemListControllerState(title: .text("Username"), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, animateChanges: false)
            let listState = ItemListNodeState(entries: usernameSetupControllerEntries(view: view, state: state), style: .blocks, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
