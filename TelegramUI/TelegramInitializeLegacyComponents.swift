import Foundation
import TelegramLegacyComponents
import UIKit

/*
 [TGHacks setApplication:application];
 [TGHacks setCurrentSizeClassGetter:^UIUserInterfaceSizeClass{
 return TGAppDelegateInstance.rootController.currentSizeClass;
 }];
 [TGHacks setCurrenHorizontalClassGetter:^UIUserInterfaceSizeClass{
 return TGAppDelegateInstance.rootController.traitCollection.horizontalSizeClass;
 }];
 TGLegacyComponentsSetDocumentsPath([TGAppDelegate documentsPath]);
 [TGHacks setForceSetStatusBarHidden:^(BOOL hidden, UIStatusBarAnimation animation) {
 [(TGApplication *)[UIApplication sharedApplication] forceSetStatusBarHidden:hidden withAnimation:animation];
 }];
 [TGHacks setApplicationBounds:^CGRect {
 return TGAppDelegateInstance.rootController.applicationBounds;
 }];
 [TGHacks setPauseMusicPlayer:^{
 [TGTelegraphInstance.musicPlayer controlPause];
 }];
 TGLegacyComponentsSetAccessChecker([[TGAccessCheckerImpl alloc] init]);
 */

private final class AccessCheckerImpl: NSObject, TGAccessCheckerProtocol {
    func checkAddressBookAuthorizationStatus(alertDismissComlpetion alertDismissCompletion: (() -> Swift.Void)!) -> Bool {
        return true
    }
    
    func checkPhotoAuthorizationStatus(for intent: TGPhotoAccessIntent, alertDismissCompletion: (() -> Swift.Void)!) -> Bool {
        return true
    }
    
    func checkMicrophoneAuthorizationStatus(for intent: TGMicrophoneAccessIntent, alertDismissCompletion: (() -> Swift.Void)!) -> Bool {
        return true
    }
    
    func checkCameraAuthorizationStatus(alertDismissComlpetion alertDismissCompletion: (() -> Swift.Void)!) -> Bool {
        return true
    }
    
    func checkLocationAuthorizationStatus(for intent: TGLocationAccessIntent, alertDismissComlpetion alertDismissCompletion: (() -> Swift.Void)!) -> Bool {
        return true
    }
}

public func initializeLegacyComponents(application: UIApplication, currentSizeClassGetter: @escaping () -> UIUserInterfaceSizeClass, currentHorizontalClassGetter: @escaping () -> UIUserInterfaceSizeClass, documentsPath: String, currentApplicationBounds: @escaping () -> CGRect, canOpenUrl: @escaping (URL) -> Bool, openUrl: @escaping (URL) -> Void) {
    freedomInit()
    //freedomUIKitInit();
    TGHacks.setApplication(application)
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
    })
}
