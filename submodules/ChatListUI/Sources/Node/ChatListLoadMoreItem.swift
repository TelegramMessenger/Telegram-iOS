import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI

final class ChatListLoadMoreItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    let presentationData: ChatListPresentationData
    let isLoading: Bool
    let showsFolderLimit: Bool
    let action: () -> Void

    var selectable: Bool {
        return !self.isLoading
    }

    init(presentationData: ChatListPresentationData, isLoading: Bool, showsFolderLimit: Bool, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.isLoading = isLoading
        self.showsFolderLimit = showsFolderLimit
        self.action = action
    }

    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action()
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListLoadMoreItemNode()
            let (layout, apply) = node.asyncLayout()(self, params)

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListLoadMoreItemNode)
            if let nodeValue = node() as? ChatListLoadMoreItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

final class ChatListLoadMoreItemNode: ListViewItemNode {
    private let highlightedBackgroundNode: ASDisplayNode
    private let titleNode: TextNode
    private let captionNode: TextNode
    private let activateArea: AccessibilityAreaNode

    private var item: ChatListLoadMoreItem?

    required init() {
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.captionNode = TextNode()
        self.captionNode.isUserInteractionEnabled = false

        self.activateArea = AccessibilityAreaNode()

        super.init(layerBacked: false)

        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.captionNode)
        self.addSubnode(self.activateArea)

        self.activateArea.activate = { [weak self] in
            guard let item = self?.item, !item.isLoading else {
                return false
            }
            item.action()
            return true
        }
    }

    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListLoadMoreItem, params)
        apply()
    }

    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)

        let alpha: CGFloat = highlighted ? 1.0 : 0.0
        if !highlighted && animated {
            self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: alpha, duration: 0.4)
        }
        self.highlightedBackgroundNode.alpha = alpha
    }

    func asyncLayout() -> (_ item: ChatListLoadMoreItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeCaptionLayout = TextNode.asyncLayout(self.captionNode)

        return { [weak self] item, params in
            let sideInset: CGFloat = 16.0
            let verticalInset: CGFloat = 12.0
            let captionSpacing: CGFloat = 4.0
            let constrainedSize = CGSize(width: max(1.0, params.width - params.leftInset - params.rightInset - sideInset * 2.0), height: .greatestFiniteMagnitude)

            let theme = item.presentationData.theme
            let strings = item.presentationData.strings
            let fontSize = item.presentationData.fontSize.itemListBaseFontSize
            let title = item.isLoading ? strings.Support_ChatLoading_LoadingMore : strings.Support_ChatLoading_LoadMore
            let titleColor = item.isLoading ? theme.list.itemSecondaryTextColor : theme.list.itemAccentColor
            let titleLayout = makeTitleLayout(TextNodeLayoutArguments(
                attributedString: NSAttributedString(string: title, font: Font.regular(fontSize), textColor: titleColor),
                maximumNumberOfLines: 1,
                truncationType: .end,
                constrainedSize: constrainedSize,
                alignment: .center
            ))

            var captionString: NSAttributedString?
            if item.showsFolderLimit {
                captionString = NSAttributedString(string: strings.Support_ChatLoading_FolderLimit, font: Font.regular(floor(fontSize * 13.0 / 17.0)), textColor: theme.list.itemSecondaryTextColor)
            }
            let captionLayout = makeCaptionLayout(TextNodeLayoutArguments(
                attributedString: captionString,
                maximumNumberOfLines: 0,
                truncationType: .end,
                constrainedSize: constrainedSize,
                alignment: .center
            ))

            var contentHeight = verticalInset + titleLayout.0.size.height
            if item.showsFolderLimit {
                contentHeight += captionSpacing + captionLayout.0.size.height
            }
            contentHeight += verticalInset

            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: contentHeight), insets: UIEdgeInsets())

            return (layout, { [weak self] in
                guard let self else {
                    return
                }

                self.item = item
                self.contentSize = layout.contentSize
                self.insets = layout.insets

                let _ = titleLayout.1()
                let _ = captionLayout.1()

                let bandWidth = params.width - params.leftInset - params.rightInset
                self.titleNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((bandWidth - titleLayout.0.size.width) * 0.5), y: verticalInset), size: titleLayout.0.size)
                self.captionNode.frame = CGRect(origin: CGPoint(x: params.leftInset + floor((bandWidth - captionLayout.0.size.width) * 0.5), y: verticalInset + titleLayout.0.size.height + captionSpacing), size: captionLayout.0.size)

                self.highlightedBackgroundNode.backgroundColor = theme.chatList.itemHighlightedBackgroundColor
                self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)

                self.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: bandWidth, height: layout.contentSize.height))
                self.activateArea.accessibilityLabel = title
                self.activateArea.accessibilityValue = captionString?.string
                self.activateArea.accessibilityTraits = item.isLoading ? [.button, .notEnabled] : .button
            })
        }
    }
}
