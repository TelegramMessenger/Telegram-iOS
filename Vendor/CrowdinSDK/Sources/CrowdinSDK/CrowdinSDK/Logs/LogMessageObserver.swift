//
//  LogMessageObserver.swift
//  CrowdinSDK
//
//  Created by Nazar Yavornytskyy on 3/31/21.
//

import Foundation

typealias LogMessageHandler = (String) -> Void
final class LogMessageObserver {
    static var shared = LogMessageObserver()
    
    var logsHandlerContainer = HandlerContainer<LogMessageHandler>()
    
    func addLogMessageHandler(_ handler: @escaping LogMessageHandler) -> Int {
        logsHandlerContainer.subscribe(handler: handler)
    }
    
    func removeLogMessageHandler(_ id: Int) {
        logsHandlerContainer.unsubscribe(with: id)
    }
    
    func removeAllLogMessageHandlers() {
        logsHandlerContainer.unsubscribe()
    }
    
    func notifyAll(_ text: String) {
        logsHandlerContainer.handlers.values.forEach({ $0(text) })
    }
}
