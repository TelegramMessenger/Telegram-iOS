import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox

final class MediaNavigationAccessoryItemListNode: ASDisplayNode {
    static let minimizedPanelHeight: CGFloat = 31.0
    
    private var theme: PresentationTheme
    
    var collapse: (() -> Void)?
    
    private var previousMaximizedHeight: CGFloat?
    
    private let account: Account
    
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let panelNode: HighlightTrackingButtonNode
    private let panelHandleNode: ASImageNode
    private let contentNode: ASDisplayNode
    private var listNode: ChatHistoryListNode?
    
    var stateAndStatus: AudioPlaylistStateAndStatus? {
        didSet {
            if self.stateAndStatus != oldValue {
                let previousPlaylistPeerId = (oldValue?.state.playlistId as? PeerMessageHistoryAudioPlaylistId)?.peerId
                let updatedPlaylistPeerId = (self.stateAndStatus?.state.playlistId as? PeerMessageHistoryAudioPlaylistId)?.peerId
                
                if previousPlaylistPeerId != updatedPlaylistPeerId {
                    if let listNode = self.listNode {
                        listNode.removeFromSupernode()
                        self.listNode = nil
                    }
                    if let updatedPlaylistPeerId = updatedPlaylistPeerId {
                        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] id in
                            if let strongSelf = self, let listNode = strongSelf.listNode {
                                var galleryMedia: Media?
                                if let message = listNode.messageInCurrentHistoryView(id) {
                                    for media in message.media {
                                        if let file = media as? TelegramMediaFile {
                                            galleryMedia = file
                                        } else if let image = media as? TelegramMediaImage {
                                            galleryMedia = image
                                        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                            if let file = content.file {
                                                galleryMedia = file
                                            } else if let image = content.image {
                                                galleryMedia = image
                                            }
                                        }
                                    }
                                }
                                
                                if let galleryMedia = galleryMedia {
                                    if let file = galleryMedia as? TelegramMediaFile, file.isMusic || file.isVoice {
                                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                                            let player = ManagedAudioPlaylistPlayer(audioSessionManager: (strongSelf.account.applicationContext as! TelegramApplicationContext).mediaManager.audioSession, overlayMediaManager: (strongSelf.account.applicationContext as! TelegramApplicationContext).mediaManager.overlayMediaManager, mediaManager: (strongSelf.account.applicationContext as! TelegramApplicationContext).mediaManager, account: strongSelf.account, postbox: strongSelf.account.postbox, playlist: peerMessageHistoryAudioPlaylist(account: strongSelf.account, messageId: id))
                                            applicationContext.mediaManager.setPlaylistPlayer(player)
                                            player.control(.navigation(.next))
                                        }
                                    }
                                }
                            }
                            }, openSecretMessagePreview: { _ in }, closeSecretMessagePreview: { }, openPeer: { _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _ in }, navigateToMessage: { _ in }, clickThroughMessage: { }, toggleMessageSelection: { _ in }, sendMessage: { _ in }, sendSticker: { _ in }, sendGif: { _ in }, requestMessageActionCallback: { _ in }, openUrl: { _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _ in  }, openHashtag: { _ in }, updateInputState: { _ in }, openMessageShareMenu: { _ in
                        }, presentController: { _ in }, callPeer: { _ in }, longTap: { _ in }, openCheckoutOrReceipt: { _ in }, automaticMediaDownloadSettings: .none)
                        
                        let listNode = ChatHistoryListNode(account: account, peerId: updatedPlaylistPeerId, tagMask: .music, messageId: nil, controllerInteraction: controllerInteraction, mode: .list)
                        listNode.preloadPages = true
                        self.listNode = listNode
                        self.contentNode.addSubnode(listNode)
                        
                        if let previousMaximizedHeight = self.previousMaximizedHeight {
                            self.updateLayout(size: self.bounds.size, maximizedHeight: previousMaximizedHeight, transition: .immediate)
                        }
                    }
                } else {
                    let previousPlaylistMessageId = (oldValue?.state.item?.id as? PeerMessageHistoryAudioPlaylistItemId)?.id
                    let updatedPlaylistMessageId = (self.stateAndStatus?.state.item?.id as? PeerMessageHistoryAudioPlaylistItemId)?.id
                    if let updatedPlaylistMessageId = updatedPlaylistMessageId, previousPlaylistMessageId != updatedPlaylistMessageId {
                        if let listNode = self.listNode {
                            var foundItemNode: ListMessageFileItemNode?
                            listNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ListMessageFileItemNode, let message = itemNode.message, message.id == updatedPlaylistMessageId {
                                    foundItemNode = itemNode
                                }
                            }
                            if let foundItemNode = foundItemNode {
                                listNode.ensureItemNodeVisible(foundItemNode)
                            } else if let message = listNode.messageInCurrentHistoryView(updatedPlaylistMessageId) {
                                listNode.scrollToMessage(from: MessageIndex(message), to: MessageIndex(message))
                            }
                        }
                    }
                }
            }
        }
    }
    
    init(account: Account) {
        self.account = account
        
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.theme = presentationData.theme
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        self.topSeparatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        self.bottomSeparatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
        
        self.panelNode = HighlightTrackingButtonNode()
        self.panelNode.backgroundColor = self.theme.rootController.navigationBar.backgroundColor
        
        self.panelHandleNode = ASImageNode()
        self.panelHandleNode.displaysAsynchronously = false
        self.panelHandleNode.displayWithoutProcessing = true
        self.panelHandleNode.image = PresentationResourcesRootController.navigationPlayerHandleIcon(self.theme)
        
        self.contentNode = ASDisplayNode()
        self.contentNode.backgroundColor = self.theme.chatList.backgroundColor
        self.contentNode.clipsToBounds = true
        
        super.init()
        
        self.addSubnode(self.contentNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.panelNode)
        self.panelNode.addSubnode(self.panelHandleNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.panelNode.addTarget(self, action: #selector(self.panelPressed), forControlEvents: .touchUpInside)
        self.panelNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    //strongSelf.panelNode.layer.removeAnimation(forKey: "opacity")
                    //strongSelf.panelNode.alpha = 0.55
                } else {
                    //strongSelf.panelNode.alpha = 0.35
                    //strongSelf.panelNode.layer.animateAlpha(from: 0.55, to: 0.35, duration: 0.2)
                }
            }
        }
    }
    
    func updateLayout(size: CGSize, maximizedHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.previousMaximizedHeight = maximizedHeight
        
        let separatorAlpha: CGFloat = size.height.isLessThanOrEqualTo(MediaNavigationAccessoryItemListNode.minimizedPanelHeight) ? 0.0 : 1.0
        transition.updateAlpha(node: self.separatorNode, alpha: separatorAlpha)
        transition.updateAlpha(node: self.panelHandleNode, alpha: min(1.0, max(0.0, size.height / MediaNavigationAccessoryItemListNode.minimizedPanelHeight)))
        
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.panelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - MediaNavigationAccessoryItemListNode.minimizedPanelHeight), size: CGSize(width: size.width, height: MediaNavigationAccessoryItemListNode.minimizedPanelHeight)))
        transition.updateFrame(node: self.panelHandleNode, frame: CGRect(origin: CGPoint(x: floor((size.width - 36.0) / 2.0), y: (size.height - 19.0) - (size.height - MediaNavigationAccessoryItemListNode.minimizedPanelHeight)), size: CGSize(width: 36.0, height: 7.0)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - MediaNavigationAccessoryItemListNode.minimizedPanelHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: max(0.0, size.height - MediaNavigationAccessoryItemListNode.minimizedPanelHeight))))
        
        if let listNode = listNode {
            let listNodeSize = CGSize(width: size.width, height: max(10.0, maximizedHeight - MediaNavigationAccessoryItemListNode.minimizedPanelHeight))
            listNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: listNodeSize)
            
            var duration: Double = 0.0
            var curve: UInt = 0
            switch transition {
                case .immediate:
                    break
                case let .animated(animationDuration, animationCurve):
                    duration = animationDuration
                    switch animationCurve {
                        case .easeInOut:
                            break
                        case .spring:
                            curve = 7
                    }
            }
            
            let listViewCurve: ListViewAnimationCurve
            if curve == 7 {
                listViewCurve = .Spring(duration: duration)
            } else {
                listViewCurve = .Default
            }

            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listNodeSize, insets: UIEdgeInsets(top: 0.0, left:
                0.0, bottom: 0.0, right: 0.0), duration: duration, curve: listViewCurve)
            listNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        }
        //transition.updateFrame(node: self.contentNode, frame: ))
    }
    
    @objc func panelPressed() {
        self.collapse?()
    }
}
