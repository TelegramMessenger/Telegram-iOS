import Foundation
import Postbox

import SyncCore

public protocol SplitTestEvent: RawRepresentable where RawValue == String {
}

public protocol SplitTestConfiguration {
    static var defaultValue: Self { get }
}

public protocol SplitTest {
    associatedtype Configuration: SplitTestConfiguration
    associatedtype Event: SplitTestEvent
    
    var postbox: Postbox { get }
    var bucket: String? { get }
    var configuration: Configuration { get }
    
    init(postbox: Postbox, bucket: String?, configuration: Configuration)
}

extension SplitTest {
    public func addEvent(_ event: Self.Event, data: JSON = []) {
        if let bucket = self.bucket {
            //TODO: merge additional data
            addAppLogEvent(postbox: self.postbox, time: Date().timeIntervalSince1970, type: event.rawValue, peerId: nil, data: ["bucket": bucket])
        }
    }
}
