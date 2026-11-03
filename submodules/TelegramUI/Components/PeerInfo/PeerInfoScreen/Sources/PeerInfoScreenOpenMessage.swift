import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import LegacyMediaPickerUI
import MediaPickerUI
import ChatHistorySearchContainerNode
import ChatScheduleTimeController
import MediaResources
import TelegramUIPreferences

extension PeerInfoScreenNode {
    private func presentMediaScheduleTimePicker(completion: @escaping (Int32, Bool) -> Void) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        let _ = (self.context.account.viewTracker.peerView(peerId)
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peerView in
            guard let self, let controller = self.controller, let peer = peerViewMainPeer(peerView) else {
                return
            }

            var sendWhenOnlineAvailable = false
            if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence, case .present = presence.status {
                sendWhenOnlineAvailable = true
            }
            if peer.id.namespace == Namespaces.Peer.CloudUser && peer.id.id._internalGetInt64Value() == 777000 {
                sendWhenOnlineAvailable = false
            }

            let mode: ChatScheduleTimeScreen.Mode
            if peerId == self.context.account.peerId {
                mode = .reminders
            } else {
                mode = .scheduledMessages(peerId: peer.id, sendWhenOnlineAvailable: sendWhenOnlineAvailable)
            }

            let scheduleController = ChatScheduleTimeScreen(
                context: self.context,
                mode: mode,
                currentTime: nil,
                currentRepeatPeriod: nil,
                minimalTime: nil,
                silentPosting: false,
                isDark: true,
                completion: { result in
                    completion(result.time, result.silentPosting)
                }
            )
            self.view.endEditing(true)
            controller.present(scheduleController, in: .window(.root))
        })
    }

    private func openScheduledMessages() {
        guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }

        var mappedChatLocation = self.chatLocation
        if case let .replyThread(message) = self.chatLocation, message.peerId == self.context.account.peerId {
            mappedChatLocation = .peer(id: self.context.account.peerId)
        }

        let scheduledController = self.context.sharedContext.makeChatController(
            context: self.context,
            chatLocation: mappedChatLocation,
            subject: .scheduledMessages,
            botStart: nil,
            mode: .standard(.default),
            params: nil
        )
        scheduledController.navigationPresentation = .modal
        navigationController.pushViewController(scheduledController)
    }

    private func transformEditedMediaMessages(_ messages: [EnqueueMessage], replyToMessageId: EngineMessage.Id, silentPosting: Bool, scheduleTime: Int32?) -> [EnqueueMessage] {
        let replySubject = EngineMessageReplySubject(messageId: replyToMessageId, quote: nil, innerSubject: nil)
        let defaultThreadId: Int64?
        if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.peerId == self.context.account.peerId {
            defaultThreadId = replyThreadMessage.threadId
        } else {
            defaultThreadId = nil
        }

        return messages.map { message in
            var message = message.withUpdatedReplyToMessageId(replySubject)

            if let defaultThreadId {
                var updateThreadId = false
                switch message {
                case let .message(_, _, _, _, threadId, _, _, _, _, _):
                    updateThreadId = threadId == nil
                case let .forward(_, threadId, _, _, _):
                    updateThreadId = threadId == nil
                }
                if updateThreadId {
                    message = message.withUpdatedThreadId(defaultThreadId)
                }
            }

            return message.withUpdatedAttributes { attributes in
                var attributes = attributes
                for i in (0 ..< attributes.count).reversed() {
                    if attributes[i] is NotificationInfoMessageAttribute || attributes[i] is OutgoingScheduleInfoMessageAttribute {
                        attributes.remove(at: i)
                    }
                }
                if silentPosting {
                    attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                }
                if let scheduleTime {
                    attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime, repeatPeriod: nil))
                }
                return attributes
            }
        }
    }

    func openMessage(id: EngineMessage.Id) -> Bool {
        guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return false
        }
        var foundGalleryMessage: EngineMessage?
        if let searchContentNode = self.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode {
            if let galleryMessage = searchContentNode.messageForGallery(id) {
                self.context.engine.messages.ensureMessagesAreLocallyAvailable(messages: [galleryMessage])
                foundGalleryMessage = galleryMessage
            }
        }
        if foundGalleryMessage == nil, let galleryMessage = self.paneContainerNode.findLoadedMessage(id: id) {
            foundGalleryMessage = galleryMessage
        }

        guard let galleryMessage = foundGalleryMessage else {
            return false
        }
        self.view.endEditing(true)

        // The gallery browses the chat the panes (and the in-profile search) list.
        let sharedMediaChatLocation = self.sharedMediaChatLocation
        return self.context.sharedContext.openChatMessage(OpenChatMessageParams(context: self.context, chatLocation: sharedMediaChatLocation.chatLocation, chatFilterTag: nil, chatLocationContextHolder: sharedMediaChatLocation.chatLocationContextHolder, message: galleryMessage._asMessage(), standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, present: { [weak self] c, a, _ in
            self?.controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
        }, transitionNode: { [weak self] messageId, media, _ in
            guard let strongSelf = self else {
                return nil
            }
            return strongSelf.paneContainerNode.transitionNodeForGallery(messageId: messageId, media: EngineMedia(media))
        }, addToTransitionSurface: { [weak self] view in
            guard let strongSelf = self else {
                return
            }
            strongSelf.paneContainerNode.currentPane?.node.addToTransitionSurface(view: view)
        }, openUrl: { [weak self] url in
            self?.openUrl(url: url, concealed: false, external: false)
        }, openPeer: { [weak self] peer, navigation in
            self?.openPeer(peerId: peer.id, navigation: navigation)
        }, callPeer: { peerId, isVideo in
        }, openConferenceCall: { _ in
        }, enqueueMessage: { _ in
        }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, actionInteraction: GalleryControllerActionInteraction(openUrl: { [weak self] url, concealed, forceExternal in
            if let strongSelf = self {
                strongSelf.openUrl(url: url, concealed: false, external: forceExternal)
            }
        }, openUrlIn: { [weak self] url in
            if let strongSelf = self {
                strongSelf.openUrlIn(url)
            }
        }, openPeerMention: { [weak self] mention in
            if let strongSelf = self {
                strongSelf.openPeerMention(mention)
            }
        }, openPeer: { [weak self] peer in
            if let strongSelf = self {
                strongSelf.openPeer(peerId: peer.id, navigation: .default)
            }
        }, openHashtag: { [weak self] peerName, hashtag in
            if let strongSelf = self {
                strongSelf.openHashtag(hashtag, peerName: peerName)
            }
        }, openBotCommand: { _ in
        }, openAd: { _ in
        }, addContact: { [weak self] phoneNumber in
            if let strongSelf = self {
                strongSelf.context.sharedContext.openAddContact(context: strongSelf.context, peer: nil, firstName: "", lastName: "", phoneNumber: phoneNumber, label: defaultContactLabel, present: { [weak self] controller, arguments in
                    self?.controller?.present(controller, in: .window(.root), with: arguments)
                }, pushController: { [weak self] controller in
                    if let strongSelf = self {
                        strongSelf.controller?.push(controller)
                    }
                }, completed: {})
            }
        }, storeMediaPlaybackState: { [weak self] messageId, timestamp, playbackRate in
            guard let strongSelf = self else {
                return
            }
            var storedState: MediaPlaybackStoredState?
            if let timestamp = timestamp {
                storedState = MediaPlaybackStoredState(timestamp: timestamp, playbackRate: AudioPlaybackRate(playbackRate))
            }
            let _ = updateMediaPlaybackStoredStateInteractively(engine: strongSelf.context.engine, messageId: messageId, state: storedState).startStandalone()
        }, editMedia: { [weak self] messageId, snapshots, transitionCompletion in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] message in
                guard let strongSelf = self, let message = message else {
                    return
                }
                
                var mediaReference: AnyMediaReference?
                for media in message.engineMedia {
                    if case let .image(image) = media {
                        mediaReference = AnyMediaReference.standalone(media: image)
                    } else if case let .file(file) = media {
                        mediaReference = AnyMediaReference.standalone(media: file)
                    }
                }

                if let mediaReference = mediaReference, let peer = message.peers[message.id.peerId] {
                    let hasSilentPosting = peer.id != strongSelf.context.account.peerId
                    let hasSchedule = peer.id.namespace != Namespaces.Peer.SecretChat
                    legacyMediaEditor(context: strongSelf.context, peer: EnginePeer(peer), threadTitle: message.associatedThreadInfo?.title, media: mediaReference, mode: .draw, initialCaption: NSAttributedString(), snapshots: snapshots, transitionCompletion: {

                        transitionCompletion()
                    }, getCaptionPanelView: {
                        return nil
                    }, photoToolbarView: { [context = strongSelf.context] backButton, doneButton, solidBackground, hasSendStarsButton in
                        return makeMediaPickerPhotoToolbarView(context: context, backButton: backButton, doneButton: doneButton, solidBackground: solidBackground, hasSendStarsButton: hasSendStarsButton)
                    }, hasSilentPosting: hasSilentPosting, hasSchedule: hasSchedule, reminder: peer.id == strongSelf.context.account.peerId, presentSchedulePicker: { [weak self] _, done in
                        self?.presentMediaScheduleTimePicker(completion: { time, silentPosting in
                            done(time, silentPosting)
                        })
                    }, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime, _ in
                        if let strongSelf = self {
                            strongSelf.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(context: strongSelf.context, account: strongSelf.context.account, signals: signals!)
                            |> deliverOnMainQueue).startStrict(next: { [weak self] messages in
                                if let strongSelf = self {
                                    let effectiveScheduleTime = scheduleTime == 0 ? nil : scheduleTime
                                    let mappedMessages = strongSelf.transformEditedMediaMessages(messages.map(\.message), replyToMessageId: message.id, silentPosting: silentPosting, scheduleTime: effectiveScheduleTime)
                                    let _ = (enqueueMessages(account: strongSelf.context.account, peerId: strongSelf.peerId, messages: mappedMessages)
                                    |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                                        guard let self, let effectiveScheduleTime, effectiveScheduleTime != scheduleWhenOnlineTimestamp else {
                                            return
                                        }
                                        self.openScheduledMessages()
                                    })
                                }
                            }))
                        }
                    }, present: { [weak self] c, a in
                        self?.controller?.present(c, in: .window(.root), with: a)
                    })
                }
            })
        }, updateCanReadHistory: { _ in
        }, sendSticker: nil), centralItemUpdated: { [weak self] messageId in
            let _ = self?.paneContainerNode.requestExpandTabs?()
            self?.paneContainerNode.currentPane?.node.ensureMessageIsVisible(id: messageId)
        }))
    }
}
