//
//  TdClientManager.swift
//  
//
//  Created by Sergey Akentev on 29.7.2023.
//

import Foundation
import TDLibFramework


public class TDLibClient: TDLibApi, Equatable {
    public let id: Int32
    public private(set) var awaitingCompletions = ConcurrentDictionary<String, (Data) -> Void>()
    public let updateHandler: (Data, TDLibClient) -> Void
    /// 'updateHandlerQueue' is a client-specific queue for incoming updates and responses. Serial queue ensures an order of updates https://core.telegram.org/tdlib/getting-started#handling-updates
    public let updateHandlerQueue: DispatchQueue
    /// 'queryQueue' is a client-specific queue for outgoing requests. It's a concurrent queue, so some requests may be dispatched earlier even if they were called later.
    private let queryQueue: DispatchQueue
    private let logger: TDLibLogger?
    
    /// Since ``td_receive`` can be called only from a single thread, ``TDLibClient`` initializer is private to ensure each client will receive responses for their requests.
    fileprivate init(updateHandler: @escaping (Data, TDLibClient) -> Void, logger: TDLibLogger? = nil) {
        self.id = td_create_client_id()
        self.updateHandler = updateHandler
        self.updateHandlerQueue = DispatchQueue(label: "app.swiftgram.TDLibKit.client-\(self.id).update-handler")
        self.queryQueue = DispatchQueue(label: "app.swiftgram.TDLibKit.client-\(self.id).query", attributes: .concurrent)
        self.logger = logger
        super.init()
    }
    

    func completionHandler(extra: String, result: Data) {
        self.updateHandlerQueue.async {
            if let completion = self.awaitingCompletions.removeValue(forKey: extra) {
                completion(result)
            }
        }
    }
    
    /// Sends request to the TDLib client.
    override public func send(query: TdQuery, completion: ((Data) -> Void)? = nil) throws {
        self.queryQueue.async { [weak self] in
            guard let `self` = self else { return }
            var extra: String? = nil
            if let completion = completion {
                extra = UUID().uuidString
                self.awaitingCompletions[extra!] = completion
            }
            let data = try! query.make(with: extra)
            if let str = String(data: data, encoding: .utf8) {
                self.logger?.log("[\(self.id)] " + str, type: .send)
                td_send(self.id, str)
            } else {
                let errorText: String = "ERROR! Unable to encode query data, conversion returns nil"
                if let strongLogger = self.logger {
                    strongLogger.log("[\(self.id)] " + errorText, type: .send)
                } else {
                    print(errorText)
                }
            }
        }
    }
    
    /// Synchronously executes TDLib request.
    override public func execute(query: TdQuery) throws -> [String:Any]? {
        do {
            let data = try query.make(with: nil)
            let str = String(data: data, encoding: .utf8)!
            logger?.log(str, type: .execute)
            if let res = td_execute(str) {
                let resString = String(cString: res)
                logger?.log(resString, type: .receive)
                let resData = resString.data(using: .utf8)
                let json = try JSONSerialization.jsonObject(with: resData!, options:[])
                let dictionary = json as! [String:Any]
                return dictionary
            } else {
                throw TDError(code: 404, message: "Empty response from TDLib")
            }
        } catch {
            throw error
        }
    }

    
    public static func == (lhs: TDLibClient, rhs: TDLibClient) -> Bool {
        return lhs.id == rhs.id
    }
    
}


open class TDLibClientManager {
    /// 'receiveQueue' is a separate queue that calls ``td_receive`` in a loop
    private let receiveQueue = DispatchQueue(label: "app.swiftgram.TDLibKit.receive")
    /// 'queryQueue' is a separate queue that will decode update string and lookup for possible completions in existing ``self.clients``. 'queryQueue' exists to quickly switch back to 'receiveQueue' and call next ``td_receive``
    private let queryQueue = DispatchQueue(label: "app.swiftgram.TDLibKit.query")
    public private(set) var clients = ConcurrentDictionary<Int32,TDLibClient>()
    private let logger: TDLibLogger?
    
    
    /// TDLibClientManager
    ///
    ///
    /// - Parameter logger: The logger object for debug print all queries and responses
    public init(logger: TDLibLogger? = nil) {
        #warning("Breaking changes may be introduced to TDLibClientManager without major version bump.")
        self.logger = logger
        self.receiveQueue.async { [weak self] in
            while (true) {
                guard let self else { break }
                guard
                    let res = td_receive(10),
                    case let dataString = String(cString: res),
                    let data = dataString.data(using: .utf8)
                else {
                    continue
                }
                self.logger?.log(dataString, type: .receive)
                self.queryResultAsync(data)
            }
        }
    }
    
    
    deinit {
        closeClients()
    }
    
    /// Sends `close` request to each known ``TDLibClient`` and waits for all ``authorizationStateClosed`` updates. This is a blocking method.
    /// Will be called on manager's ``deinit``. However, consider to call this method manually on `willTerminateNotification` or similar. Otherwise, client data may be lost.
    public func closeClients() {
        for client in self.clients.values {
            try? client.close(completion: { _ in })
        }
        
        while (!self.clients.isEmpty) {}
    }
    
    /// createClient
    /// Creates ``TDLibClient`` and registers it's `updateHandler` in manager, allowing a per-client routing from ``td_receive``.
    /// Returned client has been already "activated" with `getOption("version")` call and will receive updates immediatelly.
    ///
    ///
    /// - Parameter updateHandler: Handler closure that will get access to ``Data`` with update and corresponding ``TDLibClient``. Will run in a serial client-specific ``DispatchQueue`` without blocking any other clients or ``td_receive``. https://core.telegram.org/tdlib/getting-started#handling-updates
    public func createClient(updateHandler: @escaping (Data, TDLibClient) -> Void) -> TDLibClient {
        let newClient = TDLibClient(updateHandler: updateHandler, logger: self.logger)
        self.clients[newClient.id] = newClient
        try? newClient.send(query: DTO(GetOption(name: "version")), completion: { _ in })
        return newClient
    }
    
    private func queryResultAsync(_ result: Data) {
        self.queryQueue.async { [weak self] in
            guard
                let `self` = self,
                let json = try? JSONSerialization.jsonObject(with: result, options:[]),
                let dictionary = json as? [String:Any]
            else {
                return
            }
            
            let clientId = dictionary["@client_id"] as? Int32 ?? 1
            if let extraStr = dictionary["@extra"] as? String {
                if let client = self.clients[clientId] {
                    client.completionHandler(extra: extraStr, result: result)
                }
            } else {
                if let client = self.clients[clientId] {
                    client.updateHandlerQueue.async {
                        client.updateHandler(result, client)
                    }
                }
            }
            
            if self.checkClosedUpdate(dictionary) {
                self.clients.removeValue(forKey: clientId)
            }
        }
    }
    
    private func checkClosedUpdate(_ dict: [String: Any]) -> Bool {
        if let state = dict["authorization_state"] as? [String: Any],
           (state["@type"] as? String) == "authorizationStateClosed" {
            return true
        }
        return false
    }
    
}
