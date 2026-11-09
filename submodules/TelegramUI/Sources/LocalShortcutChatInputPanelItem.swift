import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ItemListUI

final class LocalShortcutChatInputPanelItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    fileprivate let presentationData: ItemListPresentationData
    fileprivate let shortcutId: String
    fileprivate let text: String
    fileprivate let commandSelected: (ChatInputTextCommand, Bool) -> Void

    let selectable: Bool = true

    public init(presentationData: ItemListPresentationData, shortcutId: String, text: String, commandSelected: @escaping (ChatInputTextCommand, Bool) -> Void) {
        self.presentationData = presentationData
        self.shortcutId = shortcutId
        self.text = text
        self.commandSelected = commandSelected
    }

    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = LocalShortcutChatInputPanelItemNode()

            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (neighbors.previous != nil, neighbors.next != nil)
            let (layout, apply) = nodeLayout(self, params, top, bottom)

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }

    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LocalShortcutChatInputPanelItemNode {
                let nodeLayout = nodeValue.asyncLayout()

                async {
                    let (top, bottom) = (neighbors.previous != nil, neighbors.next != nil)

                    let (layout, apply) = nodeLayout(self, params, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }

    func selected(listView: ListView) {
        self.commandSelected(.localShortcut(self.shortcutId, self.text), true)
    }
}

final class LocalShortcutChatInputPanelItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 46.0

    private var item: LocalShortcutChatInputPanelItem?
    private let iconNode: ASImageNode
    private let textNode: TextNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode

    private let activateAreaNode: AccessibilityAreaNode

    init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false

        self.textNode = TextNode()

        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true

        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true

        self.activateAreaNode = AccessibilityAreaNode()
        self.activateAreaNode.accessibilityTraits = [.button]

        super.init(layerBacked: false)

        self.addSubnode(self.separatorNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)

        self.addSubnode(self.activateAreaNode)
    }

    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let item = item as? LocalShortcutChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: neighbors.previous != nil, bottom: neighbors.next != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }

    func asyncLayout() -> (_ item: LocalShortcutChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)

        let currentItem = self.item

        return { [weak self] item, params, mergedTop, mergedBottom in
            let font = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 15.0 / 17.0))

            let leftInset: CGFloat = 48.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset

            let replyText = item.text

            let commandString = NSAttributedString(string: replyText, font: font, textColor: item.presentationData.theme.list.itemPrimaryTextColor)

            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: commandString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: LocalShortcutChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())

            return (nodeLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item

                    strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor

                    if currentItem == nil || currentItem?.presentationData.theme !== item.presentationData.theme {
                        strongSelf.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reply"), color: item.presentationData.theme.list.itemSecondaryTextColor)
                    }

                    let _ = textApply()

                    let iconSize = CGSize(width: 22.0, height: 22.0)
                    strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 13.0, y: floor((nodeLayout.contentSize.height - iconSize.height) / 2.0)), size: iconSize)
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)

                    strongSelf.separatorNode.isHidden = !mergedBottom

                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width - leftInset, height: UIScreenPixel))

                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel))

                    strongSelf.activateAreaNode.accessibilityLabel = replyText
                    strongSelf.activateAreaNode.accessibilityTraits = [.button]
                    strongSelf.activateAreaNode.frame = CGRect(origin: .zero, size: nodeLayout.size)
                }
            })
        }
    }

    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)

        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            if animated {
                self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                    if let strongSelf = self {
                        if completed {
                            strongSelf.highlightedBackgroundNode.alpha = 0.0
                        }
                    }
                })
            } else {
                self.highlightedBackgroundNode.alpha = 0.0
            }
        }
    }
}
