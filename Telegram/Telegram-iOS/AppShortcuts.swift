import AppIntents
import TelegramUI

// App Shortcuts are shown under the app in Spotlight's top hit, in the Shortcuts app and to Siri.
// Each intent opens the app and reuses the Home Screen quick-action handling.

@available(iOS 16.0, *)
struct NewChatAppIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("Intents.Shortcut.NewChat.Title", defaultValue: "New Chat", table: "AppShortcuts")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let _ = performApplicationShortcut(type: "compose")
        return .result()
    }
}

@available(iOS 16.0, *)
struct SavedMessagesAppIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("Intents.Shortcut.SavedMessages.Title", defaultValue: "Saved Messages", table: "AppShortcuts")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let _ = performApplicationShortcut(type: "savedMessages")
        return .result()
    }
}

@available(iOS 16.0, *)
struct NewStoryAppIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("Intents.Shortcut.NewStory.Title", defaultValue: "New Story", table: "AppShortcuts")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let _ = performApplicationShortcut(type: "newStory")
        return .result()
    }
}

@available(iOS 16.0, *)
struct TelegramAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewChatAppIntent(),
            phrases: [
                "New chat in \(.applicationName)",
                "Start a \(.applicationName) chat"
            ],
            shortTitle: LocalizedStringResource("Intents.Shortcut.NewChat.Title", defaultValue: "New Chat", table: "AppShortcuts"),
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: SavedMessagesAppIntent(),
            phrases: [
                "Open Saved Messages in \(.applicationName)",
                "Show my \(.applicationName) Saved Messages"
            ],
            shortTitle: LocalizedStringResource("Intents.Shortcut.SavedMessages.Title", defaultValue: "Saved Messages", table: "AppShortcuts"),
            systemImageName: "bookmark.fill"
        )
        AppShortcut(
            intent: NewStoryAppIntent(),
            phrases: [
                "New story in \(.applicationName)",
                "Post a story on \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Intents.Shortcut.NewStory.Title", defaultValue: "New Story", table: "AppShortcuts"),
            systemImageName: "camera"
        )
    }
}
