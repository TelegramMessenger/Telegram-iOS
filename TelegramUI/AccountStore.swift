import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

public final class AccountStore {
    private static var accountManager: AccountManager?
    static var switchingSettingsController: (SettingsController & ViewController)?
    
    public static func initialize(accountManager: AccountManager) {
        assert(self.accountManager == nil)
        self.accountManager = accountManager
    }
    
    static func switchToAccount(id: AccountRecordId, fromSettingsController settingsController: (SettingsController & ViewController)? = nil) {
        assert(Queue.mainQueue().isCurrent())
        guard let accountManager = self.accountManager else {
            preconditionFailure()
        }
        self.switchingSettingsController = settingsController
        let _ = accountManager.transaction({ transaction in
            transaction.setCurrentId(id)
        }).start()
    }
}
