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

final class BrowserAddressListComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let navigateTo: (String) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        navigateTo: @escaping (String) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.navigateTo = navigateTo
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
        return true
    }
    
    private struct ItemLayout: Equatable {
        struct Section: Equatable {
            var id: Int
            var insets: UIEdgeInsets
            var itemHeight: CGFloat
            var itemCount: Int
            
            var totalHeight: CGFloat
            
            init(
                id: Int,
                insets: UIEdgeInsets,
                itemHeight: CGFloat,
                itemCount: Int
            ) {
                self.id = id
                self.insets = insets
                self.itemHeight = itemHeight
                self.itemCount = itemCount
                
                self.totalHeight = insets.top + itemHeight * CGFloat(itemCount) + insets.bottom
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
            let bookmarks: [Message]
        }
        
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
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.delegate = self
            self.scrollView.showsVerticalScrollIndicator = false
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.scrollView)
            self.scrollView.addSubview(self.itemContainerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError()
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.endEditing(true)
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
                            sectionTitle = "RECENTLY VISITED"
                        } else if section.id == 1 {
                            sectionTitle = "BOOKMARKS"
                        } else {
                            sectionTitle = ""
                        }
                        
                        let _ = sectionHeader.update(
                            transition: sectionHeaderTransition,
                            component: AnyComponent(SectionHeaderComponent(
                                theme: component.theme,
                                style: .plain,
                                title: sectionTitle,
                                actionTitle: section.id == 0 ? "Clear" : nil,
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
                                self.addSubview(sectionHeaderView)
                                
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
                    let itemFrame = CGRect(origin: CGPoint(x: sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                    if !visibleBounds.intersects(itemFrame) {
                        continue
                    }

                    var id = 0
                    if section.id == 0 {
                        id += i
                    } else if section.id == 1 {
                        id += 1000 + i
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
                                webPage = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: primaryUrl, displayUrl: "", hash: 0, type: nil, websiteName: "", title: message.text, text: "", embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, image: nil, file: nil, story: nil, attributes: [], instantPage: nil)))
                            }
                            itemMessage = message
                        } else {
                            continue
                        }
                    }
                    
                    let navigateTo = component.navigateTo
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            BrowserAddressListItemComponent(
                                context: component.context,
                                theme: component.theme,
                                webPage: webPage!,
                                message: itemMessage,
                                hasNext: true,
                                action: {
                                    if let url = webPage?.content.url {
                                        navigateTo(url)
                                    }
                                })
                        ),
                        environment: {},
                        containerSize: itemFrame.size
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
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
                    component.context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: component.context.account.peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 100, fixedCombinedReadStates: nil, tag: .tag(.webPage))
                ).start(next: { [weak self] recent, view in
                    guard let self else {
                        return
                    }
                    
                    var bookmarks: [Message] = []
                    for entry in view.0.entries.reversed() {
                        bookmarks.append(entry.message)
                    }
                    
                    self.stateValue = State(
                        recent: recent,
                        bookmarks: bookmarks
                    )
                    self.state?.updated(transition: .immediate)
                })
            }
            
            self.component = component
            self.state = state
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            if themeUpdated {
                self.backgroundView.backgroundColor = component.theme.list.plainBackgroundColor
            }
            
            let itemsContainerWidth = availableSize.width
            let addressItemSize = self.addressTemplateItem.update(
                transition: .immediate,
                component: AnyComponent(BrowserAddressListItemComponent(
                    context: component.context,
                    theme: component.theme,
                    webPage: TelegramMediaWebpage(webpageId: EngineMedia.Id(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: "https://telegram.org", displayUrl: "https://telegram.org", hash: 0, type: nil, websiteName: "Telegram", title: "Telegram Telegram", text: "Telegram", embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, image: nil, file: nil, story: nil, attributes: [], instantPage: nil))),
                    message: nil,
                    hasNext: true,
                    action: {}
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
            
            let _ = resetScrolling
            let _ = addressItemSize
            
            
            var sections: [ItemLayout.Section] = []
            if let state = self.stateValue {
                if !state.recent.isEmpty {
                    sections.append(ItemLayout.Section(
                        id: 0,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: addressItemSize.height,
                        itemCount: state.recent.count
                    ))
                }
                if !state.bookmarks.isEmpty {
                    sections.append(ItemLayout.Section(
                        id: 1,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: addressItemSize.height,
                        itemCount: state.bookmarks.count
                    ))
                }
            }
            
            let itemLayout = ItemLayout(containerSize: availableSize, insets: .zero, sections: sections)
            self.itemLayout = itemLayout
            
            let containerWidth = availableSize.width
            let scrollContentHeight = max(itemLayout.contentHeight, availableSize.height)
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height)))
            let contentSize = CGSize(width: containerWidth, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
//            let contentInset: UIEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomPanelHeight + bottomPanelInset, right: 0.0)
//            let indicatorInset = UIEdgeInsets(top: max(itemLayout.containerInset, environment.safeInsets.top + navigationHeight), left: 0.0, bottom: contentInset.bottom, right: 0.0)
//            if indicatorInset != self.scrollView.scrollIndicatorInsets {
//                self.scrollView.scrollIndicatorInsets = indicatorInset
//            }
//            if contentInset != self.scrollView.contentInset {
//                self.scrollView.contentInset = contentInset
//            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height))
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: availableSize))
            transition.setFrame(view: self.itemContainerView, frame: CGRect(origin: .zero, size: CGSize(width: containerWidth, height: scrollContentHeight)))
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
