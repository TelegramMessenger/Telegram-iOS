import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences

private struct AllMentionDemoForumCombinedState: Codable {
    var validIndexBoundary: StoredPeerThreadCombinedState.Index?
}

extension AllMentionDemoBootstrap {
    static let forumTopics: [(id: Int64, title: String, color: Int32, messages: [(Int, String)])] = isShowcaseDemo ? AllMentionDemoShowcase.forumTopics : [
        (1, "Общая", 0x6fb9f0, [
            (1, "Создала темы, чтобы планы и полезные места не терялись 👋"),
            (2, "Отлично! Про пятницу пишем в соседнюю тему."),
            (3, "А сюда можно кидать общие вопросы и знакомиться."),
            (5, "Я София, недавно переехала. Рада знакомству!"),
            (6, "Добро пожаловать! В пятницу как раз собираемся вместе 🙌")
        ]),
        (100, "Планы на пятницу", 0xffd67e, [
            (1, "Пятница без дождя! Соберёмся у Калемегдана? ☀️"),
            (2, "Я за прогулку и ужин после. Буду к 19:00."),
            (3, "Тогда встречаемся у главного входа. Столик уточню вечером."),
            (4, "Нас пока восемь. Запишите меня и Машу."),
            (7, "Возьму камеру, на закате там красиво 📷"),
            (1, "Договорились! Финальные детали напишем сюда."),
            (3, "Важные изменения тоже будут в этой теме."),
            (10, "Можно присоединиться чуть позже? Освобожусь около восьми."),
            (1, "Конечно! Кинем точку, когда пойдём дальше."),
            (11, "Тогда и я с вами. Первый раз выбираюсь на общую встречу 🙂"),
            (2, "Здорово! У главного входа легко найти друг друга."),
            (12, "Поеду на трамвае, буду минут за десять до начала."),
            (3, "Я уточняю бронь на террасе. Кажется, всех разместят."),
            (7, "Если похолодает, рядом есть зал внутри."),
            (4, "Отлично, дождусь финального подтверждения."),
            (1, "И я. После прогулки точно захочется горячего чая ☕️"),
            (3, "Как только ответят из кафе — напишу всем сюда.")
        ]),
        (200, "Места и идеи", 0x8eee98, [
            (5, "Нашла уютную кофейню на Дорчоле ☕️"),
            (6, "Там есть столики снаружи? Хочется посидеть на воздухе."),
            (5, "Да! И отличный чизкейк. Можно зайти перед прогулкой."),
            (8, "А в субботу на Земунской набережной будет маркет."),
            (9, "Сохранила. Если пойдёте, напишите сюда 🌿"),
            (2, "Кидаем сюда места для следующих встреч."),
            (10, "Ещё есть хороший маршрут вдоль Дуная, почти без машин."),
            (6, "О, это уже план на воскресенье 🚲"),
            (11, "Велосипед можно взять напрокат рядом с набережной."),
            (5, "Добавила в список. Спасибо!"),
            (8, "Кстати, маркет работает только до пяти."),
            (9, "Тогда лучше идти днём, а потом выпить кофе."),
            (12, "Посмотрю погоду ближе к выходным."),
            (2, "Здесь соберём все варианты, а время обсудим отдельно.")
        ])
    ]

    static var incomingTopicId: Int64? {
        guard isForumDemo else { return nil }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--all-mention-demo-topic"), arguments.indices.contains(index + 1),
           let id = Int64(arguments[index + 1]), forumTopics.contains(where: { $0.id == id }) { return id }
        return 100
    }

    static func seedForumIfNeeded(transaction: Transaction, now: Int32) {
        if let existing = transaction.getPeer(forumPeerId) {
            AllMentionDemoForumChronology.repair(transaction: transaction, peerId: forumPeerId, maxSeedId: Int32(forumTopics.map { $0.id + Int64($0.messages.count) }.max()!))
            // Upgrade the first forum fixture without replacing its conversation,
            // permission, quota, read boundaries or scheduled queue.
            if let channel = existing as? TelegramChannel, channel.defaultBannedRights == nil {
                updatePeersCustom(transaction: transaction, peers: [channel.withUpdatedDefaultBannedRights(TelegramChatBannedRights(flags: [], untilDate: Int32.max))], update: { _, updated in updated })
            }
            return
        }
        let channel = TelegramChannel(id: forumPeerId, accessHash: .personal(0), title: isShowcaseDemo ? "Weekend Trip · topics" : "Пятница в Белграде · темы", username: nil, photo: [], creationDate: now - 86400 * 7, version: 1, participationStatus: .member, info: .group(TelegramChannelGroupInfo(flags: [])), flags: [.isCreator, .isForum], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: TelegramChatBannedRights(flags: [], untilDate: Int32.max), usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
        updatePeersCustom(transaction: transaction, peers: [channel], update: { _, updated in updated })
        transaction.updatePeerCachedData(peerIds: [forumPeerId], update: { _, _ in
            return CachedChannelData().withUpdatedAbout(isShowcaseDemo ? "Plans, tickets and ideas for our weekend away." : "Планы на пятницу, новые места и общение. Вымышленная группа с темами для проверки @all без реальных аккаунтов.")
                .withUpdatedParticipantsSummary(CachedChannelParticipantsSummary(memberCount: isShowcaseDemo ? Int32(AllMentionDemoShowcase.names.count) : 24, adminCount: 1, bannedCount: 0, kickedCount: 0))
                .withUpdatedReactionSettings(.known(PeerReactionSettings(allowedReactions: .all, maxReactionCount: nil, starsAllowed: false)))
        })
        let tags: [MessageTags] = [.photoOrVideo, .file, .music, .webPage, .voiceOrInstantVideo, .unseenPersonalMessage, .unseenReaction, .unseenPollVote, .pinned]
        var topId: Int32 = 0
        for (topicIndex, topic) in forumTopics.enumerated() {
            let rootId = Int32(topic.id)
            let timestamp = now - 14400 + Int32(topicIndex * 3600)
            var messages = [makeMessage(id: rootId, authorId: selfPeerId, text: "", timestamp: timestamp, attributes: [], media: [TelegramMediaAction(action: .topicCreated(title: topic.title, iconColor: topic.color, iconFileId: nil))], threadId: topic.id, peerId: forumPeerId)]
            for (offset, entry) in topic.messages.enumerated() {
                messages.append(makeMessage(id: rootId + Int32(offset) + 1, authorId: userPeerId(entry.0), text: entry.1, timestamp: timestamp + Int32((offset + 1) * 90), attributes: [], media: [], threadId: topic.id, peerId: forumPeerId))
            }
            let lastId = rootId + Int32(topic.messages.count)
            topId = max(topId, lastId)
            let _ = transaction.addMessages(messages, location: .UpperHistoryBlock)
            let data = MessageHistoryThreadData(creationDate: timestamp, isOwnedByMe: true, author: selfPeerId, info: .init(title: topic.title, icon: nil, iconColor: topic.color), incomingUnreadCount: 0, isMarkedUnread: false, maxIncomingReadId: lastId, maxKnownMessageId: lastId, maxOutgoingReadId: lastId, isClosed: false, isHidden: false, notificationSettings: .defaultSettings, isMessageFeeRemoved: false)
            transaction.setMessageHistoryThreadInfo(peerId: forumPeerId, threadId: topic.id, info: AllMentionDemoForumState.stored(data))
            for namespace in [Namespaces.Message.Cloud, Namespaces.Message.ScheduledCloud] {
                transaction.removeHole(peerId: forumPeerId, threadId: topic.id, namespace: namespace, space: .everywhere, range: 1 ... (Int32.max - 1))
            }
            for tag in tags {
                transaction.removeHole(peerId: forumPeerId, threadId: topic.id, namespace: Namespaces.Message.Cloud, space: .tag(tag), range: 1 ... (Int32.max - 1))
                transaction.replaceMessageTagSummary(peerId: forumPeerId, threadId: topic.id, tagMask: tag, namespace: Namespaces.Message.Cloud, customTag: nil, count: 0, maxId: lastId)
            }
        }
        for namespace in [Namespaces.Message.Cloud, Namespaces.Message.ScheduledCloud] {
            transaction.removeHole(peerId: forumPeerId, threadId: nil, namespace: namespace, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
        for tag in tags {
            transaction.removeHole(peerId: forumPeerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .tag(tag), range: 1 ... (Int32.max - 1))
            transaction.replaceMessageTagSummary(peerId: forumPeerId, threadId: nil, tagMask: tag, namespace: Namespaces.Message.Cloud, customTag: nil, count: 0, maxId: topId)
        }
        let boundary = StoredPeerThreadCombinedState.Index(timestamp: 0, threadId: 0, messageId: 1)
        transaction.setPeerThreadCombinedState(peerId: forumPeerId, state: StoredPeerThreadCombinedState(data: CodableEntry(AllMentionDemoForumCombinedState(validIndexBoundary: boundary))!, validIndexBoundary: boundary))
        transaction.setPeerPinnedThreads(peerId: forumPeerId, threadIds: [1])
        transaction.setPeerChatState(forumPeerId, state: ChannelState(pts: 0, invalidatedPts: nil, synchronizedUntilMessageId: topId))
        transaction.resetIncomingReadStates([forumPeerId: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: topId, maxOutgoingReadId: topId, maxKnownId: topId, count: 0, markedUnread: false)]])
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: forumPeerId), { _ in PreferencesEntry(AllMentionGroupPermission()) })
        transaction.updatePreferencesEntry(key: forumStoreStateKey, { _ in PreferencesEntry(AllMentionDemoStoreState(recipientIntroDelivered: true)) })
        transaction.updatePeerChatListInclusion(forumPeerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: 1, minTimestamp: nil))
    }
}
