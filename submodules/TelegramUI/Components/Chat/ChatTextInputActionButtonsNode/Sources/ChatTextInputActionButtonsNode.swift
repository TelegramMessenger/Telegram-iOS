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
    
    public let sendContainerNode: ASDisplayNode
    public let sendButtonBackgroundView: UIImageView
    public let sendButton: HighlightTrackingButtonNode
    public var sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode?
    public var sendButtonHasApplyIcon = false
    public var animatingSendButton = false
    
    public let textNode: ImmediateAnimatedCountLabelNode
    
    public let expandMediaInputButton: HighlightTrackingButton
    private let expandMediaInputButtonBackgroundView: GlassBackgroundView
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
        
        self.sendContainerNode = ASDisplayNode()
        self.sendContainerNode.layer.allowsGroupOpacity = true
        
        self.sendButtonBackgroundView = UIImageView()
        self.sendButtonBackgroundView.image = generateStretchableFilledCircleImage(diameter: 34.0, color: .white)?.withRenderingMode(.alwaysTemplate)
        self.sendButton = HighlightTrackingButtonNode(pointerStyle: nil)
        
        self.textNode = ImmediateAnimatedCountLabelNode()
        self.textNode.isUserInteractionEnabled = false
        
        self.expandMediaInputButton = HighlightTrackingButton()
        self.expandMediaInputButtonBackgroundView = GlassBackgroundView()
        self.expandMediaInputButtonBackgroundView.isUserInteractionEnabled = false
        self.expandMediaInputButton.addSubview(self.expandMediaInputButtonBackgroundView)
        self.expandMediaInputButtonIcon = GlassBackgroundView.ContentImageView()
        self.expandMediaInputButtonBackgroundView.contentView.addSubview(self.expandMediaInputButtonIcon)
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
        self.view.addSubview(self.micButton)
            
        self.addSubnode(self.sendContainerNode)
        self.sendContainerNode.view.addSubview(self.sendButtonBackgroundView)
        self.sendContainerNode.addSubnode(self.sendButton)
        self.sendContainerNode.addSubnode(self.textNode)
        self.view.addSubview(self.expandMediaInputButton)
        
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
        
        var starsAmount: Int64?
        if let sendPaidMessageStars = interfaceState.sendPaidMessageStars, interfaceState.interfaceState.editMessage == nil {
            var amount: Int64
            if let forwardedCount = interfaceState.interfaceState.forwardMessageIds?.count, forwardedCount > 0 {
                amount = sendPaidMessageStars.value * Int64(forwardedCount)
                if interfaceState.interfaceState.effectiveInputState.inputText.length > 0 {
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
            self.sendButton.imageNode.alpha = 1.0
            self.textNode.isHidden = true
        }
    
        transition.updateFrame(view: self.micButtonBackgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.micButtonBackgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark:  interfaceState.theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: interfaceState.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), transition: ComponentTransition(transition))
        
        transition.updateFrame(layer: self.micButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        self.micButton.layoutItems()
        
        transition.updateFrame(view: self.sendButtonBackgroundView, frame: CGRect(origin: CGPoint(), size: innerSize).insetBy(dx: 3.0, dy: 3.0))
        self.sendButtonBackgroundView.tintColor = interfaceState.theme.chat.inputPanel.panelControlAccentColor
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(), size: innerSize))
        let sendContainerFrame = CGRect(origin: CGPoint(), size: innerSize)
        transition.updatePosition(node: self.sendContainerNode, position: sendContainerFrame.center)
        transition.updateBounds(node: self.sendContainerNode, bounds: CGRect(origin: CGPoint(), size: sendContainerFrame.size))
        
        let backgroundSize = CGSize(width: innerSize.width, height: 40.0)
        let backgroundFrame = CGRect(origin: CGPoint(x: showTitle ? 5.0 + UIScreenPixel : floorToScreenPixels((size.width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize)
        
        transition.updateFrame(view: self.expandMediaInputButton, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(view: self.expandMediaInputButtonBackgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.expandMediaInputButtonBackgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: interfaceState.theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: interfaceState.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), transition: ComponentTransition(transition))
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
    
    public func updateAccessibility() {
        self.accessibilityTraits = .button
        if !self.micButton.alpha.isZero {
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
