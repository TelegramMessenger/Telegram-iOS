import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import ViewControllerComponent
import BundleIconComponent
import GlassBarButtonComponent
import QrCodeUI
import TelegramUIPreferences
import ContextUI
import GlassBackgroundComponent
import WallpaperResources
import Photos
import DeviceAccess

final class QrStudioScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer
    let threadId: Int64?
    let temporary: Bool

    init(context: AccountContext, peer: EnginePeer, threadId: Int64?, temporary: Bool) {
        self.context = context
        self.peer = peer
        self.threadId = threadId
        self.temporary = temporary
    }

    static func ==(lhs: QrStudioScreenComponent, rhs: QrStudioScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.threadId != rhs.threadId {
            return false
        }
        if lhs.temporary != rhs.temporary {
            return false
        }
        return true
    }

    final class View: UIView, UIGestureRecognizerDelegate {
        private let stage = QrStudioBackgroundStage()
        private let sheetView = QrStudioSheetView()
        private var cardRestCenter = CGPoint()
        private var cardSize = CGSize()
        private var pendingKindWorkItem: DispatchWorkItem?
        private var colorsTab: QrStudioColorsTabView?
        private var giftsTab: QrStudioGiftsTabView?
        private var emojiTab: QrStudioEmojiTabView?

        private let codePill = QrStudioCodePillView()
        private let emojiStripView = QrStudioEmojiStripView()
        private var emojiStripRestCenter = CGPoint()
        private let toastView = QrStudioToastView()
        private var pendingCodeAction: PendingCodeAction?
        private var themesDisposable: Disposable?
        private var codePillSize = CGSize()
        private var codeState = QrStudioCodeState()
        private var paidPrice: Int64?
        private var didLoadPaidPrice = false
        private var privacyDisposable: Disposable?
        private var noPaidToken: ExportedNoPaidMessagesToken?
        private let noPaidTokenDisposable = MetaDisposable()
        private var isRequestingNoPaidToken = false
        private var isRevokingNoPaidToken = false
        private var revokedNoPaidToken: ExportedNoPaidMessagesToken?
        private var temporaryNoPaidToken: ExportedNoPaidMessagesToken?
        private let temporaryNoPaidTokenDisposable = MetaDisposable()
        private var isRequestingTemporaryNoPaidToken = false
        private var temporaryNoPaidTokenGeneration = 0
        private var lastTemporaryNoPaidTokenRequest: Double = -100.0
        private var didApplyCodeSettings = false
        private let card = ComponentView<Empty>()
        private let closeButton = QrStudioGlassButtonView()
        private let shareButtonView = QrStudioGlassButtonView()
        private let scanButton = QrStudioGlassButtonView()
        private let saveButton = QrStudioGlassButtonView()

        private var component: QrStudioScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        private var look = QrStudioLook()
        private var contactToken: ExportedContactToken?
        private let contactTokenDisposable = MetaDisposable()
        private var contactTokenGeneration = 0
        private var contactTokenStaleAttempt = 0
        private lazy var placeholderContactLink: String = {
            let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
            return "https://t.me/contact/" + String((0 ..< 32).map { _ in alphabet.randomElement()! })
        }()
        private var didRequestContactToken = false

        private let pan = QrStudioPan()
        private let drift = QrStudioDrift()
        private let deviceTilt = QrStudioDeviceTilt()
        private var displayLink: SharedDisplayLinkDriver.Link?
        private var displayLinkIsFullRate = false
        private var isVisible = false
        private var isUpdating = false

        private var lookDisposable: Disposable?
        private var isLookLoaded = false
        private var rawSettings: QrStudioLookSettings?
        private var customEmojiFiles: [Int64: TelegramMediaFile] = [:]
        private var isLookModified = false
        private let codeMenuCooldown = QrStudioMenuCooldown()
        private let shareMenuCooldown = QrStudioMenuCooldown()
        private var syncedServerLook: QrStudioServerLook?
        private var pendingServerLook: QrStudioServerLook?
        private var shareThemeDisposable: Disposable?
        private var didReceiveServerLook = false
        private var isResolvingCustomEmoji = false
        private var didResolveServerEmoji = false
        private let serverEmojiDisposable = MetaDisposable()
        private var isResolvingServerEmoji = false

        private func resolveServerEmoji(context: AccountContext, fileIds: [Int64]) {
            guard !self.isResolvingServerEmoji else {
                return
            }
            self.isResolvingServerEmoji = true
            self.serverEmojiDisposable.set((context.engine.stickers.resolveInlineStickers(fileIds: fileIds)
            |> take(1)
            |> deliverOnMainQueue).startStrict(next: { [weak self] files in
                guard let self else {
                    return
                }
                for (id, file) in files {
                    self.customEmojiFiles[id] = file
                }
                self.didResolveServerEmoji = true
                self.isResolvingServerEmoji = false
                self.applyServerLookIfNeeded()
                self.revealIfReady()
            }, completed: { [weak self] in
                guard let self, !self.didResolveServerEmoji else {
                    return
                }
                self.didResolveServerEmoji = true
                self.isResolvingServerEmoji = false
                self.applyServerLookIfNeeded()
                self.revealIfReady()
            }))
        }
        private var serverGift: QrStudioGift?
        private var localGift: QrStudioGift?
        private var loadedGifts: [QrStudioGift]?
        private var pinnedGiftId: Int64?
        private var didDecideGiftPin = false
        private var selectionRevealTab: QrStudioLook.Kind?
        private var backdropsDisposable: Disposable?
        private var areBackdropsLoaded = false
        private var emojiFilesDisposable: Disposable?
        private var customEmojiDisposable: Disposable?
        private var savedSettings: QrStudioLookSettings?
        private var saveWorkItem: DispatchWorkItem?
        private var unicodeEmojiFiles: [String: TelegramMediaFile] = [:]
        private var giftsContext: ProfileGiftsContext?
        private var giftsDisposable: Disposable?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.alpha = 0.0
            self.addSubview(self.presentationContainer)
            self.prepareAnimateIn()

            self.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
                guard let self else {
                    return false
                }
                return self.look.kind != .color && !self.lastHitIsInsideCode
            }

            self.stage.makeContent = { [weak self] backdrop in
                switch backdrop {
                case let .color(palette):
                    return QrStudioMeshBackgroundView(palette: palette)
                case let .emoji(items, palette):
                    if let context = self?.component?.context {
                        return QrStudioEmojiPatternView(context: context, files: items.map { $0.file }, palette: palette)
                    }
                    return QrStudioMeshBackgroundView(palette: QrStudioPalette.fallback)
                case let .gift(gift):
                    if let context = self?.component?.context {
                        return QrStudioGiftPatternView(context: context, gift: gift)
                    }
                    return QrStudioMeshBackgroundView(palette: QrStudioPalette.fallback)
                case let .theme(theme):
                    if let context = self?.component?.context {
                        return QrStudioThemeBackgroundView(context: context, theme: theme)
                    }
                    return QrStudioMeshBackgroundView(palette: QrStudioPalette.fallback)
                }
            }
            self.stage.updateContent = { content, backdrop in
                if case let .emoji(items, _) = backdrop, let content = content as? QrStudioEmojiPatternView {
                    content.updateFiles(items.map { $0.file }, at: QrStudioClock.now)
                }
            }
            self.presentationContainer.addSubview(self.stage)

            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            panRecognizer.cancelsTouchesInView = false
            self.stage.addGestureRecognizer(panRecognizer)

            self.stage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleStageTap(_:))))

            self.codePill.tapPaid = { [weak self] in
                self?.codeMenuCooldown.perform { [weak self] in
                    guard let self else {
                        return
                    }
                    self.codePill.animatePourBump()
                    self.performCodeAction(.expire)
                }
            }
            self.codePill.openMenu = { [weak self] sourceView in
                self?.codeMenuCooldown.perform { [weak self, weak sourceView] in
                    if let self, let sourceView {
                        self.openCodeMenu(sourceView: sourceView)
                    }
                }
            }
            self.codePill.needsNextCode = { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                self.requestTemporaryNoPaidToken(context: component.context, revoke: false)
            }

            self.sheetView.requestOpenTab = { [weak self] kind in
                self?.openTab(kind)
            }
            self.sheetView.progressUpdated = { [weak self] in
                self?.applySheetProgress()
            }
            self.sheetView.progressAnimated = { [weak self] samples, duration in
                self?.animateSheetProgress(samples: samples, duration: duration)
            }
            self.sheetView.progressInterrupted = { [weak self] in
                self?.removeSheetProgressAnimations()
                self?.applySheetProgress()
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.themesDisposable?.dispose()
            self.contactTokenDisposable.dispose()
            self.lookDisposable?.dispose()
            self.emojiFilesDisposable?.dispose()
            self.privacyDisposable?.dispose()
            self.noPaidTokenDisposable.dispose()
            self.temporaryNoPaidTokenDisposable.dispose()
            self.shareThemeDisposable?.dispose()
            self.backdropsDisposable?.dispose()
            self.customEmojiDisposable?.dispose()
            self.giftsDisposable?.dispose()
            self.serverEmojiDisposable.dispose()
        }

        private func loadGifts(component: QrStudioScreenComponent) {
            guard self.giftsContext == nil, self.canEdit(component) else {
                return
            }
            let giftsContext = ProfileGiftsContext(account: component.context.account, peerId: component.peer.id, filter: [.unique, .displayed, .hidden])
            self.giftsContext = giftsContext
            self.giftsDisposable = (giftsContext.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                guard let self else {
                    return
                }
                var gifts: [QrStudioGift] = []
                for item in state.filteredGifts {
                    guard case let .unique(gift) = item.gift, let studioGift = qrStudioGift(gift, reference: item.reference) else {
                        continue
                    }
                    gifts.append(studioGift)
                }
                guard case .ready = state.dataState else {
                    return
                }
                self.loadedGifts = gifts
                self.applyLoadedGifts()
            })
        }

        private static let giftsFirstPageSize = 30

        private func mergedGifts(_ loadedGifts: [QrStudioGift], isComplete: Bool) -> [QrStudioGift] {
            var gifts = loadedGifts
            for extra in isComplete ? [] : [self.localGift, self.serverGift] {
                if let extra, !gifts.contains(where: { $0.id == extra.id }) {
                    gifts.append(extra)
                }
            }
            if let pinnedGiftId = self.pinnedGiftId, let index = gifts.firstIndex(where: { $0.id == pinnedGiftId }), index != 0 {
                gifts.insert(gifts.remove(at: index), at: 0)
            }
            return gifts
        }

        private static let unpinnedGiftCount = 6

        private var rememberedGiftId: Int64? {
            if case let .gift(giftId) = self.pendingServerLook {
                return giftId
            }
            return self.rawSettings?.giftId ?? self.look.giftId
        }

        private func pinGiftIfNeeded(_ giftId: Int64?) {
            guard !self.didDecideGiftPin, self.isLookLoaded, let giftId, let loadedGifts = self.loadedGifts else {
                return
            }
            self.didDecideGiftPin = true
            if let index = loadedGifts.firstIndex(where: { $0.id == giftId }), index < QrStudioScreenComponent.View.unpinnedGiftCount {
                return
            }
            self.pinnedGiftId = giftId
        }

        private func applyExtraGifts() {
            if self.loadedGifts != nil {
                self.applyLoadedGifts()
                return
            }
            let gifts = self.mergedGifts([], isComplete: false)
            if !gifts.isEmpty, self.look.gifts != gifts {
                self.look.gifts = gifts
            }
        }

        private func applyLoadedGifts() {
            guard let loadedGifts = self.loadedGifts else {
                return
            }
            self.pinGiftIfNeeded(self.rememberedGiftId)
            let isListLoaded = self.component.flatMap { self.canEdit($0) } ?? false
            let gifts = self.mergedGifts(loadedGifts, isComplete: isListLoaded && loadedGifts.count < QrStudioScreenComponent.View.giftsFirstPageSize)
            let wasLoaded = self.areGiftsLoaded
            self.areGiftsLoaded = true
            if self.look.gifts != gifts {
                let previousBackdrop = self.look.backdrop
                self.look.gifts(gifts)
                let backdropChanged = previousBackdrop != self.look.backdrop
                self.requestUpdate(transition: (backdropChanged && !self.isLookModified) || !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.45))
            } else if !wasLoaded {
                self.requestUpdate(transition: !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.45))
            }
            if !wasLoaded {
                self.revealIfReady()
                self.applyServerLookIfNeeded()
            }
        }

        private static let defaultEmoji: [String] = ["❤", "🔥", "🎉"]
        private var didPickEmoji = false

        private var isEmojiPlaceholder: Bool {
            return !self.didPickEmoji && self.look.emoji.map { $0.unicode ?? "" } == QrStudioScreenComponent.View.defaultEmoji
        }

        private func unicodeEmojiItem(_ emoji: String) -> QrStudioEmojiItem? {
            let stripped = emoji.replacingOccurrences(of: "\u{FE0F}", with: "")
            for candidate in [emoji, stripped, stripped + "\u{FE0F}"] {
                if let file = self.unicodeEmojiFiles[candidate] {
                    return QrStudioEmojiItem(file: file, unicode: emoji)
                }
            }
            return nil
        }

        private func ensureEmojiSelection() {
            guard self.look.emoji.isEmpty else {
                return
            }
            self.look.emoji = QrStudioScreenComponent.View.defaultEmoji.compactMap { self.unicodeEmojiItem($0) }
        }

        private func applyRawSettings(context: AccountContext) {
            guard let settings = self.rawSettings, !self.isLookModified else {
                return
            }
            let hasPremium = context.isPremium || self.component.flatMap { !self.canEdit($0) } ?? false
            let allowedCustomFiles = self.customEmojiFiles.filter { hasPremium || !$0.value.isPremiumEmoji }
            let resolved = settings.resolve(unicodeFiles: self.unicodeEmojiFiles, customFiles: allowedCustomFiles, giftIds: nil, hasPremium: true)
            var look = self.look
            look.colorId = settings.colorId
            look.backdropId = settings.backdropId
            look.emoji = resolved.emoji.map { setting, file -> QrStudioEmojiItem in
                if case let .unicode(unicode) = setting {
                    return QrStudioEmojiItem(file: file, unicode: unicode)
                }
                return QrStudioEmojiItem(file: file, unicode: nil)
            }
            look.giftId = resolved.giftId
            look.themeId = nil
            look.kind = QrStudioLook.Kind(rawValue: resolved.kind) ?? .color
            if look.kind == .gift, !look.gifts.isEmpty, look.selectedGift == nil {
                look.giftId = nil
                look.kind = .color
            }
            self.look = look
            if self.look.kind == .emoji {
                self.ensureEmojiSelection()
            }
            if !self.didApplyCodeSettings, let codeRemoveFee = settings.codeRemoveFee, codeRemoveFee {
                self.codeState.removeFee = true
                self.codeState.expires = (self.component?.temporary ?? false) || (settings.codeExpires ?? false)
                self.codeState.issuedAt = QrStudioClock.now
                self.codeState.pourFrom = 0.0
            }
            self.didApplyCodeSettings = true
            self.savedSettings = self.currentSettings()
        }

        private func loadThemes(context: AccountContext) {
            guard self.themesDisposable == nil else {
                return
            }
            let classic = makeDefaultPresentationTheme(reference: .dayClassic, serviceBackgroundColor: nil)
            let defaultWallpaper = classic.chat.defaultWallpaper
            self.look.themes = [QrStudioTheme(id: QrStudioTheme.defaultId, reference: .builtin(.dayClassic), wallpaper: defaultWallpaper, colors: qrStudioWallpaperColors(defaultWallpaper))]
            self.themesDisposable = (context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager)
            |> deliverOnMainQueue).startStrict(next: { [weak self] cloudThemes in
                guard let self else {
                    return
                }
                var themes = [self.look.themes[0]]
                for cloudTheme in cloudThemes {
                    guard let emoticon = cloudTheme.emoticon, emoticon != QrStudioTheme.defaultId, let presentationTheme = makePresentationTheme(cloudTheme: cloudTheme, dark: false) else {
                        continue
                    }
                    let wallpaper = presentationTheme.chat.defaultWallpaper
                    themes.append(QrStudioTheme(id: emoticon, reference: .cloud(PresentationCloudTheme(theme: cloudTheme, resolvedWallpaper: nil, creatorAccountId: nil)), wallpaper: wallpaper, colors: qrStudioWallpaperColors(wallpaper)))
                }
                if themes != self.look.themes {
                    self.look.themes = themes
                    let isPending = !self.didStartAnimateIn
                    self.requestUpdate(transition: isPending || !self.isLookModified ? .immediate : .easeInOut(duration: 0.35))
                    self.revealIfReady()
                }
            })
        }

        private func canEdit(_ component: QrStudioScreenComponent) -> Bool {
            if component.peer.id == component.context.account.peerId {
                return true
            }
            guard case let .channel(channel) = component.peer, let addressName = channel.addressName, !addressName.isEmpty else {
                return false
            }
            return channel.flags.contains(.isCreator) || channel.hasPermission(.changeInfo)
        }

        private func lookSettingsKey() -> EngineDataBuffer? {
            guard let component = self.component, self.canEdit(component) else {
                return nil
            }
            if component.peer.id == component.context.account.peerId {
                return ApplicationSpecificPreferencesKeys.qrStudioLook
            }
            return ApplicationSpecificPreferencesKeys.qrStudioPeerLook(peerId: component.peer.id)
        }

        private func storeLookSettings(_ settings: QrStudioLookSettings) {
            guard let component = self.component, let key = self.lookSettingsKey() else {
                return
            }
            let _ = component.context.engine.preferences.update(id: key, { _ in
                return EnginePreferencesEntry(settings)
            }).startStandalone()
        }

        private func loadShareTheme(component: QrStudioScreenComponent) {
            guard self.shareThemeDisposable == nil else {
                return
            }
            let isReadOnly = !self.canEdit(component)
            self.shareThemeDisposable = (component.context.engine.peers.getShareTheme(peerId: component.peer.id)
            |> deliverOnMainQueue).startStrict(next: { [weak self] theme in
                guard let self else {
                    return
                }
                guard let theme else {
                    if isReadOnly {
                        self.didReceiveServerLook = true
                        self.revealIfReady()
                    }
                    return
                }
                let serverLook: QrStudioServerLook
                switch theme {
                case .default:
                    serverLook = .default
                case let .emojiBackdrop(reactions, backdropId):
                    let emoji = (reactions ?? []).compactMap { reaction -> QrStudioLookSettings.Emoji? in
                        switch reaction {
                        case let .builtin(value):
                            return .unicode(value)
                        case let .custom(fileId):
                            return .custom(fileId)
                        case .stars:
                            return nil
                        }
                    }
                    if emoji.isEmpty && backdropId == nil {
                        serverLook = .default
                    } else {
                        serverLook = .emojiBackdrop(emoji: emoji.isEmpty ? nil : emoji, backdropId: backdropId)
                    }
                case let .gift(gift):
                    if case let .unique(uniqueGift) = gift {
                        serverLook = .gift(uniqueGift.id)
                        self.serverGift = qrStudioGift(uniqueGift, reference: nil)
                        if isReadOnly {
                            self.loadedGifts = []
                        } else if !self.isLookModified {
                            self.pinGiftIfNeeded(uniqueGift.id)
                        }
                        self.applyExtraGifts()
                    } else {
                        serverLook = .default
                    }
                }
                self.didReceiveServerLook = true
                self.syncedServerLook = serverLook
                self.pendingServerLook = serverLook
                self.applyLoadedGifts()
                self.applyServerLookIfNeeded()
            })
        }

        private func applyServerLookIfNeeded() {
            guard let component = self.component, let serverLook = self.pendingServerLook, self.isLookLoaded else {
                return
            }
            if case let .gift(giftId) = serverLook, !self.areGiftsLoaded, !self.look.gifts.contains(where: { $0.id == giftId }) {
                return
            }
            if case .emojiBackdrop(_, .some) = serverLook, !self.areBackdropsLoaded {
                return
            }
            if !self.canEdit(component), case let .emojiBackdrop(emoji?, _) = serverLook {
                if emoji.contains(where: { if case .unicode = $0 { return true } else { return false } }), self.unicodeEmojiFiles.isEmpty {
                    return
                }
                let missingFileIds = emoji.compactMap { item -> Int64? in
                    if case let .custom(fileId) = item, self.customEmojiFiles[fileId] == nil {
                        return fileId
                    }
                    return nil
                }
                if !missingFileIds.isEmpty && !self.didResolveServerEmoji {
                    self.resolveServerEmoji(context: component.context, fileIds: missingFileIds)
                    return
                }
            }
            self.pendingServerLook = nil
            guard !self.isLookModified else {
                return
            }
            let context = component.context
            let current = self.currentSettings()
            guard current.serverLook(hasPremium: context.isPremium) != serverLook else {
                return
            }
            let settings = current.applying(serverLook)
            self.rawSettings = settings
            self.applyRawSettings(context: context)
            if self.look.kind == .emoji {
                self.ensureEmojiSelection()
            }
            self.resolveMissingCustomEmoji(context: context)
            let storedSettings = self.currentSettings()
            self.savedSettings = storedSettings
            self.storeLookSettings(storedSettings)
            self.requestUpdate(transition: !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.45))
            self.revealIfReady()
        }

        private func resolveMissingCustomEmoji(context: AccountContext) {
            guard let settings = self.rawSettings else {
                return
            }
            let missingFileIds = settings.customFileIds.filter { self.customEmojiFiles[$0] == nil }
            guard !missingFileIds.isEmpty else {
                return
            }
            self.isResolvingCustomEmoji = true
            self.customEmojiDisposable?.dispose()
            self.customEmojiDisposable = (context.engine.stickers.resolveInlineStickers(fileIds: missingFileIds)
            |> take(1)
            |> deliverOnMainQueue).startStrict(next: { [weak self] files in
                guard let self else {
                    return
                }
                self.isResolvingCustomEmoji = false
                for (id, file) in files {
                    self.customEmojiFiles[id] = file
                }
                if !files.isEmpty {
                    self.applyRawSettings(context: context)
                    self.requestUpdate(transition: !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.45))
                }
                self.revealIfReady()
            }, completed: { [weak self] in
                guard let self, self.isResolvingCustomEmoji else {
                    return
                }
                self.isResolvingCustomEmoji = false
                self.revealIfReady()
            })
        }

        private func pushShareThemeIfNeeded() {
            guard let component = self.component, self.canEdit(component), self.isLookLoaded else {
                return
            }
            let context = component.context
            let settings = self.currentSettings()
            let local = settings.serverLook(hasPremium: context.isPremium)
            guard local != self.syncedServerLook else {
                return
            }
            let update: TelegramShareThemeUpdate
            switch local {
            case .default:
                update = .default
            case let .emojiBackdrop(emoji, backdropId):
                update = .emojiBackdrop(emojis: emoji?.map { item -> MessageReaction.Reaction in
                    switch item {
                    case let .unicode(value):
                        return .builtin(value)
                    case let .custom(fileId):
                        return .custom(fileId)
                    }
                }, backdropId: backdropId)
            case let .gift(giftId):
                guard let gift = self.look.gifts.first(where: { $0.id == giftId }) else {
                    return
                }
                update = .gift(gift.reference ?? .slug(slug: gift.gift.slug))
            }
            self.syncedServerLook = local
            self.pendingServerLook = nil
            let _ = context.engine.peers.setShareTheme(peerId: component.peer.id, theme: update).startStandalone()
            self.saveWorkItem?.perform()
            self.saveWorkItem?.cancel()
            self.saveWorkItem = nil
        }

        private func loadLook(context: AccountContext) {
            guard self.lookDisposable == nil else {
                return
            }
            self.look.palettes = qrStudioProfilePalettes(context.peerNameColors)
            self.backdropsDisposable = (context.engine.peers.shareThemeBackdrops()
            |> deliverOnMainQueue).startStrict(next: { [weak self] backdrops in
                guard let self else {
                    return
                }
                func rgb(_ value: Int32) -> UInt32 {
                    return UInt32(bitPattern: value) & 0xffffff
                }
                let palettes = backdrops.map { QrStudioPalette.backdrop(id: $0.id, center: rgb($0.centerColor), edge: rgb($0.edgeColor), pattern: rgb($0.patternColor), text: rgb($0.textColor)) }
                let wasLoaded = self.areBackdropsLoaded
                self.areBackdropsLoaded = true
                if self.look.backdrops != palettes {
                    self.look.backdrops = palettes
                    self.requestUpdate(transition: !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.45))
                }
                if !wasLoaded {
                    self.applyServerLookIfNeeded()
                    self.revealIfReady()
                }
            })
            let settings: Signal<QrStudioLookSettings?, NoError>
            if let key = self.lookSettingsKey() {
                settings = context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: key))
                |> map { entry -> QrStudioLookSettings? in
                    return entry?.get(QrStudioLookSettings.self)
                }
            } else {
                settings = .single(nil)
            }
            let localCustomFiles = settings
            |> mapToSignal { settings -> Signal<[Int64: TelegramMediaFile], NoError> in
                guard let settings, !settings.customFileIds.isEmpty else {
                    return .single([:])
                }
                return context.engine.stickers.resolveInlineStickersLocal(fileIds: settings.customFileIds)
                |> take(1)
            }
            self.lookDisposable = (combineLatest(settings, localCustomFiles)
            |> take(1)
            |> deliverOnMainQueue).startStrict(next: { [weak self] settings, customFiles in
                guard let self else {
                    return
                }
                self.rawSettings = settings
                self.customEmojiFiles = customFiles
                if let settings, let gift = settings.gift, gift.id == settings.giftId {
                    self.localGift = qrStudioGift(gift, reference: settings.giftReference)
                    self.applyExtraGifts()
                }
                self.applyRawSettings(context: context)
                self.isLookLoaded = true
                self.applyExtraGifts()
                self.requestUpdate(transition: .immediate)
                self.revealIfReady()
                self.resolveMissingCustomEmoji(context: context)
                self.applyServerLookIfNeeded()
            })

            self.emojiFilesDisposable = (context.animatedEmojiStickers
            |> deliverOnMainQueue).startStrict(next: { [weak self] stickers in
                guard let self, !stickers.isEmpty else {
                    return
                }
                var unicodeFiles: [String: TelegramMediaFile] = [:]
                for (emoji, items) in stickers {
                    if let item = items.first {
                        unicodeFiles[emoji] = item.file._parse()
                    }
                }
                let wasEmpty = self.unicodeEmojiFiles.isEmpty
                self.unicodeEmojiFiles = unicodeFiles
                if wasEmpty && self.pendingServerLook != nil {
                    self.applyServerLookIfNeeded()
                }
                if wasEmpty && self.isLookLoaded {
                    self.applyRawSettings(context: context)
                    if self.look.kind == .emoji {
                        self.ensureEmojiSelection()
                    }
                    self.requestUpdate(transition: !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.45))
                    self.revealIfReady()
                }
            })
        }

        private func currentSettings() -> QrStudioLookSettings {
            var settings = self.look.settings
            settings.codeRemoveFee = self.codeState.removeFee
            settings.codeExpires = self.codeState.expires
            return settings
        }

        private func loadPaidPrice(component: QrStudioScreenComponent) {
            guard self.privacyDisposable == nil, component.peer.id == component.context.account.peerId else {
                return
            }
            let _ = component.context.engine.privacy.updateGlobalPrivacySettings().startStandalone()
            self.privacyDisposable = (component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.GlobalPrivacy())
            |> deliverOnMainQueue).startStrict(next: { [weak self] settings in
                guard let self else {
                    return
                }
                var price: Int64?
                if case let .paidMessages(amount) = settings.nonContactChatsPrivacy, amount.value > 0 {
                    price = amount.value
                }
                let wasLoaded = self.didLoadPaidPrice
                self.didLoadPaidPrice = true
                if self.paidPrice != price {
                    self.paidPrice = price
                    self.requestUpdate(transition: !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.35))
                }
                if !wasLoaded {
                    self.revealIfReady()
                }
            })
        }

        private func syncNoPaidToken(context: AccountContext) {
            guard self.codeState.removeFee, self.paidPrice != nil else {
                return
            }
            if self.codeState.expires {
                if self.temporaryNoPaidToken == nil {
                    self.requestTemporaryNoPaidToken(context: context, revoke: false)
                }
                return
            }
            guard self.noPaidToken == nil, !self.isRequestingNoPaidToken, !self.isRevokingNoPaidToken else {
                return
            }
            if let token = self.revokedNoPaidToken {
                self.revokedNoPaidToken = nil
                self.noPaidToken = token
                return
            }
            self.requestNoPaidToken(context: context, revoke: false)
        }

        private func requestNoPaidToken(context: AccountContext, revoke: Bool) {
            self.isRequestingNoPaidToken = true
            self.noPaidTokenDisposable.set((context.engine.peers.exportNoPaidMessagesToken(revoke: revoke, temporary: false)
            |> deliverOnMainQueue).startStrict(next: { [weak self] token in
                guard let self else {
                    return
                }
                self.isRequestingNoPaidToken = false
                if let token {
                    self.noPaidToken = token
                } else if self.noPaidToken == nil {
                    self.codeState.perform(.restore, at: QrStudioClock.now)
                    self.presentNoPaidTokenError()
                }
                self.requestUpdate(transition: !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.3))
                self.revealIfReady()
            }))
        }

        private func requestTemporaryNoPaidToken(context: AccountContext, revoke: Bool) {
            let time = QrStudioClock.now
            guard revoke || (!self.isRequestingTemporaryNoPaidToken && time - self.lastTemporaryNoPaidTokenRequest >= 2.0) else {
                return
            }
            self.isRequestingTemporaryNoPaidToken = true
            self.lastTemporaryNoPaidTokenRequest = time
            self.temporaryNoPaidTokenGeneration += 1
            let generation = self.temporaryNoPaidTokenGeneration
            self.temporaryNoPaidTokenDisposable.set((context.engine.peers.exportNoPaidMessagesToken(revoke: revoke, temporary: true)
            |> deliverOnMainQueue).startStrict(next: { [weak self] token in
                guard let self, self.temporaryNoPaidTokenGeneration == generation else {
                    return
                }
                self.isRequestingTemporaryNoPaidToken = false
                guard self.codeState.removeFee, self.codeState.expires else {
                    return
                }
                guard let token, let expires = token.expires else {
                    if self.temporaryNoPaidToken == nil {
                        self.codeState.perform(.restore, at: QrStudioClock.now)
                        self.presentNoPaidTokenError()
                        self.requestUpdate(transition: .easeInOut(duration: 0.3))
                        self.revealIfReady()
                    }
                    return
                }
                let now = QrStudioClock.now
                let remaining = Double(expires) - Double(context.account.network.getApproximateRemoteTimestamp())
                if let current = self.temporaryNoPaidToken, current.token == token.token, current.expires == token.expires {
                    return
                }
                self.temporaryNoPaidToken = token
                self.codeState.adopt(deadline: now + max(1.0, remaining), at: now)
                self.requestUpdate(transition: !self.didStartAnimateIn ? .immediate : .easeInOut(duration: 0.3))
                self.revealIfReady()
            }))
        }

        private func revokeNoPaidToken(context: AccountContext) {
            self.isRevokingNoPaidToken = true
            self.revokedNoPaidToken = nil
            let _ = (context.engine.peers.exportNoPaidMessagesToken(revoke: true, temporary: false)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] token in
                guard let self else {
                    return
                }
                self.isRevokingNoPaidToken = false
                self.revokedNoPaidToken = token
                if token == nil {
                    self.presentNoPaidTokenError()
                }
                self.requestUpdate(transition: .easeInOut(duration: 0.3))
            })
        }

        private func presentNoPaidTokenError() {
            guard let component = self.component else {
                return
            }
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            self.showToast(.image("Chat/Context Menu/Info"), strings.QrStudio_Toast_Failed)
        }

        private func showToast(_ icon: QrStudioToastIcon, _ text: String, action: QrStudioToast.Action? = nil) {
            if self.toastView.superview == nil {
                if let component = self.component {
                    self.toastView.lottieSettings = component.context.lottieRenderingSettings
                }
            }
            self.presentationContainer.addSubview(self.toastView)
            self.toastView.show(QrStudioToast(icon: icon, text: text, action: action), isLight: self.look.backdrop.isLight, glassTint: QrStudioGlass.tint(self.look.backdrop))
            self.layoutToast()
        }

        private func layoutToast() {
            guard self.toastView.superview != nil else {
                return
            }
            if let follow = self.sheetFollow(sample: self.sheetView.presentedSample) {
                self.toastView.center = follow.toastCenter
            } else {
                self.toastView.center = CGPoint(x: self.bounds.midX, y: self.shareButtonView.frame.minY - 16.0 - self.toastView.bounds.height * 0.5)
            }
        }

        private struct PendingCodeAction {
            let action: QrStudioCodeAction
            let wasFree: Bool
            let shatterLevel: Double?
        }

        private func applyCodeActionState(_ action: QrStudioCodeAction, transition: ComponentTransition = .immediate) -> PendingCodeAction {
            let time = QrStudioClock.now
            let shatterLevel: Double? = QrStudioBurn.shatters(self.codeState, action: action) ? QrStudioBurn.level(self.codeState, at: time) : nil
            let wasFree = self.codeState.removeFee
            self.codeState.perform(action, at: time)
            self.requestUpdate(transition: transition)
            return PendingCodeAction(action: action, wasFree: wasFree, shatterLevel: shatterLevel)
        }

        private func finishPendingCodeAction() {
            guard let pending = self.pendingCodeAction else {
                return
            }
            self.pendingCodeAction = nil
            self.finishCodeAction(pending)
        }

        private func performCodeAction(_ action: QrStudioCodeAction) {
            self.finishCodeAction(self.applyCodeActionState(action, transition: .easeInOut(duration: 0.45)))
        }

        private func finishCodeAction(_ pending: PendingCodeAction) {
            guard let component = self.component else {
                return
            }
            let action = pending.action
            let wasFree = pending.wasFree
            let time = QrStudioClock.now
            if self.codeState.expires {
                self.codeState.issuedAt = time
            }
            if let level = pending.shatterLevel {
                self.codePill.startShatter(at: time, level: level)
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
            } else if action == .expire || (action == .renew && self.codeState.expires) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred(intensity: 0.65)
                DispatchQueue.main.asyncAfter(deadline: .now() + QrStudioBurn.refill, execute: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
                })
            } else {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            self.codePill.setTaken(false, animated: false)
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            switch action {
            case .expire:
                if wasFree {
                    self.showToast(.timer, strings.QrStudio_Toast_Expires)
                } else {
                    self.showToast(.timer, strings.QrStudio_Toast_FeeRemoved)
                }
            case .permanent:
                self.showToast(.clock, strings.QrStudio_Toast_Permanent)
            case .renew:
                self.showToast(.success, strings.QrStudio_Toast_NewCode)
            case .restore:
                self.showToast(.star, strings.QrStudio_Toast_FeeRestored)
            }
            switch action {
            case .expire:
                self.temporaryNoPaidToken = nil
                self.requestTemporaryNoPaidToken(context: component.context, revoke: false)
            case .permanent:
                self.temporaryNoPaidToken = nil
                self.temporaryNoPaidTokenDisposable.set(nil)
                self.isRequestingTemporaryNoPaidToken = false
                self.syncNoPaidToken(context: component.context)
            case .renew:
                if self.codeState.expires {
                    self.requestTemporaryNoPaidToken(context: component.context, revoke: true)
                } else if !self.isRevokingNoPaidToken {
                    self.requestNoPaidToken(context: component.context, revoke: true)
                }
            case .restore:
                self.temporaryNoPaidToken = nil
                self.temporaryNoPaidTokenDisposable.set(nil)
                self.isRequestingTemporaryNoPaidToken = false
                self.noPaidToken = nil
                self.isRequestingNoPaidToken = false
                self.noPaidTokenDisposable.set(nil)
                self.revokeNoPaidToken(context: component.context)
            }
            self.requestUpdate(transition: .easeInOut(duration: 0.45))
        }

        private func sheetTheme(_ theme: PresentationTheme) -> PresentationTheme {
            if theme.overallDarkAppearance {
                return theme
            }
            return theme
        }

        private func menuPresentationData(context: AccountContext) -> PresentationData {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let isDark = QrStudioGlass.glassIsDark(!self.look.backdrop.isLight, tint: QrStudioGlass.tint(self.look.backdrop))
            if presentationData.theme.overallDarkAppearance == isDark {
                return presentationData
            }
            return presentationData.withUpdated(theme: isDark ? defaultDarkColorPresentationTheme : defaultPresentationTheme)
        }

        private func openCodeMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller() as? ViewController else {
                return
            }
            let presentationData = self.menuPresentationData(context: component.context)
            let strings = presentationData.strings
            var items: [ContextMenuItem] = []
            let sections = QrStudioBurn.menu(for: self.codeState, allowsPermanent: !component.temporary)
            for (index, section) in sections.enumerated() {
                if index != 0 {
                    items.append(.separator)
                }
                for action in section {
                    let title: String
                    let icon: String
                    var textLayout: ContextMenuActionItemTextLayout = .singleLine
                    switch action {
                    case .renew:
                        title = strings.QrStudio_Menu_Reset
                        icon = "Chat/Context Menu/Reload"
                    case .permanent:
                        title = strings.QrStudio_Menu_DisableTimer
                        icon = "Chat/Context Menu/Timer"
                        textLayout = .secondLineWithValue(strings.QrStudio_Menu_DisableTimerInfo)
                    case .expire:
                        title = strings.QrStudio_Menu_Expire
                        icon = "Chat/Context Menu/Timer"
                    case .restore:
                        title = strings.QrStudio_Menu_Restore
                        icon = "Chat/Context Menu/Stars"
                    }
                    items.append(.action(ContextMenuActionItem(text: title, textLayout: textLayout, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: icon), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] c, f in
                        guard let self else {
                            f(.default)
                            return
                        }
                        self.pendingCodeAction = self.applyCodeActionState(action)
                        let delay = self.codeMenuCooldown.dismissDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                            if let c {
                                c.dismiss(result: .default, completion: {
                                    self?.finishPendingCodeAction()
                                })
                            } else {
                                f(.default)
                            }
                        }
                    })))
                }
            }
            let contextController = makeContextController(presentationData: presentationData, source: .reference(QrStudioReferenceContentSource(controller: controller, sourceView: sourceView, centersActions: true)), items: .single(ContextController.Items(content: .list(items), usesClearGlass: QrStudioGlass.isClear(QrStudioGlass.tint(self.look.backdrop)), glassBlurRadius: QrStudioGlass.blurRadius(QrStudioGlass.tint(self.look.backdrop)))), gesture: nil)
            self.codePill.setTaken(true)
            self.codeMenuCooldown.markOpened()
            self.pendingCodeAction = nil
            contextController.dismissed = { [weak self] in
                guard let self else {
                    return
                }
                self.codeMenuCooldown.markClosed()
                if self.pendingCodeAction != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: { [weak self] in
                        self?.finishPendingCodeAction()
                    })
                } else {
                    self.codePill.setTaken(false)
                }
            }
            controller.presentInGlobalOverlay(contextController)
        }

        private func scheduleSaveLook(context: AccountContext) {
            guard self.isLookLoaded else {
                return
            }
            let settings = self.currentSettings()
            guard settings != self.savedSettings else {
                return
            }
            self.savedSettings = settings
            self.rawSettings = settings
            self.saveWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.storeLookSettings(settings)
            }
            self.saveWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }

        func updateVisibility(_ isVisible: Bool) {
            guard self.isVisible != isVisible else {
                return
            }
            self.isVisible = isVisible
            self.stage.setVisible(isVisible)
            if isVisible {
                if let component = self.component, component.temporary, let token = self.contactToken, qrStudioTokenIsExpired(expires: Double(token.expires), now: Double(component.context.account.network.getApproximateRemoteTimestamp())) {
                    self.requestContactToken(context: component.context)
                }
                self.deviceTilt.start()
            } else {
                self.pushShareThemeIfNeeded()
                self.deviceTilt.stop()
            }
            self.updateDisplayLink()
        }

        private let presentationContainer = UIView()
        private var presentationOffset: CGFloat = 0.0
        private var isAnimatingIn = false
        private var areGiftsLoaded = false
        private var pendingAnimateIn: DispatchWorkItem?
        private var isDismissing = false
        private var cardDismissRecognizer: UIPanGestureRecognizer?

        private var screenCornerRadius: CGFloat {
            return self.environment?.deviceMetrics.screenCornerRadius ?? 0.0
        }

        private func setPresentationRounded(_ rounded: Bool) {
            let layer = self.presentationContainer.layer
            layer.cornerCurve = .continuous
            layer.cornerRadius = rounded ? self.screenCornerRadius : 0.0
            layer.masksToBounds = rounded
        }

        private func setPresentationOffset(_ offset: CGFloat) {
            self.presentationOffset = offset
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.presentationContainer.layer.transform = CATransform3DMakeTranslation(0.0, offset, 0.0)
            CATransaction.commit()
        }

        func prepareAnimateIn() {
            self.setPresentationRounded(true)
            self.setPresentationOffset(max(self.bounds.height, UIScreen.main.bounds.height))
        }

        private var isLookReady: Bool {
            guard self.isLookLoaded else {
                return false
            }
            if self.look.themeId != nil && self.look.selectedTheme == nil && self.look.kind == .color {
                return false
            }
            if self.look.kind == .gift, self.look.selectedGift == nil, !self.areGiftsLoaded {
                return false
            }
            if let component = self.component, self.rawSettings?.kind == QrStudioLook.Kind.gift.rawValue, !self.areGiftsLoaded, self.look.selectedGift == nil, self.canEdit(component) {
                return false
            }
            if let component = self.component, !self.canEdit(component), !self.didReceiveServerLook || self.pendingServerLook != nil {
                return false
            }
            if let component = self.component, !self.canEdit(component), let settings = self.rawSettings, settings.kind == QrStudioLook.Kind.emoji.rawValue {
                let hasUnicode = settings.emoji.contains(where: { if case .unicode = $0 { return true } else { return false } })
                if hasUnicode && self.unicodeEmojiFiles.isEmpty {
                    return false
                }
                if self.isResolvingCustomEmoji {
                    return false
                }
            }
            if self.look.kind == .color, self.look.backdropId != nil, !self.areBackdropsLoaded {
                return false
            }
            if let component = self.component, component.peer.id == component.context.account.peerId, self.codeState.removeFee {
                if !self.didLoadPaidPrice {
                    return false
                }
                if self.paidPrice != nil {
                    let hasToken: Bool
                    if component.temporary {
                        hasToken = self.temporaryNoPaidToken != nil
                    } else if self.codeState.expires {
                        hasToken = self.temporaryNoPaidToken != nil || self.noPaidToken != nil
                    } else {
                        hasToken = self.noPaidToken != nil
                    }
                    if !hasToken {
                        return false
                    }
                }
            }
            return true
        }

        private var expansionReadyHandler: (() -> Void)?

        func whenReadyForExpansion(_ f: @escaping () -> Void) {
            if self.isLookReady {
                f()
                return
            }
            self.expansionReadyHandler = f
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                self?.fireExpansionReady()
            })
        }

        private func fireExpansionReady() {
            let handler = self.expansionReadyHandler
            self.expansionReadyHandler = nil
            handler?()
        }

        private func revealIfReady() {
            if self.expansionReadyHandler != nil, self.isLookReady {
                DispatchQueue.main.async { [weak self] in
                    self?.fireExpansionReady()
                }
            }
            guard self.pendingAnimateIn != nil, self.isLookReady else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.runPendingAnimateIn()
            }
        }

        func animateIn() {
            if !self.isLookReady && self.pendingAnimateIn == nil {
                let item = DispatchWorkItem { [weak self] in
                    self?.runPendingAnimateIn()
                }
                self.pendingAnimateIn = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
                return
            }
            self.startAnimateIn()
        }

        private func runPendingAnimateIn() {
            guard let item = self.pendingAnimateIn else {
                return
            }
            item.cancel()
            self.pendingAnimateIn = nil
            self.startAnimateIn()
        }

        private var didStartAnimateIn = false

        private func updateStatusBar() {
            guard !self.isDismissing, self.isLookReady || self.didStartAnimateIn, let controller = self.environment?.controller() as? QrStudioScreen else {
                return
            }
            let statusBarStyle: StatusBarStyle = self.look.backdrop.isLight ? .Black : .White
            if controller.statusBar.statusBarStyle != statusBarStyle {
                Queue.mainQueue().justDispatch { [weak controller] in
                    controller?.statusBar.updateStatusBarStyle(statusBarStyle, animated: true)
                }
            }
        }

        private func startAnimateIn() {
            self.alpha = 1.0
            self.didStartAnimateIn = true
            self.updateStatusBar()
            self.setPresentationRounded(true)
            self.isAnimatingIn = true
            (self.card.view as? QrStudioCardComponent.View)?.playCodeReveal(delay: 0.03)
            let from = self.presentationOffset
            self.setPresentationOffset(0.0)
            self.presentationContainer.layer.animate(from: from as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.translation.y", timingFunction: kCAMediaTimingFunctionSpring, duration: QrStudioPresentation.openDuration, additive: true, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isAnimatingIn = false
                if !self.isDismissing, self.presentationOffset == 0.0 {
                    self.setPresentationRounded(false)
                }
            })
        }

        func animateOut(velocity: CGFloat?, completion: @escaping () -> Void) {
            guard !self.isDismissing else {
                return
            }
            self.isDismissing = true
            self.pushShareThemeIfNeeded()
            (self.environment?.controller() as? QrStudioScreen)?.restoreUnderlyingStatusBar()
            self.isUserInteractionEnabled = false
            self.setPresentationRounded(true)
            let from = self.presentationOffset
            let distance = max(self.bounds.height, 1.0)
            self.setPresentationOffset(distance)
            if let velocity, velocity > 0.0 {
                let remaining = max(1.0, distance - from)
                self.presentationContainer.layer.animateSpring(from: (from - distance) as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.translation.y", duration: 0.45, initialVelocity: velocity / remaining, damping: 124.0, removeOnCompletion: false, additive: true, completion: { _ in
                    completion()
                })
            } else {
                self.presentationContainer.layer.animate(from: (from - distance) as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.translation.y", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: QrStudioPresentation.closeDuration, removeOnCompletion: false, additive: true, completion: { _ in
                    completion()
                })
            }
        }

        private var expansionBackgroundView: UIView?
        private var lastHitIsInsideCode = false

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let cardView = self.card.view, cardView.superview != nil {
                self.lastHitIsInsideCode = cardView.point(inside: self.convert(point, to: cardView), with: event)
            } else {
                self.lastHitIsInsideCode = false
            }
            return super.hitTest(point, with: event)
        }

        struct ExpansionViews {
            let background: [UIView]
            let card: [UIView]
            let controls: [UIView]
            let closeButton: UIView
            let screenCornerRadii: CornerRadii
        }

        func beginExpansionAppearance() {
            guard !self.didStartAnimateIn else {
                return
            }
            self.pendingAnimateIn?.cancel()
            self.pendingAnimateIn = nil
            self.alpha = 1.0
            self.didStartAnimateIn = true
            self.updateVisibility(true)
            self.setPresentationOffset(0.0)
            self.setPresentationRounded(false)
            self.updateStatusBar()
            (self.card.view as? QrStudioCardComponent.View)?.playCodeReveal(delay: 0.03)
        }

        func lendForExpansion(isOpening: Bool) -> ExpansionViews {
            let backgroundView = UIView(frame: self.presentationContainer.bounds)
            backgroundView.isUserInteractionEnabled = false
            backgroundView.backgroundColor = self.presentationContainer.backgroundColor
            self.presentationContainer.backgroundColor = .clear
            self.presentationContainer.insertSubview(backgroundView, at: 0)
            self.expansionBackgroundView = backgroundView
            let background: [UIView] = isOpening ? [backgroundView] : [backgroundView, self.stage]
            func isShown(_ view: UIView) -> Bool {
                return view.superview != nil && !view.isHidden && view.alpha == 1.0
            }
            let buttons = [self.codePill, self.closeButton, self.scanButton, self.shareButtonView, self.saveButton, self.emojiStripView, self.sheetView].filter(isShown)
            var controls: [UIView] = isOpening && isShown(self.stage) ? [self.stage] : []
            var card: [UIView] = []
            if let cardView = self.card.view, isShown(cardView) {
                card.append(cardView)
                card.append(contentsOf: buttons)
            } else {
                controls.append(contentsOf: buttons)
            }
            return ExpansionViews(background: background, card: card, controls: controls, closeButton: self.closeButton, screenCornerRadii: self.environment?.screenCornerRadii ?? CornerRadii(uniform: self.screenCornerRadius))
        }

        func returnFromExpansion() {
            if let backgroundView = self.expansionBackgroundView {
                self.expansionBackgroundView = nil
                self.presentationContainer.backgroundColor = backgroundView.backgroundColor
                backgroundView.removeFromSuperview()
            }
        }

        func prepareExpansionDismiss() {
            self.codeMenuCooldown.cancel()
            self.shareMenuCooldown.cancel()
            self.sheetView.close()
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === self.cardDismissRecognizer, let recognizer = gestureRecognizer as? UIPanGestureRecognizer else {
                return super.gestureRecognizerShouldBegin(gestureRecognizer)
            }
            if self.sheetView.isOpen || self.isDismissing {
                return false
            }
            let velocity = recognizer.velocity(in: self)
            return velocity.y > 0.0 && abs(velocity.y) > abs(velocity.x)
        }

        private weak var expansionPopNavigationController: NavigationController?

        private func handleExpansionPop(_ recognizer: UIPanGestureRecognizer, controller: QrStudioScreen) {
            if recognizer.state == .began {
                guard let navigationController = controller.navigationController as? NavigationController else {
                    return
                }
                let location = recognizer.location(in: navigationController.view)
                let translation = recognizer.translation(in: navigationController.view)
                guard navigationController.beginVerticalExpansionPop(from: controller, anchor: CGPoint(x: location.x - translation.x, y: location.y - translation.y)) else {
                    return
                }
                self.expansionPopNavigationController = navigationController
                self.codeMenuCooldown.cancel()
                self.shareMenuCooldown.cancel()
                navigationController.updateVerticalExpansionPop(translation: translation)
                return
            }
            guard let navigationController = self.expansionPopNavigationController else {
                return
            }
            let translation = recognizer.translation(in: navigationController.view)
            switch recognizer.state {
            case .changed:
                navigationController.updateVerticalExpansionPop(translation: translation)
            case .ended, .cancelled, .failed:
                self.expansionPopNavigationController = nil
                navigationController.endVerticalExpansionPop(translation: translation, velocity: recognizer.velocity(in: navigationController.view), isCancelled: recognizer.state != .ended)
            default:
                break
            }
        }

        @objc private func handleCardDismissPan(_ recognizer: UIPanGestureRecognizer) {
            guard !self.isDismissing else {
                return
            }
            if let controller = self.environment?.controller() as? QrStudioScreen {
                if controller.opensByExpansion {
                    self.handleExpansionPop(recognizer, controller: controller)
                    return
                }
                if controller.opensAsModal {
                    return
                }
            }
            let translation = recognizer.translation(in: self).y
            switch recognizer.state {
            case .began:
                self.setPresentationRounded(true)
                self.setPresentationOffset(QrStudioPresentation.offset(translation: translation))
            case .changed:
                self.setPresentationOffset(QrStudioPresentation.offset(translation: translation))
            case .ended, .cancelled, .failed:
                let velocity = recognizer.state == .ended ? recognizer.velocity(in: self).y : 0.0
                if QrStudioPresentation.shouldDismiss(offset: self.presentationOffset, velocity: velocity, height: self.bounds.height) {
                    self.animateOut(velocity: velocity, completion: { [weak self] in
                        self?.environment?.controller()?.dismiss(animated: false)
                    })
                } else {
                    let from = self.presentationOffset
                    self.setPresentationOffset(0.0)
                    self.presentationContainer.layer.animateSpring(from: from as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.translation.y", duration: 0.45, initialVelocity: 0.0, damping: 88.0, additive: true, completion: { [weak self] _ in
                        guard let self, !self.isDismissing, self.presentationOffset == 0.0 else {
                            return
                        }
                        self.setPresentationRounded(false)
                    })
                }
            default:
                break
            }
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let time = QrStudioClock.now
            let translation = recognizer.translation(in: self)
            let size = CGSize(width: translation.x, height: translation.y)
            switch recognizer.state {
            case .began:
                self.pan.begin(at: time)
                self.pan.update(translation: size)
            case .changed:
                self.pan.update(translation: size)
            case .ended:
                let velocity = recognizer.velocity(in: self)
                self.pan.end(translation: size, velocity: CGSize(width: velocity.x, height: velocity.y), at: time)
            case .cancelled, .failed:
                self.pan.cancel(at: time)
            default:
                break
            }
            self.updateDisplayLink()
        }

        private func requestUpdate(transition: ComponentTransition) {
            guard !self.isUpdating else {
                return
            }
            self.state?.updated(transition: transition)
        }

        private func updateDisplayLink() {
            guard self.isVisible else {
                self.displayLink = nil
                return
            }
            let isFullRate = self.pan.isActive(at: QrStudioClock.now) || self.stage.isRevealing || self.stage.wantsFullFrameRate
            if self.displayLink != nil && self.displayLinkIsFullRate == isFullRate {
                return
            }
            self.displayLinkIsFullRate = isFullRate
            self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: isFullRate ? .fps(60) : .fps(30), { [weak self] _ in
                guard let self else {
                    return
                }
                self.tick()
            })
        }

        private func tick() {
            let time = QrStudioClock.now
            self.stage.tick(time: time, pan: self.pan, drift: self.drift, tilt: self.deviceTilt.value())
            self.updateDisplayLink()
        }

        private func openTab(_ kind: QrStudioLook.Kind) {
            let wasOpen = self.sheetView.isOpen
            self.sheetView.open(tab: kind)
            self.selectionRevealTab = kind
            self.requestUpdate(transition: .immediate)

            self.pendingKindWorkItem?.cancel()
            guard self.look.kind != kind else {
                return
            }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.sheetView.isOpen, self.sheetView.currentTab == kind else {
                    return
                }
                self.isLookModified = true
                self.look.select(kind)
                if kind == .emoji {
                    self.ensureEmojiSelection()
                }
                self.requestUpdate(transition: .easeInOut(duration: 0.45))
            }
            self.pendingKindWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + (wasOpen ? 0.16 : 0.45), execute: workItem)
        }

        private func updateTabs(component: QrStudioScreenComponent, environment: EnvironmentType) {
            let sheetSize = self.sheetView.sheetSize
            guard sheetSize.width > 0.0, sheetSize.height > 0.0 else {
                return
            }

            let colorsTab: QrStudioColorsTabView
            if let current = self.colorsTab {
                colorsTab = current
            } else {
                colorsTab = QrStudioColorsTabView()
                colorsTab.tintMaskContainer = self.sheetView.tintMaskContainer(for: .color)
                colorsTab.selected = { [weak self] id in
                    guard let self else {
                        return
                    }
                    self.isLookModified = true
                    self.look.selectPalette(id: id)
                    self.requestUpdate(transition: .easeInOut(duration: 0.35))
                }
                colorsTab.selectedTheme = { [weak self] id in
                    guard let self else {
                        return
                    }
                    self.isLookModified = true
                    self.look.selectTheme(id: id)
                    self.requestUpdate(transition: .easeInOut(duration: 0.35))
                }
                let context = component.context
                colorsTab.themeImage = { theme, pixelSide in
                    let side = CGFloat(pixelSide) / UIScreenScale
                    return themeIconImage(account: context.account, accountManager: context.sharedContext.accountManager, theme: theme.reference, color: nil, wallpaper: theme.wallpaper, nightMode: false, plain: true)
                    |> map { generator -> CGImage? in
                        let size = CGSize(width: side, height: side)
                        return generator(TransformImageArguments(corners: ImageCorners(radius: side * 0.5), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets()))?.generateImage()?.cgImage
                    }
                }
                self.colorsTab = colorsTab
                self.sheetView.setContent(colorsTab, for: .color)
                self.sheetView.attachScrollView(colorsTab.scrollView)
            }
            let revealTab = self.selectionRevealTab
            self.selectionRevealTab = nil
            let shownTab: QrStudioLook.Kind? = self.sheetView.isOpen || revealTab != nil ? self.sheetView.currentTab : nil
            let colorsSelection: QrStudioColorsSelection?
            if self.look.kind == .color {
                if let theme = self.look.selectedTheme {
                    colorsSelection = .theme(theme.id)
                } else {
                    colorsSelection = self.look.palette.id.map { .palette($0) }
                }
            } else if shownTab == .color, let backdropId = self.look.backdropId, self.look.backdrops.contains(where: { $0.id == .backdrop(backdropId) }) {
                colorsSelection = .palette(.backdrop(backdropId))
            } else if shownTab == .color, self.look.themeId == nil, let paletteId = self.look.palette.id {
                colorsSelection = .palette(paletteId)
            } else {
                colorsSelection = nil
            }
            colorsTab.update(size: sheetSize, theme: self.sheetTheme(environment.theme), strings: environment.strings, themes: self.look.themes, palettes: self.look.backdrops, selection: colorsSelection, revealSelection: revealTab == .color)

            let emojiTab: QrStudioEmojiTabView
            if let current = self.emojiTab {
                emojiTab = current
            } else {
                emojiTab = QrStudioEmojiTabView(context: component.context, tintMaskContainer: self.sheetView.tintMaskContainer(for: .emoji))
                emojiTab.resolveUnicode = { [weak self] emoji in
                    return self?.unicodeEmojiItem(emoji)
                }
                emojiTab.isAnimatedUnicode = { [weak self] emoji in
                    return self?.unicodeEmojiItem(emoji) != nil
                }
                emojiTab.toggle = { [weak self] item in
                    guard let self else {
                        return false
                    }
                    if self.isEmojiPlaceholder {
                        self.look.emoji = [item]
                        self.look.kind = .emoji
                    } else {
                        guard self.look.toggleEmoji(item) else {
                            return false
                        }
                    }
                    self.didPickEmoji = true
                    self.isLookModified = true
                    self.requestUpdate(transition: .easeInOut(duration: 0.35))
                    return true
                }
                emojiTab.push = { [weak self] controller in
                    (self?.environment?.controller() as? ViewController)?.push(controller)
                }
                emojiTab.premiumRequired = { [weak self] in
                    self?.presentPremiumEmojiToast()
                }
                emojiTab.requestLayout = { [weak self] in
                    self?.requestUpdate(transition: .immediate)
                }
                emojiTab.scrollViewFound = { [weak self] scrollView in
                    self?.sheetView.attachScrollView(scrollView)
                }
                self.emojiTab = emojiTab
                self.sheetView.setContent(emojiTab, for: .emoji)
            }
            emojiTab.update(size: sheetSize, theme: self.sheetTheme(environment.theme), strings: environment.strings, deviceMetrics: environment.deviceMetrics, selected: self.isEmojiPlaceholder ? [] : self.look.emoji, animatedCount: self.unicodeEmojiFiles.count)

            let giftsTab: QrStudioGiftsTabView
            if let current = self.giftsTab {
                giftsTab = current
            } else {
                giftsTab = QrStudioGiftsTabView()
                giftsTab.tintMaskContainer = self.sheetView.tintMaskContainer(for: .gift)
                giftsTab.selected = { [weak self] id in
                    guard let self else {
                        return
                    }
                    self.isLookModified = true
                    self.look.selectGift(id: id)
                    self.requestUpdate(transition: .easeInOut(duration: 0.35))
                }
                giftsTab.loadMore = { [weak self] in
                    self?.giftsContext?.loadMore()
                }
                giftsTab.browse = { [weak self] in
                    self?.openGiftShop()
                }
                self.giftsTab = giftsTab
                self.sheetView.setContent(giftsTab, for: .gift)
                self.sheetView.attachScrollView(giftsTab.scrollView)
            }
            giftsTab.update(size: sheetSize, context: component.context, theme: self.sheetTheme(environment.theme), strings: environment.strings, gifts: self.look.gifts, isLoaded: self.areGiftsLoaded, selectedId: self.look.kind == .gift || shownTab == .gift ? self.look.giftId : nil, revealSelection: revealTab == .gift, scrollsToSelection: self.pinnedGiftId == nil || self.look.giftId != self.pinnedGiftId)
        }

        private func presentPremiumEmojiToast() {
            guard let component = self.component else {
                return
            }
            let context = component.context
            let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
            self.showToast(.star, strings.QrStudio_Toast_PremiumEmoji, action: QrStudioToast.Action(title: strings.QrStudio_Toast_Subscribe, perform: { [weak self] in
                guard let controller = self?.environment?.controller() as? ViewController else {
                    return
                }
                controller.push(context.sharedContext.makePremiumIntroController(context: context, source: .animatedEmoji, forceDark: false, dismissed: nil))
            }))
        }

        private var emojiStripItems: [QrStudioEmojiItem] {
            return self.isEmojiPlaceholder ? [] : self.look.emoji
        }

        private func updateEmojiStripVisibility() {
            let isShown = self.sheetView.isOpen && self.sheetView.currentTab == .emoji && (self.environment?.inputHeight ?? 0.0) <= 0.0 && !self.emojiStripItems.isEmpty
            self.emojiStripView.setShown(isShown, animated: true)
        }

        private func updateEmojiStrip(component: QrStudioScreenComponent, environment: EnvironmentType, transition: ComponentTransition) {
            if self.emojiStripView.superview == nil {
                self.emojiStripView.tap = { [weak self] item in
                    guard let self else {
                        return
                    }
                    guard self.look.toggleEmoji(item) else {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        return
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.didPickEmoji = true
                    self.isLookModified = true
                    self.requestUpdate(transition: .easeInOut(duration: 0.35))
                }
                self.presentationContainer.insertSubview(self.emojiStripView, aboveSubview: self.sheetView)
            }
            guard let geometry = self.sheetView.geometry else {
                return
            }
            let items = self.emojiStripItems
            let size = CGSize(width: QrStudioEmojiStripView.width(count: max(1, items.count)), height: QrStudioEmojiStripView.height)
            self.emojiStripRestCenter = CGPoint(x: geometry.capsule.midX, y: geometry.capsule.midY)
            let stripTransition: ComponentTransition = self.emojiStripView.isShown ? .spring(duration: 0.4) : .immediate
            stripTransition.setBounds(view: self.emojiStripView, bounds: CGRect(origin: CGPoint(), size: size))
            if let follow = self.sheetFollow(sample: self.sheetView.presentedSample) {
                self.emojiStripView.center = follow.stripCenter
            } else {
                self.emojiStripView.center = self.emojiStripRestCenter
            }
            self.emojiStripView.update(context: component.context, emoji: items, isDark: !self.look.backdrop.isLight, glassTint: QrStudioGlass.tint(self.look.backdrop), size: size, transition: stripTransition)
            self.updateEmojiStripVisibility()
        }

        private func openGiftShop() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let context = component.context
            let giftsController = context.sharedContext.makeGiftCollectiblesController(context: context, peerId: context.account.peerId)
            controller.push(giftsController)
        }

        @objc private func handleStageTap(_ recognizer: UITapGestureRecognizer) {
            guard case .ended = recognizer.state, self.sheetView.isOpen else {
                return
            }
            if let environment = self.environment, environment.inputHeight > 0.0 {
                self.endEditing(true)
            } else {
                self.sheetView.close()
            }
        }

        private struct SheetFollow {
            var cardCenter: CGPoint
            var cardScale: CGFloat
            var pillCenter: CGPoint
            var buttonsAlpha: CGFloat
            var toastCenter: CGPoint
            var stripCenter: CGPoint
        }

        private static let sheetFollowKey = "qrSheetFollow"

        private func sheetFollow(sample: QrStudioSheetMotion.Sample) -> SheetFollow? {
            guard let geometry = self.sheetView.geometry, self.cardSize.height > 0.0 else {
                return nil
            }
            let openness = sample.openness(travel: geometry.sheet.height)
            let search = sample.search
            let groupY = self.cardRestCenter.y - self.cardSize.height * 0.5 + (self.cardSize.height + QrStudioCardMetrics.pillReserve) * 0.5
            let panelTop = geometry.sheetFrame(height: sample.height).minY
            let rest = QrStudioSheetGeometry.raise(card: self.cardSize.height, groupY: groupY, panelTop: panelTop, gap: 35.0)
            let lifted = QrStudioSheetGeometry.raise(card: self.cardSize.height, groupY: groupY, panelTop: panelTop - geometry.searchLift(keyboard: self.sheetView.keyboardHeight), gap: 14.0)
            let fit = rest.fit + (lifted.fit - rest.fit) * search
            let lift = rest.lift + (lifted.lift - rest.lift) * search
            let scale = 1.0 + (fit - 1.0) * openness
            let cardCenter = CGPoint(x: self.cardRestCenter.x, y: self.cardRestCenter.y + lift * openness + self.cardSize.height * (1.0 - scale) * 0.5)
            let pillCenter = CGPoint(x: cardCenter.x, y: cardCenter.y + self.cardSize.height * scale * 0.5 + 16.0 + QrStudioCodePillView.height * 0.5)
            let t = min(1.0, max(0.0, openness / 0.55))
            let toastHalfHeight = self.toastView.bounds.height * 0.5
            var toastY = self.shareButtonView.frame.minY - 16.0 - toastHalfHeight
            if let windowFrame = self.sheetView.windowFrame(sample: sample) {
                toastY = min(toastY, windowFrame.minY - 16.0 - toastHalfHeight)
            }
            return SheetFollow(cardCenter: cardCenter, cardScale: scale, pillCenter: pillCenter, buttonsAlpha: 1.0 - t * t * (3.0 - 2.0 * t), toastCenter: CGPoint(x: self.bounds.midX, y: toastY), stripCenter: CGPoint(x: self.emojiStripRestCenter.x, y: self.emojiStripRestCenter.y + max(0.0, sample.pull)))
        }

        private func liftedCardCenter() -> CGPoint {
            return self.sheetFollow(sample: self.sheetView.presentedSample)?.cardCenter ?? self.cardRestCenter
        }

        private func applySheetProgress(updateButtons: Bool = true) {
            guard let follow = self.sheetFollow(sample: self.sheetView.modelSample) else {
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if let cardView = self.card.view {
                cardView.center = follow.cardCenter
                cardView.transform = CGAffineTransform(scaleX: follow.cardScale, y: follow.cardScale)
                (cardView as? QrStudioCardComponent.View)?.updateFillPosition()
            }
            if self.codePillSize.width > 0.0 {
                self.codePill.center = follow.pillCenter
                self.codePill.isUserInteractionEnabled = !self.sheetView.isOpen
                self.codePill.isActive = self.paidPrice != nil
            }
            self.saveButton.isUserInteractionEnabled = !self.sheetView.isOpen
            self.shareButtonView.isUserInteractionEnabled = !self.sheetView.isOpen
            self.updateEmojiStripVisibility()
            if self.toastView.superview != nil {
                self.toastView.center = follow.toastCenter
            }
            if self.emojiStripView.superview != nil {
                self.emojiStripView.center = follow.stripCenter
            }
            CATransaction.commit()
            if updateButtons {
                self.setButtonsOpacity([NSNumber(value: Float(follow.buttonsAlpha))], duration: 0.0)
            }
        }

        private static let buttonsOpacityKey = "qrButtonsOpacity"

        private var buttonsOpacityTarget: Float?

        private func setButtonsOpacity(_ values: [NSNumber], duration: Double) {
            let target = values.last?.floatValue
            if values.count == 1, target == self.buttonsOpacityTarget {
                return
            }
            self.buttonsOpacityTarget = target
            for layer in [self.saveButton.layer, self.shareButtonView.layer] {
                let animation: CAAnimation
                if values.count > 1 {
                    let keyframes = CAKeyframeAnimation(keyPath: "opacity")
                    keyframes.values = values
                    keyframes.calculationMode = .linear
                    keyframes.duration = duration
                    animation = keyframes
                } else {
                    let basic = CABasicAnimation(keyPath: "opacity")
                    basic.fromValue = values.first
                    basic.toValue = values.first
                    basic.duration = 0.001
                    animation = basic
                }
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
                layer.add(animation, forKey: QrStudioScreenComponent.View.buttonsOpacityKey)
            }
        }

        private func addSheetKeyframes(_ layer: CALayer, _ keyPath: String, _ values: [Any], duration: Double) {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = values
            animation.duration = duration
            animation.calculationMode = .linear
            layer.add(animation, forKey: QrStudioScreenComponent.View.sheetFollowKey + "." + keyPath)
        }

        private func removeSheetProgressAnimations() {
            var layers: [CALayer] = [self.codePill.layer, self.toastView.layer, self.emojiStripView.layer]
            if let cardView = self.card.view {
                layers.append(cardView.layer)
            }
            for layer in layers {
                for key in layer.animationKeys() ?? [] where key.hasPrefix(QrStudioScreenComponent.View.sheetFollowKey) {
                    layer.removeAnimation(forKey: key)
                }
            }
        }

        private func animateSheetProgress(samples: [QrStudioSheetMotion.Sample], duration: Double) {
            self.removeSheetProgressAnimations()
            let follows = samples.compactMap { self.sheetFollow(sample: $0) }
            guard follows.count == samples.count, follows.count > 1 else {
                self.applySheetProgress()
                return
            }
            self.applySheetProgress(updateButtons: false)
            if let cardView = self.card.view {
                self.addSheetKeyframes(cardView.layer, "position", follows.map { NSValue(cgPoint: $0.cardCenter) }, duration: duration)
                self.addSheetKeyframes(cardView.layer, "transform.scale", follows.map { NSNumber(value: Double($0.cardScale)) }, duration: duration)
            }
            if self.codePillSize.width > 0.0 {
                self.addSheetKeyframes(self.codePill.layer, "position", follows.map { NSValue(cgPoint: $0.pillCenter) }, duration: duration)
            }
            if self.toastView.superview != nil {
                self.addSheetKeyframes(self.toastView.layer, "position", follows.map { NSValue(cgPoint: $0.toastCenter) }, duration: duration)
            }
            if self.emojiStripView.superview != nil {
                self.addSheetKeyframes(self.emojiStripView.layer, "position", follows.map { NSValue(cgPoint: $0.stripCenter) }, duration: duration)
            }
            self.setButtonsOpacity(follows.map { NSNumber(value: Float($0.buttonsAlpha)) }, duration: duration)
        }

        private func link(component: QrStudioScreenComponent) -> String {
            if self.codeState.removeFee && self.paidPrice != nil {
                let token: ExportedNoPaidMessagesToken?
                if component.temporary {
                    token = self.temporaryNoPaidToken
                } else if self.codeState.expires {
                    token = self.temporaryNoPaidToken ?? self.noPaidToken
                } else {
                    token = self.noPaidToken
                }
                if let token, !token.url.isEmpty {
                    return token.url
                }
            }
            if component.temporary {
                return self.contactToken?.url ?? ""
            }
            let peer = component.peer
            var link: String
            if let addressName = peer.addressName, !addressName.isEmpty {
                link = "https://t.me/\(addressName)"
            } else if case let .user(user) = peer {
                link = "https://t.me/+\(user.phone ?? "")"
            } else if case .channel = peer {
                link = "https://t.me/c/\(peer.id.id._internalGetInt64Value())"
            } else {
                link = ""
            }
            if let threadId = component.threadId, !link.isEmpty {
                link += "/\(threadId)"
            }
            return link
        }

        private func requestContactToken(context: AccountContext) {
            self.contactTokenGeneration += 1
            let generation = self.contactTokenGeneration
            self.contactTokenDisposable.set((context.engine.peers.exportContactToken()
            |> deliverOnMainQueue).startStrict(next: { [weak self] token in
                guard let self, self.contactTokenGeneration == generation else {
                    return
                }
                let now = Double(context.account.network.getApproximateRemoteTimestamp())
                let delay: Double
                if let token, !qrStudioTokenIsExpired(expires: Double(token.expires), now: now) {
                    self.contactTokenStaleAttempt = 0
                    if self.contactToken?.url != token.url || self.contactToken?.expires != token.expires {
                        self.contactToken = token
                        self.requestUpdate(transition: .easeInOut(duration: 0.3))
                    }
                    delay = qrStudioTokenRefreshDelay(expires: Double(token.expires), now: now, staleAttempt: 0)
                } else {
                    if self.contactToken == nil, let token {
                        self.contactToken = token
                        self.requestUpdate(transition: .easeInOut(duration: 0.3))
                    }
                    delay = qrStudioTokenRefreshDelay(expires: Double(token?.expires ?? 0), now: now, staleAttempt: self.contactTokenStaleAttempt)
                    self.contactTokenStaleAttempt += 1
                }
                Queue.mainQueue().after(delay, { [weak self] in
                    guard let self, self.contactTokenGeneration == generation, let component = self.component else {
                        return
                    }
                    self.requestContactToken(context: component.context)
                })
            }))
        }

        private func dismiss() {
            self.codeMenuCooldown.cancel()
            self.shareMenuCooldown.cancel()
            self.sheetView.close()
            self.environment?.controller()?.dismiss()
        }

        private func openShareMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller() as? ViewController else {
                return
            }
            let presentationData = self.menuPresentationData(context: component.context)
            let strings = presentationData.strings
            var items: [ContextMenuItem] = []
            func add(_ title: String, _ icon: String, _ action: @escaping () -> Void) {
                items.append(.action(ContextMenuActionItem(text: title, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: icon), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    let delay = self?.shareMenuCooldown.dismissDelay ?? 0.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        f(.default)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: action)
                    }
                })))
            }
            add(strings.QrStudio_Share_CopyLink, "Chat/Context Menu/Link", { [weak self] in
                self?.copyLink()
            })
            add(strings.QrStudio_Share_Share, "Chat/Context Menu/Share", { [weak self] in
                self?.shareImage()
            })
            let contextController = makeContextController(presentationData: presentationData, source: .reference(QrStudioReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items), usesClearGlass: QrStudioGlass.isClear(QrStudioGlass.tint(self.look.backdrop)), glassBlurRadius: QrStudioGlass.blurRadius(QrStudioGlass.tint(self.look.backdrop)))), gesture: nil)
            self.shareMenuCooldown.markOpened()
            contextController.dismissed = { [weak self] in
                self?.shareMenuCooldown.markClosed()
            }
            controller.presentInGlobalOverlay(contextController)
        }

        private func copyLink() {
            guard let component = self.component else {
                return
            }
            let link = self.link(component: component)
            guard !link.isEmpty else {
                return
            }
            UIPasteboard.general.string = link
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            self.showToast(.copy, strings.QrStudio_Toast_LinkCopied)
        }

        private func exportCardImage(scale: CGFloat, staticPlane: Bool) -> (image: CGImage, screenCard: CGRect, planeRect: CGRect)? {
            guard let cardView = self.card.view as? QrStudioCardComponent.View, let result = cardView.exportImage(scale: scale, staticPlane: staticPlane) else {
                return nil
            }
            let size = cardView.bounds.size
            let center = self.cardRestCenter
            return (result.image, CGRect(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5, width: size.width, height: size.height), result.planeRect)
        }

        private func makeExportScene(canvas: QrStudioExportCanvas, completion: @escaping (QrStudioExportScene?) -> Void) -> Disposable {
            guard let component = self.component, !self.link(component: component).isEmpty, let (cardImage, screenCard, _) = self.exportCardImage(scale: canvas.scale * 1.5, staticPlane: true) else {
                completion(nil)
                return EmptyDisposable
            }
            let screenSize = self.bounds.size
            let backdrop = self.look.backdrop
            let isLight = backdrop.isLight
            let ink = self.look.ink.uiColor
            let context = component.context
            switch backdrop {
            case let .color(palette):
                completion(QrStudioExportScene(background: .mesh(palette.colors), card: cardImage, screenSize: screenSize, screenCard: screenCard, isLight: isLight))
                return EmptyDisposable
            case .theme:
                var snapshot: CGImage?
                self.stage.forEachContent { content in
                    if let view = content as? QrStudioThemeBackgroundView {
                        snapshot = view.snapshotImage(scale: canvas.scale)
                    }
                }
                guard let snapshot else {
                    completion(nil)
                    return EmptyDisposable
                }
                completion(QrStudioExportScene(background: .image(snapshot), card: cardImage, screenSize: screenSize, screenCard: screenCard, isLight: isLight))
                return EmptyDisposable
            case let .emoji(items, palette):
                let side = Int(56.0 * canvas.scale)
                let patternItems = QrStudioEmojiPatternView.canonicalExportItems(size: screenSize, fileCount: items.count)
                let signals = items.map { qrStudioDecodeExportSticker(context: context, file: $0.file, pixelSide: side, tint: $0.isTemplate ? ink : nil, firstFrameOnly: true) }
                return (combineLatest(signals)
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { stickers in
                    let loaded = stickers.map { $0 ?? QrStudioExportSticker(frames: [], period: 0.0) }
                    completion(QrStudioExportScene(background: .emoji(colors: palette.colors, stickers: loaded, items: patternItems), card: cardImage, screenSize: screenSize, screenCard: screenCard, isLight: isLight))
                })
            case let .gift(gift):
                let symbol = qrStudioDecodeExportSticker(context: context, file: gift.pattern, pixelSide: Int(28.0 * canvas.scale), tint: gift.patternColor.uiColor.withAlphaComponent(0.42), firstFrameOnly: true)
                let model = qrStudioDecodeExportSticker(context: context, file: gift.model, pixelSide: Int(94.0 * canvas.scale), tint: nil, firstFrameOnly: true)
                let patternItems = QrStudioGiftPatternView.canonicalExportItems(size: screenSize)
                return (combineLatest(symbol, model)
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { symbol, model in
                    completion(QrStudioExportScene(background: .gift(inner: gift.inner, outer: gift.outer, symbol: symbol?.frames.first, model: model, items: patternItems), card: cardImage, screenSize: screenSize, screenCard: screenCard, isLight: isLight))
                })
            }
        }

        private func shareImage() {
            guard let component = self.component else {
                return
            }
            let canvas = QrStudioExportCanvas.screen(size: self.bounds.size, scale: UIScreenScale)
            let _ = self.makeExportScene(canvas: canvas, completion: { [weak self] scene in
                guard let self, let scene else {
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = qrStudioExportImage(scene, canvas: canvas)
                    DispatchQueue.main.async {
                        guard let data = image?.jpegData(compressionQuality: 0.92) else {
                            return
                        }
                        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("qr-code.jpg")
                        try? FileManager.default.removeItem(at: url)
                        guard (try? data.write(to: url)) != nil else {
                            return
                        }
                        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let popover = controller.popoverPresentationController {
                            popover.sourceView = self.shareButtonView
                            popover.sourceRect = self.shareButtonView.bounds
                        }
                        component.context.sharedContext.applicationBindings.presentNativeController(controller)
                    }
                }
            })
        }

        private func saveImage() {
            guard let component = self.component else {
                return
            }
            let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
            let _ = self.makeExportScene(canvas: .story, completion: { [weak self] scene in
                guard let self else {
                    return
                }
                guard let scene else {
                    self.showToast(.image("Chat/Context Menu/Info"), strings.QrStudio_Toast_Failed)
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let image = qrStudioExportImage(scene, canvas: .story)
                    DispatchQueue.main.async {
                        guard let image else {
                            self.showToast(.image("Chat/Context Menu/Info"), strings.QrStudio_Toast_Failed)
                            return
                        }
                        self.saveToPhotos(image: image, completion: { success in
                            UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
                            if success {
                                self.showToast(.save, strings.QrStudio_Toast_ImageSaved)
                            } else {
                                self.showToast(.image("Chat/Context Menu/Info"), strings.QrStudio_Toast_Failed)
                            }
                        })
                    }
                }
            })
        }

        private func saveToPhotos(image: UIImage, completion: @escaping (_ success: Bool) -> Void) {
            guard let component = self.component else {
                completion(false)
                return
            }
            let context = component.context
            DeviceAccess.authorizeAccess(to: .mediaLibrary(.save), presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: { c, a in
                context.sharedContext.presentGlobalController(c, a)
            }, openSettings: context.sharedContext.applicationBindings.openSettings, { authorized in
                guard authorized else {
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { success, _ in
                    DispatchQueue.main.async {
                        completion(success)
                    }
                })
            })
        }

        private func scan() {
            guard let component = self.component, let controller = self.environment?.controller() as? ViewController else {
                return
            }
            controller.push(QrCodeScanScreen(context: component.context, subject: .peer))
        }

        private func updateGlassButton(_ button: QrStudioGlassButtonView, icon: String? = nil, title: String? = nil, isDark: Bool, glassTint: GlassBackgroundView.TintColor, frame: CGRect, transition: ComponentTransition, action: @escaping () -> Void) {
            if button.superview == nil {
                self.presentationContainer.addSubview(button)
                button.action = { _ in
                    action()
                }
            }
            transition.setFrame(view: button, frame: frame)
            button.update(size: frame.size, isDark: isDark, glassTint: glassTint, icon: icon, title: title, transition: transition)
        }

        func update(component: QrStudioScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            self.component = component
            self.state = state
            self.environment = environment
            self.presentationContainer.bounds = CGRect(origin: CGPoint(), size: availableSize)
            if let expansionBackgroundView = self.expansionBackgroundView {
                expansionBackgroundView.backgroundColor = self.look.backdrop.baseColor.uiColor
            } else {
                self.presentationContainer.backgroundColor = self.look.backdrop.baseColor.uiColor
            }
            self.presentationContainer.center = CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5)

            if component.temporary && !self.didRequestContactToken {
                self.didRequestContactToken = true
                self.requestContactToken(context: component.context)
            }

            self.loadLook(context: component.context)
            self.loadShareTheme(component: component)
            self.loadGifts(component: component)
            self.loadPaidPrice(component: component)
            self.syncNoPaidToken(context: component.context)

            let backdrop = self.look.backdrop
            let isDark = !backdrop.isLight
            let glassTint = QrStudioGlass.tint(backdrop)
            let ink = self.look.ink
            var link = self.link(component: component)
            if link.isEmpty && component.temporary {
                link = self.placeholderContactLink
            }

            var username: String?
            if let addressName = component.peer.addressName, !addressName.isEmpty {
                username = addressName
            }

            self.updateStatusBar()

            let linkExpires = username == nil && component.temporary ? self.contactToken.flatMap { token -> Int32 in
                let skew = Int32(Date().timeIntervalSince1970) - component.context.account.network.getApproximateRemoteTimestamp()
                return token.expires + skew
            } : nil
            let reservesTimer = username == nil && component.temporary
            let cardCenterY = QrStudioCardMetrics.cardCenterY(screenHeight: availableSize.height, showsUsername: username != nil || linkExpires != nil || reservesTimer)
            let cardCenter = CGPoint(x: environment.safeInsets.left + (availableSize.width - environment.safeInsets.left - environment.safeInsets.right) * 0.5, y: cardCenterY)
            self.cardRestCenter = cardCenter

            let rowInset: CGFloat = 34.0
            let rowSide: CGFloat = 44.0
            let topRowY: CGFloat
            let bottomInset: CGFloat
            if environment.metrics.widthClass == .regular {
                topRowY = 16.0
                bottomInset = rowInset
            } else if environment.reservedCorners == .none {
                topRowY = max(64.0, environment.statusBarHeight + 8.0)
                bottomInset = rowInset
            } else {
                if environment.navigationBarTrailingButtonsInset > 0.0 {
                    topRowY = environment.statusBarHeight + 31.0 - rowSide * 0.5
                } else {
                    topRowY = max(environment.statusBarHeight, environment.safeInsets.top) + 16.0
                }
                bottomInset = max(topRowY, environment.safeInsets.bottom)
            }
            self.sheetView.frame = CGRect(origin: CGPoint(), size: availableSize)
            self.sheetView.isHidden = !self.canEdit(component)
            self.sheetView.compactHeights[.gift] = self.areGiftsLoaded ? QrStudioGiftsTabView.compactHeight(count: self.look.gifts.count, width: availableSize.width, bottomInset: environment.safeInsets.bottom) : nil
            self.sheetView.update(
                size: availableSize,
                safeBottom: bottomInset,
                bottomCornerRadius: max(24.0, environment.deviceMetrics.screenCornerRadius) - 2.0,
                inputHeight: environment.inputHeight,
                kinds: self.look.availableKinds,
                isDark: !self.look.backdrop.isLight,
                glassTint: QrStudioGlass.tint(self.look.backdrop),
                theme: self.sheetTheme(environment.theme)
            )

            self.stage.frame = CGRect(origin: CGPoint(), size: availableSize)
            if self.isLookLoaded {
                self.stage.update(backdrop: backdrop, size: availableSize, revealCenter: self.cardSize.height > 0.0 ? self.liftedCardCenter() : cardCenter, animated: !transition.animation.isImmediate)
                self.scheduleSaveLook(context: component.context)
                let inkColor = ink.uiColor
                self.stage.forEachContent { content in
                    (content as? QrStudioEmojiPatternView)?.templateTintColor = inkColor
                }
            }

            var fillSource: QrStudioThemeBackgroundView?
            if case let .theme(theme) = backdrop {
                self.stage.forEachContent { content in
                    if let view = content as? QrStudioThemeBackgroundView, view.theme.id == theme.id {
                        fillSource = view
                    }
                }
            }
            let cardSize = self.card.update(
                transition: transition,
                component: AnyComponent(QrStudioCardComponent(
                    link: link,
                    username: username,
                    expires: linkExpires,
                    reservesTimer: reservesTimer,
                    animatesLinkChange: self.didStartAnimateIn,
                    ink: ink,
                    isLight: backdrop.isLight,
                    bounceToken: backdrop.cardSignature + link,
                    fillSource: fillSource
                )),
                environment: {},
                containerSize: availableSize
            )
            if let cardView = self.card.view {
                if cardView.superview == nil {
                    self.presentationContainer.addSubview(cardView)
                    let recognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handleCardDismissPan(_:)))
                    recognizer.delegate = self
                    cardView.addGestureRecognizer(recognizer)
                    self.cardDismissRecognizer = recognizer
                    cardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleStageTap(_:))))
                }
                cardView.bounds = CGRect(origin: CGPoint(), size: cardSize)
            }
            self.cardSize = cardSize

            let buttonSide = rowSide
            let closeTop = topRowY
            let closeFrame: CGRect
            if let sideColumnFrame = environment.sideColumnNavigationButtonFrame {
                closeFrame = CGRect(x: sideColumnFrame.midX - buttonSide * 0.5, y: sideColumnFrame.midY - buttonSide * 0.5, width: buttonSide, height: buttonSide)
            } else {
                closeFrame = CGRect(x: 16.5 + environment.safeInsets.left, y: closeTop, width: buttonSide, height: buttonSide)
            }
            self.updateGlassButton(
                self.closeButton,
                icon: "Navigation/Close",
                isDark: isDark,
                glassTint: glassTint,
                frame: closeFrame,
                transition: transition,
                action: { [weak self] in
                    self?.dismiss()
                }
            )

            let scanTitle = environment.strings.PeerInfo_QRCode_Scan
            let scanWidth = QrStudioGlassButtonView.width(title: scanTitle, height: buttonSide)
            self.updateGlassButton(
                self.scanButton,
                title: scanTitle,
                isDark: isDark,
                glassTint: glassTint,
                frame: CGRect(x: availableSize.width - 16.5 - environment.safeInsets.right - environment.navigationBarTrailingButtonsInset - scanWidth, y: closeTop, width: scanWidth, height: buttonSide),
                transition: transition,
                action: { [weak self] in
                    self?.scan()
                }
            )

            let bottomRowY = availableSize.height - bottomInset - buttonSide
            let sideInset = rowInset
            let bottomSideInsets = environment.bottomEdgeSideInsets()
            if self.shareButtonView.superview == nil {
                self.presentationContainer.addSubview(self.shareButtonView)
                self.shareButtonView.action = { [weak self] sourceView in
                    self?.shareMenuCooldown.perform { [weak self, weak sourceView] in
                        if let self, let sourceView {
                            self.openShareMenu(sourceView: sourceView)
                        }
                    }
                }
            }
            transition.setFrame(view: self.shareButtonView, frame: CGRect(x: sideInset + bottomSideInsets.left, y: bottomRowY, width: buttonSide, height: buttonSide))
            self.shareButtonView.update(size: CGSize(width: buttonSide, height: buttonSide), isDark: isDark, glassTint: glassTint, icon: "Navigation/Share", transition: transition)
            self.updateGlassButton(
                self.saveButton,
                icon: "sf:arrow.down.to.line",
                isDark: isDark,
                glassTint: glassTint,
                frame: CGRect(x: availableSize.width - sideInset - bottomSideInsets.right - buttonSide, y: bottomRowY, width: buttonSide, height: buttonSide),
                transition: transition,
                action: { [weak self] in
                    self?.saveImage()
                }
            )

            if self.sheetView.superview == nil {
                self.presentationContainer.addSubview(self.sheetView)
            }
            if self.isLookLoaded {
                self.updateTabs(component: component, environment: environment)
            }
            if self.canEdit(component) {
                self.updateEmojiStrip(component: component, environment: environment, transition: transition)
            }
            if let price = self.paidPrice {
                let isAppearing = self.codePill.superview == nil
                let pillTransition: ComponentTransition = (isAppearing && (self.isAnimatingIn || self.presentationOffset != 0.0)) ? .immediate : transition
                let codePillSize = self.codePill.update(
                    state: self.codeState,
                    price: price,
                    ink: ink,
                    isLight: backdrop.isLight,
                    glassTint: glassTint,
                    texts: QrStudioCodePillView.Texts(
                        free: environment.strings.QrStudio_Pill_Free,
                        removeFee: qrStudioRemoveFeeParts(environment.strings),
                        permanent: environment.strings.QrStudio_Pill_Permanent,
                        expiresIn: { [strings = environment.strings] value in
                            return strings.QrStudio_Pill_ExpiresIn(value).string
                        }
                    ),
                    transition: isAppearing ? .immediate : transition
                )
                if isAppearing {
                    self.presentationContainer.insertSubview(self.codePill, belowSubview: self.sheetView)
                    self.codePill.alpha = pillTransition.animation.isImmediate ? 1.0 : 0.0
                }
                pillTransition.setAlpha(view: self.codePill, alpha: 1.0)
                if self.codePillSize != codePillSize {
                    let previousWidth = self.codePillSize.width
                    self.codePillSize = codePillSize
                    let pillBounds = CGRect(origin: CGPoint(), size: codePillSize)
                    if previousWidth == 0.0 || pillTransition.animation.isImmediate {
                        self.codePill.bounds = pillBounds
                    } else {
                        UIView.animate(withDuration: QrStudioCodePillView.resizeDuration, delay: 0.0, usingSpringWithDamping: QrStudioCodePillView.resizeDamping, initialSpringVelocity: 0.0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                            self.codePill.bounds = pillBounds
                        })
                    }
                }
            } else if self.codePill.superview != nil {
                transition.setAlpha(view: self.codePill, alpha: 0.0)
            }
            self.presentationContainer.bringSubviewToFront(self.closeButton)
            self.presentationContainer.bringSubviewToFront(self.scanButton)
            self.applySheetProgress()
            self.layoutToast()

            self.updateDisplayLink()

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func qrStudioGift(_ gift: StarGift.UniqueGift, reference: StarGiftReference?) -> QrStudioGift? {
    var model: TelegramMediaFile?
    var pattern: TelegramMediaFile?
    var colors: (QrStudioColor, QrStudioColor, QrStudioColor, QrStudioColor)?
    for attribute in gift.attributes {
        switch attribute {
        case let .model(_, file, _, _):
            model = file
        case let .pattern(_, file, _):
            pattern = file
        case let .backdrop(_, _, innerColor, outerColor, patternColor, textColor, _):
            func color(_ value: Int32) -> QrStudioColor {
                return QrStudioColor(rgb: UInt32(bitPattern: value) & 0xffffff)
            }
            colors = (color(innerColor), color(outerColor), color(patternColor), color(textColor))
        default:
            break
        }
    }
    guard let model, let pattern, let colors else {
        return nil
    }
    return QrStudioGift(id: gift.id, gift: gift, reference: reference, model: model, pattern: pattern, inner: colors.0, outer: colors.1, patternColor: colors.2, text: colors.3)
}

private func qrStudioProfilePalettes(_ colors: PeerNameColors) -> [QrStudioPalette] {
    let ids = colors.profileDisplayOrder.isEmpty ? colors.profileColors.keys.sorted() : colors.profileDisplayOrder
    return ids.compactMap { id -> QrStudioPalette? in
        guard let value = colors.profileColors[id] else {
            return nil
        }
        return QrStudioPalette.profile(id: id, center: value.main.rgb, edge: (value.secondary ?? value.main).rgb)
    }
}

private func qrStudioRemoveFeeParts(_ strings: PresentationStrings) -> (prefix: String, suffix: String) {
    let formatted = strings.QrStudio_Pill_RemoveFee("")
    let string = formatted.string as NSString
    guard let range = formatted.ranges.first(where: { $0.index == 0 })?.range else {
        return (formatted.string, "")
    }
    let prefix = string.substring(to: range.location).trimmingCharacters(in: .whitespaces)
    let suffix = string.substring(from: range.location + range.length).trimmingCharacters(in: .whitespaces)
    return (prefix, suffix)
}

private final class QrStudioMenuCooldown {
    static var interval: Double {
        if #available(iOS 27.0, *) {
            return 1.0
        } else if #available(iOS 26.0, *) {
            return 1.2
        } else {
            return 0.0
        }
    }

    private var openedAt: Double = 0.0
    private var closedAt: Double = 0.0
    private var pending: DispatchWorkItem?

    var dismissDelay: Double {
        return max(0.0, QrStudioMenuCooldown.interval - (CACurrentMediaTime() - self.openedAt))
    }

    func markOpened() {
        self.openedAt = CACurrentMediaTime()
    }

    func markClosed() {
        self.closedAt = CACurrentMediaTime()
    }

    func perform(_ action: @escaping () -> Void) {
        let remaining = QrStudioMenuCooldown.interval - (CACurrentMediaTime() - self.closedAt)
        guard remaining > 0.0 else {
            action()
            return
        }
        guard self.pending == nil else {
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.pending = nil
            action()
        }
        self.pending = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
    }

    func cancel() {
        self.pending?.cancel()
        self.pending = nil
    }
}

public final class QrStudioScreen: ViewControllerComponentContainer, ChatQrCodeScreen {
    public init(context: AccountContext, peer: EnginePeer, threadId: Int64?, temporary: Bool) {
        super.init(
            context: context,
            component: QrStudioScreenComponent(context: context, peer: peer, threadId: threadId, temporary: temporary),
            navigationBarAppearance: .none,
            theme: .default
        )
        self.statusBar.statusBarStyle = .White
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }

    required public init(coder: NSCoder) {
        preconditionFailure()
    }

    private var didAnimateIn = false
    private var isAnimatingOut = false
    fileprivate private(set) var opensByExpansion = false
    fileprivate private(set) var opensAsModal = false

    private var skipsOwnPresentation: Bool {
        return self.opensByExpansion || self.opensAsModal
    }

    private let hapticFeedback = HapticFeedback()

    public func prepareForNavigationExpansion(layout: ContainerViewLayout?, ready: @escaping () -> Void) {
        self.hapticFeedback.impact(.light, intensity: 0.7)
        self.hapticFeedback.prepareImpact(.light)
        if let layout, layout.deviceMetrics.type == .tablet {
            self.opensAsModal = true
            self.navigationPresentation = .modal
        } else {
            self.opensByExpansion = true
            self.navigationPresentation = .default
        }
        guard let layout else {
            ready()
            return
        }
        let _ = self.view
        self.containerLayoutUpdated(layout, transition: ContainedViewLayoutTransition.immediate)
        guard let view = self.studioView else {
            ready()
            return
        }
        view.whenReadyForExpansion(ready)
    }

    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        guard self.opensAsModal, layout.metrics.widthClass == .regular else {
            return nil
        }
        return CGSize(
            width: min(480.0, layout.size.width - 20.0),
            height: min(800.0, min(layout.size.width, layout.size.height) - 88.0)
        )
    }

    override public func navigationExpansionDestination(below controller: ViewController, operation: NavigationExpansionOperation) -> NavigationExpansionDestination? {
        guard self.opensByExpansion, let view = self.studioView else {
            return nil
        }
        if case .push = operation {
            view.beginExpansionAppearance()
        }
        return QrStudioExpansionDestination(view: view, isOpening: operation == .push, landed: { [weak self] in
            self?.hapticFeedback.impact(.light, intensity: 0.7)
        })
    }

    private func underlyingStatusBarStyle() -> Display.StatusBarStyle? {
        guard let navigationController = self.navigationController as? NavigationController, let index = navigationController.viewControllers.firstIndex(where: { $0 === self }), index > 0, let previous = navigationController.viewControllers[index - 1] as? ViewController else {
            return nil
        }
        var style = previous.statusBar.statusBarStyle
        if let tabBarController = previous as? TabBarController, let current = tabBarController.currentController {
            style = current.statusBar.statusBarStyle
        }
        return style == .Ignore ? nil : style
    }

    fileprivate func restoreUnderlyingStatusBar() {
        if let style = self.underlyingStatusBarStyle() {
            self.statusBar.updateStatusBarStyle(style, animated: true)
        }
    }

    private var studioView: QrStudioScreenComponent.View? {
        return self.node.hostView.componentView as? QrStudioScreenComponent.View
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !self.didAnimateIn, !self.skipsOwnPresentation, let style = self.underlyingStatusBarStyle() {
            self.statusBar.statusBarStyle = style
        }

        self.studioView?.updateVisibility(true)
        if !self.didAnimateIn {
            if self.skipsOwnPresentation {
                self.studioView?.beginExpansionAppearance()
            } else {
                self.studioView?.prepareAnimateIn()
            }
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !self.didAnimateIn {
            self.didAnimateIn = true
            if self.skipsOwnPresentation {
                self.studioView?.beginExpansionAppearance()
            } else {
                self.studioView?.animateIn()
            }
        }
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        guard !self.isAnimatingOut, let view = self.studioView else {
            super.dismiss(completion: completion)
            return
        }
        self.isAnimatingOut = true
        if self.skipsOwnPresentation {
            view.prepareExpansionDismiss()
            super.dismiss(completion: completion)
            return
        }
        view.animateOut(velocity: nil, completion: { [weak self] in
            self?.dismissImmediately(completion: completion)
        })
    }

    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if flag {
            self.dismiss(completion: completion)
        } else {
            self.isAnimatingOut = true
            self.dismissImmediately(completion: completion)
        }
    }

    private func dismissImmediately(completion: (() -> Void)?) {
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.filterController(self, animated: false)
            completion?()
        } else {
            super.dismiss(animated: false, completion: completion)
        }
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        (self.node.hostView.componentView as? QrStudioScreenComponent.View)?.updateVisibility(false)
    }
}

private final class QrStudioReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    private let centersActions: Bool

    let forceDisplayBelowKeyboard = true

    init(controller: ViewController, sourceView: UIView, centersActions: Bool = false) {
        self.controller = controller
        self.sourceView = sourceView
        self.centersActions = centersActions
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds, centersMorphedActions: self.centersActions)
    }
}
