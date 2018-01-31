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
    case settingHeader(PresentationTheme, String)
    case everybody(PresentationTheme, String, Bool)
    case contacts(PresentationTheme, String, Bool)
    case nobody(PresentationTheme, String, Bool)
    case settingInfo(PresentationTheme, String)
    case disableFor(PresentationTheme, String, String)
    case enableFor(PresentationTheme, String, String)
    case peersInfo(PresentationTheme, String)
    
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
            case let .settingHeader(lhsTheme, lhsText):
                if case let .settingHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .everybody(lhsTheme, lhsText, lhsValue):
                if case let .everybody(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .contacts(lhsTheme, lhsText, lhsValue):
                if case let .contacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .nobody(lhsTheme, lhsText, lhsValue):
                if case let nobody(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .settingInfo(lhsTheme, lhsText):
                if case let .settingInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .disableFor(lhsTheme, lhsText, lhsValue):
                if case let .disableFor(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .enableFor(lhsTheme, lhsText, lhsValue):
                if case let .enableFor(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .peersInfo(lhsTheme, lhsText):
                if case let .peersInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .settingHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .everybody(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.everybody)
                })
            case let .contacts(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.contacts)
                })
            case let .nobody(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.nobody)
                })
            case let .settingInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .disableFor(theme, title, value):
                return ItemListDisclosureItem(theme: theme, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openDisableFor()
                })
            case let .enableFor(theme, title, value):
                return ItemListDisclosureItem(theme: theme, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openEnableFor()
                })
            case let .peersInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
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

private func selectivePrivacySettingsControllerEntries(presentationData: PresentationData, kind: SelectivePrivacySettingsKind, state: SelectivePrivacySettingsControllerState) -> [SelectivePrivacySettingsEntry] {
    var entries: [SelectivePrivacySettingsEntry] = []
    
    let settingTitle: String
    let settingInfoText: String
    let disableForText: String
    let enableForText: String
    switch kind {
        case .presence:
            settingTitle = presentationData.strings.PrivacyLastSeenSettings_WhoCanSeeMyTimestamp
            settingInfoText = presentationData.strings.PrivacyLastSeenSettings_CustomHelp
            disableForText = presentationData.strings.PrivacyLastSeenSettings_NeverShareWith
            enableForText = presentationData.strings.PrivacyLastSeenSettings_AlwaysShareWith
        case .groupInvitations:
            settingTitle = presentationData.strings.Privacy_GroupsAndChannels_WhoCanAddMe
            settingInfoText = presentationData.strings.Privacy_GroupsAndChannels_CustomHelp
            disableForText = presentationData.strings.Privacy_GroupsAndChannels_NeverAllow
            enableForText = presentationData.strings.Privacy_GroupsAndChannels_AlwaysAllow
        case .voiceCalls:
            settingTitle = presentationData.strings.Privacy_Calls_WhoCanCallMe
            settingInfoText = presentationData.strings.Privacy_Calls_CustomHelp
            disableForText = presentationData.strings.Privacy_GroupsAndChannels_NeverAllow
            enableForText = presentationData.strings.Privacy_GroupsAndChannels_AlwaysAllow
    }
    
    entries.append(.settingHeader(presentationData.theme, settingTitle))
    
    entries.append(.everybody(presentationData.theme, presentationData.strings.PrivacySettings_LastSeenEverybody, state.setting == .everybody))
    entries.append(.contacts(presentationData.theme, presentationData.strings.PrivacySettings_LastSeenContacts, state.setting == .contacts))
    switch kind {
        case .presence, .voiceCalls:
            entries.append(.nobody(presentationData.theme, presentationData.strings.PrivacySettings_LastSeenNobody, state.setting == .nobody))
        case .groupInvitations:
            break
    }
    entries.append(.settingInfo(presentationData.theme, settingInfoText))
    
    switch state.setting {
        case .everybody:
            entries.append(.disableFor(presentationData.theme, disableForText, stringForUserCount(state.disableFor.count)))
        case .contacts:
            entries.append(.disableFor(presentationData.theme, disableForText, stringForUserCount(state.disableFor.count)))
            entries.append(.enableFor(presentationData.theme, enableForText, stringForUserCount(state.enableFor.count)))
        case .nobody:
            entries.append(.enableFor(presentationData.theme, enableForText, stringForUserCount(state.enableFor.count)))
    }
    entries.append(.peersInfo(presentationData.theme, presentationData.strings.PrivacyLastSeenSettings_CustomShareSettingsHelp))
    
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
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<SelectivePrivacySettingsEntry>, SelectivePrivacySettingsEntry.ItemGenerationArguments)) in
            
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            let rightNavigationButton: ItemListNavigationButton
            if state.saving {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
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
                    title = presentationData.strings.PrivacySettings_LastSeen
                case .groupInvitations:
                    title = presentationData.strings.Privacy_GroupsAndChannels
                case .voiceCalls:
                    title = presentationData.strings.Settings_CallSettings
            }
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: selectivePrivacySettingsControllerEntries(presentationData: presentationData, kind: kind, state: state), style: .blocks, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    dismissImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    
    return controller
}
