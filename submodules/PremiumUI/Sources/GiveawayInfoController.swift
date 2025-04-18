import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramStringFormatting
import TelegramPresentationData
import Markdown
import AlertUI

public func presentGiveawayInfoController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    messageId: EngineMessage.Id,
    giveawayInfo: PremiumGiveawayInfo,
    present: @escaping (ViewController) -> Void,
    openLink: @escaping (String) -> Void
) {
    var peerIds: [EnginePeer.Id] = [context.account.peerId]
    if case let .ongoing(_, status) = giveawayInfo, case let .notAllowed(reason) = status, case let .channelAdmin(adminId) = reason {
        peerIds.append(adminId)
    }
        
    let _ = (context.engine.data.get(
        TelegramEngine.EngineData.Item.Messages.Message(id: messageId),
        EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init))
    )
    |> deliverOnMainQueue).startStandalone(next: { message, peerMap in
        guard let message else {
            return
        }
        
        let giveaway = message.media.first(where: { $0 is TelegramMediaGiveaway }) as? TelegramMediaGiveaway
        let giveawayResults = message.media.first(where: { $0 is TelegramMediaGiveawayResults }) as? TelegramMediaGiveawayResults
        
        var quantity: Int32 = 0
        if let giveaway {
            quantity = giveaway.quantity
        } else if let giveawayResults {
            quantity = giveawayResults.winnersCount + giveawayResults.unclaimedCount
        }
        
        var months: Int32 = 0
        var stars: Int64 = 0
        if let giveaway {
            switch giveaway.prize {
            case let .premium(monthsValue):
                months = monthsValue
            case let .stars(amount):
                stars = amount
            }
        } else if let giveawayResults {
            switch giveawayResults.prize {
            case let .premium(monthsValue):
                months = monthsValue
            case let .stars(amount):
                stars = amount
            }
        }
        
        var prizeDescription: String?
        if let giveaway {
            prizeDescription = giveaway.prizeDescription
        } else if let giveawayResults {
            prizeDescription = giveawayResults.prizeDescription
        }
        
        var untilDateValue: Int32 = 0
        if let giveaway {
            untilDateValue = giveaway.untilDate
        } else if let giveawayResults {
            untilDateValue = giveawayResults.untilDate
        }
        
        var onlyNewSubscribers = false
        if let giveaway, giveaway.flags.contains(.onlyNewSubscribers) {
            onlyNewSubscribers = true
        } else if let giveawayResults, giveawayResults.flags.contains(.onlyNewSubscribers) {
            onlyNewSubscribers = true
        }
        
        var author = message.forwardInfo?.author ?? message.author?._asPeer()
        if author is TelegramChannel {
        } else {
            if let peer = message.forwardInfo?.source ?? message.peers[message.id.peerId] {
                author = peer
            }
        }
        var isGroup = false
        if let channel = author as? TelegramChannel, case .group = channel.info {
            isGroup = true
        }
        var peerName = ""
        if let author {
            peerName = EnginePeer(author).compactDisplayTitle
        }
        
        var groupsAndChannels = false
        var channelsCount: Int32 = 1
        if let giveaway {
            channelsCount = Int32(giveaway.channelPeerIds.count)
            
            var channelCount = 0
            var groupCount = 0
            for peerId in giveaway.channelPeerIds {
                if let peer = message.peers[peerId] as? TelegramChannel {
                    switch peer.info {
                    case .broadcast:
                        channelCount += 1
                    case .group:
                        groupCount += 1
                    }
                }
            }
            if groupCount > 0 && channelCount > 0 {
                groupsAndChannels = true
            }
        } else if let giveawayResults {
            channelsCount = 1 + giveawayResults.additionalChannelsCount
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                

        
        let timeZone = TimeZone.current
        let untilDate = stringForDate(timestamp: untilDateValue, timeZone: timeZone, strings: presentationData.strings)
        
        let title: String
        let text: String
        var warning: String?
        
        var dismissImpl: (() -> Void)?
        
        var actions: [TextAlertAction] = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
            dismissImpl?()
        })]
        
        var additionalPrizes = ""
        if let prizeDescription, !prizeDescription.isEmpty {
            additionalPrizes = "\n\n" + presentationData.strings.Chat_Giveaway_Info_AdditionalPrizes(peerName, "\(quantity) \(prizeDescription)").string
        }
        
        switch giveawayInfo {
        case let .ongoing(start, status):
            let startDate = presentationData.strings.Chat_Giveaway_Info_FullDate(
                stringForMessageTimestamp(timestamp: start, dateTimeFormat: presentationData.dateTimeFormat),
                stringForDate(timestamp: start, timeZone: timeZone, strings: presentationData.strings)
            ).string.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
            
            title = presentationData.strings.Chat_Giveaway_Info_Title
            
            let intro: String
            if stars > 0 {
                let starsString = presentationData.strings.Chat_Giveaway_Info_Stars_Stars(Int32(stars))
                if case .almostOver = status {
                    if isGroup {
                        intro = presentationData.strings.Chat_Giveaway_Info_Stars_Group_EndedIntro(peerName, starsString).string
                    } else {
                        intro = presentationData.strings.Chat_Giveaway_Info_Stars_EndedIntro(peerName, starsString).string
                    }
                } else {
                    if isGroup {
                        intro = presentationData.strings.Chat_Giveaway_Info_Stars_Group_OngoingIntro(peerName, starsString).string
                    } else {
                        intro = presentationData.strings.Chat_Giveaway_Info_Stars_OngoingIntro(peerName, starsString).string
                    }
                }
            } else {
                let subscriptionsString = presentationData.strings.Chat_Giveaway_Info_Subscriptions(quantity)
                let monthsString = presentationData.strings.Chat_Giveaway_Info_Months(months)
                if case .almostOver = status {
                    if isGroup {
                        intro = presentationData.strings.Chat_Giveaway_Info_Group_EndedIntro(peerName, subscriptionsString, monthsString).string
                    } else {
                        intro = presentationData.strings.Chat_Giveaway_Info_EndedIntro(peerName, subscriptionsString, monthsString).string
                    }
                } else {
                    if isGroup {
                        intro = presentationData.strings.Chat_Giveaway_Info_Group_OngoingIntro(peerName, subscriptionsString, monthsString).string
                    } else {
                        intro = presentationData.strings.Chat_Giveaway_Info_OngoingIntro(peerName, subscriptionsString, monthsString).string
                    }
                }
            }
            
            var otherText: String = ""
            if channelsCount > 1 {
                if isGroup {
                    if groupsAndChannels {
                        if channelsCount == 2 {
                            otherText = presentationData.strings.Chat_Giveaway_Info_OtherChannels(Int32(channelsCount - 1))
                        } else {
                            otherText = presentationData.strings.Chat_Giveaway_Info_OtherGroupsAndChannels(Int32(channelsCount - 1))
                        }
                    } else {
                        otherText = presentationData.strings.Chat_Giveaway_Info_OtherGroups(Int32(channelsCount - 1))
                    }
                } else {
                    if groupsAndChannels {
                        if channelsCount == 2 {
                            otherText = presentationData.strings.Chat_Giveaway_Info_OtherGroups(Int32(channelsCount - 1))
                        } else {
                            otherText = presentationData.strings.Chat_Giveaway_Info_OtherChannelsAndGroups(Int32(channelsCount - 1))
                        }
                    } else {
                        otherText = presentationData.strings.Chat_Giveaway_Info_OtherChannels(Int32(channelsCount - 1))
                    }
                }
            }
            
            let ending: String
            if onlyNewSubscribers {
                let randomUsers = presentationData.strings.Chat_Giveaway_Info_RandomUsers(quantity)
                if channelsCount > 1 {
                    ending = presentationData.strings.Chat_Giveaway_Info_OngoingNewMany(untilDate, randomUsers, peerName, otherText, startDate).string
                } else {
                    ending = presentationData.strings.Chat_Giveaway_Info_OngoingNew(untilDate, randomUsers, peerName, startDate).string
                }
            } else {
                let randomSubscribers = isGroup ? presentationData.strings.Chat_Giveaway_Info_Group_RandomMembers(quantity) : presentationData.strings.Chat_Giveaway_Info_RandomSubscribers(quantity)
                if channelsCount > 1 {
                    ending = presentationData.strings.Chat_Giveaway_Info_OngoingMany(untilDate, randomSubscribers, peerName, otherText).string
                } else {
                    ending = presentationData.strings.Chat_Giveaway_Info_Ongoing(untilDate, randomSubscribers, peerName).string
                }
            }
            
            var participation: String
            switch status {
            case .notQualified:
                if channelsCount > 1 {
                    participation = presentationData.strings.Chat_Giveaway_Info_NotQualifiedMany(peerName, otherText, untilDate).string
                } else {
                    participation = presentationData.strings.Chat_Giveaway_Info_NotQualified(peerName, untilDate).string
                }
            case let .notAllowed(reason):
                switch reason {
                case let .joinedTooEarly(joinedOn):
                    let joinDate = stringForDate(timestamp: joinedOn, strings: presentationData.strings)
                    participation = presentationData.strings.Chat_Giveaway_Info_NotAllowedJoinedEarly(joinDate).string
                case let .channelAdmin(adminId):
                    var channelName = peerName
                    var isGroup = false
                    if let maybePeer = peerMap[adminId], let peer = maybePeer {
                        channelName = peer.compactDisplayTitle
                        if case let .channel(channel) = peer, case .group = channel.info {
                            isGroup = true
                        }
                    }
                    participation = isGroup ? presentationData.strings.Chat_Giveaway_Info_NotAllowedAdminGroup(channelName).string : presentationData.strings.Chat_Giveaway_Info_NotAllowedAdmin(channelName).string
                case .disallowedCountry:
                    participation = presentationData.strings.Chat_Giveaway_Info_NotAllowedCountry
                }
            case .participating:
                if channelsCount > 1 {
                    participation = presentationData.strings.Chat_Giveaway_Info_ParticipatingMany(peerName, otherText).string
                } else {
                    participation = presentationData.strings.Chat_Giveaway_Info_Participating(peerName).string
                }
            case .almostOver:
                participation = presentationData.strings.Chat_Giveaway_Info_AlmostOver
            }
            
            if !participation.isEmpty {
                participation = "\n\n\(participation)"
            }
            
            text = "\(intro)\(additionalPrizes)\n\n\(ending)\(participation)"
        case let .finished(status, start, finish, _, activatedCount):
            let startDate = presentationData.strings.Chat_Giveaway_Info_FullDate(
                stringForMessageTimestamp(timestamp: start, dateTimeFormat: presentationData.dateTimeFormat),
                stringForDate(timestamp: start, timeZone: timeZone, strings: presentationData.strings)
            ).string.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
            
            let finishDate = stringForDate(timestamp: finish, timeZone: timeZone, strings: presentationData.strings)
            title = presentationData.strings.Chat_Giveaway_Info_EndedTitle
            
            let intro: String
            if stars > 0 {
                let starsString = presentationData.strings.Chat_Giveaway_Info_Stars_Stars(Int32(stars))
                if isGroup {
                    intro = presentationData.strings.Chat_Giveaway_Info_Stars_Group_EndedIntro(peerName, starsString).string
                } else {
                    intro = presentationData.strings.Chat_Giveaway_Info_Stars_EndedIntro(peerName, starsString).string
                }
            } else {
                let subscriptionsString = presentationData.strings.Chat_Giveaway_Info_Subscriptions(quantity)
                let monthsString = presentationData.strings.Chat_Giveaway_Info_Months(months)
                if isGroup {
                    intro = presentationData.strings.Chat_Giveaway_Info_Group_EndedIntro(peerName, subscriptionsString, monthsString).string
                } else {
                    intro = presentationData.strings.Chat_Giveaway_Info_EndedIntro(peerName, subscriptionsString, monthsString).string
                }
            }
            
            var ending: String
            if onlyNewSubscribers {
                let randomUsers = presentationData.strings.Chat_Giveaway_Info_RandomUsers(quantity)
                if channelsCount > 1 {
                    ending = presentationData.strings.Chat_Giveaway_Info_EndedNewMany(finishDate, randomUsers, peerName, startDate).string
                } else {
                    ending = presentationData.strings.Chat_Giveaway_Info_EndedNew(finishDate, randomUsers, peerName, startDate).string
                }
            } else {
                let randomSubscribers = isGroup ? presentationData.strings.Chat_Giveaway_Info_Group_RandomMembers(quantity) : presentationData.strings.Chat_Giveaway_Info_RandomSubscribers(quantity)
                if channelsCount > 1 {
                    ending = presentationData.strings.Chat_Giveaway_Info_EndedMany(finishDate, randomSubscribers, peerName).string
                } else {
                    ending = presentationData.strings.Chat_Giveaway_Info_Ended(finishDate, randomSubscribers, peerName).string
                }
            }
            
            if let activatedCount, activatedCount > 0 {
                ending += " " + presentationData.strings.Chat_Giveaway_Info_ActivatedLinks(activatedCount)
            }
                        
            var result: String
            switch status {
            case .refunded:
                result = ""
                warning = presentationData.strings.Chat_Giveaway_Info_Refunded
                actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Close, action: {
                    dismissImpl?()
                })]
            case .notWon:
                result = "**\(presentationData.strings.Chat_Giveaway_Info_DidntWin)**\n\n"
            case let .wonPremium(slug):
                result = "**\(presentationData.strings.Chat_Giveaway_Info_Won("").string)**\n\n"
                actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Chat_Giveaway_Info_ViewPrize, action: {
                    dismissImpl?()
                    openLink(slug)
                }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    dismissImpl?()
                })]
            case let .wonStars(stars):
                let _ = stars
                result = "**\(presentationData.strings.Chat_Giveaway_Info_Won("").string)**\n\n"
                actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Chat_Giveaway_Info_ViewPrize, action: {
                    dismissImpl?()
                    openLink("")
                }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    dismissImpl?()
                })]
            }
            
            text = "\(result)\(intro)\(additionalPrizes)\n\n\(ending)"
        }
        
        let alertController = giveawayInfoAlertController(
            context: context,
            updatedPresentationData: updatedPresentationData,
            title: title,
            text: text,
            warning: warning,
            actions: actions
        )
        dismissImpl = { [weak alertController] in
            alertController?.dismissAnimated()
        }
        present(alertController)
    })
}

private final class GiveawayInfoAlertContentNode: AlertContentNode {
    private let title: String
    private let text: String
    private let warning: String?
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    fileprivate let warningBackgroundNode: ASImageNode
    fileprivate let warningTextNode: ImmediateTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
        
    public var theme: PresentationTheme
    
    public override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    public init(theme: AlertControllerTheme, ptheme: PresentationTheme, title: String, text: String, warning: String?, actions: [TextAlertAction]) {
        self.theme = ptheme
        self.title = title
        self.text = text
        self.warning = warning
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        self.warningBackgroundNode = ASImageNode()
        self.warningBackgroundNode.displaysAsynchronously = false
        
        self.warningTextNode = ImmediateTextNode()
        self.warningTextNode.maximumNumberOfLines = 0
        self.warningTextNode.lineSpacing = 0.1
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.warningBackgroundNode)
        self.addSubnode(self.warningTextNode)
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
                
        self.updateTheme(theme)
    }

    public override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
        
        let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor)
        let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.primaryColor)
        let attributedText = parseMarkdownIntoAttributedString(self.text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
        
        self.textNode.attributedText = attributedText
        
        self.warningTextNode.attributedText = NSAttributedString(string: self.warning ?? "", font: Font.semibold(13.0), textColor: theme.destructiveColor, paragraphAlignment: .center)
        self.warningBackgroundNode.image = generateStretchableFilledCircleImage(radius: 5.0, color: theme.destructiveColor.withAlphaComponent(0.1))
        
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
                
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    public override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width, 270.0)
        let measureSize = CGSize(width: size.width - 16.0 * 2.0, height: CGFloat.greatestFiniteMagnitude)
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        
        let titleSize = self.titleNode.measure(measureSize)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 4.0
        
        let textSize = self.textNode.measure(measureSize)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: origin.y), size: textSize))
        origin.y += textSize.height + 6.0
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        if "".isEmpty {
            effectiveActionLayout = .vertical
        }
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var contentWidth = max(titleSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 234.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        
        var warningHeight: CGFloat = 0.0
        if let _ = self.warning {
            let warningSize = self.warningTextNode.updateLayout(measureSize)
            let warningFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - warningSize.width) / 2.0), y: origin.y + 20.0), size: warningSize)
            transition.updateFrame(node: self.warningTextNode, frame: warningFrame)
            
            transition.updateFrame(node: self.warningBackgroundNode, frame: warningFrame.insetBy(dx: -8.0, dy: -8.0))
            
            warningHeight += warningSize.height + 26.0
        }
        
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + textSize.height + 8.0 + actionsHeight + warningHeight + insets.top + insets.bottom)
        
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
            case .horizontal:
                if nodeIndex == self.actionNodes.count - 1 {
                    currentActionWidth = resultSize.width - actionOffset
                } else {
                    currentActionWidth = actionWidth
                }
            case .vertical:
                currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

private func giveawayInfoAlertController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, title: String, text: String, warning: String?, actions: [TextAlertAction]) -> AlertController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                
    let contentNode = GiveawayInfoAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, title: title, text: text, warning: warning, actions: actions)
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = (updatedPresentationData?.signal ?? context.sharedContext.presentationData).start(next: { [weak controller] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
    }

    return controller
}
