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
private let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)

private class VoiceChatPinButtonNode: HighlightTrackingButtonNode {
    private let pinButtonIconNode: VoiceChatPinNode
    private let pinButtonClippingnode: ASDisplayNode
    private let pinButtonTitleNode: ImmediateTextNode
    
    init(presentationData: PresentationData) {
        self.pinButtonIconNode = VoiceChatPinNode()
        self.pinButtonClippingnode = ASDisplayNode()
        self.pinButtonClippingnode.clipsToBounds = true
    
        self.pinButtonTitleNode = ImmediateTextNode()
        self.pinButtonTitleNode.attributedText = NSAttributedString(string: presentationData.strings.VoiceChat_Unpin, font: Font.regular(17.0), textColor: .white)
        self.pinButtonTitleNode.alpha = 0.0
    
        super.init()
        
        self.addSubnode(self.pinButtonClippingnode)
        self.addSubnode(self.pinButtonIconNode)
        self.pinButtonClippingnode.addSubnode(self.pinButtonTitleNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.pinButtonClippingnode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.pinButtonIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.pinButtonClippingnode.alpha = 0.4
                    strongSelf.pinButtonIconNode.alpha = 0.4
                } else {
                    strongSelf.pinButtonClippingnode.alpha = 1.0
                    strongSelf.pinButtonIconNode.alpha = 1.0
                    strongSelf.pinButtonClippingnode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.pinButtonIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    private var isPinned = false
    func update(pinned: Bool, animated: Bool) {
        let wasPinned = self.isPinned
        self.pinButtonIconNode.update(state: .init(pinned: pinned, color: .white), animated: true)
        self.isPinned = pinned
        
        self.pinButtonTitleNode.alpha = self.isPinned ? 1.0 : 0.0
        if animated && pinned != wasPinned {
            if wasPinned {
                self.pinButtonTitleNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                self.pinButtonTitleNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: self.pinButtonTitleNode.frame.width, y: 0.0), duration: 0.2, additive: true)
            } else {
                self.pinButtonTitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.pinButtonTitleNode.layer.animatePosition(from: CGPoint(x: self.pinButtonTitleNode.frame.width, y: 0.0), to: CGPoint(), duration: 0.2, additive: true)
            }
        }
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let unpinSize = self.pinButtonTitleNode.updateLayout(size)
        let pinIconSize = CGSize(width: 48.0, height: 48.0)
        let totalSize = CGSize(width: unpinSize.width + pinIconSize.width, height: 44.0)
        
        transition.updateFrame(node: self.pinButtonIconNode, frame: CGRect(origin: CGPoint(x: totalSize.width - pinIconSize.width, y: 0.0), size: pinIconSize))
        transition.updateFrame(node: self.pinButtonTitleNode, frame: CGRect(origin: CGPoint(x: 4.0, y: 12.0), size: unpinSize))
        transition.updateFrame(node: self.pinButtonClippingnode, frame: CGRect(x: 0.0, y: 0.0, width: totalSize.width - pinIconSize.width * 0.6667, height: 44.0))
        
        return totalSize
    }
}

final class VoiceChatMainStageNode: ASDisplayNode {
    private let context: AccountContext
    private let call: PresentationGroupCall
    private(set) var currentPeer: (PeerId, String?, Bool, Bool, Bool)?
    private var currentPeerEntry: VoiceChatPeerEntry?
        
    var callState: PresentationGroupCallState?
    
    private(set) var currentVideoNode: GroupVideoNode?
        
    private let backgroundNode: ASDisplayNode
    private let topFadeNode: ASDisplayNode
    private let bottomFadeNode: ASDisplayNode
    private let bottomGradientNode: ASDisplayNode
    private let bottomFillNode: ASDisplayNode
    private let headerNode: ASDisplayNode
    private let backButtonNode: HighlightableButtonNode
    private let backButtonArrowNode: ASImageNode
    private let pinButtonNode: VoiceChatPinButtonNode
    private let audioLevelNode: VoiceChatBlobNode
    private let audioLevelDisposable = MetaDisposable()
    private let speakingPeerDisposable = MetaDisposable()
    private let speakingAudioLevelDisposable = MetaDisposable()
    private var backdropAvatarNode: ImageNode
    private var avatarNode: ImageNode
    private let titleNode: ImmediateTextNode
    private let microphoneNode: VoiceChatMicrophoneNode
    private let placeholderTextNode: ImmediateTextNode
    private let placeholderIconNode: ASImageNode
    private let placeholderButton: HighlightTrackingButtonNode
    private var placeholderButtonEffectView: UIVisualEffectView?
    private let placeholderButtonHighlightNode: ASDisplayNode
    private let placeholderButtonTextNode: ImmediateTextNode
    
    private let speakingContainerNode: ASDisplayNode
    private var speakingEffectView: UIVisualEffectView?
    private let speakingAvatarNode: AvatarNode
    private let speakingTitleNode: ImmediateTextNode
    private var speakingAudioLevelView: VoiceBlobView?
    
    private var validLayout: (CGSize, CGFloat, CGFloat, Bool, Bool)?
    
    var tapped: (() -> Void)?
    var back: (() -> Void)?
    var togglePin: (() -> Void)?
    var switchTo: ((PeerId) -> Void)?
    var stopScreencast: (() -> Void)?
    
    var controlsHidden: ((Bool) -> Void)?
    
    var getAudioLevel: ((PeerId) -> Signal<Float, NoError>)?
    var getVideo: ((String, Bool, @escaping (GroupVideoNode?) -> Void) -> Void)?
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

            let stepCount = 10
            var colors: [CGColor] = []
            var locations: [CGFloat] = []

            for i in 0 ... stepCount {
                let t = CGFloat(i) / CGFloat(stepCount)
                colors.append(fadeColor.withAlphaComponent(t * t).cgColor)
                locations.append(t)
            }

            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colors as CFArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }) {
            self.topFadeNode.backgroundColor = UIColor(patternImage: image)
        }
        
        self.bottomFadeNode = ASDisplayNode()
        
        self.bottomGradientNode = ASDisplayNode()
        self.bottomGradientNode.displaysAsynchronously = false
        if let image = generateImage(CGSize(width: fadeHeight, height: fadeHeight), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            
            let colorsArray = [fadeColor.withAlphaComponent(0.0).cgColor, fadeColor.cgColor] as CFArray
            var locations: [CGFloat] = [1.0, 0.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!

            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }) {
            self.bottomGradientNode.backgroundColor = UIColor(patternImage: image)
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
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.pinButtonNode = VoiceChatPinButtonNode(presentationData: presentationData)
        
        self.backdropAvatarNode = ImageNode()
        self.backdropAvatarNode.contentMode = .scaleAspectFill
        self.backdropAvatarNode.displaysAsynchronously = false
        
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
        
        self.placeholderTextNode = ImmediateTextNode()
        self.placeholderTextNode.alpha = 0.0
        self.placeholderTextNode.maximumNumberOfLines = 2
        self.placeholderTextNode.textAlignment = .center
        
        self.placeholderIconNode = ASImageNode()
        self.placeholderIconNode.alpha = 0.0
        self.placeholderIconNode.contentMode = .scaleAspectFit
        self.placeholderIconNode.displaysAsynchronously = false
        
        self.placeholderButton = HighlightTrackingButtonNode()
        self.placeholderButton.alpha = 0.0
        self.placeholderButton.clipsToBounds = true
        self.placeholderButton.cornerRadius = backgroundCornerRadius
            
        self.placeholderButtonHighlightNode = ASDisplayNode()
        self.placeholderButtonHighlightNode.alpha = 0.0
        self.placeholderButtonHighlightNode.backgroundColor = UIColor(white: 1.0, alpha: 0.4)
        self.placeholderButtonHighlightNode.isUserInteractionEnabled = false
             
        self.placeholderButtonTextNode = ImmediateTextNode()
        self.placeholderButtonTextNode.attributedText = NSAttributedString(string: presentationData.strings.VoiceChat_StopScreenSharingShort, font: Font.semibold(17.0), textColor: .white)
        self.placeholderButtonTextNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = backgroundCornerRadius
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.backdropAvatarNode)
        self.addSubnode(self.topFadeNode)
        self.addSubnode(self.bottomFadeNode)
        self.bottomFadeNode.addSubnode(self.bottomGradientNode)
        self.bottomFadeNode.addSubnode(self.bottomFillNode)
        self.addSubnode(self.audioLevelNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.microphoneNode)
        self.addSubnode(self.headerNode)
        self.headerNode.addSubnode(self.backButtonNode)
        self.headerNode.addSubnode(self.backButtonArrowNode)
        self.headerNode.addSubnode(self.pinButtonNode)
        
        self.addSubnode(self.placeholderIconNode)
        self.addSubnode(self.placeholderTextNode)
        
        self.addSubnode(self.placeholderButton)
        self.placeholderButton.addSubnode(self.placeholderButtonHighlightNode)
        self.placeholderButton.addSubnode(self.placeholderButtonTextNode)
        self.placeholderButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.placeholderButtonHighlightNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.placeholderButtonHighlightNode.alpha = 1.0
                } else {
                    strongSelf.placeholderButtonHighlightNode.alpha = 0.0
                    strongSelf.placeholderButtonHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        self.placeholderButton.addTarget(self, action: #selector(self.stopSharingPressed), forControlEvents: .touchUpInside)
        
        self.addSubnode(self.speakingContainerNode)
        self.speakingContainerNode.addSubnode(self.speakingAvatarNode)
        self.speakingContainerNode.addSubnode(self.speakingTitleNode)

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
        
        self.topFadeNode.view.layer.rasterizationScale = UIScreen.main.scale
        self.topFadeNode.view.layer.shouldRasterize = true
        self.bottomFadeNode.view.layer.rasterizationScale = UIScreen.main.scale
        self.bottomFadeNode.view.layer.shouldRasterize = true
        
        let speakingEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        speakingEffectView.layer.cornerRadius = 19.0
        speakingEffectView.clipsToBounds = true
        if #available(iOS 13.0, *) {
            speakingEffectView.layer.cornerCurve = .continuous
        }
        self.speakingContainerNode.view.insertSubview(speakingEffectView, at: 0)
        self.speakingEffectView = speakingEffectView
        
        let placeholderButtonEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        placeholderButtonEffectView.isUserInteractionEnabled = false
        self.placeholderButton.view.insertSubview(placeholderButtonEffectView, at: 0)
        self.placeholderButtonEffectView = placeholderButtonEffectView
        
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
    
    @objc private func stopSharingPressed() {
        self.stopScreencast?()
    }
    
    var visibility = true {
        didSet {
            if let videoNode = self.currentVideoNode, videoNode.supernode === self {
                videoNode.updateIsEnabled(self.visibility)
            }
        }
    }
    
    var animating: Bool {
        return self.animatingIn || self.animatingOut
    }
    
    private var animatingIn = false
    private var animatingOut = false
    private var appeared = false
    
    func animateTransitionIn(from sourceNode: ASDisplayNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        guard let sourceNode = sourceNode as? VoiceChatTileItemNode, let _ = sourceNode.item, let (_, sideInset, bottomInset, isLandscape, isTablet) = self.validLayout else {
            return
        }
        self.appeared = true
        
        self.backgroundNode.alpha = 0.0
        self.topFadeNode.alpha = 0.0
        self.titleNode.alpha = 0.0
        self.microphoneNode.alpha = 0.0
        self.headerNode.alpha = 0.0
        
        let hasPlaceholder = !self.placeholderIconNode.alpha.isZero
                
        let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
        alphaTransition.updateAlpha(node: self.backgroundNode, alpha: 1.0)
        alphaTransition.updateAlpha(node: self.topFadeNode, alpha: 1.0)
        alphaTransition.updateAlpha(node: self.titleNode, alpha: 1.0)
        alphaTransition.updateAlpha(node: self.microphoneNode, alpha: 1.0)
        alphaTransition.updateAlpha(node: self.headerNode, alpha: 1.0)
        if hasPlaceholder {
            self.placeholderIconNode.alpha = 0.0
            self.placeholderTextNode.alpha = 0.0
            alphaTransition.updateAlpha(node: self.placeholderTextNode, alpha: 1.0)
            
            if !self.placeholderButton.alpha.isZero {
                self.placeholderButton.alpha = 0.0
                alphaTransition.updateAlpha(node: self.placeholderButton, alpha: 1.0)
            }
        }
        
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
        self.update(size: startLocalFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, force: true, transition: .immediate)
        self.frame = startLocalFrame
        self.update(size: targetFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, force: true, transition: transition)
        transition.updateFrame(node: self, frame: targetFrame, completion: { [weak self] _ in
            sourceNode.alpha = 1.0
            self?.animatingIn = false
            completion()
        })
        
        if hasPlaceholder, let iconSnapshotView = sourceNode.placeholderIconNode.view.snapshotView(afterScreenUpdates: false), let textSnapshotView = sourceNode.placeholderTextNode.view.snapshotView(afterScreenUpdates: false) {
            iconSnapshotView.frame = sourceNode.placeholderIconNode.frame
            self.view.addSubview(iconSnapshotView)
            textSnapshotView.frame = sourceNode.placeholderTextNode.frame
            self.view.addSubview(textSnapshotView)
            transition.updatePosition(layer: iconSnapshotView.layer, position: self.placeholderIconNode.position, completion: { [weak self, weak iconSnapshotView] _ in
                iconSnapshotView?.removeFromSuperview()
                self?.placeholderIconNode.alpha = 1.0
            })
            transition.updateTransformScale(layer: iconSnapshotView.layer, scale: 2.0)
            textSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak textSnapshotView] _ in
                textSnapshotView?.removeFromSuperview()
            })
            let textPosition =  self.placeholderTextNode.position
            self.placeholderTextNode.position = textSnapshotView.center
            transition.updatePosition(layer: textSnapshotView.layer, position: textPosition)
            transition.updatePosition(node: self.placeholderTextNode, position: textPosition)
        }
    }
    
    func animateTransitionOut(to targetNode: ASDisplayNode?, offset: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        guard let (_, sideInset, bottomInset, isLandscape, isTablet) = self.validLayout else {
            return
        }
        
        self.appeared = false
        
        let hasPlaceholder = !self.placeholderIconNode.alpha.isZero
                
        let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
        if offset.isZero {
            alphaTransition.updateAlpha(node: self.backgroundNode, alpha: 0.0)
        } else {
            self.backgroundNode.alpha = 0.0
            
            self.microphoneNode.alpha = 1.0
            self.titleNode.alpha = 1.0
            self.bottomFadeNode.alpha = 1.0
        }
        alphaTransition.updateAlpha(node: self.topFadeNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.titleNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.microphoneNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.headerNode, alpha: 0.0)
        alphaTransition.updateAlpha(node: self.bottomFadeNode, alpha: 1.0)
        if hasPlaceholder {
            alphaTransition.updateAlpha(node: self.placeholderTextNode, alpha: 0.0)
            if !self.placeholderButton.alpha.isZero {
                self.placeholderButton.alpha = 0.0
                self.placeholderButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            }
        }
        
        let originalFrame = self.frame
        let initialFrame = originalFrame.offsetBy(dx: 0.0, dy: offset)
        guard let targetNode = targetNode as? VoiceChatTileItemNode, let _ = targetNode.item else {
            guard let supernode = self.supernode else {
                completion()
                return
            }
            self.animatingOut = true
            self.frame = initialFrame
            if offset < 0.0 {
                let targetFrame = CGRect(origin: CGPoint(x: 0.0, y: -originalFrame.size.height), size: originalFrame.size)
                transition.updateFrame(node: self, frame: targetFrame, completion: { [weak self] _ in
                    self?.frame = originalFrame
                    completion()
                    self?.animatingOut = false
                })
            } else {
                let targetFrame = CGRect(origin: CGPoint(x: 0.0, y: supernode.frame.height), size: originalFrame.size)
                transition.updateFrame(node: self, frame: targetFrame, completion: { [weak self] _ in
                    self?.frame = originalFrame
                    completion()
                    self?.animatingOut = false
                })
            }
            return
        }
        
        targetNode.isHidden = false
        if offset.isZero {
            targetNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        }
                
        self.animatingOut = true
        let targetFrame = targetNode.view.convert(targetNode.bounds, to: self.supernode?.view)
        
        let currentVideoNode = self.currentVideoNode
        
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
        
        let textPosition = self.placeholderTextNode.position
        var textTargetPosition = textPosition
        var textView: UIView?
        if hasPlaceholder, let iconSnapshotView = targetNode.placeholderIconNode.view.snapshotView(afterScreenUpdates: false), let textSnapshotView = targetNode.placeholderTextNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.addSubview(iconSnapshotView)
            self.view.addSubview(textSnapshotView)
            iconSnapshotView.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            iconSnapshotView.center = self.placeholderIconNode.position
            textSnapshotView.center = textPosition
            textTargetPosition = targetNode.placeholderTextNode.position
            
            self.placeholderIconNode.alpha = 0.0
            transition.updatePosition(layer: iconSnapshotView.layer, position: targetNode.placeholderIconNode.position, completion: { [weak self, weak iconSnapshotView] _ in
                iconSnapshotView?.removeFromSuperview()
                self?.placeholderIconNode.alpha = 1.0
            })
            transition.updateTransformScale(layer: iconSnapshotView.layer, scale: 1.0)
            
            textView = textSnapshotView
            textSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, removeOnCompletion: false)
        }
        
        self.update(size: targetFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, force: true, transition: transition)
        transition.updateFrame(node: self, frame: targetFrame, completion: { [weak self] _ in
            if let strongSelf = self {
                completion()
                
                infoView?.removeFromSuperview()
                textView?.removeFromSuperview()
                currentVideoNode?.isMainstageExclusive = false
                targetNode.transitionIn(from: nil)
                targetNode.alpha = 1.0
                targetNode.highlightNode.layer.animateAlpha(from: 0.0, to: targetNode.highlightNode.alpha, duration: 0.2)
                strongSelf.animatingOut = false
                strongSelf.frame = originalFrame
                strongSelf.update(size: initialFrame.size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, transition: .immediate)
            }
        })
        
        if hasPlaceholder {
            self.placeholderTextNode.position = textPosition
            if let textSnapshotView = textView {
                transition.updatePosition(layer: textSnapshotView.layer, position: textTargetPosition)
            }
            transition.updatePosition(node: self.placeholderTextNode, position: textTargetPosition)
        }
        
        self.update(speakingPeerId: nil)
    }
    
    private var effectiveSpeakingPeerId: PeerId?
    private func updateSpeakingPeer() {
        guard let (_, _, _, _, isTablet) = self.validLayout else {
            return
        }
        var effectiveSpeakingPeerId = self.speakingPeerId
        if let peerId = effectiveSpeakingPeerId, self.currentPeer?.0 == peerId || self.callState?.myPeerId == peerId || isTablet {
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
                    strongSelf.speakingAvatarNode.setPeer(context: strongSelf.context, theme: presentationData.theme, peer: EnginePeer(peer))
                
                let bodyAttributes = MarkdownAttributeSet(font: Font.regular(15.0), textColor: .white, additionalAttributes: [:])
                let boldAttributes = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: .white, additionalAttributes: [:])
                let attributedText = addAttributesToStringWithRanges(presentationData.strings.VoiceChat_ParticipantIsSpeaking(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                strongSelf.speakingTitleNode.attributedText = attributedText

                strongSelf.speakingContainerNode.alpha = 0.0
                
                if let (size, sideInset, bottomInset, isLandscape, isTablet) = strongSelf.validLayout {
                    strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, transition: .immediate)
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
            self.backdropAvatarNode.setSignal(peerAvatarCompleteImage(account: self.context.account, peer: EnginePeer(peer), size: CGSize(width: 240.0, height: 240.0), round: false, font: avatarPlaceholderFont(size: 78.0), drawLetters: false, blurred: true))
            self.avatarNode.setSignal(peerAvatarCompleteImage(account: self.context.account, peer: EnginePeer(peer), size: CGSize(width: 180.0, height: 180.0), font: avatarPlaceholderFont(size: 78.0), fullSize: true))
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
        var titleAttributedString = NSAttributedString(string: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.semibold(15.0), textColor: .white)
        if mutedForYou {
            microphoneColor = destructiveColor
            
            let updatedString = NSMutableAttributedString(attributedString: titleAttributedString)
            updatedString.append(NSAttributedString(string: " \(presentationData.strings.VoiceChat_StatusMutedForYou)", font: Font.regular(15.0), textColor: UIColor.white))
            titleAttributedString = updatedString
        }
        self.titleNode.attributedText = titleAttributedString
        if let (size, sideInset, bottomInset, isLandscape, isTablet) = self.validLayout {
            self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, transition: .immediate)
        }
        
        self.pinButtonNode.update(pinned: pinned, animated: true)
        
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
        self.topFadeNode.isHidden = !hidden
        self.bottomFadeNode.isHidden = !hidden
        self.avatarNode.isHidden = hidden
        self.audioLevelNode.isHidden = hidden
    }
    
    func update(peer: (peer: PeerId, endpointId: String?, isMyPeer: Bool, isPresentation: Bool, isPaused: Bool)?, isReady: Bool = true, waitForFullSize: Bool, completion: (() -> Void)? = nil) {
        let previousPeer = self.currentPeer
        if previousPeer?.0 == peer?.0 && previousPeer?.1 == peer?.1 && previousPeer?.2 == peer?.2 && previousPeer?.3 == peer?.3 && previousPeer?.4 == peer?.4 {
            completion?()
            return
        }
        self.currentPeer = peer
       
        self.updateSpeakingPeer()
        
        var isTablet = false
        if let (_, _, _, _, isTabletValue) = self.validLayout {
            isTablet = isTabletValue
        }
        
        if let (_, endpointId, isMyPeer, isPresentation, isPaused) = peer {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            var showPlaceholder = false
            if isMyPeer && isPresentation {
                self.placeholderTextNode.attributedText = NSAttributedString(string: presentationData.strings.VoiceChat_YouAreSharingScreen, font: Font.semibold(15.0), textColor: .white)
                self.placeholderIconNode.image = generateTintedImage(image: UIImage(bundleImageName: isTablet ? "Call/ScreenShareTablet" : "Call/ScreenSharePhone"), color: .white)
                showPlaceholder = true
            } else if isPaused {
                self.placeholderTextNode.attributedText = NSAttributedString(string: presentationData.strings.VoiceChat_VideoPaused, font: Font.semibold(14.0), textColor: .white)
                self.placeholderIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/Pause"), color: .white)
                showPlaceholder = true
            }
            
            let updatePlaceholderVisibility = {
                let peerChanged = previousPeer?.0 != peer?.0
                let transition: ContainedViewLayoutTransition = self.appeared && !peerChanged ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
                transition.updateAlpha(node: self.placeholderTextNode, alpha: showPlaceholder ? 1.0 : 0.0)
                transition.updateAlpha(node: self.placeholderIconNode, alpha: showPlaceholder ? 1.0 : 0.0)
                transition.updateAlpha(node: self.placeholderButton, alpha: showPlaceholder && !isPaused ? 1.0 : 0.0)
            }
            
            if endpointId != previousPeer?.1 {
                updatePlaceholderVisibility()
                if let endpointId = endpointId {
                    var delayTransition = false
                    if previousPeer?.0 == peer?.0 && previousPeer?.1 == nil && self.appeared {
                        delayTransition = true
                    }                    
                    if !delayTransition {
                        self.setAvatarHidden(true)
                    }
                    
                    var waitForFullSize = waitForFullSize
                    if isMyPeer && !isPresentation && isReady && !self.appeared {
                        waitForFullSize = false
                    }
                    
                    self.getVideo?(endpointId, isMyPeer && !isPresentation, { [weak self] videoNode in
                        Queue.mainQueue().async {
                            guard let strongSelf = self, let videoNode = videoNode else {
                                return
                            }
                            
                            videoNode.isMainstageExclusive = isMyPeer && !isPresentation
                            if videoNode.isMainstageExclusive {
                                videoNode.storeSnapshot()
                            }
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
                            videoNode.updateIsBlurred(isBlurred: isPaused, light: true, animated: false)
                            videoNode.isUserInteractionEnabled = true
                            let previousVideoNode = strongSelf.currentVideoNode
                            var previousVideoNodeSnapshot: UIView?
                            if let previousVideoNode = previousVideoNode, previousVideoNode.isMainstageExclusive, let snapshotView = previousVideoNode.view.snapshotView(afterScreenUpdates: false) {
                                previousVideoNodeSnapshot = snapshotView
                                snapshotView.frame = previousVideoNode.frame
                                previousVideoNode.view.superview?.insertSubview(snapshotView, aboveSubview: previousVideoNode.view)
                            }
                            strongSelf.currentVideoNode = videoNode
                            strongSelf.insertSubnode(videoNode, aboveSubnode: strongSelf.backdropAvatarNode)

                            if delayTransition {
                                videoNode.alpha = 0.0
                            } else if !isReady {
                                videoNode.alpha = 0.0
                                strongSelf.topFadeNode.isHidden = true
                                strongSelf.bottomFadeNode.isHidden = true
                            } else if isMyPeer {
                                videoNode.layer.removeAnimation(forKey: "opacity")
                                videoNode.alpha = 1.0
                            }
                            if waitForFullSize {
                                previousVideoNode?.isMainstageExclusive = false
                                Queue.mainQueue().after(2.0) {
                                    previousVideoNodeSnapshot?.removeFromSuperview()
                                    if let previousVideoNode = previousVideoNode, previousVideoNode.supernode === strongSelf && !previousVideoNode.isMainstageExclusive {
                                        previousVideoNode.removeFromSupernode()
                                    }
                                }
                                strongSelf.videoReadyDisposable.set((videoNode.ready
                                |> filter { $0 }
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] _ in
                                    Queue.mainQueue().after(0.1) {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        
                                        if let (size, sideInset, bottomInset, isLandscape, isTablet) = strongSelf.validLayout {
                                            strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, transition: .immediate)
                                        }
                                        
                                        Queue.mainQueue().after(0.02) {
                                            completion?()
                                        }
                                        
                                        if videoNode.alpha.isZero {
                                            if delayTransition {
                                                strongSelf.topFadeNode.isHidden = false
                                                strongSelf.bottomFadeNode.isHidden = false
                                                strongSelf.topFadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                                strongSelf.bottomFadeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                                                strongSelf.avatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                                                strongSelf.audioLevelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                                            }
                                            if let videoNode = strongSelf.currentVideoNode {
                                                videoNode.alpha = 1.0
                                                videoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, completion: { [weak self] _ in
                                                    if let strongSelf = self {
                                                        strongSelf.setAvatarHidden(true)
                                                        strongSelf.avatarNode.layer.removeAllAnimations()
                                                        strongSelf.audioLevelNode.layer.removeAllAnimations()
                                                        previousVideoNodeSnapshot?.removeFromSuperview()
                                                        if let previousVideoNode = previousVideoNode, previousVideoNode.supernode === strongSelf {
                                                            previousVideoNode.removeFromSupernode()
                                                        }
                                                    }
                                                })
                                            }
                                        } else {
                                            previousVideoNodeSnapshot?.removeFromSuperview()
                                            previousVideoNode?.isMainstageExclusive = false
                                            Queue.mainQueue().after(0.07) {
                                                if let previousVideoNode = previousVideoNode, previousVideoNode.supernode === strongSelf {
                                                    previousVideoNode.removeFromSupernode()
                                                }
                                            }
                                        }
                                    }
                                }))
                            } else {
                                if let (size, sideInset, bottomInset, isLandscape, isTablet) = strongSelf.validLayout {
                                    strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, transition: .immediate)
                                }
                                if let previousVideoNode = previousVideoNode {
                                    previousVideoNodeSnapshot?.removeFromSuperview()
                                    previousVideoNode.isMainstageExclusive = false
                                    if previousVideoNode.supernode === strongSelf {
                                        previousVideoNode.removeFromSupernode()
                                    }
                                }
                                strongSelf.videoReadyDisposable.set(nil)
                                completion?()
                            }
                        }
                    })
                } else {
                    if let currentVideoNode = self.currentVideoNode {
                        currentVideoNode.isMainstageExclusive = false
                        if currentVideoNode.supernode === self {
                            currentVideoNode.removeFromSupernode()
                        }
                        self.currentVideoNode = nil
                    }
                    self.setAvatarHidden(false)
                    completion?()
                }
            } else {
                self.setAvatarHidden(endpointId != nil)
                if waitForFullSize && !isReady && !isPaused, let videoNode = self.currentVideoNode {
                    self.videoReadyDisposable.set((videoNode.ready
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] _ in
                        Queue.mainQueue().after(0.1) {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let (size, sideInset, bottomInset, isLandscape, isTablet) = strongSelf.validLayout {
                                strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, isLandscape: isLandscape, isTablet: isTablet, transition: .immediate)
                            }
                            
                            Queue.mainQueue().after(0.02) {
                                completion?()
                            }
                            
                            updatePlaceholderVisibility()
                            if videoNode.alpha.isZero {
                                videoNode.updateIsBlurred(isBlurred: isPaused, light: true, animated: false)
                                strongSelf.topFadeNode.isHidden = true
                                strongSelf.bottomFadeNode.isHidden = true
                                if let videoNode = strongSelf.currentVideoNode {
                                    videoNode.alpha = 1.0
                                    videoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, completion: { [weak self] _ in
                                        if let strongSelf = self {
                                            strongSelf.setAvatarHidden(true)
                                        }
                                    })
                                }
                            }
                        }
                    }))
                } else {
                    updatePlaceholderVisibility()
                    self.currentVideoNode?.updateIsBlurred(isBlurred: isPaused, light: true, animated: true)
                    completion?()
                }
            }
        } else {
            self.videoReadyDisposable.set(nil)
            if let currentVideoNode = self.currentVideoNode {
                currentVideoNode.isMainstageExclusive = false
                if currentVideoNode.supernode === self {
                    currentVideoNode.removeFromSupernode()
                }
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
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, isLandscape: Bool, isTablet: Bool, force: Bool = false, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, sideInset, bottomInset, isLandscape, isTablet)
        
        if self.animating && !force {
            return
        }
        
        let initialBottomInset = bottomInset
        var bottomInset = bottomInset        
        let layoutMode: VideoNodeLayoutMode
        if case .immediate = transition, self.animatingIn {
            layoutMode = .fillOrFitToSquare
            bottomInset = 0.0
        } else if self.animatingOut {
            layoutMode = .fillOrFitToSquare
            bottomInset = 0.0
        } else {
            if let (_, _, _, isPresentation, _) = self.currentPeer, isPresentation {
                layoutMode = .fit
            } else {
                layoutMode = isLandscape ? .fillHorizontal : .fillVertical
            }
        }
        
        if let currentVideoNode = self.currentVideoNode {
            transition.updateFrame(node: currentVideoNode, frame: CGRect(origin: CGPoint(), size: size))
            currentVideoNode.updateLayout(size: size, layoutMode: layoutMode, transition: transition)
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.backdropAvatarNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let avatarSize = CGSize(width: 180.0, height: 180.0)
        let avatarFrame = CGRect(origin: CGPoint(x: (size.width - avatarSize.width) / 2.0, y: (size.height - avatarSize.height) / 2.0), size: avatarSize)
        transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
        transition.updateFrame(node: self.audioLevelNode, frame: avatarFrame.insetBy(dx: -60.0, dy: -60.0))
        
        let animationSize = CGSize(width: 36.0, height: 36.0)
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - sideInset * 2.0 - 24.0 - animationSize.width, height: size.height))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: sideInset + 12.0 + animationSize.width, y: size.height - bottomInset - titleSize.height - 16.0), size: titleSize))
        
        transition.updateFrame(node: self.microphoneNode, frame: CGRect(origin: CGPoint(x: sideInset + 7.0, y: size.height - bottomInset - animationSize.height - 6.0), size: animationSize))
        
        var totalFadeHeight: CGFloat = fadeHeight
        if size.height != tileHeight && size.width < size.height {
            totalFadeHeight += bottomInset
        }
        transition.updateFrame(node: self.bottomFadeNode, frame: CGRect(x: 0.0, y: size.height - totalFadeHeight, width: size.width, height: totalFadeHeight))
        transition.updateFrame(node: self.bottomGradientNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: fadeHeight))
        transition.updateFrame(node: self.bottomFillNode, frame: CGRect(x: 0.0, y: fadeHeight, width: size.width, height: max(0.0, totalFadeHeight - fadeHeight)))
        transition.updateFrame(node: self.topFadeNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: 50.0))
        
        let backSize = self.backButtonNode.measure(CGSize(width: 320.0, height: 100.0))
        if let image = self.backButtonArrowNode.image {
            transition.updateFrame(node: self.backButtonArrowNode, frame: CGRect(origin: CGPoint(x: sideInset + 8.0, y: 11.0), size: image.size))
        }
        transition.updateFrame(node: self.backButtonNode, frame: CGRect(origin: CGPoint(x: sideInset + 27.0, y: 12.0), size: backSize))
        
        let offset: CGFloat = sideInset.isZero ? 0.0 : initialBottomInset + 8.0
        let pinButtonSize = self.pinButtonNode.update(size: size, transition: transition)
        transition.updateFrame(node: self.pinButtonNode, frame: CGRect(origin: CGPoint(x: size.width - pinButtonSize.width - offset, y: 0.0), size: pinButtonSize))
        
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 64.0)))
        
        let speakingInset: CGFloat = 16.0
        let speakingAvatarSize = CGSize(width: 30.0, height: 30.0)
        let speakingTitleSize = self.speakingTitleNode.updateLayout(CGSize(width: size.width - 100.0, height: CGFloat.greatestFiniteMagnitude))
        let speakingContainerSize = CGSize(width: speakingTitleSize.width + speakingInset * 2.0 + speakingAvatarSize.width, height: 38.0)
        self.speakingEffectView?.frame = CGRect(origin: CGPoint(), size: speakingContainerSize)
        self.speakingAvatarNode.frame = CGRect(origin: CGPoint(x: 4.0, y: 4.0), size: speakingAvatarSize)
        self.speakingTitleNode.frame = CGRect(origin: CGPoint(x: 4.0 + speakingAvatarSize.width + 14.0, y: floorToScreenPixels((38.0 - speakingTitleSize.height) / 2.0)), size: speakingTitleSize)
        transition.updateFrame(node: self.speakingContainerNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - speakingContainerSize.width) / 2.0), y: 46.0), size: speakingContainerSize))
        
        let placeholderTextSize = self.placeholderTextNode.updateLayout(CGSize(width: size.width - 100.0, height: 100.0))
        transition.updateFrame(node: self.placeholderTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - placeholderTextSize.width) / 2.0), y: floorToScreenPixels(size.height / 2.0) + 10.0), size: placeholderTextSize))
        if let imageSize = self.placeholderIconNode.image?.size {
            transition.updateFrame(node: self.placeholderIconNode, frame: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floorToScreenPixels(size.height / 2.0) - imageSize.height - 8.0), size: imageSize))
        }
        
        let placeholderButtonTextSize = self.placeholderButtonTextNode.updateLayout(CGSize(width: 240.0, height: 100.0))
        let placeholderButtonSize = CGSize(width: placeholderButtonTextSize.width + 60.0, height: 52.0)
        transition.updateFrame(node: self.placeholderButton, frame: CGRect(origin: CGPoint(x: floor((size.width - placeholderButtonSize.width) / 2.0), y: floorToScreenPixels(size.height / 2.0) + 10.0 + placeholderTextSize.height + 30.0), size: placeholderButtonSize))
        self.placeholderButtonEffectView?.frame = CGRect(origin: CGPoint(), size: placeholderButtonSize)
        self.placeholderButtonHighlightNode.frame = CGRect(origin: CGPoint(), size: placeholderButtonSize)
        self.placeholderButtonTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((placeholderButtonSize.width - placeholderButtonTextSize.width) / 2.0), y: floorToScreenPixels((placeholderButtonSize.height - placeholderButtonTextSize.height) / 2.0)), size: placeholderButtonTextSize)
        
        if let imageSize = self.placeholderIconNode.image?.size {
            transition.updateFrame(node: self.placeholderIconNode, frame: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floorToScreenPixels(size.height / 2.0) - imageSize.height - 8.0), size: imageSize))
        }
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
