import Foundation
import SwiftSignalKit
import UIKit
import Postbox
import TelegramCore

public final class TelegramApplicationBindings {
    public let isMainApp: Bool
    public let openUrl: (String) -> Void
    public let canOpenUrl: (String) -> Bool
    public let getTopWindow: () -> UIWindow?
    public let displayNotification: (String) -> Void
    public let applicationInForeground: Signal<Bool, NoError>
    public let applicationIsActive: Signal<Bool, NoError>
    public let clearMessageNotifications: ([MessageId]) -> Void
    public let pushIdleTimerExtension: () -> Disposable
    
    public init(isMainApp: Bool, openUrl: @escaping (String) -> Void, canOpenUrl: @escaping (String) -> Bool, getTopWindow: @escaping () -> UIWindow?, displayNotification: @escaping (String) -> Void, applicationInForeground: Signal<Bool, NoError>, applicationIsActive: Signal<Bool, NoError>, clearMessageNotifications: @escaping ([MessageId]) -> Void, pushIdleTimerExtension: @escaping () -> Disposable) {
        self.isMainApp = isMainApp
        self.openUrl = openUrl
        self.canOpenUrl = canOpenUrl
        self.getTopWindow = getTopWindow
        self.displayNotification = displayNotification
        self.applicationInForeground = applicationInForeground
        self.applicationIsActive = applicationIsActive
        self.clearMessageNotifications = clearMessageNotifications
        self.pushIdleTimerExtension = pushIdleTimerExtension
    }
}

public final class TelegramApplicationContext {
    public let applicationBindings: TelegramApplicationBindings
    public let accountManager: AccountManager
    let fetchManager: FetchManager
    public var callManager: PresentationCallManager?
    
    public let mediaManager: MediaManager
    
    let locationManager: DeviceLocationManager?
    public let liveLocationManager: LiveLocationManager?
    
    public let contactsManager = DeviceContactsManager()
    
    public let currentPresentationData: Atomic<PresentationData>
    private let _presentationData = Promise<PresentationData>()
    public var presentationData: Signal<PresentationData, NoError> {
        return self._presentationData.get()
    }
    
    public let currentInAppNotificationSettings: Atomic<InAppNotificationSettings>
    private var inAppNotificationSettingsDisposable: Disposable?
    
    public let currentAutomaticMediaDownloadSettings: Atomic<AutomaticMediaDownloadSettings>
    private let _automaticMediaDownloadSettings = Promise<AutomaticMediaDownloadSettings>()
    public var automaticMediaDownloadSettings: Signal<AutomaticMediaDownloadSettings, NoError> {
        return self._automaticMediaDownloadSettings.get()
    }
    
    private let presentationDataDisposable = MetaDisposable()
    private let automaticMediaDownloadSettingsDisposable = MetaDisposable()
    
    public var navigateToCurrentCall: (() -> Void)?
    public var hasOngoingCall: Signal<Bool, NoError>?
    
    public init(applicationBindings: TelegramApplicationBindings, accountManager: AccountManager, currentPresentationData: PresentationData, presentationData: Signal<PresentationData, NoError>, currentMediaDownloadSettings: AutomaticMediaDownloadSettings, automaticMediaDownloadSettings: Signal<AutomaticMediaDownloadSettings, NoError>, currentInAppNotificationSettings: InAppNotificationSettings, postbox: Postbox, network: Network, accountPeerId: PeerId?, viewTracker: AccountViewTracker?, stateManager: AccountStateManager?) {
        self.mediaManager = MediaManager(postbox: postbox, inForeground: applicationBindings.applicationInForeground)
        
        if applicationBindings.isMainApp {
            self.locationManager = DeviceLocationManager(queue: Queue.mainQueue())
        } else {
            self.locationManager = nil
        }
        if let stateManager = stateManager, let accountPeerId = accountPeerId, let viewTracker = viewTracker, let locationManager = self.locationManager {
            self.liveLocationManager = LiveLocationManager(postbox: postbox, network: network, accountPeerId: accountPeerId, viewTracker: viewTracker, stateManager: stateManager, locationManager: locationManager, inForeground: applicationBindings.applicationInForeground)
        } else {
            self.liveLocationManager = nil
        }
        self.applicationBindings = applicationBindings
        self.accountManager = accountManager
        self.fetchManager = FetchManager(postbox: postbox)
        self.currentPresentationData = Atomic(value: currentPresentationData)
        self.currentAutomaticMediaDownloadSettings = Atomic(value: currentMediaDownloadSettings)
        self._presentationData.set(.single(currentPresentationData) |> then(presentationData))
        self._automaticMediaDownloadSettings.set(.single(currentMediaDownloadSettings) |> then(automaticMediaDownloadSettings))
        self.currentInAppNotificationSettings = Atomic(value: currentInAppNotificationSettings)
        
        
        let inAppPreferencesKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.inAppNotificationSettings]))
        inAppNotificationSettingsDisposable = (postbox.combinedView(keys: [inAppPreferencesKey]) |> deliverOnMainQueue).start(next: { [weak self] views in
            if let strongSelf = self {
                if let view = views.views[inAppPreferencesKey] as? PreferencesView {
                    if let settings = view.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                        let _ = strongSelf.currentInAppNotificationSettings.swap(settings)
                    }
                }
            }
        })
        
        self.presentationDataDisposable.set(self._presentationData.get().start(next: { [weak self] next in
            if let strongSelf = self {
                var stringsUpdated = false
                var themeUpdated = false
                let _ = strongSelf.currentPresentationData.modify { current in
                    if next.strings !== current.strings {
                        stringsUpdated = true
                    }
                    if next.theme !== current.theme {
                        themeUpdated = true
                    }
                    return next
                }
                if stringsUpdated {
                    updateLegacyLocalization(strings: next.strings)
                }
                if themeUpdated {
                    updateLegacyTheme()
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
        self.inAppNotificationSettingsDisposable?.dispose()
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
