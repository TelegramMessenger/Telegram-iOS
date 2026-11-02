import XCTest
import TelegramCore
@testable import TranslateUI

final class ChatTranslationPeerChoiceTests: XCTestCase {
    private func channel(id: Int64 = 1234, flags: TelegramChannelFlags) -> EnginePeer {
        return .channel(TelegramChannel(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(id)), accessHash: nil, title: "Forum", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .group(TelegramChannelGroupInfo(flags: [])), flags: flags, restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil))
    }
    
    private func state(fromLang: String = "es", toLang: String? = nil, isEnabled: Bool) -> ChatTranslationState {
        return ChatTranslationState(baseLang: "en", fromLang: fromLang, timestamp: 100, toLang: toLang, isEnabled: isEnabled)
    }
    
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1234))
    
    func testForumTopicsShareThePeersChoice() {
        XCTAssertTrue(chatTranslationSharesPeerChoice(peer: self.channel(flags: [.isForum])))
        XCTAssertTrue(chatTranslationSharesPeerChoice(peer: self.channel(flags: [])))
        XCTAssertTrue(chatTranslationSharesPeerChoice(peer: nil))
    }
    
    func testMonoforumThreadsKeepTheirOwnChoice() {
        XCTAssertFalse(chatTranslationSharesPeerChoice(peer: self.channel(flags: [.isMonoforum])))
    }
    
    func testPeerChoiceReplacesALocationsOwnChoiceButNotItsDetectedLanguage() {
        let topicB = self.state(fromLang: "de", toLang: nil, isEnabled: false)
        let applied = topicB.withPeerChoice(ChatTranslationPeerChoice(isEnabled: true, toLang: "fr"))
        XCTAssertTrue(applied.isEnabled)
        XCTAssertEqual(applied.toLang, "fr")
        XCTAssertEqual(applied.fromLang, "de")
        XCTAssertEqual(applied.baseLang, "en")
        XCTAssertEqual(applied.timestamp, 100)
        
        let disabled = self.state(isEnabled: true).withPeerChoice(ChatTranslationPeerChoice(isEnabled: false, toLang: nil))
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertNil(disabled.toLang)
    }
    
    func testWithoutAPeerChoiceALocationKeepsItsOwn() {
        let topic = self.state(toLang: "it", isEnabled: true).withPeerChoice(nil)
        XCTAssertTrue(topic.isEnabled)
        XCTAssertEqual(topic.toLang, "it")
    }
    
    func testATopicTranslatedBeforeTheChoiceWasSharedEnablesThePeer() {
        XCTAssertEqual(chatTranslationPeerChoiceToMigrate(locationState: self.state(toLang: "it", isEnabled: true), peerChoice: nil), ChatTranslationPeerChoice(isEnabled: true, toLang: "it"))
        XCTAssertNil(chatTranslationPeerChoiceToMigrate(locationState: self.state(isEnabled: false), peerChoice: nil))
    }
    
    func testAStoredPeerChoiceIsNeverOverriddenByATopicsOldState() {
        XCTAssertNil(chatTranslationPeerChoiceToMigrate(locationState: self.state(isEnabled: true), peerChoice: ChatTranslationPeerChoice(isEnabled: false, toLang: nil)))
    }
    
    func testPeerChoiceKeyCollidesWithNoLocationKey() {
        let choiceKey = chatTranslationPeerChoiceKey(peerId: self.peerId)
        XCTAssertNotEqual(choiceKey, chatTranslationStateKey(peerId: self.peerId, threadId: nil))
        XCTAssertNotEqual(choiceKey, chatTranslationStateKey(peerId: self.peerId, threadId: 1))
        XCTAssertNotEqual(choiceKey, chatTranslationStateKey(peerId: self.peerId, threadId: 256))
        XCTAssertEqual(choiceKey, chatTranslationPeerChoiceKey(peerId: self.peerId))
        
        let otherPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1235))
        XCTAssertNotEqual(choiceKey, chatTranslationPeerChoiceKey(peerId: otherPeerId))
        let userWithTheSameId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1234))
        XCTAssertNotEqual(choiceKey, chatTranslationPeerChoiceKey(peerId: userWithTheSameId))
    }
    
    func testLocationKeysAreUnchanged() {
        let peerKey = chatTranslationStateKey(peerId: self.peerId, threadId: nil)
        XCTAssertEqual(peerKey.length, 8)
        XCTAssertEqual(peerKey.getInt64(0), 1234)
        let topicKey = chatTranslationStateKey(peerId: self.peerId, threadId: 7)
        XCTAssertEqual(topicKey.length, 16)
        XCTAssertEqual(topicKey.getInt64(0), 1234)
        XCTAssertEqual(topicKey.getInt64(8), 7)
    }
    
    func testPeerChoiceRoundTripsThroughTheItemCacheCoding() {
        for choice in [ChatTranslationPeerChoice(isEnabled: true, toLang: "fr"), ChatTranslationPeerChoice(isEnabled: false, toLang: nil)] {
            XCTAssertEqual(EngineCodableEntry(choice)?.get(ChatTranslationPeerChoice.self), choice)
        }
    }
    
    func testATopicInTheTargetLanguageIsShownUntranslatedOfferingTheBaseLanguage() {
        for (fromLang, toLang) in [("fr", "fr"), ("pt", "pt-br"), ("en", nil)] as [(String, String?)] {
            let topic = effectiveChatTranslationState(self.state(fromLang: fromLang, toLang: "it", isEnabled: true), peerChoice: ChatTranslationPeerChoice(isEnabled: true, toLang: toLang))
            XCTAssertFalse(topic.isEnabled, fromLang)
            XCTAssertNil(topic.toLang, fromLang)
            XCTAssertEqual(topic.fromLang, fromLang)
        }
        
        let spanishTopic = effectiveChatTranslationState(self.state(fromLang: "es", isEnabled: false), peerChoice: ChatTranslationPeerChoice(isEnabled: true, toLang: "fr"))
        XCTAssertTrue(spanishTopic.isEnabled)
        XCTAssertEqual(spanishTopic.toLang, "fr")
        XCTAssertEqual(spanishTopic.fromLang, "es")
    }
    
    func testWithoutAPeerChoiceTheLocationStateIsShownAsBefore() {
        let state = self.state(fromLang: "en", isEnabled: true)
        XCTAssertEqual(effectiveChatTranslationState(state, peerChoice: nil), state)
    }
    
    func testDoNotTranslateInAChatWithoutTopicsTurnsTheChatsTranslationOff() {
        XCTAssertTrue(chatTranslationDiscardsPeerChoice(peer: self.channel(flags: []), threadId: nil))
        XCTAssertTrue(chatTranslationDiscardsPeerChoice(peer: nil, threadId: nil))
    }
    
    func testDoNotTranslateInOneTopicKeepsTheOtherTopicsTranslating() {
        XCTAssertFalse(chatTranslationDiscardsPeerChoice(peer: self.channel(flags: [.isForum]), threadId: 3))
        XCTAssertFalse(chatTranslationDiscardsPeerChoice(peer: self.channel(flags: [.isForum]), threadId: nil))
        XCTAssertFalse(chatTranslationDiscardsPeerChoice(peer: self.channel(flags: []), threadId: 100))
    }
}
