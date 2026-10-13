import Foundation
import MtProtoKit
import Postbox
import SwiftSignalKit
import TelegramApi

public struct TonApiRequestError: Error, Equatable, Sendable {
    public let code: Int32
    public let description: String

    public init(code: Int32, description: String) {
        self.code = code
        self.description = description
    }
}

public struct WalletStreamingUrl: Equatable, Sendable {
    public let url: String
    public let expires: Int32

    public init(url: String, expires: Int32) {
        self.url = url
        self.expires = expires
    }
}

public struct WalletProofChallenge: Equatable, Sendable {
    public let payload: String
    public let expires: Int32
    public let domain: String
    public let timestamp: Int32

    public init(payload: String, expires: Int32, domain: String, timestamp: Int32) {
        self.payload = payload
        self.expires = expires
        self.domain = domain
        self.timestamp = timestamp
    }
}

public struct WalletOwnershipProof: Equatable, Sendable {
    public let timestamp: Int32
    public let signature: Data

    public init(timestamp: Int32, signature: Data) {
        self.timestamp = timestamp
        self.signature = signature
    }
}

public struct WalletExistingBalance: Equatable {
    public let hasBalance: Bool
    public let url: String?

    public init(hasBalance: Bool, url: String?) {
        self.hasBalance = hasBalance
        self.url = url
    }
}

public enum WalletState: Equatable, Sendable {
    case empty(creating: Bool)
    case ready(
        backupEnabled: Bool,
        canExportPhrase: Bool,
        canEnableBackup: Bool,
        address: String,
        publicKey: Data,
        balance: Int64
    )
}

public struct WalletUserAddress: Equatable {
    public let userId: EnginePeer.Id?
    public let address: String
    public let publicKey: Data

    public init(userId: EnginePeer.Id?, address: String, publicKey: Data) {
        self.userId = userId
        self.address = address
        self.publicKey = publicKey
    }
}

public enum WalletTransactionPeer: Equatable, @unchecked Sendable {
    case user(EnginePeer, address: String, domain: String?)
    case address(String, domain: String?)
    case onramp(address: String, domain: String?, providerName: String)
    case unsupported
}

public struct WalletTransaction: Equatable, Sendable {
    public let incoming: Bool
    public let gasless: Bool
    public let failed: Bool
    public let keyChange: Bool
    public let id: String
    public let amount: Int64
    public let fee: Int64
    public let date: Int32
    public let peer: WalletTransactionPeer
    public let comment: String?
    public let commentEncrypted: Bool
    public let txHash: String?
    public let nft: WalletNftItem?

    public init(
        incoming: Bool,
        gasless: Bool = false,
        failed: Bool,
        keyChange: Bool = false,
        id: String,
        amount: Int64,
        fee: Int64,
        date: Int32,
        peer: WalletTransactionPeer,
        comment: String?,
        commentEncrypted: Bool = false,
        txHash: String?,
        nft: WalletNftItem? = nil
    ) {
        self.incoming = incoming
        self.gasless = gasless
        self.failed = failed
        self.keyChange = keyChange
        self.id = id
        self.amount = amount
        self.fee = fee
        self.date = date
        self.peer = peer
        self.comment = comment
        self.commentEncrypted = commentEncrypted
        self.txHash = txHash
        self.nft = nft
    }
}

public struct WalletTransactions: Equatable {
    public let balance: Int64
    public let items: [WalletTransaction]
    public let nextOffset: String?

    public init(balance: Int64, items: [WalletTransaction], nextOffset: String?) {
        self.balance = balance
        self.items = items
        self.nextOffset = nextOffset
    }
}

public struct WalletGaslessInfo: Codable, Equatable, Sendable {
    public let available: Bool
    public let left: Int32
    public let resetAt: Int32
    public let minAmount: Int64
    public let relayerAddress: String

    public init(available: Bool, left: Int32, resetAt: Int32, minAmount: Int64, relayerAddress: String) {
        self.available = available
        self.left = left
        self.resetAt = resetAt
        self.minAmount = minAmount
        self.relayerAddress = relayerAddress
    }
}

public struct WalletSentTransfer: Codable, Equatable, Sendable {
    public let gasless: Bool
    public let msgHash: String

    public init(gasless: Bool, msgHash: String) {
        self.gasless = gasless
        self.msgHash = msgHash
    }
}

public struct WalletSendTransferResult: Equatable, Sendable {
    public let transfer: WalletSentTransfer
    public let transaction: WalletTransaction?
    public let gaslessInfo: WalletGaslessInfo

    public init(transfer: WalletSentTransfer, transaction: WalletTransaction?, gaslessInfo: WalletGaslessInfo) {
        self.transfer = transfer
        self.transaction = transaction
        self.gaslessInfo = gaslessInfo
    }
}

struct WalletSendTransferUpdates {
    let transfer: WalletSentTransfer
    let transaction: Api.WalletTransaction?
    let gaslessInfo: WalletGaslessInfo

    init?(updates: Api.Updates) {
        var transfer: Api.Update.Cons_updateSentWalletTransaction?
        var gaslessInfo: WalletGaslessInfo?
        for update in updates.allUpdates {
            switch update {
            case let .updateSentWalletTransaction(data):
                transfer = data
            case let .updateWalletGaslessInfo(data):
                gaslessInfo = WalletGaslessInfo(apiInfo: data)
            default:
                break
            }
        }
        guard let transfer, let gaslessInfo else { return nil }
        self.transfer = WalletSentTransfer(apiTransfer: transfer)
        self.transaction = transfer.transaction
        self.gaslessInfo = gaslessInfo
    }
}

public enum WalletTransferUpdate: Equatable, Sendable {
    case sentTransaction(WalletSentTransfer, WalletTransaction?)
    case gaslessInfo(WalletGaslessInfo)
}

extension WalletGaslessInfo {
    init(apiInfo: Api.Update.Cons_updateWalletGaslessInfo) {
        self.init(available: apiInfo.flags & 1 != 0, left: apiInfo.left, resetAt: apiInfo.resetAt, minAmount: apiInfo.minAmount, relayerAddress: apiInfo.relayerAddress)
    }
}

extension WalletSentTransfer {
    init(apiTransfer: Api.Update.Cons_updateSentWalletTransaction) {
        self.init(gasless: apiTransfer.flags & 1 != 0, msgHash: apiTransfer.msgHash)
    }
}

public enum WalletGetGaslessInfoError: Error {
    case generic
}

public enum WalletSendTransferError: Error, Equatable, Sendable {
    case invalidData
    case sendFailed
    case keyMismatch
    case network
    case generic
}

public enum WalletGetStateError: Error {
    case generic
}

public enum WalletGetUserAddressesError: Error {
    case generic
}

public enum WalletGetTransactionsError: Error {
    case generic
}

public enum WalletReplacement: Equatable, Sendable {
    case new
    case imported(publicKey: Data, anchorPublicKey: Data? = nil, proof: WalletOwnershipProof)
}

public enum WalletOperationError: Error, Equatable {
    case generic
    case network
    case preflightNetwork
    case requestPassword
    case invalidPassword
    case twoStepAuthMissing
    case passwordTooFresh(Int32)
    case sessionTooFresh(Int32)
    case backupDisabled
    case backupNotAvailable
    case replacementInvalid
    case publicKeyInvalid
    case proofInvalid
    case proofExpired
    case rotationNotFound
    case tokenInvalid
    case tokenExpired
    case clientKeyInvalid
    case partUnavailable
    case invalidBackupData
}

extension WalletState {
    public init(apiState: Api.WalletState) {
        switch apiState {
        case let .walletState(state):
            self = .ready(
                backupEnabled: (state.flags & (1 << 0)) != 0,
                canExportPhrase: (state.flags & (1 << 1)) != 0,
                canEnableBackup: (state.flags & (1 << 2)) != 0,
                address: state.address,
                publicKey: state.publicKey.makeData(),
                balance: state.balance
            )
        case let .walletStateEmpty(state):
            self = .empty(creating: (state.flags & (1 << 0)) != 0)
        }
    }
}

private extension WalletUserAddress {
    init(apiAddress: Api.WalletUserAddress) {
        switch apiAddress {
        case let .walletUserAddress(address):
            self.init(
                userId: address.userId.map { userId in
                    EnginePeer.Id(
                        namespace: Namespaces.Peer.CloudUser,
                        id: PeerId.Id._internalFromInt64Value(userId)
                    )
                },
                address: address.address,
                publicKey: address.publicKey.makeData()
            )
        }
    }
}

private extension WalletTransactionPeer {
    init(apiPeer: Api.WalletTransactionPeer, transaction: Transaction) {
        switch apiPeer {
        case let .walletTransactionPeerAddress(peer):
            self = .address(peer.address, domain: peer.domain)
        case let .walletTransactionPeerOnramp(peer):
            self = .onramp(address: peer.address, domain: peer.domain, providerName: peer.providerName)
        case .walletTransactionPeerUnsupported:
            self = .unsupported
        case let .walletTransactionPeerUser(apiPeer):
            let peerId = EnginePeer.Id(
                namespace: Namespaces.Peer.CloudUser,
                id: PeerId.Id._internalFromInt64Value(apiPeer.userId)
            )
            if let peer = transaction.getPeer(peerId) {
                self = .user(EnginePeer(peer), address: apiPeer.address, domain: apiPeer.domain)
            } else {
                self = .address(apiPeer.address, domain: apiPeer.domain)
            }
        }
    }
}

extension WalletTransaction {
    init(apiTransaction: Api.WalletTransaction, transaction: Transaction) {
        switch apiTransaction {
        case let .walletTransaction(walletTransaction):
            self.init(
                incoming: (walletTransaction.flags & (1 << 0)) != 0,
                gasless: (walletTransaction.flags & (1 << 1)) != 0,
                failed: (walletTransaction.flags & (1 << 2)) != 0,
                keyChange: (walletTransaction.flags & (1 << 5)) != 0,
                id: walletTransaction.id,
                amount: walletTransaction.amount,
                fee: walletTransaction.fee,
                date: walletTransaction.date,
                peer: WalletTransactionPeer(apiPeer: walletTransaction.peer, transaction: transaction),
                comment: walletTransaction.comment,
                commentEncrypted: (walletTransaction.flags & (1 << 6)) != 0,
                txHash: walletTransaction.txHash,
                nft: walletTransaction.nft.map(WalletNftItem.init(apiItem:))
            )
        }
    }
}

private func tonApiRequestError(_ error: MTRpcError) -> TonApiRequestError {
    return TonApiRequestError(code: error.errorCode, description: error.errorDescription)
}

private struct CachedExistingWaltBalance: Codable {
    let hasBalance: Bool
}

func _internal_getExistingWaltBalance(account: Account) -> Signal<WalletExistingBalance?, NoError> {
    let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedExistingWaltBalance, key: ValueBoxKey(length: 0))
    return account.postbox.transaction { transaction -> CachedExistingWaltBalance? in
        return transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedExistingWaltBalance.self)
    }
    |> mapToSignal { cachedBalance -> Signal<WalletExistingBalance?, NoError> in
        let cached: Signal<WalletExistingBalance?, NoError> = .single(
            WalletExistingBalance(hasBalance: cachedBalance?.hasBalance ?? false, url: nil)
        )

        let updated = account.network.request(Api.functions.wallet.getExistingWaltBalance())
        |> map { result -> WalletExistingBalance in
            switch result {
            case let .existingBalance(balance):
                return WalletExistingBalance(hasBalance: (balance.flags & (1 << 0)) != 0, url: balance.url)
            }
        }
        |> `catch` { _ -> Signal<WalletExistingBalance, NoError> in
            return .complete()
        }
        |> mapToSignal { balance -> Signal<WalletExistingBalance, NoError> in
            return account.postbox.transaction { transaction -> WalletExistingBalance in
                if let entry = CodableEntry(CachedExistingWaltBalance(hasBalance: balance.hasBalance)) {
                    transaction.putItemCacheEntry(id: cacheId, entry: entry)
                }
                return balance
            }
        }
        |> map(Optional.init)
        return cached |> then(updated)
    }
    |> distinctUntilChanged
}

func _internal_getWalletState(account: Account) -> Signal<WalletState, WalletGetStateError> {
    return account.network.request(Api.functions.wallet.getState())
    |> mapError { _ -> WalletGetStateError in
        return .generic
    }
    |> map { result in
        return WalletState(apiState: result)
    }
}

private struct CachedWalletUserAddresses: Codable {
    struct Address: Codable {
        let userId: Int64?
        let address: String
        let publicKey: Data
    }

    let addresses: [Address]
    let timestamp: Int32

    init(addresses: [WalletUserAddress], timestamp: Int32) {
        self.addresses = addresses.map { Address(userId: $0.userId?.toInt64(), address: $0.address, publicKey: $0.publicKey) }
        self.timestamp = timestamp
    }

    var userAddresses: [WalletUserAddress] {
        return self.addresses.map { WalletUserAddress(userId: $0.userId.map { PeerId($0) }, address: $0.address, publicKey: $0.publicKey) }
    }
}

func _internal_getWalletUserAddresses(
    account: Account,
    userIds: [EnginePeer.Id],
    addresses: [String],
    force: Bool,
    ageLimit: Int32 = 60
) -> Signal<[WalletUserAddress], WalletGetUserAddressesError> {
    guard !userIds.isEmpty || !addresses.isEmpty else {
        return .single([])
    }

    let cacheKey: ValueBoxKey?
    if addresses.count == 1 && userIds.isEmpty {
        cacheKey = ValueBoxKey("address:\(addresses[0])")
    } else if userIds.count == 1 && addresses.isEmpty {
        cacheKey = ValueBoxKey("userId:\(userIds[0].toInt64())")
    } else {
        cacheKey = nil
    }
    let cacheId = cacheKey.map { ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedWalletUserAddresses, key: $0) }

    return account.postbox.transaction { transaction -> (inputUsers: [Api.InputUser]?, cachedAddresses: [WalletUserAddress]?) in
        if let cacheId, let cachedEntry = transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedWalletUserAddresses.self) {
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            if cachedEntry.timestamp <= timestamp && cachedEntry.timestamp >= timestamp - ageLimit {
                return (nil, cachedEntry.userAddresses)
            }
        }

        var inputUsers: [Api.InputUser] = []
        inputUsers.reserveCapacity(userIds.count)
        for userId in userIds {
            if userId == account.peerId {
                inputUsers.append(.inputUserSelf)
            } else if userId.namespace == Namespaces.Peer.CloudUser,
                      let peer = transaction.getPeer(userId),
                      let inputUser = apiInputUser(peer) {
                inputUsers.append(inputUser)
            } else {
                return (nil, nil)
            }
        }
        return (inputUsers, nil)
    }
    |> castError(WalletGetUserAddressesError.self)
    |> mapToSignal { result -> Signal<[WalletUserAddress], WalletGetUserAddressesError> in
        if let cachedAddresses = result.cachedAddresses {
            return .single(cachedAddresses)
        }
        guard let inputUsers = result.inputUsers else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        if force {
            flags |= 1 << 0
        }
        return account.network.request(Api.functions.wallet.getUserAddresses(flags: flags, id: inputUsers, addresses: addresses))
        |> mapError { _ -> WalletGetUserAddressesError in
            return .generic
        }
        |> mapToSignal { result -> Signal<[WalletUserAddress], WalletGetUserAddressesError> in
            return account.postbox.transaction { transaction -> [WalletUserAddress] in
                switch result {
                case let .userAddresses(data):
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: data.users)
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                    let addresses = data.addresses.map { WalletUserAddress(apiAddress: $0) }
                    if let cacheId {
                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                        if let entry = CodableEntry(CachedWalletUserAddresses(addresses: addresses, timestamp: timestamp)) {
                            transaction.putItemCacheEntry(id: cacheId, entry: entry)
                        }
                    }
                    return addresses
                }
            }
            |> castError(WalletGetUserAddressesError.self)
        }
    }
}

func _internal_getWalletTransactions(
    account: Account,
    inbound: Bool,
    outbound: Bool,
    offset: String,
    limit: Int32
) -> Signal<WalletTransactions, WalletGetTransactionsError> {
    var flags: Int32 = 0
    if inbound {
        flags |= 1 << 0
    }
    if outbound {
        flags |= 1 << 1
    }

    return account.network.request(Api.functions.wallet.getTransactions(
        flags: flags,
        offset: offset,
        limit: limit
    ))
    |> mapError { _ -> WalletGetTransactionsError in
        return .generic
    }
    |> mapToSignal { result -> Signal<WalletTransactions, WalletGetTransactionsError> in
        return _internal_walletTransactionsResult(account: account, result: result)
    }
}

func _internal_getWalletGaslessInfo(account: Account) -> Signal<WalletGaslessInfo, WalletGetGaslessInfoError> {
    return account.network.request(Api.functions.wallet.getGaslessInfo(), automaticFloodWait: false)
    |> mapError { _ -> WalletGetGaslessInfoError in .generic }
    |> mapToSignal { updates -> Signal<WalletGaslessInfo, WalletGetGaslessInfoError> in
        account.stateManager.addUpdates(updates)
        guard let info = updates.allUpdates.compactMap({ update -> WalletGaslessInfo? in
            if case let .updateWalletGaslessInfo(data) = update {
                return WalletGaslessInfo(apiInfo: data)
            }
            return nil
        }).last else { return .fail(.generic) }
        return .single(info)
    }
}

func _internal_sendWalletTransfer(account: Account, dataNormal: Data, dataGasless: Data?, recipientPeerId: EnginePeer.Id?, randomId: Int64, pendingMessage: WalletPendingTransferMessageReference? = nil) -> Signal<WalletSendTransferResult, WalletSendTransferError> {
    guard !dataNormal.isEmpty, dataNormal.count <= 16 * 1024,
          (dataGasless?.count ?? 0) <= 16 * 1024 else {
        if let pendingMessage {
            return _internal_removePendingWalletTransferMessage(postbox: account.postbox, reference: pendingMessage)
            |> castError(WalletSendTransferError.self)
            |> mapToSignal { _ in .fail(.invalidData) }
        }
        return .fail(.invalidData)
    }
    return account.postbox.transaction { transaction -> Api.InputUser in
        guard let recipientPeerId,
              recipientPeerId.namespace == Namespaces.Peer.CloudUser,
              let peer = transaction.getPeer(recipientPeerId),
              let inputUser = apiInputUser(peer) else {
            return .inputUserEmpty
        }
        return inputUser
    }
    |> castError(WalletSendTransferError.self)
    |> mapToSignal { inputUser -> Signal<Api.Updates, WalletSendTransferError> in
        return account.network.request(Api.functions.wallet.sendTransfer(
            flags: dataGasless == nil ? 0 : (1 << 0),
            dataNormal: Buffer(data: dataNormal),
            dataGasless: dataGasless.map { Buffer(data: $0) },
            userId: inputUser,
            randomId: randomId
        ), automaticFloodWait: false)
        |> mapError { error -> WalletSendTransferError in
            switch error.errorDescription {
            case "WALLET_TRANSFER_DATA_INVALID":
                return .invalidData
            case "WALLET_KEY_MISMATCH":
                return .keyMismatch
            case "WALLET_TRANSFER_SEND_FAILED":
                return .sendFailed
            default:
                return error.errorCode < 0 ? .network : .generic
            }
        }
    }
    |> mapToSignal { updates -> Signal<WalletSendTransferResult, WalletSendTransferError> in
        return account.postbox.transaction { transaction -> WalletSendTransferResult? in
            let peers = AccumulatedPeers(transaction: transaction, chats: updates.chats, users: updates.users)
            updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: peers)
            var messageIds: [Int64: Int32] = [:]
            for update in updates.allUpdates {
                if case let .updateMessageID(value) = update {
                    messageIds[value.randomId] = value.id
                }
            }
            _ = applyWalletTransferMessageIds(transaction: transaction, mappings: messageIds)
            guard let data = WalletSendTransferUpdates(updates: updates) else { return nil }
            let result = WalletSendTransferResult(
                transfer: data.transfer,
                transaction: data.transaction.map { WalletTransaction(apiTransaction: $0, transaction: transaction) },
                gaslessInfo: data.gaslessInfo
            )
            if !result.transfer.msgHash.isEmpty, let pendingMessage {
                acceptPendingWalletTransferMessage(transaction: transaction, reference: pendingMessage, transfer: result.transfer, receivedAt: Int32(clamping: Int64(Date().timeIntervalSince1970)))
                if let value = result.transaction, case let .user(peer, _, _) = value.peer, peer.id.toInt64() == pendingMessage.peerId {
                    resolvePendingWalletTransferMessage(transaction: transaction, reference: pendingMessage, transactionId: value.id, failed: value.failed)
                }
            }
            return result
        }
        |> castError(WalletSendTransferError.self)
        |> mapToSignal { result -> Signal<WalletSendTransferResult, WalletSendTransferError> in
            account.stateManager.addUpdates(updates)
            guard let result else {
                return .fail(.generic)
            }
            guard !result.transfer.msgHash.isEmpty else { return .fail(.sendFailed) }
            return .single(result)
        }
    }
}

func _internal_getWalletTransactionsByIDs(account: Account, ids: [String]) -> Signal<WalletTransactions, WalletGetTransactionsError> {
    return account.network.request(Api.functions.wallet.getTransactionsByIDs(id: ids), automaticFloodWait: false)
    |> mapError { _ -> WalletGetTransactionsError in .generic }
    |> mapToSignal { result in
        return _internal_walletTransactionsResult(account: account, result: result)
    }
}

func _internal_getWalletTransactionsByMsgHash(account: Account, msgHash: [String]) -> Signal<WalletTransactions, WalletGetTransactionsError> {
    return account.network.request(Api.functions.wallet.getTransactionsByMsgHash(msgHash: msgHash), automaticFloodWait: false)
    |> mapError { _ -> WalletGetTransactionsError in .generic }
    |> mapToSignal { result in
        return _internal_walletTransactionsResult(account: account, result: result)
    }
}

func _internal_walletTransactionsResult(account: Account, result: Api.wallet.Transactions) -> Signal<WalletTransactions, WalletGetTransactionsError> {
    return account.postbox.transaction { transaction -> WalletTransactions in
        switch result {
        case let .transactions(transactions):
            let parsedPeers = AccumulatedPeers(
                transaction: transaction,
                chats: transactions.chats,
                users: transactions.users
            )
            updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
            return WalletTransactions(
                balance: transactions.balance,
                items: transactions.transactions.map {
                    return WalletTransaction(apiTransaction: $0, transaction: transaction)
                },
                nextOffset: transactions.nextOffset
            )
        }
    }
    |> castError(WalletGetTransactionsError.self)
}

func _internal_getStreamingUrl(account: Account) -> Signal<WalletStreamingUrl, TonApiRequestError> {
    let request = Api.functions.toncenter.getStreamingUrl()

    return currentWebDocumentsHostDatacenterId(
        postbox: account.postbox,
        isTestingEnvironment: account.testingEnvironment
    )
    |> castError(TonApiRequestError.self)
    |> mapToSignal { datacenterId -> Signal<Api.toncenter.StreamingUrl, TonApiRequestError> in
        let targetDatacenterId = Int(datacenterId)
        let signal: Signal<Api.toncenter.StreamingUrl, MTRpcError>
        if account.network.datacenterId == targetDatacenterId {
            signal = account.network.request(request)
        } else {
            signal = account.network.download(datacenterId: targetDatacenterId, isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(request)
            }
        }

        return signal
        |> mapError { error in
            return tonApiRequestError(error)
        }
    }
    |> map { result -> WalletStreamingUrl in
        switch result {
        case let .streamingUrl(streamingUrl):
            return WalletStreamingUrl(url: streamingUrl.url, expires: streamingUrl.expires)
        }
    }
}

func _internal_performTonApiRequest(
    account: Account,
    flags: Int32,
    endpoint: String,
    query: String?,
    payload: String?
) -> Signal<String, TonApiRequestError> {
    let request = Api.functions.toncenter.performApiRequest(
        flags: flags,
        endpoint: endpoint,
        query: query,
        payload: payload
    )

    return currentWebDocumentsHostDatacenterId(
        postbox: account.postbox,
        isTestingEnvironment: account.testingEnvironment
    )
    |> castError(TonApiRequestError.self)
    |> mapToSignal { datacenterId -> Signal<Api.toncenter.ApiResponse, TonApiRequestError> in
        let targetDatacenterId = Int(datacenterId)
        let signal: Signal<Api.toncenter.ApiResponse, MTRpcError>
        if account.network.datacenterId == targetDatacenterId {
            signal = account.network.request(request)
        } else {
            signal = account.network.download(datacenterId: targetDatacenterId, isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(request)
            }
        }

        return signal
        |> mapError { error in
            return tonApiRequestError(error)
        }
    }
    |> map { result -> String in
        switch result {
        case let .apiResponse(apiResponse):
            switch apiResponse.response {
            case let .dataJSON(dataJSON):
                return dataJSON.data
            }
        }
    }
}
