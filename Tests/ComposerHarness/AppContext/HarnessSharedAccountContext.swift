import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import Display

/// The live members are the ones `ChatTextInputPanelNode` actually reads. Everything else lives in
/// `HarnessSharedAccountContext+Generated.swift` and traps. See the design doc §4.1 for the table
/// of read sites.
public final class HarnessSharedAccountContext: SharedAccountContext {
    private let settings: HarnessSettings
    private let accountManagerValue: AccountManager<TelegramAccountManagerTypes>
    private let presentationDataValue: Atomic<PresentationData>
    private let chatSettingsValue: Atomic<ChatSettings>
    private let applicationBindingsValue: TelegramApplicationBindings

    public init(settings: HarnessSettings, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.settings = settings
        self.accountManagerValue = accountManager
        var presentationData = defaultPresentationData()
        if settings.useDarkTheme {
            presentationData = presentationData.withUpdated(theme: defaultDarkPresentationTheme)
        }
        if settings.fontSize != presentationData.chatFontSize {
            let p = presentationData
            presentationData = PresentationData(strings: p.strings, theme: p.theme, autoNightModeTriggered: p.autoNightModeTriggered, chatWallpaper: p.chatWallpaper, chatFontSize: settings.fontSize, chatBubbleCorners: p.chatBubbleCorners, listsFontSize: p.listsFontSize, dateTimeFormat: p.dateTimeFormat, nameDisplayOrder: p.nameDisplayOrder, nameSortOrder: p.nameSortOrder, reduceMotion: p.reduceMotion, largeEmoji: p.largeEmoji)
        }
        self.presentationDataValue = Atomic(value: presentationData)
        self.chatSettingsValue = Atomic(value: ChatSettings.defaultSettings)
        // Real bindings for a foreground app with nothing to open: the widget bubble reads `applicationIsActive`
        // (`feedMessageWidgetApplicationState`) on every pass on main. Every action is a no-op; nothing here may open a URL.
        self.applicationBindingsValue = TelegramApplicationBindings(
            isMainApp: true, appBundleId: Bundle.main.bundleIdentifier ?? "org.telegram.Harness", appBuildType: .internal,
            containerPath: NSTemporaryDirectory(), appSpecificScheme: "tg",
            openUrl: { _ in }, openUniversalUrl: { _, _ in }, canOpenUrl: { _ in false }, getTopWindow: { nil },
            displayNotification: { _ in }, applicationInForeground: .single(true), applicationIsActive: .single(true),
            clearMessageNotifications: { _ in }, pushIdleTimerExtension: { EmptyDisposable }, openSettings: {},
            openAppStorePage: {}, openSubscriptions: {}, registerForNotifications: { _ in }, requestSiriAuthorization: { _ in },
            siriAuthorization: { .notDetermined }, getWindowHost: { nil }, presentNativeController: { _ in },
            dismissNativeController: {}, getAvailableAlternateIcons: { [] }, getAlternateIconName: { nil },
            requestSetAlternateIconName: { _, completion in completion(false) }, forceOrientation: { _ in }
        )
    }

    /// Read by the widget bubble (`feedMessageWidgetApplicationState`: `applicationIsActive`).
    public var applicationBindings: TelegramApplicationBindings {
        return self.applicationBindingsValue
    }

    /// Read by `EmojiSuggestionsComponent.suggestionData` (from `ChatTextInputPanelNode.updateInputField`)
    /// whenever the text ends in an emoji. The real manager the harness account was opened through.
    public var accountManager: AccountManager<TelegramAccountManagerTypes> {
        return self.accountManagerValue
    }

    /// Read at `ChatTextInputPanelNode.swift:1254`, `:4355`, `:4447`.
    public var currentPresentationData: Atomic<PresentationData> {
        return self.presentationDataValue
    }

    /// Read at `ChatTextInputPanelNode.swift:870-881` — this is the backend switch, and it is the
    /// one answer in this whole file that the harness cannot afford to get wrong.
    public var immediateExperimentalUISettings: ExperimentalUISettings {
        var value = ExperimentalUISettings.defaultSettings
        switch self.settings.backend {
        case .engine:
            // The engine flag also forces the composer native, which it must be for the engine
            // editor to be built at all.
            value.useInputDecEngine = true
            value.inputDecTextBackend = true
        case .legacy:
            value.useInputDecEngine = false
            value.inputDecTextBackend = false
        }
        return value
    }

    /// Read at `ChatTextInputPanelNode.swift:4873` (`sendWithCmdEnter`).
    public var currentChatSettings: Atomic<ChatSettings> {
        return self.chatSettingsValue
    }

    /// **`nil` is the honest answer, not a stub.** `mainWindow` is optional precisely because a
    /// host may not have Telegram's `Window1`; the harness uses a plain scene-backed `UIWindow`,
    /// so there is no `Window1` to hand back. Returning one would be the lie.
    public var mainWindow: Window1? {
        return nil
    }

    /// Read at `ChatTextInputPanelNode.swift:2049` (`fullTranslucency`).
    public var energyUsageSettings: EnergyUsageSettings {
        return EnergyUsageSettings.default
    }
}
