//
//  ActionRequest.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/2/19.
//

import Foundation

struct ActionRequest: Codable {
    let action: String
    let event: String
    
    enum Events: String {
        case subscribe
    }
    
    static func subscribeAction(with event: String) -> ActionRequest {
        return ActionRequest(action: Events.subscribe.rawValue, event: event)
    }

    var data: Data? {
        return try? JSONEncoder().encode(self)
    }
}
