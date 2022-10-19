//////////////////////////////////////////////////////////////////////////////////////////////////
//
//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Transport.swift
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

import Foundation

public enum ConnectionState {
    case connected
    case waiting
    case cancelled
    case failed(Error?)
    
    //the viability (connection status) of the connection has updated
    //e.g. connection is down, connection came back up, etc
    case viability(Bool)
    
    //the connection has upgrade to wifi from cellular.
    //you should consider reconnecting to take advantage of this
    case shouldReconnect(Bool)
    
    //the connection receive data
    case receive(Data)
}

public protocol TransportEventClient: class {
    func connectionChanged(state: ConnectionState)
}

public protocol Transport: class {
    func register(delegate: TransportEventClient)
    func connect(url: URL, timeout: Double, certificatePinning: CertificatePinning?)
    func disconnect()
    func write(data: Data, completion: @escaping ((Error?) -> ()))
    var usingTLS: Bool { get }
}
