import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

let supportOccupyFor: Int32 = 60
let supportReoccupyEach: Double = 30.0
let supportOccupiedExpiryDelay: Int32 = 2
let supportReleaseDelay: Double = 1.0

struct SupportReceivedDraft {
    var peerId: PeerId
    var text: String?
}

public struct SupportOccupation: Equatable {
    public var till: Int32
    public var name: String
}

func supportOccupationTag(installationTag: UInt64) -> UInt32 {
    return UInt32(truncatingIfNeeded: installationTag)
}

func supportNormalizedName(_ name: String) -> String {
    return name.replacingOccurrences(of: ":", with: "_").replacingOccurrences(of: ";", with: "_")
}

func supportOccupationDraftText(now: Int32, tag: UInt32, normalizedName: String) -> String {
    return "t:\(now + supportOccupyFor);u:\(tag);n:\(normalizedName)"
}

// As Qt's toInt and toUInt, anything that is not a number in range reads as 0.
private func supportParseInt32(_ value: Substring) -> Int32 {
    return Int32(value) ?? 0
}

private func supportParseUInt32(_ value: Substring) -> UInt32 {
    return UInt32(value) ?? 0
}

// TDesktop's ParseOccupationTag: 0 means not occupied.
func supportParseOccupationTag(_ text: String, now: Int32) -> UInt32 {
    var valid = false
    var result: UInt32 = 0
    for part in text.split(separator: ";", omittingEmptySubsequences: false) {
        if part.hasPrefix("t:") {
            if supportParseInt32(part.dropFirst(2)) >= now {
                valid = true
            } else {
                return 0
            }
        } else if part.hasPrefix("u:") {
            result = supportParseUInt32(part.dropFirst(2))
        }
    }
    return valid ? result : 0
}

// TDesktop's ParseOccupationName.
func supportParseOccupationName(_ text: String, now: Int32) -> String {
    var valid = false
    var result = ""
    for part in text.split(separator: ";", omittingEmptySubsequences: false) {
        if part.hasPrefix("t:") {
            if supportParseInt32(part.dropFirst(2)) >= now {
                valid = true
            } else {
                return ""
            }
        } else if part.hasPrefix("n:") {
            result = String(part.dropFirst(2))
        }
    }
    return valid ? result : ""
}

// TDesktop's OccupiedBySomeoneTill: 0 means nobody else holds the chat.
func supportOccupiedBySomeoneTill(_ text: String, now: Int32, ownTag: UInt32) -> Int32 {
    var valid = false
    var result: Int32 = 0
    for part in text.split(separator: ";", omittingEmptySubsequences: false) {
        if part.hasPrefix("t:") {
            let till = supportParseInt32(part.dropFirst(2))
            if till >= now {
                result = till
            } else {
                return 0
            }
        } else if part.hasPrefix("u:") {
            if supportParseUInt32(part.dropFirst(2)) != ownTag {
                valid = true
            } else {
                return 0
            }
        }
    }
    return valid ? result : 0
}

func supportOccupationBySomeone(_ text: String?, now: Int32, ownTag: UInt32) -> SupportOccupation? {
    guard let text else {
        return nil
    }
    let till = supportOccupiedBySomeoneTill(text, now: now, ownTag: ownTag)
    if till == 0 {
        return nil
    }
    return SupportOccupation(till: till, name: supportParseOccupationName(text, now: now))
}

func supportIsOccupiedByMe(_ text: String?, now: Int32, ownTag: UInt32) -> Bool {
    guard let text else {
        return false
    }
    let tag = supportParseOccupationTag(text, now: now)
    return tag != 0 && tag == ownTag
}

func supportTracksOccupation(peerId: PeerId, accountPeerId: PeerId, isBot: Bool) -> Bool {
    if peerId.namespace != Namespaces.Peer.CloudUser || peerId == accountPeerId || isBot {
        return false
    }
    let value = peerId.id._internalGetInt64Value()
    return value != 777000 && value != 333000
}

func supportTracksOccupation(transaction: Transaction, peerId: PeerId, accountPeerId: PeerId) -> Bool {
    guard let user = transaction.getPeer(peerId) as? TelegramUser else {
        return false
    }
    return supportTracksOccupation(peerId: peerId, accountPeerId: accountPeerId, isBot: user.botInfo != nil)
}

func supportReceivedDraftText(_ inputState: SynchronizeableChatInputState?) -> String? {
    guard let inputState, case let .textEntities(text, _) = inputState.content, !text.isEmpty else {
        return nil
    }
    return text
}

private typealias SignalKitTimer = SwiftSignalKit.Timer

private func supportSaveDraft(postbox: Postbox, network: Network, peerId: PeerId, text: String) -> Signal<Bool, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Bool, NoError> in
        guard let inputPeer else {
            return .single(false)
        }
        return network.request(Api.functions.messages.saveDraft(flags: 0, replyTo: nil, peer: inputPeer, message: text, entities: nil, media: nil, effect: nil, suggestedPost: nil, richMessage: nil))
        |> map { _ -> Bool in
            return true
        }
        |> `catch` { _ -> Signal<Bool, NoError> in
            return .single(false)
        }
    }
}

// The open chat's current cloud draft, read before the first claim; nil when it cannot be read.
private func supportFetchCloudDraft(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId) -> Signal<SupportReceivedDraft?, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<SupportReceivedDraft?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        return network.request(Api.functions.messages.getPeerDialogs(peers: [.inputDialogPeer(.init(peer: inputPeer))]))
        |> map { result -> SupportReceivedDraft? in
            guard case let .peerDialogs(data) = result else {
                return nil
            }
            for dialog in data.dialogs {
                guard dialog.peerId == peerId, case let .dialog(dialogData) = dialog else {
                    continue
                }
                var text: String?
                if let draft = dialogData.draft {
                    text = supportReceivedDraftText(_internal_synchronizeableChatInputState(accountPeerId: accountPeerId, peerId: peerId, apiDraft: draft))
                }
                return SupportReceivedDraft(peerId: peerId, text: text)
            }
            return SupportReceivedDraft(peerId: peerId, text: nil)
        }
        |> `catch` { _ -> Signal<SupportReceivedDraft?, NoError> in
            return .single(nil)
        }
    }
}

private final class SupportOccupationManager {
    private let queue: Queue
    private let postbox: Postbox
    private let network: Network
    private let accountPeerId: PeerId
    private let ownTag: UInt32
    private let updatedOccupations: ([PeerId: SupportOccupation]) -> Void

    private var normalizedName: String?
    private var openPeerId: PeerId?
    private var openPeerIsReady = false
    private var claimedPeerId: PeerId?
    private var occupied: [PeerId: SupportOccupation] = [:]

    private var reoccupyTimer: SignalKitTimer?
    private var expiryTimer: SignalKitTimer?
    private let prepareDisposable = MetaDisposable()
    private let deliveredDisposable = MetaDisposable()
    private let claimDisposable = MetaDisposable()

    init(queue: Queue, postbox: Postbox, network: Network, accountPeerId: PeerId, ownTag: UInt32, updatedOccupations: @escaping ([PeerId: SupportOccupation]) -> Void) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
        self.ownTag = ownTag
        self.updatedOccupations = updatedOccupations
    }

    deinit {
        self.reoccupyTimer?.invalidate()
        self.expiryTimer?.invalidate()
        self.prepareDisposable.dispose()
        self.deliveredDisposable.dispose()
        self.claimDisposable.dispose()
    }

    private var now: Int32 {
        return Int32(Date().timeIntervalSince1970)
    }

    func setName(_ name: String) {
        self.normalizedName = supportNormalizedName(name)
        self.occupyIfNotYet()
    }

    func setOpenPeer(_ peerId: PeerId?, deliveredMessages: (PeerId) -> Signal<Void, NoError>) {
        if self.openPeerId == peerId {
            return
        }
        self.prepareDisposable.set(nil)
        self.deliveredDisposable.set(nil)
        self.claimDisposable.set(nil)
        self.reoccupyTimer?.invalidate()
        self.reoccupyTimer = nil
        if let claimedPeerId = self.claimedPeerId {
            self.claimedPeerId = nil
            self.release(peerId: claimedPeerId)
        }
        self.openPeerId = peerId
        self.openPeerIsReady = false
        guard let peerId else {
            return
        }

        let postbox = self.postbox
        let network = self.network
        let accountPeerId = self.accountPeerId
        let prepare: Signal<SupportReceivedDraft?, NoError> = postbox.transaction { transaction -> Bool in
            return supportTracksOccupation(transaction: transaction, peerId: peerId, accountPeerId: accountPeerId)
        }
        |> mapToSignal { isTracked -> Signal<SupportReceivedDraft?, NoError> in
            if !isTracked {
                return .never()
            }
            return supportFetchCloudDraft(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId)
        }
        self.prepareDisposable.set((prepare
        |> deliverOn(self.queue)).start(next: { [weak self] draft in
            guard let self, self.openPeerId == peerId else {
                return
            }
            if let draft {
                self.apply(drafts: [draft])
            }
            self.openPeerIsReady = true
            self.occupyIfNotYet()
        }))

        self.deliveredDisposable.set((deliveredMessages(peerId)
        |> deliverOn(self.queue)).start(next: { [weak self] in
            guard let self, self.openPeerId == peerId else {
                return
            }
            // A send carries clear_draft, so the server no longer holds the claim.
            if self.claimedPeerId == peerId {
                self.claimedPeerId = nil
            }
            self.occupyIfNotYet()
        }))
    }

    func apply(drafts: [SupportReceivedDraft]) {
        let now = self.now
        var openPeerChanged = false
        for draft in drafts {
            if let occupation = supportOccupationBySomeone(draft.text, now: now, ownTag: self.ownTag) {
                self.occupied[draft.peerId] = occupation
                if self.claimedPeerId == draft.peerId {
                    self.claimedPeerId = nil
                }
            } else {
                self.occupied.removeValue(forKey: draft.peerId)
                if !supportIsOccupiedByMe(draft.text, now: now, ownTag: self.ownTag), self.claimedPeerId == draft.peerId {
                    self.claimedPeerId = nil
                }
            }
            if draft.peerId == self.openPeerId {
                openPeerChanged = true
            }
        }
        self.updateExpiryTimer()
        if openPeerChanged {
            self.occupyIfNotYet()
        }
    }

    private func isOccupiedBySomeone(peerId: PeerId) -> Bool {
        guard let occupation = self.occupied[peerId] else {
            return false
        }
        return occupation.till >= self.now
    }

    private func occupyIfNotYet() {
        guard let peerId = self.openPeerId, self.openPeerIsReady, self.claimedPeerId != peerId else {
            return
        }
        guard let normalizedName = self.normalizedName, !self.isOccupiedBySomeone(peerId: peerId) else {
            return
        }
        self.claimedPeerId = peerId
        self.sendClaim(peerId: peerId, normalizedName: normalizedName)
        if self.reoccupyTimer == nil {
            let timer = SignalKitTimer(timeout: supportReoccupyEach, repeat: true, completion: { [weak self] in
                self?.reoccupy()
            }, queue: self.queue)
            self.reoccupyTimer = timer
            timer.start()
        }
    }

    private func reoccupy() {
        guard let peerId = self.openPeerId, self.claimedPeerId == peerId, let normalizedName = self.normalizedName else {
            return
        }
        self.sendClaim(peerId: peerId, normalizedName: normalizedName)
    }

    private func sendClaim(peerId: PeerId, normalizedName: String) {
        let text = supportOccupationDraftText(now: self.now, tag: self.ownTag, normalizedName: normalizedName)
        self.claimDisposable.set(supportSaveDraft(postbox: self.postbox, network: self.network, peerId: peerId, text: text).start())
    }

    private func release(peerId: PeerId) {
        if self.isOccupiedBySomeone(peerId: peerId) {
            return
        }
        let _ = supportSaveDraft(postbox: self.postbox, network: self.network, peerId: peerId, text: "").start()
    }

    private func updateExpiryTimer() {
        self.expiryTimer?.invalidate()
        self.expiryTimer = nil

        let now = self.now
        var expiredOpenPeer = false
        for (peerId, occupation) in self.occupied where occupation.till + supportOccupiedExpiryDelay <= now {
            self.occupied.removeValue(forKey: peerId)
            if peerId == self.openPeerId {
                expiredOpenPeer = true
            }
        }
        if let nearest = self.occupied.values.map({ $0.till + supportOccupiedExpiryDelay }).min() {
            let timer = SignalKitTimer(timeout: Double(nearest - now), repeat: false, completion: { [weak self] in
                self?.updateExpiryTimer()
            }, queue: self.queue)
            self.expiryTimer = timer
            timer.start()
        }
        self.updatedOccupations(self.occupied)
        if expiredOpenPeer {
            self.occupyIfNotYet()
        }
    }
}

func managedSupportOccupation(postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager, pendingMessageManager: PendingMessageManager, supportContext: SupportContext) -> Signal<Never, NoError> {
    return Signal { _ in
        let queue = Queue()
        let disposable = DisposableSet()
        let manager = Atomic<QueueLocalObject<SupportOccupationManager>?>(value: nil)

        disposable.add((postbox.transaction { transaction -> UInt64 in
            return supportInstallationTag(transaction: transaction)
        }
        |> deliverOn(queue)).start(next: { installationTag in
            let object = QueueLocalObject(queue: queue, generate: {
                return SupportOccupationManager(queue: queue, postbox: postbox, network: network, accountPeerId: accountPeerId, ownTag: supportOccupationTag(installationTag: installationTag), updatedOccupations: { occupations in
                    supportContext.setOccupations(occupations)
                })
            })
            let _ = manager.swap(object)

            let deliveredMessages: (PeerId) -> Signal<Void, NoError> = { peerId in
                return pendingMessageManager.deliveredMessageEvents(peerId: peerId)
                |> map { _ -> Void in
                    return Void()
                }
            }
            for receivedDrafts in [stateManager.supportReceivedDrafts(), supportContext.receivedDrafts] {
                disposable.add((receivedDrafts
                |> deliverOn(queue)).start(next: { drafts in
                    object.with { $0.apply(drafts: drafts) }
                }))
            }
            disposable.add((supportContext.supportName
            |> deliverOn(queue)).start(next: { name in
                object.with { $0.setName(name) }
            }))
            // Closing waits a moment, so moving between a chat and its profile neither releases nor re-claims.
            disposable.add((supportContext.openChat
            |> mapToSignal { peerId -> Signal<PeerId?, NoError> in
                if peerId == nil {
                    return .single(nil) |> delay(supportReleaseDelay, queue: queue)
                }
                return .single(peerId)
            }
            |> deliverOn(queue)).start(next: { peerId in
                object.with { $0.setOpenPeer(peerId, deliveredMessages: deliveredMessages) }
            }))
        }))

        return ActionDisposable {
            disposable.dispose()
            let _ = manager.swap(nil)
        }
    }
}
