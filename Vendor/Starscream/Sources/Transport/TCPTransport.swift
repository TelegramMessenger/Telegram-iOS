//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HTTPTransport.swift
//  Starscream
//
//  Created by Dalton Cherry on 1/23/19.
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

public enum TCPTransportError: Error {
    case invalidRequest
}

@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public class TCPTransport: Transport {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.vluxe.starscream.networkstream", attributes: [])
    private weak var delegate: TransportEventClient?
    private var isRunning = false
    private var isTLS = false
    
    public var usingTLS: Bool {
        return self.isTLS
    }
    
    public init(connection: NWConnection) {
        self.connection = connection
        start()
    }
    
    public init() {
        //normal connection, will use the "connect" method below
    }
    
    public func connect(url: URL, timeout: Double = 10, certificatePinning: CertificatePinning? = nil) {
        guard let parts = url.getParts() else {
            delegate?.connectionChanged(state: .failed(TCPTransportError.invalidRequest))
            return
        }
        self.isTLS = parts.isTLS
        let options = NWProtocolTCP.Options()
        options.connectionTimeout = Int(timeout.rounded(.up))

        let tlsOptions = isTLS ? NWProtocolTLS.Options() : nil
        if let tlsOpts = tlsOptions {
            sec_protocol_options_set_verify_block(tlsOpts.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
                let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
                guard let pinner = certificatePinning else {
                    sec_protocol_verify_complete(true)
                    return
                }
                pinner.evaluateTrust(trust: trust, domain: parts.host, completion: { (state) in
                    switch state {
                    case .success:
                        sec_protocol_verify_complete(true)
                    case .failed(_):
                        sec_protocol_verify_complete(false)
                    }
                })
            }, queue)
        }
        let parameters = NWParameters(tls: tlsOptions, tcp: options)
        let conn = NWConnection(host: NWEndpoint.Host.name(parts.host, nil), port: NWEndpoint.Port(rawValue: UInt16(parts.port))!, using: parameters)
        connection = conn
        start()
    }
    
    public func disconnect() {
        isRunning = false
        connection?.cancel()
    }
    
    public func register(delegate: TransportEventClient) {
        self.delegate = delegate
    }
    
    public func write(data: Data, completion: @escaping ((Error?) -> ())) {
        connection?.send(content: data, completion: .contentProcessed { (error) in
            completion(error)
        })
    }
    
    private func start() {
        guard let conn = connection else {
            return
        }
        conn.stateUpdateHandler = { [weak self] (newState) in
            switch newState {
            case .ready:
                self?.delegate?.connectionChanged(state: .connected)
            case .waiting:
                self?.delegate?.connectionChanged(state: .waiting)
            case .cancelled:
                self?.delegate?.connectionChanged(state: .cancelled)
            case .failed(let error):
                self?.delegate?.connectionChanged(state: .failed(error))
            case .setup, .preparing:
                break
            @unknown default:
                break
            }
        }
        
        conn.viabilityUpdateHandler = { [weak self] (isViable) in
            self?.delegate?.connectionChanged(state: .viability(isViable))
        }
        
        conn.betterPathUpdateHandler = { [weak self] (isBetter) in
            self?.delegate?.connectionChanged(state: .shouldReconnect(isBetter))
        }
        
        conn.start(queue: queue)
        isRunning = true
        readLoop()
    }
    
    //readLoop keeps reading from the connection to get the latest content
    private func readLoop() {
        if !isRunning {
            return
        }
        connection?.receive(minimumIncompleteLength: 2, maximumLength: 4096, completion: {[weak self] (data, context, isComplete, error) in
            guard let s = self else {return}
            if let data = data {
                s.delegate?.connectionChanged(state: .receive(data))
            }
            
            // Refer to https://developer.apple.com/documentation/network/implementing_netcat_with_network_framework
            if let context = context, context.isFinal, isComplete {
                return
            }
            
            if error == nil {
                s.readLoop()
            }

        })
    }
}
#else
typealias TCPTransport = FoundationTransport
#endif
