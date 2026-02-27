import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramStringFormatting
import TelegramPresentationData
import ComponentFlow
import AlertComponent

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
        
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
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
        
        let timeZone = TimeZone.current
        let untilDate = stringForDate(timestamp: untilDateValue, timeZone: timeZone, strings: presentationData.strings)
        
        let title: String
        var text: String
        var warning: String?
                
        var actions: [AlertScreen.Action] = [
            .init(title: presentationData.strings.Common_OK, type: .default)
        ]
        
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
                let starsString = presentationData.strings.Chat_Giveaway_Info_Stars_Stars(Int32(clamping: stars))
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
                let starsString = presentationData.strings.Chat_Giveaway_Info_Stars_Stars(Int32(clamping: stars))
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
            case .notWon:
                result = "**\(presentationData.strings.Chat_Giveaway_Info_DidntWin)**\n\n"
            case let .wonPremium(slug):
                result = "**\(presentationData.strings.Chat_Giveaway_Info_Won("").string)**\n\n"
                actions = [
                    .init(title: presentationData.strings.Chat_Giveaway_Info_ViewPrize, type: .default, action: {
                        openLink(slug)
                    }),
                    .init(title: presentationData.strings.Common_Cancel)
                ]
            case let .wonStars(stars):
                let _ = stars
                result = "**\(presentationData.strings.Chat_Giveaway_Info_Won("").string)**\n\n"
                actions = [
                    .init(title: presentationData.strings.Chat_Giveaway_Info_ViewPrize, type: .default, action: {
                        openLink("")
                    }),
                    .init(title: presentationData.strings.Common_Cancel)
                ]
            }
            
            text = "\(result)\(intro)\(additionalPrizes)\n\n\(ending)"
        }
        
        var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
        content.append(AnyComponentWithIdentity(
            id: "title",
            component: AnyComponent(
                AlertTitleComponent(title: title)
            )
        ))
        content.append(AnyComponentWithIdentity(
            id: "text",
            component: AnyComponent(
                AlertTextComponent(content: .plain(text))
            )
        ))
        if let warning {
            content.append(AnyComponentWithIdentity(
                id: "warning",
                component: AnyComponent(
                    AlertTextComponent(content: .plain(warning), color: .destructive, style: .background(.bold))
                )
            ))
        }
        
        var effectiveUpdatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
        if let updatedPresentationData {
            effectiveUpdatedPresentationData = updatedPresentationData
        } else {
            effectiveUpdatedPresentationData = (presentationData, context.sharedContext.presentationData)
        }
        
        let alertController = AlertScreen(
            configuration: AlertScreen.Configuration(actionAlignment: .vertical),
            content: content,
            actions: actions,
            updatedPresentationData: effectiveUpdatedPresentationData
        )
        present(alertController)
    })
}
