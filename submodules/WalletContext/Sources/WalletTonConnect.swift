import Foundation
import PasscodeCore
import Postbox
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI
#if os(iOS)
import UIKit
#endif

@available(macOS 10.15, *)
struct TonConnectMessageKey: Hashable {
    let sessionId: Int64
    let msgId: Int32
}

@available(macOS 10.15, *)
final class TonConnectPendingInteraction {
    enum Source {
        case connect(TonConnectLink, TonConnectConnectRequest)
        case request(WalletTonConnectLookup, msgId: Int32?, returnTarget: TonConnectReturnTarget)
    }
    enum Publication {
        case connect(answer: Data, body: Data, isError: Bool, traceId: String?)
        case response(msgId: Int32, body: Data, traceId: String?)
    }
    let id: String
    let source: Source
    var returnTarget: TonConnectReturnTarget
    let valid = Atomic(value: true)
    var session: WalletTonConnectSession?
    var wallet: TonConnectWalletIdentity?
    var envelope: WalletTonConnectRequest?
    var journal: WalletStoredTonConnectRequest?
    var request: TonConnectWireRequest?
    var validationError: TonConnectWireFailure?
    var authorization: PasscodeSession?
    var content: WalletContext.TonConnectActiveRequest.Content?
    var status: TonConnectRequestStatus = .ready
    var lifecycle = TonConnectRequestLifecycle()
    var publication: Publication?
    var connectEventId: Int64?
    var wantsRejection = false
    var approved = false
    var failure: TonConnectFailure?
    var preparationFailed = false
    var preparationIsUserInitiated: Bool
    var expiryTask: Task<Void, Never>?

    init(_ source: Source, userInitiated: Bool, journal: WalletStoredTonConnectRequest? = nil) {
        self.id = journal?.operationId ?? UUID().uuidString
        self.journal = journal
        if let journal, journal.phase != .received {
            _ = self.lifecycle.beginClaim()
            if journal.phase != .claiming { _ = self.lifecycle.claimSucceeded() }
            if journal.phase == .executing { _ = self.lifecycle.beginExecution() }
            if journal.phase == .prepared || journal.phase == .closing { self.lifecycle.prepared() }
        }
        self.source = source
        self.preparationIsUserInitiated = userInitiated
        switch source {
        case let .connect(link, _): self.returnTarget = link.returnTarget
        case let .request(_, _, target): self.returnTarget = target
        }
    }
    var messageKey: TonConnectMessageKey? {
        if let envelope { return TonConnectMessageKey(sessionId: envelope.sessionId, msgId: envelope.msgId) }
        if let journal { return journal.key }
        if case let .request(.sessionId(sessionId), .some(msgId), _) = self.source {
            return TonConnectMessageKey(sessionId: sessionId, msgId: msgId)
        }
        return nil
    }
}

@available(macOS 10.15, *)
struct TonConnectRequestLifecycle {
    enum Phase { case pending, claiming, claimed, executing, prepared, completed, stopped }
    private(set) var phase: Phase = .pending
    mutating func beginClaim() -> Bool {
        guard self.phase == .pending || self.phase == .claiming || self.phase == .claimed else { return false }
        self.phase = .claiming
        return true
    }
    mutating func claimSucceeded() -> Bool {
        guard self.phase == .claiming else { return false }
        self.phase = .claimed
        return true
    }
    mutating func beginExecution() -> Bool {
        guard self.phase == .claimed else { return false }
        self.phase = .executing
        return true
    }
    mutating func prepared() { self.phase = .prepared }
    mutating func completed() { self.phase = .completed }
    mutating func stop() { self.phase = .stopped }
    var ownsClaimAttempt: Bool {
        switch self.phase {
        case .claiming, .claimed, .executing, .prepared: return true
        default: return false
        }
    }
}

@available(macOS 10.15, *)
public extension WalletContext {
    var tonConnectState: Signal<TonConnectState, NoError> {
        self.output.tonConnectStatePromise.get() |> deliverOnMainQueue
    }

    static func isTonConnectUrl(_ value: String) -> Bool { TonConnectLink.matches(value) }

    func processTonConnectUrl(_ value: String) {
        Task { await self.impl.openTonConnectUrl(value) }
    }

    func openTonConnectRequest(sessionId: Int64, messageId: MessageId) {
        guard messageId.namespace == Namespaces.Message.Cloud,
              messageId.peerId == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000)) else { return }
        Task { await self.impl.enqueueTonConnectRequest(sessionId: sessionId, msgId: messageId.id, userInitiated: true) }
    }

    func decideTonConnectRequest(id: String, approve: Bool) -> Signal<TonConnectDecisionResult, WalletError> {
        self.signal(name: "ton_connect_decide", cancelOnDispose: false) { impl, operationId in
            try await impl.decideTonConnectRequest(id: id, approve: approve, operationId: operationId, showErrors: true)
        }
    }

    func rejectTonConnectRequest(id: String) {
        Task { await self.impl.rejectTonConnectRequest(id: id) }
    }

    func retryTonConnectRequest(id: String) {
        Task { await self.impl.retryTonConnectPreparation(id: id) }
    }

    func closeTonConnectPresentation(id: String) {
        Task { await self.impl.closeTonConnectPresentation(id: id) }
    }

    func refreshTonConnectSessions() {
        Task { await self.impl.updateTonConnectEnvironment(refresh: true) }
    }

    func disconnectTonConnectSession(id: Int64) -> Signal<Void, NoError> {
        self.disconnectTonConnectSessions(ids: [id])
    }

    func disconnectAllTonConnectSessions() -> Signal<Void, NoError> {
        self.disconnectTonConnectSessions(ids: nil)
    }

    private func disconnectTonConnectSessions(ids: [Int64]?) -> Signal<Void, NoError> {
        self.signal(name: "ton_connect_disconnect", cancelOnDispose: false) { impl, operationId in
            await impl.disconnectTonConnectSessions(ids: ids, operationId: operationId)
        } |> `catch` { _ in .single(()) }
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    private func logTonConnect(_ stage: String, _ active: TonConnectPendingInteraction, walletClientId: String? = nil, body: Data? = nil, outcome: String? = nil, error: Error? = nil) {
        let traceId: String?
        switch active.source {
        case let .connect(link, _): traceId = link.traceId
        case .request: traceId = active.envelope?.traceId
        }
        self.logger.tonConnect(stage, requestId: active.id, session: active.session, traceId: traceId,
            eventId: active.connectEventId, walletClientId: walletClientId, body: body, outcome: outcome, error: error)
    }

    private func persistTonConnectJournal() async throws {
        guard self.isStoredStateRestored, !self.isShutdown else { throw WalletError.unavailable }
        self.storedStateMutationRevision &+= 1
        guard await self.storedStateWriter.storeAndWait(self.storedState, revision: self.storedStateMutationRevision),
              !self.isShutdown else { throw WalletError.unavailable }
    }

    private func storeTonConnect(_ active: TonConnectPendingInteraction, phase: WalletStoredTonConnectRequest.Phase, approved: Bool? = nil, response: Data? = nil) async throws {
        try self.checkTonConnect(active)
        guard var record = active.journal else { throw WalletError.unavailable }
        record.phase = phase
        record.returnTarget = active.returnTarget
        if let approved { record.approved = approved }
        if let response { record.response = response }
        active.journal = record
        self.storedState.tonConnectRequests.removeAll { $0.key == record.key }
        self.storedState.tonConnectRequests.append(record)
        try await self.persistTonConnectJournal()
        try self.checkTonConnect(active)
    }

    private func removeTonConnectJournal(_ key: TonConnectMessageKey) {
        guard self.storedState.tonConnectRequests.contains(where: { $0.key == key }) else { return }
        self.storedState.tonConnectRequests.removeAll { $0.key == key }
        self.storedStateMutationRevision &+= 1
        let state = self.storedState
        let revision = self.storedStateMutationRevision
        Task { await self.storedStateWriter.enqueue(state, revision: revision) }
    }

    private func validateTonConnectBinding(_ record: WalletStoredTonConnectRequest, wallet: TonConnectWalletIdentity) async throws {
        let authorizationId = try await WalletSignalRequestContext<Int64>().run(
            self.engine.account.network.getAuthKeyId() |> castError(WalletError.self)
        )
        guard authorizationId != 0 else { throw WalletError.unavailable }
        guard record.authorizationId == authorizationId,
              record.accountId == self.engine.account.peerId.toInt64(), record.wallet == wallet else { throw TonConnectFailure.keyMismatch }
    }

    private func restoreTonConnectRequests() async throws {
        guard self.isStoredStateRestored, case let .wallet(info) = self.currentState.phase, info.canSign else { return }
        let epoch = self.tonConnectEpoch
        let wallet = try await self.runtime.tonConnectIdentity()
        for record in self.storedState.tonConnectRequests {
            if record.expires <= self.tonConnectNow && !record.isFinishingDisconnect {
                self.removeTonConnectJournal(record.key)
                continue
            }
            do { try await self.validateTonConnectBinding(record, wallet: wallet) }
            catch let failure as TonConnectFailure where failure == .keyMismatch {
                self.removeTonConnectJournal(record.key)
                continue
            }
            guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
            if record.phase != .executing {
                self.enqueueTonConnectRequest(sessionId: record.key.sessionId, msgId: record.key.msgId, userInitiated: false)
            }
        }
    }

    func resetTonConnect() {
        self.tonConnectEpoch &+= 1
        self.tonConnectPreparationTask?.cancel()
        self.tonConnectRefreshTask?.cancel()
        self.tonConnectPreparationTask = nil
        self.tonConnectRefreshTask = nil
        if let active = self.tonConnectActive {
            _ = active.valid.swap(false)
            active.expiryTask?.cancel()
            self.authorization.finish(active.authorization)
        }
        self.tonConnectActive = nil
        self.tonConnectQueue.removeAll()
        self.tonConnectHandledRequests.removeAll()
        self.tonConnectProvenSessions.removeAll()
        self.tonConnectDisconnectBodies.removeAll()
        self.tonConnectPendingDisconnects.removeAll()
        self.tonConnectSessionErrors.removeAll()
        self.tonConnectSessions.removeAll()
        self.tonConnectSessionRevisions.removeAll()
        self.tonConnectRevision &+= 1
        self.tonConnectDiagnostic = nil
        self.publishTonConnectState()
    }

    func updateTonConnectWallet() {
        guard case let .wallet(info) = self.currentState.phase else {
            if case .empty = self.currentState.phase {
                self.resetTonConnect()
                self.tonConnectWalletIdentity = nil
            }
            return
        }
        let identity = info.address + ":" + info.publicKey
        if let previous = self.tonConnectWalletIdentity, previous != identity { self.resetTonConnect() }
        let changed = self.tonConnectWalletIdentity != identity
        self.tonConnectWalletIdentity = identity
        self.updateTonConnectEnvironment(refresh: changed)
    }

    var tonConnectNow: Int32 { Int32(clamping: Int64(self.engine.account.network.globalTime)) }
    var canPresentTonConnect: Bool {
        self.isApplicationInForeground && self.isAccountCurrent && self.authorization.isAvailable && !self.isShutdown
    }

    func publishTonConnectState() {
        let sessions = self.tonConnectSessions.values.filter { !$0.isClosed }.sorted { $0.date > $1.date }.map { session in
            let isDisconnecting = session.isClosing || self.tonConnectDisconnectBodies[session.id] != nil
                || self.storedState.tonConnectRequests.contains(where: { $0.session.id == session.id && $0.isFinishingDisconnect })
            return TonConnectSessionInfo(id: session.id, manifest: session.manifest.map(TonConnectManifestInfo.init),
                status: isDisconnecting ? .disconnecting : session.isPending ? .connecting : .connected,
                error: self.tonConnectSessionErrors[session.id])
        }
        let active = self.tonConnectActive.flatMap { interaction -> WalletContext.TonConnectActiveRequest? in
            guard let content = interaction.content else { return nil }
            return WalletContext.TonConnectActiveRequest(content: content, status: interaction.status)
        }
        self.output.tonConnectStatePromise.set(WalletContext.TonConnectState(sessions: sessions, active: active,
            presentationEnabled: self.canPresentTonConnect, diagnostic: self.tonConnectDiagnostic))
    }

    private func isSilentTonConnectError(_ error: Error) -> Bool {
        error is CancellationError || walletError(error) == .authorizationCancelled
            || (error as? TonConnectFailure) == .handledElsewhere || (error as? TonConnectFailure) == .expired
    }

    private func presentTonConnectError(_ error: Error, requestId: String? = nil) {
        guard !self.isSilentTonConnectError(error) else { return }
        let failure: TonConnectFailure
        if let value = error as? TonConnectFailure { failure = value }
        else { failure = .unavailable }
        self.tonConnectDiagnostic = TonConnectDiagnostic(id: UUID(), failure: failure, requestId: requestId)
        self.publishTonConnectState()
    }

    func updateTonConnectEnvironment(refresh: Bool) {
        let becameAvailable = self.canPresentTonConnect && !self.tonConnectWasAvailable
        self.tonConnectWasAvailable = self.canPresentTonConnect
        self.publishTonConnectState()
        guard self.canPresentTonConnect else {
            self.tonConnectPreparationTask?.cancel()
            if let active = self.tonConnectActive, !active.lifecycle.ownsClaimAttempt {
                self.authorization.finish(active.authorization)
                active.authorization = nil
            }
            return
        }
        if refresh || becameAvailable, self.isNetworkAvailable, self.tonConnectRefreshTask == nil {
            self.tonConnectRefreshTask = Task { [weak self] in
                guard let self else { return }
                await self.refreshTonConnectFromServer()
            }
        }
        self.advanceTonConnectQueue()
    }

    func refreshTonConnectFromServer() async {
        guard !Task.isCancelled else { return }
        let revision = self.tonConnectRevision
        let epoch = self.tonConnectEpoch
        defer { if epoch == self.tonConnectEpoch { self.tonConnectRefreshTask = nil } }
        do {
            try await self.restoreTonConnectRequests()
            let sessions = try await WalletSignalRequestContext<[WalletTonConnectSession]>().run(self.engine.wallet.tonConnectGetSessions())
            guard !self.isShutdown, epoch == self.tonConnectEpoch else { return }
            let ids = Set(sessions.map(\.id))
            for id in Array(self.tonConnectSessions.keys) where !ids.contains(id) && (self.tonConnectSessionRevisions[id] ?? 0) <= revision {
                self.removeTonConnectSession(id)
                if let active = self.tonConnectActive, active.session?.id == id, active.session?.isActive == true,
                   active.lifecycle.phase != .completed, active.journal?.isFinishingDisconnect != true {
                    self.invalidateTonConnect(active, failure: .unavailable)
                }
            }
            for session in sessions { self.mergeTonConnectSession(session, fetchedAt: revision) }
            await self.refreshTonConnectPending(sessionIds: ids.union(self.storedState.tonConnectRequests.map { $0.session.id }), epoch: epoch)
            guard !Task.isCancelled, !self.isShutdown, epoch == self.tonConnectEpoch else { return }
            self.publishTonConnectState()
            if let active = self.tonConnectActive, active.publication != nil || active.journal?.phase == .closing, active.status == .ready {
                if (try? await self.decideTonConnectRequest(id: active.id, approve: active.approved, operationId: UUID(), showErrors: false)) != nil, active.content == nil || active.wantsRejection {
                    self.finishTonConnect(active)
                }
            }
            await self.finishPendingTonConnectDisconnects()
            self.advanceTonConnectQueue()
        } catch { self.logger.error("ton_connect_refresh_failed", error) }
    }

    private func refreshTonConnectPending(sessionIds: Set<Int64>, epoch: UInt64) async {
        for id in sessionIds.sorted() {
            guard !Task.isCancelled, !self.isShutdown, epoch == self.tonConnectEpoch else { return }
            let revision = self.tonConnectRevision
            do {
                let pending = try await WalletSignalRequestContext<WalletTonConnectPending>().run(self.engine.wallet.tonConnectGetPending(lookup: .sessionId(id)))
                guard !Task.isCancelled, !self.isShutdown, epoch == self.tonConnectEpoch else { return }
                self.mergeTonConnectSession(pending.session, fetchedAt: revision)
                guard let session = self.tonConnectSessions[id], !session.isClosed, !session.isClosing,
                      session.dappClientId == pending.session.dappClientId, session.clientId == pending.session.clientId,
                      session.nonce == pending.session.nonce else { continue }
                for request in pending.requests where request.sessionId == id && request.expires > self.tonConnectNow {
                    let key = TonConnectMessageKey(sessionId: id, msgId: request.msgId)
                    if let record = self.storedState.tonConnectRequests.first(where: { $0.key == key }) {
                        guard record.phase != .executing, record.envelope.body == request.body else { continue }
                    }
                    self.enqueueTonConnectRequest(sessionId: id, msgId: request.msgId, userInitiated: false)
                }
            } catch { self.logger.error("ton_connect_pending_refresh_failed", error) }
        }
    }

    func mergeTonConnectSession(_ session: WalletTonConnectSession, fetchedAt revision: UInt64? = nil) {
        if let revision, (self.tonConnectSessionRevisions[session.id] ?? 0) > revision { return }
        self.tonConnectSessions[session.id] = session
        self.tonConnectRevision &+= 1
        self.tonConnectSessionRevisions[session.id] = self.tonConnectRevision
        if session.isClosed { self.tonConnectPendingDisconnects.remove(session.id) }
        if let active = self.tonConnectActive, active.session?.id == session.id {
            let previousKey = active.session?.clientId
            let previousManifest = active.session?.manifest
            active.session = session
            self.logTonConnect("session_update", active, outcome: session.isActive ? "active" : session.isClosed ? "closed" : session.isClosing ? "closing" : "pending")
            if session.isClosed, active.journal?.isFinishingDisconnect == true { return }
            if case .connect = active.source, active.content != nil, previousManifest != session.manifest {
                self.invalidateTonConnect(active, failure: .invalidManifest)
            } else if let previousKey, session.clientId != previousKey {
                self.invalidateTonConnect(active, failure: .keyMismatch)
            } else if (session.isClosed || session.isClosing) && active.journal?.isFinishingDisconnect != true {
                self.invalidateTonConnect(active, failure: .unavailable)
            } else if session.isActive, case .connect = active.source,
                      active.lifecycle.phase == .pending, active.publication == nil {
                self.invalidateTonConnect(active, failure: .handledElsewhere)
            }
        }
    }

    func removeTonConnectSession(_ id: Int64) {
        self.tonConnectSessions[id] = nil
        self.tonConnectRevision &+= 1
        self.tonConnectSessionRevisions[id] = self.tonConnectRevision
    }

    func receiveTonConnectUpdates(_ updates: [WalletTonConnectEvent]) {
        guard !self.isShutdown else { return }
        for update in updates {
            switch update {
            case let .session(session):
                self.mergeTonConnectSession(session)
            case let .request(message):
                let key = TonConnectMessageKey(sessionId: message.sessionId, msgId: message.msgId)
                if message.isAccepted || message.isDeclined {
                    if self.storedState.tonConnectRequests.contains(where: { $0.key == key && $0.phase != .received }) {
                        self.enqueueTonConnectRequest(sessionId: message.sessionId, msgId: message.msgId, userInitiated: false)
                        continue
                    }
                    self.tonConnectHandledRequests.insert(key)
                    self.removeTonConnectJournal(key)
                    self.tonConnectQueue.removeAll { $0.messageKey == key }
                    if let active = self.tonConnectActive, active.messageKey == key, !active.lifecycle.ownsClaimAttempt, active.lifecycle.phase != .completed {
                        self.invalidateTonConnect(active, failure: .handledElsewhere)
                    }
                } else if message.expires > self.tonConnectNow {
                    self.enqueueTonConnectRequest(sessionId: message.sessionId, msgId: message.msgId, userInitiated: false)
                }
            case let .pendingDisconnect(sessionIds):
                self.tonConnectPendingDisconnects.formUnion(sessionIds)
            }
        }
        self.updateTonConnectEnvironment(refresh: !self.tonConnectPendingDisconnects.isEmpty)
    }

    func openTonConnectUrl(_ value: String) {
        do {
            if case .empty = self.currentState.phase { throw TonConnectFailure.unavailable }
            if case let .wallet(info) = self.currentState.phase, !info.canSign { throw TonConnectFailure.unavailable }
            let link = try TonConnectLink(value)
            if let raw = link.request {
                let request = try TonConnectConnectRequest(Data(raw.utf8))
                let existing = ([self.tonConnectActive].compactMap { $0 } + self.tonConnectQueue).first {
                    if case let .connect(other, _) = $0.source { return other.peerId == link.peerId }
                    return false
                }
                if let existing {
                    if case let .connect(other, _) = existing.source, other != link { throw TonConnectFailure.conflictingLink }
                    existing.preparationIsUserInitiated = true
                    return
                }
                self.tonConnectQueue.append(TonConnectPendingInteraction(.connect(link, request), userInitiated: true))
            } else {
                if let existing = ([self.tonConnectActive].compactMap { $0 } + self.tonConnectQueue).first(where: {
                    if $0.session?.dappClientId == link.peerId { return true }
                    if case let .request(.dappClientId(peerId), _, _) = $0.source { return peerId == link.peerId }
                    return false
                }) {
                    existing.preparationIsUserInitiated = true
                    existing.returnTarget = link.returnTarget
                    return
                }
                if let record = self.storedState.tonConnectRequests.first(where: { $0.session.dappClientId == link.peerId && $0.envelope.expires > self.tonConnectNow }) {
                    self.enqueueTonConnectRequest(sessionId: record.key.sessionId, msgId: record.key.msgId, userInitiated: true)
                    let restored = ([self.tonConnectActive].compactMap { $0 } + self.tonConnectQueue).first { $0.messageKey == record.key }
                    restored?.returnTarget = link.returnTarget
                } else {
                    self.tonConnectQueue.append(TonConnectPendingInteraction(.request(.dappClientId(link.peerId), msgId: nil, returnTarget: link.returnTarget), userInitiated: true))
                }
            }
            self.advanceTonConnectQueue()
        } catch {
            self.logger.error("ton_connect_link_failed", error)
            self.presentTonConnectError(error)
        }
    }

    func enqueueTonConnectRequest(sessionId: Int64, msgId: Int32, userInitiated: Bool) {
        let key = TonConnectMessageKey(sessionId: sessionId, msgId: msgId)
        guard !self.tonConnectHandledRequests.contains(key) || self.storedState.tonConnectRequests.contains(where: { $0.key == key }) else { return }
        if let existing = ([self.tonConnectActive].compactMap { $0 } + self.tonConnectQueue).first(where: { $0.messageKey == key }) {
            if userInitiated { existing.preparationIsUserInitiated = true }
            return
        }
        let record = self.storedState.tonConnectRequests.first { $0.key == key }
        guard record?.phase != .executing else { return }
        let interaction = TonConnectPendingInteraction(.request(.sessionId(sessionId), msgId: msgId, returnTarget: record?.returnTarget ?? .none), userInitiated: userInitiated, journal: record)
        self.tonConnectQueue.append(interaction)
        self.advanceTonConnectQueue()
    }

    func advanceTonConnectQueue() {
        guard self.isStoredStateRestored, self.canPresentTonConnect, self.isNetworkAvailable, self.currentState.activeOperation == nil,
              case let .wallet(info) = self.currentState.phase, info.canSign,
              self.tonConnectPreparationTask == nil else { return }
        if self.tonConnectActive == nil, !self.tonConnectQueue.isEmpty {
            self.tonConnectActive = self.tonConnectQueue.removeFirst()
        }
        if let active = self.tonConnectActive, active.wallet == nil, active.journal == nil, active.valid.with({ $0 }),
           case let .request(lookup, msgId, _) = active.source,
           let record = self.storedState.tonConnectRequests.first(where: { record in
               switch lookup {
               case let .sessionId(id): return record.session.id == id && (msgId == nil || record.envelope.msgId == msgId)
               case let .dappClientId(id): return record.session.dappClientId == id
               }
           }) {
            self.tonConnectActive = TonConnectPendingInteraction(active.source, userInitiated: active.preparationIsUserInitiated, journal: record)
            self.tonConnectActive?.returnTarget = active.returnTarget
        }
        guard let active = self.tonConnectActive, active.wallet == nil, !active.preparationFailed, active.valid.with({ $0 }) else { return }
        self.publishTonConnectState()
        self.tonConnectPreparationTask = Task { [weak self] in
            guard let self else { return }
            await self.prepareTonConnect(active)
        }
    }

    func prepareTonConnect(_ active: TonConnectPendingInteraction) async {
        guard self.tonConnectActive === active else { return }
        let epoch = self.tonConnectEpoch
        defer {
            if epoch == self.tonConnectEpoch {
                self.tonConnectPreparationTask = nil
                self.advanceTonConnectQueue()
            }
        }
        do {
            let wallet = try await self.runtime.tonConnectIdentity()
            try self.checkTonConnect(active)
            switch active.source {
            case let .connect(link, request):
                let revision = self.tonConnectRevision
                let session = try await WalletSignalRequestContext<WalletTonConnectSession>().run(
                    self.engine.wallet.tonConnectCreateSession(dappClientId: link.peerId, manifestUrl: request.prompt.manifestUrl))
                self.mergeTonConnectSession(session, fetchedAt: revision)
                active.session = self.tonConnectSessions[session.id] ?? session
                self.logTonConnect("session_created", active)
                try self.checkTonConnect(active)
                if active.session?.isActive == true { throw TonConnectFailure.handledElsewhere }
                let deadline = Date().addingTimeInterval(30)
                let reconcile = Task { [weak self] in await self?.reconcileTonConnectSession(session.id) }
                defer { reconcile.cancel() }
                while active.session?.manifest == nil && active.session?.manifestError == nil && !active.wantsRejection {
                    try self.checkTonConnect(active)
                    guard Date() < deadline else { throw TonConnectFailure.invalidManifest }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                try self.checkTonConnect(active)
                guard let current = active.session else { throw TonConnectFailure.unavailable }
                _ = try self.checkTonConnectConnection(active, matching: current)
                guard current.manifestError == nil, let manifest = current.manifest else { throw TonConnectFailure.invalidManifest }
                let info = TonConnectManifestInfo(manifest)
                guard !info.domain.isEmpty else { throw TonConnectFailure.invalidManifest }
                active.wallet = wallet
                active.content = .connect(try Self.tonConnectPrompt(id: active.id, manifest: info, request: request))
                self.logTonConnect("manifest_ready", active)
            case let .request(lookup, msgId, _):
                let session: WalletTonConnectSession
                let envelope: WalletTonConnectRequest
                if let record = active.journal {
                    try await self.validateTonConnectBinding(record, wallet: wallet)
                    session = self.tonConnectSessions[record.session.id] ?? record.session
                    guard session.clientId == record.session.clientId, session.dappClientId == record.session.dappClientId,
                          session.nonce == record.session.nonce else { throw TonConnectFailure.keyMismatch }
                    envelope = record.envelope
                    active.session = session
                    active.envelope = envelope
                    active.wallet = wallet
                    try self.checkTonConnect(active)
                    if record.phase == .executing { throw TonConnectFailure.outcomeUnknown }
                    if record.phase == .closing {
                        _ = try await self.publishTonConnect(active, showErrors: false)
                        self.finishTonConnect(active)
                        return
                    }
                    if let response = record.response, record.phase == .prepared {
                        active.publication = .response(msgId: envelope.msgId, body: response, traceId: envelope.traceId)
                        active.approved = record.approved ?? false
                        active.lifecycle.prepared()
                        self.scheduleTonConnectExpiry(active)
                        _ = try await self.publishTonConnect(active, showErrors: false)
                        self.finishTonConnect(active)
                        return
                    }
                } else {
                    let revision = self.tonConnectRevision
                    let pending = try await WalletSignalRequestContext<WalletTonConnectPending>().run(self.engine.wallet.tonConnectGetPending(lookup: lookup))
                    self.mergeTonConnectSession(pending.session, fetchedAt: revision)
                    session = self.tonConnectSessions[pending.session.id] ?? pending.session
                    active.session = session
                    let requests = pending.requests.filter { $0.sessionId == session.id && $0.expires > self.tonConnectNow }
                    guard let found = requests.first(where: { msgId == nil || $0.msgId == msgId }) else {
                        self.finishTonConnect(active)
                        return
                    }
                    envelope = found
                    active.envelope = envelope
                    if msgId == nil {
                        self.tonConnectQueue.removeAll { $0.messageKey == active.messageKey }
                        for other in requests where other.msgId != envelope.msgId {
                            self.enqueueTonConnectRequest(sessionId: session.id, msgId: other.msgId, userInitiated: false)
                        }
                    }
                    guard !self.tonConnectHandledRequests.contains(active.messageKey!) else { throw TonConnectFailure.handledElsewhere }
                }
                try await self.authorizeTonConnect(active)
                do {
                    let now = UInt64(max(0, self.tonConnectNow))
                    active.request = try await self.authorization.withSession(active.authorization) {
                        try await self.runtime.decodeTonConnectRequest(envelope.body, wallet: wallet, session: session, now: now, operationId: active.id)
                    }
                } catch let error as TonConnectWireFailure {
                    guard error.requestId != nil else { throw error }
                    active.validationError = error
                }
                active.wallet = wallet
                try self.checkTonConnect(active)
                if active.journal == nil, let requestId = active.request?.id ?? active.validationError?.requestId {
                    let authorizationId = try await WalletSignalRequestContext<Int64>().run(
                        self.engine.account.network.getAuthKeyId() |> castError(WalletError.self)
                    )
                    guard authorizationId != 0 else { throw WalletError.unavailable }
                    active.journal = WalletStoredTonConnectRequest(accountId: self.engine.account.peerId.toInt64(), authorizationId: authorizationId,
                        wallet: wallet, session: session, envelope: envelope, appRequestId: requestId, operationId: active.id,
                        returnTarget: active.returnTarget, validUntil: active.request?.validUntil, approved: nil, phase: .received, response: nil)
                    try await self.storeTonConnect(active, phase: .received)
                } else if let record = active.journal {
                    guard record.appRequestId == (active.request?.id ?? active.validationError?.requestId) else { throw TonConnectFailure.unavailable }
                }
                self.scheduleTonConnectExpiry(active)
                if session.isClosed || session.isClosing || session.isPending {
                    active.validationError = TonConnectWireFailure(requestId: active.request?.id ?? active.validationError?.requestId, code: .unknownApp)
                }
                if active.validationError != nil || active.journal?.approved == false || { if case .disconnect = active.request { return true }; return false }() {
                    _ = try await self.decideTonConnectRequest(id: active.id, approve: active.journal?.approved ?? true, operationId: UUID(), showErrors: false)
                    self.finishTonConnect(active)
                    return
                }
                guard let manifest = session.manifest else { throw TonConnectFailure.invalidManifest }
                let info = TonConnectManifestInfo(manifest)
                switch active.request {
                case let .sendTransaction(_, request):
                    let preview = try await self.authorization.withSession(active.authorization) { try await self.runtime.previewTonConnect(request, wallet: wallet) }
                    active.content = .operation(Self.tonConnectOperation(id: active.id, manifest: info, preview: preview))
                case let .signData(_, payload):
                    active.content = .signData(WalletContext.TonConnectSignDataRequest(id: active.id, applicationName: info.name,
                        domain: info.domain, icon: info.icon, payload: payload.content, address: wallet.address, network: wallet.network))
                default: throw TonConnectFailure.unavailable
                }
            }
            try self.checkTonConnect(active)
            self.publishTonConnectState()
        } catch {
            self.logTonConnect("preparation_failed", active, error: error)
            guard self.tonConnectActive === active else { return }
            if active.status == .invalidated || (error as? TonConnectFailure) == .handledElsewhere || (error as? TonConnectFailure) == .expired {
                self.invalidateTonConnect(active, failure: error as? TonConnectFailure ?? .unavailable)
            } else if active.publication != nil || active.journal?.phase == .closing {
                active.status = .ready
                self.publishTonConnectState()
            } else if !self.canPresentTonConnect, active.valid.with({ $0 }) {
                active.wallet = nil
                active.preparationIsUserInitiated = false
                self.authorization.finish(active.authorization)
                active.authorization = nil
            } else if case .connect = active.source, active.preparationIsUserInitiated, !active.wantsRejection, active.valid.with({ $0 }),
                      (error as? TonConnectFailure) != .keyMismatch, !self.isSilentTonConnectError(error) {
                active.preparationFailed = true
                active.wallet = nil
                self.authorization.finish(active.authorization)
                active.authorization = nil
                active.content = nil
                self.presentTonConnectError(error, requestId: active.id)
            } else {
                if active.preparationIsUserInitiated { self.presentTonConnectError(error) }
                self.finishTonConnect(active)
            }
        }
    }

    func reconcileTonConnectSession(_ id: Int64) async {
        let revision = self.tonConnectRevision
        let epoch = self.tonConnectEpoch
        do {
            let pending = try await WalletSignalRequestContext<WalletTonConnectPending>().run(self.engine.wallet.tonConnectGetPending(lookup: .sessionId(id)))
            guard !Task.isCancelled, !self.isShutdown, epoch == self.tonConnectEpoch else { return }
            self.mergeTonConnectSession(pending.session, fetchedAt: revision)
            if self.tonConnectActive?.session?.id == id { self.tonConnectActive?.session = self.tonConnectSessions[id] }
        } catch { self.logger.error("ton_connect_reconcile_failed", error) }
    }

    func authorizeTonConnect(_ active: TonConnectPendingInteraction) async throws {
        if let session = active.authorization, (try? self.authorization.validate(session)) != nil { return }
        self.authorization.finish(active.authorization)
        let session = try await self.authorization.beginSession(id: UUID(), reason: "TON Connect", lifetime: .ownerManaged)
        guard self.tonConnectActive === active, active.status != .invalidated else {
            self.authorization.finish(session)
            throw CancellationError()
        }
        active.authorization = session
        try self.checkTonConnect(active)
    }

    func checkTonConnect(_ active: TonConnectPendingInteraction) throws {
        try Task.checkCancellation()
        guard self.tonConnectActive === active, active.status != .invalidated else { throw CancellationError() }
        guard active.valid.with({ $0 }), self.canPresentTonConnect else { throw TonConnectFailure.unavailable }
        if active.journal?.isFinishingDisconnect == true { return }
        if let envelope = active.envelope, envelope.expires <= self.tonConnectNow { throw TonConnectFailure.expired }
        if let until = active.request?.validUntil ?? active.journal?.validUntil, until <= UInt64(max(0, self.tonConnectNow)) { throw TonConnectFailure.expired }
    }

    private func checkTonConnectConnection(_ active: TonConnectPendingInteraction, matching expected: WalletTonConnectSession, clientId: String? = nil) throws -> WalletTonConnectSession {
        try self.checkTonConnect(active)
        guard let current = active.session, current.id == expected.id,
              current.dappClientId == expected.dappClientId, current.nonce == expected.nonce,
              current.manifest == expected.manifest, current.manifestError == expected.manifestError,
              !current.isClosing, !current.isClosed else { throw TonConnectFailure.unavailable }
        guard current.isPending else { throw TonConnectFailure.handledElsewhere }
        if let expectedKey = clientId ?? expected.clientId, let currentKey = current.clientId, expectedKey != currentKey {
            throw TonConnectFailure.keyMismatch
        }
        return current
    }

    func scheduleTonConnectExpiry(_ active: TonConnectPendingInteraction) {
        guard let envelope = active.envelope else { return }
        active.expiryTask?.cancel()
        if active.journal?.isFinishingDisconnect == true { return }
        let expiry = min(Int64(envelope.expires), Int64(clamping: active.request?.validUntil ?? active.journal?.validUntil ?? UInt64(Int32.max)))
        let delay = max(0, expiry - Int64(self.tonConnectNow))
        active.expiryTask = Task { [weak self, weak active] in
            guard let self, let active else { return }
            do { try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000) } catch { return }
            await self.invalidateTonConnect(active, failure: .expired)
        }
    }

    func invalidateTonConnect(_ active: TonConnectPendingInteraction, failure: TonConnectFailure) {
        guard self.tonConnectActive === active else { return }
        if failure == .expired, active.journal?.isFinishingDisconnect == true { return }
        self.logTonConnect("invalidated", active, error: failure)
        _ = active.valid.swap(false)
        if active.status != .processing || !active.lifecycle.ownsClaimAttempt { active.lifecycle.stop() }
        active.status = .invalidated
        if let key = active.messageKey {
            self.tonConnectHandledRequests.insert(key)
            if failure != .outcomeUnknown { self.removeTonConnectJournal(key) }
        }
        if self.tonConnectDiagnostic?.requestId == active.id { self.tonConnectDiagnostic = nil }
        self.publishTonConnectState()
        if active.content == nil && !active.lifecycle.ownsClaimAttempt { self.finishTonConnect(active) }
    }

    func rejectTonConnectRequest(id: String) async {
        guard let active = self.tonConnectActive, active.id == id, active.status == .ready else { return }
        if active.journal?.approved == true, active.journal?.phase != .received { self.finishTonConnect(active); return }
        active.wantsRejection = true
        if case .connect = active.source, active.publication == nil {
            guard let session = active.authorization, (try? self.authorization.validate(session)) != nil else {
                self.finishTonConnect(active)
                return
            }
        }
        guard active.wallet != nil else {
            self.retryTonConnectPreparation(id: id)
            return
        }
        do {
            _ = try await self.decideTonConnectRequest(id: id, approve: false, operationId: UUID(), showErrors: false)
            self.finishTonConnect(active)
        } catch {
            self.logTonConnect("rejection_failed", active, error: error)
            guard self.tonConnectActive === active else { return }
            if active.publication == nil { self.finishTonConnect(active) }
        }
    }

    func retryTonConnectPreparation(id: String) {
        guard let active = self.tonConnectActive, active.id == id, active.preparationFailed else { return }
        active.preparationFailed = false
        active.preparationIsUserInitiated = true
        if self.tonConnectDiagnostic?.requestId == id { self.tonConnectDiagnostic = nil }
        self.publishTonConnectState()
        self.advanceTonConnectQueue()
    }

    func closeTonConnectPresentation(id: String) {
        guard let active = self.tonConnectActive, active.id == id, active.status != .processing,
              !active.lifecycle.ownsClaimAttempt else { return }
        self.finishTonConnect(active)
    }

    func finishTonConnect(_ active: TonConnectPendingInteraction) {
        guard self.tonConnectActive === active else { return }
        active.expiryTask?.cancel()
        self.authorization.finish(active.authorization)
        active.authorization = nil
        if self.tonConnectDiagnostic?.requestId == active.id { self.tonConnectDiagnostic = nil }
        self.tonConnectActive = nil
        self.publishTonConnectState()
        self.advanceTonConnectQueue()
        if !self.tonConnectPendingDisconnects.isEmpty {
            Task { await self.finishPendingTonConnectDisconnects() }
        }
    }

    func decideTonConnectRequest(id: String, approve: Bool, operationId: UUID, showErrors: Bool) async throws -> TonConnectDecision {
        guard let active = self.tonConnectActive, active.id == id, active.status != .invalidated else { throw CancellationError() }
        guard active.status == .ready,
              let session = active.session, let wallet = active.wallet else { throw WalletError.unavailable }
        active.status = .processing
        self.publishTonConnectState()
        do {
            if active.publication != nil || active.journal?.phase == .closing { return try await self.publishTonConnect(active, showErrors: showErrors) }
            try self.checkTonConnect(active)
            if active.journal?.phase == .received {
                try await self.storeTonConnect(active, phase: .received, approved: approve)
            }
            if approve, let request = active.request, request.consumesWalletSequenceNumber {
                guard case let .wallet(info) = self.currentState.phase else { throw WalletError.unavailable }
                _ = try await self.waitForPreviousWalletTransfer(wallet: info, generation: self.activationGeneration,
                    operationId: operationId, expiresAt: Int32(clamping: request.validUntil ?? UInt64(max(0, self.tonConnectNow + 300))))
                try self.checkTonConnect(active)
            }
            if case .connect = active.source, !approve {
                guard let authorization = active.authorization else { throw WalletError.authorizationCancelled }
                try self.authorization.validate(authorization)
            } else {
                if case .connect = active.source { self.logTonConnect("authorization_started", active) }
                try await self.authorizeTonConnect(active)
                if case .connect = active.source { self.logTonConnect("authorization_succeeded", active) }
            }
            return try await self.performOperation(.tonConnect, operationId: operationId, session: active.authorization) {
                try self.checkTonConnect(active)
                if approve, active.request?.consumesWalletSequenceNumber == true {
                    try await self.runtime.ensureApiTransferAllowsSigning()
                }
                let generation = try self.authorization.operationGeneration()
                let valid = active.valid
                let authorization = self.authorization
                let network = self.engine.account.network
                let expiry = active.envelope?.expires
                let validUntil = active.request?.validUntil
                let beforeSigning: @Sendable () throws -> Void = {
                    guard valid.with({ $0 }) else { throw TonConnectFailure.unavailable }
                    try authorization.validateGeneration(generation)
                    let now = network.globalTime
                    if let expiry, Double(expiry) <= now { throw TonConnectFailure.expired }
                    if let validUntil, Double(validUntil) <= now { throw TonConnectFailure.expired }
                }
                let body: Data
                switch active.source {
                case let .connect(link, request):
                    var current = try self.checkTonConnectConnection(active, matching: session)
                    guard try await self.runtime.tonConnectIdentity() == wallet else { throw TonConnectFailure.keyMismatch }
                    current = try self.checkTonConnectConnection(active, matching: session)
                    let key = try await self.runtime.tonConnectSessionPublicKey(wallet: wallet, session: current)
                    current = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    self.logTonConnect("register_key_started", active, walletClientId: key)
                    let challenge = try await WalletSignalRequestContext<WalletTonConnectChallenge>().run(
                        self.engine.wallet.tonConnectRegisterKey(sessionId: current.id, clientId: key))
                    active.connectEventId = challenge.eventId
                    self.logTonConnect("register_key_succeeded", active, walletClientId: key)
                    current = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    let answer = try await self.runtime.openTonConnectChallenge(challenge.challenge, wallet: wallet, session: current)
                    current = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    let registered = WalletTonConnectSession(flags: current.flags | (1 << 3), id: current.id,
                        dappClientId: current.dappClientId, clientId: key, nonce: current.nonce,
                        manifest: current.manifest, manifestError: current.manifestError, date: current.date)
                    self.mergeTonConnectSession(registered)
                    active.session = registered
                    self.logTonConnect("challenge_verified", active)
                    if approve {
                        let account = try await self.runtime.tonConnectAccount(wallet: wallet)
                        _ = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                        if let network = request.prompt.requestedNetwork, network != account.network { throw TonConnectFailure.wrongNetwork }
                        let timestamp = UInt64(max(0, self.tonConnectNow))
                        let proof: TonConnectProofReply?
                        if let payload = request.prompt.proofPayload {
                            proof = try await self.runtime.signTonConnectProof(wallet: wallet, manifestUrl: request.prompt.manifestUrl, timestamp: timestamp,
                                payload: payload, beforeSigning: beforeSigning)
                        } else { proof = nil }
                        let device = await Self.tonConnectDevice()
                        try beforeSigning()
                        _ = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                        body = try await self.runtime.encryptTonConnectEvent(eventId: challenge.eventId, account: account, proof: proof,
                            device: device, wallet: wallet, session: registered)
                    } else {
                        try beforeSigning()
                        _ = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                        body = try await self.runtime.encryptTonConnectConnectError(eventId: challenge.eventId, code: .userDeclined,
                            message: TonConnectWireErrorCode.userDeclined.message, wallet: wallet, session: registered)
                    }
                    _ = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    active.publication = .connect(answer: answer, body: body, isError: !approve, traceId: link.traceId)
                    self.logTonConnect("packet_prepared", active, body: body, outcome: approve ? "connect" : "connect_error")
                case .request:
                    guard let envelope = active.envelope, let requestId = active.request?.id ?? active.validationError?.requestId else {
                        throw TonConnectFailure.unavailable
                    }
                    try await self.claimTonConnectRequest(active, session: session, wallet: wallet, approve: approve, beforeSigning: beforeSigning)
                    if !approve {
                        body = try await self.runtime.encryptTonConnectError(id: requestId, code: .userDeclined, wallet: wallet, session: session)
                    } else if let failure = active.validationError {
                        body = try await self.runtime.encryptTonConnectError(id: requestId, code: failure.code, message: failure.message, wallet: wallet, session: session)
                    } else if case .disconnect = active.request {
                        body = try await self.runtime.encryptTonConnectDisconnectSuccess(id: requestId, wallet: wallet, session: session)
                        active.journal?.closeSessionAfterResponse = true
                    } else {
                        try await self.storeTonConnect(active, phase: .executing)
                        guard active.lifecycle.beginExecution() else { throw TonConnectFailure.outcomeUnknown }
                        do {
                            try beforeSigning()
                            switch active.request {
                            case let .sendTransaction(_, request):
                                let sent = try await self.runtime.sendTonConnect(request, wallet: wallet, beforeSigning: beforeSigning)
                                guard walletEngineAcceptsSubmission(sent.phase) else { throw TonConnectFailure.outcomeUnknown }
                                self.requestSynchronization(scope: [.account, .transactions], force: true)
                                body = try await self.runtime.encryptTonConnectSendSuccess(id: requestId, signedBoc: sent.signedBoc, wallet: wallet, session: session)
                            case let .signData(_, payload):
                                guard let manifest = session.manifest, case let .signData(preview) = active.content,
                                      preview.domain == TonConnectManifestInfo(manifest).domain else { throw TonConnectFailure.invalidManifest }
                                let timestamp = UInt64(max(0, self.tonConnectNow))
                                let signedData = try await self.runtime.signTonConnectData(payload, domain: preview.domain, timestamp: timestamp, wallet: wallet, beforeSigning: beforeSigning)
                                body = try await self.runtime.encryptTonConnectSignDataSuccess(id: requestId, signedData: signedData, wallet: wallet, session: session)
                            default: throw TonConnectFailure.unavailable
                            }
                        } catch {
                            try self.checkTonConnect(active)
                            self.logger.error("ton_connect_execution_failed", error)
                            active.failure = error as? TonConnectFailure ?? .unavailable
                            body = try await self.runtime.encryptTonConnectError(id: requestId, code: .unknown, wallet: wallet, session: session)
                        }
                    }
                    active.publication = .response(msgId: envelope.msgId, body: body, traceId: envelope.traceId)
                }
                active.approved = approve && active.validationError == nil
                active.lifecycle.prepared()
                return try await self.publishTonConnect(active, showErrors: showErrors)
            }
        } catch {
            self.logTonConnect("decision_failed", active, error: error)
            guard self.tonConnectActive === active else { throw CancellationError() }
            if active.status == .invalidated {
                active.lifecycle.stop()
                self.finishTonConnect(active)
                throw CancellationError()
            }
            if let failure = error as? TonConnectFailure, failure == .handledElsewhere || failure == .expired {
                active.lifecycle.stop()
                self.invalidateTonConnect(active, failure: failure)
                throw CancellationError()
            } else if active.publication != nil || active.journal?.phase == .closing {
                active.status = .ready
            } else if active.lifecycle.phase == .claiming || active.lifecycle.phase == .claimed {
                active.status = .ready
            } else if active.lifecycle.phase != .pending {
                active.lifecycle.stop()
                self.invalidateTonConnect(active, failure: .outcomeUnknown)
                if showErrors { self.presentTonConnectError(error) }
                throw CancellationError()
            } else {
                active.status = active.valid.with({ $0 }) ? .ready : .invalidated
            }
            self.publishTonConnectState()
            throw error
        }
    }

    private func claimTonConnectRequest(_ active: TonConnectPendingInteraction, session: WalletTonConnectSession,
                                        wallet: TonConnectWalletIdentity, approve: Bool, beforeSigning: @Sendable () throws -> Void) async throws {
        guard let record = active.journal, let envelope = active.envelope,
              record.phase == .received || record.phase == .claiming || record.phase == .claimed,
              record.phase == .received || record.approved == nil || record.approved == approve else { throw TonConnectFailure.outcomeUnknown }
        try await self.validateTonConnectBinding(record, wallet: wallet)
        try await self.runtime.validateTonConnectAccess(wallet: wallet)
        if record.phase != .claimed {
            var answer: Data?
            if !session.isClosed && !session.isClosing && !self.tonConnectProvenSessions.contains(session.id) {
                let key = try await self.runtime.tonConnectSessionPublicKey(wallet: wallet, session: session)
                let challenge = try await WalletSignalRequestContext<WalletTonConnectChallenge>().run(
                    self.engine.wallet.tonConnectRegisterKey(sessionId: session.id, clientId: key))
                answer = try await self.runtime.openTonConnectChallenge(challenge.challenge, wallet: wallet, session: session)
            }
            try beforeSigning()
            try await self.storeTonConnect(active, phase: .claiming, approved: approve)
            guard active.lifecycle.beginClaim() else { throw TonConnectFailure.outcomeUnknown }
            do {
                let claimed = try await WalletSignalRequestContext<Bool>().run(self.engine.wallet.tonConnectClaimRequest(
                    sessionId: session.id, msgId: envelope.msgId, appRequestId: record.appRequestId.rawValue,
                    challengeAnswer: answer, declined: !approve || active.validationError != nil))
                guard claimed else { throw TonConnectFailure.handledElsewhere }
                guard active.lifecycle.claimSucceeded() else { throw TonConnectFailure.outcomeUnknown }
            } catch {
                if case let WalletTonConnectError.rpc(_, description) = error {
                    switch description {
                    case "TONCONNECT_REQUEST_ALREADY_CLAIMED", "TONCONNECT_REQUEST_NOT_FOUND": throw TonConnectFailure.handledElsewhere
                    case "TONCONNECT_REQUEST_EXPIRED": throw TonConnectFailure.expired
                    default: break
                    }
                }
                throw error
            }
            try await self.storeTonConnect(active, phase: .claimed)
        }
        try await self.validateTonConnectBinding(record, wallet: self.runtime.tonConnectIdentity())
        try beforeSigning()
        self.tonConnectProvenSessions.insert(session.id)
        self.tonConnectHandledRequests.insert(record.key)
        try self.checkTonConnect(active)
    }

    func publishTonConnect(_ active: TonConnectPendingInteraction, showErrors: Bool) async throws -> TonConnectDecision {
        guard !self.isShutdown, self.tonConnectActive === active, let session = active.session else { throw TonConnectFailure.unavailable }
        try self.checkTonConnect(active)
        if active.journal?.phase == .closing || (active.journal?.isFinishingDisconnect == true && session.isClosed) {
            return try await self.finishTonConnectDisconnect(active)
        }
        guard let publication = active.publication else { throw TonConnectFailure.unavailable }
        if case let .response(_, body, _) = publication {
            guard let record = active.journal else { throw WalletError.unavailable }
            try await self.validateTonConnectBinding(record, wallet: self.runtime.tonConnectIdentity())
            try await self.storeTonConnect(active, phase: .prepared, approved: active.approved, response: body)
            if active.journal?.isFinishingDisconnect == true { active.expiryTask?.cancel() }
        }
        let signal: Signal<Bool, WalletTonConnectError>
        let packet: Data
        switch publication {
        case let .connect(answer, body, isError, traceId):
            packet = body
            signal = self.engine.wallet.tonConnectSubmitConnectResult(sessionId: session.id, challengeAnswer: answer,
                body: body, isError: isError, traceId: traceId)
        case let .response(msgId, body, traceId):
            packet = body
            signal = self.engine.wallet.tonConnectSubmitResponse(sessionId: session.id, msgId: msgId, body: body, traceId: traceId)
        }
        self.logTonConnect("publish_started", active, body: packet)
        let accepted: Bool
        do {
            accepted = try await WalletSignalRequestContext<Bool>().run(signal)
        } catch {
            self.logTonConnect("publish_failed", active, body: packet, error: error)
            if case .connect = publication, case WalletTonConnectError.rpc(_, "TONCONNECT_SESSION_NOT_FOUND") = error {
                self.invalidateTonConnect(active, failure: .handledElsewhere)
                throw CancellationError()
            }
            if case .response = publication, case let WalletTonConnectError.rpc(_, description) = error {
                switch description {
                case "TONCONNECT_REQUEST_EXPIRED":
                    active.journal?.closeSessionAfterResponse = nil
                    self.invalidateTonConnect(active, failure: .expired)
                    throw CancellationError()
                case "TONCONNECT_REQUEST_NOT_FOUND", "TONCONNECT_SESSION_NOT_FOUND", "TONCONNECT_REQUEST_ALREADY_CLAIMED":
                    self.invalidateTonConnect(active, failure: .handledElsewhere)
                    throw CancellationError()
                default: break
                }
            }
            throw error
        }
        self.logTonConnect("publish_result", active, body: packet, outcome: accepted ? "server_accepted" : "server_rejected")
        guard !self.isShutdown, self.tonConnectActive === active, active.status != .invalidated else { throw CancellationError() }
        guard accepted else { throw TonConnectFailure.bridgeUnavailable }
        active.publication = nil
        if active.journal?.closeSessionAfterResponse == true {
            active.journal?.phase = .closing
            active.expiryTask?.cancel()
            return try await self.finishTonConnectDisconnect(active)
        }
        if let key = active.messageKey { self.removeTonConnectJournal(key) }
        active.lifecycle.completed()
        active.expiryTask?.cancel()
        if case let .connect(_, _, isError, _) = publication {
            if isError { self.removeTonConnectSession(session.id) }
            else {
                self.tonConnectProvenSessions.insert(session.id)
                if self.tonConnectSessions[session.id]?.isPending == true {
                    self.mergeTonConnectSession(WalletTonConnectSession(flags: session.flags & ~1,
                        id: session.id, dappClientId: session.dappClientId, clientId: session.clientId,
                        nonce: session.nonce, manifest: session.manifest, manifestError: nil, date: session.date))
                }
            }
        }
        let decision = TonConnectDecision(approved: active.approved && active.failure == nil, failure: active.failure, returnTarget: active.returnTarget)
        if showErrors, let failure = decision.failure { self.presentTonConnectError(failure) }
        active.status = .completed(decision)
        self.publishTonConnectState()
        return decision
    }

    private func finishTonConnectDisconnect(_ active: TonConnectPendingInteraction) async throws -> TonConnectDecision {
        guard let record = active.journal, record.isFinishingDisconnect else { throw TonConnectFailure.unavailable }
        try self.checkTonConnect(active)
        try await self.validateTonConnectBinding(record, wallet: self.runtime.tonConnectIdentity())
        try self.checkTonConnect(active)
        if active.session?.isClosed != true {
            try await self.storeTonConnect(active, phase: .closing)
            do {
                let accepted = try await WalletSignalRequestContext<Bool>().run(self.engine.wallet.tonConnectCloseSession(sessionId: record.session.id, body: nil))
                guard accepted else { throw TonConnectFailure.bridgeUnavailable }
            } catch WalletTonConnectError.rpc(_, "TONCONNECT_SESSION_NOT_FOUND") {

            } catch {
                self.logTonConnect("close_failed", active, error: error)
                throw error
            }
        }
        guard !self.isShutdown, self.tonConnectActive === active, active.status != .invalidated else { throw CancellationError() }
        self.removeTonConnectJournal(record.key)
        self.tonConnectDisconnectBodies[record.session.id] = nil
        self.tonConnectPendingDisconnects.remove(record.session.id)
        self.tonConnectSessionErrors[record.session.id] = nil
        self.removeTonConnectSession(record.session.id)
        active.publication = nil
        active.lifecycle.completed()
        active.expiryTask?.cancel()
        let decision = TonConnectDecision(approved: true, failure: nil, returnTarget: active.returnTarget)
        active.status = .completed(decision)
        self.publishTonConnectState()
        return decision
    }

    func disconnectTonConnectSessions(ids: [Int64]?, operationId: UUID) async {
        let ids = ids ?? self.tonConnectSessions.values.filter { !$0.isClosed }.map(\.id)
        let epoch = self.tonConnectEpoch
        do {
            try await self.performOperation(.tonConnect, operationId: operationId) {
                let wallet = try await self.runtime.tonConnectIdentity()
                for id in ids {
                    guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
                    if self.storedState.tonConnectRequests.contains(where: { $0.session.id == id && $0.isFinishingDisconnect }) { continue }
                    guard let session = self.tonConnectSessions[id], !session.isClosed else { continue }
                    do {
                        if self.tonConnectDisconnectBodies[id] == nil {
                            let eventId = try await WalletSignalRequestContext<Int64>().run(self.engine.wallet.tonConnectNextEventId(sessionId: id))
                            let body = try await self.runtime.encryptTonConnectDisconnectEvent(eventId: eventId, wallet: wallet, session: session)
                            guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
                            self.tonConnectDisconnectBodies[id] = body
                        }
                        self.publishTonConnectState()
                        let accepted = try await WalletSignalRequestContext<Bool>().run(self.engine.wallet.tonConnectCloseSession(sessionId: id, body: self.tonConnectDisconnectBodies[id]!))
                        guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
                        guard accepted else { throw TonConnectFailure.bridgeUnavailable }
                        self.tonConnectDisconnectBodies[id] = nil
                        self.tonConnectSessionErrors[id] = nil
                        self.tonConnectPendingDisconnects.remove(id)
                        self.removeTonConnectSession(id)
                        if let active = self.tonConnectActive, active.session?.id == id { self.invalidateTonConnect(active, failure: .unavailable) }
                    } catch {
                        guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
                        self.tonConnectSessionErrors[id] = error as? TonConnectFailure ?? .bridgeUnavailable
                        self.logger.error("ton_connect_disconnect_failed", error)
                    }
                }
            }
        } catch {
            guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
            for id in ids { self.tonConnectSessionErrors[id] = error as? TonConnectFailure ?? .unavailable }
        }
        self.publishTonConnectState()
    }

    func finishPendingTonConnectDisconnects() async {
        guard self.canPresentTonConnect, self.currentState.activeOperation == nil, self.tonConnectActive == nil else { return }
        let ids = self.tonConnectPendingDisconnects.union(self.tonConnectDisconnectBodies.keys)
        guard !ids.isEmpty else { return }
        await self.disconnectTonConnectSessions(ids: Array(ids), operationId: UUID())
    }

    @MainActor private static func tonConnectDevice() -> TonConnectDevice {
        #if os(iOS)
        let platform: TonConnectDevicePlatform = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #else
        let platform: TonConnectDevicePlatform = .mac
        #endif
        return TonConnectDevice(platform: platform, appName: "Telegram", appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    private static func tonConnectPrompt(
        id: String,
        manifest: TonConnectManifestInfo,
        request: TonConnectConnectRequest
    ) throws -> WalletContext.TonConnectRequest {
        var permissions: [WalletContext.TonConnectPermission] = [
            .address
        ]
        if let _ = request.prompt.proofPayload {
            permissions.append(.proof(try TonConnectWireCodec.proofDomain(manifestUrl: request.prompt.manifestUrl)))
        }
        return WalletContext.TonConnectRequest(
            id: id,
            applicationName: manifest.name,
            domain: manifest.domain,
            icon: manifest.icon,
            permissions: permissions,
            requestsProof: request.prompt.proofPayload != nil
        )
    }

    private static func tonConnectOperation(
        id: String,
        manifest: TonConnectManifestInfo,
        preview: SendPreview
    ) -> WalletContext.TonConnectOperationRequest {
        let messages = preview.messages.enumerated().map { index, value in
            let amount: String
            switch value.amount {
            case let .exact(nanograms): amount = nanograms
            case .all: amount = "all"
            }
            let payload: WalletContext.TonConnectOperationRequest.Message.Payload
            switch value.body {
            case .empty: payload = .empty
            case let .comment(text): payload = .comment(text)
            case let .rawPayload(boc): payload = .raw(boc)
            }
            return WalletContext.TonConnectOperationRequest.Message(
                id: "\(id):\(index)",
                destination: value.destination,
                amountNanograms: amount,
                payload: payload,
                stateInit: value.stateInit
            )
        }
        var warnings: [String] = []
        if !preview.emulation.traceSucceeded || preview.emulation.isIncomplete {
            warnings.append("Some emulated actions may fail or the trace is incomplete.")
        }
        return WalletContext.TonConnectOperationRequest(
            id: id,
            applicationName: manifest.name,
            domain: manifest.domain,
            icon: manifest.icon,
            method: .sendTransaction,
            messages: messages,
            feeNanograms: preview.emulation.walletFeesNanograms,
            validUntil: preview.validUntil,
            relayerWillSubmit: false,
            needsWalletStateInit: false,
            warnings: warnings,
            actions: preview.emulation.actions.map {
                WalletContext.TonConnectOperationRequest.Action(
                    id: $0.actionId,
                    kind: $0.kind,
                    succeeded: $0.succeeded,
                    accounts: $0.accounts,
                    detailsJson: $0.detailsJson
                )
            }
        )
    }

}

@available(macOS 10.15, *)
public struct TonConnectLink: Equatable, Sendable {
    public let peerId: String
    public let request: String?
    public let returnTarget: TonConnectReturnTarget
    public let traceId: String?

    /// Malformed TonConnect links must not fall through to payment routing.
    public static func matches(_ value: String) -> Bool {
        guard let url = URLComponents(string: value) else { return false }
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let telegramScheme = scheme == "tg" || scheme == "telegram"
        if scheme == "tc" || (telegramScheme && host == "ton-connect") { return true }
        let items = url.queryItems ?? []
        let carriesStart = items.contains { $0.name == "startapp" && $0.value?.hasPrefix("tonconnect-") == true }
        let walletLink = (scheme == "https" && host == "t.me" && ["/sendgrams", "/sendgrams/"].contains(url.path.lowercased()))
            || (telegramScheme && host == "sendgrams")
        if walletLink {
            return carriesStart || items.contains { ["id", "v", "r"].contains($0.name) }
        }
        // The same request also arrives addressed to the wallet by name.
        let resolvesWallet = telegramScheme && host == "resolve"
            && items.contains { $0.name == "domain" && $0.value?.lowercased() == "sendgrams" }
        return resolvesWallet && carriesStart
    }

    public init(_ value: String) throws {
        guard value.utf8.count <= 256 * 1024, Self.matches(value),
              var url = URLComponents(string: value), url.user == nil,
              url.password == nil, url.fragment == nil else { throw TonConnectFailure.invalidLink }
        let starts = (url.queryItems ?? []).filter { $0.name == "startapp" }
        if starts.contains(where: { $0.value?.hasPrefix("tonconnect-") == true }) {
            guard starts.count == 1, let start = starts.first?.value,
                  !(url.queryItems ?? []).contains(where: { ["id", "v", "r"].contains($0.name) }) else {
                throw TonConnectFailure.invalidLink
            }
            let query = String(start.dropFirst("tonconnect-".count))
                .replacingOccurrences(of: "--", with: "%")
                .replacingOccurrences(of: "__", with: "=")
                .replacingOccurrences(of: "-", with: "&")
            guard let decoded = URLComponents(string: "tc://?" + query) else { throw TonConnectFailure.invalidLink }
            url = decoded
        }
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%20")
        var fields: [String: String] = [:]
        for item in url.queryItems ?? [] where ["id", "v", "r", "ret", "trace_id"].contains(item.name) {
            guard fields[item.name] == nil, let value = item.value else { throw TonConnectFailure.invalidLink }
            fields[item.name] = value
        }
        guard let peer = fields["id"], peer.utf8.count == 64,
              peer.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              fields["v"] == nil || fields["v"] == "2",
              (fields["trace_id"]?.count ?? 0) <= 100 else { throw TonConnectFailure.invalidLink }
        if let request = fields["r"] {
            guard !request.isEmpty, fields["v"] == "2" else { throw TonConnectFailure.invalidLink }
        }
        switch fields["ret"] {
        case nil, "back": self.returnTarget = .back
        case "none": self.returnTarget = .none
        case let .some(target):
            guard let parsed = URLComponents(string: target), let scheme = parsed.scheme?.lowercased(),
                  !["file", "data", "javascript"].contains(scheme), parsed.user == nil, parsed.password == nil else {
                throw TonConnectFailure.invalidLink
            }
            self.returnTarget = .url(target)
        }
        self.peerId = peer.lowercased()
        self.request = fields["r"]
        self.traceId = fields["trace_id"]
    }
}

@available(macOS 10.15, *)
public struct TonConnectSignDataPayload: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case text(String)
        case binary(Data)
        case cell(schema: String, boc: Data)
    }

    public let content: Content
    let engineRequest: WalletEngineFFI.TonConnectSignDataRequest

    init(_ request: WalletEngineFFI.TonConnectSignDataRequest) throws {
        self.engineRequest = request
        switch request.payload {
        case let .text(text):
            self.content = .text(text)
        case let .binary(bytes):
            self.content = .binary(try Self.decodeBase64(bytes))
        case let .cell(schema, cell):
            self.content = .cell(schema: schema, boc: try Self.decodeBase64(cell))
        }
    }

    private static func decodeBase64(_ value: String) throws -> Data {
        var padded = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        padded += String(repeating: "=", count: (4 - padded.utf8.count % 4) % 4)
        guard let data = Data(base64Encoded: padded) else { throw TonConnectWireFailure(code: .badRequest) }
        return data
    }
}

@available(macOS 10.15, *)
public struct TonConnectWalletIdentity: Equatable, Codable, Sendable {
    public let recordId: String
    public let address: String
    public let network: String
    public let publicKey: Data

    public init(recordId: String, address: String, network: String, publicKey: Data) {
        self.recordId = recordId
        self.address = address
        self.network = network
        self.publicKey = publicKey
    }
}

@available(macOS 10.15, *)
public enum TonConnectFailure: Error, Equatable, Sendable {
    case unavailable, invalidLink, conflictingLink
    case invalidManifest, wrongNetwork
    case bridgeUnavailable, outcomeUnknown
    case keyMismatch, expired, handledElsewhere

    public var message: String {
        switch self {
        case .unavailable: return "This TON Connect request is no longer available."
        case .invalidLink: return "This TON Connect link is invalid."
        case .conflictingLink: return "This app is already using a different connection request. Reconnect from the app."
        case .invalidManifest: return "Unable to load a valid manifest for this app."
        case .wrongNetwork: return "This app requested a different wallet network."
        case .bridgeUnavailable: return "The TON Connect response is waiting for network delivery."
        case .outcomeUnknown: return "This operation may already have been signed or sent. It will not be signed again. Check the wallet history."
        case .keyMismatch: return "This connection belongs to a different wallet key."
        case .expired: return "This TON Connect request has expired."
        case .handledElsewhere: return "This request was handled on another device."
        }
    }
}

@available(macOS 10.15, *)
public struct TonConnectManifestInfo: Equatable, Sendable {
    public let url: String
    public let name: String
    public let icon: WalletTonConnectIcon?
    public let domain: String

    init(_ value: WalletTonConnectManifest) {
        self.url = value.url
        self.name = value.name
        self.icon = value.icon
        if let url = URLComponents(string: value.url), let host = url.url?.host?.lowercased() {
            let defaultPort: Int? = url.scheme?.lowercased() == "https" ? 443 : (url.scheme?.lowercased() == "http" ? 80 : nil)
            if let port = url.port, port != defaultPort {
                self.domain = "\(host):\(port)"
            } else {
                self.domain = host
            }
        } else {
            self.domain = ""
        }
    }
}

@available(macOS 10.15, *)
public enum TonConnectReturnTarget: Equatable, Codable, Sendable {
    case back, none, url(String)
}

@available(macOS 10.15, *)
public struct TonConnectDecision: Equatable, Sendable {
    public let approved: Bool
    public let failure: TonConnectFailure?
    public let returnTarget: TonConnectReturnTarget
}

@available(macOS 10.15, *)
public struct TonConnectSessionInfo: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case connecting, connected, disconnecting
    }
    public let id: Int64
    public let manifest: TonConnectManifestInfo?
    public let status: Status
    public let error: TonConnectFailure?
}

@available(macOS 10.15, *)
public enum TonConnectRequestStatus: Equatable, Sendable {
    case ready, processing, completed(TonConnectDecision), invalidated
}

@available(macOS 10.15, *)
public struct TonConnectDiagnostic: Equatable, Sendable {
    public let id: UUID
    public let failure: TonConnectFailure
    public let requestId: String?
    public init(id: UUID, failure: TonConnectFailure, requestId: String? = nil) {
        self.id = id
        self.failure = failure
        self.requestId = requestId
    }
}

@available(macOS 10.15, *)
enum TonConnectJSONValue: Decodable {
    case object([String: TonConnectJSONValue]), array([TonConnectJSONValue]), string(String)
    case integer(Int64), unsigned(UInt64), decimal(Double), bool(Bool), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode(Int64.self) { self = .integer(v) }
        else if let v = try? value.decode(UInt64.self) { self = .unsigned(v) }
        else if let v = try? value.decode(Double.self) { self = .decimal(v) }
        else if let v = try? value.decode([String: Self].self) { self = .object(v) }
        else { self = .array(try value.decode([Self].self)) }
    }

    var object: [String: Self]? { if case let .object(v) = self { return v }; return nil }
    var string: String? { if case let .string(v) = self { return v }; return nil }
    var array: [Self]? { if case let .array(v) = self { return v }; return nil }
}

@available(macOS 10.15, *)
public struct TonConnectRequestId: Equatable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ value: String) throws {
        guard (1 ... 100).contains(value.utf8.count), value.utf8.allSatisfy({ (0x20 ... 0x7e).contains($0) }) else { throw TonConnectWireFailure(code: .badRequest) }
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

@available(macOS 10.15, *)
public enum TonConnectWireErrorCode: Int, Codable, Sendable {
    case unknown = 0, badRequest = 1, manifestNotFound = 2, invalidManifest = 3, unknownApp = 100, userDeclined = 300, methodNotSupported = 400

    init(_ code: TonConnectRpcErrorCode) {
        switch code {
        case .unknown: self = .unknown
        case .badRequest: self = .badRequest
        case .unknownApp: self = .unknownApp
        case .userDeclined: self = .userDeclined
        case .methodNotSupported: self = .methodNotSupported
        }
    }

    var engineCode: TonConnectRpcErrorCode {
        get throws {
            switch self {
            case .unknown: return .unknown
            case .badRequest: return .badRequest
            case .unknownApp: return .unknownApp
            case .userDeclined: return .userDeclined
            case .methodNotSupported: return .methodNotSupported
            case .manifestNotFound, .invalidManifest: throw TonConnectFailure.invalidLink
            }
        }
    }

    public var message: String {
        switch self {
        case .unknown: return "Unknown error"
        case .badRequest: return "Bad request"
        case .manifestNotFound: return "Manifest not found"
        case .invalidManifest: return "Invalid manifest"
        case .unknownApp: return "Unknown app"
        case .userDeclined: return "User declined the request"
        case .methodNotSupported: return "Method not supported"
        }
    }
}

@available(macOS 10.15, *)
public struct TonConnectWireFailure: Error, Equatable, Sendable {
    public let requestId: TonConnectRequestId?
    public let code: TonConnectWireErrorCode
    public let message: String

    public init(requestId: TonConnectRequestId? = nil, code: TonConnectWireErrorCode, message: String? = nil) {
        self.requestId = requestId
        self.code = code
        self.message = message ?? code.message
    }
}

@available(macOS 10.15, *)
public enum TonConnectWireRequest: Sendable {
    case sendTransaction(id: TonConnectRequestId, request: SendRequest)
    case signData(id: TonConnectRequestId, payload: TonConnectSignDataPayload)
    case disconnect(id: TonConnectRequestId)

    public var id: TonConnectRequestId {
        switch self {
        case let .sendTransaction(id, _), let .signData(id, _), let .disconnect(id): return id
        }
    }

    public var validUntil: UInt64? {
        let expiration: SendExpiration
        switch self {
        case let .sendTransaction(_, request): expiration = request.intent.expiration
        default: return nil
        }
        if case let .exact(value) = expiration { return value }
        return nil
    }

    var consumesWalletSequenceNumber: Bool {
        switch self {
        case .sendTransaction: return true
        default: return false
        }
    }
}

@available(macOS 10.15, *)
public struct TonConnectConnectRequest: Equatable, Sendable {
    public let prompt: TonConnectConnectPrompt
    public let itemNames: [String]

    public init(_ data: Data) throws {
        let object = try TonConnectWireCodec.object(data)
        try TonConnectWireCodec.keys(object, allowed: ["manifestUrl", "items"])
        guard let manifest = object["manifestUrl"]?.string, let url = URLComponents(string: manifest),
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil, url.fragment == nil,
              let items = object["items"]?.array, !items.isEmpty else { throw TonConnectWireFailure(code: .badRequest) }
        var network: String?
        var proof: String?
        var names: [String] = []
        for item in items {
            guard let item = item.object, let name = item["name"]?.string, !name.isEmpty,
                  !names.contains(name) else { throw TonConnectWireFailure(code: .badRequest) }
            names.append(name)
            switch name {
            case "ton_addr":
                try TonConnectWireCodec.keys(item, allowed: ["name", "network"])
                network = try TonConnectWireCodec.optionalString(item, "network")
                if let network { try TonConnectWireCodec.validateNetwork(network) }
            case "ton_proof":
                try TonConnectWireCodec.keys(item, allowed: ["name", "payload"])
                guard let payload = item["payload"]?.string else { throw TonConnectWireFailure(code: .badRequest) }
                proof = payload
            default: throw TonConnectFailure.invalidLink
            }
        }
        guard names.contains("ton_addr") else { throw TonConnectWireFailure(code: .badRequest) }
        if proof != nil { _ = try TonConnectWireCodec.proofDomain(manifestUrl: manifest) }
        self.prompt = TonConnectConnectPrompt(manifestUrl: manifest, requestedNetwork: network, proofPayload: proof)
        self.itemNames = names
    }
}

@available(macOS 10.15, *)
public enum TonConnectWireCodec {
    public static let maximumPacketBytes = 1024 * 1024

    static func proofDomain(manifestUrl: String) throws -> String {
        guard let url = URLComponents(string: manifestUrl), url.scheme?.lowercased() == "https",
              let host = url.url?.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil else { throw TonConnectFailure.invalidLink }
        let domain = host.replacingOccurrences(of: "\\.+$", with: "", options: .regularExpression)
        guard !domain.isEmpty, domain != "telegram.org" else { throw TonConnectFailure.invalidLink }
        return domain
    }

    static func object(_ data: Data) throws -> [String: TonConnectJSONValue] {
        guard !data.isEmpty, data.count <= self.maximumPacketBytes else { throw TonConnectWireFailure(code: .badRequest) }
        var structure = TonConnectJSONStructure(data)
        try structure.validate()
        guard
              let value = try? JSONDecoder().decode(TonConnectJSONValue.self, from: data), let object = value.object else {
            throw TonConnectWireFailure(code: .badRequest)
        }
        return object
    }

    static func keys(_ object: [String: TonConnectJSONValue], allowed: Set<String>) throws {
        guard Set(object.keys).isSubset(of: allowed) else { throw TonConnectWireFailure(code: .badRequest) }
    }

    static func optionalString(_ object: [String: TonConnectJSONValue], _ key: String) throws -> String? {
        guard let value = object[key] else { return nil }
        guard let string = value.string else { throw TonConnectWireFailure(code: .badRequest) }
        return string
    }

    static func validateNetwork(_ value: String) throws {
        guard let network = Int32(value), String(network) == value else { throw TonConnectWireFailure(code: .badRequest) }
    }
}

/// Reject duplicate keys (including escaped aliases) before JSONDecoder discards them.
@available(macOS 10.15, *)
private struct TonConnectJSONStructure {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) { self.bytes = Array(data) }

    mutating func validate() throws {
        try self.value(depth: 0)
        self.whitespace()
        guard self.offset == self.bytes.count else { throw TonConnectWireFailure(code: .badRequest) }
    }

    private mutating func value(depth: Int) throws {
        self.whitespace()
        guard depth <= 64, self.offset < self.bytes.count else { throw TonConnectWireFailure(code: .badRequest) }
        switch self.bytes[self.offset] {
        case 123: // object
            self.offset += 1
            self.whitespace()
            if self.consume(125) { return }
            var keys = Set<String>()
            while true {
                self.whitespace()
                let key = try self.string()
                guard keys.insert(key).inserted else { throw TonConnectWireFailure(code: .badRequest) }
                self.whitespace()
                guard self.consume(58) else { throw TonConnectWireFailure(code: .badRequest) }
                try self.value(depth: depth + 1)
                self.whitespace()
                if self.consume(125) { return }
                guard self.consume(44) else { throw TonConnectWireFailure(code: .badRequest) }
            }
        case 91: // array
            self.offset += 1
            self.whitespace()
            if self.consume(93) { return }
            while true {
                try self.value(depth: depth + 1)
                self.whitespace()
                if self.consume(93) { return }
                guard self.consume(44) else { throw TonConnectWireFailure(code: .badRequest) }
            }
        case 34: _ = try self.string()
        default:
            let start = self.offset
            while self.offset < self.bytes.count, ![9, 10, 13, 32, 44, 93, 125].contains(self.bytes[self.offset]) { self.offset += 1 }
            guard self.offset > start else { throw TonConnectWireFailure(code: .badRequest) }
        }
    }

    private mutating func string() throws -> String {
        let start = self.offset
        guard self.consume(34) else { throw TonConnectWireFailure(code: .badRequest) }
        while self.offset < self.bytes.count {
            let byte = self.bytes[self.offset]
            self.offset += 1
            if byte == 92 {
                guard self.offset < self.bytes.count else { throw TonConnectWireFailure(code: .badRequest) }
                self.offset += 1
            } else if byte == 34 {
                guard let value = try? JSONDecoder().decode(String.self, from: Data(self.bytes[start ..< self.offset])) else { throw TonConnectWireFailure(code: .badRequest) }
                return value
            }
        }
        throw TonConnectWireFailure(code: .badRequest)
    }

    private mutating func whitespace() {
        while self.offset < self.bytes.count, [9, 10, 13, 32].contains(self.bytes[self.offset]) { self.offset += 1 }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard self.offset < self.bytes.count, self.bytes[self.offset] == byte else { return false }
        self.offset += 1
        return true
    }
}
