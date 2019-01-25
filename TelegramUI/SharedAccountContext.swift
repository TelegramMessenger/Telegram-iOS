import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

public final class SharedAccountContext {
    public let applicationBindings: TelegramApplicationBindings
    public let accountManager: AccountManager
    
    private let apsNotificationToken: Signal<Data?, NoError>
    private let voipNotificationToken: Signal<Data?, NoError>
    
    private var activeAccountsValue: (primary: Account?, accounts: [AccountRecordId: Account], currentAuth: UnauthorizedAccount?)?
    private let activeAccountsPromise = Promise<(primary: Account?, accounts: [AccountRecordId: Account], currentAuth: UnauthorizedAccount?)>()
    public var activeAccounts: Signal<(primary: Account?, accounts: [AccountRecordId: Account], currentAuth: UnauthorizedAccount?), NoError> {
        return self.activeAccountsPromise.get()
    }
    
    private var activeUnauthorizedAccountValue: UnauthorizedAccount?
    private let activeUnauthorizedAccountPromise = Promise<UnauthorizedAccount?>()
    public var activeUnauthorizedAccount: Signal<UnauthorizedAccount?, NoError> {
        return self.activeUnauthorizedAccountPromise.get()
    }
    
    private let registeredNotificationTokensDisposable = MetaDisposable()
    
    public let mediaManager: MediaManager
    public let contactDataManager: DeviceContactDataManager?
    let locationManager: DeviceLocationManager?
    
    var switchingSettingsController: (SettingsController & ViewController)?
    
    public init(accountManager: AccountManager, applicationBindings: TelegramApplicationBindings, networkArguments: NetworkInitializationArguments, rootPath: String, apsNotificationToken: Signal<Data?, NoError>, voipNotificationToken: Signal<Data?, NoError>) {
        assert(Queue.mainQueue().isCurrent())
        self.applicationBindings = applicationBindings
        self.accountManager = accountManager
        
        self.apsNotificationToken = apsNotificationToken
        self.voipNotificationToken = voipNotificationToken
        
        self.mediaManager = MediaManager(inForeground: applicationBindings.applicationInForeground)
        
        if applicationBindings.isMainApp {
            self.locationManager = DeviceLocationManager(queue: Queue.mainQueue())
            self.contactDataManager = DeviceContactDataManager()
        } else {
            self.locationManager = nil
            self.contactDataManager = nil
        }
        
        let differenceDisposable = MetaDisposable()
        let _ = (accountManager.accountRecords()
        |> map { view -> (AccountRecordId?, [AccountRecordId: Bool], (AccountRecordId, Bool)?) in
            var result: [AccountRecordId: Bool] = [:]
            for record in view.records {
                let isLoggedOut = record.attributes.contains(where: { attribute in
                    return attribute is LoggedOutAccountAttribute
                })
                if isLoggedOut {
                    continue
                }
                let isTestingEnvironment = record.attributes.contains(where: { attribute in
                    if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
                        return true
                    } else {
                        return false
                    }
                })
                result[record.id] = isTestingEnvironment
            }
            let authRecord: (AccountRecordId, Bool)? = view.currentAuthAccount.flatMap({ authAccount in
                let isTestingEnvironment = authAccount.attributes.contains(where: { attribute in
                    if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
                        return true
                    } else {
                        return false
                    }
                })
                return (authAccount.id, isTestingEnvironment)
            })
            return (view.currentRecord?.id, result, authRecord)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.0 != rhs.0 {
                return false
            }
            if lhs.1 != rhs.1 {
                return false
            }
            if lhs.2?.0 != rhs.2?.0 {
                return false
            }
            if lhs.2?.1 != rhs.2?.1 {
                return false
            }
            return true
        })
        |> deliverOnMainQueue).start(next: { primaryId, records, authRecord in
            var addedSignals: [Signal<Account?, NoError>] = []
            var addedAuthSignal: Signal<UnauthorizedAccount?, NoError> = .single(nil)
            for (id, isTestingEnvironment) in records {
                if self.activeAccountsValue?.accounts[id] == nil {
                    addedSignals.append(accountWithId(networkArguments: networkArguments, id: id, supplementary: false, rootPath: rootPath, beginWithTestingEnvironment: isTestingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                    |> map { result -> Account? in
                        switch result {
                            case let .authorized(account):
                                return account
                            default:
                                return nil
                        }
                    })
                }
            }
            if let authRecord = authRecord, authRecord.0 != self.activeAccountsValue?.currentAuth?.id {
                addedAuthSignal = accountWithId(networkArguments: networkArguments, id: authRecord.0, supplementary: false, rootPath: rootPath, beginWithTestingEnvironment: authRecord.1, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                |> map { result -> UnauthorizedAccount? in
                    switch result {
                        case let .unauthorized(account):
                            return account
                        default:
                            return nil
                    }
                }
            }
            differenceDisposable.set((combineLatest(combineLatest(addedSignals), addedAuthSignal)
            |> deliverOnMainQueue).start(next: { accounts, authAccount in
                var hadUpdates = false
                if self.activeAccountsValue == nil {
                    self.activeAccountsValue = (nil, [:], nil)
                    hadUpdates = true
                }
                for account in accounts {
                    if let account = account {
                        self.activeAccountsValue!.accounts[account.id] = account
                        hadUpdates = true
                    }
                }
                var removedIds: [AccountRecordId] = []
                for id in self.activeAccountsValue!.accounts.keys {
                    if records[id] == nil {
                        removedIds.append(id)
                    }
                }
                for id in removedIds {
                    hadUpdates = true
                    self.activeAccountsValue!.accounts.removeValue(forKey: id)
                }
                var primary: Account?
                if let primaryId = primaryId {
                    primary = self.activeAccountsValue!.accounts[primaryId]
                } else if !self.activeAccountsValue!.accounts.isEmpty {
                    primary = self.activeAccountsValue!.accounts.sorted(by: { lhs, rhs in lhs.key < rhs.key }).first?.1
                }
                if primary !== self.activeAccountsValue!.primary {
                    hadUpdates = true
                    self.activeAccountsValue!.primary?.postbox.clearCaches()
                    self.activeAccountsValue!.primary = primary
                }
                if self.activeAccountsValue!.currentAuth?.id != authRecord?.0 {
                    hadUpdates = true
                    self.activeAccountsValue!.currentAuth?.postbox.clearCaches()
                    self.activeAccountsValue!.currentAuth = nil
                }
                if let authAccount = authAccount {
                    hadUpdates = true
                    self.activeAccountsValue!.currentAuth = authAccount
                }
                if hadUpdates {
                    self.activeAccountsPromise.set(.single(self.activeAccountsValue!))
                }
                
                if self.activeAccountsValue!.primary == nil && self.activeAccountsValue!.currentAuth == nil {
                    self.beginNewAuth(testingEnvironment: false)
                }
            }))
        })
        
        let _ = managedCleanupAccounts(networkArguments: networkArguments, accountManager: self.accountManager, rootPath: rootPath, auxiliaryMethods: telegramAccountAuxiliaryMethods).start()
        
        self.updateNotificationTokensRegistration()
    }
    
    deinit {
        assertionFailure("SharedAccountContext is not supposed to be deallocated")
        self.registeredNotificationTokensDisposable.dispose()
    }
    
    public func updateNotificationTokensRegistration() {
        let sandbox: Bool
        #if DEBUG
        sandbox = true
        #else
        sandbox = false
        #endif
        
        self.registeredNotificationTokensDisposable.set((self.activeAccounts
        |> mapToSignal { _, activeAccounts, _ -> Signal<Never, NoError> in
            var applied: [Signal<Never, NoError>] = []
            let activeUserIds = activeAccounts.values.map({ $0.peerId.id })
            for (_, account) in activeAccounts {
                let appliedAps = self.apsNotificationToken
                |> distinctUntilChanged(isEqual: { $0 == $1 })
                |> mapToSignal { token -> Signal<Never, NoError> in
                    guard let token = token else {
                        return .complete()
                    }
                    return registerNotificationToken(account: account, token: token, type: .aps, sandbox: sandbox, otherAccountUserIds: activeUserIds.filter({ $0 != account.peerId.id }))
                }
                let appliedVoip = self.voipNotificationToken
                |> distinctUntilChanged(isEqual: { $0 == $1 })
                |> mapToSignal { token -> Signal<Never, NoError> in
                    guard let token = token else {
                        return .complete()
                    }
                    return registerNotificationToken(account: account, token: token, type: .voip, sandbox: sandbox, otherAccountUserIds: activeUserIds.filter({ $0 != account.peerId.id }))
                }
                
                applied.append(appliedAps)
                applied.append(appliedVoip)
            }
            return combineLatest(applied)
            |> ignoreValues
        }).start())
    }
    
    public func beginNewAuth(testingEnvironment: Bool) {
        let _ = self.accountManager.transaction({ transaction -> Void in
            let _ = transaction.createAuth([AccountEnvironmentAttribute(environment: testingEnvironment ? .test : .production)])
        }).start()
    }
    
    func switchToAccount(id: AccountRecordId, fromSettingsController settingsController: (SettingsController & ViewController)? = nil) {
        assert(Queue.mainQueue().isCurrent())
        self.switchingSettingsController = settingsController
        let _ = self.accountManager.transaction({ transaction in
            transaction.setCurrentId(id)
        }).start()
    }
}
