import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TelegramVoip
import TelegramAudio
import AccountContext
import Postbox
import TelegramCore
import SyncCore
import AppBundle
import PresentationDataUtils
import AvatarNode
import AudioBlob

private let backArrowImage = NavigationBarTheme.generateBackArrowImage(color: .white)
private let backgroundCornerRadius: CGFloat = 11.0

final class VoiceChatMainStageNode: ASDisplayNode {
    private let context: AccountContext
    private let call: PresentationGroupCall
    private var currentPeer: (PeerId, String?)?
    private var currentPeerEntry: VoiceChatPeerEntry?
    
    private var currentVideoNode: GroupVideoNode?
    private var candidateVideoNode: GroupVideoNode?
        
    private let backgroundNode: ASDisplayNode
    private let topFadeNode: ASImageNode
    private let bottomFadeNode: ASImageNode
    private let headerNode: ASDisplayNode
    private let backButtonNode: HighlightableButtonNode
    private let backButtonArrowNode: ASImageNode
    private let pinButtonNode: HighlightTrackingButtonNode
    private let pinButtonIconNode: ASImageNode
    private let pinButtonTitleNode: ImmediateTextNode
    private var audioLevelView: VoiceBlobView?
    private let audioLevelDisposable = MetaDisposable()
    private let speakingPeerDisposable = MetaDisposable()
    private let speakingAudioLevelDisposable = MetaDisposable()
    private var avatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let microphoneNode: VoiceChatMicrophoneNode
    
    private let speakingContainerNode: ASDisplayNode
    private var speakingEffectView: UIVisualEffectView?
    private let speakingAvatarNode: AvatarNode
    private let speakingTitleNode: ImmediateTextNode
    private var speakingAudioLevelView: VoiceBlobView?
    
    private var validLayout: (CGSize, CGFloat, CGFloat, Bool)?
    
    var tapped: (() -> Void)?
    var back: (() -> Void)?
    var togglePin: (() -> Void)?
    
    var getAudioLevel: ((PeerId) -> Signal<Float, NoError>)?
    private let videoReadyDisposable = MetaDisposable()
    private var silenceTimer: SwiftSignalKit.Timer?
        
    init(context: AccountContext, call: PresentationGroupCall) {
        self.context = context
        self.call = call
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.alpha = 0.0
        self.backgroundNode.backgroundColor = UIColor(rgb: 0x1c1c1e)
        
        self.topFadeNode = ASImageNode()
        self.topFadeNode.alpha = 0.0
        self.topFadeNode.displaysAsynchronously = false
        self.topFadeNode.displayWithoutProcessing = true
        self.topFadeNode.contentMode = .scaleToFill
        self.topFadeNode.image = generateImage(CGSize(width: 1.0, height: 50.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            
            let colorsArray = [UIColor(rgb: 0x000000, alpha: 0.7).cgColor, UIColor(rgb: 0x000000, alpha: 0.0).cgColor] as CFArray
            var locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
        
        self.bottomFadeNode = ASImageNode()
        self.bottomFadeNode.displaysAsynchronously = false
        self.bottomFadeNode.displayWithoutProcessing = true
        self.bottomFadeNode.contentMode = .scaleToFill
        self.bottomFadeNode.image = generateImage(CGSize(width: 1.0, height: 50.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            
            let colorsArray = [UIColor(rgb: 0x000000, alpha: 0.0).cgColor, UIColor(rgb: 0x000000, alpha: 0.7).cgColor] as CFArray
            var locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
        
        self.headerNode = ASDisplayNode()
        self.headerNode.alpha = 0.0
        
        self.backButtonArrowNode = ASImageNode()
        self.backButtonArrowNode.displayWithoutProcessing = true
        self.backButtonArrowNode.displaysAsynchronously = false
        self.backButtonArrowNode.image = NavigationBarTheme.generateBackArrowImage(color: .white)
        self.backButtonNode = HighlightableButtonNode()
        
        self.pinButtonIconNode = ASImageNode()
        self.pinButtonIconNode.displayWithoutProcessing = true
        self.pinButtonIconNode.displaysAsynchronously = false
        self.pinButtonIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/Pin"), color: .white)
        self.pinButtonTitleNode = ImmediateTextNode()
        self.pinButtonTitleNode.isHidden = true
        self.pinButtonTitleNode.attributedText = NSAttributedString(string: "Unpin", font: Font.regular(17.0), textColor: .white)
        self.pinButtonNode = HighlightableButtonNode()
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 42.0))
        self.avatarNode.isHidden = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.alpha = 0.0
        self.titleNode.isUserInteractionEnabled = false
        
        self.microphoneNode = VoiceChatMicrophoneNode()
        self.microphoneNode.alpha = 0.0
        
        self.speakingContainerNode = ASDisplayNode()
        self.speakingContainerNode.cornerRadius = 19.0
        
        self.speakingAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))
        self.speakingTitleNode = ImmediateTextNode()
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = backgroundCornerRadius
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topFadeNode)
        self.addSubnode(self.bottomFadeNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.microphoneNode)
        self.addSubnode(self.headerNode)
        
        self.headerNode.addSubnode(self.backButtonNode)
        self.headerNode.addSubnode(self.backButtonArrowNode)
        self.headerNode.addSubnode(self.pinButtonIconNode)
        self.headerNode.addSubnode(self.pinButtonTitleNode)
        self.headerNode.addSubnode(self.pinButtonNode)

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.backButtonNode.setTitle(presentationData.strings.Common_Back, with: Font.regular(17.0), with: .white, for: [])
        self.backButtonNode.hitTestSlop = UIEdgeInsets(top: -8.0, left: -20.0, bottom: -8.0, right: -8.0)
        self.backButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backButtonNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backButtonArrowNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backButtonNode.alpha = 0.4
                    strongSelf.backButtonArrowNode.alpha = 0.4
                } else {
                    strongSelf.backButtonNode.alpha = 1.0
                    strongSelf.backButtonArrowNode.alpha = 1.0
                    strongSelf.backButtonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.backButtonArrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.backButtonNode.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
       
        self.pinButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.pinButtonTitleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.pinButtonIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.pinButtonTitleNode.alpha = 0.4
                    strongSelf.pinButtonIconNode.alpha = 0.4
                } else {
                    strongSelf.pinButtonTitleNode.alpha = 1.0
                    strongSelf.pinButtonIconNode.alpha = 1.0
                    strongSelf.pinButtonTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.pinButtonIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.pinButtonNode.addTarget(self, action: #selector(self.pinPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.videoReadyDisposable.dispose()
        self.audioLevelDisposable.dispose()
        self.speakingPeerDisposable.dispose()
        self.speakingAudioLevelDisposable.dispose()
        self.silenceTimer?.invalidate()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let speakingEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        self.speakingContainerNode.view.addSubview(speakingEffectView)
        self.speakingEffectView = speakingEffectView
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
    }
    
    @objc private func tap() {
        self.tapped?()
    }
    
    @objc private func backPressed() {
        self.back?()
    }
    
    @objc private func pinPressed() {
        self.togglePin?()
    }
    
    var animating: Bool {
        return self.animatingIn || self.animatingOut
    }
    private var animatingIn = false
    private var animatingOut = false
    func animateTransitionIn(from sourceNode: ASDisplayNode, transition: ContainedViewLayoutTransition) {
        guard let sourceNode = sourceNode as? VoiceChatTileItemNode, let _ = sourceNode.item, let (_, sideInset, bottomInset, isLandscape) = self.validLayout else {
            return
        }
                
        let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear)
        alphaTransition.updateAlpha(node: self.backgroundNode, alpha: 1.0)
        alphaTransition.updateAlpha(node: self.topFadeNode, alpha: 1.0)
        alphaTransition.updateAlpha(node: self.titleNode, alpha: 1.0)
        alphaTransition.updateAlpha(node: self.microphoneNode, alpha: 1.0)
        alphaTransition.updateAlpha(node: self.headerNode, alpha: 1.0)
        
        let targetFrame = self.frame
        
        if let snapshotView = sourceNode.infoNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.addSubview(snapshotView)
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
            var infoFrame = snapshotView.frame
            infoFrame.origin.x = sideInset
            infoFrame.origin.y = targetFrame.height - infoFrame.height - (sideInset.isZero ? bottomInset : 14.0)
            transition.updateFrame(view: snapshotView, frame: infoFrame)
        }
        
        self.animatingIn = true
        let startLocalFrame = sourceNode.view.convert(sourceNode.bounds, to: self.supernode?.view)
        self.update(size: startLocalFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, force: true, transition: .immediate)
        self.frame = startLocalFrame
        self.update(size: targetFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, force: true, transition: transition)
        transition.updateFrame(node: self, frame: targetFrame, completion: { [weak self] _ in
            self?.animatingIn = false
        })
    }
    
    func animateTransitionOut(to targetNode: ASDisplayNode?, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        guard let (_, sideInset, bottomInset, isLandscape) = self.validLayout else {
            return
        }
        
        let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear)
        alphaTransition.updateAlpha(node: self.backgroundNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.topFadeNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.titleNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.microphoneNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.headerNode, alpha: 0.0)
        
        guard let targetNode = targetNode as? VoiceChatTileItemNode, let _ = targetNode.item else {
            completion()
            return
        }
        
        targetNode.isHidden = false
        targetNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
              
        self.animatingOut = true
        let initialFrame = self.frame
        let targetFrame = targetNode.view.convert(targetNode.bounds, to: self.supernode?.view)
        
        self.currentVideoNode?.keepBackdropSize = true
        
        var infoView: UIView?
        if let snapshotView = targetNode.infoNode.view.snapshotView(afterScreenUpdates: false) {
            infoView = snapshotView
            self.view.addSubview(snapshotView)
            snapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, removeOnCompletion: false)
            var infoFrame = snapshotView.frame
            infoFrame.origin.y = initialFrame.height - infoFrame.height - (sideInset.isZero ? bottomInset : 14.0)
            snapshotView.frame = infoFrame
            transition.updateFrame(view: snapshotView, frame: CGRect(origin: CGPoint(), size: targetFrame.size))
        }
        
        self.update(size: targetFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, force: true, transition: transition)
        transition.updateFrame(node: self, frame: targetFrame, completion: { [weak self] _ in
            if let strongSelf = self {
                completion()
                
                infoView?.removeFromSuperview()
                strongSelf.animatingOut = false
                strongSelf.frame = initialFrame
                strongSelf.update(size: initialFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, transition: .immediate)
            }
        })
    }
    
    
    private var speakingPeerId: PeerId?
    func update(speakingPeerId: PeerId?) {
        guard self.speakingPeerId != speakingPeerId else {
            return
        }
        
        var wavesColor = UIColor(rgb: 0x34c759)
        if let getAudioLevel = self.getAudioLevel, let peerId = speakingPeerId {
            self.speakingAudioLevelView?.removeFromSuperview()
            
            let blobFrame = self.speakingAvatarNode.frame.insetBy(dx: -14.0, dy: -14.0)
            self.speakingAudioLevelDisposable.set((getAudioLevel(peerId)
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                
                if strongSelf.speakingAudioLevelView == nil, value > 0.0 {
                    let audioLevelView = VoiceBlobView(
                        frame: blobFrame,
                        maxLevel: 1.5,
                        smallBlobRange: (0, 0),
                        mediumBlobRange: (0.69, 0.87),
                        bigBlobRange: (0.71, 1.0)
                    )
                    audioLevelView.isHidden = strongSelf.currentPeer?.1 != nil
                    
                    audioLevelView.setColor(wavesColor)
                    audioLevelView.alpha = 1.0
                    
                    strongSelf.speakingAudioLevelView = audioLevelView
                    strongSelf.speakingContainerNode.view.insertSubview(audioLevelView, belowSubview: strongSelf.speakingAvatarNode.view)
                }
                
                let level = min(1.5, max(0.0, CGFloat(value)))
                if let audioLevelView = strongSelf.speakingAudioLevelView {
                    audioLevelView.updateLevel(CGFloat(value))
                    
                    let avatarScale: CGFloat
                    if value > 0.02 {
                        audioLevelView.startAnimating()
                        avatarScale = 1.03 + level * 0.13
                        audioLevelView.setColor(wavesColor, animated: true)
                    } else {
                        avatarScale = 1.0
                    }
                    
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
                    transition.updateTransformScale(node: strongSelf.avatarNode, scale: avatarScale, beginWithCurrentState: true)
                }
            }))
        } else {
            self.speakingPeerDisposable.set(nil)
            
            if let audioLevelView = self.audioLevelView {
                audioLevelView.removeFromSuperview()
                self.audioLevelView = nil
            }
        }
    }
    
    func update(peerEntry: VoiceChatPeerEntry, pinned: Bool) {
        let previousPeerEntry = self.currentPeerEntry
        self.currentPeerEntry = peerEntry
        if !arePeersEqual(previousPeerEntry?.peer, peerEntry.peer) {
            let peer = peerEntry.peer
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            if previousPeerEntry?.peer.id == peerEntry.peer.id {
                self.avatarNode.setPeer(context: self.context, theme: presentationData.theme, peer: peer)
            } else {
                let previousAvatarNode = self.avatarNode
                self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 42.0))
                self.avatarNode.setPeer(context: self.context, theme: presentationData.theme, peer: peer, synchronousLoad: true)
                self.avatarNode.frame = previousAvatarNode.frame
                previousAvatarNode.supernode?.insertSubnode(self.avatarNode, aboveSubnode: previousAvatarNode)
                previousAvatarNode.removeFromSupernode()
            }
            self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.semibold(15.0), textColor: .white)
            if let (size, sideInset, bottomInset, isLandscape) = self.validLayout {
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, transition: .immediate)
            }
        }
        
        self.pinButtonTitleNode.isHidden = !pinned
        self.pinButtonIconNode.image = !pinned ? generateTintedImage(image: UIImage(bundleImageName: "Call/Pin"), color: .white) : generateTintedImage(image: UIImage(bundleImageName: "Call/Unpin"), color: .white)
        
        var wavesColor = UIColor(rgb: 0x34c759)
        if let getAudioLevel = self.getAudioLevel, previousPeerEntry?.peer.id != peerEntry.peer.id {
            self.audioLevelView?.removeFromSuperview()
            
            let blobFrame = self.avatarNode.frame.insetBy(dx: -60.0, dy: -60.0)
            self.audioLevelDisposable.set((getAudioLevel(peerEntry.peer.id)
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                
                if strongSelf.audioLevelView == nil, value > 0.0 {
                    let audioLevelView = VoiceBlobView(
                        frame: blobFrame,
                        maxLevel: 1.5,
                        smallBlobRange: (0, 0),
                        mediumBlobRange: (0.69, 0.87),
                        bigBlobRange: (0.71, 1.0)
                    )
                    audioLevelView.isHidden = strongSelf.currentPeer?.1 != nil
                    
                    audioLevelView.setColor(wavesColor)
                    audioLevelView.alpha = 1.0
                    
                    strongSelf.audioLevelView = audioLevelView
                    strongSelf.view.insertSubview(audioLevelView, belowSubview: strongSelf.avatarNode.view)
                }
                
                let level = min(1.5, max(0.0, CGFloat(value)))
                if let audioLevelView = strongSelf.audioLevelView {
                    audioLevelView.updateLevel(CGFloat(value))
                    
                    let avatarScale: CGFloat
                    if value > 0.02 {
                        audioLevelView.startAnimating()
                        avatarScale = 1.03 + level * 0.13
                        audioLevelView.setColor(wavesColor, animated: true)
                        
                        if let silenceTimer = strongSelf.silenceTimer {
                            silenceTimer.invalidate()
                            strongSelf.silenceTimer = nil
                        }
                    } else {
                        avatarScale = 1.0
                        if strongSelf.silenceTimer == nil {
                            let silenceTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
                                self?.audioLevelView?.stopAnimating(duration: 0.5)
                                self?.silenceTimer = nil
                            }, queue: Queue.mainQueue())
                            strongSelf.silenceTimer = silenceTimer
                            silenceTimer.start()
                        }
                    }
                    
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
                    transition.updateTransformScale(node: strongSelf.avatarNode, scale: avatarScale, beginWithCurrentState: true)
                }
            }))
        }
        
        var muted = false
        var state = peerEntry.state
        if let muteState = peerEntry.muteState, case .speaking = state, muteState.mutedByYou || !muteState.canUnmute {
            state = .listening
        }
        switch state {
        case .listening:
            if let muteState = peerEntry.muteState, muteState.mutedByYou {
                muted = true
            } else {
                muted = peerEntry.muteState != nil
            }
        case .speaking:
            if let muteState = peerEntry.muteState, muteState.mutedByYou {
                muted = true
            } else {
                muted = false
            }
        case .raisedHand, .invited:
            muted = true
        }
        
        self.microphoneNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, filled: true, color: .white), animated: true)
    }
    
    func update(peer: (peer: PeerId, endpointId: String?)?, waitForFullSize: Bool, completion: (() -> Void)? = nil) {
        let previousPeer = self.currentPeer
        if previousPeer?.0 == peer?.0 && previousPeer?.1 == peer?.1 {
            completion?()
            return
        }
        self.currentPeer = peer
       
        if let (_, endpointId) = peer {
            if endpointId != previousPeer?.1 {
                if let endpointId = endpointId {
                    self.avatarNode.isHidden = true
                    self.audioLevelView?.isHidden = true
                    
                    self.call.makeIncomingVideoView(endpointId: endpointId, completion: { [weak self] videoView in
                        Queue.mainQueue().async {
                            self?.call.makeIncomingVideoView(endpointId: endpointId, completion: { [weak self] backdropVideoView in
                                Queue.mainQueue().async {
                                    guard let strongSelf = self, let videoView = videoView else {
                                        return
                                    }
                                    
                                    let videoNode = GroupVideoNode(videoView: videoView, backdropVideoView: backdropVideoView)
                                    if let currentVideoNode = strongSelf.currentVideoNode {
                                        strongSelf.currentVideoNode = nil
                                        
                                        currentVideoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak currentVideoNode] _ in
                                            currentVideoNode?.removeFromSupernode()
                                        })
                                    }
                                    strongSelf.currentVideoNode = videoNode
                                    strongSelf.insertSubnode(videoNode, aboveSubnode: strongSelf.backgroundNode)
                                    if let (size, sideInset, bottomInset, isLandscape) = strongSelf.validLayout {
                                        strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, transition: .immediate)
                                    }
                                    
                                    if waitForFullSize {
                                        strongSelf.videoReadyDisposable.set((videoNode.ready
                                        |> filter { $0 }
                                        |> take(1)
                                        |> deliverOnMainQueue).start(next: { _ in
                                            Queue.mainQueue().after(0.07) {
                                                completion?()
                                            }
                                        }))
                                    } else {
                                        strongSelf.videoReadyDisposable.set(nil)
                                        completion?()
                                    }
                                }
                            })
                        }
                    })
                } else {
                    self.avatarNode.isHidden = false
                    self.audioLevelView?.isHidden = false
                    if let currentVideoNode = self.currentVideoNode {
                        currentVideoNode.removeFromSupernode()
                        self.currentVideoNode = nil
                    }
                }
            } else {
                self.audioLevelView?.isHidden = self.currentPeer?.1 != nil
                completion?()
            }
        } else {
            self.videoReadyDisposable.set(nil)
            if let currentVideoNode = self.currentVideoNode {
                currentVideoNode.removeFromSupernode()
                self.currentVideoNode = nil
            }
            completion?()
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, isLandscape: Bool, force: Bool = false, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, sideInset, bottomInset, isLandscape)
        
        if self.animating && !force {
            return
        }
        
        let initialBottomInset = bottomInset
        var bottomInset = bottomInset
        if !sideInset.isZero {
            bottomInset = 14.0
        }
        
        let layoutMode: GroupVideoNode.LayoutMode
        if case .immediate = transition, self.animatingIn {
            layoutMode = .fillOrFitToSquare
            bottomInset = 0.0
        } else if self.animatingOut {
            layoutMode = .fillOrFitToSquare
            bottomInset = 0.0
        } else {
            layoutMode = isLandscape ? .fillHorizontal : .fillVertical
        }
        
        if let currentVideoNode = self.currentVideoNode {
            transition.updateFrame(node: currentVideoNode, frame: CGRect(origin: CGPoint(), size: size))
            currentVideoNode.updateLayout(size: size, layoutMode: layoutMode, transition: transition)
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let avatarSize = CGSize(width: 180.0, height: 180.0)
        let avatarFrame = CGRect(origin: CGPoint(x: (size.width - avatarSize.width) / 2.0, y: (size.height - avatarSize.height) / 2.0), size: avatarSize)
        transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
        if let audioLevelView = self.audioLevelView {
            transition.updatePosition(layer: audioLevelView.layer, position: avatarFrame.center)
        }
        
        let animationSize = CGSize(width: 36.0, height: 36.0)
        let titleSize = self.titleNode.updateLayout(size)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: sideInset + 12.0 + animationSize.width, y: size.height - bottomInset - titleSize.height - 16.0), size: titleSize))
        
        transition.updateFrame(node: self.microphoneNode, frame: CGRect(origin: CGPoint(x: sideInset + 7.0, y: size.height - bottomInset - animationSize.height - 6.0), size: animationSize))
        
        var fadeHeight: CGFloat = 50.0
        if size.height != 180.0 && size.width < size.height {
            fadeHeight = 140.0
        }
        transition.updateFrame(node: self.bottomFadeNode, frame: CGRect(x: 0.0, y: size.height - fadeHeight, width: size.width, height: fadeHeight))
        transition.updateFrame(node: self.topFadeNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: 50.0))
        
        let backSize = self.backButtonNode.measure(CGSize(width: 320.0, height: 100.0))
        if let image = self.backButtonArrowNode.image {
            transition.updateFrame(node: self.backButtonArrowNode, frame: CGRect(origin: CGPoint(x: sideInset + 9.0, y: 12.0), size: image.size))
        }
        transition.updateFrame(node: self.backButtonNode, frame: CGRect(origin: CGPoint(x: sideInset + 28.0, y: 13.0), size: backSize))
        
        let unpinSize = self.pinButtonTitleNode.updateLayout(size)
        if let image = self.pinButtonIconNode.image {
            let offset: CGFloat = sideInset.isZero ? 0.0 : initialBottomInset + 8.0
            transition.updateFrame(node: self.pinButtonIconNode, frame: CGRect(origin: CGPoint(x: size.width - image.size.width - offset, y: 0.0), size: image.size))
            transition.updateFrame(node: self.pinButtonTitleNode, frame: CGRect(origin: CGPoint(x: size.width - image.size.width - unpinSize.width + 4.0 - offset, y: 14.0), size: unpinSize))
            transition.updateFrame(node: self.pinButtonNode, frame: CGRect(x: size.width - image.size.width - unpinSize.width - offset, y: 0.0, width: unpinSize.width + image.size.width, height: 44.0))
        }
        
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 64.0)))
    }
}
