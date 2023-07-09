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
    let switchSuppressForeignAgentNotice: (Bool) -> Void
    let switchEnableForeignAgentNoticeSearchFiltering: (Bool) -> Void
    let switchEnableLiveText: (Bool) -> Void
    let switchPreferAppleVoiceToText: (Bool) -> Void
    
    init(switchShowPeerId: @escaping (Bool) -> Void, switchSuppressForeignAgentNotice: @escaping (Bool) -> Void, switchEnableForeignAgentNoticeSearchFiltering: @escaping (Bool) -> Void, switchEnableLiveText: @escaping (Bool) -> Void, switchPreferAppleVoiceToText: @escaping (Bool) -> Void) {
        self.switchShowPeerId = switchShowPeerId
        self.switchSuppressForeignAgentNotice = switchSuppressForeignAgentNotice
        self.switchEnableForeignAgentNoticeSearchFiltering = switchEnableForeignAgentNoticeSearchFiltering
        self.switchEnableLiveText = switchEnableLiveText
        self.switchPreferAppleVoiceToText = switchPreferAppleVoiceToText
    }
}

private enum PtgSettingsSection: Int32 {
    case showPeerId
    case foreignAgentNotice
    case liveText
    case preferAppleVoiceToText
}

private enum PtgSettingsEntry: ItemListNodeEntry {
    case showPeerId(String, Bool)
    case showPeerIdInfo(String)
    
    case foreignAgentNoticeHeader(String)
    case suppressForeignAgentNotice(String, Bool)
    case enableForeignAgentNoticeSearchFiltering(String, Bool, Bool)
    case enableForeignAgentNoticeSearchFilteringInfo(String)

    case enableLiveText(String, Bool)
    case enableLiveTextInfo(String)
    
    case preferAppleVoiceToText(String, Bool, Bool)
    case preferAppleVoiceToTextInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .showPeerId, .showPeerIdInfo:
            return PtgSettingsSection.showPeerId.rawValue
        case .foreignAgentNoticeHeader, .suppressForeignAgentNotice, .enableForeignAgentNoticeSearchFiltering, .enableForeignAgentNoticeSearchFilteringInfo:
            return PtgSettingsSection.foreignAgentNotice.rawValue
        case .enableLiveText, .enableLiveTextInfo:
            return PtgSettingsSection.liveText.rawValue
        case .preferAppleVoiceToText, .preferAppleVoiceToTextInfo:
            return PtgSettingsSection.preferAppleVoiceToText.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .showPeerId:
            return 0
        case .showPeerIdInfo:
            return 1
        case .enableLiveText:
            return 2
        case .enableLiveTextInfo:
            return 3
        case .preferAppleVoiceToText:
            return 4
        case .preferAppleVoiceToTextInfo:
            return 5
        case .foreignAgentNoticeHeader:
            return 6
        case .suppressForeignAgentNotice:
            return 7
        case .enableForeignAgentNoticeSearchFiltering:
            return 8
        case .enableForeignAgentNoticeSearchFilteringInfo:
            return 9
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
        case let .foreignAgentNoticeHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .suppressForeignAgentNotice(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchSuppressForeignAgentNotice(updatedValue)
            })
        case let .enableForeignAgentNoticeSearchFiltering(title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchEnableForeignAgentNoticeSearchFiltering(updatedValue)
            })
        case let .enableLiveText(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchEnableLiveText(updatedValue)
            })
        case let .showPeerIdInfo(text), let .enableForeignAgentNoticeSearchFilteringInfo(text), let .enableLiveTextInfo(text), let .preferAppleVoiceToTextInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .preferAppleVoiceToText(title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchPreferAppleVoiceToText(updatedValue)
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
    entries.append(.showPeerIdInfo(presentationData.strings.PtgSettings_ShowPeerIdHelp))
    
    entries.append(.enableLiveText(presentationData.strings.PtgSettings_EnableLiveText, !experimentalSettings.disableImageContentAnalysis))
    entries.append(.enableLiveTextInfo(presentationData.strings.PtgSettings_EnableLiveTextHelp))

    if experimentalSettings.localTranscription {
        entries.append(.preferAppleVoiceToText(presentationData.strings.PtgSettings_PreferAppleVoiceToText, settings.preferAppleVoiceToText || !hasPremiumAccounts, hasPremiumAccounts))
        entries.append(.preferAppleVoiceToTextInfo(presentationData.strings.PtgSettings_PreferAppleVoiceToTextHelp))
    }
    
    entries.append(.foreignAgentNoticeHeader(presentationData.strings.PtgSettings_ForeignAgentNoticeHeader.uppercased()))
    entries.append(.suppressForeignAgentNotice(presentationData.strings.PtgSettings_SuppressForeignAgentNotice, settings.suppressForeignAgentNotice))
    entries.append(.enableForeignAgentNoticeSearchFiltering(presentationData.strings.PtgSettings_EnableForeignAgentNoticeSearchFiltering, settings.enableForeignAgentNoticeSearchFiltering, settings.suppressForeignAgentNotice))
    entries.append(.enableForeignAgentNoticeSearchFilteringInfo(presentationData.strings.PtgSettings_EnableForeignAgentNoticeSearchFilteringHelp))
    
    return entries
}

public func ptgSettingsController(context: AccountContext) -> ViewController {
    let statePromise = Promise<PtgSettingsState>()
    statePromise.set(context.sharedContext.accountManager.transaction { transaction in
        return PtgSettingsState(settings: PtgSettings(transaction))
    })
    
    let arguments = PtgSettingsControllerArguments(switchShowPeerId: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(showPeerId: value)
        }
    }, switchSuppressForeignAgentNotice: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(suppressForeignAgentNotice: value)
        }
    }, switchEnableForeignAgentNoticeSearchFiltering: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(enableForeignAgentNoticeSearchFiltering: value)
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
        return PtgSettings(showPeerId: showPeerId, suppressForeignAgentNotice: self.suppressForeignAgentNotice, enableForeignAgentNoticeSearchFiltering: self.enableForeignAgentNoticeSearchFiltering, preferAppleVoiceToText: self.preferAppleVoiceToText, isTestingEnvironment: self.isTestingEnvironment)
    }
    
    public func withUpdated(suppressForeignAgentNotice: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, suppressForeignAgentNotice: suppressForeignAgentNotice, enableForeignAgentNoticeSearchFiltering: self.enableForeignAgentNoticeSearchFiltering, preferAppleVoiceToText: self.preferAppleVoiceToText, isTestingEnvironment: self.isTestingEnvironment)
    }
    
    public func withUpdated(enableForeignAgentNoticeSearchFiltering: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, suppressForeignAgentNotice: self.suppressForeignAgentNotice, enableForeignAgentNoticeSearchFiltering: enableForeignAgentNoticeSearchFiltering, preferAppleVoiceToText: self.preferAppleVoiceToText, isTestingEnvironment: self.isTestingEnvironment)
    }
    
    public func withUpdated(preferAppleVoiceToText: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, suppressForeignAgentNotice: self.suppressForeignAgentNotice, enableForeignAgentNoticeSearchFiltering: self.enableForeignAgentNoticeSearchFiltering, preferAppleVoiceToText: preferAppleVoiceToText, isTestingEnvironment: self.isTestingEnvironment)
    }
    
    public func withUpdated(isTestingEnvironment: Bool?) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, suppressForeignAgentNotice: self.suppressForeignAgentNotice, enableForeignAgentNoticeSearchFiltering: self.enableForeignAgentNoticeSearchFiltering, preferAppleVoiceToText: self.preferAppleVoiceToText, isTestingEnvironment: isTestingEnvironment)
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
