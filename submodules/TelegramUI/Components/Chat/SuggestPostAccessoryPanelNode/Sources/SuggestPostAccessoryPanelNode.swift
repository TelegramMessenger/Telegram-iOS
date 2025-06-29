import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import LocalizedPeerData
import PhotoResources
import TelegramStringFormatting
import TextFormat
import ChatPresentationInterfaceState
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import AccessoryPanelNode
import TelegramNotices
import AppBundle
import CompositeTextNode

public final class SuggestPostAccessoryPanelNode: AccessoryPanelNode {
    private var previousMediaReference: AnyMediaReference?
    
    public let closeButton: HighlightableButtonNode
    public let lineNode: ASImageNode
    public let iconView: UIImageView
    public let titleNode: CompositeTextNode
    public let textNode: ImmediateTextNodeWithEntities
    
    private let actionArea: AccessibilityAreaNode
    
    private let context: AccountContext
    public var theme: PresentationTheme
    public var strings: PresentationStrings
    private let dateTimeFormat: PresentationDateTimeFormat
    
    private var textIsOptions: Bool = false
    
    private var validLayout: (size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState)?
    
    private var inlineTextStarImage: UIImage?
    private var inlineTextTonImage: (UIImage, UIColor)?
    
    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, animationCache: AnimationCache?, animationRenderer: MultiAnimationRenderer?) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.accessibilityLabel = strings.VoiceOver_DiscardPreparedContent
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
        
        self.iconView = UIImageView()
        self.iconView.image = UIImage(bundleImageName: "Chat/Input/Accessory Panels/SuggestPostIcon")?.withRenderingMode(.alwaysTemplate)
        self.iconView.tintColor = theme.chat.inputPanel.panelControlAccentColor
        
        self.titleNode = CompositeTextNode()
        
        self.textNode = ImmediateTextNodeWithEntities()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        self.textNode.insets = UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0)
        self.textNode.visibility = true
        self.textNode.spoilerColor = self.theme.chat.inputPanel.secondaryTextColor
        
        if let animationCache = animationCache, let animationRenderer = animationRenderer {
            self.textNode.arguments = TextNodeWithEntities.Arguments(
                context: context,
                cache: animationCache,
                renderer: animationRenderer,
                placeholderColor: theme.list.mediaPlaceholderColor,
                attemptSynchronous: false
            )
        }
        
        self.actionArea = AccessibilityAreaNode()
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.view.addSubview(self.iconView)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.actionArea)
    }
    
    deinit {
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    override public func animateIn() {
        self.iconView.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
    }
    
    override public func animateOut() {
        self.iconView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.updateThemeAndStrings(theme: theme, strings: strings, force: false)
    }
        
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, force: Bool) {
        if self.theme !== theme || force {
            self.theme = theme
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
            
            self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
            self.iconView.tintColor = theme.chat.inputPanel.panelControlAccentColor
            
            self.titleNode.components = self.titleNode.components.map { item in
                switch item {
                case let .text(text):
                    let updatedText = NSMutableAttributedString(attributedString: text)
                    updatedText.addAttribute(.foregroundColor, value: theme.chat.inputPanel.panelControlAccentColor, range: NSRange(location: 0, length: updatedText.length))
                    return .text(updatedText)
                case let .icon(icon):
                    if let iconImage = generateTintedImage(image: icon, color: theme.chat.inputPanel.panelControlAccentColor) {
                        return .icon(iconImage)
                    } else {
                        return .icon(icon)
                    }
                }
            }
            
            if let text = self.textNode.attributedText {
                let updatedText = NSMutableAttributedString(attributedString: text)
                updatedText.addAttribute(.foregroundColor, value: self.textIsOptions ? self.theme.chat.inputPanel.secondaryTextColor : self.theme.chat.inputPanel.primaryTextColor, range: NSRange(location: 0, length: updatedText.length))
                self.textNode.attributedText = updatedText
            }
            self.textNode.spoilerColor = self.theme.chat.inputPanel.secondaryTextColor
            
            if let (size, inset, interfaceState) = self.validLayout {
                self.updateState(size: size, inset: inset, interfaceState: interfaceState)
            }
        }
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }
    
    override public func updateState(size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, inset, interfaceState)
        
        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 45.0))
        let leftInset: CGFloat = 55.0 + inset
        let textLineInset: CGFloat = 10.0
        let rightInset: CGFloat = 55.0
        let textRightInset: CGFloat = 20.0
        
        let closeButtonSize = CGSize(width: 44.0, height: bounds.height)
        let closeButtonFrame = CGRect(origin: CGPoint(x: bounds.width - closeButtonSize.width - inset, y: 2.0), size: closeButtonSize)
        self.closeButton.frame = closeButtonFrame
        
        self.actionArea.frame = CGRect(origin: CGPoint(x: leftInset, y: 2.0), size: CGSize(width: closeButtonFrame.minX - leftInset, height: bounds.height))

        if self.lineNode.supernode == self {
            self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))
        }
        
        if let icon = self.iconView.image {
            self.iconView.frame = CGRect(origin: CGPoint(x: 7.0 + inset, y: 10.0), size: icon.size)
        }
        
        let imageTextInset: CGFloat = 0.0
        
        let textFont = Font.regular(15.0)
        
        var inlineTextStarImage: UIImage?
        if let current = self.inlineTextStarImage {
            inlineTextStarImage = current
        } else {
            if let image = UIImage(bundleImageName: "Premium/Stars/StarSmall") {
                let starInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                inlineTextStarImage = generateImage(CGSize(width: starInsets.left + image.size.width + starInsets.right, height: image.size.height), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    image.draw(at: CGPoint(x: starInsets.left, y: starInsets.top))
                })?.withRenderingMode(.alwaysOriginal)
                self.inlineTextStarImage = inlineTextStarImage
            }
        }
        
        var inlineTextTonImage: UIImage?
        if let current = self.inlineTextTonImage, current.1 == self.theme.list.itemAccentColor {
            inlineTextTonImage = current.0
        } else {
            if let image = UIImage(bundleImageName: "Ads/TonMedium") {
                let tonInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                let inlineTextTonImageValue = generateTintedImage(image: generateImage(CGSize(width: tonInsets.left + image.size.width + tonInsets.right, height: image.size.height), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    UIGraphicsPushContext(context)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    image.draw(at: CGPoint(x: tonInsets.left, y: tonInsets.top))
                }), color: self.theme.list.itemAccentColor)!.withRenderingMode(.alwaysOriginal)
                inlineTextTonImage = inlineTextTonImageValue
                self.inlineTextTonImage = (inlineTextTonImageValue, self.theme.list.itemAccentColor)
            }
        }
        
        var titleText: [CompositeTextNode.Component] = []
        if let postSuggestionState = interfaceState.interfaceState.postSuggestionState, postSuggestionState.editingOriginalMessageId != nil {
            titleText.append(.text(NSAttributedString(string: self.strings.Chat_PostSuggestion_Suggest_InputEditTitle, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)))
        } else {
            titleText.append(.text(NSAttributedString(string: self.strings.Chat_PostSuggestion_Suggest_InputTitle, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)))
        }
        self.titleNode.components = titleText
        
        let titleSize = self.titleNode.update(constrainedSize: CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        if self.titleNode.supernode == self {
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset, y: 7.0), size: titleSize)
        }
        
        let textString: NSAttributedString
        if let postSuggestionState = interfaceState.interfaceState.postSuggestionState, let price = postSuggestionState.price, price.amount != .zero {
            let currencySymbol: String
            let amountString: String
            switch price.currency {
            case .stars:
                currencySymbol = "#"
                amountString = "\(price.amount)"
            case .ton:
                currencySymbol = "$"
                amountString = formatTonAmountText(price.amount.value, dateTimeFormat: self.dateTimeFormat)
            }
            if let timestamp = postSuggestionState.timestamp {
                let timeString = humanReadableStringForTimestamp(strings: interfaceState.strings, dateTimeFormat: interfaceState.dateTimeFormat, timestamp: timestamp, alwaysShowTime: true, allowYesterday: false, format: HumanReadableStringFormat(
                    dateFormatString: { value in
                        return PresentationStrings.FormattedString(string: interfaceState.strings.SuggestPost_SetTimeFormat_Date(value).string, ranges: [])
                    },
                    tomorrowFormatString: { value in
                        return PresentationStrings.FormattedString(string: interfaceState.strings.SuggestPost_SetTimeFormat_TomorrowAt(value).string, ranges: [])
                    },
                    todayFormatString: { value in
                        return PresentationStrings.FormattedString(string: interfaceState.strings.SuggestPost_SetTimeFormat_TodayAt(value).string, ranges: [])
                    },
                    yesterdayFormatString: { value in
                        return PresentationStrings.FormattedString(string: interfaceState.strings.SuggestPost_SetTimeFormat_TodayAt(value).string, ranges: [])
                    }
                )).string
                textString = NSAttributedString(string: "\(currencySymbol)\(amountString)  📅 \(timeString)", font: textFont, textColor: self.theme.chat.inputPanel.primaryTextColor)
            } else {
                textString = NSAttributedString(string: self.strings.Chat_PostSuggestion_Suggest_InputSubtitleAnytime("\(currencySymbol)\(amountString)").string, font: textFont, textColor: self.theme.chat.inputPanel.primaryTextColor)
            }
        } else {
            textString = NSAttributedString(string: self.strings.Chat_PostSuggestion_Suggest_InputSubtitleEmpty, font: textFont, textColor: self.theme.chat.inputPanel.primaryTextColor)
        }
        
        let mutableTextString = NSMutableAttributedString(attributedString: textString)
        for currency in [.stars, .ton] as [CurrencyAmount.Currency] {
            let currencySymbol: String
            let currencyImage: UIImage?
            switch currency {
            case .stars:
                currencySymbol = "#"
                currencyImage = inlineTextStarImage
            case .ton:
                currencySymbol = "$"
                currencyImage = inlineTextTonImage
            }
            
            if let range = mutableTextString.string.range(of: currencySymbol), let currencyImage {
                final class RunDelegateData {
                    let ascent: CGFloat
                    let descent: CGFloat
                    let width: CGFloat
                    
                    init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
                        self.ascent = ascent
                        self.descent = descent
                        self.width = width
                    }
                }
                
                let runDelegateData = RunDelegateData(
                    ascent: Font.regular(15.0).ascender,
                    descent: Font.regular(15.0).descender,
                    width: currencyImage.size.width + 2.0
                )
                var callbacks = CTRunDelegateCallbacks(
                    version: kCTRunDelegateCurrentVersion,
                    dealloc: { dataRef in
                        Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                    },
                    getAscent: { dataRef in
                        let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                        return data.takeUnretainedValue().ascent
                    },
                    getDescent: { dataRef in
                        let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                        return data.takeUnretainedValue().descent
                    },
                    getWidth: { dataRef in
                        let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                        return data.takeUnretainedValue().width
                    }
                )
                if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
                    mutableTextString.addAttribute(NSAttributedString.Key(kCTRunDelegateAttributeName as String), value: runDelegate, range: NSRange(range, in: mutableTextString.string))
                }
                mutableTextString.addAttribute(.attachment, value: currencyImage, range: NSRange(range, in: mutableTextString.string))
                mutableTextString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xffffff), range: NSRange(range, in: mutableTextString.string))
                mutableTextString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: mutableTextString.string))
            }
        }
        
        self.textNode.attributedText = mutableTextString
        
        let textSize = self.textNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset - imageTextInset, height: bounds.size.height))
        let textFrame = CGRect(origin: CGPoint(x: leftInset + textLineInset + imageTextInset - self.textNode.insets.left, y: 25.0 - self.textNode.insets.top), size: textSize)
        if self.textNode.supernode == self {
            self.textNode.frame = textFrame
        }
    }
    
    @objc private func closePressed() {
        if let dismiss = self.dismiss {
            dismiss()
        }
    }
    
    private var previousTapTimestamp: Double?
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let timestamp = CFAbsoluteTimeGetCurrent()
            if let previousTapTimestamp = self.previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                return
            }
            self.previousTapTimestamp = CFAbsoluteTimeGetCurrent()
            self.interfaceInteraction?.presentSuggestPostOptions()
            Queue.mainQueue().after(1.5) {
                self.updateThemeAndStrings(theme: self.theme, strings: self.strings, force: true)
            }
        }
    }
}
