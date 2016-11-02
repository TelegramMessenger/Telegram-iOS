import Foundation
import SwiftSignalKit

final class ApplicationSpecificData {
    let sharedChatMediaInputNode = Atomic<ChatMediaInputNode?>(value: nil)
}
