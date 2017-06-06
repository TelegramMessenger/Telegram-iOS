import Foundation
import Display
import TelegramCore
import SwiftSignalKit

public class TelegramController: ViewController {
    private let account: Account
    
    private var mediaStatusDisposable: Disposable?
    
    private var playlistStateAndStatus: AudioPlaylistStateAndStatus?
    private var mediaAccessoryPanel: MediaNavigationAccessoryPanel?
    
    override public var navigationHeight: CGFloat {
        var height = super.navigationHeight
        if let _ = self.mediaAccessoryPanel {
            height += 36.0
        }
        return height
    }
    
    init(account: Account) {
        self.account = account
        
        super.init(navigationBarTheme: NavigationBarTheme(rootControllerTheme: (account.telegramApplicationContext.currentPresentationData.with { $0 }).theme))
        
        if let applicationContext = account.applicationContext as? TelegramApplicationContext {
            self.mediaStatusDisposable = (applicationContext.mediaManager.playlistPlayerStateAndStatus
                |> deliverOnMainQueue).start(next: { [weak self] playlistStateAndStatus in
                    if let strongSelf = self {
                        if strongSelf.playlistStateAndStatus != playlistStateAndStatus {
                            strongSelf.playlistStateAndStatus = playlistStateAndStatus
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
        
        if let playlistStateAndStatus = self.playlistStateAndStatus {
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: super.navigationHeight), size: CGSize(width: layout.size.width, height: max(0.0, layout.size.height - super.navigationHeight - layout.insets(options: [.input]).bottom)))
            if let mediaAccessoryPanel = self.mediaAccessoryPanel {
                transition.updateFrame(node: mediaAccessoryPanel, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, transition: transition)
                mediaAccessoryPanel.containerNode.headerNode.stateAndStatus = playlistStateAndStatus
                mediaAccessoryPanel.containerNode.itemListNode.stateAndStatus = playlistStateAndStatus
            } else {
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(account: self.account)
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self {
                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                            applicationContext.mediaManager.setPlaylistPlayer(nil)
                        }
                    }
                }
                mediaAccessoryPanel.togglePlayPause = { [weak self] in
                    if let strongSelf = self {
                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                            applicationContext.mediaManager.playlistPlayerControl(.playback(.togglePlayPause))
                        }
                    }
                }
                mediaAccessoryPanel.previous = { [weak self] in
                    if let strongSelf = self {
                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                            applicationContext.mediaManager.playlistPlayerControl(.navigation(.previous))
                        }
                    }
                }
                mediaAccessoryPanel.next = { [weak self] in
                    if let strongSelf = self {
                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                            applicationContext.mediaManager.playlistPlayerControl(.navigation(.next))
                        }
                    }
                }
                mediaAccessoryPanel.seek = { [weak self] timestamp in
                    if let strongSelf = self {
                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                            applicationContext.mediaManager.playlistPlayerControl(.playback(.seek(timestamp)))
                        }
                    }
                }
                mediaAccessoryPanel.frame = panelFrame
                if let navigationBar = self.navigationBar {
                    self.displayNode.insertSubnode(mediaAccessoryPanel, belowSubnode: navigationBar)
                } else {
                    self.displayNode.addSubnode(mediaAccessoryPanel)
                }
                self.mediaAccessoryPanel = mediaAccessoryPanel
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, transition: .immediate)
                mediaAccessoryPanel.containerNode.headerNode.stateAndStatus = playlistStateAndStatus
                mediaAccessoryPanel.containerNode.itemListNode.stateAndStatus = playlistStateAndStatus
                mediaAccessoryPanel.animateIn(transition: transition)
            }
        } else if let mediaAccessoryPanel = self.mediaAccessoryPanel {
            self.mediaAccessoryPanel = nil
            mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak mediaAccessoryPanel] in
                mediaAccessoryPanel?.removeFromSupernode()
            })
        }
    }
}
