//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WebSocketServer.swift
//  Starscream
//
//  Created by Dalton Cherry on 4/5/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

#if canImport(Network)
import Foundation
import Network

/// WebSocketServer is a Network.framework implementation of a WebSocket server
@available(watchOS, unavailable)
@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public class WebSocketServer: Server, ConnectionDelegate {
    public var onEvent: ((ServerEvent) -> Void)?
    private var connections = [String: ServerConnection]()
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.vluxe.starscream.server.networkstream", attributes: [])
    
    public init() {
        
    }
    
    public func start(address: String, port: UInt16) -> Error? {
        //TODO: support TLS cert adding/binding
        let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        let p = NWEndpoint.Port(rawValue: port)!
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host.name(address, nil), port: p)
        
        guard let listener = try? NWListener(using: parameters, on: p) else {
            return WSError(type: .serverError, message: "unable to start the listener at: \(address):\(port)", code: 0)
        }
        listener.newConnectionHandler = {[weak self] conn in
            let transport = TCPTransport(connection: conn)
            let c = ServerConnection(transport: transport)
            c.delegate = self
            self?.connections[c.uuid] = c
        }
//        listener.stateUpdateHandler = { state in
//            switch state {
//            case .ready:
//                print("ready to get sockets!")
//            case .setup:
//                print("setup to get sockets!")
//            case .cancelled:
//                print("server cancelled!")
//            case .waiting(let error):
//                print("waiting error: \(error)")
//            case .failed(let error):
//                print("server failed: \(error)")
//            @unknown default:
//                print("wat?")
//            }
//        }
        self.listener = listener
        listener.start(queue: queue)
        return nil
    }
    
    public func didReceive(event: ServerEvent) {
        onEvent?(event)
        switch event {
        case .disconnected(let conn, _, _):
            guard let conn = conn as? ServerConnection else {
                return
            }
            connections.removeValue(forKey: conn.uuid)
        default:
            break
        }
    }
}

@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public class ServerConnection: Connection, HTTPServerDelegate, FramerEventClient, FrameCollectorDelegate, TransportEventClient {
    let transport: TCPTransport
    private let httpHandler = FoundationHTTPServerHandler()
    private let framer = WSFramer(isServer: true)
    private let frameHandler = FrameCollector()
    private var didUpgrade = false
    public var onEvent: ((ConnectionEvent) -> Void)?
    public weak var delegate: ConnectionDelegate?
    private let id: String
    var uuid: String {
        return id
    }
    
    init(transport: TCPTransport) {
        self.id = UUID().uuidString
        self.transport = transport
        transport.register(delegate: self)
        httpHandler.register(delegate: self)
        framer.register(delegate: self)
        frameHandler.delegate = self
    }
    
    public func write(data: Data, opcode: FrameOpCode) {
        let wsData = framer.createWriteFrame(opcode: opcode, payload: data, isCompressed: false)
        transport.write(data: wsData, completion: {_ in })
    }
    
    // MARK: - TransportEventClient
    
    public func connectionChanged(state: ConnectionState) {
        switch state {
        case .connected:
            break
        case .waiting:
            break
        case .failed(let error):
            print("server connection error: \(error ?? WSError(type: .protocolError, message: "default error, no extra data", code: 0))") //handleError(error)
        case .viability(_):
            break
        case .shouldReconnect(_):
            break
        case .receive(let data):
            if didUpgrade {
                framer.add(data: data)
            } else {
                httpHandler.parse(data: data)
            }
        case .cancelled:
            print("server connection cancelled!")
            //broadcast(event: .cancelled)
        }
    }
    
    /// MARK: - HTTPServerDelegate
    
    public func didReceive(event: HTTPEvent) {
        switch event {
        case .success(let headers):
            didUpgrade = true
            let response = httpHandler.createResponse(headers: [:])
            transport.write(data: response, completion: {_ in })
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
#endif
