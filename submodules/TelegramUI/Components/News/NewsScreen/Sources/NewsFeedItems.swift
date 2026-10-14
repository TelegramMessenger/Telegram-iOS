import Foundation
import SwiftSignalKit
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
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
    let skeletonRowLayout: NewsFeedSkeletonRowLayout
    /// The list the rows are for: whether they load synchronously as they are built.
    let rowLoading: NewsFeedRowLoading
    let openPost: (EnginePeer, EngineMessage.Id) -> Void
}

/// An album keeps its identity when a later page adds a message to it.
private func newsPostIdentity(_ entry: EngineFeedEntry) -> AnyHashable {
    if let groupingKey = entry.groupingKey {
        return AnyHashable("album-\(entry.peerId.toInt64())-\(groupingKey)")
    }
    return AnyHashable("post-\(entry.peerId.toInt64())-\(entry.messageIds[0].namespace)-\(entry.messageIds[0].id)")
}

func newsPostItem(entry: EngineFeedEntry, messages: [EngineMessage.Id: EngineMessage], environment: NewsFeedItemEnvironment) -> CoreListComponentItem? {
    let resolved = entry.messageIds.compactMap { messages[$0] }
    guard let first = resolved.first, let peer = first.enginePeers[first.id.peerId] ?? first.author else {
        return nil
    }
    var newest = first
    for message in resolved where message.timestamp > newest.timestamp {
        newest = message
    }
    let presentationData = environment.presentationData
    let openPost = environment.openPost
    let messageId = first.id
    return CoreListComponentItem(identity: newsPostIdentity(entry), component: AnyComponent(NewsFeedPostComponent(
        context: environment.context,
        theme: presentationData.theme,
        strings: presentationData.strings,
        dateTimeFormat: presentationData.dateTimeFormat,
        nameDisplayOrder: presentationData.nameDisplayOrder,
        peer: peer,
        messages: resolved,
        timestamp: newest.timestamp,
        loading: environment.rowLoading,
        action: {
            openPost(peer, messageId)
        }
    )))
}

func newsPlaceholderItems(count: Int, theme: PresentationTheme, rowLayout: NewsFeedSkeletonRowLayout, identityPrefix: String) -> [CoreListComponentItem] {
    return (0 ..< count).map { index in
        CoreListComponentItem(identity: AnyHashable("\(identityPrefix)-placeholder-\(index)"), component: AnyComponent(NewsPlaceholderRowComponent(theme: theme, rowLayout: rowLayout)))
    }
}

func newsStatusItem(theme: PresentationTheme, text: String, actionTitle: String?, action: (() -> Void)?) -> CoreListComponentItem {
    return CoreListComponentItem(identity: AnyHashable("status"), component: AnyComponent(NewsStatusRowComponent(theme: theme, text: text, actionTitle: actionTitle, action: action)))
}
