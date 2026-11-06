import XCTest
import Postbox
import TelegramCore
import TelegramUIPreferences
import TextFormat

final class AllMentionIncomingMessageTests: XCTestCase {
    private func incoming(silent: Bool = false) -> [MessageAttribute] {
        let entities = allMentionEntitiesForLocalDemo(text: "@all Встречаемся у входа", entities: [], isEnabled: true)
        return allMentionIncomingAttributes([TextEntitiesMessageAttribute(entities: entities)], isCollective: true, isSilent: silent)
    }

    func testIncomingCallUsesNativeUnreadMentionTag() {
        let attributes = incoming()
        XCTAssertTrue(tagsForStoreMessage(incoming: true, attributes: attributes, media: [], textEntities: nil, isPinned: false).0.contains(.unseenPersonalMessage))
        XCTAssertTrue(attributes.contains { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.personal) == true })
        let mention = attributes.compactMap { $0 as? ConsumablePersonalMentionMessageAttribute }.first
        XCTAssertEqual(mention?.consumed, false)
        XCTAssertEqual(mention?.pending, false)
    }

    func testSilentCallStillHasUnreadMentionAndNoSoundFlag() {
        let attributes = incoming(silent: true)
        XCTAssertTrue(tagsForStoreMessage(incoming: true, attributes: attributes, media: [], textEntities: nil, isPinned: false).0.contains(.unseenPersonalMessage))
        let flags = attributes.compactMap { $0 as? NotificationInfoMessageAttribute }.first?.flags
        XCTAssertEqual(flags?.contains(.muted), true)
        XCTAssertEqual(flags?.contains(.personal), true)
    }

    func testReadingClearsNativeMentionTagWithoutNetworkPendingState() {
        let consumed = allMentionConsumedAttributes(incoming(silent: true))
        XCTAssertFalse(tagsForStoreMessage(incoming: true, attributes: consumed, media: [], textEntities: nil, isPinned: false).0.contains(.unseenPersonalMessage))
        let mention = consumed.compactMap { $0 as? ConsumablePersonalMentionMessageAttribute }.first
        XCTAssertEqual(mention?.consumed, true)
        XCTAssertEqual(mention?.pending, false)
        let flags = consumed.compactMap { $0 as? NotificationInfoMessageAttribute }.first?.flags
        XCTAssertEqual(flags?.contains(.muted), true)
        XCTAssertEqual(flags?.contains(.personal), true)
    }

    func testConsumedMentionRemainsConsumedOnRepeatedRead() {
        let once = allMentionConsumedAttributes(incoming())
        let twice = allMentionConsumedAttributes(once)
        XCTAssertEqual(twice.compactMap { $0 as? ConsumablePersonalMentionMessageAttribute }.count, 1)
        XCTAssertFalse(tagsForStoreMessage(incoming: true, attributes: twice, media: [], textEntities: nil, isPinned: false).0.contains(.unseenPersonalMessage))
    }

    func testProtectedAtAllDoesNotCreateRecipientMention() {
        let code = MessageTextEntity(range: 0 ..< 4, type: .Code)
        let entities = allMentionEntitiesForLocalDemo(text: "@all", entities: [code], isEnabled: true)
        let collective = entities.contains { $0.type == .Custom(type: ApplicationSpecificEntityType.AllMention) }
        let attributes = allMentionIncomingAttributes([TextEntitiesMessageAttribute(entities: entities)], isCollective: collective, isSilent: false)
        XCTAssertFalse(tagsForStoreMessage(incoming: true, attributes: attributes, media: [], textEntities: nil, isPinned: false).0.contains(.unseenPersonalMessage))
        XCTAssertFalse(attributes.contains { $0 is ConsumablePersonalMentionMessageAttribute })
    }

    func testIncomingConversionPreservesSelectedEffectAndExistingFlags() {
        let attributes = allMentionIncomingAttributes([EffectMessageAttribute(id: 8100101), NotificationInfoMessageAttribute(flags: .automaticMessage)], isCollective: true, isSilent: true)
        let consumed = allMentionConsumedAttributes(attributes)
        XCTAssertTrue(consumed.contains { ($0 as? EffectMessageAttribute)?.id == 8100101 })
        XCTAssertEqual(consumed.compactMap { $0 as? NotificationInfoMessageAttribute }.count, 1)
        XCTAssertTrue(consumed.contains { ($0 as? NotificationInfoMessageAttribute)?.flags.contains([.automaticMessage, .muted, .personal]) == true })
    }

    func testOrdinaryIncomingMessageDoesNotBecomePersonalMention() {
        let attributes = allMentionIncomingAttributes([], isCollective: false, isSilent: true)
        XCTAssertFalse(tagsForStoreMessage(incoming: true, attributes: attributes, media: [], textEntities: nil, isPinned: false).0.contains(.unseenPersonalMessage))
        XCTAssertFalse(attributes.contains { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.personal) == true })
        XCTAssertTrue(attributes.contains { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.muted) == true })
    }
}
