import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import ContextUI
import UndoUI
import ListActionItemComponent

final class BrowserAddressListComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
    let metrics: LayoutMetrics
    let addressBarFrame: CGRect
    let performAction: ActionSlot<BrowserScreen.Action>
    let presentInGlobalOverlay: (ViewController) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        insets: UIEdgeInsets,
        metrics: LayoutMetrics,
        addressBarFrame: CGRect,
        performAction: ActionSlot<BrowserScreen.Action>,
        presentInGlobalOverlay: @escaping (ViewController) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.metrics = metrics
        self.addressBarFrame = addressBarFrame
        self.performAction = performAction
        self.presentInGlobalOverlay = presentInGlobalOverlay
    }
    
    static func ==(lhs: BrowserAddressListComponent, rhs: BrowserAddressListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.metrics != rhs.metrics {
            return false
        }
        if lhs.addressBarFrame != rhs.addressBarFrame {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        struct Section: Equatable {
            var id: Int
            var insets: UIEdgeInsets
            var itemHeight: CGFloat
            var itemCount: Int
            var hasMore: Bool
            
            var totalHeight: CGFloat
            
            init(
                id: Int,
                insets: UIEdgeInsets,
                itemHeight: CGFloat,
                itemCount: Int,
                hasMore: Bool
            ) {
                self.id = id
                self.insets = insets
                self.itemHeight = itemHeight
                self.itemCount = itemCount
                self.hasMore = hasMore
                
                var totalHeight = insets.top + itemHeight * CGFloat(itemCount) + insets.bottom
                if hasMore {
                    totalHeight -= itemHeight
                    totalHeight += 44.0
                }
                self.totalHeight = totalHeight
            }
        }
        
        var containerSize: CGSize
        var insets: UIEdgeInsets
        var sections: [Section]
        
        var contentHeight: CGFloat
        
        init(
            containerSize: CGSize,
            insets: UIEdgeInsets,
            sections: [Section]
        ) {
            self.containerSize = containerSize
            self.insets = insets
            self.sections = sections
            
            var contentHeight: CGFloat = 0.0
            for section in sections {
                contentHeight += section.totalHeight
            }
            self.contentHeight = contentHeight
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
        
    final class View: UIView, UIScrollViewDelegate {
        struct State {
            let recent: [TelegramMediaWebpage]
            let isRecentExpanded: Bool
            let bookmarks: [Message]
        }
        
        private let outerView = UIButton()
        private let shadowView = UIImageView()
        private let backgroundView = UIView()
        private let scrollView = ScrollView()
        private let itemContainerView = UIView()
        
        private let addressTemplateItem = ComponentView<Empty>()
        
        private var visibleSectionHeaders: [Int: ComponentView<Empty>] = [:]
        private var visibleItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var ignoreScrolling: Bool = false
        
        private var component: BrowserAddressListComponent?
        private weak var state: EmptyComponentState?
        private var itemLayout: ItemLayout?
        
        private var stateDisposable: Disposable?
        private var stateValue: State?
        private let isRecentExpanded = ValuePromise<Bool>(false)
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundView.clipsToBounds = true
            
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.delegate = self
            self.scrollView.showsVerticalScrollIndicator = false
            
            self.addSubview(self.outerView)
            self.addSubview(self.shadowView)
            self.addSubview(self.backgroundView)
            self.backgroundView.addSubview(self.scrollView)
            self.scrollView.addSubview(self.itemContainerView)
            
            self.outerView.addTarget(self, action: #selector(self.outerPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError()
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        @objc private func outerPressed() {
            self.component?.performAction.invoke(.closeAddressBar)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.window?.endEditing(true)
            
            cancelContextGestures(view: scrollView)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let itemLayout = self.itemLayout, let state = self.stateValue else {
                return
            }
            
            var topOffset = -self.scrollView.bounds.minY
            topOffset = max(0.0, topOffset)
            
            let visibleBounds = self.scrollView.bounds
            var visibleFrame = self.scrollView.frame
            visibleFrame.origin.x = 0.0
            
            var validIds: [AnyHashable] = []
            var validSectionHeaders: [AnyHashable] = []
            var sectionOffset: CGFloat = 0.0
            
            let sideInset: CGFloat = 0.0
            let containerInset: CGFloat = 0.0
            
            for sectionIndex in 0 ..< itemLayout.sections.count {
                let section = itemLayout.sections[sectionIndex]
                
                do {
                    var sectionHeaderFrame = CGRect(origin: CGPoint(x: sideInset, y: sectionOffset - self.scrollView.bounds.minY), size: CGSize(width: itemLayout.containerSize.width, height: section.insets.top))

                    let sectionHeaderMinY = topOffset + containerInset
                    let sectionHeaderMaxY = containerInset + sectionOffset - self.scrollView.bounds.minY + section.totalHeight - 28.0
                    
                    sectionHeaderFrame.origin.y = max(sectionHeaderFrame.origin.y, sectionHeaderMinY)
                    sectionHeaderFrame.origin.y = min(sectionHeaderFrame.origin.y, sectionHeaderMaxY)
                    
                    if visibleFrame.intersects(sectionHeaderFrame) {
                        validSectionHeaders.append(section.id)
                        let sectionHeader: ComponentView<Empty>
                        var sectionHeaderTransition = transition
                        if let current = self.visibleSectionHeaders[section.id] {
                            sectionHeader = current
                        } else {
                            if !transition.animation.isImmediate {
                                sectionHeaderTransition = .immediate
                            }
                            sectionHeader = ComponentView()
                            self.visibleSectionHeaders[section.id] = sectionHeader
                        }
                        
                        let sectionTitle: String
                        if section.id == 0 {
                            sectionTitle = component.strings.WebBrowser_AddressBar_RecentlyVisited
                        } else if section.id == 1 {
                            sectionTitle = component.strings.WebBrowser_AddressBar_Bookmarks
                        } else {
                            sectionTitle = ""
                        }
                        
                        let _ = sectionHeader.update(
                            transition: sectionHeaderTransition,
                            component: AnyComponent(SectionHeaderComponent(
                                theme: component.theme,
                                style: .plain,
                                title: sectionTitle,
                                insets: component.insets,
                                actionTitle: section.id == 0 ? component.strings.WebBrowser_AddressBar_RecentlyVisited_Clear : nil,
                                action: { [weak self] in
                                    if let self, let component = self.component {
                                        let _ = clearRecentlyVisitedLinks(engine: component.context.engine).start()
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: sectionHeaderFrame.size
                        )
                        if let sectionHeaderView = sectionHeader.view {
                            if sectionHeaderView.superview == nil {
                                self.backgroundView.addSubview(sectionHeaderView)
                                
                                if !transition.animation.isImmediate {
                                    sectionHeaderView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                                }
                            }
                            let sectionXOffset = self.scrollView.frame.minX
                            sectionHeaderTransition.setFrame(view: sectionHeaderView, frame: sectionHeaderFrame.offsetBy(dx: sectionXOffset, dy: 0.0))
                        }
                    }
                }
                
                for i in 0 ..< section.itemCount {
                    var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                    if !visibleBounds.intersects(itemFrame) {
                        continue
                    }
                    
                    var isMore = false
                    if section.hasMore && i == 3 {
                        isMore = true
                        itemFrame.size.height = 44.0
                    }
                    
                    var id: String = ""
                    if section.id == 0 {
                        id = "recent_\(state.recent[i].content.url ?? "")"
                        if isMore {
                            id = "recent_more"
                        }
                    } else if section.id == 1 {
                        id = "bookmark_\(state.bookmarks[i].id.id)"
                        if isMore {
                            id = "bookmark_more"
                        }
                    }
                    
                    let itemId = AnyHashable(id)
                    validIds.append(itemId)
                    
                    var itemTransition = transition
                    let visibleItem: ComponentView<Empty>
                    if let current = self.visibleItems[itemId] {
                        visibleItem = current
                    } else {
                        visibleItem = ComponentView()
                        if !transition.animation.isImmediate {
                            itemTransition = .immediate
                        }
                        self.visibleItems[itemId] = visibleItem
                    }
                    
                    if isMore {
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(
                                ListActionItemComponent(
                                    theme: component.theme,
                                    title: AnyComponent(Text(
                                        text: component.strings.WebBrowser_AddressBar_ShowMore,
                                        font: Font.regular(17.0),
                                        color: component.theme.list.itemAccentColor
                                    )),
                                    leftIcon: .custom(
                                        AnyComponentWithIdentity(
                                            id: "icon",
                                            component: AnyComponent(Image(
                                                image: PresentationResourcesItemList.downArrowImage(component.theme),
                                                size: CGSize(width: 30.0, height: 30.0)
                                            ))
                                        ),
                                        false
                                    ),
                                    accessory: nil,
                                    action: { [weak self] _ in
                                        self?.isRecentExpanded.set(true)
                                    },
                                    highlighting: .default,
                                    updateIsHighlighted: { view, _ in
                                        
                                    }
                                )
                            ),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                    } else {
                        var webPage: TelegramMediaWebpage?
                        var itemMessage: Message?
                        
                        if section.id == 0 {
                            webPage = state.recent[i]
                        } else if section.id == 1 {
                            let message = state.bookmarks[i]
                            if let primaryUrl = getPrimaryUrl(message: message) {
                                if let media = message.media.first(where: { $0 is TelegramMediaWebpage }) as? TelegramMediaWebpage {
                                    webPage = media
                                } else {
                                    webPage = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: primaryUrl, displayUrl: "", hash: 0, type: nil, websiteName: "", title: message.text, text: "", embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil, story: nil, attributes: [], instantPage: nil)))
                                }
                                itemMessage = message
                            } else {
                                continue
                            }
                        }
                    
                        let performAction = component.performAction
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(
                                BrowserAddressListItemComponent(
                                    context: component.context,
                                    theme: component.theme,
                                    webPage: webPage!,
                                    message: itemMessage,
                                    hasNext: true,
                                    insets: component.insets,
                                    action: {
                                        if let url = webPage?.content.url {
                                            performAction.invoke(.navigateTo(url, false))
                                        }
                                    },
                                    contextAction: { [weak self] webPage, message, sourceView, gesture in
                                        guard let self, let component = self.component, let url = webPage.content.url else {
                                            return
                                        }
                                        
                                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                        
                                        var itemList: [ContextMenuItem] = []
                                        itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.WebBrowser_CopyLink, icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
                                        }, action: { [weak self] _, f in
                                            f(.default)
                                            
                                            UIPasteboard.general.string = url
                                            if let self, let component = self.component {
                                                component.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
                                            }
                                        })))
                                        
                                        if let message {
                                            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.WebBrowser_DeleteBookmark, textColor: .destructive, icon: { theme in
                                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                                            }, action: { [weak self] _, f in
                                                f(.dismissWithoutContent)
                                                
                                                if let self, let component = self.component {
                                                    let _ = component.context.engine.messages.deleteMessagesInteractively(messageIds: [message.id], type: .forEveryone).startStandalone()
                                                }
                                            })))
                                        } else {
                                            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.WebBrowser_RemoveRecent, textColor: .destructive, icon: { theme in
                                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                                            }, action: { [weak self] _, f in
                                                f(.dismissWithoutContent)
                                                
                                                if let self, let component = self.component, let url = webPage.content.url {
                                                    let _ = removeRecentlyVisitedLink(engine: component.context.engine, url: url).startStandalone()
                                                }
                                            })))
                                        }
                                        
                                        let items = ContextController.Items(content: .list(itemList))
                                        let controller = ContextController(
                                            presentationData: presentationData,
                                            source: .extracted(BrowserAddressListContextExtractedContentSource(contentView: sourceView)),
                                            items: .single(items),
                                            recognizer: nil,
                                            gesture: gesture
                                        )
                                        component.presentInGlobalOverlay(controller)
                                    })
                            ),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                    }
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                            if !transition.animation.isImmediate {
                                transition.animateAlpha(view: itemView, from: 0.0, to: 1.0)
                            }
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                
                sectionOffset += section.totalHeight
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            var removeSectionHeaderIds: [Int] = []
            for (id, item) in self.visibleSectionHeaders {
                if !validSectionHeaders.contains(id) {
                    removeSectionHeaderIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeSectionHeaderIds {
                self.visibleSectionHeaders.removeValue(forKey: id)
            }
        }
        
        func update(component: BrowserAddressListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            if self.component == nil {
                self.stateDisposable = combineLatest(queue: Queue.mainQueue(),
                    recentlyVisitedLinks(engine: component.context.engine),
                    self.isRecentExpanded.get(),
                    component.context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: component.context.account.peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 100, fixedCombinedReadStates: nil, tag: .tag(.webPage))
                ).start(next: { [weak self] recent, isRecentExpanded, view in
                    guard let self else {
                        return
                    }
                    
                    var bookmarks: [Message] = []
                    for entry in view.0.entries.reversed() {
                        bookmarks.append(entry.message)
                    }
                    
                    let isFirstTime = self.stateValue == nil
                    self.stateValue = State(
                        recent: recent,
                        isRecentExpanded: isRecentExpanded,
                        bookmarks: bookmarks
                    )
                    self.state?.updated(transition: isFirstTime ? .immediate : .easeInOut(duration: 0.25))
                })
            }
            
            self.component = component
            self.state = state
            
            self.outerView.isHidden = !component.metrics.isTablet
            self.outerView.frame = CGRect(origin: .zero, size: availableSize)
            
            let containerFrame: CGRect
            if component.metrics.isTablet {
                let containerSize = CGSize(width: component.addressBarFrame.width + 32.0, height: 540.0)
                containerFrame = CGRect(origin: CGPoint(x: floor(component.addressBarFrame.center.x - containerSize.width / 2.0), y: 72.0), size: containerSize)
                
                self.backgroundView.layer.cornerRadius = 10.0
            } else {
                containerFrame = CGRect(origin: .zero, size: availableSize)
                
                self.backgroundView.layer.cornerRadius = 0.0
            }
            
            let resetScrolling = self.scrollView.bounds.width != containerFrame.width
            if themeUpdated {
                self.backgroundView.backgroundColor = component.theme.list.plainBackgroundColor
            }
            
            let itemsContainerWidth = availableSize.width
            let addressItemSize = self.addressTemplateItem.update(
                transition: .immediate,
                component: AnyComponent(BrowserAddressListItemComponent(
                    context: component.context,
                    theme: component.theme,
                    webPage: TelegramMediaWebpage(webpageId: EngineMedia.Id(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: "https://telegram.org", displayUrl: "https://telegram.org", hash: 0, type: nil, websiteName: "Telegram", title: "Telegram Telegram", text: "Telegram", embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil, story: nil, attributes: [], instantPage: nil))),
                    message: nil,
                    hasNext: true,
                    insets: .zero,
                    action: {},
                    contextAction: nil
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
            
            var sections: [ItemLayout.Section] = []
            if let state = self.stateValue {
                if !state.recent.isEmpty {
                    var recentCount = state.recent.count
                    var hasMore = false
                    if recentCount > 4 && !state.isRecentExpanded {
                        recentCount = 4
                        hasMore = true
                    }
                    sections.append(ItemLayout.Section(
                        id: 0,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: addressItemSize.height,
                        itemCount: recentCount,
                        hasMore: hasMore
                    ))
                }
                if !state.bookmarks.isEmpty {
                    sections.append(ItemLayout.Section(
                        id: 1,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: addressItemSize.height,
                        itemCount: state.bookmarks.count,
                        hasMore: false
                    ))
                }
            }
            
            let itemLayout = ItemLayout(containerSize: containerFrame.size, insets: .zero, sections: sections)
            self.itemLayout = itemLayout
            
            let containerWidth = containerFrame.size.width
            let scrollContentHeight = max(itemLayout.contentHeight, containerFrame.size.height)
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: .zero, size: containerFrame.size))
            let contentSize = CGSize(width: containerWidth, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: containerFrame.size.height))
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            transition.setFrame(view: self.backgroundView, frame: containerFrame)
            transition.setFrame(view: self.itemContainerView, frame: CGRect(origin: .zero, size: CGSize(width: containerWidth, height: scrollContentHeight)))
            
            if component.metrics.isTablet {
                transition.setFrame(view: self.shadowView, frame: containerFrame.insetBy(dx: -60.0, dy: -60.0))
                self.shadowView.isHidden = false
                if self.shadowView.image == nil {
                    self.shadowView.image = generateShadowImage()
                }
            } else {
                self.shadowView.isHidden = true
            }
            
            return availableSize
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if let component = self.component, component.metrics.isTablet {
                let addressFrame = CGRect(origin: CGPoint(x: self.backgroundView.frame.minX, y: self.backgroundView.frame.minY - 48.0), size: CGSize(width: self.backgroundView.frame.width, height: 48.0))
                if addressFrame.contains(point) {
                    return nil
                }
            }
            return result
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateShadowImage() -> UIImage? {
    return generateImage(CGSize(width: 140.0, height: 140.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.saveGState()
        context.setShadow(offset: CGSize(), blur: 60.0, color: UIColor(white: 0.0, alpha: 0.4).cgColor)

        let path = UIBezierPath(roundedRect: CGRect(x: 60.0, y: 60.0, width: 20.0, height: 20.0), cornerRadius: 10.0).cgPath
        context.addPath(path)
        context.fillPath()
        
        context.restoreGState()
        
        context.setBlendMode(.clear)
        context.addPath(path)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 70, topCapHeight: 70)
}

private final class BrowserAddressListContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private let contentView: ContextExtractedContentContainingView
    
    init(contentView: ContextExtractedContentContainingView) {
        self.contentView = contentView
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}
