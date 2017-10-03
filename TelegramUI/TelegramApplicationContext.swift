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
    let fetchManager: FetchManager
    public var callManager: PresentationCallManager?
    
    public let mediaManager = MediaManager()
    
    public let contactsManager = DeviceContactsManager()
    
    public let currentPresentationData: Atomic<PresentationData>
    private let _presentationData = Promise<PresentationData>()
    public var presentationData: Signal<PresentationData, NoError> {
        return self._presentationData.get()
    }
    
    public let currentAutomaticMediaDownloadSettings: Atomic<AutomaticMediaDownloadSettings>
    private let _automaticMediaDownloadSettings = Promise<AutomaticMediaDownloadSettings>()
    public var automaticMediaDownloadSettings: Signal<AutomaticMediaDownloadSettings, NoError> {
        return self._automaticMediaDownloadSettings.get()
    }
    
    private let presentationDataDisposable = MetaDisposable()
    private let automaticMediaDownloadSettingsDisposable = MetaDisposable()
    
    public var navigateToCurrentCall: (() -> Void)?
    public var hasOngoingCall: Signal<Bool, NoError>?
    
    public init(applicationBindings: TelegramApplicationBindings, accountManager: AccountManager, currentPresentationData: PresentationData, presentationData: Signal<PresentationData, NoError>, currentMediaDownloadSettings: AutomaticMediaDownloadSettings, automaticMediaDownloadSettings: Signal<AutomaticMediaDownloadSettings, NoError>, postbox: Postbox) {
        self.applicationBindings = applicationBindings
        self.accountManager = accountManager
        self.fetchManager = FetchManager(postbox: postbox)
        self.currentPresentationData = Atomic(value: currentPresentationData)
        self.currentAutomaticMediaDownloadSettings = Atomic(value: currentMediaDownloadSettings)
        self._presentationData.set(.single(currentPresentationData) |> then(presentationData))
        self._automaticMediaDownloadSettings.set(.single(currentMediaDownloadSettings) |> then(automaticMediaDownloadSettings))
        
        self.presentationDataDisposable.set(self._presentationData.get().start(next: { [weak self] next in
            if let strongSelf = self {
                var stringsUpdated = false
                let _ = strongSelf.currentPresentationData.modify { current in
                    if next.strings !== current.strings {
                        stringsUpdated = true
                    }
                    return next
                }
                if stringsUpdated {
                    updateLegacyLocalization(strings: next.strings)
                }
            }
        }))
        
        self.automaticMediaDownloadSettingsDisposable.set(self._automaticMediaDownloadSettings.get().start(next: { [weak self] next in
            if let strongSelf = self {
                let _ = strongSelf.currentAutomaticMediaDownloadSettings.swap(next)
            }
        }))
    }
    
    deinit {
        self.presentationDataDisposable.dispose()
        self.automaticMediaDownloadSettingsDisposable.dispose()
    }
    
    public func attachOverlayMediaController(_ controller: OverlayMediaController) {
        self.mediaManager.overlayMediaManager.attachOverlayMediaController(controller)
    }
}

public extension Account {
    public var telegramApplicationContext: TelegramApplicationContext {
        return self.applicationContext as! TelegramApplicationContext
    }
}
