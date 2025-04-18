import Foundation
import AVFoundation
import SwiftSignalKit
import UniversalMediaPlayer
import AccountContext
import AVKit

public class ExternalVideoPlayer: NSObject, AVRoutePickerViewDelegate {
    private let context: AccountContext
    let content: NativeVideoContent
    
    let player: AVPlayer?
    private var didPlayToEndTimeObserver: NSObjectProtocol?
    private var timeObserver: Any?
    
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .buffering(initial: true, whilePlaying: false, progress: 0.0, display: true), soundEnabled: true)
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    private var seekId: Int = 0
    
    private weak var routePickerView: UIView?
    
    public var isActiveUpdated: (Bool) -> Void = { _ in }
 
    public init(context: AccountContext, content: NativeVideoContent) {
        self.context = context
        self.content = content
        
        if let path = context.account.postbox.mediaBox.completedResourcePath(content.fileReference.media.resource, pathExtension: "mp4") {
            let player = AVPlayer(url: URL(fileURLWithPath: path))
            self.player = player
        } else {
            self.player = nil
        }
        
        super.init()
        
        self.startObservingForAirPlayStatusChanges()
        self.isActiveUpdated(self.player?.isExternalPlaybackActive ?? false)
        
        if let player = self.player {
            self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil, using: { [weak self] notification in
                if let strongSelf = self {
                    strongSelf.player?.seek(to: CMTime(seconds: 0.0, preferredTimescale: 30))
                    strongSelf.play()
                }
            })
            
            self.timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 10), queue: DispatchQueue.main) { [weak self] time in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: strongSelf.statusValue.duration, dimensions: CGSize(), timestamp: CMTimeGetSeconds(time), baseRate: 1.0, seekId: strongSelf.seekId, status: strongSelf.statusValue.status, soundEnabled: true)
                strongSelf._status.set(strongSelf.statusValue)
            }
        }
        
        self._status.set(self.statusValue)
    }
    
    deinit {
        if let timeObserver = self.timeObserver {
            self.player?.removeTimeObserver(timeObserver)
        }
        
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
        
        self.stopObservingForAirPlayStatusChanges()
    }
    
    public func play() {
        self.player?.play()
    }

    public func openRouteSelection() {
        if #available(iOS 11.0, *) {
            let routePickerView = AVRoutePickerView()
            routePickerView.delegate = self
            if #available(iOS 13.0, *) {
                routePickerView.prioritizesVideoDevices = true
            }
            self.context.sharedContext.mainWindow?.viewController?.view.addSubview(routePickerView)
            
            if let routePickerButton = routePickerView.subviews.first(where: { $0 is UIButton }) as? UIButton {
                routePickerButton.sendActions(for: .touchUpInside)
            }
        }
    }
    
    @available(iOS 11.0, *)
    public func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        routePickerView.removeFromSuperview()
        
        self.play()
    }
    
    private var observerContextAirplay = 1
    
    func startObservingForAirPlayStatusChanges()
    {
        self.player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.isExternalPlaybackActive), options: .new, context: &observerContextAirplay)
    }

    func stopObservingForAirPlayStatusChanges()
    {
        self.player?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.isExternalPlaybackActive))
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &observerContextAirplay {
            self.isActiveUpdated(self.player?.isExternalPlaybackActive ?? false)
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
