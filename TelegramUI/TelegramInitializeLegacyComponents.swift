import Foundation
import LegacyComponents
import UIKit
import TelegramCore
import SwiftSignalKit
import MtProtoKitDynamic

var legacyComponentsApplication: UIApplication!

private let legacyLocalization = TGLocalization(version: 0, code: "en", dict: [:], isActive: true)
private var legacyDocumentsStorePath: String?
private var legacyCanOpenUrl: (URL) -> Bool = { _ in return false }
private var legacyOpenUrl: (URL) -> Void = { _ in }
private weak var legacyAccount: Account?

func legacyAccountGet() -> Account? {
    return legacyAccount
}

private final class LegacyComponentsAccessCheckerImpl: NSObject, LegacyComponentsAccessChecker {
    public func checkAddressBookAuthorizationStatus(alertDismissComlpetion alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkPhotoAuthorizationStatus(for intent: TGPhotoAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkMicrophoneAuthorizationStatus(for intent: TGMicrophoneAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkCameraAuthorizationStatus(for intent: TGCameraAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkLocationAuthorizationStatus(for intent: TGLocationAccessIntent, alertDismissComlpetion alertDismissCompletion: (() -> Void)!) -> Bool {
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
        return legacyComponentsApplication.windows
    }
    
    public func applicationStatusBarWindow() -> UIWindow! {
        return nil
    }
    
    public func applicationKeyboardWindow() -> UIWindow! {
        guard let keyboardWindowClass = keyboardWindowClass else {
            return nil
        }
        
        for window in legacyComponentsApplication.windows {
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
        return legacyComponentsApplication.statusBarOrientation
    }
    
    public func statusBarFrame() -> CGRect {
        return legacyComponentsApplication.statusBarFrame
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
        legacyComponentsApplication.isIdleTimerDisabled = value
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
        return LegacyComponentsAccessCheckerImpl()
    }
    
    public func stickerPacksSignal() -> SSignal! {
        if let legacyAccount = legacyAccount {
            return legacyComponentsStickers(postbox: legacyAccount.postbox, namespace: Namespaces.ItemCollection.CloudStickerPacks)
        } else {
            var dict: [AnyHashable: Any] = [:]
            dict["packs"] = NSArray()
            return SSignal.single(dict)
        }
    }
    
    public func maskStickerPacksSignal() -> SSignal! {
        if let legacyAccount = legacyAccount {
            return legacyComponentsStickers(postbox: legacyAccount.postbox, namespace: Namespaces.ItemCollection.CloudMaskPacks)
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
        return nil
    }
    
    public func currentWallpaperInfo() -> TGWallpaperInfo! {
        return nil
    }
    
    public func currentWallpaperImage() -> UIImage! {
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
    
    public func makeHTTPRequestOperation(with request: URLRequest!) -> Operation! {
        return nil
    }
    
    public func pausePictureInPicturePlayback() {
        
    }
    
    public func resumePictureInPicturePlayback() {
        
    }
    
    public func maybeReleaseVolumeOverlay() {
        
    }
}

public func setupLegacyComponents(account: Account) {
    legacyAccount = account
}

public func initializeLegacyComponents(application: UIApplication, currentSizeClassGetter: @escaping () -> UIUserInterfaceSizeClass, currentHorizontalClassGetter: @escaping () -> UIUserInterfaceSizeClass, documentsPath: String, currentApplicationBounds: @escaping () -> CGRect, canOpenUrl: @escaping (URL) -> Bool, openUrl: @escaping (URL) -> Void) {
    legacyComponentsApplication = application
    legacyCanOpenUrl = canOpenUrl
    legacyOpenUrl = openUrl
    legacyDocumentsStorePath = documentsPath
    
    freedomInit()
    
    TGRemoteImageView.setSharedCache(TGCache())
    
    TGImageDataSource.register(LegacyStickerImageDataSource(account: {
        return legacyAccount
    }))
    TGImageDataSource.register(LegacyPeerAvatarPlaceholderDataSource(account: {
        return legacyAccount
    }))
    TGImageDataSource.register(LegacyLocationVenueIconDataSource(account: {
        return legacyAccount
    }))
    ASActor.registerClass(LegacyImageDownloadActor.self)
    
    LegacyComponentsGlobals.setProvider(LegacyComponentsGlobalsProviderImpl())
    //freedomUIKitInit();
    
    /*TGHacks.setApplication(application)
    TGLegacyComponentsSetAccessChecker(AccessCheckerImpl())
    TGHacks.setPauseMusicPlayer {
        
    }
    TGViewController.setSizeClassSignal {
        return SSignal.single(UIUserInterfaceSizeClass.compact.rawValue as NSNumber)
    }
    TGLegacyComponentsSetDocumentsPath(documentsPath)
    
    TGLegacyComponentsSetCanOpenURL({ url in
        if let url = url {
            return canOpenUrl(url)
        }
        return false
    })
    TGLegacyComponentsSetOpenURL({ url in
        if let url = url {
            return openUrl(url)
        }
    })*/
}
