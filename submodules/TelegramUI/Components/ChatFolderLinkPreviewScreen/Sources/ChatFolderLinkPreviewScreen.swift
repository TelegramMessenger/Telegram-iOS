import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import Postbox
import SolidRoundedButtonComponent
import PresentationDataUtils
import Markdown
import UndoUI
import PremiumUI
import ButtonComponent
import ContextUI
import QrCodeUI
import InviteLinksUI
import PlainButtonComponent
import AnimatedCounterComponent

private final class ChatFolderLinkPreviewScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: ChatFolderLinkPreviewScreen.Subject
    let linkContents: ChatFolderLinkContents?
    let completion: (() -> Void)?
    
    init(
        context: AccountContext,
        subject: ChatFolderLinkPreviewScreen.Subject,
        linkContents: ChatFolderLinkContents?,
        completion: (() -> Void)?
    ) {
        self.context = context
        self.subject = subject
        self.linkContents = linkContents
        self.completion = completion
    }
    
    static func ==(lhs: ChatFolderLinkPreviewScreenComponent, rhs: ChatFolderLinkPreviewScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.linkContents !== rhs.linkContents {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        var contentHeight: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat, contentHeight: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.contentHeight = contentHeight
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class AnimationHint {
        init() {
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        private let bottomBackgroundLayer: SimpleLayer
        private let bottomSeparatorLayer: SimpleLayer
        
        private let topIcon = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let leftButton = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private let listHeaderText = ComponentView<Empty>()
        private let listHeaderAction = ComponentView<Empty>()
        private let itemContainerView: UIView
        private var items: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var selectedItems = Set<EnginePeer.Id>()
        
        private var linkListItems: [ExportedChatFolderLink] = []
        
        private let bottomOverscrollLimit: CGFloat
        
        private var ignoreScrolling: Bool = false
        
        private var component: ChatFolderLinkPreviewScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        private var joinDisposable: Disposable?
        
        private var inProgress: Bool = false
        
        override init(frame: CGRect) {
            self.bottomOverscrollLimit = 200.0
            
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.itemContainerView = UIView()
            self.itemContainerView.clipsToBounds = true
            self.itemContainerView.layer.cornerRadius = 10.0
            
            self.bottomBackgroundLayer = SimpleLayer()
            self.bottomSeparatorLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
            
            self.addSubview(self.navigationBarContainer)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.scrollContentView.addSubview(self.itemContainerView)
            
            self.layer.addSublayer(self.bottomBackgroundLayer)
            self.layer.addSublayer(self.bottomSeparatorLayer)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.joinDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let itemLayout = self.itemLayout, let topOffsetDistance = self.topOffsetDistance else {
                return
            }
            
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            if topOffset > 0.0 {
                topOffset = max(0.0, topOffset)
                
                if topOffset < topOffsetDistance {
                    targetContentOffset.pointee.y = scrollView.contentOffset.y
                    scrollView.setContentOffset(CGPoint(x: 0.0, y: itemLayout.topInset), animated: true)
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func updateScrolling(transition: Transition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            let bottomDistance = itemLayout.contentHeight - self.scrollView.bounds.maxY
            let bottomAlphaDistance: CGFloat = 30.0
            var bottomAlpha: CGFloat = bottomDistance / bottomAlphaDistance
            bottomAlpha = max(0.0, min(1.0, bottomAlpha))
            
            let bottomOverlayAlpha: CGFloat = bottomAlpha
            transition.setAlpha(layer: self.bottomBackgroundLayer, alpha: bottomOverlayAlpha)
            transition.setAlpha(layer: self.bottomSeparatorLayer, alpha: bottomOverlayAlpha)
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: transition.containedViewLayoutTransition)
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomBackgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomSeparatorLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            if let controller = self.environment?.controller() {
                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
            
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomBackgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomSeparatorLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
        }
        
        func update(component: ChatFolderLinkPreviewScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            let animationHint = transition.userData(AnimationHint.self)
            
            var contentTransition = transition
            if animationHint != nil {
                contentTransition = .immediate
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0
            
            if self.component?.linkContents == nil, let linkContents = component.linkContents {
                if case let .remove(_, defaultSelectedPeerIds) = component.subject {
                    for peer in linkContents.peers {
                        if defaultSelectedPeerIds.contains(peer.id) {
                            self.selectedItems.insert(peer.id)
                        }
                    }
                } else {
                    for peer in linkContents.peers {
                        self.selectedItems.insert(peer.id)
                    }
                }
            }
            
            if self.component == nil, case let .linkList(_, initialLinks) = component.subject {
                self.linkListItems = initialLinks
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.list.blocksBackgroundColor.cgColor
                self.itemContainerView.backgroundColor = environment.theme.list.itemBlocksBackgroundColor
                self.bottomBackgroundLayer.backgroundColor = environment.theme.rootController.navigationBar.opaqueBackgroundColor.cgColor
                self.bottomSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            
            let leftButtonSize = self.leftButton.update(
                transition: contentTransition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.list.itemAccentColor)),
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        controller.dismiss()
                    }
                ).minSize(CGSize(width: 44.0, height: 56.0))),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            let leftButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: 0.0), size: leftButtonSize)
            if let leftButtonView = self.leftButton.view {
                if leftButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(leftButtonView)
                }
                transition.setFrame(view: leftButtonView, frame: leftButtonFrame)
            }
            
            let titleString: String
            var allChatsAdded = false
            if case .linkList = component.subject {
                //TODO:localize
                titleString = "Share Folder"
            } else if let linkContents = component.linkContents {
                //TODO:localize
                if case .remove = component.subject {
                    titleString = "Remove Folder"
                } else if linkContents.localFilterId != nil {
                    if linkContents.alreadyMemberPeerIds == Set(linkContents.peers.map(\.id)) {
                        allChatsAdded = true
                    }
                    
                    if allChatsAdded {
                        titleString = "Add Folder"
                    } else if linkContents.peers.count == 1 {
                        titleString = "Add \(linkContents.peers.count) chat"
                    } else {
                        titleString = "Add \(linkContents.peers.count) chats"
                    }
                } else {
                    titleString = "Add Folder"
                }
            } else {
                titleString = " "
            }
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftButtonFrame.maxX * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: 18.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                contentTransition.setFrame(view: titleView, frame: titleFrame)
            }
            
            contentHeight += 44.0
            contentHeight += 14.0
            
            var topBadge: String?
            if case .linkList = component.subject {
            } else if case .remove = component.subject {
            } else if !allChatsAdded, let linkContents = component.linkContents, linkContents.localFilterId != nil {
                topBadge = "+\(linkContents.peers.count)"
            }
            
            let topIconSize = self.topIcon.update(
                transition: contentTransition,
                component: AnyComponent(ChatFolderLinkHeaderComponent(
                    theme: environment.theme,
                    strings: environment.strings,
                    title: component.linkContents?.title ?? "Folder",
                    badge: topBadge
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset, height: 1000.0)
            )
            let topIconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - topIconSize.width) * 0.5), y: contentHeight), size: topIconSize)
            if let topIconView = self.topIcon.view {
                if topIconView.superview == nil {
                    self.scrollContentView.addSubview(topIconView)
                }
                contentTransition.setFrame(view: topIconView, frame: topIconFrame)
                topIconView.isHidden = component.linkContents == nil
            }
            
            contentHeight += topIconSize.height
            contentHeight += 20.0
            
            let text: String
            if case .linkList = component.subject {
                text = "Create more links to set up different access\nlevels for different people."
            } else if let linkContents = component.linkContents {
                if case .remove = component.subject {
                    text = "Do you also want to quit the chats included in this folder?"
                } else if allChatsAdded {
                    text = "You have already added this\nfolder and its chats."
                } else if linkContents.localFilterId == nil {
                    text = "Do you want to add a new chat folder\nand join its groups and channels?"
                } else {
                    let chatCountString: String
                    if linkContents.peers.count == 1 {
                        chatCountString = "1 chat"
                    } else {
                        chatCountString = "\(linkContents.peers.count) chats"
                    }
                    if let title = linkContents.title {
                        text = "Do you want to add **\(chatCountString)** to your\nfolder **\(title)**?"
                    } else {
                        text = "Do you want to add **\(chatCountString)** chats to your\nfolder?"
                    }
                }
            } else {
                text = " "
            }
            
            let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.freeTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.freeTextColor)
            
            let descriptionTextSize = self.descriptionText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(text: text, attributes: MarkdownAttributes(
                        body: body,
                        bold: bold,
                        link: body,
                        linkAttribute: { _ in nil }
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 1000.0)
            )
            let descriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionTextSize.width) * 0.5), y: contentHeight), size: descriptionTextSize)
            if let descriptionTextView = self.descriptionText.view {
                if descriptionTextView.superview == nil {
                    self.scrollContentView.addSubview(descriptionTextView)
                }
                descriptionTextView.bounds = CGRect(origin: CGPoint(), size: descriptionTextFrame.size)
                contentTransition.setPosition(view: descriptionTextView, position: descriptionTextFrame.center)
            }
            
            contentHeight += descriptionTextFrame.height
            contentHeight += 39.0
            
            var singleItemHeight: CGFloat = 0.0
            
            var itemsHeight: CGFloat = 0.0
            var validIds: [AnyHashable] = []
            if case let .linkList(folderId, _) = component.subject {
                do {
                    let id = AnyHashable("action")
                    validIds.append(id)
                    
                    let item: ComponentView<Empty>
                    var itemTransition = transition
                    if let current = self.items[id] {
                        item = current
                    } else {
                        itemTransition = .immediate
                        item = ComponentView()
                        self.items[id] = item
                    }
                    
                    let itemSize = item.update(
                        transition: itemTransition,
                        component: AnyComponent(ActionListItemComponent(
                            theme: environment.theme,
                            sideInset: 0.0,
                            iconName: "Contact List/LinkActionIcon",
                            title: "Create a New Link",
                            hasNext: !self.linkListItems.isEmpty,
                            action: { [weak self] in
                                self?.openCreateLink()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize)
                    
                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                    
                    itemsHeight += itemSize.height
                    singleItemHeight = itemSize.height
                }
                
                for i in 0 ..< self.linkListItems.count {
                    let link = self.linkListItems[i]
                    
                    let id = AnyHashable(link.link)
                    validIds.append(id)
                    
                    let item: ComponentView<Empty>
                    var itemTransition = transition
                    if let current = self.items[id] {
                        item = current
                    } else {
                        itemTransition = .immediate
                        item = ComponentView()
                        self.items[id] = item
                    }
                    
                    let subtitle: String
                    if link.peerIds.count == 1 {
                        subtitle = "includes 1 chat"
                    } else {
                        subtitle = "includes \(link.peerIds.count) chats"
                    }
                    
                    let itemComponent = LinkListItemComponent(
                        theme: environment.theme,
                        sideInset: 0.0,
                        title: link.title.isEmpty ? link.link : link.title,
                        link: link,
                        label: subtitle,
                        selectionState: .none,
                        hasNext: i != self.linkListItems.count - 1,
                        action: { [weak self] link in
                            guard let self else {
                                return
                            }
                            self.openLink(link: link)
                        },
                        contextAction: { [weak self] link, sourceView, gesture in
                            guard let self, let component = self.component, let environment = self.environment else {
                                return
                            }
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            
                            var itemList: [ContextMenuItem] = []
                            
                            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.default)
                                
                                UIPasteboard.general.string = link.link
                                
                                if let self, let component = self.component, let controller = self.environment?.controller() {
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    controller.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                }
                            })))
                            
                            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                if let self, let component = self.component, let controller = self.environment?.controller() {
                                    controller.present(QrCodeScreen(context: component.context, updatedPresentationData: nil, subject: .chatFolder(slug: link.slug)), in: .window(.root))
                                }
                            })))
                            
                            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                if let self, let component = self.component {
                                    self.linkListItems.removeAll(where: { $0.link == link.link })
                                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                                    
                                    let context = component.context
                                    let _ = (context.engine.peers.editChatFolderLink(filterId: folderId, link: link, title: nil, peerIds: nil, revoke: true)
                                    |> deliverOnMainQueue).start(completed: {
                                        let _ = (context.engine.peers.deleteChatFolderLink(filterId: folderId, link: link)
                                        |> deliverOnMainQueue).start(completed: {
                                        })
                                    })
                                }
                            })))
                            
                            let items = ContextController.Items(content: .list(itemList))
                            
                            let controller = ContextController(
                                account: component.context.account,
                                presentationData: presentationData,
                                source: .extracted(LinkListContextExtractedContentSource(contentView: sourceView)),
                                items: .single(items),
                                recognizer: nil,
                                gesture: gesture
                            )
                            
                            environment.controller()?.forEachController({ controller in
                                if let controller = controller as? UndoOverlayController {
                                    controller.dismiss()
                                }
                                return true
                            })
                            environment.controller()?.presentInGlobalOverlay(controller)
                        }
                    )
                    
                    let itemSize = item.update(
                        transition: itemTransition,
                        component: AnyComponent(itemComponent),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize)
                    
                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                    
                    itemsHeight += itemSize.height
                    singleItemHeight = itemSize.height
                }
            } else if let linkContents = component.linkContents {
                for i in 0 ..< linkContents.peers.count {
                    let peer = linkContents.peers[i]
                    
                    let id = AnyHashable(peer.id)
                    validIds.append(id)
                    
                    let item: ComponentView<Empty>
                    var itemTransition = transition
                    if let current = self.items[id] {
                        item = current
                    } else {
                        itemTransition = .immediate
                        item = ComponentView()
                        self.items[id] = item
                    }
                    
                    var subtitle: String?
                    if linkContents.alreadyMemberPeerIds.contains(peer.id) {
                        subtitle = "You are already a member"
                    } else if let memberCount = linkContents.memberCounts[peer.id] {
                        subtitle = "\(memberCount) participants"
                    }
                    
                    let itemSize = item.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            sideInset: 0.0,
                            title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                            peer: peer,
                            subtitle: subtitle,
                            selectionState: .editing(isSelected: self.selectedItems.contains(peer.id), isTinted: linkContents.alreadyMemberPeerIds.contains(peer.id)),
                            hasNext: i != linkContents.peers.count - 1,
                            action: { [weak self] peer in
                                guard let self, let component = self.component, let linkContents = component.linkContents, let controller = self.environment?.controller() else {
                                    return
                                }
                                
                                if case .remove = component.subject {
                                    if self.selectedItems.contains(peer.id) {
                                        self.selectedItems.remove(peer.id)
                                    } else {
                                        self.selectedItems.insert(peer.id)
                                    }
                                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                                } else if linkContents.alreadyMemberPeerIds.contains(peer.id) {
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    let text: String
                                    if case let .channel(channel) = peer, case .broadcast = channel.info {
                                        text = "You are already a member of this channel."
                                    } else {
                                        text = "You are already a member of this group."
                                    }
                                    controller.present(UndoOverlayController(presentationData: presentationData, content: .peers(context: component.context, peers: [peer], title: nil, text: text, customUndoText: nil), elevatedLayout: false, action: { _ in true }), in: .current)
                                } else {
                                    if self.selectedItems.contains(peer.id) {
                                        self.selectedItems.remove(peer.id)
                                    } else {
                                        self.selectedItems.insert(peer.id)
                                    }
                                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                                }
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize)
                    
                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                    
                    itemsHeight += itemSize.height
                    singleItemHeight = itemSize.height
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.items {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    item.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.items.removeValue(forKey: id)
            }
            
            let listHeaderTitle: String
            if case .linkList = component.subject {
                listHeaderTitle = "INVITE LINKS"
            } else if let linkContents = component.linkContents {
                if case .remove = component.subject {
                    if linkContents.peers.count == 1 {
                        listHeaderTitle = "1 CHAT TO QUIT"
                    } else {
                        listHeaderTitle = "\(linkContents.peers.count) CHATS TO QUIT"
                    }
                } else if allChatsAdded {
                    if linkContents.peers.count == 1 {
                        listHeaderTitle = "1 CHAT IN THIS FOLDER"
                    } else {
                        listHeaderTitle = "\(linkContents.peers.count) CHATS IN THIS FOLDER"
                    }
                } else {
                    if linkContents.peers.count == 1 {
                        listHeaderTitle = "1 CHAT IN FOLDER TO JOIN"
                    } else {
                        listHeaderTitle = "\(linkContents.peers.count) CHATS IN FOLDER TO JOIN"
                    }
                }
            } else {
                listHeaderTitle = " "
            }
            
            //TODO:localize
            let listHeaderActionItems: [AnimatedCounterComponent.Item]
            if self.selectedItems.count == self.items.count {
                listHeaderActionItems = [
                    AnimatedCounterComponent.Item(id: AnyHashable(0), text: "DESELECT", numericValue: 0),
                    AnimatedCounterComponent.Item(id: AnyHashable(1), text: "ALL", numericValue: 1)
                ]
            } else {
                listHeaderActionItems = [
                    AnimatedCounterComponent.Item(id: AnyHashable(0), text: "SELECT", numericValue: 1),
                    AnimatedCounterComponent.Item(id: AnyHashable(1), text: "ALL", numericValue: 1)
                ]
            }
            
            let listHeaderBody = MarkdownAttributeSet(font: Font.with(size: 13.0, design: .regular, traits: [.monospacedNumbers]), textColor: environment.theme.list.freeTextColor)
            
            let listHeaderTextSize = self.listHeaderText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: listHeaderTitle,
                        attributes: MarkdownAttributes(
                            body: listHeaderBody,
                            bold: listHeaderBody,
                            link: listHeaderBody,
                            linkAttribute: { _ in nil }
                        )
                    )
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0, height: 1000.0)
            )
            if let listHeaderTextView = self.listHeaderText.view {
                if listHeaderTextView.superview == nil {
                    listHeaderTextView.layer.anchorPoint = CGPoint()
                    self.scrollContentView.addSubview(listHeaderTextView)
                }
                let listHeaderTextFrame = CGRect(origin: CGPoint(x: sideInset + 15.0, y: contentHeight), size: listHeaderTextSize)
                contentTransition.setPosition(view: listHeaderTextView, position: listHeaderTextFrame.origin)
                listHeaderTextView.bounds = CGRect(origin: CGPoint(), size: listHeaderTextFrame.size)
                listHeaderTextView.isHidden = component.linkContents == nil
            }
            
            let listHeaderActionSize = self.listHeaderAction.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(AnimatedCounterComponent(
                        font: Font.regular(13.0),
                        color: environment.theme.list.itemAccentColor,
                        alignment: .right,
                        items: listHeaderActionItems
                    )),
                    effectAlignment: .right,
                    action: { [weak self] in
                        guard let self, let component = self.component, let linkContents = component.linkContents else {
                            return
                        }
                        if self.selectedItems.count != linkContents.peers.count {
                            for peer in linkContents.peers {
                                self.selectedItems.insert(peer.id)
                            }
                        } else {
                            self.selectedItems.removeAll()
                            for peerId in linkContents.alreadyMemberPeerIds {
                                self.selectedItems.insert(peerId)
                            }
                        }
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 15.0, height: 1000.0)
            )
            if let listHeaderActionView = self.listHeaderAction.view {
                if listHeaderActionView.superview == nil {
                    listHeaderActionView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                    self.scrollContentView.addSubview(listHeaderActionView)
                }
                let listHeaderActionFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - 15.0 - listHeaderActionSize.width, y: contentHeight), size: listHeaderActionSize)
                contentTransition.setFrame(view: listHeaderActionView, frame: listHeaderActionFrame)
                
                if let linkContents = component.linkContents, !allChatsAdded, linkContents.peers.count > 1 {
                    listHeaderActionView.isHidden = false
                } else {
                    listHeaderActionView.isHidden = true
                }
            }
            
            contentHeight += listHeaderTextSize.height
            contentHeight += 6.0
            
            contentTransition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: itemsHeight)))
            
            var initialContentHeight = contentHeight
            initialContentHeight += min(itemsHeight, floor(singleItemHeight * 2.5))
            
            contentHeight += itemsHeight
            contentHeight += 24.0
            initialContentHeight += 24.0
            
            let actionButtonTitle: String
            var actionButtonBadge: Int = 0
            if case .remove = component.subject {
                actionButtonBadge = self.selectedItems.count
                if self.selectedItems.isEmpty {
                    actionButtonTitle = "Remove Folder"
                } else {
                    actionButtonTitle = "Remove Folder and Chats"
                }
            } else if allChatsAdded {
                actionButtonBadge = 0
                actionButtonTitle = "OK"
            } else if let linkContents = component.linkContents {
                actionButtonBadge = self.selectedItems.count
                if linkContents.localFilterId != nil {
                    if self.selectedItems.isEmpty {
                        actionButtonTitle = "Do Not Join Any Chats"
                    } else {
                        actionButtonTitle = "Join Chats"
                    }
                } else {
                    actionButtonTitle = "Add Folder"
                }
            } else {
                actionButtonTitle = " "
            }
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: actionButtonTitle,
                        component: AnyComponent(ButtonTextContentComponent(
                            text: actionButtonTitle,
                            badge: actionButtonBadge,
                            textColor: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: environment.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: !self.selectedItems.isEmpty || component.linkContents?.localFilterId != nil,
                    displaysProgress: self.inProgress,
                    action: { [weak self] in
                        guard let self, let component = self.component, let linkContents = component.linkContents, let controller = self.environment?.controller() else {
                            return
                        }
                        
                        if case let .remove(folderId, _) = component.subject {
                            self.inProgress = true
                            self.state?.updated(transition: .immediate)
                            
                            component.completion?()
                            
                            let disposable = DisposableSet()
                            disposable.add(component.context.account.postbox.addHiddenChatIds(peerIds: Array(self.selectedItems)))
                            disposable.add(component.context.account.viewTracker.addHiddenChatListFilterIds([folderId]))
                            
                            let folderTitle = linkContents.title ?? ""
                            
                            var additionalText: String?
                            if !self.selectedItems.isEmpty {
                                if self.selectedItems.count == 1 {
                                    additionalText = "You also left **1** chat"
                                } else {
                                    additionalText = "You also left **\(self.selectedItems.count)** chats"
                                }
                            }
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                            
                            var chatListController: ChatListController?
                            if let navigationController = controller.navigationController as? NavigationController {
                                for viewController in navigationController.viewControllers.reversed() {
                                    if let rootController = viewController as? TabBarController {
                                        for c in rootController.controllers {
                                            if let c = c as? ChatListController {
                                                chatListController = c
                                                break
                                            }
                                        }
                                    } else if let c = viewController as? ChatListController {
                                        chatListController = c
                                        break
                                    }
                                    
                                    break
                                }
                            }
                            
                            let context = component.context
                            let selectedItems = self.selectedItems
                            let undoOverlayController = UndoOverlayController(
                                presentationData: presentationData,
                                content: .removedChat(title: "Folder \(folderTitle) deleted", text: additionalText),
                                elevatedLayout: false,
                                action: { value in
                                    if case .commit = value {
                                        let _ = (context.engine.peers.leaveChatFolder(folderId: folderId, removePeerIds: Array(selectedItems))
                                        |> deliverOnMainQueue).start(completed: {
                                            Queue.mainQueue().after(1.0, {
                                                disposable.dispose()
                                            })
                                        })
                                        return true
                                    } else if case .undo = value {
                                        disposable.dispose()
                                        return true
                                    }
                                    return false
                                }
                            )
                            
                            if let chatListController, chatListController.view.window != nil {
                                chatListController.present(undoOverlayController, in: .current)
                            } else {
                                controller.present(undoOverlayController, in: .window(.root))
                            }
                            
                            controller.dismiss()
                        } else if allChatsAdded {
                            controller.dismiss()
                        } else if let _ = component.linkContents {
                            if self.joinDisposable == nil, !self.selectedItems.isEmpty {
                                let joinSignal: Signal<JoinChatFolderResult?, JoinChatFolderLinkError>
                                switch component.subject {
                                case .linkList, .remove:
                                    return
                                case let .slug(slug):
                                    joinSignal = component.context.engine.peers.joinChatFolderLink(slug: slug, peerIds: Array(self.selectedItems))
                                    |> map(Optional.init)
                                case let .updates(updates):
                                    var result: JoinChatFolderResult?
                                    if let localFilterId = updates.chatFolderLinkContents.localFilterId, let title = updates.chatFolderLinkContents.title {
                                        result = JoinChatFolderResult(folderId: localFilterId, title: title, newChatCount: self.selectedItems.count)
                                    }
                                    joinSignal = component.context.engine.peers.joinAvailableChatsInFolder(updates: updates, peerIds: Array(self.selectedItems))
                                    |> map { _ -> JoinChatFolderResult? in
                                    }
                                    |> then(Signal<JoinChatFolderResult?, JoinChatFolderLinkError>.single(result))
                                }
                                
                                self.inProgress = true
                                self.state?.updated(transition: .immediate)
                                
                                self.joinDisposable = (joinSignal
                                |> deliverOnMainQueue).start(next: { [weak self] result in
                                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                                        return
                                    }
                                    
                                    if let result, let navigationController = controller.navigationController as? NavigationController {
                                        var chatListController: ChatListController?
                                        for viewController in navigationController.viewControllers {
                                            if let rootController = viewController as? TabBarController {
                                                for c in rootController.controllers {
                                                    if let c = c as? ChatListController {
                                                        chatListController = c
                                                        break
                                                    }
                                                }
                                            } else if let c = viewController as? ChatListController {
                                                chatListController = c
                                                break
                                            }
                                        }
                                            
                                        if let chatListController  {
                                            navigationController.popToRoot(animated: true)
                                            let context = component.context
                                            chatListController.navigateToFolder(folderId: result.folderId, completion: { [weak context, weak chatListController] in
                                                guard let context, let chatListController else {
                                                    return
                                                }
                                                
                                                //TODO:localize
                                                let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
                                                if case .updates = component.subject {
                                                    let chatCountString: String
                                                    if result.newChatCount == 1 {
                                                        chatCountString = "1 new chat"
                                                    } else {
                                                        chatCountString = "\(result.newChatCount) new chats"
                                                    }
                                                    
                                                    chatListController.present(UndoOverlayController(presentationData: presentationData, content: .info(title: "Folder \(result.title) Updated", text: "You have joined \(chatCountString)", timeout: nil), elevatedLayout: false, action: { _ in true }), in: .current)
                                                } else if result.newChatCount != 0 {
                                                    let chatCountString: String
                                                    if result.newChatCount == 1 {
                                                        chatCountString = "1 chat"
                                                    } else {
                                                        chatCountString = "\(result.newChatCount) chats"
                                                    }
                                                    
                                                    chatListController.present(UndoOverlayController(presentationData: presentationData, content: .info(title: "Folder \(result.title) Added", text: "You also joined \(chatCountString)", timeout: nil), elevatedLayout: false, action: { _ in true }), in: .current)
                                                } else {
                                                    chatListController.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: "Folder \(result.title) Added", timeout: nil), elevatedLayout: false, action: { _ in true }), in: .current)
                                                }
                                            })
                                        }
                                    }
                                    
                                    controller.dismiss()
                                }, error: { [weak self] error in
                                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                                        return
                                    }
                                    
                                    switch error {
                                    case .generic:
                                        controller.dismiss()
                                    case let .dialogFilterLimitExceeded(limit, _):
                                        let limitController = PremiumLimitScreen(context: component.context, subject: .folders, count: limit, action: {})
                                        controller.push(limitController)
                                        controller.dismiss()
                                    case let .sharedFolderLimitExceeded(limit, _):
                                        let limitController = PremiumLimitScreen(context: component.context, subject: .membershipInSharedFolders, count: limit, action: {})
                                        controller.push(limitController)
                                        controller.dismiss()
                                    case let .tooManyChannels(limit, _):
                                        let limitController = PremiumLimitScreen(context: component.context, subject: .chatsPerFolder, count: limit, action: {})
                                        controller.push(limitController)
                                        controller.dismiss()
                                    }
                                })
                            } else {
                                controller.dismiss()
                            }
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            
            var bottomPanelHeight: CGFloat = 0.0
            
            if case .linkList = component.subject {
                bottomPanelHeight += 30.0
            } else {
                bottomPanelHeight += 14.0 + environment.safeInsets.bottom + actionButtonSize.height
                let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
                if let actionButtonView = self.actionButton.view {
                    if actionButtonView.superview == nil {
                        self.addSubview(actionButtonView)
                    }
                    transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
                }
                
                transition.setFrame(layer: self.bottomBackgroundLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight - 8.0), size: CGSize(width: availableSize.width, height: bottomPanelHeight)))
                transition.setFrame(layer: self.bottomSeparatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight - 8.0 - UIScreenPixel), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            }
            
            if let controller = environment.controller() {
                let subLayout = ContainerViewLayout(
                    size: availableSize, metrics: environment.metrics, deviceMetrics: environment.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: 0.0, left: sideInset - 12.0, bottom: bottomPanelHeight, right: sideInset),
                    safeInsets: UIEdgeInsets(),
                    additionalInsets: UIEdgeInsets(),
                    statusBarHeight: nil,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(subLayout, transition: transition.containedViewLayoutTransition)
            }
            
            contentHeight += bottomPanelHeight
            initialContentHeight += bottomPanelHeight
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset, contentHeight: scrollContentHeight)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            let scrollClippingFrame: CGRect
            if case .linkList = component.subject {
                scrollClippingFrame = CGRect(origin: CGPoint(x: sideInset, y: containerInset + 56.0), size: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height - (containerInset + 56.0) + 1000.0))
            } else {
                scrollClippingFrame = CGRect(origin: CGPoint(x: sideInset, y: containerInset + 56.0), size: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height - bottomPanelHeight - 8.0 - (containerInset + 56.0)))
            }
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
        
        private func openLink(link: ExportedChatFolderLink) {
            guard let component = self.component else {
                return
            }
            guard case let .linkList(folderId, _) = component.subject else {
                return
            }
            
            let _ = (component.context.engine.peers.currentChatListFilters()
            |> deliverOnMainQueue).start(next: { [weak self] filters in
                guard let self, let component = self.component else {
                    return
                }
                guard let filter = filters.first(where: { $0.id == folderId }) else {
                    return
                }
                guard case let .filter(_, title, _, data) = filter else {
                    return
                }
                
                let peerIds = data.includePeers.peers
                let _ = (component.context.engine.data.get(
                    EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                )
                |> deliverOnMainQueue).start(next: { [weak self] peers in
                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    
                    let peers = peers.compactMap({ peer -> EnginePeer? in
                        guard let peer else {
                            return nil
                        }
                        if case let .legacyGroup(group) = peer, group.migrationReference != nil {
                            return nil
                        }
                        return peer
                    })
                    
                    let navigationController = controller.navigationController
                    controller.push(folderInviteLinkListController(context: component.context, filterId: folderId, title: title, allPeerIds: peers.map(\.id), currentInvitation: link, linkUpdated: { _ in }, presentController: { [weak navigationController] c in
                        (navigationController?.topViewController as? ViewController)?.present(c, in: .window(.root))
                    }))
                    controller.dismiss()
                })
            })
        }
        
        private func openCreateLink() {
            guard let component = self.component else {
                return
            }
            guard case let .linkList(folderId, _) = component.subject else {
                return
            }
            
            let _ = (component.context.engine.peers.currentChatListFilters()
            |> deliverOnMainQueue).start(next: { [weak self] filters in
                guard let self, let component = self.component else {
                    return
                }
                guard let filter = filters.first(where: { $0.id == folderId }) else {
                    return
                }
                guard case let .filter(_, title, _, data) = filter else {
                    return
                }
                
                let peerIds = data.includePeers.peers
                let _ = (component.context.engine.data.get(
                    EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                )
                |> deliverOnMainQueue).start(next: { [weak self] peers in
                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    
                    let peers = peers.compactMap({ peer -> EnginePeer? in
                        guard let peer else {
                            return nil
                        }
                        if case let .legacyGroup(group) = peer, group.migrationReference != nil {
                            return nil
                        }
                        return peer
                    })
                    if peers.allSatisfy({ !canShareLinkToPeer(peer: $0) }) {
                        let navigationController = controller.navigationController
                        controller.push(folderInviteLinkListController(context: component.context, filterId: folderId, title: title, allPeerIds: peers.map(\.id), currentInvitation: nil, linkUpdated: { _ in }, presentController: { [weak navigationController] c in
                            (navigationController?.topViewController as? ViewController)?.present(c, in: .window(.root))
                        }))
                    } else {
                        var enabledPeerIds: [EnginePeer.Id] = []
                        for peer in peers {
                            if canShareLinkToPeer(peer: peer) {
                                enabledPeerIds.append(peer.id)
                            }
                        }
                        
                        let _ = (component.context.engine.peers.exportChatFolder(filterId: folderId, title: "", peerIds: enabledPeerIds)
                        |> deliverOnMainQueue).start(next: { [weak self] link in
                            guard let self, let component = self.component, let controller = self.environment?.controller() else {
                                return
                            }
                            
                            self.linkListItems.insert(link, at: 0)
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                            
                            let navigationController = controller.navigationController
                            controller.push(folderInviteLinkListController(context: component.context, filterId: folderId, title: title, allPeerIds: peers.map(\.id), currentInvitation: link, linkUpdated: { [weak self] updatedLink in
                                guard let self else {
                                    return
                                }
                                if let index = self.linkListItems.firstIndex(where: { $0.link == link.link }) {
                                    if let updatedLink {
                                        self.linkListItems[index] = updatedLink
                                    } else {
                                        self.linkListItems.remove(at: index)
                                    }
                                } else {
                                    if let updatedLink {
                                        self.linkListItems.insert(updatedLink, at: 0)
                                    }
                                }
                                self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                            }, presentController: { [weak navigationController] c in
                                (navigationController?.topViewController as? ViewController)?.present(c, in: .window(.root))
                            }))
                            
                            controller.dismiss()
                        }, error: { [weak self] error in
                            guard let self, let component = self.component, let controller = self.environment?.controller() else {
                                return
                            }
                            
                            //TODO:localize
                            let text: String
                            switch error {
                            case .generic:
                                text = "An error occurred"
                            case let .sharedFolderLimitExceeded(limit, _):
                                let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .membershipInSharedFolders, count: limit, action: {
                                })
                                
                                controller.push(limitController)
                                
                                return
                            case let .limitExceeded(limit, _):
                                let limitController = component.context.sharedContext.makePremiumLimitController(context: component.context, subject: .linksPerSharedFolder, count: limit, action: {
                                })
                                controller.push(limitController)
                                
                                return
                            }
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        })
                    }
                })
            })
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ChatFolderLinkPreviewScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case slug(String)
        case updates(ChatFolderUpdates)
        case remove(folderId: Int32, defaultSelectedPeerIds: [EnginePeer.Id])
        case linkList(folderId: Int32, initialLinks: [ExportedChatFolderLink])
    }
    
    private let context: AccountContext
    private var linkContentsDisposable: Disposable?
    
    private var isDismissed: Bool = false
    
    public init(context: AccountContext, subject: Subject, contents: ChatFolderLinkContents, completion: (() -> Void)? = nil) {
        self.context = context
        
        super.init(context: context, component: ChatFolderLinkPreviewScreenComponent(context: context, subject: subject, linkContents: contents, completion: completion), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        self.lockOrientation = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.linkContentsDisposable?.dispose()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? ChatFolderLinkPreviewScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? ChatFolderLinkPreviewScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

private final class LinkListContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    //let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
    
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
