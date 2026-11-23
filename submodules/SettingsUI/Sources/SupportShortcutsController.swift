import Foundation
import UIKit
import GameController
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import ChatListUI

func supportHardwareKeyboardIsConnected() -> Signal<Bool, NoError> {
    #if targetEnvironment(simulator)
    return .single(true)
    #else
    guard #available(iOS 14.0, *) else {
        return .single(false)
    }
    return Signal { subscriber in
        subscriber.putNext(GCKeyboard.coalesced != nil)
        let center = NotificationCenter.default
        let update: (Notification) -> Void = { _ in
            subscriber.putNext(GCKeyboard.coalesced != nil)
        }
        let connected = center.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main, using: update)
        let disconnected = center.addObserver(forName: .GCKeyboardDidDisconnect, object: nil, queue: .main, using: update)
        return ActionDisposable {
            center.removeObserver(connected)
            center.removeObserver(disconnected)
        }
    }
    |> distinctUntilChanged
    #endif
}

@available(iOS 13.4, *)
func supportKeyCombo(from key: UIKey) -> SupportKeyCombo? {
    var modifiers: SupportKeyCombo.Modifiers = []
    if key.modifierFlags.contains(.shift) {
        modifiers.insert(.shift)
    }
    if key.modifierFlags.contains(.control) {
        modifiers.insert(.control)
    }
    if key.modifierFlags.contains(.alternate) {
        modifiers.insert(.alternate)
    }
    if key.modifierFlags.contains(.command) {
        modifiers.insert(.command)
    }
    let code = key.keyCode.rawValue
    let name: String
    switch code {
    case 0x04 ... 0x1D:
        name = String(UnicodeScalar(UInt8(65 + code - 0x04)))
    case 0x1E ... 0x26:
        name = "\(code - 0x1E + 1)"
    case 0x27:
        name = "0"
    case 0x28, 0x58:
        name = SupportKeyCombo.returnKey
    case 0x29:
        name = SupportKeyCombo.escapeKey
    case 0x2B:
        name = SupportKeyCombo.tabKey
    case 0x2C:
        name = " "
    case 0x3A ... 0x45:
        name = "F\(code - 0x3A + 1)"
    case 0x4F:
        name = "Right"
    case 0x50:
        name = "Left"
    case 0x51:
        name = SupportKeyCombo.downKey
    case 0x52:
        name = SupportKeyCombo.upKey
    case 0xE0 ... 0xE7:
        return nil
    default:
        guard let character = key.charactersIgnoringModifiers.first else {
            return nil
        }
        name = String(character).uppercased()
    }
    return SupportKeyCombo(key: name, modifiers: modifiers)
}

private final class SupportKeyRecorderView: UIView {
    var keyPressed: ((SupportKeyCombo) -> Void)?

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard #available(iOS 13.4, *) else {
            return
        }
        for press in presses {
            if let key = press.key, let combo = supportKeyCombo(from: key) {
                self.keyPressed?(combo)
                return
            }
        }
    }

    deinit {
        KeyShortcutsController.isSuspended = false
    }
}

private func supportKeyComboTitle(_ combo: SupportKeyCombo, strings: PresentationStrings) -> String {
    return combo.displayString(escape: strings.Support_Shortcuts_KeyEscape, space: strings.Support_Shortcuts_KeySpace)
}

private func supportPresentShortcutRecorder(context: AccountContext, action: SupportShortcutAction, slot: Int, hasCombo: Bool, present: @escaping (ViewController) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let recorder = SupportKeyRecorderView()
    var alert: ViewController?

    let finish: () -> Void = {
        recorder.keyPressed = nil
        recorder.resignFirstResponder()
        recorder.removeFromSuperview()
        KeyShortcutsController.isSuspended = false
    }
    let update: (@escaping ([SupportShortcutOverride]) -> [SupportShortcutOverride]) -> Void = { f in
        let _ = updateSupportSettingsInteractively(engine: context.engine, { settings in
            var settings = settings
            settings.shortcutOverrides = f(settings.shortcutOverrides)
            return settings
        }).startStandalone()
    }
    let showMessage: (String) -> Void = { text in
        present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    recorder.keyPressed = { combo in
        finish()
        alert?.dismiss()

        guard let supportContext = context.supportContext else {
            return
        }
        switch supportShortcutAssignment(of: combo, to: action, overrides: supportContext.currentShortcutOverrides) {
        case .assignable:
            update { overrides in
                return supportShortcutOverrides(overrides, assigning: combo, slot: slot, for: action)
            }
        case .needsModifier:
            showMessage(presentationData.strings.Support_Shortcuts_NeedsModifier.replacingOccurrences(of: "{keys}", with: supportKeyComboTitle(combo, strings: presentationData.strings)))
        case .reservedByApp:
            showMessage(presentationData.strings.Support_Shortcuts_ReservedByApp.replacingOccurrences(of: "{keys}", with: supportKeyComboTitle(combo, strings: presentationData.strings)))
        case let .usedBy(other):
            if other == action {
                return
            }
            present(textAlertController(context: context, title: nil, text: presentationData.strings.Support_Shortcuts_MoveText.replacingOccurrences(of: "{keys}", with: supportKeyComboTitle(combo, strings: presentationData.strings)).replacingOccurrences(of: "{other}", with: supportShortcutTitle(other, strings: presentationData.strings)).replacingOccurrences(of: "{action}", with: supportShortcutTitle(action, strings: presentationData.strings)), actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Support_Shortcuts_MoveAction, action: {
                update { overrides in
                    return supportShortcutOverrides(supportShortcutOverrides(overrides, removing: combo, from: other), assigning: combo, slot: slot, for: action)
                }
            })]))
        }
    }

    var actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        finish()
    })]
    if hasCombo {
        actions.append(TextAlertAction(type: .destructiveAction, title: presentationData.strings.Support_Shortcuts_RemoveAction, action: {
            finish()
            update { overrides in
                return supportShortcutOverrides(overrides, assigning: nil, slot: slot, for: action)
            }
        }))
    }
    let controller = textAlertController(context: context, title: supportShortcutTitle(action, strings: presentationData.strings), text: presentationData.strings.Support_Shortcuts_PressKeys, actions: actions, dismissOnOutsideTap: false)
    alert = controller
    KeyShortcutsController.isSuspended = true
    present(controller)
    DispatchQueue.main.async {
        controller.view.addSubview(recorder)
        recorder.becomeFirstResponder()
    }
}

private func supportShortcutSettings(context: AccountContext) -> Signal<SupportSettings, NoError> {
    return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.supportSettings))
    |> map { entry -> SupportSettings in
        return entry?.get(SupportSettings.self) ?? .default
    }
}

private final class SupportShortcutSlotsArguments {
    let record: (Int, Bool) -> Void

    init(record: @escaping (Int, Bool) -> Void) {
        self.record = record
    }
}

private enum SupportShortcutSlotsEntry: ItemListNodeEntry {
    case slot(index: Int, label: String, hasCombo: Bool)
    case info(String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int {
        switch self {
        case let .slot(index, _, _):
            return index
        case .info:
            return Int.max
        }
    }

    static func <(lhs: SupportShortcutSlotsEntry, rhs: SupportShortcutSlotsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportShortcutSlotsArguments
        switch self {
        case let .slot(index, label, hasCombo):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: index == 0 ? presentationData.strings.Support_Shortcuts_FirstKey : presentationData.strings.Support_Shortcuts_SecondKey, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.record(index, hasCombo)
            })
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func supportShortcutSlotsController(context: AccountContext, action: SupportShortcutAction) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    let arguments = SupportShortcutSlotsArguments(record: { slot, hasCombo in
        supportPresentShortcutRecorder(context: context, action: action, slot: slot, hasCombo: hasCombo, present: { controller in
            presentControllerImpl?(controller)
        })
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, supportShortcutSettings(context: context))
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let combos = supportShortcutCombos(action, overrides: settings.shortcutOverrides)
        var entries: [SupportShortcutSlotsEntry] = []
        for index in 0 ..< SupportShortcutAction.maxCombos {
            let combo = index < combos.count ? combos[index] : nil
            entries.append(.slot(index: index, label: combo.flatMap { supportKeyComboTitle($0, strings: presentationData.strings) } ?? presentationData.strings.Support_Shortcuts_NotSet, hasCombo: combo != nil))
        }
        entries.append(.info(presentationData.strings.Support_Shortcuts_SlotsInfo))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(supportShortcutTitle(action, strings: presentationData.strings)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

private final class SupportShortcutsArguments {
    let open: (SupportShortcutAction) -> Void
    let reset: () -> Void

    init(open: @escaping (SupportShortcutAction) -> Void, reset: @escaping () -> Void) {
        self.open = open
        self.reset = reset
    }
}

private enum SupportShortcutsEntry: ItemListNodeEntry {
    case action(index: Int, action: SupportShortcutAction, label: String)
    case fixedHeader
    case fixed(index: Int, title: String, label: String)
    case fixedInfo
    case reset(isEnabled: Bool)

    var section: ItemListSectionId {
        switch self {
        case .action:
            return 0
        case .fixedHeader, .fixed, .fixedInfo:
            return 1
        case .reset:
            return 2
        }
    }

    var stableId: Int {
        switch self {
        case let .action(index, _, _):
            return index
        case .fixedHeader:
            return 100
        case let .fixed(index, _, _):
            return 101 + index
        case .fixedInfo:
            return 200
        case .reset:
            return 201
        }
    }

    static func <(lhs: SupportShortcutsEntry, rhs: SupportShortcutsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportShortcutsArguments
        switch self {
        case let .action(_, action, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: supportShortcutTitle(action, strings: presentationData.strings), label: label, sectionId: self.section, style: .blocks, action: {
                arguments.open(action)
            })
        case .fixedHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Support_Shortcuts_FixedHeader, sectionId: self.section)
        case let .fixed(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case .fixedInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(presentationData.strings.Support_Shortcuts_FixedInfo), sectionId: self.section)
        case let .reset(isEnabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: presentationData.strings.Support_Shortcuts_ResetToDefaults, kind: isEnabled ? .destructive : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if isEnabled {
                    arguments.reset()
                }
            })
        }
    }
}

func supportShortcutsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = SupportShortcutsArguments(open: { action in
        pushControllerImpl?(supportShortcutSlotsController(context: context, action: action))
    }, reset: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Support_Shortcuts_ResetText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .destructiveAction, title: presentationData.strings.Support_Shortcuts_ResetAction, action: {
            let _ = updateSupportSettingsInteractively(engine: context.engine, { settings in
                var settings = settings
                settings.shortcutOverrides = []
                return settings
            }).startStandalone()
        })]))
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, supportShortcutSettings(context: context))
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [SupportShortcutsEntry] = []
        for (index, action) in SupportShortcutAction.allCases.enumerated() {
            let combos = supportShortcutCombos(action, overrides: settings.shortcutOverrides)
            entries.append(.action(index: index, action: action, label: combos.isEmpty ? presentationData.strings.Support_Shortcuts_None : combos.map { supportKeyComboTitle($0, strings: presentationData.strings) }.joined(separator: "  ")))
        }
        entries.append(.fixedHeader)
        entries.append(.fixed(index: 0, title: presentationData.strings.Support_Shortcuts_DoneNext, label: "\u{21A9}"))
        entries.append(.fixed(index: 1, title: presentationData.strings.Support_Shortcuts_OpenFromPreview, label: "\u{21A9}"))
        entries.append(.fixed(index: 2, title: presentationData.strings.Support_Shortcuts_OpenTemplates, label: "\u{21E5}"))
        entries.append(.fixedInfo)
        entries.append(.reset(isEnabled: !settings.shortcutOverrides.isEmpty))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Support_Shortcuts_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
