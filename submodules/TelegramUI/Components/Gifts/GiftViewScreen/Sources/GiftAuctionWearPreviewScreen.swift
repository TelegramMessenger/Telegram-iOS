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
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import ButtonComponent
import Markdown
import BalancedTextComponent
import AvatarNode
import TextFormat
import TelegramStringFormatting
import PlainButtonComponent
import GiftItemComponent
import GiftAnimationComponent
import GlassBarButtonComponent
import GiftRemainingCountComponent
import AnimatedTextComponent
import AvatarComponent

private final class GiftAuctionWearPreviewSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let auctionContext: GiftAuctionContext
    let attributes: [StarGift.UniqueGift.Attribute]
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        auctionContext: GiftAuctionContext,
        attributes: [StarGift.UniqueGift.Attribute],
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.auctionContext = auctionContext
        self.attributes = attributes
        self.animateOut = animateOut
        self.getController = getController
    }
    
    static func ==(lhs: GiftAuctionWearPreviewSheetContent, rhs: GiftAuctionWearPreviewSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
                        
        private var peerDisposable: Disposable?
        var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
        
        private var disposable: Disposable?
        private(set) var giftAuctionState: GiftAuctionContext.State?
        private var giftAuctionTimer: SwiftSignalKit.Timer?
        
        private var previewTimer: SwiftSignalKit.Timer?
        private(set) var previewModelIndex: Int = 0
        private(set) var previewBackdropIndex: Int = 0
        private(set) var previewSymbolIndex: Int = 0
        
        private(set) var previewModels: [StarGift.UniqueGift.Attribute] = []
        private(set) var previewBackdrops: [StarGift.UniqueGift.Attribute] = []
        private(set) var previewSymbols: [StarGift.UniqueGift.Attribute] = []
        
        init(
            context: AccountContext,
            auctionContext: GiftAuctionContext,
            attributes: [StarGift.UniqueGift.Attribute]
        ) {
            self.context = context
            
            super.init()
            
            for attribute in attributes {
                switch attribute {
                case .model:
                    self.previewModels.append(attribute)
                case .backdrop:
                    self.previewBackdrops.append(attribute)
                case .pattern:
                    self.previewSymbols.append(attribute)
                default:
                    break
                }
            }
            
            let peerIds: [EnginePeer.Id] = [context.account.peerId]
            self.peerDisposable = (
                context.engine.data.get(EngineDataMap(
                    peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                        return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    }
                ))
                |> deliverOnMainQueue
            ).startStrict(next: { [weak self] peers in
                if let strongSelf = self {
                    var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                    for (peerId, maybePeer) in peers {
                        if let peer = maybePeer {
                            peersMap[peerId] = peer
                        }
                    }
                    strongSelf.peerMap = peersMap
                    strongSelf.updated(transition: .immediate)
                }
            })
            
            self.previewTimer = SwiftSignalKit.Timer(timeout: 3.0, repeat: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.previewTimerTick()
            }, queue: Queue.mainQueue())
            self.previewTimer?.start()
            
            self.disposable = (auctionContext.state
            |> deliverOnMainQueue).start(next: { [weak self] auctionState in
                guard let self else {
                    return
                }
                self.giftAuctionState = auctionState
                self.updated()
            })
            
            self.giftAuctionTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                self?.updated()
            }, queue: Queue.mainQueue())
            self.giftAuctionTimer?.start()
        }
        
        deinit {
            self.disposable?.dispose()
            self.giftAuctionTimer?.invalidate()
            self.peerDisposable?.dispose()
            self.previewTimer?.invalidate()
        }
        
        private func previewTimerTick() {
            guard !self.previewModels.isEmpty else { return }
            self.previewModelIndex = (self.previewModelIndex + 1) % self.previewModels.count
            
            let previousSymbolIndex = self.previewSymbolIndex
            var randomSymbolIndex = previousSymbolIndex
            while randomSymbolIndex == previousSymbolIndex && !self.previewSymbols.isEmpty {
                randomSymbolIndex = Int.random(in: 0 ..< self.previewSymbols.count)
            }
            if !self.previewSymbols.isEmpty { self.previewSymbolIndex = randomSymbolIndex }
            
            let previousBackdropIndex = self.previewBackdropIndex
            var randomBackdropIndex = previousBackdropIndex
            while randomBackdropIndex == previousBackdropIndex && !self.previewBackdrops.isEmpty {
                randomBackdropIndex = Int.random(in: 0 ..< self.previewBackdrops.count)
            }
            if !self.previewBackdrops.isEmpty { self.previewBackdropIndex = randomBackdropIndex }
            
            self.updated(transition: .easeInOut(duration: 0.25))
        }
    }


    func makeState() -> State {
        return State(context: self.context, auctionContext: self.auctionContext, attributes: self.attributes)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let animation = Child(GiftCompositionComponent.self)
        let avatar = Child(AvatarComponent.self)
        let peerName = Child(MultilineTextComponent.self)
        let learnMore = Child(PlainButtonComponent.self)
        
        let initialGift = Child(GiftItemComponent.self)
        let upgradedGift = Child(GiftItemComponent.self)
        let arrow = Child(BundleIconComponent.self)
        let upgradeLabel = Child(MultilineTextComponent.self)
        let remainingCount = Child(GiftRemainingCountComponent.self)
        let auctionFooter = Child(MultilineTextComponent.self)
        
        let button = Child(ButtonComponent.self)
        
        let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let nameDisplayOrder = component.context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder
            let controller = environment.controller
            let state = context.state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var contentHeight: CGFloat = 0.0
                        
            let headerHeight: CGFloat = 226.0
                    
            var peerNameString = ""
            if let peer = state.peerMap[component.context.account.peerId] {
                peerNameString = peer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
            }
            
            let peerName = peerName.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: peerNameString,
                        font: Font.bold(20.0),
                        textColor: .white,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let animationOffset: CGPoint? = CGPoint(x: peerName.size.width / 2.0 + 20.0 - 12.0, y: 79.0)
            let animationScale: CGFloat = 0.19

            var attributes: [StarGift.UniqueGift.Attribute] = []
            if !state.previewModels.isEmpty {
                attributes.append(state.previewModels[state.previewModelIndex])
                if !state.previewBackdrops.isEmpty {
                    attributes.append(state.previewBackdrops[state.previewBackdropIndex])
                }
                if !state.previewSymbols.isEmpty {
                    attributes.append(state.previewSymbols[state.previewSymbolIndex])
                }
            }
            let animation = animation.update(
                component: GiftCompositionComponent(
                    context: component.context,
                    theme: environment.theme,
                    subject: .preview(attributes),
                    animationOffset: animationOffset,
                    animationScale: animationScale,
                    displayAnimationStars: true,
                    animateScaleOnTransition: false,
                    externalState: giftCompositionExternalState,
                    requestUpdate: { [weak state] transition in
                        state?.updated(transition: transition)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width, height: headerHeight),
                transition: context.transition
            )
            context.add(animation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: headerHeight / 2.0))
            )
            contentHeight += headerHeight
            
            if let peer = state.peerMap[component.context.account.peerId] {
                let avatar = avatar.update(
                    component: AvatarComponent(
                        context: component.context,
                        theme: theme,
                        peer: peer
                    ),
                    environment: {},
                    availableSize: CGSize(width: 100.0, height: 100.0),
                    transition: context.transition
                )
                context.add(avatar
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 86.0))
                )
            }
            context.add(peerName
                .position(CGPoint(x: context.availableSize.width / 2.0 - 12.0, y: 167.0))
            )
            
            var buttonColor: UIColor = .white.withAlphaComponent(0.1)
            var secondaryTextColor: UIColor = .white.withAlphaComponent(0.4)
            if let backdropAttribute = attributes.first(where: { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }), case let .backdrop(_, _, innerColor, outerColor, _, _, _) = backdropAttribute {
                buttonColor = UIColor(rgb: UInt32(bitPattern: outerColor)).mixedWith(.white, alpha: 0.2)
                secondaryTextColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
            }
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: buttonColor,
                    isDark: false,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: .white
                        )
                    )),
                    action: { _ in
                        (controller() as? GiftAuctionWearPreviewScreen)?.dismissAnimated()
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            let textFont = Font.regular(13.0)
            let boldTextFont = Font.semibold(13.0)
            let textColor = UIColor.white
            let linkColor = UIColor.white
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: linkColor)!, theme)
            }
            
            let learnMoreAttributedString = parseMarkdownIntoAttributedString(strings.Gift_WearPreview_LearnMore, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
            if let range = learnMoreAttributedString.string.range(of: ">"), let chevronImage = state.cachedSmallChevronImage?.0 {
                learnMoreAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: learnMoreAttributedString.string))
            }
            let learnMore = learnMore.update(
                component: PlainButtonComponent(
                    content: AnyComponent(BalancedTextComponent(
                        text: .plain(learnMoreAttributedString),
                        maximumNumberOfLines: 1,
                        tintColor: secondaryTextColor
                    )),
                    action: {
                        let controller = component.context.sharedContext.makeGiftWearPreviewScreen(context: component.context, gift: component.auctionContext.gift, attributes: component.attributes)
                        environment.controller()?.push(controller)
                    },
                    animateScale: false
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(learnMore
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 198.0))
            )
            
            if case let .generic(gift) = component.auctionContext.gift {
                let initialGift = initialGift.update(
                    component: GiftItemComponent(
                        context: component.context,
                        theme: theme,
                        strings: strings,
                        subject: .starGift(gift: gift, price: ""),
                        ribbon: GiftItemComponent.Ribbon(text: strings.Gift_WearPreview_Limited, color: .blue),
                        mode: .thumbnail
                    ),
                    availableSize: CGSize(width: 120.0, height: 120.0),
                    transition: context.transition
                )
                context.add(initialGift
                    .position(CGPoint(x: sideInset + initialGift.size.width * 0.5, y: contentHeight + 76.0))
                )
            }

            var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
            for attribute in attributes {
                if case let .backdrop(_, _, innerColor, outerColor, _, _, _) = attribute {
                    ribbonColor = .custom(outerColor, innerColor)
                    break
                }
            }
            let upgradedGift = upgradedGift.update(
                component: GiftItemComponent(
                    context: component.context,
                    theme: theme,
                    strings: strings,
                    subject: .preview(attributes: attributes, rarity: nil),
                    ribbon: GiftItemComponent.Ribbon(text: strings.Gift_WearPreview_Upgraded, color: ribbonColor),
                    animateChanges: true,
                    mode: .thumbnail
                ),
                availableSize: CGSize(width: 120.0, height: 120.0),
                transition: context.transition
            )
            context.add(upgradedGift
                .position(CGPoint(x: context.availableSize.width - sideInset - upgradedGift.size.width * 0.5, y: contentHeight + 76.0))
            )
            
            
            let arrow = arrow.update(
                component: BundleIconComponent(name: "Premium/Auction/Upgrade", tintColor: theme.list.itemSecondaryTextColor),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(arrow
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + 56.0))
            )
            
            let upgradeLabel = upgradeLabel.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: strings.Gift_WearPreview_FreeUpgrade, font: Font.medium(13.0), textColor: theme.list.itemSecondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 2,
                    lineSpacing: 0.1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(upgradeLabel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + 94.0))
            )
            
            contentHeight += 137.0

            if case let .generic(gift) = component.auctionContext.gift, let availability = gift.availability {
                var remains: Int32 = availability.remains
                if let auctionState = state.giftAuctionState {
                    switch auctionState.auctionState {
                    case let .ongoing(_, _, _, _, _, _, _, giftsLeft, _, _, _, _):
                        remains = giftsLeft
                    case .finished:
                        remains = 0
                    }
                }
                let total = availability.total
                let position = CGFloat(remains) / CGFloat(total)
                let sold = total - remains
                let remainingCount = remainingCount.update(
                    component: GiftRemainingCountComponent(
                        inactiveColor: theme.list.itemBlocksBackgroundColor,
                        activeColors: [UIColor(rgb: 0x72d6ff), UIColor(rgb: 0x32a0f9)],
                        inactiveTitle: strings.Gift_Send_Remains(remains),
                        inactiveValue: "",
                        inactiveTitleColor: theme.list.itemSecondaryTextColor,
                        activeTitle: "",
                        activeValue: sold > 0 ? strings.Gift_Send_Sold(sold) : "",
                        activeTitleColor: .white,
                        badgeText: "",
                        badgePosition: position,
                        badgeGraphPosition: position,
                        invertProgress: true,
                        leftString: "",
                        groupingSeparator: environment.dateTimeFormat.groupingSeparator
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(remainingCount
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight))
                )
                
                if let giftsPerRound = gift.auctionGiftsPerRound {
                    let footerAttributes = MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.freeTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.list.freeTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemAccentColor),
                        linkAttribute: { contents in
                            return (TelegramTextAttributes.URL, contents)
                        }
                    )
                    let parsedString = parseMarkdownIntoAttributedString(strings.Gift_Setup_AuctionInfo(environment.strings.Gift_Setup_AuctionInfo_Gifts(giftsPerRound), strings.Gift_Setup_AuctionInfo_Bidders(giftsPerRound)).string, attributes: footerAttributes)
                    let auctionFooterText = NSMutableAttributedString(attributedString: parsedString)
                    
                    if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                        state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: theme.list.itemAccentColor)!, environment.theme)
                    }
                    if let range = auctionFooterText.string.range(of: ">"), let chevronImage = state.cachedSmallChevronImage?.0 {
                        auctionFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: auctionFooterText.string))
                    }
                    
                    let auctionFooter = auctionFooter.update(
                        component: MultilineTextComponent(
                            text: .plain(auctionFooterText),
                            maximumNumberOfLines: 0,
                            highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.1),
                            highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { _, _ in
                                guard let controller = controller() else {
                                    return
                                }
                                let infoController = component.context.sharedContext.makeGiftAuctionInfoScreen(context: component.context, auctionContext: component.auctionContext, completion: nil)
                                controller.push(infoController)
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 10000.0),
                        transition: context.transition
                    )
                    context.add(auctionFooter
                        .position(CGPoint(x: sideInset + 16.0 + auctionFooter.size.width * 0.5, y: contentHeight + 52.0 + auctionFooter.size.height * 0.5))
                    )
                    contentHeight += auctionFooter.size.height
                }
            }
            contentHeight += 80.0
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            var startTime = currentTime
            var endTime = currentTime
            var isUpcoming = false
            
            if let auctionState = state.giftAuctionState {
                startTime = auctionState.startDate
                endTime = auctionState.endDate
            }
            
            var buttonTitle = strings.Gift_Auction_Join
            let endTimeout: Int32
            if currentTime < startTime {
                isUpcoming = true
                endTimeout = max(0, startTime - currentTime)
            } else {
                endTimeout = max(0, endTime - currentTime)
            }
            
            let hours = Int(endTimeout / 3600)
            let minutes = Int((endTimeout % 3600) / 60)
            let seconds = Int(endTimeout % 60)
            
            let rawString: String
            if isUpcoming {
                buttonTitle = strings.Gift_Auction_EarlyBid
                rawString = hours > 0 ? strings.Gift_Auction_StartsInHours : strings.Gift_Auction_StartsInMinutes
            } else {
                rawString = hours > 0 ? strings.Gift_Auction_TimeLeftHours : strings.Gift_Auction_TimeLeftMinutes
            }
            
            var buttonAnimatedTitleItems: [AnimatedTextComponent.Item] = []
            var startIndex = rawString.startIndex
            while true {
                if let range = rawString.range(of: "{", range: startIndex ..< rawString.endIndex) {
                    if range.lowerBound != startIndex {
                        buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "prefix_\(buttonAnimatedTitleItems.count)", content: .text(String(rawString[startIndex ..< range.lowerBound]))))
                    }
                    
                    startIndex = range.upperBound
                    if let endRange = rawString.range(of: "}", range: startIndex ..< rawString.endIndex) {
                        let controlString = rawString[range.upperBound ..< endRange.lowerBound]
                        if controlString == "h" {
                            buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "h", content: .number(hours, minDigits: 2)))
                        } else if controlString == "m" {
                            buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                        } else if controlString == "s" {
                            buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
                        }
                        
                        startIndex = endRange.upperBound
                    }
                } else {
                    break
                }
            }
            if startIndex != rawString.endIndex {
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "suffix_\(buttonAnimatedTitleItems.count)", content: .text(String(rawString[startIndex ..< rawString.endIndex]))))
            }

            let buttonAttributedString = NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            let items: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))),
                AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: 12.0, weight: .medium, traits: .monospacedNumbers),
                    color: theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7),
                    items: buttonAnimatedTitleItems,
                    noDelay: true
                )))
            ]
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let buttonSize = CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
            let buttonBackground = ButtonComponent.Background(
                style: .glass,
                color: theme.list.itemCheckColors.fillColor,
                foreground: theme.list.itemCheckColors.foregroundColor,
                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
            )
            let button = button.update(
                component: ButtonComponent(
                    background: buttonBackground,
                    content: AnyComponentWithIdentity(
                        id: AnyHashable("bid"),
                        component: AnyComponent(VStack(items, spacing: 1.0))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                        if let controller = controller() as? GiftAuctionWearPreviewScreen {
                            controller.completion()
                            controller.dismissAnimated()
                        }
                    }),
                availableSize: buttonSize,
                transition: .spring(duration: 0.2)
            )
            
            let buttonFrame = CGRect(origin: CGPoint(x: buttonInsets.left, y: contentHeight), size: button.size)
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
            contentHeight += button.size.height
            contentHeight += 7.0
            
            let effectiveBottomInset: CGFloat = environment.metrics.isTablet ? 0.0 : environment.safeInsets.bottom
            return CGSize(width: context.availableSize.width, height: contentHeight + 5.0 + effectiveBottomInset)
        }
    }
}

final class GiftAuctionWearPreviewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let auctionContext: GiftAuctionContext
    let attributes: [StarGift.UniqueGift.Attribute]
    
    init(
        context: AccountContext,
        auctionContext: GiftAuctionContext,
        attributes: [StarGift.UniqueGift.Attribute]
    ) {
        self.context = context
        self.auctionContext = auctionContext
        self.attributes = attributes
    }
    
    static func ==(lhs: GiftAuctionWearPreviewSheetComponent, rhs: GiftAuctionWearPreviewSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let theme = environment.theme.withModalBlocksBackground()
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(GiftAuctionWearPreviewSheetContent(
                        context: context.component.context,
                        auctionContext: context.component.auctionContext,
                        attributes: context.component.attributes,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(theme.list.blocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    hasDimView: false,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                    },
                    willDismiss: {
                        if let controller = controller() as? GiftAuctionWearPreviewScreen {
                            controller.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition()))
                        }
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                if let controller = controller() as? GiftAuctionWearPreviewScreen {
                                    controller.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition()))
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? GiftAuctionWearPreviewScreen {
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
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public class GiftAuctionWearPreviewScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    fileprivate let completion: () -> Void
    
    public init(
        context: AccountContext,
        auctionContext: GiftAuctionContext,
        attributes: [StarGift.UniqueGift.Attribute],
        completion: @escaping () -> Void
    ) {
        self.context = context
        self.completion = completion
        
        super.init(
            context: context,
            component: GiftAuctionWearPreviewSheetComponent(context: context, auctionContext: auctionContext, attributes: attributes),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
}
