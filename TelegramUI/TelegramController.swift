import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

public class TelegramController: ViewController {
    private let account: Account
    
    let enableMediaAccessoryPanel: Bool
    
    private var mediaStatusDisposable: Disposable?
    
    private(set) var playlistStateAndType: (SharedMediaPlaylistItem, MusicPlaybackSettingsOrder, MediaManagerPlayerType)?
    private var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    
    private var dismissingPanel: ASDisplayNode?
    
    override public var navigationHeight: CGFloat {
        var height = super.navigationHeight
        if let _ = self.mediaAccessoryPanel {
            height += 36.0
        }
        return height
    }
    
    init(account: Account, navigationBarTheme: NavigationBarTheme?, enableMediaAccessoryPanel: Bool) {
        self.account = account
        self.enableMediaAccessoryPanel = enableMediaAccessoryPanel
        
        super.init(navigationBarTheme: navigationBarTheme)
        
        if let applicationContext = account.applicationContext as? TelegramApplicationContext {
            self.mediaStatusDisposable = (applicationContext.mediaManager.globalMediaPlayerState
                |> deliverOnMainQueue).start(next: { [weak self] playlistStateAndType in
                    if let strongSelf = self, strongSelf.enableMediaAccessoryPanel {
                        if !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.0, playlistStateAndType?.0.item) ||
                            strongSelf.playlistStateAndType?.1 != playlistStateAndType?.0.order || strongSelf.playlistStateAndType?.2 != playlistStateAndType?.1 {
                            if let playlistStateAndType = playlistStateAndType {
                                strongSelf.playlistStateAndType = (playlistStateAndType.0.item, playlistStateAndType.0.order, playlistStateAndType.1)
                            } else {
                                strongSelf.playlistStateAndType = nil
                            }
                            strongSelf.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                        }
                    }
                })
        }
    }
    
    deinit {
        self.mediaStatusDisposable?.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let (item, _, type) = self.playlistStateAndType {
            let navigationHeight = super.navigationHeight
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight.isZero ? -panelHeight : (navigationHeight + UIScreenPixel)), size: CGSize(width: layout.size.width, height: panelHeight))
            if let (mediaAccessoryPanel, mediaType) = self.mediaAccessoryPanel, mediaType == type {
                transition.updateFrame(layer: mediaAccessoryPanel.layer, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, transition: transition)
                mediaAccessoryPanel.containerNode.headerNode.playbackItem = item
                mediaAccessoryPanel.containerNode.headerNode.playbackStatus = self.account.telegramApplicationContext.mediaManager.globalMediaPlayerState |> map { state in
                    return state?.0.status ?? MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, timestamp: 0.0, seekId: 0, status: .paused)
                }
            } else {
                if let (mediaAccessoryPanel, _) = self.mediaAccessoryPanel {
                    self.mediaAccessoryPanel = nil
                    self.dismissingPanel = mediaAccessoryPanel
                    mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak self, weak mediaAccessoryPanel] in
                        mediaAccessoryPanel?.removeFromSupernode()
                        if let strongSelf = self, strongSelf.dismissingPanel === mediaAccessoryPanel {
                            strongSelf.dismissingPanel = nil
                        }
                    })
                }
                
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(account: self.account)
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = type != .voice
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self, let (_, _, type) = strongSelf.playlistStateAndType {
                        strongSelf.account.telegramApplicationContext.mediaManager.setPlaylist(nil, type: type)
                    }
                }
                mediaAccessoryPanel.togglePlayPause = { [weak self] in
                    if let strongSelf = self, let (_, _, type) = strongSelf.playlistStateAndType {
                        strongSelf.account.telegramApplicationContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: type)
                    }
                }
                mediaAccessoryPanel.tapAction = { [weak self] in
                    if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController, let (state, order, type) = strongSelf.playlistStateAndType {
                        if let id = state.id as? PeerMessagesMediaPlaylistItemId {
                            if type == .music {
                                let controller = OverlayPlayerController(account: strongSelf.account, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, parentNavigationController: strongSelf.navigationController as? NavigationController) 
                                strongSelf.displayNode.view.window?.endEditing(true)
                                strongSelf.present(controller, in: .window(.root))
                            } else {
                                navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(id.messageId.peerId), messageId: id.messageId)
                            }
                        }
                    }
                }
                mediaAccessoryPanel.frame = panelFrame
                if let dismissingPanel = self.dismissingPanel {
                    self.displayNode.insertSubnode(mediaAccessoryPanel, aboveSubnode: dismissingPanel)
                } else if let navigationBar = self.navigationBar {
                    self.displayNode.insertSubnode(mediaAccessoryPanel, aboveSubnode: navigationBar)
                } else {
                    self.displayNode.addSubnode(mediaAccessoryPanel)
                }
                self.mediaAccessoryPanel = (mediaAccessoryPanel, type)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, transition: .immediate)
                mediaAccessoryPanel.containerNode.headerNode.playbackItem = item
                mediaAccessoryPanel.containerNode.headerNode.playbackStatus = self.account.telegramApplicationContext.mediaManager.globalMediaPlayerState |> map { state in
                    return state?.0.status ?? MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, timestamp: 0.0, seekId: 0, status: .paused)
                }
                mediaAccessoryPanel.animateIn(transition: transition)
            }
        } else if let (mediaAccessoryPanel, _) = self.mediaAccessoryPanel {
            self.mediaAccessoryPanel = nil
            self.dismissingPanel = mediaAccessoryPanel
            mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak self, weak mediaAccessoryPanel] in
                mediaAccessoryPanel?.removeFromSupernode()
                if let strongSelf = self, strongSelf.dismissingPanel === mediaAccessoryPanel {
                    strongSelf.dismissingPanel = nil
                }
            })
        }
    }
}
