import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

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

public final class WatchManagerArguments {
    public let appInstalled: Signal<Bool, NoError>
    public let navigateToMessageRequested: Signal<MessageId, NoError>
    public let runningTasks: Signal<WatchRunningTasks?, NoError>
    
    public init(appInstalled: Signal<Bool, NoError>, navigateToMessageRequested: Signal<MessageId, NoError>, runningTasks: Signal<WatchRunningTasks?, NoError>) {
        self.appInstalled = appInstalled
        self.navigateToMessageRequested = navigateToMessageRequested
        self.runningTasks = runningTasks
    }
}

public final class WatchManager {
    private let arguments: WatchManagerArguments?
    
    public init(arguments: WatchManagerArguments?) {
        self.arguments = arguments
    }
    
    public var watchAppInstalled: Signal<Bool, NoError> {
        return self.arguments?.appInstalled ?? .single(false)
    }
    
    public var navigateToMessageRequested: Signal<MessageId, NoError> {
        return self.arguments?.navigateToMessageRequested ?? .never()
    }
    
    public var runningTasks: Signal<WatchRunningTasks?, NoError> {
        return self.arguments?.runningTasks ?? .single(nil)
    }
}
