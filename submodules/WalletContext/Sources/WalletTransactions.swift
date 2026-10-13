import Foundation
import TelegramCore
import SwiftSignalKit
import WalletEngineFFI

let walletTransactionFetchLimit = 25

@available(macOS 10.15, *)
struct WalletPeerAddressMapping: @unchecked Sendable {
    let peer: EnginePeer
    let address: String
}

@available(macOS 10.15, *)
struct ResolvedTransferInput {
    let destination: WalletTransferDestination
    var address: String { self.destination.address }
    let amount: Int64
    let hasLinkAmount: Bool
    let body: SendMessageBody
    let comment: String?
    let expiration: SendExpiration
}

@available(macOS 10.15, *)
struct WalletTransferDestination {
    let address: String
    let bounce: Bool

    init(_ address: String) throws {
        guard let info = try? parseTonAddress(value: address), !isTestnetAddress(info.format) else {
            throw WalletContext.WalletError.invalidAddress
        }
        // Friendly-address flags are part of the sender's intent, even for an uninitialized account.
        switch info.format {
        case .raw:
            self.bounce = false
        case let .userFriendly(bounceable, _):
            self.bounce = bounceable
        }
        guard let normalized = try? convertTonAddress(
            value: address,
            format: .userFriendly(bounceable: self.bounce, testnet: false)
        ) else {
            throw WalletContext.WalletError.invalidAddress
        }
        self.address = normalized
    }

    func message(amount: SendAmount, body: SendMessageBody) -> SendMessage {
        return SendMessage(destination: self.address, amount: amount, body: body, bounce: self.bounce, stateInit: nil)
    }
}

@available(macOS 10.15, *)
func resolveTransferInput(address: String, amount: Int64, comment: String?) throws -> ResolvedTransferInput {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    let link: ParsedTonTransferLink?
    if trimmed.lowercased().hasPrefix("ton://") {
        do {
            link = try parseTonTransferLink(value: trimmed)
        } catch {
            throw WalletContext.WalletError.invalidAddress
        }
    } else {
        link = nil
    }

    let recipient = link?.recipient ?? trimmed
    let destination = try WalletTransferDestination(recipient)

    if let link {
        guard case .gram = link.asset else {
            throw WalletContext.WalletError.invalidAddress
        }
    }

    var resolvedAmount = amount
    if resolvedAmount <= 0, let linkAmount = link?.amount {
        guard let parsed = Int64(linkAmount) else {
            throw WalletContext.WalletError.invalidAmount
        }
        resolvedAmount = parsed
    }
    guard resolvedAmount > 0 else {
        throw WalletContext.WalletError.invalidAmount
    }

    let explicitComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
    let linkComment: String?
    let linkBody: SendMessageBody
    if let payload = link?.payload {
        switch payload {
        case .none:
            linkComment = nil
            linkBody = .empty
        case let .text(text):
            linkComment = text
            linkBody = .comment(text: text)
        case let .boc(boc):
            linkComment = nil
            linkBody = .rawPayload(boc: boc)
        }
    } else {
        linkComment = nil
        linkBody = .empty
    }
    let resolvedComment = (explicitComment?.isEmpty == false ? explicitComment : nil) ?? linkComment
    let body: SendMessageBody
    if let resolvedComment {
        body = .comment(text: resolvedComment)
    } else {
        body = linkBody
    }
    return ResolvedTransferInput(
        destination: destination,
        amount: resolvedAmount,
        hasLinkAmount: link?.amount != nil,
        body: body,
        comment: resolvedComment,
        expiration: link?.expiration ?? .engineDefault
    )
}

@available(macOS 10.15, *)
private func isTestnetAddress(_ format: TonAddressFormat) -> Bool {
    switch format {
    case .raw:
        return false
    case let .userFriendly(_, testnet):
        return testnet
    }
}

@available(macOS 10.15, *)
func walletTransactions(
    from transactions: [TelegramCore.WalletTransaction]
) -> [WalletContext.Transaction] {
    var seenIds = Set<String>()
    var result: [WalletContext.Transaction] = []
    result.reserveCapacity(transactions.count)
    for transaction in transactions {
        guard seenIds.insert(transaction.id).inserted else {
            continue
        }
        let peer: WalletContext.Transaction.Peer
        switch transaction.peer {
        case let .user(enginePeer, address, domain):
            peer = .user(enginePeer, address: address, domain: domain)
        case let .address(address, domain):
            peer = .address(address, domain: domain)
        case let .onramp(address, domain, providerName):
            peer = .onramp(address: address, domain: domain, providerName: providerName)
        case .unsupported:
            peer = .unsupported
        }

        let status: WalletContext.Transaction.Status = transaction.failed ? .failed : .completed
        let logicalTime = transaction.id.split(separator: ":", maxSplits: 1).first.map(String.init)
            ?? transaction.id
        result.append(WalletContext.Transaction(
            id: transaction.id,
            transactionHash: transaction.txHash,
            logicalTime: logicalTime,
            timestamp: transaction.date,
            direction: transaction.incoming ? .incoming : .outgoing,
            amount: transaction.amount,
            fee: transaction.fee,
            gasless: transaction.gasless,
            peer: peer,
            comment: transaction.comment,
            commentEncrypted: transaction.commentEncrypted,
            collectible: transaction.nft.map {
                WalletContext.Transaction.CollectibleTransfer(collectible: walletCollectible(from: $0))
            },
            status: status,
            kind: transaction.keyChange ? .keyChange : .transfer
        ))
    }
    return result
}

@available(macOS 10.15, *)
func walletTransactions(
    from transactions: [WalletStoredTransaction],
    engine: TelegramEngine
) async throws -> [WalletContext.Transaction] {
    let peerIds = Array(Set(transactions.compactMap { $0.peer.userId }))
    guard !peerIds.isEmpty else {
        return transactions.map { $0.transaction(peers: [:]) }
    }
    let values = try await WalletSignalRequestContext<[EnginePeer.Id: EnginePeer?]>().run(
        engine.data.get(EngineDataMap(
            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
        ))
        |> castError(WalletContext.WalletError.self)
    )
    var peers: [EnginePeer.Id: EnginePeer] = [:]
    for (id, peer) in values {
        if let peer {
            peers[id] = peer
        }
    }
    return transactions.map { $0.transaction(peers: peers) }
}

@available(macOS 10.15, *)
func mergeTransactions(
    existing: [WalletContext.Transaction],
    new: [WalletContext.Transaction],
    source: String = "history",
    log: ((String) -> Void)? = nil
) -> [WalletContext.Transaction] {
    let transactions = existing + new
    let identityIndex = WalletTransactionIdentityIndex(transactions)
    let values = identityIndex.groups.map { indices -> WalletContext.Transaction in
        let current = transactions[indices[0]]
        let preferredIndex = indices.first(where: { $0 >= existing.count }) ?? indices[0]
        let preferred = transactions[preferredIndex]
        let preservePresentationId = current.presentationId != current.id
            || walletIncomingTransactionIdentity(current) != nil
        let fallbackHash = indices.lazy.map { transactions[$0] }.first {
            !$0.id.isEmpty && $0.id == preferred.id && $0.transactionHash != nil
        }?.transactionHash
        for index in indices where index != preferredIndex {
            let discarded = transactions[index]
            if discarded.id != preferred.id || discarded.transactionHash != preferred.transactionHash {
                log?("event=wallet_transaction_duplicate source=\(source) lt=\(preferred.logicalTime) discarded_id=\(discarded.id) discarded_hash=\(discarded.transactionHash ?? "nil") retained_id=\(preferred.id) retained_hash=\(preferred.transactionHash ?? fallbackHash ?? "nil")")
            }
        }
        return walletTransactionWithPresentationId(
            preferred,
            presentationId: preservePresentationId ? current.presentationId : preferred.presentationId,
            fallbackTransactionHash: fallbackHash
        )
    }
    return sortedWalletTransactions(values)
}

@available(macOS 10.15, *)
func walletPendingTransferTransaction(
    _ pending: WalletContext.PendingTransfer
) -> WalletContext.Transaction? {
    guard pending.collectibleAddress == nil, pending.amount > 0 else {
        return nil
    }
    let status: WalletContext.Transaction.Status
    switch pending.status {
    case .broadcasting, .pending, .submissionUnknown:
        status = .pending
    case .confirmed:
        status = .completed
    }
    return WalletContext.Transaction(
        id: "pending:\(pending.id)",
        presentationId: "pending:\(pending.id)",
        transactionHash: pending.transactionHash,
        logicalTime: pending.transactionLt ?? "0",
        timestamp: pending.createdAt,
        direction: .outgoing,
        amount: -pending.amount,
        fee: pending.fee ?? 0,
        gasless: pending.gasless,
        peer: .address(pending.recipient, domain: nil),
        comment: pending.comment,
        commentEncrypted: pending.commentEncrypted,
        status: status
    )
}

@available(macOS 10.15, *)
func transactionsWithStreamingOverlay(
    authoritative: [WalletContext.Transaction],
    streaming: [WalletContext.Transaction],
    peerByAddress: [String: EnginePeer],
    log: ((String) -> Void)? = nil
) -> [WalletContext.Transaction] {
    return mergeTransactions(existing: [], new: authoritative + streaming, source: "presentation", log: log).map { transaction in
        transactionWithResolvedPeer(
            transaction,
            peerByAddress: peerByAddress
        )
    }
}

@available(macOS 10.15, *)
func walletAddressMappingKey(_ address: String) -> String? {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let info = try? parseTonAddress(value: trimmed) else {
        return nil
    }
    if case let .userFriendly(_, testnet) = info.format, testnet {
        return nil
    }
    return try? convertTonAddress(value: trimmed, format: .raw).lowercased()
}

@available(macOS 10.15, *)
private func transactionWithResolvedPeer(
    _ transaction: WalletContext.Transaction,
    peerByAddress: [String: EnginePeer]
) -> WalletContext.Transaction {
    guard case let .address(address, domain) = transaction.peer,
          let key = walletAddressMappingKey(address),
          let peer = peerByAddress[key] else {
        return transaction
    }
    return WalletContext.Transaction(
        id: transaction.id,
        presentationId: transaction.presentationId,
        transactionHash: transaction.transactionHash,
        logicalTime: transaction.logicalTime,
        timestamp: transaction.timestamp,
        direction: transaction.direction,
        amount: transaction.amount,
        fee: transaction.fee,
        gasless: transaction.gasless,
        peer: .user(peer, address: address, domain: domain),
        comment: transaction.comment,
        commentEncrypted: transaction.commentEncrypted,
        currency: transaction.currency,
        collectible: transaction.collectible,
        status: transaction.status,
        kind: transaction.kind
    )
}

@available(macOS 10.15, *)
func walletTransactionWithPresentationId(
    _ transaction: WalletContext.Transaction,
    presentationId: String,
    fallbackTransactionHash: String? = nil
) -> WalletContext.Transaction {
    let transactionHash = transaction.transactionHash ?? fallbackTransactionHash
    guard transaction.presentationId != presentationId || transaction.transactionHash != transactionHash else {
        return transaction
    }
    return WalletContext.Transaction(
        id: transaction.id,
        presentationId: presentationId,
        transactionHash: transactionHash,
        logicalTime: transaction.logicalTime,
        timestamp: transaction.timestamp,
        direction: transaction.direction,
        amount: transaction.amount,
        fee: transaction.fee,
        gasless: transaction.gasless,
        peer: transaction.peer,
        comment: transaction.comment,
        commentEncrypted: transaction.commentEncrypted,
        currency: transaction.currency,
        collectible: transaction.collectible,
        status: transaction.status,
        kind: transaction.kind
    )
}

@available(macOS 10.15, *)
private struct WalletIncomingTransactionIdentity: Hashable {
    let logicalTime: UInt64
    let timestamp: Int32
    let amount: Int64
    let address: String
}

@available(macOS 10.15, *)
private func walletIncomingTransactionIdentity(_ transaction: WalletContext.Transaction) -> WalletIncomingTransactionIdentity? {
    guard transaction.status == .completed, transaction.kind == .transfer,
          transaction.direction == .incoming, transaction.currency == .ton,
          transaction.collectible == nil, transaction.amount > 0,
          transaction.logicalTime.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
          let logicalTime = UInt64(transaction.logicalTime), logicalTime != 0,
          let peerAddress = transaction.peer.address,
          let address = walletAddressMappingKey(peerAddress) else {
        return nil
    }
    return WalletIncomingTransactionIdentity(
        logicalTime: logicalTime, timestamp: transaction.timestamp,
        amount: transaction.amount, address: address
    )
}

@available(macOS 10.15, *)
private enum WalletTransactionIdentity: Hashable {
    case id(String)
    case hash(String)
    case outgoingOperation(id: String, recipient: String)
    case incoming(WalletIncomingTransactionIdentity)
}

@available(macOS 10.15, *)
private func walletTransactionIdentities(_ transaction: WalletContext.Transaction) -> [WalletTransactionIdentity] {
    var result: [WalletTransactionIdentity] = []
    if !transaction.id.isEmpty { result.append(.id(transaction.id)) }
    if let hash = transaction.transactionHash, !hash.isEmpty { result.append(.hash(hash)) }
    if transaction.direction == .outgoing, transaction.kind == .transfer,
       transaction.currency == .ton, transaction.collectible == nil,
       transaction.presentationId.hasPrefix("pending:"),
       transaction.presentationId.count > "pending:".count,
       let address = transaction.peer.address, let recipient = walletAddressMappingKey(address) {
        result.append(.outgoingOperation(id: transaction.presentationId, recipient: recipient))
    }
    if let incoming = walletIncomingTransactionIdentity(transaction) { result.append(.incoming(incoming)) }
    return result
}

@available(macOS 10.15, *)
struct WalletTransactionIdentityIndex {
    private var indicesByIdentity: [WalletTransactionIdentity: Int] = [:]
    private(set) var groups: [[Int]] = []

    init(_ transactions: [WalletContext.Transaction]) {
        var roots = Array(transactions.indices)
        func root(_ index: Int) -> Int {
            var index = index
            while roots[index] != index {
                roots[index] = roots[roots[index]]
                index = roots[index]
            }
            return index
        }
        for (index, transaction) in transactions.enumerated() {
            for identity in walletTransactionIdentities(transaction) {
                if let previous = self.indicesByIdentity[identity] {
                    let currentRoot = root(index)
                    let previousRoot = root(previous)
                    roots[max(currentRoot, previousRoot)] = min(currentRoot, previousRoot)
                } else {
                    self.indicesByIdentity[identity] = index
                }
            }
        }
        var groupByRoot: [Int: Int] = [:]
        for index in transactions.indices {
            let rootIndex = root(index)
            if let group = groupByRoot[rootIndex] {
                self.groups[group].append(index)
            } else {
                groupByRoot[rootIndex] = self.groups.count
                self.groups.append([index])
            }
        }
    }

    func contains(_ transaction: WalletContext.Transaction) -> Bool {
        walletTransactionIdentities(transaction).contains { self.indicesByIdentity[$0] != nil }
    }
}

@available(macOS 10.15, *)
public extension WalletContext.Transaction {
    func matchesHistoryTransaction(_ other: WalletContext.Transaction) -> Bool {
        WalletTransactionIdentityIndex([self]).contains(other)
    }
}

@available(macOS 10.15, *)
private func sortedWalletTransactions(
    _ transactions: [WalletContext.Transaction]
) -> [WalletContext.Transaction] {
    transactions.sorted(by: walletTransactionIsNewer)
}

@available(macOS 10.15, *)
private func walletTransactionIsNewer(_ lhs: WalletContext.Transaction, _ rhs: WalletContext.Transaction) -> Bool {
    if lhs.timestamp != rhs.timestamp {
        return lhs.timestamp > rhs.timestamp
    }
    return decimalStringIsGreater(lhs.logicalTime, rhs.logicalTime)
}

@available(macOS 10.15, *)
private func decimalStringIsGreater(_ lhs: String, _ rhs: String) -> Bool {
    let left = normalizedUnsignedDecimal(lhs)
    let right = normalizedUnsignedDecimal(rhs)
    guard let left, let right else {
        return lhs > rhs
    }
    if left.count != right.count {
        return left.count > right.count
    }
    return left > right
}

@available(macOS 10.15, *)
private func normalizedUnsignedDecimal(_ value: String) -> String? {
    guard !value.isEmpty, value.allSatisfy(\.isNumber) else {
        return nil
    }
    let trimmed = value.drop(while: { $0 == "0" })
    return trimmed.isEmpty ? "0" : String(trimmed)
}

@available(macOS 10.15, *)
struct WalletTransactionHistory {
    struct Page {
        let items: [WalletContext.Transaction]
        let nextOffset: String?
    }

    struct PageRequest: Hashable {
        let offset: String
        fileprivate let generation: UInt64
        fileprivate let routeRevision: UInt64
    }

    private var hasLoadedFirstPage = false
    private var nextOffset: String?
    private var generation: UInt64 = 0
    private var routeRevision: UInt64 = 0

    var nextPageRequest: PageRequest? {
        self.nextOffset.map {
            PageRequest(offset: $0, generation: self.generation, routeRevision: self.routeRevision)
        }
    }

    mutating func reset() {
        self.hasLoadedFirstPage = false
        self.nextOffset = nil
        self.generation &+= 1
    }

    mutating func applyRefresh(
        _ page: Page,
        previous: WalletContext.TransactionsState,
        retaining: [WalletContext.Transaction] = [],
        log: ((String) -> Void)? = nil
    ) -> WalletContext.TransactionsState {
        let existingIdentities = WalletTransactionIdentityIndex(previous.items)
        let hasGap = !page.items.isEmpty && !page.items.contains(where: existingIdentities.contains)
        if !self.hasLoadedFirstPage || hasGap {
            self.nextOffset = page.nextOffset
            self.routeRevision &+= 1
        }
        self.hasLoadedFirstPage = true
        var existing = previous.items
        let orderedPage = sortedWalletTransactions(page.items)
        if let newest = orderedPage.first, let oldest = orderedPage.last {
            let pageIdentities = WalletTransactionIdentityIndex(page.items)
            let retainedIdentities = WalletTransactionIdentityIndex(retaining)
            existing.removeAll { transaction in
                let keep = pageIdentities.contains(transaction)
                    || retainedIdentities.contains(transaction)
                    || transaction.status == .pending
                    || walletTransactionIsNewer(transaction, newest)
                    || (page.nextOffset != nil && walletTransactionIsNewer(oldest, transaction))
                if !keep {
                    log?("event=wallet_history_cache_replaced id=\(transaction.id) hash=\(transaction.transactionHash ?? "nil")")
                }
                return !keep
            }
        }
        let items = mergeTransactions(existing: existing, new: page.items, source: "refresh", log: log)
        return WalletContext.TransactionsState(
            items: items,
            offset: items.count,
            canLoadMore: self.nextOffset != nil,
            isLoadingMore: previous.isLoadingMore,
            error: nil
        )
    }

    mutating func applyPage(
        _ page: Page,
        request: PageRequest,
        previous: WalletContext.TransactionsState,
        log: ((String) -> Void)? = nil
    ) -> (state: WalletContext.TransactionsState, shouldContinue: Bool) {
        guard request.generation == self.generation else { return (previous, false) }
        let identities = WalletTransactionIdentityIndex(previous.items + page.items)
        let hasNewTransactions = identities.groups.contains { $0[0] >= previous.items.count }
        let items = mergeTransactions(existing: previous.items, new: page.items, source: "page", log: log)
        if request.routeRevision == self.routeRevision && request.offset == self.nextOffset {
            self.nextOffset = page.nextOffset
        }
        let shouldContinue = !hasNewTransactions && self.nextOffset != nil
        return (
            WalletContext.TransactionsState(
                items: items,
                offset: items.count,
                canLoadMore: self.nextOffset != nil,
                isLoadingMore: shouldContinue,
                error: nil
            ),
            shouldContinue
        )
    }

    func failed(
        _ error: Error,
        previous: WalletContext.TransactionsState,
        pagination: Bool
    ) -> WalletContext.TransactionsState {
        WalletContext.TransactionsState(
            items: previous.items,
            offset: previous.offset,
            canLoadMore: previous.canLoadMore,
            isLoadingMore: pagination ? false : previous.isLoadingMore,
            error: error is CancellationError ? previous.error : synchronizationError(error)
        )
    }
}

@available(macOS 10.15, *)
func loadWalletTransactionHistoryPages(
    isolation: isolated (any Actor)? = #isolation,
    nextRequest: () throws -> WalletTransactionHistory.PageRequest?,
    fetch: (String) async throws -> WalletTransactionHistory.Page,
    apply: (WalletTransactionHistory.PageRequest, WalletTransactionHistory.Page) throws -> Bool
) async throws {
    var requestedPages = Set<WalletTransactionHistory.PageRequest>()
    while true {
        try Task.checkCancellation()
        guard let request = try nextRequest() else { return }
        guard requestedPages.insert(request).inserted else {
            throw WalletContext.SynchronizationError.invalidData
        }
        let page = try await fetch(request.offset)
        try Task.checkCancellation()
        if try !apply(request, page) { return }
    }
}
