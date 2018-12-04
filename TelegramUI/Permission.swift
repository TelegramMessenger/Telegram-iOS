import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

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

public func requiredPermissions(account: Account) -> Signal<(PermissionState, PermissionState), NoError> {
    return combineLatest(DeviceAccess.authorizationStatus(account: account, subject: .contacts), DeviceAccess.authorizationStatus(account: account, subject: .notifications))
    |> map { contactsStatus, notificationsStatus in
        return (.contacts(status: PermissionRequestStatus(accessType: contactsStatus)), .notifications(status: PermissionRequestStatus(accessType: notificationsStatus)))
    }
}
