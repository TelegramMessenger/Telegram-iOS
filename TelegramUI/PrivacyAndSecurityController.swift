import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class PrivacyAndSecurityControllerArguments {
    let account: Account
    let openBlockedUsers: () -> Void
    let openLastSeenPrivacy: () -> Void
    let openGroupsPrivacy: () -> Void
    let openVoiceCallPrivacy: () -> Void
    let openPasscode: () -> Void
    let openTwoStepVerification: () -> Void
    let openActiveSessions: () -> Void
    let setupAccountAutoremove: () -> Void
    
    init(account: Account, openBlockedUsers: @escaping () -> Void, openLastSeenPrivacy: @escaping () -> Void, openGroupsPrivacy: @escaping () -> Void, openVoiceCallPrivacy: @escaping () -> Void, openPasscode: @escaping () -> Void, openTwoStepVerification: @escaping () -> Void, openActiveSessions: @escaping () -> Void, setupAccountAutoremove: @escaping () -> Void) {
        self.account = account
        self.openBlockedUsers = openBlockedUsers
        self.openLastSeenPrivacy = openLastSeenPrivacy
        self.openGroupsPrivacy = openGroupsPrivacy
        self.openVoiceCallPrivacy = openVoiceCallPrivacy
        self.openPasscode = openPasscode
        self.openTwoStepVerification = openTwoStepVerification
        self.openActiveSessions = openActiveSessions
        self.setupAccountAutoremove = setupAccountAutoremove
    }
}

private enum PrivacyAndSecuritySection: Int32 {
    case privacy
    case security
    case account
}

private enum PrivacyAndSecurityEntry: ItemListNodeEntry {
    case privacyHeader
    case blockedPeers
    case lastSeenPrivacy(String)
    case groupPrivacy(String)
    case voiceCallPrivacy(String)
    case securityHeader
    case passcode
    case twoStepVerification
    case activeSessions
    case accountHeader
    case accountTimeout(String)
    case accountInfo
    
    var section: ItemListSectionId {
        switch self {
            case .privacyHeader, .blockedPeers, .lastSeenPrivacy, .groupPrivacy, .voiceCallPrivacy:
                return PrivacyAndSecuritySection.privacy.rawValue
            case .securityHeader, .passcode, .twoStepVerification, .activeSessions:
                return PrivacyAndSecuritySection.security.rawValue
            case .accountHeader, .accountTimeout, .accountInfo:
                return PrivacyAndSecuritySection.account.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .privacyHeader:
                return 0
            case .blockedPeers:
                return 1
            case .lastSeenPrivacy:
                return 2
            case .groupPrivacy:
                return 3
            case .voiceCallPrivacy:
                return 4
            case .securityHeader:
                return 5
            case .passcode:
                return 6
            case .twoStepVerification:
                return 7
            case .activeSessions:
                return 8
            case .accountHeader:
                return 9
            case .accountTimeout:
                return 10
            case .accountInfo:
                return 11
        }
    }
    
    static func ==(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        switch lhs {
            case .privacyHeader, .blockedPeers, .securityHeader, .passcode, .twoStepVerification, .activeSessions, .accountHeader, .accountInfo:
                return lhs.stableId == rhs.stableId
            case let .lastSeenPrivacy(text):
                if case .lastSeenPrivacy(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .groupPrivacy(text):
                if case .groupPrivacy(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .voiceCallPrivacy(text):
                if case .voiceCallPrivacy(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .accountTimeout(text):
                if case .accountTimeout(text) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: PrivacyAndSecurityControllerArguments) -> ListViewItem {
        switch self {
            case .privacyHeader:
                return ItemListSectionHeaderItem(text: "PRIVACY", sectionId: self.section)
            case .blockedPeers:
                return ItemListDisclosureItem(title: "Blocked Users", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openBlockedUsers()
                })
            case let .lastSeenPrivacy(text):
                return ItemListDisclosureItem(title: "Last Seen", label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.openLastSeenPrivacy()
                })
            case let .groupPrivacy(text):
                return ItemListDisclosureItem(title: "Groups", label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.openGroupsPrivacy()
                })
            case let .voiceCallPrivacy(text):
                return ItemListDisclosureItem(title: "Voice Calls", label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.openVoiceCallPrivacy()
                })
            case .securityHeader:
                return ItemListSectionHeaderItem(text: "SECURITY", sectionId: self.section)
            case .passcode:
                return ItemListDisclosureItem(title: "Passcode Lock", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openPasscode()
                })
            case .twoStepVerification:
                return ItemListDisclosureItem(title: "Two-Step Verification", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openTwoStepVerification()
                })
            case .activeSessions:
                return ItemListDisclosureItem(title: "Active Sessions", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openActiveSessions()
                })
            case .accountHeader:
                return ItemListSectionHeaderItem(text: "DELETE MY ACCOUNT", sectionId: self.section)
            case let .accountTimeout(text):
                return ItemListDisclosureItem(title: "If Away For", label: text, sectionId: self.section, style: .blocks, action: {
                    arguments.setupAccountAutoremove()
                })
            case .accountInfo:
                return ItemListTextItem(text: "If you do not log in at least once within this period, your account will be deleted along with all groups, messages and contacts.", sectionId: self.section)
        }
    }
}

private struct PrivacyAndSecurityControllerState: Equatable {
    init() {
    }
    
    static func ==(lhs: PrivacyAndSecurityControllerState, rhs: PrivacyAndSecurityControllerState) -> Bool {
        return true
    }
}

private func privacyAndSecurityControllerEntries(state: PrivacyAndSecurityControllerState, privacySettings: AccountPrivacySettings?) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []
    
    entries.append(.privacyHeader)
    entries.append(.blockedPeers)
    entries.append(.lastSeenPrivacy(""))
    entries.append(.groupPrivacy(""))
    entries.append(.voiceCallPrivacy(""))
    
    entries.append(.securityHeader)
    entries.append(.passcode)
    entries.append(.twoStepVerification)
    entries.append(.activeSessions)
    entries.append(.accountHeader)
    entries.append(.accountTimeout(""))
    entries.append(.accountInfo)
    
    return entries
}

public func privacyAndSecurityController(account: Account) -> ViewController {
    let statePromise = ValuePromise(PrivacyAndSecurityControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PrivacyAndSecurityControllerState())
    let updateState: ((PrivacyAndSecurityControllerState) -> PrivacyAndSecurityControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let arguments = PrivacyAndSecurityControllerArguments(account: account, openBlockedUsers: {
        pushControllerImpl?(blockedPeersController(account: account))
    }, openLastSeenPrivacy: {
        
    }, openGroupsPrivacy: {
        
    }, openVoiceCallPrivacy: {
        
    }, openPasscode: {
        
    }, openTwoStepVerification: {
        
    }, openActiveSessions: {
        pushControllerImpl?(recentSessionsController(account: account))
    }, setupAccountAutoremove: {
        
    })
    
    let privacySettings: Signal<AccountPrivacySettings?, NoError> = .single(nil) |> then(updatedAccountPrivacySettings(account: account) |> map { Optional($0) })
        |> deliverOnMainQueue
    
    let signal = combineLatest(statePromise.get() |> deliverOnMainQueue, privacySettings)
        |> map { state, privacySettings -> (ItemListControllerState, (ItemListNodeState<PrivacyAndSecurityEntry>, PrivacyAndSecurityEntry.ItemGenerationArguments)) in
            
            var rightNavigationButton: ItemListNavigationButton?
            if privacySettings == nil {
                rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
            }
            
            let controllerState = ItemListControllerState(title: "Privacy and Security", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, animateChanges: false)
            let listState = ItemListNodeState(entries: privacyAndSecurityControllerEntries(state: state, privacySettings: privacySettings), style: .blocks, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    
    return controller
}
