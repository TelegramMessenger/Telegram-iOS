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
import BlurredBackgroundComponent
import Markdown
import TelegramUIPreferences

public final class PremiumGradientBackgroundComponent: Component {
    public let colors: [UIColor]
    public let cornerRadius: CGFloat
    public let topOverscroll: Bool
    
    public init(
        colors: [UIColor],
        cornerRadius: CGFloat = 10.0,
        topOverscroll: Bool = false
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.topOverscroll = topOverscroll
    }
    
    public static func ==(lhs: PremiumGradientBackgroundComponent, rhs: PremiumGradientBackgroundComponent) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        if lhs.topOverscroll != rhs.topOverscroll {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let clipLayer: CAReplicatorLayer
        private let gradientLayer: CAGradientLayer
        
        private var component: PremiumGradientBackgroundComponent?
        
        override init(frame: CGRect) {
            self.clipLayer = CAReplicatorLayer()
            self.clipLayer.masksToBounds = true
            
            self.gradientLayer = CAGradientLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.clipLayer)
            self.clipLayer.addSublayer(gradientLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(component: PremiumGradientBackgroundComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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

            self.clipLayer.cornerRadius = component.cornerRadius
            
            self.component = component
            
            self.setupGradientAnimations()
            
            if component.topOverscroll {
                self.clipLayer.instanceCount = 2
                var instanceTransform = CATransform3DIdentity
                instanceTransform = CATransform3DTranslate(instanceTransform, 0.0, -availableSize.height * 1.5, 0.0)
                instanceTransform = CATransform3DScale(instanceTransform, 1.0, -2.0, 1.0)
                self.clipLayer.instanceTransform = instanceTransform
                self.clipLayer.masksToBounds = false
            } else {
                self.clipLayer.masksToBounds = true
            }
            
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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

final class PageComponent<ChildEnvironment: Equatable>: CombinedComponent {
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
                .position(CGPoint(x: context.availableSize.width / 2.0, y: content.size.height + 60.0 + text.size.height / 2.0))
            )
            context.add(content
                .position(CGPoint(x: content.size.width / 2.0, y: content.size.height / 2.0))
            )
        
            return availableSize
        }
    }
}

final class DemoPagerComponent: Component {
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
    let nextAction: ActionSlot<Void>?
    let updated: (CGFloat, Int) -> Void
    
    public init(
        items: [Item],
        index: Int = 0,
        nextAction: ActionSlot<Void>? = nil,
        updated: @escaping (CGFloat, Int) -> Void
    ) {
        self.items = items
        self.index = index
        self.nextAction = nextAction
        self.updated = updated
    }
    
    public static func ==(lhs: DemoPagerComponent, rhs: DemoPagerComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        private var itemViews: [AnyHashable: ComponentHostView<DemoPageEnvironment>] = [:]
        
        private var component: DemoPagerComponent?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView(frame: frame)
            self.scrollView.isPagingEnabled = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.bounces = false
            self.scrollView.layer.cornerRadius = 10.0
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            
            self.addSubview(self.scrollView)
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
            component.updated(self.scrollView.contentOffset.x / (self.scrollView.contentSize.width - self.scrollView.frame.width), component.items.count)
            self.ignoreContentOffsetChange = false
        }
        
        func update(component: DemoPagerComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            var validIds: [AnyHashable] = []
            
            component.nextAction?.connect { [weak self] in
                if let self {
                    var nextContentOffset = self.scrollView.contentOffset
                    nextContentOffset.x += self.scrollView.frame.width
                    if nextContentOffset.x >= self.scrollView.contentSize.width {
                        nextContentOffset.x = 0.0
                    }
                    self.scrollView.contentOffset = nextContentOffset
                }
            }
            
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
                var position: CGFloat
                if self.scrollView.contentSize.width > self.scrollView.frame.width {
                    position = self.scrollView.contentOffset.x / (self.scrollView.contentSize.width - self.scrollView.frame.width)
                } else {
                    position = 0.0
                }
                component.updated(position, component.items.count)
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
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
    let action: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        subject: PremiumDemoScreen.Subject,
        source: PremiumDemoScreen.Source,
        action: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.subject = subject
        self.source = source
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
                    if let view = views.views[stickersKey] as? OrderedItemListView {
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
                var reactionOverrides: [MessageReaction.Reaction: TelegramMediaFile] = [:]
                for item in accountSpecificReactionOverrides {
                    if let maybeMessage = reactionOverrideMessages[item.messageId], let message = maybeMessage {
                        for media in message.media {
                            if let file = media as? TelegramMediaFile, file.fileId == item.mediaId {
                                reactionOverrides[item.key] = file
                            }
                        }
                    }
                }
                
                var stickerOverrides: [MessageReaction.Reaction: TelegramMediaFile] = [:]
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
                                result.append(mediaItem.media._parse())
                            }
                        }
                    }
                    return (reactions.reactions.filter({ $0.isPremium }).map { reaction -> AvailableReactions.Reaction in
                        var aroundAnimation = reaction.aroundAnimation
                        if let replacementFile = reactionOverrides[reaction.value] {
                            aroundAnimation = TelegramMediaFile.Accessor(replacementFile)
                        }
                        
                        return AvailableReactions.Reaction(
                            isEnabled: reaction.isEnabled,
                            isPremium: reaction.isPremium,
                            value: reaction.value,
                            title: reaction.title,
                            staticIcon: reaction.staticIcon._parse(),
                            appearAnimation: reaction.appearAnimation._parse(),
                            selectAnimation: reaction.selectAnimation._parse(),
                            activateAnimation: reaction.activateAnimation._parse(),
                            effectAnimation: reaction.effectAnimation._parse(),
                            aroundAnimation: aroundAnimation?._parse(),
                            centerAnimation: reaction.centerAnimation?._parse()
                        )
                    }, result.map { file -> TelegramMediaFile in
                        for attribute in file.attributes {
                            switch attribute {
                            case let .Sticker(displayText, _, _):
                                if let replacementFile = stickerOverrides[.builtin(displayText)], let dimensions = replacementFile.dimensions {
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
                                        attributes: file.attributes,
                                        alternativeRepresentations: file.alternativeRepresentations
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
                    strongSelf.updated(transition: ComponentTransition(.immediate).withUserData(DemoAnimateInTransition()))
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
        let background = Child(PremiumGradientBackgroundComponent.self)
        let pager = Child(DemoPagerComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        let measureText = Child(MultilineTextComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            
            let state = context.state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
                    
            let background = background.update(
                component: PremiumGradientBackgroundComponent(colors: [
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
                        
            if let stickers = state.stickers, let appIcons = state.appIcons, let configuration = state.promoConfiguration {
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
                                text: isStandalone ? strings.Premium_FasterSpeedStandaloneInfo : strings.Premium_FasterSpeedInfo,
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
                                text: isStandalone ? strings.Premium_VoiceToTextStandaloneInfo : strings.Premium_VoiceToTextInfo,
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
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    videoFile: configuration.videos["infinite_reactions"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_InfiniteReactions,
                                text: strings.Premium_InfiniteReactionsInfo,
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
                                        stickers: stickers,
                                        tapAction: {}
                                    )
                                ),
                                title: strings.Premium_Stickers,
                                text: strings.Premium_StickersInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.emojiStatus] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.emojiStatus,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    videoFile: configuration.videos["emoji_status"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_EmojiStatus,
                                text: strings.Premium_EmojiStatusInfo,
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
                                text: isStandalone ? strings.Premium_ChatManagementStandaloneInfo : strings.Premium_ChatManagementInfo,
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
                availableItems[.animatedEmoji] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.animatedEmoji,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .bottom,
                                    videoFile: configuration.videos["animated_emoji"],
                                    decoration: .emoji
                                )),
                                title: strings.Premium_AnimatedEmoji,
                                text: isStandalone ? strings.Premium_AnimatedEmojiStandaloneInfo : strings.Premium_AnimatedEmojiInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.translation] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.translation,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    model: .island,
                                    videoFile: configuration.videos["translations"],
                                    decoration: .hello
                                )),
                                title: strings.Premium_Translation,
                                text: isStandalone ? strings.Premium_TranslationStandaloneInfo : strings.Premium_TranslationInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.colors] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.colors,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    videoFile: configuration.videos["peer_colors"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_Colors,
                                text: strings.Premium_ColorsInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.wallpapers] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.wallpapers,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    model: .island,
                                    videoFile: configuration.videos["wallpapers"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_Wallpapers,
                                text: strings.Premium_WallpapersInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.messageTags] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.messageTags,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    model: .island,
                                    videoFile: configuration.videos["saved_tags"],
                                    decoration: .tag
                                )),
                                title: strings.Premium_MessageTags,
                                text: strings.Premium_MessageTagsInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.lastSeen] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.lastSeen,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    model: .island,
                                    videoFile: configuration.videos["last_seen"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_LastSeen,
                                text: strings.Premium_LastSeenInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.messagePrivacy] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.messagePrivacy,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    model: .island,
                                    videoFile: configuration.videos["message_privacy"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_MessagePrivacy,
                                text: strings.Premium_MessagePrivacyInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                
                availableItems[.folderTags] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.folderTags,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    model: .island,
                                    videoFile: configuration.videos["folder_tags"],
                                    decoration: .tag
                                )),
                                title: strings.Premium_FolderTags,
                                text: strings.Premium_FolderTagsStandaloneInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                
                availableItems[.messageEffects] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.messageEffects,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    model: .island,
                                    videoFile: configuration.videos["effects"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_MessageEffects,
                                text: strings.Premium_MessageEffectsInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                                
                availableItems[.todo] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.todo,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: component.context,
                                    position: .top,
                                    model: .island,
                                    videoFile: configuration.videos["todo"],
                                    decoration: .todo
                                )),
                                title: strings.Premium_Todo,
                                text: strings.Premium_TodoInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                
                let index: Int = 0
                var items: [DemoPagerComponent.Item] = []
                if let item = availableItems.first(where: { $0.value.content.id == component.subject as AnyHashable }) {
                    items.append(item.value)
                } else {
                    fatalError()
                }
                
                let pager = pager.update(
                    component: DemoPagerComponent(
                        items: items,
                        index: index,
                        updated: { _, _ in }
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
                                BlurredBackgroundComponent(
                                    color: UIColor(rgb: 0x888888, alpha: 0.1)
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
                .clipsToBounds(true)
                .cornerRadius(15.0)
            )
                         
            var measuredTextHeight: CGFloat?
            var text: String
            switch component.subject {
            case .moreUpload:
                text = strings.Premium_UploadSizeInfo
            case .fasterDownload:
                text = strings.Premium_FasterSpeedStandaloneInfo
            case .voiceToText:
                text = strings.Premium_VoiceToTextStandaloneInfo
            case .noAds:
                text = strings.Premium_NoAdsStandaloneInfo
            case .uniqueReactions:
                text = strings.Premium_InfiniteReactionsInfo
            case .premiumStickers:
                text = strings.Premium_StickersInfo
            case .emojiStatus:
                text = strings.Premium_EmojiStatusInfo
            case .advancedChatManagement:
                text = strings.Premium_ChatManagementStandaloneInfo
            case .profileBadge:
                text = strings.Premium_BadgeInfo
            case .animatedUserpics:
                text = strings.Premium_AvatarInfo
            case .appIcons:
                text = strings.Premium_AppIconStandaloneInfo
            case .animatedEmoji:
                text = strings.Premium_AnimatedEmojiStandaloneInfo
            case .translation:
                text = strings.Premium_TranslationStandaloneInfo
            case .colors:
                text = strings.Premium_ColorsInfo
            case .wallpapers:
                text = strings.Premium_WallpapersInfo
            case .messageTags:
                text = strings.Premium_MessageTagsInfo
            case .lastSeen:
                text = strings.Premium_LastSeenInfo
            case .messagePrivacy:
                text = strings.Premium_MessagePrivacyInfo
            case .folderTags:
                text = strings.Premium_FolderTagsStandaloneInfo
            case .messageEffects:
                text = strings.Premium_MessageEffectsInfo
            case .todo:
                text = strings.Premium_TodoInfo
            default:
                text = ""
            }
        
            let textSideInset: CGFloat = 24.0
            
            let textColor = UIColor.black
            let textFont = Font.regular(17.0)
            let boldTextFont = Font.semibold(17.0)
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: textColor),
                linkAttribute: { _ in
                    return nil
                }
            )
            let measureText = measureText.update(
                component: MultilineTextComponent(
                    text: .markdown(text: text, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.0
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(measureText
                .position(CGPoint(x: 0.0, y: 1000.0))
            )
            measuredTextHeight = measureText.size.height
            
            let buttonText: String
            var buttonAnimationName: String?
            if state.isPremium == true {
                buttonText = strings.Common_OK
            } else {
                switch component.source {
                case let .intro(price):
                    buttonText = strings.Premium_SubscribeFor(price ?? "–").string
                case let .gift(price):
                    buttonText = strings.Premium_Gift_GiftSubscription(price ?? "–").string
                case .other:
                    switch component.subject {
                        case .fasterDownload:
                            buttonText = strings.Premium_FasterSpeed_Proceed
                        case .advancedChatManagement:
                            buttonText = strings.Premium_ChatManagement_Proceed
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
                        case .animatedEmoji:
                            buttonText = strings.Premium_AnimatedEmoji_Proceed
                            buttonAnimationName = "premium_unlock"
                        case .translation:
                            buttonText = strings.Premium_Translation_Proceed
                        case .stories:
                            buttonText = strings.Common_OK
                            buttonAnimationName = "premium_unlock"
                        case .voiceToText:
                            buttonText = strings.Premium_VoiceToText_Proceed
                        case .wallpapers:
                            buttonText = strings.Premium_Wallpaper_Proceed
                        case .colors:
                            buttonText = strings.Premium_Colors_Proceed
                        case .messageTags:
                            buttonText = strings.Premium_MessageTags_Proceed
                        case .lastSeen:
                            buttonText = strings.Premium_LastSeen_Proceed
                        case .messagePrivacy:
                            buttonText = strings.Premium_MessagePrivacy_Proceed
                        case .folderTags:
                            buttonText = strings.Premium_FolderTags_Proceed
                        case .emojiStatus:
                            buttonText = strings.Premium_EmojiStatus_Proceed
                            buttonAnimationName = "premium_unlock"
                        case .todo:
                            buttonText = strings.Premium_PaidMessages_Proceed
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
        
            var contentHeight: CGFloat = context.availableSize.width
            if let measuredTextHeight {
                contentHeight += measuredTextHeight + 66.0
            } else {
                contentHeight += 146.0
                if case .other = component.source {
                    contentHeight -= 40.0
                    
                    if [.advancedChatManagement, .fasterDownload].contains(component.subject) {
                        contentHeight += 20.0
                    }
                }
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
    let action: () -> Void
    
    init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source, action: @escaping () -> Void) {
        self.context = context
        self.subject = subject
        self.source = source
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
                        action: context.component.action,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: context.component.source == .other,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: nil,
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
        case doubleLimits
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
        case animatedEmoji
        case emojiStatus
        case translation
        case stories
        case colors
        case wallpapers
        case messageTags
        case lastSeen
        case messagePrivacy
        case business
        case folderTags
        case messageEffects
        case todo
        
        case businessLocation
        case businessHours
        case businessGreetingMessage
        case businessQuickReplies
        case businessAwayMessage
        case businessChatBots
        case businessIntro
        case businessLinks
        
        public var perk: PremiumPerk {
            switch self {
            case .doubleLimits:
                return .doubleLimits
            case .moreUpload:
                return .moreUpload
            case .fasterDownload:
                return .fasterDownload
            case .voiceToText:
                return .voiceToText
            case .noAds:
                return .noAds
            case .uniqueReactions:
                return .uniqueReactions
            case .premiumStickers:
                return .premiumStickers
            case .advancedChatManagement:
                return .advancedChatManagement
            case .profileBadge:
                return .profileBadge
            case .animatedUserpics:
                return .animatedUserpics
            case .appIcons:
                return .appIcons
            case .animatedEmoji:
                return .animatedEmoji
            case .emojiStatus:
                return .emojiStatus
            case .translation:
                return .translation
            case .stories:
                return .stories
            case .colors:
                return .colors
            case .wallpapers:
                return .wallpapers
            case .messageTags:
                return .messageTags
            case .lastSeen:
                return .lastSeen
            case .messagePrivacy:
                return .messagePrivacy
            case .business:
                return .business
            case .folderTags:
                return .folderTags
            case .messageEffects:
                return .messageEffects
            case .todo:
                return .todo
            case .businessLocation:
                return .businessLocation
            case .businessHours:
                return .businessHours
            case .businessGreetingMessage:
                return .businessGreetingMessage
            case .businessQuickReplies:
                return .businessQuickReplies
            case .businessAwayMessage:
                return .businessAwayMessage
            case .businessChatBots:
                return .businessChatBots
            case .businessIntro:
                return .businessIntro
            case .businessLinks:
                return .businessLinks
            }
        }
    }
    
    public enum Source: Equatable {
        case intro(String?)
        case gift(String?)
        case other
    }
    
    public var disposed: () -> Void = {}
    
    private var didSetReady = false
    private let _ready = Promise<Bool>()
    public override var ready: Promise<Bool> {
        return self._ready
    }
        
    public init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source = .other, forceDark: Bool = false, action: @escaping () -> Void) {
        super.init(context: context, component: DemoSheetComponent(context: context, subject: subject, source: source, action: action), navigationBarAppearance: .none, theme: forceDark ? .dark : .default)
        
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
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
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
