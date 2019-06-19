import Foundation
import UIKit
import TelegramPresentationData

enum ApplicationShortcutItemType: String {
    case search
    case compose
    case camera
    case savedMessages
}

struct ApplicationShortcutItem: Equatable {
    let type: ApplicationShortcutItemType
    let title: String
}

@available(iOS 9.1, *)
extension ApplicationShortcutItem {
    func shortcutItem() -> UIApplicationShortcutItem {
        let icon: UIApplicationShortcutIcon
        switch self.type {
            case .search:
                icon = UIApplicationShortcutIcon(type: .search)
            case .compose:
                icon = UIApplicationShortcutIcon(type: .compose)
            case .camera:
                icon = UIApplicationShortcutIcon(type: .capturePhoto)
            case .savedMessages:
                icon = UIApplicationShortcutIcon(templateImageName: "Shortcuts/SavedMessages")
        }
        return UIApplicationShortcutItem(type: self.type.rawValue, localizedTitle: self.title, localizedSubtitle: nil, icon: icon, userInfo: nil)
    }
}

func applicationShortcutItems(strings: PresentationStrings) -> [ApplicationShortcutItem] {
    return [
        ApplicationShortcutItem(type: .search, title: strings.Common_Search),
        ApplicationShortcutItem(type: .compose, title: strings.Compose_NewMessage),
        ApplicationShortcutItem(type: .camera, title: strings.Camera_Title),
        ApplicationShortcutItem(type: .savedMessages, title: strings.Conversation_SavedMessages)
    ]
}
