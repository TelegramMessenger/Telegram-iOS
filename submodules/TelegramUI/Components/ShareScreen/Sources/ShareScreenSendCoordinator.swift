import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import ChatMessagePaymentAlertController

final class ShareScreenSendCoordinator {
    private enum SendError { case unavailable }
    private(set) var isEnqueuing = false
    private let context: AccountContext
    private let subject: ShareScreen.Subject
    private let disposable = MetaDisposable()
    private(set) var isSending = false
    private var silently = false
    var updated: (() -> Void)?
    var externalStatusUpdated: ((ShareControllerExternalStatus) -> Void)?
    var present: ((ViewController) -> Void)?
    var premiumRequired: ((EnginePeer) -> Void)?
    var navigationController: (() -> NavigationController?)?
    var enqueued: (([EnginePeer.Id], [Int64]) -> Void)?
    var mediaStartTimestamp: Int32?
    var willEnqueue: (([EnginePeer.Id]) -> Void)?
    var hidesSenderNames = false

    init(context: AccountContext, subject: ShareScreen.Subject) {
        self.context = context
        self.subject = subject
    }

    deinit {
        self.disposable.dispose()
    }

    func cancelPreparation(notify: Bool = true) {
        guard !self.isEnqueuing else { return }
        self.disposable.set(nil)
        self.isSending = false
        if notify { self.updated?() }
    }

    static func messageCount(subject: ShareScreen.Subject, caption: NSAttributedString) -> Int {
        switch subject {
        case let .fromExternal(count, _):
            return count
        case .url, .image:
            return 1
        case .quote, .mapMedia:
            return 1 + (caption.length == 0 ? 0 : 1)
        case let .media(reference):
            return 1 + (Self.forwardSource(reference) != nil && caption.length != 0 ? 1 : 0)
        case .text:
            return 1 + (caption.length == 0 ? 0 : 1)
        case let .messages(messages):
            return messages.count + (caption.length == 0 ? 0 : 1)
        }
    }

    var sendsForwards: Bool {
        switch self.subject {
        case .messages:
            return true
        case let .media(reference):
            return Self.forwardSource(reference) != nil
        default:
            return false
        }
    }

    private static func forwardSource(_ reference: AnyMediaReference) -> EngineMessage.Id? {
        if case let .message(message, _) = reference, let id = message.id,
           [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(id.peerId.namespace) {
            return id
        }
        return nil
    }

    private func isMultipleSlowmodeMessages(caption: NSAttributedString) -> Bool {
        if case let .messages(messages) = self.subject,
           let groupingKey = messages.first?.groupingKey,
           messages.allSatisfy({ $0.groupingKey == groupingKey }) {
            return caption.length > 0
        }
        return Self.messageCount(subject: self.subject, caption: caption) > 1
    }

    func send(peers: [EnginePeer], topics: [EnginePeer.Id: Int64], caption: NSAttributedString, silently: Bool = false) {
        guard !self.isSending, !peers.isEmpty, Self.messageCount(subject: self.subject, caption: caption) > 0 else { return }
        self.silently = silently
        self.isSending = true
        self.updated?()
        let context = self.context
        let ids = peers.map(\.id)
        self.disposable.set((context.engine.peers.isPremiumRequiredToContact(ids)
        |> castError(SendError.self)
        |> timeout(15.0, queue: Queue.mainQueue(), alternate: .fail(.unavailable))
        |> mapToSignal { requirements in
            return context.engine.data.get(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.SlowmodeValidUntilTimeout.init(id:))),
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
            )
            |> castError(SendError.self)
            |> map { (requirements, $0, $1) }
        }
        |> deliverOnMainQueue).start(next: { [weak self] requirements, slowmodeValidUntil, currentPeers in
            guard let self else { return }
            let data = context.sharedContext.currentPresentationData.with { $0 }
            var stars: [EnginePeer.Id: StarsAmount] = [:]
            for peer in peers {
                if case .premium = requirements[peer.id] {
                    self.isSending = false
                    self.updated?()
                    self.premiumRequired?(peer)
                    return
                }
                if !canSendMessagesToPeer(peer) || self.isRestricted(peer: peer, caption: caption) {
                    self.fail(data.strings.Login_UnknownError, peer: peer)
                    return
                }
                if case let .channel(channel) = peer, channel.isRestrictedBySlowmode {
                    if self.isMultipleSlowmodeMessages(caption: caption) {
                        self.fail(data.strings.Share_MultipleMessagesDisabled, peer: peer)
                        return
                    }
                    if let validUntil = slowmodeValidUntil[peer.id] ?? nil, validUntil > Int32(Date().timeIntervalSince1970) {
                        self.fail(data.strings.Chat_SlowmodeSendError, peer: peer)
                        return
                    }
                }
                if case let .stars(amount) = requirements[peer.id] {
                    stars[peer.id] = amount
                } else if let currentPeer = currentPeers[peer.id] ?? nil, case let .channel(channel) = currentPeer {
                    stars[peer.id] = channel.sendPaidMessageStars
                }
            }
            let total = stars.values.reduce(StarsAmount.zero, +)
            if total.value > 0 {
                self.isSending = false
                self.updated?()
                self.present?(chatMessagePaymentAlertController(
                    context: context, presentationData: data, updatedPresentationData: nil,
                    peers: peers.filter { stars[$0.id] != nil }.map { EngineRenderedPeer(peer: $0) },
                    count: Int32(Self.messageCount(subject: self.subject, caption: caption)),
                    amount: total, totalAmount: total, hasCheck: false, navigationController: self.navigationController?(),
                    completion: { [weak self] _ in
                        guard let self, !self.isSending else { return }
                        self.isSending = true
                        self.updated?()
                        self.enqueue(peers: peers, topics: topics, caption: caption, stars: stars)
                    }
                ))
            } else {
                self.enqueue(peers: peers, topics: topics, caption: caption, stars: stars)
            }
        }, error: { [weak self] _ in
            guard let self, let peer = peers.first else { return }
            self.fail(context.sharedContext.currentPresentationData.with { $0.strings.Login_UnknownError }, peer: peer)
        }))
    }

    private func fail(_ text: String, peer: EnginePeer) {
        self.isSending = false
        self.updated?()
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        self.present?(standardTextAlertController(theme: AlertControllerTheme(presentationData: data), title: peer.compactDisplayTitle, text: text, actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]))
    }

    private func isRestricted(peer: EnginePeer, caption: NSAttributedString) -> Bool {
        func banned(_ flag: TelegramChatBannedRightsFlags) -> Bool {
            switch peer {
            case let .channel(channel): return channel.hasBannedPermission(flag) != nil
            case let .legacyGroup(group): return group.hasBannedPermission(flag)
            default: return false
            }
        }
        if caption.length > 0 && banned(.banSendText) { return true }
        switch self.subject {
        case .fromExternal:
            return false
        case .url, .text, .quote:
            return banned(.banSendText)
        case .mapMedia:
            return false
        case .image:
            return banned(.banSendPhotos)
        case let .media(reference):
            if reference.media is TelegramMediaImage { return banned(.banSendPhotos) }
            if let file = reference.media as? TelegramMediaFile {
                if file.isSticker || file.isAnimated { return banned(.banSendStickers) }
                if file.isInstantVideo { return banned(.banSendInstantVideos) }
                if file.isVoice { return banned(.banSendVoice) }
                if file.isMusic { return banned(.banSendMusic) }
                if file.isVideo { return banned(.banSendVideos) }
                return banned(.banSendFiles)
            }
            return false
        case let .messages(messages):
            for message in messages {
                if message.isCopyProtected() { return true }
                if !message.text.isEmpty && banned(.banSendText) { return true }
                for media in message.media {
                    if media is TelegramMediaImage && banned(.banSendPhotos) { return true }
                    if media is TelegramMediaPoll && banned(.banSendPolls) { return true }
                    if let file = media as? TelegramMediaFile {
                        let flag: TelegramChatBannedRightsFlags
                        if file.isSticker || file.isAnimated { flag = .banSendStickers }
                        else if file.isInstantVideo { flag = .banSendInstantVideos }
                        else if file.isVoice { flag = .banSendVoice }
                        else if file.isMusic { flag = .banSendMusic }
                        else if file.isVideo { flag = .banSendVideos }
                        else { flag = .banSendFiles }
                        if banned(flag) { return true }
                    }
                }
            }
            return false
        }
    }

    private func enqueue(peers: [EnginePeer], topics: [EnginePeer.Id: Int64], caption: NSAttributedString, stars: [EnginePeer.Id: StarsAmount]) {
        self.willEnqueue?(peers.map(\.id))
        if case let .fromExternal(_, send) = self.subject {
            self.externalStatusUpdated?(.preparing(false))
            var didComplete = false
            self.disposable.set((send(peers.map(\.id), topics, stars, caption.string, ShareControllerAppAccountContext(context: self.context), self.silently)
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if case .done = status { didComplete = true }
                self?.externalStatusUpdated?(status)
            }, error: { [weak self] error in
                guard let self, let peer = peers.first else { return }
                let strings = self.context.sharedContext.currentPresentationData.with { $0.strings }
                let text: String
                switch error {
                case .generic: text = strings.Login_UnknownError
                case .fileTooBig: text = strings.Conversation_UploadFileTooLarge
                }
                self.fail(text, peer: peer)
            }, completed: { [weak self] in
                if !didComplete { self?.externalStatusUpdated?(.done) }
            }))
            return
        }
        self.isEnqueuing = true
        var correlationIds: [Int64] = []
        var signals: [Signal<[EngineMessage.Id?], NoError>] = []
        for peer in peers {
            let threadId = topics[peer.id]
            var attributes: [EngineMessage.Attribute] = []
            if let amount = stars[peer.id] {
                attributes.append(PaidStarsMessageAttribute(stars: amount, postponeSending: false))
            }
            if self.silently {
                attributes.append(NotificationInfoMessageAttribute(flags: .muted))
            }
            if self.hidesSenderNames {
                attributes.append(ForwardOptionsMessageAttribute(hideNames: true, hideCaptions: false))
            }
            func textMessage(_ text: NSAttributedString, mediaReference: AnyMediaReference? = nil) -> EnqueueMessage {
                let correlationId = Int64.random(in: Int64.min ... Int64.max)
                correlationIds.append(correlationId)
                var inlineStickers: [EngineMedia.Id: EngineRawMedia] = [:]
                text.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: text.length), options: []) { value, _, _ in
                    if let emoji = value as? ChatTextInputTextCustomEmojiAttribute, let file = emoji.file { inlineStickers[file.fileId] = file }
                }
                return .message(text: text.string, attributes: attributes + [TextEntitiesMessageAttribute(entities: generateChatInputTextEntities(text))], inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: threadId.map { EngineMessageReplySubject(messageId: EngineMessage.Id(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(clamping: $0)), quote: nil, innerSubject: nil) }, replyToStoryId: nil, localGroupingKey: nil, correlationId: correlationId, bubbleUpEmojiOrStickersets: [])
            }
            var messages: [EnqueueMessage] = []
            switch self.subject {
            case .fromExternal:
                return
            case let .image(representations):
                let image = TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: representations.map { $0.representation }, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                messages.append(textMessage(caption, mediaReference: .standalone(media: image)))
            case let .media(reference):
                if let source = Self.forwardSource(reference) {
                    if caption.length > 0 { messages.append(textMessage(caption)) }
                    let correlationId = Int64.random(in: Int64.min ... Int64.max)
                    correlationIds.append(correlationId)
                    var forwardAttributes = attributes
                    if let timestamp = self.mediaStartTimestamp {
                        forwardAttributes.append(ForwardVideoTimestampAttribute(timestamp: timestamp))
                    }
                    messages.append(.forward(source: source, threadId: threadId, grouping: .auto, attributes: forwardAttributes, correlationId: correlationId))
                } else {
                    messages.append(textMessage(caption, mediaReference: reference))
                }
            case let .url(url):
                let text = NSMutableAttributedString(string: url)
                if caption.length > 0 {
                    text.append(NSAttributedString(string: "\n\n"))
                    text.append(caption)
                }
                messages.append(textMessage(text))
            case let .text(text):
                if caption.length > 0 { messages.append(textMessage(caption)) }
                messages.append(textMessage(NSAttributedString(string: text)))
            case let .quote(text, url):
                if caption.length > 0 { messages.append(textMessage(caption)) }
                let quote = NSMutableAttributedString(string: text, attributes: [ChatTextInputAttributes.italic: true as NSNumber])
                quote.append(NSAttributedString(string: "\n\n\(url)"))
                messages.append(textMessage(quote))
            case let .mapMedia(media):
                if caption.length > 0 { messages.append(textMessage(caption)) }
                messages.append(textMessage(NSAttributedString(string: ""), mediaReference: .standalone(media: media)))
            case let .messages(source):
                if caption.length > 0 { messages.append(textMessage(caption)) }
                for message in source {
                    let correlationId = Int64.random(in: Int64.min ... Int64.max)
                    correlationIds.append(correlationId)
                    messages.append(.forward(source: message.id, threadId: threadId, grouping: .auto, attributes: attributes, correlationId: correlationId))
                }
            }
            signals.append(enqueueMessages(account: self.context.account, peerId: peer.id, messages: messages))
        }
        self.disposable.set((combineLatest(signals) |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else { return }
            self.isEnqueuing = false
            self.isSending = false
            self.updated?()
            self.enqueued?(peers.map(\.id), correlationIds)
        }))
    }
}
