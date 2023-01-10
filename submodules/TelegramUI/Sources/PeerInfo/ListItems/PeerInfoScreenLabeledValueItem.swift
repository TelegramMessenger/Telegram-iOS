import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import TextFormat
import UIKit
import AppBundle
import TelegramStringFormatting
import ContextUI

enum PeerInfoScreenLabeledValueTextColor {
    case primary
    case accent
}

enum PeerInfoScreenLabeledValueTextBehavior: Equatable {
    case singleLine
    case multiLine(maxLines: Int, enabledEntities: EnabledEntityTypes)
}

enum PeerInfoScreenLabeledValueIcon {
    case qrCode
}

final class PeerInfoScreenLabeledValueItem: PeerInfoScreenItem {
    let id: AnyHashable
    let label: String
    let text: String
    let additionalText: String?
    let textColor: PeerInfoScreenLabeledValueTextColor
    let textBehavior: PeerInfoScreenLabeledValueTextBehavior
    let icon: PeerInfoScreenLabeledValueIcon?
    let action: ((ASDisplayNode) -> Void)?
    let longTapAction: ((ASDisplayNode) -> Void)?
    let linkItemAction: ((TextLinkItemActionType, TextLinkItem, ASDisplayNode, CGRect?) -> Void)?
    let iconAction: (() -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    let requestLayout: () -> Void
    
    init(
        id: AnyHashable,
        label: String,
        text: String,
        additionalText: String? = nil,
        textColor: PeerInfoScreenLabeledValueTextColor = .primary,
        textBehavior: PeerInfoScreenLabeledValueTextBehavior = .singleLine,
        icon: PeerInfoScreenLabeledValueIcon? = nil,
        action: ((ASDisplayNode) -> Void)?,
        longTapAction: ((ASDisplayNode) -> Void)? = nil,
        linkItemAction: ((TextLinkItemActionType, TextLinkItem, ASDisplayNode, CGRect?) -> Void)? = nil,
        iconAction: (() -> Void)? = nil,
        contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)? = nil,
        requestLayout: @escaping () -> Void
    ) {
        self.id = id
        self.label = label
        self.text = text
        self.additionalText = additionalText
        self.textColor = textColor
        self.textBehavior = textBehavior
        self.icon = icon
        self.action = action
        self.longTapAction = longTapAction
        self.linkItemAction = linkItemAction
        self.iconAction = iconAction
        self.contextAction = contextAction
        self.requestLayout = requestLayout
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenLabeledValueItemNode()
    }
}

private func generateExpandBackground(size: CGSize, color: UIColor) -> UIImage? {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colors: [CGColor] = [color.withAlphaComponent(0.0).cgColor, color.cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 40.0, y: size.height), options: CGGradientDrawingOptions())
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(x: 40.0, y: 0.0), size: CGSize(width: size.width - 40.0, height: size.height)))
    })
}

private final class PeerInfoScreenLabeledValueItemNode: PeerInfoScreenItemNode {
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let labelNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let additionalTextNode: ImmediateTextNode
    private let measureTextNode: ImmediateTextNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private let expandBackgroundNode: ASImageNode
    private let expandNode: ImmediateTextNode
    private let expandButonNode: HighlightTrackingButtonNode
    
    private let iconNode: ASImageNode
    private let iconButtonNode: HighlightTrackingButtonNode
    
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenLabeledValueItem?
    private var theme: PresentationTheme?
    
    private var isExpanded: Bool = false
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        self.selectionNode.isUserInteractionEnabled = false
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.additionalTextNode = ImmediateTextNode()
        self.additionalTextNode.displaysAsynchronously = false
        self.additionalTextNode.isUserInteractionEnabled = false
        
        self.measureTextNode = ImmediateTextNode()
        self.measureTextNode.displaysAsynchronously = false
        self.measureTextNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.expandBackgroundNode = ASImageNode()
        self.expandBackgroundNode.displaysAsynchronously = false
        
        self.expandNode = ImmediateTextNode()
        self.expandNode.displaysAsynchronously = false
        self.expandNode.isUserInteractionEnabled = false
        
        self.expandButonNode = HighlightTrackingButtonNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.contentMode = .center
        self.iconNode.displaysAsynchronously = false
        
        self.iconButtonNode = HighlightTrackingButtonNode()
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.addSubnode(self.maskNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.labelNode)
        self.contextSourceNode.contentNode.addSubnode(self.textNode)
        self.contextSourceNode.contentNode.addSubnode(self.additionalTextNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.expandBackgroundNode)
        self.contextSourceNode.contentNode.addSubnode(self.expandNode)
        self.contextSourceNode.contentNode.addSubnode(self.expandButonNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.iconNode)
        self.contextSourceNode.contentNode.addSubnode(self.iconButtonNode)
        
        self.addSubnode(self.activateArea)
        
        self.expandButonNode.addTarget(self, action: #selector(self.expandPressed), forControlEvents: .touchUpInside)
        self.expandButonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.expandNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.expandNode.alpha = 0.4
                } else {
                    strongSelf.expandNode.alpha = 1.0
                    strongSelf.expandNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.iconButtonNode.addTarget(self, action: #selector(self.iconPressed), forControlEvents: .touchUpInside)
        self.iconButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.iconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.iconNode.alpha = 0.4
                } else {
                    strongSelf.iconNode.alpha = 1.0
                    strongSelf.iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextSourceNode, gesture, nil)
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let theme = strongSelf.theme else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: theme.list.plainBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    @objc private func expandPressed() {
        self.isExpanded = true
        self.item?.requestLayout()
    }
    
    @objc private func iconPressed() {
        self.item?.iconAction?()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            guard let strongSelf = self, let item = strongSelf.item else {
                return .keepWithSingleTap
            }
            if !strongSelf.iconButtonNode.isHidden, strongSelf.iconButtonNode.view.hitTest(strongSelf.view.convert(point, to: strongSelf.iconButtonNode.view), with: nil) != nil {
                return .fail
            }
            if !strongSelf.expandButonNode.isHidden, strongSelf.expandButonNode.view.hitTest(strongSelf.view.convert(point, to: strongSelf.expandButonNode.view), with: nil) != nil {
                return .fail
            }
            if let _ = strongSelf.linkItemAtPoint(point) {
                return .waitForSingleTap
            }
            if item.longTapAction != nil {
                return .waitForSingleTap
            }
            if item.action != nil {
                return .keepWithSingleTap
            }
            return .fail
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.iconButtonNode.isHidden, let point = point, strongSelf.iconButtonNode.frame.contains(point) {
            } else {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap, .longTap:
                    if let item = self.item {
                        if let linkItem = self.linkItemAtPoint(location) {
                            item.linkItemAction?(gesture == .tap ? .tap : .longTap, linkItem, self.linkHighlightingNode ?? self, self.linkHighlightingNode?.rects.first)
                        } else if case .longTap = gesture {
                            item.longTapAction?(self)
                        } else if case .tap = gesture {
                            item.action?(self.contextSourceNode)
                        }
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenLabeledValueItem else {
            return 10.0
        }
        
        self.item = item
        self.theme = presentationData.theme
        
        if let action = item.action {
            self.selectionNode.pressed = { [weak self] in
                if let strongSelf = self {
                    action(strongSelf.contextSourceNode)
                }
            }
        } else {
            self.selectionNode.pressed = nil
        }
                
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let textColorValue: UIColor
        switch item.textColor {
        case .primary:
            textColorValue = presentationData.theme.list.itemPrimaryTextColor
        case .accent:
            textColorValue = presentationData.theme.list.itemAccentColor
        }
        
        self.expandNode.attributedText = NSAttributedString(string: presentationData.strings.PeerInfo_BioExpand, font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor)
        let expandSize = self.expandNode.updateLayout(CGSize(width: width, height: 100.0))
        
        self.labelNode.attributedText = NSAttributedString(string: item.label, font: Font.regular(14.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
        
        if let icon = item.icon {
            let iconImage: UIImage?
            switch icon {
            case .qrCode:
                iconImage = UIImage(bundleImageName: "Settings/QrIcon")
            }
            self.iconNode.image = generateTintedImage(image: iconImage, color: presentationData.theme.list.itemAccentColor)
            self.iconNode.isHidden = false
            self.iconButtonNode.isHidden = false
        } else {
            self.iconNode.isHidden = true
            self.iconButtonNode.isHidden = true
        }
        
        let additionalSideInset: CGFloat = !self.iconNode.isHidden ? 32.0 : 0.0
        
        var text = item.text
        let maxNumberOfLines: Int
        switch item.textBehavior {
        case .singleLine:
            maxNumberOfLines = 1
            self.textNode.maximumNumberOfLines = maxNumberOfLines
            self.textNode.cutout = nil
            self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: textColorValue)
            
            let fontSize: CGFloat = 15.0
            
            let baseFont = Font.regular(fontSize)
            let linkFont = baseFont
            let boldFont = Font.medium(fontSize)
            let italicFont = Font.italic(fontSize)
            let boldItalicFont = Font.semiboldItalic(fontSize)
            let titleFixedFont = Font.monospace(fontSize)
            
            if let additionalText = item.additionalText {
                let entities = generateTextEntities(additionalText, enabledTypes: [.mention])
                let attributedAdditionalText = stringWithAppliedEntities(additionalText, entities: entities, baseColor: presentationData.theme.list.itemPrimaryTextColor, linkColor: presentationData.theme.list.itemAccentColor, baseFont: baseFont, linkFont: linkFont, boldFont: boldFont, italicFont: italicFont, boldItalicFont: boldItalicFont, fixedFont: titleFixedFont, blockQuoteFont: baseFont, underlineLinks: false, message: nil)
                
                self.additionalTextNode.maximumNumberOfLines = 3
                self.additionalTextNode.attributedText = attributedAdditionalText
            } else {
                self.additionalTextNode.attributedText = nil
            }
        case let .multiLine(maxLines, enabledEntities):
            let originalText = text
            if !self.isExpanded {
                text = trimToLineCount(text, lineCount: 3)
            }
            
            func createAttributedText(_ text: String) -> NSAttributedString {
                if enabledEntities.isEmpty {
                    return NSAttributedString(string: text, font: Font.regular(17.0), textColor: textColorValue)
                } else {
                    let fontSize: CGFloat = 17.0
                    
                    let baseFont = Font.regular(fontSize)
                    let linkFont = baseFont
                    let boldFont = Font.medium(fontSize)
                    let italicFont = Font.italic(fontSize)
                    let boldItalicFont = Font.semiboldItalic(fontSize)
                    let titleFixedFont = Font.monospace(fontSize)
                    
                    let entities = generateTextEntities(text, enabledTypes: enabledEntities)
                    return stringWithAppliedEntities(text, entities: entities, baseColor: textColorValue, linkColor: presentationData.theme.list.itemAccentColor, baseFont: baseFont, linkFont: linkFont, boldFont: boldFont, italicFont: italicFont, boldItalicFont: boldItalicFont, fixedFont: titleFixedFont, blockQuoteFont: baseFont, message: nil)
                }
            }
                        
            self.measureTextNode.maximumNumberOfLines = 0
            self.measureTextNode.attributedText = createAttributedText(originalText)
            
            let textLayout = self.measureTextNode.updateLayoutInfo(CGSize(width: width - sideInset * 2.0 - additionalSideInset, height: .greatestFiniteMagnitude))
            var collapsedNumberOfLines = 3
            if textLayout.numberOfLines == 4 {
                collapsedNumberOfLines = 4
            }
            
            self.textNode.attributedText = createAttributedText(text)
            
            maxNumberOfLines = self.isExpanded ? maxLines : collapsedNumberOfLines
            self.textNode.maximumNumberOfLines = maxNumberOfLines
        }
        

        let labelSize = self.labelNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let textLayout = self.textNode.updateLayoutInfo(CGSize(width: width - sideInset * 2.0 - additionalSideInset, height: .greatestFiniteMagnitude))
        let textSize = textLayout.size
        
        let additionalTextSize = self.additionalTextNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        var displayMore = false
        if !self.isExpanded {
            if textLayout.truncated || text.count < item.text.count {
                displayMore = true
            }
        }
        
        if case .multiLine = item.textBehavior, displayMore {
            self.expandBackgroundNode.isHidden = false
            self.expandNode.isHidden = false
            self.expandButonNode.isHidden = false
        } else {
            self.expandBackgroundNode.isHidden = true
            self.expandNode.isHidden = true
            self.expandButonNode.isHidden = true
        }
        
        let labelFrame = CGRect(origin: CGPoint(x: sideInset, y: 11.0), size: labelSize)
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: labelFrame.maxY + 3.0), size: textSize)
        let additionalTextFrame = CGRect(origin: CGPoint(x: sideInset, y: textFrame.maxY + 3.0), size: additionalTextSize)
        
        let expandFrame = CGRect(origin: CGPoint(x: width - safeInsets.right - expandSize.width - 14.0 - UIScreenPixel, y: textFrame.maxY - expandSize.height), size: expandSize)
        self.expandNode.frame = expandFrame
        self.expandButonNode.frame = expandFrame.insetBy(dx: -8.0, dy: -8.0)
        
        var expandBackgroundFrame = expandFrame
        expandBackgroundFrame.origin.x -= 50.0
        expandBackgroundFrame.size.width += 50.0
        self.expandBackgroundNode.frame = expandBackgroundFrame
        self.expandBackgroundNode.image = generateExpandBackground(size: expandBackgroundFrame.size, color: presentationData.theme.list.itemBlocksBackgroundColor)
        
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        var textTransition = transition
        if self.textNode.frame.size != textFrame.size {
            textTransition = .immediate
        }
        textTransition.updateFrame(node: self.textNode, frame: textFrame)
        
        transition.updateFrame(node: self.additionalTextNode, frame: additionalTextFrame)
        
        var height = labelSize.height + 3.0 + textSize.height + 22.0
        
        let iconButtonFrame = CGRect(x: width - safeInsets.right - height, y: 0.0, width: height, height: height)
        transition.updateFrame(node: self.iconButtonNode, frame: iconButtonFrame)
        if let iconSize = self.iconNode.image?.size {
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: width - safeInsets.right - sideInset - iconSize.width + 5.0, y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize))
        }
        
        if additionalTextSize.height > 0.0 {
            height += additionalTextSize.height + 3.0
        }
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        self.activateArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: height))
        self.activateArea.accessibilityLabel = item.label
        self.activateArea.accessibilityValue = item.text
        
        
        let contentSize = CGSize(width: width, height: height)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.containerNode.isGestureEnabled = item.contextAction != nil
        
        let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: contentSize.height))
        let extractedRect = nonExtractedRect
        self.extractedRect = extractedRect
        self.nonExtractedRect = nonExtractedRect
        
        if self.contextSourceNode.isExtractedToContextPreview {
            self.extractedBackgroundImageNode.frame = extractedRect
        } else {
            self.extractedBackgroundImageNode.frame = nonExtractedRect
        }
        self.contextSourceNode.contentRect = extractedRect
        
        return height
    }
    
    private func linkItemAtPoint(_ point: CGPoint) -> TextLinkItem? {
        let textNodeFrame = self.textNode.frame
        if let (_, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                return .url(url: url, concealed: false)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .mention(peerName)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return nil
            }
        }
        let additionalTextNodeFrame = self.additionalTextNode.frame
        if let (_, attributes) = self.additionalTextNode.attributesAtPoint(CGPoint(x: point.x - additionalTextNodeFrame.minX, y: point.y - additionalTextNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                return .url(url: url, concealed: false)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .mention(peerName)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return nil
            }
        }
        return nil
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item, let theme = self.theme else {
            return
        }
        var rects: [CGRect]?
        var textNode: ASDisplayNode?
        if let point = point {
            let textNodeFrame = self.textNode.frame
            if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                let possibleNames: [String] = [
                    TelegramTextAttributes.URL,
                    TelegramTextAttributes.PeerMention,
                    TelegramTextAttributes.PeerTextMention,
                    TelegramTextAttributes.BotCommand,
                    TelegramTextAttributes.Hashtag
                ]
                for name in possibleNames {
                    if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                        rects = self.textNode.attributeRects(name: name, at: index)
                        textNode = self.textNode
                        break
                    }
                }
            }
            if textNode == nil {
                let additionalTextNodeFrame = self.additionalTextNode.frame
                let mappedPoint = CGPoint(x: point.x - additionalTextNodeFrame.minX, y: point.y - additionalTextNodeFrame.minY)
                if mappedPoint.y > 0.0, let (index, attributes) = self.additionalTextNode.attributesAtPoint(mappedPoint) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.additionalTextNode.attributeRects(name: name, at: index)
                            textNode = self.additionalTextNode
                            break
                        }
                    }
                }
            }
        }
        
        if let rects = rects, let textNode = textNode {
            let linkHighlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                linkHighlightingNode = current
            } else {
                linkHighlightingNode = LinkHighlightingNode(color: theme.list.itemAccentColor.withAlphaComponent(0.5))
                self.linkHighlightingNode = linkHighlightingNode
                self.contextSourceNode.contentNode.insertSubnode(linkHighlightingNode, belowSubnode: textNode)
            }
            linkHighlightingNode.frame = textNode.frame
            linkHighlightingNode.updateRects(rects)
        } else if let linkHighlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                linkHighlightingNode?.removeFromSupernode()
            })
        }
        
        if point != nil && rects == nil && item.action != nil {
            self.selectionNode.updateIsHighlighted(true)
        } else {
            self.selectionNode.updateIsHighlighted(false)
        }
    }
}
