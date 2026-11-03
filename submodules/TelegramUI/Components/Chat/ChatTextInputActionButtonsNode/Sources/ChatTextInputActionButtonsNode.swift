import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ContextUI
import ChatPresentationInterfaceState
import ChatMessageBackground
import ChatControllerInteraction
import AccountContext
import ChatTextInputMediaRecordingButton
import ChatSendButtonRadialStatusNode
import ChatSendMessageActionUI
import ComponentFlow
import AnimatedCountLabelNode
import GlassBackgroundComponent
import ComponentDisplayAdapters
import StarsParticleEffect

private final class EffectBadgeView: UIView {
    private let context: AccountContext
    private var currentEffectId: Int64?
    
    private let backgroundView: UIImageView
    
    private var theme: PresentationTheme?
    
    private var effect: AvailableMessageEffects.MessageEffect?
    private var effectIcon: ComponentView<Empty>?
    
    private let effectDisposable = MetaDisposable()
    
    init(context: AccountContext) {
        self.context = context
        self.backgroundView = UIImageView()
        
        super.init(frame: CGRect())
        
        self.isUserInteractionEnabled = false
        
        self.addSubview(self.backgroundView)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        self.effectDisposable.dispose()
    }
    
    func update(size: CGSize, theme: PresentationTheme, effectId: Int64) {
        if self.theme !== theme {
            self.theme = theme
            self.backgroundView.image = generateFilledCircleImage(diameter: size.width, color: theme.list.plainBackgroundColor, strokeColor: nil, strokeWidth: nil, backgroundColor: nil)
            self.backgroundView.layer.shadowPath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(), size: size)).cgPath
            self.backgroundView.layer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.backgroundView.layer.shadowOpacity = 0.14
            self.backgroundView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
            self.backgroundView.layer.shadowRadius = 1.0
        }
        
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        
        if self.currentEffectId != effectId {
            self.currentEffectId = effectId
            
            let messageEffect = self.context.engine.stickers.availableMessageEffects()
            |> take(1)
            |> map { availableMessageEffects -> AvailableMessageEffects.MessageEffect? in
                guard let availableMessageEffects else {
                    return nil
                }
                for messageEffect in availableMessageEffects.messageEffects {
                    if messageEffect.id == effectId || messageEffect.effectSticker.fileId.id == effectId {
                        return messageEffect
                    }
                }
                return nil
            }
            
            self.effectDisposable.set((messageEffect |> deliverOnMainQueue).start(next: { [weak self] effect in
                guard let self, let effect else {
                    return
                }
                self.effect = effect
                self.updateIcon()
            }))
        }
    }
    
    private func updateIcon() {
        guard let effect else {
            return
        }
        
        let effectIcon: ComponentView<Empty>
        if let current = self.effectIcon {
            effectIcon = current
        } else {
            effectIcon = ComponentView()
            self.effectIcon = effectIcon
        }
        let effectIconContent: ChatSendMessageScreenEffectIcon.Content
        if let staticIcon = effect.staticIcon {
            effectIconContent = .file(staticIcon._parse())
        } else {
            effectIconContent = .text(effect.emoticon)
        }
        let effectIconSize = effectIcon.update(
            transition: .immediate,
            component: AnyComponent(ChatSendMessageScreenEffectIcon(
                context: self.context,
                content: effectIconContent
            )),
            environment: {},
            containerSize: CGSize(width: 8.0, height: 8.0)
        )
        
        let size = CGSize(width: 16.0, height: 16.0)
        if let effectIconView = effectIcon.view {
            if effectIconView.superview == nil {
                self.addSubview(effectIconView)
            }
            effectIconView.frame = CGRect(origin: CGPoint(x: floor((size.width - effectIconSize.width) * 0.5), y: floor((size.height - effectIconSize.height) * 0.5)), size: effectIconSize)
        }
    }
}

public final class ChatTextInputActionButtonsNode: ASDisplayNode, ChatSendMessageActionSheetControllerSourceSendButtonNode {
    private let context: AccountContext
    private let presentationContext: ChatPresentationContext?
    private let strings: PresentationStrings
    
    public let micButtonBackgroundView: GlassBackgroundView
    public let micButtonTintMaskView: UIImageView
    public let micButton: ChatTextInputMediaRecordingButton
    public let stopButtonIcon: GlassBackgroundView.ContentImageView
    public let stopButton: HighlightTrackingButton
    
    public let sendContainerNode: ASDisplayNode
    public let sendButtonBackgroundView: UIImageView
    private var sendButtonBackgroundImageDiameter: CGFloat?
    private var sendButtonBackgroundEffectLayer: StarsParticleEffectLayer?
    public let sendButton: HighlightTrackingButtonNode
    public var sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode?
    public var sendButtonHasApplyIcon = false
    public var animatingSendButton = false
    
    public let textNode: ImmediateAnimatedCountLabelNode
    
    public let expandMediaInputButton: HighlightTrackingButton
    public let expandMediaInputButtonBackgroundView: GlassBackgroundView
    private let expandMediaInputButtonIcon: GlassBackgroundView.ContentImageView
    
    private var effectBadgeView: EffectBadgeView?
    
    public var sendButtonLongPressed: ((ASDisplayNode, ContextGesture) -> Void)?
    
    private var gestureRecognizer: ContextGesture?
    public var sendButtonLongPressEnabled = false {
        didSet {
            self.gestureRecognizer?.isEnabled = self.sendButtonLongPressEnabled
        }
    }
    
    private var micButtonPointerInteraction: PointerInteraction?
    private var sendButtonPointerInteraction: PointerInteraction?
    
    let maskContentView: UIView
    
    private var validLayout: CGSize?
    
    public var customSendColor: UIColor?
    public var isSendDisabled: Bool = false
    
    private var slowmodeProgressTimestamp: (duration: Int32, timestamp: Int32)?
    private var slowmodeProgressTimer: Foundation.Timer?
    private var slowmodeProgressLayer: SimpleShapeLayer?
    
    public init(context: AccountContext, presentationInterfaceState: ChatPresentationInterfaceState, presentationContext: ChatPresentationContext?, presentController: @escaping (ViewController) -> Void) {
        self.context = context
        self.presentationContext = presentationContext
        let theme = presentationInterfaceState.theme
        let strings = presentationInterfaceState.strings
        self.strings = strings
        
        self.micButtonBackgroundView = GlassBackgroundView()
        self.maskContentView = UIView()
        
        self.micButtonTintMaskView = UIImageView()
        self.micButtonTintMaskView.tintColor = .black
        self.micButton = ChatTextInputMediaRecordingButton(context: context, theme: theme, pause: true, strings: strings, presentController: presentController)
        self.micButton.animationOutput = self.micButtonTintMaskView
        self.micButtonBackgroundView.maskContentView.addSubview(self.micButtonTintMaskView)
        
        self.stopButtonIcon = GlassBackgroundView.ContentImageView()
        self.micButtonBackgroundView.contentView.addSubview(self.stopButtonIcon)
        self.stopButtonIcon.alpha = 0.0

        // Hidden rather than alpha-driven: this is the hit-test gate, and it must be closed
        // whenever Stop is not on screen, independent of the icon's cross-fade.
        self.stopButton = HighlightTrackingButton()
        self.micButtonBackgroundView.contentView.addSubview(self.stopButton)
        self.stopButton.isHidden = true
        
        self.sendContainerNode = ASDisplayNode()
        self.sendContainerNode.layer.allowsGroupOpacity = true
        
        self.sendButtonBackgroundView = UIImageView()
        // The image is (re)generated in `updateLayout` for the frame's `min(width, height)`, so the capsule's
        // radius is always half its shorter side rather than a baked-in constant.
        self.sendButton = HighlightTrackingButtonNode(pointerStyle: nil)
        
        self.textNode = ImmediateAnimatedCountLabelNode()
        self.textNode.isUserInteractionEnabled = false
        
        self.expandMediaInputButton = HighlightTrackingButton()
        self.expandMediaInputButtonBackgroundView = GlassBackgroundView()
        self.expandMediaInputButtonIcon = GlassBackgroundView.ContentImageView()
        self.expandMediaInputButtonBackgroundView.contentView.addSubview(self.expandMediaInputButtonIcon)
        self.expandMediaInputButtonBackgroundView.contentView.addSubview(self.expandMediaInputButton)
        self.expandMediaInputButtonIcon.image = PresentationResourcesChat.chatInputPanelExpandButtonImage(presentationInterfaceState.theme)
        self.expandMediaInputButtonIcon.tintColor = theme.chat.inputPanel.panelControlColor
        self.expandMediaInputButtonIcon.setMonochromaticEffect(tintColor: theme.chat.inputPanel.panelControlColor)
        
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button, .notEnabled]
        
        self.sendButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if !strongSelf.sendButtonLongPressEnabled {
                    if highlighted {
                        strongSelf.sendContainerNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.sendContainerNode.alpha = 0.4
                    } else {
                        strongSelf.sendContainerNode.alpha = 1.0
                        strongSelf.sendContainerNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                } else {
                    if highlighted {
                        strongSelf.sendContainerNode.layer.animateScale(from: 1.0, to: 0.75, duration: 0.4, removeOnCompletion: false)
                    } else if let presentationLayer = strongSelf.sendContainerNode.layer.presentation() {
                        strongSelf.sendContainerNode.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                    }
                }
            }
        }
        
        self.micButton.layer.allowsGroupOpacity = true
        self.view.addSubview(self.micButtonBackgroundView)
        self.micButtonBackgroundView.contentView.addSubview(self.micButton)
            
        self.addSubnode(self.sendContainerNode)
        self.sendContainerNode.view.addSubview(self.sendButtonBackgroundView)
        self.sendContainerNode.addSubnode(self.sendButton)
        self.sendContainerNode.addSubnode(self.textNode)
        self.view.addSubview(self.expandMediaInputButtonBackgroundView)
        
        self.expandMediaInputButton.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.expandMediaInputButton.layer.animateScale(from: 1.0, to: 0.75, duration: 0.4, removeOnCompletion: false)
            } else if let presentationLayer = self.expandMediaInputButton.layer.presentation() {
                self.expandMediaInputButton.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
            }
        }
    }
    
    deinit {
        self.slowmodeProgressTimer?.invalidate()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = ContextGesture(target: nil, action: nil)
        self.gestureRecognizer = gestureRecognizer
        self.sendButton.view.addGestureRecognizer(gestureRecognizer)
        gestureRecognizer.activated = { [weak self] recognizer, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.sendButtonLongPressed?(strongSelf, recognizer)
        }
        
        self.micButtonPointerInteraction = PointerInteraction(view: self.micButton, style: .circle(36.0))
        self.sendButtonPointerInteraction = PointerInteraction(view: self.sendButton.view, customInteractionView: self.sendButtonBackgroundView, style: .lift)
    }
    
    public func updateTheme(theme: PresentationTheme, wallpaper: TelegramWallpaper) {
        self.micButton.updateTheme(theme: theme)
        self.expandMediaInputButtonIcon.tintColor = theme.chat.inputPanel.panelControlColor
        self.expandMediaInputButtonIcon.setMonochromaticEffect(tintColor: theme.chat.inputPanel.panelControlColor)
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        let previousContaierSize = self.absoluteRect?.1
        self.absoluteRect = (rect, containerSize)
        
        if let previousContaierSize, previousContaierSize != containerSize {
            Queue.mainQueue().after(0.2) {
                self.micButton.reset()
            }
        }
    }
    
    public func updateLayout(size: CGSize, isMediaInputExpanded: Bool, showTitle: Bool, currentMessageEffectId: Int64?, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGSize {
        self.validLayout = size
        
        var innerSize = size
        innerSize.width = 40.0 + 3.0 * 2.0
        
        let defaultGlassTintColor: GlassBackgroundView.TintColor
        if case .clear = interfaceState.preferredGlassType {
            defaultGlassTintColor = .init(kind: .clear)
        } else {
            defaultGlassTintColor = .init(kind: .panel)
        }
        
        var starsAmount: Int64?
        if let sendPaidMessageStars = interfaceState.sendPaidMessageStars, interfaceState.interfaceState.editMessage == nil {
            var amount: Int64
            if let forwardedCount = interfaceState.interfaceState.forwardMessageIds?.count, forwardedCount > 0 {
                amount = sendPaidMessageStars.value * Int64(forwardedCount)
                if !interfaceState.interfaceState.effectiveInputState.isEmpty {
                    amount += sendPaidMessageStars.value
                }
            } else {
                if interfaceState.interfaceState.effectiveInputState.inputText.length > 4096 {
                    let messageCount = Int32(ceil(CGFloat(interfaceState.interfaceState.effectiveInputState.inputText.length) / 4096.0))
                    amount = sendPaidMessageStars.value * Int64(messageCount)
                } else {
                    amount = sendPaidMessageStars.value
                }
            }
            starsAmount = amount
        }
        
        if let amount = starsAmount {
            self.sendButton.imageNode.alpha = 0.0
            self.textNode.isHidden = false
            let text = "\(amount)"
            let font = Font.with(size: 17.0, design: .round, weight: .semibold, traits: .monospacedNumbers)
            let badgeString = NSMutableAttributedString(string: "⭐️ ", font: font, textColor: interfaceState.theme.chat.inputPanel.actionControlForegroundColor)
            if let range = badgeString.string.range(of: "⭐️") {
                badgeString.addAttribute(.attachment, value: PresentationResourcesChat.chatPlaceholderStarIcon(interfaceState.theme)!, range: NSRange(range, in: badgeString.string))
                badgeString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: badgeString.string))
            }
            var segments: [AnimatedCountLabelNode.Segment] = []
            segments.append(.text(0, badgeString))
            for char in text {
                if let intValue = Int(String(char)) {
                    segments.append(.number(intValue, NSAttributedString(string: String(char), font: font, textColor: interfaceState.theme.chat.inputPanel.actionControlForegroundColor)))
                }
            }
            self.textNode.segments = segments
            
            let textSize = self.textNode.updateLayout(size: CGSize(width: 100.0, height: 100.0), animated: transition.isAnimated)
            let buttonInset: CGFloat = 14.0
            if showTitle {
                innerSize.width = textSize.width + buttonInset * 2.0
            }
            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: showTitle ? 5.0 + 7.0 : floorToScreenPixels((innerSize.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize))
        } else {
            self.textNode.isHidden = true
        }
    
        transition.updateFrame(view: self.micButtonBackgroundView, frame: CGRect(origin: CGPoint(), size: size))
        // While recording, the recording blob stands in for this button. On iOS 26 the circle is system glass, which
        // does not follow its view's alpha (the panel's fade-out leaves it on screen, under the translucent blob), so
        // it is dissolved through the glass itself.
        let isRecording = interfaceState.inputTextPanelState.mediaRecordingState != nil
        self.micButtonBackgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark:  interfaceState.theme.overallDarkAppearance, tintColor: defaultGlassTintColor, isInteractive: true, isVisible: !isRecording, transition: ComponentTransition(transition))
        
        transition.updatePosition(layer: self.micButton.layer, position: CGRect(origin: CGPoint(), size: size).center)
        transition.updateBounds(layer: self.micButton.layer, bounds: CGRect(origin: CGPoint(), size: size))
        self.micButton.layoutItems()
        
        if self.stopButtonIcon.image == nil {
            self.stopButtonIcon.image = generateImage(CGSize(width: 14.0, height: 14.0), rotatedContext: { size, context in
                UIGraphicsPushContext(context)
                defer {
                    UIGraphicsPopContext()
                }
                
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor.white.cgColor)
                
                UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 3.0).fill()
            })?.withRenderingMode(.alwaysTemplate)
        }
        if let image = self.stopButtonIcon.image {
            self.stopButtonIcon.tintColor = interfaceState.theme.chat.inputPanel.panelControlColor
            // This icon carries a scale transform: ChatTextInputPanelNode cross-fades it against the
            // mic button by scaling between 0.001 and 1.0. `frame` is a DERIVED property — UIKit
            // computes it from bounds, position, anchorPoint and transform — so writing it back while
            // the transform is non-identity makes UIKit solve for bounds instead, inflating them by
            // 1/scale. A 14pt icon written at scale 0.001 yields 14000pt bounds, which render as a
            // huge square once the scale animates back to 1.0, and each subsequent layout pass feeds
            // the inflated value back in. Drive the transform-independent properties directly, the
            // way micButton above does for exactly the same reason.
            let iconFrame = image.size.centered(in: CGRect(origin: CGPoint(), size: size))
            transition.updatePosition(layer: self.stopButtonIcon.layer, position: iconFrame.center)
            transition.updateBounds(layer: self.stopButtonIcon.layer, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
        }
        transition.updateFrame(view: self.stopButton, frame: CGRect(origin: CGPoint(), size: size))
        
        var sendSlowmodeTimerTimestamp: (duration: Int32, timestamp: Int32)?
        if let slowmodeState = interfaceState.slowmodeState {
            switch slowmodeState.variant {
            case .pendingMessages:
                break
            case let .timestamp(timeoutTimestamp):
                sendSlowmodeTimerTimestamp = (slowmodeState.timeout, timeoutTimestamp)
            }
        }
        
        let sendButtonBackgroundFrame = CGRect(origin: CGPoint(), size: innerSize).insetBy(dx: 3.0, dy: 3.0)
        // Corner radius = min(width, height) / 2: a true capsule whatever the frame. The stretchable image
        // must be generated at that diameter — a fixed one (it was 34) reads as a rounded rect the moment
        // the frame's shorter side differs from it.
        let sendButtonCornerDiameter = min(sendButtonBackgroundFrame.width, sendButtonBackgroundFrame.height)
        if self.sendButtonBackgroundImageDiameter != sendButtonCornerDiameter {
            self.sendButtonBackgroundImageDiameter = sendButtonCornerDiameter
            self.sendButtonBackgroundView.image = generateStretchableFilledCircleImage(diameter: sendButtonCornerDiameter, color: .white)?.withRenderingMode(.alwaysTemplate)
        }
        
        let slowmodeInset: CGFloat = 4.0
        
        self.slowmodeProgressTimestamp = sendSlowmodeTimerTimestamp
        if sendSlowmodeTimerTimestamp != nil {
            let slowmodeProgressLayer: SimpleShapeLayer
            var slowmodeProgressTransition = transition
            if let current = self.slowmodeProgressLayer {
                slowmodeProgressLayer = current
            } else {
                slowmodeProgressTransition = .immediate
                slowmodeProgressLayer = SimpleShapeLayer()
                self.slowmodeProgressLayer = slowmodeProgressLayer
                self.sendButtonBackgroundView.layer.superlayer?.insertSublayer(slowmodeProgressLayer, below: self.sendButtonBackgroundView.layer)
                
                slowmodeProgressLayer.fillColor = nil
                slowmodeProgressLayer.lineWidth = 2.0
                slowmodeProgressLayer.lineCap = .round
            }
            
            slowmodeProgressLayer.strokeColor = (self.customSendColor ?? interfaceState.theme.chat.inputPanel.panelControlAccentColor).cgColor
            
            if slowmodeProgressLayer.bounds.size != sendButtonBackgroundFrame.size {
                let pathFrame = CGRect(origin: CGPoint(), size: sendButtonBackgroundFrame.size).insetBy(dx: 2.0, dy: 2.0)
                slowmodeProgressLayer.path = UIBezierPath(roundedRect: pathFrame, cornerRadius: min(pathFrame.width, pathFrame.height) * 0.5).cgPath
            }
            slowmodeProgressTransition.updateFrame(layer: slowmodeProgressLayer, frame: sendButtonBackgroundFrame)
            
            if self.slowmodeProgressTimer == nil {
                self.slowmodeProgressTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateSlowmodeProgress()
                })
            }
            self.updateSlowmodeProgress()
        } else {
            if let slowmodeProgressLayer = self.slowmodeProgressLayer {
                self.slowmodeProgressLayer = nil
                slowmodeProgressLayer.removeFromSuperlayer()
            }
            if let slowmodeProgressTimer = self.slowmodeProgressTimer {
                self.slowmodeProgressTimer = nil
                slowmodeProgressTimer.invalidate()
            }
        }
        
        ComponentTransition(transition).setPosition(view: self.sendButtonBackgroundView, position: sendButtonBackgroundFrame.center)
        ComponentTransition(transition).setBounds(view: self.sendButtonBackgroundView, bounds: CGRect(origin: CGPoint(), size: sendButtonBackgroundFrame.size))
        var sendButtonBackgroundScale: CGFloat = 1.0
        if sendSlowmodeTimerTimestamp != nil, let image = self.sendButtonBackgroundView.image {
            sendButtonBackgroundScale = (image.size.height - slowmodeInset * 2.0) / image.size.height
        }
        transition.updateTransformScale(layer: self.sendButtonBackgroundView.layer, scale: sendButtonBackgroundScale)
        
        if self.isSendDisabled {
            transition.updateTintColor(view: self.sendButtonBackgroundView, color: interfaceState.theme.chat.inputPanel.panelControlAccentColor.withMultiplied(hue: 1.0, saturation: 0.0, brightness: 0.5).withMultipliedAlpha(0.25))
        } else {
            transition.updateTintColor(view: self.sendButtonBackgroundView, color: self.customSendColor ?? interfaceState.theme.chat.inputPanel.panelControlAccentColor)
        }
        
        if starsAmount == nil {
            if self.isSendDisabled {
                transition.updateAlpha(layer: self.sendButton.imageNode.layer, alpha: 0.4)
            } else {
                transition.updateAlpha(layer: self.sendButton.imageNode.layer, alpha: 1.0)
            }
        }
        
        if let _ = self.customSendColor {
            let sendButtonBackgroundEffectLayer: StarsParticleEffectLayer
            var sendButtonBackgroundEffectLayerTransition = transition
            if let current = self.sendButtonBackgroundEffectLayer {
                sendButtonBackgroundEffectLayer = current
            } else {
                sendButtonBackgroundEffectLayerTransition = .immediate
                sendButtonBackgroundEffectLayer = StarsParticleEffectLayer()
                self.sendButtonBackgroundEffectLayer = sendButtonBackgroundEffectLayer
                self.sendButtonBackgroundView.layer.addSublayer(sendButtonBackgroundEffectLayer)
                if transition.isAnimated {
                    sendButtonBackgroundEffectLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            transition.updateFrame(layer: sendButtonBackgroundEffectLayer, frame: CGRect(origin: CGPoint(), size: sendButtonBackgroundFrame.size))
            sendButtonBackgroundEffectLayer.update(color: UIColor(white: 1.0, alpha: 0.5), size: sendButtonBackgroundFrame.size, cornerRadius: sendButtonCornerDiameter * 0.5, transition: ComponentTransition(sendButtonBackgroundEffectLayerTransition))
        } else if let sendButtonBackgroundEffectLayer = self.sendButtonBackgroundEffectLayer {
            self.sendButtonBackgroundEffectLayer = nil
            transition.updateFrame(layer: sendButtonBackgroundEffectLayer, frame: CGRect(origin: CGPoint(), size: sendButtonBackgroundFrame.size))
            transition.updateAlpha(layer: sendButtonBackgroundEffectLayer, alpha: 0.0, completion: { [weak sendButtonBackgroundEffectLayer] _ in
                sendButtonBackgroundEffectLayer?.removeFromSuperlayer()
            })
        }
        
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(), size: innerSize))
        let sendContainerFrame = CGRect(origin: CGPoint(), size: innerSize)
        transition.updatePosition(node: self.sendContainerNode, position: sendContainerFrame.center)
        transition.updateBounds(node: self.sendContainerNode, bounds: CGRect(origin: CGPoint(), size: sendContainerFrame.size))
        
        let backgroundSize = CGSize(width: innerSize.width, height: 40.0)
        let backgroundFrame = CGRect(origin: CGPoint(x: showTitle ? 5.0 + UIScreenPixel : floorToScreenPixels((size.width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize)
        
        transition.updateFrame(view: self.expandMediaInputButton, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(view: self.expandMediaInputButtonBackgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.expandMediaInputButtonBackgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: interfaceState.theme.overallDarkAppearance, tintColor: defaultGlassTintColor, isInteractive: true, transition: ComponentTransition(transition))
        if let image = self.expandMediaInputButtonIcon.image {
            let expandIconFrame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) * 0.5), y: floor((size.height - image.size.height) * 0.5)), size: image.size)
            self.expandMediaInputButtonIcon.center = expandIconFrame.center
            self.expandMediaInputButtonIcon.bounds = CGRect(origin: CGPoint(), size: expandIconFrame.size)
            transition.updateTransformScale(layer: self.expandMediaInputButtonIcon.layer, scale: CGPoint(x: 1.0, y: isMediaInputExpanded ? 1.0 : -1.0))
        }
        
        if let currentMessageEffectId {
            let effectBadgeView: EffectBadgeView
            if let current = self.effectBadgeView {
                effectBadgeView = current
            } else {
                effectBadgeView = EffectBadgeView(context: self.context)
                self.effectBadgeView = effectBadgeView
                self.sendContainerNode.view.addSubview(effectBadgeView)
                
                effectBadgeView.alpha = 0.0
                transition.updateAlpha(layer: effectBadgeView.layer, alpha: 1.0)
            }
            let badgeSize = CGSize(width: 16.0, height: 16.0)
            effectBadgeView.frame = CGRect(origin: CGPoint(x: backgroundFrame.minX + backgroundSize.width + 3.0 - badgeSize.width, y: backgroundFrame.minY + backgroundSize.height + 3.0 - badgeSize.height), size: badgeSize)
            effectBadgeView.update(size: badgeSize, theme: interfaceState.theme, effectId: currentMessageEffectId)
        } else if let effectBadgeView = self.effectBadgeView {
            self.effectBadgeView = nil
            transition.updateAlpha(layer: effectBadgeView.layer, alpha: 0.0, completion: { [weak effectBadgeView] _ in
                effectBadgeView?.removeFromSuperview()
            })
        }
        
        return innerSize
    }
    
    private func updateSlowmodeProgress() {
        guard let slowmodeProgressLayer = self.slowmodeProgressLayer, let slowmodeProgressTimestamp = self.slowmodeProgressTimestamp else {
            return
        }
        
        let timestamp = Date().timeIntervalSince1970
        let timeout = max(0.0, Double(slowmodeProgressTimestamp.timestamp) - timestamp)
        let fraction = timeout / max(0.1, Double(slowmodeProgressTimestamp.duration))
        
        slowmodeProgressLayer.strokeEnd = CGFloat(fraction)
    }
    
    public func updateAccessibility() {
        self.accessibilityTraits = .button
        if !self.stopButtonIcon.alpha.isZero {
            self.accessibilityLabel = self.strings.VoiceOver_Chat_Stop
            self.accessibilityHint = nil
        } else if !self.micButton.alpha.isZero {
            switch self.micButton.mode {
                case .audio:
                    self.accessibilityLabel = self.strings.VoiceOver_Chat_RecordModeVoiceMessage
                    self.accessibilityHint = self.strings.VoiceOver_Chat_RecordModeVoiceMessageInfo
                case .video:
                    self.accessibilityLabel = self.strings.VoiceOver_Chat_RecordModeVideoMessage
                    self.accessibilityHint = self.strings.VoiceOver_Chat_RecordModeVideoMessageInfo
            }
        } else {
            self.accessibilityLabel = self.strings.MediaPicker_Send
            self.accessibilityHint = nil
        }
    }
    
    public func makeCustomContents() -> UIView? {
        if self.sendButtonHasApplyIcon || self.effectBadgeView != nil {
            let result = UIView()
            result.frame = self.bounds
            if let copyView = self.sendContainerNode.view.snapshotView(afterScreenUpdates: false) {
                copyView.frame = self.sendContainerNode.frame
                result.addSubview(copyView)
            }
            return result
        }
        return nil
    }
}
