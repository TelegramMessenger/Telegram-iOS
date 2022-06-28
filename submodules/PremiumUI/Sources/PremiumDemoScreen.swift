import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown
import TelegramUIPreferences

private final class GradientBackgroundComponent: Component {
    public let colors: [UIColor]
    
    public init(
        colors: [UIColor]
    ) {
        self.colors = colors
    }
    
    public static func ==(lhs: GradientBackgroundComponent, rhs: GradientBackgroundComponent) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let clipLayer: CALayer
        private let gradientLayer: CAGradientLayer
        
        private var component: GradientBackgroundComponent?
        
        override init(frame: CGRect) {
            self.clipLayer = CALayer()
            self.clipLayer.cornerRadius = 10.0
            self.clipLayer.masksToBounds = true
            
            self.gradientLayer = CAGradientLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.clipLayer)
            self.clipLayer.addSublayer(gradientLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(component: GradientBackgroundComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.clipLayer.frame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: availableSize.height + 10.0))
            self.gradientLayer.frame = CGRect(origin: .zero, size: availableSize)
        
            var locations: [NSNumber] = []
            let delta = 1.0 / CGFloat(component.colors.count - 1)
            for i in 0 ..< component.colors.count {
                locations.append((delta * CGFloat(i)) as NSNumber)
            }
            self.gradientLayer.locations = locations
            self.gradientLayer.colors = component.colors.reversed().map { $0.cgColor }
            self.gradientLayer.type = .radial
            self.gradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
            self.gradientLayer.endPoint = CGPoint(x: -2.0, y: 3.0)
            
            self.component = component
            
            self.setupGradientAnimations()
            
            return availableSize
        }
        
        private func setupGradientAnimations() {
            if let _ = self.gradientLayer.animation(forKey: "movement") {
            } else {
                let previousValue = self.gradientLayer.endPoint
                let value: CGFloat
                if previousValue.x < -0.5 {
                    value = 0.5
                } else {
                    value = 2.0
                }
                let newValue = CGPoint(x: -value, y: 1.0 + value)
//                let secondNewValue = CGPoint(x: 3.0 - value, y: -2.0 + value)
                self.gradientLayer.endPoint = newValue
                
                CATransaction.begin()
                
                let animation = CABasicAnimation(keyPath: "endPoint")
                animation.duration = 4.5
                animation.fromValue = previousValue
                animation.toValue = newValue
                
                CATransaction.setCompletionBlock { [weak self] in
                    self?.setupGradientAnimations()
                }
                
                self.gradientLayer.add(animation, forKey: "movement")
                
//                let secondPreviousValue = self.gradientLayer.startPoint
//                let secondAnimation = CABasicAnimation(keyPath: "startPoint")
//                secondAnimation.duration = 4.5
//                secondAnimation.fromValue = secondPreviousValue
//                secondAnimation.toValue = secondNewValue
//
//                self.gradientLayer.add(secondAnimation, forKey: "movement2")
                
                CATransaction.commit()
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class DemoPageEnvironment: Equatable {
    public let isDisplaying: Bool
    public let isCentral: Bool
    public let position: CGFloat
    
    public init(isDisplaying: Bool, isCentral: Bool, position: CGFloat) {
        self.isDisplaying = isDisplaying
        self.isCentral = isCentral
        self.position = position
    }
    
    public static func ==(lhs: DemoPageEnvironment, rhs: DemoPageEnvironment) -> Bool {
        if lhs.isDisplaying != rhs.isDisplaying {
            return false
        }
        if lhs.isCentral != rhs.isCentral {
            return false
        }
        if lhs.position != rhs.position {
            return false
        }
        return true
    }
}

private final class PageComponent<ChildEnvironment: Equatable>: CombinedComponent {
    typealias EnvironmentType = ChildEnvironment
    
    private let content: AnyComponent<ChildEnvironment>
    private let title: String
    private let text: String
    private let textColor: UIColor
    
    init(
        content: AnyComponent<ChildEnvironment>,
        title: String,
        text: String,
        textColor: UIColor
    ) {
        self.content = content
        self.title = title
        self.text = text
        self.textColor = textColor
    }
    
    static func ==(lhs: PageComponent<ChildEnvironment>, rhs: PageComponent<ChildEnvironment>) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let children = ChildMap(environment: ChildEnvironment.self, keyedBy: AnyHashable.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)

        return { context in
            let availableSize = context.availableSize
            let component = context.component
            
            let sideInset: CGFloat = 16.0
            let textSideInset: CGFloat = 24.0
            
            let textColor = component.textColor
            let textFont = Font.regular(17.0)
            let boldTextFont = Font.semibold(17.0)
            
            let content = children["main"].update(
                component: component.content,
                environment: {
                    context.environment[ChildEnvironment.self]
                },
                availableSize: CGSize(width: availableSize.width, height: availableSize.width),
                transition: context.transition
            )
                        
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: boldTextFont,
                        textColor: component.textColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: textColor),
                linkAttribute: { _ in
                    return nil
                }
            )
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.0
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: content.size.height + 40.0))
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: content.size.height + 80.0))
            )
            context.add(content
                .position(CGPoint(x: content.size.width / 2.0, y: content.size.height / 2.0))
            )
        
            return availableSize
        }
    }
}

private final class DemoPagerComponent: Component {
    public final class Item: Equatable {
        public let content: AnyComponentWithIdentity<DemoPageEnvironment>
        
        public init(_ content: AnyComponentWithIdentity<DemoPageEnvironment>) {
            self.content = content
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.content != rhs.content {
                return false
            }
            
            return true
        }
    }
    
    let items: [Item]
    let index: Int
    let activeColor: UIColor
    let inactiveColor: UIColor
    
    public init(
        items: [Item],
        index: Int = 0,
        activeColor: UIColor,
        inactiveColor: UIColor
    ) {
        self.items = items
        self.index = index
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }
    
    public static func ==(lhs: DemoPagerComponent, rhs: DemoPagerComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if !lhs.activeColor.isEqual(rhs.activeColor) {
            return false
        }
        if !lhs.inactiveColor.isEqual(rhs.inactiveColor) {
            return false
        }
        return true
    }
    
    fileprivate final class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        private var itemViews: [AnyHashable: ComponentHostView<DemoPageEnvironment>] = [:]
        
        private let pageIndicatorView: ComponentHostView<Empty>
        
        private var component: DemoPagerComponent?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView(frame: frame)
            self.scrollView.isPagingEnabled = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.bounces = false
            self.scrollView.layer.cornerRadius = 10.0
            
            self.pageIndicatorView = ComponentHostView<Empty>()
            self.pageIndicatorView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            
            self.addSubview(self.scrollView)
            self.addSubview(self.pageIndicatorView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var ignoreContentOffsetChange = false
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let component = self.component, !self.ignoreContentOffsetChange else {
                return
            }

            self.ignoreContentOffsetChange = true
            let _ = self.update(component: component, availableSize: self.bounds.size, transition: .immediate)
            self.ignoreContentOffsetChange = false
        }
        
        func update(component: DemoPagerComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            var validIds: [AnyHashable] = []
            
            let firstTime = self.itemViews.isEmpty
            
            let contentSize = CGSize(width: availableSize.width * CGFloat(component.items.count), height: availableSize.height)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollFrame = CGRect(origin: .zero, size: availableSize)
            if self.scrollView.frame != scrollFrame {
                self.scrollView.frame = scrollFrame
            }
            
            if firstTime {
                self.scrollView.contentOffset = CGPoint(x: CGFloat(component.index) * availableSize.width, y: 0.0)
            }
            let viewportCenter = self.scrollView.contentOffset.x + availableSize.width * 0.5
            
            var i = 0
            for item in component.items {
                let itemFrame = CGRect(origin: CGPoint(x: availableSize.width * CGFloat(i), y: 0.0), size: availableSize)
                let isDisplaying = itemFrame.intersects(self.scrollView.bounds)
                                
                let centerDelta = itemFrame.midX - viewportCenter
                let position = centerDelta / (availableSize.width * 0.75)
                
                i += 1
                
                if abs(position) > 1.5 {
                    continue
                }
                
                validIds.append(item.content.id)
                
                let itemView: ComponentHostView<DemoPageEnvironment>
                var itemTransition = transition
                
                if let current = self.itemViews[item.content.id] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<DemoPageEnvironment>()
                    self.itemViews[item.content.id] = itemView
                    
                    
                    if item.content.id == (PremiumDemoScreen.Subject.fasterDownload as AnyHashable) {
                        self.scrollView.insertSubview(itemView, at: 0)
                    } else {
                        self.scrollView.addSubview(itemView)
                    }
                }
                                
                let environment = DemoPageEnvironment(isDisplaying: isDisplaying, isCentral: abs(centerDelta) < CGFloat.ulpOfOne, position: position)
                let _ = itemView.update(
                    transition: itemTransition,
                    component: item.content.component,
                    environment: { environment },
                    containerSize: availableSize
                )
                
                itemView.frame = itemFrame
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
                
            self.component = component
            
            if component.items.count > 1 {
                let pageIndicatorComponent = PageIndicatorComponent(
                    pageCount: component.items.count,
                    position: self.scrollView.contentOffset.x / (self.scrollView.contentSize.width - availableSize.width),
                    inactiveColor: component.inactiveColor,
                    activeColor: component.activeColor
                )
                let indicatorSize = self.pageIndicatorView.update(
                    transition: .immediate,
                    component: AnyComponent(
                        pageIndicatorComponent
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                self.pageIndicatorView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - indicatorSize.width) / 2.0), y: availableSize.height - indicatorSize.height - 11.0), size: indicatorSize)
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

public final class DemoAnimateInTransition {
}

private final class DemoSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumDemoScreen.Subject
    let source: PremiumDemoScreen.Source
    let order: [PremiumPerk]
    let action: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        subject: PremiumDemoScreen.Subject,
        source: PremiumDemoScreen.Source,
        order: [PremiumPerk]?,
        action: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.subject = subject
        self.source = source
        self.order = order ?? [.moreUpload, .fasterDownload, .voiceToText, .noAds, .uniqueReactions, .premiumStickers, .advancedChatManagement, .profileBadge, .animatedUserpics, .appIcons]
        self.action = action
        self.dismiss = dismiss
    }
    
    static func ==(lhs: DemoSheetContent, rhs: DemoSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.source != rhs.source {
            return false
        }
        if lhs.order != rhs.order {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        var cachedCloseImage: UIImage?
        
        var isPremium: Bool?
        var reactions: [AvailableReactions.Reaction]?
        var stickers: [TelegramMediaFile]?
        var appIcons: [PresentationAppIcon]?
        var disposable: Disposable?
        
        var promoConfiguration: PremiumPromoConfiguration?
        
        init(context: AccountContext) {
            self.context = context
            self.appIcons = context.sharedContext.applicationBindings.getAvailableAlternateIcons().filter { $0.isPremium }
            
            super.init()
            
            let accountSpecificReactionOverrides: [ExperimentalUISettings.AccountReactionOverrides.Item]
            if self.context.sharedContext.immediateExperimentalUISettings.enableReactionOverrides, let value = self.context.sharedContext.immediateExperimentalUISettings.accountReactionEffectOverrides.first(where: { $0.accountId == self.context.account.id.int64 }) {
                accountSpecificReactionOverrides = value.items
            } else {
                accountSpecificReactionOverrides = []
            }
            
            let reactionOverrideMessages = self.context.engine.data.get(
                EngineDataMap(accountSpecificReactionOverrides.map(\.messageId).map(TelegramEngine.EngineData.Item.Messages.Message.init))
            )
            
            let accountSpecificStickerOverrides: [ExperimentalUISettings.AccountReactionOverrides.Item]
            if self.context.sharedContext.immediateExperimentalUISettings.enableReactionOverrides, let value = self.context.sharedContext.immediateExperimentalUISettings.accountStickerEffectOverrides.first(where: { $0.accountId == self.context.account.id.int64 }) {
                accountSpecificStickerOverrides = value.items
            } else {
                accountSpecificStickerOverrides = []
            }
            let stickerOverrideMessages = self.context.engine.data.get(
                EngineDataMap(accountSpecificStickerOverrides.map(\.messageId).map(TelegramEngine.EngineData.Item.Messages.Message.init))
            )
            
            let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudPremiumStickers)
            self.disposable = (combineLatest(
                queue: Queue.mainQueue(),
                self.context.engine.stickers.availableReactions(),
                self.context.account.postbox.combinedView(keys: [stickersKey])
                |> map { views -> [OrderedItemListEntry]? in
                    if let view = views.views[stickersKey] as? OrderedItemListView, !view.items.isEmpty {
                        return view.items
                    } else {
                        return nil
                    }
                }
                |> filter { items in
                    return items != nil
                }
                |> take(1),
                self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId),
                    TelegramEngine.EngineData.Item.Configuration.PremiumPromo()
                ),
                reactionOverrideMessages,
                stickerOverrideMessages
            )
            |> map { reactions, items, data, reactionOverrideMessages, stickerOverrideMessages -> ([AvailableReactions.Reaction], [TelegramMediaFile], Bool?, PremiumPromoConfiguration?) in
                var reactionOverrides: [String: TelegramMediaFile] = [:]
                for item in accountSpecificReactionOverrides {
                    if let maybeMessage = reactionOverrideMessages[item.messageId], let message = maybeMessage {
                        for media in message.media {
                            if let file = media as? TelegramMediaFile, file.fileId == item.mediaId {
                                reactionOverrides[item.key] = file
                            }
                        }
                    }
                }
                
                var stickerOverrides: [String: TelegramMediaFile] = [:]
                for item in accountSpecificStickerOverrides {
                    if let maybeMessage = stickerOverrideMessages[item.messageId], let message = maybeMessage {
                        for media in message.media {
                            if let file = media as? TelegramMediaFile, file.fileId == item.mediaId {
                                stickerOverrides[item.key] = file
                            }
                        }
                    }
                }
                
                if let reactions = reactions {
                    var result: [TelegramMediaFile] = []
                    if let items = items {
                        for item in items {
                            if let mediaItem = item.contents.get(RecentMediaItem.self) {
                                result.append(mediaItem.media)
                            }
                        }
                    }
                    return (reactions.reactions.filter({ $0.isPremium }).map { reaction -> AvailableReactions.Reaction in
                        var aroundAnimation = reaction.aroundAnimation
                        if let replacementFile = reactionOverrides[reaction.value] {
                            aroundAnimation = replacementFile
                        }
                        
                        return AvailableReactions.Reaction(
                            isEnabled: reaction.isEnabled,
                            isPremium: reaction.isPremium,
                            value: reaction.value,
                            title: reaction.title,
                            staticIcon: reaction.staticIcon,
                            appearAnimation: reaction.appearAnimation,
                            selectAnimation: reaction.selectAnimation,
                            activateAnimation: reaction.activateAnimation,
                            effectAnimation: reaction.effectAnimation,
                            aroundAnimation: aroundAnimation,
                            centerAnimation: reaction.centerAnimation
                        )
                    }, result.map { file -> TelegramMediaFile in
                        for attribute in file.attributes {
                            switch attribute {
                            case let .Sticker(displayText, _, _):
                                if let replacementFile = stickerOverrides[displayText], let dimensions = replacementFile.dimensions {
                                    let _ = dimensions
                                    return TelegramMediaFile(
                                        fileId: file.fileId,
                                        partialReference: file.partialReference,
                                        resource: file.resource,
                                        previewRepresentations: file.previewRepresentations,
                                        videoThumbnails: [TelegramMediaFile.VideoThumbnail(dimensions: dimensions, resource: replacementFile.resource)],
                                        immediateThumbnailData: file.immediateThumbnailData,
                                        mimeType: file.mimeType,
                                        size: file.size,
                                        attributes: file.attributes
                                    )
                                }
                            default:
                                break
                            }
                        }
                        return file
                    }, data.0?.isPremium ?? false, data.1)
                } else {
                    return ([], [], nil, nil)
                }
            }).start(next: { [weak self] reactions, stickers, isPremium, promoConfiguration in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reactions = reactions
                strongSelf.stickers = stickers
                strongSelf.isPremium = isPremium
                strongSelf.promoConfiguration = promoConfiguration
                if !reactions.isEmpty && !stickers.isEmpty {
                    strongSelf.updated(transition: Transition(.immediate).withUserData(DemoAnimateInTransition()))
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context)
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        let background = Child(GradientBackgroundComponent.self)
        let pager = Child(DemoPagerComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            
            let state = context.state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
                    
            let background = background.update(
                component: GradientBackgroundComponent(colors: [
                    UIColor(rgb: 0x0077ff),
                    UIColor(rgb: 0x6b93ff),
                    UIColor(rgb: 0x8878ff),
                    UIColor(rgb: 0xe46ace)
                ]),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.width),
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
            
            let closeImage: UIImage
            if let image = state.cachedCloseImage {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff))!
                state.cachedCloseImage = closeImage
            }
            
            var isStandalone = false
            if case .other = component.source {
                isStandalone = true
            }
            
            if let reactions = state.reactions, let stickers = state.stickers, let appIcons = state.appIcons, let configuration = state.promoConfiguration {
                let textColor = theme.actionSheet.primaryTextColor
                
                var availableItems: [PremiumPerk: DemoPagerComponent.Item] = [:]
                
                availableItems[.moreUpload] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.moreUpload,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .bottom,
                                    videoFile: configuration.videos["more_upload"],
                                    decoration: .dataRain
                                )),
                                title: strings.Premium_UploadSize,
                                text: strings.Premium_UploadSizeInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.fasterDownload] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.fasterDownload,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    videoFile: configuration.videos["faster_download"],
                                    decoration: .fasterStars
                                )),
                                title: strings.Premium_FasterSpeed,
                                text: strings.Premium_FasterSpeedInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.voiceToText] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.voiceToText,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    videoFile: configuration.videos["voice_to_text"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_VoiceToText,
                                text: strings.Premium_VoiceToTextInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.noAds] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.noAds,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .bottom,
                                    videoFile: configuration.videos["no_ads"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_NoAds,
                                text: isStandalone ? strings.Premium_NoAdsStandaloneInfo : strings.Premium_NoAdsInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.uniqueReactions] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.uniqueReactions,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(
                                    ReactionsCarouselComponent(
                                        context: component.context,
                                        theme: environment.theme,
                                        reactions: reactions
                                    )
                                ),
                                title: isStandalone ? strings.Premium_ReactionsStandalone : strings.Premium_Reactions,
                                text: isStandalone ? strings.Premium_ReactionsStandaloneInfo : strings.Premium_ReactionsInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.premiumStickers] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.premiumStickers,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(
                                    StickersCarouselComponent(
                                        context: component.context,
                                        stickers: stickers
                                    )
                                ),
                                title: strings.Premium_Stickers,
                                text: strings.Premium_StickersInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.advancedChatManagement] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.advancedChatManagement,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    videoFile: configuration.videos["advanced_chat_management"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_ChatManagement,
                                text: strings.Premium_ChatManagementInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.profileBadge] =  DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.profileBadge,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    videoFile: configuration.videos["profile_badge"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_Badge,
                                text: strings.Premium_BadgeInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.animatedUserpics] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.animatedUserpics,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    videoFile: configuration.videos["animated_userpics"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_Avatar,
                                text: strings.Premium_AvatarInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.appIcons] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.appIcons,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(AppIconsDemoComponent(
                                    context: component.context,
                                    appIcons: appIcons
                                )),
                                title: isStandalone ? strings.Premium_AppIconStandalone : strings.Premium_AppIcon,
                                text: isStandalone ? strings.Premium_AppIconStandaloneInfo :strings.Premium_AppIconInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                
                var items: [DemoPagerComponent.Item] = component.order.compactMap { availableItems[$0] }
                let index: Int
                switch component.source {
                    case .intro:
                        index = items.firstIndex(where: { (component.subject as AnyHashable) == $0.content.id }) ?? 0
                    case .other:
                        items = items.filter { item in
                            return item.content.id == (component.subject as AnyHashable)
                        }
                        index = 0
                }
                
                let pager = pager.update(
                    component: DemoPagerComponent(
                        items: items,
                        index: index,
                        activeColor: UIColor(rgb: 0x7169ff),
                        inactiveColor: theme.list.disclosureArrowColor
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.width + 154.0),
                    transition: context.transition
                )
                context.add(pager
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: pager.size.height / 2.0))
                )
            }
            
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(ZStack([
                        AnyComponentWithIdentity(
                            id: "background",
                            component: AnyComponent(
                                BlurredRectangle(
                                    color:  UIColor(rgb: 0x888888, alpha: 0.1),
                                    radius: 15.0
                                )
                            )
                        ),
                        AnyComponentWithIdentity(
                            id: "icon",
                            component: AnyComponent(
                                Image(image: closeImage)
                            )
                        ),
                    ])),
                    action: { [weak component] in
                        component?.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
            )
                         
            let buttonText: String
            var buttonAnimationName: String?
            if state.isPremium == true {
                buttonText = strings.Common_OK
            } else {
                switch component.source {
                    case let .intro(price):
                        buttonText = strings.Premium_SubscribeFor(price ?? "–").string
                    case .other:
                        switch component.subject {
                            case .uniqueReactions:
                                buttonText = strings.Premium_Reactions_Proceed
                                buttonAnimationName = "premium_unlock"
                            case .premiumStickers:
                                buttonText = strings.Premium_Stickers_Proceed
                                buttonAnimationName = "premium_unlock"
                            case .appIcons:
                                buttonText = strings.Premium_AppIcons_Proceed
                                buttonAnimationName = "premium_unlock"
                            case .noAds:
                                buttonText = strings.Premium_NoAds_Proceed
                            default:
                                buttonText = strings.Common_OK
                        }
                }
            }
            
            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: buttonText,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: .black,
                        backgroundColors: [
                            UIColor(rgb: 0x0077ff),
                            UIColor(rgb: 0x6b93ff),
                            UIColor(rgb: 0x8878ff),
                            UIColor(rgb: 0xe46ace)
                        ],
                        foregroundColor: .white
                    ),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 11.0,
                    gloss: state.isPremium != true,
                    animationName: isStandalone ? buttonAnimationName : nil,
                    iconPosition: .right,
                    iconSpacing: 4.0,
                    action: { [weak component, weak state] in
                        guard let component = component else {
                            return
                        }
                        component.dismiss()
                        if let state = state, state.isPremium == false {
                            component.action()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
        
            var contentHeight: CGFloat = context.availableSize.width + 146.0
            if case .other = component.source {
                contentHeight -= 40.0
            }
              
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 20.0), size: button.size)
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
        
            let bottomPanelPadding: CGFloat = 12.0
            let bottomInset: CGFloat
            if case .regular = environment.metrics.widthClass {
                bottomInset = bottomPanelPadding
            } else {
                bottomInset = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            }
            return CGSize(width: context.availableSize.width, height: buttonFrame.maxY + bottomInset)
        }
    }
}


private final class DemoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: PremiumDemoScreen.Subject
    let source: PremiumDemoScreen.Source
    let order: [PremiumPerk]?
    let action: () -> Void
    
    init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source, order: [PremiumPerk]?, action: @escaping () -> Void) {
        self.context = context
        self.subject = subject
        self.source = source
        self.order = order
        self.action = action
    }
    
    static func ==(lhs: DemoSheetComponent, rhs: DemoSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.source != rhs.source {
            return false
        }
        if lhs.order != rhs.order {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(DemoSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        source: context.component.source,
                        order: context.component.order,
                        action: context.component.action,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: environment.theme.actionSheet.opaqueItemBackgroundColor,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        dismiss: { animated in
                            if animated {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else {
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public class PremiumDemoScreen: ViewControllerComponentContainer {
    public enum Subject {
        case moreUpload
        case fasterDownload
        case voiceToText
        case noAds
        case uniqueReactions
        case premiumStickers
        case advancedChatManagement
        case profileBadge
        case animatedUserpics
        case appIcons
    }
    
    public enum Source: Equatable {
        case intro(String?)
        case other
    }
    
    var disposed: () -> Void = {}
    
    private var didSetReady = false
    private let _ready = Promise<Bool>()
    public override var ready: Promise<Bool> {
        return self._ready
    }
        
    public convenience init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source = .other, action: @escaping () -> Void) {
        self.init(context: context, subject: subject, source: source, order: nil, action: action)
    }
    
    init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source = .other, order: [PremiumPerk]?, action: @escaping () -> Void) {
        super.init(context: context, component: DemoSheetComponent(context: context, subject: subject, source: source, order: order, action: action), navigationBarAppearance: .none)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if !self.didSetReady {
            self.didSetReady = true
            if let view = self.node.hostView.findTaggedView(tag: PhoneDemoComponent.View.Tag()) as? PhoneDemoComponent.View {
                self._ready.set(view.ready)
            } else {
                self._ready.set(.single(true) |> delay(0.1, queue: Queue.mainQueue()))
            }
        }
    }
}

