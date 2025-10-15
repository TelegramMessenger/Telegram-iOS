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
                    return (PresentationResourcesChat.chatInputTextFieldTimerImage(theme), nil, strings.VoiceOver_SelfDestructTimerOff, 1.0, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0))
                }
            case .scheduledMessages:
                return (PresentationResourcesChat.chatInputTextFieldScheduleImage(theme), nil, strings.VoiceOver_ScheduledMessages, 1.0, UIEdgeInsets())
            case .gift:
                return (PresentationResourcesChat.chatInputTextFieldGiftImage(theme), nil, strings.VoiceOver_GiftPremium, 1.0, UIEdgeInsets())
        }
    }
    
    private static func calculateWidth(item: ChatTextInputAccessoryItem, image: UIImage?, text: String?, strings: PresentationStrings) -> CGFloat {
        switch item {
        case .input, .botInput, .silentPost, .commands, .scheduledMessages, .gift, .suggestPost:
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
        
        let (updatedImage, text, _, _, _) = AccessoryItemIconButton.imageAndInsets(item: item, theme: self.theme, strings: self.strings)
        
        if let image = self.iconImageView.image {
            self.iconImageView.image = updatedImage
            
            let bottomInset: CGFloat = 0.0
            var imageFrame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0) - bottomInset), size: image.size)
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
