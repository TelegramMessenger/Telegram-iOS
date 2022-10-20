//
//  MockServer.swift
//  Starscream
//
//  Created by Dalton Cherry on 1/29/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//

import Foundation
@testable import Starscream

public class MockConnection: Connection, HTTPServerDelegate, FramerEventClient, FrameCollectorDelegate {
    let transport: MockTransport
    private let httpHandler = FoundationHTTPServerHandler()
    private let framer = WSFramer(isServer: true)
    private let frameHandler = FrameCollector()
    private var didUpgrade = false
    public var onEvent: ((ConnectionEvent) -> Void)?
    fileprivate weak var delegate: ConnectionDelegate?
    
    init(transport: MockTransport) {
        self.transport = transport
        httpHandler.register(delegate: self)
        framer.register(delegate: self)
        frameHandler.delegate = self
    }
    
    func add(data: Data) {
        if !didUpgrade {
            httpHandler.parse(data: data)
        } else {
            framer.add(data: data)
        }
    }
    
    public func write(data: Data, opcode: FrameOpCode) {
        let wsData = framer.createWriteFrame(opcode: opcode, payload: data, isCompressed: false)
        transport.received(data: wsData)
    }
    
    /// MARK: - HTTPServerDelegate
    
    public func didReceive(event: HTTPEvent) {
        switch event {
        case .success(let headers):
            didUpgrade = true
            //TODO: add headers and key check?
            let response = httpHandler.createResponse(headers: [:])
            transport.received(data: response)
            delegate?.didReceive(event: .connected(self, headers))
            onEvent?(.connected(headers))
        case .failure(let error):
            onEvent?(.error(error))
        }
    }
    
    /// MARK: - FrameCollectorDelegate
    
    public func frameProcessed(event: FrameEvent) {
        switch event {
        case .frame(let frame):
            frameHandler.add(frame: frame)
        case .error(let error):
            onEvent?(.error(error))
        }
    }
    
    public func didForm(event: FrameCollector.Event) {
        switch event {
        case .text(let string):
            delegate?.didReceive(event: .text(self, string))
            onEvent?(.text(string))
        case .binary(let data):
            delegate?.didReceive(event: .binary(self, data))
            onEvent?(.binary(data))
        case .pong(let data):
            delegate?.didReceive(event: .pong(self, data))
            onEvent?(.pong(data))
        case .ping(let data):
            delegate?.didReceive(event: .ping(self, data))
            onEvent?(.ping(data))
        case .closed(let reason, let code):
            delegate?.didReceive(event: .disconnected(self, reason, code))
            onEvent?(.disconnected(reason, code))
        case .error(let error):
            onEvent?(.error(error))
        }
    }
    
    public func decompress(data: Data, isFinal: Bool) -> Data? {
        return nil
    }
}
    

public class MockServer: Server, ConnectionDelegate {
    fileprivate var connections = [String: MockConnection]()
    
    public var onEvent: ((ServerEvent) -> Void)?
    
    public func start(address: String, port: UInt16) -> Error? {
        return nil
    }
    
    public func connect(transport: MockTransport) {
        let conn = MockConnection(transport: transport)
        conn.delegate = self
        connections[transport.uuid] = conn
    }
    
    public func disconnect(uuid: String) {
//        guard let conn = connections[uuid] else {
//            return
//        }
        //TODO: force disconnect
        connections.removeValue(forKey: uuid)
    }
    
    public func write(data: Data, uuid: String) {
        guard let conn = connections[uuid] else {
            return
        }
        conn.add(data: data)
    }
    
    /// MARK: - MockConnectionDelegate
    public func didReceive(event: ServerEvent) {
        onEvent?(event)
    }
}
