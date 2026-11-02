import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Channel updates whose pts is checked here against the channel's state (`updateReadChannelInbox`
/// carries a pts too, not checked here: it is in +ReadStates and reaches `resetIncomingReadState` with its
/// pts, which the replay compares with the channel's stored pts), and the ones that ask for their channel
/// to be polled. What they ask for collects in `channelRecovery`.
extension UpdateInterpreter {
    mutating func applyChannelTooLong(_ updateChannelTooLongData: Api.Update.Cons_updateChannelTooLong) {
        let (channelId, channelPts) = (updateChannelTooLongData.channelId, updateChannelTooLongData.pts)
        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
        if !channelRecovery.isPollRequested(peerId) {
            if let channelPts = channelPts, let channelState = state.channelStates[peerId], channelState.pts >= channelPts {
                Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip updateChannelTooLong by pts")
            } else {
                channelRecovery.requestPoll(peerId, ptsHint: channelPts)
            }
        }
    }
    
    mutating func applyPinnedForumTopics(_ updatePinnedForumTopicsData: Api.Update.Cons_updatePinnedForumTopics) {
        if let order = updatePinnedForumTopicsData.order {
            updatedState.addUpdatePinnedTopicOrder(peerId: updatePinnedForumTopicsData.peer.peerId, threadIds: order.map(Int64.init))
        } else {
            let peerId = updatePinnedForumTopicsData.peer.peerId
            // The peer can be a bot-forum user, which cannot be polled or reset.
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                channelRecovery.requestPoll(peerId, ptsHint: nil)
            }
        }
    }
    
    /// A forum topic's edit (a group's topics or a bot's). It carries no pts: in a group the topic's service message,
    /// when there is one, edits the same fields in its own channel update.
    mutating func applyEditForumTopic(_ updateEditForumTopicData: Api.Update.Cons_updateEditForumTopic) {
        let components = forumTopicEditComponents(title: updateEditForumTopicData.title, iconEmojiId: updateEditForumTopicData.iconEmojiId, closed: updateEditForumTopicData.closed, hidden: updateEditForumTopicData.hidden)
        if !components.isEmpty {
            updatedState.addEditForumTopic(peerId: updateEditForumTopicData.peer.peerId, threadId: Int64(updateEditForumTopicData.topicId), components: components)
        }
    }

    mutating func applyDeleteChannelMessages(_ updateDeleteChannelMessagesData: Api.Update.Cons_updateDeleteChannelMessages) {
        let (channelId, messages, pts: pts, ptsCount) = (updateDeleteChannelMessagesData.channelId, updateDeleteChannelMessagesData.messages, updateDeleteChannelMessagesData.pts, updateDeleteChannelMessagesData.ptsCount)
        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
        if let previousState = updatedState.channelStates[peerId] {
            if previousState.pts >= pts {
                Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old delete update")
            } else if previousState.pts + ptsCount == pts {
                updatedState.deleteMessages(messages.map({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }))
                updatedState.updateChannelState(peerId, pts: pts)
            } else {
                if channelRecovery.markGap(peerId) {
                    Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) delete pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                }
            }
        } else {
            channelRecovery.noteUnknownChannelState(peerId)
        }
    }
    
    mutating func applyEditChannelMessage(_ updateEditChannelMessageData: Api.Update.Cons_updateEditChannelMessage) {
        let (apiMessage, pts, ptsCount) = (updateEditChannelMessageData.message, updateEditChannelMessageData.pts, updateEditChannelMessageData.ptsCount)
        var peerIsForum = false
        if let peerId = apiMessage.peerId {
            peerIsForum = updatedState.isPeerForum(peerId: peerId)
        }
        if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum), case let .Id(messageId) = message.id {
            let peerId = messageId.peerId
            if let previousState = updatedState.channelStates[peerId] {
                if previousState.pts >= pts {
                    Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old edit update")
                } else if previousState.pts + ptsCount == pts {
                    if let preCachedResources = apiMessage.preCachedResources {
                        for (resource, data) in preCachedResources {
                            updatedState.addPreCachedResource(resource, data: data)
                        }
                    }
                    if let preCachedStories = apiMessage.preCachedStories {
                        for (id, story) in preCachedStories {
                            updatedState.addPreCachedStory(id: id, story: story)
                        }
                    }
                    var attributes = message.attributes
                    attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                    updatedState.editMessage(messageId, message: message.withUpdatedAttributes(attributes))
                    updatedState.updateChannelState(peerId, pts: pts)
                } else {
                    if channelRecovery.markGap(peerId) {
                        Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) edit message pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                    }
                }
            } else {
                channelRecovery.noteUnknownChannelState(peerId)
            }
        } else {
            Logger.shared.log("State", "Invalid updateEditChannelMessage")
        }
    }
    
    mutating func applyChannelWebPage(_ updateChannelWebPageData: Api.Update.Cons_updateChannelWebPage) {
        let (channelId, apiWebpage, pts, ptsCount) = (updateChannelWebPageData.channelId, updateChannelWebPageData.webpage, updateChannelWebPageData.pts, updateChannelWebPageData.ptsCount)
        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
        if let previousState = updatedState.channelStates[peerId] {
            if previousState.pts >= pts {
            } else if previousState.pts + ptsCount == pts {
                switch apiWebpage {
                    case let .webPageEmpty(webPageEmptyData):
                        let (flags, id, url) = (webPageEmptyData.flags, webPageEmptyData.id, webPageEmptyData.url)
                        let _ = flags
                        let _ = url
                        updatedState.updateMedia(MediaId(namespace: Namespaces.Media.CloudWebpage, id: id), media: nil)
                    default:
                        if let webpage = telegramMediaWebpageFromApiWebpage(apiWebpage) {
                            updatedState.updateMedia(webpage.webpageId, media: webpage)
                        }
                }

                updatedState.updateChannelState(peerId, pts: pts)
            } else {
                if channelRecovery.requestPoll(peerId, ptsHint: nil) {
                    Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) updateWebPage pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                }
            }
        } else {
            channelRecovery.noteUnknownChannelState(peerId)
        }
    }
    
    mutating func applyNewChannelMessage(_ updateNewChannelMessageData: Api.Update.Cons_updateNewChannelMessage) {
        let (apiMessage, pts, ptsCount) = (updateNewChannelMessageData.message, updateNewChannelMessageData.pts, updateNewChannelMessageData.ptsCount)
        var peerIsForum = false
        if let peerId = apiMessage.peerId {
            peerIsForum = updatedState.isPeerForum(peerId: peerId)
        }
        if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
            if let previousState = updatedState.channelStates[message.id.peerId] {
                if previousState.pts >= pts {
                    let messageText: String
                    if Logger.shared.redactSensitiveData {
                        messageText = "[[redacted]]"
                    } else {
                        messageText = message.text
                    }
                Logger.shared.log("State", "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) skip old message \(message.id) (\(messageText))")
                } else if previousState.pts + ptsCount == pts {
                    if let preCachedResources = apiMessage.preCachedResources {
                        for (resource, data) in preCachedResources {
                            updatedState.addPreCachedResource(resource, data: data)
                        }
                    }
                    if let preCachedStories = apiMessage.preCachedStories {
                        for (id, story) in preCachedStories {
                            updatedState.addPreCachedStory(id: id, story: story)
                        }
                    }
                    var attributes = message.attributes
                    attributes.append(ChannelMessageStateVersionAttribute(pts: pts))
                    updatedState.addMessages([message.withUpdatedAttributes(attributes)], location: .UpperHistoryBlock)
                    updatedState.updateChannelState(message.id.peerId, pts: pts)
                    if case let .Id(id) = message.id {
                        updatedState.updateChannelSynchronizedUntilMessage(id.peerId, id: id.id)
                    }
                } else {
                    if channelRecovery.markGap(message.id.peerId) {
                        Logger.shared.log("State", "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) message pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                    }
                }
            } else {
                if channelRecovery.noteUnknownChannelState(message.id.peerId) {
                    Logger.shared.log("State", "channel \(message.id.peerId) (\((updatedState.peers[message.id.peerId] as? TelegramChannel)?.title ?? "nil")) state unknown")
                }
            }
        }
    }
    
    mutating func applyPinnedChannelMessages(_ updatePinnedChannelMessagesData: Api.Update.Cons_updatePinnedChannelMessages) {
        let (flags, channelId, messages, pts, ptsCount) = (updatePinnedChannelMessagesData.flags, updatePinnedChannelMessagesData.channelId, updatePinnedChannelMessagesData.messages, updatePinnedChannelMessagesData.pts, updatePinnedChannelMessagesData.ptsCount)
        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
        if let previousState = updatedState.channelStates[peerId] {
            if previousState.pts >= pts {
                Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) skip old pinned messages update")
            } else if previousState.pts + ptsCount == pts {
                let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                updatedState.updateMessagesPinned(ids: messages.map { id in
                    MessageId(peerId: channelPeerId, namespace: Namespaces.Message.Cloud, id: id)
                }, pinned: (flags & (1 << 0)) != 0)
                updatedState.updateChannelState(peerId, pts: pts)
            } else {
                if channelRecovery.markGap(peerId) {
                    Logger.shared.log("State", "channel \(peerId) (\((updatedState.peers[peerId] as? TelegramChannel)?.title ?? "nil")) pinned messages pts hole \(previousState.pts) + \(ptsCount) != \(pts)")
                }
            }
        } else {
            channelRecovery.noteUnknownChannelState(peerId)
        }
    }
}
