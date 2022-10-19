//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FoundationTransport.swift
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

public enum FoundationTransportError: Error {
    case invalidRequest
    case invalidOutputStream
    case timeout
}

public class FoundationTransport: NSObject, Transport, StreamDelegate {
    private weak var delegate: TransportEventClient?
    private let workQueue = DispatchQueue(label: "com.vluxe.starscream.websocket", attributes: [])
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var isOpen = false
    private var onConnect: ((InputStream, OutputStream) -> Void)?
    private var isTLS = false
    private var certPinner: CertificatePinning?
    
    public var usingTLS: Bool {
        return self.isTLS
    }
    
    public init(streamConfiguration: ((InputStream, OutputStream) -> Void)? = nil) {
        super.init()
        onConnect = streamConfiguration
    }
    
    deinit {
        inputStream?.delegate = nil
        outputStream?.delegate = nil
    }
    
    public func connect(url: URL, timeout: Double = 10, certificatePinning: CertificatePinning? = nil) {
        guard let parts = url.getParts() else {
            delegate?.connectionChanged(state: .failed(FoundationTransportError.invalidRequest))
            return
        }
        self.certPinner = certificatePinning
        self.isTLS = parts.isTLS
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        let h = parts.host as NSString
        CFStreamCreatePairWithSocketToHost(nil, h, UInt32(parts.port), &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        guard let inStream = inputStream, let outStream = outputStream else {
                return
        }
        inStream.delegate = self
        outStream.delegate = self
    
        if isTLS {
            let key = CFStreamPropertyKey(rawValue: kCFStreamPropertySocketSecurityLevel)
            CFReadStreamSetProperty(inStream, key, kCFStreamSocketSecurityLevelNegotiatedSSL)
            CFWriteStreamSetProperty(outStream, key, kCFStreamSocketSecurityLevelNegotiatedSSL)
        }
        
        onConnect?(inStream, outStream)
        
        isOpen = false
        CFReadStreamSetDispatchQueue(inStream, workQueue)
        CFWriteStreamSetDispatchQueue(outStream, workQueue)
        inStream.open()
        outStream.open()
        
        
        workQueue.asyncAfter(deadline: .now() + timeout, execute: { [weak self] in
            guard let s = self else { return }
            if !s.isOpen {
                s.delegate?.connectionChanged(state: .failed(FoundationTransportError.timeout))
            }
        })
    }
    
    public func disconnect() {
        if let stream = inputStream {
            stream.delegate = nil
            CFReadStreamSetDispatchQueue(stream, nil)
            stream.close()
        }
        if let stream = outputStream {
            stream.delegate = nil
            CFWriteStreamSetDispatchQueue(stream, nil)
            stream.close()
        }
        isOpen = false
        outputStream = nil
        inputStream = nil
    }
    
    public func register(delegate: TransportEventClient) {
        self.delegate = delegate
    }
    
    public func write(data: Data, completion: @escaping ((Error?) -> ())) {
        guard let outStream = outputStream else {
            completion(FoundationTransportError.invalidOutputStream)
            return
        }
        var total = 0
        let buffer = UnsafeRawPointer((data as NSData).bytes).assumingMemoryBound(to: UInt8.self)
        //NOTE: this might need to be dispatched to the work queue instead of being written inline. TBD.
        while total < data.count {
            let written = outStream.write(buffer, maxLength: data.count)
            if written < 0 {
                completion(FoundationTransportError.invalidOutputStream)
                return
            }
            total += written
        }
        completion(nil)
    }
    
    private func getSecurityData() -> (SecTrust?, String?) {
        #if os(watchOS)
        return (nil, nil)
        #else
        guard let outputStream = outputStream else {
            return (nil, nil)
        }
        let trust = outputStream.property(forKey: kCFStreamPropertySSLPeerTrust as Stream.PropertyKey) as! SecTrust?
        var domain = outputStream.property(forKey: kCFStreamSSLPeerName as Stream.PropertyKey) as! String?
        
        if domain == nil,
            let sslContextOut = CFWriteStreamCopyProperty(outputStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLContext)) as! SSLContext? {
            var peerNameLen: Int = 0
            SSLGetPeerDomainNameLength(sslContextOut, &peerNameLen)
            var peerName = Data(count: peerNameLen)
            let _ = peerName.withUnsafeMutableBytes { (peerNamePtr: UnsafeMutablePointer<Int8>) in
                SSLGetPeerDomainName(sslContextOut, peerNamePtr, &peerNameLen)
            }
            if let peerDomain = String(bytes: peerName, encoding: .utf8), peerDomain.count > 0 {
                domain = peerDomain
            }
        }
        return (trust, domain)
        #endif
    }
    
    private func read() {
        guard let stream = inputStream else {
            return
        }
        let maxBuffer = 4096
        let buf = NSMutableData(capacity: maxBuffer)
        let buffer = UnsafeMutableRawPointer(mutating: buf!.bytes).assumingMemoryBound(to: UInt8.self)
        let length = stream.read(buffer, maxLength: maxBuffer)
        if length < 1 {
            return
        }
        let data = Data(bytes: buffer, count: length)
        delegate?.connectionChanged(state: .receive(data))
    }
    
    // MARK: - StreamDelegate
    
    open func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            if aStream == inputStream {
                read()
            }
        case .errorOccurred:
            delegate?.connectionChanged(state: .failed(aStream.streamError))
        case .endEncountered:
            if aStream == inputStream {
                delegate?.connectionChanged(state: .cancelled)
            }
        case .openCompleted:
            if aStream == inputStream {
                let (trust, domain) = getSecurityData()
                if let pinner = certPinner, let trust = trust {
                    pinner.evaluateTrust(trust: trust, domain:  domain, completion: { [weak self] (state) in
                        switch state {
                        case .success:
                            self?.isOpen = true
                            self?.delegate?.connectionChanged(state: .connected)
                        case .failed(let error):
                            self?.delegate?.connectionChanged(state: .failed(error))
                        }
                        
                    })
                } else {
                    isOpen = true
                    delegate?.connectionChanged(state: .connected)
                }
            }
        case .endEncountered:
            if aStream == inputStream {
                delegate?.connectionChanged(state: .cancelled)
            }
        default:
            break
        }
    }
}
