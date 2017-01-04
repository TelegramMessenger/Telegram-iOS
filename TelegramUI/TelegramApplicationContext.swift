import Foundation
import SwiftSignalKit
import UIKit

public final class TelegramApplicationContext {
    public let openUrl: (String) -> Void
    public let getTopWindow: () -> UIWindow?
    public let displayNotification: (String) -> Void
    
    let sharedChatMediaInputNode = Atomic<ChatMediaInputNode?>(value: nil)
    let mediaManager = MediaManager()
    
    public init(openUrl: @escaping (String) -> Void, getTopWindow: @escaping () -> UIWindow?, displayNotification: @escaping (String) -> Void) {
        self.openUrl = openUrl
        self.getTopWindow = getTopWindow
        self.displayNotification = displayNotification
    }
}
