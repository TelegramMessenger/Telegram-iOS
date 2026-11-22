import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import Markdown
import AccountContext
import ContextUI
import ComponentFlow
import AppBundle

private struct TranslationLanguagesContextMenuLayout {
    static let sideInset: CGFloat = 18.0
    static let verticalInset: CGFloat = 11.0
    static let listVerticalInset: CGFloat = 10.0
    static let separatorRowHeight: CGFloat = 20.0
    static let iconSideInset: CGFloat = 20.0
    static let standardIconWidth: CGFloat = 32.0
    static let iconTitleOffset: CGFloat = 40.0
    static let highlightSideInset: CGFloat = 10.0
    static let highlightMaxCornerRadius: CGFloat = 20.0

    static func titleFont(presentationData: PresentationData) -> UIFont {
        return Font.regular(presentationData.listsFontSize.baseDisplaySize)
    }

    static func itemHeight(titleHeight: CGFloat) -> CGFloat {
        return verticalInset + titleHeight + verticalInset
    }

    static func iconFrame(itemSize: CGSize, iconSize: CGSize) -> CGRect {
        return CGRect(origin: CGPoint(x: iconSideInset + floor((standardIconWidth - iconSize.width) * 0.5), y: floor((itemSize.height - iconSize.height) * 0.5)), size: iconSize)
    }

    static func highlightFrame(itemSize: CGSize) -> CGRect {
        return CGRect(origin: CGPoint(x: highlightSideInset, y: 0.0), size: CGSize(width: max(0.0, itemSize.width - highlightSideInset * 2.0), height: itemSize.height))
    }

    static func highlightCornerRadius(highlightHeight: CGFloat) -> CGFloat {
        return min(highlightMaxCornerRadius, highlightHeight * 0.5)
    }

    static func separatorFrame(rowSize: CGSize) -> CGRect {
        return CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((rowSize.height - 1.0) * 0.5)), size: CGSize(width: max(0.0, rowSize.width - sideInset * 2.0), height: 1.0))
    }
}

private func updateHighlightBackground(view: UIView, presentationData: PresentationData, itemSize: CGSize) {
    view.backgroundColor = presentationData.theme.overallDarkAppearance ? UIColor.white : UIColor.black
    view.setMonochromaticEffect(tintColor: view.backgroundColor)
    let highlightFrame = TranslationLanguagesContextMenuLayout.highlightFrame(itemSize: itemSize)
    view.frame = highlightFrame
    view.layer.cornerRadius = TranslationLanguagesContextMenuLayout.highlightCornerRadius(highlightHeight: highlightFrame.height)
}

private func setHighlightBackground(view: UIView, isHighlighted: Bool) {
    if isHighlighted {
        view.layer.removeAnimation(forKey: "opacity")
        view.alpha = 0.1
    } else {
        let currentAlpha = view.alpha
        view.alpha = 0.0
        view.layer.animateAlpha(from: currentAlpha, to: 0.0, duration: 0.3)
    }
}

public final class TranslationLanguagesContextMenuContent: ContextControllerItemsContent {
    private final class BackButtonNode: HighlightTrackingButtonNode {
        let highlightBackgroundView: UIView
        let titleLabelNode: ImmediateTextNode
        let iconNode: ASImageNode

        var action: (() -> Void)?

        private var theme: PresentationTheme?

        init() {
            self.highlightBackgroundView = UIView()
            self.highlightBackgroundView.isUserInteractionEnabled = false
            self.highlightBackgroundView.alpha = 0.0

            self.titleLabelNode = ImmediateTextNode()
            self.titleLabelNode.isAccessibilityElement = false
            self.titleLabelNode.maximumNumberOfLines = 1
            self.titleLabelNode.isUserInteractionEnabled = false

            self.iconNode = ASImageNode()
            self.iconNode.isAccessibilityElement = false

            super.init()

            self.view.addSubview(self.highlightBackgroundView)
            self.addSubnode(self.titleLabelNode)
            self.addSubnode(self.iconNode)

            self.isAccessibilityElement = true

            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                setHighlightBackground(view: self.highlightBackgroundView, isHighlighted: highlighted)
            }

            self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        }

        @objc private func pressed() {
            self.action?()
        }

        func updateLayout(presentationData: PresentationData, width: CGFloat) -> CGFloat {
            if self.theme !== presentationData.theme {
                self.theme = presentationData.theme
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: presentationData.theme.contextMenu.primaryColor)

                self.accessibilityLabel = presentationData.strings.Common_Back
            }

            let titleX = TranslationLanguagesContextMenuLayout.iconSideInset + TranslationLanguagesContextMenuLayout.iconTitleOffset
            self.titleLabelNode.attributedText = NSAttributedString(string: presentationData.strings.Common_Back, font: TranslationLanguagesContextMenuLayout.titleFont(presentationData: presentationData), textColor: presentationData.theme.contextMenu.primaryColor)
            let titleSize = self.titleLabelNode.updateLayout(CGSize(width: max(1.0, width - titleX - TranslationLanguagesContextMenuLayout.sideInset), height: 100.0))
            return TranslationLanguagesContextMenuLayout.itemHeight(titleHeight: titleSize.height)
        }

        func update(size: CGSize, presentationData: PresentationData) {
            updateHighlightBackground(view: self.highlightBackgroundView, presentationData: presentationData, itemSize: size)

            let titleSize = self.titleLabelNode.updateLayout(CGSize(width: max(1.0, size.width - TranslationLanguagesContextMenuLayout.iconSideInset - TranslationLanguagesContextMenuLayout.iconTitleOffset - TranslationLanguagesContextMenuLayout.sideInset), height: 100.0))
            self.titleLabelNode.frame = CGRect(origin: CGPoint(x: TranslationLanguagesContextMenuLayout.iconSideInset + TranslationLanguagesContextMenuLayout.iconTitleOffset, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)

            if let iconImage = self.iconNode.image {
                self.iconNode.frame = TranslationLanguagesContextMenuLayout.iconFrame(itemSize: size, iconSize: iconImage.size)
            }
        }
    }

    private final class SeparatorNode: ASDisplayNode {
        private let lineNode: ASDisplayNode

        override init() {
            self.lineNode = ASDisplayNode()
            self.lineNode.isAccessibilityElement = false
            self.lineNode.isUserInteractionEnabled = false

            super.init()

            self.isUserInteractionEnabled = false
            self.addSubnode(self.lineNode)
        }

        func update(size: CGSize, presentationData: PresentationData) {
            self.lineNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
            self.lineNode.frame = TranslationLanguagesContextMenuLayout.separatorFrame(rowSize: size)
        }
    }

    private final class LanguagesListNode: ASDisplayNode, ASScrollViewDelegate {
        private final class ItemNode: HighlightTrackingButtonNode {
            let context: AccountContext
            let highlightBackgroundView: UIView
            let titleLabelNode: ImmediateTextNode
            var iconNode: ASImageNode?

            let action: () -> Void

            private var language: String?
            private var displayTitle: String?
            private var theme: PresentationTheme?

            init(context: AccountContext, action: @escaping () -> Void) {
                self.action = action
                self.context = context

                self.highlightBackgroundView = UIView()
                self.highlightBackgroundView.isUserInteractionEnabled = false
                self.highlightBackgroundView.alpha = 0.0

                self.titleLabelNode = ImmediateTextNode()
                self.titleLabelNode.isAccessibilityElement = false
                self.titleLabelNode.maximumNumberOfLines = 1
                self.titleLabelNode.isUserInteractionEnabled = false

                super.init()

                self.isAccessibilityElement = true

                self.view.addSubview(self.highlightBackgroundView)
                self.addSubnode(self.titleLabelNode)

                self.highligthedChanged = { [weak self] highlighted in
                    guard let self else {
                        return
                    }
                    setHighlightBackground(view: self.highlightBackgroundView, isHighlighted: highlighted)
                }

                self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
            }

            @objc private func pressed() {
                self.action()
            }

            func update(size: CGSize, presentationData: PresentationData, language: String, displayTitle: String, isSelected: Bool?, syncronousLoad: Bool) {
                var titleX = TranslationLanguagesContextMenuLayout.sideInset
                if let _ = isSelected {
                    titleX = TranslationLanguagesContextMenuLayout.iconSideInset + TranslationLanguagesContextMenuLayout.iconTitleOffset
                }

                if isSelected == true {
                    let iconNode: ASImageNode
                    if let current = self.iconNode {
                        iconNode = current
                    } else {
                        iconNode = ASImageNode()
                        iconNode.displaysAsynchronously = false
                        iconNode.isUserInteractionEnabled = false
                        self.iconNode = iconNode
                        self.addSubnode(iconNode)
                    }
                    if iconNode.image == nil || self.theme !== presentationData.theme {
                        iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: presentationData.theme.contextMenu.primaryColor)
                    }

                    if let icon = iconNode.image {
                        iconNode.frame = TranslationLanguagesContextMenuLayout.iconFrame(itemSize: size, iconSize: icon.size)
                    }
                } else if let iconNode = self.iconNode {
                    self.iconNode = nil
                    iconNode.removeFromSupernode()
                }
                self.theme = presentationData.theme

                if self.language != language {
                    self.language = language
                    self.displayTitle = displayTitle

                    self.accessibilityLabel = "\(displayTitle)"
                }

                updateHighlightBackground(view: self.highlightBackgroundView, presentationData: presentationData, itemSize: size)

                self.titleLabelNode.attributedText = NSAttributedString(string: self.displayTitle ?? "", font: TranslationLanguagesContextMenuLayout.titleFont(presentationData: presentationData), textColor: presentationData.theme.contextMenu.primaryColor)
                let maxTextWidth: CGFloat = max(1.0, size.width - titleX - TranslationLanguagesContextMenuLayout.sideInset)

                let titleSize = self.titleLabelNode.updateLayout(CGSize(width: maxTextWidth, height: 100.0))
                self.titleLabelNode.frame = CGRect(origin: CGPoint(x: titleX, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            }
        }

        private let context: AccountContext
        private let languages: [(String, String)]
        private let selectedLanguages: Set<String>?
        private let topInset: CGFloat
        
        private let requestUpdate: (LanguagesListNode, ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (LanguagesListNode, ContainedViewLayoutTransition) -> Void
        private let selectLanguage: (String) -> Void

        private let scrollNode: ASScrollNode
        private let titleMeasureNode: ImmediateTextNode
        private var ignoreScrolling: Bool = false
        private var animateIn: Bool = false
        private var bottomScrollInset: CGFloat = 0.0

        private var presentationData: PresentationData?
        private var currentSize: CGSize?
        private var apparentHeight: CGFloat = 0.0
        private var itemHeight: CGFloat = 0.0
        private var rowFrames: [CGRect] = []

        private var itemNodes: [Int: ItemNode] = [:]
        private var separatorNodes: [Int: SeparatorNode] = [:]

        init(
            context: AccountContext,
            languages: [(String, String)],
            selectedLanguages: Set<String>?,
            topInset: CGFloat,
            requestUpdate: @escaping (LanguagesListNode, ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (LanguagesListNode, ContainedViewLayoutTransition) -> Void,
            selectLanguage: @escaping (String) -> Void
        ) {
            self.context = context
            self.languages = languages
            self.selectedLanguages = selectedLanguages
            self.topInset = topInset
            self.requestUpdate = requestUpdate
            self.requestUpdateApparentHeight = requestUpdateApparentHeight
            self.selectLanguage = selectLanguage

            self.scrollNode = ASScrollNode()
            self.scrollNode.canCancelAllTouchesInViews = true
            self.scrollNode.view.delaysContentTouches = false
            self.scrollNode.view.showsVerticalScrollIndicator = false
            if #available(iOS 11.0, *) {
                self.scrollNode.view.contentInsetAdjustmentBehavior = .never
            }
            self.scrollNode.clipsToBounds = false
            self.scrollNode.view.scrollsToTop = false

            self.titleMeasureNode = ImmediateTextNode()
            self.titleMeasureNode.maximumNumberOfLines = 1

            super.init()

            self.addSubnode(self.scrollNode)
            self.scrollNode.view.delegate = self.wrappedScrollViewDelegate

            self.clipsToBounds = true
        }

        private func isSeparator(at index: Int) -> Bool {
            return self.languages[index].0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            self.updateVisibleItems(animated: false, syncronousLoad: false)

            if let size = self.currentSize {
                var apparentHeight = -self.scrollNode.view.contentOffset.y + self.scrollNode.view.contentSize.height
                apparentHeight = max(apparentHeight, self.itemHeight)
                apparentHeight = min(apparentHeight, size.height)
                if self.apparentHeight != apparentHeight {
                    self.apparentHeight = apparentHeight

                    self.requestUpdateApparentHeight(self, .immediate)
                }
            }
        }

        private func updateVisibleItems(animated: Bool, syncronousLoad: Bool) {
            guard self.currentSize != nil else {
                return
            }
            guard let presentationData = self.presentationData else {
                return
            }
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -180.0)

            var validItemIds = Set<Int>()
            var validSeparatorIds = Set<Int>()

            for index in 0 ..< min(self.rowFrames.count, self.languages.count) {
                let rowFrame = self.rowFrames[index]
                if !rowFrame.intersects(visibleBounds) {
                    continue
                }
                if self.isSeparator(at: index) {
                    validSeparatorIds.insert(index)

                    let separatorNode: SeparatorNode
                    if let current = self.separatorNodes[index] {
                        separatorNode = current
                    } else {
                        separatorNode = SeparatorNode()
                        self.separatorNodes[index] = separatorNode
                        self.scrollNode.addSubnode(separatorNode)
                    }
                    separatorNode.update(size: rowFrame.size, presentationData: presentationData)
                    separatorNode.frame = rowFrame
                } else {
                    let (languageCode, displayTitle) = self.languages[index]
                    validItemIds.insert(index)

                    let itemNode: ItemNode
                    if let current = self.itemNodes[index] {
                        itemNode = current
                    } else {
                        let selectLanguage = self.selectLanguage
                        itemNode = ItemNode(context: self.context, action: {
                            selectLanguage(languageCode)
                        })
                        self.itemNodes[index] = itemNode
                        self.scrollNode.addSubnode(itemNode)
                    }

                    var isSelected: Bool?
                    if let selectedLanguages = self.selectedLanguages {
                        isSelected = selectedLanguages.contains(languageCode)
                    }

                    itemNode.update(size: rowFrame.size, presentationData: presentationData, language: languageCode, displayTitle: displayTitle, isSelected: isSelected, syncronousLoad: syncronousLoad)
                    itemNode.frame = rowFrame
                }
            }

            var removeIds: [Int] = []
            for (id, itemNode) in self.itemNodes {
                if !validItemIds.contains(id) {
                    removeIds.append(id)
                    itemNode.removeFromSupernode()
                }
            }
            for id in removeIds {
                self.itemNodes.removeValue(forKey: id)
            }

            removeIds.removeAll()
            for (id, separatorNode) in self.separatorNodes {
                if !validSeparatorIds.contains(id) {
                    removeIds.append(id)
                    separatorNode.removeFromSupernode()
                }
            }
            for id in removeIds {
                self.separatorNodes.removeValue(forKey: id)
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
            self.presentationData = presentationData

            self.titleMeasureNode.attributedText = NSAttributedString(string: "A", font: TranslationLanguagesContextMenuLayout.titleFont(presentationData: presentationData), textColor: .black)
            let titleHeight = self.titleMeasureNode.updateLayout(CGSize(width: 1000.0, height: 100.0)).height
            let itemHeight = TranslationLanguagesContextMenuLayout.itemHeight(titleHeight: titleHeight)
            self.itemHeight = itemHeight

            var rowFrames: [CGRect] = []
            rowFrames.reserveCapacity(self.languages.count)
            var nextY = self.topInset
            for index in 0 ..< self.languages.count {
                let height = self.isSeparator(at: index) ? TranslationLanguagesContextMenuLayout.separatorRowHeight : itemHeight
                rowFrames.append(CGRect(origin: CGPoint(x: 0.0, y: nextY), size: CGSize(width: constrainedSize.width, height: height)))
                nextY += height
            }
            self.rowFrames = rowFrames

            let contentHeight = nextY + TranslationLanguagesContextMenuLayout.listVerticalInset
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
            apparentHeight = max(apparentHeight, itemHeight)
            apparentHeight = min(apparentHeight, containerSize.height)
            self.apparentHeight = apparentHeight

            return (containerSize.height, apparentHeight)
        }
    }

    final class ItemsNode: ASDisplayNode, ContextControllerItemsNode {
        private let context: AccountContext
        private let languages: [(String, String)]
        private let selectedLanguages: Set<String>?
        
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (ContainedViewLayoutTransition) -> Void

        private var presentationData: PresentationData

        private var backButtonNode: BackButtonNode?
        private var separatorNode: SeparatorNode?

        private let currentTabIndex: Int = 0
        private var visibleTabNodes: [Int: LanguagesListNode] = [:]

        private let selectLanguage: (String) -> Void

        private(set) var apparentHeight: CGFloat = 0.0

        init(
            context: AccountContext,
            languages: [(String, String)],
            selectedLanguages: Set<String>?,
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void,
            back: (() -> Void)?,
            selectLanguage: @escaping (String) -> Void
        ) {
            self.context = context
            self.languages = languages
            self.selectedLanguages = selectedLanguages
            self.selectLanguage = selectLanguage
            self.presentationData = context.sharedContext.currentPresentationData.with({ $0 })

            self.requestUpdate = requestUpdate
            self.requestUpdateApparentHeight = requestUpdateApparentHeight

            if let back = back {
                self.backButtonNode = BackButtonNode()
                self.backButtonNode?.action = {
                    back()
                }
            }

            super.init()

            if self.backButtonNode != nil {
                self.separatorNode = SeparatorNode()
            }

            if let backButtonNode = self.backButtonNode {
                self.addSubnode(backButtonNode)
            }
            if let separatorNode = self.separatorNode {
                self.addSubnode(separatorNode)
            }
        }

        func update(presentationData: PresentationData, constrainedWidth: CGFloat, maxHeight: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (cleanSize: CGSize, apparentHeight: CGFloat) {
            let constrainedSize = CGSize(width: min(220.0, constrainedWidth), height: min(604.0, maxHeight))

            var topContentHeight: CGFloat = 0.0
            if let backButtonNode = self.backButtonNode {
                topContentHeight += TranslationLanguagesContextMenuLayout.listVerticalInset
                let backButtonHeight = backButtonNode.updateLayout(presentationData: self.presentationData, width: constrainedSize.width)
                let backButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: backButtonHeight))
                backButtonNode.update(size: backButtonFrame.size, presentationData: self.presentationData)
                transition.updateFrame(node: backButtonNode, frame: backButtonFrame)
                topContentHeight += backButtonFrame.height
            }
            if let separatorNode = self.separatorNode {
                let separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: TranslationLanguagesContextMenuLayout.separatorRowHeight))
                separatorNode.update(size: separatorFrame.size, presentationData: self.presentationData)
                transition.updateFrame(node: separatorNode, frame: separatorFrame)
                topContentHeight += separatorFrame.height
            }

            var tabLayouts: [Int: (height: CGFloat, apparentHeight: CGFloat)] = [:]

            var visibleIndices: [Int] = []
            visibleIndices.append(self.currentTabIndex)

            let previousVisibleTabFrames: [(Int, CGRect)] = self.visibleTabNodes.map { key, value -> (Int, CGRect) in
                return (key, value.frame)
            }

            for index in visibleIndices {
                var tabTransition = transition
                let tabNode: LanguagesListNode
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

                    tabNode = LanguagesListNode(
                        context: self.context,
                        languages: self.languages,
                        selectedLanguages: self.selectedLanguages,
                        topInset: self.backButtonNode == nil ? TranslationLanguagesContextMenuLayout.listVerticalInset : 0.0,
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
                        selectLanguage: self.selectLanguage
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
    let languages: [(String, String)]
    let selectedLanguages: Set<String>?
    let back: (() -> Void)?
    let selectLanguage: (String) -> Void

    public init(
        context: AccountContext,
        languages: [(String, String)],
        selectedLanguages: Set<String>? = nil,
        back: (() -> Void)?,
        selectLanguage: @escaping (String) -> Void
    ) {
        self.context = context
        self.languages = languages
        self.selectedLanguages = selectedLanguages
        self.back = back
        self.selectLanguage = selectLanguage
    }

    public func node(
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerItemsNode {
        return ItemsNode(
            context: self.context,
            languages: self.languages,
            selectedLanguages: self.selectedLanguages,
            requestUpdate: requestUpdate,
            requestUpdateApparentHeight: requestUpdateApparentHeight,
            back: self.back,
            selectLanguage: self.selectLanguage
        )
    }
}
