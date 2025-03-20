import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import Markdown
import SolidRoundedButtonNode
import BlurredBackgroundComponent

public class PremiumLimitsListScreen: ViewController {
    final class Node: ViewControllerTracingNode, ASScrollViewDelegate, ASGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: PremiumLimitsListScreen?
                
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        
        let backgroundView: ComponentHostView<Empty>
        let pagerView: ComponentHostView<Empty>
        let closeView: ComponentHostView<Empty>
        let closeDarkIconView = UIImageView()
        
        fileprivate let footerNode: FooterNode
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: ContainerViewLayout?
                
        var isPremium: Bool?
        var reactions: [AvailableReactions.Reaction]?
        var stickers: [TelegramMediaFile]?
        var appIcons: [PresentationAppIcon]?
        var disposable: Disposable?
        var promoConfiguration: PremiumPromoConfiguration?
        
        let nextAction = ActionSlot<Void>()
        
        init(context: AccountContext, controller: PremiumLimitsListScreen, buttonTitle: String, gloss: Bool, forceDark: Bool) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if forceDark {
                self.presentationData = self.presentationData.withUpdated(theme: defaultDarkPresentationTheme)
            }
            self.presentationData = self.presentationData.withUpdated(theme: self.presentationData.theme.withModalBlocksBackground())
            
            self.controller = controller
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.backgroundView = ComponentHostView()
            self.pagerView = ComponentHostView()
            self.closeView = ComponentHostView()
            
            self.footerNode = FooterNode(theme: self.presentationData.theme, title: buttonTitle, gloss: gloss, order: controller.order)
            
            super.init()
                        
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.overallDarkAppearance ? self.presentationData.theme.list.blocksBackgroundColor : self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.backgroundView)
            self.containerView.addSubview(self.pagerView)
            self.containerView.addSubnode(self.footerNode)
            self.containerView.addSubview(self.closeView)
        
            self.footerNode.action = { [weak self] in
                self?.controller?.action()
            }
            
            let context = controller.context
            
            let accountSpecificStickerOverrides: [ExperimentalUISettings.AccountReactionOverrides.Item]
            if context.sharedContext.immediateExperimentalUISettings.enableReactionOverrides, let value = context.sharedContext.immediateExperimentalUISettings.accountStickerEffectOverrides.first(where: { $0.accountId == context.account.id.int64 }) {
                accountSpecificStickerOverrides = value.items
            } else {
                accountSpecificStickerOverrides = []
            }
            let stickerOverrideMessages = context.engine.data.get(
                EngineDataMap(accountSpecificStickerOverrides.map(\.messageId).map(TelegramEngine.EngineData.Item.Messages.Message.init))
            )
            
            self.appIcons = controller.context.sharedContext.applicationBindings.getAvailableAlternateIcons()
            
            let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudPremiumStickers)
            self.disposable = (combineLatest(
                queue: Queue.mainQueue(),
                context.account.postbox.combinedView(keys: [stickersKey])
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
                if let items = items {
                    for item in items {
                        if let mediaItem = item.contents.get(RecentMediaItem.self) {
                            result.append(mediaItem.media)
                        }
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
                if !stickers.isEmpty {
                    strongSelf.updated(transition: ComponentTransition(.immediate).withUserData(DemoAnimateInTransition()))
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.pagerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.pagerTapGesture(_:))))
            
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        @objc func pagerTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.nextAction.invoke(Void())
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let layout = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                }
            }
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                if let scrollView = otherGestureRecognizer.view as? UIScrollView {
                    if scrollView.contentSize.width > scrollView.contentSize.height || scrollView.contentSize.height > 1500.0 {
                        return false
                    }
                } else if otherGestureRecognizer.view is PremiumCoinComponent.View {
                    return false
                }
                return true
            }
            return false
        }
        
        private var isDismissing = false
        func animateIn() {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.containerView.center
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.containerView.center = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            
            self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
        }
                
        private var dismissOffset: CGFloat?
        func containerLayoutUpdated(layout: ContainerViewLayout, transition: ComponentTransition) {
            self.currentLayout = layout
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset
            let topInset: CGFloat
            if let (panInitialTopInset, panOffset, _, _) = self.panGestureArguments {
                if effectiveExpanded {
                    topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else if let dismissOffset = self.dismissOffset, !dismissOffset.isZero {
                topInset = edgeTopInset * dismissOffset
            } else {
                topInset = effectiveExpanded ? 0.0 : edgeTopInset
            }
            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: nil)
            
            let modalProgress = isLandscape ? 0.0 : (1.0 - topInset / self.defaultTopInset)
            self.controller?.updateModalStyleOverlayTransitionFactor(modalProgress, transition: transition.containedViewLayoutTransition)
            
            let clipFrame: CGRect
            if layout.metrics.widthClass == .compact {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.25)
                if isLandscape {
                    self.containerView.layer.cornerRadius = 0.0
                } else {
                    self.containerView.layer.cornerRadius = 10.0
                }
                
                if #available(iOS 11.0, *) {
                    if layout.safeInsets.bottom.isZero {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    } else {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                }
                
                if isLandscape {
                    clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                } else {
                    let coveredByModalTransition: CGFloat = 0.0
                    var containerTopInset: CGFloat = 10.0
                    if let statusBarHeight = layout.statusBarHeight {
                        containerTopInset += statusBarHeight
                    }
                                        
                    let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: CGSize(width: layout.size.width, height: layout.size.height - containerTopInset))
                    let maxScale: CGFloat = (layout.size.width - 16.0 * 2.0) / layout.size.width
                    let containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                    let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                    let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                    let containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                    
                    clipFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height)
                }
            } else {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.containerView.layer.cornerRadius = 10.0
  
                let verticalInset: CGFloat = 44.0
                
                let maxSide = max(layout.size.width, layout.size.height)
                let minSide = min(layout.size.width, layout.size.height)
                let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
                clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            }
            
            transition.setFrame(view: self.containerView, frame: clipFrame)
            
            var clipLayout = layout.withUpdatedSize(clipFrame.size)
            if case .regular = layout.metrics.widthClass {
                clipLayout = clipLayout.withUpdatedIntrinsicInsets(.zero)
            }
            let footerHeight = self.footerNode.updateLayout(layout: clipLayout, transition: .immediate)
            
            let convertedFooterFrame = self.view.convert(CGRect(origin: CGPoint(x: clipFrame.minX, y: clipFrame.maxY - footerHeight), size: CGSize(width: clipFrame.width, height: footerHeight)), to: self.containerView)
            transition.setFrame(view: self.footerNode.view, frame: convertedFooterFrame)
            
            self.updated(transition: transition)
        }
        
        private var indexPosition: CGFloat?
        func updated(transition: ComponentTransition) {
            guard let controller = self.controller else {
                return
            }
            
            let contentSize = self.containerView.bounds.size
            
            let backgroundSize = self.backgroundView.update(
                transition: .immediate,
                component: AnyComponent(
                    PremiumGradientBackgroundComponent(colors: [
                        UIColor(rgb: 0x0077ff),
                        UIColor(rgb: 0x6b93ff),
                        UIColor(rgb: 0x8878ff),
                        UIColor(rgb: 0xe46ace)
                    ])
                ),
                environment: {},
                containerSize: CGSize(width: contentSize.width, height: contentSize.width)
            )
            self.backgroundView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((contentSize.width - backgroundSize.width) / 2.0), y: 0.0), size: backgroundSize)
            
            var isStandalone = false
            if case .other = controller.source {
                isStandalone = true
            }
            
            let theme = self.presentationData.theme
            let strings = self.presentationData.strings
            
            let videos: [String: TelegramMediaFile] = self.promoConfiguration?.videos ?? [:]
            let stickers = self.stickers ?? []
            let appIcons = self.appIcons ?? []
            
            let isReady: Bool
            switch controller.subject {
            case .premiumStickers:
                isReady = !stickers.isEmpty
            case .appIcons:
                isReady = !appIcons.isEmpty
            case .stories:
                isReady = true
            case .doubleLimits:
                isReady = true
            case .business:
                isReady = true
            default:
                isReady = !videos.isEmpty
            }
            
            if isReady {
                let context = controller.context
                    
                let textColor = theme.actionSheet.primaryTextColor
                
                var availableItems: [PremiumPerk: DemoPagerComponent.Item] = [:]
                
                var storiesIndex: Int?
                var limitsIndex: Int?
                var businessIndex: Int?
                var storiesNeighbors = PageNeighbors(leftIsList: false, rightIsList: false)
                var limitsNeighbors = PageNeighbors(leftIsList: false, rightIsList: false)
                let businessNeighbors = PageNeighbors(leftIsList: false, rightIsList: false)
                if let order = controller.order {
                    storiesIndex = order.firstIndex(where: { $0 == .stories })
                    limitsIndex = order.firstIndex(where: { $0 == .doubleLimits })
                    businessIndex = order.firstIndex(where: { $0 == .business })
                    if let limitsIndex, let storiesIndex {
                        if limitsIndex == storiesIndex + 1 {
                            storiesNeighbors.rightIsList = true
                            limitsNeighbors.leftIsList = true
                        } else if limitsIndex == storiesIndex - 1 {
                            limitsNeighbors.rightIsList = true
                            storiesNeighbors.leftIsList = true
                        }
                    }
                }
                
                availableItems[.doubleLimits] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.doubleLimits,
                        component: AnyComponent(
                            LimitsPageComponent(
                                context: context,
                                theme: self.presentationData.theme,
                                neighbors: limitsNeighbors,
                                bottomInset: self.footerNode.frame.height,
                                updatedBottomAlpha: { [weak self] alpha in
                                    if let strongSelf = self {
                                        strongSelf.footerNode.updateCoverAlpha(alpha, transition: .immediate)
                                    }
                                },
                                updatedDismissOffset: { [weak self] offset in
                                    if let strongSelf = self {
                                        strongSelf.updateDismissOffset(offset)
                                    }
                                },
                                updatedIsDisplaying: { [weak self] isDisplaying in
                                    if let self, self.isExpanded && !isDisplaying {
                                        if let storiesIndex, let indexPosition = self.indexPosition, abs(CGFloat(storiesIndex) - indexPosition) < 0.1 {
                                        } else {
                                            self.update(isExpanded: false, transition: .animated(duration: 0.2, curve: .easeInOut))
                                        }
                                    }
                                }
                            )
                        )
                    )
                )
                availableItems[.stories] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.stories,
                        component: AnyComponent(
                            StoriesPageComponent(
                                context: context,
                                theme: self.presentationData.theme,
                                neighbors: storiesNeighbors,
                                bottomInset: self.footerNode.frame.height,
                                updatedBottomAlpha: { [weak self] alpha in
                                    if let strongSelf = self {
                                        strongSelf.footerNode.updateCoverAlpha(alpha, transition: .immediate)
                                    }
                                },
                                updatedDismissOffset: { [weak self] offset in
                                    if let strongSelf = self {
                                        strongSelf.updateDismissOffset(offset)
                                    }
                                },
                                updatedIsDisplaying: { [weak self] isDisplaying in
                                    if let self, self.isExpanded && !isDisplaying {
                                        if let limitsIndex, let indexPosition = self.indexPosition, abs(CGFloat(limitsIndex) - indexPosition) < 0.1 {
                                        } else {
                                            self.update(isExpanded: false, transition: .animated(duration: 0.2, curve: .easeInOut))
                                        }
                                    }
                                }
                            )
                        )
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
                                    context: context,
                                    position: .top,
                                    videoFile: videos["faster_download"],
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
                                    context: context,
                                    position: .top,
                                    videoFile: videos["voice_to_text"],
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
                                    context: context,
                                    position: .bottom,
                                    videoFile: videos["no_ads"],
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
                                    context: context,
                                    position: .top,
                                    videoFile: videos["infinite_reactions"],
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
                                        context: context,
                                        stickers: stickers,
                                        tapAction: { [weak self] in
                                            self?.nextAction.invoke(Void())
                                        }
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
                                    context: context,
                                    position: .top,
                                    videoFile: videos["emoji_status"],
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
                                    context: context,
                                    position: .top,
                                    videoFile: videos["advanced_chat_management"],
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
                                    context: context,
                                    position: .top,
                                    videoFile: videos["profile_badge"],
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
                                    context: context,
                                    position: .top,
                                    videoFile: videos["animated_userpics"],
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
                                    context: context,
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
                                    context: context,
                                    position: .bottom,
                                    videoFile: videos["animated_emoji"],
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
                                    context: context,
                                    position: .top,
                                    model: .island,
                                    videoFile: videos["translations"],
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
                                    context: context,
                                    position: .top,
                                    videoFile: videos["peer_colors"],
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
                                    context: context,
                                    position: .top,
                                    model: .island,
                                    videoFile: videos["wallpapers"],
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
                                    context: context,
                                    position: .top,
                                    model: .island,
                                    videoFile: videos["saved_tags"],
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
                                    context: context,
                                    position: .top,
                                    model: .island,
                                    videoFile: videos["last_seen"],
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
                                    context: context,
                                    position: .top,
                                    model: .island,
                                    videoFile: videos["message_privacy"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_MessagePrivacy,
                                text: strings.Premium_MessagePrivacyInfo,
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
                                    context: context,
                                    position: .top,
                                    model: .island,
                                    videoFile: videos["effects"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_MessageEffects,
                                text: strings.Premium_MessageEffectsInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.paidMessages] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.paidMessages,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .top,
                                    videoFile: videos["paid_messages"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_PaidMessages,
                                text: strings.Premium_PaidMessagesInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.business] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.business,
                        component: AnyComponent(
                            BusinessPageComponent(
                                context: context,
                                theme: self.presentationData.theme,
                                neighbors: businessNeighbors,
                                bottomInset: self.footerNode.frame.height,
                                updatedBottomAlpha: { [weak self] alpha in
                                    if let strongSelf = self {
                                        strongSelf.footerNode.updateCoverAlpha(alpha, transition: .immediate)
                                    }
                                },
                                updatedDismissOffset: { [weak self] offset in
                                    if let strongSelf = self {
                                        strongSelf.updateDismissOffset(offset)
                                    }
                                },
                                updatedIsDisplaying: { [weak self] isDisplaying in
                                    if let self, self.isExpanded && !isDisplaying {
                                        if let businessIndex, let indexPosition = self.indexPosition, abs(CGFloat(businessIndex) - indexPosition) < 0.1 {
                                        } else {
                                            self.update(isExpanded: false, transition: .animated(duration: 0.2, curve: .easeInOut))
                                        }
                                    }
                                }
                            )
                        )
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
                                textColor: textColor
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
                                textColor: textColor
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
                                textColor: textColor
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
                                textColor: textColor
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
                                textColor: textColor
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
                                textColor: textColor
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
                                textColor: textColor
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
                                textColor: textColor
                            )
                        )
                    )
                )
                
                if let order = controller.order {
                    var items: [DemoPagerComponent.Item] = order.compactMap { availableItems[$0] }
                    let initialIndex: Int
                    switch controller.source {
                    case .intro, .gift:
                        initialIndex = items.firstIndex(where: { (controller.subject as AnyHashable) == $0.content.id }) ?? 0
                    case .other:
                        items = items.filter { item in
                            return item.content.id == (controller.subject as AnyHashable)
                        }
                        initialIndex = 0
                    }
                    
                    let pagerSize = self.pagerView.update(
                        transition: .immediate,
                        component: AnyComponent(
                            DemoPagerComponent(
                                items: items,
                                index: initialIndex,
                                nextAction: nextAction,
                                updated: { [weak self] position, count in
                                    if let self {
                                        let indexPosition = position * CGFloat(count - 1)
                                        self.indexPosition = indexPosition
                                        self.footerNode.updatePosition(position, count: count)
                                        
                                        var distance: CGFloat?
                                        if let storiesIndex {
                                            let value = indexPosition - CGFloat(storiesIndex)
                                            if abs(value) < 1.0 {
                                                distance = value
                                            }
                                        }
                                        if let limitsIndex {
                                            let value = indexPosition - CGFloat(limitsIndex)
                                            if abs(value) < 1.0 {
                                                distance = value
                                            }
                                        }
                                        if let businessIndex {
                                            let value = indexPosition - CGFloat(businessIndex)
                                            if abs(value) < 1.0 {
                                                distance = value
                                            }
                                        }
                                        var distanceToPage: CGFloat = 1.0
                                        if let distance {
                                            if distance >= 0.0 && distance < 0.1 {
                                                distanceToPage = distance / 0.1
                                            } else if distance < 0.0 {
                                                if distance >= -1.0 && distance < -0.9 {
                                                    distanceToPage = ((distance * -1.0) - 0.9) / 0.1
                                                } else {
                                                    distanceToPage = 0.0
                                                }
                                            }
                                        }
                                        self.closeDarkIconView.alpha = 1.0 - max(0.0, min(1.0, distanceToPage))
                                    }
                                }
                            )
                        ),
                        environment: {},
                        containerSize: contentSize
                    )
                    self.pagerView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((contentSize.width - pagerSize.width) / 2.0), y: 0.0), size: pagerSize)
                }
            }
            
            let closeImage: UIImage
            if let image = self.cachedCloseImage {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff))!
                self.cachedCloseImage = closeImage
            }
            
            let closeSize = self.closeView.update(
                transition: .immediate,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(ZStack([
                            AnyComponentWithIdentity(
                                id: "background",
                                component: AnyComponent(
                                    BlurredBackgroundComponent(
                                        color:  UIColor(rgb: 0xbbbbbb, alpha: 0.22)
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
                        action: { [weak self] in
                            self?.controller?.dismiss(animated: true, completion: nil)
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            self.closeView.clipsToBounds = true
            self.closeView.layer.cornerRadius = 15.0
            self.closeView.frame = CGRect(origin: CGPoint(x: contentSize.width - closeSize.width * 1.5, y: 28.0 - closeSize.height / 2.0), size: closeSize)
            
            if self.closeDarkIconView.image == nil {
                self.closeDarkIconView.image = generateCloseButtonImage(backgroundColor: .clear, foregroundColor: theme.list.itemSecondaryTextColor)!
                self.closeDarkIconView.frame = CGRect(origin: .zero, size: closeSize)
                self.closeView.addSubview(self.closeDarkIconView)
            }
        }
        private var cachedCloseImage: UIImage?
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var defaultTopInset: CGFloat {
            guard let layout = self.currentLayout else {
                return 210.0
            }
            if case .compact = layout.metrics.widthClass {
                let bottomPanelPadding: CGFloat = 12.0
                let bottomInset: CGFloat = layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : bottomPanelPadding
                let panelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset + 28.0
                
                var additionalInset: CGFloat = 0.0
                if let order = self.controller?.order, order.count == 1 {
                    additionalInset = 20.0
                }
                
                return layout.size.height - layout.size.width - 181.0 - panelHeight + additionalInset
            } else {
                return 210.0
            }
        }
        
        private func findVerticalScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
            if let view = view {
                if let view = view as? UIScrollView, view.contentSize.height > view.contentSize.width && view.contentSize.height < 1500.0 {
                    return (view, nil)
                }
                if let node = view.asyncdisplaykit_node as? ListView {
                    return (node.scroller, node)
                }
                return findVerticalScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let layout = self.currentLayout else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollViewAndListNode = self.findVerticalScrollView(view: currentHitView)
                    if scrollViewAndListNode?.0.frame.height == self.frame.width {
                        scrollViewAndListNode = nil
                    }
                    let scrollView = scrollViewAndListNode?.0
                    let listNode = scrollViewAndListNode?.1
                                
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else {
                        topInset = edgeTopInset
                    }
                
                    self.panGestureArguments = (topInset, 0.0, scrollView, listNode)
                case .changed:
                    guard let (topInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    var translation = recognizer.translation(in: self.view).y

                    var currentOffset = topInset + translation
                
                    let epsilon = 1.0
                    if case let .known(value) = visibleContentOffset, value <= epsilon {
                        if let scrollView = scrollView {
                            scrollView.bounces = false
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                        }
                    } else if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                    } else if let scrollView = scrollView {
                        translation = panOffset
                        currentOffset = topInset + translation
                        if self.isExpanded {
                            recognizer.setTranslation(CGPoint(), in: self.view)
                        } else if currentOffset > 0.0 {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                    }
                
                    if scrollView == nil {
                        translation = max(0.0, translation)
                    }
                    
                    self.panGestureArguments = (topInset, translation, scrollView, listNode)
                    
                    if !self.isExpanded {
                        if currentOffset > 0.0, let scrollView = scrollView {
                            scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                
                    self.containerLayoutUpdated(layout: layout, transition: .immediate)
                case .ended:
                    guard let (currentTopInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    self.panGestureArguments = nil
                
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    let translation = recognizer.translation(in: self.view).y
                    var velocity = recognizer.velocity(in: self.view)
                    
                    if self.isExpanded {
                        if case let .known(value) = visibleContentOffset, value > 0.1 {
                            velocity = CGPoint()
                        } else if case .unknown = visibleContentOffset {
                            velocity = CGPoint()
                        } else if contentOffset > 0.1 {
                            velocity = CGPoint()
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                
                    scrollView?.bounces = true
                
                    let offset = currentTopInset + panOffset
                    let topInset: CGFloat = edgeTopInset

                    var dismissing = false
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0) {
                        self.controller?.dismiss(animated: true, completion: nil)
                        dismissing = true
                    } else if self.isExpanded {
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            if let listNode = listNode {
                                listNode.scroller.setContentOffset(CGPoint(), animated: false)
                            } else if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if scrollView != nil, (velocity.y < -300.0 || offset < topInset / 2.0) {
                        if velocity.y > -2200.0 && velocity.y < -300.0, let listNode = listNode {
                            DispatchQueue.main.async {
                                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            }
                        }
                                                    
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                    }
                    
                    if !dismissing {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(.animated(duration: 0.3, curve: .easeInOut)))
                default:
                    break
            }
        }
        
        func updateDismissOffset(_ offset: CGFloat) {
            guard self.isExpanded, let layout = self.currentLayout else {
                return
            }
            
            self.dismissOffset = offset
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.dismissOffset = nil
            self.isExpanded = isExpanded
            
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    
    let subject: PremiumDemoScreen.Subject
    let source: PremiumDemoScreen.Source
    let order: [PremiumPerk]?
    
    private var currentLayout: ContainerViewLayout?
        
    private let buttonText: String
    private let buttonGloss: Bool
    private let forceDark: Bool
    
    public var action: () -> Void = {}
    public var disposed: () -> Void = {}
    
    public init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source, order: [PremiumPerk]?, buttonText: String, isPremium: Bool, forceDark: Bool = false) {
        self.context = context
        self.subject = subject
        self.source = source
        self.order = order
        self.buttonText = buttonText
        self.buttonGloss = !isPremium
        self.forceDark = forceDark
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    @objc private func cancelPressed() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, buttonTitle: self.buttonText, gloss: self.buttonGloss, forceDark: self.forceDark)
        self.displayNodeDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if flag {
            self.node.animateOut(completion: {
                super.dismiss(animated: false, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false)
    }
        
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
                
        self.node.containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
    }
}

private class FooterNode: ASDisplayNode {
    private let order: [PremiumPerk]?
    
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let coverNode: ASDisplayNode
    private let buttonNode: SolidRoundedButtonNode
    private let pageIndicatorView: ComponentHostView<Empty>
    
    private var theme: PresentationTheme
    private var validLayout: ContainerViewLayout?
    private var currentParams: (CGFloat, Int)?
    
    var action: () -> Void = {}
        
    init(theme: PresentationTheme, title: String, gloss: Bool, order: [PremiumPerk]?) {
        self.order = order
        self.theme = theme
        
        self.backgroundNode = NavigationBackgroundNode(color: theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), height: 50.0, cornerRadius: 11.0, gloss: gloss)
        self.buttonNode.title = title
        
        self.coverNode = ASDisplayNode()
        self.coverNode.backgroundColor = self.theme.overallDarkAppearance ? self.theme.list.blocksBackgroundColor : self.theme.list.plainBackgroundColor
        
        self.pageIndicatorView = ComponentHostView<Empty>()
        self.pageIndicatorView.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.coverNode)
        self.addSubnode(self.buttonNode)
        
        self.updateTheme(theme)
        
        self.buttonNode.pressed = { [weak self] in
            self?.action()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addSubview(self.pageIndicatorView)
    }
    
    private func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.backgroundNode.updateColor(color: self.theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = self.theme.rootController.tabBar.separatorColor
        
        let backgroundColors = [
            UIColor(rgb: 0x0077ff),
            UIColor(rgb: 0x6b93ff),
            UIColor(rgb: 0x8878ff),
            UIColor(rgb: 0xe46ace)
        ]
        
        self.buttonNode.updateTheme(SolidRoundedButtonTheme(backgroundColor: UIColor(rgb: 0x0077ff), backgroundColors: backgroundColors, foregroundColor: .white), animated: true)
    }
    
    func updateCoverAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.coverNode, alpha: alpha)
    }
    
    func updatePosition(_ position: CGFloat, count: Int) {
        self.currentParams = (position, count)
        if let layout = self.validLayout {
            let _ = self.updateLayout(layout: layout, transition: .immediate)
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        
        let buttonInset: CGFloat = 16.0
        let buttonWidth = layout.size.width - layout.safeInsets.left - layout.safeInsets.right - buttonInset * 2.0
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        let bottomPanelPadding: CGFloat = 12.0
        let bottomInset: CGFloat = layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : bottomPanelPadding
                
        var panelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset + 8.0
        var buttonOffset: CGFloat = 20.0
        if let order, order.count > 1 {
            panelHeight += 20.0
            buttonOffset += 20.0
        }
        
        let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: panelHeight))
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInset, y: buttonOffset), size: CGSize(width: buttonWidth, height: buttonHeight)))
        
        transition.updateFrame(node: self.backgroundNode, frame: panelFrame)
        self.backgroundNode.update(size: panelFrame.size, transition: transition)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: panelFrame.width, height: UIScreenPixel)))
        
        if let (position, count) = self.currentParams {
            let indicatorSize = self.pageIndicatorView.update(
                transition: .immediate,
                component: AnyComponent(
                    PageIndicatorComponent(
                        pageCount: count,
                        position: position,
                        inactiveColor: self.theme.list.disclosureArrowColor,
                        activeColor: UIColor(rgb: 0x7169ff)
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            self.pageIndicatorView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - indicatorSize.width) / 2.0), y: 10.0), size: indicatorSize)
            transition.updateAlpha(layer: self.pageIndicatorView.layer, alpha: count <= 1 ? 0.0 : 1.0)
        }
        
        transition.updateFrame(node: self.coverNode, frame: panelFrame)
        
        return panelHeight
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.backgroundNode.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
}
