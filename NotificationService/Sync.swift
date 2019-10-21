//import SwiftSignalKit
//import Postbox
//import SyncCore
//import BuildConfig

@objc(SyncProviderImpl)
final class SyncProviderImpl: NSObject {
}

/*@objc(SyncProviderImpl)
final class SyncProviderImpl: NSObject, SyncProvider {
    func addIncomingMessage(withRootPath rootPath: String, accountId: Int64, encryptionParameters: DeviceSpecificEncryptionParameters, peerId: Int64, messageId: Int32, completion: ((Int32) -> Void)!) {
        let _ = (addIncomingMessageImpl(rootPath: rootPath, accountId: accountId, encryptionParameters: ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: encryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: encryptionParameters.salt)!), peerId: peerId, messageId: messageId)
        |> deliverOnMainQueue).start(next: { result in
            completion(Int32(clamping: result))
        })
    }
}

private func addIncomingMessageImpl(rootPath: String, accountId: Int64, encryptionParameters: ValueBoxEncryptionParameters, peerId: Int64, messageId: Int32) -> Signal<Int, NoError> {
    return accountTransaction(rootPath: rootPath, id: AccountRecordId(rawValue: accountId), encryptionParameters: encryptionParameters, transaction: { transaction -> Int in
        transaction.countIncomingMessage(id: MessageId(peerId: PeerId(peerId), namespace: Namespaces.Message.Cloud, id: messageId))
        let totalUnreadState = transaction.getTotalUnreadState()
        let totalCount = totalUnreadState.count(for: .filtered, in: .chats, with: [
            .regularChatsAndPrivateGroups,
            .publicGroups,
            .channels
        ])
        return Int(totalCount)
    })
}
*/
