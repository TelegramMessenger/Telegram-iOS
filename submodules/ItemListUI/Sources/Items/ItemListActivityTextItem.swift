import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ActivityIndicator
import TextFormat
import Markdown

public class ItemListActivityTextItem: ListViewItem, ItemListItem {
    public enum TextColor {
        case generic
        case constructive
        case destructive
        case warning
    }
    
    let displayActivity: Bool
    let presentationData: ItemListPresentationData
    let text: String
    let color: TextColor
    let linkAction: ((ItemListTextItemLinkAction) -> Void)?
    public let sectionId: ItemListSectionId
    
    public let isAlwaysPlain: Bool = true
    
    public init(displayActivity: Bool, presentationData: ItemListPresentationData, text: String, color: TextColor, linkAction: ((ItemListTextItemLinkAction) -> Void)? = nil, sectionId: ItemListSectionId) {
        self.displayActivity = displayActivity
        self.presentationData = presentationData
        self.text = text
        self.color = color
        self.linkAction = linkAction
        self.sectionId = sectionId
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListActivityTextItemNode()
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
            guard let nodeValue = node() as? ItemListActivityTextItemNode else {
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

public class ItemListActivityTextItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let activityIndicator: ActivityIndicator
    
    private var item: ItemListActivityTextItem?
    
    public init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.activityIndicator = ActivityIndicator(type: ActivityIndicatorType.custom(.black, 16.0, 2.0, false))
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.activityIndicator)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    public func asyncLayout() -> (_ item: ItemListActivityTextItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 15.0 + params.leftInset
            let verticalInset: CGFloat = 7.0
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            
            var activityWidth: CGFloat = 0.0
            if item.displayActivity {
                activityWidth = 25.0
            }
            
            let textColor: UIColor
            switch item.color {
            case .generic:
                textColor = item.presentationData.theme.list.freeTextColor
            case .constructive:
                textColor = item.presentationData.theme.list.freeTextSuccessColor
            case .destructive:
                textColor = item.presentationData.theme.list.freeTextErrorColor
            case .warning:
                textColor = UIColor(rgb: 0xef8c00)
            }
            
            let attributedString = parseMarkdownIntoAttributedString(item.text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: textColor), bold: MarkdownAttributeSet(font: titleFont, textColor: item.presentationData.theme.list.freeTextErrorColor), link: MarkdownAttributeSet(font: titleFont, textColor: item.presentationData.theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            }))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - 22.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: TextNodeCutout(topLeft: CGSize(width: activityWidth, height: 22.0)), insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            
            contentSize = CGSize(width: params.width, height: titleLayout.size.height + verticalInset + verticalInset)
            insets = itemListNeighborsPlainInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                    strongSelf.activityIndicator.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((contentSize.height - 16.0) / 2.0)), size: CGSize(width: 16.0, height: 16.0))
                    
                    strongSelf.activityIndicator.type = .custom(item.presentationData.theme.list.itemAccentColor, 16.0, 2.0, false)
                    
                    if item.displayActivity {
                        strongSelf.activityIndicator.isHidden = false
                    } else {
                        strongSelf.activityIndicator.isHidden = true
                    }
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            let titleFrame = self.titleNode.frame
                            if let item = self.item, titleFrame.contains(location) {
                                if let (_, attributes) = self.titleNode.attributesAtPoint(CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)) {
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
