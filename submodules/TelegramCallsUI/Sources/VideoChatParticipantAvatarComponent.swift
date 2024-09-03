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
        let additionalAvatarScale = CGFloat(max(0.0, min(self.presentationAudioLevel * 18.0, 5.0)) * 0.05)
        let blobAmplificationFactor: CGFloat = 2.0
        let blobScale = 1.0 + additionalAvatarScale * blobAmplificationFactor
        self.blobsLayer.transform = CATransform3DMakeScale(blobScale, blobScale, 1.0)
        
        self.scaleUpdated?(blobScale)
    }
    
    public func startAnimating() {
        guard !self.isAnimating else { return }
        self.isAnimating = true
        
        self.updateBlobsState()
        
        self.displayLinkAnimator?.isPaused = false
    }
    
    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }
    
    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        self.isAnimating = false
        
        self.updateBlobsState()
        
        self.displayLinkAnimator?.isPaused = true
    }
    
    private func updateBlobsState() {
        /*if self.isAnimating {
            if self.mediumBlob.frame.size != .zero {
                self.mediumBlob.startAnimating()
                self.bigBlob.startAnimating()
            }
        } else {
            self.mediumBlob.stopAnimating()
            self.bigBlob.stopAnimating()
        }*/
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        //self.mediumBlob.frame = bounds
        //self.bigBlob.frame = bounds
        
        let blobsFrame = bounds.insetBy(dx: floor(bounds.width * 0.12), dy: floor(bounds.height * 0.12))
        self.blobsLayer.position = blobsFrame.center
        self.blobsLayer.bounds = CGRect(origin: CGPoint(), size: blobsFrame.size)
        
        self.updateBlobsState()
    }
}

final class VideoChatParticipantAvatarComponent: Component {
    let call: PresentationGroupCall
    let peer: EnginePeer
    let isSpeaking: Bool
    let theme: PresentationTheme

    init(
        call: PresentationGroupCall,
        peer: EnginePeer,
        isSpeaking: Bool,
        theme: PresentationTheme
    ) {
        self.call = call
        self.peer = peer
        self.isSpeaking = isSpeaking
        self.theme = theme
    }

    static func ==(lhs: VideoChatParticipantAvatarComponent, rhs: VideoChatParticipantAvatarComponent) -> Bool {
        if lhs.call !== rhs.call {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.isSpeaking != rhs.isSpeaking {
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
        
        func update(component: VideoChatParticipantAvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            
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
            if case let .channel(channel) = component.peer, channel.flags.contains(.isForum) {
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
            
            if component.peer.smallProfileImage != nil {
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
            
            transition.setFrame(view: avatarNode.view, frame: CGRect(origin: CGPoint(), size: avatarSize))
            avatarNode.updateSize(size: avatarSize)
            
            if self.audioLevelDisposable == nil {
                let peerId = component.peer.id
                struct Level {
                    var value: Float
                    var isSpeaking: Bool
                }
                self.audioLevelDisposable = (component.call.audioLevels
                |> map { levels -> Level? in
                    for level in levels {
                        if level.0 == peerId {
                            return Level(value: level.2, isSpeaking: level.3)
                        }
                    }
                    return nil
                }
                |> distinctUntilChanged(isEqual: { lhs, rhs in
                    if (lhs == nil) != (rhs == nil) {
                        return false
                    }
                    if lhs != nil {
                        return true
                    } else {
                        return false
                    }
                })
                |> deliverOnMainQueue).startStrict(next: { [weak self] level in
                    guard let self, let component = self.component, let avatarNode = self.avatarNode else {
                        return
                    }
                    if let level {
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
                            blobView.frame = avatarNode.frame
                            self.insertSubview(blobView, belowSubview: avatarNode.view)
                            
                            blobView.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                            
                            ComponentTransition.immediate.setTintColor(layer: blobView.blobsLayer, color: component.isSpeaking ? UIColor(rgb: 0x33C758) : component.theme.list.itemAccentColor)
                        }
                        
                        blobView.updateLevel(CGFloat(level.value), immediately: false)
                        
                        if let noAudioTimer = self.noAudioTimer {
                            self.noAudioTimer = nil
                            noAudioTimer.invalidate()
                        }
                    } else {
                        if self.noAudioTimer == nil {
                            self.noAudioTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false, block: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.noAudioTimer?.invalidate()
                                self.noAudioTimer = nil
                                
                                if let blobView = self.blobView {
                                    self.blobView = nil
                                    blobView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak blobView] _ in
                                        blobView?.removeFromSuperview()
                                    })
                                    blobView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.3, removeOnCompletion: false)
                                }
                            })
                        }
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
