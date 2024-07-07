import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContextUI
import TelegramCore
import TextFormat
import ReactionSelectionNode
import ViewControllerComponent
import ComponentFlow
import ComponentDisplayAdapters
import ChatMessageBackground
import WallpaperBackgroundNode
import MultilineTextWithEntitiesComponent
import ReactionButtonListComponent
import MultilineTextComponent
import ChatInputTextNode
import EmojiTextAttachmentView

public final class ChatSendMessageScreenEffectIcon: Component {
    public enum Content: Equatable {
        case file(TelegramMediaFile)
        case text(String)
    }
    
    public let context: AccountContext
    public let content: Content
    
    public init(
        context: AccountContext,
        content: Content
    ) {
        self.context = context
        self.content = content
    }
    
    public static func ==(lhs: ChatSendMessageScreenEffectIcon, rhs: ChatSendMessageScreenEffectIcon) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var fileView: ReactionIconView?
        private var textView: ComponentView<Empty>?
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatSendMessageScreenEffectIcon, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if case let .file(file) = component.content {
                let fileView: ReactionIconView
                if let current = self.fileView {
                    fileView = current
                } else {
                    fileView = ReactionIconView()
                    self.fileView = fileView
                    self.addSubview(fileView)
                }
                fileView.update(
                    size: availableSize,
                    context: component.context,
                    file: file,
                    fileId: file.fileId.id,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    tintColor: nil,
                    placeholderColor: UIColor(white: 0.0, alpha: 0.1),
                    animateIdle: false,
                    reaction: .custom(file.fileId.id),
                    transition: .immediate
                )
                fileView.frame = CGRect(origin: CGPoint(), size: availableSize)
            } else {
                if let fileView = self.fileView {
                    self.fileView = nil
                    fileView.removeFromSuperview()
                }
            }
            
            if case let .text(text) = component.content {
                let textView: ComponentView<Empty>
                if let current = self.textView {
                    textView = current
                } else {
                    textView = ComponentView()
                    self.textView = textView
                }
                let textInsets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)
                let textSize = textView.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: text, font: Font.regular(10.0), textColor: .black)),
                        insets: textInsets
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - textSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - textSize.height) * 0.5)), size: textSize)
                if let textComponentView = textView.view {
                    if textComponentView.superview == nil {
                        self.addSubview(textComponentView)
                    }
                    textComponentView.frame = textFrame
                }
            } else {
                if let textView = self.textView {
                    self.textView = nil
                    textView.view?.removeFromSuperview()
                }
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class CustomEmojiContainerView: UIView {
    private let emojiViewProvider: (ChatTextInputTextCustomEmojiAttribute) -> UIView?
    
    private var emojiLayers: [InlineStickerItemLayer.Key: UIView] = [:]
    
    init(emojiViewProvider: @escaping (ChatTextInputTextCustomEmojiAttribute) -> UIView?) {
        self.emojiViewProvider = emojiViewProvider
        
        super.init(frame: CGRect())
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func update(emojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute)]) {
        var nextIndexById: [Int64: Int] = [:]
        
        var validKeys = Set<InlineStickerItemLayer.Key>()
        for (rect, emoji) in emojiRects {
            let index: Int
            if let nextIndex = nextIndexById[emoji.fileId] {
                index = nextIndex
            } else {
                index = 0
            }
            nextIndexById[emoji.fileId] = index + 1
            
            let key = InlineStickerItemLayer.Key(id: emoji.fileId, index: index)
            
            let view: UIView
            if let current = self.emojiLayers[key] {
                view = current
            } else if let newView = self.emojiViewProvider(emoji) {
                view = newView
                self.addSubview(newView)
                self.emojiLayers[key] = view
            } else {
                continue
            }
            
            let size = CGSize(width: 24.0, height: 24.0)
            
            view.frame = CGRect(origin: CGPoint(x: floor(rect.midX - size.width / 2.0), y: floor(rect.midY - size.height / 2.0)), size: size)
            
            validKeys.insert(key)
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, view) in self.emojiLayers {
            if !validKeys.contains(key) {
                removeKeys.append(key)
                view.removeFromSuperview()
            }
        }
        for key in removeKeys {
            self.emojiLayers.removeValue(forKey: key)
        }
    }
}


final class MessageItemView: UIView {
    private let backgroundWallpaperNode: ChatMessageBubbleBackdrop
    private let backgroundNode: ChatMessageBackground
    
    private let textClippingContainer: UIView
    private var textNode: ChatInputTextNode?
    private var customEmojiContainerView: CustomEmojiContainerView?
    private var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    
    private var mediaPreviewClippingView: UIView?
    private var mediaPreview: ChatSendMessageContextScreenMediaPreview?
    
    private var effectIcon: ComponentView<Empty>?
    var effectIconView: UIView? {
        return self.effectIcon?.view
    }
    
    private var effectIconBackgroundView: UIImageView?
    
    private var chatTheme: ChatPresentationThemeData?
    private var currentSize: CGSize?
    private var currentMediaCaptionIsAbove: Bool = false
    
    override init(frame: CGRect) {
        self.backgroundWallpaperNode = ChatMessageBubbleBackdrop()
        self.backgroundNode = ChatMessageBackground()
        self.backgroundNode.backdropNode = self.backgroundWallpaperNode
        
        self.textClippingContainer = UIView()
        self.textClippingContainer.layer.anchorPoint = CGPoint()
        self.textClippingContainer.clipsToBounds = true
        
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        
        self.addSubview(self.backgroundWallpaperNode.view)
        self.addSubview(self.backgroundNode.view)
        
        self.addSubview(self.textClippingContainer)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func animateIn(
        sourceTextInputView: ChatInputTextView?,
        isEditMessage: Bool,
        transition: ComponentTransition
    ) {
        if isEditMessage {
            transition.animateScale(view: self, from: 0.001, to: 1.0)
            transition.animateAlpha(view: self, from: 0.0, to: 1.0)
        } else {
            if let mediaPreview = self.mediaPreview {
                mediaPreview.animateIn(transition: transition)
            }
        }
    }
    
    func animateOut(
        sourceTextInputView: ChatInputTextView?,
        toEmpty: Bool,
        isEditMessage: Bool,
        transition: ComponentTransition
    ) {
        if isEditMessage {
            transition.setScale(view: self, scale: 0.001)
            transition.setAlpha(view: self, alpha: 0.0)
        } else {
            if let mediaPreview = self.mediaPreview {
                if toEmpty {
                    mediaPreview.animateOutOnSend(transition: transition)
                } else {
                    mediaPreview.animateOut(transition: transition)
                }
            }
        }
    }
    
    func update(
        context: AccountContext,
        presentationData: PresentationData,
        backgroundNode: WallpaperBackgroundNode?,
        textString: NSAttributedString,
        sourceTextInputView: ChatInputTextView?,
        emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?,
        sourceMediaPreview: ChatSendMessageContextScreenMediaPreview?,
        mediaCaptionIsAbove: Bool,
        textInsets: UIEdgeInsets,
        explicitBackgroundSize: CGSize?,
        maxTextWidth: CGFloat,
        maxTextHeight: CGFloat,
        containerSize: CGSize,
        effect: AvailableMessageEffects.MessageEffect?,
        isEditMessage: Bool,
        transition: ComponentTransition
    ) -> CGSize {
        self.emojiViewProvider = emojiViewProvider
        
        var effectIconSize: CGSize?
        if let effect {
            let effectIcon: ComponentView<Empty>
            if let current = self.effectIcon {
                effectIcon = current
            } else {
                effectIcon = ComponentView()
                self.effectIcon = effectIcon
            }
            let effectIconContent: ChatSendMessageScreenEffectIcon.Content
            if let staticIcon = effect.staticIcon {
                effectIconContent = .file(staticIcon)
            } else {
                effectIconContent = .text(effect.emoticon)
            }
            effectIconSize = effectIcon.update(
                transition: .immediate,
                component: AnyComponent(ChatSendMessageScreenEffectIcon(
                    context: context,
                    content: effectIconContent
                )),
                environment: {},
                containerSize: CGSize(width: 8.0, height: 8.0)
            )
        }
        
        let chatTheme: ChatPresentationThemeData
        if let current = self.chatTheme, current.theme === presentationData.theme {
            chatTheme = current
        } else {
            chatTheme = ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
            self.chatTheme = chatTheme
        }
        
        let themeGraphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper, bubbleCorners: presentationData.chatBubbleCorners)
        self.backgroundWallpaperNode.setType(
            type: .outgoing(.None),
            theme: chatTheme,
            essentialGraphics: themeGraphics,
            maskMode: true,
            backgroundNode: backgroundNode
        )
        
        self.backgroundNode.setType(
            type: .outgoing(.None),
            highlighted: false,
            graphics: themeGraphics,
            maskMode: true,
            hasWallpaper: true,
            transition: transition.containedViewLayoutTransition,
            backgroundNode: backgroundNode
        )
        
        let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.25)
        
        if let sourceMediaPreview {
            let mediaPreviewClippingView: UIView
            if let current = self.mediaPreviewClippingView {
                mediaPreviewClippingView = current
            } else {
                mediaPreviewClippingView = UIView()
                mediaPreviewClippingView.layer.anchorPoint = CGPoint()
                mediaPreviewClippingView.clipsToBounds = true
                mediaPreviewClippingView.isUserInteractionEnabled = false
                self.mediaPreviewClippingView = mediaPreviewClippingView
                self.addSubview(mediaPreviewClippingView)
            }
            
            if self.mediaPreview !== sourceMediaPreview {
                self.mediaPreview?.view.removeFromSuperview()
                self.mediaPreview = nil
                
                self.mediaPreview = sourceMediaPreview
                if let mediaPreview = self.mediaPreview {
                    mediaPreviewClippingView.addSubview(mediaPreview.view)
                }
            }
            
            let mediaPreviewSize = sourceMediaPreview.update(containerSize: containerSize, transition: transition)
            
            var backgroundSize = CGSize(width: mediaPreviewSize.width, height: mediaPreviewSize.height)
            var mediaPreviewFrame: CGRect
            switch sourceMediaPreview.layoutType {
            case .message, .media:
                backgroundSize.width += 7.0
                mediaPreviewFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: mediaPreviewSize)
            case .videoMessage:
                mediaPreviewFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: mediaPreviewSize)
            }
            
            let backgroundAlpha: CGFloat
            switch sourceMediaPreview.layoutType {
            case .media:
                if textString.length != 0 {
                    backgroundAlpha = explicitBackgroundSize != nil ? 0.0 : 1.0
                } else {
                    backgroundAlpha = 0.0
                }
            case .message, .videoMessage:
                backgroundAlpha = 0.0
            }
            
            let backgroundScale: CGFloat = 1.0
            
            var backgroundFrame = mediaPreviewFrame.insetBy(dx: -2.0, dy: -2.0)
            backgroundFrame.size.width += 6.0
            
            if textString.length != 0, case .media = sourceMediaPreview.layoutType {
                let textNode: ChatInputTextNode
                if let current = self.textNode {
                    textNode = current
                } else {
                    textNode = ChatInputTextNode(disableTiling: true)
                    textNode.textView.isScrollEnabled = false
                    textNode.isUserInteractionEnabled = false
                    self.textNode = textNode
                    self.textClippingContainer.addSubview(textNode.view)
                    
                    if let sourceTextInputView {
                        var textContainerInset = sourceTextInputView.defaultTextContainerInset
                        textContainerInset.right = 0.0
                        textNode.textView.defaultTextContainerInset = textContainerInset
                    }
                    
                    let messageAttributedText = NSMutableAttributedString(attributedString: textString)
                    
                    for entity in generateTextEntities(textString.string, enabledTypes: .all) {
                        messageAttributedText.addAttribute(.foregroundColor, value: presentationData.theme.chat.message.outgoing.linkTextColor, range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                    }
                    
                    textNode.attributedText = messageAttributedText
                }
                
                let mainColor = presentationData.theme.chat.message.outgoing.accentControlColor
                let mappedLineStyle: ChatInputTextView.Theme.Quote.LineStyle
                if let sourceTextInputView, let textTheme = sourceTextInputView.theme {
                    switch textTheme.quote.lineStyle {
                    case .solid:
                        mappedLineStyle = .solid(color: mainColor)
                    case .doubleDashed:
                        mappedLineStyle = .doubleDashed(mainColor: mainColor, secondaryColor: .clear)
                    case .tripleDashed:
                        mappedLineStyle = .tripleDashed(mainColor: mainColor, secondaryColor: .clear, tertiaryColor: .clear)
                    }
                } else {
                    mappedLineStyle = .solid(color: mainColor)
                }
                
                textNode.textView.theme = ChatInputTextView.Theme(
                    quote: ChatInputTextView.Theme.Quote(
                        background: mainColor.withMultipliedAlpha(0.1),
                        foreground: mainColor,
                        lineStyle: mappedLineStyle,
                        codeBackground: mainColor.withMultipliedAlpha(0.1),
                        codeForeground: mainColor
                    )
                )
                
                let maxTextWidth = mediaPreviewFrame.width
                
                let textPositioningInsets = UIEdgeInsets(top: -5.0, left: 0.0, bottom: -4.0, right: -4.0)
                
                let currentRightInset: CGFloat = 0.0
                let textHeight = textNode.textHeightForWidth(maxTextWidth, rightInset: currentRightInset)
                textNode.updateLayout(size: CGSize(width: maxTextWidth, height: textHeight))
                
                let textBoundingRect = textNode.textView.currentTextBoundingRect().integral
                let lastLineBoundingRect = textNode.textView.lastLineBoundingRect().integral
                
                let textWidth = textBoundingRect.width
                let textSize = CGSize(width: textWidth, height: textHeight)
                
                var positionedTextSize = CGSize(width: textSize.width + textPositioningInsets.left + textPositioningInsets.right, height: textSize.height + textPositioningInsets.top + textPositioningInsets.bottom)
                
                let effectInset: CGFloat = 12.0
                if effect != nil, lastLineBoundingRect.width > textSize.width - effectInset {
                    if lastLineBoundingRect != textBoundingRect {
                        positionedTextSize.height += 11.0
                    } else {
                        positionedTextSize.width += effectInset
                    }
                }
                let unclippedPositionedTextHeight = positionedTextSize.height - (textPositioningInsets.top + textPositioningInsets.bottom)
                
                positionedTextSize.height = min(positionedTextSize.height, maxTextHeight)
                
                let size = CGSize(width: positionedTextSize.width + textInsets.left + textInsets.right, height: positionedTextSize.height + textInsets.top + textInsets.bottom)
                
                var textFrame = CGRect(origin: CGPoint(x: textInsets.left - 6.0, y: backgroundFrame.height - 4.0 + textInsets.top), size: positionedTextSize)
                if mediaCaptionIsAbove {
                    textFrame.origin.y = 5.0
                }
                
                backgroundFrame.size.height += textSize.height + 2.0
                if mediaCaptionIsAbove {
                    mediaPreviewFrame.origin.y += textSize.height + 2.0
                }
                
                let backgroundSize = explicitBackgroundSize ?? size
                
                let previousSize = self.currentSize
                self.currentSize = backgroundFrame.size
                let _ = previousSize
                
                let textClippingContainerFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + 1.0, y: backgroundFrame.minY + 1.0), size: CGSize(width: backgroundFrame.width - 1.0 - 7.0, height: backgroundFrame.height - 1.0 - 1.0))
                
                var textClippingContainerBounds = CGRect(origin: CGPoint(), size: textClippingContainerFrame.size)
                if explicitBackgroundSize != nil, let sourceTextInputView {
                    textClippingContainerBounds.origin.y = sourceTextInputView.contentOffset.y
                } else {
                    textClippingContainerBounds.origin.y = unclippedPositionedTextHeight - backgroundSize.height + 4.0
                    textClippingContainerBounds.origin.y = max(0.0, textClippingContainerBounds.origin.y)
                }
                
                transition.setPosition(view: self.textClippingContainer, position: textClippingContainerFrame.origin)
                transition.setBounds(view: self.textClippingContainer, bounds: textClippingContainerBounds)
                
                alphaTransition.setAlpha(view: textNode.view, alpha: backgroundAlpha)
                transition.setFrame(view: textNode.view, frame: CGRect(origin: CGPoint(x: textFrame.minX + textPositioningInsets.left - textClippingContainerFrame.minX, y: textFrame.minY + textPositioningInsets.top - textClippingContainerFrame.minY), size: CGSize(width: maxTextWidth, height: textHeight)))
                self.updateTextContents()
            }
            
            transition.setFrame(view: sourceMediaPreview.view, frame: mediaPreviewFrame)
            
            transition.setPosition(view: self.backgroundWallpaperNode.view, position: CGRect(origin: CGPoint(), size: backgroundFrame.size).center)
            transition.setBounds(view: self.backgroundWallpaperNode.view, bounds: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            alphaTransition.setAlpha(view: self.backgroundWallpaperNode.view, alpha: backgroundAlpha)
            transition.setScale(view: self.backgroundWallpaperNode.view, scale: backgroundScale)
            self.backgroundWallpaperNode.updateFrame(backgroundFrame, transition: transition.containedViewLayoutTransition)
            transition.setPosition(view: self.backgroundNode.view, position: backgroundFrame.center)
            transition.setBounds(view: self.backgroundNode.view, bounds: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            transition.setScale(view: self.backgroundNode.view, scale: backgroundScale)
            alphaTransition.setAlpha(view: self.backgroundNode.view, alpha: backgroundAlpha)
            self.backgroundNode.updateLayout(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
            
            if let effectIcon = self.effectIcon, let effectIconSize {
                if let effectIconView = effectIcon.view {
                    var animateIn = false
                    if effectIconView.superview == nil {
                        animateIn = true
                        self.addSubview(effectIconView)
                    }
                    
                    let effectIconBackgroundView: UIImageView
                    if let current = self.effectIconBackgroundView {
                        effectIconBackgroundView = current
                    } else {
                        effectIconBackgroundView = UIImageView()
                        self.effectIconBackgroundView = effectIconBackgroundView
                        self.insertSubview(effectIconBackgroundView, belowSubview: effectIconView)
                    }
                    
                    let effectIconBackgroundSize = CGSize(width: effectIconSize.width + 8.0 * 2.0, height: 18.0)
                    
                    let effectIconBackgroundFrame: CGRect
                    switch sourceMediaPreview.layoutType {
                    case .message:
                        effectIconBackgroundFrame = CGRect(origin: CGPoint(x: mediaPreviewFrame.maxX - effectIconBackgroundSize.width - 3.0, y: mediaPreviewFrame.maxY - effectIconBackgroundSize.height - 4.0), size: effectIconBackgroundSize)
                        effectIconBackgroundView.backgroundColor = nil
                    case .media:
                        effectIconBackgroundFrame = CGRect(origin: CGPoint(x: mediaPreviewFrame.maxX - effectIconBackgroundSize.width - 6.0, y: mediaPreviewFrame.maxY - effectIconBackgroundSize.height - 6.0), size: effectIconBackgroundSize)
                        effectIconBackgroundView.backgroundColor = presentationData.theme.chat.message.mediaDateAndStatusFillColor
                    case .videoMessage:
                        effectIconBackgroundFrame = CGRect(origin: CGPoint(x: mediaPreviewFrame.maxX - effectIconBackgroundSize.width - 34.0, y: mediaPreviewFrame.maxY - effectIconBackgroundSize.height - 6.0), size: effectIconBackgroundSize)
                        
                        let serviceMessageColors = serviceMessageColorComponents(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
                        
                        effectIconBackgroundView.backgroundColor = serviceMessageColors.dateFillStatic
                    }
                    
                    let effectIconFrame = CGRect(origin: CGPoint(x: effectIconBackgroundFrame.minX + floor((effectIconBackgroundFrame.width - effectIconSize.width) * 0.5), y: effectIconBackgroundFrame.minY + floor((effectIconBackgroundFrame.height - effectIconSize.height) * 0.5)), size: effectIconSize)
                    
                    if animateIn {
                        effectIconView.frame = effectIconFrame
                        
                        effectIconBackgroundView.frame = effectIconBackgroundFrame
                        effectIconBackgroundView.layer.cornerRadius = effectIconBackgroundFrame.height * 0.5
                        
                        transition.animateAlpha(view: effectIconView, from: 0.0, to: 1.0)
                        if !transition.animation.isImmediate {
                            effectIconView.layer.animateSpring(from: 0.001 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                        }
                        
                        transition.animateAlpha(view: effectIconBackgroundView, from: 0.0, to: 1.0)
                    }
                    
                    transition.setFrame(view: effectIconView, frame: effectIconFrame)
                    
                    transition.setFrame(view: effectIconBackgroundView, frame: effectIconBackgroundFrame)
                    transition.setCornerRadius(layer: effectIconBackgroundView.layer, cornerRadius: effectIconBackgroundFrame.height * 0.5)
                }
            } else {
                if let effectIcon = self.effectIcon {
                    self.effectIcon = nil
                    
                    if let effectIconView = effectIcon.view {
                        transition.setScale(view: effectIconView, scale: 0.001)
                        transition.setAlpha(view: effectIconView, alpha: 0.0, completion: { [weak effectIconView] _ in
                            effectIconView?.removeFromSuperview()
                        })
                    }
                }
                if let effectIconBackgroundView = self.effectIconBackgroundView {
                    self.effectIconBackgroundView = nil
                    transition.setAlpha(view: effectIconBackgroundView, alpha: 0.0, completion: { [weak effectIconBackgroundView] _ in
                        effectIconBackgroundView?.removeFromSuperview()
                    })
                }
            }
            
            return backgroundFrame.size
        } else {
            let textNode: ChatInputTextNode
            if let current = self.textNode {
                textNode = current
            } else {
                textNode = ChatInputTextNode(disableTiling: true)
                textNode.textView.isScrollEnabled = false
                textNode.isUserInteractionEnabled = false
                self.textNode = textNode
                self.textClippingContainer.addSubview(textNode.view)
                
                if let sourceTextInputView {
                    textNode.textView.defaultTextContainerInset = sourceTextInputView.defaultTextContainerInset
                }
                
                let messageAttributedText = NSMutableAttributedString(attributedString: textString)
                
                for entity in generateTextEntities(textString.string, enabledTypes: .all) {
                    messageAttributedText.addAttribute(.foregroundColor, value: presentationData.theme.chat.message.outgoing.linkTextColor, range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                }
                
                textNode.attributedText = messageAttributedText
            }
            
            let mainColor = presentationData.theme.chat.message.outgoing.accentControlColor
            let mappedLineStyle: ChatInputTextView.Theme.Quote.LineStyle
            if let sourceTextInputView, let textTheme = sourceTextInputView.theme {
                switch textTheme.quote.lineStyle {
                case .solid:
                    mappedLineStyle = .solid(color: mainColor)
                case .doubleDashed:
                    mappedLineStyle = .doubleDashed(mainColor: mainColor, secondaryColor: .clear)
                case .tripleDashed:
                    mappedLineStyle = .tripleDashed(mainColor: mainColor, secondaryColor: .clear, tertiaryColor: .clear)
                }
            } else {
                mappedLineStyle = .solid(color: mainColor)
            }
            
            textNode.textView.theme = ChatInputTextView.Theme(
                quote: ChatInputTextView.Theme.Quote(
                    background: mainColor.withMultipliedAlpha(0.1),
                    foreground: mainColor,
                    lineStyle: mappedLineStyle,
                    codeBackground: mainColor.withMultipliedAlpha(0.1),
                    codeForeground: mainColor
                )
            )
            
            let textPositioningInsets = UIEdgeInsets(top: -5.0, left: 0.0, bottom: -4.0, right: -4.0)
            
            var currentRightInset: CGFloat = 0.0
            if let sourceTextInputView {
                currentRightInset = sourceTextInputView.currentRightInset
            }
            let textHeight = textNode.textHeightForWidth(maxTextWidth, rightInset: currentRightInset)
            textNode.updateLayout(size: CGSize(width: maxTextWidth, height: textHeight))
            
            let textBoundingRect = textNode.textView.currentTextBoundingRect().integral
            let lastLineBoundingRect = textNode.textView.lastLineBoundingRect().integral
            
            let textWidth = textBoundingRect.width
            let textSize = CGSize(width: textWidth, height: textHeight)
            
            var positionedTextSize = CGSize(width: textSize.width + textPositioningInsets.left + textPositioningInsets.right, height: textSize.height + textPositioningInsets.top + textPositioningInsets.bottom)
            
            let effectInset: CGFloat = 12.0
            if effect != nil, lastLineBoundingRect.width > textSize.width - effectInset {
                if lastLineBoundingRect != textBoundingRect {
                    positionedTextSize.height += 11.0
                } else {
                    positionedTextSize.width += effectInset
                }
            }
            let unclippedPositionedTextHeight = positionedTextSize.height - (textPositioningInsets.top + textPositioningInsets.bottom)
            
            positionedTextSize.height = min(positionedTextSize.height, maxTextHeight)
            
            let size = CGSize(width: positionedTextSize.width + textInsets.left + textInsets.right, height: positionedTextSize.height + textInsets.top + textInsets.bottom)
            
            let textFrame = CGRect(origin: CGPoint(x: textInsets.left, y: textInsets.top), size: positionedTextSize)
            
            let backgroundSize = explicitBackgroundSize ?? size
            
            let previousSize = self.currentSize
            self.currentSize = backgroundSize
            
            let textClippingContainerFrame = CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: backgroundSize.width - 1.0 - 7.0, height: backgroundSize.height - 1.0 - 1.0))
            
            var textClippingContainerBounds = CGRect(origin: CGPoint(), size: textClippingContainerFrame.size)
            if explicitBackgroundSize != nil, let sourceTextInputView {
                textClippingContainerBounds.origin.y = sourceTextInputView.contentOffset.y
            } else {
                textClippingContainerBounds.origin.y = unclippedPositionedTextHeight - backgroundSize.height + 4.0
                textClippingContainerBounds.origin.y = max(0.0, textClippingContainerBounds.origin.y)
            }
            
            transition.setPosition(view: self.textClippingContainer, position: textClippingContainerFrame.origin)
            transition.setBounds(view: self.textClippingContainer, bounds: textClippingContainerBounds)
            
            textNode.view.frame = CGRect(origin: CGPoint(x: textFrame.minX + textPositioningInsets.left - textClippingContainerFrame.minX, y: textFrame.minY + textPositioningInsets.top - textClippingContainerFrame.minY), size: CGSize(width: maxTextWidth, height: textHeight))
            self.updateTextContents()
            
            if let effectIcon = self.effectIcon, let effectIconSize {
                if let effectIconView = effectIcon.view {
                    var animateIn = false
                    if effectIconView.superview == nil {
                        animateIn = true
                        self.addSubview(effectIconView)
                    }
                    let effectIconFrame = CGRect(origin: CGPoint(x: backgroundSize.width - textInsets.right + 2.0 -  effectIconSize.width, y: backgroundSize.height - textInsets.bottom - 2.0 - effectIconSize.height), size: effectIconSize)
                    if animateIn {
                        if let previousSize {
                            let previousEffectIconFrame = CGRect(origin: CGPoint(x: previousSize.width - textInsets.right + 2.0 - effectIconSize.width, y: previousSize.height - textInsets.bottom - 2.0 - effectIconSize.height), size: effectIconSize)
                            effectIconView.frame = previousEffectIconFrame
                        } else {
                            effectIconView.frame = effectIconFrame
                        }
                        transition.animateAlpha(view: effectIconView, from: 0.0, to: 1.0)
                        if !transition.animation.isImmediate {
                            effectIconView.layer.animateSpring(from: 0.001 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                        }
                    }
                    
                    transition.setFrame(view: effectIconView, frame: effectIconFrame)
                }
            } else {
                if let effectIcon = self.effectIcon {
                    self.effectIcon = nil
                    
                    if let effectIconView = effectIcon.view {
                        let effectIconSize = effectIconView.bounds.size
                        let effectIconFrame = CGRect(origin: CGPoint(x: backgroundSize.width - textInsets.right -  effectIconSize.width, y: backgroundSize.height - textInsets.bottom - effectIconSize.height), size: effectIconSize)
                        transition.setFrame(view: effectIconView, frame: effectIconFrame)
                        transition.setScale(view: effectIconView, scale: 0.001)
                        transition.setAlpha(view: effectIconView, alpha: 0.0, completion: { [weak effectIconView] _ in
                            effectIconView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            let backgroundAlpha: CGFloat
            if explicitBackgroundSize != nil {
                backgroundAlpha = 0.0
            } else {
                backgroundAlpha = 1.0
            }
            
            transition.setFrame(view: self.backgroundWallpaperNode.view, frame: CGRect(origin: CGPoint(), size: backgroundSize))
            transition.setAlpha(view: self.backgroundWallpaperNode.view, alpha: backgroundAlpha)
            self.backgroundWallpaperNode.updateFrame(CGRect(origin: CGPoint(), size: backgroundSize), transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundNode.view, frame: CGRect(origin: CGPoint(), size: backgroundSize))
            transition.setAlpha(view: self.backgroundNode.view, alpha: backgroundAlpha)
            self.backgroundNode.updateLayout(size: backgroundSize, transition: transition.containedViewLayoutTransition)
            
            return backgroundSize
        }
    }
    
    func updateClippingRect(
        sourceMediaPreview: ChatSendMessageContextScreenMediaPreview?,
        isAnimatedIn: Bool,
        localFrame: CGRect,
        containerSize: CGSize,
        transition: ComponentTransition
    ) {
        if let mediaPreviewClippingView = self.mediaPreviewClippingView, let sourceMediaPreview {
            let clippingFrame: CGRect
            if !isAnimatedIn, let globalClippingRect = sourceMediaPreview.globalClippingRect {
                clippingFrame = self.convert(globalClippingRect, from: nil)
            } else {
                clippingFrame = CGRect(origin: CGPoint(x: -localFrame.minX, y: -localFrame.minY), size: containerSize)
            }
            
            transition.setPosition(view: mediaPreviewClippingView, position: clippingFrame.origin)
            transition.setBounds(view: mediaPreviewClippingView, bounds: CGRect(origin: CGPoint(x: clippingFrame.minX, y: clippingFrame.minY), size: clippingFrame.size))
        }
    }
    
    private func updateTextContents() {
        guard let textInputNode = self.textNode else {
            return
        }
        
        var customEmojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute)] = []
        
        if let attributedText = textInputNode.attributedText {
            let beginning = textInputNode.textView.beginningOfDocument
            attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, range, _ in
                if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                    if let start = textInputNode.textView.position(from: beginning, offset: range.location), let end = textInputNode.textView.position(from: start, offset: range.length), let textRange = textInputNode.textView.textRange(from: start, to: end) {
                        let textRects = textInputNode.textView.selectionRects(for: textRange)
                        for textRect in textRects {
                            customEmojiRects.append((textRect.rect, value))
                            break
                        }
                    }
                }
            })
        }
        
        if !customEmojiRects.isEmpty {
            let customEmojiContainerView: CustomEmojiContainerView
            if let current = self.customEmojiContainerView {
                customEmojiContainerView = current
            } else {
                customEmojiContainerView = CustomEmojiContainerView(emojiViewProvider: { [weak self] emoji in
                    guard let self, let emojiViewProvider = self.emojiViewProvider else {
                        return nil
                    }
                    return emojiViewProvider(emoji)
                })
                customEmojiContainerView.isUserInteractionEnabled = false
                textInputNode.textView.addSubview(customEmojiContainerView)
                self.customEmojiContainerView = customEmojiContainerView
            }
            
            customEmojiContainerView.update(emojiRects: customEmojiRects)
        } else {
            if let customEmojiContainerView = self.customEmojiContainerView {
                customEmojiContainerView.removeFromSuperview()
                self.customEmojiContainerView = nil
            }
        }
    }
}
