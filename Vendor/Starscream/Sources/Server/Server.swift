//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Server.swift
//  Starscream
//
//  Created by Dalton Cherry on 4/2/19.
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

public enum ConnectionEvent {
    case connected([String: String])
    case disconnected(String, UInt16)
    case text(String)
    case binary(Data)
    case pong(Data?)
    case ping(Data?)
    case error(Error)
}

public protocol Connection {
    func write(data: Data, opcode: FrameOpCode)
}

public protocol ConnectionDelegate: class {
    func didReceive(event: ServerEvent)
}

public enum ServerEvent {
    case connected(Connection, [String: String])
    case disconnected(Connection, String, UInt16)
    case text(Connection, String)
    case binary(Connection, Data)
    case pong(Connection, Data?)
    case ping(Connection, Data?)
}

public protocol Server {
    func start(address: String, port: UInt16) -> Error?
}


