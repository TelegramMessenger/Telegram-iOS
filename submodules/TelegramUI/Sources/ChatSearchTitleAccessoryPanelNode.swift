import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import AccountContext
import ComponentFlow
import MultilineTextComponent
import PlainButtonComponent
import UIKitRuntimeUtils
import TelegramCore
import EmojiStatusComponent
import SwiftSignalKit

final class ChatSearchTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode, UIScrollViewDelegate {
    private struct Params: Equatable {
        var width: CGFloat
        var leftInset: CGFloat
        var rightInset: CGFloat
        var interfaceState: ChatPresentationInterfaceState
        
        init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
            self.width = width
            self.leftInset = leftInset
            self.rightInset = rightInset
            self.interfaceState = interfaceState
        }
        
        static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs.width != rhs.width {
                return false
            }
            if lhs.leftInset != rhs.leftInset {
                return false
            }
            if lhs.rightInset != rhs.rightInset {
                return false
            }
            if lhs.interfaceState != rhs.interfaceState {
                return false
            }
            return true
        }
    }
    
    private final class Item {
        let reaction: MessageReaction.Reaction
        let count: Int
        let file: TelegramMediaFile
        
        init(reaction: MessageReaction.Reaction, count: Int, file: TelegramMediaFile) {
            self.reaction = reaction
            self.count = count
            self.file = file
        }
    }
    
    private final class ItemView: UIView {
        private let context: AccountContext
        private let item: Item
        private let action: () -> Void
        
        private let view = ComponentView<Empty>()
        
        init(context: AccountContext, item: Item, action: @escaping (() -> Void)) {
            self.context = context
            self.item = item
            self.action = action
            
            super.init(frame: CGRect())
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(theme: PresentationTheme, height: CGFloat, transition: Transition) -> CGSize {
            let viewSize = self.view.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(HStack([
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiStatusComponent(
                            context: self.context,
                            animationCache: self.context.animationCache,
                            animationRenderer: self.context.animationRenderer,
                            content: .animation(
                                content: .file(file: self.item.file),
                                size: CGSize(width: 32.0, height: 32.0),
                                placeholderColor: theme.list.mediaPlaceholderColor,
                                themeColor: theme.list.itemPrimaryTextColor,
                                loopMode: .forever
                            ),
                            size: CGSize(width: 16.0, height: 16.0),
                            isVisibleForAnimations: false,
                            useSharedAnimation: true,
                            action: nil,
                            emojiFileUpdated: nil
                        ))),
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: "\(self.item.count)", font: Font.regular(15.0), textColor: theme.rootController.navigationBar.secondaryTextColor))
                        )))
                    ], spacing: 4.0)),
                    effectAlignment: .center,
                    minSize: CGSize(width: 0.0, height: height),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.action()
                    },
                    isEnabled: true
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 32.0)
            )
            if let componentView = self.view.view {
                if componentView.superview == nil {
                    self.addSubview(componentView)
                }
                transition.setFrame(view: componentView, frame: CGRect(origin: CGPoint(), size: viewSize))
            }
            return viewSize
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
    
    private let context: AccountContext
    
    private let scrollView: ScrollView
    
    private var params: Params?
    
    private var items: [Item] = []
    private var itemViews: [MessageReaction.Reaction: ItemView] = [:]
    
    private var itemsDisposable: Disposable?
    
    init(context: AccountContext) {
        self.context = context
        
        self.scrollView = ScrollView(frame: CGRect())
        
        super.init()
        
        self.scrollView.delaysContentTouches = false
        self.scrollView.canCancelContentTouches = true
        self.scrollView.clipsToBounds = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 13.0, *) {
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.scrollsToTop = false
        self.scrollView.delegate = self
        
        self.view.addSubview(self.scrollView)
        
        self.scrollView.disablesInteractiveTransitionGestureRecognizer = true
        
        self.itemsDisposable = (context.engine.stickers.savedMessageTags()
        |> deliverOnMainQueue).start(next: { [weak self] tags, files in
            guard let self else {
                return
            }
            self.items = tags.compactMap { tag -> Item? in
                switch tag.reaction {
                case .builtin:
                    return nil
                case let .custom(fileId):
                    guard let file = files[fileId] else {
                        return nil
                    }
                    return Item(reaction: tag.reaction, count: tag.count, file: file)
                }
            }
            self.update(transition: .immediate)
        })
    }
    
    deinit {
        self.itemsDisposable?.dispose()
    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        if let params = self.params {
            self.update(params: params, transition: transition)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        let params = Params(width: width, leftInset: leftInset, rightInset: rightInset, interfaceState: interfaceState)
        if self.params != params {
            self.params = params
            self.update(params: params, transition: transition)
        }
        
        let panelHeight: CGFloat = 33.0
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight, hitTestSlop: 0.0)
    }
    
    private func update(params: Params, transition: ContainedViewLayoutTransition) {
        let panelHeight: CGFloat = 33.0
        
        let containerInsets = UIEdgeInsets(top: 0.0, left: params.leftInset + 2.0, bottom: 0.0, right: params.rightInset + 2.0)
        let itemSpacing: CGFloat = 2.0
        
        var contentSize = CGSize(width: 0.0, height: panelHeight)
        contentSize.width += containerInsets.left
        
        var validIds: [MessageReaction.Reaction] = []
        var isFirst = true
        for item in self.items {
            if isFirst {
                isFirst = false
            } else {
                contentSize.width += itemSpacing
            }
            let itemId = item.reaction
            validIds.append(itemId)
            
            let itemView: ItemView
            if let current = self.itemViews[itemId] {
                itemView = current
            } else {
                itemView = ItemView(context: self.context, item: item, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.beginMessageSearch(.tag(item.reaction, item.file), "")
                })
                self.itemViews[itemId] = itemView
                self.scrollView.addSubview(itemView)
            }
            
            let itemSize = itemView.update(theme: params.interfaceState.theme, height: panelHeight, transition: .immediate)
            itemView.frame = CGRect(origin: CGPoint(x: contentSize.width, y: 0.0), size: itemSize)
            contentSize.width += itemSize.width
        }
        var removedIds: [MessageReaction.Reaction] = []
        for (id, itemView) in self.itemViews {
            if !validIds.contains(id) {
                removedIds.append(id)
                itemView.removeFromSuperview()
            }
        }
        for id in removedIds {
            self.itemViews.removeValue(forKey: id)
        }
        
        contentSize.width += containerInsets.right
        
        let scrollSize = CGSize(width: params.width, height: contentSize.height)
        if self.scrollView.bounds.size != scrollSize {
            self.scrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: -5.0), size: scrollSize)
        }
        if self.scrollView.contentSize != contentSize {
            self.scrollView.contentSize = contentSize
        }
    }
}
