import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import DeviceAccess

public enum PermissionKind: Int32 {
    case contacts
    case notifications
    case siri
    case cellularData
}

public enum PermissionRequestStatus {
    case requestable
    case denied
    case unreachable
    case allowed
    
    init(accessType: AccessType) {
        switch accessType {
            case .notDetermined:
                self = .requestable
            case .denied, .restricted:
                self = .denied
            case .unreachable:
                self = .unreachable
            case .allowed:
                self = .allowed
        }
    }
}

public enum PermissionState: Equatable {
    case contacts(status: PermissionRequestStatus)
    case notifications(status: PermissionRequestStatus)
    case siri(status: PermissionRequestStatus)
    case cellularData
    
    var kind: PermissionKind {
        switch self {
            case .contacts:
                return .contacts
            case .notifications:
                return .notifications
            case .siri:
                return .siri
            case .cellularData:
                return .cellularData
        }
    }
    
    public var status: PermissionRequestStatus {
        switch self {
            case let .contacts(status):
                return status
            case let .notifications(status):
                return status
            case let .siri(status):
                return status
            case .cellularData:
                return .unreachable
        }
    }
}

public func requiredPermissions(context: AccountContext) -> Signal<(PermissionState, PermissionState, PermissionState), NoError> {
    return combineLatest(DeviceAccess.authorizationStatus(subject: .contacts), DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications), DeviceAccess.authorizationStatus(siriAuthorization: {
        return context.sharedContext.applicationBindings.siriAuthorization()
    }, subject: .siri))
    |> map { contactsStatus, notificationsStatus, siriStatus in
        return (.contacts(status: PermissionRequestStatus(accessType: contactsStatus)), .notifications(status: PermissionRequestStatus(accessType: notificationsStatus)), .siri(status: PermissionRequestStatus(accessType: siriStatus)))
    }
}
