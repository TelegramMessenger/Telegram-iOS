import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountUtils
import PresentationDataUtils
import PtgSettings

private final class PtgSettingsControllerArguments {
    let switchShowPeerId: (Bool) -> Void
    let switchShowChannelCreationDate: (Bool) -> Void
    let switchSuppressForeignAgentNotice: (Bool) -> Void
    let switchEnableLiveText: (Bool) -> Void
    let switchPreferAppleVoiceToText: (Bool) -> Void
    let changeDefaultCameraForVideos: () -> Void
    
    init(switchShowPeerId: @escaping (Bool) -> Void, switchShowChannelCreationDate: @escaping (Bool) -> Void, switchSuppressForeignAgentNotice: @escaping (Bool) -> Void, switchEnableLiveText: @escaping (Bool) -> Void, switchPreferAppleVoiceToText: @escaping (Bool) -> Void, changeDefaultCameraForVideos: @escaping () -> Void) {
        self.switchShowPeerId = switchShowPeerId
        self.switchShowChannelCreationDate = switchShowChannelCreationDate
        self.switchSuppressForeignAgentNotice = switchSuppressForeignAgentNotice
        self.switchEnableLiveText = switchEnableLiveText
        self.switchPreferAppleVoiceToText = switchPreferAppleVoiceToText
        self.changeDefaultCameraForVideos = changeDefaultCameraForVideos
    }
}

private enum PtgSettingsSection: Int32 {
    case showProfileData
    case foreignAgentNotice
    case liveText
    case preferAppleVoiceToText
    case defaultCameraForVideos
}

private enum PtgSettingsEntry: ItemListNodeEntry {
    case showPeerId(String, Bool)
    case showChannelCreationDate(String, Bool)
    
    case suppressForeignAgentNotice(String, Bool)

    case enableLiveText(String, Bool)
    case enableLiveTextInfo(String)
    
    case preferAppleVoiceToText(String, Bool, Bool)
    case preferAppleVoiceToTextInfo(String)

    case defaultCameraForVideos(String, String)
    
    var section: ItemListSectionId {
        switch self {
        case .showPeerId, .showChannelCreationDate:
            return PtgSettingsSection.showProfileData.rawValue
        case .suppressForeignAgentNotice:
            return PtgSettingsSection.foreignAgentNotice.rawValue
        case .enableLiveText, .enableLiveTextInfo:
            return PtgSettingsSection.liveText.rawValue
        case .preferAppleVoiceToText, .preferAppleVoiceToTextInfo:
            return PtgSettingsSection.preferAppleVoiceToText.rawValue
        case .defaultCameraForVideos:
            return PtgSettingsSection.defaultCameraForVideos.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .showPeerId:
            return 0
        case .showChannelCreationDate:
            return 1
        case .defaultCameraForVideos:
            return 2
        case .enableLiveText:
            return 3
        case .enableLiveTextInfo:
            return 4
        case .preferAppleVoiceToText:
            return 5
        case .preferAppleVoiceToTextInfo:
            return 6
        case .suppressForeignAgentNotice:
            return 7
        }
    }
    
    static func <(lhs: PtgSettingsEntry, rhs: PtgSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PtgSettingsControllerArguments
        switch self {
        case let .showPeerId(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchShowPeerId(updatedValue)
            })
        case let .showChannelCreationDate(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchShowChannelCreationDate(updatedValue)
            })
        case let .suppressForeignAgentNotice(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchSuppressForeignAgentNotice(updatedValue)
            })
        case let .enableLiveText(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchEnableLiveText(updatedValue)
            })
        case let .enableLiveTextInfo(text), let .preferAppleVoiceToTextInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .preferAppleVoiceToText(title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchPreferAppleVoiceToText(updatedValue)
            })
        case let .defaultCameraForVideos(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.changeDefaultCameraForVideos()
            })
        }
    }
}

private struct PtgSettingsState: Equatable {
    let settings: PtgSettings

    func withUpdatedSettings(_ settings: PtgSettings) -> PtgSettingsState {
        return PtgSettingsState(settings: settings)
    }
}

private func ptgSettingsControllerEntries(presentationData: PresentationData, settings: PtgSettings, experimentalSettings: ExperimentalUISettings, hasPremiumAccounts: Bool) -> [PtgSettingsEntry] {
    var entries: [PtgSettingsEntry] = []
    
    entries.append(.showPeerId(presentationData.strings.PtgSettings_ShowPeerId, settings.showPeerId))
    entries.append(.showChannelCreationDate(presentationData.strings.PtgSettings_ShowChannelCreationDate, settings.showChannelCreationDate))
    
    entries.append(.defaultCameraForVideos(presentationData.strings.PtgSettings_DefaultCameraForVideos, settings.useRearCameraByDefault ? presentationData.strings.PtgSettings_DefaultCameraForVideos_Rear : presentationData.strings.PtgSettings_DefaultCameraForVideos_Front))
    
    entries.append(.enableLiveText(presentationData.strings.PtgSettings_EnableLiveText, !experimentalSettings.disableImageContentAnalysis))
    entries.append(.enableLiveTextInfo(presentationData.strings.PtgSettings_EnableLiveTextHelp))

    if experimentalSettings.localTranscription {
        entries.append(.preferAppleVoiceToText(presentationData.strings.PtgSettings_PreferAppleVoiceToText, settings.preferAppleVoiceToText || !hasPremiumAccounts, hasPremiumAccounts))
        entries.append(.preferAppleVoiceToTextInfo(presentationData.strings.PtgSettings_PreferAppleVoiceToTextHelp))
    }
    
    entries.append(.suppressForeignAgentNotice(presentationData.strings.PtgSettings_SuppressForeignAgentNotice, settings.suppressForeignAgentNotice))
    
    return entries
}

public func ptgSettingsController(context: AccountContext) -> ViewController {
    let statePromise = Promise<PtgSettingsState>()
    statePromise.set(context.sharedContext.accountManager.transaction { transaction in
        return PtgSettingsState(settings: PtgSettings(transaction))
    })
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let arguments = PtgSettingsControllerArguments(switchShowPeerId: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(showPeerId: value)
        }
    }, switchShowChannelCreationDate: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(showChannelCreationDate: value)
        }
    }, switchSuppressForeignAgentNotice: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(suppressForeignAgentNotice: value)
        }
    }, switchEnableLiveText: { value in
        let _ = context.sharedContext.accountManager.transaction({ transaction in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                settings.disableImageContentAnalysis = !value
                return PreferencesEntry(settings)
            })
        }).start()
    }, switchPreferAppleVoiceToText: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(preferAppleVoiceToText: value)
        }
    }, changeDefaultCameraForVideos: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        
        for value in [false, true] {
            items.append(ActionSheetButtonItem(title: value ? presentationData.strings.PtgSettings_DefaultCameraForVideos_Rear : presentationData.strings.PtgSettings_DefaultCameraForVideos_Front, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                updateSettings(context, statePromise) { settings in
                    return settings.withUpdated(useRearCameraByDefault: value)
                }
            }))
        }
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
    
    let hasPremiumAccounts = combineLatest(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)), activeAccountsAndPeers(context: context))
    |> map { accountPeer, accountsAndPeers -> Bool in
        if accountPeer?.isPremium == true && !context.account.testingEnvironment {
            return true
        }
        for (accountContext, peer, _) in accountsAndPeers.1 {
            if peer.isPremium && !accountContext.account.testingEnvironment {
                return true
            }
        }
        return false
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.experimentalUISettings]), hasPremiumAccounts)
    |> deliverOnMainQueue
    |> map { presentationData, state, sharedData, hasPremiumAccounts -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let experimentalSettings: ExperimentalUISettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PtgSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ptgSettingsControllerEntries(presentationData: presentationData, settings: state.settings, experimentalSettings: experimentalSettings, hasPremiumAccounts: hasPremiumAccounts), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    presentControllerImpl = { [weak controller] c, p in
        controller?.present(c, in: .window(.root), with: p)
    }
    
    return controller
}

private func updateSettings(_ context: AccountContext, _ statePromise: Promise<PtgSettingsState>, _ f: @escaping (PtgSettings) -> PtgSettings) {
    let _ = (statePromise.get() |> take(1)).start(next: { [weak statePromise] state in
        let updatedSettings = f(state.settings)
        statePromise?.set(.single(state.withUpdatedSettings(updatedSettings)))
        
        let _ = context.sharedContext.accountManager.transaction({ transaction -> Void in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.ptgSettings, { _ in
                return PreferencesEntry(updatedSettings)
            })
        }).start()
    })
}

extension PtgSettings {
    public func withUpdated(showPeerId: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, preferAppleVoiceToText: self.preferAppleVoiceToText, useRearCameraByDefault: self.useRearCameraByDefault, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(showChannelCreationDate: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, preferAppleVoiceToText: self.preferAppleVoiceToText, useRearCameraByDefault: self.useRearCameraByDefault, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(suppressForeignAgentNotice: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: suppressForeignAgentNotice, preferAppleVoiceToText: self.preferAppleVoiceToText, useRearCameraByDefault: self.useRearCameraByDefault, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(preferAppleVoiceToText: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, preferAppleVoiceToText: preferAppleVoiceToText, useRearCameraByDefault: self.useRearCameraByDefault, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(useRearCameraByDefault: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, preferAppleVoiceToText: self.preferAppleVoiceToText, useRearCameraByDefault: useRearCameraByDefault, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(testToolsEnabled: Bool?) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, preferAppleVoiceToText: self.preferAppleVoiceToText, useRearCameraByDefault: self.useRearCameraByDefault, testToolsEnabled: testToolsEnabled)
    }
}

extension PtgAccountSettings {
    public func withUpdated(ignoreAllContentRestrictions: Bool) -> PtgAccountSettings {
        return PtgAccountSettings(ignoreAllContentRestrictions: ignoreAllContentRestrictions)
    }
}

public func updatePtgAccountSettings(engine: TelegramEngine, _ f: @escaping (PtgAccountSettings) -> PtgAccountSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.ptgAccountSettings, { entry in
        return PreferencesEntry(f(PtgAccountSettings(entry)))
    })
}
