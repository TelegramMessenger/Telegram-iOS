//
//  LocalizationUpdateObserver.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 4/22/19.
//

import Foundation

protocol HandlerContainerProtocol {
    associatedtype HandlerType
    
    func subscribe(handler: HandlerType) -> Int
    func unsubscribe(with id: Int)
    func unsubscribe()
}

class HandlerContainer<HandlerType>: HandlerContainerProtocol {
    var handlers: [Int: HandlerType] = [:]
    
    func subscribe(handler: HandlerType) -> Int {
        let newId = (handlers.keys.max() ?? 0) + 1
        handlers[newId] = handler
        return newId
    }
    
    func unsubscribe(with id: Int) {
        handlers.removeValue(forKey: id)
    }
    
    func unsubscribe() {
        handlers.removeAll()
    }
}

typealias LocalizationUpdateDownload = () -> Void
typealias LocalizationUpdateError = ([Error]) -> Void

class LocalizationUpdateObserver {
    static var shared = LocalizationUpdateObserver()
    
    var downloadHandlerContainer = HandlerContainer<LocalizationUpdateDownload>()
    var errorHandlerContainer = HandlerContainer<LocalizationUpdateError>()
    
    func addDownloadHandler(_ handler: @escaping LocalizationUpdateDownload) -> Int {
        return downloadHandlerContainer.subscribe(handler: handler)
    }
    
    func removeDownloadHandler(_ id: Int) {
        downloadHandlerContainer.unsubscribe(with: id)
    }
    
    func removeAllDownloadHandlers() {
        downloadHandlerContainer.unsubscribe()
    }
    
    func addErrorHandler(_ handler: @escaping LocalizationUpdateError) -> Int {
        return errorHandlerContainer.subscribe(handler: handler)
    }
    
    func removeErrorHandler(_ id: Int) {
        errorHandlerContainer.unsubscribe(with: id)
    }
    
    func removeAllErrorHandlers() {
        errorHandlerContainer.unsubscribe()
    }
    
    func notifyDownload() {
        downloadHandlerContainer.handlers.values.forEach({ $0() })
    }
    
    func notifyError(with errors: [Error]) {
        errorHandlerContainer.handlers.values.forEach({ $0(errors) })
        errors.forEach({ CrowdinLogsCollector.shared.add(log: CrowdinLog(type: .error, message: "Localization downloading error - \($0.localizedDescription)")) })
    }
}
