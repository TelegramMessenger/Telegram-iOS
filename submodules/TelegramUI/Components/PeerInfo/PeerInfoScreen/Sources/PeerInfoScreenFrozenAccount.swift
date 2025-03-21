import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import AccountContext

extension PeerInfoScreenImpl {
    func presentAccountFrozenInfoIfNeeded(delay: Bool = false) -> Bool {
        if self.context.isFrozen {
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
