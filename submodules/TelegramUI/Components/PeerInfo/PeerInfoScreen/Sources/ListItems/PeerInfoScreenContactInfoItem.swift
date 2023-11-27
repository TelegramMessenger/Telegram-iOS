import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import TextFormat
import UIKit
import AppBundle
import TelegramStringFormatting
import ContextUI

final class PeerInfoScreenContactInfoItem: PeerInfoScreenItem {
    let id: AnyHashable
    let username: String
    let phoneNumber: String
    let additionalText: String?
    let usernameAction: ((ASDisplayNode) -> Void)?
    let usernameLongTapAction: ((ASDisplayNode) -> Void)?
    let phoneAction: ((ASDisplayNode) -> Void)?
    let phoneLongTapAction: ((ASDisplayNode) -> Void)?
    let linkItemAction: ((TextLinkItemActionType, TextLinkItem, ASDisplayNode, CGRect?) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    let requestLayout: () -> Void
    
    init(
        id: AnyHashable,
        username: String,
        phoneNumber: String,
        additionalText: String? = nil,
        usernameAction: ((ASDisplayNode) -> Void)?,
        usernameLongTapAction: ((ASDisplayNode) -> Void)?,
        phoneAction: ((ASDisplayNode) -> Void)?,
        phoneLongTapAction: ((ASDisplayNode) -> Void)?,
        linkItemAction: ((TextLinkItemActionType, TextLinkItem, ASDisplayNode, CGRect?) -> Void)? = nil,
        contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)? = nil,
        requestLayout: @escaping () -> Void
    ) {
        self.id = id
        self.username = username
        self.phoneNumber = phoneNumber
        self.additionalText = additionalText
        self.usernameAction = usernameAction
        self.usernameLongTapAction = usernameLongTapAction
        self.phoneAction = phoneAction
        self.phoneLongTapAction = phoneLongTapAction
        self.linkItemAction = linkItemAction
        self.contextAction = contextAction
        self.requestLayout = requestLayout
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenContactInfoItemNode()
    }
}

private final class PeerInfoScreenContactInfoItemNode: PeerInfoScreenItemNode {
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let usernameNode: ImmediateTextNode
    private let phoneNumberNode: ImmediateTextNode
    private let additionalTextNode: ImmediateTextNode
    private let measureTextNode: ImmediateTextNode
    private let bottomSeparatorNode: ASDisplayNode
            
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenContactInfoItem?
    private var theme: PresentationTheme?
        
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
        
        self.usernameNode = ImmediateTextNode()
        self.usernameNode.displaysAsynchronously = false
        self.usernameNode.isUserInteractionEnabled = false
        
        self.phoneNumberNode = ImmediateTextNode()
        self.phoneNumberNode.displaysAsynchronously = false
        self.phoneNumberNode.isUserInteractionEnabled = false
        
        self.additionalTextNode = ImmediateTextNode()
        self.additionalTextNode.displaysAsynchronously = false
        self.additionalTextNode.isUserInteractionEnabled = false
        
        self.measureTextNode = ImmediateTextNode()
        self.measureTextNode.displaysAsynchronously = false
        self.measureTextNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
                                        
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
        
        self.contextSourceNode.contentNode.addSubnode(self.usernameNode)
        self.contextSourceNode.contentNode.addSubnode(self.phoneNumberNode)
        self.contextSourceNode.contentNode.addSubnode(self.additionalTextNode)
        
       
        self.addSubnode(self.activateArea)
                
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
            
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            guard let strongSelf = self else {
                return .keepWithSingleTap
            }
            if let _ = strongSelf.linkItemAtPoint(point) {
                return .waitForSingleTap
            }
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateTouchesAtPoint(point)
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
                            if self.usernameNode.frame.insetBy(dx: -10.0, dy: -10.0).contains(location) {
                                item.usernameLongTapAction?(self.usernameNode)
                            } else if self.phoneNumberNode.frame.insetBy(dx: -10.0, dy: -10.0).contains(location) {
                                item.phoneLongTapAction?(self.phoneNumberNode)
                            }
                        } else if case .tap = gesture {
                            if self.usernameNode.frame.insetBy(dx: -10.0, dy: -10.0).contains(location) {
                                item.usernameAction?(self.contextSourceNode)
                            } else if self.phoneNumberNode.frame.insetBy(dx: -10.0, dy: -10.0).contains(location) {
                                item.phoneAction?(self.contextSourceNode)
                            }
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
    
    private func linkItemAtPoint(_ point: CGPoint) -> TextLinkItem? {
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
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenContactInfoItem else {
            return 10.0
        }
        
        self.item = item
        self.theme = presentationData.theme
        
//        if let action = item.action {
//            self.selectionNode.pressed = { [weak self] in
//                if let strongSelf = self {
//                    action(strongSelf.contextSourceNode)
//                }
//            }
//        } else {
//            self.selectionNode.pressed = nil
//        }
                
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
           
        self.usernameNode.attributedText = NSAttributedString(string: item.username, font: Font.regular(15.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
                
        self.phoneNumberNode.maximumNumberOfLines = 1
        self.phoneNumberNode.cutout = nil
        self.phoneNumberNode.attributedText = NSAttributedString(string: item.phoneNumber, font: Font.regular(15.0), textColor: presentationData.theme.list.itemAccentColor)
        
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
            
            self.additionalTextNode.maximumNumberOfLines = 10
            self.additionalTextNode.attributedText = attributedAdditionalText
        } else {
            self.additionalTextNode.attributedText = nil
        }
        

        let usernameSize = self.usernameNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let phoneSize = self.phoneNumberNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let additionalTextSize = self.additionalTextNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let topOffset = 12.0
        var height = topOffset * 2.0
        let usernameFrame = CGRect(origin: CGPoint(x: sideInset, y: topOffset), size: usernameSize)
        let phoneFrame = CGRect(origin: CGPoint(x: usernameSize.width > 0.0 ? width - sideInset - phoneSize.width : sideInset, y: topOffset), size: phoneSize)
        let textHeight = max(usernameSize.height, phoneSize.height)
        height += textHeight
                
        let additionalTextFrame = CGRect(origin: CGPoint(x: sideInset, y: topOffset + textHeight + 3.0), size: additionalTextSize)
        transition.updateFrame(node: self.usernameNode, frame: usernameFrame)
    
        transition.updateFrame(node: self.phoneNumberNode, frame: phoneFrame)
        
        transition.updateFrame(node: self.additionalTextNode, frame: additionalTextFrame)
        
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
        self.activateArea.accessibilityLabel = item.username
        self.activateArea.accessibilityValue = item.phoneNumber
        
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
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let _ = self.item, let theme = self.theme else {
            return
        }
        var rects: [CGRect]?
        var textNode: ASDisplayNode?
        if let point = point {
            if self.usernameNode.frame.insetBy(dx: -10.0, dy: -10.0).contains(point) {
                textNode = self.usernameNode
                rects = [self.usernameNode.bounds]
            } else if self.phoneNumberNode.frame.insetBy(dx: -10.0, dy: -10.0).contains(point) {
                textNode = self.phoneNumberNode
                rects = [self.phoneNumberNode.bounds]
            } else if self.additionalTextNode.frame.contains(point) {
                let mappedPoint = CGPoint(x: point.x - self.additionalTextNode.frame.minX, y: point.y - self.additionalTextNode.frame.minY)
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
                linkHighlightingNode = LinkHighlightingNode(color: theme.list.itemAccentColor.withAlphaComponent(0.2))
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
    }
}
