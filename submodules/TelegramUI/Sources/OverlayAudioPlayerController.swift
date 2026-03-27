import Foundation
import UIKit
import TelegramCore
import Postbox
import Display
import SwiftSignalKit
import TelegramUIPreferences
import AccountContext
import ShareController
import UndoUI
import AttachmentFileController
import LegacyMediaPickerUI
import ICloudResources

final class OverlayAudioPlayerControllerImpl: ViewController, OverlayAudioPlayerController {
    private let context: AccountContext
    let chatLocation: ChatLocation
    let type: MediaManagerPlayerType
    let initialMessageId: MessageId
    let initialOrder: MusicPlaybackSettingsOrder
    let playlistLocation: SharedMediaPlaylistLocation?
    
    private(set) weak var parentNavigationController: NavigationController?
    
    private var animatedIn = false
    
    private var controllerNode: OverlayAudioPlayerControllerNode {
        return self.displayNode as! OverlayAudioPlayerControllerNode
    }
    
    private var accountInUseDisposable: Disposable?
    
    init(
        context: AccountContext,
        chatLocation: ChatLocation,
        type: MediaManagerPlayerType,
        initialMessageId: MessageId,
        initialOrder: MusicPlaybackSettingsOrder,
        playlistLocation: SharedMediaPlaylistLocation? = nil,
        parentNavigationController: NavigationController?
    ) {
        self.context = context
        self.chatLocation = chatLocation
        self.type = type
        self.initialMessageId = initialMessageId
        self.initialOrder = initialOrder
        self.playlistLocation = playlistLocation
        self.parentNavigationController = parentNavigationController
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.automaticallyControlPresentationContextLayout = false
        
        self.ready.set(.never())
        
        self.accountInUseDisposable = context.sharedContext.setAccountUserInterfaceInUse(context.account.id)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.accountInUseDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = OverlayAudioPlayerControllerNode(
            context: self.context,
            chatLocation: self.chatLocation,
            type: self.type,
            initialMessageId: self.initialMessageId,
            initialOrder: self.initialOrder,
            playlistLocation: self.playlistLocation,
            requestDismiss: { [weak self] in
                self?.dismiss()
            },
            requestShare: { [weak self] subject in
                if let strongSelf = self {
                    var canShowInChat = false
                    if case .messages = subject {
                        canShowInChat = true
                    }
                    let shareController = ShareController(context: strongSelf.context, subject: subject, showInChat: canShowInChat ? { message in
                        if let strongSelf = self {
                            strongSelf.context.sharedContext.navigateToChat(accountId: strongSelf.context.account.id, peerId: message.id.peerId, messageId: message.id)
                            strongSelf.dismiss()
                        }
                    } : nil, externalShare: true)
                    shareController.completed = { [weak self] peerIds in
                        if let strongSelf = self {
                            let _ = (strongSelf.context.engine.data.get(
                                EngineDataList(
                                    peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                                )
                            )
                                     |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                                if let strongSelf = self {
                                    let peers = peerList.compactMap { $0 }
                                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                    
                                    let text: String
                                    var savedMessages = false
                                    if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                        text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                                        savedMessages = true
                                    } else {
                                        if peers.count == 1, let peer = peers.first {
                                            var peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                            peerName = peerName.replacingOccurrences(of: "**", with: "")
                                            text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
                                        } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                            var firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                            firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                                            var secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                            secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                                            text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                        } else if let peer = peers.first {
                                            var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                            peerName = peerName.replacingOccurrences(of: "**", with: "")
                                            text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                                        } else {
                                            text = ""
                                        }
                                    }
                                    
                                    strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                                        if savedMessages, let self, action == .info {
                                            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                                |> deliverOnMainQueue).start(next: { [weak self] peer in
                                                guard let self, let peer else {
                                                    return
                                                }
                                                guard let navigationController = self.parentNavigationController else {
                                                    return
                                                }
                                                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                                            })
                                        }
                                        return false
                                    }), in: .current)
                                }
                            })
                        }
                    }
                    strongSelf.controllerNode.view.endEditing(true)
                    strongSelf.present(shareController, in: .window(.root))
                }
            },
            requestSearchByArtist: { [weak self] artist in
                guard let self else {
                    return
                }
                self.context.sharedContext.openSearch(filter: .music, query: artist)
                self.dismiss()
            },
            requestAdd: { [weak self] in
                guard let self, let navigationController = self.parentNavigationController else {
                    return
                }
                var dismissImpl: (() -> Void)?
                let controller = makeAttachmentFileControllerImpl(
                    context: self.context,
                    mode: .audio(.savedMusic),
                    presentFiles: { [weak self] in
                        guard let self else {
                            return
                        }
                        dismissImpl?()
                        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                        let controller = legacyICloudFilePicker(theme: presentationData.theme, mode: .default, documentTypes: ["public.mp3", "public.mpeg-4-audio", "public.aac-audio", "org.xiph.flac"], completion: { [weak self] urls in
                            guard let self, let url = urls.first else {
                                return
                            }
                            
                            let _ = (iCloudFileDescription(url)
                            |> deliverOnMainQueue).start(next: { [weak self] item in
                                guard let self, let item else {
                                    return
                                }
                                let fileId = Int64.random(in: Int64.min ... Int64.max)
                                let mimeType = guessMimeTypeByFileExtension((item.fileName as NSString).pathExtension)
                                var previewRepresentations: [TelegramMediaImageRepresentation] = []
                                if mimeType.hasPrefix("image/") || mimeType == "application/pdf" {
                                    previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: ICloudFileResource(urlData: item.urlData, thumbnail: true), progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                                }
                                var attributes: [TelegramMediaFileAttribute] = []
                                attributes.append(.FileName(fileName: item.fileName))
                                if let audioMetadata = item.audioMetadata {
                                    attributes.append(.Audio(isVoice: false, duration: audioMetadata.duration, title: audioMetadata.title, performer: audioMetadata.performer, waveform: nil))
                                }
                                
                                let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int64(item.fileSize), attributes: attributes, alternativeRepresentations: [])
                                
                                let _ = (standaloneUploadedFile(
                                    postbox: self.context.account.postbox,
                                    network: self.context.account.network,
                                    peerId: self.context.account.peerId,
                                    text: "",
                                    source: .resource(.media(media: .standalone(media: file), resource: file.resource)),
                                    thumbnailData: file.immediateThumbnailData,
                                    mimeType: file.mimeType,
                                    attributes: file.attributes,
                                    hintFileIsLarge: false
                                )
                                |> deliverOnMainQueue).start(next: { [weak self] value in
                                    guard let self else {
                                        return
                                    }
                                    switch value {
                                    case let .result(result):
                                        switch result {
                                        case let .media(resultMedia):
                                            if let resultFile = resultMedia.media as? TelegramMediaFile {
                                                self.context.account.postbox.mediaBox.moveResourceData(from: file.resource.id, to: resultFile.resource.id, synchronous: true)
                                                self.controllerNode.addToSavedMusic(file: .standalone(media: file))
                                            }
                                        }
                                    default:
                                        break
                                    }
                                })
                            })
                        })
                        self.present(controller, in: .window(.root))
                    },
                    send: { [weak self] mediaReferences, _, _, _ in
                        guard let self, let reference = mediaReferences.first?.concrete(TelegramMediaFile.self) else {
                            return
                        }
                        self.controllerNode.addToSavedMusic(file: reference)
                    }
                ) as! AttachmentFileControllerImpl
                controller.navigationPresentation = .modal
                navigationController.pushViewController(controller)
                dismissImpl = { [weak controller] in
                    controller?.dismiss()
                }
            },
            getParentController: { [weak self] in
                return self
            }
        )
        
        self.ready.set(self.controllerNode.ready.get())
        
        self.displayNodeDidLoad()
    }
    
    override public func loadView() {
        super.loadView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            if let _ = self?.navigationController {
                self?.dismiss(animated: false, completion: nil)
            } else {
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
            completion?()
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
