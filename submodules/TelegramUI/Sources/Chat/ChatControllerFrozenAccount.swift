import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import AccountContext

extension ChatControllerImpl {
    func presentAccountFrozenInfoIfNeeded(delay: Bool = false) -> Bool {
        if self.context.isFrozen {
            let accountFreezeConfiguration = AccountFreezeConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
            if let freezeAppealUrl = accountFreezeConfiguration.freezeAppealUrl {
                let components = freezeAppealUrl.components(separatedBy: "/")
                if let username = components.last, let peer = self.presentationInterfaceState.renderedPeer?.peer, peer.addressName == username {
                    return false
                }
            }
            let present = {
                self.push(self.context.sharedContext.makeAccountFreezeInfoScreen(context: self.context))
            }
            if delay {
                Queue.mainQueue().after(0.3) {
                    present()
                }
            } else {
                present()
            }
            return true
        }
        return false
    }
}
