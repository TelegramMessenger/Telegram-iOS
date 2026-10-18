import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import MtProtoKit
import MessageUI
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import AppBundle
import ZipArchive
import WebKit
import InAppPurchaseManager
import TelegramVoip
import ComponentFlow
import AlertComponent
import AlertCheckComponent
import WalletContext
import CpuProfiler
import CrashReporting
import ContextUI

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
    let getNavigationController: () -> NavigationController?
    var openLogs: () -> Void = {}
    var isTestingPasscodeMigration = false
    
    init(sharedContext: SharedAccountContext, context: AccountContext?, mailComposeDelegate: DebugControllerMailComposeDelegate, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping (ViewController) -> Void, getRootController: @escaping () -> UIViewController?, getNavigationController: @escaping () -> NavigationController?) {
        self.sharedContext = sharedContext
        self.context = context
        self.mailComposeDelegate = mailComposeDelegate
        self.presentController = presentController
        self.pushController = pushController
        self.getRootController = getRootController
        self.getNavigationController = getNavigationController
    }
}

private func presentPasscodeMigrationTest(arguments: DebugControllerArguments) {
    guard arguments.sharedContext.applicationBindings.isMainApp, !arguments.isTestingPasscodeMigration else {
        return
    }

    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
    let checkState = AlertCheckComponent.ExternalState()
    let actionsEnabled = ValuePromise<Bool>(true, ignoreRepeated: true)
    var hasSelectedPasscode = false
    let test: (PostboxAccessChallengeData) -> Void = { challenge in
        guard !hasSelectedPasscode, !arguments.isTestingPasscodeMigration else {
            return
        }
        hasSelectedPasscode = true
        arguments.isTestingPasscodeMigration = true
        actionsEnabled.set(false)
        let isLocked = checkState.value

        let signal = updatePresentationPasscodeSettingsInteractively(accountManager: arguments.sharedContext.accountManager, { _ in
            return .defaultSettings
        })
        |> mapToSignalPromotingError { _ -> Signal<Never, Error> in
            return arguments.sharedContext.accountManager._internalTestPasscodeMigration(challenge, prepare: { commitAndCrash in
                try _internalResetLocalSecretsForPasscodeMigrationTest(then: commitAndCrash)
            }, crash: {
                try arguments.sharedContext.appLockContext._internalCrashForPasscodeMigrationTest(isLocked: isLocked)
            })
        }
        let _ = (signal
        |> deliverOnMainQueue).start(error: { error in
            arguments.isTestingPasscodeMigration = false
            let controller = textAlertController(sharedContext: arguments.sharedContext, title: "Test Passcode Migration Failed", text: "Preparation failed. Local passcode or wallet data may already have been removed.\n\n\(error.localizedDescription)", actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
            ])
            arguments.presentController(controller, nil)
        })
    }

    let controller = AlertScreen(
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        content: [
            AnyComponentWithIdentity(id: "title", component: AnyComponent(AlertTitleComponent(title: "test passcode migration"))),
            AnyComponentWithIdentity(id: "lock", component: AnyComponent(AlertCheckComponent(title: "Lock on next launch", initialValue: true, externalState: checkState)))
        ],
        actions: [
            .init(title: "6-digits (123456)", action: {
                test(.numericalPassword(value: "123456"))
            }, isEnabled: actionsEnabled.get()),
            .init(title: "4-digits (1234)", action: {
                test(.numericalPassword(value: "1234"))
            }, isEnabled: actionsEnabled.get()),
            .init(title: "alphanumeric (qwerty)", action: {
                test(.plaintextPassword(value: "qwerty"))
            }, isEnabled: actionsEnabled.get()),
            .init(title: presentationData.strings.Common_Cancel, isEnabled: actionsEnabled.get())
        ],
        updatedPresentationData: (presentationData, arguments.sharedContext.presentationData)
    )
    arguments.presentController(controller, nil)
}

private extension ExperimentalUISettings.VideoMessageCameraMode {
    var debugTitle: String {
        switch self {
        case .legacy:
            return "Legacy"
        case .vga:
            return "VGA (640×480)"
        case .hdBilinear:
            return "HD · Bilinear"
        case .hdLanczos:
            return "HD · Lanczos"
        }
    }
}

private enum DebugControllerItemTag: ItemListItemTag {
    case sendLogs

    func isEqual(to other: ItemListItemTag) -> Bool {
        return (other as? DebugControllerItemTag) == self
    }
}

private final class DebugLogsContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds, insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0))
    }
}

private enum DebugLogDestination {
    case telegram
    case email
}

private enum DebugLogAction {
    case sendLogs
    case sendOneLog
    case sendShareLogs
    case sendGroupCallLogs
    case sendNotificationLogs
    case sendCriticalLogs
    case sendAllLogs
    case sendStorageStats

    var title: String {
        switch self {
        case .sendLogs: return "Logs"
        case .sendOneLog: return "Latest Logs"
        case .sendShareLogs: return "Share Logs"
        case .sendGroupCallLogs: return "Group Call Logs"
        case .sendNotificationLogs: return "Notification Logs"
        case .sendCriticalLogs: return "Critical Logs"
        case .sendAllLogs: return "All Logs"
        case .sendStorageStats: return "Storage Stats"
        }
    }

    var textLayout: ContextMenuActionItemTextLayout {
        switch self {
        case .sendLogs, .sendShareLogs, .sendGroupCallLogs, .sendNotificationLogs:
            return .secondLineWithValue("Up to 40 MB")
        case .sendOneLog:
            return .secondLineWithValue("Up to 4 MB")
        case .sendCriticalLogs, .sendAllLogs, .sendStorageStats:
            return .singleLine
        }
    }

    func perform(arguments: DebugControllerArguments, destination: DebugLogDestination) {
        switch self {
        case .sendLogs:
            let _ = (Logger.shared.collectLogs()
            |> deliverOnMainQueue).start(next: { logs in

                if destination == .telegram, let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                    controller.peerSelected = { [weak controller] peer, _ in
                        let peerId = peer.id

                        if let strongController = controller {
                            strongController.dismiss()

                            let lineFeed = "\n".data(using: .utf8)!
                            var rawLogData: Data = Data()
                            for (name, path) in logs {
                                if !rawLogData.isEmpty {
                                    rawLogData.append(lineFeed)
                                    rawLogData.append(lineFeed)
                                }

                                rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                    rawLogData.append(data)
                                }
                            }

                            let tempSource = EngineTempBox.shared.tempFile(fileName: "Log.txt")
                            let tempZip = EngineTempBox.shared.tempFile(fileName: "destination.zip")

                            let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))

                            SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                            guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                return
                            }

                            EngineTempBox.shared.dispose(tempSource)
                            EngineTempBox.shared.dispose(tempZip)

                            let id = Int64.random(in: Int64.min ... Int64.max)
                            let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                            context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: gzippedData)

                            let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")], alternativeRepresentations: [])
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                            let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                        }
                    }
                    arguments.pushController(controller)
                }
                if destination == .email {
                    let composeController = MFMailComposeViewController()
                    composeController.mailComposeDelegate = arguments.mailComposeDelegate
                    composeController.setSubject("Telegram Logs")
                    for (name, path) in logs {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                            composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                        }
                    }
                    arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                }

            })
        case .sendOneLog:
            let _ = (Logger.shared.collectLogs()
                |> deliverOnMainQueue).start(next: { logs in

                    if destination == .telegram, let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                        controller.peerSelected = { [weak controller] peer, _ in
                            let peerId = peer.id

                            if let strongController = controller {
                                strongController.dismiss()

                                let lineFeed = "\n".data(using: .utf8)!
                                var logData: Data = Data()

                                var latestLogs: [(String, String)] = []
                                if logs.count < 2 {
                                    latestLogs = logs
                                } else {
                                    for i in (logs.count - 2) ..< logs.count {
                                        latestLogs.append(logs[i])
                                    }
                                }

                                for (name, path) in latestLogs {
                                    if !logData.isEmpty {
                                        logData.append(lineFeed)
                                        logData.append(lineFeed)
                                    }

                                    logData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                        logData.append(data)
                                    }
                                }

                                let id = Int64.random(in: Int64.min ... Int64.max)
                                let fileResource = LocalFileMediaResource(fileId: id, size: Int64(logData.count), isSecretRelated: false)
                                context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: logData)

                                let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(logData.count), attributes: [.FileName(fileName: "Log-iOS-Short.txt")], alternativeRepresentations: [])
                                let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                            }
                        }
                        arguments.pushController(controller)
                    }

                    if destination == .email {
                        let composeController = MFMailComposeViewController()
                        composeController.mailComposeDelegate = arguments.mailComposeDelegate
                        composeController.setSubject("Telegram Logs")
                        for (name, path) in logs {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                            }
                        }
                        arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                    }

                })
        case .sendShareLogs:
            let _ = (Logger.shared.collectLogs(prefix: "/logs/share-logs")
            |> deliverOnMainQueue).start(next: { logs in

                if destination == .telegram, let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                    controller.peerSelected = { [weak controller] peer, _ in
                        let peerId = peer.id

                        if let strongController = controller {
                            strongController.dismiss()

                            let lineFeed = "\n".data(using: .utf8)!
                            var rawLogData: Data = Data()
                            for (name, path) in logs {
                                if !rawLogData.isEmpty {
                                    rawLogData.append(lineFeed)
                                    rawLogData.append(lineFeed)
                                }

                                rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                    rawLogData.append(data)
                                }
                            }

                            let tempSource = EngineTempBox.shared.tempFile(fileName: "Log.txt")
                            let tempZip = EngineTempBox.shared.tempFile(fileName: "destination.zip")

                            let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))

                            SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                            guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                return
                            }

                            EngineTempBox.shared.dispose(tempSource)
                            EngineTempBox.shared.dispose(tempZip)

                            let id = Int64.random(in: Int64.min ... Int64.max)
                            let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                            context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: gzippedData)

                            let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")], alternativeRepresentations: [])
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                            let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                        }
                    }
                    arguments.pushController(controller)
                }
                if destination == .email {
                    let composeController = MFMailComposeViewController()
                    composeController.mailComposeDelegate = arguments.mailComposeDelegate
                    composeController.setSubject("Telegram Logs")
                    for (name, path) in logs {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                            composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                        }
                    }
                    arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                }

            })
        case .sendGroupCallLogs:
            let _ = (Logger.shared.collectLogs(basePath: arguments.context!.account.basePath + "/group-calls")
            |> deliverOnMainQueue).start(next: { logs in

                if destination == .telegram, let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                    controller.peerSelected = { [weak controller] peer, _ in
                        let peerId = peer.id

                        if let strongController = controller {
                            strongController.dismiss()

                            let lineFeed = "\n".data(using: .utf8)!
                            var rawLogData: Data = Data()
                            for (name, path) in logs {
                                if !rawLogData.isEmpty {
                                    rawLogData.append(lineFeed)
                                    rawLogData.append(lineFeed)
                                }

                                rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                    rawLogData.append(data)
                                }
                            }

                            let tempSource = EngineTempBox.shared.tempFile(fileName: "Log.txt")
                            let tempZip = EngineTempBox.shared.tempFile(fileName: "destination.zip")

                            let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))

                            SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                            guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                return
                            }

                            EngineTempBox.shared.dispose(tempSource)
                            EngineTempBox.shared.dispose(tempZip)

                            let id = Int64.random(in: Int64.min ... Int64.max)
                            let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                            context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: gzippedData)

                            let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")], alternativeRepresentations: [])
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                            let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                        }
                    }
                    arguments.pushController(controller)
                }
                if destination == .email {
                    let composeController = MFMailComposeViewController()
                    composeController.mailComposeDelegate = arguments.mailComposeDelegate
                    composeController.setSubject("Telegram Logs")
                    for (name, path) in logs {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                            composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                        }
                    }
                    arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                }

            })
        case .sendNotificationLogs:
            let logsPath = arguments.sharedContext.basePath + "/logs/notification-logs"
            let _ = (Logger(rootPath: logsPath, basePath: logsPath).collectLogs()
                |> deliverOnMainQueue).start(next: { logs in

                if destination == .telegram, let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                    controller.peerSelected = { [weak controller] peer, _ in
                        let peerId = peer.id

                        if let strongController = controller {
                            strongController.dismiss()

                            let lineFeed = "\n".data(using: .utf8)!
                            var rawLogData: Data = Data()
                            for (name, path) in logs {
                                if !rawLogData.isEmpty {
                                    rawLogData.append(lineFeed)
                                    rawLogData.append(lineFeed)
                                }

                                rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                    rawLogData.append(data)
                                }
                            }

                            let tempSource = EngineTempBox.shared.tempFile(fileName: "Log.txt")
                            let tempZip = EngineTempBox.shared.tempFile(fileName: "destination.zip")

                            let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))

                            SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                            guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                return
                            }

                            EngineTempBox.shared.dispose(tempSource)
                            EngineTempBox.shared.dispose(tempZip)

                            let id = Int64.random(in: Int64.min ... Int64.max)
                            let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                            context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: gzippedData)

                            let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")], alternativeRepresentations: [])
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                            let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                        }
                    }
                    arguments.pushController(controller)
                }
                if destination == .email {
                    let composeController = MFMailComposeViewController()
                    composeController.mailComposeDelegate = arguments.mailComposeDelegate
                    composeController.setSubject("Telegram Logs")
                    for (name, path) in logs {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                            composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                        }
                    }
                    arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                }

            })
        case .sendCriticalLogs:
            let _ = (Logger.shared.collectShortLogFiles()
                |> deliverOnMainQueue).start(next: { logs in

                    if destination == .telegram, let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                        controller.peerSelected = { [weak controller] peer, _ in
                            let peerId = peer.id

                            if let strongController = controller {
                                strongController.dismiss()

                                let messages = logs.map { (name, path) -> EnqueueMessage in
                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)], alternativeRepresentations: [])
                                    return .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                }
                                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: messages).start()
                            }
                        }
                        arguments.pushController(controller)
                    }

                    if destination == .email {
                        let composeController = MFMailComposeViewController()
                        composeController.mailComposeDelegate = arguments.mailComposeDelegate
                        composeController.setSubject("Telegram Logs")
                        for (name, path) in logs {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                            }
                        }
                        arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                    }
                })
        case .sendAllLogs:
            let logTypes: [String] = [
                "app-logs",
                "broadcast-logs",
                "siri-logs",
                "widget-logs",
                "notificationcontent-logs",
                "notification-logs"
            ]

            var logByType: [Signal<(type: String, logs: [(String, String)]), NoError>] = []
            for type in logTypes {
                let logsPath = arguments.sharedContext.basePath + "/logs/\(type)"
                logByType.append(Logger(rootPath: logsPath, basePath: logsPath).collectLogs()
                |> map { result -> (type: String, logs: [(String, String)]) in
                    return (type, result)
                })
            }

            let allLogs = combineLatest(logByType)

            let _ = (allLogs
            |> deliverOnMainQueue).start(next: { allLogs in

                if destination == .telegram, let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                    controller.peerSelected = { [weak controller] peer, _ in
                        let peerId = peer.id

                        if let strongController = controller {
                            strongController.dismiss()

                            let lineFeed = "\n".data(using: .utf8)!

                            var tempSources: [EngineTempBox.File] = []
                            for (type, logItems) in allLogs {
                                let tempSource = EngineTempBox.shared.tempFile(fileName: "Log-\(type).txt")

                                var rawLogData: Data = Data()
                                for (name, path) in logItems {
                                    if !rawLogData.isEmpty {
                                        rawLogData.append(lineFeed)
                                        rawLogData.append(lineFeed)
                                    }

                                    rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                        rawLogData.append(data)
                                    }
                                }

                                let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                tempSources.append(tempSource)
                            }

                            let tempZip = EngineTempBox.shared.tempFile(fileName: "destination.zip")
                            SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: tempSources.map(\.path))

                            guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                return
                            }

                            tempSources.forEach(EngineTempBox.shared.dispose)
                            EngineTempBox.shared.dispose(tempZip)

                            let id = Int64.random(in: Int64.min ... Int64.max)
                            let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                            context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: gzippedData)

                            let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/zip", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-All.txt.zip")], alternativeRepresentations: [])
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                            let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                        }
                    }
                    arguments.pushController(controller)
                }

            })
        case .sendStorageStats:
            guard let context = arguments.context, context.sharedContext.applicationBindings.isMainApp else {
                return
            }

            let allStats: Signal<Data, NoError> = Signal { subscriber in
                DispatchQueue.global().async {
                    let log = collectRawStorageUsageReport(containerPath: context.sharedContext.applicationBindings.containerPath)
                    subscriber.putNext(log.data(using: .utf8) ?? Data())
                }

                return EmptyDisposable
            }

            let _ = (allStats
            |> deliverOnMainQueue).start(next: { allStatsData in

                if destination == .telegram, let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                    controller.peerSelected = { [weak controller] peer, _ in
                        let peerId = peer.id

                        if let strongController = controller {
                            strongController.dismiss()

                            let id = Int64.random(in: Int64.min ... Int64.max)
                            let fileResource = LocalFileMediaResource(fileId: id, size: Int64(allStatsData.count), isSecretRelated: false)
                            context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: allStatsData)

                            let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/zip", size: Int64(allStatsData.count), attributes: [.FileName(fileName: "StorageReport.txt")], alternativeRepresentations: [])
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                            let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                        }
                    }
                    arguments.pushController(controller)
                }

            })
        }
    }
}

private enum DebugControllerSection: Int32 {
    case appInfo
    case logs
    case accounts
    case resetApp
    case sticker
    case experiments
    case translation
    case web
    case videoExperiments2
    case info
    case profiling
}

private enum DebugControllerEntry: ItemListNodeEntry {
    case testStickerImport(PresentationTheme)
    case logsHeader(PresentationTheme)
    case logsInfo(PresentationTheme)
    case resetAppHeader(PresentationTheme)
    case experimentsHeader(PresentationTheme)
    case sendLogs(PresentationTheme)
    case accounts(PresentationTheme)
    case logToFile(PresentationTheme, Bool)
    case logToConsole(PresentationTheme, Bool)
    case redactSensitiveData(PresentationTheme, Bool)
    case crashReports
    case keepChatNavigationStack(PresentationTheme, Bool)
    case skipReadHistory(PresentationTheme, Bool)
    case alwaysDisplayTyping(Bool)
    case debugRatingLayout(Bool)
    case crashOnSlowQueries(PresentationTheme, Bool)
    case crashOnMemoryPressure(PresentationTheme, Bool)
    case clearTips(PresentationTheme)
    case resetNotifications
    case crash(PresentationTheme)
    case testPasscodeMigration
    case fillLocalSavedMessageCache
    case resetDatabase(PresentationTheme)
    case resetDatabaseAndCache(PresentationTheme)
    case resetHoles(PresentationTheme)
    case resetTagHoles
    case reindexUnread(PresentationTheme)
    case resetCacheIndex
    case reindexCache
    case resetBiometricsData(PresentationTheme)
    case webViewInspection(Bool)
    case resetWebViewCache(PresentationTheme)
    case optimizeDatabase(PresentationTheme)
    case photoPreview(PresentationTheme, Bool)
    case knockoutWallpaper(PresentationTheme, Bool)
    case experimentalCompatibility(Bool)
    case enableDebugDataDisplay(Bool)
    case fakeGlass(Bool)
    case forceClearGlass(Bool)
    case debugRipple(Bool)
    case inputDecTextBackend(Bool)
    case inputDecEngineEditor(Bool)
    case coreListChatBackend(Bool)
    case springSendAnimation(Bool)
    case fakeWalletTransfers(Bool)
    case forceRLottieBackend(Bool)
    case respectSystemMicrophone(Bool)
    case useModernVideoMessagePipeline(Bool)
    case videoMessageCameraMode(ExperimentalUISettings.VideoMessageCameraMode)
    case browserExperiment(Bool)
    case allForumsHaveTabs(Bool)
    case enableReactionOverrides(Bool)
    case compressedEmojiCache(Bool)
    case storiesJpegExperiment(Bool)
    case checkSerializedData(Bool)
    case enableQuickReactionSwitch(Bool)
    case disableReloginTokens(Bool)
    case liveStreamV2(Bool)
    case experimentalCallMute(Bool)
    case groupCallReferenceEngine(Bool)
    case playerV2(Bool)
    case devRequests(Bool)
    case enableUpdates(Bool)
    case pwa(Bool)
    case enableLocalTranslation(Bool)
    case disableVideoAspectScaling(Bool)
    case enableNetworkFramework(Bool)
    case enableNetworkExperiments(Bool)
    case rustMTProtoEngine(Bool)
    case networkEngineInfo(String)
    case restorePurchases(PresentationTheme)
    case logTranslationRecognition(Bool)
    case resetTranslationStates
    case hostInfo(PresentationTheme, String)
    case versionInfo(PresentationTheme)
    case collectCpuProfile
    case sendProfileLogs

    var section: ItemListSectionId {
        switch self {
        case .testStickerImport:
            return DebugControllerSection.sticker.rawValue
        case .logsHeader, .logsInfo, .sendLogs:
            return DebugControllerSection.logs.rawValue
        case .accounts:
            return DebugControllerSection.accounts.rawValue
        case .crashReports:
            return DebugControllerSection.logs.rawValue
        case .logToFile, .logToConsole, .redactSensitiveData:
            return DebugControllerSection.logs.rawValue
        case .resetAppHeader, .resetDatabase, .resetDatabaseAndCache, .clearTips, .resetNotifications, .fillLocalSavedMessageCache, .resetHoles, .resetTagHoles, .reindexUnread, .resetCacheIndex, .reindexCache, .optimizeDatabase, .restorePurchases:
            return DebugControllerSection.resetApp.rawValue
        case .webViewInspection, .resetWebViewCache:
            return DebugControllerSection.web.rawValue
        case .experimentsHeader, .keepChatNavigationStack, .skipReadHistory, .alwaysDisplayTyping, .debugRatingLayout, .crashOnSlowQueries, .crashOnMemoryPressure:
            return DebugControllerSection.experiments.rawValue
        case .crash, .resetBiometricsData, .photoPreview, .knockoutWallpaper, .compressedEmojiCache, .storiesJpegExperiment, .checkSerializedData, .enableQuickReactionSwitch, .experimentalCompatibility, .enableDebugDataDisplay, .fakeGlass, .forceClearGlass, .debugRipple, .inputDecEngineEditor, .coreListChatBackend, .forceRLottieBackend, .respectSystemMicrophone, .useModernVideoMessagePipeline, .videoMessageCameraMode, .browserExperiment, .allForumsHaveTabs, .enableReactionOverrides, .disableReloginTokens, .liveStreamV2, .experimentalCallMute, .groupCallReferenceEngine, .playerV2, .devRequests, .enableUpdates, .pwa, .enableLocalTranslation, .testPasscodeMigration:
            return DebugControllerSection.experiments.rawValue
        case .inputDecTextBackend, .springSendAnimation, .fakeWalletTransfers:
            return DebugControllerSection.experiments.rawValue
        case .logTranslationRecognition, .resetTranslationStates:
            return DebugControllerSection.translation.rawValue
        case .disableVideoAspectScaling, .enableNetworkFramework, .enableNetworkExperiments, .rustMTProtoEngine, .networkEngineInfo:
            return DebugControllerSection.videoExperiments2.rawValue
        case .versionInfo:
            return DebugControllerSection.appInfo.rawValue
        case .hostInfo:
            return DebugControllerSection.info.rawValue
        case .collectCpuProfile, .sendProfileLogs:
            return DebugControllerSection.profiling.rawValue
        }
    }

    var stableId: Int {
        switch self {
        case .testStickerImport:
            return 0
        case .logsHeader:
            return -2
        case .logsInfo:
            return 13
        case .resetAppHeader:
            return 14
        case .experimentsHeader:
            return 17
        case .sendLogs:
            return 1
        case .accounts:
            return -3
        case .logToFile:
            return 10
        case .logToConsole:
            return 11
        case .redactSensitiveData:
            return 12
        case .crashReports:
            return 2
        case .webViewInspection:
            return 70
        case .resetWebViewCache:
            return 71
        case .keepChatNavigationStack:
            return 18
        case .skipReadHistory:
            return 19
        case .alwaysDisplayTyping:
            return 20
        case .debugRatingLayout:
            return 21
        case .coreListChatBackend:
            return 22
        case .forceRLottieBackend:
            return 23
        case .respectSystemMicrophone:
            return 24
        case .useModernVideoMessagePipeline:
            return 25
        case .videoMessageCameraMode:
            return 26
        case .crashOnSlowQueries:
            return 27
        case .crashOnMemoryPressure:
            return 28
        case .clearTips:
            return 29
        case .resetNotifications:
            return 30
        case .crash:
            return 31
        case .testPasscodeMigration:
            return 32
        case .fillLocalSavedMessageCache:
            return 33
        case .resetDatabase:
            return 34
        case .resetDatabaseAndCache:
            return 35
        case .resetHoles:
            return 36
        case .resetTagHoles:
            return 37
        case .reindexUnread:
            return 38
        case .resetCacheIndex:
            return 39
        case .reindexCache:
            return 40
        case .resetBiometricsData:
            return 41
        case .optimizeDatabase:
            return 42
        case .photoPreview:
            return 43
        case .knockoutWallpaper:
            return 44
        case .experimentalCompatibility:
            return 45
        case .enableDebugDataDisplay:
            return 46
        case .fakeGlass:
            return 47
        case .forceClearGlass:
            return 48
        case .debugRipple:
            return 49
        case .inputDecEngineEditor:
            return 50
        case .browserExperiment:
            return 51
        case .allForumsHaveTabs:
            return 52
        case .enableReactionOverrides:
            return 53
        case .restorePurchases:
            return 54
        case .logTranslationRecognition:
            return 68
        case .resetTranslationStates:
            return 69
        case .compressedEmojiCache:
            return 55
        case .storiesJpegExperiment:
            return 56
        case .disableReloginTokens:
            return 57
        case .checkSerializedData:
            return 58
        case .enableQuickReactionSwitch:
            return 59
        case .liveStreamV2:
            return 60
        case .experimentalCallMute:
            return 61
        case .groupCallReferenceEngine:
            return 62
        case .playerV2:
            return 63
        case .devRequests:
            return 64
        case .pwa:
            return 65
        case .enableLocalTranslation:
            return 66
        case .enableUpdates:
            return 67
        case .inputDecTextBackend:
            // After `enableUpdates`, where it is appended. ItemList asserts its entries are in
            // strictly increasing order (`<`: section, then `sortIndex`, which is the stableId here;
            // ItemListControllerNode.swift), so an id must match the position the entry is appended
            // at, or the list traps at runtime inside its own state closure.
            return 72
        case .springSendAnimation:
            // Appended right after `inputDecTextBackend`; see the ordering note above.
            return 73
        case .fakeWalletTransfers:
            // Appended right after `springSendAnimation`; see the ordering note above.
            return 74
        case .disableVideoAspectScaling:
            return 104
        case .enableNetworkFramework:
            return 105
        case .enableNetworkExperiments:
            return 106
        case .rustMTProtoEngine:
            return 107
        case .networkEngineInfo:
            return 108
        case .hostInfo:
            return 109
        case .versionInfo:
            return -4
        case .collectCpuProfile:
            return 111
        case .sendProfileLogs:
            return 112
        }
    }

    private var sortIndex: Int {
        switch self {
        case .resetAppHeader: return 0
        case .clearTips: return 1
        case .resetDatabase: return 2
        case .resetDatabaseAndCache: return 3
        case .resetNotifications: return 4
        case .fillLocalSavedMessageCache: return 5
        case .resetHoles: return 6
        case .resetTagHoles: return 7
        case .reindexUnread: return 8
        case .resetCacheIndex: return 9
        case .reindexCache: return 10
        case .optimizeDatabase: return 11
        case .restorePurchases: return 12
        default: return self.stableId
        }
    }

    static func <(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        if lhs.section != rhs.section {
            return lhs.section < rhs.section
        }
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DebugControllerArguments
        switch self {
        case .testStickerImport:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Simulate Stickers Import", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                if let url = getAppBundle().url(forResource: "importstickers", withExtension: "json"), let data = try? Data(contentsOf: url) {
                    let dataType = "org.telegram.third-party.stickerset"
                    if #available(iOS 10.0, *) {
                        UIPasteboard.general.setItems([[dataType: data]], options: [UIPasteboard.OptionsKey.localOnly: true, UIPasteboard.OptionsKey.expirationDate: NSDate(timeIntervalSinceNow: 60)])
                    } else {
                        UIPasteboard.general.setData(data, forPasteboardType: dataType)
                    }
                    context.sharedContext.openResolvedUrl(.importStickers, context: context, urlContext: .generic, navigationController: arguments.getNavigationController(), forceExternal: false, forceUpdate: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { c, a in arguments.presentController(c, a as? ViewControllerPresentationArguments) }, dismissInput: {}, contentContext: nil, progress: nil, completion: nil)
                }
            })
        case .logsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LOGS", sectionId: self.section)
        case .logsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("When enabled, your message text and other sensitive information are excluded from logs."), sectionId: self.section)
        case .resetAppHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "RESET APP", sectionId: self.section)
        case .experimentsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "EXPERIMENTAL SETTINGS", sectionId: self.section)
        case .sendLogs:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Send Logs", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openLogs()
            }, tag: DebugControllerItemTag.sendLogs)
        case .accounts:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Accounts", label: "", sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                arguments.pushController(debugAccountsController(context: context, accountManager: arguments.sharedContext.accountManager))
            })
        case let .logToFile(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Log to File", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedLogToFile(value)
                }).start()
            })
        case let .logToConsole(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Log to Console", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedLogToConsole(value)
                }).start()
            })
        case .crashReports:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Crash Logs", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.pushController(crashReportsController(sharedContext: arguments.sharedContext, context: arguments.context))
            })
        case let .redactSensitiveData(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Remove Sensitive Data", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedRedactSensitiveData(value)
                }).start()
            })
        case let .keepChatNavigationStack(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Keep Chat Stack", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.keepChatNavigationStack = value
                    return settings
                }).start()
            })
        case let .skipReadHistory(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Skip read history", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.skipReadHistory = value
                    return settings
                }).start()
            })
        case let .alwaysDisplayTyping(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Show Typing", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.alwaysDisplayTyping = value
                    return settings
                }).start()
            })
        case let .debugRatingLayout(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Rating Debug", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.debugRatingLayout = value
                    return settings
                }).start()
            })
        case let .crashOnSlowQueries(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Crash when slow", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.crashOnLongQueries = value
                    return settings
                }).start()
            })
        case let .crashOnMemoryPressure(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Crash on memory pressure", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.crashOnMemoryPressure = value
                    return settings
                }).start()
            })
        case .clearTips:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Clear Tips", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let _ = (arguments.sharedContext.accountManager.transaction { transaction -> Void in
                    transaction.clearNotices()
                }).start()
                if let context = arguments.context {
                    let _ = context.engine.itemCache.clear(collectionIds: [
                        Namespaces.CachedItemCollection.cachedPollResults,
                        Namespaces.CachedItemCollection.cachedStickerPacks
                    ]).start()

                    let _ = context.engine.peers.unmarkChatListFeaturedFiltersAsSeen()
                }
            })
        case let .logTranslationRecognition(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Log Language Recognition", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.logLanguageRecognition = value
                    return settings
                }).start()
            })
        case .resetTranslationStates:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reset Translation States", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if let context = arguments.context {
                    let _ = context.engine.itemCache.clear(collectionIds: [
                        ApplicationSpecificItemCacheCollectionId.translationState
                    ]).start()
                }
            })
        case .resetNotifications:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reset Notifications", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                UIApplication.shared.unregisterForRemoteNotifications()
                
                if let context = arguments.context {
                    let controller = textAlertController(context: context, title: nil, text: "Now restart the app", actions: [TextAlertAction(type: .genericAction, title: "OK", action: {})])
                    arguments.presentController(controller, nil)
                }
            })
        case .crash:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Crash", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                preconditionFailure()
            })
        case .testPasscodeMigration:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Test Passcode Migration", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                presentPasscodeMigrationTest(arguments: arguments)
            })
        case .fillLocalSavedMessageCache:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reload Saved Messages", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (_internal_fillSavedMessageHistory(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network)
                |> deliverOnMainQueue).start(completed: {
                    controller.dismiss()
                })
            })
        case .resetDatabase:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Clear Database", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "All secret chats will be lost."),
                    ActionSheetButtonItem(title: "Clear Database", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let databasePath = context.account.basePath + "/postbox/db"
                        let _ = try? FileManager.default.removeItem(atPath: databasePath)
                        exit(0)
                    }),
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                arguments.presentController(actionSheet, nil)
            })
        case .resetDatabaseAndCache:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Clear Database and Cache", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "All secret chats will be lost."),
                    ActionSheetButtonItem(title: "Clear Database", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let databasePath = context.account.basePath + "/postbox"
                        let _ = try? FileManager.default.removeItem(atPath: databasePath)
                        exit(0)
                    }),
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                arguments.presentController(actionSheet, nil)
            })
        case .resetHoles:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reset Holes", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.engine.messages.debugAddHoles()
                |> deliverOnMainQueue).start(completed: {
                    controller.dismiss()
                })
            })
        case .resetTagHoles:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reset Tag Holes", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.engine.messages.debugResetTagHoles()
                |> deliverOnMainQueue).start(completed: {
                    controller.dismiss()
                })
            })
        case .reindexUnread:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reindex Unread Counters", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.engine.messages.debugReindexUnreadCounters()
                |> deliverOnMainQueue).start(completed: {
                    controller.dismiss()
                })
            })
        case .resetCacheIndex:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reset Cache Index [!]", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                
                context.engine.resources.resetStorageIndex()
            })
        case .reindexCache:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reindex Cache", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                
                var signal = context.engine.resources.reindexCacheInBackground(lowImpact: false)
                
                var cancelImpl: (() -> Void)?
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let progressSignal = Signal<Never, NoError> { subscriber in
                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    arguments.presentController(controller, nil)
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                
                let reindexDisposable = MetaDisposable()
                
                signal = signal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = {
                    reindexDisposable.set(nil)
                }
                reindexDisposable.set((signal
                |> deliverOnMainQueue).start(completed: {
                }))
            })
        case .resetBiometricsData:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Reset Biometrics Data", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let _ = updatePresentationPasscodeSettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    return settings.withUpdatedBiometricsDomainState(nil).withUpdatedShareBiometricsDomainState(nil)
                }).start()
            })
        case let .webViewInspection(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Allow Web View Inspection", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.allowWebViewInspection = value
                    return settings
                }).start()
            })
        case .resetWebViewCache:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Clear Web View Cache", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                WKWebsiteDataStore.default().removeData(ofTypes: [
                    WKWebsiteDataTypeDiskCache,
                    WKWebsiteDataTypeOfflineWebApplicationCache,
                    WKWebsiteDataTypeMemoryCache,
                    WKWebsiteDataTypeLocalStorage,
                    WKWebsiteDataTypeCookies,
                    WKWebsiteDataTypeSessionStorage,
                    WKWebsiteDataTypeIndexedDBDatabases,
                    WKWebsiteDataTypeWebSQLDatabases,
                    WKWebsiteDataTypeFetchCache,
                    WKWebsiteDataTypeServiceWorkerRegistrations
                ], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{ })
            })
        case .optimizeDatabase:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Optimize Database", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.account.postbox.optimizeStorage()
                |> deliverOnMainQueue).start(completed: {
                    controller.dismiss()
                    
                    let controller = OverlayStatusController(theme: presentationData.theme, type: .success)
                    arguments.presentController(controller, nil)
                })
            })
        case let .photoPreview(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Media Preview (Updated)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.chatListPhotos = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .knockoutWallpaper(_, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Knockout Wallpaper", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.knockoutWallpaper = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .experimentalCompatibility(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Experimental Compatibility", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.experimentalCompatibility = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableDebugDataDisplay(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Debug Data Display", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableDebugDataDisplay = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .fakeGlass(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Fake glass", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.fakeGlass = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .forceClearGlass(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Force clear glass", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.forceClearGlass = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .debugRipple(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Debug Ripple", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.debugRipple = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .inputDecEngineEditor(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Input V3", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.useInputDecEngine = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .inputDecTextBackend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Text Field v2: InputDec backend", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.inputDecTextBackend = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .coreListChatBackend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Chat: CoreList backend (PoC)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.coreListChatBackend = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .springSendAnimation(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Chat: spring send animation", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.springSendAnimation = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .fakeWalletTransfers(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Wallet: fake transfers", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.fakeWalletTransfers = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .forceRLottieBackend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Lottie: force rlottie", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.forceRLottieBackend = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .respectSystemMicrophone(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Recording: respect system microphone", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.respectSystemMicrophone = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .useModernVideoMessagePipeline(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Use Modern Video Message Pipeline", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.useModernVideoMessagePipeline = value
                        if value && settings.videoMessageCameraMode == .legacy {
                            settings.videoMessageCameraMode = .hdBilinear
                        }
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .videoMessageCameraMode(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Video Message Camera", label: value.debugTitle, sectionId: self.section, style: .blocks, action: {
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = [
                    ActionSheetTextItem(title: "Reopen the camera to apply. VGA and HD use the Modern Video Message Pipeline and record 480×480 at 30 FPS.")
                ]
                for mode in ExperimentalUISettings.VideoMessageCameraMode.allCases {
                    items.append(ActionSheetButtonItem(title: mode.debugTitle, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                            var settings = settings
                            settings.useModernVideoMessagePipeline = mode != .legacy
                            settings.videoMessageCameraMode = mode
                            return settings
                        }).start()
                    }))
                }
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                arguments.presentController(actionSheet, nil)
            })
        case let .browserExperiment(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Inline UI", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.browserExperiment = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .allForumsHaveTabs(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Forum Tabs Debug", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.allForumsHaveTabs = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableReactionOverrides(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Effect Overrides", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableReactionOverrides = value
                        if !value {
                            settings.accountReactionEffectOverrides.removeAll()
                            settings.accountStickerEffectOverrides.removeAll()
                        }
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .compressedEmojiCache(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Compressed Emoji Cache", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.compressedEmojiCache = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .storiesJpegExperiment(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "JPEG X", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.storiesJpegExperiment = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .checkSerializedData(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Check Serialized Data", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.checkSerializedData = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableQuickReactionSwitch(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Enable Quick Reaction", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.disableQuickReaction = !value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .liveStreamV2(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Live Stream V2", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.liveStreamV2 = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .experimentalCallMute(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "[WIP] OS mic mute", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.experimentalCallMute = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .groupCallReferenceEngine(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Group calls: reference engine", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.groupCallReferenceEngine = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .playerV2(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "PlayerV2", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.playerV2 = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .devRequests(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "DevRequests", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.devRequests = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableUpdates(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Enable Updates", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableUpdates = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .pwa(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Test1", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enablePWA = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableLocalTranslation(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Local Translation", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableLocalTranslation = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .disableVideoAspectScaling(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Video Cropping Optimization", value: !value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.disableVideoAspectScaling = !value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableNetworkFramework(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Network X [Restart App]", value: value, sectionId: self.section, style: .blocks, updated: { value in
                if let context = arguments.context {
                    let _ = updateNetworkSettingsInteractively(postbox: context.account.postbox, network: context.account.network, { settings in
                        var settings = settings
                        settings.useNetworkFramework = value
                        return settings
                    }).start()
                }
            })
        case let .enableNetworkExperiments(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Download X [Restart App]", value: value, sectionId: self.section, style: .blocks, updated: { value in
                if let context = arguments.context {
                    let _ = updateNetworkSettingsInteractively(postbox: context.account.postbox, network: context.account.network, { settings in
                        var settings = settings
                        settings.useExperimentalDownload = value
                        return settings
                    }).start()
                }
            })
        case let .rustMTProtoEngine(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Rust MTProto [Restart App]", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateNetworkEngineSettings(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.engine = value ? .rust : .mtProtoKit
                    return settings
                }).start()
            })
        case let .networkEngineInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case .restorePurchases:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Restore Purchases", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.context?.inAppPurchaseManager?.restorePurchases(completion: { state in
                    let text: String
                    switch state {
                        case .succeed:
                            text = "Done"
                        case .failed:
                            text = "Failed"
                    }
                    if let context = arguments.context {
                        let controller = textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: "OK", action: {})])
                        arguments.presentController(controller, nil)
                    }
                })
            })
        case let .disableReloginTokens(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Disable Relogin Tokens", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.disableReloginTokens = value
                    return settings
                }).start()
            })
        case let .hostInfo(_, string):
            return ItemListTextItem(presentationData: presentationData, text: .plain(string), sectionId: self.section)
        case .versionInfo:
            let bundle = Bundle.main
            let bundleId = bundle.bundleIdentifier ?? ""
            let bundleVersion = bundle.infoDictionary?["CFBundleShortVersionString"] ?? ""
            let bundleBuild = bundle.infoDictionary?[kCFBundleVersionKey as String] ?? ""
            return ItemListTextItem(presentationData: presentationData, text: .plain("Telegram for iOS \(bundleVersion) (\(bundleBuild))\n\(bundleId)"), sectionId: self.section, textAlignment: .center)
        case .collectCpuProfile:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Collect CPU Profile (10s)", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(statusController, nil)

                let basePath = arguments.sharedContext.basePath
                CpuProfiler.collectProfile(withDuration: 10.0, sampleRate: 100.0, completion: { report in
                    statusController.dismiss()

                    guard let report = report else {
                        arguments.presentController(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess("A profile is already running", false)), nil)
                        return
                    }

                    let logsPath = basePath + "/logs/profile-logs"
                    let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                    // Logger.collectLogs() only picks up files whose name starts with "log-",
                    // so the profile travels with Send Logs without any extra plumbing.
                    let fileName = "log-cpu-profile-\(dateFormatter.string(from: Date())).txt"

                    do {
                        try report.write(toFile: logsPath + "/" + fileName, atomically: true, encoding: .utf8)
                        arguments.presentController(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess("Saved \(fileName). Send it with Send Profile Logs.", false)), nil)
                    } catch let error {
                        arguments.presentController(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess("Could not save the profile: \(error.localizedDescription)", false)), nil)
                    }
                })
            })
        case .sendProfileLogs:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Send Profile Logs", label: "", sectionId: self.section, style: .blocks, action: {
                let logsPath = arguments.sharedContext.basePath + "/logs/profile-logs"
                let _ = (Logger(rootPath: logsPath, basePath: logsPath).collectLogs()
                    |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer, _ in
                                let peerId = peer.id

                                if let strongController = controller {
                                    strongController.dismiss()

                                    let lineFeed = "\n".data(using: .utf8)!
                                    var rawLogData: Data = Data()
                                    for (name, path) in logs {
                                        if !rawLogData.isEmpty {
                                            rawLogData.append(lineFeed)
                                            rawLogData.append(lineFeed)
                                        }

                                        rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                            rawLogData.append(data)
                                        }
                                    }

                                    let tempSource = EngineTempBox.shared.tempFile(fileName: "Profiles.txt")
                                    let tempZip = EngineTempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    EngineTempBox.shared.dispose(tempSource)
                                    EngineTempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: gzippedData)

                                    let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Profiles-iOS.txt.zip")], alternativeRepresentations: [])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                }
                            }
                            arguments.pushController(controller)
                        }))
                    }
                    items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()

                        let composeController = MFMailComposeViewController()
                        composeController.mailComposeDelegate = arguments.mailComposeDelegate
                        composeController.setSubject("Telegram CPU Profiles")
                        for (name, path) in logs {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                            }
                        }
                        arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                    }))

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        }
    }
}

private func debugControllerEntries(context: AccountContext?, sharedContext: SharedAccountContext, presentationData: PresentationData, loggingSettings: LoggingSettings, mediaInputSettings: MediaInputSettings, experimentalSettings: ExperimentalUISettings, networkSettings: NetworkSettings?, networkEngineSettings: NetworkEngineSettings, hasLegacyAppData: Bool, useBetaFeatures: Bool) -> [DebugControllerEntry] {
    var entries: [DebugControllerEntry] = [.versionInfo(presentationData.theme)]

    let isMainApp = sharedContext.applicationBindings.isMainApp
    
    entries.append(.logsHeader(presentationData.theme))
    entries.append(.sendLogs(presentationData.theme))
    if isMainApp {
        entries.append(.crashReports)
    }

    entries.append(.logToFile(presentationData.theme, loggingSettings.logToFile))
    entries.append(.logToConsole(presentationData.theme, loggingSettings.logToConsole))
    entries.append(.redactSensitiveData(presentationData.theme, loggingSettings.redactSensitiveData))
    entries.append(.logsInfo(presentationData.theme))

    if isMainApp {
        entries.append(.accounts(presentationData.theme))
    }

    entries.append(.resetAppHeader(presentationData.theme))
    if isMainApp {
        entries.append(.clearTips(presentationData.theme))
    }
    entries.append(.resetDatabase(presentationData.theme))
    entries.append(.resetDatabaseAndCache(presentationData.theme))
    if isMainApp {
        entries.append(.resetNotifications)
    }
    entries.append(.fillLocalSavedMessageCache)
    entries.append(.resetHoles(presentationData.theme))
    entries.append(.resetTagHoles)
    if isMainApp {
        entries.append(.reindexUnread(presentationData.theme))
        entries.append(.resetCacheIndex)
        entries.append(.reindexCache)
    }
    entries.append(.optimizeDatabase(presentationData.theme))
    if isMainApp {
        entries.append(.restorePurchases(presentationData.theme))
    }

    entries.append(.experimentsHeader(presentationData.theme))
    if isMainApp {
        entries.append(.keepChatNavigationStack(presentationData.theme, experimentalSettings.keepChatNavigationStack))
        #if DEBUG
        entries.append(.skipReadHistory(presentationData.theme, experimentalSettings.skipReadHistory))
        #endif
        entries.append(.alwaysDisplayTyping(experimentalSettings.alwaysDisplayTyping))
        entries.append(.debugRatingLayout(experimentalSettings.debugRatingLayout))
    }
    entries.append(.coreListChatBackend(experimentalSettings.coreListChatBackend))
    entries.append(.forceRLottieBackend(experimentalSettings.forceRLottieBackend))
    entries.append(.respectSystemMicrophone(experimentalSettings.respectSystemMicrophone))
    let useModernVideoMessagePipeline = (experimentalSettings.useModernVideoMessagePipeline ?? (context?.getAppConfigValue("ios_killswitch_disable_neo_round_camera_v2") == nil)) && experimentalSettings.videoMessageCameraMode != .legacy
    entries.append(.useModernVideoMessagePipeline(useModernVideoMessagePipeline))
    entries.append(.videoMessageCameraMode(useModernVideoMessagePipeline ? experimentalSettings.videoMessageCameraMode : .legacy))
    entries.append(.crashOnSlowQueries(presentationData.theme, experimentalSettings.crashOnLongQueries))
    entries.append(.crashOnMemoryPressure(presentationData.theme, experimentalSettings.crashOnMemoryPressure))
    entries.append(.crash(presentationData.theme))
    #if DEBUG
    if isMainApp {
        entries.append(.testPasscodeMigration)
    }
    #endif
    if isMainApp {
        entries.append(.knockoutWallpaper(presentationData.theme, experimentalSettings.knockoutWallpaper))
        entries.append(.experimentalCompatibility(experimentalSettings.experimentalCompatibility))
        entries.append(.enableDebugDataDisplay(experimentalSettings.enableDebugDataDisplay))
        entries.append(.fakeGlass(experimentalSettings.fakeGlass))
        entries.append(.forceClearGlass(experimentalSettings.forceClearGlass))
        entries.append(.debugRipple(experimentalSettings.debugRipple))
        entries.append(.inputDecEngineEditor(experimentalSettings.useInputDecEngine))
        #if DEBUG
        entries.append(.browserExperiment(experimentalSettings.browserExperiment))
        #else
        if sharedContext.applicationBindings.appBuildType == .internal {
            entries.append(.browserExperiment(experimentalSettings.browserExperiment))
        }
        #endif
        entries.append(.allForumsHaveTabs(experimentalSettings.allForumsHaveTabs))
        if case .internal = sharedContext.applicationBindings.appBuildType {
            entries.append(.enableReactionOverrides(experimentalSettings.enableReactionOverrides))
        }
        
        entries.append(.compressedEmojiCache(experimentalSettings.compressedEmojiCache))
        entries.append(.storiesJpegExperiment(experimentalSettings.storiesJpegExperiment))
        entries.append(.disableReloginTokens(experimentalSettings.disableReloginTokens))
        
        entries.append(.checkSerializedData(experimentalSettings.checkSerializedData))
        entries.append(.enableQuickReactionSwitch(!experimentalSettings.disableQuickReaction))
        entries.append(.liveStreamV2(experimentalSettings.liveStreamV2))
        entries.append(.experimentalCallMute(experimentalSettings.experimentalCallMute))
        entries.append(.groupCallReferenceEngine(experimentalSettings.groupCallReferenceEngine))
        
        entries.append(.playerV2(experimentalSettings.playerV2))
        
        entries.append(.devRequests(experimentalSettings.devRequests))
        
        if let data = context?.currentAppConfiguration.with({ $0 }).data {
            var displayPwa = false
            if let _ = data["ios_display_pwa"] {
                displayPwa = true
            } else if let isDev = data["dev"] as? Double, isDev == 1.0 {
                displayPwa = true
            }
            if displayPwa {
                entries.append(.pwa(experimentalSettings.enablePWA))
            }
        }
        entries.append(.enableLocalTranslation(experimentalSettings.enableLocalTranslation))
        entries.append(.enableUpdates(experimentalSettings.enableUpdates))
        #if DEBUG
        entries.append(.inputDecTextBackend(experimentalSettings.inputDecTextBackend))
        #else
        if sharedContext.applicationBindings.appBuildType == .internal {
            entries.append(.inputDecTextBackend(experimentalSettings.inputDecTextBackend))
        }
        #endif
        entries.append(.springSendAnimation(experimentalSettings.springSendAnimation))
        if let data = context?.currentAppConfiguration.with({ $0 }).data, let isDev = data["dev"] as? Double, isDev == 1.0 {
            entries.append(.fakeWalletTransfers(experimentalSettings.fakeWalletTransfers))
        }
        
        entries.append(.logTranslationRecognition(experimentalSettings.logLanguageRecognition))
        entries.append(.resetTranslationStates)
    }

    if isMainApp {
        entries.append(.webViewInspection(experimentalSettings.allowWebViewInspection))
        entries.append(.resetWebViewCache(presentationData.theme))

        entries.append(.disableVideoAspectScaling(experimentalSettings.disableVideoAspectScaling))
        entries.append(.enableNetworkFramework(networkSettings?.useNetworkFramework ?? useBetaFeatures))
        entries.append(.enableNetworkExperiments(networkSettings?.useExperimentalDownload ?? true))
        entries.append(.rustMTProtoEngine(networkEngineSettings.engine == .rust))
        if let context {
            // The engine this account actually runs. The switch alone does not say: the factory
            // still declines (WEB proxy, DC address overrides) and mtproto_engine_rust_disabled
            // forces MtProtoKit.
            entries.append(.networkEngineInfo("Engine: \(context.account.network.engineKind.rawValue)"))
        }
    }

    if let backupHostOverride = networkSettings?.backupHostOverride {
        entries.append(.hostInfo(presentationData.theme, "Host: \(backupHostOverride)"))
    }
    
    entries.append(.collectCpuProfile)
    entries.append(.sendProfileLogs)
    
    return entries
}

public func debugController(sharedContext: SharedAccountContext, context: AccountContext?, modal: Bool = false) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var getRootControllerImpl: (() -> UIViewController?)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    let arguments = DebugControllerArguments(sharedContext: sharedContext, context: context, mailComposeDelegate: DebugControllerMailComposeDelegate(), presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, getRootController: {
        return getRootControllerImpl?()
    }, getNavigationController: {
        return getNavigationControllerImpl?()
    })
    
    let appGroupName = "group.\(Bundle.main.bundleIdentifier!)"
    let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
    
    var hasLegacyAppData = false
    if let appGroupUrl = maybeAppGroupUrl {
        let statusPath = appGroupUrl.path + "/Documents/importcompleted"
        hasLegacyAppData = FileManager.default.fileExists(atPath: statusPath)
    }
    
    let preferencesSignal: Signal<EnginePreferencesEntry?, NoError>
    if let context = context {
        preferencesSignal = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.networkSettings))
    } else {
        preferencesSignal = .single(nil)
    }
    
    let signal = combineLatest(sharedContext.presentationData, sharedContext.accountManager.sharedData(keys: Set([SharedDataKeys.loggingSettings, ApplicationSpecificSharedDataKeys.mediaInputSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings, SharedDataKeys.networkEngineSettings])), preferencesSignal)
    |> map { presentationData, sharedData, preferences -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let loggingSettings: LoggingSettings
        if let value = sharedData.entries[SharedDataKeys.loggingSettings]?.get(LoggingSettings.self) {
            loggingSettings = value
        } else {
            loggingSettings = LoggingSettings.defaultSettings
        }
        
        let mediaInputSettings: MediaInputSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.mediaInputSettings]?.get(MediaInputSettings.self) {
            mediaInputSettings = value
        } else {
            mediaInputSettings = MediaInputSettings.defaultSettings
        }
        
        let experimentalSettings: ExperimentalUISettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
        
        let networkSettings: NetworkSettings? = preferences?.get(NetworkSettings.self)
        let networkEngineSettings: NetworkEngineSettings = sharedData.entries[SharedDataKeys.networkEngineSettings]?.get(NetworkEngineSettings.self) ?? NetworkEngineSettings.defaultSettings
        
        var leftNavigationButton: ItemListNavigationButton?
        if modal {
            leftNavigationButton = ItemListNavigationButton(content: .icon(.close), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        }
        
        var useBetaFeatures: Bool = false
        if let context {
            useBetaFeatures = context.account.network.useBetaFeatures
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Debug Settings"), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: debugControllerEntries(context: context, sharedContext: sharedContext, presentationData: presentationData, loggingSettings: loggingSettings, mediaInputSettings: mediaInputSettings, experimentalSettings: experimentalSettings, networkSettings: networkSettings, networkEngineSettings: networkEngineSettings, hasLegacyAppData: hasLegacyAppData, useBetaFeatures: useBetaFeatures), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    
    let controller = ItemListController(sharedContext: sharedContext, state: signal)
    arguments.openLogs = { [weak controller, weak arguments] in
        guard let controller, let arguments,
              let sourceNode = controller.itemNode(forTag: DebugControllerItemTag.sendLogs) as? ItemListActionItemNode else {
            return
        }
        var options: [DebugLogAction] = [.sendLogs, .sendShareLogs]
        if arguments.context != nil {
            options.append(.sendGroupCallLogs)
        }
        options.append(contentsOf: [.sendNotificationLogs, .sendCriticalLogs, .sendAllLogs, .sendStorageStats])
        let items: [ContextMenuItem] = options.map { option in
            return .action(ContextMenuActionItem(text: option.title, textLayout: option.textLayout, icon: { _ in nil }, action: { menu, _ in
                var subItems: [ContextMenuItem] = [
                    .action(ContextMenuActionItem(text: sharedContext.currentPresentationData.with { $0 }.strings.Common_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                    }, iconPosition: .left, action: { menu, _ in
                        menu?.popItems()
                    })),
                    .separator
                ]
                if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                    subItems.append(.action(ContextMenuActionItem(text: "Via Telegram", icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Telegram"), color: theme.contextMenu.primaryColor)
                    }, action: { menu, _ in
                        menu?.dismiss(completion: {
                            option.perform(arguments: arguments, destination: .telegram)
                        })
                    })))
                }
                if option != .sendAllLogs && option != .sendStorageStats {
                    subItems.append(.action(ContextMenuActionItem(text: "Via Email", icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Item List/Icons/Email"), color: theme.contextMenu.primaryColor)
                    }, action: { menu, _ in
                        menu?.dismiss(completion: {
                            option.perform(arguments: arguments, destination: .email)
                        })
                    })))
                }
                menu?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
            }))
        }
        let menu = makeContextController(
            presentationData: sharedContext.currentPresentationData.with { $0 },
            source: .reference(DebugLogsContextReferenceContentSource(sourceView: sourceNode.view)),
            items: .single(ContextController.Items(content: .list(items))),
            gesture: nil
        )
        controller.presentInGlobalOverlay(menu, with: nil)
    }
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
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}

public func triggerDebugSendLogsUI(context: AccountContext, additionalInfo: String = "", pushController: @escaping (ViewController) -> Void) {
    let _ = (Logger.shared.collectLogs()
    |> deliverOnMainQueue).start(next: { logs in
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
        controller.peerSelected = { [weak controller] peer, _ in
            let peerId = peer.id

            if let strongController = controller {
                strongController.dismiss()

                let lineFeed = "\n".data(using: .utf8)!
                var rawLogData: Data = Data()
                for (name, path) in logs {
                    if !rawLogData.isEmpty {
                        rawLogData.append(lineFeed)
                        rawLogData.append(lineFeed)
                    }

                    rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        rawLogData.append(data)
                    }
                }
                
                if !additionalInfo.isEmpty {
                    rawLogData.append("------ Additional Info ------\n".data(using: .utf8)!)
                    rawLogData.append("\(additionalInfo)".data(using: .utf8)!)
                }
                
                let tempSource = EngineTempBox.shared.tempFile(fileName: "Log.txt")
                let tempZip = EngineTempBox.shared.tempFile(fileName: "destination.zip")
                
                let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                
                SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                    return
                }
                
                EngineTempBox.shared.dispose(tempSource)
                EngineTempBox.shared.dispose(tempZip)

                let id = Int64.random(in: Int64.min ... Int64.max)
                let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                context.engine.resources.storeResourceData(id: EngineMediaResource.Id(fileResource.id), data: gzippedData)

                let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")], alternativeRepresentations: [])
                let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
            }
        }
        pushController(controller)
    })
}
