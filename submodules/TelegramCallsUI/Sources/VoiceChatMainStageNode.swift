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
import TextFormat
import Markdown
import ContextUI

private let backArrowImage = NavigationBarTheme.generateBackArrowImage(color: .white)
private let backgroundCornerRadius: CGFloat = 11.0
private let fadeColor = UIColor(rgb: 0x000000, alpha: 0.5)
private let fadeHeight: CGFloat = 50.0
private let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)

final class VoiceChatMainStageNode: ASDisplayNode {
    private let context: AccountContext
    private let call: PresentationGroupCall
    private var currentPeer: (PeerId, String?)?
    private var currentPeerEntry: VoiceChatPeerEntry?
        
    var callState: PresentationGroupCallState?
    
    private var currentVideoNode: GroupVideoNode?
        
    private let backgroundNode: ASDisplayNode
    private let topFadeNode: ASDisplayNode
    private let bottomFadeNode: ASDisplayNode
    private let bottomFillNode: ASDisplayNode
    private let headerNode: ASDisplayNode
    private let backButtonNode: HighlightableButtonNode
    private let backButtonArrowNode: ASImageNode
    private let pinButtonNode: HighlightTrackingButtonNode
    private let pinButtonIconNode: ASImageNode
    private let pinButtonTitleNode: ImmediateTextNode
    private let audioLevelNode: VoiceChatBlobNode
    private let audioLevelDisposable = MetaDisposable()
    private let speakingPeerDisposable = MetaDisposable()
    private let speakingAudioLevelDisposable = MetaDisposable()
    private var backdropAvatarNode: ImageNode
    private var backdropEffectView: UIVisualEffectView?
    private var avatarNode: ImageNode
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
    var switchTo: ((PeerId) -> Void)?
    
    var controlsHidden: ((Bool) -> Void)?
    
    var getAudioLevel: ((PeerId) -> Signal<Float, NoError>)?
    private let videoReadyDisposable = MetaDisposable()
    private var silenceTimer: SwiftSignalKit.Timer?
        
    init(context: AccountContext, call: PresentationGroupCall) {
        self.context = context
        self.call = call
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.alpha = 0.0
        self.backgroundNode.backgroundColor = UIColor(rgb: 0x1c1c1e)
        
        self.topFadeNode = ASDisplayNode()
        self.topFadeNode.alpha = 0.0
        self.topFadeNode.displaysAsynchronously = false
        if let image = generateImage(CGSize(width: fadeHeight, height: fadeHeight), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            
            let colorsArray = [fadeColor.cgColor, fadeColor.withAlphaComponent(0.0).cgColor] as CFArray
            var locations: [CGFloat] = [1.0, 0.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }) {
            self.topFadeNode.backgroundColor = UIColor(patternImage: image)
        }
        
        self.bottomFadeNode = ASDisplayNode()
        self.bottomFadeNode.displaysAsynchronously = false
        if let image = generateImage(CGSize(width: fadeHeight, height: fadeHeight), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            
            let colorsArray = [fadeColor.withAlphaComponent(0.0).cgColor, fadeColor.cgColor] as CFArray
            var locations: [CGFloat] = [1.0, 0.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }) {
            self.bottomFadeNode.backgroundColor = UIColor(patternImage: image)
        }
        
        self.bottomFillNode = ASDisplayNode()
        self.bottomFillNode.backgroundColor = fadeColor
        
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
        
        self.backdropAvatarNode = ImageNode()
        self.backdropAvatarNode.contentMode = .scaleAspectFill
        self.backdropAvatarNode.displaysAsynchronously = false
        self.backdropAvatarNode.isHidden = true
        
        self.audioLevelNode = VoiceChatBlobNode(size: CGSize(width: 300.0, height: 300.0))
        
        self.avatarNode = ImageNode()
        self.avatarNode.displaysAsynchronously = false
        self.avatarNode.isHidden = true
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.alpha = 0.0
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        
        self.microphoneNode = VoiceChatMicrophoneNode()
        self.microphoneNode.alpha = 0.0
        
        self.speakingContainerNode = ASDisplayNode()
        self.speakingContainerNode.alpha = 0.0
        
        self.speakingAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))
        self.speakingTitleNode = ImmediateTextNode()
        self.speakingTitleNode.displaysAsynchronously = false
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = backgroundCornerRadius
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topFadeNode)
        self.addSubnode(self.bottomFadeNode)
        self.addSubnode(self.bottomFillNode)
        self.addSubnode(self.backdropAvatarNode)
        self.addSubnode(self.audioLevelNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.microphoneNode)
        self.addSubnode(self.headerNode)
        
        self.headerNode.addSubnode(self.backButtonNode)
        self.headerNode.addSubnode(self.backButtonArrowNode)
        self.headerNode.addSubnode(self.pinButtonIconNode)
        self.headerNode.addSubnode(self.pinButtonTitleNode)
        self.headerNode.addSubnode(self.pinButtonNode)
        
        self.addSubnode(self.speakingContainerNode)
        
        self.speakingContainerNode.addSubnode(self.speakingAvatarNode)
        self.speakingContainerNode.addSubnode(self.speakingTitleNode)

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
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        let speakingEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        speakingEffectView.layer.cornerRadius = 19.0
        speakingEffectView.clipsToBounds = true
        if #available(iOS 13.0, *) {
            speakingEffectView.layer.cornerCurve = .continuous
        }
        self.speakingContainerNode.view.insertSubview(speakingEffectView, at: 0)
        self.speakingEffectView = speakingEffectView
        
        let effect: UIVisualEffect
        if #available(iOS 13.0, *) {
            effect = UIBlurEffect(style: .systemMaterialDark)
        } else {
            effect = UIBlurEffect(style: .dark)
        }
        let backdropEffectView = UIVisualEffectView(effect: effect)
        backdropEffectView.isHidden = true
        self.view.insertSubview(backdropEffectView, aboveSubview: self.backdropAvatarNode.view)
        self.backdropEffectView = backdropEffectView
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
        
        self.speakingContainerNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.speakingTap)))
    }
    
    @objc private func tap() {
        self.tapped?()
    }
    
    @objc private func speakingTap() {
        if let peerId = self.effectiveSpeakingPeerId {
            self.switchTo?(peerId)
            self.update(speakingPeerId: nil)
        }
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
    private var appeared = false
    
    func animateTransitionIn(from sourceNode: ASDisplayNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        guard let sourceNode = sourceNode as? VoiceChatTileItemNode, let _ = sourceNode.item, let (_, sideInset, bottomInset, isLandscape) = self.validLayout else {
            return
        }
        self.appeared = true
        
        self.backgroundNode.alpha = 0.0
        self.topFadeNode.alpha = 0.0
        self.titleNode.alpha = 0.0
        self.microphoneNode.alpha = 0.0
        self.headerNode.alpha = 0.0
                
        let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
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
            sourceNode.alpha = 1.0
            self?.animatingIn = false
            completion()
        })
    }
    
    func animateTransitionOut(to targetNode: ASDisplayNode?, offset: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        guard let (_, sideInset, bottomInset, isLandscape) = self.validLayout else {
            return
        }
        
        self.appeared = false
        
        let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
        if offset.isZero {
            alphaTransition.updateAlpha(node: self.backgroundNode, alpha: 0.0)
        } else {
            self.backgroundNode.alpha = 0.0
            
            self.microphoneNode.alpha = 1.0
            self.titleNode.alpha = 1.0
            self.bottomFadeNode.alpha = 1.0
            self.bottomFillNode.alpha = 1.0
        }
        alphaTransition.updateAlpha(node: self.topFadeNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.titleNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.microphoneNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.headerNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.bottomFadeNode, alpha: 1.0)
        
        guard let targetNode = targetNode as? VoiceChatTileItemNode, let _ = targetNode.item else {
            completion()
            return
        }
        
        targetNode.isHidden = false
        if offset.isZero {
            targetNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        }
        
        self.animatingOut = true
        let originalFrame = self.frame
        let initialFrame = originalFrame.offsetBy(dx: 0.0, dy: offset)
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
        
        targetNode.alpha = 0.0
        
        self.frame = initialFrame
        self.update(size: targetFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, force: true, transition: transition)
        transition.updateFrame(node: self, frame: targetFrame, completion: { [weak self] _ in
            if let strongSelf = self {
                completion()
                
                infoView?.removeFromSuperview()
                targetNode.alpha = 1.0
                targetNode.highlightNode.layer.animateAlpha(from: 0.0, to: targetNode.highlightNode.alpha, duration: 0.2)
                strongSelf.animatingOut = false
                strongSelf.frame = originalFrame
                strongSelf.update(size: initialFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, transition: .immediate)
            }
        })
        
        self.update(speakingPeerId: nil)
    }
    
    private var effectiveSpeakingPeerId: PeerId?
    private func updateSpeakingPeer() {
        var effectiveSpeakingPeerId = self.speakingPeerId
        if let peerId = effectiveSpeakingPeerId, self.visiblePeerIds.contains(peerId) || self.currentPeer?.0 == peerId || self.callState?.myPeerId == peerId {
            effectiveSpeakingPeerId = nil
        }
        guard self.effectiveSpeakingPeerId != effectiveSpeakingPeerId else {
            return
        }
        self.effectiveSpeakingPeerId = effectiveSpeakingPeerId
        if let getAudioLevel = self.getAudioLevel, let peerId = effectiveSpeakingPeerId {
            let wavesColor = UIColor(rgb: 0x34c759)
            if let speakingAudioLevelView = self.speakingAudioLevelView {
                speakingAudioLevelView.removeFromSuperview()
                self.speakingAudioLevelView = nil
            }
            
            self.speakingPeerDisposable.set((self.context.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let strongSelf = self else {
                    return
                }
                
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.speakingAvatarNode.setPeer(context: strongSelf.context, theme: presentationData.theme, peer: peer)
                
                let bodyAttributes = MarkdownAttributeSet(font: Font.regular(15.0), textColor: .white, additionalAttributes: [:])
                let boldAttributes = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: .white, additionalAttributes: [:])
                let attributedText = addAttributesToStringWithRanges(presentationData.strings.VoiceChat_ParticipantIsSpeaking(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)), body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                strongSelf.speakingTitleNode.attributedText = attributedText

                strongSelf.speakingContainerNode.alpha = 0.0
                
                if let (size, sideInset, bottomInset, isLandscape) = strongSelf.validLayout {
                    strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, transition: .immediate)
                }
                
                strongSelf.speakingContainerNode.alpha = 1.0
                strongSelf.speakingContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                strongSelf.speakingContainerNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                
                let blobFrame = strongSelf.speakingAvatarNode.frame.insetBy(dx: -12.0, dy: -12.0)
                strongSelf.speakingAudioLevelDisposable.set((getAudioLevel(peerId)
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
                            audioLevelView.startAnimating(immediately: true)
                            avatarScale = 1.03 + level * 0.13
                            audioLevelView.setColor(wavesColor, animated: true)
                        } else {
                            avatarScale = 1.0
                        }
                        
                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                        transition.updateTransformScale(node: strongSelf.speakingAvatarNode, scale: avatarScale, beginWithCurrentState: true)
                    }
                }))
            }))
        } else {
            self.speakingPeerDisposable.set(nil)
            self.speakingAudioLevelDisposable.set(nil)
            
            let audioLevelView = self.speakingAudioLevelView
            self.speakingAudioLevelView = nil
            
            if !self.speakingContainerNode.alpha.isZero {
                self.speakingContainerNode.alpha = 0.0
                self.speakingContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { _ in
                    audioLevelView?.removeFromSuperview()
                })
                self.speakingContainerNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
            } else {
                audioLevelView?.removeFromSuperview()
            }
        }
    }
    
    private var visiblePeerIds = Set<PeerId>()
    func update(visiblePeerIds: Set<PeerId>) {
        self.visiblePeerIds = visiblePeerIds
        self.updateSpeakingPeer()
    }
    
    private var speakingPeerId: PeerId?
    func update(speakingPeerId: PeerId?) {
        self.speakingPeerId = speakingPeerId
        self.updateSpeakingPeer()
    }
    
    func update(peerEntry: VoiceChatPeerEntry, pinned: Bool) {
        let previousPeerEntry = self.currentPeerEntry
        self.currentPeerEntry = peerEntry
        
        let peer = peerEntry.peer
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if !arePeersEqual(previousPeerEntry?.peer, peerEntry.peer) {
            self.backdropAvatarNode.setSignal(peerAvatarCompleteImage(account: self.context.account, peer: peer, size: CGSize(width: 180.0, height: 180.0), round: false, font: avatarPlaceholderFont(size: 78.0), drawLetters: false))
            self.avatarNode.setSignal(peerAvatarCompleteImage(account: self.context.account, peer: peer, size: CGSize(width: 180.0, height: 180.0), font: avatarPlaceholderFont(size: 78.0), fullSize: true))
        }
                
        var gradient: VoiceChatBlobNode.Gradient = .active
        var muted = false
        var state = peerEntry.state
        if let muteState = peerEntry.muteState, case .speaking = state, muteState.mutedByYou || !muteState.canUnmute {
            state = .listening
        }
        var mutedForYou = false
        switch state {
            case .listening:
                if let muteState = peerEntry.muteState {
                    muted = true
                    if muteState.mutedByYou {
                        gradient = .mutedForYou
                        mutedForYou = true
                    } else if !muteState.canUnmute {
                        gradient = .muted
                    }
                } else {
                    gradient = .active
                    muted = peerEntry.muteState != nil
                }
            case .speaking:
                if let muteState = peerEntry.muteState, muteState.mutedByYou {
                    gradient = .mutedForYou
                    muted = true
                    mutedForYou = true
                } else {
                    gradient = .speaking
                    muted = false
                }
            default:
                muted = true
        }
        
        var microphoneColor = UIColor.white
        var titleAttributedString = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.semibold(15.0), textColor: .white)
        if mutedForYou {
            microphoneColor = destructiveColor
            
            let updatedString = NSMutableAttributedString(attributedString: titleAttributedString)
            updatedString.append(NSAttributedString(string: " \(presentationData.strings.VoiceChat_StatusMutedForYou)", font: Font.regular(15.0), textColor: UIColor.white))
            titleAttributedString = updatedString
        }
        self.titleNode.attributedText = titleAttributedString
        if let (size, sideInset, bottomInset, isLandscape) = self.validLayout {
            self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, transition: .immediate)
        }
        
        self.pinButtonTitleNode.isHidden = !pinned
        self.pinButtonIconNode.image = !pinned ? generateTintedImage(image: UIImage(bundleImageName: "Call/Pin"), color: .white) : generateTintedImage(image: UIImage(bundleImageName: "Call/Unpin"), color: .white)
        
        self.audioLevelNode.startAnimating(immediately: true)
        
        if let getAudioLevel = self.getAudioLevel, previousPeerEntry?.peer.id != peerEntry.peer.id {
            self.avatarNode.layer.removeAllAnimations()
            self.avatarNode.transform = CATransform3DIdentity
            self.audioLevelNode.updateGlowAndGradientAnimations(type: .active, animated: false)
            self.audioLevelNode.updateLevel(0.0, immediately: true)
            
            self.audioLevelNode.isHidden = self.currentPeer?.1 != nil
            self.audioLevelDisposable.set((getAudioLevel(peerEntry.peer.id)
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                                    
                let level = min(1.5, max(0.0, CGFloat(value)))
                
                strongSelf.audioLevelNode.updateLevel(CGFloat(value), immediately: false)
                    
                let avatarScale: CGFloat
                if value > 0.02 {
                    avatarScale = 1.03 + level * 0.13
                } else {
                    avatarScale = 1.0
                }
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
                transition.updateTransformScale(node: strongSelf.avatarNode, scale: avatarScale, beginWithCurrentState: true)
            }))
        }
        
        self.audioLevelNode.updateGlowAndGradientAnimations(type: gradient, animated: true)
        
        self.microphoneNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, filled: true, color: microphoneColor), animated: true)
    }
    
    private func setAvatarHidden(_ hidden: Bool) {
        self.backdropAvatarNode.isHidden = hidden
        self.backdropEffectView?.isHidden = hidden
        self.avatarNode.isHidden = hidden
        self.audioLevelNode.isHidden = hidden
    }
    
    func update(peer: (peer: PeerId, endpointId: String?)?, waitForFullSize: Bool, completion: (() -> Void)? = nil) {
        let previousPeer = self.currentPeer
        if previousPeer?.0 == peer?.0 && previousPeer?.1 == peer?.1 {
            completion?()
            return
        }
        self.currentPeer = peer
       
        self.updateSpeakingPeer()
        
        if let (_, endpointId) = peer {
            if endpointId != previousPeer?.1 {
                if let endpointId = endpointId {
                    var delayTransition = false
                    if previousPeer?.0 == peer?.0 && self.appeared {
                        delayTransition = true
                    }                    
                    if !delayTransition {
                        self.setAvatarHidden(true)
                    }
                    
                    self.call.makeIncomingVideoView(endpointId: endpointId, requestClone: true, completion: { [weak self] videoView, backdropVideoView in
                        Queue.mainQueue().async {
                            guard let strongSelf = self, let videoView = videoView else {
                                return
                            }

                            let videoNode = GroupVideoNode(videoView: videoView, backdropVideoView: backdropVideoView)
                            videoNode.tapped = { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.tap()
                            }
                            videoNode.sourceContainerNode.activate = { [weak self] sourceNode in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.setControlsHidden(true, animated: false)
                                strongSelf.controlsHidden?(true)
                                let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
                                    return UIScreen.main.bounds
                                })
                                strongSelf.context.sharedContext.mainWindow?.presentInGlobalOverlay(pinchController)
                            }
                            videoNode.sourceContainerNode.animatedOut = { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.controlsHidden?(false)
                                strongSelf.setControlsHidden(false, animated: true)
                            }
                            videoNode.isUserInteractionEnabled = true
                            let previousVideoNode = strongSelf.currentVideoNode
                            strongSelf.currentVideoNode = videoNode
                            strongSelf.insertSubnode(videoNode, aboveSubnode: strongSelf.backgroundNode)

                            if delayTransition {
                                videoNode.alpha = 0.0
                            }
                            if waitForFullSize {
                                Queue.mainQueue().after(2.0) {
                                    if let previousVideoNode = previousVideoNode {
                                        previousVideoNode.removeFromSupernode()
                                    }
                                }
                                strongSelf.videoReadyDisposable.set((videoNode.ready
                                |> filter { $0 }
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] _ in
                                    Queue.mainQueue().after(0.1) {
                                        if let strongSelf = self {
                                            if let (size, sideInset, bottomInset, isLandscape) = strongSelf.validLayout {
                                                strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, transition: .immediate)
                                            }
                                        }
                                        
                                        Queue.mainQueue().after(0.02) {
                                            completion?()
                                        }
                                        
                                        if delayTransition {
                                            if let videoNode = strongSelf.currentVideoNode {
                                                videoNode.alpha = 1.0
                                                videoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, completion: { [weak self] _ in
                                                    if let strongSelf = self {
                                                        strongSelf.setAvatarHidden(true)
                                                        if let previousVideoNode = previousVideoNode {
                                                            previousVideoNode.removeFromSupernode()
                                                        }
                                                    }
                                                })
                                            }
                                        } else {
                                            Queue.mainQueue().after(0.07) {
                                                if let previousVideoNode = previousVideoNode {
                                                    previousVideoNode.removeFromSupernode()
                                                }
                                            }
                                        }
                                    }
                                }))
                            } else {
                                if let (size, sideInset, bottomInset, isLandscape) = strongSelf.validLayout {
                                    strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, transition: .immediate)
                                }
                                if let previousVideoNode = previousVideoNode {
                                    previousVideoNode.removeFromSupernode()
                                }
                                strongSelf.videoReadyDisposable.set(nil)
                                completion?()
                            }
                        }
                    })
                } else {
                    self.setAvatarHidden(false)
                    if self.appeared {
                        if let currentVideoNode = self.currentVideoNode {
                            currentVideoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak currentVideoNode] _ in
                                currentVideoNode?.removeFromSupernode()
                            })
                        }
                    } else {
                        if let currentVideoNode = self.currentVideoNode {
                            currentVideoNode.removeFromSupernode()
                            self.currentVideoNode = nil
                        }
                    }
                    completion?()
                }
            } else {
                if let currentVideoNode = self.currentVideoNode {
                    currentVideoNode.removeFromSupernode()
                    self.currentVideoNode = nil
                }
                self.setAvatarHidden(endpointId != nil)
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
    
    func setControlsHidden(_ hidden: Bool, animated: Bool, delay: Double = 0.0) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
        transition.updateAlpha(node: self.headerNode, alpha: hidden ? 0.0 : 1.0, delay: delay)
        transition.updateAlpha(node: self.topFadeNode, alpha: hidden ? 0.0 : 1.0, delay: delay)
        
        transition.updateAlpha(node: self.titleNode, alpha: hidden ? 0.0 : 1.0, delay: delay)
        transition.updateAlpha(node: self.microphoneNode, alpha: hidden ? 0.0 : 1.0, delay: delay)
        transition.updateAlpha(node: self.bottomFadeNode, alpha: hidden ? 0.0 : 1.0, delay: delay)
        transition.updateAlpha(node: self.bottomFillNode, alpha: hidden ? 0.0 : 1.0, delay: delay)
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
        transition.updateFrame(node: self.backdropAvatarNode, frame: CGRect(origin: CGPoint(), size: size))
        if let backdropEffectView = self.backdropEffectView {
            transition.updateFrame(view: backdropEffectView, frame: CGRect(origin: CGPoint(), size: size))
        }
        
        let avatarSize = CGSize(width: 180.0, height: 180.0)
        let avatarFrame = CGRect(origin: CGPoint(x: (size.width - avatarSize.width) / 2.0, y: (size.height - avatarSize.height) / 2.0), size: avatarSize)
        transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
        transition.updateFrame(node: self.audioLevelNode, frame: avatarFrame.insetBy(dx: -60.0, dy: -60.0))
        
        let animationSize = CGSize(width: 36.0, height: 36.0)
        let titleSize = self.titleNode.updateLayout(size)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: sideInset + 12.0 + animationSize.width, y: size.height - bottomInset - titleSize.height - 16.0), size: titleSize))
        
        transition.updateFrame(node: self.microphoneNode, frame: CGRect(origin: CGPoint(x: sideInset + 7.0, y: size.height - bottomInset - animationSize.height - 6.0), size: animationSize))
        
        var totalFadeHeight: CGFloat = fadeHeight
        if size.height != tileHeight && size.width < size.height {
            totalFadeHeight += bottomInset
        }
        transition.updateFrame(node: self.bottomFadeNode, frame: CGRect(x: 0.0, y: size.height - totalFadeHeight, width: size.width, height: fadeHeight))
        transition.updateFrame(node: self.bottomFillNode, frame: CGRect(x: 0.0, y: size.height - totalFadeHeight + fadeHeight, width: size.width, height: max(0.0, totalFadeHeight - fadeHeight)))
        transition.updateFrame(node: self.topFadeNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: 50.0))
        
        let backSize = self.backButtonNode.measure(CGSize(width: 320.0, height: 100.0))
        if let image = self.backButtonArrowNode.image {
            transition.updateFrame(node: self.backButtonArrowNode, frame: CGRect(origin: CGPoint(x: sideInset + 8.0, y: 11.0), size: image.size))
        }
        transition.updateFrame(node: self.backButtonNode, frame: CGRect(origin: CGPoint(x: sideInset + 27.0, y: 12.0), size: backSize))
        
        let unpinSize = self.pinButtonTitleNode.updateLayout(size)
        if let image = self.pinButtonIconNode.image {
            let offset: CGFloat = sideInset.isZero ? 0.0 : initialBottomInset + 8.0
            transition.updateFrame(node: self.pinButtonIconNode, frame: CGRect(origin: CGPoint(x: size.width - image.size.width - offset, y: 0.0), size: image.size))
            transition.updateFrame(node: self.pinButtonTitleNode, frame: CGRect(origin: CGPoint(x: size.width - image.size.width - unpinSize.width + 4.0 - offset, y: 12.0), size: unpinSize))
            transition.updateFrame(node: self.pinButtonNode, frame: CGRect(x: size.width - image.size.width - unpinSize.width - offset, y: 0.0, width: unpinSize.width + image.size.width, height: 44.0))
        }
        
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 64.0)))
        
        let speakingInset: CGFloat = 16.0
        let speakingAvatarSize = CGSize(width: 30.0, height: 30.0)
        let speakingTitleSize = self.speakingTitleNode.updateLayout(CGSize(width: size.width - 100.0, height: CGFloat.greatestFiniteMagnitude))
        let speakingContainerSize = CGSize(width: speakingTitleSize.width + speakingInset * 2.0 + speakingAvatarSize.width, height: 38.0)
        self.speakingEffectView?.frame = CGRect(origin: CGPoint(), size: speakingContainerSize)
        self.speakingAvatarNode.frame = CGRect(origin: CGPoint(x: 4.0, y: 4.0), size: speakingAvatarSize)
        self.speakingTitleNode.frame = CGRect(origin: CGPoint(x: 4.0 + speakingAvatarSize.width + 14.0, y: floorToScreenPixels((38.0 - speakingTitleSize.height) / 2.0)), size: speakingTitleSize)
        transition.updateFrame(node: self.speakingContainerNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - speakingContainerSize.width) / 2.0), y: 46.0), size: speakingContainerSize))
    }
    
    func flipVideoIfNeeded() {
        guard self.currentPeer?.0 == self.callState?.myPeerId else {
            return
        }
        self.currentVideoNode?.flip(withBackground: false)
    }
}

private let blue = UIColor(rgb: 0x007fff)
private let lightBlue = UIColor(rgb: 0x00affe)
private let green = UIColor(rgb: 0x33c659)
private let activeBlue = UIColor(rgb: 0x00a0b9)
private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xef436c)

class VoiceChatBlobNode: ASDisplayNode {
    enum Gradient {
        case speaking
        case active
        case connecting
        case mutedForYou
        case muted
    }
    private let size: CGSize
    
    private let blobView: VoiceBlobView
    private let foregroundGradientLayer = CAGradientLayer()
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = false
    
    init(size: CGSize) {
        self.size = size
        self.blobView = VoiceBlobView(
            frame: CGRect(origin: CGPoint(), size: size),
            maxLevel: 1.5,
            smallBlobRange: (0, 0),
            mediumBlobRange: (0.69, 0.87),
            bigBlobRange: (0.71, 1.0)
        )
        self.blobView.setColor(.white)
        
        self.foregroundGradientLayer.type = .radial
        self.foregroundGradientLayer.colors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
        self.foregroundGradientLayer.locations = [0.0, 0.85, 1.0]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init()
        
        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
                strongSelf.updateAnimations()
            }
        }
        
        self.addSubnode(self.hierarchyTrackingNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.mask = self.blobView
        self.layer.addSublayer(self.foregroundGradientLayer)
    }
        
    func updateAnimations() {
        if !self.isCurrentlyInHierarchy {
            self.foregroundGradientLayer.removeAllAnimations()
            self.blobView.stopAnimating()
            return
        }
        self.setupGradientAnimations()
        self.blobView.startAnimating(immediately: true)
    }
    
    func updateLevel(_ level: CGFloat, immediately: Bool) {
        self.blobView.updateLevel(level, immediately: immediately)
    }
    
    func startAnimating(immediately: Bool) {
        self.blobView.startAnimating(immediately: immediately)
    }
    
    func stopAnimating() {
        self.blobView.stopAnimating(duration: 0.8)
    }
    
    private func setupGradientAnimations() {
        if let _ = self.foregroundGradientLayer.animation(forKey: "movement") {
        } else {
            let previousValue = self.foregroundGradientLayer.startPoint
            let newValue: CGPoint
            if self.blobView.presentationAudioLevel > 0.22 {
                newValue = CGPoint(x: CGFloat.random(in: 0.9 ..< 1.0), y: CGFloat.random(in: 0.15 ..< 0.35))
            } else if self.blobView.presentationAudioLevel > 0.01 {
                newValue = CGPoint(x: CGFloat.random(in: 0.57 ..< 0.85), y: CGFloat.random(in: 0.15 ..< 0.45))
            } else {
                newValue = CGPoint(x: CGFloat.random(in: 0.6 ..< 0.75), y: CGFloat.random(in: 0.25 ..< 0.45))
            }
            self.foregroundGradientLayer.startPoint = newValue
            
            CATransaction.begin()
            
            let animation = CABasicAnimation(keyPath: "startPoint")
            animation.duration = Double.random(in: 0.8 ..< 1.4)
            animation.fromValue = previousValue
            animation.toValue = newValue
            
            CATransaction.setCompletionBlock { [weak self] in
                if let isCurrentlyInHierarchy = self?.isCurrentlyInHierarchy, isCurrentlyInHierarchy {
                    self?.setupGradientAnimations()
                }
            }
            
            self.foregroundGradientLayer.add(animation, forKey: "movement")
            CATransaction.commit()
        }
    }
    
    private var gradient: Gradient?
    func updateGlowAndGradientAnimations(type: Gradient, animated: Bool = true) {
        guard self.gradient != type else {
            return
        }
        self.gradient = type
        let initialColors = self.foregroundGradientLayer.colors
        let targetColors: [CGColor]
        switch type {
            case .speaking:
                targetColors = [activeBlue.cgColor, green.cgColor, green.cgColor]
            case .active:
                targetColors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
            case .connecting:
                targetColors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
            case .mutedForYou:
                targetColors = [pink.cgColor, destructiveColor.cgColor, destructiveColor.cgColor]
            case .muted:
                targetColors = [pink.cgColor, purple.cgColor, purple.cgColor]
        }
        if animated {
            self.foregroundGradientLayer.colors = targetColors
            self.foregroundGradientLayer.animate(from: initialColors as AnyObject, to: targetColors as AnyObject, keyPath: "colors", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.foregroundGradientLayer.colors = targetColors
            CATransaction.commit()
        }
    }
    
    override func layout() {
        super.layout()
        
        self.blobView.frame = self.bounds
        self.foregroundGradientLayer.frame = self.bounds.insetBy(dx: -24.0, dy: -24.0)
    }
}
