import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import TelegramCore
import Postbox
import PhoneNumberFormat
import ItemListUI
import SwiftSignalKit
import PhotoResources
import ItemListPeerItem
import DeviceAccess
import TelegramStringFormatting
import PeerNameColorItem

enum SettingsSection: Int, CaseIterable {
    case edit
    case phone
    case accounts
    case myProfile
    case proxy
    case apps
    case shortcuts
    case advanced
    case payment
    case extra
    case support
}

func settingsItems(data: PeerInfoScreenData?, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction, isExpanded: Bool) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    var items: [SettingsSection: [PeerInfoScreenItem]] = [:]
    for section in SettingsSection.allCases {
        items[section] = []
    }
    
    let setPhotoTitle: String
    if let peer = data.peer, !peer.profileImageRepresentations.isEmpty {
        setPhotoTitle = presentationData.strings.Settings_ChangeProfilePhoto
    } else {
        setPhotoTitle = presentationData.strings.Settings_SetProfilePhotoOrVideo
    }
    
    var setStatusTitle: String = ""
    let displaySetStatus: Bool
    var hasEmojiStatus = false
    if let peer = data.peer as? TelegramUser, peer.isPremium {
        if peer.emojiStatus != nil {
            hasEmojiStatus = true
            setStatusTitle = presentationData.strings.PeerInfo_ChangeEmojiStatus
        } else {
            setStatusTitle = presentationData.strings.PeerInfo_SetEmojiStatus
        }
        displaySetStatus = true
    } else {
        displaySetStatus = false
    }
    
    if displaySetStatus {
        items[.edit]!.append(PeerInfoScreenActionItem(id: 0, text: setStatusTitle, icon: UIImage(bundleImageName: hasEmojiStatus ? "Settings/EditEmojiStatus" : "Settings/SetEmojiStatus"), action: {
            interaction.openSettings(.emojiStatus)
        }))
        
        items[.edit]!.append(PeerInfoScreenActionItem(id: 1, text: presentationData.strings.PeerInfo_ChangeProfileColor, icon: UIImage(bundleImageName: "Premium/BoostPerk/CoverColor"), action: {
            interaction.openSettings(.profileColor)
        }))
    }
    
    items[.edit]!.append(PeerInfoScreenActionItem(id: 2, text: setPhotoTitle, icon: UIImage(bundleImageName: "Settings/SetAvatar"), action: {
        interaction.openSettings(.avatar)
    }))
    
    if let peer = data.peer, (peer.addressName ?? "").isEmpty {
        items[.edit]!.append(PeerInfoScreenActionItem(id: 3, text: presentationData.strings.Settings_SetUsername, icon: UIImage(bundleImageName: "Settings/SetUsername"), action: {
            interaction.openSettings(.username)
        }))
    }
    
    if let settings = data.globalSettings {
        if settings.premiumGracePeriod {
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: "Your access to Telegram Premium will expire soon!", text: .markdown("Unfortunately, your latest payment didn't come through. To keep your access to exclusive features, please renew the subscription."), isWarning: true, linkAction: nil))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 1, text: "Restore Subscription", action: {
                interaction.openSettings(.premiumManagement)
            }))
        } else if settings.suggestPhoneNumberConfirmation, let peer = data.peer as? TelegramUser {
            let phoneNumber = formatPhoneNumber(context: context, number: peer.phone ?? "")
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: presentationData.strings.Settings_CheckPhoneNumberTitle(phoneNumber).string, text: .markdown(presentationData.strings.Settings_CheckPhoneNumberText), linkAction: { link in
                if case .tap = link {
                    interaction.openFaq(presentationData.strings.Settings_CheckPhoneNumberFAQAnchor)
                }
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 1, text: presentationData.strings.Settings_KeepPhoneNumber(phoneNumber).string, action: {
                let _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.validatePhoneNumber.id).startStandalone()
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_ChangePhoneNumber, action: {
                interaction.openSettings(.phoneNumber)
            }))
        } else if settings.suggestPasswordConfirmation {
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: presentationData.strings.Settings_CheckPasswordTitle, text: .markdown(presentationData.strings.Settings_CheckPasswordText), linkAction: { _ in
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 1, text: presentationData.strings.Settings_KeepPassword, action: {
                let _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.validatePassword.id).startStandalone()
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_TryEnterPassword, action: {
                interaction.openSettings(.rememberPassword)
            }))
        } else if settings.suggestPasswordSetup {
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: presentationData.strings.Settings_SuggestSetupPasswordTitle, text: .markdown(presentationData.strings.Settings_SuggestSetupPasswordText), linkAction: { _ in
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_SuggestSetupPasswordAction, action: {
                interaction.openSettings(.passwordSetup)
            }))
        }
        
        if !settings.accountsAndPeers.isEmpty {
            for (peerAccountContext, peer, badgeCount) in settings.accountsAndPeers {
                let mappedContext = ItemListPeerItem.Context.custom(ItemListPeerItem.Context.Custom(
                    accountPeerId: peerAccountContext.account.peerId,
                    postbox: peerAccountContext.account.postbox,
                    network: peerAccountContext.account.network,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    isPremiumDisabled: false,
                    resolveInlineStickers: { fileIds in
                        return context.engine.stickers.resolveInlineStickers(fileIds: fileIds)
                    }
                ))
                let member: PeerInfoMember = .account(peer: RenderedPeer(peer: peer._asPeer()))
                items[.accounts]!.append(PeerInfoScreenMemberItem(id: member.id, context: mappedContext, enclosingPeer: nil, member: member, badge: badgeCount > 0 ? "\(compactNumericCountString(Int(badgeCount), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))" : nil, isAccount: true, action: { action in
                    switch action {
                    case .open:
                        interaction.switchToAccount(peerAccountContext.account.id)
                    case .remove:
                        interaction.logoutAccount(peerAccountContext.account.id)
                    default:
                        break
                    }
                }, contextAction: { node, gesture in
                    interaction.accountContextMenu(peerAccountContext.account.id, node, gesture)
                }))
            }
            
            items[.accounts]!.append(PeerInfoScreenActionItem(id: 100, text: presentationData.strings.Settings_AddAccount, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), action: {
                interaction.openSettings(.addAccount)
            }))
        }
        
        items[.myProfile]!.append(PeerInfoScreenDisclosureItem(id: 0, text: presentationData.strings.Settings_MyProfile, icon: PresentationResourcesSettings.myProfile, action: {
            interaction.openSettings(.profile)
        }))
        
        if !settings.proxySettings.servers.isEmpty {
            let proxyType: String
            if settings.proxySettings.enabled, let activeServer = settings.proxySettings.activeServer {
                switch activeServer.connection {
                case .mtp:
                    proxyType = presentationData.strings.SocksProxySetup_ProxyTelegram
                case .socks5:
                    proxyType = presentationData.strings.SocksProxySetup_ProxySocks5
                }
            } else {
                proxyType = presentationData.strings.Settings_ProxyDisabled
            }
            items[.proxy]!.append(PeerInfoScreenDisclosureItem(id: 0, label: .text(proxyType), text: presentationData.strings.Settings_Proxy, icon: PresentationResourcesSettings.proxy, action: {
                interaction.openSettings(.proxy)
            }))
        }
    }
    
    var appIndex = 1000
    if let settings = data.globalSettings {
        for bot in settings.bots {
            let iconSignal: Signal<UIImage?, NoError>
            if let peer = PeerReference(bot.peer._asPeer()), let icon = bot.icons[.iOSSettingsStatic] {
                let fileReference: FileMediaReference = .attachBot(peer: peer, media: icon)
                iconSignal = instantPageImageFile(account: context.account, userLocation: .other, fileReference: fileReference, fetched: true)
                |> map { generator -> UIImage? in
                    let size = CGSize(width: 29.0, height: 29.0)
                    let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: .zero))
                    return context?.generateImage()
                }
                let _ = freeMediaFileInteractiveFetched(account: context.account, userLocation: .other, fileReference: fileReference).startStandalone()
            } else {
                iconSignal = .single(UIImage())
            }
            let label: PeerInfoScreenDisclosureItem.Label = bot.flags.contains(.notActivated) || bot.flags.contains(.showInSettingsDisclaimer) ? .titleBadge(presentationData.strings.Settings_New, presentationData.theme.list.itemAccentColor) : .none
            items[.apps]!.append(PeerInfoScreenDisclosureItem(id: bot.peer.id.id._internalGetInt64Value(), label: label, text: bot.shortName, icon: nil, iconSignal: iconSignal, action: {
                interaction.openBotApp(bot)
            }))
            appIndex += 1
        }
    }
    
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_SavedMessages, icon: PresentationResourcesSettings.savedMessages, action: {
        interaction.openSettings(.savedMessages)
    }))
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 2, text: presentationData.strings.CallSettings_RecentCalls, icon: PresentationResourcesSettings.recentCalls, action: {
        interaction.openSettings(.recentCalls)
    }))
    
    let devicesLabel: String
    if let settings = data.globalSettings, let otherSessionsCount = settings.otherSessionsCount {
        if settings.enableQRLogin {
            devicesLabel = otherSessionsCount == 0 ? presentationData.strings.Settings_AddDevice : "\(otherSessionsCount + 1)"
        } else {
            devicesLabel = otherSessionsCount == 0 ? "" : "\(otherSessionsCount + 1)"
        }
    } else {
        devicesLabel = ""
    }
    
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 3, label: .text(devicesLabel), text: presentationData.strings.Settings_Devices, icon: PresentationResourcesSettings.devices, action: {
        interaction.openSettings(.devices)
    }))
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 4, text: presentationData.strings.Settings_ChatFolders, icon: PresentationResourcesSettings.chatFolders, action: {
        interaction.openSettings(.chatFolders)
    }))
    
    let notificationsWarning: Bool
    if let settings = data.globalSettings {
        notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: settings.notificationAuthorizationStatus, suppressed:  settings.notificationWarningSuppressed)
    } else {
        notificationsWarning = false
    }
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 0, label: notificationsWarning ? .badge("!", presentationData.theme.list.itemDestructiveColor) : .none, text: presentationData.strings.Settings_NotificationsAndSounds, icon: PresentationResourcesSettings.notifications, action: {
        interaction.openSettings(.notificationsAndSounds)
    }))
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_PrivacySettings, icon: PresentationResourcesSettings.security, action: {
        interaction.openSettings(.privacyAndSecurity)
    }))
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 2, text: presentationData.strings.Settings_ChatSettings, icon: PresentationResourcesSettings.dataAndStorage, action: {
        interaction.openSettings(.dataAndStorage)
    }))
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 3, text: presentationData.strings.Settings_Appearance, icon: PresentationResourcesSettings.appearance, action: {
        interaction.openSettings(.appearance)
    }))
    
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 6, label: .text(data.isPowerSavingEnabled == true ? presentationData.strings.Settings_PowerSavingOn : presentationData.strings.Settings_PowerSavingOff), text: presentationData.strings.Settings_PowerSaving, icon: PresentationResourcesSettings.powerSaving, action: {
        interaction.openSettings(.powerSaving)
    }))
    
    let languageName = presentationData.strings.primaryComponent.localizedName
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 4, label: .text(languageName.isEmpty ? presentationData.strings.Localization_LanguageName : languageName), text: presentationData.strings.Settings_AppLanguage, icon: PresentationResourcesSettings.language, action: {
        interaction.openSettings(.language)
    }))
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
    if !isPremiumDisabled || context.isPremium {
        items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 100, label: .text(""), text: presentationData.strings.Settings_Premium, icon: PresentationResourcesSettings.premium, action: {
            interaction.openSettings(.premium)
        }))
    }
    if let starsState = data.starsState {
        if !isPremiumDisabled || abs(starsState.balance.value) > 0 {
            let balanceText: NSAttributedString
            if abs(starsState.balance.value) > 0 {
                let formattedLabel = formatStarsAmountText(starsState.balance, dateTimeFormat: presentationData.dateTimeFormat)
                let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                let labelColor = presentationData.theme.list.itemSecondaryTextColor
                balanceText = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
            } else {
                balanceText = NSAttributedString()
            }
            items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 102, label: .attributedText(balanceText), text: presentationData.strings.Settings_Stars, icon: PresentationResourcesSettings.stars, action: {
                interaction.openSettings(.stars)
            }))
        }
    }
    if let tonState = data.tonState {
        if abs(tonState.balance.value) > 0 {
            let balanceText: NSAttributedString
            if abs(tonState.balance.value) > 0 {
                let formattedLabel = formatTonAmountText(tonState.balance.value, dateTimeFormat: presentationData.dateTimeFormat)
                let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                let labelColor = presentationData.theme.list.itemSecondaryTextColor
                balanceText = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
            } else {
                balanceText = NSAttributedString()
            }
            items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 103, label: .attributedText(balanceText), text: presentationData.strings.Settings_MyTon, icon: PresentationResourcesSettings.ton, action: {
                interaction.openSettings(.ton)
            }))
        }
    }
    if !isPremiumDisabled || context.isPremium {
        items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 104, label: .text(""), additionalBadgeLabel: nil, text: presentationData.strings.Settings_Business, icon: PresentationResourcesSettings.business, action: {
            interaction.openSettings(.businessSetup)
        }))
    }
    if let starsState = data.starsState {
        if !isPremiumDisabled || starsState.balance > StarsAmount.zero {
            items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 105, label: .text(""), text: presentationData.strings.Settings_SendGift, icon: PresentationResourcesSettings.premiumGift, action: {
                interaction.openSettings(.premiumGift)
            }))
        }
    }
    
    if let settings = data.globalSettings {
        if settings.hasPassport {
            items[.extra]!.append(PeerInfoScreenDisclosureItem(id: 0, text: presentationData.strings.Settings_Passport, icon: PresentationResourcesSettings.passport, action: {
                interaction.openSettings(.passport)
            }))
        }
        if settings.hasWatchApp {
            items[.extra]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_AppleWatch, icon: PresentationResourcesSettings.watch, action: {
                interaction.openSettings(.watch)
            }))
        }
    }
    
    items[.support]!.append(PeerInfoScreenDisclosureItem(id: 0, text: presentationData.strings.Settings_Support, icon: PresentationResourcesSettings.support, action: {
        interaction.openSettings(.support)
    }))
    items[.support]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_FAQ, icon: PresentationResourcesSettings.faq, action: {
        interaction.openSettings(.faq)
    }))
    items[.support]!.append(PeerInfoScreenDisclosureItem(id: 2, text: presentationData.strings.Settings_Tips, icon: PresentationResourcesSettings.tips, action: {
        interaction.openSettings(.tips)
    }))
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in SettingsSection.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}

func settingsEditingItems(data: PeerInfoScreenData?, state: PeerInfoState, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction, isMyProfile: Bool) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    enum Section: Int, CaseIterable {
        case help
        case bio
        case birthday
        case info
        case account
        case logout
    }
    
    var items: [Section: [PeerInfoScreenItem]] = [:]
    for section in Section.allCases {
        items[section] = []
    }
    
    let ItemNameHelp = 0
    let ItemBio: AnyHashable = AnyHashable("bio_edit")
    let ItemBioHelp = 2
    let ItemPhoneNumber = 3
    let ItemUsername = 4
    let ItemAddAccount = 5
    let ItemAddAccountHelp = 6
    let ItemLogout = 7
    let ItemPeerColor = 8
    let ItemBirthday = 9
    let ItemBirthdayPicker = 10
    let ItemBirthdayRemove = 11
    let ItemBirthdayHelp = 12
    let ItemPeerPersonalChannel = 13
    
    items[.help]!.append(PeerInfoScreenCommentItem(id: ItemNameHelp, text: presentationData.strings.EditProfile_NameAndPhotoOrVideoHelp))
    
    if let cachedData = data.cachedData as? CachedUserData {
        items[.bio]!.append(PeerInfoScreenMultilineInputItem(id: ItemBio, text: state.updatingBio ?? (cachedData.about ?? ""), placeholder: presentationData.strings.UserInfo_About_Placeholder, textUpdated: { updatedText in
            interaction.updateBio(updatedText)
        }, action: {
            interaction.dismissInput()
        }, maxLength: Int(data.globalSettings?.userLimits.maxAboutLength ?? 70)))
        items[.bio]!.append(PeerInfoScreenCommentItem(id: ItemBioHelp, text: presentationData.strings.Settings_About_PrivacyHelp, linkAction: { _ in
            interaction.openBioPrivacy()
        }))
    }
    
    
    var birthday: TelegramBirthday?
    if let updatingBirthDate = state.updatingBirthDate {
        birthday = updatingBirthDate
    } else {
        birthday = (data.cachedData as? CachedUserData)?.birthday
    }
    
    var birthDateString: String
    if let birthday {
        birthDateString = stringForCompactBirthday(birthday, strings: presentationData.strings)
    } else {
        birthDateString = presentationData.strings.Settings_Birthday_Add
    }
    
    let isEditingBirthDate = state.isEditingBirthDate
    items[.birthday]!.append(PeerInfoScreenDisclosureItem(id: ItemBirthday, label: .coloredText(birthDateString, isEditingBirthDate ? .accent : .generic), text: presentationData.strings.Settings_Birthday, icon: nil, hasArrow: false, action: {
        interaction.updateIsEditingBirthdate(!isEditingBirthDate)
    }))
    if isEditingBirthDate, let birthday {
        items[.birthday]!.append(PeerInfoScreenBirthdatePickerItem(id: ItemBirthdayPicker, value: birthday, valueUpdated: { value in
            interaction.updateBirthdate(value)
        }))
        items[.birthday]!.append(PeerInfoScreenActionItem(id: ItemBirthdayRemove, text: presentationData.strings.Settings_Birthday_Remove, alignment: .natural, action: {
            interaction.updateBirthdate(.some(nil))
            interaction.updateIsEditingBirthdate(false)
        }))
    }
    
    
    var birthdayIsForContactsOnly = false
    if let birthdayPrivacy = data.globalSettings?.privacySettings?.birthday, case .enableContacts = birthdayPrivacy {
        birthdayIsForContactsOnly = true
    }
    items[.birthday]!.append(PeerInfoScreenCommentItem(id: ItemBirthdayHelp, text: birthdayIsForContactsOnly ? presentationData.strings.Settings_Birthday_ContactsHelp : presentationData.strings.Settings_Birthday_Help, linkAction: { _ in
        interaction.openBirthdatePrivacy()
    }))
    
    if let user = data.peer as? TelegramUser {
        items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemPhoneNumber, label: .text(user.phone.flatMap({ formatPhoneNumber(context: context, number: $0) }) ?? ""), text: presentationData.strings.Settings_PhoneNumber, action: {
            interaction.openSettings(.phoneNumber)
        }))
    }
    var username = ""
    if let addressName = data.peer?.addressName, !addressName.isEmpty {
        username = "@\(addressName)"
    }
    items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(username), text: presentationData.strings.Settings_Username, action: {
          interaction.openSettings(.username)
    }))
    
    if let peer = data.peer as? TelegramUser {
        var colors: [PeerNameColors.Colors] = []
        if let nameColor = peer.nameColor {
            let nameColors: PeerNameColors.Colors
            switch nameColor {
            case let .preset(nameColor):
                nameColors = context.peerNameColors.get(nameColor, dark: presentationData.theme.overallDarkAppearance)
            case let .collectible(collectibleColor):
                nameColors = collectibleColor.peerNameColors(dark: presentationData.theme.overallDarkAppearance)
            }
            colors.append(nameColors)
        }
        if let profileColor = peer.effectiveProfileColor.flatMap({ context.peerNameColors.getProfile($0, dark: presentationData.theme.overallDarkAppearance, subject: .palette) }) {
            colors.append(profileColor)
        }
        let colorImage = generateSettingsMenuPeerColorsLabelIcon(colors: colors)
        
        items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemPeerColor, label: .image(colorImage, colorImage.size), text: presentationData.strings.Settings_YourColor, icon: nil, action: {
            interaction.editingOpenNameColorSetup()
        }))
        
        var displayPersonalChannel = false
        if data.personalChannel != nil {
            displayPersonalChannel = true
        } else if let personalChannels = state.personalChannels, !personalChannels.isEmpty {
            displayPersonalChannel = true
        }
        if displayPersonalChannel {
            var personalChannelTitle: String?
            if let personalChannel = data.personalChannel, let peer = personalChannel.peer.chatOrMonoforumMainPeer {
                personalChannelTitle = peer.compactDisplayTitle
            }
            
            items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemPeerPersonalChannel, label: .text(personalChannelTitle ?? presentationData.strings.Settings_PersonalChannelEmptyValue), text: presentationData.strings.Settings_PersonalChannelItem, icon: nil, action: {
                interaction.editingOpenPersonalChannel()
            }))
        }
    }
    
    items[.account]!.append(PeerInfoScreenActionItem(id: ItemAddAccount, text: presentationData.strings.Settings_AddAnotherAccount, alignment: .center, action: {
        interaction.openSettings(.addAccount)
    }))
    
    var hasPremiumAccounts = false
    if data.peer?.isPremium == true && !context.account.testingEnvironment {
        hasPremiumAccounts = true
    }
    if let settings = data.globalSettings {
        for (accountContext, peer, _) in settings.accountsAndPeers {
            if !accountContext.account.testingEnvironment {
                if peer.isPremium {
                    hasPremiumAccounts = true
                    break
                }
            }
        }
    }
    
    items[.account]!.append(PeerInfoScreenCommentItem(id: ItemAddAccountHelp, text: hasPremiumAccounts ? presentationData.strings.Settings_AddAnotherAccount_PremiumHelp : presentationData.strings.Settings_AddAnotherAccount_Help))
    
    items[.logout]!.append(PeerInfoScreenActionItem(id: ItemLogout, text: presentationData.strings.Settings_Logout, color: .destructive, alignment: .center, action: {
        interaction.openSettings(.logout)
    }))
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in Section.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}
