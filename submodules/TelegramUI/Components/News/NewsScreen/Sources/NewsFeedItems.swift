import Foundation
import Display
import SwiftSignalKit
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import CoreList
import CoreListComponentHost
import NewsFeedSupport
import NewsFeedComponents

/// The feed's messages by id. Re-subscribes only when the set of ids changes: a state push that only moves
/// the read mark or a loading flag (every newly read post pushes one) reuses the subscription.
/// The messages of a feed's entries, with the ids they were loaded for: an emission can still be for the
/// previous ids (see `newsWindowIsResolved`).
struct NewsFeedMessages {
    var ids: [EngineMessage.Id]
    var messages: [EngineMessage.Id: EngineMessage]
}

func newsFeedMessages(engine: TelegramEngine, ids: Signal<[EngineMessage.Id], NoError>) -> Signal<NewsFeedMessages, NoError> {
    return ids
    |> distinctUntilChanged
    |> mapToSignal { ids -> Signal<NewsFeedMessages, NoError> in
        // One view for all the feed's messages, not one per message: the feed's own queue is the main queue, and a
        // key per message made each load-more's subscribe grow with the feed's length.
        return engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Messages(ids: Set(ids)))
        |> map { messages -> NewsFeedMessages in
            return NewsFeedMessages(ids: ids, messages: messages)
        }
    }
}

struct NewsFeedItemEnvironment {
    let context: AccountContext
    let presentationData: PresentationData
    /// Measured from a post row at the list's width; the load-more placeholder is drawn from it.
    let skeletonRowLayout: NewsSkeletonModelRow
    /// The list the rows are for: whether they load synchronously as they are built.
    let rowLoading: NewsFeedRowLoading
    let openPost: (EnginePeer, EngineMessage.Id) -> Void
    /// A post row's swipe actions: For you's rows swipe both ways, Added's for Expand / Collapse only, search results
    /// not at all (nil). The last argument is the post's identity (`newsPostIdentity`).
    let postSwipe: ((EnginePeer, EngineMessage.Id, AnyHashable) -> NewsPostSwipe)?
    /// The tab's "Post hidden" flow; nil for Added and search results.
    let feedback: NewsFeedItemFeedback?
    /// A post row's context menu (a long press): the row, its channel, its messages and identity.
    let postContextMenu: ((NewsFeedPostComponent.View, ContextGesture, EnginePeer, [EngineMessage], AnyHashable) -> Void)?
    /// A row's floating avatar moved or stuck: the header's edge effects follow.
    let floatingAvatarsChanged: (() -> Void)?
    /// Compact rows, or the expanded posts.
    let displayMode: NewsFeedDisplayMode
    /// The posts a swipe switched to the other mode on their own (`NewsPostSwipeAction.expand` / `.collapse`).
    let rowModeOverrides: Set<AnyHashable>
    /// The content an expanded row needs, per post (its first message and its identity).
    let expandedContent: ((EngineMessage, AnyHashable) -> NewsFeedPostExpandedContent?)?

    /// The mode a post's row shows: the feed's, unless a swipe switched that row.
    func rowDisplayMode(_ identity: AnyHashable) -> NewsFeedDisplayMode {
        guard self.rowModeOverrides.contains(identity) else {
            return self.displayMode
        }
        return self.displayMode == .compact ? .expanded : .compact
    }
}

/// What a tab's rows read from its "Post hidden" flow (spec §3).
struct NewsFeedItemFeedback {
    let state: NewsPostFeedbackState
    let tab: NewsPostFeedbackPanelComponent.Tab
    let postAppearTimes: [AnyHashable: Double]
    let panelAppearTimes: [AnyHashable: Double]
    let undo: (AnyHashable, EnginePeer.Id) -> Void
    let choose: (AnyHashable, EnginePeer.Id, NewsPostFeedbackChoice) -> Void

    /// Hidden entries leave the feed before its rows (and their fresh segments) are built.
    func isShown(_ entry: EngineFeedEntry) -> Bool {
        return self.state.isShown(post: newsPostIdentity(entry), channel: entry.peerId)
    }

    /// A panel stands where the entry's post was: it is no part of a fresh run.
    func hasPanel(_ entry: EngineFeedEntry) -> Bool {
        return self.state.hasPanel(newsPostIdentity(entry))
    }
}

/// A panel row's identity: never equal to a post row's, so the panel replaces the post rather than updating it.
private struct NewsPostFeedbackPanelIdentity: Hashable {
    let post: AnyHashable
}

/// The channel a post's row shows.
private func newsPostPeer(_ message: EngineMessage) -> EnginePeer? {
    return message.enginePeers[message.id.peerId] ?? message.author
}

func newsPostItem(entry: EngineFeedEntry, messages: [EngineMessage.Id: EngineMessage], environment: NewsFeedItemEnvironment, fresh: NewsFreshSegment? = nil) -> CoreListComponentItem? {
    let resolved = entry.messageIds.compactMap { messages[$0] }
    guard let first = resolved.first, let peer = newsPostPeer(first) else {
        return nil
    }
    var newest = first
    for message in resolved where message.timestamp > newest.timestamp {
        newest = message
    }
    let presentationData = environment.presentationData
    let openPost = environment.openPost
    let messageId = first.id
    let identity = newsPostIdentity(entry)
    var fading = false
    // On its way out (fading for its panel, or a hidden channel's post until its fade): no swipe, no tap.
    let isLeaving = environment.feedback?.state.isLeaving(identity) ?? false
    if let feedback = environment.feedback {
        switch feedback.state.row(post: identity, channel: entry.peerId) {
        case .hidden:
            return nil
        case let .panel(phase, panelFading):
            let channel = entry.peerId
            return CoreListComponentItem(identity: AnyHashable(NewsPostFeedbackPanelIdentity(post: identity)), component: AnyComponent(NewsPostFeedbackPanelComponent(
                context: environment.context,
                theme: presentationData.theme,
                strings: presentationData.strings,
                peer: peer,
                tab: feedback.tab,
                phase: phase,
                fading: panelFading,
                appearTime: feedback.panelAppearTimes[identity],
                reduceMotion: presentationData.reduceMotion,
                undo: {
                    feedback.undo(identity, channel)
                },
                choose: { choice in
                    feedback.choose(identity, channel, choice)
                }
            )))
        case let .post(postFading):
            fading = postFading
        }
    }
    // An expanded row's avatar floats over a run of adjacent posts from the same channel, as a group chat's
    // gutter avatar does: the list draws it as a run attachment, keyed by the channel.
    var attachedItems: [AnyHashable: CoreListAttachedItem] = [:]
    let displayMode = environment.rowDisplayMode(identity)
    if displayMode == .expanded {
        attachedItems[AnyHashable(peer.id)] = NewsFloatingAvatarAttachedItem(context: environment.context, theme: presentationData.theme, peer: peer, loading: environment.rowLoading)
    }
    return CoreListComponentItem(identity: identity, attachedItems: attachedItems, component: AnyComponent(NewsFeedPostComponent(
        context: environment.context,
        theme: presentationData.theme,
        strings: presentationData.strings,
        dateTimeFormat: presentationData.dateTimeFormat,
        nameDisplayOrder: presentationData.nameDisplayOrder,
        peer: peer,
        messages: resolved,
        timestamp: newest.timestamp,
        loading: environment.rowLoading,
        fresh: fresh,
        reduceMotion: presentationData.reduceMotion,
        fading: fading,
        appearTime: environment.feedback?.postAppearTimes[identity],
        swipe: isLeaving ? nil : environment.postSwipe?(peer, messageId, identity),
        displayMode: displayMode,
        expanded: displayMode == .expanded ? environment.expandedContent?(first, identity) : nil,
        contextMenu: isLeaving ? nil : environment.postContextMenu.map { menu in
            return { row, gesture in
                menu(row, gesture, peer, resolved, identity)
            }
        },
        floatingAvatarsChanged: environment.floatingAvatarsChanged,
        action: {
            if !isLeaving {
                openPost(peer, messageId)
            }
        }
    )))
}

func newsPlaceholderItems(count: Int, theme: PresentationTheme, rowLayout: NewsSkeletonModelRow, identityPrefix: String) -> [CoreListComponentItem] {
    return (0 ..< count).map { index in
        CoreListComponentItem(identity: AnyHashable("\(identityPrefix)-placeholder-\(index)"), component: AnyComponent(NewsPlaceholderRowComponent(theme: theme, rowLayout: rowLayout)))
    }
}

func newsStatusItem(theme: PresentationTheme, text: String, actionTitle: String?, action: (() -> Void)?) -> CoreListComponentItem {
    return CoreListComponentItem(identity: AnyHashable("status"), component: AnyComponent(NewsStatusRowComponent(theme: theme, text: text, actionTitle: actionTitle, action: action)))
}
