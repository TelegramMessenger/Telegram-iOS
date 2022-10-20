import Foundation

public struct NotificationsPresentationData: Codable, Equatable {
    public var applicationLockedMessageString: String
    public var incomingCallString: String
    
    public init(applicationLockedMessageString: String, incomingCallString: String) {
        self.applicationLockedMessageString = applicationLockedMessageString
        self.incomingCallString = incomingCallString
    }
}

public func notificationsPresentationDataPath(rootPath: String) -> String {
    return rootPath + "/notificationsPresentationData.json"
}
