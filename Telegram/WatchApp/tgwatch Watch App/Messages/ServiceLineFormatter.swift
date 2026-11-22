import Foundation
import TDShim

/// Renders the actor token for a service message:
/// - sender user matches `selfUserId` → "You"
/// - sender user is in `userNames` → first name
/// - otherwise (unknown user or `messageSenderChat`) → "Someone"
private func serviceActor(
    senderId: MessageSender,
    selfUserId: Int64?,
    userNames: [Int64: String]
) -> String {
    if case .messageSenderUser(let u) = senderId {
        if let selfId = selfUserId, u.userId == selfId { return "You" }
        if let name = userNames[u.userId], !name.isEmpty { return name }
    }
    return "Someone"
}

/// Prepends the actor token when `includeActor`, otherwise returns the action
/// with no actor sentence prefix.
private func withActor(_ action: String, actor: String, includeActor: Bool) -> String {
    includeActor ? "\(actor) \(action)" : action
}

/// Bands the seconds value into a human label matching Telegram desktop.
private func autoDeleteDuration(seconds: Int) -> String {
    if seconds < 60 { return "\(seconds)s" }
    if seconds < 3600 { return "\(seconds / 60) min" }
    if seconds < 86400 { return "\(seconds / 3600) h" }
    if seconds < 7 * 86400 {
        let d = seconds / 86400
        return d == 1 ? "1 day" : "\(d) days"
    }
    if seconds < 30 * 86400 {
        let w = seconds / (7 * 86400)
        return w == 1 ? "1 week" : "\(w) weeks"
    }
    let mo = seconds / (30 * 86400)
    return mo == 1 ? "1 month" : "\(mo) months"
}

/// "{m} m" under 1 km, else whole "{km} km".
private func distanceLabel(meters: Int) -> String {
    if meters < 1000 { return "\(meters) m" }
    return "\(meters / 1000) km"
}

/// "channel" when the chat is a broadcast channel; "group" otherwise (incl. nil).
private func groupNoun(_ chatType: ChatType?) -> String {
    if case .chatTypeSupergroup(let s) = chatType, s.isChannel { return "channel" }
    return "group"
}

/// Renders the pinned-snippet phrase used in "{Actor} pinned ...". Returns
/// "«{snippet}»" for text content (with truncation to 24 characters +
/// ellipsis), "a {type}" for non-text recognized content, or "a message" for
/// anything else (including service content where messageBody returns "").
private func pinnedSnippetPhrase(target: CachedMessage?) -> String {
    guard let target else { return "a message" }
    switch target.content {
    case .messageText:
        let body = messageBody(target.content)
        if body.isEmpty { return "a message" }
        if body.count <= 24 {
            return "«\(body)»"
        }
        // Character (extended-grapheme-cluster) prefix — safer than UTF-16
        // truncation for non-ASCII text, and the visual length the reader
        // cares about on a 46mm watch.
        let truncated = body.prefix(24)
        return "«\(truncated)…»"
    case .messagePhoto:    return "a photo"
    case .messageVideo:    return "a video"
    case .messageVideoNote: return "a video message"
    case .messageSticker:  return "a sticker"
    case .messageVoiceNote: return "a voice message"
    case .messageAudio:    return "a music file"
    case .messageDocument: return "a document"
    case .messageLocation: return "a location"
    case .messageVenue:    return "a venue"
    case .messageContact:  return "a contact"
    case .messagePoll:     return "a poll"
    default:               return "a message"
    }
}

/// Resolves a list of user-ids into a single comma-joined string used as the
/// `{Targets}` token in service lines.
///
/// Rules (matches the spec):
/// - empty list → caller handles via a different fallback
/// - one known id → first name
/// - two known ids → "Alice and Bob"
/// - three+ known, or any unknown in the list → "Alice and N other(s)"
/// - all unknown → "N member(s)"
private func targetList(_ ids: [Int64], userNames: [Int64: String]) -> String {
    let known: [String] = ids.compactMap { id in
        guard let n = userNames[id], !n.isEmpty else { return nil }
        return n
    }
    if known.isEmpty {
        return ids.count == 1 ? "1 member" : "\(ids.count) members"
    }
    if ids.count == 1 {
        return known[0]
    }
    if ids.count == 2, known.count == 2 {
        return "\(known[0]) and \(known[1])"
    }
    // Either >=3 ids, or mix of known + unknown.
    let others = ids.count - 1
    let suffix = others == 1 ? "other" : "others"
    return "\(known[0]) and \(others) \(suffix)"
}

/// Renders the centered-italic line for a service message, or `nil` for content
/// that should render as a regular bubble. Pure: same inputs always produce the
/// same output. See `docs/superpowers/specs/2026-05-16-service-messages-design.md`
/// for the original classification and string set, and
/// `docs/superpowers/specs/2026-05-29-extend-service-lines-design.md` for the
/// extended coverage (theme/background/boost/forum-topic/upgrade/game-score/
/// content-protection/sharing/web-app/suggest-photo/proximity/giveaway).
///
/// - Parameters:
///   - msg: the cached message carrying senderId + content payload.
///   - selfUserId: when the actor matches this id, the actor renders as "You".
///   - userNames: per-store cache of `firstName` keyed by user id.
///   - messageCache: window of cached messages for pinned-snippet lookup. Pass
///     `[:]` from contexts (chat-list) where the cache isn't loaded.
///   - includeActor: when `false`, the leading "{Actor} " token is dropped from
///     the rendered line. Used by the chat-list preview in private/secret chats.
///   - chatType: the chat's type, used to distinguish "Channel created" from
///     "Group created" for `messageSupergroupChatCreate` (both channels and
///     supergroups carry that content type). nil → defaults to "Group created".
func serviceLineText(
    _ msg: CachedMessage,
    selfUserId: Int64?,
    userNames: [Int64: String],
    messageCache: [Int64: CachedMessage],
    includeActor: Bool,
    chatType: ChatType? = nil
) -> String? {
    let actor = serviceActor(senderId: msg.senderId, selfUserId: selfUserId, userNames: userNames)

    switch msg.content {
    case .messageContactRegistered:
        return withActor("joined Telegram", actor: actor, includeActor: includeActor)

    case .messageChatJoinByLink, .messageChatJoinByRequest:
        return withActor("joined the chat", actor: actor, includeActor: includeActor)

    case .messageChatAddMembers(let m):
        let senderUserId: Int64? = {
            if case .messageSenderUser(let u) = msg.senderId { return u.userId }
            return nil
        }()
        if m.memberUserIds.isEmpty {
            return withActor("added members", actor: actor, includeActor: includeActor)
        }
        if let s = senderUserId, m.memberUserIds == [s] {
            // Self-add collapses to a join line.
            return withActor("joined the chat", actor: actor, includeActor: includeActor)
        }
        return withActor("added \(targetList(m.memberUserIds, userNames: userNames))",
                         actor: actor, includeActor: includeActor)

    case .messageChatDeleteMember(let m):
        let senderUserId: Int64? = {
            if case .messageSenderUser(let u) = msg.senderId { return u.userId }
            return nil
        }()
        if let s = senderUserId, m.userId == s {
            return withActor("left the chat", actor: actor, includeActor: includeActor)
        }
        if let name = userNames[m.userId], !name.isEmpty {
            return withActor("removed \(name)", actor: actor, includeActor: includeActor)
        }
        return withActor("removed a member", actor: actor, includeActor: includeActor)

    case .messageChatChangeTitle(let m):
        return withActor("changed group name to \"\(m.title)\"", actor: actor, includeActor: includeActor)

    case .messageChatChangePhoto:
        return withActor("changed group photo", actor: actor, includeActor: includeActor)

    case .messageChatDeletePhoto:
        return withActor("removed group photo", actor: actor, includeActor: includeActor)

    case .messagePinMessage(let m):
        let target = messageCache[m.messageId]
        let phrase = pinnedSnippetPhrase(target: target)
        return withActor("pinned \(phrase)", actor: actor, includeActor: includeActor)

    case .messageVideoChatScheduled:
        return withActor("scheduled a video chat", actor: actor, includeActor: includeActor)

    case .messageVideoChatStarted:
        return withActor("started a video chat", actor: actor, includeActor: includeActor)

    case .messageVideoChatEnded(let m):
        // Actor intentionally dropped — TDLib emits one but stock Telegram clients
        // render this without one. includeActor is ignored.
        if m.duration >= 60 {
            let mins = m.duration / 60
            return "Video chat ended (\(mins) min)"
        }
        return "Video chat ended"

    case .messageInviteVideoChatParticipants(let m):
        if m.userIds.isEmpty {
            return withActor("invited members to the video chat", actor: actor, includeActor: includeActor)
        }
        return withActor("invited \(targetList(m.userIds, userNames: userNames)) to the video chat",
                         actor: actor, includeActor: includeActor)

    case .messageScreenshotTaken:
        return withActor("took a screenshot", actor: actor, includeActor: includeActor)

    case .messageChatSetMessageAutoDeleteTime(let m):
        if m.messageAutoDeleteTime == 0 {
            return withActor("disabled auto-delete", actor: actor, includeActor: includeActor)
        }
        let label = autoDeleteDuration(seconds: m.messageAutoDeleteTime)
        return withActor("set messages to auto-delete after \(label)",
                         actor: actor, includeActor: includeActor)

    case .messageCustomServiceAction(let m):
        return m.text

    case .messageBasicGroupChatCreate:
        // Chat-lifecycle event — rendered without an actor (Telegram convention).
        return "Group created"

    case .messageSupergroupChatCreate:
        // Both channels and supergroups carry this content type; the chat type
        // is the only signal for which word to use.
        if case .chatTypeSupergroup(let s) = chatType, s.isChannel {
            return "Channel created"
        }
        return "Group created"

    case .messageForumTopicCreated(let m):
        return withActor("created topic «\(m.name)»", actor: actor, includeActor: includeActor)

    case .messageForumTopicEdited(let m):
        if !m.name.isEmpty {
            return withActor("changed the topic name to «\(m.name)»", actor: actor, includeActor: includeActor)
        }
        if m.editIconCustomEmojiId {
            return withActor("changed the topic icon", actor: actor, includeActor: includeActor)
        }
        return withActor("edited the topic", actor: actor, includeActor: includeActor)

    case .messageForumTopicIsClosedToggled(let m):
        return withActor(m.isClosed ? "closed the topic" : "reopened the topic",
                         actor: actor, includeActor: includeActor)

    case .messageForumTopicIsHiddenToggled(let m):
        return withActor(m.isHidden ? "hid the topic" : "unhid the topic",
                         actor: actor, includeActor: includeActor)

    case .messageChatSetTheme(let m):
        guard let theme = m.theme else {
            return withActor("disabled the chat theme", actor: actor, includeActor: includeActor)
        }
        if case .chatThemeEmoji(let e) = theme {
            return withActor("changed the chat theme to \(e.name)", actor: actor, includeActor: includeActor)
        }
        return withActor("changed the chat theme", actor: actor, includeActor: includeActor)

    case .messageChatSetBackground:
        return withActor("changed the chat background", actor: actor, includeActor: includeActor)

    case .messageChatBoost(let m):
        let noun = groupNoun(chatType)
        if m.boostCount == 1 {
            return withActor("boosted the \(noun)", actor: actor, includeActor: includeActor)
        }
        return withActor("boosted the \(noun) \(m.boostCount) times", actor: actor, includeActor: includeActor)

    case .messageChatHasProtectedContentToggled(let m):
        return withActor(m.newHasProtectedContent ? "enabled content protection" : "disabled content protection",
                         actor: actor, includeActor: includeActor)

    case .messageChatUpgradeTo, .messageChatUpgradeFrom:
        // Chat-lifecycle event — actor-less (Telegram convention), ignores includeActor.
        return "Group upgraded to a supergroup"

    case .messageChatShared:
        return withActor("shared a chat", actor: actor, includeActor: includeActor)

    case .messageUsersShared(let m):
        let action = m.users.count == 1 ? "shared a user" : "shared \(m.users.count) users"
        return withActor(action, actor: actor, includeActor: includeActor)

    case .messageBotWriteAccessAllowed:
        return withActor("allowed this bot to message you", actor: actor, includeActor: includeActor)

    case .messageWebAppDataSent:
        return withActor("sent data to the bot", actor: actor, includeActor: includeActor)

    case .messageSuggestProfilePhoto:
        return withActor("suggested a new profile photo", actor: actor, includeActor: includeActor)

    case .messageGameScore(let m):
        return withActor("scored \(m.score)", actor: actor, includeActor: includeActor)

    case .messageProximityAlertTriggered(let m):
        // Actor-less: the line names traveler + watcher, not the message sender.
        let traveler = serviceActor(senderId: m.travelerId, selfUserId: selfUserId, userNames: userNames)
        let watcher = serviceActor(senderId: m.watcherId, selfUserId: selfUserId, userNames: userNames)
        return "\(traveler) is within \(distanceLabel(meters: m.distance)) of \(watcher)"

    case .messageGiveawayCreated(let m):
        // Actor-less — giveaways are posted by channels.
        return m.starCount > 0 ? "Stars giveaway started" : "Giveaway started"

    case .messageGiveawayCompleted(let m):
        let winners = m.winnerCount == 1 ? "1 winner" : "\(m.winnerCount) winners"
        return "Giveaway ended — \(winners)"

    default:
        return nil
    }
}
