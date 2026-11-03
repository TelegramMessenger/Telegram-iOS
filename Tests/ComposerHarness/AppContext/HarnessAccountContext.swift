import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import AnimationCache
import MultiAnimationRenderer
import DCTAnimationCacheImpl
import DCTMultiAnimationRendererImpl
import LottieSettings

/// The live members are the ones `ChatTextInputPanelNode` actually reads. Everything else lives in
/// `HarnessAccountContext+Generated.swift` and traps.
public final class HarnessAccountContext: AccountContext {
    private let harnessAccount: HarnessAccount
    private let sharedContextValue: HarnessSharedAccountContext
    private let limits: Atomic<LimitsConfiguration>
    private let appConfigurationValue: Atomic<AppConfiguration>
    private let animationCacheValue: AnimationCache
    private let animationRendererValue: MultiAnimationRenderer
    private let contentSettingsValue: Atomic<ContentSettings>

    public init(account: HarnessAccount, settings: HarnessSettings) {
        self.harnessAccount = account
        self.sharedContextValue = HarnessSharedAccountContext(settings: settings, accountManager: account.accountManager)
        self.limits = Atomic(value: LimitsConfiguration.defaultValue)
        self.appConfigurationValue = Atomic(value: AppConfiguration.defaultValue)
        // The real implementations, built the way TelegramUI's own AccountContext builds them
        // (`submodules/TelegramUI/Sources/AccountContext.swift:384-391`). Custom emoji in the
        // composer render through these, so a stub would show blanks and read as an editor bug.
        let cacheStorageBox = account.account.postbox.mediaBox.cacheStorageBox
        self.animationCacheValue = DCTAnimationCacheImpl(
            basePath: account.account.postbox.mediaBox.basePath + "/animation-cache",
            allocateTempFile: {
                return TempBox.shared.tempFile(fileName: "file").path
            }, updateStorageStats: { path, size in
                if let pathData = path.data(using: .utf8) {
                    cacheStorageBox.update(id: pathData, size: size)
                }
            })
        self.animationRendererValue = DCTMultiAnimationRendererImpl()
        self.contentSettingsValue = Atomic(value: ContentSettings.default)
        // This context owns a DCTAnimationCacheImpl built over the account's media box, so it is
        // subject to the same rule the account is; see HarnessProcessRetainer.
        HarnessProcessRetainer.retain(self)
    }

    public var animationCache: AnimationCache {
        return self.animationCacheValue
    }

    public var animationRenderer: MultiAnimationRenderer {
        return self.animationRendererValue
    }

    // The remaining members the panel reads. Each is a REAL default that the app itself falls back
    // to before its configuration arrives from the server — not an invented value. Anything with
    // no genuine default stays in the generated file and traps.

    /// Read at `ChatTextInputPanelNode.swift:2049`-adjacent rendering paths.
    public var lottieRenderingSettings: LottieRenderingSettings {
        return LottieRenderingSettings(backend: .tlottie)
    }

    /// The app builds this from server colour options; with none fetched it is the empty set,
    /// which is exactly what an offline harness has.
    public var peerNameColors: PeerNameColors {
        return PeerNameColors.with(
            availableReplyColors: EngineAvailableColorOptions(hash: 0, options: []),
            availableProfileColors: EngineAvailableColorOptions(hash: 0, options: []))
    }

    /// No stickers are fetched offline, and the panel tolerates an empty set.
    public var animatedEmojiStickersValue: [String: [StickerPackItem]] {
        return [:]
    }

    public var currentContentSettings: Atomic<ContentSettings> {
        return self.contentSettingsValue
    }

    public var isPremium: Bool {
        return false
    }

    public var userLimits: EngineConfiguration.UserLimits {
        return EngineConfiguration.UserLimits(UserLimitsConfiguration.defaultValue)
    }

    public var sharedContext: SharedAccountContext {
        return self.sharedContextValue
    }

    public var account: Account {
        return self.harnessAccount.account
    }

    public var engine: TelegramEngine {
        return TelegramEngine(account: self.harnessAccount.account)
    }

    public var currentLimitsConfiguration: Atomic<LimitsConfiguration> {
        return self.limits
    }

    /// Read at `ChatTextInputPanelNode.swift:863` for `ios_rich_input_mode`. Left at the default,
    /// so the panel takes the dual-field branch and `immediateExperimentalUISettings` decides.
    public var currentAppConfiguration: Atomic<AppConfiguration> {
        return self.appConfigurationValue
    }

    /// The app's own rule (`AccountContextImpl.getAppConfigValue`) over the configuration above, so
    /// a key the default configuration lacks answers nil exactly as it does on a fresh account. Read
    /// by the chat-side kill switches and the edited-date setting.
    public func getAppConfigValue(_ key: String) -> Any? {
        if let data = self.currentAppConfiguration.with({ $0 }).data, let value = data[key] {
            return value
        }
        return nil
    }
}
