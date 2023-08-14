import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import AccountContext
import TelegramPresentationData
import Photos

struct MediaGroupItem {
    let collection: PHAssetCollection
    let firstItem: PHAsset?
    let count: Int
}

final class MediaGroupsContextMenuContent: ContextControllerItemsContent {
    private final class GroupsListNode: ASDisplayNode, UIScrollViewDelegate {
        private final class ItemNode: HighlightTrackingButtonNode {
            let context: AccountContext
            let highlightBackgroundNode: ASDisplayNode
            let titleLabelNode: ImmediateTextNode
            let subtitleLabelNode: ImmediateTextNode
            let iconNode: ImageNode
            let separatorNode: ASDisplayNode

            let action: () -> Void

            private var item: MediaGroupItem?

            init(context: AccountContext, action: @escaping () -> Void) {
                self.action = action
                self.context = context

                self.highlightBackgroundNode = ASDisplayNode()
                self.highlightBackgroundNode.isAccessibilityElement = false
                self.highlightBackgroundNode.alpha = 0.0

                self.titleLabelNode = ImmediateTextNode()
                self.titleLabelNode.isAccessibilityElement = false
                self.titleLabelNode.maximumNumberOfLines = 1
                self.titleLabelNode.isUserInteractionEnabled = false
                
                self.subtitleLabelNode = ImmediateTextNode()
                self.subtitleLabelNode.isAccessibilityElement = false
                self.subtitleLabelNode.maximumNumberOfLines = 1
                self.subtitleLabelNode.isUserInteractionEnabled = false
                
                self.iconNode = ImageNode()
                self.iconNode.clipsToBounds = true
                self.iconNode.contentMode = .scaleAspectFill
                self.iconNode.cornerRadius = 6.0

                self.separatorNode = ASDisplayNode()
                self.separatorNode.isAccessibilityElement = false

                super.init()

                self.isAccessibilityElement = true

                self.addSubnode(self.separatorNode)
                self.addSubnode(self.highlightBackgroundNode)
                self.addSubnode(self.titleLabelNode)
                self.addSubnode(self.subtitleLabelNode)
                self.addSubnode(self.iconNode)

                self.highligthedChanged = { [weak self] highlighted in
                    guard let strongSelf = self else {
                        return
                    }
                    if highlighted {
                        strongSelf.highlightBackgroundNode.alpha = 1.0
                    } else {
                        let previousAlpha = strongSelf.highlightBackgroundNode.alpha
                        strongSelf.highlightBackgroundNode.alpha = 0.0
                        strongSelf.highlightBackgroundNode.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
                    }
                }

                self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
            }

            @objc private func pressed() {
                self.action()
            }
            
            func update(size: CGSize, presentationData: PresentationData, item: MediaGroupItem, isLast: Bool, syncronousLoad: Bool) {
                let leftInset: CGFloat = 16.0
                let rightInset: CGFloat = 48.0

                if self.item?.collection.localIdentifier != item.collection.localIdentifier {
                    self.item = item
                    
                    self.accessibilityLabel = item.collection.localizedTitle
                    
                    if let asset = item.firstItem {
                        self.iconNode.setSignal(assetImage(asset: asset, targetSize: CGSize(width: 24.0, height: 24.0), exact: false))
                    }
                }
                
                self.highlightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor

                self.highlightBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)

                self.titleLabelNode.attributedText = NSAttributedString(string: item.collection.localizedTitle ?? "", font: Font.regular(17.0), textColor: presentationData.theme.contextMenu.primaryColor)
                
                self.subtitleLabelNode.attributedText = NSAttributedString(string: "\(item.count)", font: Font.regular(15.0), textColor: presentationData.theme.contextMenu.secondaryColor)
                let maxTextWidth: CGFloat = size.width - leftInset - rightInset

                let titleSize = self.titleLabelNode.updateLayout(CGSize(width: maxTextWidth, height: 100.0))
                let subtitleSize = self.subtitleLabelNode.updateLayout(CGSize(width: maxTextWidth, height: 100.0))
                
                let spacing: CGFloat = 2.0
                let contentHeight = titleSize.height + spacing + subtitleSize.height
                
                let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - contentHeight) / 2.0)), size: titleSize)
                self.titleLabelNode.frame = titleFrame
                
                let subtitleFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + spacing), size: titleSize)
                self.subtitleLabelNode.frame = subtitleFrame
                
                let iconSize = CGSize(width: 24.0, height: 24.0)
                let iconFrame = CGRect(origin: CGPoint(x: size.width - leftInset - iconSize.width, y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
                self.iconNode.frame = iconFrame

                self.separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize(width: size.width, height: UIScreenPixel))
                self.separatorNode.isHidden = isLast
            }
        }

        private let context: AccountContext
        private let items: [MediaGroupItem]
        private let requestUpdate: (GroupsListNode, ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (GroupsListNode, ContainedViewLayoutTransition) -> Void
        private let selectGroup: (PHAssetCollection) -> Void

        private let scrollNode: ASScrollNode
        private var ignoreScrolling: Bool = false
        private var animateIn: Bool = false
        private var bottomScrollInset: CGFloat = 0.0

        private var presentationData: PresentationData?
        private var currentSize: CGSize?
        private var apparentHeight: CGFloat = 0.0

        private var itemNodes: [Int: ItemNode] = [:]

        init(
            context: AccountContext,
            items: [MediaGroupItem],
            requestUpdate: @escaping (GroupsListNode, ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (GroupsListNode, ContainedViewLayoutTransition) -> Void,
            selectGroup: @escaping (PHAssetCollection) -> Void
        ) {
            self.context = context
            self.items = items
            self.requestUpdate = requestUpdate
            self.requestUpdateApparentHeight = requestUpdateApparentHeight
            self.selectGroup = selectGroup

            self.scrollNode = ASScrollNode()
            self.scrollNode.canCancelAllTouchesInViews = true
            self.scrollNode.view.delaysContentTouches = false
            self.scrollNode.view.showsVerticalScrollIndicator = false
            if #available(iOS 11.0, *) {
                self.scrollNode.view.contentInsetAdjustmentBehavior = .never
            }
            self.scrollNode.clipsToBounds = false

            super.init()

            self.addSubnode(self.scrollNode)
            self.scrollNode.view.delegate = self

            self.clipsToBounds = true
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            self.updateVisibleItems(animated: false, syncronousLoad: false)

            if let size = self.currentSize {
                var apparentHeight = -self.scrollNode.view.contentOffset.y + self.scrollNode.view.contentSize.height
                apparentHeight = max(apparentHeight, 44.0)
                apparentHeight = min(apparentHeight, size.height)
                if self.apparentHeight != apparentHeight {
                    self.apparentHeight = apparentHeight

                    self.requestUpdateApparentHeight(self, .immediate)
                }
            }
        }

        private func updateVisibleItems(animated: Bool, syncronousLoad: Bool) {
            guard let size = self.currentSize else {
                return
            }
            guard let presentationData = self.presentationData else {
                return
            }
            let itemHeight: CGFloat = 54.0
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -180.0)

            var validIds = Set<Int>()

            let minVisibleIndex = max(0, Int(floor(visibleBounds.minY / itemHeight)))
            let maxVisibleIndex = Int(ceil(visibleBounds.maxY / itemHeight))
            
            if minVisibleIndex <= maxVisibleIndex {
                for index in minVisibleIndex ... maxVisibleIndex {
                    if index < self.items.count {
                        let height = itemHeight
                        let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: CGFloat(index) * itemHeight), size: CGSize(width: size.width, height: height))

                        let item = self.items[index]
                        validIds.insert(index)
                        
                        let itemNode: ItemNode
                        if let current = self.itemNodes[index] {
                            itemNode = current
                        } else {
                            let selectGroup = self.selectGroup
                            itemNode = ItemNode(context: self.context, action: {
                                selectGroup(item.collection)
                            })
                            self.itemNodes[index] = itemNode
                            self.scrollNode.addSubnode(itemNode)
                        }
                        
                        itemNode.update(size: itemFrame.size, presentationData: presentationData, item: item, isLast: index == self.items.count - 1, syncronousLoad: syncronousLoad)
                        itemNode.frame = itemFrame
                    }
                }
            }

            var removeIds: [Int] = []
            for (id, itemNode) in self.itemNodes {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemNode.removeFromSupernode()
                }
            }
            for id in removeIds {
                self.itemNodes.removeValue(forKey: id)
            }
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            var extendedScrollNodeFrame = self.scrollNode.frame
            extendedScrollNodeFrame.size.height += self.bottomScrollInset

            if extendedScrollNodeFrame.contains(point) {
                return self.scrollNode.view.hitTest(self.view.convert(point, to: self.scrollNode.view), with: event)
            }

            return super.hitTest(point, with: event)
        }

        func update(presentationData: PresentationData, constrainedSize: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (height: CGFloat, apparentHeight: CGFloat) {
            let itemHeight: CGFloat = 54.0

            self.presentationData = presentationData
            
            let contentHeight = CGFloat(self.items.count) * itemHeight
            let size = CGSize(width: constrainedSize.width, height: contentHeight)

            let containerSize = CGSize(width: size.width, height: min(constrainedSize.height, size.height))
            self.currentSize = containerSize

            self.ignoreScrolling = true

            if self.scrollNode.frame != CGRect(origin: CGPoint(), size: containerSize) {
                self.scrollNode.frame = CGRect(origin: CGPoint(), size: containerSize)
            }
            if self.scrollNode.view.contentInset.bottom != bottomInset {
                self.scrollNode.view.contentInset.bottom = bottomInset
            }
            self.bottomScrollInset = bottomInset
            let scrollContentSize = CGSize(width: size.width, height: size.height)
            if self.scrollNode.view.contentSize != scrollContentSize {
                self.scrollNode.view.contentSize = scrollContentSize
            }
            self.ignoreScrolling = false

            self.updateVisibleItems(animated: transition.isAnimated, syncronousLoad: !transition.isAnimated)

            self.animateIn = false

            var apparentHeight = -self.scrollNode.view.contentOffset.y + self.scrollNode.view.contentSize.height
            apparentHeight = max(apparentHeight, 44.0)
            apparentHeight = min(apparentHeight, containerSize.height)
            self.apparentHeight = apparentHeight

            return (containerSize.height, apparentHeight)
        }
    }

    final class ItemsNode: ASDisplayNode, ContextControllerItemsNode {
        private let context: AccountContext
        private let items: [MediaGroupItem]
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (ContainedViewLayoutTransition) -> Void

        private var presentationData: PresentationData

        private let currentTabIndex: Int = 0
        private var visibleTabNodes: [Int: GroupsListNode] = [:]

        private let selectGroup: (PHAssetCollection) -> Void

        private(set) var apparentHeight: CGFloat = 0.0

        init(
            context: AccountContext,
            items: [MediaGroupItem],
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void,
            selectGroup: @escaping (PHAssetCollection) -> Void
        ) {
            self.context = context
            self.items = items
            self.selectGroup = selectGroup
            self.presentationData = context.sharedContext.currentPresentationData.with({ $0 })

            self.requestUpdate = requestUpdate
            self.requestUpdateApparentHeight = requestUpdateApparentHeight

            super.init()
        }

        func update(presentationData: PresentationData, constrainedWidth: CGFloat, maxHeight: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (cleanSize: CGSize, apparentHeight: CGFloat) {
            let constrainedSize = CGSize(width: min(190.0, constrainedWidth), height: min(295.0, maxHeight))

            let topContentHeight: CGFloat = 0.0

            var tabLayouts: [Int: (height: CGFloat, apparentHeight: CGFloat)] = [:]

            var visibleIndices: [Int] = []
            visibleIndices.append(self.currentTabIndex)

            let previousVisibleTabFrames: [(Int, CGRect)] = self.visibleTabNodes.map { key, value -> (Int, CGRect) in
                return (key, value.frame)
            }

            for index in visibleIndices {
                var tabTransition = transition
                let tabNode: GroupsListNode
                var initialReferenceFrame: CGRect?
                if let current = self.visibleTabNodes[index] {
                    tabNode = current
                } else {
                    for (previousIndex, previousFrame) in previousVisibleTabFrames {
                        if index > previousIndex {
                            initialReferenceFrame = previousFrame.offsetBy(dx: constrainedSize.width, dy: 0.0)
                        } else {
                            initialReferenceFrame = previousFrame.offsetBy(dx: -constrainedSize.width, dy: 0.0)
                        }
                        break
                    }

                    tabNode = GroupsListNode(
                        context: self.context,
                        items: self.items,
                        requestUpdate: { [weak self] tab, transition in
                            guard let strongSelf = self else {
                                return
                            }
                            if strongSelf.visibleTabNodes.contains(where: { $0.value === tab }) {
                                strongSelf.requestUpdate(transition)
                            }
                        },
                        requestUpdateApparentHeight: { [weak self] tab, transition in
                            guard let strongSelf = self else {
                                return
                            }
                            if strongSelf.visibleTabNodes.contains(where: { $0.value === tab }) {
                                strongSelf.requestUpdateApparentHeight(transition)
                            }
                        },
                        selectGroup: self.selectGroup
                    )
                    self.addSubnode(tabNode)
                    self.visibleTabNodes[index] = tabNode
                    tabTransition = .immediate
                }

                let tabLayout = tabNode.update(presentationData: presentationData, constrainedSize: CGSize(width: constrainedSize.width, height: constrainedSize.height - topContentHeight), bottomInset: bottomInset, transition: tabTransition)
                tabLayouts[index] = tabLayout
                let currentFractionalTabIndex = CGFloat(self.currentTabIndex)
                let xOffset: CGFloat = (CGFloat(index) - currentFractionalTabIndex) * constrainedSize.width
                let tabFrame = CGRect(origin: CGPoint(x: xOffset, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: tabLayout.height))
                tabTransition.updateFrame(node: tabNode, frame: tabFrame)
                if let initialReferenceFrame = initialReferenceFrame {
                    transition.animatePositionAdditive(node: tabNode, offset: CGPoint(x: initialReferenceFrame.minX - tabFrame.minX, y: 0.0))
                }
            }

            var contentSize = CGSize(width: constrainedSize.width, height: topContentHeight)
            var apparentHeight = topContentHeight

            if let tabLayout = tabLayouts[self.currentTabIndex] {
                contentSize.height += tabLayout.height
                apparentHeight += tabLayout.apparentHeight
            }

            return (contentSize, apparentHeight)
        }
    }

    let context: AccountContext
    let items: [MediaGroupItem]
    let selectGroup: (PHAssetCollection) -> Void

    public init(
        context: AccountContext,
        items: [MediaGroupItem],
        selectGroup: @escaping (PHAssetCollection) -> Void
    ) {
        self.context = context
        self.items = items
        self.selectGroup = selectGroup
    }

    func node(
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerItemsNode {
        return ItemsNode(
            context: self.context,
            items: self.items,
            requestUpdate: requestUpdate,
            requestUpdateApparentHeight: requestUpdateApparentHeight,
            selectGroup: self.selectGroup
        )
    }
}
