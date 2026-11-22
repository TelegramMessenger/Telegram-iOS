import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import ComponentFlow
import ViewControllerComponent
import ResizableSheetComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import GlassBarButtonComponent

private let premiumLimitsGradientColors: [UIColor] = [
    UIColor(rgb: 0x0077ff),
    UIColor(rgb: 0x6b93ff),
    UIColor(rgb: 0x8878ff),
    UIColor(rgb: 0xe46ace)
]

private let premiumLimitsDemoTextHeight: CGFloat = 106.0

private func isPremiumListSubject(_ subject: PremiumDemoScreen.Subject) -> Bool {
    switch subject {
    case .doubleLimits, .stories, .business:
        return true
    default:
        return false
    }
}

private final class PremiumLimitsSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let subject: PremiumDemoScreen.Subject
    let source: PremiumDemoScreen.Source
    let order: [PremiumPerk]?
    let buttonText: String
    let isPremium: Bool

    init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source, order: [PremiumPerk]?, buttonText: String, isPremium: Bool) {
        self.context = context
        self.subject = subject
        self.source = source
        self.order = order
        self.buttonText = buttonText
        self.isPremium = isPremium
    }

    static func ==(lhs: PremiumLimitsSheetComponent, rhs: PremiumLimitsSheetComponent) -> Bool {
        return lhs.context === rhs.context && lhs.subject == rhs.subject && lhs.source == rhs.source && lhs.order == rhs.order && lhs.buttonText == rhs.buttonText && lhs.isPremium == rhs.isPremium
    }

    final class State: ComponentState {
        var stickers: [TelegramMediaFile]?
        var appIcons: [PresentationAppIcon]?
        var isPremium: Bool?
        var promoConfiguration: PremiumPromoConfiguration?
        var version = 0
        private var disposable: Disposable?

        init(context: AccountContext) {
            super.init()
            let accountSpecificStickerOverrides: [ExperimentalUISettings.AccountReactionOverrides.Item]
            if context.sharedContext.immediateExperimentalUISettings.enableReactionOverrides, let value = context.sharedContext.immediateExperimentalUISettings.accountStickerEffectOverrides.first(where: { $0.accountId == context.account.id.int64 }) {
                accountSpecificStickerOverrides = value.items
            } else {
                accountSpecificStickerOverrides = []
            }
            let stickerOverrideMessages = context.engine.data.get(
                EngineDataMap(accountSpecificStickerOverrides.map(\.messageId).map(TelegramEngine.EngineData.Item.Messages.Message.init))
            )
            
            self.appIcons = context.sharedContext.applicationBindings.getAvailableAlternateIcons()
            
            self.disposable = (combineLatest(
                queue: Queue.mainQueue(),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudPremiumStickers))
                |> take(1),
                context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                    TelegramEngine.EngineData.Item.Configuration.PremiumPromo()
                ),
                stickerOverrideMessages
            )
            |> map { items, data, stickerOverrideMessages -> ([TelegramMediaFile], Bool?, PremiumPromoConfiguration?) in
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
                
                var result: [TelegramMediaFile.Accessor] = []
                for item in items {
                    if let mediaItem = item.contents.get(RecentMediaItem.self) {
                        result.append(mediaItem.media)
                    }
                }
                return (result.map { file -> TelegramMediaFile in
                    let file = file._parse()
                    if let displayText = TelegramMediaFile.Accessor(file).stickerDisplayText {
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
                    }
                    return file
                }, data.0?.isPremium ?? false, data.1)
            }).start(next: { [weak self] stickers, isPremium, promoConfiguration in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.stickers = stickers
                strongSelf.isPremium = isPremium
                strongSelf.promoConfiguration = promoConfiguration
                strongSelf.version += 1
                strongSelf.updated(transition: ComponentTransition.immediate.withUserData(DemoAnimateInTransition()))
            })
        }

        deinit {
            self.disposable?.dispose()
        }
    }

    func makeState() -> State {
        return State(context: self.context)
    }

    final class View: UIView {
        private final class WeakScrollView {
            weak var value: UIScrollView?

            init(_ value: UIScrollView) {
                self.value = value
            }
        }

        private let sheet = ComponentView<(EnvironmentType, ResizableSheetComponentEnvironment)>()
        private let externalState = ResizableSheetComponent<EnvironmentType>.ExternalState()
        private let animateOut = ActionSlot<Action<()>>()
        private let nextAction = ActionSlot<Void>()
        private let pageAction = ActionSlot<Int>()
        private var subjects: [PremiumDemoScreen.Subject] = []
        private var position: CGFloat = 0.0
        private var scrollViews: [PremiumDemoScreen.Subject: WeakScrollView] = [:]
        private var pagingExpansion: CGFloat?
        private weak var state: State?
        private var updateScheduled = false

        private var sheetView: ResizableSheetComponent<EnvironmentType>.View? {
            return self.sheet.view as? ResizableSheetComponent<EnvironmentType>.View
        }

        private var currentSubject: PremiumDemoScreen.Subject? {
            guard !self.subjects.isEmpty else {
                return nil
            }
            return self.subjects[min(self.subjects.count - 1, max(0, Int(round(self.position * CGFloat(self.subjects.count - 1)))))]
        }

        private var listFraction: CGFloat {
            guard !self.subjects.isEmpty else {
                return 0.0
            }
            let index = self.position * CGFloat(self.subjects.count - 1)
            var result: CGFloat = 0.0
            for (i, subject) in self.subjects.enumerated() where isPremiumListSubject(subject) {
                result += max(0.0, 1.0 - abs(CGFloat(i) - index))
            }
            return min(1.0, result)
        }

        private func scheduleUpdate() {
            guard !self.updateScheduled else {
                return
            }
            self.updateScheduled = true
            Queue.mainQueue().justDispatch { [weak self] in
                guard let self else {
                    return
                }
                self.updateScheduled = false
                self.state?.updated(transition: .immediate)
            }
        }

        private func updateTrackedScrollView() {
            self.externalState.setTrackedScrollView(self.currentSubject.flatMap { self.scrollViews[$0]?.value })
        }

        private func pagerUpdated(position: CGFloat, subjects: [PremiumDemoScreen.Subject]) {
            let changed = self.position != position || self.subjects != subjects
            self.position = position
            self.subjects = subjects
            if let pagingExpansion = self.pagingExpansion {
                self.sheetView?.setExpansionFraction(pagingExpansion * self.listFraction, transition: .immediate)
            }
            self.updateTrackedScrollView()
            if changed {
                self.scheduleUpdate()
            }
        }

        private func pagingInteractionUpdated(_ isInteracting: Bool) {
            if isInteracting {
                self.pagingExpansion = self.sheetView?.expansionFraction ?? 0.0
            } else {
                if let pagingExpansion = self.pagingExpansion {
                    self.sheetView?.setExpansionFraction(pagingExpansion * self.listFraction, transition: .immediate)
                }
                self.pagingExpansion = nil
                self.updateTrackedScrollView()
            }
            self.scheduleUpdate()
        }

        func update(component: PremiumLimitsSheetComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.state = state
            let environment = environment[EnvironmentType.self].value
            let theme = environment.theme
            let controller = environment.controller
            let dismiss: (Bool) -> Void = { animated in
                controller()?.dismiss(animated: animated)
            }

            let centeredSize: CGSize?
            if environment.presentsFloatingPanels {
                let maxSide = max(availableSize.width, availableSize.height)
                let minSide = min(availableSize.width, availableSize.height)
                centeredSize = CGSize(width: min(availableSize.width - 20.0, floor(maxSide / 2.0)), height: max(0.0, min(availableSize.height, minSide) - 88.0))
            } else {
                centeredSize = nil
            }
            let placement = resizableSheetHorizontalPlacement(containerSize: availableSize, safeInsets: environment.safeInsets, maxWidth: environment.metrics.widthClass == .regular ? 414.0 : nil)
            let contentWidth = centeredSize?.width ?? placement.width
            var footerSideInsets = UIEdgeInsets.zero
            if centeredSize == nil, environment.reservedCorners != .none {
                // Keep the button and its indicator clear of bottom corners, relative to the sheet's band.
                let bottomEdgeInsets = environment.bottomEdgeSideInsets()
                footerSideInsets.left = max(0.0, bottomEdgeInsets.left - placement.minX)
                footerSideInsets.right = max(0.0, bottomEdgeInsets.right - (availableSize.width - placement.minX - placement.width))
            }
            let contentHeight = centeredSize?.height ?? max(0.0, availableSize.height - environment.statusBarHeight - 10.0)
            let pageCount = self.subjects.isEmpty ? (component.source == .other ? 1 : max(1, component.order?.count ?? 1)) : self.subjects.count
            let bottomInsets = ContainerViewLayout.concentricInsets(bottomInset: centeredSize == nil ? environment.safeInsets.bottom : 0.0, innerDiameter: 52.0, sideInset: 30.0)
            let bottomInset = PremiumLimitsFooterComponent.height(pageCount: pageCount) + bottomInsets.bottom + 20.0
            let defaultHeight = min(contentHeight, contentWidth + premiumLimitsDemoTextHeight + bottomInset)
            let listFraction = self.subjects.isEmpty ? (isPremiumListSubject(component.subject) ? 1.0 : 0.0) : self.listFraction

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent(PremiumLimitsContentComponent(
                        context: component.context,
                        subject: component.subject,
                        source: component.source,
                        order: component.order,
                        data: state,
                        dataVersion: state.version,
                        contentHeight: contentHeight,
                        demoHeight: defaultHeight,
                        bottomInset: bottomInset,
                        nextAction: self.nextAction,
                        pageAction: self.pageAction,
                        updated: { [weak self] position, subjects in
                            self?.pagerUpdated(position: position, subjects: subjects)
                        },
                        interactionUpdated: { [weak self] isInteracting in
                            self?.pagingInteractionUpdated(isInteracting)
                        },
                        scrollViewUpdated: { [weak self] subject, scrollView in
                            guard let self else {
                                return
                            }
                            if self.scrollViews[subject]?.value !== scrollView {
                                self.scrollViews[subject] = WeakScrollView(scrollView)
                                self.updateTrackedScrollView()
                            }
                        }
                    )),
                    leftItem: AnyComponent(GlassBarButtonComponent(
                        size: CGSize(width: 44.0, height: 44.0),
                        backgroundColor: listFraction == 1.0 ? nil : UIColor(rgb: 0x7f76f4).withAlphaComponent(1.0 - listFraction),
                        isDark: listFraction > 0.5 && theme.overallDarkAppearance,
                        state: listFraction == 1.0 ? .glass : .tintedGlass,
                        component: AnyComponentWithIdentity(id: "close", component: AnyComponent(BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: UIColor.white.mixedWith(theme.chat.inputPanel.panelControlColor, alpha: listFraction)
                        ))),
                        action: { _ in dismiss(true) }
                    )),
                    hasTopEdgeEffect: false,
                    bottomItem: AnyComponent(PremiumLimitsFooterComponent(
                        theme: theme,
                        title: component.buttonText,
                        isShimmering: !component.isPremium,
                        pageCount: pageCount,
                        position: self.position,
                        sideInsets: footerSideInsets,
                        pageAccessibilityLabel: environment.strings.VoiceOver_Common_Page,
                        pageAccessibilityValue: { [strings = environment.strings] index, count in
                            return strings.Items_NOfM("\(index)", "\(count)").string
                        },
                        showPage: { [weak self] index in
                            self?.pageAction.invoke(index)
                        },
                        action: { (controller() as? PremiumLimitsListScreen)?.action() }
                    )),
                    bottomEdgeEffectExtension: pageCount > 1 ? 24.0 : 0.0,
                    backgroundColor: .color(theme.overallDarkAppearance ? theme.list.blocksBackgroundColor : theme.list.plainBackgroundColor),
                    clipsContent: true,
                    allowsExpansion: self.pagingExpansion != nil || isPremiumListSubject(self.currentSubject ?? component.subject),
                    centeredSize: centeredSize,
                    defaultHeight: defaultHeight,
                    externalState: self.externalState,
                    animateOut: self.animateOut
                )),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: environment.inputHeight,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.isVisible,
                        isCentered: centeredSize != nil,
                        screenSize: availableSize,
                        regularMetricsSize: centeredSize,
                        dismiss: dismiss
                    )
                },
                containerSize: availableSize
            )
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
            }
            self.updateTrackedScrollView()
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private struct PremiumLimitsContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let subject: PremiumDemoScreen.Subject
    let source: PremiumDemoScreen.Source
    let order: [PremiumPerk]?
    let data: PremiumLimitsSheetComponent.State
    let dataVersion: Int
    let contentHeight: CGFloat
    let demoHeight: CGFloat
    let bottomInset: CGFloat
    let nextAction: ActionSlot<Void>
    let pageAction: ActionSlot<Int>
    let updated: (CGFloat, [PremiumDemoScreen.Subject]) -> Void
    let interactionUpdated: (Bool) -> Void
    let scrollViewUpdated: (PremiumDemoScreen.Subject, UIScrollView) -> Void

    static func ==(lhs: PremiumLimitsContentComponent, rhs: PremiumLimitsContentComponent) -> Bool {
        return lhs.context === rhs.context && lhs.subject == rhs.subject && lhs.source == rhs.source && lhs.order == rhs.order && lhs.dataVersion == rhs.dataVersion && lhs.contentHeight == rhs.contentHeight && lhs.demoHeight == rhs.demoHeight && lhs.bottomInset == rhs.bottomInset
    }

    final class View: UIView {
        private let background = ComponentView<Empty>()
        private let pager = ComponentView<Empty>()
        fileprivate var component: PremiumLimitsContentComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if recognizer.state == .ended {
                self.component?.nextAction.invoke(Void())
            }
        }

        func update(component: PremiumLimitsContentComponent, availableSize: CGSize, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            let environment = environment[EnvironmentType.self].value
            let contentSize = CGSize(width: availableSize.width, height: component.contentHeight)
            let mediaSide = max(0.0, min(contentSize.width, component.demoHeight - component.bottomInset - premiumLimitsDemoTextHeight))
            let mediaSize = CGSize(width: mediaSide, height: mediaSide)
            let theme = environment.theme
            let strings = environment.strings
            let context = component.context
            let textColor = theme.actionSheet.primaryTextColor
            let isStandalone = component.source == .other
            let videos = component.data.promoConfiguration?.videos ?? [:]
            let stickers = component.data.stickers ?? []
            let appIcons = component.data.appIcons ?? []

            let backgroundSize = self.background.update(
                transition: transition,
                component: AnyComponent(PremiumGradientBackgroundComponent(colors: premiumLimitsGradientColors, cornerRadius: 0.0)),
                environment: {},
                containerSize: CGSize(width: contentSize.width, height: mediaSide)
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: .zero, size: backgroundSize))
            }

            let isReady: Bool
            switch component.subject {
            case .doubleLimits, .stories, .business:
                isReady = true
            case .premiumStickers:
                isReady = !stickers.isEmpty
            case .appIcons:
                isReady = !appIcons.isEmpty
            default:
                isReady = !videos.isEmpty
            }
            guard isReady else {
                return contentSize
            }

            var availableItems: [PremiumPerk: DemoPagerComponent.Item] = [:]
            availableItems[.doubleLimits] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.doubleLimits,
                    component: AnyComponent(LimitsPageComponent(
                        context: context,
                        theme: theme,
                        bottomInset: component.bottomInset,
                        scrollViewUpdated: { scrollView in
                            component.scrollViewUpdated(.doubleLimits, scrollView)
                        }
                    ))
                )
            )

            availableItems[.stories] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.stories,
                    component: AnyComponent(StoriesPageComponent(
                        context: context,
                        theme: theme,
                        bottomInset: component.bottomInset,
                        scrollViewUpdated: { scrollView in
                            component.scrollViewUpdated(.stories, scrollView)
                        }
                    ))
                )
            )

            availableItems[.moreUpload] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.moreUpload,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .bottom,
                                videoFile: videos["more_upload"],
                                decoration: .dataRain
                            )),
                            title: strings.Premium_UploadSize,
                            text: strings.Premium_UploadSizeInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                videoFile: videos["faster_download"],
                                decoration: .fasterStars
                            )),
                            title: strings.Premium_FasterSpeed,
                            text: strings.Premium_FasterSpeedInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                videoFile: videos["voice_to_text"],
                                decoration: .badgeStars
                            )),
                            title: strings.Premium_VoiceToText,
                            text: strings.Premium_VoiceToTextInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .bottom,
                                videoFile: videos["no_ads"],
                                decoration: .swirlStars
                            )),
                            title: strings.Premium_NoAds,
                            text: isStandalone ? strings.Premium_NoAdsStandaloneInfo : strings.Premium_NoAdsInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                videoFile: videos["infinite_reactions"],
                                decoration: .swirlStars
                            )),
                            title: strings.Premium_InfiniteReactions,
                            text: strings.Premium_InfiniteReactionsInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                    context: context,
                                    stickers: stickers,
                                    tapAction: { [weak self] in
                                        self?.component?.nextAction.invoke(Void())
                                    }
                                )
                            ),
                            title: strings.Premium_Stickers,
                            text: strings.Premium_StickersInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                videoFile: videos["emoji_status"],
                                decoration: .badgeStars
                            )),
                            title: strings.Premium_EmojiStatus,
                            text: strings.Premium_EmojiStatusInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                videoFile: videos["advanced_chat_management"],
                                decoration: .swirlStars
                            )),
                            title: strings.Premium_ChatManagement,
                            text: strings.Premium_ChatManagementInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                videoFile: videos["profile_badge"],
                                decoration: .badgeStars
                            )),
                            title: strings.Premium_Badge,
                            text: strings.Premium_BadgeInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                videoFile: videos["animated_userpics"],
                                decoration: .swirlStars
                            )),
                            title: strings.Premium_Avatar,
                            text: strings.Premium_AvatarInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                appIcons: appIcons
                            )),
                            title: isStandalone ? strings.Premium_AppIconStandalone : strings.Premium_AppIcon,
                            text: isStandalone ? strings.Premium_AppIconStandaloneInfo :strings.Premium_AppIconInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .bottom,
                                videoFile: videos["animated_emoji"],
                                decoration: .emoji
                            )),
                            title: strings.Premium_AnimatedEmoji,
                            text: isStandalone ? strings.Premium_AnimatedEmojiStandaloneInfo : strings.Premium_AnimatedEmojiInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["translations"],
                                decoration: .hello
                            )),
                            title: strings.Premium_Translation,
                            text: isStandalone ? strings.Premium_TranslationStandaloneInfo : strings.Premium_TranslationInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                videoFile: videos["peer_colors"],
                                decoration: .badgeStars
                            )),
                            title: strings.Premium_Colors,
                            text: strings.Premium_ColorsInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["wallpapers"],
                                decoration: .swirlStars
                            )),
                            title: strings.Premium_Wallpapers,
                            text: strings.Premium_WallpapersInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["saved_tags"],
                                decoration: .tag
                            )),
                            title: strings.Premium_MessageTags,
                            text: strings.Premium_MessageTagsInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["last_seen"],
                                decoration: .badgeStars
                            )),
                            title: strings.Premium_LastSeen,
                            text: strings.Premium_LastSeenInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["message_privacy"],
                                decoration: .swirlStars
                            )),
                            title: strings.Premium_MessagePrivacy,
                            text: strings.Premium_MessagePrivacyInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["effects"],
                                decoration: .swirlStars
                            )),
                            title: strings.Premium_MessageEffects,
                            text: strings.Premium_MessageEffectsInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
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
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["todo"],
                                decoration: .todo
                            )),
                            title: strings.Premium_Todo,
                            text: strings.Premium_TodoInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.copyProtection] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.copyProtection,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["pm_noforwards"],
                                decoration: .badgeStars
                            )),
                            title: strings.Premium_CopyProtection,
                            text: strings.Premium_CopyProtectionInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.aiTools] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.aiTools,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["ai_compose"],
                                decoration: .badgeStars
                            )),
                            title: strings.Premium_AiTools,
                            text: strings.Premium_AiToolsInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.richText] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.richText,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["rich_formatting"],
                                decoration: .badgeStars
                            )),
                            title: strings.Premium_RichText,
                            text: strings.Premium_RichTextInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.business] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.business,
                    component: AnyComponent(BusinessPageComponent(
                        context: context,
                        theme: theme,
                        bottomInset: component.bottomInset,
                        scrollViewUpdated: { scrollView in
                            component.scrollViewUpdated(.business, scrollView)
                        }
                    ))
                )
            )

            availableItems[.businessLocation] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.businessLocation,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["business_location"],
                                decoration: .business
                            )),
                            title: strings.Business_Location,
                            text: strings.Business_LocationInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.businessHours] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.businessHours,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["business_hours"],
                                decoration: .business
                            )),
                            title: strings.Business_OpeningHours,
                            text: strings.Business_OpeningHoursInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.businessQuickReplies] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.businessQuickReplies,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["quick_replies"],
                                decoration: .business
                            )),
                            title: strings.Business_QuickReplies,
                            text: strings.Business_QuickRepliesInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.businessGreetingMessage] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.businessGreetingMessage,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["greeting_message"],
                                decoration: .business
                            )),
                            title: strings.Business_GreetingMessages,
                            text: strings.Business_GreetingMessagesInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.businessAwayMessage] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.businessAwayMessage,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["away_message"],
                                decoration: .business
                            )),
                            title: strings.Business_AwayMessages,
                            text: strings.Business_AwayMessagesInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.businessChatBots] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.businessChatBots,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["business_bots"],
                                decoration: .business
                            )),
                            title: strings.Business_ChatbotsItem,
                            text: strings.Business_ChatbotsInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.businessIntro] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.businessIntro,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["business_intro"],
                                decoration: .business
                            )),
                            title: strings.Business_Intro,
                            text: strings.Business_IntroInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )

            availableItems[.businessLinks] = DemoPagerComponent.Item(
                AnyComponentWithIdentity(
                    id: PremiumDemoScreen.Subject.businessLinks,
                    component: AnyComponent(
                        PageComponent(
                            content: AnyComponent(PhoneDemoComponent(
                                context: context,
                                position: .top,
                                model: .island,
                                videoFile: videos["business_links"],
                                decoration: .business
                            )),
                            title: strings.Business_Links,
                            text: strings.Business_LinksInfo,
                            textColor: textColor,
                            mediaSize: mediaSize
                        )
                    )
                )
            )


            let items: [DemoPagerComponent.Item]
            if case .other = component.source {
                items = availableItems[component.subject.perk].map { [$0] } ?? []
            } else {
                items = (component.order ?? [component.subject.perk]).compactMap { availableItems[$0] }
            }
            let subjects = items.compactMap { $0.content.id.base as? PremiumDemoScreen.Subject }
            let initialIndex = subjects.firstIndex(of: component.subject) ?? 0
            let pagerSize = self.pager.update(
                transition: transition,
                component: AnyComponent(DemoPagerComponent(
                    items: items,
                    index: initialIndex,
                    nextAction: component.nextAction,
                    pageAction: component.pageAction,
                    cornerRadius: 0.0,
                    interactionUpdated: component.interactionUpdated,
                    updated: { position, _ in
                        component.updated(position, subjects)
                    }
                )),
                environment: {},
                containerSize: contentSize
            )
            if let pagerView = self.pager.view {
                if pagerView.superview == nil {
                    self.addSubview(pagerView)
                }
                transition.setFrame(view: pagerView, frame: CGRect(origin: .zero, size: pagerSize))
            }
            return contentSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private struct PremiumLimitsFooterComponent: CombinedComponent {
    let theme: PresentationTheme
    let title: String
    let isShimmering: Bool
    let pageCount: Int
    let position: CGFloat
    let sideInsets: UIEdgeInsets
    let pageAccessibilityLabel: String
    let pageAccessibilityValue: (Int, Int) -> String
    let showPage: (Int) -> Void
    let action: () -> Void

    static func ==(lhs: PremiumLimitsFooterComponent, rhs: PremiumLimitsFooterComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.title == rhs.title && lhs.isShimmering == rhs.isShimmering && lhs.pageCount == rhs.pageCount && lhs.position == rhs.position && lhs.sideInsets == rhs.sideInsets && lhs.pageAccessibilityLabel == rhs.pageAccessibilityLabel
    }

    static func height(pageCount: Int) -> CGFloat {
        return 52.0 + (pageCount > 1 ? 28.0 : 0.0)
    }

    static var body: Body {
        let button = Child(ButtonComponent.self)
        let indicator = Child(PageIndicatorComponent.self)

        return { context in
            let component = context.component
            let contentWidth = max(0.0, context.availableSize.width - component.sideInsets.left - component.sideInsets.right)
            let centerX = component.sideInsets.left + contentWidth * 0.5
            if component.pageCount > 1 {
                let indicator = indicator.update(
                    component: PageIndicatorComponent(pageCount: component.pageCount, position: component.position, inactiveColor: component.theme.list.disclosureArrowColor, activeColor: UIColor(rgb: 0x7169ff), accessibilityLabel: component.pageAccessibilityLabel, accessibilityValue: component.pageAccessibilityValue, showPage: component.showPage),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                context.add(indicator.position(CGPoint(x: centerX, y: indicator.size.height * 0.5)))
            }
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: premiumLimitsGradientColors[0],
                        foreground: .white,
                        pressedColor: premiumLimitsGradientColors[0],
                        isShimmering: component.isShimmering,
                        gradient: ButtonComponent.Background.Gradient(colors: premiumLimitsGradientColors, animation: .horizontalShift(duration: 4.5))
                    ),
                    content: AnyComponentWithIdentity(id: component.title, component: AnyComponent(ButtonTextContentComponent(text: component.title, badge: 0, textColor: .white, badgeBackground: .white, badgeForeground: premiumLimitsGradientColors[0]))),
                    action: component.action
                ),
                availableSize: CGSize(width: contentWidth, height: 52.0),
                transition: context.transition
            )
            let height = Self.height(pageCount: component.pageCount)
            context.add(button.position(CGPoint(x: centerX, y: height - button.size.height * 0.5)))
            return CGSize(width: context.availableSize.width, height: height)
        }
    }
}

public class PremiumLimitsListScreen: ViewControllerComponentContainer {
    public var action: () -> Void = {}
    public var disposed: () -> Void = {}
    private var isDismissing = false

    public init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source, order: [PremiumPerk]?, buttonText: String, isPremium: Bool, forceDark: Bool = false) {
        super.init(context: context, component: PremiumLimitsSheetComponent(context: context, subject: subject, source: source, order: order, buttonText: buttonText, isPremium: isPremium), navigationBarAppearance: .none, statusBarStyle: .ignore, presentationMode: .modal, theme: forceDark ? .dark : .default)
        self.navigationPresentation = .flatModal
        // VoiceOver reads only the sheet while it shows (it is presented over the screen that opened it).
        self.blocksBackgroundWhenInOverlay = true
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
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

    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard !self.isDismissing else {
            return
        }
        self.isDismissing = true
        self.view.endEditing(true)
        if flag, let sheetView = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            sheetView.animateOut(completion: { [weak self] in
                self?.completeDismiss(completion: completion)
            })
        } else {
            self.completeDismiss(completion: completion)
        }
    }

    private func completeDismiss(completion: (() -> Void)?) {
        super.dismiss(animated: false, completion: completion)
    }
}
