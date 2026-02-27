import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi

func managedAppChangelog(postbox: Postbox, network: Network, stateManager: AccountStateManager, appVersion: String) -> Signal<Void, NoError> {
    return .never()
}

