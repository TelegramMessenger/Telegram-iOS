import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class DebugControllerArguments {
    let account: Account
    let accountManager: AccountManager
    let presentController: (ViewController, ViewControllerPresentationArguments) -> Void
    let pushController: (ViewController) -> Void
    
    init(account: Account, accountManager: AccountManager, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, pushController: @escaping (ViewController) -> Void) {
        self.account = account
        self.accountManager = accountManager
        self.presentController = presentController
        self.pushController = pushController
    }
}

private enum DebugControllerSection: Int32 {
    case logs
    case payments
    case logging
    case experiments
}

private enum DebugControllerEntry: ItemListNodeEntry {
    case sendLogs(PresentationTheme)
    case accounts(PresentationTheme)
    case clearPaymentData(PresentationTheme)
    case logToFile(PresentationTheme, Bool)
    case logToConsole(PresentationTheme, Bool)
    case redactSensitiveData(PresentationTheme, Bool)
    case enableRaiseToSpeak(PresentationTheme, Bool)
    case keepChatNavigationStack(PresentationTheme, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .sendLogs:
                return DebugControllerSection.logs.rawValue
            case .accounts:
                return DebugControllerSection.logs.rawValue
            case .clearPaymentData:
                return DebugControllerSection.payments.rawValue
            case .logToFile, .logToConsole, .redactSensitiveData:
                return DebugControllerSection.logging.rawValue
            case .enableRaiseToSpeak, .keepChatNavigationStack:
                return DebugControllerSection.experiments.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .sendLogs:
                return 0
            case .accounts:
                return 1
            case .clearPaymentData:
                return 2
            case .logToFile:
                return 3
            case .logToConsole:
                return 4
            case .redactSensitiveData:
                return 5
            case .enableRaiseToSpeak:
                return 6
            case .keepChatNavigationStack:
                return 7
        }
    }
    
    static func ==(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        switch lhs {
            case let .sendLogs(lhsTheme):
                if case let .sendLogs(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .accounts(lhsTheme):
                if case let .accounts(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .clearPaymentData(lhsTheme):
                if case let .clearPaymentData(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .logToFile(lhsTheme, lhsValue):
                if case let .logToFile(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .logToConsole(lhsTheme, lhsValue):
                if case let .logToConsole(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .redactSensitiveData(lhsTheme, lhsValue):
                if case let .redactSensitiveData(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .enableRaiseToSpeak(lhsTheme, lhsValue):
                if case let .enableRaiseToSpeak(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .keepChatNavigationStack(lhsTheme, lhsValue):
                if case let .keepChatNavigationStack(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: DebugControllerArguments) -> ListViewItem {
        switch self {
            case let .sendLogs(theme):
                return ItemListDisclosureItem(theme: theme, title: "Send Logs", label: "", sectionId: self.section, style: .blocks, action: {
                    let _ = (Logger.shared.collectLogs()
                        |> deliverOnMainQueue).start(next: { logs in
                            let controller = PeerSelectionController(account: arguments.account)
                            controller.peerSelected = { [weak controller] peerId in
                                if let strongController = controller {
                                    strongController.dismiss()
                                    
                                    let messages = logs.map { (name, path) -> EnqueueMessage in
                                        let id = arc4random64()
                                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                                        return .message(text: "", attributes: [], media: file, replyToMessageId: nil, localGroupingKey: nil)
                                    }
                                    let _ = enqueueMessages(account: arguments.account, peerId: peerId, messages: messages).start()
                                }
                            }
                            arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                        })
                })
            case let .accounts(theme):
                return ItemListDisclosureItem(theme: theme, title: "Accounts", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(debugAccountsController(account: arguments.account, accountManager: arguments.accountManager))
                })
            case let .clearPaymentData(theme):
                return ItemListDisclosureItem(theme: theme, title: "Clear Payment Password", label: "", sectionId: self.section, style: .blocks, action: {
                    let _ = cacheTwoStepPasswordToken(postbox: arguments.account.postbox, token: nil).start()
                })
            case let .logToFile(theme, value):
                return ItemListSwitchItem(theme: theme, title: "Log to File", value: value, sectionId: self.section, style: .blocks, updated: { value in
                    let _ = updateLoggingSettings(postbox: arguments.account.postbox, {
                        $0.withUpdatedLogToFile(value)
                    }).start()
                })
            case let .logToConsole(theme, value):
                return ItemListSwitchItem(theme: theme, title: "Log to Console", value: value, sectionId: self.section, style: .blocks, updated: { value in
                    let _ = updateLoggingSettings(postbox: arguments.account.postbox, {
                        $0.withUpdatedLogToConsole(value)
                    }).start()
                })
            case let .redactSensitiveData(theme, value):
                return ItemListSwitchItem(theme: theme, title: "Redact Sensitive Data", value: value, sectionId: self.section, style: .blocks, updated: { value in
                    let _ = updateLoggingSettings(postbox: arguments.account.postbox, {
                        $0.withUpdatedRedactSensitiveData(value)
                    }).start()
                })
            case let .enableRaiseToSpeak(theme, value):
                return ItemListSwitchItem(theme: theme, title: "Enable Raise to Speak", value: value, sectionId: self.section, style: .blocks, updated: { value in
                    let _ = updateMediaInputSettingsInteractively(postbox: arguments.account.postbox, {
                        $0.withUpdatedEnableRaiseToSpeak(value)
                    }).start()
                })
            case let .keepChatNavigationStack(theme, value):
                return ItemListSwitchItem(theme: theme, title: "Keep Chat Stack", value: value, sectionId: self.section, style: .blocks, updated: { value in
                    let _ = updateExperimentalUISettingsInteractively(postbox: arguments.account.postbox, { settings in
                        var settings = settings
                        settings.keepChatNavigationStack = value
                        return settings
                    }).start()
                })
        }
    }
}

private func debugControllerEntries(presentationData: PresentationData, loggingSettings: LoggingSettings, mediaInputSettings: MediaInputSettings, experimentalSettings: ExperimentalUISettings) -> [DebugControllerEntry] {
    var entries: [DebugControllerEntry] = []
    
    entries.append(.sendLogs(presentationData.theme))
    entries.append(.accounts(presentationData.theme))
    entries.append(.clearPaymentData(presentationData.theme))
    
    entries.append(.logToFile(presentationData.theme, loggingSettings.logToFile))
    entries.append(.logToConsole(presentationData.theme, loggingSettings.logToConsole))
    entries.append(.redactSensitiveData(presentationData.theme, loggingSettings.redactSensitiveData))
    
    entries.append(.enableRaiseToSpeak(presentationData.theme, mediaInputSettings.enableRaiseToSpeak))
    entries.append(.keepChatNavigationStack(presentationData.theme, experimentalSettings.keepChatNavigationStack))
    
    return entries
}

public func debugController(account: Account, accountManager: AccountManager) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = DebugControllerArguments(account: account, accountManager: accountManager, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, account.postbox.preferencesView(keys: [PreferencesKeys.loggingSettings, ApplicationSpecificPreferencesKeys.mediaInputSettings, ApplicationSpecificPreferencesKeys.experimentalUISettings]))
        |> map { presentationData, preferencesView -> (ItemListControllerState, (ItemListNodeState<DebugControllerEntry>, DebugControllerEntry.ItemGenerationArguments)) in
            let loggingSettings: LoggingSettings
            if let value = preferencesView.values[PreferencesKeys.loggingSettings] as? LoggingSettings {
                loggingSettings = value
            } else {
                loggingSettings = LoggingSettings.defaultSettings
            }
            
            let mediaInputSettings: MediaInputSettings
            if let value = preferencesView.values[ApplicationSpecificPreferencesKeys.mediaInputSettings] as? MediaInputSettings {
                mediaInputSettings = value
            } else {
                mediaInputSettings = MediaInputSettings.defaultSettings
            }
            
            let experimentalSettings: ExperimentalUISettings = (preferencesView.values[ApplicationSpecificPreferencesKeys.experimentalUISettings] as? ExperimentalUISettings) ?? ExperimentalUISettings.defaultSettings
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Debug"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: debugControllerEntries(presentationData: presentationData, loggingSettings: loggingSettings, mediaInputSettings: mediaInputSettings, experimentalSettings: experimentalSettings), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
