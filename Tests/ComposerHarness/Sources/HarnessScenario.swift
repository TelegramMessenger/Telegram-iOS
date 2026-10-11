import Foundation
import TelegramCore
import HarnessAppContext
import TelegramUIPreferences

/// A named starting state. Tests and agents refer to these by the same string, which is the whole
/// point of a registry: "the one with a table in it" is not a contract.
public struct HarnessScenario {
    public let name: String
    public let seed: ChatInputContent?

    public static let all: [HarnessScenario] = [
        HarnessScenario(name: "empty", seed: nil),
        HarnessScenario(
            name: "one-paragraph",
            seed: HarnessContent.plainText("The quick brown fox jumps over the lazy dog.")),
        HarnessScenario(
            name: "two-paragraphs",
            seed: HarnessContent.plainText("First paragraph.\nSecond paragraph.")),
        // Taller than the composer's maximum height, so the field scrolls (drag-and-drop's scroll
        // control, `HarnessTextDragUITests`).
        // A first word far wider than the selection handles' touch zones, so a long press in its
        // middle is neither handle's (drag-and-drop, `HarnessTextDragUITests`).
        HarnessScenario(
            name: "long-word",
            seed: HarnessContent.plainText("Extraordinarily careful notes, taken slowly today.")),
        HarnessScenario(
            name: "many-lines",
            seed: HarnessContent.plainText((1 ... 40).map { "Line number \($0) of the draft" }.joined(separator: "\n"))),
    ]

    public static func named(_ name: String) -> HarnessScenario? {
        return self.all.first(where: { $0.name == name })
    }
}

/// Fixture builders. `ChatInputContent` has no `plainText` factory — only the `plainText` *getter*
/// at `ChatInputContentModel.swift:165` — so the harness owns this one rather than extending a
/// TelegramCore type for a test concern.
public enum HarnessContent {
    public static func plainText(_ text: String) -> ChatInputContent {
        let paragraphs = text.components(separatedBy: "\n").map { line -> ChatInputBlock in
            return .paragraph(ChatInputParagraph(
                style: .body, list: nil, runs: [ChatInputRun(text: line)]))
        }
        return ChatInputContent(blocks: paragraphs)
    }
}

/// The arrange channel. Setup arrives out of band so that a test only ever has to synthesise the
/// touches and keystrokes it is actually exercising; reaching a starting state by typing would
/// make every case re-pay the HID flakiness tax before it began.
public struct HarnessLaunchOptions {
    public let scenario: HarnessScenario
    public let backend: HarnessBackend
    public let useDarkTheme: Bool
    public let fontSize: PresentationFontSize

    public static func parse(_ arguments: [String]) -> HarnessLaunchOptions {
        func value(_ key: String) -> String? {
            guard let index = arguments.firstIndex(of: key), index + 1 < arguments.count else {
                return nil
            }
            return arguments[index + 1]
        }
        return HarnessLaunchOptions(
            scenario: value("-harness-scenario").flatMap(HarnessScenario.named)
                ?? HarnessScenario.all[0],
            backend: value("-harness-backend").flatMap(HarnessBackend.init(rawValue:)) ?? .engine,
            useDarkTheme: value("-harness-theme") == "dark",
            fontSize: value("-harness-font-size").flatMap { name in
                PresentationFontSize.allCases.first { "\($0)" == name }
            } ?? .regular
        )
    }
}
