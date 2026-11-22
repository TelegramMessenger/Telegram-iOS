import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AsyncDisplayKit
import Display
import UndoUI
import AccountContext
import ChatControllerInteraction
import TelegramStringFormatting

extension ChatControllerImpl {
    func displaySendReactionRestrictedToast() {
        self.controllerInteraction?.presentControllerInCurrent(UndoOverlayController(
            presentationData: self.presentationData,
            content: .banned(text: self.presentationData.strings.Chat_SendReactionRestricted),
            elevatedLayout: false,
            position: .bottom,
            animateInAsReplacement: false,
            action: { _ in return true }
        ), nil)
    }
    
    func displayPollRestrictedToast(messageId: EngineMessage.Id) {
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Messages.Message(id: messageId),
            TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] message, peer in
            guard let self, let message, let peer else {
                return
            }
            let peerName = peer.compactDisplayTitle
            guard let poll = message.media.first(where: { $0 is TelegramMediaPoll }) as? TelegramMediaPoll else {
                return
            }

            var accountCountry = ""
            if let data = self.context.currentAppConfiguration.with({ $0 }).data, let country = data["phone_country_iso2"] as? String {
                accountCountry = (country)
            }
            var text = ""
            if !poll.countries.isEmpty && !poll.countries.contains(accountCountry) {
                let locale = localeWithStrings(self.presentationData.strings)
                let countryNames = poll.countries.map { id in
                    if id == "FT" {
                        return "Fragment"
                    } else if let countryName = locale.localizedString(forRegionCode: id) {
                        return countryName
                    } else {
                        return id
                    }
                }
                var countries: String = ""
                if countryNames.count == 1, let country = countryNames.first {
                    countries = "**\(country)**"
                } else {
                    for i in 0 ..< countryNames.count {
                        countries.append("**\(countryNames[i])**")
                        if i == countryNames.count - 2 {
                            countries.append(self.presentationData.strings.Chat_Poll_Restriction_Country_CountriesLastDelimiter)
                        } else if i < countryNames.count - 2 {
                            countries.append(self.presentationData.strings.Chat_Poll_Restriction_Country_CountriesDelimiter)
                        }
                    }
                }
                if poll.restrictToSubscribers {
                    text = self.presentationData.strings.Chat_Poll_Restriction_SubscribersCountry(peerName, countries).string
                } else {
                    text = self.presentationData.strings.Chat_Poll_Restriction_Country(countries).string
                }
            } else {
                if case let .channel(channel) = peer, case .member = channel.participationStatus {
                    text = self.presentationData.strings.Chat_Poll_Restriction_Subscribers_TimeLimit
                } else {
                    text = self.presentationData.strings.Chat_Poll_Restriction_Subscribers(peerName).string
                }
            }
            let controller = UndoOverlayController(
                presentationData: self.presentationData,
                content: .banned(text: text),
                position: .bottom,
                action: { _ in return true }
            )
            self.controllerInteraction?.presentControllerInCurrent(controller, nil)
        })
    }

    func displayPostedScheduledMessagesToast(ids: [EngineMessage.Id]) {
        let timestamp = CFAbsoluteTimeGetCurrent()
        if self.lastPostedScheduledMessagesToastTimestamp + 0.4 >= timestamp {
            return
        }
        self.lastPostedScheduledMessagesToastTimestamp = timestamp
        
        guard case .scheduledMessages = self.presentationInterfaceState.subject else {
            return
        }
        
        let _ = (self.context.engine.data.get(
            EngineDataList(ids.map(TelegramEngine.EngineData.Item.Messages.Message.init(id:)))
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] messages in
            guard let self else {
                return
            }
            let messages = messages.compactMap { $0 }
            
            var found: (message: EngineMessage, file: TelegramMediaFile)?
            outer: for message in messages {
                for media in message.media {
                    if let file = media as? TelegramMediaFile, file.isVideo {
                        found = (message, file)
                        break outer
                    }
                }
            }
            
            guard let (message, file) = found else {
                return
            }
            
            guard case let .loaded(isEmpty, _) = self.chatDisplayNode.historyNode.currentHistoryState else {
                return
            }
            
            if isEmpty {
                if let navigationController = self.navigationController as? NavigationController, let topController = navigationController.viewControllers.first(where: { c in
                    if let c = c as? ChatController, c.chatLocation == self.chatLocation {
                        return true
                    }
                    return false
                }) as? ChatControllerImpl {
                    topController.controllerInteraction?.presentControllerInCurrent(UndoOverlayController(
                        presentationData: self.presentationData,
                        content: .media(
                            context: self.context,
                            file: .message(message: MessageReference(message._asMessage()), media: file),
                            title: nil,
                            text: self.presentationData.strings.Chat_ToastVideoPublished_Title,
                            undoText: nil,
                            customAction: nil
                        ),
                        elevatedLayout: false,
                        position: .top,
                        animateInAsReplacement: false,
                        action: { _ in false }
                    ), nil)
                    
                    self.dismiss()
                }
            } else {
                self.controllerInteraction?.presentControllerInCurrent(UndoOverlayController(
                    presentationData: self.presentationData,
                    content: .media(
                        context: self.context,
                        file: .message(message: MessageReference(message._asMessage()), media: file),
                        title: nil,
                        text: self.presentationData.strings.Chat_ToastVideoPublished_Title,
                        undoText: self.presentationData.strings.Chat_ToastVideoPublished_Action,
                        customAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.dismiss()
                        }
                    ),
                    elevatedLayout: false,
                    position: .top,
                    animateInAsReplacement: false,
                    action: { _ in false }
                ), nil)
            }
        })
    }
}
