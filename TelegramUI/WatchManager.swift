import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

public final class WatchManagerArguments {
    public let appInstalled: Signal<Bool, NoError>
    public let navigateToMessageRequested: Signal<MessageId, NoError>
    public let runningRequests: Signal<Bool, NoError>
    
    public init(appInstalled: Signal<Bool, NoError>, navigateToMessageRequested: Signal<MessageId, NoError>, runningRequests: Signal<Bool, NoError>) {
        self.appInstalled = appInstalled
        self.navigateToMessageRequested = navigateToMessageRequested
        self.runningRequests = runningRequests
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
    
    public var runningRequests: Signal<Bool, NoError> {
        return self.arguments?.runningRequests ?? .single(false)
    }
}
