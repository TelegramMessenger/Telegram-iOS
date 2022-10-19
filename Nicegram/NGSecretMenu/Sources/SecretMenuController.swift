import AccountContext
import Display
import ItemListUI
import PresentationDataUtils
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import NGRemoteConfig

private final class SecretMenuControllerArguments {
    let setSkipReadHistory: (Bool) -> Void
    let setBypassCopyProtection: (Bool) -> Void
    let setBetaIcon: () -> Void

    init(setSkipReadHistory: @escaping (Bool) -> Void, setBypassCopyProtection: @escaping (Bool) -> Void, setBetaIcon: @escaping () -> Void) {
        self.setSkipReadHistory = setSkipReadHistory
        self.setBypassCopyProtection = setBypassCopyProtection
        self.setBetaIcon = setBetaIcon
    }
}

private enum SecretMenuControllerSection: Int32 {
    case main
}

private enum SecretMenuControllerEntry: ItemListNodeEntry {
    case skipReadHistory(String, Bool)
    case bypassCopyProtection(String, Bool)
    case setBetaIcon(String)
    
    var section: ItemListSectionId {
        switch self {
        case .skipReadHistory, .bypassCopyProtection, .setBetaIcon:
            return SecretMenuControllerSection.main.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .skipReadHistory:
            return 0
        case .bypassCopyProtection:
            return 1
        case .setBetaIcon:
            return 2
        }
    }
    
    static func < (lhs: SecretMenuControllerEntry, rhs: SecretMenuControllerEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SecretMenuControllerArguments
        switch self {
        case let .skipReadHistory(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks) { value in
                arguments.setSkipReadHistory(value)
            }
        case let .bypassCopyProtection(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks) { value in
                arguments.setBypassCopyProtection(value)
            }
        case let .setBetaIcon(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks) {
                arguments.setBetaIcon()
            }
        }
    }
}

private func secretMenuControllerEntries(experimentalSettings: ExperimentalUISettings) -> [SecretMenuControllerEntry] {
    var entries: [SecretMenuControllerEntry] = []
    
    entries.append(.skipReadHistory("Skip Read History", experimentalSettings.skipReadHistory))
    entries.append(.bypassCopyProtection("Bypass Copy Protection", getBypassCopyProtection()))
    entries.append(.setBetaIcon("Set Beta Icon"))
    
    return entries
}

public func secretMenuController(context: AccountContext) -> ViewController {
    let sharedContext = context.sharedContext
    
    let arguments = SecretMenuControllerArguments(
        setSkipReadHistory: { value in
            let _ = updateExperimentalUISettingsInteractively(accountManager: sharedContext.accountManager, { settings in
                var settings = settings
                settings.skipReadHistory = value
                return settings
            }).start()
        },
        setBypassCopyProtection: { value in
            setBypassCopyProtection(value)
        },
        setBetaIcon: {
            context.sharedContext.applicationBindings.requestSetAlternateIconName("NicegramBetaIcon", { _ in })
        }
    )
    
    let presentationData = sharedContext.presentationData
    let sharedData = sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.experimentalUISettings])
    
    let signal = combineLatest(presentationData, sharedData) |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let experimentalSettings: ExperimentalUISettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
        
        let entries = secretMenuControllerEntries(experimentalSettings: experimentalSettings)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Secret Menu"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    return controller
}

private struct SecretMenuConfig: Decodable {
    let users: [Int64]
}

public func canOpenSecretMenu(context: AccountContext) -> Bool {
    let remoteConfig = RemoteConfigServiceImpl.shared
    
    if let config = remoteConfig.get(SecretMenuConfig.self, byKey: "secretMenuConfig") {
        let userId = context.account.peerId.id._internalGetInt64Value()
        return config.users.contains(userId)
    } else {
        return false
    }
}
