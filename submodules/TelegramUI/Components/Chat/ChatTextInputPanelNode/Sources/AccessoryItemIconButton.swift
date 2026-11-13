import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import GlassBackgroundComponent
import ComponentFlow
import LottieAnimationComponent
import LottieComponent

private let accessoryButtonFont = Font.medium(14.0)

private final class SupportTemplatesIconView: UIView {
    static let size = CGSize(width: 26.0, height: 26.0)
    
    private struct Line {
        let position: CGPoint
        let rotation: CGFloat
        let scale: CGFloat
        let opacity: Float
    }
    
    private static let center = CGPoint(x: 13.0, y: 13.0)
    private static let lineX: CGFloat = 14.55
    private static let lineYs: [CGFloat] = [9.9, 13.0, 16.1]
    private static let lineScale: CGFloat = 0.85
    private static let listLines: [Line] = lineYs.map { Line(position: CGPoint(x: lineX, y: $0), rotation: 0.0, scale: lineScale, opacity: 1.0) }
    private static let closeLines: [Line] = [
        Line(position: center, rotation: .pi / 4.0, scale: 1.0, opacity: 1.0),
        Line(position: center, rotation: 0.0, scale: 0.1, opacity: 0.0),
        Line(position: center, rotation: -.pi / 4.0, scale: 1.0, opacity: 1.0)
    ]
    private static let listOutline = outlinePath(CGRect(x: 4.0, y: 5.9, width: 18.0, height: 14.2), radius: 4.0)
    private static let closeOutline = outlinePath(CGRect(x: 4.0, y: 4.0, width: 18.0, height: 18.0), radius: 9.0)
    
    private let outline = CAShapeLayer()
    private let lines = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    private let dots = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    private var isClose = false
    
    private static func outlinePath(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let handle = radius * 0.5522847
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control1: CGPoint(x: rect.maxX - radius + handle, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY + radius - handle))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.maxY - radius + handle), control2: CGPoint(x: rect.maxX - radius + handle, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control1: CGPoint(x: rect.minX + radius - handle, y: rect.maxY), control2: CGPoint(x: rect.minX, y: rect.maxY - radius + handle))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.minY + radius - handle), control2: CGPoint(x: rect.minX + radius - handle, y: rect.minY))
        path.closeSubpath()
        return path
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        self.layer.allowsGroupOpacity = true
        
        self.outline.lineWidth = 1.5
        self.outline.fillColor = nil
        self.layer.addSublayer(self.outline)
        
        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: -4.2, y: 0.0))
        linePath.addLine(to: CGPoint(x: 4.2, y: 0.0))
        for line in self.lines {
            line.path = linePath
            line.lineWidth = 1.5
            line.lineCap = .round
            line.fillColor = nil
            self.layer.addSublayer(line)
        }
        
        let dotPath = CGPath(ellipseIn: CGRect(x: -0.85, y: -0.85, width: 1.7, height: 1.7), transform: nil)
        for (index, dot) in self.dots.enumerated() {
            dot.path = dotPath
            dot.position = CGPoint(x: 8.1, y: SupportTemplatesIconView.lineYs[index])
            self.layer.addSublayer(dot)
        }
        
        self.apply(isClose: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(color: UIColor) {
        self.outline.strokeColor = color.cgColor
        for line in self.lines {
            line.strokeColor = color.cgColor
        }
        for dot in self.dots {
            dot.fillColor = color.cgColor
        }
    }
    
    private func apply(isClose: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.outline.path = isClose ? SupportTemplatesIconView.closeOutline : SupportTemplatesIconView.listOutline
        let states = isClose ? SupportTemplatesIconView.closeLines : SupportTemplatesIconView.listLines
        for (line, state) in zip(self.lines, states) {
            line.position = state.position
            line.opacity = state.opacity
            line.transform = CATransform3DScale(CATransform3DMakeRotation(state.rotation, 0.0, 0.0, 1.0), state.scale, 1.0, 1.0)
        }
        for dot in self.dots {
            dot.opacity = isClose ? 0.0 : 1.0
            dot.transform = CATransform3DMakeScale(isClose ? 0.2 : 1.0, isClose ? 0.2 : 1.0, 1.0)
        }
        CATransaction.commit()
    }
    
    private func spring(_ layer: CALayer, keyPath: String, from: Any?, to: Any?, stiffness: CGFloat, damping: CGFloat, delay: Double = 0.0) {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.stiffness = stiffness
        animation.damping = damping
        animation.fromValue = from
        animation.toValue = to
        animation.duration = animation.settlingDuration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .backwards
        if delay > 0.0 {
            animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        }
        layer.add(animation, forKey: keyPath)
    }
    
    private func fade(_ layer: CALayer, from: Float, to: Float, delay: Double) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = 0.14
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .backwards
        if delay > 0.0 {
            animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        }
        layer.add(animation, forKey: "opacity")
    }
    
    func setIsClose(_ isClose: Bool, animated: Bool) {
        guard self.isClose != isClose else {
            return
        }
        self.isClose = isClose
        
        guard animated else {
            for sublayer in [self.outline] + self.lines + self.dots {
                sublayer.removeAllAnimations()
            }
            self.apply(isClose: isClose)
            return
        }
        
        let outlineFrom = self.outline.presentation()?.path ?? self.outline.path
        let current = self.lines.map { line -> Line in
            let source = line.presentation() ?? line
            return Line(position: source.position, rotation: source.value(forKeyPath: "transform.rotation.z") as? CGFloat ?? 0.0, scale: source.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0, opacity: source.opacity)
        }
        let dotsCurrent = self.dots.map { dot -> (opacity: Float, scale: CGFloat) in
            let source = dot.presentation() ?? dot
            return (source.opacity, source.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0)
        }
        
        self.apply(isClose: isClose)
        
        self.spring(self.outline, keyPath: "path", from: outlineFrom, to: self.outline.path, stiffness: 420.0, damping: 34.0)
        
        let targets = isClose ? SupportTemplatesIconView.closeLines : SupportTemplatesIconView.listLines
        for index in self.lines.indices {
            let line = self.lines[index]
            let from = current[index]
            let to = targets[index]
            self.spring(line, keyPath: "position", from: from.position, to: to.position, stiffness: 420.0, damping: 34.0, delay: isClose ? 0.0 : 0.05)
            self.spring(line, keyPath: "transform.rotation.z", from: from.rotation, to: to.rotation, stiffness: 420.0, damping: 24.0, delay: isClose ? 0.05 : 0.0)
            self.spring(line, keyPath: "transform.scale.x", from: from.scale, to: to.scale, stiffness: 420.0, damping: 34.0)
            if from.opacity != to.opacity {
                self.fade(line, from: from.opacity, to: to.opacity, delay: isClose ? 0.0 : 0.1)
            }
        }
        for (dot, from) in zip(self.dots, dotsCurrent) {
            self.fade(dot, from: from.opacity, to: isClose ? 0.0 : 1.0, delay: isClose ? 0.0 : 0.12)
            self.spring(dot, keyPath: "transform.scale", from: from.scale, to: isClose ? 0.2 : 1.0, stiffness: 420.0, damping: 34.0, delay: isClose ? 0.0 : 0.12)
        }
    }
}

final class AccessoryItemIconButton: HighlightTrackingButton, GlassBackgroundView.ContentView {
    private var item: ChatTextInputAccessoryItem
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var width: CGFloat
    private let iconImageView: GlassBackgroundView.ContentImageView
    private var textView: ImmediateTextView?
    private var tintMaskTextView: ImmediateTextView?
    private var animationView: ComponentView<Empty>?
    private var tintMaskAnimationView: UIImageView?
    private var supportTemplatesIconView: SupportTemplatesIconView?
    private var supportTemplatesTintIconView: SupportTemplatesIconView?
    
    override static var layerClass: AnyClass {
        return GlassBackgroundView.ContentLayer.self
    }
    
    let tintMask = UIView()
    
    init(item: ChatTextInputAccessoryItem, theme: PresentationTheme, strings: PresentationStrings) {
        self.item = item
        self.theme = theme
        self.strings = strings
        
        self.iconImageView = GlassBackgroundView.ContentImageView()
        
        let (image, text, accessibilityLabel, alpha, _) = AccessoryItemIconButton.imageAndInsets(item: item, theme: theme, strings: strings)
        
        self.width = AccessoryItemIconButton.calculateWidth(item: item, image: image, text: text, strings: strings)
        
        super.init(frame: CGRect())
        
        (self.layer as? GlassBackgroundView.ContentLayer)?.targetLayer = self.tintMask.layer
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button]
        
        self.iconImageView.isUserInteractionEnabled = false
        self.addSubview(self.iconImageView)
        
        self.tintMask.addSubview(self.iconImageView.tintMask)
        
        switch item {
        case .input, .botInput, .silentPost:
            self.iconImageView.isHidden = true
            self.iconImageView.tintMask.isHidden = true
            self.animationView = ComponentView<Empty>()
            self.tintMaskAnimationView = UIImageView()
        case .supportTemplates:
            let iconView = SupportTemplatesIconView()
            let tintIconView = SupportTemplatesIconView()
            tintIconView.update(color: .black)
            self.supportTemplatesIconView = iconView
            self.supportTemplatesTintIconView = tintIconView
            self.addSubview(iconView)
            self.tintMask.addSubview(tintIconView)
            self.updateSupportTemplatesIconColor()
        default:
            break
        }
        
        if let text {
            if self.textView == nil {
                let textView = ImmediateTextView()
                textView.isUserInteractionEnabled = false
                self.textView = textView
                self.addSubview(textView)
            }
            if self.tintMaskTextView == nil {
                let tintMaskTextView = ImmediateTextView()
                self.tintMaskTextView = tintMaskTextView
                self.tintMask.addSubview(tintMaskTextView)
            }
            
            self.textView?.attributedText = NSAttributedString(string: text, font: accessoryButtonFont, textColor: theme.chat.inputPanel.inputControlColor)
            self.tintMaskTextView?.attributedText = NSAttributedString(string: text, font: accessoryButtonFont, textColor: .black)
        } else {
            if let textView = self.textView {
                self.textView = nil
                textView.removeFromSuperview()
            }
            if let tintMaskTextView = self.tintMaskTextView {
                self.tintMaskTextView = nil
                tintMaskTextView.removeFromSuperview()
            }
        }
        
        self.iconImageView.image = image
        self.iconImageView.tintColor = theme.chat.inputPanel.inputControlColor.withAlphaComponent(1.0)
        self.iconImageView.alpha = alpha * theme.chat.inputPanel.inputControlColor.alpha
        self.iconImageView.tintMask.alpha = alpha * theme.chat.inputPanel.inputControlColor.alpha
        
        self.accessibilityLabel = accessibilityLabel
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.4
                    strongSelf.layer.allowsGroupOpacity = true
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.layer.allowsGroupOpacity = false
                }
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        return result
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        let (image, text, accessibilityLabel, alpha, _) = AccessoryItemIconButton.imageAndInsets(item: item, theme: theme, strings: strings)
        
        self.width = AccessoryItemIconButton.calculateWidth(item: item, image: image, text: text, strings: strings)
        
        if let text {
            self.textView?.attributedText = NSAttributedString(string: text, font: accessoryButtonFont, textColor: theme.chat.inputPanel.inputControlColor)
            self.tintMaskTextView?.attributedText = NSAttributedString(string: text, font: accessoryButtonFont, textColor: .black)
        }
        
        self.iconImageView.image = image
        self.iconImageView.tintColor = theme.chat.inputPanel.inputControlColor.withAlphaComponent(1.0)
        self.iconImageView.alpha = alpha * theme.chat.inputPanel.inputControlColor.alpha
        
        self.accessibilityLabel = accessibilityLabel
        self.updateSupportTemplatesIconColor()
    }
    
    private func updateSupportTemplatesIconColor() {
        guard let iconView = self.supportTemplatesIconView else {
            return
        }
        let color = self.theme.chat.inputPanel.inputControlColor
        iconView.update(color: color.withAlphaComponent(1.0))
        iconView.setMonochromaticEffect(tintColor: color.withAlphaComponent(1.0))
        iconView.alpha = color.alpha
        self.supportTemplatesTintIconView?.alpha = color.alpha
    }
    
    func setSupportTemplatesIsOpen(_ isOpen: Bool, animated: Bool) {
        guard let iconView = self.supportTemplatesIconView else {
            return
        }
        iconView.setIsClose(isOpen, animated: animated)
        self.supportTemplatesTintIconView?.setIsClose(isOpen, animated: animated)
        self.accessibilityLabel = isOpen ? self.strings.Support_Templates_VoiceOverClose : self.strings.Support_Templates_VoiceOverOpen
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private static func imageAndInsets(item: ChatTextInputAccessoryItem, theme: PresentationTheme, strings: PresentationStrings) -> (UIImage?, String?, String, CGFloat, UIEdgeInsets) {
        switch item {
            case let .input(isEnabled, inputMode), let .botInput(isEnabled, inputMode):
                switch inputMode {
                case .keyboard:
                    return (PresentationResourcesChat.chatInputTextFieldKeyboardImage(theme), nil, strings.VoiceOver_Keyboard, 1.0, UIEdgeInsets())
                case .stickers, .emoji:
                    return (PresentationResourcesChat.chatInputTextFieldStickersImage(theme), nil, strings.VoiceOver_Stickers, isEnabled ? 1.0 : 0.4, UIEdgeInsets())
                case .bot:
                    return (PresentationResourcesChat.chatInputTextFieldInputButtonsImage(theme), nil, strings.VoiceOver_BotKeyboard, 1.0, UIEdgeInsets())
                }
            case .commands:
                return (PresentationResourcesChat.chatInputTextFieldCommandsImage(theme), nil, strings.VoiceOver_BotCommands, 1.0, UIEdgeInsets())
            case let .silentPost(value):
                if value {
                    return (PresentationResourcesChat.chatInputTextFieldSilentPostOnImage(theme), nil, strings.VoiceOver_SilentPostOn, 1.0, UIEdgeInsets())
                } else {
                    return (PresentationResourcesChat.chatInputTextFieldSilentPostOffImage(theme), nil, strings.VoiceOver_SilentPostOff, 1.0, UIEdgeInsets())
                }
            case .suggestPost:
                return (PresentationResourcesChat.chatInputTextFieldSuggestPostImage(theme), nil, strings.VoiceOver_SuggestPost, 1.0, UIEdgeInsets())
            case let .messageAutoremoveTimeout(timeout):
                if let timeout = timeout {
                    return (nil, shortTimeIntervalString(strings: strings, value: timeout), strings.VoiceOver_SelfDestructTimerOn(timeIntervalString(strings: strings, value: timeout)).string, 1.0, UIEdgeInsets())
                } else {
                    return (PresentationResourcesChat.chatInputTextFieldTimerImage(theme), nil, strings.VoiceOver_SelfDestructTimerOff, 1.0, UIEdgeInsets(top: 1.0, left: 0.0, bottom: -1.0, right: 0.0))
                }
            case .scheduledMessages:
                return (PresentationResourcesChat.chatInputTextFieldScheduleImage(theme), nil, strings.VoiceOver_ScheduledMessages, 1.0, UIEdgeInsets())
            case .gift:
                return (PresentationResourcesChat.chatInputTextFieldGiftImage(theme), nil, strings.VoiceOver_GiftPremium, 1.0, UIEdgeInsets())
            case .supportTemplates:
                return (nil, nil, strings.Support_Templates_VoiceOverOpen, 1.0, UIEdgeInsets())
        }
    }
    
    private static func calculateWidth(item: ChatTextInputAccessoryItem, image: UIImage?, text: String?, strings: PresentationStrings) -> CGFloat {
        switch item {
        case .input, .botInput, .silentPost, .commands, .scheduledMessages, .gift, .suggestPost, .supportTemplates:
            return 32.0
        case let .messageAutoremoveTimeout(timeout):
            var imageWidth = (image?.size.width ?? 0.0) + CGFloat(8.0)
            if let _ = timeout, let text = text {
                imageWidth = ceil((text as NSString).size(withAttributes: [.font: accessoryButtonFont]).width) + 10.0
            }
            
            return max(imageWidth, 24.0)
        }
    }
    
    func updateLayout(item: ChatTextInputAccessoryItem, size: CGSize) {
        let previousItem = self.item
        self.item = item
        
        let (updatedImage, text, _, _, insets) = AccessoryItemIconButton.imageAndInsets(item: item, theme: self.theme, strings: self.strings)
        
        if let iconView = self.supportTemplatesIconView {
            let iconSize = SupportTemplatesIconView.size
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
            iconView.frame = iconFrame
            self.supportTemplatesTintIconView?.frame = iconFrame
        }
        
        if let image = self.iconImageView.image {
            self.iconImageView.image = updatedImage
            
            let bottomInset: CGFloat = 0.0
            var imageFrame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0) - bottomInset), size: image.size)
            imageFrame.origin.y += insets.top
            if case .scheduledMessages = item {
                imageFrame.origin.y += 1.0
            }
            self.iconImageView.frame = imageFrame
            self.iconImageView.tintMask.frame = imageFrame
            
            if let animationView = self.animationView {
                let width = AccessoryItemIconButton.calculateWidth(item: item, image: image, text: "", strings: self.strings)
                
                let animationFrame = CGRect(origin: CGPoint(x: floor((size.width - width) / 2.0), y: floor((size.height - width) / 2.0) - bottomInset), size: CGSize(width: width, height: width))
                
                let animationName: String
                var animationMode: LottieAnimationComponent.AnimationItem.Mode = .still(position: .end)
                
                if case let .silentPost(muted) = item {
                    if case let .silentPost(previousMuted) = previousItem {
                        if muted {
                            animationName = "input_anim_channelMute"
                        } else {
                            animationName = "input_anim_channelUnmute"
                        }
                        if muted != previousMuted {
                            animationMode = .animating(loop: false)
                        }
                    } else {
                        animationName = "input_anim_channelMute"
                    }
                } else {
                    var previousInputMode: ChatTextInputAccessoryItem.InputMode?
                    var inputMode: ChatTextInputAccessoryItem.InputMode?
                    
                    switch previousItem {
                        case let .input(_, itemInputMode), let .botInput(_, itemInputMode):
                            previousInputMode = itemInputMode
                        default:
                            break
                    }
                    switch item {
                        case let .input(_, itemInputMode), let .botInput(_, itemInputMode):
                            inputMode = itemInputMode
                        default:
                            break
                    }
                    
                    if let inputMode = inputMode {
                        switch inputMode {
                            case .keyboard:
                                if let previousInputMode = previousInputMode {
                                    if case .stickers = previousInputMode {
                                        animationName = "input_anim_stickerToKey"
                                        animationMode = .animating(loop: false)
                                    } else if case .emoji = previousInputMode {
                                        animationName = "input_anim_smileToKey"
                                        animationMode = .animating(loop: false)
                                    } else if case .bot = previousInputMode {
                                        animationName = "input_anim_botToKey"
                                        animationMode = .animating(loop: false)
                                    } else {
                                        animationName = "input_anim_stickerToKey"
                                    }
                                } else {
                                    animationName = "input_anim_stickerToKey"
                                }
                            case .stickers:
                                if let previousInputMode = previousInputMode {
                                    if case .keyboard = previousInputMode {
                                        animationName = "input_anim_keyToSticker"
                                        animationMode = .animating(loop: false)
                                    } else if case .emoji = previousInputMode {
                                        animationName = "input_anim_smileToSticker"
                                        animationMode = .animating(loop: false)
                                    } else {
                                        animationName = "input_anim_keyToSticker"
                                    }
                                } else {
                                    animationName = "input_anim_keyToSticker"
                                }
                            case .emoji:
                                if let previousInputMode = previousInputMode {
                                    if case .keyboard = previousInputMode {
                                        animationName = "input_anim_keyToSmile"
                                        animationMode = .animating(loop: false)
                                    } else if case .stickers = previousInputMode {
                                        animationName = "input_anim_stickerToSmile"
                                        animationMode = .animating(loop: false)
                                    } else {
                                        animationName = "input_anim_keyToSmile"
                                    }
                                } else {
                                    animationName = "input_anim_keyToSmile"
                                }
                            case .bot:
                                if let previousInputMode = previousInputMode {
                                    if case .keyboard = previousInputMode {
                                        animationName = "input_anim_keyToBot"
                                        animationMode = .animating(loop: false)
                                    } else {
                                        animationName = "input_anim_keyToBot"
                                    }
                                } else {
                                    animationName = "input_anim_keyToBot"
                                }
                        }
                    } else {
                        animationName = ""
                    }
                }
                
                let animationSize = animationView.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: animationName),
                        color: self.theme.chat.inputPanel.inputControlColor.withAlphaComponent(1.0)
                    )),
                    environment: {},
                    containerSize: animationFrame.size
                )
                if let view = animationView.view as? LottieComponent.View {
                    view.isUserInteractionEnabled = false
                    if view.superview == nil {
                        view.output = self.tintMaskAnimationView
                        self.addSubview(view)
                        if let tintMaskAnimationView = self.tintMaskAnimationView {
                            self.tintMask.addSubview(tintMaskAnimationView)
                        }
                    }
                    view.setMonochromaticEffect(tintColor: self.theme.chat.inputPanel.inputControlColor.withAlphaComponent(1.0))
                    view.alpha = self.theme.chat.inputPanel.inputControlColor.alpha
                    let animationFrameValue = CGRect(origin: CGPoint(x: animationFrame.minX + floor((animationFrame.width - animationSize.width) / 2.0), y: animationFrame.minY + floor((animationFrame.height - animationSize.height) / 2.0)), size: animationSize)
                    view.frame = animationFrameValue
                    if let tintMaskAnimationView = self.tintMaskAnimationView {
                        tintMaskAnimationView.frame = animationFrameValue
                    }
                    
                    if case .animating = animationMode {
                        view.playOnce()
                    }
                }
            }
        }
        
        if let text {
            self.textView?.attributedText = NSAttributedString(string: text, font: accessoryButtonFont, textColor: theme.chat.inputPanel.inputControlColor)
            self.tintMaskTextView?.attributedText = NSAttributedString(string: text, font: accessoryButtonFont, textColor: .black)
        }
        
        if let textView = self.textView, let tintMaskTextView = self.tintMaskTextView {
            let textSize = textView.updateLayout(CGSize(width: 100.0, height: 100.0))
            let _ = tintMaskTextView.updateLayout(CGSize(width: 100.0, height: 100.0))
            
            let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) * 0.5), y: floor((size.height - textSize.height) * 0.5)), size: textSize)
            textView.frame = textFrame
            tintMaskTextView.frame = textFrame
        }
    }
    
    var buttonWidth: CGFloat {
        return self.width
    }
}
