import Foundation
import Postbox

public struct SupportKeyCombo: Codable, Hashable {
    public struct Modifiers: OptionSet, Hashable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        public static let shift = Modifiers(rawValue: 1 << 0)
        public static let control = Modifiers(rawValue: 1 << 1)
        public static let alternate = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public static let returnKey = "\r"
    public static let tabKey = "\t"
    public static let escapeKey = "Escape"
    public static let upKey = "Up"
    public static let downKey = "Down"

    public var key: String
    public var modifiers: Modifiers

    public init(key: String, modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.key = try container.decode(String.self, forKey: "k")
        self.modifiers = Modifiers(rawValue: try container.decode(Int32.self, forKey: "m"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.key, forKey: "k")
        try container.encode(self.modifiers.rawValue, forKey: "m")
    }

    public var isFunctionKey: Bool {
        return self.key.hasPrefix("F") && Int(self.key.dropFirst()) != nil
    }

    public func displayString(escape: String, space: String) -> String {
        var result = ""
        if self.modifiers.contains(.control) {
            result += "\u{2303}"
        }
        if self.modifiers.contains(.alternate) {
            result += "\u{2325}"
        }
        if self.modifiers.contains(.shift) {
            result += "\u{21E7}"
        }
        if self.modifiers.contains(.command) {
            result += "\u{2318}"
        }
        switch self.key {
        case SupportKeyCombo.returnKey:
            result += "\u{21A9}"
        case SupportKeyCombo.tabKey:
            result += "\u{21E5}"
        case SupportKeyCombo.escapeKey:
            result += escape
        case SupportKeyCombo.upKey:
            result += "\u{2191}"
        case SupportKeyCombo.downKey:
            result += "\u{2193}"
        case "Left":
            result += "\u{2190}"
        case "Right":
            result += "\u{2192}"
        case " ":
            result += space
        default:
            result += self.key
        }
        return result
    }
}

public enum SupportShortcutScope {
    case chat
    case chatList
    case everywhere

    func overlaps(_ other: SupportShortcutScope) -> Bool {
        return self == .everywhere || other == .everywhere || self == other
    }
}

public enum SupportShortcutAction: String, CaseIterable {
    case previousChat
    case nextChat
    case previousOpenedChat
    case nextOpenedChat
    case muteChat
    case sendAndStay
    case closeChat
    case reloadTemplates
    case showCurrentChat
    case openAbuseBot

    public static let maxCombos = 2

    public var scope: SupportShortcutScope {
        switch self {
        case .previousOpenedChat, .nextOpenedChat, .muteChat, .sendAndStay, .closeChat:
            return .chat
        case .showCurrentChat, .openAbuseBot:
            return .chatList
        case .previousChat, .nextChat, .reloadTemplates:
            return .everywhere
        }
    }

    public var defaultCombos: [SupportKeyCombo] {
        let controlShift: SupportKeyCombo.Modifiers = [.control, .shift]
        let commandShift: SupportKeyCombo.Modifiers = [.command, .shift]
        switch self {
        case .previousChat:
            return [SupportKeyCombo(key: SupportKeyCombo.upKey, modifiers: [.alternate])]
        case .nextChat:
            return [SupportKeyCombo(key: SupportKeyCombo.downKey, modifiers: [.alternate])]
        case .previousOpenedChat:
            return [SupportKeyCombo(key: "X", modifiers: controlShift), SupportKeyCombo(key: "X", modifiers: commandShift)]
        case .nextOpenedChat:
            return [SupportKeyCombo(key: "C", modifiers: controlShift), SupportKeyCombo(key: "C", modifiers: commandShift)]
        case .muteChat:
            return [SupportKeyCombo(key: "M", modifiers: controlShift), SupportKeyCombo(key: "M", modifiers: commandShift)]
        case .sendAndStay:
            return [SupportKeyCombo(key: SupportKeyCombo.returnKey, modifiers: controlShift), SupportKeyCombo(key: SupportKeyCombo.returnKey, modifiers: commandShift)]
        case .closeChat:
            return [SupportKeyCombo(key: SupportKeyCombo.escapeKey, modifiers: [])]
        case .reloadTemplates:
            return [SupportKeyCombo(key: "F5", modifiers: []), SupportKeyCombo(key: "R", modifiers: commandShift)]
        case .showCurrentChat:
            return [SupportKeyCombo(key: "L", modifiers: controlShift), SupportKeyCombo(key: "L", modifiers: commandShift)]
        case .openAbuseBot:
            return [SupportKeyCombo(key: "A", modifiers: controlShift), SupportKeyCombo(key: "A", modifiers: commandShift)]
        }
    }
}

public struct SupportShortcutOverride: Codable, Equatable {
    public var action: String
    public var combos: [SupportKeyCombo]

    public init(action: SupportShortcutAction, combos: [SupportKeyCombo]) {
        self.action = action.rawValue
        self.combos = combos
    }
}

public enum SupportShortcutAssignment: Equatable {
    case assignable
    case needsModifier
    case reservedByApp
    case usedBy(SupportShortcutAction)
}

public func supportShortcutCombos(_ action: SupportShortcutAction, overrides: [SupportShortcutOverride]) -> [SupportKeyCombo] {
    if let override = overrides.first(where: { $0.action == action.rawValue }) {
        return override.combos
    }
    return action.defaultCombos
}

public func supportShortcutOverrides(_ overrides: [SupportShortcutOverride], setting combos: [SupportKeyCombo], for action: SupportShortcutAction) -> [SupportShortcutOverride] {
    var result = overrides.filter { $0.action != action.rawValue }
    if combos != action.defaultCombos {
        result.append(SupportShortcutOverride(action: action, combos: Array(combos.prefix(SupportShortcutAction.maxCombos))))
    }
    return result
}

public func supportShortcutOverrides(_ overrides: [SupportShortcutOverride], assigning combo: SupportKeyCombo?, slot: Int, for action: SupportShortcutAction) -> [SupportShortcutOverride] {
    var combos = supportShortcutCombos(action, overrides: overrides)
    if let combo {
        if slot < combos.count {
            combos[slot] = combo
        } else {
            combos.append(combo)
        }
    } else if slot < combos.count {
        combos.remove(at: slot)
    }
    return supportShortcutOverrides(overrides, setting: combos, for: action)
}

public func supportShortcutOverrides(_ overrides: [SupportShortcutOverride], removing combo: SupportKeyCombo, from action: SupportShortcutAction) -> [SupportShortcutOverride] {
    return supportShortcutOverrides(overrides, setting: supportShortcutCombos(action, overrides: overrides).filter { $0 != combo }, for: action)
}

public func supportShortcutAssignment(of combo: SupportKeyCombo, to action: SupportShortcutAction, overrides: [SupportShortcutOverride]) -> SupportShortcutAssignment {
    if !supportKeyComboStandsAlone(combo) {
        return .needsModifier
    }
    if supportKeyComboIsReservedByApp(combo) {
        return .reservedByApp
    }
    for other in SupportShortcutAction.allCases where other.scope.overlaps(action.scope) {
        if supportShortcutCombos(other, overrides: overrides).contains(combo) {
            return .usedBy(other)
        }
    }
    return .assignable
}

public func supportKeyComboIsFormatKey(_ combo: SupportKeyCombo) -> Bool {
    return combo.modifiers == [.command, .shift] && (combo.key == "X" || combo.key == "M")
}

func supportKeyComboStandsAlone(_ combo: SupportKeyCombo) -> Bool {
    if combo.key == SupportKeyCombo.escapeKey || combo.isFunctionKey {
        return true
    }
    return !combo.modifiers.intersection([.control, .alternate, .command]).isEmpty
}

func supportKeyComboIsReservedByApp(_ combo: SupportKeyCombo) -> Bool {
    let digits = (0 ... 9).map(String.init)
    switch combo.modifiers {
    case []:
        return combo.key == SupportKeyCombo.tabKey || combo.key == SupportKeyCombo.returnKey
    case [.command]:
        return ["A", "B", "C", "F", "I", "K", "L", "N", "U", "V", "W", "X", "Z", "/", SupportKeyCombo.returnKey].contains(combo.key) || digits.contains(combo.key)
    case [.command, .shift]:
        return ["N", "P", "Z"].contains(combo.key)
    case [.command, .control]:
        return combo.key == "I"
    case [.command, .alternate]:
        return digits.contains(combo.key)
    case [.alternate, .shift]:
        return combo.key == SupportKeyCombo.upKey || combo.key == SupportKeyCombo.downKey
    default:
        return false
    }
}
