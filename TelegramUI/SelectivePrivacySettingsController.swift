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
    
    let updateCallsP2PMode: ((VoiceCallP2PMode) -> Void)?
    let updateCallsIntegrationEnabled: ((Bool) -> Void)?
    
    init(account: Account, updateType: @escaping (SelectivePrivacySettingType) -> Void, openEnableFor: @escaping () -> Void, openDisableFor: @escaping () -> Void, updateCallsP2PMode: ((VoiceCallP2PMode) -> Void)?, updateCallsIntegrationEnabled: ((Bool) -> Void)?) {
        self.account = account
        self.updateType = updateType
        self.openEnableFor = openEnableFor
        self.openDisableFor = openDisableFor
        
        self.updateCallsP2PMode = updateCallsP2PMode
        self.updateCallsIntegrationEnabled = updateCallsIntegrationEnabled
    }
}

private enum SelectivePrivacySettingsSection: Int32 {
    case setting
    case peers
    case callsP2P
    case callsIntegrationEnabled
}

private func stringForUserCount(_ count: Int, strings: PresentationStrings) -> String {
    if count == 0 {
        return strings.PrivacyLastSeenSettings_EmpryUsersPlaceholder
    } else {
        return strings.UserCount(Int32(count))
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
    case callsP2PHeader(PresentationTheme, String)
    case callsP2PAlways(PresentationTheme, String, Bool)
    case callsP2PContacts(PresentationTheme, String, Bool)
    case callsP2PNever(PresentationTheme, String, Bool)
    case callsP2PInfo(PresentationTheme, String)
    case callsIntegrationEnabled(PresentationTheme, String, Bool)
    case callsIntegrationInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .settingHeader, .everybody, .contacts, .nobody, .settingInfo:
                return SelectivePrivacySettingsSection.setting.rawValue
            case .disableFor, .enableFor, .peersInfo:
                return SelectivePrivacySettingsSection.peers.rawValue
            case .callsP2PHeader, .callsP2PAlways, .callsP2PContacts, .callsP2PNever, .callsP2PInfo:
                return SelectivePrivacySettingsSection.callsP2P.rawValue
            case .callsIntegrationEnabled, .callsIntegrationInfo:
                return SelectivePrivacySettingsSection.callsIntegrationEnabled.rawValue
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
            case .callsP2PHeader:
                return 8
            case .callsP2PAlways:
                return 9
            case .callsP2PContacts:
                return 10
            case .callsP2PNever:
                return 11
            case .callsP2PInfo:
                return 12
            case .callsIntegrationEnabled:
                return 13
            case .callsIntegrationInfo:
                return 14
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
            case let .callsP2PHeader(lhsTheme, lhsText):
                if case let .callsP2PHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .callsP2PInfo(lhsTheme, lhsText):
                if case let .callsP2PInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .callsP2PAlways(lhsTheme, lhsText, lhsValue):
                if case let .callsP2PAlways(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsP2PContacts(lhsTheme, lhsText, lhsValue):
                if case let .callsP2PContacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsP2PNever(lhsTheme, lhsText, lhsValue):
                if case let .callsP2PNever(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsIntegrationEnabled(lhsTheme, lhsText, lhsValue):
                if case let .callsIntegrationEnabled(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsIntegrationInfo(lhsTheme, lhsText):
                if case let .callsIntegrationInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .callsP2PHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .callsP2PAlways(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCallsP2PMode?(.always)
                })
            case let .callsP2PContacts(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCallsP2PMode?(.contacts)
                })
            case let .callsP2PNever(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCallsP2PMode?(.never)
                })
            case let .callsP2PInfo(theme, text):
                    return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .callsIntegrationEnabled(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateCallsIntegrationEnabled?(value)
                })
            case let .callsIntegrationInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct SelectivePrivacySettingsControllerState: Equatable {
    let setting: SelectivePrivacySettingType
    let enableFor: Set<PeerId>
    let disableFor: Set<PeerId>
    
    let saving: Bool
    
    let callDataSaving: VoiceCallDataSaving?
    let callP2PMode: VoiceCallP2PMode?
    let callIntegrationAvailable: Bool?
    let callIntegrationEnabled: Bool?
    
    init(setting: SelectivePrivacySettingType, enableFor: Set<PeerId>, disableFor: Set<PeerId>, saving: Bool, callDataSaving: VoiceCallDataSaving?, callP2PMode: VoiceCallP2PMode?, callIntegrationAvailable: Bool?, callIntegrationEnabled: Bool?) {
        self.setting = setting
        self.enableFor = enableFor
        self.disableFor = disableFor
        self.saving = saving
        self.callDataSaving = callDataSaving
        self.callP2PMode = callP2PMode
        self.callIntegrationAvailable = callIntegrationAvailable
        self.callIntegrationEnabled = callIntegrationEnabled
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
        if lhs.callDataSaving != rhs.callDataSaving {
            return false
        }
        if lhs.callP2PMode != rhs.callP2PMode {
            return false
        }
        if lhs.callIntegrationAvailable != rhs.callIntegrationAvailable {
            return false
        }
        if lhs.callIntegrationEnabled != rhs.callIntegrationEnabled {
            return false
        }
        
        return true
    }
    
    func withUpdatedSetting(_ setting: SelectivePrivacySettingType) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedEnableFor(_ enableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedDisableFor(_ disableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedSaving(_ saving: Bool) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedCallsP2PMode(_ mode: VoiceCallP2PMode) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: mode, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedCallsIntegrationEnabled(_ enabled: Bool) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: enabled)
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
            entries.append(.disableFor(presentationData.theme, disableForText, stringForUserCount(state.disableFor.count, strings: presentationData.strings)))
        case .contacts:
            entries.append(.disableFor(presentationData.theme, disableForText, stringForUserCount(state.disableFor.count, strings: presentationData.strings)))
            entries.append(.enableFor(presentationData.theme, enableForText, stringForUserCount(state.enableFor.count, strings: presentationData.strings)))
        case .nobody:
            entries.append(.enableFor(presentationData.theme, enableForText, stringForUserCount(state.enableFor.count, strings: presentationData.strings)))
    }
    entries.append(.peersInfo(presentationData.theme, presentationData.strings.PrivacyLastSeenSettings_CustomShareSettingsHelp))
    
    if case .voiceCalls = kind, let p2pMode = state.callP2PMode, let integrationAvailable = state.callIntegrationAvailable, let integrationEnabled = state.callIntegrationEnabled  {
        entries.append(.callsP2PHeader(presentationData.theme, presentationData.strings.Privacy_Calls_P2P.uppercased()))
        
        entries.append(.callsP2PAlways(presentationData.theme, presentationData.strings.Privacy_Calls_P2PAlways, p2pMode == .always))
        entries.append(.callsP2PContacts(presentationData.theme, presentationData.strings.Privacy_Calls_P2PContacts, p2pMode == .contacts))
        entries.append(.callsP2PNever(presentationData.theme, presentationData.strings.Privacy_Calls_P2PNever, p2pMode == .never))
        
        entries.append(.callsP2PInfo(presentationData.theme, presentationData.strings.Privacy_Calls_P2PHelp))
        
        if integrationAvailable {
            entries.append(.callsIntegrationEnabled(presentationData.theme, presentationData.strings.Privacy_Calls_Integration, integrationEnabled))
            entries.append(.callsIntegrationInfo(presentationData.theme, presentationData.strings.Privacy_Calls_IntegrationHelp))
        }
    }
    
    return entries
}

func selectivePrivacySettingsController(account: Account, kind: SelectivePrivacySettingsKind, current: SelectivePrivacySettings, callSettings: VoiceCallSettings? = nil, voipConfiguration: VoipConfiguration? = nil, callIntegrationAvailable: Bool? = nil, updated: @escaping (SelectivePrivacySettings, VoiceCallSettings?) -> Void) -> ViewController {
    let strings = account.telegramApplicationContext.currentPresentationData.with { $0 }.strings
    
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
    let initialState = SelectivePrivacySettingsControllerState(setting: SelectivePrivacySettingType(current), enableFor: initialEnableFor, disableFor: initialDisableFor, saving: false, callDataSaving: callSettings?.dataSaving, callP2PMode: callSettings?.p2pMode ?? voipConfiguration?.defaultP2PMode, callIntegrationAvailable: callIntegrationAvailable, callIntegrationEnabled: callSettings?.enableSystemIntegration)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SelectivePrivacySettingsControllerState) -> SelectivePrivacySettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
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
                title = strings.PrivacyLastSeenSettings_AlwaysShareWith_Title
            case .groupInvitations:
                title = strings.Privacy_GroupsAndChannels_AlwaysAllow_Title
            case .voiceCalls:
                title = strings.Privacy_Calls_AlwaysAllow_Title
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
                title = strings.PrivacyLastSeenSettings_NeverShareWith_Title
            case .groupInvitations:
                title = strings.Privacy_GroupsAndChannels_NeverAllow_Title
            case .voiceCalls:
                title = strings.Privacy_Calls_NeverAllow_Title
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
    }, updateCallsP2PMode: { mode in
        updateState { state in
            return state.withUpdatedCallsP2PMode(mode)
        }
        let _ = updateVoiceCallSettingsSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.p2pMode = mode
            return settings
        }).start()
    }, updateCallsIntegrationEnabled: { enabled in
         updateState { state in
            return state.withUpdatedCallsIntegrationEnabled(enabled)
        }
        let _ = updateVoiceCallSettingsSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.enableSystemIntegration = enabled
            return settings
        }).start()
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
                            if case .voiceCalls = kind, let dataSaving = state.callDataSaving, let p2pMode = state.callP2PMode, let systemIntegrationEnabled = state.callIntegrationEnabled {
                                updated(settings, VoiceCallSettings(dataSaving: dataSaving, p2pMode: p2pMode, enableSystemIntegration: systemIntegrationEnabled))
                            } else {
                                updated(settings, nil)
                            }
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
    dismissImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    
    return controller
}
