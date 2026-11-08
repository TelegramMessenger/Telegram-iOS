import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class JokerSettingsControllerArguments {
    let updateAutoSaveMedia: (Bool) -> Void
    let updateAllow100Accounts: (Bool) -> Void
    let updateGhostMode: (Bool) -> Void
    let updateForcePremiumTranslation: (Bool) -> Void
    let updateKeepDeletedMessages: (Bool) -> Void
    let updateFreezeLastSeen: (Bool) -> Void
    let updateBypassCopyProtection: (Bool) -> Void
    let updateStoryStealthMode: (Bool) -> Void
    let openBusinessGreetingMessages: () -> Void
    let openBusinessQuickReplies: () -> Void

    init(
        updateAutoSaveMedia: @escaping (Bool) -> Void,
        updateAllow100Accounts: @escaping (Bool) -> Void,
        updateGhostMode: @escaping (Bool) -> Void,
        updateForcePremiumTranslation: @escaping (Bool) -> Void,
        updateKeepDeletedMessages: @escaping (Bool) -> Void,
        updateFreezeLastSeen: @escaping (Bool) -> Void,
        updateBypassCopyProtection: @escaping (Bool) -> Void,
        updateStoryStealthMode: @escaping (Bool) -> Void,
        openBusinessGreetingMessages: @escaping () -> Void,
        openBusinessQuickReplies: @escaping () -> Void
    ) {
        self.updateAutoSaveMedia = updateAutoSaveMedia
        self.updateAllow100Accounts = updateAllow100Accounts
        self.updateGhostMode = updateGhostMode
        self.updateForcePremiumTranslation = updateForcePremiumTranslation
        self.updateKeepDeletedMessages = updateKeepDeletedMessages
        self.updateFreezeLastSeen = updateFreezeLastSeen
        self.updateBypassCopyProtection = updateBypassCopyProtection
        self.updateStoryStealthMode = updateStoryStealthMode
        self.openBusinessGreetingMessages = openBusinessGreetingMessages
        self.openBusinessQuickReplies = openBusinessQuickReplies
    }
}

private enum JokerSettingsControllerSection: Int32 {
    case features
    case business
    case credits
}

private func jokerLocalized(_ presentationData: PresentationData, _ arValue: String, _ enValue: String) -> String {
    return jokerLocalize(sample: presentationData.strings.Common_Back, arValue: arValue, enValue: enValue)
}

private enum JokerSettingsControllerEntry: ItemListNodeEntry {
    case featuresHeader(String)
    case autoSaveMediaToggle(String, String, Bool)
    case allow100AccountsToggle(String, String, Bool)
    case ghostModeToggle(String, String, Bool)
    case forcePremiumTranslationToggle(String, String, Bool)
    case freezeLastSeenToggle(String, String, Bool)
    case bypassCopyProtectionToggle(String, String, Bool)
    case keepDeletedMessagesToggle(String, String, Bool)
    case storyStealthModeToggle(String, String, Bool)

    case businessHeader(String)
    case businessGreetingMessages(String, String)
    case businessQuickReplies(String, String)

    case creditsHeader(String)
    case creditsText(String)

    var section: ItemListSectionId {
        switch self {
        case .featuresHeader, .autoSaveMediaToggle, .allow100AccountsToggle, .ghostModeToggle, .forcePremiumTranslationToggle, .freezeLastSeenToggle, .bypassCopyProtectionToggle, .keepDeletedMessagesToggle, .storyStealthModeToggle:
            return JokerSettingsControllerSection.features.rawValue
        case .businessHeader, .businessGreetingMessages, .businessQuickReplies:
            return JokerSettingsControllerSection.business.rawValue
        case .creditsHeader, .creditsText:
            return JokerSettingsControllerSection.credits.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .featuresHeader:
            return 10
        case .autoSaveMediaToggle:
            return 11
        case .allow100AccountsToggle:
            return 12
        case .ghostModeToggle:
            return 13
        case .forcePremiumTranslationToggle:
            return 14
        case .freezeLastSeenToggle:
            return 15
        case .bypassCopyProtectionToggle:
            return 16
        case .keepDeletedMessagesToggle:
            return 17
        case .storyStealthModeToggle:
            return 21
        case .businessHeader:
            return 18
        case .businessGreetingMessages:
            return 19
        case .businessQuickReplies:
            return 20
        case .creditsHeader:
            return 22
        case .creditsText:
            return 23
        }
    }

    static func <(lhs: JokerSettingsControllerEntry, rhs: JokerSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! JokerSettingsControllerArguments
        switch self {
        case let .featuresHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .autoSaveMediaToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateAutoSaveMedia(value)
            })
        case let .allow100AccountsToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateAllow100Accounts(value)
            })
        case let .ghostModeToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateGhostMode(value)
            })
        case let .forcePremiumTranslationToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateForcePremiumTranslation(value)
            })
        case let .freezeLastSeenToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFreezeLastSeen(value)
            })
        case let .bypassCopyProtectionToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateBypassCopyProtection(value)
            })
        case let .keepDeletedMessagesToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateKeepDeletedMessages(value)
            })
        case let .storyStealthModeToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateStoryStealthMode(value)
            })
        case let .businessHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .businessGreetingMessages(title, text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: nil, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, action: {
                arguments.openBusinessGreetingMessages()
            })
        case let .businessQuickReplies(title, text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: nil, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, action: {
                arguments.openBusinessQuickReplies()
            })
        case let .creditsHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .creditsText(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        }
    }
}

private func jokerSettingsControllerEntries(presentationData: PresentationData, settings: JokerSettings) -> [JokerSettingsControllerEntry] {
    var entries: [JokerSettingsControllerEntry] = []

    entries.append(.featuresHeader(jokerLocalized(presentationData, "مميزات الجوكر", "Joker Features")))
    entries.append(.autoSaveMediaToggle(jokerLocalized(presentationData, "حفظ الوسائط ذاتية التدمير تلقائياً", "Auto Save Self-Destructing Media"), jokerLocalized(presentationData, "حفظ الصور والفيديوهات والرسائل الصوتية ذاتية التدمير في الرسائل المحفوظة تلقائياً عند فتحها.", "Automatically save self-destructing photos, videos, and voice messages to Saved Messages when opened."), settings.autoSaveSelfDestructingMedia))
    entries.append(.allow100AccountsToggle(jokerLocalized(presentationData, "السماح حتى 100 حساب", "Allow 100 Accounts"), jokerLocalized(presentationData, "السماح بإضافة حتى 100 حساب في التطبيق.", "Allow adding up to 100 accounts in the app."), settings.allow100Accounts))
    entries.append(.ghostModeToggle(jokerLocalized(presentationData, "وضع الشبح", "Ghost Mode"), jokerLocalized(presentationData, "إخفاء علامات قراءة الرسائل مع أيقونة عين في أعلى المحادثة بجانب اسم المحادثة.", "Hide read receipts with an eye icon at the top of the chat next to the chat title."), settings.ghostMode))
    entries.append(.forcePremiumTranslationToggle(jokerLocalized(presentationData, "ترجمة البريميوم مجاناً", "Force Premium Translation"), jokerLocalized(presentationData, "تفعيل ميزة الترجمة الخاصة بالبريميوم مجاناً في المحادثات والقنوات.", "Enable the Premium translation feature for free in chats and channels."), settings.forcePremiumTranslation))
    entries.append(.freezeLastSeenToggle(jokerLocalized(presentationData, "تجميد آخر ظهور", "Freeze Last Seen"), jokerLocalized(presentationData, "إخفاء حالة آخر ظهور الخاصة بك وعدم إرسال تحديثات الحضور إلى الخادم.", "Hide your last seen status and stop sending presence updates to the server."), settings.freezeLastSeen))
    entries.append(.bypassCopyProtectionToggle(jokerLocalized(presentationData, "تجاوز حماية المحتوى", "Bypass Copy Protection"), jokerLocalized(presentationData, "تجاوز قيود حماية النسخ في القنوات المحمية: نسخ caption، وحفظ الصور، وإعادة توجيه الرسالة بالكامل (الصورة مع caption).", "Bypass copy protection in protected channels: copy captions, save images, and forward the full message (image with caption)."), settings.bypassCopyProtection))
    entries.append(.keepDeletedMessagesToggle(jokerLocalized(presentationData, "الاحتفاظ بالرسائل المحذوفة", "Keep Deleted Messages"), jokerLocalized(presentationData, "الاحتفاظ بالرسائل المحذوفة محلياً مع علامة x بجانب الفقاعة. مسح المحادثة يحذف كل شيء نهائياً.", "Keep deleted messages locally with an 'x' mark next to the bubble. Clearing history deletes everything permanently."), settings.keepDeletedMessages))
    entries.append(.storyStealthModeToggle(jokerLocalized(presentationData, "الستوري بدون ظهورك (محلي)", "Invisible Story Views (Local)"), jokerLocalized(presentationData, "شاهد ستوريات الآخرين دون ظهورك في قائمة المشاهدين. ميزة محلية بالكامل، بدون اشتراك وبدون Telegram Business.", "Watch other people’s stories without appearing in their viewers list. Completely local, no subscription, no Telegram Business."), settings.storyStealthMode))

    entries.append(.businessHeader(jokerLocalized(presentationData, "ميزات محلية", "Local Features")))
    entries.append(.businessGreetingMessages(jokerLocalized(presentationData, "رسالة ترحيبية محلية", "Local Greeting Message"), jokerLocalized(presentationData, "خزّن رسالة ترحيبية على جهازك واستخدمها للعملاء الجدد. ليست Telegram Business.", "Store a greeting message on your device for new customers. Not Telegram Business.")))
    entries.append(.businessQuickReplies(jokerLocalized(presentationData, "ردود سريعة محلية", "Local Quick Replies"), jokerLocalized(presentationData, "أنشئ وأدر ردودًا سريعة محلية على هذا الجهاز. ليست Telegram Business.", "Create and manage local quick replies on this device. Not Telegram Business.")))

    entries.append(.creditsHeader(jokerLocalized(presentationData, "حقوق المصدر", "Source Credits")))
    entries.append(.creditsText(jokerLocalized(presentationData, "إصدار معدّل من Talogram - المصدر بواسطة @aljokeruserbot", "Talogram Modified Version - Source by @aljokeruserbot")))

    return entries
}

public func jokerSettingsController(context: AccountContext) -> ViewController {
    var settingsController: ViewController! = nil
    let arguments = JokerSettingsControllerArguments(
        updateAutoSaveMedia: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedAutoSaveSelfDestructingMedia(value) }).start()
        },
        updateAllow100Accounts: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedAllow100Accounts(value) }).start()
        },
        updateGhostMode: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedGhostMode(value) }).start()
        },
        updateForcePremiumTranslation: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedForcePremiumTranslation(value) }).start()
        },
        updateKeepDeletedMessages: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedKeepDeletedMessages(value) }).start()
        },
        updateFreezeLastSeen: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedFreezeLastSeen(value) }).start()
        },
        updateBypassCopyProtection: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedBypassCopyProtection(value) }).start()
        },
        updateStoryStealthMode: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedStoryStealthMode(value) }).start()
        },
        openBusinessGreetingMessages: {
            guard let settingsController else {
                return
            }
            let controller = JokerLocalGreetingController(context: context)
            settingsController.push(controller)
        },
        openBusinessQuickReplies: {
            guard let settingsController else {
                return
            }
            let controller = JokerLocalQuickRepliesController(context: context)
            settingsController.push(controller)
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        getJokerSettings(accountManager: context.sharedContext.accountManager)
    )
    |> deliverOnMainQueue
    |> map { presentationData, jokerSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData

        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(jokerLocalized(presentationData, "إعدادات الجوكر", "Joker Settings")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: jokerSettingsControllerEntries(presentationData: presentationData, settings: jokerSettings), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    settingsController = controller

    return controller
}
