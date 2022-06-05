import Foundation
import UIKit
import AVFoundation
import Display
import TelegramCore
import SwiftSignalKit
import Photos
import CoreLocation
import Contacts
import AddressBook
import UserNotifications
import CoreTelephony
import TelegramPresentationData
import LegacyComponents
import AccountContext

public enum DeviceAccessCameraSubject {
    case video
    case videoCall
    case qrCode
}

public enum DeviceAccessMicrophoneSubject {
    case audio
    case video
    case voiceCall
}

public enum DeviceAccessMediaLibrarySubject {
    case send
    case save
    case wallpaper
    case qrCode
}

public enum DeviceAccessLocationSubject {
    case send
    case live
    case tracking
}

public enum DeviceAccessSubject {
    case camera(DeviceAccessCameraSubject)
    case microphone(DeviceAccessMicrophoneSubject)
    case mediaLibrary(DeviceAccessMediaLibrarySubject)
    case location(DeviceAccessLocationSubject)
    case contacts
    case notifications
    case siri
    case cellularData
}

private let cachedMediaLibraryAccessStatus = Atomic<Bool?>(value: nil)

public func shouldDisplayNotificationsPermissionWarning(status: AccessType, suppressed: Bool) -> Bool {
    switch (status, suppressed) {
        case (.allowed, _), (.unreachable, true), (.notDetermined, true):
            return false
        default:
            return true
    }
}

public final class DeviceAccess {
    private static let contactsPromise = Promise<Bool?>(nil)
    static var contacts: Signal<Bool?, NoError> {
        return self.contactsPromise.get()
        |> distinctUntilChanged
    }
    
    private static let notificationsPromise = Promise<Bool?>(nil)
    static var notifications: Signal<Bool?, NoError> {
        return self.notificationsPromise.get()
    }
    
    private static let siriPromise = Promise<Bool?>(nil)
    static var siri: Signal<Bool?, NoError> {
        return self.siriPromise.get()
    }
    
    private static let locationPromise = Promise<Bool?>(nil)
    static var location: Signal<Bool?, NoError> {
        return self.locationPromise.get()
    }
    
    public static func isMicrophoneAccessAuthorized() -> Bool? {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    public static func isCameraAccessAuthorized() -> Bool {
        return PGCamera.cameraAuthorizationStatus() == PGCameraAuthorizationStatusAuthorized
    }
    
    public static func authorizationStatus(applicationInForeground: Signal<Bool, NoError>? = nil, siriAuthorization: (() -> AccessType)? = nil, subject: DeviceAccessSubject) -> Signal<AccessType, NoError> {
        switch subject {
            case .notifications:
                let status = (Signal<AccessType, NoError> { subscriber in
                    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
                            switch settings.authorizationStatus {
                                case .authorized:
                                    if settings.alertSetting == .disabled {
                                        subscriber.putNext(.unreachable)
                                    } else {
                                        subscriber.putNext(.allowed)
                                    }
                                case .denied:
                                    subscriber.putNext(.denied)
                                case .notDetermined:
                                    subscriber.putNext(.notDetermined)
                                default:
                                    subscriber.putNext(.notDetermined)
                            }
                            subscriber.putCompletion()
                        })
                    } else {
                        subscriber.putNext(.notDetermined)
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                } |> afterNext { status in
                    switch status {
                        case .allowed, .unreachable:
                            DeviceAccess.notificationsPromise.set(.single(nil))
                        default:
                            break
                    }
                } )
                |> then(self.notifications
                    |> mapToSignal { authorized -> Signal<AccessType, NoError> in
                        if let authorized = authorized {
                            return .single(authorized ? .allowed : .denied)
                        } else {
                            return .complete()
                        }
                    })
                if let applicationInForeground = applicationInForeground {
                    return applicationInForeground
                    |> distinctUntilChanged
                    |> mapToSignal { inForeground -> Signal<AccessType, NoError> in
                        return status
                    }
                } else {
                    return status
                }
            case .contacts:
                let status = Signal<AccessType, NoError> { subscriber in
                    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                        switch CNContactStore.authorizationStatus(for: .contacts) {
                            case .notDetermined:
                                subscriber.putNext(.notDetermined)
                            case .authorized:
                                subscriber.putNext(.allowed)
                            default:
                                subscriber.putNext(.denied)
                        }
                        subscriber.putCompletion()
                    } else {
                        switch ABAddressBookGetAuthorizationStatus() {
                            case .notDetermined:
                                subscriber.putNext(.notDetermined)
                            case .authorized:
                                subscriber.putNext(.allowed)
                            default:
                                subscriber.putNext(.denied)
                        }
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }
                return status
                |> then(self.contacts
                    |> mapToSignal { authorized -> Signal<AccessType, NoError> in
                        if let authorized = authorized {
                            return .single(authorized ? .allowed : .denied)
                        } else {
                            return .complete()
                        }
                    })
            case .cellularData:
                return Signal { subscriber in
                    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                        func statusForCellularState(_ state: CTCellularDataRestrictedState) -> AccessType? {
                            switch state {
                                case .restricted:
                                    return .denied
                                case .notRestricted:
                                    return .allowed
                                default:
                                    return .allowed
                            }
                        }
                        let cellState = CTCellularData.init()
                        if let status = statusForCellularState(cellState.restrictedState) {
                            subscriber.putNext(status)
                        }
                        cellState.cellularDataRestrictionDidUpdateNotifier = { restrictedState in
                            if let status = statusForCellularState(restrictedState) {
                                subscriber.putNext(status)
                            }
                        }
                    } else {
                        subscriber.putNext(.allowed)
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
            }
            case .siri:
                if let siriAuthorization = siriAuthorization {
                    return Signal { subscriber in
                        let status = siriAuthorization()
                        subscriber.putNext(status)
                        subscriber.putCompletion()
                        return EmptyDisposable
                    }
                    |> then(self.siri
                        |> mapToSignal { authorized -> Signal<AccessType, NoError> in
                            if let authorized = authorized {
                                return .single(authorized ? .allowed : .denied)
                            } else {
                                return .complete()
                            }
                        })
                } else {
                    return .single(.denied)
                }
            case .location:
                return Signal { subscriber in
                    let status = CLLocationManager.authorizationStatus()
                    switch status {
                        case .authorizedAlways, .authorizedWhenInUse:
                            subscriber.putNext(.allowed)
                        case .denied, .restricted:
                            subscriber.putNext(.denied)
                        case .notDetermined:
                            subscriber.putNext(.notDetermined)
                        @unknown default:
                            fatalError()
                    }
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
                |> then(self.location
                    |> mapToSignal { authorized -> Signal<AccessType, NoError> in
                        if let authorized = authorized {
                            return .single(authorized ? .allowed : .denied)
                        } else {
                            return .complete()
                        }
                    }
                )
            default:
                return .single(.notDetermined)
        }
    }
    
    public static func authorizeAccess(to subject: DeviceAccessSubject, onlyCheck: Bool = false, registerForNotifications: ((@escaping (Bool) -> Void) -> Void)? = nil, requestSiriAuthorization: ((@escaping (Bool) -> Void) -> Void)? = nil, locationManager: LocationManager? = nil, presentationData: PresentationData? = nil, present: @escaping (ViewController, Any?) -> Void = { _, _ in }, openSettings: @escaping () -> Void = { }, displayNotificationFromBackground: @escaping (String) -> Void = { _ in }, _ completion: @escaping (Bool) -> Void = { _ in }) {
            switch subject {
                case let .camera(cameraSubject):
                    let status = PGCamera.cameraAuthorizationStatus()
                    if status == PGCameraAuthorizationStatusNotDetermined {
                        if !onlyCheck {
                            AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
                                Queue.mainQueue().async {
                                    completion(response)
                                    if !response, let presentationData = presentationData {
                                        let text: String
                                        switch cameraSubject {
                                            case .video:
                                                text = presentationData.strings.AccessDenied_Camera
                                            case .videoCall:
                                                text = presentationData.strings.AccessDenied_VideoCallCamera
                                            case .qrCode:
                                                text = presentationData.strings.AccessDenied_QrCamera
                                        }
                                        present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                            openSettings()
                                        })]), nil)
                                    }
                                }
                            }
                        } else {
                            completion(true)
                        }
                    } else if status == PGCameraAuthorizationStatusRestricted || status == PGCameraAuthorizationStatusDenied, let presentationData = presentationData {
                        let text: String
                        if status == PGCameraAuthorizationStatusRestricted {
                            text = presentationData.strings.AccessDenied_CameraRestricted
                        } else {
                            switch cameraSubject {
                                case .video:
                                    text = presentationData.strings.AccessDenied_Camera
                                case .videoCall:
                                    text = presentationData.strings.AccessDenied_VideoCallCamera
                                case .qrCode:
                                    text = presentationData.strings.AccessDenied_QrCamera
                            }
                        }
                        completion(false)
                        present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            openSettings()
                        })]), nil)
                    } else if status == PGCameraAuthorizationStatusAuthorized {
                        completion(true)
                    } else {
                        assertionFailure()
                        completion(true)
                    }
                case let .microphone(microphoneSubject):
                    if AVAudioSession.sharedInstance().recordPermission == .granted {
                        completion(true)
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission({ granted in
                            Queue.mainQueue().async {
                                if granted {
                                    completion(true)
                                } else if let presentationData = presentationData {
                                    completion(false)
                                    let text: String
                                    switch microphoneSubject {
                                        case .audio:
                                            text = presentationData.strings.AccessDenied_VoiceMicrophone
                                        case .video:
                                            text = presentationData.strings.AccessDenied_VideoMicrophone
                                        case .voiceCall:
                                            text = presentationData.strings.AccessDenied_CallMicrophone
                                    }
                                    present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                        openSettings()
                                    })]), nil)
                                    if case .voiceCall = microphoneSubject {
                                        displayNotificationFromBackground(text)
                                    }
                                }
                            }
                        })
                    }
                case let .mediaLibrary(mediaLibrarySubject):
                    let continueWithValue: (Bool) -> Void = { value in
                        Queue.mainQueue().async {
                            if value {
                                completion(true)
                            } else if let presentationData = presentationData {
                                completion(false)
                                let text: String
                                switch mediaLibrarySubject {
                                    case .send:
                                        text = presentationData.strings.AccessDenied_PhotosAndVideos
                                    case .save:
                                        text = presentationData.strings.AccessDenied_SaveMedia
                                    case .wallpaper:
                                        text = presentationData.strings.AccessDenied_Wallpapers
                                    case .qrCode:
                                        text = presentationData.strings.AccessDenied_QrCode
                                }
                                present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                    openSettings()
                                })]), nil)
                            }
                        }
                    }
                    if let value = cachedMediaLibraryAccessStatus.with({ $0 }) {
                        continueWithValue(value)
                    } else {
                        PHPhotoLibrary.requestAuthorization({ status in
                            let value: Bool
                            switch status {
                                case .restricted, .denied, .notDetermined:
                                    value = false
                                case .authorized, .limited:
                                    value = true
                                @unknown default:
                                    fatalError()
                            }
                            let _ = cachedMediaLibraryAccessStatus.swap(value)
                            continueWithValue(value)
                        })
                    }
                case let .location(locationSubject):
                    let status = CLLocationManager.authorizationStatus()
                    let hasPreciseLocation: Bool
                    if #available(iOS 14.0, *) {
                        if case .fullAccuracy = CLLocationManager().accuracyAuthorization {
                            hasPreciseLocation = true
                        } else {
                            hasPreciseLocation = false
                        }
                    } else {
                        hasPreciseLocation = true
                    }
                    switch status {
                        case .authorizedAlways:
                            if case .live = locationSubject, !hasPreciseLocation {
                                completion(false)
                                if let presentationData = presentationData {
                                    let text = presentationData.strings.AccessDenied_LocationPreciseDenied
                                    present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                        openSettings()
                                    })]), nil)
                                }
                            } else {
                                completion(true)
                            }
                        case .authorizedWhenInUse:
                            switch locationSubject {
                                case .send, .tracking:
                                    completion(true)
                                case .live:
                                    completion(false)
                                    if let presentationData = presentationData {
                                        let text = presentationData.strings.AccessDenied_LocationAlwaysDenied
                                        present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                            openSettings()
                                        })]), nil)
                                    }
                            }
                        case .denied, .restricted:
                            completion(false)
                            if let presentationData = presentationData {
                                let text: String
                                if status == .denied {
                                    switch locationSubject {
                                        case .send, .live:
                                            text = presentationData.strings.AccessDenied_LocationDenied
                                        case .tracking:
                                            text = presentationData.strings.AccessDenied_LocationTracking
                                    }
                                } else {
                                    text = presentationData.strings.AccessDenied_LocationDisabled
                                }
                                present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                    openSettings()
                                })]), nil)
                            }
                        case .notDetermined:
                            switch locationSubject {
                                case .send, .tracking:
                                    locationManager?.requestWhenInUseAuthorization(completion: { status in
                                        completion(status == .authorizedWhenInUse || status == .authorizedAlways)
                                    })
                                case .live:
                                    locationManager?.requestAlwaysAuthorization(completion: { status in
                                        completion(status == .authorizedAlways)
                                    })
                            }
                        @unknown default:
                            fatalError()
                }
                case .contacts:
                    let _ = (self.contactsPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { value in
                        if let value = value {
                            completion(value)
                        } else {
                            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                                switch CNContactStore.authorizationStatus(for: .contacts) {
                                    case .notDetermined:
                                        let store = CNContactStore()
                                        store.requestAccess(for: .contacts, completionHandler: { authorized, _ in
                                            self.contactsPromise.set(.single(authorized))
                                            completion(authorized)
                                        })
                                    case .authorized:
                                        self.contactsPromise.set(.single(true))
                                        completion(true)
                                    default:
                                        self.contactsPromise.set(.single(false))
                                        completion(false)
                                }
                            } else {
                                switch ABAddressBookGetAuthorizationStatus() {
                                    case .notDetermined:
                                        var error: Unmanaged<CFError>?
                                        let addressBook = ABAddressBookCreateWithOptions(nil, &error)
                                        if let addressBook = addressBook?.takeUnretainedValue() {
                                            ABAddressBookRequestAccessWithCompletion(addressBook, { authorized, _ in
                                                Queue.mainQueue().async {
                                                    self.contactsPromise.set(.single(authorized))
                                                    completion(authorized)
                                                }
                                            })
                                        } else {
                                            self.contactsPromise.set(.single(false))
                                            completion(false)
                                        }
                                    case .authorized:
                                        self.contactsPromise.set(.single(true))
                                        completion(true)
                                    default:
                                        self.contactsPromise.set(.single(false))
                                        completion(false)
                                }
                            }
                        }
                    })
                case .notifications:
                    if let registerForNotifications = registerForNotifications {
                        registerForNotifications { result in
                            self.notificationsPromise.set(.single(result))
                            completion(result)
                        }
                    }
                case .siri:
                    if let requestSiriAuthorization = requestSiriAuthorization {
                        requestSiriAuthorization { result in
                            self.siriPromise.set(.single(result))
                            completion(result)
                        }
                    }
                case .cellularData:
                    if let presentationData = presentationData {
                        present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.Permissions_CellularDataTitle_v0, text: presentationData.strings.Permissions_CellularDataText_v0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            openSettings()
                        })]), nil)
                    }
            }
    }
}
