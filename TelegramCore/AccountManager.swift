import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

private enum AccountKind {
    case authorized
    case unauthorized
}

public func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

public func performAppGroupUpgrades(appGroupPath: String, rootPath: String) {
    let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: rootPath), withIntermediateDirectories: true, attributes: nil)
    
    do {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableUrl = URL(fileURLWithPath: rootPath)
        try mutableUrl.setResourceValues(resourceValues)
    } catch let e {
        print("\(e)")
    }
    
    if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: appGroupPath), includingPropertiesForKeys: [], options: []) {
        for url in files {
            if url.lastPathComponent == "accounts-metadata" ||
                url.lastPathComponent.hasSuffix("logs") ||
                url.lastPathComponent.hasPrefix("account-") {
                let _ = try? FileManager.default.moveItem(at: url, to: URL(fileURLWithPath: rootPath + "/" + url.lastPathComponent))
            }
        }
    }
}

public final class TemporaryAccount {
    public let id: AccountRecordId
    public let basePath: String
    public let postbox: Postbox
    
    init(id: AccountRecordId, basePath: String, postbox: Postbox) {
        self.id = id
        self.basePath = basePath
        self.postbox = postbox
    }
}

public func temporaryAccount(manager: AccountManager, rootPath: String) -> Signal<TemporaryAccount, NoError> {
    return manager.allocatedTemporaryAccountId()
    |> mapToSignal { id -> Signal<TemporaryAccount, NoError> in
        let path = "\(rootPath)/\(accountRecordIdPathName(id))"
        return openPostbox(basePath: path + "/postbox", globalMessageIdsNamespace: Namespaces.Message.Cloud, seedConfiguration: telegramPostboxSeedConfiguration)
        |> mapToSignal { result -> Signal<TemporaryAccount, NoError> in
            switch result {
                case .upgrading:
                    return .complete()
                case let .postbox(postbox):
                    return .single(TemporaryAccount(id: id, basePath: path, postbox: postbox))
            }
        }
    }
}

public func currentAccount(networkArguments: NetworkInitializationArguments, supplementary: Bool, manager: AccountManager, rootPath: String, testingEnvironment: Bool, auxiliaryMethods: AccountAuxiliaryMethods) -> Signal<AccountResult?, NoError> {
    return manager.allocatedCurrentAccountId()
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
        |> mapToSignal { id -> Signal<AccountResult?, NoError> in
            if let id = id {
                let reload = ValuePromise<Bool>(true, ignoreRepeated: false)
                return reload.get() |> mapToSignal { _ -> Signal<AccountResult?, NoError> in
                    return accountWithId(networkArguments: networkArguments, id: id, supplementary: supplementary, rootPath: rootPath, testingEnvironment: testingEnvironment, auxiliaryMethods: auxiliaryMethods)
                        |> mapToSignal { accountResult -> Signal<AccountResult?, NoError> in
                            let postbox: Postbox
                            let initialKind: AccountKind
                            switch accountResult {
                                case .upgrading:
                                    return .complete()
                                case let .unauthorized(account):
                                    postbox = account.postbox
                                    initialKind = .unauthorized
                                case let .authorized(account):
                                    postbox = account.postbox
                                    initialKind = .authorized
                            }
                            let updatedKind = postbox.stateView()
                                |> map { view -> Bool in
                                    let kind: AccountKind
                                    if view.state is AuthorizedAccountState {
                                        kind = .authorized
                                    } else {
                                        kind = .unauthorized
                                    }
                                    if kind != initialKind {
                                        return true
                                    } else {
                                        return false
                                    }
                                }
                                |> distinctUntilChanged
                            
                            return Signal { subscriber in
                                subscriber.putNext(accountResult)
                                
                                return updatedKind.start(next: { value in
                                    if value {
                                        reload.set(true)
                                    }
                                })
                            }
                        }
                }
            } else {
                return .single(nil)
            }
        }
}

public func logoutFromAccount(id: AccountRecordId, accountManager: AccountManager) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        let currentId = transaction.getCurrentId()
        if let currentId = currentId {
            transaction.updateRecord(currentId, { current in
                if let current = current {
                    var found = false
                    for attribute in current.attributes {
                        if attribute is LoggedOutAccountAttribute {
                            found = true
                            break
                        }
                    }
                    if found {
                        return current
                    } else {
                        return AccountRecord(id: current.id, attributes: current.attributes + [LoggedOutAccountAttribute()], temporarySessionId: nil)
                    }
                } else {
                    return nil
                }
            })
            let id = transaction.createRecord([])
            transaction.setCurrentId(id)
        }
    }
}

public func managedCleanupAccounts(networkArguments: NetworkInitializationArguments, accountManager: AccountManager, rootPath: String, auxiliaryMethods: AccountAuxiliaryMethods) -> Signal<Void, NoError> {
    let currentTemporarySessionId = accountManager.temporarySessionId
    return Signal { subscriber in
        let loggedOutAccounts = Atomic<[AccountRecordId: MetaDisposable]>(value: [:])
        let _ = (accountManager.transaction { transaction -> Void in
            for record in transaction.getRecords() {
                if let temporarySessionId = record.temporarySessionId, temporarySessionId != currentTemporarySessionId {
                    transaction.updateRecord(record.id, { _ in
                        return nil
                    })
                }
            }
        }).start()
        let disposable = accountManager.accountRecords().start(next: { view in
            var disposeList: [(AccountRecordId, MetaDisposable)] = []
            var beginList: [(AccountRecordId, MetaDisposable)] = []
            let _ = loggedOutAccounts.modify { disposables in
                let validIds = Set(view.records.filter {
                    for attribute in $0.attributes {
                        if attribute is LoggedOutAccountAttribute {
                            return true
                        }
                    }
                    return false
                }.map { $0.id })
                
                var disposables = disposables
                
                for id in disposables.keys {
                    if !validIds.contains(id) {
                        disposeList.append((id, disposables[id]!))
                    }
                }
                
                for (id, _) in disposeList {
                    disposables.removeValue(forKey: id)
                }
                
                for id in validIds {
                    if disposables[id] == nil {
                        let disposable = MetaDisposable()
                        beginList.append((id, disposable))
                        disposables[id] = disposable
                    }
                }
                
                return disposables
            }
            for (_, disposable) in disposeList {
                disposable.dispose()
            }
            for (id, disposable) in beginList {
                disposable.set(cleanupAccount(networkArguments: networkArguments, accountManager: accountManager, id: id, rootPath: rootPath, auxiliaryMethods: auxiliaryMethods).start())
            }
            
            var validPaths = Set<String>()
            for record in view.records {
                if let temporarySessionId = record.temporarySessionId, temporarySessionId != currentTemporarySessionId {
                    continue
                }
                validPaths.insert("\(accountRecordIdPathName(record.id))")
            }
            
            if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath), includingPropertiesForKeys: [], options: []) {
                for url in files {
                    if url.lastPathComponent.hasPrefix("account-") {
                        if !validPaths.contains(url.lastPathComponent) {
                            try? FileManager.default.removeItem(at: url)
                        }
                    }
                }
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}

private func cleanupAccount(networkArguments: NetworkInitializationArguments, accountManager: AccountManager, id: AccountRecordId, rootPath: String, auxiliaryMethods: AccountAuxiliaryMethods) -> Signal<Void, NoError> {
    return accountWithId(networkArguments: networkArguments, id: id, supplementary: true, rootPath: rootPath, testingEnvironment: false, auxiliaryMethods: auxiliaryMethods)
        |> mapToSignal { account -> Signal<Void, NoError> in
            switch account {
                case .upgrading:
                    return .complete()
                case .unauthorized:
                    return .complete()
                case let .authorized(account):
                    account.shouldBeServiceTaskMaster.set(.single(.always))
                    return account.network.request(Api.functions.auth.logOut())
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                            return .single(.boolFalse)
                        }
                        |> mapToSignal { _ -> Signal<Void, NoError> in
                            account.shouldBeServiceTaskMaster.set(.single(.never))
                            return accountManager.transaction { transaction -> Void in
                                transaction.updateRecord(id, { _ in
                                    return nil
                                })
                            }
                        }
            }
        }
}
