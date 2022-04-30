import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import MtProtoKit
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
    
    public func checkCameraAuthorizationStatus(for intent: TGCameraAccessIntent, completion: ((Bool) -> Void)!, alertDismissCompletion: (() -> Void)!) -> Bool {
        if let context = self.context {
            DeviceAccess.authorizeAccess(to: .camera(.video), presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: context.sharedContext.presentGlobalController, openSettings: context.sharedContext.applicationBindings.openSettings, { value in
                completion(value)
                if !value {
                    alertDismissCompletion?()
                }
            })
        }
        return true
    }
}

private func isKeyboardWindow(window: NSObject) -> Bool {
    let typeName = NSStringFromClass(type(of: window))
    if #available(iOS 9.0, *) {
        if typeName.hasPrefix("UI") && typeName.hasSuffix("RemoteKeyboardWindow") {
            return true
        }
    } else {
        if typeName.hasPrefix("UI") && typeName.hasSuffix("TextEffectsWindow") {
            return true
        }
    }
    return false
}

private final class LegacyComponentsGlobalsProviderImpl: NSObject, LegacyComponentsGlobalsProvider {
    func log(_ string: String!) {
        if let string = string {
            print("\(string)")
        }
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
        for window in legacyComponentsApplication?.windows ?? [] {
            if isKeyboardWindow(window: window) {
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
    
    public func makeViewDisableInteractiveKeyboardGestureRecognizer(_ view: UIView!) {
        view.disablesInteractiveKeyboardGestureRecognizer = true
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
    
    public func request(_ type: TGAudioSessionType, activated: (() -> Void)!, interrupted: (() -> Void)!) -> SDisposable! {
        if let legacyContext = legacyContext {
            let convertedType: ManagedAudioSessionType
            switch type {
                case TGAudioSessionTypePlayAndRecord, TGAudioSessionTypePlayAndRecordHeadphones:
                    convertedType = .record(speaker: false)
                default:
                    convertedType = .play
            }
            let disposable = legacyContext.sharedContext.mediaManager.audioSession.push(audioSessionType: convertedType, once: true, activate: { _ in
                activated?()
            }, deactivate: { _ in
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
        return TGNavigationBarPallete(backgroundColor: barTheme.opaqueBackgroundColor, separatorColor: barTheme.separatorColor, titleColor: barTheme.primaryTextColor, tintColor: barTheme.accentTextColor)
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
    
    func darkMenuSheetPallete() -> TGMenuSheetPallete! {
        let theme: PresentationTheme
        if let legacyContext = legacyContext {
            let presentationData = legacyContext.sharedContext.currentPresentationData.with { $0 }
            if presentationData.theme.overallDarkAppearance {
                theme = presentationData.theme
            } else {
                theme = defaultDarkColorPresentationTheme
            }
        } else {
            theme = defaultDarkColorPresentationTheme
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
        
        return TGMediaAssetsPallete(dark: presentationTheme.overallDarkAppearance, backgroundColor: theme.plainBackgroundColor, selectionColor: theme.itemHighlightedBackgroundColor, separatorColor: theme.itemPlainSeparatorColor, textColor: theme.itemPrimaryTextColor, secondaryTextColor: theme.controlSecondaryColor, accentColor: theme.itemAccentColor, destructiveColor: theme.itemDestructiveColor, barBackgroundColor: navigationBar.opaqueBackgroundColor, barSeparatorColor: tabBar.separatorColor, navigationTitleColor: navigationBar.primaryTextColor, badge: generateStretchableFilledCircleImage(diameter: 22.0, color: navigationBar.accentTextColor), badgeTextColor: navigationBar.opaqueBackgroundColor, sendIconImage: PresentationResourcesChat.chatInputPanelSendButtonImage(presentationTheme), doneIconImage: PresentationResourcesChat.chatInputPanelApplyButtonImage(presentationTheme), maybeAccentColor: navigationBar.accentTextColor)
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
    
    LegacyComponentsGlobals.setProvider(LegacyComponentsGlobalsProviderImpl())
}
