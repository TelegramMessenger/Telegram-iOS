import XCTest
import Postbox
@testable import TelegramCore

/// A resend and a forward whose source has no cloud copy both enqueue a new message from the
/// attributes a message *stored*, which are not the attributes it was requested with. A timer is where
/// the two differ: a cloud chat keeps a media timer as `AutoclearTimeoutMessageAttribute` and its own
/// auto-delete period as `AutoremoveTimeoutMessageAttribute`, the attribute a media timer is requested
/// as; a secret chat keeps both kinds of timer as `AutoremoveTimeoutMessageAttribute`.
final class ReenqueuedMessageAttributesTests: XCTestCase {
    private let mediaTimer: Int32 = 10
    private let chatAutoDeletePeriod: Int32 = 24 * 60 * 60
    private let secretChatTimer: Int32 = 5

    private func sent(_ requestedAttributes: [MessageAttribute], isSecretChat: Bool = false, peerAutoremoveTimeout: Int32? = nil) -> [MessageAttribute] {
        return outgoingMessageAttributes(requestedAttributes: requestedAttributes, isSecretChat: isSecretChat, peerAutoremoveTimeout: peerAutoremoveTimeout)
    }

    private func resent(_ storedAttributes: [MessageAttribute], isSecretChat: Bool = false, peerAutoremoveTimeout: Int32? = nil) -> [MessageAttribute] {
        let requestedAttributes = storedAttributes.compactMap { resentMessageRequestedAttribute($0, isSecretChat: isSecretChat) }
        return self.sent(requestedAttributes, isSecretChat: isSecretChat, peerAutoremoveTimeout: peerAutoremoveTimeout)
    }

    /// A forward whose source is not a cloud message, sent as a copy.
    private func forwarded(_ sourceAttributes: [MessageAttribute], forwardAttributes: [MessageAttribute] = [], hidesCaption: Bool = false, isSecretChat: Bool = false, peerAutoremoveTimeout: Int32? = nil) -> [MessageAttribute] {
        let requestedAttributes = forwardCopyRequestedAttributes(sourceAttributes: sourceAttributes, forwardAttributes: forwardAttributes, hidesCaption: hidesCaption)
        return self.sent(requestedAttributes, isSecretChat: isSecretChat, peerAutoremoveTimeout: peerAutoremoveTimeout)
    }

    /// A cloud message forwarded into a secret chat, sent as a copy: the `.forward` branch stores the
    /// secret chat's timer first and the copied attributes after it.
    private func copiedIntoSecretChat(_ sourceAttributes: [MessageAttribute], secretChatTimer: Int32) -> [MessageAttribute] {
        return [AutoremoveTimeoutMessageAttribute(timeout: secretChatTimer, countdownBeginTime: nil)] + forwardCopyRequestedAttributes(sourceAttributes: sourceAttributes, forwardAttributes: [], hidesCaption: false)
    }

    private func describe(_ attributes: [MessageAttribute]) -> [String] {
        return attributes.map { attribute in
            if let attribute = attribute as? AutoclearTimeoutMessageAttribute {
                return "autoclear(\(attribute.timeout))"
            } else if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                if let countdownBeginTime = attribute.countdownBeginTime {
                    return "autoremove(\(attribute.timeout), began \(countdownBeginTime))"
                }
                return "autoremove(\(attribute.timeout))"
            } else if let attribute = attribute as? PaidStarsMessageAttribute {
                return "paidStars(\(attribute.stars.value))"
            } else if let attribute = attribute as? SendAsMessageAttribute {
                return "sendAs(\(attribute.peerId.id._internalGetInt64Value()))"
            } else if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                return "schedule(\(attribute.scheduleTime))"
            } else if let attribute = attribute as? NotificationInfoMessageAttribute {
                return attribute.flags.contains(.muted) ? "silent" : "notify"
            } else if attribute is MediaSpoilerMessageAttribute {
                return "spoiler"
            } else if attribute is InvertMediaMessageAttribute {
                return "invertMedia"
            } else if attribute is TextEntitiesMessageAttribute {
                return "entities"
            } else if attribute is OutgoingChatContextResultMessageAttribute {
                return "inlineResult"
            } else {
                return "\(type(of: attribute))"
            }
        }
    }

    private func channelId(_ id: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
    }

    // MARK: - Resend

    func testACloudChatMediaTimerSurvivesAResend() {
        let original = self.sent([AutoremoveTimeoutMessageAttribute(timeout: self.mediaTimer, countdownBeginTime: nil), MediaSpoilerMessageAttribute()])
        XCTAssertEqual(self.describe(original), ["autoclear(10)", "spoiler"])

        XCTAssertEqual(self.describe(self.resent(original)), self.describe(original))
    }

    func testCloudChatViewOnceMediaSurvivesAResend() {
        let original = self.sent([AutoremoveTimeoutMessageAttribute(timeout: viewOnceTimeout, countdownBeginTime: nil)])
        XCTAssertEqual(self.describe(original), ["autoclear(\(viewOnceTimeout))"])

        XCTAssertEqual(self.describe(self.resent(original)), self.describe(original))
    }

    /// The upload sends any `AutoclearTimeoutMessageAttribute` as the media's `ttl_seconds`, so a
    /// chat's auto-delete period read back as a request would resend a plain photo as a
    /// self-destructing one.
    func testAResendDoesNotTurnTheChatAutoDeletePeriodIntoAMediaTimer() {
        let original = self.sent([], peerAutoremoveTimeout: self.chatAutoDeletePeriod)
        XCTAssertEqual(self.describe(original), ["autoremove(86400)"])

        XCTAssertEqual(self.describe(self.resent(original, peerAutoremoveTimeout: self.chatAutoDeletePeriod)), ["autoremove(86400)"])
    }

    func testAMediaTimerAndTheChatAutoDeletePeriodBothSurviveAResend() {
        let original = self.sent([AutoremoveTimeoutMessageAttribute(timeout: self.mediaTimer, countdownBeginTime: nil)], peerAutoremoveTimeout: self.chatAutoDeletePeriod)
        XCTAssertEqual(self.describe(original), ["autoclear(10)", "autoremove(86400)"])

        XCTAssertEqual(self.describe(self.resent(original, peerAutoremoveTimeout: self.chatAutoDeletePeriod)), self.describe(original))
    }

    /// The chat's period is derived afresh at every enqueue, so a resend follows the current setting.
    func testAResendFollowsTheChatsCurrentAutoDeletePeriod() {
        let original = self.sent([], peerAutoremoveTimeout: self.chatAutoDeletePeriod)

        XCTAssertEqual(self.describe(self.resent(original, peerAutoremoveTimeout: nil)), [])
    }

    /// A secret chat stores a requested timer as-is, in place of the chat's own.
    func testASecretChatTimerSurvivesAResend() {
        let withChatTimer = self.sent([], isSecretChat: true, peerAutoremoveTimeout: self.secretChatTimer)
        XCTAssertEqual(self.describe(withChatTimer), ["autoremove(5)"])
        XCTAssertEqual(self.describe(self.resent(withChatTimer, isSecretChat: true, peerAutoremoveTimeout: self.secretChatTimer)), self.describe(withChatTimer))

        let withMediaTimer = self.sent([AutoremoveTimeoutMessageAttribute(timeout: self.mediaTimer, countdownBeginTime: nil)], isSecretChat: true, peerAutoremoveTimeout: self.secretChatTimer)
        XCTAssertEqual(self.describe(withMediaTimer), ["autoremove(10)"])
        XCTAssertEqual(self.describe(self.resent(withMediaTimer, isSecretChat: true, peerAutoremoveTimeout: self.secretChatTimer)), self.describe(withMediaTimer))
    }

    // MARK: - Forward sent as a new message

    /// Requested in a cloud chat, a secret chat's timer would upload the copy as self-destructing media.
    func testAForwardedSecretChatTimerDoesNotBecomeAMediaTimer() {
        let source = self.sent([MediaSpoilerMessageAttribute()], isSecretChat: true, peerAutoremoveTimeout: self.secretChatTimer)
        XCTAssertEqual(self.describe(source), ["spoiler", "autoremove(5)"])

        XCTAssertEqual(self.describe(self.forwarded(source)), ["spoiler"])
        XCTAssertEqual(self.describe(self.forwarded(source, peerAutoremoveTimeout: self.chatAutoDeletePeriod)), ["spoiler", "autoremove(86400)"])
    }

    /// Requested in a secret chat, the source's timer would replace the destination's own and bring its
    /// countdown along, so a message the recipient had already read would expire as soon as it is sent.
    func testAForwardIntoASecretChatTakesThatChatsTimer() {
        let readSource: [MessageAttribute] = [AutoremoveTimeoutMessageAttribute(timeout: self.secretChatTimer, countdownBeginTime: 1000)]

        XCTAssertEqual(self.describe(self.forwarded(readSource, isSecretChat: true, peerAutoremoveTimeout: 60)), ["autoremove(60)"])
        XCTAssertEqual(self.describe(self.forwarded(readSource, isSecretChat: true, peerAutoremoveTimeout: nil)), [])
    }

    func testAForwardedCloudMessageDoesNotBringItsChatsTimers() {
        let source = self.sent([AutoremoveTimeoutMessageAttribute(timeout: self.mediaTimer, countdownBeginTime: nil)], peerAutoremoveTimeout: self.chatAutoDeletePeriod)
        XCTAssertEqual(self.describe(source), ["autoclear(10)", "autoremove(86400)"])

        XCTAssertEqual(self.describe(self.forwarded(source)), [])
    }

    /// The forward's own attributes say how and where the copy is sent; the source's say how and where
    /// the source was.
    func testAForwardIsSentTheWayTheForwardAsked() {
        let source: [MessageAttribute] = [
            PaidStarsMessageAttribute(stars: StarsAmount(value: 5, nanos: 0), postponeSending: false),
            SendAsMessageAttribute(peerId: self.channelId(1)),
            OutgoingScheduleInfoMessageAttribute(scheduleTime: 1000, repeatPeriod: nil),
            NotificationInfoMessageAttribute(flags: [])
        ]
        let forwardAttributes: [MessageAttribute] = [
            PaidStarsMessageAttribute(stars: StarsAmount(value: 20, nanos: 0), postponeSending: false),
            SendAsMessageAttribute(peerId: self.channelId(2)),
            NotificationInfoMessageAttribute(flags: .muted)
        ]

        XCTAssertEqual(self.describe(self.forwarded(source, forwardAttributes: forwardAttributes)), ["paidStars(20)", "sendAs(2)", "silent"])
    }

    /// A local source's inline bot result is the only thing that carries its content when the copy has
    /// no media of its own.
    func testAForwardKeepsTheSourcesContent() {
        let source: [MessageAttribute] = [
            TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< 4, type: .Bold)]),
            MediaSpoilerMessageAttribute(),
            InvertMediaMessageAttribute(),
            OutgoingChatContextResultMessageAttribute(queryId: 1, id: "1", hideVia: false, webpageUrl: nil)
        ]

        XCTAssertEqual(self.describe(self.forwarded(source)), ["entities", "spoiler", "invertMedia", "inlineResult"])
    }

    func testAHiddenCaptionTakesItsFormattingAlong() {
        let source: [MessageAttribute] = [
            TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< 4, type: .Bold)]),
            MediaSpoilerMessageAttribute()
        ]

        XCTAssertEqual(self.describe(self.forwarded(source, hidesCaption: true)), ["spoiler"])
    }

    // MARK: - Forward

    private let paidSource: [MessageAttribute] = [
        TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< 4, type: .Bold)]),
        MediaSpoilerMessageAttribute(),
        InvertMediaMessageAttribute(),
        PaidStarsMessageAttribute(stars: StarsAmount(value: 5, nanos: 0), postponeSending: false)
    ]

    private func kinds(_ attributes: [MessageAttribute]) -> [String] {
        return self.describe(attributes).sorted()
    }

    /// The sender reads the last paid stars a message stores; the source's are what it was paid.
    func testAForwardStoresTheDestinationsPaidStarsRatherThanTheSources() {
        let forwarded = forwardedMessageAttributes(requestedAttributes: [PaidStarsMessageAttribute(stars: StarsAmount(value: 20, nanos: 0), postponeSending: false)], sourceAttributes: self.paidSource, forwardedMessageIds: nil)

        XCTAssertEqual(self.describe(forwarded).filter { $0.hasPrefix("paidStars") }, ["paidStars(20)"])
    }

    /// A resend requests what the failed forward stored, the source's attributes included, and then
    /// takes the source's again.
    func testAResentForwardStoresEachAttributeOnce() {
        let request: [MessageAttribute] = [
            NotificationInfoMessageAttribute(flags: .muted),
            InvertMediaMessageAttribute(),
            PaidStarsMessageAttribute(stars: StarsAmount(value: 20, nanos: 0), postponeSending: false)
        ]
        let failed = forwardedMessageAttributes(requestedAttributes: request, sourceAttributes: self.paidSource, forwardedMessageIds: nil)
        XCTAssertEqual(self.kinds(failed), ["entities", "invertMedia", "paidStars(20)", "silent", "spoiler"])

        // `resendMessages` drops the stored paid stars and asks for the chat's current price.
        let resendRequest = failed.compactMap { resentMessageRequestedAttribute($0, isSecretChat: false) } + [PaidStarsMessageAttribute(stars: StarsAmount(value: 20, nanos: 0), postponeSending: false)]
        let resent = forwardedMessageAttributes(requestedAttributes: resendRequest, sourceAttributes: self.paidSource, forwardedMessageIds: nil)

        XCTAssertEqual(self.kinds(resent), self.kinds(failed))
    }

    func testAForwardedAlbumStaysOneAlbumOfItsOwn() {
        var generatedKeys: [Int64: Int64] = [:]
        let sourceAlbum: Int64 = 1
        let otherSourceAlbum: Int64 = 2

        let album = (0 ..< 3).map { _ in forwardGroupingKey(grouping: .auto, sourceGroupingKey: sourceAlbum, generatedKeys: &generatedKeys) }
        let otherAlbum = forwardGroupingKey(grouping: .auto, sourceGroupingKey: otherSourceAlbum, generatedKeys: &generatedKeys)

        XCTAssertNotNil(album[0])
        XCTAssertEqual(Set(album.map { $0 }).count, 1)
        XCTAssertNotEqual(album[0], sourceAlbum)
        XCTAssertNotNil(otherAlbum)
        XCTAssertNotEqual(otherAlbum, album[0])
    }

    func testAForwardIsUngroupedWhenItsSourceIsOrWhenAskedTo() {
        var generatedKeys: [Int64: Int64] = [:]

        XCTAssertNil(forwardGroupingKey(grouping: .auto, sourceGroupingKey: nil, generatedKeys: &generatedKeys))
        XCTAssertNil(forwardGroupingKey(grouping: .none, sourceGroupingKey: 1, generatedKeys: &generatedKeys))
    }

    // MARK: - Cloud message forwarded into a secret chat

    /// The secret-chat sender takes the last timer a message stores, so a copied cloud timer would send
    /// the copy with the source chat's auto-delete period (and its running countdown) instead of the
    /// secret chat's timer; a copied send-as peer would become the copy's author.
    func testACopyIntoASecretChatKeepsThatChatsTimerAndAuthor() {
        let source: [MessageAttribute] = [
            AutoremoveTimeoutMessageAttribute(timeout: self.chatAutoDeletePeriod, countdownBeginTime: 1000),
            SendAsMessageAttribute(peerId: self.channelId(1)),
            PaidStarsMessageAttribute(stars: StarsAmount(value: 5, nanos: 0), postponeSending: false),
            MediaSpoilerMessageAttribute()
        ]

        XCTAssertEqual(self.describe(self.copiedIntoSecretChat(source, secretChatTimer: self.secretChatTimer)), ["autoremove(5)", "spoiler"])
    }
}
