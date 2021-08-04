import Foundation
import SwiftSignalKit
import Postbox

public struct WatchRunningTasks: Equatable {
    public let running: Bool
    public let version: Int32
    
    public init(running: Bool, version: Int32) {
        self.running = running
        self.version = version
    }
    
    public static func ==(lhs: WatchRunningTasks, rhs: WatchRunningTasks) -> Bool {
        return lhs.running == rhs.running && lhs.version == rhs.version
    }
}

public protocol WatchManager: AnyObject {
    var watchAppInstalled: Signal<Bool, NoError> { get }
    var navigateToMessageRequested: Signal<MessageId, NoError> { get }
    var runningTasks: Signal<WatchRunningTasks?, NoError> { get }
}
