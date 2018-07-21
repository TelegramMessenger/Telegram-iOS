import Foundation
import UIKit
import AVFoundation
import Display
import SwiftSignalKit
import Photos
import CoreLocation

import LegacyComponents

enum DeviceAccessMicrophoneSubject {
    case audio
    case video
}

enum DeviceAccessMediaLibrarySubject {
    case send
    case save
}

enum DeviceAccessLocationSubject {
    case send
    case live
    case tracking
}

enum DeviceAccessSubject {
    case camera
    case microphone(DeviceAccessMicrophoneSubject)
    case mediaLibrary(DeviceAccessMediaLibrarySubject)
    case location(DeviceAccessLocationSubject)
}

private enum AccessType {
    case allowed
    case denied
    case restricted
}

private let cachedMediaLibraryAccessStatus = Atomic<Bool?>(value: nil)

func authorizeDeviceAccess(to subject: DeviceAccessSubject, presentationData: PresentationData, present: @escaping (ViewController, Any?) -> Void, openSettings: @escaping () -> Void, _ completion: @escaping (Bool) -> Void) {
    switch subject {
        case .camera:
            let status = PGCamera.cameraAuthorizationStatus()
            if status == PGCameraAuthorizationStatusNotDetermined {
                completion(true)
            } else if status == PGCameraAuthorizationStatusRestricted || status == PGCameraAuthorizationStatusDenied {
                let text: String
                if status == PGCameraAuthorizationStatusRestricted {
                    text = presentationData.strings.AccessDenied_CameraRestricted
                } else {
                    text = presentationData.strings.AccessDenied_Camera
                }
                completion(false)
                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.AccessDenied_Settings, action: {
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
                        }
                        present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            openSettings()
                        })]), nil)
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
                        present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.AccessDenied_Settings, action: {
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
                            present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.AccessDenied_Settings, action: {
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
                    present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.AccessDenied_Settings, action: {
                        openSettings()
                    })]), nil)
                case .notDetermined:
                    completion(true)
            }
    }
}
