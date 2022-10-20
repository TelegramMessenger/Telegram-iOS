//
//  WSEngine.swift
//  Starscream
//
//  Created by Dalton Cherry on 6/15/19.
//  Copyright © 2019 Vluxe. All rights reserved.
//

import Foundation

public class WSEngine: Engine, TransportEventClient, FramerEventClient,
FrameCollectorDelegate, HTTPHandlerDelegate {
    private let transport: Transport
    private let framer: Framer
    private let httpHandler: HTTPHandler
    private let compressionHandler: CompressionHandler?
    private let certPinner: CertificatePinning?
    private let headerChecker: HeaderValidator
    private var request: URLRequest!
    
    private let frameHandler = FrameCollector()
    private var didUpgrade = false
    private var secKeyValue = ""
    private let writeQueue = DispatchQueue(label: "com.vluxe.starscream.writequeue")
    private let mutex = DispatchSemaphore(value: 1)
    private var canSend = false
    
    weak var delegate: EngineDelegate?
    public var respondToPingWithPong: Bool = true
    
    public init(transport: Transport,
                certPinner: CertificatePinning? = nil,
                headerValidator: HeaderValidator = FoundationSecurity(),
                httpHandler: HTTPHandler = FoundationHTTPHandler(),
                framer: Framer = WSFramer(),
                compressionHandler: CompressionHandler? = nil) {
        self.transport = transport
        self.framer = framer
        self.httpHandler = httpHandler
        self.certPinner = certPinner
        self.headerChecker = headerValidator
        self.compressionHandler = compressionHandler
        framer.updateCompression(supports: compressionHandler != nil)
        frameHandler.delegate = self
    }
    
    public func register(delegate: EngineDelegate) {
        self.delegate = delegate
    }
    
    public func start(request: URLRequest) {
        mutex.wait()
        let isConnected = canSend
        mutex.signal()
        if isConnected {
            return
        }
        
        self.request = request
        transport.register(delegate: self)
        framer.register(delegate: self)
        httpHandler.register(delegate: self)
        frameHandler.delegate = self
        guard let url = request.url else {
            return
        }
        transport.connect(url: url, timeout: request.timeoutInterval, certificatePinning: certPinner)
    }
    
    public func stop(closeCode: UInt16 = CloseCode.normal.rawValue) {
        let capacity = MemoryLayout<UInt16>.size
        var pointer = [UInt8](repeating: 0, count: capacity)
        writeUint16(&pointer, offset: 0, value: closeCode)
        let payload = Data(bytes: pointer, count: MemoryLayout<UInt16>.size)
        write(data: payload, opcode: .connectionClose, completion: { [weak self] in
            self?.reset()
            self?.forceStop()
        })
    }
    
    public func forceStop() {
        transport.disconnect()
    }
    
    public func write(string: String, completion: (() -> ())?) {
        let data = string.data(using: .utf8)!
        write(data: data, opcode: .textFrame, completion: completion)
    }
    
    public func write(data: Data, opcode: FrameOpCode, completion: (() -> ())?) {
        writeQueue.async { [weak self] in
            guard let s = self else { return }
            s.mutex.wait()
            let canWrite = s.canSend
            s.mutex.signal()
            if !canWrite {
                return
            }
            
            var isCompressed = false
            var sendData = data
            if let compressedData = s.compressionHandler?.compress(data: data) {
                sendData = compressedData
                isCompressed = true
            }
            
            let frameData = s.framer.createWriteFrame(opcode: opcode, payload: sendData, isCompressed: isCompressed)
            s.transport.write(data: frameData, completion: {_ in
                completion?()
            })
        }
    }
    
    // MARK: - TransportEventClient
    
    public func connectionChanged(state: ConnectionState) {
        switch state {
        case .connected:
            secKeyValue = HTTPWSHeader.generateWebSocketKey()
            let wsReq = HTTPWSHeader.createUpgrade(request: request, supportsCompression: framer.supportsCompression(), secKeyValue: secKeyValue)
            let data = httpHandler.convert(request: wsReq)
            transport.write(data: data, completion: {_ in })
        case .waiting:
            break
        case .failed(let error):
            handleError(error)
        case .viability(let isViable):
            broadcast(event: .viabilityChanged(isViable))
        case .shouldReconnect(let status):
            broadcast(event: .reconnectSuggested(status))
        case .receive(let data):
            if didUpgrade {
                framer.add(data: data)
            } else {
                let offset = httpHandler.parse(data: data)
                if offset > 0 {
                    let extraData = data.subdata(in: offset..<data.endIndex)
                    framer.add(data: extraData)
                }
            }
        case .cancelled:
            broadcast(event: .cancelled)
        }
    }
    
    // MARK: - HTTPHandlerDelegate
    
    public func didReceiveHTTP(event: HTTPEvent) {
        switch event {
        case .success(let headers):
            if let error = headerChecker.validate(headers: headers, key: secKeyValue) {
                handleError(error)
                return
            }
            mutex.wait()
            didUpgrade = true
            canSend = true
            mutex.signal()
            compressionHandler?.load(headers: headers)
            if let url = request.url {
                HTTPCookie.cookies(withResponseHeaderFields: headers, for: url).forEach {
                    HTTPCookieStorage.shared.setCookie($0)
                }
            }

            broadcast(event: .connected(headers))
        case .failure(let error):
            handleError(error)
        }
    }
    
    // MARK: - FramerEventClient
    
    public func frameProcessed(event: FrameEvent) {
        switch event {
        case .frame(let frame):
            frameHandler.add(frame: frame)
        case .error(let error):
            handleError(error)
        }
    }
    
    // MARK: - FrameCollectorDelegate
    
    public func decompress(data: Data, isFinal: Bool) -> Data? {
        return compressionHandler?.decompress(data: data, isFinal: isFinal)
    }
    
    public func didForm(event: FrameCollector.Event) {
        switch event {
        case .text(let string):
            broadcast(event: .text(string))
        case .binary(let data):
            broadcast(event: .binary(data))
        case .pong(let data):
            broadcast(event: .pong(data))
        case .ping(let data):
            broadcast(event: .ping(data))
            if respondToPingWithPong {
                write(data: data ?? Data(), opcode: .pong, completion: nil)
            }
        case .closed(let reason, let code):
            broadcast(event: .disconnected(reason, code))
            stop(closeCode: code)
        case .error(let error):
            handleError(error)
        }
    }
    
    private func broadcast(event: WebSocketEvent) {
        delegate?.didReceive(event: event)
    }
    
    //This call can be coming from a lot of different queues/threads.
    //be aware of that when modifying shared variables
    private func handleError(_ error: Error?) {
        if let wsError = error as? WSError {
            stop(closeCode: wsError.code)
        } else {
            stop()
        }
        
        delegate?.didReceive(event: .error(error))
    }
    
    private func reset() {
        mutex.wait()
        canSend = false
        didUpgrade = false
        mutex.signal()
    }
    
    
}
