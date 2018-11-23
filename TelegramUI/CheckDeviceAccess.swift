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

import LegacyComponents

public enum DeviceAccessMicrophoneSubject {
    case audio
    case video
    case voiceCall
}

public enum DeviceAccessMediaLibrarySubject {
    case send
    case save
}

public enum DeviceAccessLocationSubject {
    case send
    case live
    case tracking
}

public enum DeviceAccessSubject {
    case camera
    case microphone(DeviceAccessMicrophoneSubject)
    case mediaLibrary(DeviceAccessMediaLibrarySubject)
    case location(DeviceAccessLocationSubject)
    case contacts
    case notifications
    case siri
    case cellularData
}

public enum AccessType {
    case notDetermined
    case allowed
    case denied
    case restricted
}

private let cachedMediaLibraryAccessStatus = Atomic<Bool?>(value: nil)

public final class DeviceAccess {
    private static let contactsPromise = Promise<Bool?>(nil)
    static var contacts: Signal<Bool?, NoError> {
        return self.contactsPromise.get()
    }
    
    private static let notificationsPromise = Promise<AccessType?>(nil)
    
    public static func isMicrophoneAccessAuthorized() -> Bool? {
        return AVAudioSession.sharedInstance().recordPermission() == .granted
    }
    
    public static func authorizationStatus(account: Account, subject: DeviceAccessSubject) -> Signal<AccessType, NoError> {
        switch subject {
            case .notifications:
                let status = Signal<AccessType, NoError> { subscriber in
                    if #available(iOSApplicationExtension 10.0, *) {
                        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
                            switch settings.authorizationStatus {
                                case .authorized:
                                    subscriber.putNext(.allowed)
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
                }
                return account.telegramApplicationContext.applicationBindings.applicationInForeground
                |> distinctUntilChanged
                |> mapToSignal { inForeground -> Signal<AccessType, NoError> in
                    return status
                }
            case .contacts:
                let status = Signal<AccessType, NoError> { subscriber in
                    if #available(iOSApplicationExtension 9.0, *) {
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
                    if #available(iOSApplicationExtension 9.0, *) {
                        func statusForCellularState(_ state: CTCellularDataRestrictedState) -> AccessType? {
                            switch state {
                            case .restricted:
                                return .denied
                            case .notRestricted:
                                return .allowed
                            default:
                                return nil
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
                        subscriber.putNext(.notDetermined)
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
            }
            default:
                return .single(.notDetermined)
        }
    }
    
    public static func authorizeAccess(to subject: DeviceAccessSubject, presentationData: PresentationData, present: @escaping (ViewController, Any?) -> Void, openSettings: @escaping () -> Void, displayNotificationFromBackground: @escaping (String) -> Void = { _ in }, _ completion: @escaping (Bool) -> Void) {
            switch subject {
                case .camera:
                    let status = PGCamera.cameraAuthorizationStatus()
                    if status == PGCameraAuthorizationStatusNotDetermined {
                        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
                            Queue.mainQueue().async {
                                completion(response)
                                if !response {
                                    let text = presentationData.strings.AccessDenied_Camera
                                    present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                        openSettings()
                                    })]), nil)
                                }
                            }
                        }
                    } else if status == PGCameraAuthorizationStatusRestricted || status == PGCameraAuthorizationStatusDenied {
                        let text: String
                        if status == PGCameraAuthorizationStatusRestricted {
                            text = presentationData.strings.AccessDenied_CameraRestricted
                        } else {
                            text = presentationData.strings.AccessDenied_Camera
                        }
                        completion(false)
                        present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            openSettings()
                        })]), nil)
                    } else if status == PGCameraAuthorizationStatusAuthorized {
                        completion(true)
                    } else {
                        assertionFailure()
                        completion(true)
                    }
                case let .microphone(microphoneSubject):
                    if AVAudioSession.sharedInstance().recordPermission() == .granted {
                        completion(true)
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission({ granted in
                            if granted {
                                completion(true)
                            } else {
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
                                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                    openSettings()
                                })]), nil)
                                if case .voiceCall = microphoneSubject {
                                    displayNotificationFromBackground(text)
                                }
                            }
                        })
                    }
                case let .mediaLibrary(mediaLibrarySubject):
                    let continueWithValue: (Bool) -> Void = { value in
                        Queue.mainQueue().async {
                            if value {
                                completion(true)
                            } else {
                                completion(false)
                                let text: String
                                switch mediaLibrarySubject {
                                    case .send:
                                        text = presentationData.strings.AccessDenied_PhotosAndVideos
                                    case .save:
                                        text = presentationData.strings.AccessDenied_SaveMedia
                                }
                                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
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
                                case .authorized:
                                    value = true
                            }
                            let _ = cachedMediaLibraryAccessStatus.swap(value)
                            continueWithValue(value)
                        })
                    }
                case let .location(locationSubject):
                    let status = CLLocationManager.authorizationStatus()
                    switch status {
                        case .authorizedAlways:
                            completion(true)
                        case .authorizedWhenInUse:
                            switch locationSubject {
                                case .send, .tracking:
                                    completion(true)
                                case .live:
                                    completion(false)
                                    let text = presentationData.strings.AccessDenied_LocationAlwaysDenied
                                    present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                        openSettings()
                                    })]), nil)
                            }
                        case .denied, .restricted:
                            completion(false)
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
                            present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                                openSettings()
                            })]), nil)
                        case .notDetermined:
                            completion(true)
                    }
                case .contacts:
                    let _ = (self.contactsPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { value in
                        if let value = value {
                            completion(value)
                        } else {
                            if #available(iOSApplicationExtension 9.0, *) {
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
                default:
                    break
            }
    }
}
