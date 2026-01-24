import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import TelegramCore
import Postbox
import PeerInfoUI
import TextFormat
import PhoneNumberFormat
import SwiftSignalKit
import TelegramStringFormatting
import AsyncDisplayKit
import LocationResources
import AttachmentUI
import WebUI
import AvatarNode
import PeerNameColorItem
import BoostLevelIconComponent

private let enabledPublicBioEntities: EnabledEntityTypes = [.allUrl, .mention, .hashtag]
private let enabledPrivateBioEntities: EnabledEntityTypes = [.internalUrl, .mention, .hashtag]

enum InfoSection: Int, CaseIterable {
    case groupLocation
    case calls
    case personalChannel
    case peerInfo
    case balances
    case permissions
    case peerInfoTrailing
    case peerSettings
    case peerMembers
    case channelMonoforum
    case botAffiliateProgram
}

func infoItems(data: PeerInfoScreenData?, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction, nearbyPeerDistance: Int32?, reactionSourceMessageId: MessageId?, callMessages: [Message], chatLocation: ChatLocation, isOpenedFromChat: Bool, isMyProfile: Bool) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    var currentPeerInfoSection: InfoSection = .peerInfo
        
    var items: [InfoSection: [PeerInfoScreenItem]] = [:]
    for section in InfoSection.allCases {
        items[section] = []
    }
    
    let bioContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBioContextMenu(node, gesture)
    }
    let noteContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openNoteContextMenu(node, gesture)
    }
    let bioLinkAction: (TextLinkItemActionType, TextLinkItem, ASDisplayNode, CGRect?, Promise<Bool>?) -> Void = { action, item, _, _, _ in
        interaction.performBioLinkAction(action, item)
    }
    let workingHoursContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openWorkingHoursContextMenu(node, gesture)
    }
    let businessLocationContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBusinessLocationContextMenu(node, gesture)
    }
    let birthdayContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBirthdayContextMenu(node, gesture)
    }
    
    if let user = data.peer as? TelegramUser {
        let ItemCallList = 1000
        let ItemPersonalChannelHeader = 2000
        let ItemPersonalChannel = 2001
        let ItemPhoneNumber = 3000
        let ItemUsername = 3001
        let ItemBirthdate = 3002
        let ItemAbout = 3003
        let ItemNote = 3004
        let ItemAppFooter = 3005
        let ItemAffiliate = 4000
        let ItemAffiliateInfo = 4001
        let ItemBusinessHours = 5000
        let ItemLocation = 5001
        let ItemSendMessage = 6000
        let ItemReport = 6001
        let ItemAddToContacts = 6002
        let ItemBlock = 6003
        let ItemEncryptionKey = 6004
        let ItemBalanceHeader = 7000
        let ItemBalanceTon = 7001
        let ItemBalanceStars = 7002
        let ItemBotPermissionsHeader = 8000
        let ItemBotPermissionsEmojiStatus = 8001
        let ItemBotPermissionsLocation = 8002
        let ItemBotPermissionsBiometry = 8003
        let ItemBotSettings = 9000
        let ItemBotReport = 9001
        let ItemBotAddToChat = 9002
        let ItemBotAddToChatInfo = 9003
        let ItemVerification = 9004
        
        if !callMessages.isEmpty {
            items[.calls]!.append(PeerInfoScreenCallListItem(id: ItemCallList, messages: callMessages))
        }
        
        if let personalChannel = data.personalChannel {
            let peerId = personalChannel.peer.peerId
            var label: String?
            if let subscriberCount = personalChannel.subscriberCount {
                label = presentationData.strings.Conversation_StatusSubscribers(Int32(subscriberCount))
            }
            items[.personalChannel]?.append(PeerInfoScreenHeaderItem(id: ItemPersonalChannelHeader, text: presentationData.strings.Profile_PersonalChannelSectionTitle, label: label))
            items[.personalChannel]?.append(PeerInfoScreenPersonalChannelItem(id: ItemPersonalChannel, context: context, data: personalChannel, controller: { [weak interaction] in
                guard let interaction else {
                    return nil
                }
                return interaction.getController()
            }, action: { [weak interaction] in
                guard let interaction else {
                    return
                }
                interaction.openChat(peerId)
            }))
        }
        
        if let phone = user.phone {
            let formattedPhone = formatPhoneNumber(context: context, number: phone)
            let label: String
            if formattedPhone.hasPrefix("+888 ") {
                label = presentationData.strings.UserInfo_AnonymousNumberLabel
            } else {
                label = presentationData.strings.ContactInfo_PhoneLabelMobile
            }
            items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemPhoneNumber, label: label, text: formattedPhone, textColor: .accent, action: { node, progress in
                interaction.openPhone(phone, node, nil, progress)
            }, longTapAction: nil, contextAction: { node, gesture, _ in
                interaction.openPhone(phone, node, gesture, nil)
            }, requestLayout: { animated in
                interaction.requestLayout(animated)
            }))
        }
        if let mainUsername = user.addressName {
            var additionalUsernames: String?
            let usernames = user.usernames.filter { $0.isActive && $0.username != mainUsername }
            if !usernames.isEmpty {
                additionalUsernames = presentationData.strings.Profile_AdditionalUsernames(String(usernames.map { "@\($0.username)" }.joined(separator: ", "))).string
            }
            
            items[currentPeerInfoSection]!.append(
                PeerInfoScreenLabeledValueItem(
                    id: ItemUsername,
                    label: presentationData.strings.Profile_Username,
                    text: "@\(mainUsername)",
                    additionalText: additionalUsernames,
                    textColor: .accent,
                    icon: .qrCode,
                    action: { _, progress in
                        interaction.openUsername(mainUsername, true, progress)
                    }, linkItemAction: { type, item, _, _, progress in
                        if case .tap = type {
                            if case let .mention(username) = item {
                                interaction.openUsername(String(username[username.index(username.startIndex, offsetBy: 1)...]), false, progress)
                            }
                        }
                    }, iconAction: {
                        interaction.openQrCode()
                    }, contextAction: { node, gesture, _ in
                        interaction.openUsernameContextMenu(node, gesture)
                    }, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }
                )
            )
        }
        
        if let cachedData = data.cachedData as? CachedUserData {
            if let birthday = cachedData.birthday {
                var hasBirthdayToday = false
                let today = Calendar.current.dateComponents(Set([.day, .month]), from: Date())
                if today.day == Int(birthday.day) && today.month == Int(birthday.month) {
                    hasBirthdayToday = true
                }
                
                var birthdayAction: ((ASDisplayNode, Promise<Bool>?) -> Void)?
                if isMyProfile {
                    birthdayAction = { node, _ in
                        birthdayContextAction(node, nil, nil)
                    }
                } else if hasBirthdayToday && cachedData.disallowedGifts != TelegramDisallowedGifts.All {
                    birthdayAction = { _, _ in
                        interaction.openPremiumGift()
                    }
                }
                
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemBirthdate, context: context, label: hasBirthdayToday ? presentationData.strings.UserInfo_BirthdayToday : presentationData.strings.UserInfo_Birthday, text: stringForCompactBirthday(birthday, strings: presentationData.strings, showAge: true), textColor: .primary, leftIcon: hasBirthdayToday ? .birthday : nil, icon: hasBirthdayToday ? .premiumGift : nil, action: birthdayAction, longTapAction: nil, iconAction: {
                    interaction.openPremiumGift()
                }, contextAction: birthdayContextAction, requestLayout: { _ in
                }))
            }
            
            var hasAbout = false
            if let about = cachedData.about, !about.isEmpty {
                hasAbout = true
            }
            var hasNote = false
            if let note = cachedData.note, !note.text.isEmpty {
                hasNote = true
            }
            
            var hasWebApp = false
            if let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                hasWebApp = true
            }
            
            if user.isFake {
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: "", text: user.botInfo != nil ? presentationData.strings.UserInfo_FakeBotWarning : presentationData.strings.UserInfo_FakeUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledPrivateBioEntities : []), action: nil, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
            } else if user.isScam {
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo, text: user.botInfo != nil ? presentationData.strings.UserInfo_ScamBotWarning : presentationData.strings.UserInfo_ScamUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledPrivateBioEntities : []), action: nil, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
            } else if hasAbout || hasNote || hasWebApp {
                var actionButton: PeerInfoScreenLabeledValueItem.Button?
                if hasWebApp {
                    actionButton = PeerInfoScreenLabeledValueItem.Button(title: presentationData.strings.PeerInfo_OpenAppButton, action: {
                        guard let parentController = interaction.getController() else {
                            return
                        }
                        
                        if let navigationController = parentController.navigationController as? NavigationController, let minimizedContainer = navigationController.minimizedContainer {
                            for controller in minimizedContainer.controllers {
                                if let controller = controller as? AttachmentController, let mainController = controller.mainController as? WebAppController, mainController.botId == user.id && mainController.source == .generic {
                                    navigationController.maximizeViewController(controller, animated: true)
                                    return
                                }
                            }
                        }
                        
                        context.sharedContext.openWebApp(
                            context: context,
                            parentController: parentController,
                            updatedPresentationData: nil,
                            botPeer: .user(user),
                            chatPeer: nil,
                            threadId: nil,
                            buttonText: "",
                            url: "",
                            simple: true,
                            source: .generic,
                            skipTermsOfService: true,
                            payload: nil,
                            verifyAgeCompletion: nil
                        )
                    })
                }
                
                if hasAbout || hasWebApp {
                    var label: String = ""
                    if let about = cachedData.about, !about.isEmpty {
                        label = user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo
                    }
                    items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: label, text: cachedData.about ?? "", textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.isPremium ? enabledPublicBioEntities : enabledPrivateBioEntities), action: isMyProfile ? { node, _ in
                        bioContextAction(node, nil, nil)
                    } : nil, linkItemAction: bioLinkAction, button: actionButton, contextAction: bioContextAction, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }))
                }
                
                if let note = cachedData.note, !note.text.isEmpty {
                    var entities = note.entities
                    if context.isPremium {
                        entities = generateTextEntities(note.text, enabledTypes: [.mention, .hashtag, .allUrl], currentEntities: entities)
                    }
                    items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemNote, label: presentationData.strings.PeerInfo_Notes, rightLabel: presentationData.strings.PeerInfo_NotesInfo, text: note.text, entities: entities, handleSpoilers: true, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: []), action: nil, linkItemAction: bioLinkAction, button: nil, contextAction: noteContextAction, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }))
                }
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemAppFooter, text: presentationData.strings.PeerInfo_AppFooterAdmin, linkAction: { action in
                        if case let .tap(url) = action {
                            context.sharedContext.applicationBindings.openUrl(url)
                        }
                    }))
                    
                    currentPeerInfoSection = .peerInfoTrailing
                } else if actionButton != nil {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemAppFooter, text: presentationData.strings.PeerInfo_AppFooter, linkAction: { action in
                        if case let .tap(url) = action {
                            context.sharedContext.applicationBindings.openUrl(url)
                        }
                    }))
                    
                    currentPeerInfoSection = .peerInfoTrailing
                }
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                } else {
                    if let starRefProgram = cachedData.starRefProgram, starRefProgram.endDate == nil {
                        var canJoinRefProgram = false
                        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_connect_allowed"] {
                            if let value = value as? Double {
                                canJoinRefProgram = value != 0.0
                            } else if let value = value as? Bool {
                                canJoinRefProgram = value
                            }
                        }
                        
                        if canJoinRefProgram {
                            if items[.botAffiliateProgram] == nil {
                                items[.botAffiliateProgram] = []
                            }
                            let programTitleValue: String
                            programTitleValue = "\(formatPermille(starRefProgram.commissionPermille))%"
                            items[.botAffiliateProgram]!.append(PeerInfoScreenDisclosureItem(id: ItemAffiliate, label: .labelBadge(programTitleValue), additionalBadgeLabel: nil, text: presentationData.strings.PeerInfo_ItemAffiliateProgram_Title, icon: PresentationResourcesSettings.affiliateProgram, action: {
                                interaction.editingOpenAffiliateProgram()
                            }))
                            items[.botAffiliateProgram]!.append(PeerInfoScreenCommentItem(id: ItemAffiliateInfo, text: presentationData.strings.PeerInfo_ItemAffiliateProgram_Footer(EnginePeer.user(user).compactDisplayTitle, formatPermille(starRefProgram.commissionPermille)).string))
                        }
                    }
                }
            }
            
            if let businessHours = cachedData.businessHours {
                items[currentPeerInfoSection]!.append(PeerInfoScreenBusinessHoursItem(id: ItemBusinessHours, label: presentationData.strings.PeerInfo_BusinessHours_Label, businessHours: businessHours, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }, longTapAction: nil, contextAction: workingHoursContextAction))
            }
            
            if let businessLocation = cachedData.businessLocation {
                if let coordinates = businessLocation.coordinates {
                    let imageSignal = chatMapSnapshotImage(engine: context.engine, resource: MapSnapshotMediaResource(latitude: coordinates.latitude, longitude: coordinates.longitude, width: 90, height: 90))
                    items[currentPeerInfoSection]!.append(PeerInfoScreenAddressItem(
                        id: ItemLocation,
                        label: presentationData.strings.PeerInfo_Location_Label,
                        text: businessLocation.address,
                        imageSignal: imageSignal,
                        action: {
                            interaction.openLocation()
                        },
                        contextAction: businessLocationContextAction
                    ))
                } else {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenAddressItem(
                        id: ItemLocation,
                        label: presentationData.strings.PeerInfo_Location_Label,
                        text: businessLocation.address,
                        imageSignal: nil,
                        action: nil,
                        contextAction: businessLocationContextAction
                    ))
                }
            }
        }
        
        if !isMyProfile {
            if let reactionSourceMessageId = reactionSourceMessageId, !data.isContact {
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemSendMessage, text: presentationData.strings.UserInfo_SendMessage, action: {
                    interaction.openChat(nil)
                }))
                
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemReport, text: presentationData.strings.ReportPeer_BanAndReport, color: .destructive, action: {
                    interaction.openReport(.reaction(reactionSourceMessageId))
                }))
            } else if let _ = nearbyPeerDistance {
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemSendMessage, text: presentationData.strings.UserInfo_SendMessage, action: {
                    interaction.openChat(nil)
                }))
                
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemReport, text: presentationData.strings.ReportPeer_Report, color: .destructive, action: {
                    interaction.openReport(.user)
                }))
            } else {
                if !data.isContact {
                    if user.botInfo == nil {
                        items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemAddToContacts, text: presentationData.strings.PeerInfo_AddToContacts, action: {
                            interaction.openAddContact()
                        }))
                    }
                }
                
                var isBlocked = false
                if let cachedData = data.cachedData as? CachedUserData, cachedData.isBlocked {
                    isBlocked = true
                }
                
                if isBlocked {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemBlock, text: user.botInfo != nil ? presentationData.strings.Bot_Unblock : presentationData.strings.Conversation_Unblock, action: {
                        interaction.updateBlocked(false)
                    }))
                } else {
                    if user.flags.contains(.isSupport) || data.isContact {
                    } else {
                        if user.botInfo == nil {
                            items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemBlock, text: presentationData.strings.Conversation_BlockUser, color: .destructive, action: {
                                interaction.updateBlocked(true)
                            }))
                        }
                    }
                }
                
                if let encryptionKeyFingerprint = data.encryptionKeyFingerprint {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenDisclosureEncryptionKeyItem(id: ItemEncryptionKey, text: presentationData.strings.Profile_EncryptionKey, fingerprint: encryptionKeyFingerprint, action: {
                        interaction.openEncryptionKey()
                    }))
                }
                                
                let revenueBalance = data.revenueStatsState?.balances.currentBalance.amount.value ?? 0
                let overallRevenueBalance = data.revenueStatsState?.balances.overallRevenue.amount.value ?? 0
                
                let starsBalance = data.starsRevenueStatsState?.balances.currentBalance.amount ?? StarsAmount.zero
                let overallStarsBalance = data.starsRevenueStatsState?.balances.overallRevenue.amount ?? StarsAmount.zero
                
                if overallRevenueBalance > 0 || overallStarsBalance > StarsAmount.zero {
                    items[.balances]!.append(PeerInfoScreenHeaderItem(id: ItemBalanceHeader, text: presentationData.strings.PeerInfo_BotBalance_Title))
                    if overallRevenueBalance > 0 {
                        let string = "*\(formatTonAmountText(revenueBalance, dateTimeFormat: presentationData.dateTimeFormat))"
                        let attributedString = NSMutableAttributedString(string: string, font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize), textColor: presentationData.theme.list.itemSecondaryTextColor)
                        if let range = attributedString.string.range(of: "*") {
                            attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .ton(tinted: false)), range: NSRange(range, in: attributedString.string))
                            attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                        }
                        items[.balances]!.append(PeerInfoScreenDisclosureItem(id: ItemBalanceTon, label: .attributedText(attributedString), text: presentationData.strings.PeerInfo_BotBalance_Ton, icon: PresentationResourcesSettings.ton, action: {
                            interaction.editingOpenRevenue()
                        }))
                    }

                    if overallStarsBalance > StarsAmount.zero {
                        let formattedLabel = formatStarsAmountText(starsBalance, dateTimeFormat: presentationData.dateTimeFormat)
                        let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                        let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                        let labelColor = presentationData.theme.list.itemSecondaryTextColor
                        let attributedString = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                        attributedString.insert(NSAttributedString(string: "*", font: labelFont, textColor: labelColor), at: 0)
                        
                        if let range = attributedString.string.range(of: "*") {
                            attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedString.string))
                            attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                        }
                        items[.balances]!.append(PeerInfoScreenDisclosureItem(id: ItemBalanceStars, label: .attributedText(attributedString), text: presentationData.strings.PeerInfo_BotBalance_Stars, icon: PresentationResourcesSettings.stars, action: {
                            interaction.editingOpenStars()
                        }))
                    }
                }
                
                if let _ = user.botInfo {
                    var canManageEmojiStatus = false
                    if let cachedData = data.cachedData as? CachedUserData, cachedData.flags.contains(.botCanManageEmojiStatus) {
                        canManageEmojiStatus = true
                    }
                    if canManageEmojiStatus || data.webAppPermissions?.emojiStatus?.isRequested == true {
                        items[.permissions]!.append(PeerInfoScreenSwitchItem(id: ItemBotPermissionsEmojiStatus, text: presentationData.strings.PeerInfo_Permissions_EmojiStatus, value: canManageEmojiStatus, icon: UIImage(bundleImageName: "Chat/Info/Status"), isLocked: false, toggled: { value in
                            let _ = (context.engine.peers.toggleBotEmojiStatusAccess(peerId: user.id, enabled: value)
                                     |> deliverOnMainQueue).startStandalone()
                            
                            let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: user.id) { current in
                                return WebAppPermissionsState(location: current?.location, emojiStatus: WebAppPermissionsState.EmojiStatus(isRequested: true))
                            }.startStandalone()
                        }))
                    }
                    if data.webAppPermissions?.location?.isRequested == true || data.webAppPermissions?.location?.isAllowed == true {
                        items[.permissions]!.append(PeerInfoScreenSwitchItem(id: ItemBotPermissionsLocation, text: presentationData.strings.PeerInfo_Permissions_Geolocation, value: data.webAppPermissions?.location?.isAllowed ?? false, icon: UIImage(bundleImageName: "Chat/Info/Location"), isLocked: false, toggled: { value in
                            let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: user.id) { current in
                                return WebAppPermissionsState(location: WebAppPermissionsState.Location(isRequested: true, isAllowed: value), emojiStatus: current?.emojiStatus)
                            }.startStandalone()
                        }))
                    }
                    if !"".isEmpty {
                        items[.permissions]!.append(PeerInfoScreenSwitchItem(id: ItemBotPermissionsBiometry, text: presentationData.strings.PeerInfo_Permissions_Biometry, value: true, icon: UIImage(bundleImageName: "Settings/Menu/TouchId"), isLocked: false, toggled: { value in
                          
                        }))
                    }
                    
                    if !items[.permissions]!.isEmpty {
                        items[.permissions]!.insert(PeerInfoScreenHeaderItem(id: ItemBotPermissionsHeader, text: presentationData.strings.PeerInfo_Permissions_Title), at: 0)
                    }
                }
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenDisclosureItem(id: ItemBotSettings, label: .none, text: presentationData.strings.Bot_Settings, icon: UIImage(bundleImageName: "Chat/Info/SettingsIcon"), action: {
                        interaction.openEditing()
                    }))
                }
                
                if let botInfo = user.botInfo, !botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemBotReport, text: presentationData.strings.ReportPeer_Report, action: {
                        interaction.openReport(.default)
                    }))
                }
                                
                if let verification = (data.cachedData as? CachedUserData)?.verification {
                    let description: String
                    let descriptionString = verification.description
                    let entities = generateTextEntities(descriptionString, enabledTypes: [.allUrl])
                    if let entity = entities.first {
                        let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                        let url = (descriptionString as NSString).substring(with: range)
                        description = descriptionString.replacingOccurrences(of: url, with: "[\(url)](\(url))")
                    } else {
                        description = descriptionString
                    }
                    let attributedPrefix = NSMutableAttributedString(string: "  ")
                    attributedPrefix.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: verification.iconFileId, file: nil), range: NSMakeRange(0, 1))
                    
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemVerification, text: description, attributedPrefix: attributedPrefix, useAccentLinkColor: false, linkAction: { action in
                        if case let .tap(url) = action, let navigationController = interaction.getController()?.navigationController as? NavigationController {
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                        }
                    }))
                } else if let botInfo = user.botInfo, botInfo.flags.contains(.worksWithGroups) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: ItemBotAddToChat, text: presentationData.strings.Bot_AddToChat, color: .accent, action: {
                        interaction.openAddBotToGroup()
                    }))
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemBotAddToChatInfo, text: presentationData.strings.Bot_AddToChatInfo))
                }
            }
        }
    } else if let channel = data.peer as? TelegramChannel {
        let ItemUsername = 1
        let ItemUsernameInfo = 2
        let ItemAbout = 3
        let ItemLocationHeader = 4
        let ItemLocation = 5
        let ItemAdmins = 6
        let ItemMembers = 7
        let ItemMemberRequests = 8
        let ItemBalance = 9
        let ItemEdit = 10
        let ItemPeerPersonalChannel = 11
        
        if let _ = data.threadData {
            let mainUsername: String
            if let addressName = channel.addressName {
                mainUsername = addressName
            } else {
                mainUsername = "c/\(channel.id.id._internalGetInt64Value())"
            }
            
            var threadId: Int64 = 0
            if case let .replyThread(message) = chatLocation {
                threadId = message.threadId
            }
            
            let linkText = "https://t.me/\(mainUsername)/\(threadId)"
            
            items[currentPeerInfoSection]!.append(
                PeerInfoScreenLabeledValueItem(
                    id: ItemUsername,
                    label: presentationData.strings.Channel_LinkItem,
                    text: linkText,
                    textColor: .accent,
                    icon: .qrCode,
                    action: { _, progress in
                        interaction.openUsername(linkText, true, progress)
                    }, longTapAction: { sourceNode in
                        interaction.openPeerInfoContextMenu(.link(customLink: linkText), sourceNode, nil)
                    }, linkItemAction: { type, item, _, _, progress in
                        if case .tap = type {
                            if case let .mention(username) = item {
                                interaction.openUsername(String(username.suffix(from: username.index(username.startIndex, offsetBy: 1))), false, progress)
                            }
                        }
                    }, iconAction: {
                        interaction.openQrCode()
                    }, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }
                )
            )
            if let _ = channel.addressName {
                
            } else {
                items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemUsernameInfo, text: presentationData.strings.PeerInfo_PrivateShareLinkInfo))
            }
        } else {
            if let location = (data.cachedData as? CachedChannelData)?.peerGeoLocation {
                items[.groupLocation]!.append(PeerInfoScreenHeaderItem(id: ItemLocationHeader, text: presentationData.strings.GroupInfo_Location.uppercased()))
                
                let imageSignal = chatMapSnapshotImage(engine: context.engine, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
                items[.groupLocation]!.append(PeerInfoScreenAddressItem(
                    id: ItemLocation,
                    label: "",
                    text: location.address.replacingOccurrences(of: ", ", with: "\n"),
                    imageSignal: imageSignal,
                    action: {
                        interaction.openLocation()
                    }
                ))
            }
            
            if let mainUsername = channel.addressName {
                var additionalUsernames: String?
                let usernames = channel.usernames.filter { $0.isActive && $0.username != mainUsername }
                if !usernames.isEmpty {
                    additionalUsernames = presentationData.strings.Profile_AdditionalUsernames(String(usernames.map { "@\($0.username)" }.joined(separator: ", "))).string
                }
                
                items[currentPeerInfoSection]!.append(
                    PeerInfoScreenLabeledValueItem(
                        id: ItemUsername,
                        label: presentationData.strings.Channel_LinkItem,
                        text: "https://t.me/\(mainUsername)",
                        additionalText: additionalUsernames,
                        textColor: .accent,
                        icon: .qrCode,
                        action: { _, progress in
                            interaction.openUsername(mainUsername, true, progress)
                        }, longTapAction: { sourceNode in
                            interaction.openPeerInfoContextMenu(.link(customLink: nil), sourceNode, nil)
                        }, linkItemAction: { type, item, sourceNode, sourceRect, progress in
                            if case .tap = type {
                                if case let .mention(username) = item {
                                    interaction.openUsername(String(username.suffix(from: username.index(username.startIndex, offsetBy: 1))), false, progress)
                                }
                            } else if case .longTap = type {
                                if case let .mention(username) = item {
                                    interaction.openPeerInfoContextMenu(.link(customLink: username), sourceNode, sourceRect)
                                }
                            }
                        }, iconAction: {
                            interaction.openQrCode()
                        }, requestLayout: { animated in
                            interaction.requestLayout(animated)
                        }
                    )
                )
            }
            if let cachedData = data.cachedData as? CachedChannelData {
                let aboutText: String?
                if channel.isFake {
                    if case .broadcast = channel.info {
                        aboutText = presentationData.strings.ChannelInfo_FakeChannelWarning
                    } else {
                        aboutText = presentationData.strings.GroupInfo_FakeGroupWarning
                    }
                } else if channel.isScam {
                    if case .broadcast = channel.info {
                        aboutText = presentationData.strings.ChannelInfo_ScamChannelWarning
                    } else {
                        aboutText = presentationData.strings.GroupInfo_ScamGroupWarning
                    }
                } else if let about = cachedData.about, !about.isEmpty {
                    aboutText = about
                } else {
                    aboutText = nil
                }
                
                if let aboutText = aboutText {
                    var enabledEntities = enabledPublicBioEntities
                    if case .group = channel.info {
                        enabledEntities = enabledPrivateBioEntities
                    }
                    items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: presentationData.strings.Channel_Info_Description, text: aboutText, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledEntities), action: isMyProfile ? { node, _ in
                        bioContextAction(node, nil, nil)
                    } : nil, linkItemAction: bioLinkAction, contextAction: bioContextAction, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }))
                }
                
                if let verification = (data.cachedData as? CachedChannelData)?.verification {
                    let description: String
                    let descriptionString = verification.description
                    let entities = generateTextEntities(descriptionString, enabledTypes: [.allUrl])
                    if let entity = entities.first {
                        let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                        let url = (descriptionString as NSString).substring(with: range)
                        description = descriptionString.replacingOccurrences(of: url, with: "[\(url)](\(url))")
                    } else {
                        description = descriptionString
                    }
                    
                    let attributedPrefix = NSMutableAttributedString(string: "  ")
                    attributedPrefix.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: verification.iconFileId, file: nil), range: NSMakeRange(0, 1))
                    
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: 800, text: description, attributedPrefix: attributedPrefix, useAccentLinkColor: false, linkAction: { action in
                        if case let .tap(url) = action, let navigationController = interaction.getController()?.navigationController as? NavigationController {
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                        }
                    }))
                }
                
                if case .broadcast = channel.info {
                    var canEditMembers = false
                    if channel.hasPermission(.banMembers) {
                        canEditMembers = true
                    }
                    if canEditMembers {
                        if channel.adminRights != nil || channel.flags.contains(.isCreator) {
                            let adminCount = cachedData.participantsSummary.adminCount ?? 0
                            let memberCount = cachedData.participantsSummary.memberCount ?? 0
                            
                            items[.peerMembers]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, label: .text("\(adminCount == 0 ? "" : "\(presentationStringsFormattedNumber(adminCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Administrators, icon: UIImage(bundleImageName: "Chat/Info/GroupAdminsIcon"), action: {
                                interaction.openParticipantsSection(.admins)
                            }))
                            items[.peerMembers]!.append(PeerInfoScreenDisclosureItem(id: ItemMembers, label: .text("\(memberCount == 0 ? "" : "\(presentationStringsFormattedNumber(memberCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.Channel_Info_Subscribers, icon: UIImage(bundleImageName: "Chat/Info/GroupMembersIcon"), action: {
                                interaction.openParticipantsSection(.members)
                            }))
                            
                            if let count = data.requests?.count, count > 0 {
                                items[.peerMembers]!.append(PeerInfoScreenDisclosureItem(id: ItemMemberRequests, label: .badge(presentationStringsFormattedNumber(count, presentationData.dateTimeFormat.groupingSeparator), presentationData.theme.list.itemAccentColor), text: presentationData.strings.GroupInfo_MemberRequests, icon: UIImage(bundleImageName: "Chat/Info/GroupRequestsIcon"), action: {
                                    interaction.openParticipantsSection(.memberRequests)
                                }))
                            }
                        }
                    }
                }
                     
                if channel.adminRights != nil || channel.flags.contains(.isCreator) {
                    let section: InfoSection
                    if case .group = channel.info {
                        section = .peerSettings
                    } else {
                        section = .peerMembers
                    }
                    if cachedData.flags.contains(.canViewRevenue) || cachedData.flags.contains(.canViewStarsRevenue) {
                        let revenueBalance = data.revenueStatsState?.balances.currentBalance.amount.value ?? 0
                        let starsBalance = data.starsRevenueStatsState?.balances.currentBalance.amount ?? StarsAmount.zero
                        
                        let overallRevenueBalance = data.revenueStatsState?.balances.overallRevenue.amount.value ?? 0
                        let overallStarsBalance = data.starsRevenueStatsState?.balances.overallRevenue.amount ?? StarsAmount.zero
                        
                        if overallRevenueBalance > 0 || overallStarsBalance > StarsAmount.zero {
                            let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                            let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                            let labelColor = presentationData.theme.list.itemSecondaryTextColor
                            
                            let attributedString = NSMutableAttributedString()
                            if overallRevenueBalance > 0 {
                                attributedString.append(NSAttributedString(string: "#\(formatTonAmountText(revenueBalance, dateTimeFormat: presentationData.dateTimeFormat))", font: labelFont, textColor: labelColor))
                            }
                            if overallStarsBalance > StarsAmount.zero {
                                if !attributedString.string.isEmpty {
                                    attributedString.append(NSAttributedString(string: " ", font: labelFont, textColor: labelColor))
                                }
                                attributedString.append(NSAttributedString(string: "*", font: labelFont, textColor: labelColor))
                                
                                let formattedLabel = formatStarsAmountText(starsBalance, dateTimeFormat: presentationData.dateTimeFormat)
                                let starsAttributedString = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                                attributedString.append(starsAttributedString)
                            }
                            if let range = attributedString.string.range(of: "#") {
                                attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .ton(tinted: false)), range: NSRange(range, in: attributedString.string))
                                attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                            }
                            if let range = attributedString.string.range(of: "*") {
                                attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 1, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedString.string))
                                attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                            }
                            
                            items[section]!.append(PeerInfoScreenDisclosureItem(id: ItemBalance, label: .attributedText(attributedString), text: presentationData.strings.PeerInfo_Bot_Balance, icon: PresentationResourcesSettings.balance, action: {
                                interaction.openStats(.monetization)
                            }))
                        }
                    }
                    
                    let settingsTitle: String
                    switch channel.info {
                    case .broadcast:
                        settingsTitle = presentationData.strings.Channel_Info_Settings
                    case .group:
                        settingsTitle = presentationData.strings.Group_Info_Settings
                    }
                    items[section]!.append(PeerInfoScreenDisclosureItem(id: ItemEdit, label: .none, text: settingsTitle, icon: UIImage(bundleImageName: "Chat/Info/SettingsIcon"), action: {
                        interaction.openEditing()
                    }))
                }
                
                if channel.hasPermission(.manageDirect), let personalChannel = data.personalChannel {
                    let peerId = personalChannel.peer.peerId
                    items[.channelMonoforum]?.append(PeerInfoScreenPersonalChannelItem(id: ItemPeerPersonalChannel, context: context, data: personalChannel, controller: { [weak interaction] in
                        guard let interaction else {
                            return nil
                        }
                        return interaction.getController()
                    }, action: { [weak interaction] in
                        guard let interaction else {
                            return
                        }
                        interaction.openChat(peerId)
                    }))
                }
            }
        }
    } else if let group = data.peer as? TelegramGroup {
        if let cachedData = data.cachedData as? CachedGroupData {
            let aboutText: String?
            if group.isFake {
                aboutText = presentationData.strings.GroupInfo_FakeGroupWarning
            } else if group.isScam {
                aboutText = presentationData.strings.GroupInfo_ScamGroupWarning
            } else if let about = cachedData.about, !about.isEmpty {
                aboutText = about
            } else {
                aboutText = nil
            }
            
            if let aboutText = aboutText {
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: presentationData.strings.Channel_Info_Description, text: aboutText, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledPrivateBioEntities), action: isMyProfile ? { node, _ in
                    bioContextAction(node, nil, nil)
                } : nil, linkItemAction: bioLinkAction, contextAction: bioContextAction, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
            }
        }
    }
    
    if let peer = data.peer, let members = data.members, case let .shortList(_, memberList) = members {
        var canAddMembers = false
        if let group = data.peer as? TelegramGroup {
            switch group.role {
                case .admin, .creator:
                    canAddMembers = true
                case .member:
                    break
            }
            if !group.hasBannedPermission(.banAddMembers) {
                canAddMembers = true
            }
        } else if let channel = data.peer as? TelegramChannel {
            switch channel.info {
            case .broadcast:
                break
            case .group:
                if channel.flags.contains(.isCreator) || channel.hasPermission(.inviteMembers) {
                    canAddMembers = true
                }
            }
        }
        
        if canAddMembers {
            items[.peerMembers]!.append(PeerInfoScreenActionItem(id: 0, text: presentationData.strings.GroupInfo_AddParticipant, color: .accent, icon: UIImage(bundleImageName: "Contact List/AddMemberIcon"), alignment: .peerList, action: {
                interaction.openAddMember()
            }))
        }
        
        for member in memberList {
            let isAccountPeer = member.id == context.account.peerId
            items[.peerMembers]!.append(PeerInfoScreenMemberItem(id: member.id, context: .account(context), enclosingPeer: peer, member: member, isAccount: false, action: isAccountPeer ? nil : { action in
                switch action {
                case .open:
                    interaction.openPeerInfo(member.peer, true)
                case .promote:
                    interaction.performMemberAction(member, .promote)
                case .restrict:
                    interaction.performMemberAction(member, .restrict)
                case .remove:
                    interaction.performMemberAction(member, .remove)
                }
            }, openStories: { sourceView in
                interaction.performMemberAction(member, .openStories(sourceView: sourceView))
            }))
        }
    }
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in InfoSection.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}

func editingItems(data: PeerInfoScreenData?, boostStatus: ChannelBoostStatus?, state: PeerInfoState, chatLocation: ChatLocation, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [(AnyHashable, [PeerInfoScreenItem])] {
    enum Section: Int, CaseIterable {
        case notifications
        case groupLocation
        case peerPublicSettings
        case peerNote
        case peerDataSettings
        case peerVerifySettings
        case peerSettings
        case linkedMonoforum
        case peerAdditionalSettings
        case peerActions
    }
    
    var items: [Section: [PeerInfoScreenItem]] = [:]
    for section in Section.allCases {
        items[section] = []
    }
    
    if let data = data {
        if let user = data.peer as? TelegramUser {
            let ItemNote: AnyHashable = AnyHashable("note_edit")
            let ItemNoteInfo = 1
            
            let ItemSuggestBirthdate = 2
            let ItemSuggestPhoto = 3
            let ItemCustomPhoto = 4
            let ItemReset = 5
            let ItemInfo = 6
            let ItemDelete = 7
            let ItemUsername = 8
            let ItemAffiliateProgram = 9
            
            let ItemVerify = 10
            
            let ItemIntro = 11
            let ItemCommands = 12
            let ItemBotSettings = 13
            let ItemBotInfo = 14
            
            if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text("@\(user.addressName ?? "")"), text: presentationData.strings.PeerInfo_Bot_Username, icon: PresentationResourcesSettings.bot, action: {
                    interaction.editingOpenPublicLinkSetup()
                }))
                
                var canSetupRefProgram = false
                if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_program_allowed"] {
                    if let value = value as? Double {
                        canSetupRefProgram = value != 0.0
                    } else if let value = value as? Bool {
                        canSetupRefProgram = value
                    }
                }
                
                if canSetupRefProgram {
                    let programTitleValue: PeerInfoScreenDisclosureItem.Label
                    if let cachedData = data.cachedData as? CachedUserData, let starRefProgram = cachedData.starRefProgram, starRefProgram.endDate == nil {
                        programTitleValue = .labelBadge("\(formatPermille(starRefProgram.commissionPermille))%")
                    } else {
                        programTitleValue = .text(presentationData.strings.PeerInfo_ItemAffiliateProgram_ValueOff)
                    }
                    items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAffiliateProgram, label: programTitleValue, additionalBadgeLabel: presentationData.strings.Settings_New, text: presentationData.strings.PeerInfo_ItemAffiliateProgram_Title, icon: PresentationResourcesSettings.affiliateProgram, action: {
                        interaction.editingOpenAffiliateProgram()
                    }))
                }
                
                if let cachedUserData = data.cachedData as? CachedUserData, let _ = cachedUserData.botInfo?.verifierSettings {
                    items[.peerVerifySettings]!.append(PeerInfoScreenActionItem(id: ItemVerify, text: presentationData.strings.PeerInfo_VerifyAccounts, icon: UIImage(bundleImageName: "Peer Info/BotVerify"), action: {
                        interaction.editingOpenVerifyAccounts()
                    }))
                }
                                
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemIntro, text: presentationData.strings.PeerInfo_Bot_EditIntro, icon: UIImage(bundleImageName: "Peer Info/BotIntro"), action: {
                    interaction.openPeerMention("botfather", .withBotStartPayload(ChatControllerInitialBotStart(payload: "\(user.addressName ?? "")-intro", behavior: .interactive)))
                }))
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemCommands, text: presentationData.strings.PeerInfo_Bot_EditCommands, icon: UIImage(bundleImageName: "Peer Info/BotCommands"), action: {
                    interaction.openPeerMention("botfather", .withBotStartPayload(ChatControllerInitialBotStart(payload: "\(user.addressName ?? "")-commands", behavior: .interactive)))
                }))
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemBotSettings, text: presentationData.strings.PeerInfo_Bot_ChangeSettings, icon: UIImage(bundleImageName: "Peer Info/BotSettings"), action: {
                    interaction.openPeerMention("botfather", .withBotStartPayload(ChatControllerInitialBotStart(payload: user.addressName ?? "", behavior: .interactive)))
                }))
                items[.peerSettings]!.append(PeerInfoScreenCommentItem(id: ItemBotInfo, text: presentationData.strings.PeerInfo_Bot_BotFatherInfo, linkAction: { _ in
                    interaction.openPeerMention("botfather", .default)
                }))
            } else if !user.flags.contains(.isSupport) {
                let compactName = EnginePeer(user).compactDisplayTitle
                
                if let cachedData = data.cachedData as? CachedUserData {
                    items[.peerNote]!.append(PeerInfoScreenNoteListItem(
                        id: ItemNote,
                        initialValue: chatInputStateStringWithAppliedEntities(cachedData.note?.text ?? "", entities: cachedData.note?.entities ?? []),
                        valueUpdated: { value in
                            interaction.updateNote(value)
                        },
                        requestLayout: { animated in
                            interaction.requestLayout(animated)
                        }
                    ))
                    
                    items[.peerNote]!.append(PeerInfoScreenCommentItem(id: ItemNoteInfo, text: presentationData.strings.PeerInfo_AddNotesInfo))
                    
                    if let _ = cachedData.sendPaidMessageStars {
                        
                    } else {
                        if cachedData.birthday == nil {
                            items[.peerDataSettings]!.append(PeerInfoScreenActionItem(id: ItemSuggestBirthdate, text: presentationData.strings.UserInfo_SuggestBirthdate, color: .accent, icon: UIImage(bundleImageName: "Contact List/AddBirthdayIcon"), action: {
                                interaction.suggestBirthdate()
                            }))
                        }
   
                        items[.peerDataSettings]!.append(PeerInfoScreenActionItem(id: ItemSuggestPhoto, text: presentationData.strings.UserInfo_SuggestPhoto(compactName).string, color: .accent, icon: UIImage(bundleImageName: "Peer Info/SuggestAvatar"), action: {
                            interaction.suggestPhoto()
                        }))
                    }
                }
                
                let setText: String
                if user.photo.first?.isPersonal == true || state.updatingAvatar != nil {
                    setText = presentationData.strings.UserInfo_ChangeCustomPhoto(compactName).string
                } else {
                    setText = presentationData.strings.UserInfo_SetCustomPhoto(compactName).string
                }
                
                items[.peerDataSettings]!.append(PeerInfoScreenActionItem(id: ItemCustomPhoto, text: setText, color: .accent, icon: UIImage(bundleImageName: "Settings/SetAvatar"), action: {
                    interaction.setCustomPhoto()
                }))
                
                if user.photo.first?.isPersonal == true || state.updatingAvatar != nil {
                    var representation: TelegramMediaImageRepresentation?
                    var originalIsVideo: Bool?
                    if let cachedData = data.cachedData as? CachedUserData, case let .known(photo) = cachedData.photo {
                        representation = photo?.representationForDisplayAtSize(PixelDimensions(width: 28, height: 28))
                        originalIsVideo = !(photo?.videoRepresentations.isEmpty ?? true)
                    }
                    
                    let removeText: String
                    if let originalIsVideo {
                        removeText = originalIsVideo ? presentationData.strings.UserInfo_ResetCustomVideo : presentationData.strings.UserInfo_ResetCustomPhoto
                    } else {
                        removeText = user.photo.first?.hasVideo == true ? presentationData.strings.UserInfo_RemoveCustomVideo : presentationData.strings.UserInfo_RemoveCustomPhoto
                    }
                    
                    let imageSignal: Signal<UIImage?, NoError>
                    if let representation, let signal = peerAvatarImage(account: context.account, peerReference: PeerReference(user), authorOfMessage: nil, representation: representation, displayDimensions: CGSize(width: 28.0, height: 28.0)) {
                        imageSignal = signal
                        |> map { data -> UIImage? in
                            return data?.0
                        }
                    } else {
                        imageSignal = peerAvatarCompleteImage(account: context.account, peer: EnginePeer(user), forceProvidedRepresentation: true, representation: representation, size: CGSize(width: 28.0, height: 28.0))
                    }
                    
                    items[.peerDataSettings]!.append(PeerInfoScreenActionItem(id: ItemReset, text: removeText, color: .accent, icon: nil, iconSignal: imageSignal, action: {
                        interaction.resetCustomPhoto()
                    }))
                }
                items[.peerDataSettings]!.append(PeerInfoScreenCommentItem(id: ItemInfo, text: presentationData.strings.UserInfo_CustomPhotoInfo(compactName).string))
            }
            
            if data.isContact {
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemDelete, text: presentationData.strings.UserInfo_DeleteContact, color: .destructive, action: {
                    interaction.requestDeleteContact()
                }))
            }
        } else if let channel = data.peer as? TelegramChannel {
            switch channel.info {
            case .broadcast:
                let ItemUsername = 1
                let ItemPeerColor = 2
                let ItemInviteLinks = 3
                let ItemDiscussionGroup = 4
                let ItemDeleteChannel = 5
                let ItemReactions = 6
                let ItemAdmins = 7
                let ItemMembers = 8
                let ItemMemberRequests = 9
                let ItemStats = 10
                let ItemBanned = 11
                let ItemRecentActions = 12
                let ItemAffiliatePrograms = 13
                let ItemPostSuggestionsSettings = 14
                let ItemPeerAutoTranslate = 15
                
                let isCreator = channel.flags.contains(.isCreator)
                
                if isCreator {
                    let linkText: String
                    if let _ = channel.addressName {
                        linkText = presentationData.strings.Channel_Setup_TypePublic
                    } else {
                        linkText = presentationData.strings.Channel_Setup_TypePrivate
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(linkText), text: presentationData.strings.Channel_TypeSetup_Title, icon: UIImage(bundleImageName: "Chat/Info/GroupChannelIcon"), action: {
                        interaction.editingOpenPublicLinkSetup()
                    }))
                }

                if (isCreator && (channel.addressName?.isEmpty ?? true)) || (!channel.flags.contains(.isCreator) && channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                    let invitesText: String
                    if let count = data.invitations?.count, count > 0 {
                        invitesText = "\(count)"
                    } else {
                        invitesText = ""
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemInviteLinks, label: .text(invitesText), text: presentationData.strings.GroupInfo_InviteLinks, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                        interaction.editingOpenInviteLinksSetup()
                    }))
                }
                
                if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                    let discussionGroupTitle: String
                    if let _ = data.cachedData as? CachedChannelData {
                        if let peer = data.linkedDiscussionPeer {
                            if let addressName = peer.addressName, !addressName.isEmpty {
                                discussionGroupTitle = "@\(addressName)"
                            } else {
                                discussionGroupTitle = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            }
                        } else {
                            discussionGroupTitle = presentationData.strings.Channel_DiscussionGroupAdd
                        }
                    } else {
                        discussionGroupTitle = "..."
                    }
                    
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemDiscussionGroup, label: .text(discussionGroupTitle), text: presentationData.strings.Channel_DiscussionGroup, icon: UIImage(bundleImageName: "Chat/Info/GroupDiscussionIcon"), action: {
                        interaction.editingOpenDiscussionGroupSetup()
                    }))
                }
                
                if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                    let label: String
                    if let cachedData = data.cachedData as? CachedChannelData, case let .known(reactionSettings) = cachedData.reactionSettings {
                        switch reactionSettings.allowedReactions {
                        case .all:
                            label = presentationData.strings.PeerInfo_LabelAllReactions
                        case .empty:
                            if let starsAllowed = reactionSettings.starsAllowed, starsAllowed {
                                label = "1"
                            } else {
                                label = presentationData.strings.PeerInfo_ReactionsDisabled
                            }
                        case let .limited(reactions):
                            var countValue = reactions.count
                            if let starsAllowed = reactionSettings.starsAllowed, starsAllowed {
                                countValue += 1
                            }
                            label = "\(countValue)"
                        }
                    } else {
                        label = ""
                    }
                    let additionalBadgeLabel: String? = nil
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), additionalBadgeLabel: additionalBadgeLabel, text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                        interaction.editingOpenReactionsSetup()
                    }))
                }
                
                if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                    var colors: [PeerNameColors.Colors] = []
                    if let nameColor = channel.nameColor.flatMap({ context.peerNameColors.get($0, dark: presentationData.theme.overallDarkAppearance) }) {
                        colors.append(nameColor)
                    }
                    if let profileColor = channel.profileColor.flatMap({ context.peerNameColors.getProfile($0, dark: presentationData.theme.overallDarkAppearance, subject: .palette) }) {
                        colors.append(profileColor)
                    }
                    let colorImage = generateSettingsMenuPeerColorsLabelIcon(colors: colors)
                    
                    var boostIcon: UIImage?
                    if let approximateBoostLevel = channel.approximateBoostLevel, approximateBoostLevel < 1 {
                        boostIcon = generateDisclosureActionBoostLevelBadgeImage(text: presentationData.strings.Channel_Info_BoostLevelPlusBadge("1").string)
                    } else {
                        /*let labelText = NSAttributedString(string: presentationData.strings.Settings_New, font: Font.medium(11.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
                        let labelBounds = labelText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
                        let labelSize = CGSize(width: ceil(labelBounds.width), height: ceil(labelBounds.height))
                        let badgeSize = CGSize(width: labelSize.width + 8.0, height: labelSize.height + 2.0 + 1.0)
                        boostIcon = generateImage(badgeSize, rotatedContext: { size, context in
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            
                            let rect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height - UIScreenPixel * 2.0))
                            
                            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 5.0).cgPath)
                            context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                            context.fillPath()
                            
                            UIGraphicsPushContext(context)
                            labelText.draw(at: CGPoint(x: 4.0, y: 1.0 + UIScreenPixel))
                            UIGraphicsPopContext()
                        })*/
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPeerColor, label: .image(colorImage, colorImage.size), additionalBadgeIcon: boostIcon, text: presentationData.strings.Channel_Info_AppearanceItem, icon: UIImage(bundleImageName: "Chat/Info/NameColorIcon"), action: {
                        interaction.editingOpenNameColorSetup()
                    }))
                    
                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                    var isLocked = true
                    if let boostLevel = boostStatus?.level, boostLevel >= BoostSubject.autoTranslate.requiredLevel(group: false, context: context, configuration: premiumConfiguration) {
                        isLocked = false
                    }
                    items[.peerSettings]!.append(PeerInfoScreenSwitchItem(id: ItemPeerAutoTranslate, text: presentationData.strings.Channel_Info_AutoTranslate, value: channel.flags.contains(.autoTranslateEnabled), icon: UIImage(bundleImageName: "Settings/Menu/AutoTranslate"), isLocked: isLocked, toggled: { value in
                        if isLocked {
                            interaction.displayAutoTranslateLocked()
                        } else {
                            interaction.editingToggleAutoTranslate(value)
                        }
                    }))
                }
                
                if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                    let labelString: NSAttributedString
                    if channel.linkedMonoforumId != nil {
                        if let monoforumPeer = data.linkedMonoforumPeer as? TelegramChannel {
                            if let sendPaidMessageStars = monoforumPeer.sendPaidMessageStars {
                                let formattedLabel = formatStarsAmountText(sendPaidMessageStars, dateTimeFormat: presentationData.dateTimeFormat)
                                let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                                let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                                let labelColor = presentationData.theme.list.itemSecondaryTextColor
                                let attributedString = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                                attributedString.insert(NSAttributedString(string: "*", font: labelFont, textColor: labelColor), at: 0)
                                
                                if let range = attributedString.string.range(of: "*") {
                                    attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedString.string))
                                    attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                                }
                                labelString = attributedString
                            } else {
                                let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                                let labelColor = presentationData.theme.list.itemSecondaryTextColor
                                
                                labelString = NSAttributedString(string: presentationData.strings.PeerInfo_AllowChannelMessages_Free, font: labelFont, textColor: labelColor)
                            }
                        } else {
                            let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                            let labelColor = presentationData.theme.list.itemSecondaryTextColor
                            
                            labelString = NSAttributedString(string: " ", font: labelFont, textColor: labelColor)
                        }
                    } else {
                        let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                        let labelColor = presentationData.theme.list.itemSecondaryTextColor
                        
                        labelString = NSAttributedString(string: presentationData.strings.PeerInfo_AllowChannelMessages_Off, font: labelFont, textColor: labelColor)
                    }
                    
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPostSuggestionsSettings, label: .attributedText(labelString), additionalBadgeLabel: presentationData.strings.Settings_New, text: presentationData.strings.PeerInfo_AllowChannelMessages, icon: PresentationResourcesSettings.channelMessages, action: {
                        interaction.editingOpenPostSuggestionsSetup()
                    }))
                    
                    if let personalChannel = data.personalChannel {
                        let peerId = personalChannel.peer.peerId
                        items[.linkedMonoforum]?.append(PeerInfoScreenPersonalChannelItem(id: 1, context: context, data: personalChannel, controller: { [weak interaction] in
                            guard let interaction else {
                                return nil
                            }
                            return interaction.getController()
                        }, action: { [weak interaction] in
                            guard let interaction else {
                                return
                            }
                            interaction.openChat(peerId)
                        }))
                    }
                }
                
                var canEditMembers = false
                if channel.hasPermission(.banMembers) && (channel.adminRights != nil || channel.flags.contains(.isCreator)) {
                    canEditMembers = true
                }
                if canEditMembers {
                    let adminCount: Int32
                    let memberCount: Int32
                    if let cachedData = data.cachedData as? CachedChannelData {
                        adminCount = cachedData.participantsSummary.adminCount ?? 0
                        memberCount = cachedData.participantsSummary.memberCount ?? 0
                    } else {
                        adminCount = 0
                        memberCount = 0
                    }
                    
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, label: .text("\(adminCount == 0 ? "" : "\(presentationStringsFormattedNumber(adminCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Administrators, icon: UIImage(bundleImageName: "Chat/Info/GroupAdminsIcon"), action: {
                        interaction.openParticipantsSection(.admins)
                    }))
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMembers, label: .text("\(memberCount == 0 ? "" : "\(presentationStringsFormattedNumber(memberCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.Channel_Info_Subscribers, icon: UIImage(bundleImageName: "Chat/Info/GroupMembersIcon"), action: {
                        interaction.openParticipantsSection(.members)
                    }))
                    
                    if let count = data.requests?.count, count > 0 {
                        items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMemberRequests, label: .badge(presentationStringsFormattedNumber(count, presentationData.dateTimeFormat.groupingSeparator), presentationData.theme.list.itemAccentColor), text: presentationData.strings.GroupInfo_MemberRequests, icon: UIImage(bundleImageName: "Chat/Info/GroupRequestsIcon"), action: {
                            interaction.openParticipantsSection(.memberRequests)
                        }))
                    }
                }
                
                if let cachedData = data.cachedData as? CachedChannelData, cachedData.flags.contains(.canViewStats) {
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemStats, label: .none, text: presentationData.strings.Channel_Info_Stats, icon: UIImage(bundleImageName: "Chat/Info/StatsIcon"), action: {
                        interaction.openStats(.stats)
                    }))
                }
                
                if canEditMembers {
                    let bannedCount: Int32
                    if let cachedData = data.cachedData as? CachedChannelData {
                        bannedCount = cachedData.participantsSummary.kickedCount ?? 0
                    } else {
                        bannedCount = 0
                    }
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemBanned, label: .text("\(bannedCount == 0 ? "" : "\(presentationStringsFormattedNumber(bannedCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Permissions_Removed, icon: UIImage(bundleImageName: "Chat/Info/GroupRemovedIcon"), action: {
                        interaction.openParticipantsSection(.banned)
                    }))
                    
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemRecentActions, label: .none, text: presentationData.strings.Group_Info_AdminLog, icon: UIImage(bundleImageName: "Chat/Info/RecentActionsIcon"), action: {
                        interaction.openRecentActions()
                    }))
                }
                
                if channel.hasPermission(.changeInfo) {
                    var canJoinRefProgram = false
                    if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_connect_allowed"] {
                        if let value = value as? Double {
                            canJoinRefProgram = value != 0.0
                        } else if let value = value as? Bool {
                            canJoinRefProgram = value
                        }
                    }
                    
                    if canJoinRefProgram {
                        items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAffiliatePrograms, label: .text(""), additionalBadgeLabel: nil, text: presentationData.strings.PeerInfo_ItemAffiliatePrograms_Title, icon: PresentationResourcesSettings.affiliateProgram, action: {
                            interaction.editingOpenAffiliateProgram()
                        }))
                    }
                }
                
                if isCreator { //if let cachedData = data.cachedData as? CachedChannelData, cachedData.flags.contains(.canDeleteHistory) {
                    items[.peerActions]!.append(PeerInfoScreenActionItem(id: ItemDeleteChannel, text: presentationData.strings.ChannelInfo_DeleteChannel, color: .destructive, icon: nil, alignment: .natural, action: {
                        interaction.openDeletePeer()
                    }))
                }
            case .group:
                let ItemUsername = 101
                let ItemInviteLinks = 102
                let ItemLinkedChannel = 103
                let ItemPreHistory = 104
                let ItemMembers = 106
                let ItemPermissions = 107
                let ItemAdmins = 108
                let ItemMemberRequests = 109
                let ItemRemovedUsers = 110
                let ItemRecentActions = 111
                let ItemLocationHeader = 112
                let ItemLocation = 113
                let ItemLocationSetup = 114
                let ItemDeleteGroup = 115
                let ItemReactions = 116
                let ItemTopics = 117
                let ItemTopicsText = 118
                let ItemAppearance = 119
                
                let isCreator = channel.flags.contains(.isCreator)
                let isPublic = channel.addressName != nil
                
                if let cachedData = data.cachedData as? CachedChannelData {
                    if isCreator, let location = cachedData.peerGeoLocation {
                        items[.groupLocation]!.append(PeerInfoScreenHeaderItem(id: ItemLocationHeader, text: presentationData.strings.GroupInfo_Location.uppercased()))
                        
                        let imageSignal = chatMapSnapshotImage(engine: context.engine, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
                        items[.groupLocation]!.append(PeerInfoScreenAddressItem(
                            id: ItemLocation,
                            label: "",
                            text: location.address.replacingOccurrences(of: ", ", with: "\n"),
                            imageSignal: imageSignal,
                            action: {
                                interaction.openLocation()
                            }
                        ))
                        if cachedData.flags.contains(.canChangePeerGeoLocation) {
                            items[.groupLocation]!.append(PeerInfoScreenActionItem(id: ItemLocationSetup, text: presentationData.strings.Group_Location_ChangeLocation, action: {
                                interaction.editingOpenSetupLocation()
                            }))
                        }
                    }
                    
                    if isCreator || (channel.adminRights != nil && channel.hasPermission(.pinMessages)) {
                        if cachedData.peerGeoLocation != nil {
                            if isCreator {
                                let linkText: String
                                if let username = channel.addressName {
                                    linkText = "@\(username)"
                                } else {
                                    linkText = presentationData.strings.GroupInfo_PublicLinkAdd
                                }
                                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(linkText), text: presentationData.strings.GroupInfo_PublicLink, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                                    interaction.editingOpenPublicLinkSetup()
                                }))
                            }
                        } else {
                            if cachedData.flags.contains(.canChangeUsername) {
                                items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(isPublic ? presentationData.strings.Group_Setup_TypePublic : presentationData.strings.Group_Setup_TypePrivate), text: presentationData.strings.GroupInfo_GroupType, icon: UIImage(bundleImageName: "Chat/Info/GroupTypeIcon"), action: {
                                    interaction.editingOpenPublicLinkSetup()
                                }))
                            }
                        }
                    }
                    
                    if (isCreator && (channel.addressName?.isEmpty ?? true) && cachedData.peerGeoLocation == nil) || (!isCreator && channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                        let invitesText: String
                        if let count = data.invitations?.count, count > 0 {
                            invitesText = "\(count)"
                        } else {
                            invitesText = ""
                        }
                        
                        items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemInviteLinks, label: .text(invitesText), text: presentationData.strings.GroupInfo_InviteLinks, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                            interaction.editingOpenInviteLinksSetup()
                        }))
                    }
                            
                    if (isCreator || (channel.adminRights != nil && channel.hasPermission(.pinMessages))) && cachedData.peerGeoLocation == nil {
                        if let linkedDiscussionPeer = data.linkedDiscussionPeer {
                            let peerTitle: String
                            if let addressName = linkedDiscussionPeer.addressName, !addressName.isEmpty {
                                peerTitle = "@\(addressName)"
                            } else {
                                peerTitle = EnginePeer(linkedDiscussionPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            }
                            items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemLinkedChannel, label: .text(peerTitle), text: presentationData.strings.Group_LinkedChannel, icon: UIImage(bundleImageName: "Chat/Info/GroupLinkedChannelIcon"), action: {
                                interaction.editingOpenDiscussionGroupSetup()
                            }))
                        }
                        
                        if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                            let label: String
                            if let cachedData = data.cachedData as? CachedChannelData, case let .known(reactionSettings) = cachedData.reactionSettings {
                                switch reactionSettings.allowedReactions {
                                case .all:
                                    label = presentationData.strings.PeerInfo_LabelAllReactions
                                case .empty:
                                    label = presentationData.strings.PeerInfo_ReactionsDisabled
                                case let .limited(reactions):
                                    label = "\(reactions.count)"
                                }
                            } else {
                                label = ""
                            }
                            items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                                interaction.editingOpenReactionsSetup()
                            }))
                        }
                    } else {
                        if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                            let label: String
                            if let cachedData = data.cachedData as? CachedChannelData, case let .known(reactionSettings) = cachedData.reactionSettings {
                                switch reactionSettings.allowedReactions {
                                case .all:
                                    label = presentationData.strings.PeerInfo_LabelAllReactions
                                case .empty:
                                    label = presentationData.strings.PeerInfo_ReactionsDisabled
                                case let .limited(reactions):
                                    label = "\(reactions.count)"
                                }
                            } else {
                                label = ""
                            }
                            items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                                interaction.editingOpenReactionsSetup()
                            }))
                        }
                    }
                    
                    if isCreator || channel.adminRights?.rights.contains(.canChangeInfo) == true {
                        var colors: [PeerNameColors.Colors] = []
                        if let nameColor = channel.nameColor.flatMap({ context.peerNameColors.get($0, dark: presentationData.theme.overallDarkAppearance) }) {
                            colors.append(nameColor)
                        }
                        if let profileColor = channel.profileColor.flatMap({ context.peerNameColors.getProfile($0, dark: presentationData.theme.overallDarkAppearance, subject: .palette) }) {
                            colors.append(profileColor)
                        }
                        let colorImage = generateSettingsMenuPeerColorsLabelIcon(colors: colors)
                        
                        var boostIcon: UIImage?
                        if let approximateBoostLevel = channel.approximateBoostLevel, approximateBoostLevel < 1 {
                            boostIcon = generateDisclosureActionBoostLevelBadgeImage(text: presentationData.strings.Channel_Info_BoostLevelPlusBadge("1").string)
                        } else {
                            boostIcon = nil
                            /*let labelText = NSAttributedString(string: presentationData.strings.Settings_New, font: Font.medium(11.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
                            let labelBounds = labelText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
                            let labelSize = CGSize(width: ceil(labelBounds.width), height: ceil(labelBounds.height))
                            let badgeSize = CGSize(width: labelSize.width + 8.0, height: labelSize.height + 2.0 + 1.0)
                            boostIcon = generateImage(badgeSize, rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                
                                let rect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height - UIScreenPixel * 2.0))
                                
                                context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 5.0).cgPath)
                                context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                                context.fillPath()
                                
                                UIGraphicsPushContext(context)
                                labelText.draw(at: CGPoint(x: 4.0, y: 1.0 + UIScreenPixel))
                                UIGraphicsPopContext()
                            })*/
                        }
                        items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAppearance, label: .image(colorImage, colorImage.size), additionalBadgeIcon: boostIcon, text: presentationData.strings.Channel_Info_AppearanceItem, icon: UIImage(bundleImageName: "Chat/Info/NameColorIcon"), action: {
                            interaction.editingOpenNameColorSetup()
                        }))
                    }
                    
                    if (isCreator || (channel.adminRights != nil && channel.hasPermission(.banMembers))) && cachedData.peerGeoLocation == nil, !isPublic, case .known(nil) = cachedData.linkedDiscussionPeerId, !channel.isForumOrMonoForum {
                        items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPreHistory, label: .text(cachedData.flags.contains(.preHistoryEnabled) ? presentationData.strings.GroupInfo_GroupHistoryVisible : presentationData.strings.GroupInfo_GroupHistoryHidden), text: presentationData.strings.GroupInfo_GroupHistoryShort, icon: UIImage(bundleImageName: "Chat/Info/GroupDiscussionIcon"), action: {
                            interaction.editingOpenPreHistorySetup()
                        }))
                    }
                                        
                    if isCreator, let appConfiguration = data.appConfiguration {
                        var minParticipants = 200
                        if let data = appConfiguration.data, let value = data["forum_upgrade_participants_min"] as? Double {
                            minParticipants = Int(value)
                        }
                        
                        var canSetupTopics = false
                        var topicsLimitedReason: TopicsLimitedReason?
                        if channel.flags.contains(.isForum) {
                            canSetupTopics = true
                        } else if case let .known(value) = cachedData.linkedDiscussionPeerId, value != nil {
                            canSetupTopics = true
                            topicsLimitedReason = .discussion
                        } else if let memberCount = cachedData.participantsSummary.memberCount {
                            canSetupTopics = true
                            if Int(memberCount) < minParticipants {
                                topicsLimitedReason = .participants(minParticipants)
                            }
                        }
                        
                        if canSetupTopics {
                            let label = channel.flags.contains(.isForum) ? presentationData.strings.PeerInfo_OptionTopics_Enabled : presentationData.strings.PeerInfo_OptionTopics_Disabled
                            items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemTopics, label: .text(label), text: presentationData.strings.PeerInfo_OptionTopics, icon: UIImage(bundleImageName: "Settings/Menu/Topics"), action: {
                                if let topicsLimitedReason = topicsLimitedReason {
                                    interaction.displayTopicsLimited(topicsLimitedReason)
                                } else {
                                    interaction.openForumSettings()
                                }
                            }))
                            
                            items[.peerDataSettings]!.append(PeerInfoScreenCommentItem(id: ItemTopicsText, text: presentationData.strings.PeerInfo_OptionTopicsText))
                        }
                    }
                    
                    var canViewAdminsAndBanned = false
                    if let _ = channel.adminRights {
                        canViewAdminsAndBanned = true
                    } else if channel.flags.contains(.isCreator) {
                        canViewAdminsAndBanned = true
                    }
                    
                    if canViewAdminsAndBanned {
                        var activePermissionCount: Int?
                        if let defaultBannedRights = channel.defaultBannedRights {
                            var count = 0
                            for (right, _) in allGroupPermissionList(peer: .channel(channel), expandMedia: true) {
                                if right == .banSendMedia {
                                    if banSendMediaSubList().allSatisfy({ !defaultBannedRights.flags.contains($0.0) }) {
                                        count += 1
                                    }
                                } else {
                                    if !defaultBannedRights.flags.contains(right) {
                                        count += 1
                                    }
                                }
                            }
                            activePermissionCount = count
                        }
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMembers, label: .text(cachedData.participantsSummary.memberCount.flatMap { "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" } ?? ""), text: presentationData.strings.Group_Info_Members, icon: UIImage(bundleImageName: "Chat/Info/GroupMembersIcon"), action: {
                            interaction.openParticipantsSection(.members)
                        }))
                        if !channel.flags.contains(.isGigagroup) {
                            items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPermissions, label: .text(activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList(peer: .channel(channel), expandMedia: true).count)" }) ?? ""), text: presentationData.strings.GroupInfo_Permissions, icon: UIImage(bundleImageName: "Settings/Menu/SetPasscode"), action: {
                                interaction.openPermissions()
                            }))
                        }
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, label: .text(cachedData.participantsSummary.adminCount.flatMap { "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" } ?? ""), text: presentationData.strings.GroupInfo_Administrators, icon: UIImage(bundleImageName: "Chat/Info/GroupAdminsIcon"), action: {
                            interaction.openParticipantsSection(.admins)
                        }))
                        
                        if let count = data.requests?.count, count > 0 {
                            items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMemberRequests, label: .badge(presentationStringsFormattedNumber(count, presentationData.dateTimeFormat.groupingSeparator), presentationData.theme.list.itemAccentColor), text: presentationData.strings.GroupInfo_MemberRequests, icon: UIImage(bundleImageName: "Chat/Info/GroupRequestsIcon"), action: {
                                interaction.openParticipantsSection(.memberRequests)
                            }))
                        }
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemRemovedUsers, label: .text(cachedData.participantsSummary.kickedCount.flatMap { $0 > 0 ? "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" : "" } ?? ""), text: presentationData.strings.GroupInfo_Permissions_Removed, icon: UIImage(bundleImageName: "Chat/Info/GroupRemovedIcon"), action: {
                            interaction.openParticipantsSection(.banned)
                        }))
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemRecentActions, label: .none, text: presentationData.strings.Group_Info_AdminLog, icon: UIImage(bundleImageName: "Chat/Info/RecentActionsIcon"), action: {
                            interaction.openRecentActions()
                        }))
                    }
                    
                    if isCreator {
                        items[.peerActions]!.append(PeerInfoScreenActionItem(id: ItemDeleteGroup, text: presentationData.strings.Group_DeleteGroup, color: .destructive, icon: nil, alignment: .natural, action: {
                            interaction.openDeletePeer()
                        }))
                    }
                }
            }
        } else if let group = data.peer as? TelegramGroup {
            let ItemUsername = 101
            let ItemInviteLinks = 102
            let ItemPreHistory = 103
            let ItemPermissions = 104
            let ItemAdmins = 105
            let ItemMemberRequests = 106
            let ItemReactions = 107
            let ItemTopics = 108
            let ItemTopicsText = 109
            
            var canViewAdminsAndBanned = false
            
            if case .creator = group.role {
                if let cachedData = data.cachedData as? CachedGroupData {
                    if cachedData.flags.contains(.canChangeUsername) {
                        items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(presentationData.strings.Group_Setup_TypePrivate), text: presentationData.strings.GroupInfo_GroupType, icon: UIImage(bundleImageName: "Chat/Info/GroupTypeIcon"), action: {
                            interaction.editingOpenPublicLinkSetup()
                        }))
                    }
                }
                
                if (group.addressName?.isEmpty ?? true) {
                    let invitesText: String
                    if let count = data.invitations?.count, count > 0 {
                        invitesText = "\(count)"
                    } else {
                        invitesText = ""
                    }
                    
                    items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemInviteLinks, label: .text(invitesText), text: presentationData.strings.GroupInfo_InviteLinks, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                        interaction.editingOpenInviteLinksSetup()
                    }))
                }
                                
                items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPreHistory, label: .text(presentationData.strings.GroupInfo_GroupHistoryHidden), text: presentationData.strings.GroupInfo_GroupHistoryShort, icon: UIImage(bundleImageName: "Chat/Info/GroupDiscussionIcon"), action: {
                    interaction.editingOpenPreHistorySetup()
                }))
                
                var canSetupTopics = false
                if case .creator = group.role {
                    canSetupTopics = true
                }
                var topicsLimitedReason: TopicsLimitedReason?
                if let appConfiguration = data.appConfiguration {
                    var minParticipants = 200
                    if let data = appConfiguration.data, let value = data["forum_upgrade_participants_min"] as? Double {
                        minParticipants = Int(value)
                    }
                    if Int(group.participantCount) < minParticipants {
                        topicsLimitedReason = .participants(minParticipants)
                    }
                }
                
                if canSetupTopics {
                    items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemTopics, label: .text(presentationData.strings.PeerInfo_OptionTopics_Disabled), text: presentationData.strings.PeerInfo_OptionTopics, icon: UIImage(bundleImageName: "Settings/Menu/Topics"), action: {
                        if let topicsLimitedReason = topicsLimitedReason {
                            interaction.displayTopicsLimited(topicsLimitedReason)
                        } else {
                            interaction.openForumSettings()
                        }
                    }))
                    
                    items[.peerPublicSettings]!.append(PeerInfoScreenCommentItem(id: ItemTopicsText, text: presentationData.strings.PeerInfo_OptionTopicsText))
                }
                
                let label: String
                if let cachedData = data.cachedData as? CachedGroupData, case let .known(reactionSettings) = cachedData.reactionSettings {
                    switch reactionSettings.allowedReactions {
                    case .all:
                        label = presentationData.strings.PeerInfo_LabelAllReactions
                    case .empty:
                        label = presentationData.strings.PeerInfo_ReactionsDisabled
                    case let .limited(reactions):
                        label = "\(reactions.count)"
                    }
                } else {
                    label = ""
                }
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                    interaction.editingOpenReactionsSetup()
                }))
                
                canViewAdminsAndBanned = true
            } else if case let .admin(rights, _) = group.role {
                let label: String
                if let cachedData = data.cachedData as? CachedGroupData, case let .known(reactionSettings) = cachedData.reactionSettings {
                    switch reactionSettings.allowedReactions {
                    case .all:
                        label = presentationData.strings.PeerInfo_LabelAllReactions
                    case .empty:
                        label = presentationData.strings.PeerInfo_ReactionsDisabled
                    case let .limited(reactions):
                        label = "\(reactions.count)"
                    }
                } else {
                    label = ""
                }
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                    interaction.editingOpenReactionsSetup()
                }))
                
                if rights.rights.contains(.canInviteUsers) {
                    let invitesText: String
                    if let count = data.invitations?.count, count > 0 {
                        invitesText = "\(count)"
                    } else {
                        invitesText = ""
                    }
                    
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemInviteLinks, label: .text(invitesText), text: presentationData.strings.GroupInfo_InviteLinks, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                        interaction.editingOpenInviteLinksSetup()
                    }))
                }
                
                canViewAdminsAndBanned = true
            }
            
            if canViewAdminsAndBanned {
                var activePermissionCount: Int?
                if let defaultBannedRights = group.defaultBannedRights {
                    var count = 0
                    for (right, _) in allGroupPermissionList(peer: .legacyGroup(group), expandMedia: true) {
                        if right == .banSendMedia {
                            if banSendMediaSubList().allSatisfy({ !defaultBannedRights.flags.contains($0.0) }) {
                                count += 1
                            }
                        } else {
                            if !defaultBannedRights.flags.contains(right) {
                                count += 1
                            }
                        }
                    }
                    activePermissionCount = count
                }
                
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPermissions, label: .text(activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList(peer: .legacyGroup(group), expandMedia: true).count)" }) ?? ""), text: presentationData.strings.GroupInfo_Permissions, icon: UIImage(bundleImageName: "Settings/Menu/SetPasscode"), action: {
                    interaction.openPermissions()
                }))
                
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, text: presentationData.strings.GroupInfo_Administrators, icon: UIImage(bundleImageName: "Chat/Info/GroupAdminsIcon"), action: {
                    interaction.openParticipantsSection(.admins)
                }))
                
                if let count = data.requests?.count, count > 0 {
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMemberRequests, label: .badge(presentationStringsFormattedNumber(count, presentationData.dateTimeFormat.groupingSeparator), presentationData.theme.list.itemAccentColor), text: presentationData.strings.GroupInfo_MemberRequests, icon: UIImage(bundleImageName: "Chat/Info/GroupRequestsIcon"), action: {
                        interaction.openParticipantsSection(.memberRequests)
                    }))
                }
            }
        }
    }
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in Section.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}
