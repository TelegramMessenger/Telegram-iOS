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
import TelegramCore
import TelegramNotices
import TelegramPresentationData
import TelegramUIPreferences
import UIKit
import NGEnv
import NGWebUtils
import NGAppCache
import NGLoadingIndicator
import NGQuickReplies
import NGRemoteConfig

fileprivate let LOGTAG = extractNameFromPath(#file)

// MARK: Arguments struct

private final class NicegramSettingsControllerArguments {
    let context: AccountContext
    let accountsContexts: [(AccountContext, EnginePeer)]
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    let getRootController: () -> UIViewController?
    let updateTabs: () -> Void

    init(context: AccountContext, accountsContexts: [(AccountContext, EnginePeer)], presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping (ViewController) -> Void, getRootController: @escaping () -> UIViewController?, updateTabs: @escaping () -> Void) {
        self.context = context
        self.accountsContexts = accountsContexts
        self.presentController = presentController
        self.pushController = pushController
        self.getRootController = getRootController
        self.updateTabs = updateTabs
    }
}

// MARK: Sections

private enum NicegramSettingsControllerSection: Int32 {
    case Unblock
    case Tabs
    case Folders
    case RoundVideos
    case Account
    case Other
    case QuickReplies
}


private enum EasyToggleType {
    case sendWithEnter
    case showProfileId
    case showRegDate
    case hideReactions
}


// MARK: ItemListNodeEntry

private enum NicegramSettingsControllerEntry: ItemListNodeEntry {
    case TabsHeader(String)
    case showContactsTab(String, Bool)
    case showCallsTab(String, Bool)
    case showTabNames(String, Bool)

    case FoldersHeader(String)
    case foldersAtBottom(String, Bool)
    case foldersAtBottomNotice(String)

    case RoundVideosHeader(String)
    case startWithRearCam(String, Bool)
    case shouldDownloadVideo(String, Bool)

    case OtherHeader(String)
    case hidePhoneInSettings(String, Bool)
    case hidePhoneInSettingsNotice(String)
    
    case easyToggle(Int32, EasyToggleType, String, Bool)
    
    case Account(String)
    case doubleBottom(String)
    case restorePremium(String, String)
    
    case unblockHeader(String)
    case unblock(String, URL)
    
    case quickReplies(String)

    // MARK: Section

    var section: ItemListSectionId {
        switch self {
        case .TabsHeader, .showContactsTab, .showCallsTab, .showTabNames:
            return NicegramSettingsControllerSection.Tabs.rawValue
        case .FoldersHeader, .foldersAtBottom, .foldersAtBottomNotice:
            return NicegramSettingsControllerSection.Folders.rawValue
        case .RoundVideosHeader, .startWithRearCam, .shouldDownloadVideo:
            return NicegramSettingsControllerSection.RoundVideos.rawValue
        case .OtherHeader, .hidePhoneInSettings, .hidePhoneInSettingsNotice, .easyToggle:
            return NicegramSettingsControllerSection.Other.rawValue
        case .quickReplies:
            return NicegramSettingsControllerSection.QuickReplies.rawValue
        case .unblockHeader, .unblock:
            return NicegramSettingsControllerSection.Unblock.rawValue
        case .Account, .restorePremium, .doubleBottom:
            return NicegramSettingsControllerSection.Account.rawValue
        }
    }

    // MARK: SectionId

    var stableId: Int32 {
        switch self {
        case .unblockHeader:
            return 800
            
        case .unblock:
            return 900
            
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
            
        case .shouldDownloadVideo:
            return 2101
            
        case .OtherHeader:
            return 2200

        case .hidePhoneInSettings:
            return 2300

        case .hidePhoneInSettingsNotice:
            return 2400

        case .quickReplies:
            return 2450

        case .Account:
            return 2500
            
        case .restorePremium:
            return 2600
            
        case .doubleBottom:
            return 2700
            
        case let .easyToggle(index, _, _, _):
            return 5000 + Int32(index)
        }
    }

    // MARK: == overload

    static func == (lhs: NicegramSettingsControllerEntry, rhs: NicegramSettingsControllerEntry) -> Bool {
        switch lhs {
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
        
        case let .shouldDownloadVideo(lhsText, lhsVar0Bool):
            if case let .shouldDownloadVideo(rhsText, rhsVar0Bool) = rhs, lhsText == rhsText, lhsVar0Bool == rhsVar0Bool {
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
        case let .easyToggle(lhsIndex, _, lhsText, lhsValue):
            if case let .easyToggle(rhsIndex, _, rhsText, rhsValue) = rhs, lhsIndex == rhsIndex, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case let .unblockHeader(lhsText):
            if case let .unblockHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .unblock(lhsText, lhsUrl):
            if case let .unblock(rhsText, rhsUrl) = rhs, lhsText == rhsText, lhsUrl == rhsUrl {
                return true
            } else {
                return false
            }
        case let .Account(lhsText):
            if case let .Account(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .restorePremium(lhsText, lhsId):
            if case let .restorePremium(rhsText, rhsId) = rhs, lhsText == rhsText, lhsId == rhsId {
                return true
            } else {
                return false
            }
        case let .doubleBottom(lhsText):
            if case let .doubleBottom(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .quickReplies(lhsText):
            if case let .quickReplies(rhsText) = rhs, lhsText == rhsText {
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
        let locale = presentationData.strings.baseLanguageCode
        switch self {
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
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.foldersTabAtBottom = value
                        return PreferencesEntry(settings)
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
            
        case let .shouldDownloadVideo(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: section, style: .blocks) { value in
                NGSettings.shouldDownloadVideo = value
            }
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
                case .showProfileId:
                    NGSettings.showProfileId = value
                case .showRegDate:
                    NGSettings.showRegDate = value
                case .hideReactions:
                    VarSystemNGSettings.hideReactions = value
                }
            })
        case let .unblockHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .unblock(text, url):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .neutral, alignment: .natural, sectionId: section, style: .blocks) {
                UIApplication.shared.openURL(url)
            }
        case let .Account(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .restorePremium(text, id):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .neutral, alignment: .natural, sectionId: section, style: .blocks) {
                NGLoadingIndicator.shared.startAnimating()
                guard var urlComponents = URLComponents(string: NGENV.restore_url) else { return }
                urlComponents.queryItems = [
                    URLQueryItem(name: "id", value: id)
                ]
                guard let url = urlComponents.url else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    var alertTitle = ""
                    var alertText = ""
                    guard
                        let data = data,                              // is there data
                        let response = response as? HTTPURLResponse,  // is there HTTP response
                        200 ..< 300 ~= response.statusCode,           // is statusCode 2XX
                        error == nil                                  // was there no error
                    else {
                        NGLoadingIndicator.shared.stopAnimating()
                        DispatchQueue.main.async {
                            let controller = standardTextAlertController(
                                theme: AlertControllerTheme(presentationData: arguments.context.sharedContext.currentPresentationData.with { $0 }),
                                title: l("TelegramPremium.Failure.Title", locale),
                                text: l("TelegramPremium.Failure.Description", locale),
                                actions: [
                                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                                ]
                            )
                            arguments.presentController(controller, nil)
                        }
                        return
                    }
                    let responseObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

                    NGLoadingIndicator.shared.stopAnimating()

                    if let premiumData = responseObject?["data"] as? [String: Any], let premiumAccess = premiumData["premiumAccess"] as? Bool {
                        if premiumAccess {
                            AppCache.hasUnlimPremium = true
                            alertTitle = l("TelegramPremium.Success.Title", locale)
                            alertText = l("TelegramPremium.Success.Description", locale)
                        } else {
                            AppCache.hasUnlimPremium = false
                            alertTitle = l("TelegramPremium.Failure.Title", locale)
                            alertText = l("TelegramPremium.Failure.Pending", locale)
                        }
                    } else {
                        alertTitle = l("TelegramPremium.Failure.Title", locale)
                        alertText =  l("TelegramPremium.Failure.Description", locale)
                    }

                    DispatchQueue.main.async {
                        let controller = standardTextAlertController(
                            theme: AlertControllerTheme(presentationData: arguments.context.sharedContext.currentPresentationData.with { $0 }),
                            title: alertTitle,
                            text: alertText,
                            actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})
                            ]
                        )
                        arguments.presentController(controller, nil)
                    }
                }
                task.resume()
            }
        case let .doubleBottom(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .neutral, alignment: .natural, sectionId: section, style: .blocks) {
//                arguments.pushController(doubleBottomListController(context: arguments.context, presentationData: arguments.context.sharedContext.currentPresentationData.with { $0 }, accountsContexts: arguments.accountsContexts))
            }
        case let .quickReplies(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .neutral, alignment: .natural, sectionId: section, style: .blocks) {
                arguments.pushController(quickRepliesController(context: arguments.context))
            }
        }
    }
}

// MARK: Entries list

private func nicegramSettingsControllerEntries(presentationData: PresentationData, experimentalSettings: ExperimentalUISettings, showCalls: Bool, context: AccountContext) -> [NicegramSettingsControllerEntry] {
    var entries: [NicegramSettingsControllerEntry] = []

    let locale = presentationData.strings.baseLanguageCode
    
    if !hideUnblock,
       let url = URL(string: "https://my.nicegram.app") {
        entries.append(.unblockHeader(l("NicegramSettings.Unblock.Header", locale).uppercased()))
        entries.append(.unblock(l("NicegramSettings.Unblock.Button", locale), url))
    }

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
    entries.append(.shouldDownloadVideo(
        l("NicegramSettings.RoundVideos.DownloadVideos", locale), 
        NGSettings.shouldDownloadVideo
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
    
    if #available(iOS 10.0, *) {
        entries.append(.quickReplies(l("NiceFeatures.QuickReplies", locale)))
    }

    
    entries.append(.Account(l("NiceFeatures.Account.Header", locale)))
    entries.append(.restorePremium(l("TelegramPremium.Title", locale), "\(context.account.peerId.id._internalGetInt64Value())"))
//    if !context.account.isHidden {
//        entries.append(.doubleBottom(l("DoubleBottom.Title", locale)))
//    }
    
    var toggleIndex: Int32 = 1
    // MARK: Other Toggles (Easy)
    entries.append(.easyToggle(toggleIndex, .sendWithEnter, l("SendWithKb", locale), NGSettings.sendWithEnter))
    toggleIndex += 1
    
    entries.append(.easyToggle(toggleIndex, .showProfileId, l("NicegramSettings.Other.showProfileId", locale), NGSettings.showProfileId))
    toggleIndex += 1
    
    entries.append(.easyToggle(toggleIndex, .showRegDate, l("NicegramSettings.Other.showRegDate", locale), NGSettings.showRegDate))
    toggleIndex += 1
    
    entries.append(.easyToggle(toggleIndex, .hideReactions, l("NicegramSettings.Other.hideReactions", locale), VarSystemNGSettings.hideReactions))
    toggleIndex += 1
    
    return entries
}

// MARK: Controller

public func nicegramSettingsController(context: AccountContext, accountsContexts: [(AccountContext, EnginePeer)], modal: Bool = false) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var getRootControllerImpl: (() -> UIViewController?)?
    var updateTabsImpl: (() -> Void)?

    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    let arguments = NicegramSettingsControllerArguments(context: context, accountsContexts: accountsContexts, presentController: { controller, arguments in
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
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings]?.get(CallListSettings.self) {
                value = settings.showTab
            }
            return value
        }

    let sharedDataSignal = context.sharedContext.accountManager.sharedData(keys: [
        ApplicationSpecificSharedDataKeys.experimentalUISettings,
    ])

    let signal = combineLatest(context.sharedContext.presentationData, sharedDataSignal, showCallsTab) |> map { presentationData, sharedData, showCalls -> (ItemListControllerState, (ItemListNodeState, Any)) in

        let experimentalSettings: ExperimentalUISettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings

        var leftNavigationButton: ItemListNavigationButton?
        if modal {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        }

        let entries = nicegramSettingsControllerEntries(presentationData: presentationData, experimentalSettings: experimentalSettings, showCalls: showCalls, context: context)
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
