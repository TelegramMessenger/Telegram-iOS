import Foundation
import SwiftSignalKit
import UIKit
import Postbox
import TelegramCore

public final class TelegramApplicationBindings {
    public let openUrl: (String) -> Void
    public let getTopWindow: () -> UIWindow?
    public let displayNotification: (String) -> Void
    public let applicationInForeground: Signal<Bool, NoError>
    public let applicationIsActive: Signal<Bool, NoError>
    
    public init(openUrl: @escaping (String) -> Void, getTopWindow: @escaping () -> UIWindow?, displayNotification: @escaping (String) -> Void, applicationInForeground: Signal<Bool, NoError>, applicationIsActive: Signal<Bool, NoError>) {
        self.openUrl = openUrl
        self.getTopWindow = getTopWindow
        self.displayNotification = displayNotification
        self.applicationInForeground = applicationInForeground
        self.applicationIsActive = applicationIsActive
    }
}

public final class TelegramApplicationContext {
    public let applicationBindings: TelegramApplicationBindings
    public let accountManager: AccountManager
    public var callManager: PresentationCallManager?
    
    public let mediaManager = MediaManager()
    
    public let currentPresentationData: Atomic<PresentationData>
    private let _presentationData = Promise<PresentationData>()
    public var presentationData: Signal<PresentationData, NoError> {
        return self._presentationData.get()
    }
    
    private let presentationDataDisposable = MetaDisposable()
    
    public var navigateToCurrentCall: (() -> Void)?
    public var hasOngoingCall: Signal<Bool, NoError>?
    
    public init(applicationBindings: TelegramApplicationBindings, accountManager: AccountManager, currentPresentationData: PresentationData, presentationData: Signal<PresentationData, NoError>) {
        self.applicationBindings = applicationBindings
        self.accountManager = accountManager
        self.currentPresentationData = Atomic(value: currentPresentationData)
        self._presentationData.set(.single(currentPresentationData) |> then(presentationData))
        
        self.presentationDataDisposable.set(self._presentationData.get().start(next: { [weak self] next in
            if let strongSelf = self {
                let _ = strongSelf.currentPresentationData.swap(next)
            }
        }))
    }
    
    deinit {
        self.presentationDataDisposable.dispose()
    }
    
    public func attachOverlayMediaController(_ controller: OverlayMediaController) {
        self.mediaManager.overlayMediaManager.attachOverlayMediaController(controller)
    }
}

extension Account {
    var telegramApplicationContext: TelegramApplicationContext {
        return self.applicationContext as! TelegramApplicationContext
    }
}
