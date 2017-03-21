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
                return ItemListTextItem(text: .plain("If you do not log in at least once within this period, your account will be deleted along with all groups, messages and contacts."), sectionId: self.section)
        }
    }
}

private struct PrivacyAndSecurityControllerState: Equatable {
    let updatingAccountTimeoutValue: Int32?
    
    init() {
        self.updatingAccountTimeoutValue = nil
    }
    
    init(updatingAccountTimeoutValue: Int32?) {
        self.updatingAccountTimeoutValue = updatingAccountTimeoutValue
    }
    
    static func ==(lhs: PrivacyAndSecurityControllerState, rhs: PrivacyAndSecurityControllerState) -> Bool {
        if lhs.updatingAccountTimeoutValue != rhs.updatingAccountTimeoutValue {
            return false
        }
        
        return true
    }
    
    func withUpdatedUpdatingAccountTimeoutValue(_ updatingAccountTimeoutValue: Int32?) -> PrivacyAndSecurityControllerState {
        return PrivacyAndSecurityControllerState(updatingAccountTimeoutValue: updatingAccountTimeoutValue)
    }
}

private func stringForSelectiveSettings(_ settings: SelectivePrivacySettings) -> String {
    switch settings {
        case let .disableEveryone(enableFor):
            if enableFor.isEmpty {
                return "Nobody"
            } else {
                return "Nobody (+\(enableFor.count))"
            }
        case let .enableEveryone(disableFor):
            if disableFor.isEmpty {
                return "Everybody"
            } else {
                return "Everybody (-\(disableFor.count))"
            }
        case let .enableContacts(enableFor, disableFor):
            if !enableFor.isEmpty && !disableFor.isEmpty {
                return "My Contacts (+\(enableFor.count), -\(disableFor.count))"
            } else if !enableFor.isEmpty {
                return "My Contacts (+\(enableFor.count))"
            } else if !disableFor.isEmpty {
                return "My Contacts (-\(disableFor.count))"
            } else {
                return "My Contacts"
            }
    }
}

private func stringForAccountTimeout(_ timeout: Int32) -> String {
    if timeout <= 1 * 31 * 24 * 60 * 60 {
        return "1 month"
    } else if timeout <= 3 * 31 * 24 * 60 * 60 {
        return "3 months"
    } else if timeout <= 6 * 31 * 24 * 60 * 60 {
        return "6 months"
    } else {
        return "1 year"
    }
}

private func privacyAndSecurityControllerEntries(state: PrivacyAndSecurityControllerState, privacySettings: AccountPrivacySettings?) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []
    
    entries.append(.privacyHeader)
    entries.append(.blockedPeers)
    if let privacySettings = privacySettings {
        entries.append(.lastSeenPrivacy(stringForSelectiveSettings(privacySettings.presence)))
        entries.append(.groupPrivacy(stringForSelectiveSettings(privacySettings.groupInvitations)))
        entries.append(.voiceCallPrivacy(stringForSelectiveSettings(privacySettings.voiceCalls)))
    } else {
        entries.append(.lastSeenPrivacy("Loading"))
        entries.append(.groupPrivacy("Loading"))
        entries.append(.voiceCallPrivacy("Loading"))
    }
    
    entries.append(.securityHeader)
    entries.append(.passcode)
    entries.append(.twoStepVerification)
    entries.append(.activeSessions)
    entries.append(.accountHeader)
    if let privacySettings = privacySettings {
        let value: Int32
        if let updatingAccountTimeoutValue = state.updatingAccountTimeoutValue {
            value = updatingAccountTimeoutValue
        } else {
            value = privacySettings.accountRemovalTimeout
        }
        entries.append(.accountTimeout(stringForAccountTimeout(value)))
    } else {
        entries.append(.accountTimeout("Loading"))
    }
    entries.append(.accountInfo)
    
    return entries
}

public func privacyAndSecurityController(account: Account, initialSettings: Signal<AccountPrivacySettings?, NoError>) -> ViewController {
    let statePromise = ValuePromise(PrivacyAndSecurityControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PrivacyAndSecurityControllerState())
    let updateState: ((PrivacyAndSecurityControllerState) -> PrivacyAndSecurityControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let currentInfoDisposable = MetaDisposable()
    actionsDisposable.add(currentInfoDisposable)
    
    let updateAccountTimeoutDisposable = MetaDisposable()
    actionsDisposable.add(updateAccountTimeoutDisposable)
    
    let privacySettingsPromise = Promise<AccountPrivacySettings?>()
    privacySettingsPromise.set(initialSettings)
    
    let arguments = PrivacyAndSecurityControllerArguments(account: account, openBlockedUsers: {
        pushControllerImpl?(blockedPeersController(account: account))
    }, openLastSeenPrivacy: {
        let signal = privacySettingsPromise.get()
            |> take(1)
            |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(account: account, kind: .presence, current: info.presence, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: updated, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, accountRemovalTimeout: value.accountRemovalTimeout)))
                                }
                                return .complete()
                            }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }))
            }
        }))
    }, openGroupsPrivacy: {
        let signal = privacySettingsPromise.get()
            |> take(1)
            |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(account: account, kind: .groupInvitations, current: info.groupInvitations, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: updated, voiceCalls: value.voiceCalls, accountRemovalTimeout: value.accountRemovalTimeout)))
                                }
                                return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }))
            }
        }))
    }, openVoiceCallPrivacy: {
        let signal = privacySettingsPromise.get()
            |> take(1)
            |> deliverOnMainQueue
        currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info in
            if let info = info {
                pushControllerImpl?(selectivePrivacySettingsController(account: account, kind: .voiceCalls, current: info.voiceCalls, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: updated, accountRemovalTimeout: value.accountRemovalTimeout)))
                                }
                                return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }))
            }
        }))
    }, openPasscode: {
        
    }, openTwoStepVerification: {
        pushControllerImpl?(twoStepVerificationUnlockSettingsController(account: account, mode: .access))
    }, openActiveSessions: {
        pushControllerImpl?(recentSessionsController(account: account))
    }, setupAccountAutoremove: {
        let signal = privacySettingsPromise.get()
            |> take(1)
            |> deliverOnMainQueue
        updateAccountTimeoutDisposable.set(signal.start(next: { [weak updateAccountTimeoutDisposable] privacySettingsValue in
            if let _ = privacySettingsValue {
                let controller = ActionSheetController()
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                let timeoutAction: (Int32) -> Void = { timeout in
                    if let updateAccountTimeoutDisposable = updateAccountTimeoutDisposable {
                        updateState {
                            return $0.withUpdatedUpdatingAccountTimeoutValue(timeout)
                        }
                        let applyTimeout: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> filter { $0 != nil }
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { value -> Signal<Void, NoError> in
                                if let value = value {
                                    privacySettingsPromise.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, accountRemovalTimeout: timeout)))
                                }
                                return .complete()
                            }
                        updateAccountTimeoutDisposable.set((updateAccountRemovalTimeout(account: account, timeout: timeout)
                            |> then(applyTimeout)
                            |> deliverOnMainQueue).start(completed: {
                                updateState {
                                    return $0.withUpdatedUpdatingAccountTimeoutValue(nil)
                                }
                            }))
                    }
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: "1 month", action: {
                            dismissAction()
                            timeoutAction(1 * 30 * 24 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "3 months", action: {
                            dismissAction()
                            timeoutAction(3 * 30 * 24 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "6 months", action: {
                            dismissAction()
                            timeoutAction(6 * 30 * 24 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "1 year", action: {
                            dismissAction()
                            timeoutAction(12 * 30 * 24 * 60 * 60)
                        }),
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
                ])
                presentControllerImpl?(controller)
            }
        }))
    })
    
    let signal = combineLatest(statePromise.get() |> deliverOnMainQueue, privacySettingsPromise.get())
        |> map { state, privacySettings -> (ItemListControllerState, (ItemListNodeState<PrivacyAndSecurityEntry>, PrivacyAndSecurityEntry.ItemGenerationArguments)) in
            
            var rightNavigationButton: ItemListNavigationButton?
            if privacySettings == nil || state.updatingAccountTimeoutValue != nil {
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
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window, with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    return controller
}
