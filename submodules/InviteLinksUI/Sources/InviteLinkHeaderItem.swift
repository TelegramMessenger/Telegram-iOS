import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AccountContext
import Markdown
import TextFormat

public class InviteLinkHeaderItem: ListViewItem, ItemListItem {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let title: String?
    public let text: String
    public let animationName: String
    public let hideOnSmallScreens: Bool
    public let sectionId: ItemListSectionId
    public let linkAction: ((ItemListTextItemLinkAction) -> Void)?
    
    public init(context: AccountContext, theme: PresentationTheme, title: String? = nil, text: String, animationName: String, hideOnSmallScreens: Bool = false, sectionId: ItemListSectionId, linkAction: ((ItemListTextItemLinkAction) -> Void)? = nil) {
        self.context = context
        self.theme = theme
        self.title = title
        self.text = text
        self.animationName = animationName
        self.hideOnSmallScreens = hideOnSmallScreens
        self.sectionId = sectionId
        self.linkAction = linkAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = InviteLinkHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? InviteLinkHeaderItemNode else {
                assertionFailure()
                return
            }
            
            let makeLayout = nodeValue.asyncLayout()
            
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

private let titleFont = Font.semibold(17.0)
private let textFont = Font.regular(14.0)

class InviteLinkHeaderItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let textNode: TextNode
    private var animationNode: AnimatedStickerNode
    
    private var item: InviteLinkHeaderItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.animationNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    func asyncLayout() -> (_ item: InviteLinkHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 24.0 + params.leftInset
            let iconSize: CGSize
            if params.width > params.availableHeight && params.width > 320.0 {
                iconSize = CGSize(width: 140.0, height: 140.0)
            } else {
                if item.hideOnSmallScreens {
                    iconSize = .zero
                } else {
                    iconSize = CGSize(width: 124.0, height: 124.0)
                }
            }
            let topInset: CGFloat = iconSize.height - 4.0
            let spacing: CGFloat = 5.0
            
            let attributedTitle = NSAttributedString(string: item.title ?? "", font: titleFont, textColor: item.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
            
            let attributedText = parseMarkdownIntoAttributedString(item.text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: item.theme.list.freeTextColor), bold: MarkdownAttributeSet(font: textFont, textColor: item.theme.list.freeTextColor), link: MarkdownAttributeSet(font: textFont, textColor: item.theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            }))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedTitle, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            var contentSize = CGSize(width: params.width, height: topInset + textLayout.size.height)
            if let _ = item.title {
                contentSize.height += titleLayout.size.height + spacing
            }
                        
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    if strongSelf.item == nil {
                        strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: item.animationName), width: 256, height: 256, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                        strongSelf.animationNode.visibility = true
                    }
                    strongSelf.item = item
                    strongSelf.accessibilityLabel = attributedText.string
                                        
                    strongSelf.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: -10.0), size: iconSize)
                    strongSelf.animationNode.updateLayout(size: iconSize)
                    
                    var origin: CGFloat = topInset + 8.0
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleLayout.size.width) / 2.0), y: origin), size: titleLayout.size)
                    if titleLayout.size.height > 0.0 {
                        origin += titleLayout.size.height + spacing
                    }
                    
                    let _ = textApply()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - textLayout.size.width) / 2.0), y: origin), size: textLayout.size)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            let textFrame = self.textNode.frame
                            if let item = self.item, textFrame.contains(location) {
                                if let (_, attributes) = self.textNode.attributesAtPoint(CGPoint(x: location.x - textFrame.minX, y: location.y - textFrame.minY)) {
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
}
