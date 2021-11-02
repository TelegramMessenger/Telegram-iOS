import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import Postbox
import TelegramAudio
import AccountContext
import AVKit

public final class OverlayUniversalVideoNode: OverlayMediaItemNode, AVPictureInPictureSampleBufferPlaybackDelegate {
    public let content: UniversalVideoContent
    private let videoNode: UniversalVideoNode
    private let decoration: OverlayVideoDecoration
    
    private var validLayoutSize: CGSize?
    
    private var shouldBeDismissedDisposable: Disposable?
    
    override public var group: OverlayMediaItemNodeGroup? {
        return OverlayMediaItemNodeGroup(rawValue: 0)
    }
    
    override public var isMinimizeable: Bool {
        return true
    }
    
    public var canAttachContent: Bool = true {
        didSet {
            self.videoNode.canAttachContent = self.canAttachContent
        }
    }
    
    private let defaultExpand: () -> Void
    public var customExpand: (() -> Void)?
    public var customClose: (() -> Void)?
    public var controlsAreShowingUpdated: ((Bool) -> Void)?
    
    public init(postbox: Postbox, audioSession: ManagedAudioSession, manager: UniversalVideoManager, content: UniversalVideoContent, shouldBeDismissed: Signal<Bool, NoError> = .single(false), expand: @escaping () -> Void, close: @escaping () -> Void) {
        self.content = content
        self.defaultExpand = expand
        
        var expandImpl: (() -> Void)?
        var controlsAreShowingUpdatedImpl: ((Bool) -> Void)?
        
        var unminimizeImpl: (() -> Void)?
        var togglePlayPauseImpl: (() -> Void)?
        var closeImpl: (() -> Void)?
        let decoration = OverlayVideoDecoration(contentDimensions: content.dimensions, unminimize: {
            unminimizeImpl?()
        }, togglePlayPause: {
            togglePlayPauseImpl?()
        }, expand: {
            expandImpl?()
        }, close: {
            closeImpl?()
        }, controlsAreShowingUpdated: { value in
            controlsAreShowingUpdatedImpl?(value)
        })
        self.videoNode = UniversalVideoNode(postbox: postbox, audioSession: audioSession, manager: manager, decoration: decoration, content: content, priority: .overlay)
        self.decoration = decoration
        
        super.init()
        
        expandImpl = { [weak self] in
            self?.expand()
        }
        
        unminimizeImpl = { [weak self] in
            self?.unminimize?()
        }
        togglePlayPauseImpl = { [weak self] in
            self?.videoNode.togglePlayPause()
        }
        closeImpl = { [weak self] in
            if let strongSelf = self {
                if let customClose = strongSelf.customClose {
                    customClose()
                    return
                }
                if strongSelf.videoNode.hasAttachedContext {
                    strongSelf.videoNode.continuePlayingWithoutSound()
                }
                strongSelf.layer.animateScale(from: 1.0, to: 0.1, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    self?.dismiss()
                    close()
                })
                strongSelf.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            }
        }
        
        controlsAreShowingUpdatedImpl = { [weak self] value in
            self?.controlsAreShowingUpdated?(value)
        }

        self.clipsToBounds = true
        self.cornerRadius = 4.0
        
        self.addSubnode(self.videoNode)
        self.videoNode.ownsContentNodeUpdated = { [weak self] value in
            if let strongSelf = self {
                let previous = strongSelf.hasAttachedContext
                strongSelf.hasAttachedContext = value
                strongSelf.hasAttachedContextUpdated?(value)
                
                if previous != value {
                    if !value {
                        strongSelf.dismiss()
                        closeImpl?()
                    }
                }
            }
        }
        
        self.videoNode.canAttachContent = true
        
        self.shouldBeDismissedDisposable = (shouldBeDismissed
        |> filter { $0 }
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss()
            closeImpl?()
        })
    }
    
    override public func didLoad() {
        super.didLoad()
    }
    
    override public func layout() {
        self.updateLayout(self.bounds.size)
    }
    
    override public func preferredSizeForOverlayDisplay(boundingSize: CGSize) -> CGSize {
        return self.content.dimensions.aspectFitted(CGSize(width: 300.0, height: 300.0))
    }
    
    override public func updateLayout(_ size: CGSize) {
        if size != self.validLayoutSize {
            self.updateLayoutImpl(size, transition: .immediate)
        }
    }
    
    public func updateLayout(_ size: CGSize, transition: ContainedViewLayoutTransition) {
        if size != self.validLayoutSize {
            self.updateLayoutImpl(size, transition: transition)
        }
    }
    
    private func updateLayoutImpl(_ size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        transition.updateFrame(node: self.videoNode, frame: CGRect(origin: CGPoint(), size: size))
        self.videoNode.updateLayout(size: size, transition: transition)
    }
    
    override public func updateMinimizedEdge(_ edge: OverlayMediaItemMinimizationEdge?, adjusting: Bool) {
        self.decoration.updateMinimizedEdge(edge, adjusting: adjusting)
    }
    
    public func updateRoundCorners(_ value: Bool, transition: ContainedViewLayoutTransition) {
        transition.updateCornerRadius(node: self, cornerRadius: value ? 4.0 : 0.0)
    }
    
    public func showControls() {
        self.decoration.showControls()
    }
    
    public func expand() {
        if let customExpand = self.customExpand {
            customExpand()
        } else {
            self.defaultExpand()
        }
    }
    
    public func controlPlay() {
        self.videoNode.play()
    }

    @available(iOSApplicationExtension 15.0, iOS 15.0, *)
    override public func makeNativeContentSource() -> AVPictureInPictureController.ContentSource? {
        guard let videoLayer = self.videoNode.getVideoLayer() else {
            return nil
        }
        return AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: videoLayer, playbackDelegate: self)
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        self.controlPlay()
    }

    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(30.0)), duration: CMTime(seconds: 10.0, preferredTimescale: CMTimeScale(30.0)))
    }

    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }
}
