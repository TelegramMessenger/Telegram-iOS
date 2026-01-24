import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyMediaPickerUI
import ChatHistorySearchContainerNode
import MediaResources
import TelegramUIPreferences

extension PeerInfoScreenNode {
    func openMessage(id: MessageId) -> Bool {
        guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return false
        }
        var foundGalleryMessage: Message?
        if let searchContentNode = self.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode {
            if let galleryMessage = searchContentNode.messageForGallery(id) {
                self.context.engine.messages.ensureMessagesAreLocallyAvailable(messages: [EngineMessage(galleryMessage)])
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
        
        return self.context.sharedContext.openChatMessage(OpenChatMessageParams(context: self.context, chatLocation: self.chatLocation, chatFilterTag: nil, chatLocationContextHolder: self.chatLocationContextHolder, message: galleryMessage, standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, present: { [weak self] c, a, _ in
            self?.controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
        }, transitionNode: { [weak self] messageId, media, _ in
            guard let strongSelf = self else {
                return nil
            }
            return strongSelf.paneContainerNode.transitionNodeForGallery(messageId: messageId, media: media)
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
                strongSelf.context.sharedContext.openAddContact(context: strongSelf.context, firstName: "", lastName: "", phoneNumber: phoneNumber, label: defaultContactLabel, present: { [weak self] controller, arguments in
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
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        mediaReference = AnyMediaReference.standalone(media: image)
                    } else if let file = media as? TelegramMediaFile {
                        mediaReference = AnyMediaReference.standalone(media: file)
                    }
                }
                
                if let mediaReference = mediaReference, let peer = message.peers[message.id.peerId] {
                    legacyMediaEditor(context: strongSelf.context, peer: peer, threadTitle: message.associatedThreadInfo?.title, media: mediaReference, mode: .draw, initialCaption: NSAttributedString(), snapshots: snapshots, transitionCompletion: {
                        transitionCompletion()
                    }, getCaptionPanelView: {
                        return nil
                    }, sendMessagesWithSignals: { [weak self] signals, _, _, _ in
                        if let strongSelf = self {
                            strongSelf.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(context: strongSelf.context, account: strongSelf.context.account, signals: signals!)
                            |> deliverOnMainQueue).startStrict(next: { [weak self] messages in
                                if let strongSelf = self {
                                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: strongSelf.peerId, messages: messages.map { $0.message }).startStandalone()
                                }
                            }))
                        }
                    }, present: { [weak self] c, a in
                        self?.controller?.present(c, in: .window(.root), with: a)
                    })
                }
            })
        }, updateCanReadHistory: { _ in
        }), centralItemUpdated: { [weak self] messageId in
            let _ = self?.paneContainerNode.requestExpandTabs?()
            self?.paneContainerNode.currentPane?.node.ensureMessageIsVisible(id: messageId)
        }))
    }
}
