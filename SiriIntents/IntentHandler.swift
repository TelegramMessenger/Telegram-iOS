import Foundation
import Intents
import TelegramCore
import Postbox
import SwiftSignalKit
import BuildConfig

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

enum IntentHandlingError {
    case generic
}

class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling, INStartAudioCallIntentHandling, INSearchCallHistoryIntentHandling {
    private let accountPromise = Promise<Account>()
    
    private let resolvePersonsDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    
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
            
            account = currentAccount(allocateIfNotExists: false, networkArguments: NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, appData: .single(buildConfig.bundleData(withAppToken: nil))), supplementary: true, manager: accountManager, rootPath: rootPath, auxiliaryMethods: accountAuxiliaryMethods, encryptionParameters: encryptionParameters)
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
        self.accountPromise.set(account)
    }
    
    deinit {
        self.resolvePersonsDisposable.dispose()
        self.actionDisposable.dispose()
    }
    
    override func handler(for intent: INIntent) -> Any {
        return self
    }
    
    private func resolve(persons: [INPerson]?, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        guard let initialPersons = persons, !initialPersons.isEmpty else {
            completion([INPersonResolutionResult.needsValue()])
            return
        }
        
        let filteredPersons = initialPersons.filter({ person in
            if let contactIdentifier = person.contactIdentifier, !contactIdentifier.isEmpty {
                return true
            }
            
            if #available(iOSApplicationExtension 10.3, *) {
                if let siriMatches = person.siriMatches {
                    for match in siriMatches {
                        if let contactIdentifier = match.contactIdentifier, !contactIdentifier.isEmpty {
                            return true
                        }
                    }
                }
            }
            
            return false
        })
        
        if filteredPersons.isEmpty {
            completion([INPersonResolutionResult.needsValue()])
            return
        }
        
        if filteredPersons.count > 1 {
            completion([INPersonResolutionResult.disambiguation(with: filteredPersons)])
            return
        }
        
        var allPersonsAlreadyMatched = true
        for person in filteredPersons {
            if !(person.customIdentifier ?? "").hasPrefix("tg") {
                allPersonsAlreadyMatched = false
                break
            }
        }
        
        if allPersonsAlreadyMatched {
            completion([INPersonResolutionResult.success(with: filteredPersons[0])])
            return
        }
        
        let stableIds = filteredPersons.compactMap({ person -> String? in
            if let contactIdentifier = person.contactIdentifier {
                return contactIdentifier
            }
            if #available(iOSApplicationExtension 10.3, *) {
                if let siriMatches = person.siriMatches {
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
        self.resolvePersonsDisposable.set((signal
        |> deliverOnMainQueue).start(next: { peers in
            if peers.isEmpty {
                completion([INPersonResolutionResult.needsValue()])
            } else {
                completion(peers.map { stableId, user in
                    let person = personWithUser(stableId: stableId, user: user)
                    return INPersonResolutionResult.success(with: person)
                })
            }
        }))
    }
    
    // MARK: - INSendMessageIntentHandling
    
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
       self.resolve(persons: intent.recipients, with: completion)
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
        self.actionDisposable.set((self.accountPromise.get()
        |> take(1)
        |> mapError { _ -> IntentHandlingError in
            return .generic
        }
        |> mapToSignal { account -> Signal<Void, IntentHandlingError> in
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
            |> mapError { _ -> IntentHandlingError in
                return .generic
            }
            |> mapToSignal { _ -> Signal<Void, IntentHandlingError> in
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
    
    // MARK: - INSearchForMessagesIntentHandling
    
    func resolveAttributes(for intent: INSearchForMessagesIntent, with completion: @escaping (INMessageAttributeOptionsResolutionResult) -> Void) {
        completion(.success(with: .unread))
    }
    
    func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> take(1)
        |> introduceError(IntentHandlingError.self)
        |> mapToSignal { account -> Signal<[INMessage], IntentHandlingError> in
            account.shouldBeServiceTaskMaster.set(.single(.now))
            return unreadMessages(account: account)
            |> introduceError(IntentHandlingError.self)
            |> afterDisposed {
                account.shouldBeServiceTaskMaster.set(.single(.never))
            }
        }
        |> deliverOnMainQueue).start(next: { messages in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
            let response = INSearchForMessagesIntentResponse(code: .success, userActivity: userActivity)
            response.messages = messages
            completion(response)
        }, error: { _ in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
            let response = INSearchForMessagesIntentResponse(code: .failure, userActivity: userActivity)
            completion(response)
        }))
    }
    
    // MARK: - INSetMessageAttributeIntentHandling
    
    func resolveAttribute(for intent: INSetMessageAttributeIntent, with completion: @escaping (INMessageAttributeResolutionResult) -> Void) {
        let supportedAttributes: [INMessageAttribute] = [.read, .unread]
        var attribute = intent.attribute
        if attribute == .flagged {
            attribute = .unread
        }
        if supportedAttributes.contains(attribute) {
            completion(.success(with: attribute))
        } else {
            completion(.confirmationRequired(with: intent.attribute))
        }
    }
    
    func handle(intent: INSetMessageAttributeIntent, completion: @escaping (INSetMessageAttributeIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> take(1)
        |> mapError { _ -> IntentHandlingError in
            return .generic
        }
        |> mapToSignal { account -> Signal<Void, IntentHandlingError> in
            var signals: [Signal<Void, IntentHandlingError>] = []
            
            var maxMessageIdsToApply: [PeerId: MessageId] = [:]
            if let identifiers = intent.identifiers {
                for identifier in identifiers {
                    let components = identifier.components(separatedBy: "_")
                    if let first = components.first, let peerId = Int64(first), let namespace = Int32(components[1]), let id = Int32(components[2]) {
                        let peerId = PeerId(peerId)
                        let messageId = MessageId(peerId: peerId, namespace: namespace, id: id)
                        if let currentMessageId = maxMessageIdsToApply[peerId] {
                            if currentMessageId < messageId {
                                maxMessageIdsToApply[peerId] = messageId
                            }
                        } else {
                            maxMessageIdsToApply[peerId] = messageId
                        }
                    }
                }
            }
            
            for (_, messageId) in maxMessageIdsToApply {
                signals.append(applyMaxReadIndexInteractively(postbox: account.postbox, stateManager: account.stateManager, index: MessageIndex(id: messageId, timestamp: 0))
                |> introduceError(IntentHandlingError.self))
            }
            
            if signals.isEmpty {
                return .complete()
            } else {
                account.shouldBeServiceTaskMaster.set(.single(.now))
                return combineLatest(signals)
                |> mapToSignal { _ -> Signal<Void, IntentHandlingError> in
                    return .complete()
                }
                |> afterDisposed {
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                }
            }
        }
        |> deliverOnMainQueue).start(error: { _ in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))
            let response = INSetMessageAttributeIntentResponse(code: .failure, userActivity: userActivity)
            completion(response)
        }, completed: {
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))
            let response = INSetMessageAttributeIntentResponse(code: .success, userActivity: userActivity)
            completion(response)
        }))
    }
    
    // MARK: - INStartAudioCallIntentHandling
    
    func resolveContacts(for intent: INStartAudioCallIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        self.resolve(persons: intent.contacts, with: completion)
    }
    
    func handle(intent: INStartAudioCallIntent, completion: @escaping (INStartAudioCallIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> take(1)
        |> mapError { _ -> IntentHandlingError in
            return .generic
        }
        |> mapToSignal { account -> Signal<PeerId, IntentHandlingError> in
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
            userActivity.userInfo = ["handle": "TGCA\(peerId.toInt64())"]
            let response = INStartAudioCallIntentResponse(code: .continueInApp, userActivity: userActivity)
            completion(response)
        }, error: { _ in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INStartAudioCallIntent.self))
            let response = INStartAudioCallIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
            completion(response)
        }))
    }
    
    // MARK: - INSearchCallHistoryIntentHandling
    
    @available(iOSApplicationExtension 11.0, *)
    func resolveCallTypes(for intent: INSearchCallHistoryIntent, with completion: @escaping (INCallRecordTypeOptionsResolutionResult) -> Void) {
        completion(.success(with: .missed))
    }
    
    func resolveCallType(for intent: INSearchCallHistoryIntent, with completion: @escaping (INCallRecordTypeResolutionResult) -> Void) {
        completion(.success(with: .missed))
    }
    
    func handle(intent: INSearchCallHistoryIntent, completion: @escaping (INSearchCallHistoryIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> take(1)
        |> introduceError(IntentHandlingError.self)
        |> mapToSignal { account -> Signal<[CallRecord], IntentHandlingError> in
            account.shouldBeServiceTaskMaster.set(.single(.now))
            return missedCalls(account: account)
            |> introduceError(IntentHandlingError.self)
            |> afterDisposed {
                account.shouldBeServiceTaskMaster.set(.single(.never))
            }
        }
        |> deliverOnMainQueue).start(next: { calls in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchCallHistoryIntent.self))
            let response: INSearchCallHistoryIntentResponse
            if #available(iOSApplicationExtension 11.0, *) {
                response = INSearchCallHistoryIntentResponse(code: .success, userActivity: userActivity)
                response.callRecords = calls.map { $0.intentCall }
            } else {
                response = INSearchCallHistoryIntentResponse(code: .continueInApp, userActivity: userActivity)
            }
            completion(response)
        }, error: { _ in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchCallHistoryIntent.self))
            let response = INSearchCallHistoryIntentResponse(code: .failure, userActivity: userActivity)
            completion(response)
        }))
    }
}
