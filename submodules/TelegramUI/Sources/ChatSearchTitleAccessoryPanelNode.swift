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
    
    private final class ItemView: HighlightTrackingButton {
        private let context: AccountContext
        private let action: () -> Void
        
        private let background: UIImageView
        private let icon = ComponentView<Empty>()
        private let counter = ComponentView<Empty>()
        
        init(context: AccountContext, action: @escaping (() -> Void)) {
            self.background = UIImageView()
            if let image = UIImage(bundleImageName: "Chat/Title Panels/SearchTagTab") {
                self.background.image = image.stretchableImage(withLeftCapWidth: 8, topCapHeight: 0).withRenderingMode(.alwaysTemplate)
            }
            
            self.context = context
            self.action = action
            
            super.init(frame: CGRect())
            
            self.addSubview(self.background)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let topScale: CGFloat = (self.bounds.width - 1.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 1.0) / self.bounds.width
                    
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.layer.removeAnimation(forKey: "sublayerTransform")
                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                        transition.updateTransformScale(layer: self.layer, scale: topScale)
                    } else {
                        let transition: ContainedViewLayoutTransition = .immediate
                        transition.updateTransformScale(layer: self.layer, scale: 1.0)
                        
                        self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            
                            self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                        })
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.action()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            var mappedPoint = point
            if self.bounds.insetBy(dx: -8.0, dy: -4.0).contains(point) {
                mappedPoint = self.bounds.center
            }
            return super.hitTest(mappedPoint, with: event)
        }
        
        func update(item: Item, isSelected: Bool, theme: PresentationTheme, height: CGFloat, transition: Transition) -> CGSize {
            let spacing: CGFloat = 4.0
            
            let reactionSize = CGSize(width: 16.0, height: 16.0)
            var reactionDisplaySize = reactionSize
            if case .builtin = item.reaction {
                reactionDisplaySize = CGSize(width: reactionDisplaySize.width * 2.0, height: reactionDisplaySize.height * 2.0)
            }
            
            let _ = self.icon.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    content: .animation(
                        content: .file(file: item.file),
                        size: reactionDisplaySize,
                        placeholderColor: theme.list.mediaPlaceholderColor,
                        themeColor: theme.list.itemPrimaryTextColor,
                        loopMode: .forever
                    ),
                    isVisibleForAnimations: false,
                    useSharedAnimation: true,
                    action: nil,
                    emojiFileUpdated: nil
                )),
                environment: {},
                containerSize: reactionDisplaySize
            )
            
            let counterSize = self.counter.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "\(item.count)", font: Font.regular(14.0), textColor: isSelected ? theme.list.itemCheckColors.foregroundColor : theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.6)))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let size = CGSize(width: reactionSize.width + spacing + counterSize.width, height: height)
            
            let iconFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((size.height - reactionSize.height) * 0.5)), size: reactionSize)
            let counterFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + spacing, y: floor((size.height - counterSize.height) * 0.5)), size: counterSize)
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.addSubview(iconView)
                }
                iconView.frame = reactionDisplaySize.centered(around: iconFrame.center)
            }
            
            if let counterView = self.counter.view {
                if counterView.superview == nil {
                    counterView.isUserInteractionEnabled = false
                    self.addSubview(counterView)
                }
                counterView.frame = counterFrame
            }
            
            self.background.tintColor = isSelected ? theme.list.itemCheckColors.fillColor : theme.list.controlSecondaryColor
            if let image = self.background.image {
                let backgroundFrame = CGRect(origin: CGPoint(x: -6.0, y: floorToScreenPixels((size.height - image.size.height) * 0.5)), size: CGSize(width: size.width + 6.0 + 9.0, height: image.size.height))
                transition.setFrame(view: self.background, frame: backgroundFrame)
            }
            
            return size
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
        
        let tagsAndFiles: Signal<([MessageReaction.Reaction: Int], [Int64: TelegramMediaFile]), NoError> = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId)
        )
        |> distinctUntilChanged
        |> mapToSignal { tags -> Signal<([MessageReaction.Reaction: Int], [Int64: TelegramMediaFile]), NoError> in
            var customFileIds: [Int64] = []
            for (reaction, _) in tags {
                switch reaction {
                case .builtin:
                    break
                case let .custom(fileId):
                    customFileIds.append(fileId)
                }
            }
            
            return context.engine.stickers.resolveInlineStickers(fileIds: customFileIds)
            |> map { files in
                return (tags, files)
            }
        }
        
        var isFirstUpdate = true
        self.itemsDisposable = (combineLatest(
            context.engine.stickers.availableReactions(),
            tagsAndFiles
        )
        |> deliverOnMainQueue).start(next: { [weak self] availableReactions, tagsAndFiles in
            guard let self else {
                return
            }
            self.items.removeAll()
            
            let (tags, files) = tagsAndFiles
            for (reaction, count) in tags {
                switch reaction {
                case .builtin:
                    if let availableReactions {
                        inner: for availableReaction in availableReactions.reactions {
                            if availableReaction.value == reaction {
                                if let file = availableReaction.centerAnimation {
                                    self.items.append(Item(reaction: reaction, count: count, file: file))
                                }
                                break inner
                            }
                        }
                    }
                case let .custom(fileId):
                    if let file = files[fileId] {
                        self.items.append(Item(reaction: reaction, count: count, file: file))
                    }
                }
            }
            self.items.sort(by: { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.reaction < rhs.reaction
            })
            self.update(transition: isFirstUpdate ? .immediate : .animated(duration: 0.3, curve: .easeInOut))
            isFirstUpdate = false
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
        
        let panelHeight: CGFloat = 39.0
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight, hitTestSlop: 0.0)
    }
    
    private func update(params: Params, transition: ContainedViewLayoutTransition) {
        let panelHeight: CGFloat = 39.0
        
        let containerInsets = UIEdgeInsets(top: 0.0, left: params.leftInset + 16.0, bottom: 0.0, right: params.rightInset + 16.0)
        let itemSpacing: CGFloat = 26.0
        
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
            
            var itemTransition = transition
            var animateIn = false
            let itemView: ItemView
            if let current = self.itemViews[itemId] {
                itemView = current
            } else {
                itemTransition = .immediate
                animateIn = true
                let reaction = item.reaction
                itemView = ItemView(context: self.context, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    let tag = ReactionsMessageAttribute.messageTag(reaction: reaction)
                    
                    self.interfaceInteraction?.updateHistoryFilter({ filter in
                        var tags: [EngineMessage.CustomTag] = filter?.customTags ?? []
                        if let index = tags.firstIndex(of: tag) {
                            tags.remove(at: index)
                        } else {
                            tags.append(tag)
                        }
                        if tags.isEmpty {
                            return nil
                        } else {
                            return ChatPresentationInterfaceState.HistoryFilter(customTags: tags, isActive: filter?.isActive ?? true)
                        }
                    })
                })
                self.itemViews[itemId] = itemView
                self.scrollView.addSubview(itemView)
            }
            
            var isSelected = false
            if let historyFilter = params.interfaceState.historyFilter {
                if historyFilter.customTags.contains(ReactionsMessageAttribute.messageTag(reaction: item.reaction)) {
                    isSelected = true
                }
            }
            let itemSize = itemView.update(item: item, isSelected: isSelected, theme: params.interfaceState.theme, height: panelHeight, transition: .immediate)
            let itemFrame = CGRect(origin: CGPoint(x: contentSize.width, y: -5.0), size: itemSize)
            
            itemTransition.updatePosition(layer: itemView.layer, position: itemFrame.center)
            if animateIn && transition.isAnimated {
                itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                transition.animateTransformScale(view: itemView, from: 0.001)
            }
            
            itemView.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
            
            contentSize.width += itemSize.width
        }
        var removedIds: [MessageReaction.Reaction] = []
        for (id, itemView) in self.itemViews {
            if !validIds.contains(id) {
                removedIds.append(id)
                
                if transition.isAnimated {
                    itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak itemView] _ in
                        itemView?.removeFromSuperview()
                    })
                    transition.updateTransformScale(layer: itemView.layer, scale: 0.001)
                } else {
                    itemView.removeFromSuperview()
                }
            }
        }
        for id in removedIds {
            self.itemViews.removeValue(forKey: id)
        }
        
        contentSize.width += containerInsets.right
        
        let scrollSize = CGSize(width: params.width, height: contentSize.height)
        if self.scrollView.bounds.size != scrollSize {
            self.scrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: scrollSize)
        }
        if self.scrollView.contentSize != contentSize {
            self.scrollView.contentSize = contentSize
        }
    }
}
