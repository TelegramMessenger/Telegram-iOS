import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
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

    private func openMoreMenu(sourceView: UIView) {
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: self.presentationData.strings.News_ReloadFeed, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reload"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                // Feed2 Motion.afterMenu: the menu closes first.
                Queue.mainQueue().after(0.25, {
                    self?.newsNode.reloadFeed()
                })
            })),
            .action(ContextMenuActionItem(text: self.presentationData.strings.News_MarkAllAsRead, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReadAll"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                self?.newsNode.markAllAsRead()
            }))
        ]
        let contextController = makeContextController(presentationData: self.presentationData, source: .reference(NewsContextReferenceContentSource(controller: self, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        self.presentInGlobalOverlay(contextController)
    }
}
