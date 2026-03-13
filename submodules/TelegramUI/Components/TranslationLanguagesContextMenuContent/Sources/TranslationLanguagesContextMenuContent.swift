import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import Markdown
import AccountContext
import ContextUI
import ComponentFlow
import AppBundle

private let separatorHeight: CGFloat = 1.0

public final class TranslationLanguagesContextMenuContent: ContextControllerItemsContent {
    private final class BackButtonNode: HighlightTrackingButtonNode {
        let highlightBackgroundNode: ASDisplayNode
        let titleLabelNode: ImmediateTextNode
        let separatorNode: ASDisplayNode
        let iconNode: ASImageNode

        var action: (() -> Void)?

        private var theme: PresentationTheme?

        init() {
            self.highlightBackgroundNode = ASDisplayNode()
            self.highlightBackgroundNode.isAccessibilityElement = false
            self.highlightBackgroundNode.alpha = 0.0

            self.titleLabelNode = ImmediateTextNode()
            self.titleLabelNode.isAccessibilityElement = false
            self.titleLabelNode.maximumNumberOfLines = 1
            self.titleLabelNode.isUserInteractionEnabled = false

            self.iconNode = ASImageNode()
            self.iconNode.isAccessibilityElement = false

            self.separatorNode = ASDisplayNode()
            self.separatorNode.isAccessibilityElement = false

            super.init()

            self.addSubnode(self.separatorNode)
            self.addSubnode(self.highlightBackgroundNode)
            self.addSubnode(self.titleLabelNode)
            self.addSubnode(self.iconNode)

            self.isAccessibilityElement = true

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
            self.action?()
        }

        func update(size: CGSize, presentationData: PresentationData, isLast: Bool) {
            let standardIconWidth: CGFloat = 32.0
            let sideInset: CGFloat = 16.0
            let iconSideInset: CGFloat = 12.0

            if self.theme !== presentationData.theme {
                self.theme = presentationData.theme
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: presentationData.theme.contextMenu.primaryColor)

                self.accessibilityLabel = presentationData.strings.Common_Back
            }

            self.highlightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
            self.separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor

            self.highlightBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)

            self.titleLabelNode.attributedText = NSAttributedString(string: presentationData.strings.Common_Back, font: Font.regular(17.0), textColor: presentationData.theme.contextMenu.primaryColor)
            let titleSize = self.titleLabelNode.updateLayout(CGSize(width: size.width - sideInset - standardIconWidth, height: 100.0))
            self.titleLabelNode.frame = CGRect(origin: CGPoint(x: sideInset + 36.0, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)

            if let iconImage = self.iconNode.image {
                let iconFrame = CGRect(origin: CGPoint(x: iconSideInset, y: floor((size.height - iconImage.size.height) / 2.0)), size: iconImage.size)
                self.iconNode.frame = iconFrame
            }

            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel))
            self.separatorNode.isHidden = isLast
        }
    }

    private final class LanguagesListNode: ASDisplayNode, ASScrollViewDelegate {
        private final class ItemNode: HighlightTrackingButtonNode {
            let context: AccountContext
            let highlightBackgroundNode: ASDisplayNode
            let titleLabelNode: ImmediateTextNode
            let separatorNode: ASDisplayNode
            var iconNode: ASImageNode?

            let action: () -> Void

            private var language: String?

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

                self.separatorNode = ASDisplayNode()
                self.separatorNode.isAccessibilityElement = false

                super.init()

                self.isAccessibilityElement = true

                self.addSubnode(self.separatorNode)
                self.addSubnode(self.highlightBackgroundNode)
                self.addSubnode(self.titleLabelNode)

                self.highligthedChanged = { [weak self] highlighted in
                    guard let strongSelf = self, let language = strongSelf.language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
                guard let language = self.language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return
                }
                self.action()
            }
            
            private var displayTitle: String?
            func update(size: CGSize, presentationData: PresentationData, language: String, displayTitle: String, isSelected: Bool?, isLast: Bool, syncronousLoad: Bool) {
                var sideInset: CGFloat = 16.0
                if let _ = isSelected {
                    sideInset += 44.0
                }
                
                if isSelected == true {
                    let iconNode: ASImageNode
                    if let current = self.iconNode {
                        iconNode = current
                    } else {
                        iconNode = ASImageNode()
                        iconNode.displaysAsynchronously = false
                        iconNode.image = UIImage(bundleImageName: "Chat/Context Menu/Check")
                        self.iconNode = iconNode
                        self.addSubnode(iconNode)
                    }
                    
                    if let icon = iconNode.image {
                        iconNode.frame = CGRect(origin: CGPoint(x: 10.0, y: floorToScreenPixels((44.0 - icon.size.height) / 2.0)), size: icon.size)
                    }
                } else if let iconNode = self.iconNode {
                    self.iconNode = nil
                    iconNode.removeFromSupernode()
                }

                if self.language != language {
                    self.language = language
                    self.displayTitle = displayTitle
                    
                    self.accessibilityLabel = "\(displayTitle)"
                }
                
                self.highlightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor

                self.highlightBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)

                self.titleLabelNode.attributedText = NSAttributedString(string: self.displayTitle ?? "", font: Font.regular(17.0), textColor: presentationData.theme.contextMenu.primaryColor)
                let maxTextWidth: CGFloat = size.width - sideInset

                let titleSize = self.titleLabelNode.updateLayout(CGSize(width: maxTextWidth, height: 100.0))
                let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
                self.titleLabelNode.frame = titleFrame

                if language.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                    self.separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                    self.separatorNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 0.0), size: CGSize(width: size.width - 32.0, height: separatorHeight))
                    self.separatorNode.isHidden = false
                } else {
                    self.separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                    self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize(width: size.width, height: UIScreenPixel))
                    self.separatorNode.isHidden = true
                }
            }
        }

        private let context: AccountContext
        private let languages: [(String, String)]
        private let selectedLanguages: Set<String>?
        
        private let requestUpdate: (LanguagesListNode, ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (LanguagesListNode, ContainedViewLayoutTransition) -> Void
        private let selectLanguage: (String) -> Void

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
            languages: [(String, String)],
            selectedLanguages: Set<String>?,
            requestUpdate: @escaping (LanguagesListNode, ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (LanguagesListNode, ContainedViewLayoutTransition) -> Void,
            selectLanguage: @escaping (String) -> Void
        ) {
            self.context = context
            self.languages = languages
            self.selectedLanguages = selectedLanguages
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

            super.init()

            self.addSubnode(self.scrollNode)
            self.scrollNode.view.delegate = self.wrappedScrollViewDelegate

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
            let itemHeight: CGFloat = 44.0
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -180.0)

            var validIds = Set<Int>()

            let minVisibleIndex = max(0, Int(floor(visibleBounds.minY / itemHeight)))
            let maxVisibleIndex = Int(ceil(visibleBounds.maxY / itemHeight))
            
            var separatorIndices = Set<Int>()
            for i in 0 ..< self.languages.count {
                if self.languages[i].0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    separatorIndices.insert(i)
                }
            }
            
            if minVisibleIndex <= maxVisibleIndex {
                for index in minVisibleIndex ... maxVisibleIndex {
                    if index < self.languages.count {
                        let height = self.languages[index].0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? separatorHeight : itemHeight
                        var itemFrame = CGRect(origin: CGPoint(x: 0.0, y: CGFloat(index) * itemHeight), size: CGSize(width: size.width, height: height))
                        for i in separatorIndices {
                            if index > i {
                                itemFrame.origin.y += separatorHeight - itemHeight
                            }
                        }
                        
                        let (languageCode, displayTitle) = self.languages[index]
                        validIds.insert(index)
                        
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
                        
                        itemNode.update(size: itemFrame.size, presentationData: presentationData, language: languageCode, displayTitle: displayTitle, isSelected: isSelected, isLast: false, syncronousLoad: syncronousLoad)
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
            let itemHeight: CGFloat = 44.0

            self.presentationData = presentationData
            
            var separatorIndex = 0
            for i in 0 ..< self.languages.count {
                if self.languages[i].0.isEmpty {
                    separatorIndex = i
                    break
                }
            }
            
            var contentHeight: CGFloat
            if separatorIndex != 0 {
                contentHeight = CGFloat(self.languages.count - 1) * itemHeight + separatorHeight
            } else {
                contentHeight = CGFloat(self.languages.count) * itemHeight
            }
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
        private let languages: [(String, String)]
        private let selectedLanguages: Set<String>?
        
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private let requestUpdateApparentHeight: (ContainedViewLayoutTransition) -> Void

        private var presentationData: PresentationData

        private var backButtonNode: BackButtonNode?
        private var separatorNode: ASDisplayNode?

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
                self.separatorNode = ASDisplayNode()
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
                let backButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: topContentHeight), size: CGSize(width: constrainedSize.width, height: 44.0))
                backButtonNode.update(size: backButtonFrame.size, presentationData: self.presentationData, isLast: true)
                transition.updateFrame(node: backButtonNode, frame: backButtonFrame)
                topContentHeight += backButtonFrame.height
            }
            if let separatorNode = self.separatorNode {
                let separatorFrame = CGRect(origin: CGPoint(x: 16.0, y: topContentHeight), size: CGSize(width: constrainedSize.width - 32.0, height: separatorHeight))
                separatorNode.backgroundColor = self.presentationData.theme.contextMenu.itemSeparatorColor
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
