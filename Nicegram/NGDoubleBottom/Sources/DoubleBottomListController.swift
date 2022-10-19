import AccountContext
import Display
import Foundation
import ItemListUI
import NGData
import NGStrings
import Postbox
import PresentationDataUtils
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PasscodeUI
import TelegramStringFormatting
import UIKit
import NGEnv
import NGAppCache

private enum DoubleBottomControllerSection: Int32 {
    case IsOn
}

private final class DoubleBottomControllerArguments {
    let context: AccountContext
    let pushController: (ViewController) -> Void
    let getRootController: () -> UIViewController?
    let actionDisposable = MetaDisposable()

    init(context: AccountContext, pushController: @escaping (ViewController) -> Void, getRootController: @escaping () -> UIViewController?) {
        self.context = context
        self.pushController = pushController
        self.getRootController = getRootController
    }
}

private enum DoubleBottomControllerEntry: ItemListNodeEntry {
    case isOn(String, Bool, Bool)
    case info(String)
    
    var section: ItemListSectionId {
        switch self {
        case .isOn:
            return DoubleBottomControllerSection.IsOn.rawValue
        case .info:
            return DoubleBottomControllerSection.IsOn.rawValue
        }
    }
    
    // MARK: SectionId
    var stableId: Int32 {
        switch self {
        case .isOn:
            return 1000
        case .info:
            return 1100
        }
    }
    
    // MARK: < overload
    static func < (lhs: DoubleBottomControllerEntry, rhs: DoubleBottomControllerEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }
    
    static func == (lhs: DoubleBottomControllerEntry, rhs: DoubleBottomControllerEntry) -> Bool {
        switch lhs {
        case let .isOn(lhsText, lhsBool, _):
            if case let .isOn(rhsText, rhsBool, _) = rhs, lhsText == rhsText, lhsBool == rhsBool {
                return true
            } else {
                return false
            }
        case let .info(lhsText):
            if case let .info(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DoubleBottomControllerArguments
        switch self {
        case let .isOn(text, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: enabled, sectionId: section, style: .blocks, updated: { value in
                VarSystemNGSettings.inDoubleBottom = false
                if value {
                    arguments.context.sharedContext.openDoubleBottomFlow(arguments.context)
                } else {
                    VarSystemNGSettings.isDoubleBottomOn = false
                    
                    let _ = arguments.context.sharedContext.accountManager.transaction({ transaction -> Void in
                        let challengeData = transaction.getAccessChallengeData()
                        let challenge: PostboxAccessChallengeData
                        switch challengeData {
                        case .numericalPassword(let value):
                            challenge = .numericalPassword(value: value)
                        case .plaintextPassword(let value):
                            challenge = .plaintextPassword(value: value)
                        case .none:
                            challenge = .none
                        }
                        transaction.setAccessChallengeData(challenge)
                        for record in transaction.getRecords() {
                            transaction.updateRecord(record.id) { record in
                                guard let record = record else { return nil }
                                var attributes = record.attributes
                                attributes.removeAll { $0.isHiddenAccountAttribute }
                                return AccountRecord(id: record.id, attributes: attributes, temporarySessionId: record.temporarySessionId)
                            }
                        }
                    }).start()
                }
            })
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        }
    }
}

public func doubleBottomListController(context: AccountContext, presentationData: PresentationData, accountsContexts: [(AccountContext, EnginePeer)]) -> ViewController {
    let locale = presentationData.strings.baseLanguageCode
    var pushControllerImpl: ((ViewController) -> Void)?
    var getRootControllerImpl: (() -> UIViewController?)?
    
    let arguments = DoubleBottomControllerArguments(context: context, pushController: { controller in
        pushControllerImpl?(controller)
    }, getRootController: {
        getRootControllerImpl?()
    })
    
    let transactionStatus = (context.sharedContext.accountManager.transaction { transaction -> (Bool, Bool) in
        let hasMoreThanOnePublic = transaction.getRecords().filter({ $0.isPublic }).count > 1
        let accessChallengeData = transaction.getAccessChallengeData()
        
        let hasMainPasscode = accessChallengeData != .none
        
        return (hasMoreThanOnePublic, hasMainPasscode)
    })

    let signal = combineLatest(context.sharedContext.presentationData, transactionStatus) |> map { presentationData, contextStatus  -> (ItemListControllerState, (ItemListNodeState, Any)) in

        let entries = doubleBottomListControllerEntries(presentationData: presentationData, contextStatus: contextStatus, accountsContexts: accountsContexts)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(l("DoubleBottom.Title", locale)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    getRootControllerImpl = { [weak controller] in
        controller?.view.window?.rootViewController
    }
  
    return controller
}

// MARK: Entries list

private func doubleBottomListControllerEntries(presentationData: PresentationData, contextStatus: (Bool, Bool), accountsContexts: [(AccountContext, EnginePeer)]) -> [DoubleBottomControllerEntry] {
    let locale = presentationData.strings.baseLanguageCode
    var entries: [DoubleBottomControllerEntry] = []
    entries.append(.isOn(l("DoubleBottom.Title", locale), VarSystemNGSettings.isDoubleBottomOn, VarSystemNGSettings.isDoubleBottomOn || (contextStatus.0 && contextStatus.1)))
    entries.append(.info(l("DoubleBottom.Description", locale)))
    
    return entries
}

fileprivate extension AccountRecord {
    var isPublic: Bool {
        !attributes.contains(where: {
            guard let attribute = $0 as? TelegramAccountRecordAttribute else { return false }
            return attribute.isHiddenAccountAttribute || attribute.isLoggedOutAccountAttribute
        })
    }
}

func check(passcode: String, challengeData: PostboxAccessChallengeData) -> Bool {
    let passcodeType: PasscodeEntryFieldType
    switch challengeData {
        case let .numericalPassword(value):
            passcodeType = value.count == 6 ? .digits6 : .digits4
        default:
            passcodeType = .alphanumeric
    }
    
    switch challengeData {
    case .none:
        return true
    case let .numericalPassword(code):
        if passcodeType == .alphanumeric {
            return false
        }
        return passcode == normalizeArabicNumeralString(code, type: .western)
    case let .plaintextPassword(code):
        if passcodeType != .alphanumeric {
            return false
        }
        return passcode == code
    }
}
