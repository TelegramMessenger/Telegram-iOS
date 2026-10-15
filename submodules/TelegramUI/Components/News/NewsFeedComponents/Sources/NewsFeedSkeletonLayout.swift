import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import NewsFeedSupport

/// Lays out a post row at `width` with placeholder content (a channel name of typical length, a text long
/// enough for the three-line limit) and reads its parts. The content is never shown.
public func newsFeedSkeletonRowLayout(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, width: CGFloat) -> NewsSkeletonModelRow {
    let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    let peer = EnginePeer.channel(TelegramChannel(
        id: peerId,
        accessHash: nil,
        title: "Channel Name News",
        username: nil,
        photo: [],
        creationDate: 0,
        version: 0,
        participationStatus: .member,
        info: .broadcast(TelegramChannelBroadcastInfo(flags: [])),
        flags: [],
        restrictionInfo: nil,
        adminRights: nil,
        bannedRights: nil,
        defaultBannedRights: nil,
        usernames: [],
        storiesHidden: nil,
        nameColor: nil,
        backgroundEmojiId: nil,
        profileColor: nil,
        profileBackgroundEmojiId: nil,
        emojiStatus: nil,
        approximateBoostLevel: nil,
        subscriptionUntilDate: nil,
        verificationIconFileId: nil,
        sendPaidMessageStars: nil,
        linkedMonoforumId: nil
    ))
    let timestamp = Int32(Date().timeIntervalSince1970) - 60 * 60
    let message = EngineMessage(
        stableId: 0,
        stableVersion: 0,
        id: EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1),
        globallyUniqueId: nil,
        groupingKey: nil,
        groupInfo: nil,
        threadId: nil,
        timestamp: timestamp,
        flags: [],
        tags: [],
        globalTags: [],
        localTags: [],
        customTags: [],
        forwardInfo: nil,
        author: peer,
        text: String(repeating: "Placeholder text of a post that runs past the line limit. ", count: 8),
        attributes: [],
        media: [],
        peers: [peerId: peer],
        associatedMessages: [:],
        associatedMessageIds: [],
        associatedMedia: [:],
        associatedThreadInfo: nil,
        associatedStories: [:]
    )
    let row = ComponentView<Empty>()
    let size = row.update(
        transition: .immediate,
        component: AnyComponent(NewsFeedPostComponent(context: context, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, peer: peer, messages: [message], timestamp: timestamp, loading: NewsFeedRowLoading(), action: {})),
        environment: {},
        containerSize: CGSize(width: width, height: 10000.0)
    )
    guard let view = row.view as? NewsFeedPostComponent.View else {
        return NewsSkeletonModelRow(height: size.height, avatarFrame: CGRect(), titleFrame: CGRect(), textLineFrames: [], textWidth: newsPostTextWidth(width: width, hasThumbnail: false), thumbnailFrame: nil)
    }
    return NewsSkeletonModelRow(height: size.height, avatarFrame: view.avatarFrame, titleFrame: view.titleFrame, textLineFrames: view.textLineFrames, textWidth: newsPostTextWidth(width: width, hasThumbnail: false), thumbnailFrame: nil)
}
