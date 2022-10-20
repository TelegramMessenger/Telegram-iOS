//
//  MockTransport.swift
//  Starscream
//
//  Created by Dalton Cherry on 1/28/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//

import Foundation
@testable import Starscream

public class MockTransport: Transport {
    
    public var usingTLS: Bool {
        return false
    }
    private weak var delegate: TransportEventClient?
    
    private let id: String
    weak var server: MockServer?
    var uuid: String {
        return id
    }
    
    public init(server: MockServer) {
        self.server = server
        self.id = UUID().uuidString
    }
    
    public func register(delegate: TransportEventClient) {
        self.delegate = delegate
    }
    
   public func connect(url: URL, timeout: Double, certificatePinning: CertificatePinning?) {
        server?.connect(transport: self)
        delegate?.connectionChanged(state: .connected)
    }
    
    public func disconnect() {
        server?.disconnect(uuid: uuid)
    }
    
    public func write(data: Data, completion: @escaping ((Error?) -> ())) {
        server?.write(data: data, uuid: uuid)
    }
    
    public func received(data: Data) {
        delegate?.connectionChanged(state: .receive(data))
    }
    
    public func getSecurityData() -> (SecTrust?, String?) {
        return (nil, nil)
    }
}

public class MockSecurity: CertificatePinning, HeaderValidator {
    
    public func evaluateTrust(trust: SecTrust, domain: String?, completion: ((PinningState) -> ())) {
        completion(.success)
    }

    public func validate(headers: [String: String], key: String) -> Error? {
        return nil
    }
}
