import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
internal import TelegramApi

func managedAppChangelog(postbox: Postbox, network: Network, stateManager: AccountStateManager, appVersion: String) -> Signal<Void, NoError> {
    return .never()
}

