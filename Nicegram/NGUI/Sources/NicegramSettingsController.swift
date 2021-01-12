//
//  NicegramSettingsController.swift
//  NicegramUI
//
//  Created by Sergey Akentev.
//  Copyright © 2020 Nicegram. All rights reserved.
//

// MARK: Imports

import AccountContext
import Display
import Foundation
import ItemListUI
import NGData
import NGLogging
import NGStrings
import Postbox
import PresentationDataUtils
import SwiftSignalKit
import SyncCore
import TelegramCore
import TelegramNotices
import TelegramPresentationData
import TelegramUIPreferences
import UIKit

fileprivate let LOGTAG = extractNameFromPath(#file)

// MARK: Arguments struct

private final class NicegramSettingsControllerArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    let getRootController: () -> UIViewController?
    let updateTabs: () -> Void

    init(context: AccountContext, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping (ViewController) -> Void, getRootController: @escaping () -> UIViewController?, updateTabs: @escaping () -> Void) {
        self.context = context
        self.presentController = presentController
        self.pushController = pushController
        self.getRootController = getRootController
        self.updateTabs = updateTabs
    }
}

// MARK: Sections

private enum NicegramSettingsControllerSection: Int32 {
    case Notifications
    case Tabs
    case Folders
    case RoundVideos
    case Other
}


private enum EasyToggleType {
    case sendWithEnter
}


// MARK: ItemListNodeEntry

private enum NicegramSettingsControllerEntry: ItemListNodeEntry {
    case NotificationsHeader(String)
    case hideAccountInNotification(String, Bool)
    case hideAccountInNotificationNotice(String)

    case TabsHeader(String)
    case showContactsTab(String, Bool)
    case showCallsTab(String, Bool)
    case showTabNames(String, Bool)

    case FoldersHeader(String)
    case foldersAtBottom(String, Bool)
    case foldersAtBottomNotice(String)

    case RoundVideosHeader(String)
    case startWithRearCam(String, Bool)

    case OtherHeader(String)
    case hidePhoneInSettings(String, Bool)
    case hidePhoneInSettingsNotice(String)
    
    case easyToggle(Int32, EasyToggleType, String, Bool)

    // MARK: Section

    var section: ItemListSectionId {
        switch self {
        case .NotificationsHeader, .hideAccountInNotification, .hideAccountInNotificationNotice:
            return NicegramSettingsControllerSection.Notifications.rawValue
        case .TabsHeader, .showContactsTab, .showCallsTab, .showTabNames:
            return NicegramSettingsControllerSection.Tabs.rawValue
        case .FoldersHeader, .foldersAtBottom, .foldersAtBottomNotice:
            return NicegramSettingsControllerSection.Folders.rawValue
        case .RoundVideosHeader, .startWithRearCam:
            return NicegramSettingsControllerSection.RoundVideos.rawValue
        case .OtherHeader, .hidePhoneInSettings, .hidePhoneInSettingsNotice, .easyToggle:
            return NicegramSettingsControllerSection.Other.rawValue
        }
    }

    // MARK: SectionId

    var stableId: Int32 {
        switch self {
        case .NotificationsHeader:
            return 1000

        case .hideAccountInNotification:
            return 1100

        case .hideAccountInNotificationNotice:
            return 1200

        case .TabsHeader:
            return 1300

        case .showContactsTab:
            return 1400

        case .showCallsTab:
            return 1500

        case .showTabNames:
            return 1600

        case .FoldersHeader:
            return 1700

        case .foldersAtBottom:
            return 1800

        case .foldersAtBottomNotice:
            return 1900

        case .RoundVideosHeader:
            return 2000

        case .startWithRearCam:
            return 2100

        case .OtherHeader:
            return 2200

        case .hidePhoneInSettings:
            return 2300

        case .hidePhoneInSettingsNotice:
            return 2400
            
        case let .easyToggle(index, _, _, _):
            return 5000 + Int32(index)
        }
    }

    // MARK: == overload

    static func == (lhs: NicegramSettingsControllerEntry, rhs: NicegramSettingsControllerEntry) -> Bool {
        switch lhs {
        case let .NotificationsHeader(lhsText):
            if case let .NotificationsHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .hideAccountInNotification(lhsText, lhsVar0Bool):
            if case let .hideAccountInNotification(rhsText, rhsVar0Bool) = rhs, lhsText == rhsText, lhsVar0Bool == rhsVar0Bool {
                return true
            } else {
                return false
            }

        case let .hideAccountInNotificationNotice(lhsText):
            if case let .hideAccountInNotificationNotice(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .TabsHeader(lhsText):
            if case let .TabsHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .showContactsTab(lhsText, lhsVar0Bool):
            if case let .showContactsTab(rhsText, rhsVar0Bool) = rhs, lhsText == rhsText, lhsVar0Bool == rhsVar0Bool {
                return true
            } else {
                return false
            }

        case let .showCallsTab(lhsText, lhsVar0Bool):
            if case let .showCallsTab(rhsText, rhsVar0Bool) = rhs, lhsText == rhsText, lhsVar0Bool == rhsVar0Bool {
                return true
            } else {
                return false
            }

        case let .showTabNames(lhsText, lhsVar0Bool):
            if case let .showTabNames(rhsText, rhsVar0Bool) = rhs, lhsText == rhsText, lhsVar0Bool == rhsVar0Bool {
                return true
            } else {
                return false
            }

        case let .FoldersHeader(lhsText):
            if case let .FoldersHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .foldersAtBottom(lhsText, lhsVar0Bool):
            if case let .foldersAtBottom(rhsText, rhsVar0Bool) = rhs, lhsText == rhsText, lhsVar0Bool == rhsVar0Bool {
                return true
            } else {
                return false
            }

        case let .foldersAtBottomNotice(lhsText):
            if case let .foldersAtBottomNotice(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .RoundVideosHeader(lhsText):
            if case let .RoundVideosHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .startWithRearCam(lhsText, lhsVar0Bool):
            if case let .startWithRearCam(rhsText, rhsVar0Bool) = rhs, lhsText == rhsText, lhsVar0Bool == rhsVar0Bool {
                return true
            } else {
                return false
            }

        case let .OtherHeader(lhsText):
            if case let .OtherHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .hidePhoneInSettings(lhsText, lhsVar0Bool):
            if case let .hidePhoneInSettings(rhsText, rhsVar0Bool) = rhs, lhsText == rhsText, lhsVar0Bool == rhsVar0Bool {
                return true
            } else {
                return false
            }

        case let .hidePhoneInSettingsNotice(lhsText):
            if case let .hidePhoneInSettingsNotice(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .easyToggle(lhsIndex, lhsType, lhsText, lhsValue):
            if case let .easyToggle(rhsIndex, rhsType, rhsText, rhsValue) = rhs, lhsIndex == rhsIndex, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        }
    }

    // MARK: < overload

    static func < (lhs: NicegramSettingsControllerEntry, rhs: NicegramSettingsControllerEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    // MARK: ListViewItem
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NicegramSettingsControllerArguments
        switch self {
        case let .NotificationsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
            
        case let .hideAccountInNotification(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: false, sectionId: section, style: .blocks, updated: { value in
                ngLog("[hideAccountInNotification] invoked with \(value)", LOGTAG)
                NGSettings.hideNotifyAccount = value
            })
            
        case let .hideAccountInNotificationNotice(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
            
        case let .TabsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
            
        case let .showContactsTab(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: section, style: .blocks, updated: { value in
                ngLog("[showContactsTab] invoked with \(value)", LOGTAG)
                NGSettings.showContactsTab = value
                arguments.updateTabs()
            })
            
        case let .showCallsTab(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: section, style: .blocks, updated: { value in
                ngLog("[showCallsTab] invoked with \(value)", LOGTAG)
                let _ = updateCallListSettingsInteractively(accountManager: arguments.context.sharedContext.accountManager, {
                    $0.withUpdatedShowTab(value)
                }).start()
                
                if value {
                    let _ = ApplicationSpecificNotice.incrementCallsTabTips(accountManager: arguments.context.sharedContext.accountManager, count: 4).start()
                }
            })
            
        case let .showTabNames(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: section, style: .blocks, updated: { value in
                ngLog("[showTabNames] invoked with \(value)", LOGTAG)
                let locale = presentationData.strings.baseLanguageCode  
                NGSettings.showTabNames = value
                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: arguments.context.sharedContext.currentPresentationData.with {
                    $0
                }), title: nil, text: l("Common.RestartRequired", locale), actions: [/* TextAlertAction(type: .destructiveAction, title: l("Common.ExitNow", locale), action: { preconditionFailure() }),*/ TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})])
                arguments.presentController(controller, nil)
            })
            
        case let .FoldersHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
            
        case let .foldersAtBottom(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: section, style: .blocks, updated: { value in
                ngLog("[foldersAtBottom] invoked with \(value)", LOGTAG)
                let _ = arguments.context.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings as? ExperimentalUISettings ?? ExperimentalUISettings.defaultSettings
                        settings.foldersTabAtBottom = value
                        return settings
                    })
                }).start()
            })
            
        case let .foldersAtBottomNotice(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
            
        case let .RoundVideosHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
            
        case let .startWithRearCam(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: section, style: .blocks, updated: { value in
                ngLog("[startWithRearCam] invoked with \(value)", LOGTAG)
                NGSettings.useRearCamTelescopy = value
            })

        case let .OtherHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
            
        case let .hidePhoneInSettings(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: section, style: .blocks, updated: { value in
                ngLog("[hidePhoneInSettings] invoked with \(value)", LOGTAG)
                NGSettings.hidePhoneSettings = value
            })
            
        case let .hidePhoneInSettingsNotice(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
            
        case let .easyToggle(index, toggleType, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: section, style: .blocks, updated: { value in
                ngLog("[easyToggle] \(index) \(toggleType) invoked with \(value)", LOGTAG)
                switch (toggleType) {
                    case .sendWithEnter:
                        NGSettings.sendWithEnter = value
                }
            })
            
        }
        
    }
}

// MARK: Entries list

private func nicegramSettingsControllerEntries(presentationData: PresentationData, experimentalSettings: ExperimentalUISettings, showCalls: Bool) -> [NicegramSettingsControllerEntry] {
    var entries: [NicegramSettingsControllerEntry] = []

    let locale = presentationData.strings.baseLanguageCode

    entries.append(.NotificationsHeader(
        presentationData.strings.Notifications_Title.uppercased()))
    entries.append(.hideAccountInNotification(
        l("NicegramSettings.Notifications.hideAccountInNotification", locale),
        NGSettings.hideNotifyAccount
    ))
    entries.append(.hideAccountInNotificationNotice(
        l("NicegramSettings.Notifications.hideAccountInNotificationNotice", locale)
    ))

    entries.append(.TabsHeader(l("NicegramSettings.Tabs",
                                 locale)))
    entries.append(.showContactsTab(
        l("NicegramSettings.Tabs.showContactsTab", locale),
        NGSettings.showContactsTab
    ))
    entries.append(.showCallsTab(
        presentationData.strings.CallSettings_TabIcon,
        showCalls
    ))
    entries.append(.showTabNames(
        l("NicegramSettings.Tabs.showTabNames", locale),
        NGSettings.showTabNames
    ))

    entries.append(.FoldersHeader(l("NicegramSettings.Folders",
                                    locale)))
    entries.append(.foldersAtBottom(
        l("NicegramSettings.Folders.foldersAtBottom", locale),
        experimentalSettings.foldersTabAtBottom
    ))
    entries.append(.foldersAtBottomNotice(
        l("NicegramSettings.Folders.foldersAtBottomNotice", locale)
    ))

    entries.append(.RoundVideosHeader(l("NicegramSettings.RoundVideos",
                                        locale)))
    entries.append(.startWithRearCam(
        l("NicegramSettings.RoundVideos.startWithRearCam", locale),
        NGSettings.useRearCamTelescopy
    ))

    entries.append(.OtherHeader(
        presentationData.strings.ChatSettings_Other.uppercased()))
    entries.append(.hidePhoneInSettings(
        l("NicegramSettings.Other.hidePhoneInSettings", locale),
        NGSettings.hidePhoneSettings
    ))
    entries.append(.hidePhoneInSettingsNotice(
        l("NicegramSettings.Other.hidePhoneInSettingsNotice", locale)
    ))
    
    var toggleIndex: Int32 = 1
    entries.append(.easyToggle(toggleIndex, .sendWithEnter, l("SendWithKb"), NGSettings.sendWithEnter))
    toggleIndex += 1

    return entries
}

// MARK: Controller

public func nicegramSettingsController(context: AccountContext, modal: Bool = false) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var getRootControllerImpl: (() -> UIViewController?)?
    var updateTabsImpl: (() -> Void)?

    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    let arguments = NicegramSettingsControllerArguments(context: context, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, getRootController: {
        getRootControllerImpl?()
    }, updateTabs: {
        updateTabsImpl?()
    })

    let showCallsTab = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.callListSettings])
        |> map { sharedData -> Bool in
            var value = true
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings] as? CallListSettings {
                value = settings.showTab
            }
            return value
        }

    let sharedDataSignal = context.sharedContext.accountManager.sharedData(keys: [
        ApplicationSpecificSharedDataKeys.experimentalUISettings,
    ])

    let signal = combineLatest(context.sharedContext.presentationData, sharedDataSignal, showCallsTab) |> map { presentationData, sharedData, showCalls -> (ItemListControllerState, (ItemListNodeState, Any)) in

        let experimentalSettings: ExperimentalUISettings = (sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings] as? ExperimentalUISettings) ?? ExperimentalUISettings.defaultSettings

        var leftNavigationButton: ItemListNavigationButton?
        if modal {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        }

        let entries = nicegramSettingsControllerEntries(presentationData: presentationData, experimentalSettings: experimentalSettings, showCalls: showCalls)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(l("AppName", presentationData.strings.baseLanguageCode)), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    getRootControllerImpl = { [weak controller] in
        controller?.view.window?.rootViewController
    }
    updateTabsImpl = {
        _ = updateCallListSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
            var settings = settings
            settings.showTab = !settings.showTab
            return settings
        }.start(completed: {
            _ = updateCallListSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                var settings = settings
                settings.showTab = !settings.showTab
                return settings
            }.start(completed: {
                ngLog("Tabs refreshed", LOGTAG)
            })
        })
    }
    return controller
}
