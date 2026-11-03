import Foundation
import SwiftSignalKit
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData
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
        return engine.data.subscribe(EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Messages.Message.init)))
        |> map { messages -> NewsFeedMessages in
            var result: [EngineMessage.Id: EngineMessage] = [:]
            for (id, message) in messages {
                if let message {
                    result[id] = message
                }
            }
            return NewsFeedMessages(ids: ids, messages: result)
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
    /// A post row's swipe actions: the feeds' rows swipe, search results do not (nil). The last argument is the post's
    /// identity (`newsPostIdentity`).
    let postSwipe: ((EnginePeer, EngineMessage.Id, AnyHashable) -> NewsPostSwipe)?
    /// The tab's "Post hidden" flow; nil for search results.
    let feedback: NewsFeedItemFeedback?
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
    return CoreListComponentItem(identity: identity, component: AnyComponent(NewsFeedPostComponent(
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
        action: {
            if !isLeaving {
                openPost(peer, messageId)
            }
        }
    )))
}

/// The posts a feed holds, as the search finds them, and their messages, which their rows are built from.
struct NewsSearchCorpus {
    var documents: [NewsSearchDocument] = []
    var messages: [EngineMessage.Id: EngineMessage] = [:]

    init() {
    }

    /// The feed's entries whose messages are loaded (`newsPostItem` builds no row for the others).
    init(entries: [EngineFeedEntry], messages: [EngineMessage.Id: EngineMessage]) {
        self.messages = messages
        for entry in newsResolvedEntries(entries, availableMessageIds: Set(messages.keys)) {
            let resolved = entry.messageIds.compactMap { messages[$0] }
            guard let first = resolved.first, let peer = newsPostPeer(first) else {
                continue
            }
            self.documents.append(NewsSearchDocument(entry: entry, texts: resolved.map(\.text), channelTitle: peer.compactDisplayTitle))
        }
    }

    mutating func append(_ other: NewsSearchCorpus) {
        self.documents.append(contentsOf: other.documents)
        self.messages.merge(other.messages, uniquingKeysWith: { _, other in other })
    }
}

func newsPlaceholderItems(count: Int, theme: PresentationTheme, rowLayout: NewsSkeletonModelRow, identityPrefix: String) -> [CoreListComponentItem] {
    return (0 ..< count).map { index in
        CoreListComponentItem(identity: AnyHashable("\(identityPrefix)-placeholder-\(index)"), component: AnyComponent(NewsPlaceholderRowComponent(theme: theme, rowLayout: rowLayout)))
    }
}

func newsStatusItem(theme: PresentationTheme, text: String, actionTitle: String?, action: (() -> Void)?) -> CoreListComponentItem {
    return CoreListComponentItem(identity: AnyHashable("status"), component: AnyComponent(NewsStatusRowComponent(theme: theme, text: text, actionTitle: actionTitle, action: action)))
}
