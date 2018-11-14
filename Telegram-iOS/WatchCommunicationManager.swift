import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUI

final class WatchCommunicationManager {
    private let queue: Queue
    private var server: TGBridgeServer!
    
    private let contextDisposable = MetaDisposable()
    private let presetsDisposable = MetaDisposable()
    
    let account = Promise<Account?>(nil)
    private let presets = Promise<WatchPresetSettings?>(nil)
    private let navigateToMessagePipe = ValuePipe<MessageId>()
    
    init(queue: Queue, context: Promise<ApplicationContext?>) {
        self.queue = queue
        
        let handlers = allWatchRequestHandlers.reduce([String : AnyClass]()) { (map, handler) -> [String : AnyClass] in
            var map = map
            if let handler = handler as? WatchRequestHandler.Type {
                for case let subscription as TGBridgeSubscription.Type in handler.handledSubscriptions {
                    if let name = subscription.subscriptionName() {
                        map[name] = handler
                    }
                }
            }
            return map
        }
        
        self.server = TGBridgeServer(handler: { [weak self] subscription -> SSignal? in
            guard let strongSelf = self, let subscription = subscription, let handler = handlers[subscription.name] as? WatchRequestHandler.Type else {
                return nil
            }
            return handler.handle(subscription: subscription, manager: strongSelf)
        }, fileHandler: { [weak self] path, metadata in
            guard let strongSelf = self, let path = path, let metadata = metadata as? [String : Any] else {
                return
            }
            if metadata[TGBridgeIncomingFileTypeKey] as? String == TGBridgeIncomingFileTypeAudio {
                let _ = WatchAudioHandler.handleFile(path: path, metadata: metadata, manager: strongSelf).start()
            }
        }, dispatchOnQueue: { [weak self] block in
            if let strongSelf = self, let block = block {
                strongSelf.queue.justDispatch(block)
            }
        }, logFunction: { value in
            if let value = value {
                Logger.shared.log("WatchBridge", value)
            }
        })
        self.server.startRunning()
        
        self.contextDisposable.set((combineLatest(self.watchAppInstalled, context.get() |> deliverOn(self.queue))).start(next: { [weak self] appInstalled, appContext in
            guard let strongSelf = self, appInstalled else {
                return
            }
            if let appContext = appContext, case let .authorized(context) = appContext {
                strongSelf.account.set(.single(context.account))
                strongSelf.server.setAuthorized(true, userId: context.account.peerId.id)
                strongSelf.server.setMicAccessAllowed(false)
                strongSelf.server.pushContext()
                strongSelf.server.setMicAccessAllowed(true)
                strongSelf.server.pushContext()
                
                let watchPresetSettingsKey = ApplicationSpecificPreferencesKeys.watchPresetSettings
                strongSelf.presets.set(context.account.postbox.preferencesView(keys: [watchPresetSettingsKey])
                |> map({ preferences -> WatchPresetSettings in
                    return (preferences.values[watchPresetSettingsKey] as? WatchPresetSettings) ?? WatchPresetSettings.defaultSettings
                }))
            } else {
                strongSelf.account.set(.single(nil))
                strongSelf.server.setAuthorized(false, userId: 0)
                strongSelf.server.pushContext()
                
                strongSelf.presets.set(.single(nil))
            }
        }))
        
        self.presetsDisposable.set((combineLatest(self.watchAppInstalled, self.presets.get() |> distinctUntilChanged |> deliverOn(self.queue), context.get() |> deliverOn(self.queue))).start(next: { [weak self] appInstalled, presets, appContext in
            guard let strongSelf = self, let presets = presets, let appContext = appContext, case let .authorized(context) = appContext, appInstalled, let tempPath = strongSelf.watchTemporaryStorePath else {
                return
            }
            let presentationData = context.account.telegramApplicationContext.currentPresentationData.with { $0 }
            let defaultSuggestions: [String : String] = [
                "OK": presentationData.strings.Watch_Suggestion_OK,
                "Thanks": presentationData.strings.Watch_Suggestion_Thanks,
                "WhatsUp": presentationData.strings.Watch_Suggestion_WhatsUp,
                "TalkLater": presentationData.strings.Watch_Suggestion_TalkLater,
                "CantTalk": presentationData.strings.Watch_Suggestion_CantTalk,
                "HoldOn": presentationData.strings.Watch_Suggestion_HoldOn,
                "BRB": presentationData.strings.Watch_Suggestion_BRB,
                "OnMyWay": presentationData.strings.Watch_Suggestion_OnMyWay
            ]
            
            var suggestions: [String : String] = [:]
            for (key, defaultValue) in defaultSuggestions {
                suggestions[key] = presets.customPresets[key] ?? defaultValue
            }
            
            let fileManager = FileManager.default
            let presetsFileUrl = URL(fileURLWithPath: tempPath + "/presets.dat")
            
            if fileManager.fileExists(atPath: presetsFileUrl.path) {
                try? fileManager.removeItem(atPath: presetsFileUrl.path)
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: suggestions)
            try? data.write(to: presetsFileUrl)
            
            let _ = strongSelf.sendFile(url: presetsFileUrl, metadata: [TGBridgeIncomingFileIdentifierKey: "presets"]).start()
        }))
    }
    
    deinit {
        self.contextDisposable.dispose()
        self.presetsDisposable.dispose()
    }
    
    var arguments: WatchManagerArguments {
        return WatchManagerArguments(appInstalled: self.watchAppInstalled, navigateToMessageRequested: self.navigateToMessagePipe.signal(), runningTasks: self.runningTasks)
    }
    
    func requestNavigateToMessage(messageId: MessageId) {
        self.navigateToMessagePipe.putNext(messageId)
    }
    
    private var watchAppInstalled: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = self.server.watchAppInstalledSignal()?.start(next: { value in
                if let value = value as? NSNumber {
                    subscriber.putNext(value.boolValue)
                }
            })
            return ActionDisposable {
                disposable?.dispose()
            }
        } |> deliverOn(self.queue)
    }
    
    private var runningTasks: Signal<WatchRunningTasks?, NoError> {
        return Signal { subscriber in
            let disposable = self.server.runningRequestsSignal()?.start(next: { value in
                if let value = value as? Dictionary<String, Any> {
                    if let running = value["running"] as? Bool, let version = value["version"] as? Int32 {
                        subscriber.putNext(WatchRunningTasks(running: running, version: version))
                    }
                }
            })
            return ActionDisposable {
                disposable?.dispose()
            }
        } |> deliverOn(self.queue)
    }
    
    var watchTemporaryStorePath: String? {
        return self.server.temporaryFilesURL?.path
    }
        
    func sendFile(url: URL, metadata: Dictionary<AnyHashable, Any>, asMessageData: Bool = false) -> Signal<Void, NoError> {
        return Signal { subscriber in
            self.server.sendFile(with: url, metadata: metadata, asMessageData: asMessageData)
            subscriber.putCompletion()
            return EmptyDisposable
        } |> runOn(self.queue)
    }
    func sendFile(data: Data, metadata: Dictionary<AnyHashable, Any>) -> Signal<Void, NoError> {
        return Signal { subscriber in
            self.server.sendFile(with: data, metadata: metadata, errorHandler: {})
            subscriber.putCompletion()
            return EmptyDisposable
            } |> runOn(self.queue)
    }
}

func watchCommunicationManager(context: Promise<ApplicationContext?>) -> Signal<WatchCommunicationManager?, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        queue.async {
            if #available(iOSApplicationExtension 9.0, *) {
                subscriber.putNext(WatchCommunicationManager(queue: queue, context: context))
            } else {
                subscriber.putNext(nil)
            }
            subscriber.putCompletion()
        }
        return EmptyDisposable
    }
}
