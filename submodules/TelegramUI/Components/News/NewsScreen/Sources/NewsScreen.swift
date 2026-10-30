import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ContextUI
import SearchUI
import ChatListHeaderComponent

private final class NewsContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}

/// The News tab: For you and Added feeds under the chat list's header and search.
public final class NewsScreen: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    /// News draws its own header (no Display bar); its top row takes part in navigation transitions as a bar.
    override public var navigationBarTransitionSource: NavigationBarTransitionSource? {
        guard self.isNodeLoaded else {
            return nil
        }
        return self.newsNode.headerView
    }

    private var newsNode: NewsScreenNode {
        return self.displayNode as! NewsScreenNode
    }

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: nil)

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = self.presentationData.strings.News_Title
        self.tabBarItem.title = self.presentationData.strings.News_Title
        // A long press on the tab shows the "…" menu.
        self.tabBarItemContextActionType = .always
        let icon = UIImage(bundleImageName: "Chat List/Tabs/IconNews")?.withRenderingMode(.alwaysTemplate)
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon
        if !self.presentationData.reduceMotion {
            self.tabBarItem.animationName = "TabNews"
            self.tabBarItem.animationOffset = CGPoint(x: 0.0, y: UIScreenPixel)
        }

        self.scrollToTop = { [weak self] in
            guard let self, self.isNodeLoaded else {
                return
            }
            self.newsNode.scrollToTop()
        }

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            if presentationData.theme !== self.presentationData.theme || presentationData.strings !== self.presentationData.strings {
                self.presentationData = presentationData
                self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
                self.title = presentationData.strings.News_Title
                self.tabBarItem.title = presentationData.strings.News_Title
                if self.isNodeLoaded {
                    self.newsNode.updatePresentationData(presentationData)
                }
            }
        })
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
    }

    override public func loadDisplayNode() {
        self.displayNode = NewsScreenNode(context: self.context, controller: self)
        self.newsNode.requestActivateSearch = { [weak self] in
            self?.activateSearch()
        }
        self.newsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        self.newsNode.openMoreMenu = { [weak self] sourceView in
            self?.openMoreMenu(sourceView: sourceView)
        }
        self.newsNode.openPostMenu = { [weak self] contentView, gesture, menu in
            self?.openPostMenu(contentView: contentView, gesture: gesture, menu: menu)
        }
        // `ViewController.ready` already starts as true; the screen shows placeholders until data arrives.
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.newsNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, transition: transition)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.newsNode.didAppear()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.newsNode.didDisappear()
    }

    private func searchContentNode() -> NavigationBarSearchContentNode? {
        return self.newsNode.headerView.searchContentNode
    }

    private func activateSearch() {
        self.newsNode.activateSearch(placeholderNode: self.searchContentNode()?.placeholderNode)
        (self.parent as? TabBarController)?.updateIsTabBarHidden(true, transition: .animated(duration: 0.5, curve: .spring))
        self.requestLayout(transition: .animated(duration: 0.5, curve: .spring))
    }

    private func deactivateSearch(animated: Bool) {
        self.newsNode.deactivateSearch(placeholderNode: self.searchContentNode()?.placeholderNode, animated: animated)
        (self.parent as? TabBarController)?.updateIsTabBarHidden(false, transition: .animated(duration: 0.5, curve: .spring))
        self.requestLayout(transition: .animated(duration: 0.5, curve: .spring))
    }

    override public func tabBarItemContextAction(sourceView: ContextExtractedContentContainingView, gesture: ContextGesture) {
        let contextController = makeContextController(presentationData: self.presentationData, source: .reference(NewsTabBarContextReferenceContentSource(controller: self, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(self.moreMenuItems()))), recognizer: nil, gesture: gesture)
        self.context.sharedContext.mainWindow?.presentInGlobalOverlay(contextController)
    }

    private func openMoreMenu(sourceView: UIView) {
        let contextController = makeContextController(presentationData: self.presentationData, source: .reference(NewsContextReferenceContentSource(controller: self, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(self.moreMenuItems()))), gesture: nil)
        self.presentInGlobalOverlay(contextController)
    }

    /// A post row's context menu: For you's votes, Show in Chat and Forward.
    private func openPostMenu(contentView: ContextExtractedContentContainingView, gesture: ContextGesture, menu: NewsPostMenu) {
        let strings = self.presentationData.strings
        var items: [ContextMenuItem] = []
        if menu.hasFeedbackActions {
            items.append(.action(ContextMenuActionItem(text: strings.News_Swipe_Interesting, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ThumbsUp"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.default)
                menu.interesting()
            })))
            items.append(.action(ContextMenuActionItem(text: strings.News_Swipe_NotInterested, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ThumbsDown"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.default)
                // Feed2 Motion.afterMenu: the menu closes first.
                Queue.mainQueue().after(0.25, {
                    menu.notInterested()
                })
            })))
            items.append(.separator)
        }
        items.append(.action(ContextMenuActionItem(text: strings.MediaPlayer_ContextMenu_ShowInChat, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.default)
            Queue.mainQueue().after(0.25, {
                menu.showInChat()
            })
        })))
        items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuForward, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.default)
            Queue.mainQueue().after(0.25, {
                menu.forward()
            })
        })))
        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(NewsPostContextExtractedContentSource(contentView: contentView)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }

    /// The "…" menu's items: Reload, Mark all as read, and the Compact / Expanded choice.
    private func moreMenuItems() -> [ContextMenuItem] {
        let strings = self.presentationData.strings
        let displayMode = self.newsNode.displayMode
        var items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: strings.News_ReloadFeed, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reload"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                // Feed2 Motion.afterMenu: the menu closes first.
                Queue.mainQueue().after(0.25, {
                    self?.newsNode.reloadFeed()
                })
            })),
            .action(ContextMenuActionItem(text: strings.News_MarkAllAsRead, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReadAll"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                self?.newsNode.markAllAsRead()
            })),
            .separator
        ]
        // Compact or expanded posts: the size icon on the left (`iconPosition: .left`), the current one checked on the
        // right, where the item draws its `additionalLeftIcon` despite the name (the rich-text editor's list items).
        for (mode, title, iconName) in [(NewsFeedDisplayMode.compact, strings.News_Display_Compact, "Chat/Context Menu/MediaSizeCollapse"), (NewsFeedDisplayMode.expanded, strings.News_Display_Expanded, "Chat/Context Menu/MediaSizeExpand")] {
            items.append(.action(ContextMenuActionItem(text: title, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: iconName), color: theme.contextMenu.primaryColor)
            }, additionalLeftIcon: { theme in
                return displayMode == mode ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, iconPosition: .left, action: { [weak self] _, f in
                f(.default)
                // The rows morph once the menu is on its way out, so the two motions do not compete.
                Queue.mainQueue().after(0.25, {
                    self?.newsNode.setDisplayMode(mode)
                })
            })))
        }
        return items
    }
}

/// A post row's menu lifts the row's content out of the list, over the blurred screen (as the chat list's does).
private final class NewsPostContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true

    private let contentView: ContextExtractedContentContainingView

    init(contentView: ContextExtractedContentContainingView) {
        self.contentView = contentView
    }

    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: mainWindowScreenBounds)
    }

    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}

/// The tab bar item's menu stays by the item.
private final class NewsTabBarContextReferenceContentSource: ContextReferenceContentSource {
    let keepInPlace: Bool = true

    private let controller: ViewController
    private let sourceView: ContextExtractedContentContainingView

    init(controller: ViewController, sourceView: ContextExtractedContentContainingView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView.contentView, contentAreaInScreenSpace: mainWindowScreenBounds, actionsPosition: .top)
    }
}
