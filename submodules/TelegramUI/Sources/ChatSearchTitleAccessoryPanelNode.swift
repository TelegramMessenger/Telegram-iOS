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
import Postbox
import EmojiStatusComponent
import SwiftSignalKit
import ContextUI
import PromptUI
import BundleIconComponent
import SavedTagNameAlertController

private let backgroundTagImage: UIImage? = {
    if let image = UIImage(bundleImageName: "Chat/Title Panels/SearchTagTab") {
        return image.stretchableImage(withLeftCapWidth: 8, topCapHeight: 0).withRenderingMode(.alwaysTemplate)
    } else {
        return nil
    }
}()

final class ChatSearchTitleAccessoryPanelNode: ChatTitleAccessoryPanelNode, ChatControllerCustomNavigationPanelNode, ASScrollViewDelegate {
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
        let title: String?
        let file: TelegramMediaFile
        
        init(reaction: MessageReaction.Reaction, count: Int, title: String?, file: TelegramMediaFile) {
            self.reaction = reaction
            self.count = count
            self.title = title
            self.file = file
        }
    }
    
    private final class PromoView: UIView {
        private let containerButton: HighlightTrackingButton
        
        private let background: UIImageView
        private let titleIcon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let arrowIcon = ComponentView<Empty>()
        
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
            
            self.containerButton = HighlightTrackingButton()
            
            self.background = UIImageView()
            self.background.image = backgroundTagImage
            
            super.init(frame: CGRect())
            
            self.containerButton.layer.allowsGroupOpacity = true
            
            self.containerButton.addSubview(self.background)
            
            self.addSubview(self.containerButton)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.containerButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.containerButton.alpha = 0.7
                } else {
                    ComponentTransition.easeInOut(duration: 0.25).setAlpha(view: self.containerButton, alpha: 1.0)
                }
            }
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.action()
        }
        
        func update(theme: PresentationTheme, strings: PresentationStrings, height: CGFloat, isUnlock: Bool, transition: ComponentTransition) -> CGSize {
            let titleIconSpacing: CGFloat = 0.0
            
            let titleIconSize = self.titleIcon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Chat/Stickers/Lock",
                    tintColor: theme.rootController.navigationBar.accentTextColor,
                    maxSize: CGSize(width: 14.0, height: 14.0)
                )),
                environment: {},
                containerSize: CGSize(width: 14.0, height: 14.0)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: isUnlock ? strings.Chat_TagsHeaderPanel_Unlock : strings.Chat_TagsHeaderPanel_AddTags, font: Font.medium(14.0), textColor: theme.rootController.navigationBar.accentTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            
            let size = CGSize(width: titleIconSize.width + titleIconSpacing + titleSize.width - 1.0, height: height)
            
            let titleIconFrame = CGRect(origin: CGPoint(x: -1.0, y: UIScreenPixel + floor((size.height - titleIconSize.height) * 0.5)), size: titleIconSize)
            if let titleIconView = self.titleIcon.view {
                if titleIconView.superview == nil {
                    titleIconView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleIconView)
                }
                titleIconView.frame = titleIconFrame
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: titleIconSize.width + titleIconSpacing, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            self.background.tintColor = theme.rootController.navigationBar.accentTextColor.withMultipliedAlpha(0.1)
            
            if let image = self.background.image {
                let backgroundFrame = CGRect(origin: CGPoint(x: -6.0, y: floorToScreenPixels((size.height - image.size.height) * 0.5)), size: CGSize(width: size.width + 6.0 + 9.0, height: image.size.height))
                transition.setFrame(view: self.background, frame: backgroundFrame)
            }
            
            var totalSize = size
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: strings.Chat_TagsHeaderPanel_AddTagsSuffix, font: Font.regular(14.0), textColor: theme.rootController.navigationBar.secondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            let arrowSize = self.arrowIcon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Item List/DisclosureArrow",
                    tintColor: theme.rootController.navigationBar.secondaryTextColor.withMultipliedAlpha(0.6)
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            let textSpacing: CGFloat = 13.0
            let arrowSpacing: CGFloat = -5.0
            
            totalSize.width += textSpacing
            
            let textFrame = CGRect(origin: CGPoint(x: totalSize.width, y: floor((size.height - textSize.height) * 0.5)), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(textView)
                }
                textView.frame = textFrame
                transition.setAlpha(view: textView, alpha: isUnlock ? 0.0 : 1.0)
            }
            totalSize.width += textSize.width
            totalSize.width += arrowSpacing
            
            let arrowFrame = CGRect(origin: CGPoint(x: totalSize.width, y: 1.0 + floor((size.height - arrowSize.height) * 0.5)), size: arrowSize)
            if let arrowIconView = self.arrowIcon.view {
                if arrowIconView.superview == nil {
                    arrowIconView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(arrowIconView)
                }
                arrowIconView.frame = arrowFrame
                transition.setAlpha(view: arrowIconView, alpha: isUnlock ? 0.0 : 1.0)
            }
            totalSize.width += arrowSize.width
            
            transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: totalSize))
            
            return isUnlock ? size : totalSize
        }
    }
    
    private final class ItemView: UIView {
        private let context: AccountContext
        private let action: () -> Void
        
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let containerButton: HighlightTrackingButton
        
        private let background: UIImageView
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let counter = ComponentView<Empty>()
        
        init(context: AccountContext, action: @escaping (() -> Void), contextGesture: @escaping (ContextGesture, ContextExtractedContentContainingNode) -> Void) {
            self.context = context
            self.action = action
            
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            
            self.containerButton = HighlightTrackingButton()
            
            self.background = UIImageView()
            self.background.image = backgroundTagImage
            
            super.init(frame: CGRect())
            
            self.extractedContainerNode.contentNode.view.addSubview(self.containerButton)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.addSubview(self.containerNode.view)
            
            self.containerButton.addSubview(self.background)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.containerButton.highligthedChanged = { [weak self] highlighted in
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
            
            self.containerNode.activated = { [weak self] gesture, _ in
                guard let self else {
                    return
                }
                contextGesture(gesture, self.extractedContainerNode)
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
        
        func update(item: Item, isSelected: Bool, isLocked: Bool, theme: PresentationTheme, height: CGFloat, transition: ComponentTransition) -> CGSize {
            let spacing: CGFloat = 3.0
            
            let contentsAlpha: CGFloat = isLocked ? 0.6 : 1.0
            
            let reactionSize = CGSize(width: 20.0, height: 20.0)
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
            
            let titleText: String = item.title ?? ""
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.regular(11.0), textColor: isSelected ? theme.list.itemCheckColors.foregroundColor : theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.6)))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let counterText: String = "\(item.count)"
            let counterSize = self.counter.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: counterText, font: Font.regular(11.0), textColor: isSelected ? theme.list.itemCheckColors.foregroundColor : theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.6)))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let titleCounterSpacing: CGFloat = 3.0
            
            var titleAndCounterSize: CGFloat = titleSize.width
            if titleSize.width != 0.0 {
                titleAndCounterSize += titleCounterSpacing
            }
            titleAndCounterSize += counterSize.width
            
            let size = CGSize(width: reactionSize.width + spacing + titleAndCounterSize - 2.0, height: height)
            
            let iconFrame = CGRect(origin: CGPoint(x: -1.0, y: floor((size.height - reactionSize.height) * 0.5)), size: reactionSize)
            
            let titleFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + spacing, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            let counterFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + (titleSize.width.isZero ? 0.0 : titleCounterSpacing), y: floor((size.height - counterSize.height) * 0.5)), size: counterSize)
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(iconView)
                }
                iconView.frame = reactionDisplaySize.centered(around: iconFrame.center)
                transition.setAlpha(view: iconView, alpha: contentsAlpha)
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
                transition.setAlpha(view: titleView, alpha: contentsAlpha)
            }
            if let counterView = self.counter.view {
                if counterView.superview == nil {
                    counterView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(counterView)
                }
                counterView.frame = counterFrame
                transition.setAlpha(view: counterView, alpha: contentsAlpha)
            }
            
            if theme.overallDarkAppearance {
                self.background.tintColor = isSelected ? theme.list.itemCheckColors.fillColor : UIColor(white: 1.0, alpha: 0.1)
            } else {
                self.background.tintColor = isSelected ? theme.list.itemCheckColors.fillColor : theme.rootController.navigationSearchBar.inputFillColor
            }
            if let image = self.background.image {
                let backgroundFrame = CGRect(origin: CGPoint(x: -6.0, y: floorToScreenPixels((size.height - image.size.height) * 0.5)), size: CGSize(width: size.width + 6.0 + 9.0, height: image.size.height))
                transition.setFrame(view: self.background, frame: backgroundFrame)
            }
            
            transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: size))
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
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
    private var promoView: PromoView?
    
    private var itemsDisposable: Disposable?
    
    private var appliedScrollToTag: MemoryBuffer?
    
    init(context: AccountContext, chatLocation: ChatLocation) {
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
        self.scrollView.delegate = self.wrappedScrollViewDelegate
        
        self.view.addSubview(self.scrollView)
        
        self.scrollView.disablesInteractiveTransitionGestureRecognizer = true
        
        let tagsAndFiles: Signal<([MessageReaction.Reaction: Int], [Int64: TelegramMediaFile]), NoError> = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Messages.SavedMessageTagStats(peerId: context.account.peerId, threadId: chatLocation.threadId)
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
                case .stars:
                    break
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
            context.engine.stickers.savedMessageTagData(),
            tagsAndFiles
        )
        |> deliverOnMainQueue).start(next: { [weak self] availableReactions, savedMessageTags, tagsAndFiles in
            guard let self else {
                return
            }
            self.items.removeAll()
            
            let (tags, files) = tagsAndFiles
            for (reaction, count) in tags {
                let title = savedMessageTags?.tags.first(where: { $0.reaction == reaction })?.title
                
                switch reaction {
                case .builtin, .stars:
                    if let availableReactions {
                        inner: for availableReaction in availableReactions.reactions {
                            if availableReaction.value == reaction {
                                if let file = availableReaction.centerAnimation {
                                    self.items.append(Item(reaction: reaction, count: count, title: title, file: file))
                                }
                                break inner
                            }
                        }
                    }
                case let .custom(fileId):
                    if let file = files[fileId] {
                        self.items.append(Item(reaction: reaction, count: count, title: title, file: file))
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
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, chatController: ChatController) -> LayoutResult {
        return self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, transition: transition, interfaceState: (chatController as! ChatControllerImpl).presentationInterfaceState)
    }
    
    private func update(params: Params, transition: ContainedViewLayoutTransition) {
        let panelHeight: CGFloat = 39.0
        
        let containerInsets = UIEdgeInsets(top: 0.0, left: params.leftInset + 16.0, bottom: 0.0, right: params.rightInset + 16.0)
        let itemSpacing: CGFloat = 24.0
        
        var contentSize = CGSize(width: 0.0, height: panelHeight)
        contentSize.width += containerInsets.left
        
        var validIds: [MessageReaction.Reaction] = []
        
        let hadItemViews = !self.itemViews.isEmpty
        var isFirst = true
        
        if !params.interfaceState.isPremium {
            let promoView: PromoView
            var itemTransition = transition
            if let current = self.promoView {
                promoView = current
            } else {
                itemTransition = .immediate
                promoView = PromoView(action: { [weak self] in
                    guard let self, let interfaceInteraction = self.interfaceInteraction else {
                        return
                    }
                    (interfaceInteraction.chatController() as? ChatControllerImpl)?.presentTagPremiumPaywall()
                })
                self.promoView = promoView
                self.scrollView.addSubview(promoView)
            }
            
            let itemSize = promoView.update(theme: params.interfaceState.theme, strings: params.interfaceState.strings, height: panelHeight, isUnlock: !self.items.isEmpty, transition: .immediate)
            let itemFrame = CGRect(origin: CGPoint(x: contentSize.width, y: -5.0), size: itemSize)
            
            itemTransition.updatePosition(layer: promoView.layer, position: itemFrame.center)
            promoView.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
            
            contentSize.width += itemSize.width
            
            isFirst = false
        } else {
            if let promoView = self.promoView {
                self.promoView = nil
                promoView.removeFromSuperview()
            }
        }
            
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
                    guard let self, let params = self.params else {
                        return
                    }
                    
                    if !params.interfaceState.isPremium {
                        if let chatController = self.interfaceInteraction?.chatController() {
                            (chatController as? ChatControllerImpl)?.presentTagPremiumPaywall()
                        }
                        return
                    }
                    
                    let tag = ReactionsMessageAttribute.messageTag(reaction: reaction)
                    
                    var updatedFilter: ChatPresentationInterfaceState.HistoryFilter?
                    let currentTag = params.interfaceState.historyFilter?.customTag
                    if currentTag == tag {
                        updatedFilter = nil
                    } else {
                        updatedFilter = ChatPresentationInterfaceState.HistoryFilter(customTag: tag, isActive: true)
                    }
                    
                    self.interfaceInteraction?.updateHistoryFilter({ filter in
                        return updatedFilter
                    })
                }, contextGesture: { [weak self] gesture, sourceNode in
                    guard let self, let params = self.params, let interfaceInteraction = self.interfaceInteraction, let chatController = interfaceInteraction.chatController() else {
                        gesture.cancel()
                        return
                    }
                    guard let item = self.items.first(where: { $0.reaction == reaction }) else {
                        gesture.cancel()
                        return
                    }
                    
                    if !params.interfaceState.isPremium {
                        (chatController as? ChatControllerImpl)?.presentTagPremiumPaywall()
                        return
                    }
                    
                    var items: [ContextMenuItem] = []
                    
                    let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
                    items.append(.action(ContextMenuActionItem(text: item.title != nil ? presentationData.strings.Chat_ReactionContextMenu_EditTagLabel : presentationData.strings.Chat_ReactionContextMenu_SetTagLabel, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/TagEditName"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] c, a in
                        guard let self else {
                            a(.default)
                            return
                        }
                        
                        c?.dismiss(completion: { [weak self] in
                            guard let self, let item = self.items.first(where: { $0.reaction == reaction }) else {
                                return
                            }
                            self.openEditTagTitle(reaction: reaction, hasTitle: item.title != nil)
                        })
                    })))
                    
                    let controller = ContextController(presentationData: presentationData, source: .extracted(TagContextExtractedContentSource(controller: chatController, sourceNode: sourceNode, keepInPlace: false)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
                    interfaceInteraction.presentGlobalOverlayController(controller, nil)
                })
                self.itemViews[itemId] = itemView
                self.scrollView.addSubview(itemView)
            }
                
            var isSelected = false
            if let historyFilter = params.interfaceState.historyFilter {
                if historyFilter.customTag == ReactionsMessageAttribute.messageTag(reaction: item.reaction) {
                    isSelected = true
                }
            }
            let itemSize = itemView.update(item: item, isSelected: isSelected, isLocked: !params.interfaceState.isPremium, theme: params.interfaceState.theme, height: panelHeight, transition: .immediate)
            let itemFrame = CGRect(origin: CGPoint(x: contentSize.width, y: -5.0), size: itemSize)
            
            itemTransition.updatePosition(layer: itemView.layer, position: itemFrame.center)
            itemTransition.updateBounds(layer: itemView.layer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
            
            if animateIn && transition.isAnimated {
                itemView.layer.animateAlpha(from: 0.0, to: itemView.alpha, duration: 0.15)
                transition.animateTransformScale(view: itemView, from: 0.001)
            }
            
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
        
        let currentFilterTag = params.interfaceState.historyFilter?.customTag
        if self.appliedScrollToTag != currentFilterTag {
            if let tag = currentFilterTag {
                if let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: tag), let itemView = self.itemViews[reaction] {
                    self.appliedScrollToTag = currentFilterTag
                    self.scrollView.scrollRectToVisible(itemView.frame.insetBy(dx: -46.0, dy: 0.0), animated: hadItemViews)
                }
            } else {
                self.appliedScrollToTag = currentFilterTag
            }
        }
    }
    
    private func openEditTagTitle(reaction: MessageReaction.Reaction, hasTitle: Bool) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        let optionTitle = hasTitle ? presentationData.strings.Chat_EditTagTitle_TitleEdit : presentationData.strings.Chat_EditTagTitle_TitleSet
        
        let reactionFile: Signal<TelegramMediaFile?, NoError>
        switch reaction {
        case .builtin, .stars:
            reactionFile = self.context.engine.stickers.availableReactions()
            |> take(1)
            |> map { availableReactions -> TelegramMediaFile? in
                return availableReactions?.reactions.first(where: { $0.value == reaction })?.selectAnimation
            }
        case let .custom(fileId):
            reactionFile = self.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
            |> map { files -> TelegramMediaFile? in
                return files.values.first
            }
        }
        
        let _ = (combineLatest(
            self.context.engine.stickers.savedMessageTagData(),
            reactionFile
        )
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] savedMessageTags, reactionFile in
            guard let self, let reactionFile else {
                return
            }
            
            let promptController = savedTagNameAlertController(context: self.context, updatedPresentationData: nil, text: optionTitle, subtext: presentationData.strings.Chat_EditTagTitle_Text, value: savedMessageTags?.tags.first(where: { $0.reaction == reaction })?.title ?? "", reaction: reaction, file: reactionFile, characterLimit: 12, apply: { [weak self] value in
                guard let self else {
                    return
                }
                
                if let value {
                    let _ = self.context.engine.stickers.setSavedMessageTagTitle(reaction: reaction, title: value.isEmpty ? nil : value).start()
                }
            })
            self.interfaceInteraction?.presentController(promptController, nil)
        })
    }
}

private final class TagContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
