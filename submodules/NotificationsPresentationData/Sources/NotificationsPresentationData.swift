import Foundation

public struct NotificationsPresentationData: Codable, Equatable {
    public var applicationLockedMessageString: String
    public var applicationLockedStoryString: String?
    public var incomingCallString: String
    
    public init(applicationLockedMessageString: String, applicationLockedStoryString: String?, incomingCallString: String) {
        self.applicationLockedMessageString = applicationLockedMessageString
        self.applicationLockedStoryString = applicationLockedStoryString
        self.incomingCallString = incomingCallString
    }
}

public func notificationsPresentationDataPath(rootPath: String) -> String {
    return rootPath + "/notificationsPresentationData.json"
}
