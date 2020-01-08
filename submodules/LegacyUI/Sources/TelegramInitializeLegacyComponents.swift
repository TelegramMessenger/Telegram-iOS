import Foundation
import UIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
#if BUCK
import MtProtoKit
#else
import MtProtoKitDynamic
#endif
import Display
import TelegramPresentationData
import DeviceAccess
import TelegramAudio
import LegacyComponents
import AccountContext

var legacyComponentsApplication: UIApplication?

private var legacyLocalization = TGLocalization(version: 0, code: "en", dict: [:], isActive: true)

public func updateLegacyLocalization(strings: PresentationStrings) {
    legacyLocalization = TGLocalization(version: 0, code: strings.primaryComponent.languageCode, dict: strings.primaryComponent.dict, isActive: true)
}

public func updateLegacyTheme() {
    TGCheckButtonView.resetCache()
}

private var legacyDocumentsStorePath: String?
private var legacyCanOpenUrl: (URL) -> Bool = { _ in return false }
private var legacyOpenUrl: (URL) -> Void = { _ in }
private weak var legacyContext: AccountContext?

func legacyContextGet() -> AccountContext? {
    return legacyContext
}

private final class LegacyComponentsAccessCheckerImpl: NSObject, LegacyComponentsAccessChecker {
    private weak var context: AccountContext?
    
    init(context: AccountContext?) {
        self.context = context
    }
    
    public func checkAddressBookAuthorizationStatus(alertDismissComlpetion alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkPhotoAuthorizationStatus(for intent: TGPhotoAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        if let context = self.context {
            DeviceAccess.authorizeAccess(to: .mediaLibrary(.send), presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: context.sharedContext.presentGlobalController, openSettings: context.sharedContext.applicationBindings.openSettings, { value in
                if !value {
                    alertDismissCompletion?()
                }
            })
        }
        return true
    }
    
    public func checkMicrophoneAuthorizationStatus(for intent: TGMicrophoneAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkCameraAuthorizationStatus(for intent: TGCameraAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkLocationAuthorizationStatus(for intent: TGLocationAccessIntent, alertDismissComlpetion alertDismissCompletion: (() -> Void)!) -> Bool {
        let subject: DeviceAccessLocationSubject
        if intent == TGLocationAccessIntentSend {
            subject = .send
        } else if intent == TGLocationAccessIntentLiveLocation {
            subject = .live
        } else if intent == TGLocationAccessIntentTracking {
            subject = .tracking
        } else {
            assertionFailure()
            subject = .send
        }
        if let context = self.context {
            DeviceAccess.authorizeAccess(to: .location(subject), presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: context.sharedContext.presentGlobalController, openSettings: context.sharedContext.applicationBindings.openSettings, { value in
                if !value {
                    alertDismissCompletion?()
                }
            })
        }
        return true
    }
}

private func encodeText(_ string: String, _ key: Int) -> String {
    var result = ""
    for c in string.unicodeScalars {
        result.append(Character(UnicodeScalar(UInt32(Int(c.value) + key))!))
    }
    return result
}

private let keyboardWindowClass: AnyClass? = {
    if #available(iOS 9.0, *) {
        return NSClassFromString(encodeText("VJSfnpufLfzcpbseXjoepx", -1))
    } else {
        return NSClassFromString(encodeText("VJUfyuFggfdutXjoepx", -1))
    }
}()

private final class LegacyComponentsGlobalsProviderImpl: NSObject, LegacyComponentsGlobalsProvider {
    func log(_ string: String!) {
        print(string)
    }

    public func effectiveLocalization() -> TGLocalization! {
        return legacyLocalization
    }
    
    public func applicationWindows() -> [UIWindow]! {
        return legacyComponentsApplication?.windows ?? []
    }
    
    public func applicationStatusBarWindow() -> UIWindow! {
        return nil
    }
    
    public func applicationKeyboardWindow() -> UIWindow! {
        guard let keyboardWindowClass = keyboardWindowClass else {
            return nil
        }
        
        for window in legacyComponentsApplication?.windows ?? [] {
            if window.isKind(of: keyboardWindowClass) {
                return window
            }
        }
        return nil
    }
    
    public func applicationInstance() -> UIApplication! {
        return legacyComponentsApplication
    }
    
    public func applicationStatusBarOrientation() -> UIInterfaceOrientation {
        return legacyComponentsApplication?.statusBarOrientation ?? UIInterfaceOrientation.portrait
    }
    
    public func statusBarFrame() -> CGRect {
        return legacyComponentsApplication?.statusBarFrame ?? CGRect(origin: CGPoint(), size: CGSize(width: 320.0, height: 20.0))
    }
    
    public func isStatusBarHidden() -> Bool {
        return false
    }
    
    public func setStatusBarHidden(_ hidden: Bool, with animation: UIStatusBarAnimation) {
    }
    
    public func statusBarStyle() -> UIStatusBarStyle {
        return .default
    }
    
    public func setStatusBarStyle(_ statusBarStyle: UIStatusBarStyle, animated: Bool) {
        
    }
    
    public func forceStatusBarAppearanceUpdate() {
        
    }
    
    public func canOpen(_ url: URL!) -> Bool {
        return legacyCanOpenUrl(url)
    }
    
    public func open(_ url: URL!) {
        legacyOpenUrl(url)
    }
    
    public func openURLNative(_ url: URL!) {
        legacyOpenUrl(url)
    }
    
    public func disableUserInteraction(for timeInterval: TimeInterval) {
    }
    
    public func setIdleTimerDisabled(_ value: Bool) {
        legacyComponentsApplication?.isIdleTimerDisabled = value
    }
    
    public func pauseMusicPlayback() {
    }
    
    public func dataStoragePath() -> String! {
        return legacyDocumentsStorePath!
    }
    
    public func dataCachePath() -> String! {
        return legacyDocumentsStorePath! + "/Cache"
    }
    
    public func accessChecker() -> LegacyComponentsAccessChecker! {
        return LegacyComponentsAccessCheckerImpl(context: legacyContext)
    }
    
    public func stickerPacksSignal() -> SSignal! {
        if let legacyContext = legacyContext {
            return legacyComponentsStickers(postbox: legacyContext.account.postbox, namespace: Namespaces.ItemCollection.CloudStickerPacks)
        } else {
            var dict: [AnyHashable: Any] = [:]
            dict["packs"] = NSArray()
            return SSignal.single(dict)
        }
    }
    
    public func maskStickerPacksSignal() -> SSignal! {
        if let legacyContext = legacyContext {
            return legacyComponentsStickers(postbox: legacyContext.account.postbox, namespace: Namespaces.ItemCollection.CloudMaskPacks)
        } else {
            var dict: [AnyHashable: Any] = [:]
            dict["packs"] = NSArray()
            return SSignal.single(dict)
        }
    }
    
    public func recentStickerMasksSignal() -> SSignal! {
        return SSignal.single(NSArray())
    }
    
    public func request(_ type: TGAudioSessionType, interrupted: (() -> Void)!) -> SDisposable! {
        if let legacyContext = legacyContext {
            let convertedType: ManagedAudioSessionType
            switch type {
                case TGAudioSessionTypePlayAndRecord, TGAudioSessionTypePlayAndRecordHeadphones:
                    convertedType = .record(speaker: false)
                default:
                    convertedType = .play
            }
            let disposable = legacyContext.sharedContext.mediaManager.audioSession.push(audioSessionType: convertedType, once: true, activate: { _ in
            }, deactivate: {
                interrupted?()
                return .complete()
            })
            
            return SBlockDisposable(block: {
                disposable.dispose()
            })
        }
        return nil
    }
    
    public func sharedMediaImageProcessingThreadPool() -> SThreadPool! {
        return nil
    }
    
    public func sharedMediaMemoryImageCache() -> TGMemoryImageCache! {
        return nil
    }
    
    public func squarePhotoThumbnail(_ imageAttachment: TGImageMediaAttachment!, of size: CGSize, threadPool: SThreadPool!, memoryCache: TGMemoryImageCache!, pixelProcessingBlock: ((UnsafeMutableRawPointer?, Int32, Int32, Int32) -> Void)!, downloadLargeImage: Bool, placeholder: SSignal!) -> SSignal! {
        return SSignal.never()
    }
    
    public func localDocumentDirectory(forLocalDocumentId localDocumentId: Int64, version: Int32) -> String! {
        return ""
    }
    
    public func localDocumentDirectory(forDocumentId documentId: Int64, version: Int32) -> String! {
        return ""
    }
    
    public func json(forHttpLocation httpLocation: String!) -> SSignal! {
        return self.data(forHttpLocation: httpLocation).map(toSignal: { next in
            if let next = next as? Data {
                if let object = try? JSONSerialization.jsonObject(with: next, options: []) {
                    return SSignal.single(object)
                }
            }
            return SSignal.fail(nil)
        })
    }
    
    public func data(forHttpLocation httpLocation: String!) -> SSignal! {
        return SSignal { subscriber in
            if let httpLocation = httpLocation, let url = URL(string: httpLocation) {
                let disposable = MTHttpRequestOperation.data(forHttpUrl: url).start(next: { next in
                    subscriber?.putNext(next)
                }, error: { error in
                    subscriber?.putError(error)
                }, completed: {
                    subscriber?.putCompletion()
                })
                return SBlockDisposable(block: {
                    disposable?.dispose()
                })
            } else {
                return nil
            }
        }
    }
    
    public func makeHTTPRequestOperation(with request: URLRequest!) -> (Operation & LegacyHTTPRequestOperation)! {
        return LegacyHTTPOperationImpl(request: request)
    }
    
    public func pausePictureInPicturePlayback() {
        
    }
    
    public func resumePictureInPicturePlayback() {
        
    }
    
    public func maybeReleaseVolumeOverlay() {
        
    }
    
    func navigationBarPallete() -> TGNavigationBarPallete! {
        let theme: PresentationTheme
        if let legacyContext = legacyContext {
            let presentationData = legacyContext.sharedContext.currentPresentationData.with { $0 }
            theme = presentationData.theme
        } else {
            theme = defaultPresentationTheme
        }
        let barTheme = theme.rootController.navigationBar
        return TGNavigationBarPallete(backgroundColor: barTheme.backgroundColor, separatorColor: barTheme.separatorColor, titleColor: barTheme.primaryTextColor, tintColor: barTheme.accentTextColor)
    }
    
    func menuSheetPallete() -> TGMenuSheetPallete! {
        let theme: PresentationTheme
        if let legacyContext = legacyContext {
            let presentationData = legacyContext.sharedContext.currentPresentationData.with { $0 }
            theme = presentationData.theme
        } else {
            theme = defaultPresentationTheme
        }
        let sheetTheme = theme.actionSheet
        
        return TGMenuSheetPallete(dark: theme.overallDarkAppearance, backgroundColor: sheetTheme.opaqueItemBackgroundColor, selectionColor: sheetTheme.opaqueItemHighlightedBackgroundColor, separatorColor: sheetTheme.opaqueItemSeparatorColor, accentColor: sheetTheme.controlAccentColor, destructiveColor: sheetTheme.destructiveActionTextColor, textColor: sheetTheme.primaryTextColor, secondaryTextColor: sheetTheme.secondaryTextColor, spinnerColor: sheetTheme.secondaryTextColor, badgeTextColor: sheetTheme.controlAccentColor, badgeImage: nil, cornersImage: generateStretchableFilledCircleImage(diameter: 11.0, color: nil, strokeColor: nil, strokeWidth: nil, backgroundColor: sheetTheme.opaqueItemBackgroundColor))
    }
    
    func mediaAssetsPallete() -> TGMediaAssetsPallete! {
        let presentationTheme: PresentationTheme
        if let legacyContext = legacyContext {
            let presentationData = legacyContext.sharedContext.currentPresentationData.with { $0 }
            presentationTheme = presentationData.theme
        } else {
            presentationTheme = defaultPresentationTheme
        }
        
        let theme = presentationTheme.list
        let navigationBar = presentationTheme.rootController.navigationBar
        let tabBar = presentationTheme.rootController.tabBar
        
        return TGMediaAssetsPallete(dark: presentationTheme.overallDarkAppearance, backgroundColor: theme.plainBackgroundColor, selectionColor: theme.itemHighlightedBackgroundColor, separatorColor: theme.itemPlainSeparatorColor, textColor: theme.itemPrimaryTextColor, secondaryTextColor: theme.controlSecondaryColor, accentColor: theme.itemAccentColor, barBackgroundColor: tabBar.backgroundColor, barSeparatorColor: tabBar.separatorColor, navigationTitleColor: navigationBar.primaryTextColor, badge: generateStretchableFilledCircleImage(diameter: 22.0, color: navigationBar.accentTextColor), badgeTextColor: navigationBar.backgroundColor, sendIconImage: PresentationResourcesChat.chatInputPanelSendButtonImage(presentationTheme), maybeAccentColor: navigationBar.accentTextColor)
    }
    
    func checkButtonPallete() -> TGCheckButtonPallete! {
        let presentationTheme: PresentationTheme
        if let legacyContext = legacyContext {
            let presentationData = legacyContext.sharedContext.currentPresentationData.with { $0 }
            presentationTheme = presentationData.theme
        } else {
            presentationTheme = defaultPresentationTheme
        }
        
        let theme = presentationTheme
        return TGCheckButtonPallete(defaultBackgroundColor: theme.chat.message.selectionControlColors.fillColor, accentBackgroundColor: theme.chat.message.selectionControlColors.fillColor, defaultBorderColor: theme.chat.message.selectionControlColors.strokeColor, mediaBorderColor: theme.chat.message.selectionControlColors.strokeColor, chatBorderColor: theme.chat.message.selectionControlColors.strokeColor, check: theme.chat.message.selectionControlColors.foregroundColor, blueColor: theme.chat.message.selectionControlColors.fillColor, barBackgroundColor: theme.chat.message.selectionControlColors.fillColor)
    }
}

public func setupLegacyComponents(context: AccountContext) {
    legacyContext = context
}

public func initializeLegacyComponents(application: UIApplication?, currentSizeClassGetter: @escaping () -> UIUserInterfaceSizeClass, currentHorizontalClassGetter: @escaping () -> UIUserInterfaceSizeClass, documentsPath: String, currentApplicationBounds: @escaping () -> CGRect, canOpenUrl: @escaping (URL) -> Bool, openUrl: @escaping (URL) -> Void) {
    legacyComponentsApplication = application
    legacyCanOpenUrl = canOpenUrl
    legacyOpenUrl = openUrl
    legacyDocumentsStorePath = documentsPath
    
    freedomInit()
    
    TGRemoteImageView.setSharedCache(TGCache())
    
    TGImageDataSource.register(LegacyStickerImageDataSource(account: {
        return legacyContext?.account
    }))
    TGImageDataSource.register(LegacyPeerAvatarPlaceholderDataSource(account: {
        return legacyContext?.account
    }))
    TGImageDataSource.register(LegacyLocationVenueIconDataSource(account: {
        return legacyContext?.account
    }))
    ASActor.registerClass(LegacyImageDownloadActor.self)
    LegacyComponentsGlobals.setProvider(LegacyComponentsGlobalsProviderImpl())
}
