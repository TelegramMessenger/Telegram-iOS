import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext
import TextFormat
import AppBundle

/// An isolated, offline account for reviewing the proposal in the actual Telegram client.
/// It never opens the normal account-manager directory or creates a network-backed send.
enum AllMentionDemoBootstrap {
    static var isEnabled: Bool {
        return AllMentionDemoConfiguration.isEnabled
    }

    static let selfPeerId = AllMentionDemoConfiguration.accountPeerId
    static let groupPeerId = AllMentionDemoConfiguration.groupPeerId
    static let forumPeerId = AllMentionDemoConfiguration.forumPeerId
    static let forumStoreStateKey = applicationSpecificPreferencesKey(0x414c4d)
    static var selectedPeerId: PeerId { return isForumDemo ? forumPeerId : groupPeerId }
    static let isShowcaseDemo: Bool = {
        let arguments = ProcessInfo.processInfo.arguments
        let key = "AllMentionDemo.showcase.v1"
        let legacyRequested = arguments.contains("--all-mention-demo-qa") ||
            (!arguments.contains("--all-mention-demo-showcase") &&
             (arguments.contains("--all-mention-demo-forum") || arguments.contains("--all-mention-demo-regular")))
        let value = arguments.contains("--all-mention-demo-showcase") ||
            (!legacyRequested && (UserDefaults.standard.object(forKey: key) as? Bool ?? true))
        if isEnabled { UserDefaults.standard.set(value, forKey: key) }
        return value
    }()
    static let isForumDemo: Bool = {
        let key = isShowcaseDemo ? "AllMentionDemo.showcaseForum.v1" : "AllMentionDemo.forum.v1"
        let arguments = ProcessInfo.processInfo.arguments
        let value = arguments.contains("--all-mention-demo-forum") || (!arguments.contains("--all-mention-demo-regular") && UserDefaults.standard.bool(forKey: key))
        if isEnabled { UserDefaults.standard.set(value, forKey: key) }
        return value
    }()
    static let storeStateKey = applicationSpecificPreferencesKey(0x414c4c)

    private static let launchMode: AllMentionDemoLaunchMode = {
        let key = isShowcaseDemo ? "AllMentionDemo.showcaseLaunchMode.v1" : "AllMentionDemo.launchMode.v1"
        let mode = AllMentionDemoLaunchMode.selected(arguments: ProcessInfo.processInfo.arguments, previous: UserDefaults.standard.string(forKey: key))
        if isEnabled { UserDefaults.standard.set(mode.rawValue, forKey: key) }
        return mode
    }()

    static var isRecipientDemo: Bool {
        return isEnabled && launchMode == .recipient
    }

    static var isSilentRecipientDemo: Bool {
        return isRecipientDemo && ProcessInfo.processInfo.arguments.contains("--all-mention-demo-silent")
    }

    static func rootPath(in basePath: String) -> String {
        precondition(isEnabled)
        do {
            return try AllMentionDemoStorage.root(in: basePath, reset: ProcessInfo.processInfo.arguments.contains("--all-mention-demo-reset"), showcase: isShowcaseDemo)
        } catch {
            preconditionFailure("Cannot open the isolated @all demo store: \(error). Use --all-mention-demo-reset to start a new demo without deleting the old store.")
        }
    }

    static func prepare(accountManager: AccountManager<TelegramAccountManagerTypes>, rootPath: String, encryptionParameters: ValueBoxEncryptionParameters) -> Signal<AccountRecordId, NoError> {
        precondition(isEnabled)
        precondition(AllMentionDemoStorage.contains(rootPath: rootPath, in: URL(fileURLWithPath: rootPath).deletingLastPathComponent().deletingLastPathComponent().path))
        return accountManager.transaction { modifier -> AccountRecordId in
            applyLocalizationIfRequested(modifier: modifier)
            let proxy = ProxyServerSettings(host: "127.0.0.1", port: 1, connection: .socks5(username: nil, password: nil))
            let _ = updateProxySettingsInteractively(transaction: modifier, { _ in
                return ProxySettings(enabled: true, servers: [proxy], activeServer: proxy, useForCalls: false)
            })
            if let current = modifier.getCurrent() { return current.0 }
            if let existing = modifier.getRecords().sorted(by: { $0.id < $1.id }).first { return existing.id }
            return modifier.createRecord([
                .environment(AccountEnvironmentAttribute(environment: .production)),
                .sortOrder(AccountSortOrderAttribute(order: 0))
            ])
        }
        |> mapToSignal { recordId -> Signal<AccountRecordId, NoError> in
            let now = Int32(Date().timeIntervalSince1970)
            let path = rootPath + "/" + accountRecordIdPathName(recordId) + "/postbox"
            return openPostbox(basePath: path, seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryptionParameters, timestampForAbsoluteTimeBasedOperations: now, isMainProcess: false, isTemporary: false, isReadOnly: false, useCopy: false, useCaches: false, removeDatabaseOnError: false)
            |> mapToSignal { result -> Signal<AccountRecordId, NoError> in
                switch result {
                case let .postbox(postbox):
                    return postbox.transaction { transaction -> Bool in
                        if let state = transaction.getState() {
                            guard let state = state as? AuthorizedAccountState, state.peerId == selfPeerId else {
                                preconditionFailure("The isolated demo store contains an unexpected account")
                            }
                            return false
                        }
                        precondition(transaction.getPreferencesEntry(key: storeStateKey) == nil, "The existing demo state is incomplete; refusing to reseed it")
                        return true
                    }
                    |> mapToSignal { needsSeed -> Signal<Void, NoError> in
                        let media = needsSeed ? seedMedia(postbox: postbox) : [:]
                        return postbox.transaction { transaction -> Void in
                            if needsSeed { seed(transaction: transaction, media: media, now: now) }
                            seedForumIfNeeded(transaction: transaction, now: now)
                            let arguments = ProcessInfo.processInfo.arguments
                            if let index = arguments.firstIndex(of: "--all-mention-demo-forum-scenario"), arguments.indices.contains(index + 1) {
                                AllMentionDemoForumScenario.apply(transaction: transaction, scenario: arguments[index + 1])
                            }
                            // Old launches already contained a reviewed conversation;
                            // adopting one must not inject another introductory call.
                            let state = transaction.getPreferencesEntry(key: storeStateKey)?.get(AllMentionDemoStoreState.self)
                                ?? AllMentionDemoStoreState(recipientIntroDelivered: !needsSeed)
                            transaction.updatePreferencesEntry(key: storeStateKey, { _ in PreferencesEntry(state) })
                        }
                    }
                    |> mapToSignal { _ in
                        return accountManager.transaction { modifier -> AccountRecordId in
                            modifier.removeAuth()
                            modifier.setCurrentId(recordId)
                            let arguments = ProcessInfo.processInfo.arguments
                            if let index = arguments.firstIndex(of: "--all-mention-demo-language"), arguments.indices.contains(index + 1), arguments[index + 1] == "restore" {
                                UserDefaults.standard.removeObject(forKey: "AllMentionDemo.originalLocalization.v1")
                            }
                            return recordId
                        }
                    }
                case .upgrading:
                    return .complete()
                case .error:
                    preconditionFailure("Cannot create the isolated @all demonstration Postbox")
                }
            }
            |> take(1)
        }
    }

    static func userPeerId(_ index: Int) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(9_100_000 + Int64(index)))
    }

    // Explicit offline QA only. Use the normal LocalizationSettings pipeline and
    // bundled strings, retaining the original language pack for `restore`.
    private struct LocalizationSnapshot: Codable {
        let settings: LocalizationSettings?
    }

    private static func applyLocalizationIfRequested(modifier: AccountManagerModifier<TelegramAccountManagerTypes>) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--all-mention-demo-language"), arguments.indices.contains(index + 1) else { return }
        let language = arguments[index + 1]
        let backupKey = "AllMentionDemo.originalLocalization.v1"
        if language == "restore" {
            guard let data = UserDefaults.standard.data(forKey: backupKey), let snapshot = try? JSONDecoder().decode(LocalizationSnapshot.self, from: data) else { return }
            modifier.updateSharedData(SharedDataKeys.localizationSettings, { _ in
                if let settings = snapshot.settings {
                    return PreferencesEntry(settings)
                } else {
                    return nil
                }
            })
            return
        }
        guard getAppBundle().localizations.contains(language),
              let path = getAppBundle().path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language),
              let dictionary = NSDictionary(contentsOfFile: path) as? [String: String], dictionary["AllMention.SuggestionTitle"] != nil else { return }
        if UserDefaults.standard.data(forKey: backupKey) == nil {
            let snapshot = LocalizationSnapshot(settings: modifier.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self))
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(data, forKey: backupKey)
        }
        let component = LocalizationComponent(languageCode: language, localizedName: Locale(identifier: language).localizedString(forLanguageCode: language) ?? language, localization: Localization(version: 0, entries: []), customPluralizationCode: nil)
        modifier.updateSharedData(SharedDataKeys.localizationSettings, { _ in
            return PreferencesEntry(LocalizationSettings(primaryComponent: component, secondaryComponent: nil))
        })
    }

    private static func seed(transaction: Transaction, media: [Int: Media], now: Int32) {
        // One bundled Telegram animation makes the native effect picker usable
        // offline, without a real account or downloaded effect catalog.
        if let file = media[101] as? TelegramMediaFile {
            let effect = AvailableMessageEffects.MessageEffect(id: 8_100_101, isPremium: false, emoticon: "🎉", staticIcon: nil, effectSticker: TelegramMediaFile.Accessor(file), effectAnimation: TelegramMediaFile.Accessor(file))
            let key = ValueBoxKey(length: 8)
            key.setInt64(0, value: 0)
            if let entry = CodableEntry(AvailableMessageEffects(hash: 0, messageEffects: [effect])) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.availableMessageEffects, key: key), entry: entry)
            }
        }
        let names: [(String, String)] = isShowcaseDemo ? AllMentionDemoShowcase.names : [
            ("Александр", "Морозов"), ("Мария", "Волкова"), ("Денис", "Соколов"),
            ("Анна", "Лебедева"), ("Илья", "Орлов"), ("София", "Белова"),
            ("Максим", "Козлов"), ("Полина", "Новикова"), ("Артём", "Крылов"),
            ("Даша", "Зайцева"), ("Михаил", "Власов"), ("Катя", "Фомина"),
            ("Никита", "Павлов"), ("Оля", "Егорова"), ("Лев", "Титов"),
            ("Лена", "Громова"), ("Андрей", "Данилов"), ("Вера", "Романова"),
            ("Саша", "Федотова"), ("Глеб", "Миронов"), ("Алиса", "Кузнецова"),
            ("Роман", "Быков"), ("Настя", "Смирнова"), ("Кирилл", "Васильев")
        ]
        var peers: [Peer] = names.enumerated().map { index, name in
            return TelegramUser(id: userPeerId(index), accessHash: nil, firstName: name.0, lastName: name.1, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: .preset(PeerNameColor(rawValue: Int32(index % 7))), backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
        }
        peers.append(TelegramGroup(id: groupPeerId, title: isShowcaseDemo ? "Weekend Trip" : "Пятница в Белграде", photo: [], participantCount: names.count, role: .creator(rank: nil), membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: now - 86_400 * 30, version: 1))
        updatePeersCustom(transaction: transaction, peers: peers, update: { _, updated in updated })
        var presences: [PeerId: PeerPresence] = [:]
        for index in names.indices {
            let status: UserPresenceStatus = (1 ... 7).contains(index) ? .present(until: now + 3_600) : .recently(isHidden: false)
            presences[userPeerId(index)] = TelegramUserPresence(status: status, lastActivity: now - Int32(index * 120))
        }
        transaction.updatePeerPresencesInternal(presences: presences, merge: { _, updated in updated })
        transaction.setState(AuthorizedAccountState(isTestingEnvironment: false, masterDatacenterId: 2, peerId: selfPeerId, state: AuthorizedAccountState.State(pts: 0, qts: 0, date: now, seq: 0), invalidatedChannels: []))
        let participants: [GroupParticipant] = names.indices.map { index in
            if index == 0 {
                return .creator(id: selfPeerId, rank: nil)
            } else {
                return .member(id: userPeerId(index), invitedBy: selfPeerId, invitedAt: now - 86_400 * 7, rank: nil)
            }
        }
        transaction.updatePeerCachedData(peerIds: [groupPeerId], update: { _, _ in
            return CachedGroupData()
                .withUpdatedParticipants(CachedGroupParticipants(participants: participants, version: 1))
                .withUpdatedAbout(isShowcaseDemo ? "Tickets, packing lists and plans for our weekend away." : "Гуляем, находим новые места и договариваемся о пятнице. Все участники и сообщения в этом демо вымышлены.")
                .withUpdatedPinnedMessageId(isShowcaseDemo ? nil : messageId(10))
                .withUpdatedReactionSettings(.known(PeerReactionSettings(allowedReactions: .all, maxReactionCount: nil, starsAllowed: false)))
        })

        let conversation: [(Int, String)] = isShowcaseDemo ? AllMentionDemoShowcase.conversation : [
            (1, "Ребята, кто в пятницу за прогулку? Кажется, дождя не будет ☀️"),
            (2, "Я за! Можно начать с Калемегдана и потом спуститься к воде."),
            (3, "Отличный план. Я после работы, примерно к 19:00."),
            (0, "Давайте в 19:00 у входа со стороны Кнез-Михаиловой."),
            (4, "Буду! Возьму камеру 📷"),
            (5, "А кто знает хорошее место поужинать на набережной?"),
            (1, "Есть небольшое кафе у Бетон-халы. В прошлый раз всем понравилось."),
            (6, "Только давайте забронируем заранее, в пятницу там много людей."),
            (7, "Нас пока восемь? Я буду с Лёвой."),
            (0, "Пятница · 19:00\nВстречаемся у Калемегдана → идём на набережную → ужинаем вместе 🌅"),
            (8, "Я тоже с вами. На ужин точно останусь."),
            (9, "Супер, я освобожусь чуть позже и догоню у воды."),
            (2, "Вчера как раз проходил там. Вот какой был свет:"),
            (2, ""),
            (1, "Очень красиво! Ради такого заката стоит выбраться из дома."),
            (3, "Я уточнила в кафе: большой стол есть на 20:30."),
            (0, "Отлично, давай пока на десятерых. До вечера ещё подтянутся."),
            (4, "Вид с набережной вчера. Надеюсь, в пятницу повезёт так же ✨"),
            (10, "Плюс один! Буду к семи."),
            (1, ""),
            (2, "Да, у главного входа удобно. Я буду на месте чуть раньше."),
            (3, "Кто ещё с нами? Напишите до 18:00, пожалуйста — подтвержу бронь 🙌")
        ]
        var messages: [StoreMessage] = []
        for (offset, item) in conversation.enumerated() {
            let id = Int32(offset + 1)
            var attributes: [MessageAttribute] = []
            if id == 7 || id == 17 || id == 21 {
                let replyId: Int32 = id == 7 ? 6 : (id == 17 ? 16 : 4)
                attributes.append(ReplyMessageAttribute(messageId: messageId(replyId), threadMessageId: nil, quote: nil, isQuote: false, innerSubject: nil))
            }
            if id == 10 || id == 15 || id == 18 {
                attributes.append(ReactionsMessageAttribute(canViewList: true, isTags: false, reactions: [MessageReaction(value: .builtin(id == 18 ? "❤" : "👍"), count: id == 10 ? 8 : 4, chosenOrder: nil)], recentPeers: [], topPeers: []))
            }
            let timestamp = isShowcaseDemo ? now - Int32((conversation.count - offset) * 70) : (id <= 14 ? now - 86_400 + Int32(offset * 75) : now - Int32((conversation.count - offset) * 65))
            messages.append(makeMessage(id: id, authorId: userPeerId(item.0), text: item.1, timestamp: timestamp, attributes: attributes, media: media[Int(id)].map { [$0] } ?? []))
        }
        let _ = transaction.addMessages(messages, location: .UpperHistoryBlock)
        transaction.removeHole(peerId: groupPeerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
        for namespace in Namespaces.Message.allScheduled {
            transaction.removeHole(peerId: groupPeerId, threadId: nil, namespace: namespace, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
        for tag in MessageTags.all {
            transaction.removeHole(peerId: groupPeerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .tag(tag), range: 1 ... (Int32.max - 1))
        }
        let lastSeedId = Int32(conversation.count)
        transaction.resetIncomingReadStates([groupPeerId: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: lastSeedId, maxOutgoingReadId: lastSeedId, maxKnownId: lastSeedId, count: 0, markedUnread: false)]])
        transaction.replaceMessageTagSummary(peerId: groupPeerId, threadId: nil, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: 0, maxId: lastSeedId)
        if isRecipientDemo {
            transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: groupPeerId), { _ in PreferencesEntry(AllMentionGroupPermission(isEnabled: true)) })
            if ProcessInfo.processInfo.arguments.contains("--all-mention-demo-muted") {
                transaction.updateCurrentPeerNotificationSettings([groupPeerId: TelegramPeerNotificationSettings.defaultSettings.withUpdatedMuteState(.muted(until: Int32.max))])
            }
            if ProcessInfo.processInfo.arguments.contains("--all-mention-demo-author-muted") {
                transaction.updateCurrentPeerNotificationSettings([userPeerId(3): TelegramPeerNotificationSettings.defaultSettings.withUpdatedMuteState(.muted(until: Int32.max))])
            }
        }
        transaction.updatePeerChatListInclusion(groupPeerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: 0, minTimestamp: nil))
        // The normal seed starts with a cloud-dialog hole. Leaving it here would
        // make the genuine root controller wait for an offline dialogs request.
        if let hole = telegramPostboxSeedConfiguration.initializeChatListWithHole.topLevel {
            transaction.replaceChatListHole(groupId: .root, index: hole.index, hole: nil)
        }
        if let hole = telegramPostboxSeedConfiguration.initializeChatListWithHole.groups {
            transaction.replaceChatListHole(groupId: .group(1), index: hole.index, hole: nil)
        }
    }

    static func messageId(_ id: Int32, peerId: PeerId = groupPeerId) -> MessageId {
        return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
    }

    static func makeMessage(id: Int32, authorId: PeerId, text: String, timestamp: Int32, attributes: [MessageAttribute], media: [Media], groupingKey: Int64? = nil, threadId: Int64? = nil, namespace: Int32 = Namespaces.Message.Cloud, peerId: PeerId = groupPeerId, forwardInfo: StoreMessageForwardInfo? = nil) -> StoreMessage {
        var flags: StoreMessageFlags = namespace == Namespaces.Message.Cloud ? [.TopIndexable, .ReactionsArePossible] : []
        if authorId != selfPeerId {
            flags.insert(.Incoming)
        }
        var tags = tagsForStoreMessage(incoming: authorId != selfPeerId, attributes: attributes, media: media, textEntities: nil, isPinned: false).0
        if media.contains(where: { $0 is TelegramMediaImage }) {
            tags.formUnion([.photoOrVideo, .photo])
        }
        if media.contains(where: { ($0 as? TelegramMediaFile)?.isVoice == true }) {
            tags.formUnion([.voiceOrInstantVideo, .voice])
        }
        if !isShowcaseDemo && peerId == groupPeerId && id == 10 && namespace == Namespaces.Message.Cloud {
            tags.insert(.pinned)
        }
        if namespace != Namespaces.Message.Cloud {
            // Dates may be reordered by rescheduling; let Postbox allocate the
            // queue id instead of deriving it from the latest message's date.
            return StoreMessage(peerId: peerId, namespace: namespace, customStableId: nil, globallyUniqueId: nil, groupingKey: groupingKey, threadId: threadId, timestamp: timestamp, flags: flags, tags: tags, globalTags: [], localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: text, attributes: attributes, media: media)
        }
        return StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: groupingKey, threadId: threadId, timestamp: timestamp, flags: flags, tags: tags, globalTags: [], localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: text, attributes: attributes, media: media)
    }

    private static func seedMedia(postbox: Postbox) -> [Int: Media] {
        var result: [Int: Media] = [:]
        if let url = Bundle.main.url(forResource: "Celebrate", withExtension: "tgs"), let data = try? Data(contentsOf: url) {
            let resource = LocalFileMediaResource(fileId: 8_100_101, size: Int64(data.count))
            postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
            result[101] = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 8_100_101), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: Int64(data.count), attributes: [.FileName(fileName: "Celebrate.tgs"), .Sticker(displayText: "🎉", packReference: nil, maskData: nil), .ImageSize(size: PixelDimensions(width: 512, height: 512)), .Animated], alternativeRepresentations: [])
        }
        if isShowcaseDemo { return result }
        let photoURL = Bundle.main.url(forResource: "all-mention-belgrade", withExtension: "jpg") ?? Bundle.main.url(forResource: "all-mention-belgrade", withExtension: "jpg", subdirectory: "Resources")
        if let url = photoURL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            let resource = LocalFileMediaResource(fileId: 8_100_018, size: Int64(data.count))
            postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
            result[18] = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: 8_100_018), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(image.size.width * image.scale), height: Int32(image.size.height * image.scale)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        }
        for (id, duration) in [(14, 12), (20, 18)] {
            let data = voiceData(duration: duration)
            let resource = LocalFileMediaResource(fileId: 8_100_000 + Int64(id), size: Int64(data.count))
            postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
            // This is a generated local sound, not a recording of a real person.
            result[id] = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 8_100_000 + Int64(id)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/wav", size: Int64(data.count), attributes: [.FileName(fileName: "demo-voice.wav"), .Audio(isVoice: true, duration: duration, title: nil, performer: nil, waveform: waveform())], alternativeRepresentations: [])
        }
        return result
    }

    private static func voiceData(duration: Int) -> Data {
        let sampleRate = 8_000
        let byteCount = duration * sampleRate * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2))
        append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(byteCount))
        for index in 0 ..< duration * sampleRate {
            let time = Double(index) / Double(sampleRate)
            let envelope = min(1.0, time * 4.0) * min(1.0, (Double(duration) - time) * 4.0)
            let sample = Int16(sin(time * 2.0 * .pi * 220.0) * 800.0 * envelope * (0.55 + 0.45 * sin(time * 3.0)))
            append(UInt16(bitPattern: sample))
        }
        return data
    }

    private static func waveform() -> Data {
        var data = Data(repeating: 0, count: 63)
        for index in 0 ..< 100 {
            let value = UInt8(4 + abs(sin(Double(index) * 0.47) * cos(Double(index) * 0.13)) * 26)
            let bit = index * 5
            data[bit / 8] |= value << (bit % 8)
            if bit % 8 > 3 {
                data[bit / 8 + 1] |= value >> (8 - bit % 8)
            }
        }
        return data
    }
}

/// Uses Telegram's history, composer, bubbles, media player and Postbox. All mutations
/// are direct local transactions; neither enqueueMessages nor edit/delete uses an engine request.
struct AllMentionDemoRateLimitFailure {
    let correlationIds: [Int64]
    let reason: AllMentionSendBlockReason
    let isScheduledDelivery: Bool
    let destinationFailure: AllMentionDemoDestinationFailure?

    init(correlationIds: [Int64], reason: AllMentionSendBlockReason = .rateLimit, isScheduledDelivery: Bool = false, destinationFailure: AllMentionDemoDestinationFailure? = nil) {
        self.correlationIds = correlationIds
        self.reason = reason
        self.isScheduledDelivery = isScheduledDelivery
        self.destinationFailure = destinationFailure
    }
}

private enum AllMentionDemoEnqueueResult {
    case sent(MessageId?)
    case scheduled
    case rateLimited(AllMentionDemoRateLimitFailure)
}

final class AllMentionDemoChatContents: ChatAllMentionDemoContents {
    let kind: ChatCustomContentsKind = .allMentionDemo
    private let permissionValue = Atomic(value: false)
    private let permissionPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    var canMentionAll: Bool { return self.permissionValue.with { $0 } }
    var canMentionAllUpdated: Signal<Bool, NoError> { return self.permissionPromise.get() }
    var memberCount: Int { AllMentionDemoBootstrap.isShowcaseDemo ? AllMentionDemoShowcase.names.count : 24 }
    let messageLimit: Int? = nil
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
    let peerId: PeerId
    private let account: Account
    private let disposables = DisposableSet()
    private let messageEffectSentPipe = ValuePipe<MessageId>()
    private let rateLimitFailurePipe = ValuePipe<AllMentionDemoRateLimitFailure>()
    private let incomingNotificationPipe = ValuePipe<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)]>()
    var incomingNotifications: Signal<[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)], NoError> { return self.incomingNotificationPipe.signal() }
    private var recipientTimer: SwiftSignalKit.Timer?
    private var recipientDemoStarted = false
    private var scheduledMessages: [Message] = []
    private var scheduledTimer: SwiftSignalKit.Timer?
    private var scheduledDeliveryTransactions = 0
    private var foregroundObserver: NSObjectProtocol?


    var rateLimitFailures: Signal<AllMentionDemoRateLimitFailure, NoError> { return self.rateLimitFailurePipe.signal() }

    var messageEffectSent: Signal<MessageId, NoError> {
        return self.messageEffectSentPipe.signal()
    }

    init(account: Account, peerId: PeerId = AllMentionDemoBootstrap.groupPeerId) {
        precondition(AllMentionDemoBootstrap.isEnabled)
        precondition(account.peerId == AllMentionDemoBootstrap.selfPeerId)
        self.peerId = peerId
        self.account = account
        self.disposables.add((allMentionGroupPermission(postbox: account.postbox, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] isEnabled in
            guard let self else { return }
            let _ = self.permissionValue.swap(isEnabled)
            self.permissionPromise.set(isEnabled)
        }))
        self.disposables.add((account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: self.peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 2000, trackHoles: false, clipHoles: false, ignoreRelatedChats: true, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .just([Namespaces.Message.ScheduledCloud]), orderStatistics: [])
        |> deliverOnMainQueue).start(next: { [weak self] view, _, _ in
            self?.scheduledMessages = view.entries.map { $0.message }
            self?.updateScheduledTimer()
        }))
        self.foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: { [weak self] _ in self?.updateScheduledTimer() })
    }

    deinit {
        self.disposables.dispose()
        self.scheduledTimer?.invalidate()
        self.recipientTimer?.invalidate()
        if let observer = self.foregroundObserver { NotificationCenter.default.removeObserver(observer) }
    }

    var historyView: Signal<(EngineRawMessageHistoryView, EngineViewUpdateType), NoError> {
        return self.account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: self.peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 200, trackHoles: false, clipHoles: false, ignoreRelatedChats: true, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .just([Namespaces.Message.Cloud]), orderStatistics: [])
        |> map { view, updateType, _ in (view, updateType) }
    }

    private var storeStateKey: ValueBoxKey { return self.peerId == AllMentionDemoBootstrap.forumPeerId ? AllMentionDemoBootstrap.forumStoreStateKey : AllMentionDemoBootstrap.storeStateKey }

    func startRecipientDemo() {
        guard AllMentionDemoBootstrap.isRecipientDemo, !self.recipientDemoStarted else { return }
        self.recipientDemoStarted = true
        self.disposables.add((self.account.postbox.transaction { transaction in
            let state = transaction.getPreferencesEntry(key: self.storeStateKey)?.get(AllMentionDemoStoreState.self) ?? AllMentionDemoStoreState()
            return !state.recipientIntroDelivered || ProcessInfo.processInfo.arguments.contains("--all-mention-demo-incoming")
        } |> deliverOnMainQueue).start(next: { [weak self] shouldDeliver in
            if shouldDeliver { self?.scheduleRecipientCall() }
        }))
    }

    private func scheduleRecipientCall() {
        let timer = SwiftSignalKit.Timer(timeout: 8.0, repeat: false, completion: { [weak self] in
            self?.receiveDemoCall(silent: AllMentionDemoBootstrap.isSilentRecipientDemo, threadId: AllMentionDemoBootstrap.incomingTopicId)
        }, queue: .mainQueue())
        self.recipientTimer = timer
        timer.start()
    }

    private func receiveDemoCall(silent: Bool, threadId: Int64?) {
        self.disposables.add((self.account.postbox.transaction { transaction -> [([Message], PeerGroupId, Bool, MessageHistoryThreadData?)] in
            let now = Date().timeIntervalSince1970
            let peerId = self.peerId
            let state = transaction.getPreferencesEntry(key: self.storeStateKey)?.get(AllMentionDemoStoreState.self) ?? AllMentionDemoStoreState()
            guard !state.recipientIntroDelivered || ProcessInfo.processInfo.arguments.contains("--all-mention-demo-incoming") else { return [] }
            let permission = allMentionGroupState(transaction: transaction, peerId: peerId)
            guard let reserved = permission.reservingCall(at: now) else { return [] }
            let text = AllMentionDemoBootstrap.isShowcaseDemo ? "@all We're leaving in 5 minutes!" : "@all Бронь подтвердила! Встречаемся в 19:00 у главного входа 🙌"
            let entities = allMentionEntitiesForLocalDemo(text: text, entities: [], isEnabled: true)
            let attributes = allMentionIncomingAttributes([TextEntitiesMessageAttribute(entities: entities)], isCollective: true, isSilent: silent)
            let id = (transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)?.id ?? 22) + 1
            let author = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(9_100_003))
            let _ = transaction.addMessages([AllMentionDemoBootstrap.makeMessage(id: id, authorId: author, text: text, timestamp: Int32(now), attributes: attributes, media: [], threadId: threadId, peerId: self.peerId)], location: .UpperHistoryBlock)
            AllMentionDemoForumState.recordIncoming(transaction: transaction, peerId: self.peerId, threadId: threadId, messageId: id)
            transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: peerId), { _ in PreferencesEntry(reserved) })
            transaction.updatePreferencesEntry(key: self.storeStateKey, { _ in PreferencesEntry(state.recordingRecipientIntro()) })
            self.updateMentionSummary(transaction)
            let notification = messagesForNotification(transaction: transaction, id: AllMentionDemoBootstrap.messageId(id, peerId: self.peerId), alwaysReturnMessage: false)
            return notification.messages.isEmpty ? [] : [(notification.messages, .root, notification.notify, notification.threadData)]
        } |> deliverOnMainQueue).start(next: { [weak self] notifications in
            if !notifications.isEmpty { self?.incomingNotificationPipe.putNext(notifications) }
        }))
    }

    private func updateMentionSummary(_ transaction: Transaction) {
        let peerId = self.peerId
        if peerId == AllMentionDemoBootstrap.forumPeerId {
            for threadId in AllMentionDemoBootstrap.forumTopics.map({ $0.id }) {
                let count = transaction.getMessageIndicesWithTag(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, tag: .unseenPersonalMessage).count
                let topId = transaction.getMessageHistoryThreadTopMessage(peerId: peerId, threadId: threadId, namespaces: [Namespaces.Message.Cloud])?.id.id ?? Int32(threadId)
                transaction.replaceMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: Int32(count), maxId: topId)
            }
        }
        let count = transaction.getMessageIndicesWithTag(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, tag: .unseenPersonalMessage).count
        let topId = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)?.id ?? 22
        transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: Int32(count), maxId: topId)
    }

    func markHistoryRead(through index: MessageIndex, threadId: Int64? = nil) {
        guard index.id.peerId == self.peerId, index.id.namespace == Namespaces.Message.Cloud else { return }
        self.disposables.add(self.account.postbox.transaction { transaction in
            if self.peerId == AllMentionDemoBootstrap.forumPeerId {
                guard let threadId else { return }
                AllMentionDemoForumState.markRead(transaction: transaction, peerId: self.peerId, threadId: threadId, through: index)
            } else {
                transaction.applyIncomingReadMaxId(index.id)
            }
        }.start())
    }

    func consumeMentions(ids: Set<MessageId>? = nil, threadId: Int64? = nil, playEffect: Bool = true) {
        self.disposables.add((self.account.postbox.transaction { transaction -> [MessageId] in
            let requested = ids ?? Set(transaction.getMessageIndicesWithTag(peerId: self.peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, tag: .unseenPersonalMessage).map { $0.id })
            var consumed: [MessageId] = []
            for id in requested where id.peerId == self.peerId && id.namespace == Namespaces.Message.Cloud {
                guard let message = transaction.getMessage(id), message.flags.contains(.Incoming), message.tags.contains(.unseenPersonalMessage), threadId == nil || message.threadId == threadId else { continue }
                let collective = Self.hasCollectiveMention(message.attributes)
                transaction.updateMessage(id, update: { current in
                    var tags = current.tags
                    tags.remove(.unseenPersonalMessage)
                    return .update(StoreMessage(id: current.id, customStableId: nil, globallyUniqueId: current.globallyUniqueId, groupingKey: current.groupingKey, threadId: current.threadId, timestamp: current.timestamp, flags: StoreMessageFlags(current.flags), tags: tags, globalTags: current.globalTags, localTags: current.localTags, forwardInfo: current.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: current.author?.id, text: current.text, attributes: allMentionConsumedAttributes(current.attributes), media: current.media))
                })
                transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: nil)
                if collective { consumed.append(id) }
            }
            self.updateMentionSummary(transaction)
            return consumed
        } |> deliverOnMainQueue).start(next: { [weak self] consumed in
            if playEffect, let id = consumed.first { self?.messageEffectSentPipe.putNext(id) }
        }))
    }

    func enqueueMessages(messages: [EnqueueMessage]) {
        self.enqueueMessages(messages: messages, onScheduled: nil)
    }

    func enqueueMessages(messages: [EnqueueMessage], onScheduled: (() -> Void)?) {
        self.disposables.add((self.account.postbox.transaction { transaction -> AllMentionDemoEnqueueResult in
            let timestamp = Date().timeIntervalSince1970
            let scheduleInfo = messages.flatMap { message -> [MessageAttribute] in
                switch message {
                case let .message(_, attributes, _, _, _, _, _, _, _, _): return attributes
                case let .forward(_, _, _, attributes, _): return attributes
                }
            }.compactMap { $0 as? OutgoingScheduleInfoMessageAttribute }.first
            let namespace = scheduleInfo == nil ? Namespaces.Message.Cloud : Namespaces.Message.ScheduledCloud
            let permission = allMentionGroupState(transaction: transaction, peerId: self.peerId)
            let canMentionAll = permission.isEnabled
            // Reserve once for the complete send, in the same transaction as the
            // messages. A rejected batch stores nothing and never clears the draft.
            let callsEveryone = canMentionAll && messages.contains(where: { message in
                if case let .message(text, attributes, _, _, _, _, _, _, _, _) = message {
                    return Self.hasCollectiveMention(Self.collectiveMentionAttributes(text: text, attributes: attributes, isEnabled: true))
                }
                return false
            })
            if scheduleInfo == nil {
                for message in messages {
                    let target: (Int64?, Bool)
                    switch message {
                    case let .message(text, _, _, _, threadId, _, _, _, _, _): target = (threadId, !text.isEmpty)
                    case let .forward(source, threadId, _, _, _): target = (threadId, !(transaction.getMessage(source)?.text.isEmpty ?? true))
                    }
                    if let failure = AllMentionDemoScheduledDestination.failure(transaction: transaction, peerId: self.peerId, threadId: target.0, hasText: target.1) {
                        let correlations = messages.compactMap { message -> Int64? in
                            switch message {
                            case let .message(_, _, _, _, _, _, _, _, id, _): return id
                            case let .forward(_, _, _, _, id): return id
                            }
                        }
                        return .rateLimited(AllMentionDemoRateLimitFailure(correlationIds: correlations, destinationFailure: failure))
                    }
                }
            }
            if callsEveryone && scheduleInfo == nil {
                guard let reserved = permission.reservingCall(at: timestamp) else {
                    let correlationIds = messages.compactMap { message -> Int64? in
                        if case let .message(_, _, _, _, _, _, _, _, correlationId, _) = message { return correlationId }
                        return nil
                    }
                    return .rateLimited(AllMentionDemoRateLimitFailure(correlationIds: correlationIds))
                }
                transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: self.peerId), { _ in PreferencesEntry(reserved) })
            }
            var nextId = (transaction.getTopPeerMessageId(peerId: self.peerId, namespace: namespace)?.id ?? 0) + 1
            var stored: [StoreMessage] = []
            var sentEffectMessageId: MessageId?
            for message in messages {
                switch message {
                case let .message(text, attributes, _, mediaReference, threadId, reply, _, groupingKey, correlationId, bubbleUpEmojiOrStickersets):
                    var attributes = allMentionLocalOutgoingAttributes(Self.collectiveMentionAttributes(text: text, attributes: attributes, isEnabled: canMentionAll), keepSchedule: scheduleInfo != nil)
                    let hasAllMention = Self.hasCollectiveMention(attributes)
                    // Telegram matches the composer snapshot to this id before
                    // clearing its text. Acknowledged + no .Unsent flag keeps the
                    // message delivered locally without entering the send manager.
                    attributes.append(OutgoingMessageInfoAttribute(uniqueId: Int64.random(in: 1 ..< Int64.max), flags: [], acknowledged: true, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets, partialReference: nil))
                    if let reply {
                        attributes.append(ReplyMessageAttribute(messageId: reply.messageId, threadMessageId: nil, quote: reply.quote, isQuote: reply.quote != nil, innerSubject: reply.innerSubject))
                    }
                    stored.append(AllMentionDemoBootstrap.makeMessage(id: nextId, authorId: AllMentionDemoBootstrap.selfPeerId, text: text, timestamp: scheduleInfo?.scheduleTime ?? Int32(timestamp), attributes: attributes, media: mediaReference.map { [$0.media] } ?? [], groupingKey: groupingKey, threadId: threadId, namespace: namespace, peerId: self.peerId))
                    if scheduleInfo == nil && (hasAllMention || attributes.contains(where: { $0 is EffectMessageAttribute })) && sentEffectMessageId == nil {
                        sentEffectMessageId = AllMentionDemoBootstrap.messageId(nextId, peerId: self.peerId)
                    }
                    nextId += 1
                case let .forward(source, threadId, _, attributes, correlationId):
                    if let original = transaction.getMessage(source) {
                        stored.append(AllMentionDemoMessageReuse.forward(original: original, id: MessageId(peerId: self.peerId, namespace: namespace, id: nextId), threadId: threadId, timestamp: scheduleInfo?.scheduleTime ?? Int32(timestamp), authorId: AllMentionDemoBootstrap.selfPeerId, attributes: attributes, correlationId: correlationId))
                        nextId += 1
                    }
                }
            }
            let _ = transaction.addMessages(stored, location: .UpperHistoryBlock)
            if scheduleInfo != nil {
                self.updateScheduledPresence(transaction)
                return .scheduled
            }
            self.recordOutgoing(transaction: transaction, stored: stored, topId: nextId - 1)
            return .sent(sentEffectMessageId)
        }
        |> deliverOnMainQueue).start(next: { [weak self] result in
            switch result {
            case let .sent(messageId):
                if let messageId { self?.messageEffectSentPipe.putNext(messageId) }
            case .scheduled:
                onScheduled?()
            case let .rateLimited(failure):
                self?.rateLimitFailurePipe.putNext(failure)
            }
        }))
    }

    private func recordOutgoing(transaction: Transaction, stored: [StoreMessage], topId: Int32) {
        if self.peerId == AllMentionDemoBootstrap.forumPeerId {
            for message in stored {
                if case let .Id(id) = message.id {
                    AllMentionDemoForumState.recordOutgoing(transaction: transaction, peerId: self.peerId, threadId: message.threadId, messageId: id.id)
                }
            }
        } else {
            transaction.resetIncomingReadStates([self.peerId: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: topId, maxOutgoingReadId: topId, maxKnownId: topId, count: 0, markedUnread: false)]])
        }
    }

    private func updateScheduledTimer() {
        self.scheduledTimer?.invalidate()
        self.scheduledTimer = nil
        guard self.scheduledDeliveryTransactions == 0, let next = self.scheduledMessages.filter({ !$0.flags.contains(.Failed) }).map({ $0.timestamp }).min() else { return }
        let timer = SwiftSignalKit.Timer(timeout: max(0.2, TimeInterval(next) - Date().timeIntervalSince1970), repeat: false, completion: { [weak self] in self?.deliverScheduledMessages() }, queue: .mainQueue())
        self.scheduledTimer = timer
        timer.start()
    }

    private func updateScheduledPresence(_ transaction: Transaction) {
        let hasScheduled = transaction.getTopPeerMessageId(peerId: self.peerId, namespace: Namespaces.Message.ScheduledCloud) != nil
        transaction.updatePeerCachedData(peerIds: [self.peerId], update: { _, previous in
            if let previous = previous as? CachedChannelData { return previous.withUpdatedHasScheduledMessages(hasScheduled) }
            return ((previous as? CachedGroupData) ?? CachedGroupData()).withUpdatedHasScheduledMessages(hasScheduled)
        })
    }

    private static func scheduledAttributes(_ message: Message) -> [MessageAttribute] {
        let original = message.attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.flatMap { $0.entities }
        let entities = allMentionEntitiesForScheduledDemoDelivery(text: message.text, entities: original)
        return allMentionLocalOutgoingAttributes(message.attributes, keepSchedule: false).filter { !($0 is TextEntitiesMessageAttribute) } + [TextEntitiesMessageAttribute(entities: entities)]
    }

    private static func copyScheduled(_ message: Message, timestamp: Int32? = nil, attributes: [MessageAttribute]? = nil, flags: StoreMessageFlags? = nil) -> StoreMessage {
        return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: timestamp ?? message.timestamp, flags: flags ?? StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: attributes ?? message.attributes, media: message.media)
    }

    func deliverScheduledMessages(ids requestedIds: [MessageId]? = nil, force: Bool = false) {
        guard force || self.scheduledDeliveryTransactions == 0 else { return }
        self.scheduledDeliveryTransactions += 1
        let knownIds = self.scheduledMessages.map { $0.id }
        let requested = Set(requestedIds ?? knownIds)
        self.disposables.add((self.account.postbox.transaction { transaction -> ([MessageId], [AllMentionDemoRateLimitFailure]) in
            let now = Date().timeIntervalSince1970
            let groupingKeys = Set(requested.compactMap { transaction.getMessage($0)?.groupingKey })
            var pending = Set(knownIds).union(requested).compactMap { transaction.getMessage($0) }.filter {
                $0.id.peerId == self.peerId && $0.id.namespace == Namespaces.Message.ScheduledCloud && (requested.contains($0.id) || $0.groupingKey.map { groupingKeys.contains($0) } == true)
            }.sorted { $0.timestamp == $1.timestamp ? $0.id.id < $1.id.id : $0.timestamp < $1.timestamp }
            var effects: [MessageId] = []
            var failures: [AllMentionDemoRateLimitFailure] = []
            while let first = pending.first {
                let group = first.groupingKey.map { key in pending.filter { $0.groupingKey == key } } ?? [first]
                let ids = Set(group.map { $0.id })
                pending.removeAll { ids.contains($0.id) }
                if let reason = AllMentionDemoScheduledDestination.rejectUnavailableBatch(transaction: transaction, messages: group, timestamp: now, force: force) {
                    failures.append(AllMentionDemoRateLimitFailure(correlationIds: [], isScheduledDelivery: true, destinationFailure: reason))
                    continue
                }
                let attributes = group.map(Self.scheduledAttributes)
                let requiresCollective = attributes.contains(where: Self.hasCollectiveMention)
                let permission = allMentionGroupState(transaction: transaction, peerId: self.peerId)
                switch allMentionScheduledDeliveryDecision(scheduleTime: first.timestamp, timestamp: now, requiresCollectiveMention: requiresCollective, hasFailed: group.contains { $0.flags.contains(.Failed) }, force: force, permission: permission) {
                case .wait:
                    continue
                case let .blocked(reason):
                    for message in group {
                        transaction.updateMessage(message.id, update: { original in
                            return .update(Self.copyScheduled(original, flags: StoreMessageFlags(original.flags).union(.Failed)))
                        })
                    }
                    failures.append(AllMentionDemoRateLimitFailure(correlationIds: [], reason: reason, isScheduledDelivery: true))
                case let .deliver(reserved):
                    if reserved != permission {
                        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: self.peerId), { _ in PreferencesEntry(reserved) })
                    }
                    var nextId = (transaction.getTopPeerMessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud)?.id ?? 0) + 1
                    var stored: [StoreMessage] = []
                    var effectId: MessageId?
                    for (index, message) in group.enumerated() {
                        var messageAttributes = attributes[index]
                        messageAttributes.append(OutgoingMessageInfoAttribute(uniqueId: Int64.random(in: 1 ..< Int64.max), flags: [], acknowledged: true, correlationId: nil, bubbleUpEmojiOrStickersets: [], partialReference: nil))
                        stored.append(AllMentionDemoBootstrap.makeMessage(id: nextId, authorId: AllMentionDemoBootstrap.selfPeerId, text: message.text, timestamp: Int32(now), attributes: messageAttributes, media: message.media, groupingKey: message.groupingKey, threadId: message.threadId, peerId: self.peerId, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init)))
                        if effectId == nil && (Self.hasCollectiveMention(messageAttributes) || messageAttributes.contains { $0 is EffectMessageAttribute }) {
                            effectId = AllMentionDemoBootstrap.messageId(nextId, peerId: self.peerId)
                        }
                        nextId += 1
                        if let info = message.attributes.compactMap({ $0 as? OutgoingScheduleInfoMessageAttribute }).first, let period = info.repeatPeriod, period > 0 {
                            // Skip missed repetitions after suspension rather than
                            // producing a burst of overdue collective calls.
                            let next = Int32(clamping: max(Int64(info.scheduleTime) + Int64(period), Int64(now) + Int64(period)))
                            let queued = message.attributes.filter { !($0 is OutgoingScheduleInfoMessageAttribute) } + [OutgoingScheduleInfoMessageAttribute(scheduleTime: next, repeatPeriod: period)]
                            transaction.updateMessage(message.id, update: { original in .update(Self.copyScheduled(original, timestamp: next, attributes: queued)) })
                        } else {
                            transaction.deleteMessages([message.id], forEachMedia: nil)
                        }
                    }
                    let _ = transaction.addMessages(stored, location: .UpperHistoryBlock)
                    self.recordOutgoing(transaction: transaction, stored: stored, topId: nextId - 1)
                    if let effectId { effects.append(effectId) }
                }
            }
            self.updateScheduledPresence(transaction)
            return (effects, failures)
        }
        |> deliverOnMainQueue).start(next: { [weak self] effects, failures in
            guard let self else { return }
            self.scheduledDeliveryTransactions -= 1
            for id in effects { self.messageEffectSentPipe.putNext(id) }
            for failure in failures { self.rateLimitFailurePipe.putNext(failure) }
            self.updateScheduledTimer()
        }))
    }

    func rescheduleMessages(ids: [MessageId], time: Int32, repeatPeriod: Int32?, silentPosting: Bool? = nil) {
        self.disposables.add(self.account.postbox.transaction { transaction -> Void in
            for id in ids where id.peerId == self.peerId && id.namespace == Namespaces.Message.ScheduledCloud {
                transaction.updateMessage(id, update: { original in
                    var attributes = original.attributes.filter { !($0 is OutgoingScheduleInfoMessageAttribute) }
                    if let silentPosting {
                        var notificationFlags = attributes.compactMap { $0 as? NotificationInfoMessageAttribute }.first?.flags ?? []
                        if silentPosting { notificationFlags.insert(.muted) } else { notificationFlags.remove(.muted) }
                        attributes.removeAll { $0 is NotificationInfoMessageAttribute }
                        if !notificationFlags.isEmpty { attributes.append(NotificationInfoMessageAttribute(flags: notificationFlags)) }
                    }
                    attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: time, repeatPeriod: repeatPeriod))
                    var flags = StoreMessageFlags(original.flags)
                    flags.remove(.Failed)
                    return .update(Self.copyScheduled(original, timestamp: time, attributes: attributes, flags: flags))
                })
            }
        }.start())
    }

    private static func hasCollectiveMention(_ attributes: [MessageAttribute]) -> Bool {
        return attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.contains { attribute in
            attribute.entities.contains { $0.type == .Custom(type: ApplicationSpecificEntityType.AllMention) }
        }
    }

    func deleteMessages(ids: [EngineMessage.Id]) {
        self.disposables.add(self.account.postbox.transaction { transaction -> Void in
            transaction.deleteMessages(ids.filter { $0.peerId == self.peerId }, forEachMedia: nil)
            self.updateScheduledPresence(transaction)
        }.start())
    }

    private static func collectiveMentionAttributes(text: String, attributes: [MessageAttribute], isEnabled: Bool) -> [MessageAttribute] {
        let originalEntities = attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.flatMap { $0.entities }
        let entities = allMentionEntitiesForLocalDemo(text: text, entities: originalEntities, isEnabled: isEnabled)
        guard entities != originalEntities else { return attributes }
        return attributes.filter { !($0 is TextEntitiesMessageAttribute) } + [TextEntitiesMessageAttribute(entities: entities)]
    }

    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
        guard id.peerId == self.peerId else { return }
        self.disposables.add(self.account.postbox.transaction { transaction -> Void in
            AllMentionDemoMessageReuse.edit(transaction: transaction, peerId: self.peerId, id: id, text: text, media: media, entities: entities, webpagePreviewAttribute: webpagePreviewAttribute)
        }.start())
    }

    func updateReactions(messageId: MessageId, reactions: [UpdateMessageReaction]) {
        guard messageId.peerId == self.peerId else { return }
        let selected = reactions.map { $0.reaction }
        self.disposables.add(self.account.postbox.transaction { transaction -> Void in
            transaction.updateMessage(messageId, update: { original in
                let previous = original.attributes.compactMap { $0 as? ReactionsMessageAttribute }.first
                var updated: [MessageReaction] = []
                for reaction in previous?.reactions ?? [] {
                    let wasSelected = reaction.chosenOrder != nil
                    let selectedIndex = selected.firstIndex(of: reaction.value)
                    let count = reaction.count - (wasSelected ? 1 : 0) + (selectedIndex != nil ? 1 : 0)
                    if count > 0 {
                        updated.append(MessageReaction(value: reaction.value, count: count, chosenOrder: selectedIndex))
                    }
                }
                for (index, reaction) in selected.enumerated() where !updated.contains(where: { $0.value == reaction }) {
                    updated.append(MessageReaction(value: reaction, count: 1, chosenOrder: index))
                }
                var attributes = original.attributes.filter { !($0 is ReactionsMessageAttribute) && !($0 is PendingReactionsMessageAttribute) }
                attributes.append(ReactionsMessageAttribute(canViewList: true, isTags: false, reactions: updated, recentPeers: previous?.recentPeers ?? [], topPeers: previous?.topPeers ?? []))
                return .update(StoreMessage(id: original.id, customStableId: nil, globallyUniqueId: original.globallyUniqueId, groupingKey: original.groupingKey, threadId: original.threadId, timestamp: original.timestamp, flags: StoreMessageFlags(original.flags), tags: original.tags, globalTags: original.globalTags, localTags: original.localTags, forwardInfo: nil, authorId: original.author?.id, text: original.text, attributes: attributes, media: original.media))
            })
        }.start())
    }

    func quickReplyUpdateShortcut(value: String) {}
    func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {}
    func loadMore() {}
    func hashtagSearchUpdate(query: String) {}
}
