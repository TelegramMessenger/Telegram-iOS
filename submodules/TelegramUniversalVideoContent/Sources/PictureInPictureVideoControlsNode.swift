import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import UniversalMediaPlayer
import LegacyComponents
import AppBundle

private let leaveImage = UIImage(bundleImageName: "Media Gallery/PictureInPictureLeave")?.precomposed()
private let pauseImage = UIImage(bundleImageName: "Media Gallery/PictureInPicturePause")?.precomposed()
private let playImage = UIImage(bundleImageName: "Media Gallery/PictureInPicturePlay")?.precomposed()
private let closeImage = UIImage(bundleImageName: "Media Gallery/PictureInPictureClose")?.precomposed()

final class PictureInPictureVideoControlsNode: ASDisplayNode {
    private let leave: () -> Void
    private let playPause: () -> Void
    private let close: () -> Void
    
    private let leaveButton: TGEmbedPIPButton
    private let pauseButton: TGEmbedPIPButton
    private let playButton: TGEmbedPIPButton
    private let closeButton: TGEmbedPIPButton
    
    private var playbackStatusValue: MediaPlayerPlaybackStatus?
    private var statusValue: MediaPlayerStatus? {
        didSet {
            if self.statusValue != oldValue {
                let playbackStatus = self.statusValue?.status
                if self.playbackStatusValue != playbackStatus {
                    self.playbackStatusValue = playbackStatus
                    if let playbackStatus = playbackStatus {
                        switch playbackStatus {
                            case .paused:
                                self.playButton.isHidden = false
                                self.pauseButton.isHidden = true
                            case .playing:
                                self.playButton.isHidden = true
                                self.pauseButton.isHidden = false
                            case let .buffering(_, whilePlaying, _, _):
                                if whilePlaying {
                                    self.playButton.isHidden = true
                                    self.pauseButton.isHidden = false
                                } else {
                                    self.playButton.isHidden = false
                                    self.pauseButton.isHidden = true
                                }
                        }
                    }
                }
            }
        }
    }
    
    private var statusDisposable: Disposable?
    private var statusValuePromise = Promise<MediaPlayerStatus>()
    
    var status: Signal<MediaPlayerStatus, NoError>? {
        didSet {
            if let status = self.status {
                self.statusValuePromise.set(status)
            } else {
                self.statusValuePromise.set(.never())
            }
        }
    }
    
    init(leave: @escaping () -> Void, playPause: @escaping () -> Void, close: @escaping () -> Void) {
        self.leave = leave
        self.playPause = playPause
        self.close = close
        
        self.leaveButton = TGEmbedPIPButton(frame: CGRect(origin: CGPoint(), size: TGEmbedPIPButtonSize))
        self.pauseButton = TGEmbedPIPButton(frame: CGRect(origin: CGPoint(), size: TGEmbedPIPButtonSize))
        self.playButton = TGEmbedPIPButton(frame: CGRect(origin: CGPoint(), size: TGEmbedPIPButtonSize))
        self.closeButton = TGEmbedPIPButton(frame: CGRect(origin: CGPoint(), size: TGEmbedPIPButtonSize))
        
        super.init()
        
        self.leaveButton.setIconImage(leaveImage)
        self.pauseButton.setIconImage(pauseImage)
        self.playButton.setIconImage(playImage)
        self.closeButton.setIconImage(closeImage)
        
        self.view.addSubview(self.leaveButton)
        self.view.addSubview(self.pauseButton)
        self.view.addSubview(self.playButton)
        self.view.addSubview(self.closeButton)
        
        self.leaveButton.addTarget(self, action: #selector(self.leavePressed), for: .touchUpInside)
        self.playButton.addTarget(self, action: #selector(self.playPausePressed), for: .touchUpInside)
        self.pauseButton.addTarget(self, action: #selector(self.playPausePressed), for: .touchUpInside)
        self.closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
        
        self.statusDisposable = (self.statusValuePromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.statusValue = status
                }
            })
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let forth = floor(size.width / 4.0)
        
        let buttonSize = TGEmbedPIPButtonSize
        
        transition.updateFrame(view: self.leaveButton, frame: CGRect(origin: CGPoint(x: forth - floor(buttonSize.width / 2.0) - 10.0, y: size.height - buttonSize.height - 15.0), size: buttonSize))
        
        transition.updateFrame(view: self.pauseButton, frame: CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: size.height - buttonSize.height - 15.0), size: buttonSize))
        transition.updateFrame(view: self.playButton, frame: CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: size.height - buttonSize.height - 15.0), size: buttonSize))
        
        transition.updateFrame(view: self.closeButton, frame: CGRect(origin: CGPoint(x: self.playButton.frame.origin.x + forth + 10.0, y: size.height - buttonSize.height - 15.0), size: buttonSize))
    }
    
    @objc func leavePressed() {
        self.leave()
    }
    
    @objc func playPausePressed() {
        self.playPause()
    }
    
    @objc func closePressed() {
        self.close()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
}
