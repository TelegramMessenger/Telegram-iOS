import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextFormat
import Markdown

final class PeerInfoScreenCommentItem: PeerInfoScreenItem {
    enum LinkAction {
        case tap(String)
    }
    
    let id: AnyHashable
    let text: String
    let linkAction: ((LinkAction) -> Void)?
    
    init(id: AnyHashable, text: String, linkAction: ((LinkAction) -> Void)? = nil) {
        self.id = id
        self.text = text
        self.linkAction = linkAction
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenCommentItemNode()
    }
}

private final class PeerInfoScreenCommentItemNode: PeerInfoScreenItemNode {
    private let textNode: ImmediateTextNode
    private var linkHighlightingNode: LinkHighlightingNode?
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenCommentItem?
    private var presentationData: PresentationData?
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.activateArea)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenCommentItem else {
            return 10.0
        }
        
        self.item = item
        self.presentationData = presentationData
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let verticalInset: CGFloat = 7.0
        
        self.textNode.maximumNumberOfLines = 0
        
        let textFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
        let textColor = presentationData.theme.list.freeTextColor
        
        let attributedText = parseMarkdownIntoAttributedString(item.text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: presentationData.theme.list.itemAccentColor), linkAttribute: { contents in
            return (TelegramTextAttributes.URL, contents)
        }))
        
        self.textNode.attributedText = attributedText
        self.activateArea.accessibilityLabel = attributedText.string
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: textSize)
        
        let height = textSize.height + verticalInset * 2.0
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        
        return height
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            let titleFrame = self.textNode.frame
                            if let item = self.item, titleFrame.contains(location) {
                                if let (_, attributes) = self.textNode.attributesAtPoint(CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)) {
                                    if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                        item.linkAction?(.tap(url))
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
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        if let _ = self.item, let presentationData = self.presentationData {
            var rects: [CGRect]?
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
                            break
                        }
                    }
                }
            }
            
            if let rects = rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: presentationData.theme.list.itemAccentColor.withAlphaComponent(0.2))
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode)
                }
                linkHighlightingNode.frame = self.textNode.frame
                linkHighlightingNode.updateRects(rects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }
}
