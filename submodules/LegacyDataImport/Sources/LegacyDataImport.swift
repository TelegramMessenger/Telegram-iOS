import Foundation
import UIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import MtProtoKit
import LegacyDataImportImpl

public enum AccountImportError: Error {
    case generic
}

public enum AccountImportProgressType {
    case generic
    case messages
    case media
}

private func importedAccountData(basePath: String, documentsPath: String, accountManager: AccountManager, account: TemporaryAccount, database: SqliteInterface) -> Signal<(AccountImportProgressType, Float), AccountImportError> {
    return deferred { () -> Signal<(AccountImportProgressType, Float), AccountImportError> in
        let keychain = MTFileBasedKeychain(name: "Telegram", documentsPath: documentsPath)
        guard let masterDatacenterId = keychain.object(forKey: "defaultDatacenterId", group: "persistent") as? Int else {
            return .fail(.generic)
        }
        let keychainContents = keychain.contents(forGroup: "persistent")
        
        let importKeychain = account.postbox.transaction { transaction -> Void in
            for (key, value) in keychainContents {
                let data = NSKeyedArchiver.archivedData(withRootObject: value)
                transaction.setKeychainEntry(data, forKey: "persistent" + ":" + key)
            }
        }
        |> ignoreValues
        |> castError(AccountImportError.self)
        
        let importData = importPreferencesData(documentsPath: documentsPath, masterDatacenterId: Int32(masterDatacenterId), account: account, database: database)
        |> mapToSignal { accountUserId -> Signal<(AccountImportProgressType, Float), AccountImportError> in
            return importDatabaseData(accountManager: accountManager, account: account, basePath: basePath, database: database, accountUserId: accountUserId)
        }
        
        return importKeychain
        |> map { _ -> (AccountImportProgressType, Float) in return (.generic, 0.0) }
        |> then(importData)
    }
}

private func importPreferencesData(documentsPath: String, masterDatacenterId: Int32, account: TemporaryAccount, database: SqliteInterface) -> Signal<Int32, AccountImportError> {
    return deferred { () -> Signal<Int32, AccountImportError> in
        let defaultsPath = documentsPath + "/standard.defaults"
        var parsedAccountUserId: Int32?
        if let data = try? Data(contentsOf: URL(fileURLWithPath: defaultsPath)), let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: Any], let id = dict["telegraphUserId"] as? Int {
            parsedAccountUserId = Int32(id)
        }
        if parsedAccountUserId == nil {
            if let id = UserDefaults.standard.object(forKey: "telegraphUserId") as? Int {
                parsedAccountUserId = Int32(id)
            }
        }
        
        if let parsedAccountUserId = parsedAccountUserId {
            return account.postbox.transaction { transaction -> Int32 in
                transaction.setState(AuthorizedAccountState(isTestingEnvironment: false, masterDatacenterId: masterDatacenterId, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: parsedAccountUserId), state: nil))
                return parsedAccountUserId
            }
            |> castError(AccountImportError.self)
        } else {
            return .fail(.generic)
        }
    }
}

private func importDatabaseData(accountManager: AccountManager, account: TemporaryAccount, basePath: String, database: SqliteInterface, accountUserId: Int32) -> Signal<(AccountImportProgressType, Float), AccountImportError> {
    return deferred { () -> Signal<(AccountImportProgressType, Float), AccountImportError> in
        var importedAccountUser: Signal<Never, AccountImportError> = .complete()
        if let (user, presence) = loadLegacyUser(database: database, id: accountUserId) {
            importedAccountUser = account.postbox.transaction { transaction -> Void in
                updatePeers(transaction: transaction, peers: [user], update: { _, updated in updated })
                transaction.updatePeerPresencesInternal(presences: [user.id: presence], merge: { _, updated in return updated })
            }
            |> ignoreValues
            |> castError(AccountImportError.self)
        }
        
        let importedSecretChats = loadLegacySecretChats(account: account, basePath: basePath, accountPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: accountUserId), database: database)
        |> castError(AccountImportError.self)
        
        /*let importedFiles = loadLegacyFiles(account: account, basePath: basePath, accountPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: accountUserId), database: database)
        |> castError(AccountImportError.self)*/
        
        let importedLegacyPreferences = importLegacyPreferences(accountManager: accountManager, account: account, documentsPath: basePath + "/Documents", database: database)
        |> castError(AccountImportError.self)
        
        return importedAccountUser
        |> map { _ -> (AccountImportProgressType, Float) in return (.generic, 0.0) }
        |> then(
            importedLegacyPreferences
            |> map { _ -> (AccountImportProgressType, Float) in return (.generic, 0.0) }
        )
        |> then(
            importedSecretChats
            |> map { value -> (AccountImportProgressType, Float) in return (.messages, value) }
        )
    }
}

public enum ImportedLegacyAccountEvent {
    case progress(AccountImportProgressType, Float)
    case result(AccountRecordId?)
}

public func importedLegacyAccount(basePath: String, accountManager: AccountManager, encryptionParameters: ValueBoxEncryptionParameters, present: @escaping (UIViewController) -> Void) -> Signal<ImportedLegacyAccountEvent, AccountImportError> {
    let queue = Queue()
    return deferred { () -> Signal<ImportedLegacyAccountEvent, AccountImportError> in
        let documentsPath = basePath + "/Documents"
        if FileManager.default.fileExists(atPath: documentsPath + "/importcompleted") {
            return .single(.result(nil))
        }
        
        let unlockedDatabasePathAndKey: Signal<(String, Data?)?, AccountImportError>
        if FileManager.default.fileExists(atPath: documentsPath + "/tgdata.db.y") {
            let databasePath = documentsPath + "/tgdata.db.y"
            let unlockDatabase = Signal<(String, Data?)?, AccountImportError> { subscriber in
                let alertController = UIAlertController(title: nil, message: "Enter your passcode", preferredStyle: .alert)
                
                let confirmAction = UIAlertAction(title: "Enter", style: .default) { _ in
                    let passcode = alertController.textFields?[0].text
                    
                    func checkPasscode(_ value: String) -> Bool {
                        guard let database = SqliteInterface(databasePath: databasePath) else {
                            return false
                        }
                        let key = value.data(using: .utf8)!
                        if !database.unlock(password: hexString(key).data(using: .utf8)!) {
                            return false
                        }
                        
                        return true
                    }
                    
                    if checkPasscode(passcode ?? "") {
                        subscriber.putNext((databasePath, (passcode ?? "").data(using: .utf8)!))
                        subscriber.putCompletion()
                    } else {
                        let alertController = UIAlertController(title: nil, message: "Invalid passcode. Please try again.", preferredStyle: .alert)
                        
                        let confirmAction = UIAlertAction(title: "OK", style: .default) { _ in
                            subscriber.putCompletion()
                        }
                        
                        alertController.addAction(confirmAction)
                        
                        present(alertController)
                    }
                }
                
                let cancelAction = UIAlertAction(title: "Skip", style: .cancel) { _ in
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
                
                alertController.addTextField { textField in
                    textField.placeholder = "Passcode"
                }
                
                alertController.addAction(confirmAction)
                alertController.addAction(cancelAction)
                
                present(alertController)
                return EmptyDisposable
            }
            |> runOn(Queue.mainQueue())
            
            unlockedDatabasePathAndKey = (unlockDatabase
            |> mapToSignal { result -> Signal<(String, Data?)?, AccountImportError> in
                if let result = result {
                    return .single(result)
                } else {
                    let askAgain = Signal<(String, Data?)?, AccountImportError> { subscriber in
                        let alertController = UIAlertController(title: "Warning", message: "If you continue without entering your passcode, all your secret chats will be lost.", preferredStyle: .alert)
                        
                        let confirmAction = UIAlertAction(title: "Skip", style: .destructive) { _ in
                            subscriber.putError(.generic)
                        }
                        
                        let cancelAction = UIAlertAction(title: "Try Again", style: .cancel) { _ in
                            subscriber.putCompletion()
                        }
                        
                        alertController.addAction(confirmAction)
                        alertController.addAction(cancelAction)
                        
                        present(alertController)
                        return EmptyDisposable
                    }
                    |> runOn(Queue.mainQueue())
                    return askAgain
                }
            })
            |> restart
            |> take(1)
        } else if FileManager.default.fileExists(atPath: documentsPath + "/tgdata.db") {
            unlockedDatabasePathAndKey = .single((documentsPath + "/tgdata.db", nil))
        } else {
            return .single(.result(nil))
        }
        
        return unlockedDatabasePathAndKey
        |> mapToSignal { pathAndKey -> Signal<ImportedLegacyAccountEvent, AccountImportError> in
            guard let pathAndKey = pathAndKey else {
                return .fail(.generic)
            }
            
            guard let database = SqliteInterface(databasePath: pathAndKey.0) else {
                return .fail(.generic)
            }
            
            if let key = pathAndKey.1 {
                if !database.unlock(password: hexString(key).data(using: .utf8)!) {
                    return .fail(.generic)
                }
            }
            
            return temporaryAccount(manager: accountManager, rootPath: rootPathForBasePath(basePath), encryptionParameters: encryptionParameters)
            |> castError(AccountImportError.self)
            |> mapToSignal { account -> Signal<ImportedLegacyAccountEvent, AccountImportError> in
                let actions = importedAccountData(basePath: basePath, documentsPath: documentsPath, accountManager: accountManager, account: account, database: database)
                var result = actions
                |> map { typeAndProgress -> ImportedLegacyAccountEvent in
                    return .progress(typeAndProgress.0, typeAndProgress.1)
                }
                #if DEBUG
                //result = result
                //|> then(.never())
                #endif
                
                result = result
                |> then(.single(.result(account.id)))
                
                return result
            }
        }
    }
    |> runOn(queue)
}
