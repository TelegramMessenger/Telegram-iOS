//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Framer.swift
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

let FinMask: UInt8          = 0x80
let OpCodeMask: UInt8       = 0x0F
let RSVMask: UInt8          = 0x70
let RSV1Mask: UInt8         = 0x40
let MaskMask: UInt8         = 0x80
let PayloadLenMask: UInt8   = 0x7F
let MaxFrameSize: Int       = 32

// Standard WebSocket close codes
public enum CloseCode: UInt16 {
    case normal                 = 1000
    case goingAway              = 1001
    case protocolError          = 1002
    case protocolUnhandledType  = 1003
    // 1004 reserved.
    case noStatusReceived       = 1005
    //1006 reserved.
    case encoding               = 1007
    case policyViolated         = 1008
    case messageTooBig          = 1009
}

public enum FrameOpCode: UInt8 {
    case continueFrame = 0x0
    case textFrame = 0x1
    case binaryFrame = 0x2
    // 3-7 are reserved.
    case connectionClose = 0x8
    case ping = 0x9
    case pong = 0xA
    // B-F reserved.
    case unknown = 100
}

public struct Frame {
    let isFin: Bool
    let needsDecompression: Bool
    let isMasked: Bool
    let opcode: FrameOpCode
    let payloadLength: UInt64
    let payload: Data
    let closeCode: UInt16 //only used by connectionClose opcode
}

public enum FrameEvent {
    case frame(Frame)
    case error(Error)
}

public protocol FramerEventClient: class {
    func frameProcessed(event: FrameEvent)
}

public protocol Framer {
    func add(data: Data)
    func register(delegate: FramerEventClient)
    func createWriteFrame(opcode: FrameOpCode, payload: Data, isCompressed: Bool) -> Data
    func updateCompression(supports: Bool)
    func supportsCompression() -> Bool
}

public class WSFramer: Framer {
    private let queue = DispatchQueue(label: "com.vluxe.starscream.wsframer", attributes: [])
    private weak var delegate: FramerEventClient?
    private var buffer = Data()
    public var compressionEnabled = false
    private let isServer: Bool
    
    public init(isServer: Bool = false) {
        self.isServer = isServer
    }
    
    public func updateCompression(supports: Bool) {
        compressionEnabled = supports
    }
    
    public func supportsCompression() -> Bool {
        return compressionEnabled
    }
    
    enum ProcessEvent {
        case needsMoreData
        case processedFrame(Frame, Int)
        case failed(Error)
    }
    
    public func add(data: Data) {
        queue.async { [weak self] in
            self?.buffer.append(data)
            while(true) {
               let event = self?.process() ?? .needsMoreData
                switch event {
                case .needsMoreData:
                    return
                case .processedFrame(let frame, let split):
                    guard let s = self else { return }
                    s.delegate?.frameProcessed(event: .frame(frame))
                    if split >= s.buffer.count {
                        s.buffer = Data()
                        return
                    }
                    s.buffer = s.buffer.advanced(by: split)
                case .failed(let error):
                    self?.delegate?.frameProcessed(event: .error(error))
                    self?.buffer = Data()
                    return
                }
            }
        }
    }

    public func register(delegate: FramerEventClient) {
        self.delegate = delegate
    }
    
    private func process() -> ProcessEvent {
        if buffer.count < 2 {
            return .needsMoreData
        }
        var pointer = [UInt8]()
        buffer.withUnsafeBytes { pointer.append(contentsOf: $0) }

        let isFin = (FinMask & pointer[0])
        let opcodeRawValue = (OpCodeMask & pointer[0])
        let opcode = FrameOpCode(rawValue: opcodeRawValue) ?? .unknown
        let isMasked = (MaskMask & pointer[1])
        let payloadLen = (PayloadLenMask & pointer[1])
        let RSV1 = (RSVMask & pointer[0])
        var needsDecompression = false
        
        if compressionEnabled && opcode != .continueFrame {
           needsDecompression = (RSV1Mask & pointer[0]) > 0
        }
        if !isServer && (isMasked > 0 || RSV1 > 0) && opcode != .pong && !needsDecompression {
            let errCode = CloseCode.protocolError.rawValue
            return .failed(WSError(type: .protocolError, message: "masked and rsv data is not currently supported", code: errCode))
        }
        let isControlFrame = (opcode == .connectionClose || opcode == .ping)
        if !isControlFrame && (opcode != .binaryFrame && opcode != .continueFrame &&
            opcode != .textFrame && opcode != .pong) {
            let errCode = CloseCode.protocolError.rawValue
            return .failed(WSError(type: .protocolError, message: "unknown opcode: \(opcodeRawValue)", code: errCode))
        }
        if isControlFrame && isFin == 0 {
            let errCode = CloseCode.protocolError.rawValue
            return .failed(WSError(type: .protocolError, message: "control frames can't be fragmented", code: errCode))
        }
        
        var offset = 2
    
        if isControlFrame && payloadLen > 125 {
            return .failed(WSError(type: .protocolError, message: "payload length is longer than allowed for a control frame", code: CloseCode.protocolError.rawValue))
        }
        
        var dataLength = UInt64(payloadLen)
        var closeCode = CloseCode.normal.rawValue
        if opcode == .connectionClose {
            if payloadLen == 1 {
                closeCode = CloseCode.protocolError.rawValue
                dataLength = 0
            } else if payloadLen > 1 {
                if pointer.count < 4 {
                    return .needsMoreData
                }
                let size = MemoryLayout<UInt16>.size
                closeCode = pointer.readUint16(offset: offset)
                offset += size
                dataLength -= UInt64(size)
                if closeCode < 1000 || (closeCode > 1003 && closeCode < 1007) || (closeCode > 1013 && closeCode < 3000) {
                    closeCode = CloseCode.protocolError.rawValue
                }
            }
        }
        
        if payloadLen == 127 {
             let size = MemoryLayout<UInt64>.size
            if size + offset > pointer.count {
                return .needsMoreData
            }
            dataLength = pointer.readUint64(offset: offset)
            offset += size
        } else if payloadLen == 126 {
            let size = MemoryLayout<UInt16>.size
            if size + offset > pointer.count {
                return .needsMoreData
            }
            dataLength = UInt64(pointer.readUint16(offset: offset))
            offset += size
        }
        
        let maskStart = offset
        if isServer {
            offset += MemoryLayout<UInt32>.size
        }
        
        if dataLength > (pointer.count - offset) {
            return .needsMoreData
        }
        
        //I don't like this cast, but Data's count returns an Int.
        //Might be a problem with huge payloads. Need to revisit.
        let readDataLength = Int(dataLength)
        
        let payload: Data
        if readDataLength == 0 {
            payload = Data()
        } else {
            if isServer {
                payload = pointer.unmaskData(maskStart: maskStart, offset: offset, length: readDataLength)
            } else {
                let end = offset + readDataLength
                payload = Data(pointer[offset..<end])
            }
        }
        offset += readDataLength

        let frame = Frame(isFin: isFin > 0, needsDecompression: needsDecompression, isMasked: isMasked > 0, opcode: opcode, payloadLength: dataLength, payload: payload, closeCode: closeCode)
        return .processedFrame(frame, offset)
    }
    
    public func createWriteFrame(opcode: FrameOpCode, payload: Data, isCompressed: Bool) -> Data {
        let payloadLength = payload.count
        
        let capacity = payloadLength + MaxFrameSize
        var pointer = [UInt8](repeating: 0, count: capacity)
        
        //set the framing info
        pointer[0] = FinMask | opcode.rawValue
        if isCompressed {
             pointer[0] |= RSV1Mask
        }
        
        var offset = 2 //skip pass the framing info
        if payloadLength < 126 {
            pointer[1] = UInt8(payloadLength)
        } else if payloadLength <= Int(UInt16.max) {
            pointer[1] = 126
            writeUint16(&pointer, offset: offset, value: UInt16(payloadLength))
            offset += MemoryLayout<UInt16>.size
        } else {
            pointer[1] = 127
            writeUint64(&pointer, offset: offset, value: UInt64(payloadLength))
            offset += MemoryLayout<UInt64>.size
        }
        
        //clients are required to mask the payload data, but server don't according to the RFC
        if !isServer {
            pointer[1] |= MaskMask
            
            //write the random mask key in
            let maskKey: UInt32 = UInt32.random(in: 0...UInt32.max)
            
            writeUint32(&pointer, offset: offset, value: maskKey)
            let maskStart = offset
            offset += MemoryLayout<UInt32>.size
            
            //now write the payload data in
            for i in 0..<payloadLength {
                pointer[offset] = payload[i] ^ pointer[maskStart + (i % MemoryLayout<UInt32>.size)]
                offset += 1
            }
        } else {
            for i in 0..<payloadLength {
                pointer[offset] = payload[i]
                offset += 1
            }
        }
        return Data(pointer[0..<offset])
    }
}

/// MARK: - functions for simpler array buffer reading and writing

public protocol MyWSArrayType {}
extension UInt8: MyWSArrayType {}

public extension Array where Element: MyWSArrayType & UnsignedInteger {
    
    /**
     Read a UInt16 from a buffer.
     - parameter offset: is the offset index to start the read from (e.g. buffer[0], buffer[1], etc).
     - returns: a UInt16 of the value from the buffer
     */
    func readUint16(offset: Int) -> UInt16 {
        return (UInt16(self[offset + 0]) << 8) | UInt16(self[offset + 1])
    }
    
    /**
     Read a UInt64 from a buffer.
     - parameter offset: is the offset index to start the read from (e.g. buffer[0], buffer[1], etc).
     - returns: a UInt64 of the value from the buffer
     */
    func readUint64(offset: Int) -> UInt64 {
        var value = UInt64(0)
        for i in 0...7 {
            value = (value << 8) | UInt64(self[offset + i])
        }
        return value
    }
    
    func unmaskData(maskStart: Int, offset: Int, length: Int) -> Data {
        var unmaskedBytes = [UInt8](repeating: 0, count: length)
        let maskSize = MemoryLayout<UInt32>.size
        for i in 0..<length {
            unmaskedBytes[i] = UInt8(self[offset + i] ^ self[maskStart + (i % maskSize)])
        }
        return Data(unmaskedBytes)
    }
}

/**
 Write a UInt16 to the buffer. It fills the 2 array "slots" of the UInt8 array.
 - parameter buffer: is the UInt8 array (pointer) to write the value too.
 - parameter offset: is the offset index to start the write from (e.g. buffer[0], buffer[1], etc).
 */
public func writeUint16( _ buffer: inout [UInt8], offset: Int, value: UInt16) {
    buffer[offset + 0] = UInt8(value >> 8)
    buffer[offset + 1] = UInt8(value & 0xff)
}

/**
 Write a UInt32 to the buffer. It fills the 4 array "slots" of the UInt8 array.
 - parameter buffer: is the UInt8 array (pointer) to write the value too.
 - parameter offset: is the offset index to start the write from (e.g. buffer[0], buffer[1], etc).
 */
public func writeUint32( _ buffer: inout [UInt8], offset: Int, value: UInt32) {
    for i in 0...3 {
        buffer[offset + i] = UInt8((value >> (8*UInt32(3 - i))) & 0xff)
    }
}

/**
 Write a UInt64 to the buffer. It fills the 8 array "slots" of the UInt8 array.
 - parameter buffer: is the UInt8 array (pointer) to write the value too.
 - parameter offset: is the offset index to start the write from (e.g. buffer[0], buffer[1], etc).
 */
public func writeUint64( _ buffer: inout [UInt8], offset: Int, value: UInt64) {
    for i in 0...7 {
        buffer[offset + i] = UInt8((value >> (8*UInt64(7 - i))) & 0xff)
    }
}
