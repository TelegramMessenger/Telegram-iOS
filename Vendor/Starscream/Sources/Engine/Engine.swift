//
//  Engine.swift
//  Starscream
//
//  Created by Dalton Cherry on 6/15/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//

import Foundation

public protocol EngineDelegate: class {
    func didReceive(event: WebSocketEvent)
}

public protocol Engine {
    func register(delegate: EngineDelegate)
    func start(request: URLRequest)
    func stop(closeCode: UInt16)
    func forceStop()
    func write(data: Data, opcode: FrameOpCode, completion: (() -> ())?)
    func write(string: String, completion: (() -> ())?)
}
