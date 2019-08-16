import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import WatchBridge

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
