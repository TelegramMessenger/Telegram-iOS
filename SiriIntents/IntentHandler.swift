import Foundation
import Intents
import TelegramCore
import Postbox
import SwiftSignalKit

private var accountCache: Account?

private var installedSharedLogger = false

private func setupSharedLogger(_ path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(basePath: path))
    }
}

private let accountAuxiliaryMethods = AccountAuxiliaryMethods(updatePeerChatInputState: { interfaceState, inputState -> PeerChatInterfaceState? in
    return interfaceState
}, fetchResource: { account, resource, ranges, _ in
    return nil
}, fetchResourceMediaReferenceHash: { resource in
    return .single(nil)
}, prepareSecretThumbnailData: { _ in
    return nil
})

private struct ApplicationSettings {
    let logging: LoggingSettings
}

private func applicationSettings(accountManager: AccountManager) -> Signal<ApplicationSettings, NoError> {
    return accountManager.transaction { transaction -> ApplicationSettings in
        let loggingSettings: LoggingSettings
        if let value = transaction.getSharedData(SharedDataKeys.loggingSettings) as? LoggingSettings {
            loggingSettings = value
        } else {
            loggingSettings = LoggingSettings.defaultSettings
        }
        return ApplicationSettings(logging: loggingSettings)
    }
}

class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling {
    private let accountPromise = Promise<Account>()
    
    private let resolveRecipientsDisposable = MetaDisposable()
    private let sendMessageDisposable = MetaDisposable()
    
    override init() {
        super.init()
        
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return
        }
        
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        
        let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
        
        let apiId: Int32 = buildConfig.apiId
        let languagesCategory = "ios"
        
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        TempBox.initializeShared(basePath: rootPath, processType: "siri", launchSpecificId: arc4random64())
        
        let logsPath = rootPath + "/siri-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(logsPath)
        
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        
        let account: Signal<Account, NoError>
        if let accountCache = accountCache {
            account = .single(accountCache)
        } else {
            initializeAccountManagement()
            let accountManager = AccountManager(basePath: rootPath + "/accounts-metadata")
            
            let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
            let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
            
            account = currentAccount(allocateIfNotExists: false, networkArguments: NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, appData: buildConfig.bundleData), supplementary: true, manager: accountManager, rootPath: rootPath, auxiliaryMethods: accountAuxiliaryMethods, encryptionParameters: encryptionParameters)
            |> mapToSignal { account -> Signal<Account, NoError> in
                if let account = account {
                    switch account {
                        case .upgrading:
                            return .complete()
                        case let .authorized(account):
                            return applicationSettings(accountManager: accountManager)
                            |> deliverOnMainQueue
                            |> map { settings -> Account in
                                accountCache = account
                                Logger.shared.logToFile = settings.logging.logToFile
                                Logger.shared.logToConsole = settings.logging.logToConsole
                                
                                Logger.shared.redactSensitiveData = settings.logging.redactSensitiveData
                                return account
                            }
                        case .unauthorized:
                            return .complete()
                    }
                } else {
                    return .complete()
                }
            }
            |> take(1)
        }
        accountPromise.set(account)
    }
    
    deinit {
        self.resolveRecipientsDisposable.dispose()
        self.sendMessageDisposable.dispose()
    }
    
    override func handler(for intent: INIntent) -> Any {
        return self
    }
    
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        guard let initialRecipients = intent.recipients, !initialRecipients.isEmpty else {
            completion([INPersonResolutionResult.needsValue()])
            return
        }
        
        let filteredRecipients = initialRecipients.filter({ recipient in
            if let contactIdentifier = recipient.contactIdentifier, !contactIdentifier.isEmpty {
                return true
            }
            
            if #available(iOSApplicationExtension 10.3, *) {
                if let siriMatches = recipient.siriMatches {
                    for match in siriMatches {
                        if let contactIdentifier = match.contactIdentifier, !contactIdentifier.isEmpty {
                            return true
                        }
                    }
                }
            }
            
            return false
        })
        
        if filteredRecipients.isEmpty {
            completion([INPersonResolutionResult.needsValue()])
            return
        }
        
        if filteredRecipients.count > 1 {
            completion([INPersonResolutionResult.disambiguation(with: filteredRecipients)])
            return
        }
        
        var allRecipientsAlreadyMatched = true
        for recipient in filteredRecipients {
            if !(recipient.customIdentifier ?? "").hasPrefix("tg") {
                allRecipientsAlreadyMatched = false
                break
            }
        }
        
        if allRecipientsAlreadyMatched {
           completion([INPersonResolutionResult.success(with: filteredRecipients[0])])
            return
        }
        
        let stableIds = filteredRecipients.compactMap({ recipient -> String? in
            if let contactIdentifier = recipient.contactIdentifier {
                return contactIdentifier
            }
            if #available(iOSApplicationExtension 10.3, *) {
                if let siriMatches = recipient.siriMatches {
                    for match in siriMatches {
                        if let contactIdentifier = match.contactIdentifier, !contactIdentifier.isEmpty {
                            return contactIdentifier
                        }
                    }
                }
            }
            return nil
        })
        
        let account = self.accountPromise.get()
        
        let signal = matchingDeviceContacts(stableIds: stableIds)
        |> take(1)
        |> mapToSignal { matchedContacts in
            return account
            |> mapToSignal { account in
                return matchingCloudContacts(postbox: account.postbox, contacts: matchedContacts)
            }
        }
        self.resolveRecipientsDisposable.set((signal
        |> deliverOnMainQueue).start(next: { peers in
            completion(peers.map { stableId, user in
                let person = personWithUser(stableId: stableId, user: user)
                return INPersonResolutionResult.success(with: person)
            })
        }))
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.content, !text.isEmpty {
            completion(INStringResolutionResult.success(with: text))
        } else {
            completion(INStringResolutionResult.needsValue())
        }
    }
    
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .ready, userActivity: userActivity)
        completion(response)
    }
    
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        self.sendMessageDisposable.set((self.accountPromise.get()
        |> take(1)
        |> mapError { _ -> StandaloneSendMessageError in
            return .generic
        }
        |> mapToSignal { account -> Signal<Void, StandaloneSendMessageError> in
            guard let recipient = intent.recipients?.first, let customIdentifier = recipient.customIdentifier, customIdentifier.hasPrefix("tg") else {
                return .fail(.generic)
            }
            
            guard let peerIdValue = Int64(String(customIdentifier[customIdentifier.index(customIdentifier.startIndex, offsetBy: 2)...])) else {
                return .fail(.generic)
            }
            
            let peerId = PeerId(peerIdValue)
            if peerId.namespace != Namespaces.Peer.CloudUser {
                return .fail(.generic)
            }
            
            account.shouldBeServiceTaskMaster.set(.single(.now))
            return standaloneSendMessage(account: account, peerId: peerId, text: intent.content ?? "", attributes: [], media: nil, replyToMessageId: nil)
            |> mapToSignal { _ -> Signal<Void, StandaloneSendMessageError> in
                return .complete()
            }
            |> afterDisposed {
                account.shouldBeServiceTaskMaster.set(.single(.never))
            }
        }
        |> deliverOnMainQueue).start(error: { _ in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
            let response = INSendMessageIntentResponse(code: .failure, userActivity: userActivity)
            completion(response)
        }, completed: {
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
            let response = INSendMessageIntentResponse(code: .success, userActivity: userActivity)
            completion(response)
        }))
    }
    
    func handle(intent: INStartAudioCallIntent, completion: @escaping (INStartAudioCallIntentResponse) -> Void) {
        self.sendMessageDisposable.set((self.accountPromise.get()
            |> take(1)
            |> mapError { _ -> StandaloneSendMessageError in
                return .generic
            }
            |> mapToSignal { account -> Signal<PeerId, StandaloneSendMessageError> in
                guard let contact = intent.contacts?.first, let customIdentifier = contact.customIdentifier, customIdentifier.hasPrefix("tg") else {
                    return .fail(.generic)
                }
                
                guard let peerIdValue = Int64(String(customIdentifier[customIdentifier.index(customIdentifier.startIndex, offsetBy: 2)...])) else {
                    return .fail(.generic)
                }
                
                let peerId = PeerId(peerIdValue)
                if peerId.namespace != Namespaces.Peer.CloudUser {
                    return .fail(.generic)
                }
                
                return .single(peerId)
            }
            |> deliverOnMainQueue).start(next: { peerId in
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INStartAudioCallIntent.self))
                //userActivity.userInfo = @{ @"handle": [NSString stringWithFormat:@"TGCA%d", next.firstObject.userId] };
                let response = INStartAudioCallIntentResponse(code: .continueInApp, userActivity: userActivity)
                completion(response)
            }, error: { _ in
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INStartAudioCallIntent.self))
                let response = INStartAudioCallIntentResponse(code: .failure, userActivity: userActivity)
                completion(response)
            }))
    }
    
    // Implement handlers for each intent you wish to handle.  As an example for messages, you may wish to also handle searchForMessages and setMessageAttributes.
    
    // MARK: - INSearchForMessagesIntentHandling
    
    func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        // Implement your application logic to find a message that matches the information in the intent.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
        let response = INSearchForMessagesIntentResponse(code: .success, userActivity: userActivity)
        // Initialize with found message's attributes
        response.messages = [INMessage(
            identifier: "identifier",
            content: "I am so excited about SiriKit!",
            dateSent: Date(),
            sender: INPerson(personHandle: INPersonHandle(value: "sarah@example.com", type: .emailAddress), nameComponents: nil, displayName: "Sarah", image: nil,  contactIdentifier: nil, customIdentifier: nil),
            recipients: [INPerson(personHandle: INPersonHandle(value: "+1-415-555-5555", type: .phoneNumber), nameComponents: nil, displayName: "John", image: nil,  contactIdentifier: nil, customIdentifier: nil)]
            )]
        completion(response)
    }
    
    // MARK: - INSetMessageAttributeIntentHandling
    
    func handle(intent: INSetMessageAttributeIntent, completion: @escaping (INSetMessageAttributeIntentResponse) -> Void) {
        // Implement your application logic to set the message attribute here.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))
        let response = INSetMessageAttributeIntentResponse(code: .success, userActivity: userActivity)
        completion(response)
    }
}

