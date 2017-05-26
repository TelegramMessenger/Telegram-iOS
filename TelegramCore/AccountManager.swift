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

public func currentAccount(networkArguments: NetworkInitializationArguments, supplementary: Bool, manager: AccountManager, appGroupPath: String, testingEnvironment: Bool, auxiliaryMethods: AccountAuxiliaryMethods) -> Signal<AccountResult?, NoError> {
    return manager.allocatedCurrentAccountId()
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
        |> mapToSignal { id -> Signal<AccountResult?, NoError> in
            if let id = id {
                let reload = ValuePromise<Bool>(true, ignoreRepeated: false)
                return reload.get() |> mapToSignal { _ -> Signal<AccountResult?, NoError> in
                    return accountWithId(networkArguments: networkArguments, id: id, supplementary: supplementary, appGroupPath: appGroupPath, testingEnvironment: testingEnvironment, auxiliaryMethods: auxiliaryMethods)
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
    return accountManager.modify { modifier -> Void in
        let currentId = modifier.getCurrentId()
        if let currentId = currentId {
            modifier.updateRecord(currentId, { current in
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
                        return AccountRecord(id: current.id, attributes: current.attributes + [LoggedOutAccountAttribute()])
                    }
                } else {
                    return nil
                }
            })
            let id = modifier.createRecord([])
            modifier.setCurrentId(id)
        }
    }
}

public func managedCleanupAccounts(networkArguments: NetworkInitializationArguments, accountManager: AccountManager, appGroupPath: String, auxiliaryMethods: AccountAuxiliaryMethods) -> Signal<Void, NoError> {
    return Signal { subscriber in
        let loggedOutAccounts = Atomic<[AccountRecordId: MetaDisposable]>(value: [:])
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
                disposable.set(cleanupAccount(networkArguments: networkArguments, accountManager: accountManager, id: id, appGroupPath: appGroupPath, auxiliaryMethods: auxiliaryMethods).start())
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}


private func cleanupAccount(networkArguments: NetworkInitializationArguments, accountManager: AccountManager, id: AccountRecordId, appGroupPath: String, auxiliaryMethods: AccountAuxiliaryMethods) -> Signal<Void, NoError> {
    return accountWithId(networkArguments: networkArguments, id: id, supplementary: true, appGroupPath: appGroupPath, testingEnvironment: false, auxiliaryMethods: auxiliaryMethods)
        |> mapToSignal { account -> Signal<Void, NoError> in
            switch account {
                case .upgrading:
                    return .complete()
                case .unauthorized:
                    return .complete()
                case let .authorized(account):
                    account.shouldBeServiceTaskMaster.set(.single(.always))
                    return account.network.request(Api.functions.auth.logOut())
                        |> map { Optional($0) }
                        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                            return .single(.boolFalse)
                        }
                        |> mapToSignal { _ -> Signal<Void, NoError> in
                            account.shouldBeServiceTaskMaster.set(.single(.never))
                            return accountManager.modify { modifier -> Void in
                                modifier.updateRecord(id, { _ in
                                    return nil
                                })
                            }
                        }
            }
        }
}
