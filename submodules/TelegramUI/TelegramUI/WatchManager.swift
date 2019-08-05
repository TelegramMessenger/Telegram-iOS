import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

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

public final class WatchManagerImpl: WatchManager {
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
