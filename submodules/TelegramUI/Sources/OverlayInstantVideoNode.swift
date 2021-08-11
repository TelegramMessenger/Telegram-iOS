import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import UniversalMediaPlayer
import TelegramUIPreferences
import TelegramAudio
import AccountContext

final class OverlayInstantVideoNode: OverlayMediaItemNode {
    private let content: UniversalVideoContent
    private let videoNode: UniversalVideoNode
    private let decoration: OverlayInstantVideoDecoration
    
    private let close: () -> Void
    
    private var validLayoutSize: CGSize?
    
    override var group: OverlayMediaItemNodeGroup? {
        return OverlayMediaItemNodeGroup(rawValue: 1)
    }
    
    override var isMinimizeable: Bool {
        return false
    }
    
    var canAttachContent: Bool = true {
        didSet {
            self.videoNode.canAttachContent = self.canAttachContent
        }
    }
    
    var status: Signal<MediaPlayerStatus?, NoError> {
        return self.videoNode.status
    }
    
    var playbackEnded: (() -> Void)?
    
    init(postbox: Postbox, audioSession: ManagedAudioSession, manager: UniversalVideoManager, content: UniversalVideoContent, close: @escaping () -> Void) {
        self.close = close
        self.content = content
        var togglePlayPauseImpl: (() -> Void)?
        let decoration = OverlayInstantVideoDecoration(tapped: {
            togglePlayPauseImpl?()
        })
        self.videoNode = UniversalVideoNode(postbox: postbox, audioSession: audioSession, manager: manager, decoration: decoration, content: content, priority: .secondaryOverlay, snapshotContentWhenGone: true)
        self.decoration = decoration
        
        super.init()
        
        togglePlayPauseImpl = { [weak self] in
            self?.videoNode.togglePlayPause()
        }
        
        self.addSubnode(self.videoNode)
        self.videoNode.ownsContentNodeUpdated = { [weak self] value in
            if let strongSelf = self {
                let previous = strongSelf.hasAttachedContext
                strongSelf.hasAttachedContext = value
                if previous != value {
                    strongSelf.hasAttachedContextUpdated?(value)
                }
            }
        }
        
        self.videoNode.playbackCompleted = { [weak self] in
            self?.playbackEnded?()
        }
        
        self.videoNode.canAttachContent = true
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    override func layout() {
        self.updateLayout(self.bounds.size)
    }
    
    override func preferredSizeForOverlayDisplay(boundingSize: CGSize) -> CGSize {
        if min(boundingSize.width, boundingSize.height) > 320.0 {
            return CGSize(width: 150.0, height: 150.0)
        } else {
            return CGSize(width: 120.0, height: 120.0)
        }
    }
    
    override func dismiss() {
        self.close()
    }
    
    override func updateLayout(_ size: CGSize) {
        if size != self.validLayoutSize {
            self.updateLayoutImpl(size)
        }
    }
    
    private func updateLayoutImpl(_ size: CGSize) {
        self.validLayoutSize = size
        
        self.videoNode.frame = CGRect(origin: CGPoint(), size: size)
        self.videoNode.updateLayout(size: size, transition: .immediate)
    }
    
    func play() {
        self.videoNode.play()
    }
    
    func playOnceWithSound(playAndRecord: Bool) {
        self.videoNode.playOnceWithSound(playAndRecord: playAndRecord)
    }
    
    func pause() {
        self.videoNode.pause()
    }
    
    func togglePlayPause() {
        self.videoNode.togglePlayPause()
    }
    
    func seek(_ timestamp: Double) {
        self.videoNode.seek(timestamp)
    }
    
    func setSoundEnabled(_ soundEnabled: Bool) {
        if soundEnabled {
            self.videoNode.playOnceWithSound(playAndRecord: true)
        } else {
            self.videoNode.continuePlayingWithoutSound()
            self.videoNode.setBaseRate(1.0)
        }
    }
    
    func setBaseRate(_ baseRate: Double) {
        self.videoNode.setBaseRate(baseRate)
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
        self.videoNode.setForceAudioToSpeaker(forceAudioToSpeaker)
    }
}
