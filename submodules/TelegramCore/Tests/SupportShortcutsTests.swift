import XCTest
import Postbox
@testable import TelegramCore

final class SupportShortcutsTests: XCTestCase {
    private let commandShiftM = SupportKeyCombo(key: "M", modifiers: [.command, .shift])

    func testEveryActionHasAtMostTwoDefaults() {
        for action in SupportShortcutAction.allCases {
            XCTAssertLessThanOrEqual(action.defaultCombos.count, SupportShortcutAction.maxCombos, action.rawValue)
            XCTAssertFalse(action.defaultCombos.isEmpty, action.rawValue)
        }
    }

    func testDefaultsNeverCollideWithinAScope() {
        for action in SupportShortcutAction.allCases {
            for combo in action.defaultCombos {
                for other in SupportShortcutAction.allCases where other != action && other.scope.overlaps(action.scope) {
                    XCTAssertFalse(other.defaultCombos.contains(combo), "\(action.rawValue) and \(other.rawValue)")
                }
            }
        }
    }

    func testDefaultsPassTheirOwnRules() {
        for action in SupportShortcutAction.allCases {
            for combo in action.defaultCombos {
                XCTAssertTrue(supportKeyComboStandsAlone(combo), combo.displayString(escape: "Esc", space: "Space"))
                XCTAssertFalse(supportKeyComboIsReservedByApp(combo), combo.displayString(escape: "Esc", space: "Space"))
            }
        }
    }

    func testAPlainKeyNeedsAModifierButEscapeAndFunctionKeysDoNot() {
        let plain = SupportKeyCombo(key: "J", modifiers: [])
        XCTAssertEqual(supportShortcutAssignment(of: plain, to: .muteChat, overrides: []), .needsModifier)
        let shiftOnly = SupportKeyCombo(key: "J", modifiers: [.shift])
        XCTAssertEqual(supportShortcutAssignment(of: shiftOnly, to: .muteChat, overrides: []), .needsModifier)
        XCTAssertEqual(supportShortcutAssignment(of: SupportKeyCombo(key: "F7", modifiers: []), to: .muteChat, overrides: []), .assignable)
        XCTAssertEqual(supportShortcutAssignment(of: SupportKeyCombo(key: "J", modifiers: [.control]), to: .muteChat, overrides: []), .assignable)
    }

    func testTheAppsOwnKeysAreRefusedButTheFormatKeysAreNot() {
        XCTAssertEqual(supportShortcutAssignment(of: SupportKeyCombo(key: "B", modifiers: [.command]), to: .muteChat, overrides: []), .reservedByApp)
        XCTAssertEqual(supportShortcutAssignment(of: SupportKeyCombo(key: "3", modifiers: [.command]), to: .muteChat, overrides: []), .reservedByApp)
        XCTAssertTrue(supportKeyComboIsFormatKey(self.commandShiftM))
        XCTAssertFalse(supportKeyComboIsReservedByApp(self.commandShiftM))
    }

    func testAKeyAnotherActionUsesIsReported() {
        XCTAssertEqual(supportShortcutAssignment(of: self.commandShiftM, to: .sendAndStay, overrides: []), .usedBy(.muteChat))
        XCTAssertEqual(supportShortcutAssignment(of: self.commandShiftM, to: .muteChat, overrides: []), .usedBy(.muteChat))
    }

    func testAChatKeyAndAListKeyMayShareACombination() {
        let combo = SupportKeyCombo(key: "A", modifiers: [.control, .shift])
        XCTAssertEqual(supportShortcutAssignment(of: combo, to: .muteChat, overrides: []), .assignable)
        XCTAssertEqual(supportShortcutAssignment(of: combo, to: .reloadTemplates, overrides: []), .usedBy(.openAbuseBot))
    }

    func testAssigningReplacesASlotAndAddsASecond() {
        let combo = SupportKeyCombo(key: "J", modifiers: [.control])
        var overrides = supportShortcutOverrides([], assigning: combo, slot: 0, for: .muteChat)
        XCTAssertEqual(supportShortcutCombos(.muteChat, overrides: overrides), [combo, self.commandShiftM])
        overrides = supportShortcutOverrides(overrides, assigning: nil, slot: 1, for: .muteChat)
        XCTAssertEqual(supportShortcutCombos(.muteChat, overrides: overrides), [combo])
        let second = SupportKeyCombo(key: "K", modifiers: [.control])
        overrides = supportShortcutOverrides(overrides, assigning: second, slot: 1, for: .muteChat)
        XCTAssertEqual(supportShortcutCombos(.muteChat, overrides: overrides), [combo, second])
    }

    func testClearingEveryKeyIsKept() {
        var overrides = supportShortcutOverrides([], assigning: nil, slot: 0, for: .closeChat)
        XCTAssertEqual(supportShortcutCombos(.closeChat, overrides: overrides), [])
        overrides = supportShortcutOverrides(overrides, assigning: SupportKeyCombo(key: SupportKeyCombo.escapeKey, modifiers: []), slot: 0, for: .closeChat)
        XCTAssertEqual(overrides, [])
    }

    func testMovingAKeyFreesItFromTheOtherAction() {
        let overrides = supportShortcutOverrides([], removing: self.commandShiftM, from: .muteChat)
        XCTAssertEqual(supportShortcutCombos(.muteChat, overrides: overrides), [SupportKeyCombo(key: "M", modifiers: [.control, .shift])])
        XCTAssertEqual(supportShortcutAssignment(of: self.commandShiftM, to: .sendAndStay, overrides: overrides), .assignable)
    }

    func testDisplayStrings() {
        XCTAssertEqual(SupportKeyCombo(key: "M", modifiers: [.control, .shift]).displayString(escape: "escape", space: "space"), "\u{2303}\u{21E7}M")
        XCTAssertEqual(SupportKeyCombo(key: SupportKeyCombo.returnKey, modifiers: [.command, .shift]).displayString(escape: "escape", space: "space"), "\u{21E7}\u{2318}\u{21A9}")
        XCTAssertEqual(SupportKeyCombo(key: SupportKeyCombo.upKey, modifiers: [.alternate]).displayString(escape: "escape", space: "space"), "\u{2325}\u{2191}")
        XCTAssertEqual(SupportKeyCombo(key: "Left", modifiers: [.control]).displayString(escape: "escape", space: "space"), "\u{2303}\u{2190}")
        XCTAssertEqual(SupportKeyCombo(key: "Right", modifiers: [.command]).displayString(escape: "escape", space: "space"), "\u{2318}\u{2192}")
        XCTAssertEqual(SupportKeyCombo(key: SupportKeyCombo.escapeKey, modifiers: []).displayString(escape: "escape", space: "space"), "escape")
        XCTAssertEqual(SupportKeyCombo(key: " ", modifiers: [.control]).displayString(escape: "escape", space: "space"), "\u{2303}space")
    }

    func testOverridesSurviveStorage() {
        var settings = SupportSettings.default
        settings.shortcutOverrides = supportShortcutOverrides([], assigning: SupportKeyCombo(key: "J", modifiers: [.control]), slot: 0, for: .muteChat)
        settings.shortcutOverrides = supportShortcutOverrides(settings.shortcutOverrides, assigning: nil, slot: 0, for: .closeChat)
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self)?.shortcutOverrides, settings.shortcutOverrides)
    }

    func testOldSettingsHaveNoOverrides() {
        XCTAssertEqual(SupportSettings.default.shortcutOverrides, [])
    }
}
