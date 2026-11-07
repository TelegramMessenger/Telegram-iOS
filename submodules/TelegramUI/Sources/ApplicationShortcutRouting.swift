import Foundation
import UIKit

// Entry point for App Intents declared in the app's main module (Spotlight / Siri App Shortcuts).
// Routes through the same handler as the Home Screen quick actions.
public func performApplicationShortcut(type: String) -> Bool {
    guard ApplicationShortcutItemType(rawValue: type) != nil else {
        return false
    }
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
        return false
    }
    appDelegate.handleShortcutItem(UIApplicationShortcutItem(type: type, localizedTitle: ""), completionHandler: { _ in })
    return true
}
