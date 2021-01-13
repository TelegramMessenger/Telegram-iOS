//
//  PremiumController.swift
//  NicegramPremium
//
//  Created by Sergey Akentev on 22.10.2019.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import TelegramNotices
import NGData
import NGStrings
import SyncCore

private struct SelectionState: Equatable {
}

private final class PremiumControllerArguments {
    let toggleSetting: (Bool, PremiumSettingsToggle) -> Void
    let openSetMissedInterval: () -> Void
    let testAction: () -> Void
    let openManageFilters: () -> Void
    let openIgnoreTranslations: () -> Void

    init(toggleSetting:@escaping (Bool, PremiumSettingsToggle) -> Void, openSetMissedInterval:@escaping () -> Void, testAction:@escaping () -> Void, openManageFilters:@escaping () -> Void, openIgnoreTranslations:@escaping () -> Void) {
        self.toggleSetting = toggleSetting
        self.openSetMissedInterval = openSetMissedInterval
        self.testAction = testAction
        self.openManageFilters = openManageFilters
        self.openIgnoreTranslations = openIgnoreTranslations
    }
}


private enum premiumControllerSection: Int32 {
    case mainHeader
    case syncPins
    case notifyMissed
    case manageFilters
    case other
    case test
}

private enum PremiumControllerEntityId: Equatable, Hashable {
    case index(Int)
}

private enum PremiumSettingsToggle {
    case syncPins
    case oneTapTr
    case rememberFilterOnExit
}

private enum PremiumControllerEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)

    case syncPinsHeader(PresentationTheme, String)
    case syncPinsToggle(PresentationTheme, String, Bool)
    case syncPinsNotice(PresentationTheme, String)

    case notifyMissed(PresentationTheme, String, String)
    case notifyMissedNotice(PresentationTheme, String)

    case manageFiltersHeader(PresentationTheme, String)
    case manageFilters(PresentationTheme, String)
    
    case rememberFolderOnExit(PresentationTheme, String, Bool)

    case otherHeader(PresentationTheme, String)

    case onetaptr(PresentationTheme, String, Bool)

    case testButton(PresentationTheme, String)
    case ignoretr(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .header:
            return premiumControllerSection.mainHeader.rawValue
        case .syncPinsHeader, .syncPinsToggle, .syncPinsNotice:
            return premiumControllerSection.syncPins.rawValue
        case .notifyMissed, .notifyMissedNotice:
            return premiumControllerSection.notifyMissed.rawValue
        case .manageFiltersHeader, .manageFilters, .rememberFolderOnExit:
           return premiumControllerSection.manageFilters.rawValue
        case .otherHeader, .onetaptr, .ignoretr:
            return premiumControllerSection.other.rawValue
        case .testButton:
            return premiumControllerSection.test.rawValue
        }

    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .syncPinsHeader:
            return 1000
        case .syncPinsToggle:
            return 1100
        case .syncPinsNotice:
            return 1200
        case .notifyMissed:
            return 2100
        case .notifyMissedNotice:
            return 2200
        case .manageFiltersHeader:
            return 3000
        case .manageFilters:
            return 3100
        case .rememberFolderOnExit:
            return 4000
        case .otherHeader:
            return 10000
        case .onetaptr:
            return 11000
        case .ignoretr:
            return 12000
        case .testButton:
            return 999999
        }
    }

    static func ==(lhs: PremiumControllerEntry, rhs: PremiumControllerEntry) -> Bool {
        switch lhs {
        case let .header(lhsTheme, lhsText):
            if case let .header(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .syncPinsHeader(lhsTheme, lhsText):
            if case let .syncPinsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .syncPinsToggle(lhsTheme, lhsText, lhsValue):
            if case let .syncPinsToggle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case let .syncPinsNotice(lhsTheme, lhsText):
            if case let .syncPinsNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .notifyMissed(lhsTheme, lhsText, lhsValue):
            if case let .notifyMissed(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }

        case let .notifyMissedNotice(lhsTheme, lhsText):
            if case let .notifyMissedNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .manageFiltersHeader(lhsTheme, lhsText):
            if case let .manageFiltersHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .manageFilters(lhsTheme, lhsText):
            if case let .manageFilters(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .onetaptr(lhsTheme, lhsText, lhsValue):
            if case let .onetaptr(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        
        case let .rememberFolderOnExit(lhsTheme, lhsText, lhsValue):
            if case let .rememberFolderOnExit(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
            
        case let .otherHeader(lhsTheme, lhsText):
            if case let .otherHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }

        case let .testButton(lhsTheme, lhsText):
            if case let .testButton(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .ignoretr(lhsTheme, lhsText):
            if case let .ignoretr(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        }

    }

    static func <(lhs: PremiumControllerEntry, rhs: PremiumControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PremiumControllerArguments
        switch self {
        case let .header(theme, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .syncPinsHeader(theme, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .syncPinsToggle(theme, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleSetting(value, .syncPins)
            })
        case let .syncPinsNotice(theme, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        case let .notifyMissed(theme, title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.openSetMissedInterval()
            })
        case let .notifyMissedNotice(theme, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .manageFiltersHeader(theme, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .manageFilters(theme, text):
            return ItemListDisclosureItem(presentationData: presentationData, icon: nil, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openManageFilters()
            })
        case let .otherHeader(theme, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .onetaptr(theme, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleSetting(value, .oneTapTr)
            })

        case let .testButton(theme, text):
            return ItemListActionItem(presentationData: presentationData, title: "Test Button", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.testAction()
            })
        case let .ignoretr(theme, text):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openIgnoreTranslations()
            })
        case let .rememberFolderOnExit(theme, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleSetting(value, .rememberFilterOnExit)
            })
        }
    }

}


private func premiumControllerEntries(presentationData: PresentationData) -> [PremiumControllerEntry] {
    var entries: [PremiumControllerEntry] = []

    let theme = presentationData.theme
    let strings = presentationData.strings
    let locale = presentationData.strings.baseLanguageCode

    entries.append(.rememberFolderOnExit(theme, l("Premium.rememberFolderOnExit", locale), NGSettings.rememberFolderOnExit))
    entries.append(.onetaptr(theme, l("Premium.OnetapTranslate", locale), NGSettings.oneTapTr))
    entries.append(.ignoretr(theme, l("Premium.IgnoreTranslate.Title", locale)))

    #if DEBUG
    entries.append(.testButton(theme, "TEST"))
    #endif

    return entries
}


private struct PremiumSelectionState: Equatable {
    var updatingFiltersAmountValue: Int32? = nil
}

private func stringForShowMissedTimeout(_ strings: PresentationStrings, _ timeout: Int32?) -> String {
    if let timeout = timeout {
        if timeout > 1 * 31 * 24 * 60 * 60 {
            return strings.PrivacySettings_PasscodeOff
        } else {
            return timeIntervalString(strings: strings, value: timeout)
        }
    } else {
        return strings.PrivacySettings_PasscodeOff
    }
}

public func premiumController(context: AccountContext) -> ViewController {
    // let statePromise = ValuePromise(PremiumSelectionState(), ignoreRepeated: true)
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var pushControllerImpl: ((ViewController) -> Void)?

    //var currentBrowser = Browser(rawValue: "safari")
    let statePromise = ValuePromise(SelectionState(), ignoreRepeated: false)
    let stateValue = Atomic(value: SelectionState())
    let updateState: ((SelectionState) -> SelectionState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }


    func updateTabs() {
       //
    }

    let arguments = PremiumControllerArguments(toggleSetting: { value, setting in
        switch (setting) {
        case .oneTapTr:
            NGSettings.oneTapTr = value
        case .rememberFilterOnExit:
            NGSettings.rememberFolderOnExit = value
        default:
            break
        }
        updateState { state in
            return SelectionState()
        }
    }, openSetMissedInterval: {
//        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
//        let actionSheet = ActionSheetController(presentationData: presentationData)
//        var items: [ActionSheetItem] = []
//        let setAction: (Int32?) -> Void = { value in
//            if let value = value {
//                if value == Int32.max {
//                    VarPremiumSettings.notifyMissed = false
//                } else if value > 0 {
//                    VarPremiumSettings.notifyMissed = true
//                    VarPremiumSettings.notifyMissedEach = Int(value)
//                } else {
//                    VarPremiumSettings.notifyMissed = false
//                }
//            } else {
//                VarPremiumSettings.notifyMissed = false
//            }
//            updateState { state in
//                return SelectionState()
//            }
//        }
//        var values: [Int32] = [
//            1 * 60,
//            5 * 60,
//            15 * 60,
//            30 * 60,
//            1 * 60 * 60,
//            3 * 60 * 60,
//            5 * 60 * 60,
//            8 * 60 * 60,
//            Int32.max]
//
//        #if DEBUG
//        values.append(10)
//        values.sort()
//        #endif
//
//        for value in values {
//            var t: Int32?
//            if value != 0 {
//                t = value
//            }
//            items.append(ActionSheetButtonItem(title: stringForShowMissedTimeout(presentationData.strings, t), color: .accent, action: { [weak actionSheet] in
//                actionSheet?.dismissAnimated()
//
//                setAction(t)
//            }))
//        }
//
//        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
//            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
//                actionSheet?.dismissAnimated()
//            })
//            ])])
//        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, testAction: {
//        presentControllerImpl?(WebController(url: URL(string: "https://nicegram.app/")!), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))

//        let msg = "- 儒家 \n\n> - Dota"
//        let _ = (getRegDate(context.account.peerId.toInt64(), owner: context.account.peerId.toInt64())  |> deliverOnMainQueue).start(next: { response in
//            print("Regdate response", response)
//            let dateFormatter = DateFormatter()
//            dateFormatter.timeZone = TimeZone(abbreviation: "UTC") //Set timezone that you want
//            dateFormatter.locale = NSLocale.current
//            dateFormatter.setLocalizedDateFormatFromTemplate("MMMMy")
//            let strDate = dateFormatter.string(from: response)
//            print(strDate)
//        },
//        error: {_ in print("error regdate request")})
//        print("TESTED!")

//        if let exportPath = VarNicegramSettings.exportSettings() {
//            var messages: [EnqueueMessage] = []
//            let id = arc4random64()
//            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: exportPath, randomId: id), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "application/json", size: nil, attributes: [.FileName(fileName: BACKUP_NAME)])
//            messages.append(.message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil))
//            let _ = enqueueMessages(account: context.account, peerId: context.account.peerId, messages: messages).start()
//        } else {
//            print("Error exporting")
//        }




    }, openManageFilters: {
        // pushControllerImpl?(manageFilters(context: context))
    }, openIgnoreTranslations: {
        presentControllerImpl?(ignoreTranslateController(context: context), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    )



    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in

            let entries = premiumControllerEntries(presentationData: presentationData)

            var index = 0
            var scrollToItem: ListViewScrollToItem?
            // workaround
            //            let focusOnItemTag: FakeEntryTag? = nil
            //            if let focusOnItemTag = focusOnItemTag {
            //                for entry in entries {
            //                    if entry.tag?.isEqual(to: focusOnItemTag) ?? false {
            //                        scrollToItem = ListViewScrollToItem(index: index, position: .top(0.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
            //                    }
            //                    index += 1
            //                }
            //            }

            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(l("Premium.Title", presentationData.strings.baseLanguageCode)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: scrollToItem)

            return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}

