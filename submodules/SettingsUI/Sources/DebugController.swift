import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
#if BUCK
import MtProtoKit
#else
import MtProtoKitDynamic
#endif
import MessageUI
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import OverlayStatusController
import AccountContext

@objc private final class DebugControllerMailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

private final class DebugControllerArguments {
    let sharedContext: SharedAccountContext
    let context: AccountContext?
    let mailComposeDelegate: DebugControllerMailComposeDelegate
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    let getRootController: () -> UIViewController?
    
    init(sharedContext: SharedAccountContext, context: AccountContext?, mailComposeDelegate: DebugControllerMailComposeDelegate, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping (ViewController) -> Void, getRootController: @escaping () -> UIViewController?) {
        self.sharedContext = sharedContext
        self.context = context
        self.mailComposeDelegate = mailComposeDelegate
        self.presentController = presentController
        self.pushController = pushController
        self.getRootController = getRootController
    }
}

private enum DebugControllerSection: Int32 {
    case logs
    case logging
    case experiments
    case info
}

private enum DebugControllerEntry: ItemListNodeEntry {
    case sendLogs(PresentationTheme)
    case sendOneLog(PresentationTheme)
    case sendNotificationLogs(PresentationTheme)
    case sendCriticalLogs(PresentationTheme)
    case accounts(PresentationTheme)
    case logToFile(PresentationTheme, Bool)
    case logToConsole(PresentationTheme, Bool)
    case redactSensitiveData(PresentationTheme, Bool)
    case enableRaiseToSpeak(PresentationTheme, Bool)
    case keepChatNavigationStack(PresentationTheme, Bool)
    case skipReadHistory(PresentationTheme, Bool)
    case crashOnSlowQueries(PresentationTheme, Bool)
    case clearTips(PresentationTheme)
    case reimport(PresentationTheme)
    case resetData(PresentationTheme)
    case resetDatabase(PresentationTheme)
    case resetHoles(PresentationTheme)
    case resetBiometricsData(PresentationTheme)
    case optimizeDatabase(PresentationTheme)
    case photoPreview(PresentationTheme, Bool)
    case knockoutWallpaper(PresentationTheme, Bool)
    case gradientBubbles(PresentationTheme, Bool)
    case versionInfo(PresentationTheme)
    
    var section: ItemListSectionId {
        switch self {
        case .sendLogs, .sendOneLog, .sendNotificationLogs, .sendCriticalLogs:
            return DebugControllerSection.logs.rawValue
        case .accounts:
            return DebugControllerSection.logs.rawValue
        case .logToFile, .logToConsole, .redactSensitiveData:
            return DebugControllerSection.logging.rawValue
        case .enableRaiseToSpeak, .keepChatNavigationStack, .skipReadHistory, .crashOnSlowQueries:
            return DebugControllerSection.experiments.rawValue
        case .clearTips, .reimport, .resetData, .resetDatabase, .resetHoles, .resetBiometricsData, .optimizeDatabase, .photoPreview, .knockoutWallpaper, .gradientBubbles:
            return DebugControllerSection.experiments.rawValue
        case .versionInfo:
            return DebugControllerSection.info.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .sendLogs:
            return 0
        case .sendOneLog:
            return 1
        case .sendNotificationLogs:
            return 2
        case .sendCriticalLogs:
            return 3
        case .accounts:
            return 4
        case .logToFile:
            return 5
        case .logToConsole:
            return 6
        case .redactSensitiveData:
            return 7
        case .enableRaiseToSpeak:
            return 8
        case .keepChatNavigationStack:
            return 9
        case .skipReadHistory:
            return 10
        case .crashOnSlowQueries:
            return 11
        case .clearTips:
            return 12
        case .reimport:
            return 13
        case .resetData:
            return 14
        case .resetDatabase:
            return 15
        case .resetHoles:
            return 16
        case .resetBiometricsData:
            return 17
        case .optimizeDatabase:
            return 18
        case .photoPreview:
            return 19
        case .knockoutWallpaper:
            return 20
        case .gradientBubbles:
            return 21
        case .versionInfo:
            return 22
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
                        guard let context = arguments.context else {
                            return
                        }
                        
                        let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                        
                        var items: [ActionSheetButtonItem] = []
                        
                        if let context = arguments.context {
                            items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                                controller.peerSelected = { [weak controller] peerId in
                                    if let strongController = controller {
                                        strongController.dismiss()
                                        
                                        let messages = logs.map { (name, path) -> EnqueueMessage in
                                            let id = arc4random64()
                                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                                            return .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                                        }
                                        let _ = enqueueMessages(account: context.account, peerId: peerId, messages: messages).start()
                                    }
                                }
                                arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                            }))
                        }
                        items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            let composeController = MFMailComposeViewController()
                            composeController.mailComposeDelegate = arguments.mailComposeDelegate
                            composeController.setSubject("Telegram Logs")
                            for (name, path) in logs {
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                    composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                                }
                            }
                            arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                        }))
                        
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                            ])])
                        arguments.presentController(actionSheet, nil)
                    })
            })
        case let .sendOneLog(theme):
            return ItemListDisclosureItem(theme: theme, title: "Send Latest Log", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs()
                    |> deliverOnMainQueue).start(next: { logs in
                        let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                        
                        var items: [ActionSheetButtonItem] = []
                        
                        if let context = arguments.context {
                            items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                                controller.peerSelected = { [weak controller] peerId in
                                    if let strongController = controller {
                                        strongController.dismiss()
                                        
                                        let updatedLogs = logs.last.flatMap({ [$0] }) ?? []
                                        
                                        let messages = updatedLogs.map { (name, path) -> EnqueueMessage in
                                            let id = arc4random64()
                                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                                            return .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                                        }
                                        let _ = enqueueMessages(account: context.account, peerId: peerId, messages: messages).start()
                                    }
                                }
                                arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                            }))
                        }
                        
                        items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            let composeController = MFMailComposeViewController()
                            composeController.mailComposeDelegate = arguments.mailComposeDelegate
                            composeController.setSubject("Telegram Logs")
                            for (name, path) in logs {
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                    composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                                }
                            }
                            arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                        }))
                        
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                            ])
                            ])
                        arguments.presentController(actionSheet, nil)
                    })
            })
        case let .sendNotificationLogs(theme):
            return ItemListDisclosureItem(theme: theme, title: "Send Notification Logs", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger(basePath: arguments.sharedContext.basePath + "/notificationServiceLogs").collectLogs()
                    |> deliverOnMainQueue).start(next: { logs in
                        guard let context = arguments.context else {
                            return
                        }
                        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                        controller.peerSelected = { [weak controller] peerId in
                            if let strongController = controller {
                                strongController.dismiss()
                                
                                let messages = logs.map { (name, path) -> EnqueueMessage in
                                    let id = arc4random64()
                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                                    return .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                                }
                                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: messages).start()
                            }
                        }
                        arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                    })
            })
        case let .sendCriticalLogs(theme):
            return ItemListDisclosureItem(theme: theme, title: "Send Critical Logs", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectShortLogFiles()
                    |> deliverOnMainQueue).start(next: { logs in
                        let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                        
                        var items: [ActionSheetButtonItem] = []
                        
                        if let context = arguments.context {
                            items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                                controller.peerSelected = { [weak controller] peerId in
                                    if let strongController = controller {
                                        strongController.dismiss()
                                        
                                        let messages = logs.map { (name, path) -> EnqueueMessage in
                                            let id = arc4random64()
                                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                                            return .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                                        }
                                        let _ = enqueueMessages(account: context.account, peerId: peerId, messages: messages).start()
                                    }
                                }
                                arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                            }))
                        }
                        
                        items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            let composeController = MFMailComposeViewController()
                            composeController.mailComposeDelegate = arguments.mailComposeDelegate
                            composeController.setSubject("Telegram Logs")
                            for (name, path) in logs {
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                    composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                                }
                            }
                            arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                            ])])
                        arguments.presentController(actionSheet, nil)
                    })
            })
        case let .accounts(theme):
            return ItemListDisclosureItem(theme: theme, title: "Accounts", label: "", sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                arguments.pushController(debugAccountsController(context: context, accountManager: arguments.sharedContext.accountManager))
            })
        case let .logToFile(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Log to File", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedLogToFile(value)
                }).start()
            })
        case let .logToConsole(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Log to Console", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedLogToConsole(value)
                }).start()
            })
        case let .redactSensitiveData(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Remove Sensitive Data", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedRedactSensitiveData(value)
                }).start()
            })
        case let .enableRaiseToSpeak(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Enable Raise to Speak", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateMediaInputSettingsInteractively(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedEnableRaiseToSpeak(value)
                }).start()
            })
        case let .keepChatNavigationStack(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Keep Chat Stack", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.keepChatNavigationStack = value
                    return settings
                }).start()
            })
        case let .skipReadHistory(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Skip read history", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.skipReadHistory = value
                    return settings
                }).start()
            })
        case let .crashOnSlowQueries(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Crash when slow", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.crashOnLongQueries = value
                    return settings
                }).start()
            })
        case let .clearTips(theme):
            return ItemListActionItem(theme: theme, title: "Clear Tips", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let _ = (arguments.sharedContext.accountManager.transaction { transaction -> Void in
                    transaction.clearNotices()
                }).start()
            })
        case let .reimport(theme):
            return ItemListActionItem(theme: theme, title: "Reimport Application Data", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let appGroupName = "group.\(Bundle.main.bundleIdentifier!)"
                let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
                
                guard let appGroupUrl = maybeAppGroupUrl else {
                    return
                }
                
                let statusPath = appGroupUrl.path + "/Documents/importcompleted"
                if FileManager.default.fileExists(atPath: statusPath) {
                    let _ = try? FileManager.default.removeItem(at: URL(fileURLWithPath: statusPath))
                    exit(0)
                }
            })
        case let .resetData(theme):
            return ItemListActionItem(theme: theme, title: "Reset Data", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "All data will be lost."),
                    ActionSheetButtonItem(title: "Reset Data", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let databasePath = arguments.sharedContext.accountManager.basePath + "/db"
                        let _ = try? FileManager.default.removeItem(atPath: databasePath)
                        preconditionFailure()
                    }),
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                        ])])
                arguments.presentController(actionSheet, nil)
            })
        case let .resetDatabase(theme):
            return ItemListActionItem(theme: theme, title: "Clear Database", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "All secret chats will be lost."),
                    ActionSheetButtonItem(title: "Clear Database", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let databasePath = context.account.basePath + "/postbox/db"
                        let _ = try? FileManager.default.removeItem(atPath: databasePath)
                        preconditionFailure()
                    }),
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                        ])])
                arguments.presentController(actionSheet, nil)
            })
        case let .resetHoles(theme):
            return ItemListActionItem(theme: theme, title: "Reset Holes", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.account.postbox.transaction { transaction -> Void in
                    transaction.addHolesEverywhere(peerNamespaces: [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel], holeNamespace: Namespaces.Message.Cloud)
                    }
                    |> deliverOnMainQueue).start(completed: {
                        controller.dismiss()
                    })
            })
        case let .resetBiometricsData(theme):
            return ItemListActionItem(theme: theme, title: "Reset Biometrics Data", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let _ = updatePresentationPasscodeSettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    return settings.withUpdatedBiometricsDomainState(nil).withUpdatedShareBiometricsDomainState(nil)
                }).start()
            })
        case let .optimizeDatabase(theme):
            return ItemListActionItem(theme: theme, title: "Optimize Database", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.account.postbox.optimizeStorage()
                    |> deliverOnMainQueue).start(completed: {
                        controller.dismiss()
                        
                        let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .success)
                        arguments.presentController(controller, nil)
                    })
            })
        case let .photoPreview(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Photo Preview", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings as? ExperimentalUISettings ?? ExperimentalUISettings.defaultSettings
                        settings.chatListPhotos = value
                        return settings
                    })
                }).start()
            })
        case let .knockoutWallpaper(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Knockout Wallpaper", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings as? ExperimentalUISettings ?? ExperimentalUISettings.defaultSettings
                        settings.knockoutWallpaper = value
                        return settings
                    })
                }).start()
            })
        case let .gradientBubbles(theme, value):
            return ItemListSwitchItem(theme: theme, title: "Gradient", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings as? ExperimentalUISettings ?? ExperimentalUISettings.defaultSettings
                        settings.gradientBubbles = value
                        return settings
                    })
                }).start()
            })
        case let .versionInfo(theme):
            let bundle = Bundle.main
            let bundleId = bundle.bundleIdentifier ?? ""
            let bundleVersion = bundle.infoDictionary?["CFBundleShortVersionString"] ?? ""
            let bundleBuild = bundle.infoDictionary?[kCFBundleVersionKey as String] ?? ""
            return ItemListTextItem(theme: theme, text: .plain("\(bundleId)\n\(bundleVersion) (\(bundleBuild))"), sectionId: self.section)
        }
    }
}

private func debugControllerEntries(presentationData: PresentationData, loggingSettings: LoggingSettings, mediaInputSettings: MediaInputSettings, experimentalSettings: ExperimentalUISettings, hasLegacyAppData: Bool) -> [DebugControllerEntry] {
    var entries: [DebugControllerEntry] = []
    
    entries.append(.sendLogs(presentationData.theme))
    entries.append(.sendOneLog(presentationData.theme))
    entries.append(.sendNotificationLogs(presentationData.theme))
    entries.append(.sendCriticalLogs(presentationData.theme))
    entries.append(.accounts(presentationData.theme))
    
    entries.append(.logToFile(presentationData.theme, loggingSettings.logToFile))
    entries.append(.logToConsole(presentationData.theme, loggingSettings.logToConsole))
    entries.append(.redactSensitiveData(presentationData.theme, loggingSettings.redactSensitiveData))
    
    entries.append(.enableRaiseToSpeak(presentationData.theme, mediaInputSettings.enableRaiseToSpeak))
    entries.append(.keepChatNavigationStack(presentationData.theme, experimentalSettings.keepChatNavigationStack))
    #if DEBUG
    entries.append(.skipReadHistory(presentationData.theme, experimentalSettings.skipReadHistory))
    #endif
    entries.append(.crashOnSlowQueries(presentationData.theme, experimentalSettings.crashOnLongQueries))
    entries.append(.clearTips(presentationData.theme))
    if hasLegacyAppData {
        entries.append(.reimport(presentationData.theme))
    }
    entries.append(.resetData(presentationData.theme))
    entries.append(.resetDatabase(presentationData.theme))
    entries.append(.resetHoles(presentationData.theme))
    entries.append(.optimizeDatabase(presentationData.theme))
    entries.append(.photoPreview(presentationData.theme, experimentalSettings.chatListPhotos))
    entries.append(.knockoutWallpaper(presentationData.theme, experimentalSettings.knockoutWallpaper))
    entries.append(.gradientBubbles(presentationData.theme, experimentalSettings.gradientBubbles))

    entries.append(.versionInfo(presentationData.theme))
    
    return entries
}

public func debugController(sharedContext: SharedAccountContext, context: AccountContext?, modal: Bool = false) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var getRootControllerImpl: (() -> UIViewController?)?
    
    let arguments = DebugControllerArguments(sharedContext: sharedContext, context: context, mailComposeDelegate: DebugControllerMailComposeDelegate(), presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, getRootController: {
        return getRootControllerImpl?()
    })
    
    let appGroupName = "group.\(Bundle.main.bundleIdentifier!)"
    let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
    
    var hasLegacyAppData = false
    if let appGroupUrl = maybeAppGroupUrl {
        let statusPath = appGroupUrl.path + "/Documents/importcompleted"
        hasLegacyAppData = FileManager.default.fileExists(atPath: statusPath)
    }
    
    let signal = combineLatest(sharedContext.presentationData, sharedContext.accountManager.sharedData(keys: Set([SharedDataKeys.loggingSettings, ApplicationSpecificSharedDataKeys.mediaInputSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings])))
        |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState<DebugControllerEntry>, DebugControllerEntry.ItemGenerationArguments)) in
            let loggingSettings: LoggingSettings
            if let value = sharedData.entries[SharedDataKeys.loggingSettings] as? LoggingSettings {
                loggingSettings = value
            } else {
                loggingSettings = LoggingSettings.defaultSettings
            }
            
            let mediaInputSettings: MediaInputSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.mediaInputSettings] as? MediaInputSettings {
                mediaInputSettings = value
            } else {
                mediaInputSettings = MediaInputSettings.defaultSettings
            }
            
            let experimentalSettings: ExperimentalUISettings = (sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings] as? ExperimentalUISettings) ?? ExperimentalUISettings.defaultSettings
            
            var leftNavigationButton: ItemListNavigationButton?
            if modal {
                leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                    dismissImpl?()
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Debug"), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: debugControllerEntries(presentationData: presentationData, loggingSettings: loggingSettings, mediaInputSettings: mediaInputSettings, experimentalSettings: experimentalSettings, hasLegacyAppData: hasLegacyAppData), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    
    let controller = ItemListController(sharedContext: sharedContext, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    getRootControllerImpl = { [weak controller] in
        return controller?.view.window?.rootViewController
    }
    return controller
}
