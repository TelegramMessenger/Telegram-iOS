import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import GiftItemComponent
import AnimatedTextComponent

private let titleFont = Font.semibold(15.0)
private let subtitleFont = Font.regular(14.0)

final class GiftAuctionAccessoryPanel: ASDisplayNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let tapAction: () -> Void
    
    private let contentNode: ASDisplayNode
    
    private let title = ComponentView<Empty>()
    private let subtitle = ComponentView<Empty>()
    private let button = ComponentView<Empty>()
    
    private let separatorNode: ASDisplayNode
    
    private var validLayout: (CGSize, CGFloat, CGFloat, Bool)?
    private var states: [GiftAuctionContext.State] = []
    private var giftAuctionTimer: SwiftSignalKit.Timer?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, tapAction: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        
        self.tapAction = tapAction
        
        self.contentNode = ASDisplayNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.contentNode)
        
        self.contentNode.addSubnode(self.separatorNode)
        
        self.giftAuctionTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
            if let self, let (size, leftInset, rightInset, isHidden) = self.validLayout {
                self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, isHidden: isHidden, transition: .immediate)
            }
        }, queue: Queue.mainQueue())
        self.giftAuctionTimer?.start()
    }
    
    deinit {
        self.giftAuctionTimer?.invalidate()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, isHidden: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, leftInset, rightInset, isHidden)
        
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: isHidden ? -size.height : 0.0), size: size))
        transition.updateAlpha(node: self.contentNode, alpha: isHidden ? 0.0 : 1.0)
        
        
        guard self.states.count > 0 else {
            return
        }
                        
        var titleItems: [AnyComponentWithIdentity<Empty>] = []
        for auctionState in self.states {
            if case let .generic(gift) = auctionState.gift {
                titleItems.append(AnyComponentWithIdentity(id: "icon-\(gift.id)", component: AnyComponent(
                    GiftItemComponent(
                        context: self.context,
                        theme: self.theme,
                        strings: self.strings,
                        peer: nil,
                        subject: .starGift(gift: gift, price: ""),
                        mode: .tableIcon
                    )
                )))
            }
        }
        
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        
        var titleText: String = self.strings.ChatList_Auctions_ActiveAuction(Int32(self.states.count))
        
        let subtitleText: String
        var subtitleTextColor = self.theme.rootController.navigationBar.secondaryTextColor
        var isOutbid = false
        
        var buttonAnimatedTitleItems: [AnimatedTextComponent.Item] = []
        
        if self.states.count == 1, let auctionState = self.states.first {
            var isUpcoming = false
            var startTime = currentTime
            var endTime = currentTime
            if case let .ongoing(_, startDate, _, _, _, _, nextRoundDate, _, _, _, _, _) = auctionState.auctionState {
                startTime = startDate
                endTime = nextRoundDate
                if currentTime < startDate {
                    isUpcoming = true
                }
            }
            
            let place = auctionState.place ?? 1
            if isUpcoming {
                subtitleText = self.strings.ChatList_Auctions_Status_UpcomingBid
            } else if case let .generic(gift) = auctionState.gift, let auctionGiftsPerRound = gift.auctionGiftsPerRound, place > auctionGiftsPerRound {
                subtitleText = self.strings.ChatList_Auctions_Status_Single_Outbid
                subtitleTextColor = self.theme.list.itemDestructiveColor
                isOutbid = true
            } else {
                let placeText: String
                let lastDigit = place % 10
                switch lastDigit {
                case 1:
                    placeText = self.strings.ChatList_Auctions_Status_Single_PlaceFirst("\(place)").string
                case 2:
                    placeText = self.strings.ChatList_Auctions_Status_Single_PlaceSecond("\(place)").string
                case 3:
                    placeText = self.strings.ChatList_Auctions_Status_Single_PlaceThird("\(place)").string
                default:
                    placeText = self.strings.ChatList_Auctions_Status_Single_PlaceNTh("\(place)").string
                }
                subtitleText = self.strings.ChatList_Auctions_Status_Single_Winning(placeText).string
            }
            
            let endTimeout: Int32
            if currentTime < startTime {
                endTimeout = max(0, startTime - currentTime)
                titleText = self.strings.ChatList_Auctions_UpcomingAuction
            } else {
                endTimeout = max(0, endTime - currentTime)
            }
            
            let hours = Int(endTimeout / 3600)
            let minutes = Int((endTimeout % 3600) / 60)
            let seconds = Int(endTimeout % 60)
                    
            if hours > 0 {
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "h", content: .number(hours, minDigits: 1)))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "colon1", content: .text(":")))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "colon2", content: .text(":")))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
            } else {
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "colon2", content: .text(":")))
                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
            }
        } else {
            var outbidCount = 0
            for auctionState in self.states {
                let place = auctionState.place ?? 1
                if case let .generic(gift) = auctionState.gift, let auctionGiftsPerRound = gift.auctionGiftsPerRound, place > auctionGiftsPerRound {
                    outbidCount += 1
                }
            }
            if outbidCount > 0 {
                if outbidCount == self.states.count {
                    subtitleText = self.strings.ChatList_Auctions_Status_Many_OutbidAll
                } else {
                    subtitleText = self.strings.ChatList_Auctions_Status_Many_Outbid(Int32(outbidCount))
                }
                subtitleTextColor = self.theme.list.itemDestructiveColor
                isOutbid = true
            } else {
                subtitleText = self.strings.ChatList_Auctions_Status_Many_WinningAll
            }
            buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "view", content: .text(self.strings.ChatList_Auctions_View)))
        }
        
        titleItems.append(AnyComponentWithIdentity(id: "label", component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: titleText, font: titleFont, textColor: self.theme.rootController.navigationBar.primaryTextColor))))))
        
        let buttonSize = self.button.update(
            transition: .spring(duration: 0.2),
            component: AnyComponent(
                ButtonComponent(
                    background: ButtonComponent.Background(
                        color: self.theme.list.itemCheckColors.fillColor,
                        foreground: self.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: self.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 14.0,
                        isShimmering: isOutbid
                    ),
                    content: AnyComponentWithIdentity(
                        id: "content",
                        component: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Premium/Auction/BidSmall", tintColor: self.theme.list.itemCheckColors.foregroundColor))),
                            AnyComponentWithIdentity(id: "timer", component: AnyComponent(
                                AnimatedTextComponent(
                                    font: Font.with(size: 15.0, weight: .semibold, traits: .monospacedNumbers),
                                    color: self.theme.list.itemCheckColors.foregroundColor,
                                    items: buttonAnimatedTitleItems,
                                    noDelay: true
                                )
                            ))
                        ], spacing: 3.0))
                    ),
                    fitToContentWidth: true,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.tapAction()
                    }
                )
            ),
            environment: {},
            containerSize: CGSize(width: size.width, height: 28.0)
        )
        let buttonFrame = CGRect(origin: CGPoint(x: size.width - rightInset - buttonSize.width - 16.0, y: 14.0), size: buttonSize)
        if let buttonView = self.button.view {
            if buttonView.superview == nil {
                self.contentNode.view.addSubview(buttonView)
            }
            buttonView.frame = buttonFrame
        }
        
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(
                HStack(titleItems, spacing: 3.0, alignment: .left)
            ),
            environment: {},
            containerSize: CGSize(width: size.width - buttonSize.width - 48.0, height: size.height)
        )
        let titleFrame = CGRect(origin: CGPoint(x: 16.0, y: 9.0), size: titleSize)
        if let titleView = self.title.view {
            if titleView.superview == nil {
                self.contentNode.view.addSubview(titleView)
            }
            titleView.frame = titleFrame
        }
        
        let subtitleSize = self.subtitle.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: subtitleText, font: subtitleFont, textColor: subtitleTextColor)))),
            environment: {},
            containerSize: CGSize(width: size.width - buttonSize.width - 40.0, height: size.height)
        )
        let subtitleFrame = CGRect(origin: CGPoint(x: 16.0, y: 29.0), size: subtitleSize)
        if let subtitleView = self.subtitle.view {
            if subtitleView.superview == nil {
                self.contentNode.view.addSubview(subtitleView)
            }
            subtitleView.frame = subtitleFrame
        }
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel)))
    }
    
    func update(states: [GiftAuctionContext.State]) {
        self.states = states
        if let (size, leftInset, rightInset, isHidden) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, isHidden: isHidden, transition: .immediate)
        }
    }
    
    func animateIn(_ transition: ContainedViewLayoutTransition) {
        let contentPosition = self.contentNode.layer.position

        transition.animatePosition(node: self.contentNode, from: CGPoint(x: contentPosition.x, y: contentPosition.y - 56.0))

        guard let (size, _, _, _) = self.validLayout else {
            return
        }

        transition.animatePositionAdditive(node: self.separatorNode, offset: CGPoint(x: 0.0, y: size.height))
    }
    
    func animateOut(_ transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let contentPosition = self.contentNode.layer.position
        transition.animatePosition(node: self.contentNode, to: CGPoint(x: contentPosition.x, y: contentPosition.y - 56.0), removeOnCompletion: false, completion: { _ in
            completion()
        })

        guard let (size, _, _, _) = self.validLayout else {
            return
        }

        transition.updatePosition(node: self.separatorNode, position: self.separatorNode.position.offsetBy(dx: 0.0, dy: size.height))
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapAction()
        }
    }
}
