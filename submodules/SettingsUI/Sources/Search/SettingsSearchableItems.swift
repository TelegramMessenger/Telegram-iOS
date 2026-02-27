import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import TelegramCallsUI
import OverlayStatusController
import AccountContext
import PassportUI
import LocalAuth
import CallListUI
import ChatListUI
import NotificationSoundSelectionUI
import PresentationDataUtils
import PhoneNumberFormat
import AccountUtils
import InstantPageCache
import NotificationPeerExceptionController
import QrCodeUI
import PremiumUI
import StorageUsageScreen
import PeerInfoStoryGridScreen
import WallpaperGridScreen
import PeerNameColorScreen
import UndoUI
import PasskeysScreen
import ContextUI
import QuickReactionSetupController
import AvatarEditorScreen
import PeerSelectionScreen
import DeviceModel

enum SettingsSearchableItemIcon {
    case profile
    case proxy
    case savedMessages
    case calls
    case stickers
    case notifications
    case privacy
    case data
    case appearance
    case language
    case watch
    case passport
    case support
    case faq
    case tips
    case chatFolders
    case deleteAccount
    case devices
    case premium
    case business
    case stars
    case ton
    case stories
    case myProfile
    case gift
    case powerSaving
}

public enum SettingsSearchableItemPresentation {
    case push
    case modal
    case immediate
    case dismiss
}

public struct SettingsSearchableItem {
    public let id: AnyHashable
    let title: String
    let alternate: [String]
    let icon: SettingsSearchableItemIcon
    let breadcrumbs: [String]
    let isVisible: Bool
    public let present: (AccountContext, NavigationController?, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void
    
    init(
        id: AnyHashable,
        title: String = "",
        alternate: [String] = [],
        icon: SettingsSearchableItemIcon = .privacy,
        breadcrumbs: [String] = [],
        isVisible: Bool = true,
        present: @escaping (AccountContext, NavigationController?, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void
    ) {
        self.id = id
        self.title = title
        self.alternate = alternate
        self.icon = icon
        self.breadcrumbs = breadcrumbs
        self.isVisible = isVisible
        self.present = present
    }
    
    func withUpdatedTitle(_ title: String) -> SettingsSearchableItem {
        return SettingsSearchableItem(id: self.id, title: title, alternate: self.alternate, icon: self.icon, breadcrumbs: self.breadcrumbs, isVisible: self.isVisible,  present: self.present)
    }
}

private func synonyms(_ string: String?) -> [String] {
    if let string = string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return string.components(separatedBy: "\n")
    } else {
        return []
    }
}

private func profileSearchableItems(
    context: AccountContext,
    canAddAccount: Bool
) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .profile
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    var items: [SettingsSearchableItem] = []
    
    items.append(
        SettingsSearchableItem(
            id: "search",
            isVisible: false,
            present: { context, _, present in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.openSettings(edit: false)
                    Queue.mainQueue().after(0.1) {
                        rootController.getSettingsController()?.tabBarActivateSearch()
                    }
                }
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "edit",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.openSettings(edit: true)
                }
            }
        )
    )
    //TODO:highlight
    items.append(
        SettingsSearchableItem(
            id: "edit/first-name",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.openSettings(edit: true)
                }
            }
        )
    )
    
    //TODO:highlight
    items.append(
        SettingsSearchableItem(
            id: "edit/last-name",
            icon: .profile,
            isVisible: false,
            present: { context, _, present in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.openSettings(edit: true)
                }
            }
        )
    )
    
    //TODO:highlight
    items.append(
        SettingsSearchableItem(
            id: "edit/bio",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.openSettings(edit: true)
                }
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "edit/change-number",
            title: strings.Settings_PhoneNumber,
            alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_PhoneNumber),
            icon: icon,
            breadcrumbs: [strings.EditProfile_Title],
            present: { context, _, present in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    var phoneNumber: String?
                    if case let .user(user) = peer {
                        phoneNumber = user.phone
                    }
                    present(.push, PrivacyIntroController(context: context, mode: .changePhoneNumber(phoneNumber ?? ""), proceedAction: {
                        present(.push, ChangePhoneNumberController(context: context))
                    }))
                })
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "edit/username",
            title: strings.Settings_Username,
            alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_Username),
            icon: icon,
            breadcrumbs: [strings.EditProfile_Title],
            present: { context, _, present in
                let controller = usernameSetupController(context: context)
                present(.modal, controller)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "edit/your-color",
            title: strings.Settings_YourColor,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.EditProfile_Title],
            present: { context, _, present in
                let controller = UserAppearanceScreen(context: context)
                present(.push, controller)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "edit/channel",
            title: strings.Settings_PersonalChannelItem,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.EditProfile_Title],
            present: { context, _, present in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let _ = (context.engine.peers.adminedPublicChannels(scope: .forPersonalProfile)
                |> deliverOnMainQueue).start(next: { personalChannels in
                    let _ = (PeerSelectionScreen.initialData(context: context, channels: personalChannels)
                    |> deliverOnMainQueue).start(next: { initialData in
                        present(.push, PeerSelectionScreen(context: context, initialData: initialData, updatedPresentationData: nil, completion: { channel in
                            if initialData.channelId == channel?.peer.id {
                                return
                            }
                            
                            let toastText: String
                            var mappedChannel: TelegramPersonalChannel?
                            if let channel {
                                mappedChannel = TelegramPersonalChannel(peerId: channel.peer.id, subscriberCount: channel.subscriberCount.flatMap(Int32.init(clamping:)), topMessageId: nil)
                                if initialData.channelId != nil {
                                    toastText = presentationData.strings.Settings_PersonalChannelUpdatedToast
                                } else {
                                    toastText = presentationData.strings.Settings_PersonalChannelAddedToast
                                }
                            } else {
                                toastText = presentationData.strings.Settings_PersonalChannelRemovedToast
                            }
                            let _ = context.engine.accountData.updatePersonalChannel(personalChannel: mappedChannel).startStandalone()
                            
                            present(.immediate, UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: toastText, cancel: nil, destructive: false), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
                        }))
                    })
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "edit/birthday",
            title: strings.Settings_Birthday,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.EditProfile_Title],
            present: { context, _, present in
                presentSetupBirthday(context: context, present: present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "emoji-status",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.openSettings(edit: false)
                    Queue.mainQueue().justDispatch {
                        if let settingsScreen = rootController.getSettingsController() as? PeerInfoScreen {
                            settingsScreen.openEmojiStatusSetup()
                        }
                    }
                }
            }
        )
    )

    items.append(
        SettingsSearchableItem(
            id: "profile-photo",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.openPhotoSetup(completedWithUploadingImage: { [weak rootController] _, _ in
                        rootController?.openSettings(edit: false)
                        return nil
                    })
                }
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "profile-photo/use-emoji",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                let controller = AvatarEditorScreen(context: context, inputData: AvatarEditorScreen.inputData(context: context, isGroup: false), peerType: .user, markup: nil)
                controller.imageCompletion = { image, commit in
                    if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface, let settingsController = rootController.getSettingsController() as? PeerInfoScreen {
                        settingsController.updateProfilePhoto(image)
                        commit()
                    }
                }
                controller.videoCompletion = { image, url, values, markup, commit in
                    if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface, let settingsController = rootController.getSettingsController() as? PeerInfoScreen {
                        settingsController.updateProfileVideo(image, video: nil, values: nil, markup: markup)
                        commit()
                    }
                }
                present(.push, controller)
            }
        )
    )
    
    if canAddAccount {
        items.append(
            SettingsSearchableItem(
                id: "edit/add-account",
                title: strings.Settings_AddAccount,
                alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_AddAccount),
                icon: icon,
                breadcrumbs: [strings.EditProfile_Title],
                present: { context, _, present in
                    let isTestingEnvironment = context.account.testingEnvironment
                    context.sharedContext.beginNewAuth(testingEnvironment: isTestingEnvironment)
                }
            )
        )
    }
    items.append(
        SettingsSearchableItem(
            id: "edit/log-out",
            title: strings.Settings_Logout,
            alternate: synonyms(strings.SettingsSearch_Synonyms_EditProfile_Logout),
            icon: icon,
            breadcrumbs: [strings.EditProfile_Title],
            present: { context, navigationController, present in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    var phoneNumber: String?
                    if case let .user(user) = peer {
                        phoneNumber = user.phone
                    }
                    if let navigationController {
                        present(.modal, logoutOptionsController(context: context, navigationController: navigationController, canAddAccounts: canAddAccount, phoneNumber: phoneNumber ?? ""))
                    }
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "profile-color",
            isVisible: false,
            present: { context, _, present in
                let controller = UserAppearanceScreen(context: context)
                present(.push, controller)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "profile-color/profile",
            isVisible: false,
            present: { context, _, present in
                let controller = UserAppearanceScreen(context: context)
                present(.push, controller)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "profile-color/profile/add-icons",
            isVisible: false,
            present: { context, _, present in
                let controller = UserAppearanceScreen(context: context, focusOnItemTag: .profileAddIcons)
                present(.push, controller)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "profile-color/profile/use-gift",
            isVisible: false,
            present: { context, _, present in
                let controller = UserAppearanceScreen(context: context, focusOnItemTag: .profileUseGift)
                present(.push, controller)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "profile-color/name",
            isVisible: false,
            present: { context, _, present in
                let controller = UserAppearanceScreen(context: context, focusOnItemTag: .name)
                present(.push, controller)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "profile-color/name/add-icons",
            isVisible: false,
            present: { context, _, present in
                let controller = UserAppearanceScreen(context: context, focusOnItemTag: .nameAddIcons)
                present(.push, controller)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "profile-color/name/use-gift",
            isVisible: false,
            present: { context, _, present in
                let controller = UserAppearanceScreen(context: context, focusOnItemTag: .nameUseGift)
                present(.push, controller)
            }
        )
    )
    
    return items
}

private func devicesSearchableItems(context: AccountContext, activeSessionsContext: ActiveSessionsContext?, webSessionsContext: WebSessionsContext?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .devices
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    var items: [SettingsSearchableItem] = []
    if let activeSessionsContext = activeSessionsContext {
        items.append(
            SettingsSearchableItem(
                id: "devices",
                title: strings.Settings_Devices,
                alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_AuthSessions) + [strings.PrivacySettings_AuthSessions],
                icon: icon,
                breadcrumbs: [],
                present: { context, _, present in
                    present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext ?? context.engine.privacy.webSessions(), websitesOnly: false))
                }
            )
        )
        items.append(
            SettingsSearchableItem(
                id: "devices/edit",
                icon: icon,
                isVisible: false,
                present: { context, _, present in
                    present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext ?? context.engine.privacy.webSessions(), websitesOnly: false, focusOnItemTag: .edit))
                }
            )
        )
        items.append(
            SettingsSearchableItem(
                id: "devices/terminate-sessions",
                title: strings.AuthSessions_TerminateOtherSessions,
                alternate: synonyms(strings.SettingsSearch_Synonyms_Devices_TerminateOtherSessions),
                icon: icon,
                breadcrumbs: [strings.Settings_Devices],
                present: { context, _, present in
                    present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext ?? context.engine.privacy.webSessions(), websitesOnly: false, focusOnItemTag: .terminateOtherSessions))
                }
            )
        )
        items.append(
            SettingsSearchableItem(
                id: "devices/link-desktop",
                title: strings.AuthSessions_LinkDesktopDevice,
                alternate: synonyms(strings.SettingsSearch_Synonyms_Devices_LinkDesktopDevice),
                icon: icon,
                breadcrumbs: [strings.Settings_Devices],
                present: { context, _, present in
                    present(.push, QrCodeScanScreen(context: context, subject: .authTransfer(activeSessionsContext: activeSessionsContext)))
                }
            )
        )
        items.append(
            SettingsSearchableItem(
                id: "devices/auto-terminate",
                icon: icon,
                isVisible: false,
                present: { context, _, present in
                    present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext ?? context.engine.privacy.webSessions(), websitesOnly: false, focusOnItemTag: .autoTerminate))
                }
            )
        )
    }
    return items
}

private func premiumSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .premium
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    var items: [SettingsSearchableItem] = []
        
    items.append(
        SettingsSearchableItem(
            id: "premium",
            title: strings.Settings_Premium,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                present(.push, PremiumIntroScreen(context: context, source: .settings, modal: false))
            }
        )
    )
    
    let presentDemo: (PremiumDemoScreen.Subject, (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { subject, present in
        var replaceImpl: ((ViewController) -> Void)?
        let controller = PremiumDemoScreen(context: context, subject: subject, action: {
            let controller = PremiumIntroScreen(context: context, source: .settings, modal: false)
            replaceImpl?(controller)
        })
        replaceImpl = { [weak controller] c in
            controller?.replace(with: c)
        }
        present(.push, controller)
    }
    
    let openResolvedUrl: (ResolvedUrl, NavigationController?, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { resolvedUrl, navigationController, present in
        context.sharedContext.openResolvedUrl(
            resolvedUrl,
            context: context,
            urlContext: .generic,
            navigationController: navigationController,
            forceExternal: false,
            forceUpdate: false,
            openPeer: { peer, navigation in },
            sendFile: nil,
            sendSticker: nil,
            sendEmoji: nil,
            requestMessageActionUrlAuth: nil,
            joinVoiceChat: nil,
            present: { controller, arguments in
                present(.push, controller)
            },
            dismissInput: {},
            contentContext: nil,
            progress: nil,
            completion: nil
        )
    }
    
    items.append(
        SettingsSearchableItem(
            id: "premium/doubled-limits",
            title: strings.Premium_DoubledLimits,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_DoubledLimits),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { _, _, present in
                presentDemo(.doubleLimits, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/unlimited-cloud-storage",
            title: strings.Premium_UploadSize,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_UploadSize),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.moreUpload, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/faster-download-speed",
            title: strings.Premium_FasterSpeed,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_FasterSpeed),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.fasterDownload, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/voice-to-text",
            title: strings.Premium_VoiceToText,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_VoiceToText),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.voiceToText, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/no-ads",
            title: strings.Premium_NoAds,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_NoAds),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.noAds, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/emoji-statuses",
            title: strings.Premium_EmojiStatus,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_EmojiStatus),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.emojiStatus, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/unique-reactions",
            title: strings.Premium_Reactions,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_Reactions),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.uniqueReactions, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/premium-stickers",
            title: strings.Premium_Stickers,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_Stickers),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.premiumStickers, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/animated-emoji",
            title: strings.Premium_AnimatedEmoji,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_AnimatedEmoji),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.animatedEmoji, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/advanced-chat-management",
            title: strings.Premium_ChatManagement,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_ChatManagement),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.advancedChatManagement, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/profile-badge",
            title: strings.Premium_Badge,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_Badge),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.profileBadge, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/animated-profile-pictures",
            title: strings.Premium_Avatar,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_Avatar),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.animatedUserpics, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "premium/app-icons",
            title: strings.Premium_AppIcon,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Premium_AppIcon),
            icon: icon,
            breadcrumbs: [strings.Settings_Premium],
            present: { context, _, present in
                presentDemo(.appIcons, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "business",
            title: strings.Settings_Business,
            alternate: [],
            icon: .business,
            breadcrumbs: [],
            present: { context, _, present in
                present(.push, PremiumIntroScreen(context: context, mode: .business, source: .settings, modal: false))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "business/do-not-hide-ads",
            title: strings.Business_DontHideAds,
            alternate: [],
            icon: .business,
            breadcrumbs: [strings.Settings_Business],
            present: { context, _, present in
                present(.push, PremiumIntroScreen(context: context, mode: .business, source: .settings, modal: false, focusOnItemTag: .doNotHideAds))
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "stars",
            title: strings.Settings_Stars,
            alternate: [],
            icon: .stars,
            breadcrumbs: [],
            present: { context, _, present in
                guard let starsContext = context.starsContext else {
                    return
                }
                let controller = context.sharedContext.makeStarsTransactionsScreen(context: context, starsContext: starsContext)
                present(.push, controller)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "stars/top-up",
            icon: .stars,
            isVisible: false,
            present: { context, navigationController, present in
                openResolvedUrl(.starsTopup(amount: nil, purpose: nil), navigationController, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "stars/stats",
            icon: .stars,
            isVisible: false,
            present: { context, navigationController, present in
                let starsRevenueStatsContext = StarsRevenueStatsContext(account: context.account, peerId: context.account.peerId, ton: false)
                let controller = context.sharedContext.makeStarsStatisticsScreen(context: context, peerId: context.account.peerId, revenueContext: starsRevenueStatsContext)
                present(.push, controller)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "stars/gift",
            icon: .stars,
            isVisible: false,
            present: { context, navigationController, present in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let _ = combineLatest(queue: Queue.mainQueue(),
                    context.engine.payments.starsTopUpOptions(),
                    context.account.stateManager.contactBirthdays |> take(1)
                ).start(next: { [weak navigationController] options, birthdays in
                    guard let starsContext = context.starsContext else {
                        return
                    }
                    let controller = context.sharedContext.makeStarsGiftController(context: context, birthdays: birthdays, completion: { [weak navigationController] peerIds in
                        guard let peerId = peerIds.first else {
                            return
                        }
                        let purchaseController = context.sharedContext.makeStarsPurchaseScreen(
                            context: context,
                            starsContext: starsContext,
                            options: options,
                            purpose: .gift(peerId: peerId),
                            targetPeerId: nil,
                            customTheme: nil,
                            completion: { [weak navigationController] stars in
                                if let navigationController {
                                    var controllers = navigationController.viewControllers
                                    controllers = controllers.filter { !($0 is ContactSelectionController) }
                                    navigationController.setViewControllers(controllers, animated: true)
                                }
                                
                                Queue.mainQueue().after(2.0) {
                                    let resultController = UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .universal(
                                            animation: "StarsSend",
                                            scale: 0.066,
                                            colors: [:],
                                            title: nil,
                                            text: presentationData.strings.Stars_Intro_StarsSent(Int32(stars)),
                                            customUndoText: presentationData.strings.Stars_Intro_StarsSent_ViewChat,
                                            timeout: nil
                                        ),
                                        elevatedLayout: false,
                                        action: { [weak navigationController] action in
                                            if case .undo = action, let navigationController {
                                                let _ = (context.engine.data.get(
                                                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                                                )
                                                |> deliverOnMainQueue).start(next: { peer in
                                                    guard let peer else {
                                                        return
                                                    }
                                                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), subject: nil, botStart: nil, updateTextInputState: nil, keepStack: .always, useExisting: true, purposefulAction: nil, scrollToEndIfExists: false, activateMessageSearch: nil, animated: true))
                                                })
                                            }
                                            return true
                                        }
                                    )
                                    present(.immediate, resultController)
                                }
                            }
                        )
                        present(.push, purchaseController)
                    })
                    present(.push, controller)
                })
            }
        )
    )
    
    var canJoinRefProgram = false
    if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_connect_allowed"] {
        if let value = value as? Double {
            canJoinRefProgram = value != 0.0
        } else if let value = value as? Bool {
            canJoinRefProgram = value
        }
    }
    if canJoinRefProgram {
        items.append(
            SettingsSearchableItem(
                id: "stars/earn",
                title: strings.Monetization_EarnStarsInfo_Title,
                alternate: [],
                icon: .stars,
                breadcrumbs: [strings.Settings_Stars],
                present: { context, navigationController, present in
                    let _ = (context.sharedContext.makeAffiliateProgramSetupScreenInitialData(context: context, peerId: context.account.peerId, mode: .connectedPrograms)
                    |> deliverOnMainQueue).startStandalone(next: { initialData in
                        let controller = context.sharedContext.makeAffiliateProgramSetupScreen(context: context, initialData: initialData)
                        present(.push, controller)
                    })
                }
            )
        )
    }
    
    items.append(
        SettingsSearchableItem(
            id: "ton",
            title: strings.Settings_MyTon,
            alternate: [],
            icon: .ton,
            breadcrumbs: [],
            present: { context, _, present in
                guard let tonContext = context.tonContext else {
                    return
                }
                let controller = context.sharedContext.makeStarsTransactionsScreen(context: context, starsContext: tonContext)
                present(.push, controller)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "send-gift",
            title: strings.Settings_SendGift,
            alternate: [],
            icon: .gift,
            breadcrumbs: [],
            present: { context, navigationController, present in
                openResolvedUrl(.sendGift(peerId: nil), navigationController, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "send-gift/self",
            title: strings.Settings_SendGift,
            alternate: [],
            icon: .gift,
            breadcrumbs: [],
            isVisible: false,
            present: { context, navigationController, present in
                openResolvedUrl(.sendGift(peerId: context.account.peerId), navigationController, present)
            }
        )
    )
   
    return items
}

private func myProfileSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    var items: [SettingsSearchableItem] = []
    
    items.append(
        SettingsSearchableItem(
            id: "qr-code",
            isVisible: false,
            present: { context, _, present in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer?._asPeer() else {
                        return
                    }
                    let controller = context.sharedContext.makeChatQrCodeScreen(context: context, peer: peer, threadId: nil, temporary: false)
                    present(.push, controller)
                })
            }
        )
    )
    
    //TODO:fix
    items.append(
        SettingsSearchableItem(
            id: "qr-code/share",
            isVisible: false,
            present: { context, _, present in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer?._asPeer() else {
                        return
                    }
                    let controller = context.sharedContext.makeChatQrCodeScreen(context: context, peer: peer, threadId: nil, temporary: false)
                    present(.push, controller)
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "qr-code/scan",
            isVisible: false,
            present: { context, _, present in
                let scanController = QrCodeScanScreen(context: context, subject: .peer)
                present(.push, scanController)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "my-profile",
            title: strings.Settings_MyProfile,
            alternate: [],
            icon: .myProfile,
            breadcrumbs: [],
            present: { context, _, present in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer?._asPeer() else {
                        return
                    }
                    let controller = context.sharedContext.makePeerInfoController(
                        context: context,
                        updatedPresentationData: nil,
                        peer: peer,
                        mode: .myProfile,
                        avatarInitiallyExpanded: false,
                        fromChat: false,
                        requestsContext: nil
                    )
                    present(.push, controller)
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "my-profile/edit",
            icon: .myProfile,
            isVisible: false,
            present: { context, _, present in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer?._asPeer() else {
                        return
                    }
                    let controller = context.sharedContext.makePeerInfoController(
                        context: context,
                        updatedPresentationData: nil,
                        peer: peer,
                        mode: .myProfile,
                        avatarInitiallyExpanded: false,
                        fromChat: false,
                        requestsContext: nil
                    )
                    present(.push, controller)
                    
                    Queue.mainQueue().justDispatch {
                        if let controller = controller as? PeerInfoScreen {
                            controller.activateEdit()
                        }
                    }
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "my-profile/gifts",
            title: strings.Gift_Options_Gift_Filter_MyGifts,
            alternate: [],
            icon: .myProfile,
            breadcrumbs: [strings.Settings_MyProfile],
            present: { context, _, present in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer?._asPeer() else {
                        return
                    }
                    let controller = context.sharedContext.makePeerInfoController(
                        context: context,
                        updatedPresentationData: nil,
                        peer: peer,
                        mode: .myProfileGifts,
                        avatarInitiallyExpanded: false,
                        fromChat: false,
                        requestsContext: nil
                    )
                    present(.push, controller)
                })
            }
        )
    )
        
    items.append(
        SettingsSearchableItem(
            id: "my-profile/posts",
            title: strings.Settings_MyStories,
            alternate: [],
            icon: .stories,
            breadcrumbs: [strings.Settings_MyProfile],
            present: { context, _, present in
                present(.push, PeerInfoStoryGridScreen(context: context, peerId: context.account.peerId, scope: .saved))
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "my-profile/posts/all-stories",
            icon: .stories,
            isVisible: false,
            present: { context, _, present in
                present(.push, PeerInfoStoryGridScreen(context: context, peerId: context.account.peerId, scope: .saved))
            }
        )
    )
    
    //TODO:fix
    items.append(
        SettingsSearchableItem(
            id: "my-profile/posts/add-album",
            icon: .stories,
            isVisible: false,
            present: { context, _, present in
                present(.push, PeerInfoStoryGridScreen(context: context, peerId: context.account.peerId, scope: .saved))
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "my-profile/archived-posts",
            title: strings.Settings_StoriesArchive,
            alternate: [],
            icon: .stories,
            breadcrumbs: [strings.Settings_MyProfile],
            present: { context, _, present in
                present(.push, PeerInfoStoryGridScreen(context: context, peerId: context.account.peerId, scope: .archive))
            }
        )
    )
   
    return items
}


private func callSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .calls
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentCallSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, CallListEntryTag?) -> Void = { context, present, itemTag in
        present(.push, CallListController(context: context, mode: .navigation, focusOnItemTag: itemTag))
    }
    return [
        SettingsSearchableItem(
            id: "calls",
            title: strings.CallSettings_RecentCalls,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Calls_Title),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentCallSettings(context, present, nil)
            }
        ),
        SettingsSearchableItem(
            id: "calls/all",
            title: strings.Calls_All,
            icon: icon,
            breadcrumbs: [strings.CallSettings_RecentCalls],
            isVisible: false,
            present: { context, _, present in
                presentCallSettings(context, present, nil)
            }
        ),
        SettingsSearchableItem(
            id: "calls/missed",
            title: strings.Calls_Missed,
            icon: icon,
            breadcrumbs: [strings.CallSettings_RecentCalls],
            isVisible: false,
            present: { context, _, present in
                presentCallSettings(context, present, .missed)
            }
        ),
        SettingsSearchableItem(
            id: "calls/edit",
            icon: icon,
            breadcrumbs: [strings.CallSettings_RecentCalls],
            isVisible: false,
            present: { context, _, present in
                presentCallSettings(context, present, .edit)
            }
        ),
        SettingsSearchableItem(
            id: "calls/show-tab",
            title: strings.CallSettings_TabIcon,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Calls_CallTab),
            icon: icon,
            breadcrumbs: [strings.CallSettings_RecentCalls],
            present: { context, _, present in
                presentCallSettings(context, present, .showTab)
            }
        ),
        SettingsSearchableItem(
            id: "calls/start-call",
            title: strings.Calls_StartNewCall,
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.startNewCall()
                }
            }
        )
    ]
}

private func chatFoldersSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .chatFolders
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentChatFoldersSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, ChatListFilterPresetListEntryTag?) -> Void = { context, present, itemTag in
        present(.push, chatListFilterPresetListController(context: context, mode: .default, focusOnItemTag: itemTag))
    }
 
    var items: [SettingsSearchableItem] = []
    
    items.append(
        SettingsSearchableItem(
            id: "folders",
            title: strings.Settings_ChatFolders,
            alternate: synonyms(strings.SettingsSearch_Synonyms_ChatFolders),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentChatFoldersSettings(context, present, nil)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "folders/edit",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatFolders],
            isVisible: false,
            present: { context, _, present in
                presentChatFoldersSettings(context, present, .edit)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "folders/create",
            title: strings.ChatListFolderSettings_NewFolder,
            icon: icon,
            breadcrumbs: [strings.Settings_ChatFolders],
            isVisible: false,
            present: { context, _, present in
                let filtersWithCounts = context.engine.peers.updatedChatListFilters()
                |> distinctUntilChanged
                |> mapToSignal { filters -> Signal<[(ChatListFilter, Int)], NoError> in
                    return .single(filters.map { filter -> (ChatListFilter, Int) in
                        return (filter, 0)
                    })
                }
                
                let _ = combineLatest(
                    queue: Queue.mainQueue(),
                    context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                        TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                        TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
                    ),
                    filtersWithCounts |> take(1)
                ).start(next: { result, filters in
                    let (accountPeer, limits, premiumLimits) = result
                    let isPremium = accountPeer?.isPremium ?? false
                    
                    let filters = filters.filter { filter in
                        if case .allChats = filter.0 {
                            return false
                        }
                        return true
                    }
                    
                    let limit = limits.maxFoldersCount
                    let premiumLimit = premiumLimits.maxFoldersCount
                    if filters.count >= premiumLimit {
                        let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {
                            return true
                        })
                        present(.push, controller)
                        return
                    } else if filters.count >= limit && !isPremium {
                        var replaceImpl: ((ViewController) -> Void)?
                        let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {
                            let controller = PremiumIntroScreen(context: context, source: .folders)
                            replaceImpl?(controller)
                            return true
                        })
                        replaceImpl = { [weak controller] c in
                            controller?.replace(with: c)
                        }
                        present(.push, controller)
                        return
                    }
                    present(.push, chatListFilterPresetController(context: context, currentPreset: nil, updated: { _ in }))
                })
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "folders/add-recommended",
            title: strings.ChatListFolderSettings_RecommendedFoldersSection.capitalized,
            icon: icon,
            breadcrumbs: [strings.Settings_ChatFolders],
            isVisible: false,
            present: { context, _, present in
                presentChatFoldersSettings(context, present, .addRecommended)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "folders/show-tags",
            title: strings.ChatListFilterList_ShowTags,
            icon: icon,
            breadcrumbs: [strings.Settings_ChatFolders],
            isVisible: false,
            present: { context, _, present in
                presentChatFoldersSettings(context, present, .displayTags)
            }
        )
    )

    return items
}

private func stickerSearchableItems(context: AccountContext, archivedStickerPacks: [ArchivedStickerPackItem]?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .stickers
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentStickerSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, InstalledStickerPacksControllerMode, InstalledStickerPacksEntryTag?) -> Void = { context, present, mode, itemTag in
        present(.push, installedStickerPacksController(context: context, mode: mode, archivedPacks: archivedStickerPacks, updatedPacks: { _ in }, focusOnItemTag: itemTag))
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji",
            title: strings.ChatSettings_Stickers,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_Title),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentStickerSettings(context, present, .general, nil)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/edit",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentStickerSettings(context, present, .general, .edit)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/suggest-by-emoji",
            title: strings.Stickers_SuggestStickers,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_SuggestStickers),
            icon: icon,
            breadcrumbs: [strings.ChatSettings_Stickers],
            present: { context, _, present in
                presentStickerSettings(context, present, .general, .suggestOptions)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/trending",
            title: strings.StickerPacksSettings_FeaturedPacks,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_FeaturedPacks),
            icon: icon,
            breadcrumbs: [strings.ChatSettings_Stickers],
            present: { context, _, present in
                present(.push, featuredStickerPacksController(context: context))
            }
        )
    )
    if !(archivedStickerPacks?.isEmpty ?? true) {
        items.append(
            SettingsSearchableItem(
                id: "appearance/stickers-and-emoji/archived",
                title: strings.StickerPacksSettings_ArchivedPacks,
                alternate: synonyms(strings.SettingsSearch_Synonyms_Stickers_ArchivedPacks),
                icon: icon,
                breadcrumbs: [strings.ChatSettings_Stickers],
                present: { context, _, present in
                    present(.push, archivedStickerPacksController(context: context, mode: .stickers, archived: archivedStickerPacks, updatedPacks: { _ in }))
                }
            )
        )
        items.append(
            SettingsSearchableItem(
                id: "appearance/stickers-and-emoji/archived/edit",
                icon: icon,
                isVisible: false,
                present: { context, _, present in
                    present(.push, archivedStickerPacksController(context: context, mode: .stickers, archived: archivedStickerPacks, updatedPacks: { _ in }, forceEdit: true))
                }
            )
        )
    }
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/large",
            title: strings.Appearance_LargeEmoji,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_LargeEmoji),
            icon: icon,
            breadcrumbs: [strings.ChatSettings_Stickers],
            present: { context, _, present in
                presentStickerSettings(context, present, .general, .largeEmoji)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/dynamic-order",
            title: strings.StickerPacksSettings_DynamicOrder,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.ChatSettings_Stickers],
            present: { context, _, present in
                presentStickerSettings(context, present, .general, .dynamicOrder)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/emoji",
            title: strings.StickerPacksSettings_Emoji,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.ChatSettings_Stickers],
            present: { context, _, present in
                presentStickerSettings(context, present, .emoji, nil)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/emoji/edit",
            icon: icon,
            breadcrumbs: [strings.StickerPacksSettings_Emoji],
            isVisible: false,
            present: { context, _, present in
                presentStickerSettings(context, present, .emoji, .edit)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/emoji/suggest",
            icon: icon,
            breadcrumbs: [strings.StickerPacksSettings_Emoji],
            present: { context, _, present in
                presentStickerSettings(context, present, .emoji, .suggestOptions)
            }
        )
    )
    if !(archivedStickerPacks?.isEmpty ?? true) {
        //TODO:fix
        items.append(
            SettingsSearchableItem(
                id: "appearance/stickers-and-emoji/emoji/archived",
                title: strings.StickerPacksSettings_ArchivedPacks,
                alternate: [],
                icon: icon,
                breadcrumbs: [strings.ChatSettings_Stickers],
                isVisible: false,
                present: { context, _, present in
                    present(.push, archivedStickerPacksController(context: context, mode: .emoji, archived: archivedStickerPacks, updatedPacks: { _ in }))
                }
            )
        )
        items.append(
            SettingsSearchableItem(
                id: "appearance/stickers-and-emoji/emoji/archived/edit",
                icon: icon,
                isVisible: false,
                present: { context, _, present in
                    present(.push, archivedStickerPacksController(context: context, mode: .emoji, archived: archivedStickerPacks, updatedPacks: { _ in }, forceEdit: true))
                }
            )
        )
    }
    
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/emoji/quick-reaction",
            title: strings.Settings_QuickReactionSetup_Title,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.ChatSettings_Stickers],
            present: { context, _, present in
                present(.push, quickReactionSetupController(context: context))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "appearance/stickers-and-emoji/emoji/quick-reaction/choose",
            icon: icon,
            breadcrumbs: [strings.ChatSettings_Stickers, strings.Settings_QuickReactionSetup_Title],
            isVisible: false,
            present: { context, _, present in
                present(.push, quickReactionSetupController(context: context, focusOnItemTag: .choose))
            }
        )
    )
    
    return items
}

private func notificationSearchableItems(context: AccountContext, settings: GlobalNotificationSettingsSet, exceptionsList: NotificationExceptionsList?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .notifications
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentNotificationSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, NotificationsAndSoundsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, notificationsAndSoundsController(context: context, exceptionsList: exceptionsList, focusOnItemTag: itemTag))
    }
        
    let defaultStorySettings = PeerStoryNotificationSettings.default
    let exceptions = { () -> (NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode) in
        var users:[PeerId : NotificationExceptionWrapper] = [:]
        var groups: [PeerId : NotificationExceptionWrapper] = [:]
        var channels: [PeerId : NotificationExceptionWrapper] = [:]
        var stories: [PeerId : NotificationExceptionWrapper] = [:]
        
        if let list = exceptionsList {
            for (key, value) in list.settings {
                if let peer = list.peers[key], !peer.debugDisplayTitle.isEmpty, peer.id != context.account.peerId {
                    if value.storySettings != defaultStorySettings {
                        stories[key] = NotificationExceptionWrapper(settings: value, peer: EnginePeer(peer))
                    }
                    
                    switch value.muteState {
                        case .default:
                            switch value.messageSound {
                                case .default:
                                    break
                                default:
                                    switch key.namespace {
                                        case Namespaces.Peer.CloudUser:
                                            users[key] = NotificationExceptionWrapper(settings: value, peer: EnginePeer(peer))
                                        default:
                                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                                channels[key] = NotificationExceptionWrapper(settings: value, peer: .channel(peer))
                                            } else {
                                                groups[key] = NotificationExceptionWrapper(settings: value, peer: EnginePeer(peer))
                                            }
                                    }
                            }
                        default:
                            switch key.namespace {
                                case Namespaces.Peer.CloudUser:
                                    users[key] = NotificationExceptionWrapper(settings: value, peer: EnginePeer(peer))
                                default:
                                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                        channels[key] = NotificationExceptionWrapper(settings: value, peer: .channel(peer))
                                    } else {
                                        groups[key] = NotificationExceptionWrapper(settings: value, peer: EnginePeer(peer))
                                    }
                            }
                    }
                }
            }
        }
        return (.users(users), .groups(groups), .channels(channels), .stories(stories))
    }
    
    func filteredGlobalSound(_ sound: PeerMessageSound) -> PeerMessageSound {
        if case .default = sound {
            return defaultCloudPeerNotificationSound
        } else {
            return sound
        }
    }
    
    let presentNotificationCategorySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, NotificationsPeerCategory, NotificationsPeerCategoryEntryTag?) -> Void = { context, present, category, itemTag in
        let exceptionMode = exceptions()
        let mode: NotificationExceptionMode
        switch category {
        case .privateChat:
            mode = exceptionMode.0
        case .group:
            mode = exceptionMode.1
        case .channel:
            mode = exceptionMode.2
        case .stories:
            mode = exceptionMode.3
        }
        present(.push, notificationsPeerCategoryController(context: context, category: category, mode: mode, updatedMode: { _ in }, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(
            id: "notifications",
            title: strings.Settings_NotificationsAndSounds,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_Title),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentNotificationSettings(context, present, nil)
            }
        ),
        
        SettingsSearchableItem(
            id: "notifications/accounts",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds],
            isVisible: false,
            present: { context, _, present in
                presentNotificationSettings(context, present, .allAccounts)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/private-chats",
            title: strings.Notifications_PrivateChats,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsSound),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized],
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .privateChat, nil)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/private-chats/edit",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_PrivateChats],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .privateChat, .edit)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/private-chats/show",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_PrivateChats],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .privateChat, .enable)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/private-chats/preview",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_PrivateChats],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .privateChat, .previews)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/private-chats/sound",
            title: strings.Notifications_MessageNotificationsSound,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsSound),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_PrivateChats],
            present: { context, _, present in
                let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: filteredGlobalSound(settings.privateChats.sound), defaultSound: nil, completion: { value in
                    let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                        var settings = settings
                        settings.privateChats.sound = value
                        return settings
                    }).start()
                })
                present(.modal, controller)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/private-chats/add-exception",
            title: strings.Notifications_MessageNotificationsExceptions,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsExceptions),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_PrivateChats],
            present: { context, _, present in
                present(.push, NotificationExceptionsController(context: context, mode: exceptions().0, updatedMode: { _ in}))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/private-chats/delete-exceptions",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_PrivateChats],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .privateChat, .deleteExceptions)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/groups",
            title: strings.Notifications_GroupChats,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized],
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .group, nil)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/groups/edit",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupChats],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .group, .edit)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/groups/show",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupChats],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .group, .enable)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/groups/preview",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupChats],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .group, .previews)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/groups/sound",
            title: strings.Notifications_GroupNotificationsSound,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsSound),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupChats],
            present: { context, _, present in
                let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: filteredGlobalSound(settings.groupChats.sound), defaultSound: nil, completion: { value in
                    let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                        var settings = settings
                        settings.groupChats.sound = value
                        return settings
                    }).start()
                })
                present(.modal, controller)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/groups/add-exception",
            title: strings.Notifications_GroupNotificationsExceptions,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_GroupNotificationsExceptions),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupChats],
            present: { context, _, present in
                present(.push, NotificationExceptionsController(context: context, mode: exceptions().1, updatedMode: { _ in}))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/groups/delete-exceptions",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_GroupChats],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .group, .deleteExceptions)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/channels",
            title: strings.Notifications_Channels,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized],
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .channel, nil)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/channels/edit",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Channels],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .channel, .edit)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/channels/show",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Channels],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .channel, .enable)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/channels/preview",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Channels],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .channel, .previews)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/channels/sound",
            title: strings.Notifications_ChannelNotificationsSound,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsSound),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Channels],
            present: { context, _, present in
                let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: filteredGlobalSound(settings.channels.sound), defaultSound: nil, completion: { value in
                    let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                        var settings = settings
                        settings.channels.sound = value
                        return settings
                    }).start()
                })
                present(.modal, controller)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/channels/add-exception",
            title: strings.Notifications_MessageNotificationsExceptions,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ChannelNotificationsExceptions),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Channels],
            present: { context, _, present in
                present(.push, NotificationExceptionsController(context: context, mode: exceptions().2, updatedMode: { _ in}))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/channels/delete-exceptions",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Channels],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .channel, .deleteExceptions)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/stories",
            title: strings.Notifications_Stories,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsSound),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_MessageNotifications.capitalized],
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .stories, nil)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/stories/new",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Stories],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .stories, .enable)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/stories/important",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Stories],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .stories, .important)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/stories/show-sender",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Stories],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .stories, .previews)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/stories/sound",
            title: strings.Notifications_MessageNotificationsSound,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Stories],
            present: { context, _, present in
                let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: filteredGlobalSound(settings.privateChats.storySettings.sound), defaultSound: nil, completion: { value in
                    let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                        var settings = settings
                        settings.privateChats.storySettings.sound = value
                        return settings
                    }).start()
                })
                present(.modal, controller)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/stories/add-exception",
            title: strings.Notifications_MessageNotificationsExceptions,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_MessageNotificationsExceptions),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Stories],
            present: { context, _, present in
                present(.push, NotificationExceptionsController(context: context, mode: exceptions().3, updatedMode: { _ in}))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/stories/delete-exceptions",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Stories],
            isVisible: false,
            present: { context, _, present in
                presentNotificationCategorySettings(context, present, .stories, .deleteExceptions)
            }
        ),
        
        SettingsSearchableItem(
            id: "notifications/reactions",
            title: strings.Notifications_Reactions,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds],
            present: { context, _, present in
                present(.push, reactionNotificationSettingsController(context: context))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/reactions/messages",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Reactions],
            isVisible: false,
            present: { context, _, present in
                present(.push, reactionNotificationSettingsController(context: context, focusOnItemTag: .messages))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/reactions/stories",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Reactions],
            isVisible: false,
            present: { context, _, present in
                present(.push, reactionNotificationSettingsController(context: context, focusOnItemTag: .stories))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/reactions/show-sender",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Reactions],
            isVisible: false,
            present: { context, _, present in
                present(.push, reactionNotificationSettingsController(context: context, focusOnItemTag: .showSender))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/reactions/sound",
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Reactions],
            isVisible: false,
            present: { context, _, present in
                present(.push, reactionNotificationSettingsController(context: context, focusOnItemTag: .sound))
            }
        ),
        SettingsSearchableItem(
            id: "notifications/in-app-sounds",
            title: strings.Notifications_InAppNotificationsSounds,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsSound),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized],
            present: { context, _, present in
                presentNotificationSettings(context, present, .inAppSounds)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/in-app-vibrate",
            title: strings.Notifications_InAppNotificationsVibrate,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsVibrate),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized],
            present: { context, _, present in
                presentNotificationSettings(context, present, .inAppVibrate)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/in-app-preview",
            title: strings.Notifications_InAppNotificationsPreview,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_InAppNotificationsPreview),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_InAppNotifications.capitalized],
            present: { context, _, present in
                presentNotificationSettings(context, present, .inAppPreviews)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/lock-screen-names",
            title: strings.Notifications_DisplayNamesOnLockScreen,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_DisplayNamesOnLockScreen),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds],
            present: { context, _, present in
                presentNotificationSettings(context, present, .displayNamesOnLockscreen)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/include-channels",
            title: strings.Notifications_Badge_IncludeChannels,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChannels),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized],
            present: { context, _, present in
                presentNotificationSettings(context, present, .includeChannels)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/count-unread-messages",
            title: strings.Notifications_Badge_CountUnreadMessages,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_BadgeCountUnreadMessages),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds, strings.Notifications_Badge.capitalized],
            present: { context, _, present in
                presentNotificationSettings(context, present, .unreadCountCategory)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/new-contacts",
            title: strings.NotificationSettings_ContactJoined,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ContactJoined),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds],
            present: { context, _, present in
                presentNotificationSettings(context, present, .joinedNotifications)
            }
        ),
        SettingsSearchableItem(
            id: "notifications/reset",
            title: strings.Notifications_ResetAllNotifications,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Notifications_ResetAllNotifications),
            icon: icon,
            breadcrumbs: [strings.Settings_NotificationsAndSounds],
            present: { context, _, present in
                presentNotificationSettings(context, present, .reset)
            }
        )
    ]
}

private func privacySearchableItems(context: AccountContext, privacySettings: AccountPrivacySettings?, activeSessionsContext: ActiveSessionsContext?, webSessionsContext: WebSessionsContext?) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .privacy
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentPrivacySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, PrivacyAndSecurityEntryTag?) -> Void = { context, present, itemTag in
        present(.push, privacyAndSecurityController(context: context, focusOnItemTag: itemTag))
    }
    
    let presentSelectivePrivacySettings: (AccountContext, SelectivePrivacySettingsKind, SelectivePrivacyEntryTag?, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { context, kind, focusOnItemTag, present in
        let privacySignal: Signal<AccountPrivacySettings, NoError>
        if let privacySettings = privacySettings {
            privacySignal = .single(privacySettings)
        } else {
            privacySignal = context.engine.privacy.requestAccountPrivacySettings()
        }
        let callsSignal: Signal<(VoiceCallSettings, VoipConfiguration)?, NoError>
        if case .voiceCalls = kind {
            callsSignal = combineLatest(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings]), context.account.postbox.preferencesView(keys: [PreferencesKeys.voipConfiguration]))
            |> take(1)
            |> map { sharedData, view -> (VoiceCallSettings, VoipConfiguration)? in
                let voiceCallSettings: VoiceCallSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? .defaultSettings
                let voipConfiguration = view.values[PreferencesKeys.voipConfiguration]?.get(VoipConfiguration.self) ?? .defaultValue
                return (voiceCallSettings, voipConfiguration)
            }
        } else {
            callsSignal = .single(nil)
        }

        let _ = (combineLatest(privacySignal, callsSignal)
        |> deliverOnMainQueue).start(next: { info, callSettings in
            let current: SelectivePrivacySettings
            switch kind {
            case .presence:
                current = info.presence
            case .groupInvitations:
                current = info.groupInvitations
            case .voiceCalls:
                current = info.voiceCalls
            case .profilePhoto:
                current = info.profilePhoto
            case .forwards:
                current = info.forwards
            case .phoneNumber:
                current = info.phoneNumber
            case .voiceMessages:
                current = info.voiceMessages
            case .bio:
                current = info.bio
            case .birthday:
                current = info.birthday
            case .savedMusic:
                current = info.savedMusic
            case .giftsAutoSave:
                current = info.giftsAutoSave
            }

            present(.push, selectivePrivacySettingsController(context: context, kind: kind, current: current, callSettings: callSettings != nil ? (info.voiceCallsP2P, callSettings!.0) : nil, voipConfiguration: callSettings?.1, callIntegrationAvailable: CallKitIntegration.isAvailable, focusOnItemTag: focusOnItemTag, updated: { updated, updatedCallSettings, _, _ in
                    if let (_, updatedCallSettings) = updatedCallSettings  {
                        let _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, { _ in
                            return updatedCallSettings
                        }).start()
                    }
                }))
        })
    }
    
    let presentMessagesPrivacySettings: (AccountContext, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void, IncomingMessagePrivacyEntryTag?) -> Void = { context, present, itemTag in
        let privacySignal: Signal<AccountPrivacySettings, NoError>
        if let privacySettings = privacySettings {
            privacySignal = .single(privacySettings)
        } else {
            privacySignal = context.engine.privacy.requestAccountPrivacySettings()
        }
        
        let _ = (privacySignal
        |> deliverOnMainQueue).start(next: { privacySettings in
            let controller = incomingMessagePrivacyScreen(context: context, value: privacySettings.globalSettings.nonContactChatsPrivacy, exceptions: privacySettings.noPaidMessages, update: { settingValue in
                let _ = (context.engine.privacy.updateNonContactChatsPrivacy(value: settingValue)
                |> mapToSignal { _ -> Signal<Void, NoError> in }
                |> deliverOnMainQueue).start()
            }, focusOnItemTag: itemTag)
            
            present(.push, controller)
        })
    }
    
    let presentMessageAutoRemove: (AccountContext, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void, GlobalAutoremoveEntryTag?) -> Void = { context, present, itemTag in
        let privacySignal: Signal<AccountPrivacySettings, NoError>
        if let privacySettings = privacySettings {
            privacySignal = .single(privacySettings)
        } else {
            privacySignal = context.engine.privacy.requestAccountPrivacySettings()
        }
        let _ = (privacySignal
        |> deliverOnMainQueue).start(next: { info in
            let controller = globalAutoremoveScreen(context: context, initialValue: info.messageAutoremoveTimeout ?? 0, updated: { _ in }, focusOnItemTag: itemTag)
            present(.push, controller)
        })
    }
    
    let presentDataPrivacySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, DataPrivacyEntryTag?) -> Void = { context, present, itemTag in
        present(.push, dataPrivacyController(context: context, focusOnItemTag: itemTag))
    }
    
    let presentBlockUser: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void) -> Void = { context, present in
        let blockedPeersContext = BlockedPeersContext(account: context.account, subject: .blocked)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyPrivateChats, .excludeSavedMessages, .removeSearchHeader, .excludeRecent, .doNotSearchMessages], title: presentationData.strings.BlockedUsers_SelectUserTitle))
        controller.peerSelected = { [weak controller] peer, _ in
            let peerId = peer.id
            
            guard let strongController = controller else {
                return
            }
            strongController.inProgress = true
            let _ = (blockedPeersContext.add(peerId: peerId)
            |> deliverOnMainQueue).start(completed: {
                guard let strongController = controller else {
                    return
                }
                strongController.inProgress = false
                strongController.dismiss()
            })
        }
        present(.push, controller)
    }
    
    let passcodeTitle: String
    let passcodeAlternate: [String]
    if let biometricAuthentication = LocalAuth.biometricAuthentication {
        switch biometricAuthentication {
            case .touchId:
                passcodeTitle = strings.PrivacySettings_PasscodeAndTouchId
                passcodeAlternate = synonyms(strings.SettingsSearch_Synonyms_Privacy_PasscodeAndTouchId)
            case .faceId:
                passcodeTitle = strings.PrivacySettings_PasscodeAndFaceId
                passcodeAlternate = synonyms(strings.SettingsSearch_Synonyms_Privacy_PasscodeAndFaceId)
        }
    } else {
        passcodeTitle = strings.PrivacySettings_Passcode
        passcodeAlternate = synonyms(strings.SettingsSearch_Synonyms_Privacy_Passcode)
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(
        SettingsSearchableItem(
            id: "privacy",
            title: strings.Settings_PrivacySettings,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Title),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentPrivacySettings(context, present, nil)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/blocked",
            title: strings.Settings_BlockedUsers,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_BlockedUsers),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                present(.push, blockedPeersController(context: context, blockedPeersContext: BlockedPeersContext(account: context.account, subject: .blocked)))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/blocked/edit",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Settings_BlockedUsers],
            isVisible: false,
            present: { context, _, present in
                present(.push, blockedPeersController(context: context, blockedPeersContext: BlockedPeersContext(account: context.account, subject: .blocked), forceEdit: true))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/blocked/block-user",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Settings_BlockedUsers],
            isVisible: false,
            present: { context, _, present in
                presentBlockUser(context, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/blocked/block-user/chats",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Settings_BlockedUsers],
            isVisible: false,
            present: { context, _, present in
                presentBlockUser(context, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/blocked/block-user/contacts",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Settings_BlockedUsers],
            isVisible: false,
            present: { context, _, present in
                presentBlockUser(context, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/last-seen",
            title: strings.PrivacySettings_LastSeen,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_LastSeen),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .presence, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/last-seen/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_LastSeen],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .presence, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/last-seen/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_LastSeen],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .presence, .alwaysAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/last-seen/hide-read-time",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_LastSeen],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .presence, .lastSeenHideReadTime, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/profile-photos",
            title: strings.Privacy_ProfilePhoto,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_ProfilePhoto),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .profilePhoto, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/profile-photos/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_ProfilePhoto],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .profilePhoto, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/profile-photos/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_ProfilePhoto],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .profilePhoto, .alwaysAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/profile-photos/set-public",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_ProfilePhoto],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .profilePhoto, .photoSetPublic, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/profile-photos/update-public",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_ProfilePhoto],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .profilePhoto, .photoUpdatePublic, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/profile-photos/remove-public",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_ProfilePhoto],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .profilePhoto, .photoRemovePublic, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/forwards",
            title: strings.Privacy_Forwards,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Forwards),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .forwards, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/forwards/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Forwards],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .forwards, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/forwards/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Forwards],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .forwards, .alwaysAllow, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/calls",
            title: strings.Privacy_Calls,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Calls),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceCalls, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/calls/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Calls],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceCalls, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/calls/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Calls],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceCalls, .alwaysAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/calls/p2p",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Calls],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceCalls, .callsP2P, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/calls/p2p/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Calls],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceCalls, .callsP2PNeverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/calls/p2p/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Calls],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceCalls, .callsP2PAlwaysAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/calls/ios-integration",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Calls],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceCalls, .callsIntegration, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/invites",
            title: strings.Privacy_GroupsAndChannels,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_GroupsAndChannels),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .groupInvitations, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/invites/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_GroupsAndChannels],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .groupInvitations, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/invites/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_GroupsAndChannels],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .groupInvitations, .alwaysAllow, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/bio",
            title: strings.Privacy_Bio,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .bio, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/bio/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Bio],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .bio, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/bio/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Bio],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .bio, .alwaysAllow, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/birthday",
            title: strings.Privacy_Birthday,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .birthday, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/birthday/add",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Birthday],
            isVisible: false,
            present: { context, _, present in
                presentSetupBirthday(context: context, present: present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/birthday/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Birthday],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .birthday, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/birthday/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Birthday],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .birthday, .alwaysAllow, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/gifts",
            title: strings.Privacy_Gifts,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .giftsAutoSave, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/gifts/show-icon",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Gifts],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .giftsAutoSave, .giftsShowButton, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/gifts/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Gifts],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .giftsAutoSave, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/gifts/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Gifts],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .giftsAutoSave, .alwaysAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/gifts/accepted-types",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_Gifts],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .giftsAutoSave, .giftsAcceptedTypes, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/phone-number",
            title: strings.Privacy_PhoneNumber,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .phoneNumber, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/phone-number/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_PhoneNumber],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .phoneNumber, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/phone-number/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_PhoneNumber],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .phoneNumber, .alwaysAllow, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/saved-music",
            title: strings.Privacy_SavedMusic,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .savedMusic, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/saved-music/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_SavedMusic],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .savedMusic, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/saved-music/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_SavedMusic],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .savedMusic, .alwaysAllow, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/voice",
            title: strings.Privacy_VoiceMessages,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceMessages, nil, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/voice/never",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_VoiceMessages],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceMessages, .neverAllow, present)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/voice/always",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Privacy_VoiceMessages],
            isVisible: false,
            present: { context, _, present in
                presentSelectivePrivacySettings(context, .voiceMessages, .alwaysAllow, present)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/messages",
            title: strings.Settings_Privacy_Messages,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentMessagesPrivacySettings(context, present, nil)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/messages/set-price",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Settings_Privacy_Messages],
            isVisible: false,
            present: { context, _, present in
                presentMessagesPrivacySettings(context, present, .setPrice)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/messages/remove-fee",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Settings_Privacy_Messages],
            isVisible: false,
            present: { context, _, present in
                presentMessagesPrivacySettings(context, present, .removeFee)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/passcode",
            title: passcodeTitle,
            alternate: passcodeAlternate,
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                let _ = passcodeOptionsAccessController(context: context, pushController: { c in
                    present(.push, c)
                }, completion: { animated in
                    let controller = passcodeOptionsController(context: context)
                    present(.push, controller)
                }).start(next: { controller in
                    if let controller {
                        present(.push, controller)
                    }
                })
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/passcode/disable",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, passcodeTitle],
            isVisible: false,
            present: { context, _, present in
                let _ = passcodeOptionsAccessController(context: context, pushController: { c in
                    present(.push, c)
                }, completion: { animated in
                    let controller = passcodeOptionsController(context: context, focusOnItemTag: .togglePasscode)
                    present(.push, controller)
                }).start(next: { controller in
                    if let controller {
                        present(.push, controller)
                    }
                })
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/passcode/change",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, passcodeTitle],
            isVisible: false,
            present: { context, _, present in
                let _ = passcodeOptionsAccessController(context: context, pushController: { c in
                    present(.push, c)
                }, completion: { animated in
                    let controller = passcodeOptionsController(context: context, focusOnItemTag: .changePasscode)
                    present(.push, controller)
                }).start(next: { controller in
                    if let controller {
                        present(.push, controller)
                    }
                })
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/passcode/auto-lock",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, passcodeTitle],
            isVisible: false,
            present: { context, _, present in
                let _ = passcodeOptionsAccessController(context: context, pushController: { c in
                    present(.push, c)
                }, completion: { animated in
                    let controller = passcodeOptionsController(context: context, focusOnItemTag: .autolock)
                    present(.push, controller)
                }).start(next: { controller in
                    if let controller {
                        present(.push, controller)
                    }
                })
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/passcode/face-id",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, passcodeTitle],
            isVisible: false,
            present: { context, _, present in
                let _ = passcodeOptionsAccessController(context: context, pushController: { c in
                    present(.push, c)
                }, completion: { animated in
                    let controller = passcodeOptionsController(context: context, focusOnItemTag: .touchId)
                    present(.push, controller)
                }).start(next: { controller in
                    if let controller {
                        present(.push, controller)
                    }
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/2sv",
            title: strings.PrivacySettings_TwoStepAuth,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_TwoStepAuth),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                present(.push, twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: true, data: nil)))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/2sv/change",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_TwoStepAuth],
            isVisible: false,
            present: { context, _, present in
                present(.push, twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: true, data: nil), focusOnItemTag: .change))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/2sv/disable",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_TwoStepAuth],
            isVisible: false,
            present: { context, _, present in
                present(.push, twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: true, data: nil), focusOnItemTag: .disable))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/2sv/change-email",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_TwoStepAuth],
            isVisible: false,
            present: { context, _, present in
                present(.push, twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: true, data: nil), focusOnItemTag: .changeEmail))
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/passkey",
            title: strings.PrivacySettings_Passkey,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                Task { @MainActor in
                    let initialPasskeysData = await (context.engine.auth.passkeysData() |> take(1)).get()
                    let passkeysScreen = PasskeysScreen(context: context, displaySkip: false, initialPasskeysData: initialPasskeysData, passkeysDataUpdated: { _ in
                    }, completion: {}, cancel: {})
                    present(.push, passkeysScreen)
                }
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/passkey/create",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_Passkey],
            isVisible: false,
            present: { context, _, present in
                Task { @MainActor in
                    let initialPasskeysData = await (context.engine.auth.passkeysData() |> take(1)).get()
                    let passkeysScreen = PasskeysScreen(context: context, displaySkip: false, initialPasskeysData: initialPasskeysData, forceCreate: true, passkeysDataUpdated: { _ in
                    }, completion: {}, cancel: {})
                    present(.push, passkeysScreen)
                }
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/auto-delete",
            title: strings.Settings_AutoDeleteTitle,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentMessageAutoRemove(context, present, nil)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/auto-delete/set-custom",
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.Settings_AutoDeleteTitle],
            isVisible: false,
            present: { context, _, present in
                presentMessageAutoRemove(context, present, .setCustom)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/login-email",
            title: strings.PrivacySettings_LoginEmail,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, navigationController, present in
                let settingsPromise: Promise<TwoStepAuthData?>
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface, let current = rootController.getTwoStepAuthData() {
                    settingsPromise = current
                } else {
                    settingsPromise = Promise()
                    settingsPromise.set(
                        context.engine.auth.twoStepAuthData()
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<TwoStepAuthData?, NoError> in
                            return .single(nil)
                        }
                    )
                }
                
                let _ = (settingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { twoStepAuthData in
                    let emailPattern = twoStepAuthData?.loginEmailPattern
                    let setupEmailImpl: (String?) -> Void = { emailPattern in
                        let controller = loginEmailSetupController(context: context, blocking: false, emailPattern: nil, navigationController: navigationController, completion: {}, dismiss: {})
                        present(.push, controller)
                    }
                    if let emailPattern, !emailPattern.contains(" ") {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let controller = textAlertController(
                            context: context, title: emailPattern, text: presentationData.strings.PrivacySettings_LoginEmailAlertText, actions: [
                                TextAlertAction(type: .defaultAction, title: presentationData.strings.PrivacySettings_LoginEmailAlertChange, action: {
                                    setupEmailImpl(emailPattern)
                                }),
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                })
                            ], actionLayout: .vertical
                        )
                        present(.immediate, controller)
                    } else {
                        setupEmailImpl(nil)
                    }
                })
            }
        )
    )
    
    if let webSessionsContext {
        items.append(
            SettingsSearchableItem(
                id: "privacy/active-websites",
                title: strings.PrivacySettings_WebSessions,
                alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_AuthSessions),
                icon: icon,
                breadcrumbs: [strings.Settings_PrivacySettings],
                present: { context, _, present in
                    present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext ?? context.engine.privacy.activeSessions(), webSessionsContext: webSessionsContext, websitesOnly: true))
                }
            )
        )
        items.append(
            SettingsSearchableItem(
                id: "privacy/active-websites/edit",
                isVisible: false,
                present: { context, _, present in
                    present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext ?? context.engine.privacy.activeSessions(), webSessionsContext: webSessionsContext, websitesOnly: true, focusOnItemTag: .edit))
                }
            )
        )
        items.append(
            SettingsSearchableItem(
                id: "privacy/active-websites/disconnect-all",
                isVisible: false,
                present: { context, _, present in
                    present(.push, recentSessionsController(context: context, activeSessionsContext: activeSessionsContext ?? context.engine.privacy.activeSessions(), webSessionsContext: webSessionsContext, websitesOnly: true, focusOnItemTag: .terminateOtherSessions))
                }
            )
        )
    }
    items.append(
        SettingsSearchableItem(
            id: "privacy/self-destruct",
            title: strings.PrivacySettings_DeleteAccountTitle.capitalized,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_DeleteAccountIfAwayFor),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentPrivacySettings(context, present, .accountTimeout)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/archive-and-mute",
            title: strings.PrivacySettings_AutoArchive,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentPrivacySettings(context, present, .autoArchive)
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy/data-settings",
            title: strings.PrivacySettings_DataSettings,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_Title),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings],
            present: { context, _, present in
                presentDataPrivacySettings(context, present, nil)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/data-settings/delete-synced",
            title: strings.Privacy_ContactsReset,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ContactsReset),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings],
            present: { context, _, present in
                presentDataPrivacySettings(context, present, .deleteSynced)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/data-settings/sync-contacts",
            title: strings.Privacy_ContactsSync,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ContactsSync),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings],
            present: { context, _, present in
                presentDataPrivacySettings(context, present, .syncContacts)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/data-settings/suggest-contacts",
            title: strings.Privacy_TopPeers,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_TopPeers),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings],
            present: { context, _, present in
                presentDataPrivacySettings(context, present, .suggestContacts)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/data-settings/delete-cloud-drafts",
            title: strings.Privacy_DeleteDrafts,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_DeleteDrafts),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings],
            present: { context, _, present in
                presentDataPrivacySettings(context, present, .deleteCloudDrafts)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/data-settings/clear-payment-info",
            title: strings.Privacy_PaymentsClearInfo,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_ClearPaymentsInfo),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings],
            present: { context, _, present in
                presentDataPrivacySettings(context, present, .clearPaymentInfo)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/data-settings/link-previews",
            title: strings.Privacy_SecretChatsLinkPreviews,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Privacy_Data_SecretChatLinkPreview),
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings, strings.Privacy_SecretChatsTitle.capitalized],
            present: { context, _, present in
                presentDataPrivacySettings(context, present, .linkPreviews)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "privacy/data-settings/bot-settings",
            title: strings.Settings_BotListSettings,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_PrivacySettings, strings.PrivacySettings_DataSettings],
            present: { context, _, present in
                let controller = context.sharedContext.makeBotSettingsScreen(context: context, peerId: nil)
                present(.push, controller)
            }
        )
    )
    return items
}

private func dataSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .data
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentDataSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, DataAndStorageEntryTag?) -> Void = { context, present, itemTag in
        present(.push, dataAndStorageController(context: context, focusOnItemTag: itemTag))
    }
    
    let presentDataUsage: (AccountContext, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void, DataUsageEntryTag?) -> Void = { context, present, itemTag in
        let mediaAutoDownloadSettings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings])
        |> map { sharedData -> MediaAutoDownloadSettings in
            var automaticMediaDownloadSettings: MediaAutoDownloadSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) {
                automaticMediaDownloadSettings = value
            } else {
                automaticMediaDownloadSettings = .defaultSettings
            }
            return automaticMediaDownloadSettings
        }
        
        let _ = (combineLatest(
            accountNetworkUsageStats(account: context.account, reset: []),
            mediaAutoDownloadSettings
        )
        |> take(1)
        |> deliverOnMainQueue).start(next: { stats, mediaAutoDownloadSettings in
            var stats = stats
            
            if stats.resetWifiTimestamp == 0 {
                var value = stat()
                if stat(context.account.basePath, &value) == 0 {
                    stats.resetWifiTimestamp = Int32(value.st_ctimespec.tv_sec)
                }
            }
            
            present(.push, DataUsageScreen(context: context, stats: stats, mediaAutoDownloadSettings: mediaAutoDownloadSettings, makeAutodownloadSettingsController: { isCellular in
                return autodownloadMediaConnectionTypeController(context: context, connectionType: isCellular ? .cellular : .wifi)
            }, focusOnItemTag: itemTag))
        })
    }
    
    let presentStorageUsage: (AccountContext, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void, StorageUsageEntryTag?) -> Void = { context, present, itemTag in
        let controller = StorageUsageScreen(context: context, makeStorageUsageExceptionsScreen: { category in
            return storageUsageExceptionsScreen(context: context, category: category)
        }, focusOnItemTag: itemTag)
        present(.push, controller)
    }
    
    let presentSaveIncomingMediaSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, AutomaticSaveIncomingPeerType, SaveIncomingMediaEntryTag?) -> Void = { context, present, peerType, itemTag in
        present(.push, saveIncomingMediaController(context: context, scope: .peerType(peerType), focusOnItemTag: itemTag))
    }
    
    let presentAutodownloadMediaSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, AutomaticDownloadConnectionType, AutodownloadMediaCategoryEntryTag?) -> Void = { context, present, connectionType, itemTag in
        present(.push, autodownloadMediaConnectionTypeController(context: context, connectionType: connectionType, focusOnItemTag: itemTag))
    }
    
    return [
        SettingsSearchableItem(
            id: "data",
            title: strings.Settings_ChatSettings,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_Title),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentDataSettings(context, present, nil)
            }
        ),
        SettingsSearchableItem(
            id: "data/storage",
            title: strings.ChatSettings_Cache,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_Storage_Title),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            present: { context, _, present in
                presentStorageUsage(context, present, nil)
            }
        ),
        SettingsSearchableItem(
            id: "data/storage/edit",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_Cache],
            isVisible: false,
            present: { context, _, present in
                presentStorageUsage(context, present, .edit)
            }
        ),
        SettingsSearchableItem(
            id: "data/storage/auto-remove",
            title: strings.Cache_KeepMedia,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_Storage_KeepMedia),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_Cache],
            present: { context, _, present in
                presentStorageUsage(context, present, .autoRemove)
            }
        ),
        SettingsSearchableItem(
            id: "data/storage/clear-cache",
            title: strings.Cache_ClearCache,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_Storage_ClearCache),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_Cache],
            present: { context, _, present in
                presentStorageUsage(context, present, .clearCache)
            }
        ),
        SettingsSearchableItem(
            id: "data/max-cache",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_Cache],
            isVisible: false,
            present: { context, _, present in
                presentStorageUsage(context, present, .maxCache)
            }
        ),
        SettingsSearchableItem(
            id: "data/usage",
            title: strings.NetworkUsageSettings_Title,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_NetworkUsage),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            present: { context, _, present in
                presentDataUsage(context, present, nil)
            }
        ),
        SettingsSearchableItem(
            id: "data/usage/mobile",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentDataUsage(context, present, .mobile)
            }
        ),
        SettingsSearchableItem(
            id: "data/usage/wifi",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentDataUsage(context, present, .wifi)
            }
        ),
        SettingsSearchableItem(
            id: "data/usage/reset",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentDataUsage(context, present, .reset)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/mobile",
            title: strings.ChatSettings_AutoDownloadUsingCellular,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoDownloadUsingCellular),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized],
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .cellular, nil)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/mobile/enable",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .cellular, .master)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/mobile/usage",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .cellular, .usage)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/mobile/photos",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .cellular, .photos)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/mobile/stories",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .cellular, .stories)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/mobile/videos",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .cellular, .videos)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/mobile/files",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .cellular, .files)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/wifi",
            title: strings.ChatSettings_AutoDownloadUsingWiFi,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoDownloadUsingWifi),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized],
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .wifi, nil)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/wifi/enable",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .wifi, .master)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/wifi/usage",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .wifi, .usage)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/wifi/photos",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .wifi, .photos)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/wifi/stories",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .wifi, .stories)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/wifi/videos",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .wifi, .videos)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/wifi/files",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_AutoDownloadTitle.capitalized, strings.ChatSettings_AutoDownloadUsingCellular],
            isVisible: false,
            present: { context, _, present in
                presentAutodownloadMediaSettings(context, present, .wifi, .files)
            }
        ),
        SettingsSearchableItem(
            id: "data/auto-download/reset",
            title: strings.ChatSettings_AutoDownloadReset,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_AutoDownloadReset),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            present: { context, _, present in
                presentDataSettings(context, present, .automaticDownloadReset)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/chats",
            title: strings.Notifications_PrivateChats,
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .privateChats, nil)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/chats/max-video-size",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_PrivateChats],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .privateChats, .maxVideoSize)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/chats/add-exception",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_PrivateChats],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .privateChats, .addException)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/chats/delete-all",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_PrivateChats],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .privateChats, .deleteExceptions)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/groups",
            title: strings.Notifications_GroupChats,
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .groups, nil)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/groups/max-video-size",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_GroupChats],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .groups, .maxVideoSize)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/groups/add-exception",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_GroupChats],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .groups, .addException)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/groups/delete-all",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_GroupChats],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .groups, .deleteExceptions)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/channels",
            title: strings.Notifications_Channels,
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .channels, nil)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/channels/max-video-size",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_Channels],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .channels, .maxVideoSize)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/channels/add-exception",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_Channels],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .channels, .addException)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-to-photos/channels/delete-all",
            icon: icon,
            breadcrumbs: [strings.Settings_SaveToCameraRollSection, strings.Notifications_Channels],
            isVisible: false,
            present: { context, _, present in
                presentSaveIncomingMediaSettings(context, present, .channels, .deleteExceptions)
            }
        ),
        SettingsSearchableItem(
            id: "data/use-less-data",
            title: strings.CallSettings_UseLessData,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_CallsUseLessData),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.Settings_CallSettings],
            present: { context, _, present in
                presentDataSettings(context, present, .useLessVoiceData)
            }
        ),
        SettingsSearchableItem(
            id: "data/save-edited-photos",
            title: strings.Settings_SaveEditedPhotos,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Data_SaveEditedPhotos),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            present: { context, _, present in
                presentDataSettings(context, present, .saveEditedPhotos)
            }
        ),
        SettingsSearchableItem(
            id: "data/pause-music",
            title: strings.Settings_PauseMusicOnRecording,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            present: { context, _, present in
                presentDataSettings(context, present, .pauseMusicOnRecording)
            }
        ),
        SettingsSearchableItem(
            id: "data/raise-to-listen",
            title: strings.Settings_RaiseToListen,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            present: { context, _, present in
                presentDataSettings(context, present, .raiseToListen)
            }
        ),
        SettingsSearchableItem(
            id: "data/show-18-content",
            title: strings.Settings_SensitiveContent,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            isVisible: false,
            present: { context, _, present in
                presentDataSettings(context, present, .sensitiveContent)
            }
        ),
        SettingsSearchableItem(
            id: "data/open-links",
            title: strings.ChatSettings_OpenLinksIn,
            alternate: synonyms(strings.SettingsSearch_Synonyms_ChatSettings_OpenLinksIn),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            present: { context, _, present in
                present(.push, webBrowserSettingsController(context: context))
            }
        ),
        SettingsSearchableItem(
            id: "data/share-sheet",
            title: strings.ChatSettings_IntentsSettings,
            alternate: synonyms(strings.SettingsSearch_Synonyms_ChatSettings_IntentsSettings),
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings],
            present: { context, _, present in
                present(.push, intentsSettingsController(context: context))
            }
        ),
        SettingsSearchableItem(
            id: "data/share-sheet/suggested-chats",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_IntentsSettings],
            isVisible: false,
            present: { context, _, present in
                present(.push, intentsSettingsController(context: context, focusOnItemTag: .suggested))
            }
        ),
        SettingsSearchableItem(
            id: "data/share-sheet/suggest-by",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_IntentsSettings],
            isVisible: false,
            present: { context, _, present in
                present(.push, intentsSettingsController(context: context, focusOnItemTag: .suggestBy))
            }
        ),
        SettingsSearchableItem(
            id: "data/share-sheet/reset",
            icon: icon,
            breadcrumbs: [strings.Settings_ChatSettings, strings.ChatSettings_IntentsSettings],
            isVisible: false,
            present: { context, _, present in
                present(.push, intentsSettingsController(context: context, focusOnItemTag: .reset))
            }
        )
    ]
}

private func proxySearchableItems(context: AccountContext, servers: [ProxyServerSettings]) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .proxy
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentProxySettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, ProxySettingsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, proxySettingsController(context: context, focusOnItemTag: itemTag))
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(
        SettingsSearchableItem(
            id: "data/proxy",
            title: strings.Settings_Proxy,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_Title),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentProxySettings(context, present, nil)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "data/proxy/edit",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentProxySettings(context, present, .edit)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "data/use-proxy",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentProxySettings(context, present, .useProxy)
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "data/proxy/add-proxy",
            title: strings.SocksProxySetup_AddProxy,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_AddProxy),
            icon: icon,
            breadcrumbs: [strings.Settings_Proxy],
            present: { context, _, present in
                present(.modal, proxyServerSettingsController(context: context))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "data/proxy/share-list",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentProxySettings(context, present, .shareList)
            }
        )
    )

    var hasSocksServers = false
    for server in servers {
        if case .socks5 = server.connection {
            hasSocksServers = true
            break
        }
    }
    if hasSocksServers {
        items.append(
            SettingsSearchableItem(
                id: "data/proxy/use-for-calls",
                title: strings.SocksProxySetup_UseForCalls,
                alternate: synonyms(strings.SettingsSearch_Synonyms_Proxy_UseForCalls),
                icon: icon,
                breadcrumbs: [strings.Settings_Proxy],
                present: { context, _, present in
                    presentProxySettings(context, present, .useForCalls)
                }
            )
        )
    }
    return items
}

private func energySavingSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .powerSaving
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentEnergySaving: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, EnergySavingItemType?) -> Void = { context, present, item in
        let controller = energySavingSettingsScreen(context: context, focusOnItemTag: item.flatMap { .item($0) })
        present(.push, controller)
    }
    
    return [
        SettingsSearchableItem(
            id: "power-saving",
            title: strings.Settings_PowerSaving,
            alternate: [],
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentEnergySaving(context, present, nil)
            }
        ),
        SettingsSearchableItem(
            id: "power-saving/videos",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentEnergySaving(context, present, .autoplayVideo)
            }
        ),
        SettingsSearchableItem(
            id: "power-saving/gifs",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentEnergySaving(context, present, .autoplayGif)
            }
        ),
        SettingsSearchableItem(
            id: "power-saving/stickers",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentEnergySaving(context, present, .loopStickers)
            }
        ),
        SettingsSearchableItem(
            id: "power-saving/emoji",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentEnergySaving(context, present, .loopEmoji)
            }
        ),
        SettingsSearchableItem(
            id: "power-saving/effects",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentEnergySaving(context, present, .fullTranslucency)
            }
        ),
        SettingsSearchableItem(
            id: "power-saving/preload",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentEnergySaving(context, present, .autodownloadInBackground)
            }
        ),
        SettingsSearchableItem(
            id: "power-saving/background",
            icon: icon,
            isVisible: false,
            present: { context, _, present in
                presentEnergySaving(context, present, .extendBackgroundWork)
            }
        ),
    ]
}

private func appearanceSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .appearance
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let presentAppearanceSettings: (AccountContext, (SettingsSearchableItemPresentation, ViewController?) -> Void, ThemeSettingsEntryTag?) -> Void = { context, present, itemTag in
        present(.push, themeSettingsController(context: context, focusOnItemTag: itemTag))
    }
    
    var items: [SettingsSearchableItem] = [
        SettingsSearchableItem(
            id: "appearance",
            title: strings.Settings_Appearance,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_Title),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                presentAppearanceSettings(context, present, nil)
            }
        ),
        SettingsSearchableItem(
            id: "appearance/wallpapers",
            title: strings.Settings_ChatBackground,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ChatBackground),
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            present: { context, _, present in
                present(.push, ThemeGridController(context: context))
            }
        ),
        SettingsSearchableItem(
            id: "appearance/wallpapers/edit",
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance, strings.Settings_ChatBackground],
            isVisible: false,
            present: { context, _, present in
                present(.push, ThemeGridController(context: context, forceEdit: true))
            }
        ),
        SettingsSearchableItem(
            id: "appearance/wallpapers/set",
            title: strings.Wallpaper_SetColor,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ChatBackground_SetColor),
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance, strings.Settings_ChatBackground],
            present: { context, _, present in
                
                present(.push, ThemeColorsGridController(context: context))
            }
        ),
        SettingsSearchableItem(
            id: "appearance/wallpapers/choose-photo",
            title: strings.Wallpaper_SetCustomBackground,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ChatBackground_Custom),
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance, strings.Settings_ChatBackground],
            present: { context, _, present in
                presentCustomWallpaperPicker(context: context, present: { controller in
                    present(.immediate, controller)
                }, push: { controller in
                    present(.push, controller)
                })
            }
        ),
        SettingsSearchableItem(
            id: "appearance/night-mode",
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            isVisible: false,
            present: { context, _, present in
                presentAppearanceSettings(context, present, .nightMode)
            }
        ),
        SettingsSearchableItem(
            id: "appearance/auto-night-mode",
            title: strings.Appearance_AutoNightTheme,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_AutoNightTheme),
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            present: { context, _, present in
                present(.push, themeAutoNightSettingsController(context: context))
            }
        ),
        SettingsSearchableItem(
            id: "appearance/themes",
            title: strings.Themes_Title,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_ColorTheme),
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            present: { context, _, present in
                let controller = themePickerController(context: context)
                present(.push, controller)
            }
        ),
        SettingsSearchableItem(
            id: "appearance/themes/edit",
            title: strings.Themes_EditCurrentTheme,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance, strings.Themes_Title],
            present: { context, _, present in
                let controller = themePickerController(context: context)
                present(.push, controller)
            }
        ),
        SettingsSearchableItem(
            id: "appearance/themes/create",
            title: strings.Themes_CreateNewTheme,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance, strings.Themes_Title],
            present: { context, navigationController, present in
                let _ = (context.sharedContext.accountManager.transaction { transaction -> PresentationThemeReference in
                    let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings)?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
                    
                    let themeReference: PresentationThemeReference
                    let autoNightModeTriggered = context.sharedContext.currentPresentationData.with { $0 }.autoNightModeTriggered
                    if autoNightModeTriggered {
                        themeReference = settings.automaticThemeSwitchSetting.theme
                    } else {
                        themeReference = settings.theme
                    }
                    
                    return themeReference
                }
                |> deliverOnMainQueue).start(next: { [weak navigationController] themeReference in
                    let controller = editThemeController(context: context, mode: .create(nil, nil), navigateToChat: { [weak navigationController] peerId in
                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                        |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                            guard let peer else {
                                return
                            }
                            if let navigationController {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                            }
                        })
                    })
                    present(.push, controller)
                })
            }
        ),
        SettingsSearchableItem(
            id: "appearance/text-size",
            title: strings.Appearance_TextSizeSetting,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Appearance_TextSize),
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            present: { context, _, present in
                let _ = (context.sharedContext.accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationThemeSettings]))
                |> take(1)
                |> deliverOnMainQueue).start(next: { view in
                    let settings = view.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
                    present(.push, TextSizeSelectionController(context: context, presentationThemeSettings: settings))
                })
            }
        ),
        SettingsSearchableItem(
            id: "appearance/text-size/use-system",
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            isVisible: false,
            present: { context, _, present in
                let _ = (context.sharedContext.accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationThemeSettings]))
                |> take(1)
                |> deliverOnMainQueue).start(next: { view in
                    let settings = view.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
                    present(.push, TextSizeSelectionController(context: context, presentationThemeSettings: settings, focusOnItemTag: .useSystem))
                })
            }
        ),
        SettingsSearchableItem(
            id: "appearance/message-corners",
            title: strings.Appearance_BubbleCornersSetting,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            present: { context, _, present in
                let _ = (context.sharedContext.accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationThemeSettings]))
                |> take(1)
                |> deliverOnMainQueue).start(next: { view in
                    let settings = view.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
                    present(.push, BubbleSettingsController(context: context, presentationThemeSettings: settings))
                })
            }
        ),
        SettingsSearchableItem(
            id: "appearance/app-icon",
            title: strings.Appearance_AppIcon.capitalized,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            present: { context, _, present in
                presentAppearanceSettings(context, present, .icon)
            }
        ),
        SettingsSearchableItem(
            id: "appearance/animations",
            title: strings.Appearance_Animations.capitalized,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            present: { context, _, present in
                let controller = energySavingSettingsScreen(context: context)
                present(.push, controller)
            }
        ),
        SettingsSearchableItem(
            id: "appearance/tap-for-next-media",
            title: strings.Appearance_ShowNextMediaOnTap,
            icon: icon,
            breadcrumbs: [strings.Settings_Appearance],
            isVisible: false,
            present: { context, _, present in
                presentAppearanceSettings(context, present, .tapForNextMedia)
            }
        )
    ]
    
    if DeviceModel.current.isIpad {
        items.append(
            SettingsSearchableItem(
                id: "appearance/send-with-cmd-enter",
                title: strings.Appearance_SendWithCmdEnter,
                icon: icon,
                breadcrumbs: [strings.Settings_Appearance],
                isVisible: false,
                present: { context, _, present in
                    presentAppearanceSettings(context, present, .sendWithCmdEnter)
                }
            )
        )
    }
    return items
}

private func languageSearchableItems(context: AccountContext, localizations: [LocalizationInfo]) -> [SettingsSearchableItem] {
    let icon: SettingsSearchableItemIcon = .language
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    let applyLocalization: (AccountContext, @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void, String) -> Void = { context, present, languageCode in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
        present(.immediate, controller)
        
        let _ = (context.engine.localization.downloadAndApplyLocalization(accountManager: context.sharedContext.accountManager, languageCode: languageCode)
        |> deliverOnMainQueue).start(completed: { [weak controller] in
            controller?.dismiss()
            present(.dismiss, nil)
        })
    }
    
    var items: [SettingsSearchableItem] = []
    items.append(
        SettingsSearchableItem(
            id: "language",
            title: strings.Settings_AppLanguage,
            alternate: synonyms(strings.SettingsSearch_Synonyms_AppLanguage),
            icon: icon,
            breadcrumbs: [],
            present: { context, _, present in
                present(.push, LocalizationListController(context: context))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "language/show-button",
            title: strings.Localization_ShowTranslate,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Language_ShowTranslateButton),
            icon: icon,
            breadcrumbs: [strings.Settings_AppLanguage],
            present: { context, _, present in
                present(.push, LocalizationListController(context: context, focusOnItemTag: .showButton))
            }
        )
    )
    items.append(
        SettingsSearchableItem(
            id: "language/translate-chats",
            title: strings.Localization_TranslateEntireChat,
            alternate: [],
            icon: icon,
            breadcrumbs: [strings.Settings_AppLanguage],
            present: { context, _, present in
                present(.push, LocalizationListController(context: context, focusOnItemTag: .translateChats))
            })
    )
    items.append(
        SettingsSearchableItem(
            id: "language/do-not-translate",
            title: strings.Localization_DoNotTranslate,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Language_DoNotTranslate),
            icon: icon,
            breadcrumbs: [strings.Settings_AppLanguage],
            present: { context, _, present in
                present(.push, translationSettingsController(context: context))
            })
    )
    
    var index: Int32 = 1
    for localization in localizations {
        items.append(
            SettingsSearchableItem(
                id: "language/set/\(localization.languageCode)",
                title: localization.localizedTitle,
                alternate: [localization.title],
                icon: icon,
                breadcrumbs: [strings.Settings_AppLanguage],
                present: { context, _, present in
                    applyLocalization(context, present, localization.languageCode)
                }
            )
        )
        index += 1
    }
            
    return items
}

private func helpSearchableItems(context: AccountContext) -> [SettingsSearchableItem] {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    var items: [SettingsSearchableItem] = []
    
    items.append(
        SettingsSearchableItem(
            id: "ask-question",
            title: strings.Settings_Support,
            alternate: synonyms(strings.SettingsSearch_Synonyms_Support),
            icon: .support,
            breadcrumbs: [],
            present: { context, _, present in
                let _ = (context.engine.peers.supportPeerId()
                |> deliverOnMainQueue).start(next: { peerId in
                    if let peerId = peerId {
                        present(.push, context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil))
                    }
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "faq",
            title: strings.Settings_FAQ,
            alternate: synonyms(strings.SettingsSearch_Synonyms_FAQ),
            icon: .faq,
            breadcrumbs: [],
            present: { context, navigationController, present in
                let _ = (cachedFaqInstantPage(context: context)
                |> take(1)
                |> deliverOnMainQueue).start(next: { resolvedUrl in
                    context.sharedContext.openResolvedUrl(resolvedUrl, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, forceUpdate: false, openPeer: { peer, navigation in
                    }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { controller, arguments in
                        present(.push, controller)
                    }, dismissInput: {}, contentContext: nil, progress: nil, completion: nil)
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "features",
            title: strings.Settings_Tips,
            alternate: [],
            icon: .tips,
            breadcrumbs: [],
            present: { context, navigationController, present in
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                present(.immediate, controller)
                
                let _ = (context.engine.peers.resolvePeerByName(name: strings.Settings_TipsUsername, referrer: nil)
                |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                    guard case let .result(result) = result else {
                        return .complete()
                    }
                    return .single(result)
                }
                |> deliverOnMainQueue).startStandalone(next: { [weak controller] peer in
                    controller?.dismiss()
                    if let peer, let navigationController {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                    }
                })
            }
        )
    )
    
    items.append(
        SettingsSearchableItem(
            id: "privacy-policy",
            title: strings.Permissions_PrivacyPolicy,
            alternate: [],
            icon: .tips,
            breadcrumbs: [],
            present: { context, navigationController, present in
                let _ = (cachedPrivacyPage(context: context)
                |> take(1)
                |> deliverOnMainQueue).start(next: { resolvedUrl in
                    context.sharedContext.openResolvedUrl(resolvedUrl, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, forceUpdate: false, openPeer: { peer, navigation in
                    }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { c, arguments in
                        present(.push, c)
                    }, dismissInput: {}, contentContext: nil, progress: nil, completion: nil)
                })
            }
        )
    )
    
    return items
}

func settingsSearchableItems(
    context: AccountContext,
    notificationExceptionsList: Signal<NotificationExceptionsList?, NoError> = .single(nil),
    archivedStickerPacks: Signal<[ArchivedStickerPackItem]?, NoError> = .single(nil),
    privacySettings: Signal<AccountPrivacySettings?, NoError> = .single(nil),
    hasTwoStepAuth: Signal<Bool?, NoError> = .single(nil),
    twoStepAuthData: Signal<TwoStepVerificationAccessConfiguration?, NoError> = .single(nil),
    activeSessionsContext: Signal<ActiveSessionsContext?, NoError> = .single(nil),
    webSessionsContext: Signal<WebSessionsContext?, NoError> = .single(nil)
) -> Signal<[SettingsSearchableItem], NoError> {
    let canAddAccount = activeAccountsAndPeers(context: context)
    |> take(1)
    |> map { accountsAndPeers -> Bool in
        return accountsAndPeers.1.count + 1 < maximumNumberOfAccounts
    }
    
    let notificationSettings = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
    |> take(1)
    |> map { view -> GlobalNotificationSettingsSet in
        let viewSettings: GlobalNotificationSettingsSet
        if let settings = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
            viewSettings = settings.effective
        } else {
            viewSettings = GlobalNotificationSettingsSet.defaultSettings
        }
        return viewSettings
    }
    
    let archivedStickerPacks = archivedStickerPacks
    |> take(1)
    
    let privacySettings = privacySettings
    |> take(1)
    
    let proxyServers = context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
    |> map { sharedData -> ProxySettings in
        if let value = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
            return value
        } else {
            return ProxySettings.defaultSettings
        }
    }
    |> map { settings -> [ProxyServerSettings] in
        return settings.servers
    }
    
    let localizations = combineLatest(
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.LocalizationList()),
        context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.localizationSettings])
    )
    |> map { localizationListState, sharedData -> [LocalizationInfo] in
        if !localizationListState.availableOfficialLocalizations.isEmpty {
            var existingIds = Set<String>()
            let availableSavedLocalizations = localizationListState.availableSavedLocalizations.filter({ info in !localizationListState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) })
            
            var activeLanguageCode: String?
            if let localizationSettings = sharedData.entries[SharedDataKeys.localizationSettings]?.get(LocalizationSettings.self) {
                activeLanguageCode = localizationSettings.primaryComponent.languageCode
            }
            
            var localizationItems: [LocalizationInfo] = []
            if !availableSavedLocalizations.isEmpty {
                for info in availableSavedLocalizations {
                    if existingIds.contains(info.languageCode) || info.languageCode == activeLanguageCode {
                        continue
                    }
                    existingIds.insert(info.languageCode)
                    localizationItems.append(info)
                }
            }
            for info in localizationListState.availableOfficialLocalizations {
                if existingIds.contains(info.languageCode) || info.languageCode == activeLanguageCode {
                    continue
                }
                existingIds.insert(info.languageCode)
                localizationItems.append(info)
            }
            
            return localizationItems
        } else {
            return []
        }
    }
    
    let activeWebSessionsContext = webSessionsContext
    |> mapToSignal { webSessionsContext -> Signal<WebSessionsContext?, NoError> in
        if let webSessionsContext = webSessionsContext {
            return webSessionsContext.state
            |> map { state -> WebSessionsContext? in
                if !state.sessions.isEmpty {
                    return webSessionsContext
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                return lhs !== rhs
            })
        } else {
            return .single(nil)
        }
    }
    
    return combineLatest(
        canAddAccount,
        localizations,
        notificationSettings,
        notificationExceptionsList,
        archivedStickerPacks,
        proxyServers,
        privacySettings,
        hasTwoStepAuth,
        twoStepAuthData,
        activeSessionsContext,
        activeWebSessionsContext
    )
    |> map {
        canAddAccount,
        localizations,
        notificationSettings,
        notificationExceptionsList,
        archivedStickerPacks,
        proxyServers,
        privacySettings,
        hasTwoStepAuth,
        twoStepAuthData,
        activeSessionsContext,
        activeWebSessionsContext in
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        
        var allItems: [SettingsSearchableItem] = []
        
        let profileItems = profileSearchableItems(context: context, canAddAccount: canAddAccount)
        allItems.append(contentsOf: profileItems)
        
        let savedMessages = SettingsSearchableItem(
            id: "saved-messages",
            title: strings.Settings_SavedMessages,
            alternate: synonyms(strings.SettingsSearch_Synonyms_SavedMessages),
            icon: .savedMessages,
            breadcrumbs: [],
            present: { context, _, present in
                present(.push, context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: context.account.peerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil))
            }
        )
        allItems.append(savedMessages)
        
        let devicesItems = devicesSearchableItems(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: activeWebSessionsContext)
        allItems.append(contentsOf: devicesItems)
        
        let callItems = callSearchableItems(context: context)
        allItems.append(contentsOf: callItems)
        
        let chatFolders = chatFoldersSearchableItems(context: context)
        allItems.append(contentsOf: chatFolders)
        
        let stickerItems = stickerSearchableItems(context: context, archivedStickerPacks: archivedStickerPacks)
        allItems.append(contentsOf: stickerItems)
        
        let notificationItems = notificationSearchableItems(context: context, settings: notificationSettings, exceptionsList: notificationExceptionsList)
        allItems.append(contentsOf: notificationItems)
        
        let privacyItems = privacySearchableItems(context: context, privacySettings: privacySettings, activeSessionsContext: activeSessionsContext, webSessionsContext: activeWebSessionsContext)
        allItems.append(contentsOf: privacyItems)
        
        let dataItems = dataSearchableItems(context: context)
        allItems.append(contentsOf: dataItems)
        
        let proxyItems = proxySearchableItems(context: context, servers: proxyServers)
        allItems.append(contentsOf: proxyItems)
        
        let appearanceItems = appearanceSearchableItems(context: context)
        allItems.append(contentsOf: appearanceItems)
        
        let powerSavingItems = energySavingSearchableItems(context: context)
        allItems.append(contentsOf: powerSavingItems)
        
        let languageItems = languageSearchableItems(context: context, localizations: localizations)
        allItems.append(contentsOf: languageItems)
        
        let premiumItems = premiumSearchableItems(context: context)
        allItems.append(contentsOf: premiumItems)
        
        let storiesItems = myProfileSearchableItems(context: context)
        allItems.append(contentsOf: storiesItems)
        
        if let hasTwoStepAuth = hasTwoStepAuth,
           hasTwoStepAuth {
            let passport = SettingsSearchableItem(
                id: "passport",
                title: strings.Settings_Passport,
                alternate: synonyms(strings.SettingsSearch_Synonyms_Passport),
                icon: .passport,
                breadcrumbs: [],
                present: { context, _, present in
                    present(.modal, SecureIdAuthController(context: context, mode: .list))
                }
            )
            allItems.append(passport)
        }
        
        let helpItems = helpSearchableItems(context: context)
        allItems.append(contentsOf: helpItems)
                
        let deleteAccount = SettingsSearchableItem(
            id: "delete-account",
            title: strings.DeleteAccount_DeleteMyAccount,
            alternate: synonyms(strings.SettingsSearch_DeleteAccount_DeleteMyAccount),
            icon: .deleteAccount,
            breadcrumbs: [],
            present: { context, navigationController, present in
                if let navigationController = navigationController {
                    let controller = deleteAccountOptionsController(context: context, navigationController: navigationController, hasTwoStepAuth: hasTwoStepAuth ?? false, twoStepAuthData: twoStepAuthData)
                    present(.push, controller)
                }
            }
        )
        allItems.append(deleteAccount)
    
        return allItems
    }
}

private func stringTokens(_ string: String) -> [ValueBoxKey] {
    let nsString = string.folding(options: .diacriticInsensitive, locale: .current).lowercased() as NSString
    
    let flag = UInt(kCFStringTokenizerUnitWord)
    let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, nsString, CFRangeMake(0, nsString.length), flag, CFLocaleCopyCurrent())
    var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    var tokens: [ValueBoxKey] = []
    
    var addedTokens = Set<ValueBoxKey>()
    while tokenType != [] {
        let currentTokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        
        if currentTokenRange.location >= 0 && currentTokenRange.length != 0 {
            let token = ValueBoxKey(length: currentTokenRange.length * 2)
            nsString.getCharacters(token.memory.assumingMemoryBound(to: unichar.self), range: NSMakeRange(currentTokenRange.location, currentTokenRange.length))
            if !addedTokens.contains(token) {
                tokens.append(token)
                addedTokens.insert(token)
            }
        }
        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
    }
    
    return tokens
}

private func matchStringTokens(_ tokens: [ValueBoxKey], with other: [ValueBoxKey]) -> Bool {
    if other.isEmpty {
        return false
    } else if other.count == 1 {
        let otherToken = other[0]
        for token in tokens {
            if otherToken.isPrefix(to: token) {
                return true
            }
        }
    } else {
        for otherToken in other {
            var found = false
            for token in tokens {
                if otherToken.isPrefix(to: token) {
                    found = true
                    break
                }
            }
            if !found {
                return false
            }
        }
        return true
    }
    return false
}

func searchSettingsItems(items: [SettingsSearchableItem], query: String) -> [SettingsSearchableItem] {
    let showAll = query == "#all"

    let queryTokens = stringTokens(query.lowercased())
    
    var result: [SettingsSearchableItem] = []
    for item in items {
        guard item.isVisible || showAll else {
            continue
        }
        var string = item.title
        if !item.alternate.isEmpty {
            for alternate in item.alternate {
                let trimmed = alternate.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    string += " \(trimmed)"
                }
            }
        }
        if item.breadcrumbs.count > 1 {
            string += " \(item.breadcrumbs.suffix(from: 1).joined(separator: " "))"
        }
        
        let tokens = stringTokens(string)
        if showAll || matchStringTokens(tokens, with: queryTokens) {
            var item = item
            if item.title.isEmpty && !item.isVisible, let id = item.id.base as? String {
                item = item.withUpdatedTitle(id)
            }
            result.append(item)
        }
    }
    
    return result
}

public func handleSettingsPathUrl(context: AccountContext, path: String, navigationController: NavigationController) {
    let _ = (settingsSearchableItems(context: context)
    |> take(1)
    |> deliverOnMainQueue).start(next: { items in
        guard let item = items.first(where: { $0.id == AnyHashable(path) }) else {
            return
        }
        item.present(context, navigationController, { mode, controller in
            guard let controller, let topController = navigationController.topViewController as? ViewController else {
                return
            }
            switch mode {
                case .push:
                    navigationController.pushViewController(controller)
                case .modal:
                    topController.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet, completion: {}), blockInteraction: false, completion: {})
                case .immediate:
                    topController.present(controller, in: .window(.root))
                default:
                    break
            }
        })
    })
}

private func presentSetupBirthday(context: AccountContext, present: @escaping (SettingsSearchableItemPresentation, ViewController?) -> Void) {
    let settingsPromise: Promise<AccountPrivacySettings?>
    if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface, let current = rootController.getPrivacySettings() {
        settingsPromise = current
    } else {
        settingsPromise = Promise()
        settingsPromise.set(.single(nil) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)))
    }
    
    let controller = context.sharedContext.makeBirthdayPickerScreen(
        context: context,
        settings: settingsPromise,
        openSettings: {
            context.sharedContext.makeBirthdayPrivacyController(context: context, settings: settingsPromise, openedFromBirthdayScreen: true, present: { c in
                present(.push, c)
            })
        },
        completion: { value in
            let _ = context.engine.accountData.updateBirthday(birthday: value).startStandalone()
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            present(.immediate, UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: presentationData.strings.Birthday_Added, cancel: nil, destructive: false), elevatedLayout: false, action: { _ in
                return true
            }))
        }
    )
    present(.push, controller)
}
