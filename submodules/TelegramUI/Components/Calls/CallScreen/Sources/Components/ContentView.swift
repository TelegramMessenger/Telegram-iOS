import Foundation
import UIKit
import Display
import MetalEngine
import ComponentFlow
import SwiftSignalKit

final class ContentView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
        var screenCornerRadius: CGFloat
        var state: PrivateCallScreen.State
        
        init(size: CGSize, insets: UIEdgeInsets, screenCornerRadius: CGFloat, state: PrivateCallScreen.State) {
            self.size = size
            self.insets = insets
            self.screenCornerRadius = screenCornerRadius
            self.state = state
        }
        
        static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs.size != rhs.size {
                return false
            }
            if lhs.insets != rhs.insets {
                return false
            }
            if lhs.screenCornerRadius != rhs.screenCornerRadius {
                return false
            }
            if lhs.state != rhs.state {
                return false
            }
            return true
        }
    }
    
    private let blobLayer: CallBlobsLayer
    private let avatarLayer: AvatarLayer
    private let titleView: TextView
    
    private var statusView: StatusView
    
    private var emojiView: KeyEmojiView?
    
    let blurContentsLayer: SimpleLayer
    
    private var videoContainerView: VideoContainerView?
    
    private var params: Params?
    
    private var activeRemoteVideoSource: VideoSource?
    private var waitingForFirstVideoFrameDisposable: Disposable?
    
    private var processedInitialAudioLevelBump: Bool = false
    private var audioLevelBump: Float = 0.0
    
    private var targetAudioLevel: Float = 0.0
    private var audioLevel: Float = 0.0
    private var audioLevelUpdateSubscription: SharedDisplayLinkDriver.Link?
    
    override init(frame: CGRect) {
        self.blobLayer = CallBlobsLayer()
        self.avatarLayer = AvatarLayer()
        
        self.titleView = TextView()
        self.statusView = StatusView()
        
        self.blurContentsLayer = SimpleLayer()
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.blobLayer)
        self.layer.addSublayer(self.avatarLayer)
        
        self.addSubview(self.titleView)
        
        self.addSubview(self.statusView)
        self.statusView.requestLayout = { [weak self] in
            self?.update(transition: .immediate)
        }
        
        self.audioLevelUpdateSubscription = SharedDisplayLinkDriver.shared.add(needsHighestFramerate: false, { [weak self] in
            guard let self else {
                return
            }
            self.attenuateAudioLevelStep()
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.waitingForFirstVideoFrameDisposable?.dispose()
    }
    
    func addIncomingAudioLevel(value: Float) {
        self.targetAudioLevel = value
    }
    
    private func attenuateAudioLevelStep() {
        self.audioLevel = self.audioLevel * 0.8 + (self.targetAudioLevel + self.audioLevelBump) * 0.2
        if self.audioLevel <= 0.01 {
            self.audioLevel = 0.0
        }
        self.updateAudioLevel()
    }
    
    private func updateAudioLevel() {
        if self.activeRemoteVideoSource == nil {
            let additionalAvatarScale = CGFloat(max(0.0, min(self.audioLevel, 5.0)) * 0.05)
            self.avatarLayer.transform = CATransform3DMakeScale(1.0 + additionalAvatarScale, 1.0 + additionalAvatarScale, 1.0)
            
            if let params = self.params, case .terminated = params.state.lifecycleState {
            } else {
                let blobAmplificationFactor: CGFloat = 2.0
                self.blobLayer.transform = CATransform3DMakeScale(1.0 + additionalAvatarScale * blobAmplificationFactor, 1.0 + additionalAvatarScale * blobAmplificationFactor, 1.0)
            }
        }
    }
    
    func update(
        size: CGSize,
        insets: UIEdgeInsets,
        screenCornerRadius: CGFloat,
        state: PrivateCallScreen.State,
        transition: Transition
    ) {
        let params = Params(size: size, insets: insets, screenCornerRadius: screenCornerRadius, state: state)
        if self.params == params {
            return
        }
        
        if self.params?.state.remoteVideo !== params.state.remoteVideo {
            self.waitingForFirstVideoFrameDisposable?.dispose()
            
            if let remoteVideo = params.state.remoteVideo {
                if remoteVideo.currentOutput != nil {
                    self.activeRemoteVideoSource = remoteVideo
                } else {
                    let firstVideoFrameSignal = Signal<Never, NoError> { subscriber in
                        remoteVideo.updated = { [weak remoteVideo] in
                            guard let remoteVideo else {
                                subscriber.putCompletion()
                                return
                            }
                            if remoteVideo.currentOutput != nil {
                                subscriber.putCompletion()
                            }
                        }
                        
                        return EmptyDisposable
                    }
                    var shouldUpdate = false
                    self.waitingForFirstVideoFrameDisposable = (firstVideoFrameSignal
                    |> timeout(4.0, queue: .mainQueue(), alternate: .complete())
                    |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.activeRemoteVideoSource = remoteVideo
                        if shouldUpdate {
                            self.update(transition: .spring(duration: 0.3))
                        }
                    })
                    shouldUpdate = true
                }
            } else {
                self.activeRemoteVideoSource = nil
            }
        }
        
        self.params = params
        self.updateInternal(params: params, transition: transition)
    }
    
    private func update(transition: Transition) {
        guard let params = self.params else {
            return
        }
        self.updateInternal(params: params, transition: transition)
    }
    
    private func updateInternal(params: Params, transition: Transition) {
        if case let .active(activeState) = params.state.lifecycleState {
            let emojiView: KeyEmojiView
            var emojiTransition = transition
            if let current = self.emojiView {
                emojiView = current
            } else {
                emojiTransition = transition.withAnimation(.none)
                emojiView = KeyEmojiView(emoji: activeState.emojiKey)
                self.emojiView = emojiView
            }
            if emojiView.superview == nil {
                self.addSubview(emojiView)
                if !transition.animation.isImmediate {
                    emojiView.animateIn()
                }
            }
            emojiTransition.setFrame(view: emojiView, frame: CGRect(origin: CGPoint(x: params.size.width - params.insets.right - 12.0 - emojiView.size.width, y: params.insets.top + 27.0), size: emojiView.size))
        } else {
            if let emojiView = self.emojiView {
                self.emojiView = nil
                emojiView.removeFromSuperview()
            }
        }
        
        let collapsedAvatarSize: CGFloat = 136.0
        let blobSize: CGFloat = collapsedAvatarSize + 40.0
        
        let collapsedAvatarFrame = CGRect(origin: CGPoint(x: floor((params.size.width - collapsedAvatarSize) * 0.5), y: 222.0), size: CGSize(width: collapsedAvatarSize, height: collapsedAvatarSize))
        let expandedAvatarFrame = CGRect(origin: CGPoint(), size: params.size)
        let avatarFrame = self.activeRemoteVideoSource != nil ? expandedAvatarFrame : collapsedAvatarFrame
        let avatarCornerRadius = self.activeRemoteVideoSource != nil ? params.screenCornerRadius : collapsedAvatarSize * 0.5
        
        if let activeRemoteVideoSource = self.activeRemoteVideoSource {
            let videoContainerView: VideoContainerView
            if let current = self.videoContainerView {
                videoContainerView = current
            } else {
                videoContainerView = VideoContainerView(frame: CGRect())
                self.videoContainerView = videoContainerView
                self.insertSubview(videoContainerView, belowSubview: self.titleView)
                self.blurContentsLayer.addSublayer(videoContainerView.blurredContainerLayer)
                
                videoContainerView.layer.position = self.avatarLayer.position
                videoContainerView.layer.bounds = self.avatarLayer.bounds
                videoContainerView.alpha = 0.0
                videoContainerView.blurredContainerLayer.position = self.avatarLayer.position
                videoContainerView.blurredContainerLayer.bounds = self.avatarLayer.bounds
                videoContainerView.blurredContainerLayer.opacity = 0.0
                videoContainerView.update(size: self.avatarLayer.bounds.size, cornerRadius: self.avatarLayer.params?.cornerRadius ?? 0.0, isExpanded: false, transition: .immediate)
            }
            
            if videoContainerView.video !== activeRemoteVideoSource {
                videoContainerView.video = activeRemoteVideoSource
            }
            
            transition.setPosition(view: videoContainerView, position: avatarFrame.center)
            transition.setBounds(view: videoContainerView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            transition.setAlpha(view: videoContainerView, alpha: 1.0)
            transition.setPosition(layer: videoContainerView.blurredContainerLayer, position: avatarFrame.center)
            transition.setBounds(layer: videoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            transition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 1.0)
            videoContainerView.update(size: avatarFrame.size, cornerRadius: avatarCornerRadius, isExpanded: self.activeRemoteVideoSource != nil, transition: transition)
        } else {
            if let videoContainerView = self.videoContainerView {
                videoContainerView.update(size: avatarFrame.size, cornerRadius: avatarCornerRadius, isExpanded: self.activeRemoteVideoSource != nil, transition: transition)
                transition.setPosition(layer: videoContainerView.blurredContainerLayer, position: avatarFrame.center)
                transition.setBounds(layer: videoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                transition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 0.0)
                transition.setPosition(view: videoContainerView, position: avatarFrame.center)
                transition.setBounds(view: videoContainerView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                if videoContainerView.alpha != 0.0 {
                    transition.setAlpha(view: videoContainerView, alpha: 0.0, completion: { [weak self, weak videoContainerView] completed in
                        guard let self, let videoContainerView, completed else {
                            return
                        }
                        videoContainerView.removeFromSuperview()
                        videoContainerView.blurredContainerLayer.removeFromSuperlayer()
                        if self.videoContainerView === videoContainerView {
                            self.videoContainerView = nil
                        }
                    })
                }
            }
        }
        
        if self.avatarLayer.image !== params.state.avatarImage {
            self.avatarLayer.image = params.state.avatarImage
        }
        transition.setPosition(layer: self.avatarLayer, position: avatarFrame.center)
        transition.setBounds(layer: self.avatarLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
        self.avatarLayer.update(size: collapsedAvatarFrame.size, isExpanded: self.activeRemoteVideoSource != nil, cornerRadius: avatarCornerRadius, transition: transition)
        
        let blobFrame = CGRect(origin: CGPoint(x: floor(avatarFrame.midX - blobSize * 0.5), y: floor(avatarFrame.midY - blobSize * 0.5)), size: CGSize(width: blobSize, height: blobSize))
        transition.setPosition(layer: self.blobLayer, position: CGPoint(x: blobFrame.midX, y: blobFrame.midY))
        transition.setBounds(layer: self.blobLayer, bounds: CGRect(origin: CGPoint(), size: blobFrame.size))
        
        let titleString: String
        switch params.state.lifecycleState {
        case .terminated:
            titleString = "Call Ended"
            transition.setScale(layer: self.blobLayer, scale: 0.001)
            transition.setAlpha(layer: self.blobLayer, alpha: 0.0)
        default:
            titleString = params.state.name
        }
        
        let titleSize = self.titleView.update(
            string: titleString,
            fontSize: self.activeRemoteVideoSource == nil ? 28.0 : 17.0,
            fontWeight: self.activeRemoteVideoSource == nil ? 0.0 : 0.25,
            color: .white,
            constrainedWidth: params.size.width - 16.0 * 2.0,
            transition: transition
        )
        let titleFrame = CGRect(
            origin: CGPoint(
                x: (params.size.width - titleSize.width) * 0.5,
                y: self.activeRemoteVideoSource == nil ? collapsedAvatarFrame.maxY + 39.0 : params.insets.top + 17.0
            ),
            size: titleSize
        )
        transition.setFrame(view: self.titleView, frame: titleFrame)
        
        let statusState: StatusView.State
        switch params.state.lifecycleState {
        case .connecting:
            statusState = .waiting(.requesting)
        case .ringing:
            statusState = .waiting(.ringing)
        case .exchangingKeys:
            statusState = .waiting(.generatingKeys)
        case let .active(activeState):
            statusState = .active(StatusView.ActiveState(startTimestamp: activeState.startTime, signalStrength: activeState.signalInfo.quality))
            
            if !self.processedInitialAudioLevelBump {
                self.processedInitialAudioLevelBump = true
                self.audioLevelBump = 2.0
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.audioLevelBump = 0.0
                })
            }
        case let .terminated(terminatedState):
            statusState = .terminated(StatusView.TerminatedState(duration: terminatedState.duration))
        }
        
        if let previousState = self.statusView.state, previousState.key != statusState.key {
            let previousStatusView = self.statusView
            if !transition.animation.isImmediate {
                transition.setPosition(view: previousStatusView, position: CGPoint(x: previousStatusView.center.x, y: previousStatusView.center.y - 5.0))
                transition.setScale(view: previousStatusView, scale: 0.5)
                Transition.easeInOut(duration: 0.1).setAlpha(view: previousStatusView, alpha: 0.0, completion: { [weak previousStatusView] _ in
                    previousStatusView?.removeFromSuperview()
                })
            } else {
                previousStatusView.removeFromSuperview()
            }
                
            self.statusView = StatusView()
            self.insertSubview(self.statusView, aboveSubview: previousStatusView)
            self.statusView.requestLayout = { [weak self] in
                self?.update(transition: .immediate)
            }
        }
        
        let statusSize = self.statusView.update(state: statusState, transition: .immediate)
        let statusFrame = CGRect(
            origin: CGPoint(
                x: (params.size.width - statusSize.width) * 0.5,
                y: titleFrame.maxY + (self.activeRemoteVideoSource != nil ? 0.0 : 4.0)
            ),
            size: statusSize
        )
        if self.statusView.bounds.isEmpty {
            self.statusView.frame = statusFrame
            
            if !transition.animation.isImmediate {
                transition.animatePosition(view: self.statusView, from: CGPoint(x: 0.0, y: 5.0), to: CGPoint(), additive: true)
                transition.animateScale(view: self.statusView, from: 0.5, to: 1.0)
                Transition.easeInOut(duration: 0.15).animateAlpha(view: self.statusView, from: 0.0, to: 1.0)
            }
        } else {
            transition.setFrame(view: self.statusView, frame: statusFrame)
        }
    }
}
