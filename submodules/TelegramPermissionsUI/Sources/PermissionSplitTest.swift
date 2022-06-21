import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPermissions

extension PermissionKind {
    fileprivate static var defaultOrder: [PermissionKind] {
        return [.contacts, .notifications]
    }
}

public enum PermissionUIRequestVariation {
    case `default`
    case modal(title: String, text: String, allowTitle: String, allowInSettingsTitle: String)
}

public struct PermissionUISplitTest: SplitTest {
    public typealias Configuration = PermissionUIConfiguration
    public typealias Event = PermissionUIEvent
    
    public let postbox: Postbox
    public let bucket: String?
    public let configuration: Configuration
    
    public init(postbox: Postbox, bucket: String?, configuration: Configuration) {
        self.postbox = postbox
        self.bucket = bucket
        self.configuration = configuration
    }
    
    public struct PermissionUIConfiguration: SplitTestConfiguration {
        public static var defaultValue: PermissionUIConfiguration {
            return PermissionUIConfiguration(contacts: .default, notifications: .default, order: PermissionKind.defaultOrder)
        }
        
        public let contacts: PermissionUIRequestVariation
        public let notifications: PermissionUIRequestVariation
        public let order: [PermissionKind]
        
        fileprivate init(contacts: PermissionUIRequestVariation, notifications: PermissionUIRequestVariation, order: [PermissionKind]) {
            self.contacts = contacts
            self.notifications = notifications
            self.order = order
        }
        
        static func with(appConfiguration: AppConfiguration) -> (PermissionUIConfiguration, String?) {
            if let data = appConfiguration.data, let permissions = data["ui_permissions_modals"] as? [String: Any] {
                let contacts: PermissionUIRequestVariation
                if let modal = permissions["phonebook_modal"] as? [String: Any] {
                    contacts = .modal(title: modal["popup_title_lang"] as? String ?? "", text: modal["popup_text_lang"] as? String ?? "", allowTitle: modal["popup_allowbtn_lang"] as? String ?? "", allowInSettingsTitle: modal["popup_allowbtn_settings_lang"] as? String ?? "")
                } else {
                    contacts = .default
                }
                
                let notifications: PermissionUIRequestVariation
                if let modal = permissions["notifications_modal"] as? [String: Any] {
                    notifications = .modal(title: modal["popup_title_lang"] as? String ?? "", text: modal["popup_text_lang"] as? String ?? "", allowTitle: modal["popup_allowbtn_lang"] as? String ?? "", allowInSettingsTitle: modal["popup_allowbtn_settings_lang"] as? String ?? "")
                } else {
                    notifications = .default
                }
                
                let order: [PermissionKind]
                if let values = permissions["order"] as? [String] {
                    order = values.compactMap { value in
                        switch value {
                            case "phonebook":
                                return .contacts
                            case "notifications":
                                return .notifications
                            default:
                                return nil
                        }
                    }
                } else {
                    order = PermissionKind.defaultOrder
                }

                return (PermissionUIConfiguration(contacts: contacts, notifications: notifications, order: order), permissions["bucket"] as? String)
            } else {
                return (.defaultValue, nil)
            }
        }
    }
    
    public enum PermissionUIEvent: String, SplitTestEvent {
        case ContactsModalRequest = "phbmodal_request"
        case ContactsRequest = "phbperm_request"
        case ContactsAllowed = "phbperm_allow"
        case ContactsDenied = "phbperm_disallow"
        case NotificationsModalRequest = "ntfmodal_request"
        case NotificationsRequest = "ntfperm_request"
        case NotificationsAllowed = "ntfperm_allow"
        case NotificationsDenied = "ntfperm_disallow"
    }
}

public func permissionUISplitTest(postbox: Postbox) -> Signal<PermissionUISplitTest, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> mapToSignal { view -> Signal<PermissionUISplitTest, NoError> in
        if let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self), appConfiguration.data != nil {
            let (config, bucket) = PermissionUISplitTest.Configuration.with(appConfiguration: appConfiguration)
            return .single(PermissionUISplitTest(postbox: postbox, bucket: bucket, configuration: config))
        } else {
            return .never()
        }
    } |> take(1)
}
