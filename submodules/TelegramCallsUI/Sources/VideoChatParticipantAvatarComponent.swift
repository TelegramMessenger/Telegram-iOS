import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramCore
import AccountContext
import AvatarNode
import VoiceChatActionButton
import CallScreen
import MetalEngine
import SwiftSignalKit

private final class BlobView: UIView {
    let blobsLayer: CallBlobsLayer
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0.0
    var presentationAudioLevel: CGFloat = 0.0
    
    var scaleUpdated: ((CGFloat) -> Void)? {
        didSet {
        }
    }
    
    private(set) var isAnimating = false
    
    public typealias BlobRange = (min: CGFloat, max: CGFloat)

    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true
    
    init(
        frame: CGRect,
        maxLevel: CGFloat,
        mediumBlobRange: BlobRange,
        bigBlobRange: BlobRange
    ) {
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        self.maxLevel = maxLevel
        
        self.blobsLayer = CallBlobsLayer()
        
        super.init(frame: frame)

        self.addSubnode(self.hierarchyTrackingNode)
        
        self.layer.addSublayer(self.blobsLayer)
        
        self.displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let self else {
                return
            }

            if !self.isCurrentlyInHierarchy {
                return
            }
            
            self.presentationAudioLevel = self.presentationAudioLevel * 0.9 + self.audioLevel * 0.1
            self.updateAudioLevel()
        }

        updateInHierarchy = { [weak self] value in
            guard let self else {
                return
            }
            self.isCurrentlyInHierarchy = value
            if value {
                self.startAnimating()
            } else {
                self.stopAnimating()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setColor(_ color: UIColor) {
    }
    
    public func updateLevel(_ level: CGFloat, immediately: Bool) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        self.audioLevel = normalizedLevel
        if immediately {
            self.presentationAudioLevel = normalizedLevel
        }
    }
    
    private func updateAudioLevel() {
        let additionalAvatarScale = CGFloat(max(0.0, min(self.presentationAudioLevel * 0.3, 1.0)) * 1.0)
        let blobScale = 1.28 + additionalAvatarScale
        self.blobsLayer.transform = CATransform3DMakeScale(blobScale, blobScale, 1.0)
        
        self.scaleUpdated?(additionalAvatarScale)
    }
    
    public func startAnimating() {
        guard !self.isAnimating else { return }
        self.isAnimating = true
        
        self.displayLinkAnimator?.isPaused = false
    }
    
    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }
    
    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        self.isAnimating = false
        
        self.displayLinkAnimator?.isPaused = true
    }
    
    func update(size: CGSize) {
        super.layoutSubviews()
        
        let blobsFrame = CGRect(origin: CGPoint(), size: size)
        self.blobsLayer.position = blobsFrame.center
        self.blobsLayer.bounds = CGRect(origin: CGPoint(), size: blobsFrame.size)
    }
}

final class VideoChatParticipantAvatarComponent: Component {
    let call: VideoChatCall
    let peer: EnginePeer?
    let myPeerId: EnginePeer.Id
    let isSpeaking: Bool
    let theme: PresentationTheme

    init(
        call: VideoChatCall,
        peer: EnginePeer?,
        myPeerId: EnginePeer.Id,
        isSpeaking: Bool,
        theme: PresentationTheme
    ) {
        self.call = call
        self.peer = peer
        self.myPeerId = myPeerId
        self.isSpeaking = isSpeaking
        self.theme = theme
    }

    static func ==(lhs: VideoChatParticipantAvatarComponent, rhs: VideoChatParticipantAvatarComponent) -> Bool {
        if lhs.call != rhs.call {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.isSpeaking != rhs.isSpeaking {
            return false
        }
        if lhs.myPeerId != rhs.myPeerId {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: VideoChatParticipantAvatarComponent?
        private var isUpdating: Bool = false
        
        private var avatarNode: AvatarNode?
        private var blobView: BlobView?
        private var audioLevelDisposable: Disposable?
        
        private var wasSpeaking: Bool?
        private var noAudioTimer: Foundation.Timer?
        private var lastAudioLevelTimestamp: Double = 0.0
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.audioLevelDisposable?.dispose()
            self.noAudioTimer?.invalidate()
        }
        
        private func checkNoAudio() {
            let timestamp = CFAbsoluteTimeGetCurrent()
            if self.lastAudioLevelTimestamp + 1.0 < timestamp {
                self.noAudioTimer?.invalidate()
                self.noAudioTimer = nil
                
                if let blobView = self.blobView {
                    let transition: ComponentTransition = .easeInOut(duration: 0.3)
                    transition.setAlpha(view: blobView, alpha: 0.0, completion: { [weak self, weak blobView] completed in
                        guard let self, let blobView, completed else {
                            return
                        }
                        if self.blobView === blobView {
                            self.blobView = nil
                        }
                        blobView.removeFromSuperview()
                    })
                    transition.setScale(layer: blobView.layer, scale: 0.5)
                    if let avatarNode = self.avatarNode {
                        transition.setScale(view: avatarNode.view, scale: 1.0)
                    }
                }
            }
        }
        
        func update(component: VideoChatParticipantAvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            
            if let previousComponent, previousComponent.call != component.call {
                self.audioLevelDisposable?.dispose()
                self.audioLevelDisposable = nil
            }
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 15.0))
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            let avatarSize = availableSize
            
            let clipStyle: AvatarNodeClipStyle
            if case let .channel(channel) = component.peer, channel.isForumOrMonoForum {
                clipStyle = .roundedRect
            } else {
                clipStyle = .round
            }
            
            if let blobView = self.blobView {
                let tintTransition: ComponentTransition
                if let previousComponent, previousComponent.isSpeaking != component.isSpeaking {
                    if component.isSpeaking {
                        tintTransition = .easeInOut(duration: 0.15)
                    } else {
                        tintTransition = .easeInOut(duration: 0.25)
                    }
                } else {
                    tintTransition = .immediate
                }
                tintTransition.setTintColor(layer: blobView.blobsLayer, color: component.isSpeaking ? UIColor(rgb: 0x33C758) : component.theme.list.itemAccentColor)
            }
            
            if component.peer?.smallProfileImage != nil {
                avatarNode.setPeerV2(
                    context: component.call.accountContext,
                    theme: component.theme,
                    peer: component.peer,
                    authorOfMessage: nil,
                    overrideImage: nil,
                    emptyColor: nil,
                    clipStyle: .round,
                    synchronousLoad: false,
                    displayDimensions: avatarSize
                )
            } else {
                avatarNode.setPeer(context: component.call.accountContext, theme: component.theme, peer: component.peer, clipStyle: clipStyle, synchronousLoad: false, displayDimensions: avatarSize)
            }
            
            let avatarFrame = CGRect(origin: CGPoint(), size: avatarSize)
            transition.setPosition(view: avatarNode.view, position: avatarFrame.center)
            transition.setBounds(view: avatarNode.view, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            avatarNode.updateSize(size: avatarSize)
            
            let blobScale: CGFloat = 2.0
            
            if self.audioLevelDisposable == nil {
                struct Level {
                    var value: Float
                    var isSpeaking: Bool
                }
                
                let peerId = component.peer?.id
                let levelSignal: Signal<Level?, NoError>
                if peerId == component.myPeerId {
                    levelSignal = component.call.myAudioLevelAndSpeaking
                    |> map { value, isSpeaking -> Level? in
                        if value == 0.0 {
                            return nil
                        } else {
                            return Level(value: value, isSpeaking: isSpeaking)
                        }
                    }
                } else {
                    levelSignal = component.call.audioLevels
                    |> map { levels -> Level? in
                        for level in levels {
                            if level.0 == peerId {
                                return Level(value: level.2, isSpeaking: level.3)
                            }
                        }
                        return nil
                    }
                }
                
                self.audioLevelDisposable = (levelSignal
                |> distinctUntilChanged(isEqual: { lhs, rhs in
                    if (lhs == nil) != (rhs == nil) {
                        return false
                    }
                    if lhs != nil {
                        return false
                    } else {
                        return true
                    }
                })
                |> deliverOnMainQueue).startStrict(next: { [weak self] level in
                    guard let self, let component = self.component, let avatarNode = self.avatarNode else {
                        return
                    }
                    if let level, level.value >= 0.1 {
                        self.lastAudioLevelTimestamp = CFAbsoluteTimeGetCurrent()
                        
                        let blobView: BlobView
                        if let current = self.blobView {
                            blobView = current
                        } else {
                            self.wasSpeaking = nil
                            
                            blobView = BlobView(
                                frame: avatarNode.frame,
                                maxLevel: 1.5,
                                mediumBlobRange: (0.69, 0.87),
                                bigBlobRange: (0.71, 1.0)
                            )
                            self.blobView = blobView
                            let blobSize = floor(avatarNode.bounds.width * blobScale)
                            blobView.center = avatarNode.frame.center
                            blobView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: blobSize, height: blobSize))
                            blobView.layer.transform = CATransform3DMakeScale(1.0 / blobScale, 1.0 / blobScale, 1.0)
                            
                            blobView.update(size: blobView.bounds.size)
                            self.insertSubview(blobView, belowSubview: avatarNode.view)
                            
                            blobView.layer.animateScale(from: 0.5, to: 1.0 / blobScale, duration: 0.2)
                            
                            blobView.scaleUpdated = { [weak self] additionalScale in
                                guard let self, let avatarNode = self.avatarNode else {
                                    return
                                }
                                avatarNode.layer.transform = CATransform3DMakeScale(1.0 + additionalScale, 1.0 + additionalScale, 1.0)
                            }
                            
                            ComponentTransition.immediate.setTintColor(layer: blobView.blobsLayer, color: component.isSpeaking ? UIColor(rgb: 0x33C758) : component.theme.list.itemAccentColor)
                        }
                        
                        if blobView.alpha == 0.0 {
                            let transition: ComponentTransition = .easeInOut(duration: 0.3)
                            transition.setAlpha(view: blobView, alpha: 1.0)
                            transition.setScale(view: blobView, scale: 1.0 / blobScale)
                        }
                        blobView.updateLevel(CGFloat(level.value), immediately: false)
                        
                        if let noAudioTimer = self.noAudioTimer {
                            self.noAudioTimer = nil
                            noAudioTimer.invalidate()
                        }
                    } else {
                        if let blobView = self.blobView {
                            blobView.updateLevel(0.0, immediately: false)
                        }
                    }
                    
                    if self.noAudioTimer == nil {
                        self.noAudioTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true, block: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.checkNoAudio()
                        })
                    }
                })
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
