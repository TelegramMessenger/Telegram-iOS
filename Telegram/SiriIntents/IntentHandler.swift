import Foundation
import PasscodeCore
import Intents
import TelegramCore
import Postbox
import SwiftSignalKit
import BuildConfig
import Contacts
import OpenSSLEncryptionProvider
import AppLockState
import UIKit
import GeneratedSources
import WidgetItems

/// The account the extension opened for an earlier request. The process outlives a single
/// request, and opening an account costs time Siri does not give us, so it is kept - but only
/// while it is still the account the app has current (see `usableAccountRecordId`). Read and
/// written on the main queue only.
private var accountCache: Account?

/// The account record the extension may answer from: the app's current record, unless that
/// record has been logged out. Logging out marks the record before the app moves its
/// selection, so a request in that window, or a cached account opened for that record, must
/// not read or send with the revoked session; `currentAccount` yields nothing for such a
/// record, and the cache must agree.
func usableAccountRecordId(_ record: AccountRecord<TelegramAccountManagerTypes.Attribute>?) -> AccountRecordId? {
    guard let record else {
        return nil
    }
    for attribute in record.attributes {
        if case .loggedOut = attribute {
            return nil
        }
    }
    return record.id
}

/// The first value of `signal`, or nil if it completes without one. The account signal does
/// exactly that for a logged-out or upgrading record, and every handler waits for its first
/// value; without this that wait never ended and the intent's completion never ran.
func firstValueOrNil<T>(_ signal: Signal<T?, NoError>) -> Signal<T?, NoError> {
    return (signal |> take(1) |> map { Optional<T?>.some($0) })
    |> then(.single(nil))
    |> take(1)
    |> map { $0 ?? nil }
}

private var installedSharedLogger = false

private func setupSharedLogger(rootPath: String, path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: path))
    }
}

private let accountAuxiliaryMethods = AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
    return nil
}, fetchResourceMediaReferenceHash: { resource in
    return .single(nil)
}, prepareSecretThumbnailData: { _ in
    return nil
}, backgroundUpload: { _, _, _ in
    return .single(nil)
})

private struct ApplicationSettings {
    let logging: LoggingSettings
}

private func applicationSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<ApplicationSettings, NoError> {
    return accountManager.transaction { transaction -> ApplicationSettings in
        let loggingSettings: LoggingSettings
        if let value = transaction.getSharedData(SharedDataKeys.loggingSettings)?.get(LoggingSettings.self) {
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

/// Runs a signal that produces no values and reports `value` once it completes.
/// A `Signal<Never, _>` cannot be chained into a differently typed one: `then` needs a
/// matching value type, and `map`/`mapToSignal` bodies would be unreachable, which this
/// project builds as an error.
private func completing<T, E>(_ signal: Signal<Never, E>, with value: T) -> Signal<T, E> {
    return Signal { subscriber in
        return signal.start(error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putNext(value)
            subscriber.putCompletion()
        })
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
@objc(IntentHandler)
class IntentHandler: INExtension {
    override public func handler(for intent: INIntent) -> Any {
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            if intent is SelectAvatarFriendsIntent {
                return AvatarsIntentHandler()
            } else if intent is SelectFriendsIntent {
                return FriendsIntentHandler()
            } else {
                return DefaultIntentHandler()
            }
        } else {
            return DefaultIntentHandler()
        }
    }
}

@objc(IntentHandler)
class DefaultIntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling, INStartCallIntentHandling {
    private let accountPromise = Promise<Account?>()
    private let allAccounts = Promise<[(AccountRecordId, PeerId, Bool)]>()
    
    private let resolvePersonsDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    private let searchDisposable = MetaDisposable()
    
    private var rootPath: String?
    private var accountManager: AccountManager<TelegramAccountManagerTypes>?
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
        try! PasscodeEnvironment.shared.configure(PasscodeConfiguration(appGroupIdentifier: appGroupName, processRole: .appExtension))
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return
        }
        
        self.appGroupUrl = appGroupUrl
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        self.rootPath = rootPath
        
        TempBox.initializeShared(basePath: rootPath, processType: "siri", launchSpecificId: Int64.random(in: Int64.min ... Int64.max))
        
        let logsPath = rootPath + "/logs/siri-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(rootPath: logsPath, path: logsPath)
        
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        
        initializeAccountManagement()
        let accountManager: AccountManager<TelegramAccountManagerTypes> = setupAccountManager(basePath: rootPath + "/accounts-metadata", isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: false)
        self.accountManager = accountManager
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        self.encryptionParameters = encryptionParameters
        
        // One read of the account records serves both the account list and the choice of the
        // account to answer from.
        let accountRecords = accountManager.accountRecords()
        |> take(1)
        
        self.allAccounts.set(accountRecords
        |> map { view -> [(AccountRecordId, PeerId, Bool)] in
            var result: [(AccountRecordId, Int, PeerId, Bool)] = []
            for record in view.records {
                let isLoggedOut = record.attributes.contains(where: { attribute in
                    if case .loggedOut = attribute {
                        return true
                    } else {
                        return false
                    }
                })
                if isLoggedOut {
                    continue
                }
                var backupData: AccountBackupData?
                var sortIndex: Int32 = 0
                for attribute in record.attributes {
                    if case let .sortOrder(sortOrder) = attribute {
                        sortIndex = sortOrder.order
                    } else if case let .backupData(backupDataValue) = attribute {
                        backupData = backupDataValue.data
                    }
                }
                if let backupData = backupData {
                    result.append((record.id, Int(sortIndex), PeerId(backupData.peerId), view.currentRecord?.id == record.id))
                }
            }
            result.sort(by: { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                } else {
                    return lhs.0 < rhs.0
                }
            })
            return result.map { record -> (AccountRecordId, PeerId, Bool) in
                return (record.0, record.2, record.3)
            }
        })
        
        let account: Signal<Account?, NoError> = accountRecords
        |> map { view in
            return usableAccountRecordId(view.currentRecord)
        }
        |> deliverOnMainQueue
        |> mapToSignal { currentRecordId -> Signal<Account?, NoError> in
            if let accountCache, accountCache.id == currentRecordId {
                return .single(accountCache)
            }
            if let previous = accountCache {
                // The app switched accounts (or logged this one out): the account opened for
                // the previous record must not stay connected from the extension while the
                // new one is opened beside it.
                previous.shouldBeServiceTaskMaster.set(.single(.never))
                accountCache = nil
            }
            guard currentRecordId != nil else {
                return .single(nil)
            }
            return currentAccount(allocateIfNotExists: false, networkArguments: NetworkInitializationArguments(apiId: apiId, apiHash: apiHash, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, voipVersions: [], appData: .single(buildConfig.bundleData(withAppToken: nil, tokenType: nil, tokenEnvironment: nil, signatureDict: nil)), externalRequestVerificationStream: .never(), externalRecaptchaRequestVerification: { _, _ in return .never() }, autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider(), deviceModelName: nil, useBetaFeatures: !buildConfig.isAppStoreBuild, isICloudEnabled: false), supplementary: true, manager: accountManager, rootPath: rootPath, auxiliaryMethods: accountAuxiliaryMethods, encryptionParameters: encryptionParameters)
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
        self.accountPromise.set(firstValueOrNil(account))
    }
    
    deinit {
        self.resolvePersonsDisposable.dispose()
        self.actionDisposable.dispose()
        self.searchDisposable.dispose()
    }
    
    enum ResolveResult {
        case success(INPerson)
        case disambiguation([INPerson])
        case needsValue
        case noResult
        /// A peer that exists but may not be messaged (see `peerAcceptsSiriMessages`).
        case refused
        /// No account is logged in.
        case noAccount
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
                case .refused:
                    return .unsupported(forReason: .messagingServiceNotEnabledForRecipient)
                case .noAccount:
                    return .unsupported(forReason: .noAccount)
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
            case .noResult, .refused, .noAccount:
                return .unsupported()
            case .skip:
                return .notRequired()
            }
        }
        
        var contactResolutionResult: INStartCallContactResolutionResult {
            switch self {
            case let .success(person):
                return .success(with: person)
            case let .disambiguation(persons):
                return .disambiguation(with: persons)
            case .needsValue:
                return .needsValue()
            case .noResult, .refused, .noAccount:
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
            // A person this extension handed Siri earlier - typically the sender of a message
            // it just read. That sender may be a channel, which is not a recipient: decide by
            // the peer, never by the identifier alone.
            guard let peerId = siriSendMessageTarget(conversationIdentifier: nil, recipientCustomIdentifier: filteredPersons[0].customIdentifier) else {
                completion([.noResult])
                return
            }
            self.resolvePersonsDisposable.set((account
            |> take(1)
            |> mapToSignal { account -> Signal<SiriRecipientDecision?, NoError> in
                guard let account else {
                    return .single(nil)
                }
                return account.postbox.transaction { transaction -> SiriRecipientDecision? in
                    return siriRecipientDecision(transaction: transaction, accountPeerId: account.peerId, peerId: peerId)
                }
            }
            |> deliverOnMainQueue).start(next: { decision in
                switch decision {
                case .none:
                    completion([.noAccount])
                case .unknown:
                    completion([.noResult])
                case .refused:
                    completion([.refused])
                case let .person(person):
                    completion([.success(person)])
                }
            }))
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
            |> mapToSignal { account -> Signal<INSendMessageRecipientResolutionResult, IntentHandlingError> in
                if let account = account {
                    // The conversation is the chat whose message Siri read: a user, or a group
                    // when the message was a group message. A group is "recipient" enough for
                    // Siri; the send handler routes by the conversation anyway.
                    return account.postbox.transaction { transaction -> SiriRecipientDecision in
                        return siriRecipientDecision(transaction: transaction, accountPeerId: account.peerId, peerId: PeerId(peerId))
                    }
                    |> castError(IntentHandlingError.self)
                    |> map { decision -> INSendMessageRecipientResolutionResult in
                        switch decision {
                        case .unknown:
                            return .needsValue()
                        case .refused:
                            return .unsupported(forReason: .messagingServiceNotEnabledForRecipient)
                        case let .person(person):
                            return .success(with: person)
                        }
                    }
                } else {
                    return .fail(.generic)
                }
            }
            
            self.resolvePersonsDisposable.set((signal
            |> deliverOnMainQueue).start(next: { result in
                completion([result])
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
            guard let peerId = siriSendMessageTarget(conversationIdentifier: intent.conversationIdentifier, recipientCustomIdentifier: intent.recipients?.first?.customIdentifier) else {
                return .fail(.generic)
            }
            
            account.shouldBeServiceTaskMaster.set(.single(.now))
            return account.postbox.transaction { transaction -> Bool in
                return siriRecipientAccepted(transaction: transaction, accountPeerId: account.peerId, peerId: peerId)
            }
            |> castError(IntentHandlingError.self)
            |> mapToSignal { accepted -> Signal<Void, IntentHandlingError> in
                guard accepted else {
                    return .fail(.generic)
                }
                // A refused send fails here (StandaloneSendMessage no longer swallows the
                // server's answer), and Siri reports the failure instead of "sent".
                return standaloneSendMessage(account: account, peerId: peerId, text: intent.content ?? "", attributes: [], media: nil, replyToMessageId: nil)
                |> mapError { _ -> IntentHandlingError in
                    return .generic
                }
                |> mapToSignal { _ -> Signal<Void, IntentHandlingError> in
                    return .complete()
                }
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
                let scope = messageSearchScope(for: intent)
                Logger.shared.log("SiriIntents", "INSearchForMessagesIntent notificationIdentifiers: \(intent.notificationIdentifiers ?? []), operator: \(intent.notificationIdentifiersOperator.rawValue), identifiers: \(intent.identifiers ?? []), scope: \(scope)")

                let messages: Signal<[INMessage], NoError>
                switch scope {
                case let .notifications(requestIdentifiers):
                    // An announce: only what these notifications stand for. A notification
                    // this build never recorded yields nothing rather than the unread backlog.
                    // The link is looked up in the current account only, which is also the
                    // account a Siri reply would be sent from; a notification of another
                    // logged-in account therefore resolves to nothing here.
                    messages = account.postbox.transaction { transaction -> [MessageId] in
                        return requestIdentifiers.compactMap { requestIdentifier in
                            return _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: requestIdentifier)
                        }
                    }
                    |> mapToSignal { ids -> Signal<[INMessage], NoError> in
                        Logger.shared.log("SiriIntents", "INSearchForMessagesIntent resolved \(ids.count) of \(requestIdentifiers.count) notification identifiers: \(ids)")
                        return getMessages(account: account, ids: ids)
                    }
                case let .messages(ids):
                    messages = getMessages(account: account, ids: ids)
                case let .unread(excludingNotifications):
                    if excludingNotifications.isEmpty {
                        messages = unreadMessages(account: account)
                    } else {
                        messages = account.postbox.transaction { transaction -> Set<String> in
                            return Set(excludingNotifications.compactMap { requestIdentifier in
                                return _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: requestIdentifier)
                            }.map(intentMessageIdentifier))
                        }
                        |> mapToSignal { excludedIdentifiers -> Signal<[INMessage], NoError> in
                            return unreadMessages(account: account)
                            |> map { messages -> [INMessage] in
                                return messages.filter { !excludedIdentifiers.contains($0.identifier) }
                            }
                        }
                    }
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
        |> mapToSignal { account -> Signal<INSetMessageAttributeIntentResponseCode, IntentHandlingError> in
            guard let account = account else {
                return .fail(.generic)
            }
            
            // Message identifiers are "<peerId>_<namespace>_<id>" (IntentMessages.swift).
            // Anything else - an identifier donated by an older build, a truncated payload -
            // has to be skipped rather than indexed into.
            var maxMessageIdsToApply: [PeerId: MessageId] = [:]
            for identifier in intent.identifiers ?? [] {
                let components = identifier.components(separatedBy: "_")
                guard components.count == 3, let peerIdValue = Int64(components[0]), let namespace = Int32(components[1]), let id = Int32(components[2]) else {
                    continue
                }
                let peerId = PeerId(peerIdValue)
                let messageId = MessageId(peerId: peerId, namespace: namespace, id: id)
                if let currentMessageId = maxMessageIdsToApply[peerId], messageId < currentMessageId {
                    continue
                }
                maxMessageIdsToApply[peerId] = messageId
            }
            
            if maxMessageIdsToApply.isEmpty {
                return .single(.failureMessageNotFound)
            }
            
            // resolveAttribute accepts .read and .unread and folds .flagged into .unread;
            // acting on the attribute is what tells "mark as read" from "mark as unread".
            var attribute = intent.attribute
            if attribute == .flagged {
                attribute = .unread
            }
            
            let engine = TelegramEngine(account: account)
            let applied: Signal<Bool, NoError>
            switch attribute {
            case .read:
                applied = combineLatest(maxMessageIdsToApply.values.map { messageId in
                    return engine.messages.applyMaxReadMessageIdInteractively(messageId: messageId)
                })
                |> map { results -> Bool in
                    return results.contains(true)
                }
            case .unread:
                // Marking unread is idempotent and never refused, so it always applies.
                applied = completing(engine.messages.togglePeersUnreadMarkInteractively(peerIds: Array(maxMessageIdsToApply.keys), setToValue: true), with: true)
            default:
                return .single(.failureMessageAttributeNotSet)
            }
            
            account.shouldBeServiceTaskMaster.set(.single(.now))
            return applied
            |> castError(IntentHandlingError.self)
            |> map { applied -> INSetMessageAttributeIntentResponseCode in
                // Nothing was applied - every peer refused, which is what a secret chat does
                // for a read. Saying "success" would tell the user it was marked when it was not.
                return applied ? .success : .failureMessageAttributeNotSet
            }
            |> afterDisposed {
                account.shouldBeServiceTaskMaster.set(.single(.never))
            }
        }
        |> deliverOnMainQueue).start(next: { code in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))
            let response = INSetMessageAttributeIntentResponse(code: code, userActivity: userActivity)
            completion(response)
        }, error: { _ in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))
            let response = INSetMessageAttributeIntentResponse(code: .failure, userActivity: userActivity)
            completion(response)
        }))
    }
    
    // MARK: - INStartAudioCallIntentHandling
    public func resolveContacts(for intent: INStartCallIntent, with completion: @escaping ([INStartCallContactResolutionResult]) -> Void) {
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                completion([INStartCallContactResolutionResult.notRequired()])
                return
            }
        }
        
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            completion([INStartCallContactResolutionResult.notRequired()])
            return
        }
        self.resolve(persons: intent.contacts, with: { result in
            completion(result.map { $0.contactResolutionResult })
        })
    }
    
    public func resolveDestinationType(for intent: INStartCallIntent, with completion: @escaping (INCallDestinationTypeResolutionResult) -> Void) {
        completion(.success(with: .normal))
    }
    
    public func handle(intent: INStartCallIntent, completion: @escaping (INStartCallIntentResponse) -> Void) {
        if let appGroupUrl = self.appGroupUrl {
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
                let userActivity = NSUserActivity(activityType: NSStringFromClass(INStartCallIntent.self))
                let response = INStartCallIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
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
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INStartCallIntent.self))
            userActivity.userInfo = ["handle": "TGCA\(peerId.toInt64())"]
            let response = INStartCallIntentResponse(code: .continueInApp, userActivity: userActivity)
            completion(response)
        }, error: { _ in
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INStartCallIntent.self))
            let response = INStartCallIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity)
            completion(response)
        }))
    }

    @available(iOSApplicationExtension 14.0, iOS 14.0, *)
    func provideFriendsOptionsCollection(for intent: SelectFriendsIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<Friend>?, Error?) -> Void) {
        guard let rootPath = self.rootPath, let _ = self.accountManager, let encryptionParameters = self.encryptionParameters else {
            completion(nil, nil)
            return
        }
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
            let presentationData = WidgetPresentationData.getForExtension()
            
            let error = NSError(domain: presentationData.generalLockedTitle, code: 1, userInfo: [
                NSLocalizedDescriptionKey: presentationData.generalLockedText
            ])
            
            completion(nil, error)
            return
        }
        
        self.searchDisposable.set((self.allAccounts.get()
        |> castError(Error.self)
        |> take(1)
        |> mapToSignal { accounts -> Signal<INObjectCollection<Friend>, Error> in
            var accountResults: [Signal<INObjectSection<Friend>, Error>] = []
            
            for (accountId, accountPeerId, _) in accounts {
                accountResults.append(accountTransaction(rootPath: rootPath, id: accountId, encryptionParameters: encryptionParameters, isReadOnly: true, useCopy: false, transaction: { postbox, transaction -> INObjectSection<Friend> in
                    var accountTitle: String = ""
                    if let peer = transaction.getPeer(accountPeerId) as? TelegramUser {
                        if let username = peer.addressName, !username.isEmpty {
                            accountTitle = "@\(username)"
                        } else {
                            accountTitle = peer.debugDisplayTitle
                        }
                    }
                    
                    var peers: [Peer] = []
                    
                    if let searchTerm = searchTerm {
                        if !searchTerm.isEmpty {
                            for renderedPeer in transaction.searchPeers(query: searchTerm, predicate: nil) {
                                if let peer = renderedPeer.peer, !(peer is TelegramSecretChat), !peer.isDeleted {
                                    peers.append(peer)
                                }
                            }
                            
                            if peers.count > 30 {
                                peers = Array(peers.dropLast(peers.count - 30))
                            }
                        }
                    } else {
                        for renderedPeer in transaction.getTopChatListEntries(groupId: .root, count: 50) {
                            if let peer = renderedPeer.peer, !(peer is TelegramSecretChat), !peer.isDeleted {
                                peers.append(peer)
                            }
                        }
                    }
                    
                    let items = mapPeersToFriends(accountId: accountId, accountPeerId: accountPeerId, mediaBox: postbox.mediaBox, peers: peers)
                    
                    return INObjectSection<Friend>(title: accountTitle, items: items)
                })
                |> `catch` { _ -> Signal<INObjectSection<Friend>, NoError> in
                    return .single(INObjectSection<Friend>(title: nil, items: []))
                }
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
    }
}

private final class WidgetIntentHandler {
    private let allAccounts = Promise<[(AccountRecordId, PeerId, Bool)]>()
    
    private let searchDisposable = MetaDisposable()
    
    private var rootPath: String?
    private var encryptionParameters: ValueBoxEncryptionParameters?
    private var appGroupUrl: URL?
    
    init() {
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier, let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return
        }
        
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return
        }
        
        self.appGroupUrl = appGroupUrl
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        self.rootPath = rootPath
        
        TempBox.initializeShared(basePath: rootPath, processType: "siri", launchSpecificId: Int64.random(in: Int64.min ... Int64.max))
        
        let logsPath = rootPath + "/logs/siri-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(rootPath: rootPath, path: logsPath)
        
        initializeAccountManagement()
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        self.encryptionParameters = encryptionParameters
        
        let view = AccountManager<TelegramAccountManagerTypes>.getCurrentRecords(basePath: rootPath + "/accounts-metadata")
        
        var result: [(AccountRecordId, Int, PeerId, Bool)] = []
        for record in view.records {
            let isLoggedOut = record.attributes.contains(where: { attribute in
                if case .loggedOut = attribute {
                    return true
                } else {
                    return false
                }
            })
            if isLoggedOut {
                continue
            }
            var backupData: AccountBackupData?
            var sortIndex: Int32 = 0
            for attribute in record.attributes {
                if case let .sortOrder(sortOrder) = attribute {
                    sortIndex = sortOrder.order
                } else if case let .backupData(backupDataValue) = attribute {
                    backupData = backupDataValue.data
                }
            }
            if let backupData = backupData {
                result.append((record.id, Int(sortIndex), PeerId(backupData.peerId), view.currentId == record.id))
            }
        }
        result.sort(by: { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 < rhs.1
            } else {
                return lhs.0 < rhs.0
            }
        })
        self.allAccounts.set(.single(result.map { record -> (AccountRecordId, PeerId, Bool) in
            return (record.0, record.2, record.3)
        }))
    }
    
    deinit {
        self.searchDisposable.dispose()
    }
    
    @available(iOSApplicationExtension 14.0, iOS 14.0, *)
    func provideFriendsOptionsCollection(searchTerm: String?, with completion: @escaping (INObjectCollection<Friend>?, Error?) -> Void) {
        guard let rootPath = self.rootPath, let encryptionParameters = self.encryptionParameters else {
            completion(nil, nil)
            return
        }
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
            
            //let presentationData = WidgetPresentationData.getForExtension()
            
            let error = NSError(domain: "Locked", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Open Telegram and enter passcode to edit widget."
            ])
            
            completion(nil, error)
            return
        }
        
        self.searchDisposable.set((self.allAccounts.get()
        |> castError(Error.self)
        |> take(1)
        |> mapToSignal { accounts -> Signal<INObjectCollection<Friend>, Error> in
            var accountResults: [Signal<INObjectSection<Friend>, Error>] = []
            
            for (accountId, accountPeerId, _) in accounts {
                accountResults.append(accountTransaction(rootPath: rootPath, id: accountId, encryptionParameters: encryptionParameters, isReadOnly: true, useCopy: false, transaction: { postbox, transaction -> INObjectSection<Friend> in
                    var accountTitle: String = ""
                    if let peer = transaction.getPeer(accountPeerId) as? TelegramUser {
                        if let username = peer.addressName, !username.isEmpty {
                            accountTitle = "@\(username)"
                        } else {
                            accountTitle = peer.debugDisplayTitle
                        }
                    }
                    
                    var peers: [Peer] = []
                    
                    if let searchTerm = searchTerm {
                        if !searchTerm.isEmpty {
                            for renderedPeer in transaction.searchPeers(query: searchTerm, predicate: nil) {
                                if let peer = renderedPeer.peer, !(peer is TelegramSecretChat), !peer.isDeleted {
                                    peers.append(peer)
                                }
                            }
                            
                            if peers.count > 30 {
                                peers = Array(peers.dropLast(peers.count - 30))
                            }
                        }
                    } else {
                        for renderedPeer in transaction.getTopChatListEntries(groupId: .root, count: 50) {
                            if let peer = renderedPeer.peer, !(peer is TelegramSecretChat), !peer.isDeleted {
                                peers.append(peer)
                            }
                        }
                    }
                    
                    let items = mapPeersToFriends(accountId: accountId, accountPeerId: accountPeerId, mediaBox: postbox.mediaBox, peers: peers)
                    
                    return INObjectSection<Friend>(title: accountTitle, items: items)
                })
                |> `catch` { _ -> Signal<INObjectSection<Friend>, NoError> in
                    return .single(INObjectSection<Friend>(title: nil, items: []))
                }
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
    }
    
    @available(iOSApplicationExtension 14.0, iOS 14.0, *)
    func defaultFriends() -> [Friend]? {
        guard let rootPath = self.rootPath, let encryptionParameters = self.encryptionParameters else {
            return []
        }
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
            return []
        }
        
        var resultItems: [Friend] = []
        
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        let _ = ((self.allAccounts.get()
        |> castError(Error.self)
        |> take(1)
        |> mapToSignal { accounts -> Signal<[Friend], Error> in
            var accountResults: [Signal<[Friend], Error>] = []
            
            for (accountId, accountPeerId, isActive) in accounts {
                if !isActive {
                    continue
                }
                accountResults.append(accountTransaction(rootPath: rootPath, id: accountId, encryptionParameters: encryptionParameters, isReadOnly: true, useCopy: false, transaction: { postbox, transaction -> [Friend] in
                    var peers: [Peer] = []
                    
                    for id in _internal_getRecentPeers(transaction: transaction) {
                        if let peer = transaction.getPeer(id), !(peer is TelegramSecretChat), !peer.isDeleted {
                            peers.append(peer)
                        }
                        if peers.count >= 8 {
                            break
                        }
                    }
                    
                    let items = mapPeersToFriends(accountId: accountId, accountPeerId: accountPeerId, mediaBox: postbox.mediaBox, peers: peers)
                    
                    return items
                })
                |> `catch` { _ -> Signal<[Friend], NoError> in
                    return .single([])
                }
                |> castError(Error.self))
            }
            
            return combineLatest(accountResults)
            |> map { accountResults -> [Friend] in
                var combinedResult: [Friend] = []
                for result in accountResults {
                    combinedResult.append(contentsOf: result)
                }
                return combinedResult
            }
        }).start(next: { result in
            resultItems = result
            semaphore.signal()
        }, error: { error in
            semaphore.signal()
        }))
        
        semaphore.wait()
        
        if resultItems.count > 8 {
            resultItems = Array(resultItems.dropLast(resultItems.count - 8))
        }
        
        return resultItems
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
@objc(FriendsIntentHandler)
class FriendsIntentHandler: NSObject, SelectFriendsIntentHandling {
    private let handler: WidgetIntentHandler
    
    override init() {
        self.handler = WidgetIntentHandler()
        
        super.init()
    }
    
    @available(iOSApplicationExtension 14.0, iOS 14.0, *)
    func provideFriendsOptionsCollection(for intent: SelectFriendsIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<Friend>?, Error?) -> Void) {
        self.handler.provideFriendsOptionsCollection(searchTerm: searchTerm, with: completion)
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
@objc(AvatarsIntentHandler)
class AvatarsIntentHandler: NSObject, SelectAvatarFriendsIntentHandling {
    private let handler: WidgetIntentHandler
    
    override init() {
        self.handler = WidgetIntentHandler()
        
        super.init()
    }
    
    @available(iOSApplicationExtension 14.0, iOS 14.0, *)
    func provideFriendsOptionsCollection(for intent: SelectAvatarFriendsIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<Friend>?, Error?) -> Void) {
        self.handler.provideFriendsOptionsCollection(searchTerm: searchTerm, with: completion)
    }
    
    @available(iOSApplicationExtension 14.0, iOS 14.0, *)
    func defaultFriends(for intent: SelectAvatarFriendsIntent) -> [Friend]? {
        return self.handler.defaultFriends()
    }
}

enum AvatarClipStyle {
    case round
    case roundedRect
}
private func avatarRoundImage(size: CGSize, source: UIImage, style: AvatarClipStyle) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()
    
    context?.beginPath()
    switch style {
    case .round:
        context?.addEllipse(in: CGRect(origin: .zero, size: size))
    case .roundedRect:
        context?.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.width * 0.25).cgPath)
    }
    context?.clip()
    
    source.draw(in: CGRect(origin: CGPoint(), size: size))
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private let deviceColorSpace: CGColorSpace = {
    if #available(iOSApplicationExtension 9.3, iOS 9.3, *) {
        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            return colorSpace
        } else {
            return CGColorSpaceCreateDeviceRGB()
        }
    } else {
        return CGColorSpaceCreateDeviceRGB()
    }
}()

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
}

private let gradientColors: [NSArray] = [
    [UIColor(rgb: 0xff516a).cgColor, UIColor(rgb: 0xff885e).cgColor],
    [UIColor(rgb: 0xffa85c).cgColor, UIColor(rgb: 0xffcd6a).cgColor],
    [UIColor(rgb: 0x665fff).cgColor, UIColor(rgb: 0x82b1ff).cgColor],
    [UIColor(rgb: 0x54cb68).cgColor, UIColor(rgb: 0xa0de7e).cgColor],
    [UIColor(rgb: 0x4acccd).cgColor, UIColor(rgb: 0x00fcfd).cgColor],
    [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor],
    [UIColor(rgb: 0xd669ed).cgColor, UIColor(rgb: 0xe0a2f3).cgColor],
]

private func avatarViewLettersImage(size: CGSize, peerId: Int64, accountPeerId: Int64, letters: [String]) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
    let context = UIGraphicsGetCurrentContext()
    
    context?.beginPath()
    context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context?.clip()
    
    let colorIndex = abs(Int(accountPeerId + peerId))
    
    let colorsArray = gradientColors[colorIndex % gradientColors.count]
    var locations: [CGFloat] = [1.0, 0.0]
    let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
    
    context?.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
    context?.setBlendMode(.normal)
    
    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20.0), NSAttributedString.Key.foregroundColor: UIColor.white])
    
    let line = CTLineCreateWithAttributedString(attributedString)
    let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    
    let lineOffset = CGPoint(x: string == "B" ? 1.0 : 0.0, y: 0.0)
    let lineOrigin = CGPoint(x: floor(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floor(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))
    
    context?.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context?.scaleBy(x: 1.0, y: -1.0)
    context?.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    
    context?.translateBy(x: lineOrigin.x, y: lineOrigin.y)
    if let context = context {
        CTLineDraw(line, context)
    }
    context?.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private func avatarImage(path: String?, peerId: Int64, accountPeerId: Int64, letters: [String], size: CGSize, style: AvatarClipStyle) -> UIImage {
    if let path = path, let image = UIImage(contentsOfFile: path), let roundImage = avatarRoundImage(size: size, source: image, style: style) {
        return roundImage
    } else {
        return avatarViewLettersImage(size: size, peerId: peerId, accountPeerId: accountPeerId, letters: letters)!
    }
}

private func generateTintedImage(image: UIImage?, color: UIColor, backgroundColor: UIColor? = nil) -> UIImage? {
    guard let image = image else {
        return nil
    }
    
    let imageSize = image.size

    UIGraphicsBeginImageContextWithOptions(imageSize, backgroundColor != nil, image.scale)
    if let context = UIGraphicsGetCurrentContext() {
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: imageSize))
        }
        
        let imageRect = CGRect(origin: CGPoint(), size: imageSize)
        context.saveGState()
        context.translateBy(x: imageRect.midX, y: imageRect.midY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
        context.clip(to: imageRect, mask: image.cgImage!)
        context.setFillColor(color.cgColor)
        context.fill(imageRect)
        context.restoreGState()
    }
    
    let tintedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return tintedImage
}

private let savedMessagesColors: NSArray = [
    UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor
]

private func savedMessagesImage(size: CGSize) -> UIImage? {
    guard let icon = generateTintedImage(image: UIImage(named: "Intents/SavedMessages"), color: .white) else {
        return nil
    }
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()
    
    context?.beginPath()
    context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context?.clip()
    
    let colorsArray = savedMessagesColors
    var locations: [CGFloat] = [1.0, 0.0]
    let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
    
    context?.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
    context?.setBlendMode(.normal)
    
    let factor = size.width / 60.0
    context?.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context?.scaleBy(x: factor, y: -factor)
    context?.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
    
    if let context = context {
        context.draw(icon.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - icon.size.width) / 2.0), y: floor((size.height - icon.size.height) / 2.0)), size: icon.size))
    }
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

@available(iOSApplicationExtension 14.0, iOS 14.0, *)
private func mapPeersToFriends(accountId: AccountRecordId, accountPeerId: PeerId, mediaBox: MediaBox, peers: [Peer]) -> [Friend] {
    var items: [Friend] = []
    for peer in peers {
        autoreleasepool {
            var profileImage: INImage?
            
            var isForum = false
            if let peer = peer as? TelegramChannel, peer.isForumOrMonoForum {
                isForum = true
            }
            
            if peer.id == accountPeerId {
                let cachedPath = mediaBox.cachedRepresentationPathForId("savedMessagesAvatar50x50", representationId: "intents.png", keepDuration: .shortLived)
                if let _ = fileSize(cachedPath) {
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: cachedPath), options: .alwaysMapped)
                        profileImage = INImage(imageData: data)
                    } catch {
                    }
                } else {
                    let image = savedMessagesImage(size: CGSize(width: 50.0, height: 50.0))
                    if let data = image?.pngData() {
                        let _ = try? data.write(to: URL(fileURLWithPath: cachedPath), options: .atomic)
                    }
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: cachedPath), options: .alwaysMapped)
                        profileImage = INImage(imageData: data)
                    } catch {
                    }
                }
            } else if let resource = smallestImageRepresentation(peer.profileImageRepresentations)?.resource, let path = mediaBox.completedResourcePath(resource) {
                let cachedPath = mediaBox.cachedRepresentationPathForId(resource.id.stringRepresentation, representationId: "intents.png", keepDuration: .shortLived)
                if let _ = fileSize(cachedPath) {
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: cachedPath), options: .alwaysMapped)
                        profileImage = INImage(imageData: data)
                    } catch {
                    }
                } else {
                    let image = avatarImage(path: path, peerId: peer.id.toInt64(), accountPeerId: accountPeerId.toInt64(), letters: peer.displayLetters, size: CGSize(width: 50.0, height: 50.0), style: isForum ? .roundedRect : .round)
                    if let data = image.pngData() {
                        let _ = try? data.write(to: URL(fileURLWithPath: cachedPath), options: .atomic)
                    }
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: cachedPath), options: .alwaysMapped)
                        profileImage = INImage(imageData: data)
                    } catch {
                    }
                }
            }
            if profileImage == nil {
                let cachedPath = mediaBox.cachedRepresentationPathForId("lettersAvatar-\(peer.displayLetters.joined(separator: ","))", representationId: "intents.png", keepDuration: .shortLived)
                if let _ = fileSize(cachedPath) {
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: cachedPath), options: .alwaysMapped)
                        profileImage = INImage(imageData: data)
                    } catch {
                    }
                } else {
                    let image = avatarImage(path: nil, peerId: peer.id.toInt64(), accountPeerId: accountPeerId.toInt64(), letters: peer.displayLetters, size: CGSize(width: 50.0, height: 50.0), style: isForum ? .roundedRect : .round)
                    if let data = image.pngData() {
                        let _ = try? data.write(to: URL(fileURLWithPath: cachedPath), options: .atomic)
                    }
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: cachedPath), options: .alwaysMapped)
                        profileImage = INImage(imageData: data)
                    } catch {
                    }
                }
            }
            
            var displayTitle = peer.debugDisplayTitle
            if peer.id == accountPeerId {
                displayTitle = WidgetPresentationData.getForExtension().chatSavedMessages
            }
            
            items.append(Friend(identifier: "\(accountId.int64):\(peer.id.toInt64())", display: displayTitle, subtitle: nil, image: profileImage))
        }
    }
    return items
}

/// `INSearchCallHistoryIntent` and friends were deprecated in iOS 15 with no replacement, but the
/// system still dispatches them, so the handler is retained. Keeping the conformance in a deprecated
/// extension is what lets the deprecated types appear in these signatures without tripping
/// `-warnings-as-errors`.
@available(iOS, deprecated: 15.0, message: "INSearchCallHistoryIntent has no replacement; retained while the system still dispatches it.")
extension DefaultIntentHandler: INSearchCallHistoryIntentHandling {
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
}
