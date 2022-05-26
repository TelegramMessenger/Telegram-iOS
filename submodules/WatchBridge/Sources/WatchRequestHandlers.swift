import Foundation
import SwiftSignalKit
import Postbox
import Display
import TelegramCore
import LegacyComponents
import WatchCommon
import TelegramPresentationData
import AvatarNode
import StickerResources
import PhotoResources
import AccountContext
import WatchBridgeAudio

let allWatchRequestHandlers: [AnyClass] = [
    WatchChatListHandler.self,
    WatchChatMessagesHandler.self,
    WatchSendMessageHandler.self,
    WatchPeerInfoHandler.self,
    WatchMediaHandler.self,
    WatchStickersHandler.self,
    WatchAudioHandler.self,
    WatchLocationHandler.self,
    WatchPeerSettingsHandler.self,
    WatchContinuationHandler.self,
]

protocol WatchRequestHandler: AnyObject {
    static var handledSubscriptions: [Any] { get }
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal
}

final class WatchChatListHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [TGBridgeChatListSubscription.self]
    }
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgeChatListSubscription {
            let limit = Int(args.limit)
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<(ChatListView, PresentationData), NoError> in
                    if let context = context {
                        return context.account.viewTracker.tailChatListView(groupId: .root, count: limit)
                        |> map { chatListView, _ -> (ChatListView, PresentationData) in
                            return (chatListView, context.sharedContext.currentPresentationData.with { $0 })
                        }
                    } else {
                        return .complete()
                    }
                })
                let disposable = signal.start(next: { chatListView, presentationData in
                    var chats: [TGBridgeChat] = []
                    var users: [Int64 : TGBridgeUser] = [:]
                    for entry in chatListView.entries.reversed() {
                        if let (chat, chatUsers) = makeBridgeChat(entry, strings: presentationData.strings) {
                            chats.append(chat)
                            users = users.merging(chatUsers, uniquingKeysWith: { (_, last) in last })
                        }
                    }
                    subscriber.putNext([ TGBridgeChatsArrayKey: chats, TGBridgeUsersDictionaryKey: users ])
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        } else {
            return SSignal.fail(nil)
        }
    }
}


final class WatchChatMessagesHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [
            TGBridgeChatMessageListSubscription.self,
            TGBridgeChatMessageSubscription.self,
            TGBridgeReadChatMessageListSubscription.self
        ]
    }
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgeChatMessageListSubscription, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
            return SSignal { subscriber in
                let limit = Int(args.rangeMessageCount)
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<(MessageHistoryView, Bool, PresentationData), NoError> in
                    if let context = context {
                        return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId), index: .upperBound, anchorIndex: .upperBound, count: limit, fixedCombinedReadStates: nil)
                        |> map { messageHistoryView, _, _ -> (MessageHistoryView, Bool, PresentationData) in
                            return (messageHistoryView, peerId == context.account.peerId, context.sharedContext.currentPresentationData.with { $0 })
                        }
                    } else {
                        return .complete()
                    }
                })
                let disposable = signal.start(next: { messageHistoryView, savedMessages, presentationData in
                    var messages: [TGBridgeMessage] = []
                    var users: [Int64 : TGBridgeUser] = [:]
                    for entry in messageHistoryView.entries.reversed() {
                        if let (message, messageUsers) = makeBridgeMessage(entry, strings: presentationData.strings) {
                            messages.append(message)
                            users = users.merging(messageUsers, uniquingKeysWith: { (_, last) in last })
                        }
                    }
                    subscriber.putNext([ TGBridgeMessagesArrayKey: messages, TGBridgeUsersDictionaryKey: users ])
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        } else if let args = subscription as? TGBridgeReadChatMessageListSubscription, let peerId = makePeerIdFromBridgeIdentifier(args.peerId)  {
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<Void, NoError> in
                    if let context = context {
                        let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: args.messageId)
                        return context.engine.messages.applyMaxReadIndexInteractively(index: MessageIndex(id: messageId, timestamp: 0))
                    } else {
                        return .complete()
                    }
                })
                let disposable = signal.start(next: { _ in
                    subscriber.putNext(true)
                },  completed: {
                    subscriber.putCompletion()
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        } else if let args = subscription as? TGBridgeChatMessageSubscription, let peerId = makePeerIdFromBridgeIdentifier(args.peerId)  {
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<(Message, PresentationData)?, NoError> in
                    if let context = context {
                        let messageSignal = context.engine.messages.downloadMessage(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: args.messageId))
                        |> map { message -> (Message, PresentationData)? in
                            if let message = message {
                                return (message, context.sharedContext.currentPresentationData.with { $0 })
                            } else {
                                return nil
                            }
                        }
                        return messageSignal |> timeout(3.5, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
                    } else {
                        return .single(nil)
                    }
                })
                let disposable = signal.start(next: { messageAndPresentationData in
                    if let (message, presentationData) = messageAndPresentationData, let bridgeMessage = makeBridgeMessage(message, strings: presentationData.strings) {
                        let peers = makeBridgePeers(message)
                        var response: [String : Any] = [TGBridgeMessageKey: bridgeMessage, TGBridgeUsersDictionaryKey: peers]
                        if peerId.namespace != Namespaces.Peer.CloudUser {
                            response[TGBridgeChatKey] = peers[makeBridgeIdentifier(peerId)]
                        }
                        subscriber.putNext(response)
                    }
                    subscriber.putCompletion()
                })
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        }
        return SSignal.fail(nil)
    }
}

final class WatchSendMessageHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [
            TGBridgeSendTextMessageSubscription.self,
            TGBridgeSendLocationMessageSubscription.self,
            TGBridgeSendStickerMessageSubscription.self,
            TGBridgeSendForwardedMessageSubscription.self
        ]
    }
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        return SSignal { subscriber in
            let signal = manager.accountContext.get()
            |> take(1)
            |> mapToSignal({ context -> Signal<Bool, NoError> in
                if let context = context {
                    var messageSignal: Signal<(EnqueueMessage?, PeerId?), NoError>?
                    if let args = subscription as? TGBridgeSendTextMessageSubscription {
                        let peerId = makePeerIdFromBridgeIdentifier(args.peerId)
                        var replyMessageId: MessageId?
                        if args.replyToMid != 0, let peerId = peerId {
                            replyMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: args.replyToMid)
                        }
                        messageSignal = .single((.message(text: args.text, attributes: [], mediaReference: nil, replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil), peerId))
                    } else if let args = subscription as? TGBridgeSendLocationMessageSubscription, let location = args.location {
                        let peerId = makePeerIdFromBridgeIdentifier(args.peerId)
                        let map = TelegramMediaMap(latitude: location.latitude, longitude: location.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: makeVenue(from: location.venue), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
                        messageSignal = .single((.message(text: "", attributes: [], mediaReference: .standalone(media: map), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil), peerId))
                    } else if let args = subscription as? TGBridgeSendStickerMessageSubscription {
                        let peerId = makePeerIdFromBridgeIdentifier(args.peerId)
                        messageSignal = mediaForSticker(documentId: args.document.documentId, account: context.account)
                        |> map({ media -> (EnqueueMessage?, PeerId?) in
                            if let media = media {
                                return (.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil), peerId)
                            } else {
                                return (nil, nil)
                            }
                        })
                    } else if let args = subscription as? TGBridgeSendForwardedMessageSubscription {
                        let peerId = makePeerIdFromBridgeIdentifier(args.targetPeerId)
                        if let forwardPeerId = makePeerIdFromBridgeIdentifier(args.peerId) {
                            messageSignal = .single((.forward(source: MessageId(peerId: forwardPeerId, namespace: Namespaces.Message.Cloud, id: args.messageId), grouping: .none, attributes: [], correlationId: nil), peerId))
                        }
                    }
                    
                    if let messageSignal = messageSignal {
                        return messageSignal |> mapToSignal({ message, peerId -> Signal<Bool, NoError> in
                            if let message = message, let peerId = peerId {
                                return enqueueMessages(account: context.account, peerId: peerId, messages: [message]) |> mapToSignal({ _ in
                                    return .single(true)
                                })
                            } else {
                                return .complete()
                            }
                        })
                    }
                }
                return .complete()
            })

            let disposable = signal.start(next: { _ in
                subscriber.putNext(true)
            }, completed: {
                subscriber.putCompletion()
            })
            
            return SBlockDisposable {
                disposable.dispose()
            }
        }
    }
}

final class WatchPeerInfoHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [
            TGBridgeUserInfoSubscription.self,
            TGBridgeUserBotInfoSubscription.self,
            TGBridgeConversationSubscription.self
        ]
    }
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgeUserInfoSubscription {
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<PeerView, NoError> in
                    if let context = context, let userId = args.userIds.first as? Int64, let peerId = makePeerIdFromBridgeIdentifier(userId) {
                        return context.account.viewTracker.peerView(peerId)
                    } else {
                        return .complete()
                    }
                })
                let disposable = signal.start(next: { view in
                    if let user = makeBridgeUser(peerViewMainPeer(view), presence: view.peerPresences[view.peerId], cachedData: view.cachedData) {
                        subscriber.putNext([user.identifier: user])
                    } else {
                        subscriber.putCompletion()
                    }
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        } else if let _ = subscription as? TGBridgeUserBotInfoSubscription {
            return SSignal.complete()
        } else if let args = subscription as? TGBridgeConversationSubscription {
            return SSignal { subscriber in
                let signal = manager.accountContext.get() |> take(1) |> mapToSignal({ context -> Signal<PeerView, NoError> in
                    if let context = context, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
                        return context.account.viewTracker.peerView(peerId)
                    } else {
                        return .complete()
                    }
                })
                let disposable = signal.start(next: { view in
                    let (chat, users) = makeBridgeChat(peerViewMainPeer(view), view: view)
                    subscriber.putNext([ TGBridgeChatKey: chat, TGBridgeUsersDictionaryKey: users ])
                })
            
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        }
        return SSignal.fail(nil)
    }
}

private func mediaForSticker(documentId: Int64, account: Account) -> Signal<TelegramMediaFile?, NoError> {
    return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 50)
    |> take(1)
    |> map { view -> TelegramMediaFile? in
        for view in view.orderedItemListsViews {
            for entry in view.items {
                if let file = entry.contents.get(SavedStickerItem.self)?.file {
                    if file.id?.id == documentId {
                        return file
                    }
                } else if let file = entry.contents.get(RecentMediaItem.self)?.media {
                    if file.id?.id == documentId {
                        return file
                    }
                }
            }
        }
        return nil
    }
}

private let roundCorners = { () -> UIImage in
    let diameter: CGFloat = 44.0
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setBlendMode(.clear)
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}()

private func sendData(manager: WatchCommunicationManager, data: Data, key: String, ext: String, type: String, forceAsData: Bool = false) {
    if let tempPath = manager.watchTemporaryStorePath, !forceAsData {
        let tempFileUrl = URL(fileURLWithPath: tempPath + "/\(key)\(ext)")
        let _ = try? data.write(to: tempFileUrl)
        let _ = manager.sendFile(url: tempFileUrl, metadata: [TGBridgeIncomingFileTypeKey: type, TGBridgeIncomingFileIdentifierKey: key]).start()
    } else {
        let _ = manager.sendFile(data: data, metadata: [TGBridgeIncomingFileTypeKey: type, TGBridgeIncomingFileIdentifierKey: key]).start()
    }
}

final class WatchMediaHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [
            TGBridgeMediaThumbnailSubscription.self,
            TGBridgeMediaAvatarSubscription.self,
            TGBridgeMediaStickerSubscription.self
        ]
    }
    
    static private let disposable = DisposableSet()
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgeMediaAvatarSubscription, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
            let key = "\(args.url!)_\(args.type.rawValue)"
            let targetSize: CGSize
            var compressionRate: CGFloat = 0.5
            var round = false
            switch args.type {
                case .small:
                    targetSize = CGSize(width: 19, height: 19);
                    compressionRate = 0.5
                case .profile:
                    targetSize = CGSize(width: 44, height: 44);
                    round = true
                case .large:
                    targetSize = CGSize(width: 150, height: 150);
                @unknown default:
                    fatalError()
            }
            
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<UIImage?, NoError> in
                    if let context = context {
                        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                        |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
                            if let peer = peer, case let .secretChat(secretChat) = peer {
                                return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: secretChat.regularPeerId))
                            } else {
                                return .single(peer)
                            }
                        }
                        |> mapToSignal({ peer -> Signal<UIImage?, NoError> in
                            if let peer = peer, let representation = peer.smallProfileImage {
                                let imageData = peerAvatarImageData(account: context.account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: nil, representation: representation, synchronousLoad: false)
                                if let imageData = imageData {
                                    return imageData
                                    |> map { data -> UIImage? in
                                        if let (data, _) = data, let image = generateImage(targetSize, contextGenerator: { size, context -> Void in
                                            if let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let dataImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                                                context.setBlendMode(.copy)
                                                context.draw(dataImage, in: CGRect(origin: CGPoint(), size: targetSize))
                                                if round {
                                                    context.setBlendMode(.normal)
                                                    context.draw(roundCorners.cgImage!, in: CGRect(origin: CGPoint(), size: targetSize))
                                                }
                                            }
                                        }, scale: 2.0) {
                                            return image
                                        }
                                        return nil
                                    }
                                }
                            }
                            return .single(nil)
                        })
                    } else {
                        return .complete()
                    }
                })
                
                let disposable = signal.start(next: { image in
                    if let image = image, let imageData = image.jpegData(compressionQuality: compressionRate) {
                        sendData(manager: manager, data: imageData, key: key, ext: ".jpg", type: TGBridgeIncomingFileTypeImage, forceAsData: true)
                    }
                    subscriber.putNext(key)
                }, completed: {
                    subscriber.putCompletion()
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        } else if let args = subscription as? TGBridgeMediaStickerSubscription {
            let key = "sticker_\(args.documentId)_\(Int(args.size.width))x\(Int(args.size.height))_\(args.notification ? 1 : 0)"
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<UIImage?, NoError> in
                    if let context = context {
                        var mediaSignal: Signal<(TelegramMediaFile, FileMediaReference)?, NoError>? = nil
                        if args.stickerPackId != 0 {
                            mediaSignal = mediaForSticker(documentId: args.documentId, account: context.account)
                            |> map { media -> (TelegramMediaFile, FileMediaReference)? in
                                if let media = media {
                                    return (media, .standalone(media: media))
                                } else {
                                    return nil
                                }
                            }
                        } else if args.stickerPeerId != 0, let peerId = makePeerIdFromBridgeIdentifier(args.stickerPeerId) {
                            mediaSignal = context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: args.stickerMessageId)))
                            |> map { message -> (TelegramMediaFile, FileMediaReference)? in
                                if let message = message {
                                    for media in message.media {
                                        if let media = media as? TelegramMediaFile {
                                            return (media, .message(message: MessageReference(message._asMessage()), media: media))
                                        }
                                    }
                                }
                                return nil
                            }
                        }
                        var size: CGSize = args.size
                        if let mediaSignal = mediaSignal {
                            return mediaSignal
                            |> mapToSignal { mediaAndFileReference -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> in
                                if let (media, fileReference) = mediaAndFileReference {
                                    if let dimensions = media.dimensions {
                                        size = dimensions.cgSize
                                    }
                                    self.disposable.add(freeMediaFileInteractiveFetched(account: context.account, fileReference: fileReference).start())
                                    return chatMessageSticker(account: context.account, file: media, small: false, fetched: true, onlyFullSize: true)
                                }
                                return .complete()
                            }
                            |> map{ f -> UIImage? in
                                let context = f(TransformImageArguments(corners: ImageCorners(), imageSize: size.fitted(args.size), boundingSize: args.size, intrinsicInsets: UIEdgeInsets(), emptyColor: args.notification ? UIColor(rgb: 0xe5e5ea) : .black, scale: 2.0))
                                return context?.generateImage()
                            }
                        }
                    }
                    return .complete()
                })
                
                let disposable = signal.start(next: { image in
                    if let image = image, let imageData = image.jpegData(compressionQuality: 0.2) {
                        sendData(manager: manager, data: imageData, key: key, ext: ".jpg", type: TGBridgeIncomingFileTypeImage, forceAsData: args.notification)
                    }
                    subscriber.putNext(key)
                }, completed: {
                    subscriber.putCompletion()
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        } else if let args = subscription as? TGBridgeMediaThumbnailSubscription {
            let key = "\(args.peerId)_\(args.messageId)"
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<UIImage?, NoError> in
                    if let context = context, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
                        var roundVideo = false
                        return context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: args.messageId)))
                        |> mapToSignal { message -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> in
                            if let message = message, !message._asMessage().containsSecretMedia {
                                var imageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?                                
                                var updatedMediaReference: AnyMediaReference?
                                var candidateMediaReference: AnyMediaReference?
                                var imageDimensions: CGSize?
                                for media in message.media {
                                    if let image = media as? TelegramMediaImage, let resource = largestImageRepresentation(image.representations)?.resource {
                                        self.disposable.add(messageMediaImageInteractiveFetched(context: context, message: message._asMessage(), image: image, resource: resource, storeToDownloadsPeerType: nil).start())
                                        candidateMediaReference = .message(message: MessageReference(message._asMessage()), media: media)
                                        break
                                    } else if let _ = media as? TelegramMediaFile {
                                        candidateMediaReference = .message(message: MessageReference(message._asMessage()), media: media)
                                        break
                                    } else if let webPage = media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let image = content.image, let resource = largestImageRepresentation(image.representations)?.resource  {
                                        self.disposable.add(messageMediaImageInteractiveFetched(context: context, message: message._asMessage(), image: image, resource: resource, storeToDownloadsPeerType: nil).start())
                                        candidateMediaReference = .webPage(webPage: WebpageReference(webPage), media: image)
                                        break
                                    }
                                }
                                if let imageReference = candidateMediaReference?.concrete(TelegramMediaImage.self) {
                                    updatedMediaReference = imageReference.abstract
                                    if let representation = largestRepresentationForPhoto(imageReference.media) {
                                        imageDimensions = representation.dimensions.cgSize
                                    }
                                } else if let fileReference = candidateMediaReference?.concrete(TelegramMediaFile.self) {
                                    updatedMediaReference = fileReference.abstract
                                    if let representation = largestImageRepresentation(fileReference.media.previewRepresentations), !fileReference.media.isSticker {
                                        imageDimensions = representation.dimensions.cgSize
                                    }
                                }
                                if let updatedMediaReference = updatedMediaReference, imageDimensions != nil {
                                    if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                                        imageSignal = chatMessagePhotoThumbnail(account: context.account, photoReference: imageReference, onlyFullSize: true)
                                    } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                                        if fileReference.media.isVideo {
                                            imageSignal = chatMessageVideoThumbnail(account: context.account, fileReference: fileReference)
                                            roundVideo = fileReference.media.isInstantVideo
                                        } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                                            imageSignal = chatWebpageSnippetFile(account: context.account, mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                                        }
                                    }
                                }
                                if let signal = imageSignal {
                                    return signal
                                }
                            }
                            return .complete()
                        } |> map{ f -> UIImage? in
                            var insets = UIEdgeInsets()
                            if roundVideo {
                                insets = UIEdgeInsets(top: -2, left: -2, bottom: -2, right: -2)
                            }
                            let context = f(TransformImageArguments(corners: ImageCorners(), imageSize: args.size, boundingSize: args.size, intrinsicInsets: insets, scale: 2.0))
                            return context?.generateImage()
                        }
                    } else {
                        return .complete()
                    }
                })
                
                let disposable = signal.start(next: { image in
                    if let image = image, let imageData = image.jpegData(compressionQuality: 0.5) {
                        sendData(manager: manager, data: imageData, key: key, ext: ".jpg", type: TGBridgeIncomingFileTypeImage, forceAsData: args.notification)
                    }
                    subscriber.putNext(key)
                }, completed: {
                    subscriber.putCompletion()
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        }
        return SSignal.fail(nil)
    }
}

final class WatchStickersHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [TGBridgeRecentStickersSubscription.self]
    }
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgeRecentStickersSubscription {
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<ItemCollectionsView, NoError> in
                    if let context = context {
                        return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 50) |> take(1)
                    } else {
                        return .complete()
                    }
                })
                let disposable = signal.start(next: { view in
                    var stickers: [TGBridgeDocumentMediaAttachment] = []
                    var added: Set<Int64> = []
                    outer: for view in view.orderedItemListsViews {
                        for entry in view.items {
                            if let file = entry.contents.get(SavedStickerItem.self)?.file {
                                if let sticker = makeBridgeDocument(file), !added.contains(sticker.documentId) {
                                    stickers.append(sticker)
                                    added.insert(sticker.documentId)
                                }
                            } else if let file = entry.contents.get(RecentMediaItem.self)?.media {
                                if let sticker = makeBridgeDocument(file), !added.contains(sticker.documentId) {
                                    stickers.append(sticker)
                                    added.insert(sticker.documentId)
                                }
                            }
                            if stickers.count == args.limit {
                                break outer
                            }
                        }
                    }
                    subscriber.putNext(stickers)
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        }
        return SSignal.fail(nil)
    }
}

final class WatchAudioHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [
            TGBridgeAudioSubscription.self,
            TGBridgeAudioSentSubscription.self
        ]
    }
    
    static private let disposable = DisposableSet()
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgeAudioSubscription {
            let key = "audio_\(args.peerId)_\(args.messageId)"
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<String, NoError> in
                    if let context = context, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
                        return context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: args.messageId)))
                        |> mapToSignal { message -> Signal<String, NoError> in
                            if let message = message {
                                for media in message.media {
                                    if let file = media as? TelegramMediaFile {
                                        self.disposable.add(messageMediaFileInteractiveFetched(context: context, message: message._asMessage(), file: file, userInitiated: true).start())
                                        return context.account.postbox.mediaBox.resourceData(file.resource)
                                        |> mapToSignal({ data -> Signal<String, NoError> in
                                            if let tempPath = manager.watchTemporaryStorePath, data.complete {
                                                let outputPath = tempPath + "/\(key).m4a"
                                                return legacyDecodeOpusAudio(path: data.path, outputPath: outputPath)
                                            } else {
                                                return .complete()
                                            }
                                        })
                                    }
                                }
                            }
                            return .complete()
                        }
                    } else {
                        return .complete()
                    }
                })
                
                let disposable = signal.start(next: { path in
                    let _ = manager.sendFile(url: URL(fileURLWithPath: path), metadata: [TGBridgeIncomingFileTypeKey: TGBridgeIncomingFileTypeAudio, TGBridgeIncomingFileIdentifierKey: key]).start()
                    subscriber.putNext(key)
                }, completed: {
                    subscriber.putCompletion()
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
            //let outputPath = manager.watchTemporaryStorePath + "/\(key).opus"
        } else if let _ = subscription as? TGBridgeAudioSentSubscription {

        }
        return SSignal.fail(nil)
    }
    
    static func handleFile(path: String, metadata: Dictionary<String, Any>, manager: WatchCommunicationManager) -> Signal<Void, NoError> {
        let randomId = metadata[TGBridgeIncomingFileRandomIdKey] as? Int64
        let peerId = metadata[TGBridgeIncomingFilePeerIdKey] as? Int64
        let replyToMid = metadata[TGBridgeIncomingFileReplyToMidKey] as? Int32
        
        if let randomId = randomId, let id = peerId, let peerId = makePeerIdFromBridgeIdentifier(id) {
            return combineLatest(manager.accountContext.get() |> take(1), legacyEncodeOpusAudio(path: path))
            |> map({ context, pathAndDuration -> Void in
                let (path, duration) = pathAndDuration
                if let context = context, let path = path, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    let resource = LocalFileMediaResource(fileId: randomId)
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    
                    var replyMessageId: MessageId? = nil
                    if let replyToMid = replyToMid, replyToMid != 0 {
                        replyMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToMid)
                    }
                    
                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(data.count), attributes: [.Audio(isVoice: true, duration: Int(duration), title: nil, performer: nil, waveform: nil)])), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil)]).start()
                }
            })
        } else {
            return .complete()
        }
    }
}

final class WatchLocationHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [TGBridgeNearbyVenuesSubscription.self]
    }
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgeNearbyVenuesSubscription  {
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<[ChatContextResultMessage], NoError> in
                    if let context = context {
                        return context.engine.peers.resolvePeerByName(name: "foursquare")
                        |> take(1)
                        |> mapToSignal { peer -> Signal<ChatContextResultCollection?, NoError> in
                            guard let peer = peer else {
                                return .single(nil)
                            }
                            return context.engine.messages.requestChatContextResults(botId: peer.id, peerId: context.account.peerId, query: "", location: .single((args.coordinate.latitude, args.coordinate.longitude)), offset: "")
                            |> map { results -> ChatContextResultCollection? in
                                return results?.results
                            }
                            |> `catch` { error -> Signal<ChatContextResultCollection?, NoError> in
                                return .single(nil)
                            }
                        }
                        |> mapToSignal { contextResult -> Signal<[ChatContextResultMessage], NoError> in
                            guard let contextResult = contextResult else {
                                return .single([])
                            }
                            return .single(contextResult.results.map { $0.message })
                        }
                    } else {
                        return .complete()
                    }
                })
                
                let disposable = signal.start(next: { results in
                    var venues: [TGBridgeLocationVenue] = []
                    for result in results {
                        if let venue = makeBridgeLocationVenue(result) {
                            venues.append(venue)
                        }
                    }
                    subscriber.putNext(venues)
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        }
        return SSignal.fail(nil)
    }
}

final class WatchPeerSettingsHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [
            TGBridgePeerSettingsSubscription.self,
            TGBridgePeerUpdateNotificationSettingsSubscription.self,
            TGBridgePeerUpdateBlockStatusSubscription.self
        ]
    }
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgePeerSettingsSubscription {
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<PeerView, NoError> in
                    if let context = context, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
                        return context.account.viewTracker.peerView(peerId)
                    } else {
                        return .complete()
                    }
                })
                let disposable = signal.start(next: { view in
                    var muted = false
                    var blocked = false
                    
                    if let notificationSettings = view.notificationSettings as? TelegramPeerNotificationSettings, case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                        muted = true
                    }
                    if let cachedData = view.cachedData as? CachedUserData {
                        blocked = cachedData.isBlocked
                    }
                    
                    subscriber.putNext([ "muted": muted, "blocked": blocked ])
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        } else {
            return SSignal { subscriber in
                let signal = manager.accountContext.get()
                |> take(1)
                |> mapToSignal({ context -> Signal<Bool, NoError> in
                    if let context = context {
                        var signal: Signal<Void, NoError>?
                        
                        if let args = subscription as? TGBridgePeerUpdateNotificationSettingsSubscription, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
                            signal = context.engine.peers.togglePeerMuted(peerId: peerId)
                        } else if let args = subscription as? TGBridgePeerUpdateBlockStatusSubscription, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
                            signal = context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peerId, isBlocked: args.blocked)
                        }
                        
                        if let signal = signal {
                            return signal |> mapToSignal({ _ in
                                return .single(true)
                            })
                        } else {
                            return .complete()
                        }
                    } else {
                        return .complete()
                    }
                })
                
                let disposable = signal.start(next: { _ in
                    subscriber.putNext(true)
                },  completed: {
                    subscriber.putCompletion()
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            }
        }
    }
}

final class WatchContinuationHandler: WatchRequestHandler {
    static var handledSubscriptions: [Any] {
        return [TGBridgeRemoteSubscription.self]
    }
    
    static func handle(subscription: TGBridgeSubscription, manager: WatchCommunicationManager) -> SSignal {
        if let args = subscription as? TGBridgeRemoteSubscription, let peerId = makePeerIdFromBridgeIdentifier(args.peerId) {
            manager.requestNavigateToMessage(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: args.messageId))
        }
        return SSignal.fail(nil)
    }
}
