import Foundation
import Display
import TelegramCore
import SwiftSignalKit

public class TelegramController: ViewController {
    private let account: Account
    
    private var mediaStatusDisposable: Disposable?
    
    private var playlistState: AudioPlaylistState?
    private var mediaAccessoryPanel: MediaNavigationAccessoryPanel?
    
    override public var navigationHeight: CGFloat {
        var height = super.navigationHeight
        if let mediaAccessoryPanel = self.mediaAccessoryPanel {
            height += 36.0
        }
        return height
    }
    
    init(account: Account) {
        self.account = account
        
        super.init(navigationBar: NavigationBar())
        
        if let applicationContext = account.applicationContext as? TelegramApplicationContext {
            self.mediaStatusDisposable = (applicationContext.mediaManager.playlistPlayerState
                |> deliverOnMainQueue).start(next: { [weak self] playlistState in
                    if let strongSelf = self, strongSelf.playlistState != playlistState {
                        strongSelf.playlistState = playlistState
                        strongSelf.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
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
        
        if let playlistState = playlistState {
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: self.navigationBar.frame.maxY), size: CGSize(width: layout.size.width, height: 36.0))
            if let mediaAccessoryPanel = self.mediaAccessoryPanel {
                transition.updateFrame(node: mediaAccessoryPanel, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, transition: transition)
            } else {
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel()
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self {
                        if let applicationContext = strongSelf.account.applicationContext as? TelegramApplicationContext {
                            applicationContext.mediaManager.setPlaylistPlayer(nil)
                        }
                    }
                }
                mediaAccessoryPanel.frame = panelFrame
                self.displayNode.insertSubnode(mediaAccessoryPanel, belowSubnode: self.navigationBar)
                self.mediaAccessoryPanel = mediaAccessoryPanel
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, transition: .immediate)
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
