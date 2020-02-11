import Foundation
import Intents
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import BuildConfig
import Contacts
import OpenSSLEncryptionProvider

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

@available(iOSApplicationExtension 10.0, *)
@objc(IntentHandler)
public class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling, INStartAudioCallIntentHandling, INSearchCallHistoryIntentHandling {
    private let accountPromise = Promise<Account?>()
    
    private let resolvePersonsDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    
    override init() {
        super.init()
        
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier, let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return
        }
        
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        
        let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
        
        let apiId: Int32 = buildConfig.apiId
        let apiHash: String = buildConfig.apiHash
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
        
        let account: Signal<Account?, NoError>
        if let accountCache = accountCache {
            account = .single(accountCache)
        } else {
            initializeAccountManagement()
            let accountManager = AccountManager(basePath: rootPath + "/accounts-metadata")
            
            let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
            let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
            
            account = currentAccount(allocateIfNotExists: false, networkArguments: NetworkInitializationArguments(apiId: apiId, apiHash: apiHash, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, appData: .single(buildConfig.bundleData(withAppToken: nil, signatureDict: nil)), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider()), supplementary: true, manager: accountManager, rootPath: rootPath, auxiliaryMethods: accountAuxiliaryMethods, encryptionParameters: encryptionParameters)
            |> mapToSignal { account -> Signal<Account?, NoError> in
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
                    return .single(nil)
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
    
    override public func handler(for intent: INIntent) -> Any {
        return self
    }
    
    enum ResolveResult {
        case success(INPerson)
        case disambiguation([INPerson])
        case needsValue
        case noResult
        case skip
        
        @available(iOSApplicationExtension 11.0, *)
        var sendMessageRecipientResulutionResult: INSendMessageRecipientResolutionResult {
            switch self {
                case let .success(person):
                    return .success(with: person)
                case let .disambiguation(persons):
                    return .disambiguation(with: persons)
                case .needsValue:
                    return .needsValue()
                case .noResult:
                    return .unsupported()
                case .skip:
                    return .notRequired()
            }
        }
        
        var personResolutionResult: INPersonResolutionResult {
            switch self {
                case let .success(person):
                    return .success(with: person)
                case let .disambiguation(persons):
                    return .disambiguation(with: persons)
                case .needsValue:
                    return .needsValue()
                case .noResult:
                    return .unsupported()
                case .skip:
                    return .notRequired()
            }
        }
    }
    
    private func resolve(persons: [INPerson]?, with completion: @escaping ([ResolveResult]) -> Void) {
        let account = self.accountPromise.get()
        guard let initialPersons = persons, !initialPersons.isEmpty else {
            completion([.needsValue])
            return
        }
        
        var filteredPersons: [INPerson] = []
        for person in initialPersons {
            if let contactIdentifier = person.contactIdentifier, !contactIdentifier.isEmpty {
                filteredPersons.append(person)
            }
            
            if #available(iOSApplicationExtension 10.3, *) {
                if let siriMatches = person.siriMatches {
                    for match in siriMatches {
                        if let contactIdentifier = match.contactIdentifier, !contactIdentifier.isEmpty {
                            filteredPersons.append(match)
                        }
                    }
                }
            }
        }
        
        if filteredPersons.isEmpty {
            completion([.noResult])
            return
        }
        
        var allPersonsAlreadyMatched = true
        for person in filteredPersons {
            if !(person.customIdentifier ?? "").hasPrefix("tg") {
                allPersonsAlreadyMatched = false
                break
            }
        }
        
        if allPersonsAlreadyMatched && filteredPersons.count == 1 {
            completion([.success(filteredPersons[0])])
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
        
        let signal = matchingDeviceContacts(stableIds: stableIds)
        |> take(1)
        |> mapToSignal { matchedContacts in
            return account
            |> castError(IntentContactsError.self)
            |> mapToSignal { account -> Signal<[(String, TelegramUser)], IntentContactsError> in
                if let account = account {
                    return matchingCloudContacts(postbox: account.postbox, contacts: matchedContacts)
                    |> castError(IntentContactsError.self)
                } else {
                    return .fail(.generic)
                }
            }
        }
        self.resolvePersonsDisposable.set((signal
        |> deliverOnMainQueue).start(next: { peers in
            if peers.isEmpty {
                completion([.noResult])
            } else if peers.count == 1 {
                completion(peers.map { .success(personWithUser(stableId: $0, user: $1)) })
            } else {
                completion([.disambiguation(peers.map { (personWithUser(stableId: $0, user: $1)) })])
            }
        }, error: { error in
            completion([.skip])
        }))
    }
    
    // MARK: - INSendMessageIntentHandling
    
     public func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            completion([INPersonResolutionResult.notRequired()])
            return
        }
        self.resolve(persons: intent.recipients, with: { result in
            completion(result.map { $0.personResolutionResult })
        })
    }
    
    @available(iOSApplicationExtension 11.0, *)
    public func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        if let peerId = intent.conversationIdentifier.flatMap(Int64.init) {
            let account = self.accountPromise.get()
            
            let signal = account
            |> castError(IntentHandlingError.self)
            |> mapToSignal { account -> Signal<INPerson?, IntentHandlingError> in
                if let account = account {
                    return matchingCloudContact(postbox: account.postbox, peerId: PeerId(peerId))
                    |> castError(IntentHandlingError.self)
                    |> map { user -> INPerson? in
                        if let user = user {
                            return personWithUser(stableId: "tg\(peerId)", user: user)
                        } else {
                            return nil
                        }
                    }
                } else {
                    return .fail(.generic)
                }
            }
            
            self.resolvePersonsDisposable.set((signal
            |> deliverOnMainQueue).start(next: { person in
                if let person = person {
                    completion([INSendMessageRecipientResolutionResult.success(with: person)])
                } else {
                    completion([INSendMessageRecipientResolutionResult.needsValue()])
                }
            }, error: { error in
                completion([INSendMessageRecipientResolutionResult.unsupported(forReason: .noAccount)])
            }))
        } else {
            guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
                completion([INSendMessageRecipientResolutionResult.notRequired()])
                return
            }
            self.resolve(persons: intent.recipients, with: { result in
                completion(result.map { $0.sendMessageRecipientResulutionResult })
            })
        }
    }
    
    public func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            completion(INStringResolutionResult.notRequired())
            return
        }
        if let text = intent.content, !text.isEmpty {
            completion(INStringResolutionResult.success(with: text))
        } else {
            completion(INStringResolutionResult.needsValue())
        }
    }
    
    public func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            let response = INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
            completion(response)
            return
        }
        let response = INSendMessageIntentResponse(code: .ready, userActivity: userActivity)
        completion(response)
    }
    
    public func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> castError(IntentHandlingError.self)
        |> take(1)
        |> mapToSignal { account -> Signal<Void, IntentHandlingError> in
            guard let account = account else {
                return .fail(.generic)
            }
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
            let response = INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
            completion(response)
        }, completed: {
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
            let response = INSendMessageIntentResponse(code: .success, userActivity: userActivity)
            completion(response)
        }))
    }
    
    // MARK: - INSearchForMessagesIntentHandling
    
    public func resolveAttributes(for intent: INSearchForMessagesIntent, with completion: @escaping (INMessageAttributeOptionsResolutionResult) -> Void) {
        completion(.success(with: .unread))
    }
    
    public func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> take(1)
        |> castError(IntentHandlingError.self)
        |> mapToSignal { account -> Signal<[INMessage], IntentHandlingError> in
            guard let account = account else {
                return .fail(.generic)
            }
            
            account.shouldBeServiceTaskMaster.set(.single(.now))
            account.resetStateManagement()
            
            let completion: Signal<Void, NoError> = account.stateManager.pollStateUpdateCompletion()
            |> map { _ in
                return Void()
            }
            
            return (completion |> timeout(4.0, queue: Queue.mainQueue(), alternate: .single(Void())))
            |> castError(IntentHandlingError.self)
            |> take(1)
            |> mapToSignal { _ -> Signal<[INMessage], IntentHandlingError> in
                let messages: Signal<[INMessage], NoError>
                if let identifiers = intent.identifiers, !identifiers.isEmpty {
                    messages = getMessages(account: account, ids: identifiers.compactMap(MessageId.init(string:)))
                } else {
                    messages = unreadMessages(account: account)
                }
                return messages
                |> castError(IntentHandlingError.self)
                |> afterDisposed {
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                }
            }
        }
        |> deliverOnMainQueue).start(next: { messages in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
            let response = INSearchForMessagesIntentResponse(code: .success, userActivity: userActivity)
            response.messages = messages
            completion(response)
        }, error: { _ in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
            let response = INSearchForMessagesIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
            completion(response)
        }))
    }
    
    // MARK: - INSetMessageAttributeIntentHandling
    
    public func resolveAttribute(for intent: INSetMessageAttributeIntent, with completion: @escaping (INMessageAttributeResolutionResult) -> Void) {
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
    
    public func handle(intent: INSetMessageAttributeIntent, completion: @escaping (INSetMessageAttributeIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> castError(IntentHandlingError.self)
        |> take(1)
        |> mapToSignal { account -> Signal<Void, IntentHandlingError> in
            guard let account = account else {
                return .fail(.generic)
            }
            
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
                |> castError(IntentHandlingError.self))
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
    
    public func resolveContacts(for intent: INStartAudioCallIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            completion([INPersonResolutionResult.notRequired()])
            return
        }
        self.resolve(persons: intent.contacts, with: { result in
            completion(result.map { $0.personResolutionResult })
        })
    }
    
    @available(iOSApplicationExtension 11.0, *)
    public func resolveDestinationType(for intent: INStartAudioCallIntent, with completion: @escaping (INCallDestinationTypeResolutionResult) -> Void) {
        completion(.success(with: .normal))
    }
    
    public func handle(intent: INStartAudioCallIntent, completion: @escaping (INStartAudioCallIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> castError(IntentHandlingError.self)
        |> take(1)
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
    public func resolveCallTypes(for intent: INSearchCallHistoryIntent, with completion: @escaping (INCallRecordTypeOptionsResolutionResult) -> Void) {
        completion(.success(with: .missed))
    }
    
    /*public func resolveCallType(for intent: INSearchCallHistoryIntent, with completion: @escaping (INCallRecordTypeResolutionResult) -> Void) {
        completion(.success(with: .missed))
    }*/
    
    public func handle(intent: INSearchCallHistoryIntent, completion: @escaping (INSearchCallHistoryIntentResponse) -> Void) {
        self.actionDisposable.set((self.accountPromise.get()
        |> take(1)
        |> castError(IntentHandlingError.self)
        |> mapToSignal { account -> Signal<[CallRecord], IntentHandlingError> in
            guard let account = account else {
                return .fail(.generic)
            }
            
            account.shouldBeServiceTaskMaster.set(.single(.now))
            return missedCalls(account: account)
            |> castError(IntentHandlingError.self)
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
            let response = INSearchCallHistoryIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
            completion(response)
        }))
    }
}
