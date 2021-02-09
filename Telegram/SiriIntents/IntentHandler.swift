import Foundation
import Intents
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import BuildConfig
import Contacts
import OpenSSLEncryptionProvider
import AppLockState
import UIKit
import GeneratedSources

private var accountCache: Account?

private var installedSharedLogger = false

private func setupSharedLogger(rootPath: String, path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: path))
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

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
@objc(IntentHandler)
class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling, INStartAudioCallIntentHandling, INSearchCallHistoryIntentHandling, SelectFriendsIntentHandling {
    private let accountPromise = Promise<Account?>()
    private let allAccounts = Promise<[(AccountRecordId, PeerId)]>()
    
    private let resolvePersonsDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    private let searchDisposable = MetaDisposable()
    
    private var rootPath: String?
    private var accountManager: AccountManager?
    private var encryptionParameters: ValueBoxEncryptionParameters?
    private var appGroupUrl: URL?
    
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
        
        self.appGroupUrl = appGroupUrl
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        self.rootPath = rootPath
        
        TempBox.initializeShared(basePath: rootPath, processType: "siri", launchSpecificId: arc4random64())
        
        let logsPath = rootPath + "/siri-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(rootPath: rootPath, path: logsPath)
        
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        
        initializeAccountManagement()
        let accountManager = AccountManager(basePath: rootPath + "/accounts-metadata")
        self.accountManager = accountManager
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        self.encryptionParameters = encryptionParameters
        
        self.allAccounts.set(accountManager.accountRecords()
        |> take(1)
        |> map { view -> [(AccountRecordId, PeerId)] in
            var result: [(AccountRecordId, Int, PeerId)] = []
            for record in view.records {
                let isLoggedOut = record.attributes.contains(where: { attribute in
                    return attribute is LoggedOutAccountAttribute
                })
                if isLoggedOut {
                    continue
                }
                /*let isTestingEnvironment = record.attributes.contains(where: { attribute in
                    if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
                        return true
                    } else {
                        return false
                    }
                })*/
                var backupData: AccountBackupData?
                var sortIndex: Int32 = 0
                for attribute in record.attributes {
                    if let attribute = attribute as? AccountSortOrderAttribute {
                        sortIndex = attribute.order
                    } else if let attribute = attribute as? AccountBackupDataAttribute {
                        backupData = attribute.data
                    }
                }
                if let backupData = backupData {
                    result.append((record.id, Int(sortIndex), PeerId(backupData.peerId)))
                }
            }
            result.sort(by: { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                } else {
                    return lhs.0 < rhs.0
                }
            })
            return result.map { record -> (AccountRecordId, PeerId) in
                return (record.0, record.2)
            }
        })
        
        let account: Signal<Account?, NoError>
        if let accountCache = accountCache {
            account = .single(accountCache)
        } else {
            account = currentAccount(allocateIfNotExists: false, networkArguments: NetworkInitializationArguments(apiId: apiId, apiHash: apiHash, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, voipVersions: [], appData: .single(buildConfig.bundleData(withAppToken: nil, signatureDict: nil)), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider()), supplementary: true, manager: accountManager, rootPath: rootPath, auxiliaryMethods: accountAuxiliaryMethods, encryptionParameters: encryptionParameters)
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
        self.searchDisposable.dispose()
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
        
        @available(iOSApplicationExtension 11.0, iOS 11.0, *)
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
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                completion([.skip])
                return
            }
        }
        
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
            
            if #available(iOSApplicationExtension 10.3, iOS 10.3, *) {
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
            if #available(iOSApplicationExtension 10.3, iOS 10.3, *) {
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
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                completion([INSendMessageRecipientResolutionResult.notRequired()])
                return
            }
        }
        
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
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                completion(INStringResolutionResult.notRequired())
                return
            }
        }
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
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
                let response = INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
                completion(response)
                return
            }
        }
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
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
                let response = INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
                completion(response)
                return
            }
        }
        
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
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
                let response = INSearchForMessagesIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
                completion(response)
                return
            }
        }
        
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
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))
                let response = INSetMessageAttributeIntentResponse(code: .failure, userActivity: userActivity)
                completion(response)
                return
            }
        }
        
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
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                completion([INPersonResolutionResult.notRequired()])
                return
            }
        }
        
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            completion([INPersonResolutionResult.notRequired()])
            return
        }
        self.resolve(persons: intent.contacts, with: { result in
            completion(result.map { $0.personResolutionResult })
        })
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func resolveDestinationType(for intent: INStartAudioCallIntent, with completion: @escaping (INCallDestinationTypeResolutionResult) -> Void) {
        completion(.success(with: .normal))
    }
    
    public func handle(intent: INStartAudioCallIntent, completion: @escaping (INStartAudioCallIntentResponse) -> Void) {
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INStartAudioCallIntent.self))
                let response = INStartAudioCallIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
                completion(response)
                return
            }
        }
        
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
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func resolveCallTypes(for intent: INSearchCallHistoryIntent, with completion: @escaping (INCallRecordTypeOptionsResolutionResult) -> Void) {
        completion(.success(with: .missed))
    }
    
    /*public func resolveCallType(for intent: INSearchCallHistoryIntent, with completion: @escaping (INCallRecordTypeResolutionResult) -> Void) {
        completion(.success(with: .missed))
    }*/
    
    public func handle(intent: INSearchCallHistoryIntent, completion: @escaping (INSearchCallHistoryIntentResponse) -> Void) {
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchCallHistoryIntent.self))
                let response = INSearchCallHistoryIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
                completion(response)
                return
            }
        }
        
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
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
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

    @available(iOSApplicationExtension 14.0, iOS 14.0, *)
    func provideFriendsOptionsCollection(for intent: SelectFriendsIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<Friend>?, Error?) -> Void) {
        guard let rootPath = self.rootPath, let _ = self.accountManager, let encryptionParameters = self.encryptionParameters else {
            completion(nil, nil)
            return
        }
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data) {
            if state.isManuallyLocked || state.autolockTimeout != nil {
                let error = NSError(domain: "Locked", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Open Telegram and enter passcode to edit widget."
                ])
                
                completion(nil, error)
                return
            }
        }
        
        self.searchDisposable.set((self.allAccounts.get()
        |> castError(Error.self)
        |> take(1)
        |> mapToSignal { accounts -> Signal<INObjectCollection<Friend>, Error> in
            var accountResults: [Signal<INObjectSection<Friend>, Error>] = []
            
            for (accountId, accountPeerId) in accounts {
                accountResults.append(accountTransaction(rootPath: rootPath, id: accountId, encryptionParameters: encryptionParameters, transaction: { postbox, transaction -> INObjectSection<Friend> in
                    var accountTitle: String = ""
                    if let peer = transaction.getPeer(accountPeerId) as? TelegramUser {
                        if let username = peer.username, !username.isEmpty {
                            accountTitle = "@\(username)"
                        } else {
                            accountTitle = peer.debugDisplayTitle
                        }
                    }
                    
                    var peers: [Peer] = []
                    
                    if let searchTerm = searchTerm {
                        if !searchTerm.isEmpty {
                            for renderedPeer in transaction.searchPeers(query: searchTerm) {
                                if let peer = renderedPeer.peer, !(peer is TelegramSecretChat) {
                                    peers.append(peer)
                                }
                            }
                            
                            if peers.count > 30 {
                                peers = Array(peers.dropLast(peers.count - 30))
                            }
                        }
                    } else {
                        for renderedPeer in transaction.getTopChatListEntries(groupId: .root, count: 50) {
                            if let peer = renderedPeer.peer, !(peer is TelegramSecretChat) {
                                peers.append(peer)
                            }
                        }
                    }
                    
                    var items: [Friend] = []
                    for peer in peers {
                        let profileImage = smallestImageRepresentation(peer.profileImageRepresentations).flatMap { representation in
                            return postbox.mediaBox.resourcePath(representation.resource)
                        }.flatMap { path -> INImage? in
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                return INImage(imageData: data)
                            } else {
                                return nil
                            }
                        }
                        items.append(Friend(identifier: "\(accountId.int64):\(peer.id.toInt64())", display: peer.debugDisplayTitle, subtitle: nil, image: nil))
                    }
                    
                    return INObjectSection<Friend>(title: accountTitle, items: items)
                })
                |> castError(Error.self))
            }
            
            return combineLatest(accountResults)
            |> map { accountResults -> INObjectCollection<Friend> in
                let filteredSections = accountResults.filter { section in
                    return !section.items.isEmpty
                }
                if filteredSections.count == 1 {
                    return INObjectCollection<Friend>(items: filteredSections[0].items)
                } else {
                    return INObjectCollection<Friend>(sections: filteredSections)
                }
            }
        }).start(next: { result in
            completion(result, nil)
        }, error: { error in
            completion(nil, error)
        }))
        
        /*let _ = (self.accountPromise.get()
        |> take(1)
        |> mapToSignal { account -> Signal<[Friend], NoError> in
            guard let account = account else {
                return .single([])
            }
            
            if let searchTerm = searchTerm {
                if !searchTerm.isEmpty {
                    return account.postbox.searchPeers(query: searchTerm)
                    |> map { renderedPeers -> [Friend] in
                        var peers: [Peer] = []
                        
                        for renderedPeer in renderedPeers {
                            if let peer = renderedPeer.peer, !(peer is TelegramSecretChat) {
                                peers.append(peer)
                            }
                        }
                        
                        peers.sort(by: { lhs, rhs in
                            return lhs.debugDisplayTitle < rhs.debugDisplayTitle
                        })
                        
                        if peers.count > 30 {
                            peers = Array(peers.dropLast(peers.count - 30))
                        }
                        
                        var result: [Friend] = []
                        for peer in peers {
                            let profileImage = smallestImageRepresentation(peer.profileImageRepresentations).flatMap { representation in
                                return account.postbox.mediaBox.resourcePath(representation.resource)
                            }.flatMap { path -> INImage? in
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                    return INImage(imageData: data)
                                } else {
                                    return nil
                                }
                            }
                            result.append(Friend(identifier: "\(peer.id.toInt64())", display: peer.debugDisplayTitle, subtitle: nil, image: nil))
                        }
                        return result
                    }
                } else {
                    return .single([])
                }
            } else {
                return account.postbox.transaction { transaction -> [Friend] in
                    var peers: [Peer] = []
                    
                    for peerId in transaction.getContactPeerIds() {
                        if let peer = transaction.getPeer(peerId) as? TelegramUser {
                            peers.append(peer)
                        }
                    }
                    
                    peers.sort(by: { lhs, rhs in
                        return lhs.debugDisplayTitle < rhs.debugDisplayTitle
                    })
                    
                    if peers.count > 50 {
                        peers = Array(peers.dropLast(peers.count - 50))
                    }
                    
                    var result: [Friend] = []
                    for peer in peers {
                        let profileImage = smallestImageRepresentation(peer.profileImageRepresentations).flatMap { representation in
                            return account.postbox.mediaBox.resourcePath(representation.resource)
                        }.flatMap { path -> INImage? in
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                return INImage(imageData: data)
                            } else {
                                return nil
                            }
                        }
                        result.append(Friend(identifier: "\(peer.id.toInt64())", display: peer.debugDisplayTitle, subtitle: nil, image: nil))
                    }
                    return result
                }
            }
        }
        |> deliverOnMainQueue).start(next: { result in
            let collection = INObjectCollection(items: result)
            completion(collection, nil)
        })*/
    }
}
