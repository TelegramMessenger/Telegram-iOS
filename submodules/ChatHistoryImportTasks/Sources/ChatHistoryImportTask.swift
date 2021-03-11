import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

public enum ChatHistoryImportTasks {
    public final class Context {
        
    }
    
    public static func importState(peerId: PeerId) -> Signal<Float?, NoError> {
        return .single(nil)
    }
}
