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

final class ChatTextInputActionButtonsNode: ASDisplayNode, ChatSendMessageActionSheetControllerSourceSendButtonNode {
    private let context: AccountContext
    private let presentationContext: ChatPresentationContext?
    private let strings: PresentationStrings
    
    let micButton: ChatTextInputMediaRecordingButton
    let sendContainerNode: ASDisplayNode
    let backdropNode: ChatMessageBubbleBackdrop
    let backgroundNode: ASDisplayNode
    let sendButton: HighlightTrackingButtonNode
    var sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode?
    var sendButtonHasApplyIcon = false
    var animatingSendButton = false
    
    let textNode: ImmediateAnimatedCountLabelNode
    
    let expandMediaInputButton: HighlightableButtonNode
    private var effectBadgeView: EffectBadgeView?
    
    var sendButtonLongPressed: ((ASDisplayNode, ContextGesture) -> Void)?
    
    private var gestureRecognizer: ContextGesture?
    var sendButtonLongPressEnabled = false {
        didSet {
            self.gestureRecognizer?.isEnabled = self.sendButtonLongPressEnabled
        }
    }
    
    private var micButtonPointerInteraction: PointerInteraction?
    private var sendButtonPointerInteraction: PointerInteraction?
    
    private var validLayout: CGSize?
    
    init(context: AccountContext, presentationInterfaceState: ChatPresentationInterfaceState, presentationContext: ChatPresentationContext?, presentController: @escaping (ViewController) -> Void) {
        self.context = context
        self.presentationContext = presentationContext
        let theme = presentationInterfaceState.theme
        let strings = presentationInterfaceState.strings
        self.strings = strings
         
        self.micButton = ChatTextInputMediaRecordingButton(context: context, theme: theme, pause: true, strings: strings, presentController: presentController)
        
        self.sendContainerNode = ASDisplayNode()
        self.sendContainerNode.layer.allowsGroupOpacity = true
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.actionControlFillColor
        self.backgroundNode.clipsToBounds = true
        self.backdropNode = ChatMessageBubbleBackdrop()
        self.sendButton = HighlightTrackingButtonNode(pointerStyle: nil)
        
        self.textNode = ImmediateAnimatedCountLabelNode()
        self.textNode.isUserInteractionEnabled = false
        
        self.expandMediaInputButton = HighlightableButtonNode(pointerStyle: .circle(36.0))
        
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
        self.view.addSubview(self.micButton)
            
        self.addSubnode(self.sendContainerNode)
        self.sendContainerNode.addSubnode(self.backgroundNode)
        if let presentationContext = presentationContext {
            let graphics = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: presentationInterfaceState.chatWallpaper, bubbleCorners: presentationInterfaceState.bubbleCorners)
            self.backdropNode.setType(type: .outgoing(.None), theme: ChatPresentationThemeData(theme: theme, wallpaper: presentationInterfaceState.chatWallpaper), essentialGraphics: graphics, maskMode: true, backgroundNode: presentationContext.backgroundNode)
            self.backgroundNode.addSubnode(self.backdropNode)
        }
        self.sendContainerNode.addSubnode(self.sendButton)
        self.sendContainerNode.addSubnode(self.textNode)
        self.addSubnode(self.expandMediaInputButton)
    }
    
    override func didLoad() {
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
        self.sendButtonPointerInteraction = PointerInteraction(view: self.sendButton.view, customInteractionView: self.backgroundNode.view, style: .lift)
    }
    
    func updateTheme(theme: PresentationTheme, wallpaper: TelegramWallpaper) {
        self.micButton.updateTheme(theme: theme)
        self.expandMediaInputButton.setImage(PresentationResourcesChat.chatInputPanelExpandButtonImage(theme), for: [])
        
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.actionControlFillColor
        
        if [.day, .night].contains(theme.referenceTheme.baseTheme) && !theme.chat.message.outgoing.bubble.withWallpaper.hasSingleFillColor {
            self.backdropNode.isHidden = false
        } else {
            self.backdropNode.isHidden = true
        }
        
        let graphics = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: wallpaper, bubbleCorners: .init(mainRadius: 1, auxiliaryRadius: 1, mergeBubbleCorners: false))
        self.backdropNode.setType(type: .outgoing(.None), theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), essentialGraphics: graphics, maskMode: false, backgroundNode: self.presentationContext?.backgroundNode)
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        let previousContaierSize = self.absoluteRect?.1
        self.absoluteRect = (rect, containerSize)
        self.backdropNode.update(rect: rect, within: containerSize, transition: transition)
        
        if let previousContaierSize, previousContaierSize != containerSize {
            Queue.mainQueue().after(0.2) {
                self.micButton.reset()
            }
        }
    }
    
    func updateLayout(size: CGSize, isMediaInputExpanded: Bool, showTitle: Bool, currentMessageEffectId: Int64?, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGSize {
        self.validLayout = size
        
        var innerSize = size
        
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
    
        transition.updateFrame(layer: self.micButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        self.micButton.layoutItems()
        
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(), size: innerSize))
        transition.updateFrame(node: self.sendContainerNode, frame: CGRect(origin: CGPoint(), size: innerSize))
        
        let backgroundSize = CGSize(width: innerSize.width - 11.0, height: 33.0)
        let backgroundFrame = CGRect(origin: CGPoint(x: showTitle ? 5.0 + UIScreenPixel : floorToScreenPixels((size.width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        self.backgroundNode.cornerRadius = backgroundSize.height / 2.0
        
        transition.updateFrame(node: self.backdropNode, frame: CGRect(origin: CGPoint(x: -2.0, y: -2.0), size: CGSize(width: innerSize.width + 12.0, height: size.height + 2.0)))
        if let (rect, containerSize) = self.absoluteRect {
            self.backdropNode.update(rect: rect, within: containerSize)
        }
        
        transition.updateFrame(node: self.expandMediaInputButton, frame: CGRect(origin: CGPoint(), size: size))
        let expanded = isMediaInputExpanded
        transition.updateSublayerTransformScale(node: self.expandMediaInputButton, scale: CGPoint(x: 1.0, y: expanded ? 1.0 : -1.0))
        
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
    
    func updateAccessibility() {
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
    
    func makeCustomContents() -> UIView? {
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
