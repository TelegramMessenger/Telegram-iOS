import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
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

private enum DebugControllerSection: Int32 {
    case sticker
    case logs
    case logging
    case experiments
    case videoExperiments
    case videoExperiments2
    case info
}

private enum DebugControllerEntry: ItemListNodeEntry {
    case testStickerImport(PresentationTheme)
    case sendLogs(PresentationTheme)
    case sendOneLog(PresentationTheme)
    case sendShareLogs
    case sendGroupCallLogs
    case sendNotificationLogs(PresentationTheme)
    case sendCriticalLogs(PresentationTheme)
    case sendAllLogs
    case accounts(PresentationTheme)
    case logToFile(PresentationTheme, Bool)
    case logToConsole(PresentationTheme, Bool)
    case redactSensitiveData(PresentationTheme, Bool)
    case enableRaiseToSpeak(PresentationTheme, Bool)
    case keepChatNavigationStack(PresentationTheme, Bool)
    case skipReadHistory(PresentationTheme, Bool)
    case crashOnSlowQueries(PresentationTheme, Bool)
    case clearTips(PresentationTheme)
    case crash(PresentationTheme)
    case resetData(PresentationTheme)
    case resetDatabase(PresentationTheme)
    case resetDatabaseAndCache(PresentationTheme)
    case resetHoles(PresentationTheme)
    case reindexUnread(PresentationTheme)
    case resetBiometricsData(PresentationTheme)
    case resetWebViewCache(PresentationTheme)
    case optimizeDatabase(PresentationTheme)
    case photoPreview(PresentationTheme, Bool)
    case knockoutWallpaper(PresentationTheme, Bool)
    case experimentalCompatibility(Bool)
    case enableDebugDataDisplay(Bool)
    case acceleratedStickers(Bool)
    case experimentalBackground(Bool)
    case inlineStickers(Bool)
    case localTranscription(Bool)
    case enableReactionOverrides(Bool)
    case playerEmbedding(Bool)
    case playlistPlayback(Bool)
    case voiceConference
    case preferredVideoCodec(Int, String, String?, Bool)
    case disableVideoAspectScaling(Bool)
    case enableVoipTcp(Bool)
    case restorePurchases(PresentationTheme)
    case hostInfo(PresentationTheme, String)
    case versionInfo(PresentationTheme)
    
    var section: ItemListSectionId {
        switch self {
        case .testStickerImport:
            return DebugControllerSection.sticker.rawValue
        case .sendLogs, .sendOneLog, .sendShareLogs, .sendGroupCallLogs, .sendNotificationLogs, .sendCriticalLogs, .sendAllLogs:
            return DebugControllerSection.logs.rawValue
        case .accounts:
            return DebugControllerSection.logs.rawValue
        case .logToFile, .logToConsole, .redactSensitiveData:
            return DebugControllerSection.logging.rawValue
        case .enableRaiseToSpeak, .keepChatNavigationStack, .skipReadHistory, .crashOnSlowQueries:
            return DebugControllerSection.experiments.rawValue
        case .clearTips, .crash, .resetData, .resetDatabase, .resetDatabaseAndCache, .resetHoles, .reindexUnread, .resetBiometricsData, .resetWebViewCache, .optimizeDatabase, .photoPreview, .knockoutWallpaper, .playerEmbedding, .playlistPlayback, .voiceConference, .experimentalCompatibility, .enableDebugDataDisplay, .acceleratedStickers, .experimentalBackground, .inlineStickers, .localTranscription, . enableReactionOverrides, .restorePurchases:
            return DebugControllerSection.experiments.rawValue
        case .preferredVideoCodec:
            return DebugControllerSection.videoExperiments.rawValue
        case .disableVideoAspectScaling, .enableVoipTcp:
            return DebugControllerSection.videoExperiments2.rawValue
        case .hostInfo, .versionInfo:
            return DebugControllerSection.info.rawValue
        }
    }
    
    var stableId: Int {
        switch self {
        case .testStickerImport:
            return 0
        case .sendLogs:
            return 1
        case .sendOneLog:
            return 2
        case .sendShareLogs:
            return 3
        case .sendGroupCallLogs:
            return 4
        case .sendNotificationLogs:
            return 5
        case .sendCriticalLogs:
            return 6
        case .sendAllLogs:
            return 7
        case .accounts:
            return 8
        case .logToFile:
            return 9
        case .logToConsole:
            return 10
        case .redactSensitiveData:
            return 11
        case .enableRaiseToSpeak:
            return 12
        case .keepChatNavigationStack:
            return 13
        case .skipReadHistory:
            return 14
        case .crashOnSlowQueries:
            return 15
        case .clearTips:
            return 16
        case .crash:
            return 17
        case .resetData:
            return 18
        case .resetDatabase:
            return 19
        case .resetDatabaseAndCache:
            return 20
        case .resetHoles:
            return 21
        case .reindexUnread:
            return 22
        case .resetBiometricsData:
            return 23
        case .resetWebViewCache:
            return 24
        case .optimizeDatabase:
            return 25
        case .photoPreview:
            return 26
        case .knockoutWallpaper:
            return 27
        case .experimentalCompatibility:
            return 28
        case .enableDebugDataDisplay:
            return 29
        case .acceleratedStickers:
            return 30
        case .experimentalBackground:
            return 31
        case .inlineStickers:
            return 32
        case .localTranscription:
            return 33
        case .enableReactionOverrides:
            return 34
        case .restorePurchases:
            return 35
        case .playerEmbedding:
            return 36
        case .playlistPlayback:
            return 37
        case .voiceConference:
            return 38
        case let .preferredVideoCodec(index, _, _, _):
            return 39 + index
        case .disableVideoAspectScaling:
            return 100
        case .enableVoipTcp:
            return 101
        case .hostInfo:
            return 102
        case .versionInfo:
            return 103
        }
    }
    
    static func <(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DebugControllerArguments
        switch self {
        case .testStickerImport:
            return ItemListActionItem(presentationData: presentationData, title: "Simulate Stickers Import", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
                    context.sharedContext.openResolvedUrl(.importStickers, context: context, urlContext: .generic, navigationController: arguments.getNavigationController(), forceExternal: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { c, a in arguments.presentController(c, a as? ViewControllerPresentationArguments) }, dismissInput: {}, contentContext: nil)
                }
            })
        case .sendLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Logs (Up to 40 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs()
                |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer in
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

                                    let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    TempBox.shared.dispose(tempSource)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)

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
                        composeController.setSubject("Telegram Logs")
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
        case .sendOneLog:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Latest Logs (Up to 4 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs()
                    |> deliverOnMainQueue).start(next: { logs in
                        let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        
                        var items: [ActionSheetButtonItem] = []
                        
                        if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                            items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                                controller.peerSelected = { [weak controller] peer in
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
                                        context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: logData)
                                        
                                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(logData.count), attributes: [.FileName(fileName: "Log-iOS-Short.txt")])
                                        let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)
                                        
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
                            composeController.setSubject("Telegram Logs")
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
                            ])
                            ])
                        arguments.presentController(actionSheet, nil)
                    })
            })
        case .sendShareLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Share Logs (Up to 40 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs(prefix: "/logs/share-logs")
                |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer in
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

                                    let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    TempBox.shared.dispose(tempSource)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)

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
                        composeController.setSubject("Telegram Logs")
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
        case .sendGroupCallLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Group Call Logs (Up to 40 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs(basePath: arguments.context!.account.basePath + "/group-calls")
                |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer in
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

                                    let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    TempBox.shared.dispose(tempSource)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)

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
                        composeController.setSubject("Telegram Logs")
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
        case .sendNotificationLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Notification Logs (Up to 40 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger(rootPath: arguments.sharedContext.basePath, basePath: arguments.sharedContext.basePath + "/logs/notification-logs").collectLogs()
                    |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer in
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

                                    let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    TempBox.shared.dispose(tempSource)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)

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
                        composeController.setSubject("Telegram Logs")
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
        case .sendCriticalLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Critical Logs", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectShortLogFiles()
                    |> deliverOnMainQueue).start(next: { logs in
                        let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        
                        var items: [ActionSheetButtonItem] = []
                        
                        if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                            items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                                controller.peerSelected = { [weak controller] peer in
                                    let peerId = peer.id
                                    
                                    if let strongController = controller {
                                        strongController.dismiss()
                                        
                                        let messages = logs.map { (name, path) -> EnqueueMessage in
                                            let id = Int64.random(in: Int64.min ... Int64.max)
                                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                                            return .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)
                                        }
                                        let _ = enqueueMessages(account: context.account, peerId: peerId, messages: messages).start()
                                    }
                                }
                                arguments.pushController(controller)
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
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                            ])])
                        arguments.presentController(actionSheet, nil)
                    })
            })
        case .sendAllLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send All Logs", label: "", sectionId: self.section, style: .blocks, action: {
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
                    logByType.append(Logger(rootPath: arguments.sharedContext.basePath, basePath: arguments.sharedContext.basePath + "/logs/\(type)").collectLogs()
                    |> map { result -> (type: String, logs: [(String, String)]) in
                        return (type, result)
                    })
                }
                
                let allLogs = combineLatest(logByType)
                
                let _ = (allLogs
                |> deliverOnMainQueue).start(next: { allLogs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer in
                                let peerId = peer.id

                                if let strongController = controller {
                                    strongController.dismiss()

                                    let lineFeed = "\n".data(using: .utf8)!
                                    
                                    var tempSources: [TempBoxFile] = []
                                    for (type, logItems) in allLogs {
                                        let tempSource = TempBox.shared.tempFile(fileName: "Log-\(type).txt")
                                        
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

                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: tempSources.map(\.path))

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    tempSources.forEach(TempBox.shared.dispose)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/zip", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-All.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)

                                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                }
                            }
                            arguments.pushController(controller)
                        }))
                    }

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .accounts:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Accounts", label: "", sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                arguments.pushController(debugAccountsController(context: context, accountManager: arguments.sharedContext.accountManager))
            })
        case let .logToFile(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Log to File", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedLogToFile(value)
                }).start()
            })
        case let .logToConsole(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Log to Console", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedLogToConsole(value)
                }).start()
            })
        case let .redactSensitiveData(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Remove Sensitive Data", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedRedactSensitiveData(value)
                }).start()
            })
        case let .enableRaiseToSpeak(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Enable Raise to Speak", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateMediaInputSettingsInteractively(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedEnableRaiseToSpeak(value)
                }).start()
            })
        case let .keepChatNavigationStack(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Keep Chat Stack", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.keepChatNavigationStack = value
                    return settings
                }).start()
            })
        case let .skipReadHistory(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Skip read history", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.skipReadHistory = value
                    return settings
                }).start()
            })
        case let .crashOnSlowQueries(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Crash when slow", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.crashOnLongQueries = value
                    return settings
                }).start()
            })
        case .clearTips:
            return ItemListActionItem(presentationData: presentationData, title: "Clear Tips", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
        case .crash:
            return ItemListActionItem(presentationData: presentationData, title: "Crash", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                preconditionFailure()
            })
        case .resetData:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Data", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "All data will be lost."),
                    ActionSheetButtonItem(title: "Reset Data", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let databasePath = arguments.sharedContext.accountManager.basePath + "/db"
                        let _ = try? FileManager.default.removeItem(atPath: databasePath)
                        preconditionFailure()
                    }),
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                        ])])
                arguments.presentController(actionSheet, nil)
            })
        case .resetDatabase:
            return ItemListActionItem(presentationData: presentationData, title: "Clear Database", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
            return ItemListActionItem(presentationData: presentationData, title: "Clear Database and Cache", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
            return ItemListActionItem(presentationData: presentationData, title: "Reset Holes", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
        case .reindexUnread:
            return ItemListActionItem(presentationData: presentationData, title: "Reindex Unread Counters", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
        case .resetBiometricsData:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Biometrics Data", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let _ = updatePresentationPasscodeSettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    return settings.withUpdatedBiometricsDomainState(nil).withUpdatedShareBiometricsDomainState(nil)
                }).start()
            })
        case .resetWebViewCache:
            return ItemListActionItem(presentationData: presentationData, title: "Clear Web View Cache", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{ })
            })
        case .optimizeDatabase:
            return ItemListActionItem(presentationData: presentationData, title: "Optimize Database", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
            return ItemListSwitchItem(presentationData: presentationData, title: "Media Preview (Updated)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.chatListPhotos = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .knockoutWallpaper(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Knockout Wallpaper", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.knockoutWallpaper = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .experimentalCompatibility(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Experimental Compatibility", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.experimentalCompatibility = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableDebugDataDisplay(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Debug Data Display", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableDebugDataDisplay = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .acceleratedStickers(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Accelerated Stickers", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.acceleratedStickers = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .experimentalBackground(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Background Experiment", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.experimentalBackground = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .inlineStickers(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Inline Stickers", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.inlineStickers = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .localTranscription(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Local Transcription", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.localTranscription = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableReactionOverrides(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Effect Overrides", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableReactionOverrides = value
                        if !value {
                            settings.accountReactionEffectOverrides.removeAll()
                            settings.accountStickerEffectOverrides.removeAll()
                        }
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .playerEmbedding(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Player Embedding", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.playerEmbedding = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .playlistPlayback(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Playlist Playback", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.playlistPlayback = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case .voiceConference:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Voice Conference (Test)", label: "", sectionId: self.section, style: .blocks, action: {
                guard let _ = arguments.context else {
                    return
                }
            })
        case let .preferredVideoCodec(_, title, value, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .right, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.preferredVideoCodec = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .disableVideoAspectScaling(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Video Cropping Optimization", value: !value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.disableVideoAspectScaling = !value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableVoipTcp(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Enable VoIP TCP", value: !value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableVoipTcp = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case .restorePurchases:
            return ItemListActionItem(presentationData: presentationData, title: "Restore Purchases", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
        case let .hostInfo(_, string):
            return ItemListTextItem(presentationData: presentationData, text: .plain(string), sectionId: self.section)
        case .versionInfo:
            let bundle = Bundle.main
            let bundleId = bundle.bundleIdentifier ?? ""
            let bundleVersion = bundle.infoDictionary?["CFBundleShortVersionString"] ?? ""
            let bundleBuild = bundle.infoDictionary?[kCFBundleVersionKey as String] ?? ""
            return ItemListTextItem(presentationData: presentationData, text: .plain("\(bundleId)\n\(bundleVersion) (\(bundleBuild))"), sectionId: self.section)
        }
    }
}

private func debugControllerEntries(sharedContext: SharedAccountContext, presentationData: PresentationData, loggingSettings: LoggingSettings, mediaInputSettings: MediaInputSettings, experimentalSettings: ExperimentalUISettings, networkSettings: NetworkSettings?, hasLegacyAppData: Bool) -> [DebugControllerEntry] {
    var entries: [DebugControllerEntry] = []

    let isMainApp = sharedContext.applicationBindings.isMainApp
    
//    entries.append(.testStickerImport(presentationData.theme))
    entries.append(.sendLogs(presentationData.theme))
    //entries.append(.sendOneLog(presentationData.theme))
    entries.append(.sendShareLogs)
    entries.append(.sendGroupCallLogs)
    entries.append(.sendNotificationLogs(presentationData.theme))
    entries.append(.sendCriticalLogs(presentationData.theme))
    entries.append(.sendAllLogs)
    if isMainApp {
        entries.append(.accounts(presentationData.theme))
    }
    
    entries.append(.logToFile(presentationData.theme, loggingSettings.logToFile))
    entries.append(.logToConsole(presentationData.theme, loggingSettings.logToConsole))
    entries.append(.redactSensitiveData(presentationData.theme, loggingSettings.redactSensitiveData))

    if isMainApp {
        entries.append(.enableRaiseToSpeak(presentationData.theme, mediaInputSettings.enableRaiseToSpeak))
        entries.append(.keepChatNavigationStack(presentationData.theme, experimentalSettings.keepChatNavigationStack))
        #if DEBUG
        entries.append(.skipReadHistory(presentationData.theme, experimentalSettings.skipReadHistory))
        #endif
    }
    entries.append(.crashOnSlowQueries(presentationData.theme, experimentalSettings.crashOnLongQueries))
    if isMainApp {
        entries.append(.clearTips(presentationData.theme))
    }
    entries.append(.crash(presentationData.theme))
    entries.append(.resetData(presentationData.theme))
    entries.append(.resetDatabase(presentationData.theme))
    entries.append(.resetDatabaseAndCache(presentationData.theme))
    entries.append(.resetHoles(presentationData.theme))
    if isMainApp {
        entries.append(.reindexUnread(presentationData.theme))
        entries.append(.resetWebViewCache(presentationData.theme))
    }
    entries.append(.optimizeDatabase(presentationData.theme))
    if isMainApp {
        entries.append(.knockoutWallpaper(presentationData.theme, experimentalSettings.knockoutWallpaper))
        entries.append(.experimentalCompatibility(experimentalSettings.experimentalCompatibility))
        entries.append(.enableDebugDataDisplay(experimentalSettings.enableDebugDataDisplay))
        entries.append(.acceleratedStickers(experimentalSettings.acceleratedStickers))
        entries.append(.experimentalBackground(experimentalSettings.experimentalBackground))
        entries.append(.inlineStickers(experimentalSettings.inlineStickers))
        entries.append(.localTranscription(experimentalSettings.localTranscription))
        if case .internal = sharedContext.applicationBindings.appBuildType {
            entries.append(.enableReactionOverrides(experimentalSettings.enableReactionOverrides))
        }
        entries.append(.restorePurchases(presentationData.theme))
        entries.append(.playerEmbedding(experimentalSettings.playerEmbedding))
        entries.append(.playlistPlayback(experimentalSettings.playlistPlayback))
    }
    
    let codecs: [(String, String?)] = [
        ("No Preference", nil),
        ("H265", "H265"),
        ("H264", "H264"),
        ("VP8", "VP8"),
        ("VP9", "VP9")
    ]
    
    for i in 0 ..< codecs.count {
        entries.append(.preferredVideoCodec(i, codecs[i].0, codecs[i].1, experimentalSettings.preferredVideoCodec == codecs[i].1))
    }

    if isMainApp {
        entries.append(.disableVideoAspectScaling(experimentalSettings.disableVideoAspectScaling))
        entries.append(.enableVoipTcp(experimentalSettings.enableVoipTcp))
    }

    if let backupHostOverride = networkSettings?.backupHostOverride {
        entries.append(.hostInfo(presentationData.theme, "Host: \(backupHostOverride)"))
    }
    entries.append(.versionInfo(presentationData.theme))
    
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
    
    let preferencesSignal: Signal<PreferencesView?, NoError>
    if let context = context {
        preferencesSignal = context.account.postbox.preferencesView(keys: [PreferencesKeys.networkSettings])
        |> map(Optional.init)
    } else {
        preferencesSignal = .single(nil)
    }
    
    let signal = combineLatest(sharedContext.presentationData, sharedContext.accountManager.sharedData(keys: Set([SharedDataKeys.loggingSettings, ApplicationSpecificSharedDataKeys.mediaInputSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings])), preferencesSignal)
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
        
        let networkSettings: NetworkSettings? = preferences?.values[PreferencesKeys.networkSettings]?.get(NetworkSettings.self)
        
        var leftNavigationButton: ItemListNavigationButton?
        if modal {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Debug"), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: debugControllerEntries(sharedContext: sharedContext, presentationData: presentationData, loggingSettings: loggingSettings, mediaInputSettings: mediaInputSettings, experimentalSettings: experimentalSettings, networkSettings: networkSettings, hasLegacyAppData: hasLegacyAppData), style: .blocks)
        
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
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}

public func triggerDebugSendLogsUI(context: AccountContext, additionalInfo: String = "", pushController: @escaping (ViewController) -> Void) {
    let _ = (Logger.shared.collectLogs()
    |> deliverOnMainQueue).start(next: { logs in
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
        controller.peerSelected = { [weak controller] peer in
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
                
                let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                
                let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                
                SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                    return
                }
                
                TempBox.shared.dispose(tempSource)
                TempBox.shared.dispose(tempZip)

                let id = Int64.random(in: Int64.min ... Int64.max)
                let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)

                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
            }
        }
        pushController(controller)
    })
}
