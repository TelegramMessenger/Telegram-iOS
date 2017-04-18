import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum SelectivePrivacySettingsKind {
    case presence
    case groupInvitations
    case voiceCalls
}

private enum SelectivePrivacySettingType {
    case everybody
    case contacts
    case nobody
    
    init(_ setting: SelectivePrivacySettings) {
        switch setting {
            case .disableEveryone:
                self = .nobody
            case .enableContacts:
                self = .contacts
            case .enableEveryone:
                self = .everybody
        }
    }
}

private final class SelectivePrivacySettingsControllerArguments {
    let account: Account
    
    let updateType: (SelectivePrivacySettingType) -> Void
    let openEnableFor: () -> Void
    let openDisableFor: () -> Void
    
    init(account: Account, updateType: @escaping (SelectivePrivacySettingType) -> Void, openEnableFor: @escaping () -> Void, openDisableFor: @escaping () -> Void) {
        self.account = account
        self.updateType = updateType
        self.openEnableFor = openEnableFor
        self.openDisableFor = openDisableFor
    }
}

private enum SelectivePrivacySettingsSection: Int32 {
    case setting
    case peers
}

private func stringForUserCount(_ count: Int) -> String {
    if count == 0 {
        return "Add Users"
    } else if count == 1 {
        return "1 user"
    } else {
        return "\(count) users"
    }
}

private enum SelectivePrivacySettingsEntry: ItemListNodeEntry {
    case settingHeader(String)
    case everybody(Bool)
    case contacts(Bool)
    case nobody(Bool)
    case settingInfo(String)
    case disableFor(String, Int)
    case enableFor(String, Int)
    case peersInfo
    
    var section: ItemListSectionId {
        switch self {
            case .settingHeader, .everybody, .contacts, .nobody, .settingInfo:
                return SelectivePrivacySettingsSection.setting.rawValue
            case .disableFor, .enableFor, .peersInfo:
                return SelectivePrivacySettingsSection.peers.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .settingHeader:
                return 0
            case .everybody:
                return 1
            case .contacts:
                return 2
            case .nobody:
                return 3
            case .settingInfo:
                return 4
            case .disableFor:
                return 5
            case .enableFor:
                return 6
            case .peersInfo:
                return 7
        }
    }
    
    static func ==(lhs: SelectivePrivacySettingsEntry, rhs: SelectivePrivacySettingsEntry) -> Bool {
        switch lhs {
            case let .settingHeader(text):
                if case .settingHeader(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .everybody(value):
                if case .everybody(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .contacts(value):
                if case .contacts(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .nobody(value):
                if case .nobody(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .settingInfo(text):
                if case .settingInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .disableFor(title, count):
                if case .disableFor(title, count) = rhs {
                    return true
                } else {
                    return false
                }
            case let .enableFor(title, count):
                if case .enableFor(title, count) = rhs {
                    return true
                } else {
                    return false
                }
            case .peersInfo:
                if case .peersInfo = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: SelectivePrivacySettingsEntry, rhs: SelectivePrivacySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: SelectivePrivacySettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .settingHeader(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .everybody(value):
                return ItemListCheckboxItem(title: "Everybody", checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.everybody)
                })
            case let .contacts(value):
                return ItemListCheckboxItem(title: "My Contacts", checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.contacts)
                })
            case let .nobody(value):
                return ItemListCheckboxItem(title: "Nobody", checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.nobody)
                })
            case let .settingInfo(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
            case let .disableFor(title, count):
                return ItemListDisclosureItem(title: title, label: stringForUserCount(count), sectionId: self.section, style: .blocks, action: {
                    arguments.openDisableFor()
                })
            case let .enableFor(title, count):
                return ItemListDisclosureItem(title: title, label: stringForUserCount(count), sectionId: self.section, style: .blocks, action: {
                    arguments.openEnableFor()
                })
            case .peersInfo:
                return ItemListTextItem(text: .plain("These settings will override the values above."), sectionId: self.section)
        }
    }
}

private struct SelectivePrivacySettingsControllerState: Equatable {
    let setting: SelectivePrivacySettingType
    let enableFor: Set<PeerId>
    let disableFor: Set<PeerId>
    
    let saving: Bool
    
    init(setting: SelectivePrivacySettingType, enableFor: Set<PeerId>, disableFor: Set<PeerId>, saving: Bool) {
        self.setting = setting
        self.enableFor = enableFor
        self.disableFor = disableFor
        self.saving = saving
    }
    
    static func ==(lhs: SelectivePrivacySettingsControllerState, rhs: SelectivePrivacySettingsControllerState) -> Bool {
        if lhs.setting != rhs.setting {
            return false
        }
        if lhs.enableFor != rhs.enableFor {
            return false
        }
        if lhs.disableFor != rhs.disableFor {
            return false
        }
        if lhs.saving != rhs.saving {
            return false
        }
        
        return true
    }
    
    func withUpdatedSetting(_ setting: SelectivePrivacySettingType) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving)
    }
    
    func withUpdatedEnableFor(_ enableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: enableFor, disableFor: self.disableFor, saving: self.saving)
    }
    
    func withUpdatedDisableFor(_ disableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: disableFor, saving: self.saving)
    }
    
    func withUpdatedSaving(_ saving: Bool) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: saving)
    }
}

private func selectivePrivacySettingsControllerEntries(kind: SelectivePrivacySettingsKind, state: SelectivePrivacySettingsControllerState) -> [SelectivePrivacySettingsEntry] {
    var entries: [SelectivePrivacySettingsEntry] = []
    
    let settingTitle: String
    let settingInfoText: String
    let disableForText: String
    let enableForText: String
    switch kind {
        case .presence:
            settingTitle = "WHO CAN SEE MY TIMESTAMP"
            settingInfoText = "Important: you won't be able to see Last Seen times for people with whom you don't share your Last Seen time. Approximate last seen will be shown instead (recently, within a week, within a month)."
            disableForText = "Never Share With"
            enableForText = "Always Share With"
        case .groupInvitations:
            settingTitle = "WHO CAN ADD ME TO GROUP CHATS"
            settingInfoText = "You can restrict who can add you to groups and channels with granular precision."
            disableForText = "Never Allow"
            enableForText = "Always Allow"
        case .voiceCalls:
            settingTitle = "WHO CAN CALL ME"
            settingInfoText = "You can restrict who can call you with granular precision."
            disableForText = "Never Allow"
            enableForText = "Always Allow"
    }
    
    entries.append(.settingHeader(settingTitle))
    
    entries.append(.everybody(state.setting == .everybody))
    entries.append(.contacts(state.setting == .contacts))
    switch kind {
        case .presence, .voiceCalls:
            entries.append(.nobody(state.setting == .nobody))
        case .groupInvitations:
            break
    }
    entries.append(.settingInfo(settingInfoText))
    
    switch state.setting {
        case .everybody:
            entries.append(.disableFor(disableForText, state.disableFor.count))
        case .contacts:
            entries.append(.disableFor(disableForText, state.disableFor.count))
            entries.append(.enableFor(enableForText, state.enableFor.count))
        case .nobody:
            entries.append(.enableFor(enableForText, state.enableFor.count))
    }
    entries.append(.peersInfo)
    
    return entries
}

func selectivePrivacySettingsController(account: Account, kind: SelectivePrivacySettingsKind, current: SelectivePrivacySettings, updated: @escaping (SelectivePrivacySettings) -> Void) -> ViewController {
    var initialEnableFor = Set<PeerId>()
    var initialDisableFor = Set<PeerId>()
    switch current {
        case let .disableEveryone(enableFor):
            initialEnableFor = enableFor
        case let .enableContacts(enableFor, disableFor):
            initialEnableFor = enableFor
            initialDisableFor = disableFor
        case let .enableEveryone(disableFor):
            initialDisableFor = disableFor
    }
    let initialState = SelectivePrivacySettingsControllerState(setting: SelectivePrivacySettingType(current), enableFor: initialEnableFor, disableFor: initialDisableFor, saving: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SelectivePrivacySettingsControllerState) -> SelectivePrivacySettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateSettingsDisposable = MetaDisposable()
    actionsDisposable.add(updateSettingsDisposable)
    
    let arguments = SelectivePrivacySettingsControllerArguments(account: account, updateType: { type in
        updateState {
            $0.withUpdatedSetting(type)
        }
    }, openEnableFor: {
        let title: String
        switch kind {
            case .presence:
                title = "Always Share With"
            case .groupInvitations:
                title = "Always Allow"
            case .voiceCalls:
                title = "Always Allow"
        }
        var peerIds = Set<PeerId>()
        updateState { state in
            peerIds = state.enableFor
            return state
        }
        pushControllerImpl?(selectivePrivacyPeersController(account: account, title: title, initialPeerIds: Array(peerIds), updated: { updatedPeerIds in
            updateState { state in
                return state.withUpdatedEnableFor(Set(updatedPeerIds)).withUpdatedDisableFor(state.disableFor.subtracting(Set(updatedPeerIds)))
            }
        }))
    }, openDisableFor: {
        let title: String
        switch kind {
            case .presence:
                title = "Never Share With"
            case .groupInvitations:
                title = "Never Allow"
            case .voiceCalls:
                title = "Never Allow"
        }
        var peerIds = Set<PeerId>()
        updateState { state in
            peerIds = state.disableFor
            return state
        }
        pushControllerImpl?(selectivePrivacyPeersController(account: account, title: title, initialPeerIds: Array(peerIds), updated: { updatedPeerIds in
            updateState { state in
                return state.withUpdatedDisableFor(Set(updatedPeerIds)).withUpdatedEnableFor(state.enableFor.subtracting(Set(updatedPeerIds)))
            }
        }))
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue
        |> map { state -> (ItemListControllerState, (ItemListNodeState<SelectivePrivacySettingsEntry>, SelectivePrivacySettingsEntry.ItemGenerationArguments)) in
            
            let leftNavigationButton = ItemListNavigationButton(title: "Cancel", style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            let rightNavigationButton: ItemListNavigationButton
            if state.saving {
                rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: true, action: {
                    var wasSaving = false
                    var settings: SelectivePrivacySettings?
                    updateState { state in
                        wasSaving = state.saving
                        switch state.setting {
                            case .everybody:
                                settings = SelectivePrivacySettings.enableEveryone(disableFor: state.disableFor)
                            case .contacts:
                                settings = SelectivePrivacySettings.enableContacts(enableFor: state.enableFor, disableFor: state.disableFor)
                            case .nobody:
                                settings = SelectivePrivacySettings.disableEveryone(enableFor: state.enableFor)
                        }
                        return state.withUpdatedSaving(true)
                    }
                    
                    if let settings = settings, !wasSaving {
                        let type: UpdateSelectiveAccountPrivacySettingsType
                        switch kind {
                            case .presence:
                                type = .presence
                            case .groupInvitations:
                                type = .groupInvitations
                            case .voiceCalls:
                                type = .voiceCalls
                        }
                        
                        updateSettingsDisposable.set((updateSelectiveAccountPrivacySettings(account: account, type: type, settings: settings) |> deliverOnMainQueue).start(completed: {
                            updateState { state in
                                return state.withUpdatedSaving(false)
                            }
                            updated(settings)
                            dismissImpl?()
                        }))
                    }
                })
            }
            
            let title: String
            switch kind {
                case .presence:
                    title = "Last Seen"
                case .groupInvitations:
                    title = "Groups"
                case .voiceCalls:
                    title = "Voice Calls"
            }
            let controllerState = ItemListControllerState(title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, animateChanges: false)
            let listState = ItemListNodeState(entries: selectivePrivacySettingsControllerEntries(kind: kind, state: state), style: .blocks, animateChanges: false)
            
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
        controller?.present(c, in: .window)
    }
    dismissImpl = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    
    return controller
}
