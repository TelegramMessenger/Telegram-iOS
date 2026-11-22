import Foundation
import SwiftSignalKit
import TelegramCore

enum VideoChatNotificationIcon {
    case peer(EnginePeer)
    case icon(String)
    case animation(String)
}

extension VideoChatScreenComponent.View {
    func presentToast(icon: VideoChatNotificationIcon, text: String, duration: Int32) {
        let id = Int64.random(in: 0 ..< .max)
                
        let expiresOn = Int32(CFAbsoluteTimeGetCurrent()) + duration
        self.toastMessages.append((id: id, icon: icon, text: text, expiresOn: expiresOn))
        self.state?.updated(transition: .spring(duration: 0.4))
        
        Queue.mainQueue().after(Double(duration)) {
            self.toastMessages.removeAll(where: { $0.id == id })
            self.state?.updated(transition: .spring(duration: 0.4))
        }
    }
}
