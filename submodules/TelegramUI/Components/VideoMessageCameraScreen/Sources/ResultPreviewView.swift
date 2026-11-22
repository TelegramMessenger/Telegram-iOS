import Foundation
import UIKit
import AVFoundation

final class ResultPreviewView: UIView {
    let composition: AVComposition
    
    let player: AVPlayer
    let playerLayer: AVPlayerLayer
    
    var didPlayToEndTimeObserver: NSObjectProtocol?
    
    var trimRange: Range<Double>? {
        didSet {
            if let trimRange = self.trimRange {
                self.player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: trimRange.upperBound, preferredTimescale: CMTimeScale(1000))
            } else {
                self.player.currentItem?.forwardPlaybackEndTime = .invalid
            }
        }
    }
    
    var onLoop: () -> Void = {}
    var isMuted = true {
        didSet {
            self.player.isMuted = self.isMuted
        }
    }
    
    init(composition: AVComposition) {
        self.composition = composition
        
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: composition))
        self.player.isMuted = true
        
        self.playerLayer = AVPlayerLayer(player: self.player)
        
        super.init(frame: .zero)
        
        self.layer.addSublayer(self.playerLayer)
        
        self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: nil, using: { [weak self] notification in
            guard let self else {
                return
            }
            var start: Double = 0.0
            if let trimRange = self.trimRange {
                start = trimRange.lowerBound
            }
            self.player.pause()
            self.seek(to: start, andPlay: true)
            
            self.onLoop()
        })
        
        self.player.play()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
    }
    
    func updateTrimRange(start: Double, end: Double, updatedEnd: Bool, apply: Bool) {
        if !apply {
            self.player.pause()
        } else {
            self.trimRange = start..<end
        }
        let seekTo: Double
        if updatedEnd && !apply {
            seekTo = end
        } else {
            seekTo = start
        }
        self.seek(to: seekTo, andPlay: apply)
    }
    
    func play() {
        self.player.play()
    }
    
    func pause() {
        self.player.pause()
    }
    
    private var targetTimePosition: (CMTime, Bool)?
    private var updatingTimePosition = false
    func seek(to seconds: Double, andPlay play: Bool) {
        let position = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(1000.0))
        self.targetTimePosition = (position, play)
        
        if !self.updatingTimePosition {
            self.updateVideoTimePosition()
        }
    }
    
    private func updateVideoTimePosition() {
        guard let (targetPosition, _) = self.targetTimePosition else {
            return
        }
        self.updatingTimePosition = true
        
        self.player.seek(to: targetPosition, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self] _ in
            if let self {
                if let (currentTargetPosition, play) = self.targetTimePosition, currentTargetPosition == targetPosition {
                    self.updatingTimePosition = false
                    self.targetTimePosition = nil
                    
                    if play {
                        self.player.play()
                    }
                } else {
                    self.updateVideoTimePosition()
                }
            }
        })
    }
    
    override func layoutSubviews() {
        self.playerLayer.frame = self.bounds
    }
}
