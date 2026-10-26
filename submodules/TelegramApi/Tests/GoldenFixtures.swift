import Foundation
@testable import TelegramApi

private func text(_ s: String, bold: Bool) -> Api.TextWithEntities {
    return .textWithEntities(Api.TextWithEntities.Cons_textWithEntities(
        text: s,
        entities: bold ? [.messageEntityBold(Api.MessageEntity.Cons_messageEntityBold(offset: 0, length: 2))] : []
    ))
}

private func user(phone: String?) -> Api.User {
    // flags: accessHash(0) firstName(1) phone(4, only when present); flags2 = 0
    let flags: Int32 = (1 << 0) | (1 << 1) | (phone != nil ? (1 << 4) : 0)
    return .user(Api.User.Cons_user(
        flags: flags, flags2: 0, id: 1000, accessHash: 77, firstName: "Ann", lastName: nil,
        username: nil, phone: phone, photo: nil, status: nil, botInfoVersion: nil,
        restrictionReason: nil, botInlinePlaceholder: nil, langCode: nil, emojiStatus: nil,
        usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, botActiveUsers: nil,
        botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedCommunityId: nil
    ))
}

let goldenFixtures: [(name: String, value: Any)] = [
    // optional scalars/strings/object all present (flags bits 1,2,3,4,5) + creator true-flag (bit 0)
    ("aiComposeTone.full", Api.AiComposeTone.aiComposeTone(Api.AiComposeTone.Cons_aiComposeTone(
        flags: 0b111111, id: 1, accessHash: 2, slug: "slug", title: "Tone",
        emojiId: 5, prompt: "prompt", installsCount: 7, authorId: 8,
        exampleEnglish: .aiComposeToneExample(Api.AiComposeToneExample.Cons_aiComposeToneExample(
            from: text("hi", bold: true), to: text("привет 👋", bold: false)))
    ))),
    // all optionals absent
    ("aiComposeTone.empty", Api.AiComposeTone.aiComposeTone(Api.AiComposeTone.Cons_aiComposeTone(
        flags: 0, id: 1, accessHash: 2, slug: "", title: "", emojiId: nil, prompt: nil,
        installsCount: nil, authorId: nil, exampleEnglish: nil
    ))),
    // present optional scalars whose value is zero (Review Focus 2)
    ("aiComposeTone.presentZero", Api.AiComposeTone.aiComposeTone(Api.AiComposeTone.Cons_aiComposeTone(
        flags: (1 << 1) | (1 << 2), id: 0, accessHash: 0, slug: "s", title: "t", emojiId: 0,
        prompt: nil, installsCount: 0, authorId: nil, exampleEnglish: nil
    ))),
    // `long` field name, Double, optional Int32
    ("inputGeoPoint", Api.InputGeoPoint.inputGeoPoint(Api.InputGeoPoint.Cons_inputGeoPoint(
        flags: 1, lat: 55.75, long: 37.62, accuracyRadius: 25
    ))),
    // `id` field name + Buffer
    ("inputDocument", Api.InputDocument.inputDocument(Api.InputDocument.Cons_inputDocument(
        id: 42, accessHash: -3, fileReference: Buffer(data: Data([0x00, 0xff, 0x10]))
    ))),
    // `protocol` field name, Buffer, nested object with [String] and true-flags
    ("phoneCallAccepted", Api.PhoneCall.phoneCallAccepted(Api.PhoneCall.Cons_phoneCallAccepted(
        flags: 1 << 6, id: 9, accessHash: 10, date: 11, adminId: 12, participantId: 13,
        gB: Buffer(data: Data([1, 2, 3, 4])),
        protocol: .phoneCallProtocol(Api.PhoneCallProtocol.Cons_phoneCallProtocol(
            flags: 3, minLayer: 65, maxLayer: 92, libraryVersions: ["11.0.0", "12.0.0"]))
    ))),
    // [Buffer]
    ("messagePeerVoteMultiple", Api.MessagePeerVote.messagePeerVoteMultiple(Api.MessagePeerVote.Cons_messagePeerVoteMultiple(
        peer: .peerUser(Api.Peer.Cons_peerUser(userId: 5)),
        options: [Buffer(data: Data([1])), Buffer(data: Data([2, 3]))], date: 100
    ))),
    // [Int32] (non-empty and empty)
    ("todoCompletions", Api.MessageAction.messageActionTodoCompletions(Api.MessageAction.Cons_messageActionTodoCompletions(
        completed: [1, 2, -3], incompleted: []
    ))),
    // [Int64] + String, and an empty [Int64]
    ("chatCreate", Api.MessageAction.messageActionChatCreate(Api.MessageAction.Cons_messageActionChatCreate(
        title: "Group", users: [1, Int64.max]
    ))),
    ("chatCreate.empty", Api.MessageAction.messageActionChatCreate(Api.MessageAction.Cons_messageActionChatCreate(
        title: "", users: []
    ))),
    // fieldless enum values nested in a payload
    ("noForwardsToggle", Api.MessageAction.messageActionNoForwardsToggle(Api.MessageAction.Cons_messageActionNoForwardsToggle(
        prevValue: .boolFalse, newValue: .boolTrue
    ))),
    // `description` field name
    ("botCommand", Api.BotCommand.botCommand(Api.BotCommand.Cons_botCommand(
        flags: 0, command: "start", description: "Start the bot"
    ))),
    // `hash` field name, [Api.User] with a phone (nested redaction), empty [AttachMenuBot]
    ("attachMenuBots", Api.AttachMenuBots.attachMenuBots(Api.AttachMenuBots.Cons_attachMenuBots(
        hash: 123456789, bots: [], users: [user(phone: "+15550100"), user(phone: nil)]
    ))),
    // top-level redaction (InputContact.inputPhoneContact → phone)
    ("inputPhoneContact", Api.InputContact.inputPhoneContact(Api.InputContact.Cons_inputPhoneContact(
        flags: 0, clientId: 1, phone: "+15550199", firstName: "Bob", lastName: "", note: nil
    ))),
    // top-level redaction (Updates.updateShortMessage → message) + nested vector of enums
    ("updateShortMessage", Api.Updates.updateShortMessage(Api.Updates.Cons_updateShortMessage(
        flags: 1 << 7, id: 1, userId: 2, message: "secret text", pts: 3, ptsCount: 1, date: 4,
        fwdFrom: nil, viaBotId: nil, replyTo: nil,
        entities: [.messageEntityBold(Api.MessageEntity.Cons_messageEntityBold(offset: 0, length: 6))],
        ttlPeriod: nil
    ))),
]
