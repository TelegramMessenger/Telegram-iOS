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
import SolidRoundedButtonNode

class RecentSessionsHeaderItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let text: String
    let animationName: String
    let sectionId: ItemListSectionId
    let buttonAction: () -> Void
    let linkAction: ((ItemListTextItemLinkAction) -> Void)?
    
    init(context: AccountContext, theme: PresentationTheme, text: String, animationName: String, sectionId: ItemListSectionId, buttonAction: @escaping () -> Void, linkAction: ((ItemListTextItemLinkAction) -> Void)? = nil) {
        self.context = context
        self.theme = theme
        self.text = text
        self.animationName = animationName
        self.sectionId = sectionId
        self.buttonAction = buttonAction
        self.linkAction = linkAction
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = RecentSessionsHeaderItemNode()
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
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? RecentSessionsHeaderItemNode else {
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

private let titleFont = Font.regular(13.0)

class RecentSessionsHeaderItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private var animationNode: AnimatedStickerNode
    private let buttonNode: SolidRoundedButtonNode
    
    private var item: RecentSessionsHeaderItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), fontSize: 16.0, height: 50.0, cornerRadius: 11.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.buttonNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.titleNode.view.addGestureRecognizer(recognizer)
        
        self.buttonNode.pressed = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                item.buttonAction()
            }
        }
    }
    
    func asyncLayout() -> (_ item: RecentSessionsHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            let leftInset: CGFloat = 32.0 + params.leftInset
            let topInset: CGFloat = 124.0
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let attributedText = parseMarkdownIntoAttributedString(item.text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: item.theme.list.freeTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: item.theme.list.freeTextColor), link: MarkdownAttributeSet(font: titleFont, textColor: item.theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            }))
                
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: topInset + titleLayout.size.height + 69.0)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    if strongSelf.item == nil {
                        strongSelf.animationNode.autoplay = true
                        strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: item.animationName), width: 256, height: 256, playbackMode: .still(.start), mode: .direct(cachePathPrefix: nil))
                        strongSelf.animationNode.visibility = true
                        Queue.mainQueue().after(0.3) {
                            strongSelf.animationNode.play(firstFrame: false, fromIndex: nil)
                        }
                    }
                    strongSelf.item = item
                    
                    strongSelf.buttonNode.title = item.context.sharedContext.currentPresentationData.with { $0 }.strings.AuthSessions_LinkDesktopDevice
                    if let _ = updatedTheme {
                        strongSelf.buttonNode.icon = UIImage(bundleImageName: "Settings/QrButtonIcon")
                        strongSelf.buttonNode.updateTheme(SolidRoundedButtonTheme(theme: item.theme))
                    }
                    
                    let inset = max(16.0, params.leftInset)
                    let buttonWidth = min(375, contentSize.width - inset - inset)
                    let buttonHeight = strongSelf.buttonNode.updateLayout(width: buttonWidth, transition: .immediate)
                    let buttonFrame = CGRect(x: floorToScreenPixels((params.width - buttonWidth) / 2.0), y: contentSize.height - buttonHeight + 4.0, width: buttonWidth, height: buttonHeight)
                    strongSelf.buttonNode.frame = buttonFrame
                    
                    strongSelf.accessibilityLabel = attributedText.string
                                        
                    let iconSize = CGSize(width: 128.0, height: 128.0)
                    strongSelf.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: -10.0), size: iconSize)
                    strongSelf.animationNode.updateLayout(size: iconSize)
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleLayout.size.width) / 2.0), y: topInset + 8.0), size: titleLayout.size)
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
                            if let item = self.item {
                                if let (_, attributes) = self.titleNode.attributesAtPoint(location) {
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
