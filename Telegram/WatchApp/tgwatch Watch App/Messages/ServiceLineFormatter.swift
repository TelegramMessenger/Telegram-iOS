import Foundation
import TDShim

/// The actor of a service message, as named in its line.
private enum ServiceActor {
    /// Sender user matches `selfUserId`; `name` is the user's own first name.
    case you(name: String?)
    /// Sender user is in `userNames` (first name).
    case named(String)
    /// Unknown user or `messageSenderChat`.
    case someone

    /// The name substituted into a line's actor placeholder. Like the iOS
    /// app, the current user is named too: the templates are written for a
    /// third-person name, and "You" there breaks verb agreement in many
    /// languages. Lines with a dedicated sentence for the current user pass
    /// it as `you:` instead.
    var name: String {
        switch self {
        case .you(let name): return name ?? L("DialogList.You")
        case .named(let name): return name
        case .someone: return L("Watch.Service.Someone")
        }
    }
}

/// Resolves the actor for a service message:
/// - sender user matches `selfUserId` → `.you` (with the user's first name)
/// - sender user is in `userNames` → first name
/// - otherwise (unknown user or `messageSenderChat`) → "Someone"
private func serviceActor(
    senderId: MessageSender,
    selfUserId: Int64?,
    userNames: [Int64: String]
) -> ServiceActor {
    if case .messageSenderUser(let u) = senderId {
        if let selfId = selfUserId, u.userId == selfId {
            let name = userNames[selfId].flatMap { $0.isEmpty ? nil : $0 }
            return .you(name: name)
        }
        if let name = userNames[u.userId], !name.isEmpty { return .named(name) }
    }
    return .someone
}

/// Renders a service line from its localized templates.
///
/// - `key`: the sentence with the actor; its first placeholder is the actor's
///   name, followed by `args`.
/// - `noActor`: the same sentence without the actor (placeholders: `args`),
///   used when `includeActor` is false. Lines that only occur in groups and
///   channels (where the chat list always includes the actor) pass nil and
///   keep the actor.
/// - `you`: optional sentence for when the actor is the current user
///   (placeholders: `args`).
/// - `count`: when set, the templates are plural keys selected by `count`.
private func serviceLine(
    _ key: String,
    noActor noActorKey: String?,
    you youKey: String? = nil,
    count: Int? = nil,
    actor: ServiceActor,
    includeActor: Bool,
    _ args: CustomStringConvertible...
) -> String {
    return serviceLine(key, noActor: noActorKey, you: youKey, count: count,
                       actor: actor, includeActor: includeActor, args: args)
}

private func serviceLine(
    _ key: String,
    noActor noActorKey: String?,
    you youKey: String? = nil,
    count: Int? = nil,
    actor: ServiceActor,
    includeActor: Bool,
    args: [CustomStringConvertible]
) -> String {
    func lookup(_ key: String, _ args: [CustomStringConvertible]) -> String {
        if let count {
            return AppStrings.shared.plural(key, count: count, args)
        }
        return AppStrings.shared.string(key, args)
    }
    let line: String
    if !includeActor, let noActorKey {
        line = lookup(noActorKey, args)
    } else if case .you = actor, let youKey {
        line = lookup(youKey, args)
    } else {
        let withActor: [CustomStringConvertible] = [actor.name] + args
        line = lookup(key, withActor)
    }
    // Some iOS templates carry a trailing space.
    return line.trimmingCharacters(in: .whitespaces)
}

/// Bands the seconds value into a human label matching Telegram desktop.
private func autoDeleteDuration(seconds: Int) -> String {
    if seconds < 60 { return LPlural("MessageTimer.Seconds", seconds) }
    if seconds < 3600 { return LPlural("MessageTimer.Minutes", seconds / 60) }
    if seconds < 86400 { return LPlural("MessageTimer.Hours", seconds / 3600) }
    if seconds < 7 * 86400 { return LPlural("MessageTimer.Days", seconds / 86400) }
    if seconds < 30 * 86400 { return LPlural("MessageTimer.Weeks", seconds / (7 * 86400)) }
    return LPlural("MessageTimer.Months", seconds / (30 * 86400))
}

/// "{m} m" under 1 km, else whole "{km} km", in the UI locale's notation.
private func distanceLabel(meters: Int) -> String {
    let formatter = MeasurementFormatter()
    formatter.locale = AppStrings.shared.locale
    formatter.unitOptions = .providedUnit
    formatter.unitStyle = .medium
    if meters < 1000 {
        return formatter.string(from: Measurement(value: Double(meters), unit: UnitLength.meters))
    }
    return formatter.string(from: Measurement(value: Double(meters / 1000), unit: UnitLength.kilometers))
}

/// True when the chat is a broadcast channel (false for groups, incl. nil).
private func isChannel(_ chatType: ChatType?) -> Bool {
    if case .chatTypeSupergroup(let s) = chatType, s.isChannel { return true }
    return false
}

/// Renders the "{Actor} pinned ..." line: "«{snippet}»" for text content (with
/// truncation to 24 characters + ellipsis), "a {type}" for non-text recognized
/// content, or "a message" for anything else (including service content where
/// messageBody returns "").
private func pinnedLine(target: CachedMessage?, actor: ServiceActor, includeActor: Bool) -> String {
    func line(_ key: String, _ noActorKey: String, _ args: CustomStringConvertible...) -> String {
        serviceLine(key, noActor: noActorKey, actor: actor, includeActor: includeActor, args: args)
    }
    let pinnedMessage = { line("Watch.Service.PinnedMessage", "Watch.ServiceNoActor.PinnedMessage") }
    guard let target else { return pinnedMessage() }
    switch target.content {
    case .messageText:
        let body = messageBody(target.content)
        if body.isEmpty { return pinnedMessage() }
        if body.count <= 24 {
            return line("Watch.Service.PinnedText", "Watch.ServiceNoActor.PinnedText", body)
        }
        // Character (extended-grapheme-cluster) prefix — safer than UTF-16
        // truncation for non-ASCII text, and the visual length the reader
        // cares about on a 46mm watch.
        let truncated = body.prefix(24)
        return line("Watch.Service.PinnedText", "Watch.ServiceNoActor.PinnedText", "\(truncated)…")
    case .messagePhoto:     return line("Notification.PinnedPhotoMessage", "Watch.ServiceNoActor.PinnedPhoto")
    case .messageVideo:     return line("Notification.PinnedVideoMessage", "Watch.ServiceNoActor.PinnedVideo")
    case .messageVideoNote: return line("Notification.PinnedRoundMessage", "Watch.ServiceNoActor.PinnedVideoMessage")
    case .messageSticker:   return line("Notification.PinnedStickerMessage", "Watch.ServiceNoActor.PinnedSticker")
    case .messageVoiceNote: return line("Notification.PinnedAudioMessage", "Watch.ServiceNoActor.PinnedVoiceMessage")
    case .messageAudio:     return line("Watch.Service.PinnedMusic", "Watch.ServiceNoActor.PinnedMusic")
    case .messageDocument:  return line("Watch.Service.PinnedDocument", "Watch.ServiceNoActor.PinnedDocument")
    case .messageLocation:  return line("Watch.Service.PinnedLocation", "Watch.ServiceNoActor.PinnedLocation")
    case .messageVenue:     return line("Watch.Service.PinnedVenue", "Watch.ServiceNoActor.PinnedVenue")
    case .messageContact:   return line("Notification.PinnedContactMessage", "Watch.ServiceNoActor.PinnedContact")
    case .messagePoll:      return line("Notification.PinnedPollMessage", "Watch.ServiceNoActor.PinnedPoll")
    default:                return pinnedMessage()
    }
}

/// Resolves a list of user-ids into a single string used as the `{Targets}`
/// token in service lines.
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
        return LPlural("Conversation.StatusMembers", ids.count)
    }
    if ids.count == 1 {
        return known[0]
    }
    if ids.count == 2, known.count == 2 {
        return L("Watch.Service.TargetsPair", known[0], known[1])
    }
    // Either >=3 ids, or mix of known + unknown.
    let others = ids.count - 1
    return LPlural("Watch.Service.TargetsMore", others, known[0], others)
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
        return serviceLine("Notification.Joined", noActor: "Watch.Notification.Joined",
                           actor: actor, includeActor: includeActor)

    case .messageChatJoinByLink, .messageChatJoinByRequest:
        return serviceLine("Watch.Service.JoinedChat", noActor: nil, actor: actor, includeActor: includeActor)

    case .messageChatAddMembers(let m):
        let senderUserId: Int64? = {
            if case .messageSenderUser(let u) = msg.senderId { return u.userId }
            return nil
        }()
        if m.memberUserIds.isEmpty {
            return serviceLine("Watch.Service.AddedMembers", noActor: nil, actor: actor, includeActor: includeActor)
        }
        if let s = senderUserId, m.memberUserIds == [s] {
            // Self-add collapses to a join line.
            return serviceLine("Watch.Service.JoinedChat", noActor: nil, actor: actor, includeActor: includeActor)
        }
        return serviceLine("Watch.Service.Added", noActor: nil, actor: actor, includeActor: includeActor,
                           targetList(m.memberUserIds, userNames: userNames))

    case .messageChatDeleteMember(let m):
        let senderUserId: Int64? = {
            if case .messageSenderUser(let u) = msg.senderId { return u.userId }
            return nil
        }()
        if let s = senderUserId, m.userId == s {
            return serviceLine("Watch.Service.LeftChat", noActor: nil, actor: actor, includeActor: includeActor)
        }
        if let name = userNames[m.userId], !name.isEmpty {
            return serviceLine("Notification.Kicked", noActor: nil, actor: actor, includeActor: includeActor, name)
        }
        return serviceLine("Watch.Service.RemovedMember", noActor: nil, actor: actor, includeActor: includeActor)

    case .messageChatChangeTitle(let m):
        return serviceLine("Notification.ChangedGroupName", noActor: nil, actor: actor, includeActor: includeActor,
                           m.title)

    case .messageChatChangePhoto:
        return serviceLine("Notification.ChangedGroupPhoto", noActor: nil, actor: actor, includeActor: includeActor)

    case .messageChatDeletePhoto:
        return serviceLine("Notification.RemovedGroupPhoto", noActor: nil, actor: actor, includeActor: includeActor)

    case .messagePinMessage(let m):
        let target = messageCache[m.messageId]
        return pinnedLine(target: target, actor: actor, includeActor: includeActor)

    case .messageVideoChatScheduled:
        return serviceLine("Watch.Service.VideoChatScheduled", noActor: nil, actor: actor, includeActor: includeActor)

    case .messageVideoChatStarted:
        return serviceLine("Watch.Service.VideoChatStarted", noActor: nil, actor: actor, includeActor: includeActor)

    case .messageVideoChatEnded(let m):
        // Actor intentionally dropped — TDLib emits one but stock Telegram clients
        // render this without one. includeActor is ignored.
        if m.duration >= 60 {
            let mins = m.duration / 60
            return L("Watch.Service.VideoChatEndedDuration", mins)
        }
        return L("Watch.Service.VideoChatEnded")

    case .messageInviteVideoChatParticipants(let m):
        if m.userIds.isEmpty {
            return serviceLine("Watch.Service.VideoChatInvitedMembers", noActor: nil,
                               actor: actor, includeActor: includeActor)
        }
        return serviceLine("Watch.Service.VideoChatInvited", noActor: nil, actor: actor, includeActor: includeActor,
                           targetList(m.userIds, userNames: userNames))

    case .messageScreenshotTaken:
        return serviceLine("Notification.SecretChatMessageScreenshot", noActor: "Watch.ServiceNoActor.ScreenshotTaken",
                           you: "Notification.SecretChatMessageScreenshotSelf",
                           actor: actor, includeActor: includeActor)

    case .messageChatSetMessageAutoDeleteTime(let m):
        if m.messageAutoDeleteTime == 0 {
            return serviceLine("Watch.Service.AutoDeleteDisabled", noActor: "Watch.ServiceNoActor.AutoDeleteDisabled",
                               actor: actor, includeActor: includeActor)
        }
        let label = autoDeleteDuration(seconds: m.messageAutoDeleteTime)
        return serviceLine("Watch.Service.AutoDeleteSet", noActor: "Watch.ServiceNoActor.AutoDeleteSet",
                           actor: actor, includeActor: includeActor, label)

    case .messageCustomServiceAction(let m):
        return m.text

    case .messageBasicGroupChatCreate:
        // Chat-lifecycle event — rendered without an actor (Telegram convention).
        return L("Notification.CreatedGroup")

    case .messageSupergroupChatCreate:
        // Both channels and supergroups carry this content type; the chat type
        // is the only signal for which word to use.
        if isChannel(chatType) {
            return L("Notification.CreatedChannel")
        }
        return L("Notification.CreatedGroup")

    case .messageForumTopicCreated(let m):
        return serviceLine("Watch.Service.TopicCreated", noActor: nil, actor: actor, includeActor: includeActor,
                           m.name)

    case .messageForumTopicEdited(let m):
        if !m.name.isEmpty {
            return serviceLine("Watch.Service.TopicRenamed", noActor: nil, actor: actor, includeActor: includeActor,
                               m.name)
        }
        if m.editIconCustomEmojiId {
            return serviceLine("Watch.Service.TopicIconChanged", noActor: nil, actor: actor, includeActor: includeActor)
        }
        return serviceLine("Watch.Service.TopicEdited", noActor: nil, actor: actor, includeActor: includeActor)

    case .messageForumTopicIsClosedToggled(let m):
        return serviceLine(m.isClosed ? "Watch.Service.TopicClosed" : "Watch.Service.TopicReopened",
                           noActor: nil, actor: actor, includeActor: includeActor)

    case .messageForumTopicIsHiddenToggled(let m):
        return serviceLine(m.isHidden ? "Notification.ForumTopicHiddenAuthor" : "Notification.ForumTopicUnhiddenAuthor",
                           noActor: nil, actor: actor, includeActor: includeActor)

    case .messageChatSetTheme(let m):
        guard let theme = m.theme else {
            return serviceLine("Watch.Service.ThemeDisabled", noActor: "Watch.ServiceNoActor.ThemeDisabled",
                               actor: actor, includeActor: includeActor)
        }
        if case .chatThemeEmoji(let e) = theme {
            return serviceLine("Watch.Service.ThemeChangedTo", noActor: "Watch.ServiceNoActor.ThemeChangedTo",
                               actor: actor, includeActor: includeActor, e.name)
        }
        return serviceLine("Watch.Service.ThemeChanged", noActor: "Watch.ServiceNoActor.ThemeChanged",
                           actor: actor, includeActor: includeActor)

    case .messageChatSetBackground:
        return serviceLine("Watch.Service.BackgroundChanged", noActor: "Watch.ServiceNoActor.BackgroundChanged",
                           actor: actor, includeActor: includeActor)

    case .messageChatBoost(let m):
        if isChannel(chatType) {
            if m.boostCount == 1 {
                return serviceLine("Watch.Service.BoostedChannel", noActor: nil,
                                   actor: actor, includeActor: includeActor)
            }
            return serviceLine("Watch.Service.BoostedChannelTimes", noActor: nil,
                               actor: actor, includeActor: includeActor,
                               LPlural("Notification.Boost.Times", m.boostCount))
        }
        if m.boostCount == 1 {
            return serviceLine("Notification.Boost.Single", noActor: nil, you: "Notification.Boost.SingleYou",
                               actor: actor, includeActor: includeActor)
        }
        return serviceLine("Notification.Boost.Multiple", noActor: nil, you: "Notification.Boost.MultipleYou",
                           actor: actor, includeActor: includeActor,
                           LPlural("Notification.Boost.Times", m.boostCount))

    case .messageChatHasProtectedContentToggled(let m):
        if m.newHasProtectedContent {
            return serviceLine("Watch.Service.ContentProtectionEnabled",
                               noActor: "Watch.ServiceNoActor.ContentProtectionEnabled",
                               actor: actor, includeActor: includeActor)
        }
        return serviceLine("Watch.Service.ContentProtectionDisabled",
                           noActor: "Watch.ServiceNoActor.ContentProtectionDisabled",
                           actor: actor, includeActor: includeActor)

    case .messageChatUpgradeTo, .messageChatUpgradeFrom:
        // Chat-lifecycle event — actor-less (Telegram convention), ignores includeActor.
        return L("Watch.Service.GroupUpgraded")

    case .messageChatShared:
        return serviceLine("Watch.Service.SharedChat", noActor: "Watch.ServiceNoActor.SharedChat",
                           actor: actor, includeActor: includeActor)

    case .messageUsersShared(let m):
        return serviceLine("Watch.Service.SharedUsers", noActor: "Watch.ServiceNoActor.SharedUsers",
                           count: m.users.count, actor: actor, includeActor: includeActor, m.users.count)

    case .messageBotWriteAccessAllowed:
        return serviceLine("Watch.Service.BotWriteAccessAllowed", noActor: "Watch.ServiceNoActor.BotWriteAccessAllowed",
                           actor: actor, includeActor: includeActor)

    case .messageWebAppDataSent:
        return serviceLine("Watch.Service.WebAppDataSent", noActor: "Watch.ServiceNoActor.WebAppDataSent",
                           actor: actor, includeActor: includeActor)

    case .messageSuggestProfilePhoto:
        return serviceLine("Watch.Service.SuggestedProfilePhoto", noActor: "Watch.ServiceNoActor.SuggestedProfilePhoto",
                           actor: actor, includeActor: includeActor)

    case .messageGameScore(let m):
        return serviceLine("Watch.Service.GameScore", noActor: "Notification.GameScoreSimple",
                           count: m.score, actor: actor, includeActor: includeActor, m.score)

    case .messageProximityAlertTriggered(let m):
        // Actor-less: the line names traveler + watcher, not the message sender.
        let traveler = serviceActor(senderId: m.travelerId, selfUserId: selfUserId, userNames: userNames)
        let watcher = serviceActor(senderId: m.watcherId, selfUserId: selfUserId, userNames: userNames)
        return L("Watch.Service.ProximityAlert", traveler.name, distanceLabel(meters: m.distance), watcher.name)

    case .messageGiveawayCreated(let m):
        // Actor-less — giveaways are posted by channels.
        return m.starCount > 0 ? L("Watch.Service.StarsGiveawayStarted") : L("Watch.Service.GiveawayStarted")

    case .messageGiveawayCompleted(let m):
        return LPlural("Watch.Service.GiveawayEnded", m.winnerCount)

    default:
        return nil
    }
}
