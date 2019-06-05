import Foundation
import AsyncDisplayKit
import MtProtoKit
import SwiftSignalKit
import SSignalKit
import Display
import Postbox
import TelegramCore
import LegacyComponents
import HockeySDK
import Lottie

func test() {
    let _ = ASDisplayNode()
    let _ = MTProto()
    let _ = Signal<Never, NoError> { subscriber in
        return ActionDisposable {
        }
    }
    let _ = SSignal(generator: { subscriber in
        return SBlockDisposable {
        }
    })
    let _ = ListView()
    let _ = SqliteValueBox(basePath: "", queue: .mainQueue(), encryptionParameters: nil, upgradeProgress: { _ in }, inMemory: true)
    initializeAccountManagement()
    BITHockeyManager.shared().crashManager.crashManagerStatus = .alwaysAsk
    let _ = LOTComposition(json: [:])
}
