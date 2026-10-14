import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ShimmerEffect

/// Where a post row puts the parts the loading skeleton draws, measured from a real `NewsFeedPostComponent`,
/// so the skeleton matches the rows it stands in for.
public struct NewsFeedSkeletonRowLayout: Equatable {
    public let height: CGFloat
    public let avatarFrame: CGRect
    public let titleFrame: CGRect
    public let textLineFrames: [CGRect]
}

/// Lays out a post row at `width` with placeholder content (a channel name of typical length, a text long
/// enough for the three-line limit) and reads its parts. The content is never shown.
public func newsFeedSkeletonRowLayout(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, width: CGFloat) -> NewsFeedSkeletonRowLayout {
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
        return NewsFeedSkeletonRowLayout(height: size.height, avatarFrame: CGRect(), titleFrame: CGRect(), textLineFrames: [])
    }
    return NewsFeedSkeletonRowLayout(height: size.height, avatarFrame: view.avatarFrame, titleFrame: view.titleFrame, textLineFrames: view.textLineFrames)
}

/// The shimmer shapes of one skeleton row whose top is at `y`: the avatar, a bar for the name and one per text
/// line. The last line is drawn shorter, as a post's text usually ends partway along it.
func newsFeedSkeletonRowShapes(_ layout: NewsFeedSkeletonRowLayout, y: CGFloat) -> [ShimmerEffectNode.Shape] {
    let lineDiameter: CGFloat = 10.0
    func bar(_ frame: CGRect, width: CGFloat) -> ShimmerEffectNode.Shape {
        return .roundedRectLine(startPoint: CGPoint(x: frame.minX, y: y + floor(frame.midY - lineDiameter * 0.5)), width: width, diameter: lineDiameter)
    }
    var shapes: [ShimmerEffectNode.Shape] = [.circle(layout.avatarFrame.offsetBy(dx: 0.0, dy: y)), bar(layout.titleFrame, width: layout.titleFrame.width)]
    for (index, frame) in layout.textLineFrames.enumerated() {
        let isLast = index == layout.textLineFrames.count - 1 && layout.textLineFrames.count > 1
        shapes.append(bar(frame, width: isLast ? floor(frame.width * 0.6) : frame.width))
    }
    return shapes
}
